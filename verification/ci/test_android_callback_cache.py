"""执行真实 callback CLI 的缓存选择；Java 调用由记录器替代，不运行 SDK。"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
VERSION = re.search(r'kotlin\("multiplatform"\) version "([^"]+)"',
                    (ROOT / 'build.gradle.kts').read_text()).group(1)


class AndroidCallbackCacheTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / 'component with spaces'
        for name in ('build.gradle.kts', 'verification/android-callbacks/verify.sh',
                     'verification/android-callbacks/create-fixture.py'):
            target = self.source / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)
        self.home = self.root / 'home'
        self.default = self.home / '.gradle'
        self.private = self.root / 'private gradle home'
        self.calls = self.root / 'java-calls.jsonl'
        tools = self.root / 'tools'
        tools.mkdir()
        (tools / 'python3').symlink_to(sys.executable)
        java = tools / 'java'
        java.write_text('#!' + sys.executable + '\n'
                        'import json, os, sys\n'
                        'with open(os.environ["JAVA_CALLS"], "a") as output:\n'
                        '    output.write(json.dumps(sys.argv[1:]) + "\\n")\n')
        java.chmod(0o700)
        self.environment = dict(os.environ, HOME=str(self.home), JAVA_CALLS=str(self.calls),
                                PATH=str(tools) + os.pathsep + '/usr/bin:/bin')
        self.environment.pop('GRADLE_USER_HOME', None)

    def seed(self, home):
        cache = home / 'caches/modules-2/files-2.1'
        modules = [('org.jetbrains.kotlin', name, VERSION) for name in
                   ('kotlin-compiler-embeddable', 'kotlin-stdlib', 'kotlin-script-runtime')]
        modules += [('org.jetbrains.kotlin', 'kotlin-reflect', '1.6.10'),
                    ('org.jetbrains.kotlinx', 'kotlinx-coroutines-core-jvm', '1.10.2'),
                    ('org.jetbrains.kotlinx', 'kotlinx-coroutines-test-jvm', '1.10.2'),
                    ('org.jetbrains', 'annotations', '13.0')]
        for group, name, version in modules:
            jar = cache / group / name / version / 'hash' / f'{name}-{version}.jar'
            jar.parent.mkdir(parents=True)
            jar.write_text('not a real compiler; Java is mocked')
        return cache / 'org.jetbrains.kotlin/kotlin-compiler-embeddable' / VERSION / 'hash' / f'kotlin-compiler-embeddable-{VERSION}.jar'

    def run_cli(self, success, selected=None):
        result = subprocess.run(['bash', str(self.source / 'verification/android-callbacks/verify.sh')],
                                env=self.environment, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()] if self.calls.exists() else []
        if success:
            self.assertEqual(len(calls), 2)
            self.assertIn('org.jetbrains.kotlin.cli.jvm.K2JVMCompiler', calls[0])
            self.assertIn('io.github.gycrosskit.customerservice.MainKt', calls[1])
            for call in calls:
                for path in call[call.index('-cp') + 1].split(os.pathsep):
                    if path.endswith('.jar'):
                        self.assertTrue(Path(path).is_relative_to(selected), path)
        else:
            self.assertEqual(calls, [])

    def test_unset_uses_default_gradle_home(self):
        self.seed(self.default)
        self.run_cli(True, self.default)

    def test_private_home_with_spaces_overrides_default(self):
        self.seed(self.default)
        self.seed(self.private)
        self.environment['GRADLE_USER_HOME'] = str(self.private)
        self.run_cli(True, self.private)

    def test_missing_exact_compiler_rejects_without_default_fallback(self):
        self.seed(self.default)
        compiler = self.seed(self.private)
        compiler.rename(compiler.with_name('kotlin-compiler-embeddable-old-version.jar'))
        self.environment['GRADLE_USER_HOME'] = str(self.private)
        self.run_cli(False)

    def test_duplicate_compiler_is_rejected(self):
        compiler = self.seed(self.private)
        duplicate = compiler.parent.parent / 'other-hash' / compiler.name
        duplicate.parent.mkdir()
        shutil.copyfile(compiler, duplicate)
        self.environment['GRADLE_USER_HOME'] = str(self.private)
        self.run_cli(False)


if __name__ == '__main__':
    unittest.main()
