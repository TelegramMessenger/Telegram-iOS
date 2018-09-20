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
    
    init(theme: TabBarControllerTheme, itemSelected: @escaping (Int, Bool) -> Void) {
        self.tabBarNode = TabBarNode(theme: theme, itemSelected: itemSelected)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = theme.backgroundColor
        
        self.addSubnode(self.tabBarNode)
    }
    
    func updateTheme(_ theme: TabBarControllerTheme) {
        self.backgroundColor = theme.backgroundColor
        
        self.tabBarNode.updateTheme(theme)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let update = {
            let tabBarHeight: CGFloat
            let bottomInset: CGFloat = layout.insets(options: []).bottom
            if !layout.safeInsets.left.isZero {
                tabBarHeight = 34.0 + bottomInset
            } else {
                tabBarHeight = 49.0 + bottomInset
            }
            
            transition.updateFrame(node: self.tabBarNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - tabBarHeight), size: CGSize(width: layout.size.width, height: tabBarHeight)))
            self.tabBarNode.updateLayout(size: layout.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: bottomInset, transition: transition)
        }
        
        switch transition {
            case .immediate:
                update()
            case .animated:
                update()
        }
    }
}
