import Foundation
import AsyncDisplayKit

final class TabBarControllerNode: ASDisplayNode {
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
        
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
        
        self.addSubnode(self.tabBarNode)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let update = {
            self.tabBarNode.frame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - layout.insets(options: []).bottom - 49.0), size: CGSize(width: layout.size.width, height: 49.0))
            self.tabBarNode.layout()
        }
        
        switch transition {
            case .immediate:
                update()
            case let .animated(duration, curve):
                update()
        }
    }
}
