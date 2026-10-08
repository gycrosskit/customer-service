#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="${VERSION:-0.1.6}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
rm -rf build/maven
GROUP=com.github.gycrosskit VERSION="$version" bash gradlew --no-daemon --max-workers=1 -Dorg.gradle.parallel=false publishAllPublicationsToStagingRepository
python3 scripts/jitpack-metadata.py build/maven
python3 scripts/verify-maven.py build/maven com.github.gycrosskit "$version" customer-service ios_arm64,ios_x64,ios_simulator_arm64 customer-service,customer-service-android,customer-service-iosarm64,customer-service-iosx64,customer-service-iossimulatorarm64
mkdir -p build/release
COPYFILE_DISABLE=1 tar --no-xattrs -czf build/release/customer-service-maven.tar.gz -C build/maven com
(cd build/release && shasum -a 256 customer-service-maven.tar.gz) > build/release/SHA256SUMS
