import Foundation
public enum ModalStyle { case fullScreen }
public final class Transition {
    public func animate(alongsideTransition: ((Int) -> Void)?, completion: ((Int) -> Void)?) -> Bool { false }
}
open class UIViewController: NSObject {
    public var isBeingPresented = false
    public var isBeingDismissed = false
    public var transitionCoordinator: Transition?
    public var presentingViewController: UIViewController?
    public var presentedViewController: UIViewController?
    public var modalPresentationStyle: ModalStyle = .fullScreen
    open func viewDidDisappear(_ animated: Bool) {}
    public func present(_ controller: UIViewController, animated: Bool, completion: (() -> Void)?) {
        presentedViewController = controller; controller.presentingViewController = self; completion?()
    }
    public func dismiss(animated: Bool, completion: (() -> Void)?) {
        presentingViewController?.presentedViewController = nil; presentingViewController = nil; completion?()
    }
}
open class UINavigationController: UIViewController { public init(rootViewController: UIViewController) { super.init() } }
