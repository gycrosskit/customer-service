import Foundation
import ImSDK_Plus
import TencentCloudAIDeskCustomer
import TDeskCore
import UIKit
let client = GycTencentCustomerServiceClient.shared
let im = V2TIMManager.instance
let sdk = TencentCloudCustomerManager.instance
func runtime(_ user: String?, ready: Bool = true) {
    im.actualUser = user; im.actualStatus = user == nil ? .loggedOut : .loggedIn
    sdk.facadeUser = ready ? user : nil
}
var result: Error?
func prepare(_ user: String = "member") {
    result = nil
    client.prepare(appId: 100, userId: user, userSig: "mock-signature", nickname: "", avatar: "") { result = $0 }
}
func finish(_ error: Error? = nil) { sdk.initializations.removeFirst()(error) }
// 自有登录成功；facade不就绪的错误成功回调保留旧清理权限。
runtime(nil); prepare(); runtime("member"); finish(); assert(result == nil)
runtime("member", ready: false); prepare(); finish(); assert(result != nil)
client.reset { result = $0 }; assert(sdk.cleanups.count == 1)
sdk.cleanups.removeFirst()(false); assert(result != nil)
client.reset { result = $0 }; assert(sdk.cleanups.count == 1)
sdk.cleanups.removeFirst()(true); assert(result == nil)
// 已有同用户runtime借用，reset不能unInit。
runtime("member", ready: false); prepare(); runtime("member"); finish(); assert(result == nil)
client.reset { result = $0 }; assert(result == nil && sdk.cleanups.isEmpty)
// reset在pending initialize之前递增代次，迟回调不能取得注销权限。
runtime(nil); prepare(); client.reset { result = $0 }
runtime("member"); finish(); assert(result != nil)
client.reset { result = $0 }; assert(result == nil && sdk.cleanups.isEmpty)
// 自有old runtime再准备失败、foreign接管，不恢复或清理foreign身份。
runtime(nil); prepare(); runtime("member"); finish()
runtime("member", ready: false); prepare(); runtime("foreign"); finish(NSError(domain: "mock", code: -1))
client.reset { result = $0 }; assert(result == nil && sdk.cleanups.isEmpty)
// 旧 unInit 回调不能清除较新本地代次，并保留仍匹配的cleanup以重试。
runtime(nil); prepare(); runtime("member"); finish()
var oldCleanup: Error?; var newCleanup: Error?
client.reset { oldCleanup = $0 }; client.reset { newCleanup = $0 }
assert(sdk.cleanups.count == 2)
sdk.cleanups.removeFirst()(true); assert(oldCleanup != nil)
sdk.cleanups.removeFirst()(false); assert(newCleanup != nil)
client.reset { result = $0 }; assert(sdk.cleanups.count == 1)
sdk.cleanups.removeFirst()(true)
print("Customer production callback contracts passed: own/borrow, invalid success recovery, late init/unInit, foreign and cleanup retry")

// 已知Desk AppId变化且user相同，不得把旧权限视为新的self owner。
runtime(nil); TDeskLogin.sdkAppID = 100; prepare(); runtime("member"); finish()
TDeskLogin.sdkAppID = 101; prepare(); assert(result != nil && sdk.initializations.isEmpty)
client.reset { result = $0 }; assert(result == nil && sdk.cleanups.isEmpty)
TDeskLogin.sdkAppID = 100; runtime(nil); prepare(); runtime("member"); finish()
runtime("member", ready: false); prepare(); TDeskLogin.sdkAppID = 101
finish(NSError(domain: "mock", code: -1)); client.reset { result = $0 }
assert(result == nil && sdk.cleanups.isEmpty)
TDeskLogin.sdkAppID = 100
print("Customer same-user foreign SDKAppID preparation/cleanup/failure guards passed")

// 已准备身份被另一AppId的同名用户接管，资料和页面操作均不能落到foreign runtime。
runtime(nil); prepare(); runtime("member"); finish()
let presenter = UIViewController()
client.presenterResolver = { presenter }
let updates = sdk.profileUpdates
let pages = sdk.chatRequests
TDeskLogin.sdkAppID = 101
client.syncProfile(nickname: "new", avatar: "avatar") { result = $0 }
assert(result != nil && sdk.profileUpdates == updates)
client.open { result = $0 }
assert(result != nil && sdk.chatRequests == pages && presenter.presentedViewController == nil)
client.reset { result = $0 }; assert(result == nil && sdk.cleanups.isEmpty)

// borrow拥有使用权限但没有注销权限；未知getter保持原兼容行为。
for appId: Int32 in [100, 0] {
    TDeskLogin.sdkAppID = 100; runtime("member", ready: false); prepare(); runtime("member"); finish()
    TDeskLogin.sdkAppID = appId
    let updatesBefore = sdk.profileUpdates
    let pagesBefore = sdk.chatRequests
    client.syncProfile(nickname: "borrow", avatar: "avatar") { result = $0 }
    assert(result == nil && sdk.profileUpdates == updatesBefore + 1)
    var openCompleted = false
    client.open { error in openCompleted = true; assert(error != nil) }
    assert(sdk.chatRequests == pagesBefore + 1 && presenter.presentedViewController != nil && !openCompleted)
    client.reset { result = $0 }
    assert(result == nil && sdk.cleanups.isEmpty && presenter.presentedViewController == nil && openCompleted)
}
TDeskLogin.sdkAppID = 100
print("Customer profile/page AppId guards passed, including borrowed and unknown-AppId runtime")

// 空白凭据不得进入厂商初始化，保持与 Android 的输入边界一致。
let invalidProfiles: [(Int32, String, String)] = [(0, "member", "sig"), (100, " \t", "sig"), (100, "member", "\n")]
for (appId, user, signature) in invalidProfiles {
    let calls = sdk.initializations.count
    var completed = false
    client.prepare(appId: appId, userId: user, userSig: signature, nickname: "", avatar: "") { error in
        completed = true; assert(error != nil)
    }
    assert(completed && sdk.initializations.count == calls)
}
im.actualStatus = .loggingIn
prepare(); assert(result != nil && sdk.initializations.isEmpty)
im.actualStatus = .loggedOut

// 展示后的全屏子页不会结算 open，重复打开也不覆盖原 completion。
runtime("member", ready: false); prepare(); runtime("member"); finish()
var closedCount = 0
client.open { error in closedCount += 1; assert(error != nil) }
let navigation = presenter.presentedViewController!
navigation.viewDidDisappear(false)
assert(closedCount == 0)
client.open { error in assert(error != nil) }
assert(closedCount == 0 && presenter.presentedViewController === navigation)
client.reset { result = $0 }
assert(result == nil && closedCount == 1 && sdk.cleanups.isEmpty)
navigation.viewDidDisappear(false)
assert(closedCount == 1)
print("Customer invalid-input, pending-login and full-screen child lifecycle contracts passed")
