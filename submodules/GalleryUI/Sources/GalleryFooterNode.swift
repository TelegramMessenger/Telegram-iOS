import Foundation
import UIKit
import AsyncDisplayKit
import Display

public final class GalleryFooterNode: ASDisplayNode {
    private let backgroundNode: ASDisplayNode
    
    private var currentFooterContentNode: GalleryFooterContentNode?
    private var currentLayout: (ContainerViewLayout, CGFloat)?
    
    private let controllerInteraction: GalleryControllerInteraction
    
    public init(controllerInteraction: GalleryControllerInteraction) {
        self.controllerInteraction = controllerInteraction
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = UIColor(white: 0.0, alpha: 0.6)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
    }
    
    public func updateLayout(_ layout: ContainerViewLayout, footerContentNode: GalleryFooterContentNode?, thumbnailPanelHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.currentLayout = (layout, thumbnailPanelHeight)
        let cleanInsets = layout.insets(options: [])
        
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
                    if let strongSelf = self, let (currentLayout, currentThumbnailPanelHeight) = strongSelf.currentLayout {
                        strongSelf.updateLayout(currentLayout, footerContentNode: strongSelf.currentFooterContentNode, thumbnailPanelHeight: currentThumbnailPanelHeight, transition: transition)
                    }
                }
                self.addSubnode(footerContentNode)
            }
        }
        
        var backgroundHeight: CGFloat = 0.0
        if let footerContentNode = self.currentFooterContentNode {
            backgroundHeight = footerContentNode.updateLayout(size: layout.size, metrics: layout.metrics, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: cleanInsets.bottom, contentInset: thumbnailPanelHeight, transition: transition)
            transition.updateFrame(node: footerContentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - backgroundHeight), size: CGSize(width: layout.size.width, height: backgroundHeight)))
            if let removeCurrentFooterContentNode = removeCurrentFooterContentNode {
                let contentTransition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                footerContentNode.animateIn(fromHeight: removeCurrentFooterContentNode.bounds.height, previousContentNode: removeCurrentFooterContentNode, transition: contentTransition)
                removeCurrentFooterContentNode.animateOut(toHeight: backgroundHeight, nextContentNode: footerContentNode, transition: contentTransition, completion: { [weak self, weak removeCurrentFooterContentNode] in
                    if let strongSelf = self, let removeCurrentFooterContentNode = removeCurrentFooterContentNode, removeCurrentFooterContentNode !== strongSelf.currentFooterContentNode {
                        removeCurrentFooterContentNode.removeFromSupernode()
                    }
                })
                contentTransition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - backgroundHeight), size: CGSize(width: layout.size.width, height: backgroundHeight)))
            } else {
                transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - backgroundHeight), size: CGSize(width: layout.size.width, height: backgroundHeight)))
            }
        } else {
            if let removeCurrentFooterContentNode = removeCurrentFooterContentNode {
                removeCurrentFooterContentNode.removeFromSupernode()
            }
            
            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - backgroundHeight), size: CGSize(width: layout.size.width, height: backgroundHeight)))
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.backgroundNode.frame.contains(point) {
            return nil
        }
        let result = super.hitTest(point, with: event)
        return result
    }
}
