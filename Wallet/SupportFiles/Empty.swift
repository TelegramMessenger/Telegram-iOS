import Foundation
import UIKit
import GZip

@objc(Application)
final class Application: UIApplication {
}

@objc(AppDelegate)
final class AppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = UIViewController()
        self.window?.rootViewController?.view.backgroundColor = .green
        self.window?.makeKeyAndVisible()
        
        if #available(iOS 13.0, *) {
            self.window?.rootViewController?.overrideUserInterfaceStyle = .dark
        }
        
        return true
    }
}
