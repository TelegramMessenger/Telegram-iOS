import Foundation
import UIKit

@objc(Application)
public final class Application: UIApplication {
}

/// **Scene-based on purpose.** A window created without a `UIWindowScene`, or one whose
/// `rootViewController` is assigned before it has a scene, leaves the keyboard mis-attached on
/// modern iOS — it stops rotating and its geometry cannot be trusted. Keyboard geometry is half of
/// what this harness exists to exercise, so the scene path is not optional here.
@objc(AppDelegate)
public final class AppDelegate: NSObject, UIApplicationDelegate {
    public static private(set) weak var harnessRootViewController: HarnessRootViewController?

    public func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    static func setRootViewController(_ value: HarnessRootViewController) {
        self.harnessRootViewController = value
    }
}

@objc(SceneDelegate)
public final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    public var window: UIWindow?

    public func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }
        let window = UIWindow(windowScene: windowScene)
        let root = HarnessRootViewController()
        AppDelegate.setRootViewController(root)
        window.rootViewController = root
        self.window = window
        window.makeKeyAndVisible()
    }
}
