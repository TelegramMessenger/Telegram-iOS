import Foundation
import UIKit
import AsyncDisplayKit

class NavigationBarTransitionContainer: ASDisplayNode {
    var progress: CGFloat = 0.0 {
        didSet {
            self.layout()
        }
    }
    
    let transition: NavigationTransition
    let topNavigationBar: NavigationBar
    let bottomNavigationBar: NavigationBar
    
    let topClippingNode: ASDisplayNode
    let bottomClippingNode: ASDisplayNode
    
    let topNavigationBarSupernode: ASDisplayNode?
    let bottomNavigationBarSupernode: ASDisplayNode?
    
    init(transition: NavigationTransition, topNavigationBar: NavigationBar, bottomNavigationBar: NavigationBar) {
        self.transition = transition
        
        self.topNavigationBar = topNavigationBar
        self.topNavigationBarSupernode = topNavigationBar.supernode
        
        self.bottomNavigationBar = bottomNavigationBar
        self.bottomNavigationBarSupernode = bottomNavigationBar.supernode
        
        self.topClippingNode = ASDisplayNode()
        self.topClippingNode.clipsToBounds = true
        self.bottomClippingNode = ASDisplayNode()
        self.bottomClippingNode.clipsToBounds = true
        
        super.init()
        
        self.topClippingNode.addSubnode(self.topNavigationBar)
        self.bottomClippingNode.addSubnode(self.bottomNavigationBar)
        
        self.addSubnode(self.bottomClippingNode)
        self.addSubnode(self.topClippingNode)
    }
    
    func complete() {
        self.topNavigationBarSupernode?.addSubnode(self.topNavigationBar)
        self.bottomNavigationBarSupernode?.addSubnode(self.bottomNavigationBar)
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        let position: CGFloat
        switch self.transition {
            case .Push:
                position = 1.0 - progress
            case .Pop:
                position = progress
        }
        
        let offset = floorToScreenPixels(size.width * position)

        self.topClippingNode.frame = CGRect(origin: CGPoint(x: offset, y: 0.0), size: size)
        
        self.bottomClippingNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: offset, height: size.height))
    }
}
