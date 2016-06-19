import Foundation
import UIKit

private class StatusBarHostWindowController: UIViewController {
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.default
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return false
    }
    
    override func shouldAutorotate() -> Bool {
        return true
    }
}

public class StatusBarHostWindow: UIWindow {
    public init() {
        super.init(frame: CGRect())
        
        self.windowLevel = 10000.0
        self.rootViewController = StatusBarHostWindowController()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
