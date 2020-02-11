import Foundation
import UIKit
import AsyncDisplayKit
import Display

public final class GalleryFooterNode: ASDisplayNode {
    private let backgroundNode: ASDisplayNode
    
    private var currentFooterContentNode: GalleryFooterContentNode?
    private var currentOverlayContentNode: GalleryOverlayContentNode?
    private var currentLayout: (ContainerViewLayout, CGFloat)?
    
    private let controllerInteraction: GalleryControllerInteraction
    
    public init(controllerInteraction: GalleryControllerInteraction) {
        self.controllerInteraction = controllerInteraction
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = UIColor(white: 0.0, alpha: 0.6)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
    }
    
    private var visibilityAlpha: CGFloat = 1.0
    public func setVisibilityAlpha(_ alpha: CGFloat) {
        self.visibilityAlpha = alpha
        self.backgroundNode.alpha = alpha
        self.currentFooterContentNode?.alpha = alpha
        self.currentOverlayContentNode?.setVisibilityAlpha(alpha)
    }
    
    public func updateLayout(_ layout: ContainerViewLayout, footerContentNode: GalleryFooterContentNode?, overlayContentNode: GalleryOverlayContentNode?, thumbnailPanelHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.currentLayout = (layout, thumbnailPanelHeight)
        let cleanInsets = layout.insets(options: [])
        
        var dismissedCurrentFooterContentNode: GalleryFooterContentNode?
        if self.currentFooterContentNode !== footerContentNode {
            if let currentFooterContentNode = self.currentFooterContentNode {
                currentFooterContentNode.requestLayout = nil
                dismissedCurrentFooterContentNode = currentFooterContentNode
            }
            self.currentFooterContentNode = footerContentNode
            if let footerContentNode = footerContentNode {
                footerContentNode.alpha = self.visibilityAlpha
                footerContentNode.controllerInteraction = self.controllerInteraction
                footerContentNode.requestLayout = { [weak self] transition in
                    if let strongSelf = self, let (currentLayout, currentThumbnailPanelHeight) = strongSelf.currentLayout {
                        strongSelf.updateLayout(currentLayout, footerContentNode: strongSelf.currentFooterContentNode, overlayContentNode: strongSelf.currentOverlayContentNode, thumbnailPanelHeight: currentThumbnailPanelHeight, transition: transition)
                    }
                }
                self.addSubnode(footerContentNode)
            }
        }
        
        var dismissedCurrentOverlayContentNode: GalleryOverlayContentNode?
        if self.currentOverlayContentNode !== overlayContentNode {
            if let currentOverlayContentNode = self.currentOverlayContentNode {
                dismissedCurrentOverlayContentNode = currentOverlayContentNode
            }
            self.currentOverlayContentNode = overlayContentNode
            if let overlayContentNode = overlayContentNode {
                overlayContentNode.setVisibilityAlpha(self.visibilityAlpha)
                self.addSubnode(overlayContentNode)
            }
        }
        
        var backgroundHeight: CGFloat = 0.0
        if let footerContentNode = self.currentFooterContentNode {
            backgroundHeight = footerContentNode.updateLayout(size: layout.size, metrics: layout.metrics, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: cleanInsets.bottom, contentInset: thumbnailPanelHeight, transition: transition)
            transition.updateFrame(node: footerContentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - backgroundHeight), size: CGSize(width: layout.size.width, height: backgroundHeight)))
            if let dismissedCurrentFooterContentNode = dismissedCurrentFooterContentNode {
                let contentTransition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                footerContentNode.animateIn(fromHeight: dismissedCurrentFooterContentNode.bounds.height, previousContentNode: dismissedCurrentFooterContentNode, transition: contentTransition)
                dismissedCurrentFooterContentNode.animateOut(toHeight: backgroundHeight, nextContentNode: footerContentNode, transition: contentTransition, completion: { [weak self, weak dismissedCurrentFooterContentNode] in
                    if let strongSelf = self, let dismissedCurrentFooterContentNode = dismissedCurrentFooterContentNode, dismissedCurrentFooterContentNode !== strongSelf.currentFooterContentNode {
                        dismissedCurrentFooterContentNode.removeFromSupernode()
                    }
                })
                contentTransition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - backgroundHeight), size: CGSize(width: layout.size.width, height: backgroundHeight)))
            } else {
                transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - backgroundHeight), size: CGSize(width: layout.size.width, height: backgroundHeight)))
            }
        } else {
            if let dismissedCurrentFooterContentNode = dismissedCurrentFooterContentNode {
                dismissedCurrentFooterContentNode.removeFromSupernode()
            }
            
            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - backgroundHeight), size: CGSize(width: layout.size.width, height: backgroundHeight)))
        }
        
        let contentTransition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
        if let overlayContentNode = self.currentOverlayContentNode {
            overlayContentNode.updateLayout(size: layout.size, metrics: layout.metrics, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: backgroundHeight, transition: transition)
            transition.updateFrame(node: overlayContentNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            
            overlayContentNode.animateIn(previousContentNode: dismissedCurrentOverlayContentNode, transition: contentTransition)
            if let dismissedCurrentOverlayContentNode = dismissedCurrentOverlayContentNode {
                dismissedCurrentOverlayContentNode.animateOut(nextContentNode: overlayContentNode, transition: contentTransition, completion: { [weak self, weak dismissedCurrentOverlayContentNode] in
                    if let strongSelf = self, let dismissedCurrentOverlayContentNode = dismissedCurrentOverlayContentNode, dismissedCurrentOverlayContentNode !== strongSelf.currentOverlayContentNode {
                        dismissedCurrentOverlayContentNode.removeFromSupernode()
                    }
                })
            }
        } else {
            if let dismissedCurrentOverlayContentNode = dismissedCurrentOverlayContentNode {
                dismissedCurrentOverlayContentNode.animateOut(nextContentNode: overlayContentNode, transition: contentTransition, completion: { [weak self, weak dismissedCurrentOverlayContentNode] in
                    if let strongSelf = self, let dismissedCurrentOverlayContentNode = dismissedCurrentOverlayContentNode, dismissedCurrentOverlayContentNode !== strongSelf.currentOverlayContentNode {
                        dismissedCurrentOverlayContentNode.removeFromSupernode()
                    }
                })
            }
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let overlayResult = self.currentOverlayContentNode?.hitTest(point, with: event) {
            return overlayResult
        }
        if !self.backgroundNode.frame.contains(point) || self.visibilityAlpha < 1.0 {
            return nil
        }
        let result = super.hitTest(point, with: event)
        return result
    }
}
