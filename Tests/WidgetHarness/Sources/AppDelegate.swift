import Foundation
import UIKit
import MessageWidgetStress

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
        // `-widget-stress measure|production`: widget-sandbox v0.3.0's stress kit instead of the chat; the run file goes
        // to the app's Documents and its path to the log.
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-widget-stress"), index + 1 < arguments.count, let pass = MessageWidgetStressRunner.Pass(rawValue: arguments[index + 1]),
           let root = Bundle.main.url(forResource: "WidgetStress", withExtension: "bundle").flatMap(Bundle.init(url:))?.resourceURL,
           let kit = try? MessageWidgetStressKit(root: root) {
            let stress = MessageWidgetStressViewController(kit: kit, options: MessageWidgetStressRunner.Options(pass: pass))
            stress.onFinish = { url in
                NSLog("WidgetHarness stress run file: %@", url.path)
            }
            window.rootViewController = stress
            self.window = window
            window.makeKeyAndVisible()
            return
        }
        let root = WidgetHarnessRootViewController()
        AppDelegate.setRootViewController(root)
        window.rootViewController = root
        self.window = window
        window.makeKeyAndVisible()
    }
}
