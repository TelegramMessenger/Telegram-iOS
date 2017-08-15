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
    
    init(theme: TabBarControllerTheme, itemSelected: @escaping (Int) -> Void) {
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
