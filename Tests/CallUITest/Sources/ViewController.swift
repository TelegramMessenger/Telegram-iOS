import Foundation
import UIKit
import CallScreen

public final class ViewController: UIViewController {    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        let privateCallScreen = PrivateCallScreen(frame: CGRect())
        self.view.addSubview(privateCallScreen)
        
        privateCallScreen.frame = self.view.bounds
        privateCallScreen.update(size: self.view.bounds.size, insets: UIEdgeInsets(top: 44.0, left: 0.0, bottom: 0.0, right: 0.0))
        
        let context = MetalContext.shared
        self.view.layer.addSublayer(context.rootLayer)
        context.rootLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -101.0), size: CGSize(width: 100.0, height: 100.0))
    }
}
