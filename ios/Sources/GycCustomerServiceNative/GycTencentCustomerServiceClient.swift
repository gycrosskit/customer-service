import Foundation
import TencentCloudAIDeskCustomer
import UIKit

/// 进程唯一原生适配器；宿主持有不可取消的会话操作与等待，不因页面重建创建第二份 SDK。
public final class GycTencentCustomerServiceClient {
    public static let shared = GycTencentCustomerServiceClient()
    public var presenterResolver: () -> UIViewController? = { nil }
    private var ownedIdentity: CustomerServiceIdentity?
    private var presentedController: CustomerServiceNavigationController?
    private init() {}

    public func prepare(
        appId: Int32,
        userId: String,
        userSig: String,
        nickname: String,
        avatar: String,
        completion: @escaping (Error?) -> Void
    ) {
        onMain {
            guard appId > 0, !userId.isEmpty, !userSig.isEmpty,
                  let manager = TencentCloudCustomerManager.shared() else {
                completion(self.failure("Invalid customer service configuration"))
                return
            }
            let identity = CustomerServiceIdentity(appId: appId, userId: userId)
            let initialize = {
                self.ownedIdentity = nil
                Self.configure(manager)
                manager.initWithProfile(appId, userID: userId, userSig: userSig, nickName: nickname, avatar: avatar) { error in
                    self.onMain {
                        if error == nil { self.ownedIdentity = identity }
                        completion(error)
                    }
                }
            }
            switch customerServicePreparationAction(owned: self.ownedIdentity, actualUser: self.sdkUser(manager), target: identity) {
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

    public func syncProfile(nickname: String, avatar: String, completion: @escaping (Error?) -> Void) {
        onMain {
            guard let manager = TencentCloudCustomerManager.shared(),
                  let owned = self.ownedIdentity, self.sdkUser(manager) == owned.userId else {
                completion(self.failure("Customer service identity is no longer owned"))
                return
            }
            manager.setSelfInfo(nickname, avatar: avatar) { success in
                self.onMain { completion(success ? nil : self.failure("Customer service profile sync failed")) }
            }
        }
    }

    /// 只包装厂商页面；真实 dismiss 后回调，照片等全屏子页面不视为关闭。
    public func open(completion: @escaping (Error?) -> Void) {
        onMain {
            guard let manager = TencentCloudCustomerManager.shared(),
                  let owned = self.ownedIdentity, self.sdkUser(manager) == owned.userId,
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

    public func reset(completion: @escaping (Error?) -> Void) {
        onMain {
            let cleanup = {
                // 未准备的根 reset 保持静默，不能在隐私准入前查询 SDK 单例。
                guard let owned = self.ownedIdentity else {
                    completion(nil)
                    return
                }
                guard let manager = TencentCloudCustomerManager.shared(),
                      self.sdkUser(manager) == owned.userId else {
                    self.ownedIdentity = nil
                    completion(nil)
                    return
                }
                manager.unInit { success in
                    self.onMain {
                        // 清理失败保留身份，让宿主的失败屏障可以显式重试。
                        if success { self.ownedIdentity = nil }
                        completion(success ? nil : self.failure("Customer service cleanup failed"))
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
