import Foundation
import UIKit
import MetalEngine
import Display
import CallScreen
import ComponentFlow

public final class ViewController: UIViewController {
    private var callScreenView: PrivateCallScreen?
    private var callState: PrivateCallScreen.State = PrivateCallScreen.State(
        lifecycleState: .connecting,
        name: "Emma Walters",
        avatarImage: UIImage(named: "test")
    )
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.layer.addSublayer(MetalEngine.shared.rootLayer)
        MetalEngine.shared.rootLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -101.0), size: CGSize(width: 100.0, height: 100.0))
        
        self.view.backgroundColor = .black
        
        SharedDisplayLinkDriver.shared.updateForegroundState(true)
        
        let callScreenView = PrivateCallScreen(frame: self.view.bounds)
        self.callScreenView = callScreenView
        self.view.addSubview(callScreenView)
        
        self.update(size: self.view.bounds.size, transition: .immediate)
    }
    
    private func update(size: CGSize, transition: Transition) {
        guard let callScreenView = self.callScreenView else {
            return
        }
        
        transition.setFrame(view: callScreenView, frame: CGRect(origin: CGPoint(), size: size))
        let insets: UIEdgeInsets
        if size.width < size.height {
            insets = UIEdgeInsets(top: 44.0, left: 0.0, bottom: 0.0, right: 0.0)
        } else {
            insets = UIEdgeInsets(top: 0.0, left: 44.0, bottom: 0.0, right: 44.0)
        }
        callScreenView.update(size: size, insets: insets, screenCornerRadius: 55.0, state: self.callState, transition: transition)
    }
    
    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.update(size: size, transition: .easeInOut(duration: 0.3))
    }
}
