import Foundation
import UIKit

@objc(Application)
public final class Application: UIApplication {
}

@objc(AppDelegate)
public final class AppDelegate: NSObject, UIApplicationDelegate {
    public var window: UIWindow?
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        let window = UIWindow()
        self.window = window
        
        window.rootViewController = ViewController()
        window.makeKeyAndVisible()
        
        return true
    }
}
