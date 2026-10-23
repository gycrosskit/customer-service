#!/usr/bin/env python3
"""缓存只用于源码编译；测试任务与发布验证保留原执行边界。"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
workflow = (ROOT / '.github/workflows/regression.yml').read_text()
jobs = dict(re.findall(r'^  ([\w-]+):\n(.*?)(?=^  [\w-]+:\n|\Z)',
                       workflow.split('\njobs:\n', 1)[1], re.M | re.S))
for name in ('android', 'native'):
    job = jobs[name]
    assert "GYC_CI_BUILD_CACHE: 'true'" in job
    assert 'gradle/actions/setup-gradle@ed408507eac070d1f99cc633dbcf757c94c7933a' in job
    assert "cache-read-only: ${{ github.event_name == 'pull_request' }}" in job
    cache_step = re.search(r'uses: gradle/actions/setup-gradle@[^\n]+\n        if: ([^\n]+)', job)
    assert cache_step and cache_step.group(1) == "needs.changes.outputs.source == 'true'"
    assert 'cache: gradle' not in job, 'Do not restore Gradle User Home twice'
    assert '--init-script "$PWD/scripts/ci-repositories.gradle"' in job
for name, job in jobs.items():
    if name not in ('android', 'native'):
        assert 'GYC_CI_BUILD_CACHE' not in job
        assert 'gradle/actions/setup-gradle@' not in job
policy = (ROOT / 'scripts/ci-repositories.gradle').read_text()
assert "if (System.getenv('GYC_CI_BUILD_CACHE') == 'true')" in policy
assert 'gradle.startParameter.buildCacheEnabled = true' in policy
assert 'withType(org.gradle.api.tasks.testing.AbstractTestTask).configureEach' in policy
assert 'outputs.upToDateWhen { false }' in policy
assert "outputs.doNotCacheIf('CI must execute behavior tests') { true }" in policy
print('CI cache contract: source-only cache and real test execution policy')

# 插件、消费工程与 Native 下载声明须保持一致，避免只改缓存键。
version = "2.2.21-1.0.0"
for build in ("build.gradle.kts", "verification/gradle/build.gradle.kts"):
    assert re.findall(r'kotlin\("multiplatform"\) version "([^"]+)"', (ROOT / build).read_text()) == [version]
assert re.findall(r'^kotlin=(.+)$', (ROOT / "gradle/native-toolchain.properties").read_text(), re.M) == [version]
for settings in ("settings.gradle.kts", "verification/gradle/settings.gradle.kts"):
    assert (ROOT / settings).read_text().count('maven("https://maven.eazytec-cloud.com/nexus/repository/maven-public/")') == 2
consumer = (ROOT / "verification/gradle/settings.gradle.kts").read_text()
assert 'exclusiveContent {' in consumer and 'includeGroup("com.github.gycrosskit.customer-service")' in consumer
assert 'candidateMaven?.toURI() ?: uri("https://jitpack.io")' in consumer
assert "mavenLocal" not in consumer and "includeBuild" not in consumer
print("Toolchain contract: common compiler, isolated candidate/public consumers; SDK execution not performed")
