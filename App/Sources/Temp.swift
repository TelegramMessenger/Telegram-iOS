import Foundation
import UIKit
import Emoji

@objc(AppDelegate1)
public final class AppDelegate: NSObject, UIApplicationDelegate {
    public var window: UIWindow?
    
	override init() {
		super.init()

		print("OK".isSingleEmoji)
	}
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = UIViewController()
        self.window?.rootViewController?.view.backgroundColor = .green
        self.window?.makeKeyAndVisible()
        return true
    }
}
