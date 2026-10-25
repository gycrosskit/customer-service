#!/usr/bin/env python3
"""缓存只用于源码编译；测试任务与发布验证保留原执行边界。"""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
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

subprocess.run([sys.executable, '-B', str(ROOT / 'verification/ci/test_android_callback_cache.py')], check=True)
