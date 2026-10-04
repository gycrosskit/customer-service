import Foundation

struct CustomerServiceIdentity: Equatable {
    let appId: Int32
    let userId: String
}

enum CustomerServicePreparationAction { case reuse, initialize, reset, reject }

func customerServicePreparationAction(owned: CustomerServiceIdentity?, actualUser: String?, target: CustomerServiceIdentity, ownsRuntime: Bool = true, sdkReady: Bool = true, configuredSdkAppId: Int32 = 0) -> CustomerServicePreparationAction {
    if let actualUser, actualUser != target.userId && !customerServiceOwnsActualIdentity(prepared: owned, ownsRuntime: ownsRuntime, actualUser: actualUser, configuredSdkAppId: configuredSdkAppId) { return .reject }
    let configured = configuredSdkAppId > 0 ? configuredSdkAppId : (owned?.appId ?? 0)
    if actualUser != nil, configured > 0, configured != target.appId, !customerServiceOwnsActualIdentity(prepared: owned, ownsRuntime: ownsRuntime, actualUser: actualUser, configuredSdkAppId: configuredSdkAppId) { return .reject }
    if let owned, customerServiceOwnsActualIdentity(prepared: owned, ownsRuntime: ownsRuntime, actualUser: actualUser, configuredSdkAppId: configured), owned != target { return .reset }
    if owned == target && actualUser == target.userId && sdkReady { return .reuse }
    return .initialize
}

func customerServiceOwnsActualIdentity(prepared: CustomerServiceIdentity?, ownsRuntime: Bool, actualUser: String?, configuredSdkAppId: Int32 = 0) -> Bool {
    ownsRuntime && prepared != nil && actualUser == prepared?.userId &&
        (configuredSdkAppId <= 0 || configuredSdkAppId == prepared?.appId)
}
