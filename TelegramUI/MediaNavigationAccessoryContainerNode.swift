import Foundation
import AsyncDisplayKit
import Display

final class MediaNavigationAccessoryContainerNode: ASDisplayNode {
    private let separatorNode: ASDisplayNode
    let headerNode: MediaNavigationAccessoryHeaderNode
    
    override init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.backgroundColor = UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0)
        
        self.headerNode = MediaNavigationAccessoryHeaderNode()
        
        super.init()
        
        self.backgroundColor = UIColor(red: 0.968626451, green: 0.968626451, blue: 0.968626451, alpha: 1.0)
        
        self.addSubnode(self.headerNode)
        self.addSubnode(self.separatorNode)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 36.0 - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.headerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: 36.0)))
        self.headerNode.updateLayout(size: size, transition: transition)
    }
}
