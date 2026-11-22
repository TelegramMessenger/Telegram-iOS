import UIKit
import Display

// A bare app hosting `DisplayAccessibilityTests`. The tests need a running UIApplication: without one,
// `CADisplayLink(target:selector:)` returns nil and `ListViewImpl.init` traps. Class names match
// `//Tests/Common:Main`'s `UIApplicationMain(…, @"Application", @"AppDelegate")`. Display is imported so the host
// links it (and AsyncDisplayKit) and the test bundle uses the host's copy.

private let linkDisplay: Any.Type = ListViewImpl.self

@objc(Application)
final class Application: UIApplication {
}

@objc(AppDelegate)
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
