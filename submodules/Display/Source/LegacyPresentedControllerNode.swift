import Foundation
import UIKit
import AsyncDisplayKit

final class LegacyPresentedControllerNode: ASDisplayNode {
    private var containerLayout: ContainerViewLayout?
    
    var controllerView: UIView? {
        didSet {
            if let controllerView = self.controllerView, let containerLayout = self.containerLayout {
                controllerView.frame = CGRect(origin: CGPoint(), size: containerLayout.size)
            }
        }
    }
    
    override init() {
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = layout
        if let controllerView = self.controllerView {
            controllerView.frame = CGRect(origin: CGPoint(), size: layout.size)
        }
    }
    
    func animateModalIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateModalOut(completion: @escaping () -> Void) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
}
