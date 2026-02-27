import Foundation
import UIKit
import AsyncDisplayKit
import Display
import EdgeEffect
import ComponentFlow
import ComponentDisplayAdapters

public final class GalleryFooterNode: ASDisplayNode {
    private let edgeEffectView: EdgeEffectView
    private var contentsFrame = CGRect()
    
    private var currentThumbnailPanelHeight: CGFloat?
    private var currentFooterContentNode: GalleryFooterContentNode?
    private var currentOverlayContentNode: GalleryOverlayContentNode?
    private var currentLayout: (ContainerViewLayout, CGFloat, CGFloat, Bool)?
    
    private let controllerInteraction: GalleryControllerInteraction
    
    public init(controllerInteraction: GalleryControllerInteraction) {
        self.controllerInteraction = controllerInteraction
        
        self.edgeEffectView = EdgeEffectView()
        self.edgeEffectView.isUserInteractionEnabled = false
        
        super.init()
        
        self.view.addSubview(self.edgeEffectView)
    }
    
    private var visibilityAlpha: CGFloat = 1.0
    private var defaultEdgeEffectAlpha: CGFloat = 0.0
    
    public func setVisibilityAlpha(_ alpha: CGFloat, animated: Bool) {
        self.visibilityAlpha = alpha
        let transition: ComponentTransition = animated ? .easeInOut(duration: 0.2) : .immediate
        transition.setAlpha(view: self.edgeEffectView, alpha: alpha * self.defaultEdgeEffectAlpha)
        self.currentFooterContentNode?.setVisibilityAlpha(alpha, animated: true)
        self.currentOverlayContentNode?.setVisibilityAlpha(alpha)
    }
    
    func animateIn(transition: ContainedViewLayoutTransition) {
        self.edgeEffectView.alpha = 0.0
        ComponentTransition(transition).setAlpha(view: self.edgeEffectView, alpha: self.defaultEdgeEffectAlpha * self.visibilityAlpha)
        
        if let currentFooterContentNode = self.currentFooterContentNode {
            currentFooterContentNode.animateIn(transition: transition)
        }
        
        if let currentOverlayContentNode = self.currentOverlayContentNode {
            currentOverlayContentNode.alpha = 0.0
            transition.updateAlpha(node: currentOverlayContentNode, alpha: 1.0)
        }
    }
    
    func animateOut(transition: ContainedViewLayoutTransition) {
        ComponentTransition(transition).setAlpha(view: self.edgeEffectView, alpha: 0.0)
        
        if let currentFooterContentNode = self.currentFooterContentNode {
            currentFooterContentNode.animateOut(transition: transition)
        }
        
        if let currentOverlayContentNode = self.currentOverlayContentNode {
            transition.updateAlpha(node: currentOverlayContentNode, alpha: 0.0)
        }
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
        } else if let _ = self.currentThumbnailPanelHeight {
            self.currentThumbnailPanelHeight = thumbnailPanelHeight
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
        var backgroundLayoutInfo: GalleryFooterContentNode.LayoutInfo?
        let verticalOffset: CGFloat = isHidden ? (layout.size.width > layout.size.height ? 44.0 : (effectiveThumbnailPanelHeight > 0.0 ? 106.0 : 54.0)) : 0.0
        let backgroundFrame: CGRect
        var edgeEffectTransition = ComponentTransition(transition)
        if let footerContentNode = self.currentFooterContentNode {
            var footerTransition = transition
            if footerContentNode.bounds.isEmpty {
                footerTransition = .immediate
            }
            let backgroundLayoutInfoValue = footerContentNode.updateLayout(size: layout.size, metrics: layout.metrics, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: cleanInsets.bottom, contentInset: effectiveThumbnailPanelHeight, transition: footerTransition)
            backgroundLayoutInfo = backgroundLayoutInfoValue
            
            footerTransition.updateFrame(node: footerContentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - backgroundLayoutInfoValue.height + verticalOffset), size: CGSize(width: layout.size.width, height: backgroundLayoutInfoValue.height)))
            if let dismissedCurrentFooterContentNode = dismissedCurrentFooterContentNode {
                let contentTransition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                footerContentNode.animateIn(fromHeight: dismissedCurrentFooterContentNode.bounds.height, previousContentNode: dismissedCurrentFooterContentNode, transition: contentTransition)
                dismissedCurrentFooterContentNode.animateOut(toHeight: backgroundLayoutInfoValue.height, nextContentNode: footerContentNode, transition: contentTransition, completion: { [weak self, weak dismissedCurrentFooterContentNode] in
                    if let strongSelf = self, let dismissedCurrentFooterContentNode = dismissedCurrentFooterContentNode, dismissedCurrentFooterContentNode !== strongSelf.currentFooterContentNode {
                        dismissedCurrentFooterContentNode.removeFromSupernode()
                    }
                })
                backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - backgroundLayoutInfoValue.height + verticalOffset), size: CGSize(width: layout.size.width, height: backgroundLayoutInfoValue.height))
                edgeEffectTransition = ComponentTransition(contentTransition)
            } else {
                backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - backgroundLayoutInfoValue.height + verticalOffset), size: CGSize(width: layout.size.width, height: backgroundLayoutInfoValue.height))
            }
        } else {
            if let dismissedCurrentFooterContentNode = dismissedCurrentFooterContentNode {
                dismissedCurrentFooterContentNode.removeFromSupernode()
            }
            
            backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height + verticalOffset), size: CGSize(width: layout.size.width, height: 0.0))
        }
        
        self.contentsFrame = backgroundFrame
        
        var edgeEffectFrame = backgroundFrame
        let edgeEffectHeight: CGFloat = 120.0
        let edgeEffectOffset: CGFloat = 70.0
        edgeEffectFrame.origin.y -= edgeEffectOffset
        edgeEffectFrame.size.height += edgeEffectOffset
        edgeEffectTransition.setFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
        self.edgeEffectView.update(content: .black, alpha: 0.65, rect: edgeEffectFrame, edge: .bottom, edgeSize: min(edgeEffectHeight, edgeEffectFrame.height), transition: edgeEffectTransition)
        if let backgroundLayoutInfo, backgroundLayoutInfo.needsShadow {
            self.defaultEdgeEffectAlpha = 1.0
        } else {
            self.defaultEdgeEffectAlpha = 0.5
        }
        ComponentTransition(transition).setAlpha(view: self.edgeEffectView, alpha: self.visibilityAlpha * self.defaultEdgeEffectAlpha)
        
        let contentTransition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
        if let overlayContentNode = self.currentOverlayContentNode {
            var backgroundHeight: CGFloat = 0.0
            if let backgroundLayoutInfo {
                backgroundHeight = backgroundLayoutInfo.height
            }
            var overlayContentTransition = transition
            if overlayContentNode.frame.isEmpty {
                overlayContentTransition = .immediate
            }
            let insets = UIEdgeInsets(top: navigationBarHeight, left: layout.safeInsets.left, bottom: isHidden ? layout.intrinsicInsets.bottom : backgroundHeight, right: layout.safeInsets.right)
            overlayContentNode.updateLayout(size: layout.size, metrics: layout.metrics, insets: insets, isHidden: isHidden, transition: overlayContentTransition)
            overlayContentTransition.updateFrame(node: overlayContentNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            
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
        if !self.contentsFrame.contains(point) || self.visibilityAlpha < 1.0 {
            return nil
        }
        let result = super.hitTest(point, with: event)
        return result
    }
}
