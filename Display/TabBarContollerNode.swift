import Foundation
import AsyncDisplayKit

class TabBarControllerNode: ASDisplayNode {
    let tabBarNode: TabBarNode
    
    var currentControllerView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            
            if let currentControllerView = self.currentControllerView {
                self.view.insertSubview(currentControllerView, at: 0)
            }
        }
    }
    
    init(itemSelected: (Int) -> Void) {
        self.tabBarNode = TabBarNode(itemSelected: itemSelected)
        
        super.init()
        
        self.addSubnode(self.tabBarNode)
    }
    
    func updateLayout(_ layout: ViewControllerLayout, previousLayout: ViewControllerLayout?, duration: Double, curve: UInt) {
        let update = {
            self.tabBarNode.frame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - layout.insets.bottom - 49.0), size: CGSize(width: layout.size.width, height: 49.0))
            self.tabBarNode.layout()
        }
        
        if duration > DBL_EPSILON {
            UIView.animate(withDuration: duration, delay: 0.0, options: UIViewAnimationOptions(rawValue: curve << 7), animations: update, completion: nil)
        } else {
            update()
        }
    }
}
