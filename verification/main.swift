import Foundation
let target = CustomerServiceIdentity(appId: 100, userId: "member")
assert(customerServicePreparationAction(owned: nil, actualUser: "member", target: target) == .initialize)
assert(customerServicePreparationAction(owned: target, actualUser: "member", target: target) == .reuse)
assert(customerServicePreparationAction(owned: nil, actualUser: "foreign", target: target) == .reject)
assert(customerServicePreparationAction(owned: target, actualUser: "foreign", target: target) == .reject)
assert(customerServicePreparationAction(owned: target, actualUser: "member", target: CustomerServiceIdentity(appId: 101, userId: "member")) == .reset)
assert(customerServicePreparationAction(owned: target, actualUser: "member", target: CustomerServiceIdentity(appId: 100, userId: "next")) == .reset)
assert(customerServicePreparationAction(owned: target, actualUser: nil, target: target) == .initialize)
print("Swift ownership checks passed")

let failedPresentation = CustomerServicePresentationCompletion()
var failures: [Bool] = []
failedPresentation.onClosed = { failures.append($0) }
failedPresentation.presentationCompleted(isPresented: false)
failedPresentation.dismissed()
assert(failures == [false])

let actualDismiss = CustomerServicePresentationCompletion()
var closes: [Bool] = []
actualDismiss.onClosed = { closes.append($0) }
actualDismiss.presentationCompleted(isPresented: true)
assert(closes.isEmpty)
actualDismiss.dismissed()
actualDismiss.dismissed()
assert(closes == [true])

let resetDismiss = CustomerServicePresentationCompletion()
var resets: [Bool] = []
resetDismiss.onClosed = { resets.append($0) }
resetDismiss.cancelForReset()
assert(resets.isEmpty)
resetDismiss.dismissed()
assert(resets == [false])
print("Swift presentation settlement checks passed")

// 旧自有账号需要 reset；等待 UIKit 关闭期间外部接管 IM，清理后必须重新判定并拒绝覆盖。
let nextIdentity = CustomerServiceIdentity(appId: 100, userId: "next")
assert(customerServicePreparationAction(owned: target, actualUser: target.userId, target: nextIdentity) == .reset)
assert(customerServicePreparationAction(owned: nil, actualUser: "foreign-during-dismiss", target: nextIdentity) == .reject)
print("Foreign identity acquired during dismiss is rejected after reset")

assert(customerServicePreparationAction(owned: target, actualUser: "member", target: target, ownsRuntime: false) == .reuse)
assert(customerServicePreparationAction(owned: target, actualUser: "member", target: nextIdentity, ownsRuntime: false) == .reject)
assert(customerServicePreparationAction(owned: nil, actualUser: "member", target: target, ownsRuntime: false, configuredSdkAppId: 101) == .reject)
assert(customerServicePreparationAction(owned: nil, actualUser: "member", target: target, ownsRuntime: false, sdkReady: false) == .initialize)
assert(customerServicePreparationAction(owned: CustomerServiceIdentity(appId: 101, userId: "previous"), actualUser: "member", target: target, ownsRuntime: true, configuredSdkAppId: 101) == .reject)
assert(customerServicePreparationAction(owned: target, actualUser: "member", target: target, ownsRuntime: false, configuredSdkAppId: 101) == .reject)
print("Borrowed runtime never authorizes foreign replacement or mismatched SDK app-id")
