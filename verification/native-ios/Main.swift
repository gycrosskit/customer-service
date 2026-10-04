import GycCustomerServiceNative
import UIKit

@main
final class CustomerServiceConsumerApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.makeKeyAndVisible()
        self.window = window
        let client = GycTencentCustomerServiceClient.shared
        client.presenterResolver = { [weak presenter] in presenter }
        // 只链接真实 public API；设备操作需明确指定参数并人工提供真实凭据。
        if ProcessInfo.processInfo.arguments.contains("--exercise-customer-api") {
            client.prepare(appId: 0, userId: "consumer", userSig: "", nickname: "", avatar: "") { _ in }
            client.syncProfile(nickname: "", avatar: "") { _ in }
            client.open { _ in }
            client.reset { _ in }
        }
        return true
    }
}
