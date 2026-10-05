#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
python3 verification/android-callbacks/create-fixture.py
python3 - <<'PY'
from pathlib import Path
import os,re,subprocess
cache=Path.home()/'.gradle/caches/modules-2/files-2.1'
def jar(group,name,version):
 matches=list((cache/group/name/version).rglob(name+'-'+version+'.jar'))
 assert len(matches)==1,(group,name,version,matches)
 return str(matches[0])
def support(module):return str(next(p for p in (cache/module).rglob('*.jar') if not any(x in p.name for x in ['-sources','-javadoc','-all'])))
kotlin_version=re.search(r'kotlin\("multiplatform"\) version "([^"]+)"',Path('build.gradle.kts').read_text()).group(1)
compiler=[jar('org.jetbrains.kotlin','kotlin-compiler-embeddable',kotlin_version),jar('org.jetbrains.kotlin','kotlin-stdlib',kotlin_version),jar('org.jetbrains.kotlin','kotlin-script-runtime',kotlin_version),support('org.jetbrains.kotlin/kotlin-reflect'),support('org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm'),support('org.jetbrains/annotations')]
libs=[compiler[1],jar('org.jetbrains.kotlinx','kotlinx-coroutines-core-jvm','1.10.2'),jar('org.jetbrains.kotlinx','kotlinx-coroutines-test-jvm','1.10.2')]
root=Path('build/remote-library-review/android-fixture');source=os.environ.get('CUSTOMER_CALLBACK_SOURCE','src/androidMain/kotlin/io/github/gycrosskit/customerservice/AndroidTencentCustomerServiceClient.kt')
sources=[str(p) for p in root.glob('*.kt')]+['verification/android-callbacks/main.kt','src/commonMain/kotlin/io/github/gycrosskit/customerservice/CustomerServiceProfile.kt',source]
subprocess.run(['java','-cp',os.pathsep.join(compiler),'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler','-no-stdlib','-no-reflect','-classpath',os.pathsep.join(libs),'-d',str(root/'classes')]+sources,check=True)
subprocess.run(['java','-cp',os.pathsep.join([str(root/'classes')]+libs),'io.github.gycrosskit.customerservice.MainKt'],check=True)
PY
