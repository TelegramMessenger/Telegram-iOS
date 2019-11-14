import Foundation
import UIKit
import GZip
import AsyncDisplayKit
import SSignalKit
import SwiftSignalKit
import ObjCRuntimeUtils
import UIKitRuntimeUtils

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
        
        let node = ASEditableTextNode()
        node.frame = CGRect(origin: CGPoint(x: 50.0, y: 50.0), size: CGSize(width: 100.0, height: 100.0))
        node.backgroundColor = .blue
        self.window?.rootViewController?.view.addSubnode(node)
        if #available(iOS 13.0, *) {
            self.window?.rootViewController?.overrideUserInterfaceStyle = .dark
        }
        
        let disposable = SSignal.single("abcd")?.start(next: { next in
            print("from signal: \(String(describing: next))")
        })
        disposable?.dispose()
        
        let disposable2 = Signal<Int, NoError>.single(1234).start(next: { next in
            print("from swift signal: \(next)")
        })
        disposable2.dispose()
        
        return true
    }
}
