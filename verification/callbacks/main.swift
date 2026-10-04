import Foundation
import ImSDK_Plus
import TencentCloudAIDeskCustomer
import TDeskCore
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
