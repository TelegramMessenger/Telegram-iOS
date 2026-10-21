import Foundation
import UIKit

@objc(Application)
public final class Application: UIApplication {
}

/// Scene-based, as the composer harness is (a window without a scene mis-attaches the keyboard and rotation).
@objc(AppDelegate)
public final class AppDelegate: NSObject, UIApplicationDelegate {
    public static private(set) weak var widgetHarnessRootViewController: WidgetHarnessRootViewController?

    public func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    static func setRootViewController(_ value: WidgetHarnessRootViewController) {
        self.widgetHarnessRootViewController = value
    }
}

@objc(SceneDelegate)
public final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    public var window: UIWindow?

    public func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }
        let window = UIWindow(windowScene: windowScene)
        let root = WidgetHarnessRootViewController()
        AppDelegate.setRootViewController(root)
        window.rootViewController = root
        self.window = window
        window.makeKeyAndVisible()
    }
}
