#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=0.1.1
rm -rf build/maven
GROUP=com.github.gycrosskit VERSION="$version" bash gradlew --no-daemon publishAllPublicationsToStagingRepository
python3 scripts/jitpack-metadata.py build/maven
python3 scripts/verify-maven.py build/maven
mkdir -p build/release
# staging 可能保留旧版本；归档只包含本次不可变版本的五个模块。
archive_paths=()
for module_version in build/maven/com/github/gycrosskit/*/"$version"; do
    archive_paths+=("${module_version#build/maven/}")
done
[[ ${#archive_paths[@]} -eq 5 ]] || { echo "Expected five Maven modules" >&2; exit 1; }
COPYFILE_DISABLE=1 tar --no-xattrs -czf "build/release/customer-service-maven-${version}.tar.gz" -C build/maven "${archive_paths[@]}"
(cd build/release && shasum -a 256 "customer-service-maven-${version}.tar.gz") > SHA256SUMS
cp SHA256SUMS build/release/SHA256SUMS
