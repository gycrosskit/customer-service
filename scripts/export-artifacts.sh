#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=0.1.0
GROUP=com.github.gycrosskit VERSION="$version" bash gradlew --no-daemon publishAllPublicationsToStagingRepository
mkdir -p build/release
COPYFILE_DISABLE=1 tar -czf "build/release/customer-service-maven-${version}.tar.gz" -C build/maven com
COPYFILE_DISABLE=1 tar -czf "build/release/customer-service-native-${version}.tar.gz" GycCustomerServiceNative.podspec ios README.md LICENSE
(cd build/release && shasum -a 256 "customer-service-maven-${version}.tar.gz" "customer-service-native-${version}.tar.gz") > SHA256SUMS
cp SHA256SUMS build/release/SHA256SUMS
