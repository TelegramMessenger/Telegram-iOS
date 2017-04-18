import Foundation
import AsyncDisplayKit
import Display

final class GalleryFooterNode: ASDisplayNode {
    private let backgroundNode: ASDisplayNode
    
    private var currentFooterContentNode: GalleryFooterContentNode?
    private var currentLayout: ContainerViewLayout?
    
    private let controllerInteraction: GalleryControllerInteraction
    
    init(controllerInteraction: GalleryControllerInteraction) {
        self.controllerInteraction = controllerInteraction
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = UIColor(white: 0.0, alpha: 0.6)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
    }
    
    func updateLayout(_ layout: ContainerViewLayout, footerContentNode: GalleryFooterContentNode?, transition: ContainedViewLayoutTransition) {
        self.currentLayout = layout
        
        var removeCurrentFooterContentNode: GalleryFooterContentNode?
        if self.currentFooterContentNode !== footerContentNode {
            if let currentFooterContentNode = self.currentFooterContentNode {
                currentFooterContentNode.requestLayout = nil
                removeCurrentFooterContentNode = currentFooterContentNode
            }
            self.currentFooterContentNode = footerContentNode
            if let footerContentNode = footerContentNode {
                footerContentNode.controllerInteraction = self.controllerInteraction
                footerContentNode.requestLayout = { [weak self] transition in
                    if let strongSelf = self, let currentLayout = strongSelf.currentLayout {
                        strongSelf.updateLayout(currentLayout, footerContentNode: strongSelf.currentFooterContentNode, transition: transition)
                    }
                }
                self.addSubnode(footerContentNode)
            }
        }
        
        if let removeCurrentFooterContentNode = removeCurrentFooterContentNode {
            removeCurrentFooterContentNode.removeFromSupernode()
        }
        
        var backgroundHeight: CGFloat = 0.0
        if let footerContentNode = self.currentFooterContentNode {
            backgroundHeight = footerContentNode.updateLayout(width: layout.size.width, transition: transition)
            transition.updateFrame(node: footerContentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - backgroundHeight), size: CGSize(width: layout.size.width, height: backgroundHeight)))
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - backgroundHeight), size: CGSize(width: layout.size.width, height: backgroundHeight)))
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.backgroundNode.frame.contains(point) {
            return nil
        }
        let result = super.hitTest(point, with: event)
        return result
    }
}
