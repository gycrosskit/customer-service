import Foundation
import ImSDK_Plus
import TencentCloudAIDeskCustomer
import TDeskCore
import UIKit

/// 进程唯一原生适配器。宿主与 Live 共用串行屏障，不因页面重建创建第二份 SDK。
/// 方法将操作和 completion 转到主线程；厂商操作不可取消，调用方结束等待不代表屏障可释放。
public final class GycTencentCustomerServiceClient {
    /// 进程共享实例；prepared 身份与 runtime 所有权由本实例持有。
    public static let shared = GycTencentCustomerServiceClient()
    /// 在主线程设置及调用，返回当前可展示的活动容器；未设置或容器忙时 open 失败。
    public var presenterResolver: () -> UIViewController? = { nil }
    private var ownedIdentity: CustomerServiceIdentity?
    private var ownsRuntime = false
    private var operationSerial = 0
    private var presentedController: CustomerServiceNavigationController?
    private init() {}

    /// 准备厂商 facade，同身份可复用，foreign runtime 不会被覆盖。completion 在主线程结算。
    /// appId 必须大于 0 且与共用 IM 一致，userId/userSig 不得为空白；不会 trim 实际传给厂商的值。
    /// nickname/avatar 允许为空，签名有效期与隐私准入由宿主负责；不要记录 userSig。
    public func prepare(
        appId: Int32,
        userId: String,
        userSig: String,
        nickname: String,
        avatar: String,
        completion: @escaping (Error?) -> Void
    ) {
        onMain {
            guard appId > 0, !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !userSig.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let manager = TencentCloudCustomerManager.shared() else {
                completion(self.failure("Invalid customer service configuration"))
                return
            }
            guard V2TIMManager.sharedInstance()?.getLoginStatus().rawValue != 2 else {
                completion(self.failure("Tencent runtime login is pending")); return
            }
            let identity = CustomerServiceIdentity(appId: appId, userId: userId)
            let actual = self.runtimeUser()
            let initialize = {
                self.operationSerial += 1
                let serial = self.operationSerial
                let previousIdentity = self.ownedIdentity
                let previouslyOwned = customerServiceOwnsActualIdentity(prepared: previousIdentity, ownsRuntime: self.ownsRuntime, actualUser: actual, configuredSdkAppId: TDeskLogin.getSdkAppID())
                let mayOwn = actual == nil || previouslyOwned
                self.ownedIdentity = nil; self.ownsRuntime = false
                Self.configure(manager)
                manager.initWithProfile(appId, userID: userId, userSig: userSig, nickName: nickname, avatar: avatar) { error in
                    self.onMain {
                        guard serial == self.operationSerial else { completion(self.failure("Tencent preparation superseded")); return }
                        if error == nil {
                            let configuredAppId = TDeskLogin.getSdkAppID()
                            guard self.runtimeUser() == userId, self.sdkUser(manager) == userId,
                                  configuredAppId <= 0 || configuredAppId == appId else {
                                if customerServiceOwnsActualIdentity(prepared: previousIdentity, ownsRuntime: previouslyOwned, actualUser: self.runtimeUser(), configuredSdkAppId: TDeskLogin.getSdkAppID()) {
                                    self.ownedIdentity = previousIdentity; self.ownsRuntime = true
                                }
                                completion(self.failure("Tencent identity changed while preparation was pending")); return
                            }
                            self.ownedIdentity = identity; self.ownsRuntime = mayOwn
                        } else if customerServiceOwnsActualIdentity(prepared: previousIdentity, ownsRuntime: previouslyOwned, actualUser: self.runtimeUser(), configuredSdkAppId: TDeskLogin.getSdkAppID()) {
                            self.ownedIdentity = previousIdentity; self.ownsRuntime = true
                        }
                        completion(error)
                    }
                }
            }
            switch customerServicePreparationAction(owned: self.ownedIdentity, actualUser: actual, target: identity, ownsRuntime: self.ownsRuntime, sdkReady: self.sdkUser(manager) == userId, configuredSdkAppId: TDeskLogin.getSdkAppID()) {
            case .reuse: completion(nil)
            case .reject: completion(self.failure("Refusing to replace a foreign Tencent identity"))
            case .initialize: initialize()
            case .reset:
                // unInit 会注销共享 IM；只有仍匹配自己旧身份的账号可以进入这条路径。
                self.reset { error in
                    if let error {
                        completion(error)
                    } else {
                        // 等待关闭期间共享 IM 可能换成其他所有者，不能沿用 reset 前的身份判断。
                        self.prepare(
                            appId: appId,
                            userId: userId,
                            userSig: userSig,
                            nickname: nickname,
                            avatar: avatar,
                            completion: completion
                        )
                    }
                }
            }
        }
    }

    /// 更新准备身份的昵称/头像（空值透传）；身份/AppId 失效或厂商失败通过主线程 completion 返回。
    public func syncProfile(nickname: String, avatar: String, completion: @escaping (Error?) -> Void) {
        onMain {
            let configuredAppId = TDeskLogin.getSdkAppID()
            guard let manager = TencentCloudCustomerManager.shared(),
                  let owned = self.ownedIdentity, self.runtimeUser() == owned.userId, self.sdkUser(manager) == owned.userId,
                  configuredAppId <= 0 || configuredAppId == owned.appId else {
                completion(self.failure("Customer service identity is no longer owned"))
                return
            }
            let serial = self.operationSerial
            manager.setSelfInfo(nickname, avatar: avatar) { success in
                self.onMain {
                    // 厂商回包期间共享身份可能被接管；只为仍准备的同一代次结算成功。
                    let actualAppId = TDeskLogin.getSdkAppID()
                    let valid = serial == self.operationSerial && self.ownedIdentity == owned &&
                        self.runtimeUser() == owned.userId && self.sdkUser(manager) == owned.userId &&
                        (actualAppId <= 0 || actualAppId == owned.appId)
                    completion(success && valid ? nil : self.failure("Customer service profile sync failed or identity changed"))
                }
            }
        }
    }

    /// 展示厂商页面；主线程 completion 只在真实 dismiss 或展示失败后结算一次。
    /// 照片等全屏子页面不视为关闭；重复打开失败，reset 关闭本组件页面后结算取消错误。
    public func open(completion: @escaping (Error?) -> Void) {
        onMain {
            let configuredAppId = TDeskLogin.getSdkAppID()
            guard let manager = TencentCloudCustomerManager.shared(),
                  let owned = self.ownedIdentity, self.runtimeUser() == owned.userId, self.sdkUser(manager) == owned.userId,
                  configuredAppId <= 0 || configuredAppId == owned.appId,
                  let presenter = self.presenterResolver(), presenter.presentedViewController == nil,
                  self.presentedController == nil, let chat = manager.getCustomerServiceViewController() else {
                completion(self.failure("Customer service presenter is unavailable"))
                return
            }
            let navigation = CustomerServiceNavigationController(rootViewController: chat)
            navigation.modalPresentationStyle = .fullScreen
            navigation.completion.onClosed = { [weak self, weak navigation] success in
                if self?.presentedController === navigation { self?.presentedController = nil }
                completion(success ? nil : NSError(
                    domain: "GycCustomerService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Customer service presentation was cancelled"]
                ))
            }
            self.presentedController = navigation
            presenter.present(navigation, animated: true) {
                navigation.completion.presentationCompleted(isPresented: navigation.presentingViewController != nil)
            }
        }
    }

    /// 先关闭本组件页面，再清本地身份；仅仍自有 runtime 才 unInit，借用身份不注销。
    /// 主线程 completion 等真实 callback；失败且仍自有时保留清理权限供宿主重试。
    public func reset(completion: @escaping (Error?) -> Void) {
        onMain {
            let cleanup = {
                self.operationSerial += 1
                let serial = self.operationSerial
                // 未准备的根 reset 保持静默，不能在隐私准入前查询 SDK 单例。
                guard let owned = self.ownedIdentity else {
                    completion(nil)
                    return
                }
                guard self.ownsRuntime else { self.ownedIdentity = nil; completion(nil); return }
                guard V2TIMManager.sharedInstance()?.getLoginStatus().rawValue != 2,
                      customerServiceOwnsActualIdentity(prepared: owned, ownsRuntime: self.ownsRuntime, actualUser: self.runtimeUser(), configuredSdkAppId: TDeskLogin.getSdkAppID()),
                      let manager = TencentCloudCustomerManager.shared() else {
                    self.ownedIdentity = nil; self.ownsRuntime = false
                    completion(nil)
                    return
                }
                manager.unInit { success in
                    self.onMain {
                        // 清理失败保留身份，让宿主的失败屏障可以显式重试。
                        guard serial == self.operationSerial else { completion(self.failure("Tencent cleanup superseded")); return }
                        if success || !customerServiceOwnsActualIdentity(prepared: owned, ownsRuntime: true, actualUser: self.runtimeUser(), configuredSdkAppId: TDeskLogin.getSdkAppID()) {
                            self.ownedIdentity = nil; self.ownsRuntime = false; completion(nil)
                        } else { completion(self.failure("Customer service cleanup failed")) }
                    }
                }
            }
            if let controller = self.presentedController {
                controller.completion.cancelForReset()
                self.dismiss(controller) {
                    controller.completion.dismissed()
                    cleanup()
                }
            } else { cleanup() }
        }
    }

    /// 等待展示/关闭转场并重新读取 UIKit 标志，不能把被取消的交互关闭当作已经完成。
    private func dismiss(_ controller: UIViewController, completion: @escaping () -> Void) {
        if controller.isBeingPresented || controller.isBeingDismissed,
           let transition = controller.transitionCoordinator,
           transition.animate(alongsideTransition: nil, completion: { _ in
               DispatchQueue.main.async { self.dismiss(controller, completion: completion) }
           }) { return }
        guard controller.presentingViewController != nil else { completion(); return }
        controller.dismiss(animated: false, completion: completion)
    }

    private func runtimeUser() -> String? {
        guard let user = V2TIMManager.sharedInstance()?.getLoginUser(), !user.isEmpty else { return nil }
        return user
    }

    private func sdkUser(_ manager: TencentCloudCustomerManager) -> String? {
        guard manager.isUserLoggedIn(), let user = manager.getLoginUser(), !user.isEmpty else { return nil }
        return user
    }

    private func onMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
    }

    private func failure(_ message: String) -> Error {
        NSError(domain: "GycCustomerService", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func configure(_ manager: TencentCloudCustomerManager) {
        manager.setShowAvatar(true)
        manager.setShowNickName(true)
        manager.setShowHumanService(true)
        manager.setShowLeaveQueue(true)
        manager.setShowServiceRating(true)
        manager.setShowEndHumanService(true)
    }
}

private final class CustomerServiceNavigationController: UINavigationController {
    let completion = CustomerServicePresentationCompletion()
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil { completion.dismissed() }
    }
}
