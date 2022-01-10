import Foundation
import UIKit
import AsyncDisplayKit
import Display

public final class GalleryFooterNode: ASDisplayNode {
    private let backgroundNode: ASDisplayNode
    
    private var currentThumbnailPanelHeight: CGFloat?
    private var currentFooterContentNode: GalleryFooterContentNode?
    private var currentOverlayContentNode: GalleryOverlayContentNode?
    private var currentLayout: (ContainerViewLayout, CGFloat, CGFloat, Bool)?
    
    private let controllerInteraction: GalleryControllerInteraction
    
    public init(controllerInteraction: GalleryControllerInteraction) {
        self.controllerInteraction = controllerInteraction
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = UIColor(white: 0.0, alpha: 0.6)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
    }
    
    private var visibilityAlpha: CGFloat = 1.0
    public func setVisibilityAlpha(_ alpha: CGFloat, animated: Bool) {
        self.visibilityAlpha = alpha
        self.backgroundNode.alpha = alpha
        self.currentFooterContentNode?.setVisibilityAlpha(alpha, animated: true)
        self.currentOverlayContentNode?.setVisibilityAlpha(alpha)
    }
    
    public func updateLayout(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, footerContentNode: GalleryFooterContentNode?, overlayContentNode: GalleryOverlayContentNode?, thumbnailPanelHeight: CGFloat, isHidden: Bool, transition: ContainedViewLayoutTransition) {
        self.currentLayout = (layout, navigationBarHeight, thumbnailPanelHeight, isHidden)
        let cleanInsets = layout.insets(options: [])
        
        var dismissedCurrentFooterContentNode: GalleryFooterContentNode?
        if self.currentFooterContentNode !== footerContentNode {
            if let currentFooterContentNode = self.currentFooterContentNode {
                currentFooterContentNode.requestLayout = nil
                dismissedCurrentFooterContentNode = currentFooterContentNode
            }
            self.currentThumbnailPanelHeight = thumbnailPanelHeight
            self.currentFooterContentNode = footerContentNode
            if let footerContentNode = footerContentNode {
                footerContentNode.setVisibilityAlpha(self.visibilityAlpha, animated: transition.isAnimated)
                footerContentNode.controllerInteraction = self.controllerInteraction
                footerContentNode.requestLayout = { [weak self] transition in
                    if let strongSelf = self, let (currentLayout, navigationBarHeight, currentThumbnailPanelHeight, isHidden) = strongSelf.currentLayout {
                        strongSelf.updateLayout(currentLayout, navigationBarHeight: navigationBarHeight, footerContentNode: strongSelf.currentFooterContentNode, overlayContentNode: strongSelf.currentOverlayContentNode, thumbnailPanelHeight: currentThumbnailPanelHeight, isHidden: isHidden, transition: transition)
                    }
                }
                self.addSubnode(footerContentNode)
            }
        }
        
        var animateOverlayIn = false
        var dismissedCurrentOverlayContentNode: GalleryOverlayContentNode?
        if self.currentOverlayContentNode !== overlayContentNode {
            if let currentOverlayContentNode = self.currentOverlayContentNode {
                dismissedCurrentOverlayContentNode = currentOverlayContentNode
            }
            self.currentOverlayContentNode = overlayContentNode
            animateOverlayIn = true
            if let overlayContentNode = overlayContentNode {
                overlayContentNode.setVisibilityAlpha(self.visibilityAlpha)
                self.addSubnode(overlayContentNode)
            }
        }
        
        var effectiveThumbnailPanelHeight = self.currentThumbnailPanelHeight ?? thumbnailPanelHeight
        if layout.size.width > layout.size.height {
            effectiveThumbnailPanelHeight = 0.0
        }
        var backgroundHeight: CGFloat = 0.0
        let verticalOffset: CGFloat = isHidden ? (layout.size.width > layout.size.height ? 44.0 : (effectiveThumbnailPanelHeight > 0.0 ? 106.0 : 54.0)) : 0.0
        if let footerContentNode = self.currentFooterContentNode {
            backgroundHeight = footerContentNode.updateLayout(size: layout.size, metrics: layout.metrics, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: cleanInsets.bottom, contentInset: effectiveThumbnailPanelHeight, transition: transition)
            transition.updateFrame(node: footerContentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - backgroundHeight + verticalOffset), size: CGSize(width: layout.size.width, height: backgroundHeight)))
            if let dismissedCurrentFooterContentNode = dismissedCurrentFooterContentNode {
                let contentTransition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                footerContentNode.animateIn(fromHeight: dismissedCurrentFooterContentNode.bounds.height, previousContentNode: dismissedCurrentFooterContentNode, transition: contentTransition)
                dismissedCurrentFooterContentNode.animateOut(toHeight: backgroundHeight, nextContentNode: footerContentNode, transition: contentTransition, completion: { [weak self, weak dismissedCurrentFooterContentNode] in
                    if let strongSelf = self, let dismissedCurrentFooterContentNode = dismissedCurrentFooterContentNode, dismissedCurrentFooterContentNode !== strongSelf.currentFooterContentNode {
                        dismissedCurrentFooterContentNode.removeFromSupernode()
                    }
                })
                contentTransition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - backgroundHeight + verticalOffset), size: CGSize(width: layout.size.width, height: backgroundHeight)))
            } else {
                transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - backgroundHeight + verticalOffset), size: CGSize(width: layout.size.width, height: backgroundHeight)))
            }
        } else {
            if let dismissedCurrentFooterContentNode = dismissedCurrentFooterContentNode {
                dismissedCurrentFooterContentNode.removeFromSupernode()
            }
            
            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - backgroundHeight + verticalOffset), size: CGSize(width: layout.size.width, height: backgroundHeight)))
        }
        
        let contentTransition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
        if let overlayContentNode = self.currentOverlayContentNode {
            let insets = UIEdgeInsets(top: navigationBarHeight, left: layout.safeInsets.left, bottom: isHidden ? layout.intrinsicInsets.bottom : backgroundHeight, right: layout.safeInsets.right)
            overlayContentNode.updateLayout(size: layout.size, metrics: layout.metrics, insets: insets, isHidden: isHidden, transition: transition)
            transition.updateFrame(node: overlayContentNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            
            if animateOverlayIn {
                overlayContentNode.animateIn(previousContentNode: dismissedCurrentOverlayContentNode, transition: contentTransition)
            }
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
