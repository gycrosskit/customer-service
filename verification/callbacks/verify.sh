#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
output=build/ownership/callbacks
mkdir -p "$output"
for module in ImSDK_Plus TDeskCore UIKit; do
  case "$module" in
    ImSDK_Plus) source=MocksImSDK.swift;;
    TDeskCore) source=MocksTDesk.swift;;
    UIKit) source=MocksUIKit.swift;;
  esac
  swiftc -emit-module -emit-library -module-name "$module" "verification/callbacks/$source" -o "$output/lib$module.dylib" -emit-module-path "$output/$module.swiftmodule"
done
swiftc -I "$output" -L "$output" -lUIKit -emit-module -emit-library -module-name TencentCloudAIDeskCustomer verification/callbacks/MocksDesk.swift -o "$output/libTencentCloudAIDeskCustomer.dylib" -emit-module-path "$output/TencentCloudAIDeskCustomer.swiftmodule"
swiftc -I "$output" -L "$output" -lUIKit -lTDeskCore -lImSDK_Plus -lTencentCloudAIDeskCustomer -Xlinker -rpath -Xlinker "$(pwd)/$output" ios/Sources/GycCustomerServiceNative/*.swift verification/callbacks/main.swift -o "$output/contract"
"$output/contract"
