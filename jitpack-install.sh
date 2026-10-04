#!/usr/bin/env bash
set -euo pipefail
version=0.1.1
[[ "${VERSION:?JitPack must provide VERSION}" == "$version" ]] || { echo "Unsupported version" >&2; exit 1; }
archive="customer-service-maven-${version}.tar.gz"
# 从不可变标签的 Release 下载 macOS 生成的完整产物，并校验仓库中的 SHA-256。
curl -fL --retry 3 -o "$archive" "https://github.com/gycrosskit/customer-service/releases/download/${version}/${archive}"
sha256sum -c SHA256SUMS --ignore-missing
mkdir -p "$HOME/.m2/repository" build/release-maven
tar -xzf "$archive" -C "$HOME/.m2/repository"
tar -xzf "$archive" -C build/release-maven
