import UIKit

@objc(SceneDelegate) final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    /// True only for the single application-role scene that owns the app's window.
    /// Non-application scenes (e.g. an external display) get their own `SceneDelegate`
    /// instance, and must never drive app-wide life-cycle state.
    private var isPrimaryScene = false

    private var appDelegate: AppDelegate? {
        return UIApplication.shared.delegate as? AppDelegate
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard session.role == .windowApplication, let windowScene = scene as? UIWindowScene else {
            return
        }
        guard let appDelegate = self.appDelegate else {
            return
        }
        self.isPrimaryScene = true
        appDelegate.attach(scene: windowScene, connectionOptions: connectionOptions)
        self.window = appDelegate.window
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard self.isPrimaryScene else {
            return
        }
        self.appDelegate?.handleDidBecomeActive()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        guard self.isPrimaryScene else {
            return
        }
        self.appDelegate?.handleWillResignActive()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        guard self.isPrimaryScene else {
            return
        }
        self.appDelegate?.handleDidEnterBackground()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        guard self.isPrimaryScene else {
            return
        }
        self.appDelegate?.handleWillEnterForeground()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard self.isPrimaryScene else {
            return
        }
        guard let appDelegate = self.appDelegate else {
            return
        }
        for context in URLContexts {
            appDelegate.handleOpenURL(context.url)
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard self.isPrimaryScene else {
            return
        }
        self.appDelegate?.handleUserActivity(userActivity)
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        guard self.isPrimaryScene else {
            completionHandler(false)
            return
        }
        guard let appDelegate = self.appDelegate else {
            completionHandler(false)
            return
        }
        appDelegate.handleShortcutItem(shortcutItem, completionHandler: completionHandler)
    }

    @available(iOS 26.0, *)
    func preferredWindowingControlStyle(for windowScene: UIWindowScene) -> UIWindowScene.WindowingControlStyle {
        return .minimal
    }
}
