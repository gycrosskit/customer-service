import UIKit
public final class TencentCloudCustomerManager {
    public static let instance = TencentCloudCustomerManager()
    public static func shared() -> TencentCloudCustomerManager? { instance }
    public var facadeUser: String?
    public var initializations: [(Error?) -> Void] = []
    public var cleanups: [(Bool) -> Void] = []
    public var profileUpdates = 0
    public var chatRequests = 0
    public func isUserLoggedIn() -> Bool { facadeUser != nil }
    public func getLoginUser() -> String? { facadeUser }
    public func initWithProfile(_ appId: Int32, userID: String, userSig: String, nickName: String, avatar: String, completion: @escaping (Error?) -> Void) { initializations.append(completion) }
    public func unInit(completion: @escaping (Bool) -> Void) { cleanups.append(completion) }
    public func setSelfInfo(_ nickname: String, avatar: String, completion: (Bool) -> Void) { profileUpdates += 1; completion(true) }
    public func getCustomerServiceViewController() -> UIViewController? { chatRequests += 1; return UIViewController() }
    public func setShowAvatar(_ value: Bool) {}
    public func setShowNickName(_ value: Bool) {}
    public func setShowHumanService(_ value: Bool) {}
    public func setShowLeaveQueue(_ value: Bool) {}
    public func setShowServiceRating(_ value: Bool) {}
    public func setShowEndHumanService(_ value: Bool) {}
}
