//
//  ChatListPreviewController.swift
//  ChatListUI
//
//  Created by Bogdan Redkin on 02/09/2023.
//

import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import ContextUI
import ChatAvatarNavigationNode
import ChatTitleView
import TelegramPresentationData

final class ChatListPreviewContentContainerNode: ASDisplayNode {
    public var controllerNode: ContextControllerContentNode?
    
    override public init() {
        super.init()
    }
    
    public func updateLayout(size: CGSize, scaledSize: CGSize, transition: ContainedViewLayoutTransition) {
        guard let contentNode = self.controllerNode else { return }
        transition.updatePosition(node: contentNode, position: CGPoint(x: scaledSize.width / 2.0, y: scaledSize.height / 2.0))
        transition.updateBounds(node: contentNode, bounds: CGRect(origin: CGPoint(), size: size))
        transition.updateTransformScale(node: contentNode, scale: scaledSize.width / size.width)
        contentNode.updateLayout(size: size, transition: transition)
        contentNode.controller.containerLayoutUpdated(
            ContainerViewLayout(
                size: size,
                metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact),
                deviceMetrics: .iPhoneX,
                intrinsicInsets: UIEdgeInsets(),
                safeInsets: UIEdgeInsets(),
                additionalInsets: UIEdgeInsets(),
                statusBarHeight: nil,
                inputHeight: nil,
                inputHeightIsInteractivellyChanging: false,
                inVoiceOver: false
            ),
            transition: transition
        )
    }
}

func convertFrame(_ frame: CGRect, from fromView: UIView, to toView: UIView) -> CGRect {
    let sourceWindowFrame = fromView.convert(frame, to: nil)
    var targetWindowFrame = toView.convert(sourceWindowFrame, from: nil)
    
    if let fromWindow = fromView.window, let toWindow = toView.window {
        targetWindowFrame.origin.x += toWindow.bounds.width - fromWindow.bounds.width
    }
    return targetWindowFrame
}


final class ChatListPreviewControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    
    private let context: AccountContext
    private let presentationData: PresentationData
    
    private var validLayout: ContainerViewLayout?
    
    private let effectView: UIVisualEffectView
    private var propertyAnimator: AnyObject?
    private var displayLinkAnimator: DisplayLinkAnimator?
    private let dimNode: ASDisplayNode
    private let withoutBlurDimNode: ASDisplayNode
    private let dismissNode: ASDisplayNode
    private let dismissAccessibilityArea: AccessibilityAreaNode

    private let clippingNode: ASDisplayNode
    private let scrollNode: ASScrollNode

    private var originalProjectedContentViewFrame: (CGRect, CGRect)?
    private var contentAreaInScreenSpace: CGRect?
    private var customPosition: CGPoint?
    private let contentContainerNode: ChatListPreviewContentContainerNode
    private weak var gesture: ContextGesture?
    
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    
    private var animatedIn = false
    private var isAnimatingOut = false
    private var didCompleteAnimationIn = false

    var presentationArguments: ChatListPreviewPresentationData?
    var controller: ViewController?
    var transitionParams: TransitionParams?
    
    struct TransitionParams {
        var contentArea: CGRect
        
        var sourceMessageFrame: CGRect
        var sourceChatItemSnapshot: CALayer
        var sourceTitleSnapshot: CALayer
        var sourceTitleFrame: CGRect
        var sourceAvatarSnapshot: CALayer
        var sourceAvatarStartFrame: CGRect
        var sourceAvatarFinalFrame: CGRect

        var targetTitleView: ChatTitleView
        var targetTitleViewFrame: CGRect
        var targetAvatarNode: NavigationButtonNode
        var targetAvatarFrameStart: CGRect
        var targetAvatarFrameEnd: CGRect
        var targetBackgroundLayer: CALayer
        var targetBackgroundMaskLayer: CALayer
        var targetBackgroundStartFrame: CGRect
        var targetBackgroundEndFrame: CGRect
    }

    init(context: AccountContext, gesture: ContextGesture?) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.gesture = gesture

        self.effectView = UIVisualEffectView()
        if #available(iOS 9.0, *) {
        } else {
            if presentationData.theme.rootController.keyboardColor == .dark {
                self.effectView.effect = UIBlurEffect(style: .dark)
            } else {
                self.effectView.effect = UIBlurEffect(style: .light)
            }
            self.effectView.alpha = 0.0
        }
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = presentationData.theme.contextMenu.dimColor
        self.dimNode.alpha = 0.0
        
        self.withoutBlurDimNode = ASDisplayNode()
        self.withoutBlurDimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        self.withoutBlurDimNode.alpha = 0.0
        
        self.dismissNode = ASDisplayNode()
        self.dismissAccessibilityArea = AccessibilityAreaNode()
        self.dismissAccessibilityArea.accessibilityLabel = presentationData.strings.VoiceOver_DismissContextMenu
        self.dismissAccessibilityArea.accessibilityTraits = .button
        
        self.clippingNode = ASDisplayNode()
        self.clippingNode.clipsToBounds = true
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.canCancelAllTouchesInViews = true
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.contentContainerNode = ChatListPreviewContentContainerNode()
                
        super.init()
        self.scrollNode.view.delegate = self
        
        self.view.addSubview(self.effectView)
        self.addSubnode(self.dimNode)
        self.addSubnode(self.withoutBlurDimNode)

        self.addSubnode(self.clippingNode)
        
        self.clippingNode.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.dismissNode)
        self.scrollNode.addSubnode(self.dismissAccessibilityArea)

        self.initializeContent()

        self.dismissAccessibilityArea.activate = { [weak self] in
            self?.dimNodeTapped()
            return true
        }
    }
    
    deinit {
        if let propertyAnimator = self.propertyAnimator {
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                propertyAnimator?.stopAnimation(true)
            }
        }
    }

    override func didLoad() {
        super.didLoad()
        
        self.dismissNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimNodeTapped)))
    }
    
    @objc private func dimNodeTapped() {
        guard self.animatedIn else {
            return
        }
        self.cancel?()
    }
    
    func initializeContent() {
        guard let presentationArguments,
              let controller,
              let (sourceNode, sourceRect) = presentationArguments.sourceNodeAndRect()
        else { return }
        
        let controlleContentrNode = ContextControllerContentNode(sourceView: sourceNode.view, controller: controller, tapped: {
            print("tapped")
        })
        
        self.contentContainerNode.controllerNode = controlleContentrNode
        self.scrollNode.addSubnode(self.contentContainerNode)
        self.contentContainerNode.clipsToBounds = true
        self.contentContainerNode.cornerRadius = 14.0
        self.contentContainerNode.addSubnode(controlleContentrNode)
        
        let projectedFrame = convertFrame(sourceRect, from: sourceNode.view, to: self.view)
        self.originalProjectedContentViewFrame = (projectedFrame, projectedFrame)
    }
        
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
    
    func animateIn() {
        self.gesture?.endPressedAppearance()
        guard
            let transitionParams
        else { return }
        let sourceTitleSnapshot = transitionParams.sourceTitleSnapshot
//        let projectedFrame = convertFrame(sourceRect, from: sourceNode.view, to: self.view)
        let sourceChatItemSnapshot = transitionParams.sourceChatItemSnapshot
        let sourceAvatarSnapshot = transitionParams.sourceAvatarSnapshot
        var updatedContentAreaInScreenSpace = transitionParams.contentArea
        self.originalProjectedContentViewFrame = (transitionParams.sourceMessageFrame, transitionParams.sourceMessageFrame)

        updatedContentAreaInScreenSpace.origin.x = 0.0
        updatedContentAreaInScreenSpace.size.width = self.bounds.width
        self.contentAreaInScreenSpace = updatedContentAreaInScreenSpace

        if let validLayout = self.validLayout {
            self.updateLayout(validLayout, transition: .immediate)
        }
        
        if !self.dimNode.isHidden {
            self.dimNode.alpha = 1.0
            self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        } else {
            self.withoutBlurDimNode.alpha = 1.0
            self.withoutBlurDimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
        
        if let propertyAnimator = self.propertyAnimator {
            let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
            propertyAnimator?.stopAnimation(true)
        }
        self.effectView.effect = makeCustomZoomBlurEffect(isLight: presentationData.theme.rootController.keyboardColor == .light)
        self.effectView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.propertyAnimator = UIViewPropertyAnimator(duration: 0.3 * UIView.animationDurationFactor(), curve: .easeInOut, animations: {
        })

        if let _ = self.propertyAnimator {
            self.displayLinkAnimator = DisplayLinkAnimator(duration: 0.3 * UIView.animationDurationFactor(), from: 0.0, to: 1.0, update: { [weak self] value in
                (self?.propertyAnimator as? UIViewPropertyAnimator)?.fractionComplete = value
            }, completion: { [weak self] in
                self?.didCompleteAnimationIn = true
            })
        } else {
            UIView.animate(withDuration: 0.3, animations: {
                self.effectView.effect = makeCustomZoomBlurEffect(isLight: self.presentationData.theme.rootController.keyboardColor == .light)
            }, completion: { [weak self] _ in
                self?.didCompleteAnimationIn = true
//                self?.actionsContainerNode.animateIn()
            })
        }

        let springDuration: Double = 0.52
        let springDamping: CGFloat = 110.0
        
        self.contentContainerNode.allowsGroupOpacity = true
        self.contentContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 1.15, completion: { [weak self] _ in
            self?.contentContainerNode.allowsGroupOpacity = false
        })
        
        
        sourceAvatarSnapshot.animateAlpha(from: 1.0, to: 0.0, duration: 1.15)
        sourceChatItemSnapshot.animateAlpha(from: 1.0, to: 0.0, duration: 1.15)
        
        
        if let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
            let localSourceFrame = self.view.convert(
                CGRect(origin: CGPoint(x: originalProjectedContentViewFrame.1.minX,
                                       y: originalProjectedContentViewFrame.1.minY),
                       size: CGSize(width: originalProjectedContentViewFrame.1.width,
                                    height: originalProjectedContentViewFrame.1.height)),
                to: self.scrollNode.view
            )

            self.contentContainerNode.layer.animateSpring(from: min(localSourceFrame.width / self.contentContainerNode.frame.width, localSourceFrame.height / self.contentContainerNode.frame.height) as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
           
//            if let source = self.contentContainerNode.controllerNode {
//
//            }
            
            let contentContainerOffset = CGPoint(x: localSourceFrame.center.x - self.contentContainerNode.frame.center.x, y: localSourceFrame.center.y - self.contentContainerNode.frame.center.y)
            if let controller = self.contentContainerNode.controllerNode {
                let snapshotView: UIView? = nil// controller.sourceNode.view.snapshotContentTree()
                if let snapshotView = snapshotView {
                    controller.sourceView.isHidden = true
                    
                    self.view.insertSubview(snapshotView, belowSubview: self.contentContainerNode.view)
                    snapshotView.layer.animateSpring(from: NSValue(cgPoint: localSourceFrame.center), to: NSValue(cgPoint: CGPoint(x: self.contentContainerNode.frame.midX, y: self.contentContainerNode.frame.minY + localSourceFrame.height / 2.0)), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, removeOnCompletion: false)
                    snapshotView.layer.animateSpring(from: 1.0 as NSNumber, to: (self.contentContainerNode.frame.width / localSourceFrame.width) as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping, removeOnCompletion: false)
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                }
            }
            
            let targetPosition = CGPoint(x: localSourceFrame.midY, y: localSourceFrame.minX + 20)
            sourceTitleSnapshot.animateSpring(from: NSValue(cgPoint: sourceTitleSnapshot.position), to: NSValue(cgPoint: targetPosition), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
            
            self.contentContainerNode.layer.animateSpring(from: NSValue(cgPoint: contentContainerOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, additive: true, completion: { [weak self] _ in
                self?.animatedIn = true
            })
        }
    }
    
    func updateLayout() {
        if let layout = self.validLayout {
            self.updateLayout(layout, transition: .immediate)
        }
    }
    
    func updateLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        if self.isAnimatingOut {
            return
        }

        self.validLayout = layout
        
        let targetFrame = CGRect(origin: CGPoint(), size: layout.size)
        transition.updateFrame(view: self.effectView, frame: targetFrame)
        transition.updateFrame(node: self.dimNode, frame: targetFrame)
        transition.updateFrame(node: self.withoutBlurDimNode, frame: targetFrame)
        
        switch layout.metrics.widthClass {
        case .compact:
            if self.effectView.superview == nil {
                self.view.insertSubview(self.effectView, at: 0)
                if let propertyAnimator = self.propertyAnimator {
                    let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                    propertyAnimator?.stopAnimation(true)
                }
                self.effectView.effect = makeCustomZoomBlurEffect(isLight: presentationData.theme.rootController.keyboardColor == .light)
                self.dimNode.alpha = 1.0
            }
            self.dimNode.isHidden = false
            self.withoutBlurDimNode.isHidden = true
        case .regular:
            if self.effectView.superview != nil {
                self.effectView.removeFromSuperview()
                self.withoutBlurDimNode.alpha = 1.0
            }
            self.dimNode.isHidden = true
            self.withoutBlurDimNode.isHidden = false
        }
        transition.updateFrame(node: self.clippingNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let actionsSideInset: CGFloat = layout.safeInsets.left + 12.0
        let contentTopInset: CGFloat = max(11.0, layout.statusBarHeight ?? 0.0)

        let actionsBottomInset: CGFloat = 11.0
        
        if let contentParentNode = contentContainerNode.controllerNode {
            var projectedFrame: CGRect = convertFrame(contentParentNode.sourceView.bounds, from: contentParentNode.sourceView, to: self.view)
            if let presentationArguments, let (sourceNode, sourceRect) = presentationArguments.sourceNodeAndRect() {
                projectedFrame = convertFrame(sourceRect, from: sourceNode.view, to: self.view)
            }
            self.originalProjectedContentViewFrame = (projectedFrame, projectedFrame)
            if let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
                let topEdge = max(contentTopInset, presentationArguments!.contentArea().minY)
                
                let constrainedWidth: CGFloat
                if layout.size.width < layout.size.height {
                    constrainedWidth = layout.size.width
                } else {
                    constrainedWidth = floor(layout.size.width / 2.0)
                }
                let contentScale = (constrainedWidth - actionsSideInset * 2.0) / constrainedWidth
                
                var contentUnscaledSize: CGSize
                if case .compact = layout.metrics.widthClass {
                    let proposedContentHeight: CGFloat
                    if layout.size.width < layout.size.height {
                        proposedContentHeight = layout.size.height - topEdge - actionsSideInset - layout.intrinsicInsets.bottom - actionsBottomInset
                    } else {
                        proposedContentHeight = layout.size.height - topEdge - topEdge
                    }

                    contentUnscaledSize = CGSize(width: constrainedWidth, height: max(100.0, proposedContentHeight))
                    if let preferredSize = contentParentNode.controller.preferredContentSizeForLayout(ContainerViewLayout(size: contentUnscaledSize, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false)) {
                        contentUnscaledSize = preferredSize
                    }
                } else {
                    let proposedContentHeight = layout.size.height - topEdge - actionsSideInset - layout.intrinsicInsets.bottom

                    contentUnscaledSize = CGSize(width: min(layout.size.width, 340.0), height: min(568.0, proposedContentHeight))
                    if let preferredSize = contentParentNode.controller.preferredContentSizeForLayout(ContainerViewLayout(size: contentUnscaledSize, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false)) {
                        contentUnscaledSize = preferredSize
                    }
                }
                let contentSize = CGSize(width: floor(contentUnscaledSize.width * contentScale), height: floor(contentUnscaledSize.height * contentScale))
                self.contentContainerNode.updateLayout(size: contentUnscaledSize, scaledSize: contentSize, transition: transition)
                
                let contentActionsSpacing: CGFloat = .zero
                let actionsSize: CGSize = .zero
                
                let maximumActionsFrameOrigin = max(60.0, layout.size.height - layout.intrinsicInsets.bottom - actionsBottomInset - actionsSize.height)
                var originalActionsFrame: CGRect
                var originalContentFrame: CGRect
                var contentHeight: CGFloat
                                
                if case .compact = layout.metrics.widthClass {
                    if layout.size.width < layout.size.height {
                        let sideInset = floor((layout.size.width - contentSize.width) / 2.0)
                        originalActionsFrame = CGRect(origin: CGPoint(x: sideInset, y: min(maximumActionsFrameOrigin, floor((layout.size.height - actionsSideInset - contentSize.height) / 2.0) + contentSize.height)), size: actionsSize)
                        originalContentFrame = CGRect(origin: CGPoint(x: sideInset, y: originalActionsFrame.minY - contentActionsSpacing - contentSize.height), size: contentSize)
                        if originalContentFrame.minY < topEdge {
                            let requiredOffset = topEdge - originalContentFrame.minY
                            let availableOffset = max(0.0, layout.size.height - layout.intrinsicInsets.bottom - actionsBottomInset - originalActionsFrame.maxY)
                            let offset = min(requiredOffset, availableOffset)
                            originalActionsFrame = originalActionsFrame.offsetBy(dx: 0.0, dy: offset)
                            originalContentFrame = originalContentFrame.offsetBy(dx: 0.0, dy: offset)
                        }
                        contentHeight = max(layout.size.height, max(layout.size.height, originalActionsFrame.maxY + actionsBottomInset) - originalContentFrame.minY + contentTopInset)
                    } else {
                        originalContentFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - contentSize.width - actionsSideInset - actionsSize.width) / 2.0), y: floor((layout.size.height - contentSize.height) / 2.0)), size: contentSize)
                        originalActionsFrame = CGRect(origin: CGPoint(x: originalContentFrame.maxX + actionsSideInset, y: max(topEdge, originalContentFrame.minY)), size: actionsSize)
                        contentHeight = max(layout.size.height, max(originalContentFrame.maxY, originalActionsFrame.maxY))
                    }
                } else {
                    originalContentFrame = CGRect(origin: CGPoint(x: floor(originalProjectedContentViewFrame.1.midX - contentSize.width / 2.0), y: floor(originalProjectedContentViewFrame.1.midY - contentSize.height / 2.0)), size: contentSize)
                    originalContentFrame.origin.x = min(originalContentFrame.origin.x, layout.size.width - actionsSideInset - contentSize.width)
                    originalContentFrame.origin.x = max(originalContentFrame.origin.x, actionsSideInset)
                    originalContentFrame.origin.y = min(originalContentFrame.origin.y, layout.size.height - layout.intrinsicInsets.bottom - actionsSideInset - contentSize.height)
                    originalContentFrame.origin.y = max(originalContentFrame.origin.y, contentTopInset)
                    if originalContentFrame.maxX <= layout.size.width - actionsSideInset - actionsSize.width - contentActionsSpacing {
                        originalActionsFrame = CGRect(origin: CGPoint(x: originalContentFrame.maxX + contentActionsSpacing, y: originalContentFrame.minY), size: actionsSize)
                        if originalActionsFrame.maxX > layout.size.width - actionsSideInset {
                            let offset = originalActionsFrame.maxX - (layout.size.width - actionsSideInset)
                            originalActionsFrame.origin.x -= offset
                            originalContentFrame.origin.x -= offset
                        }
                    } else {
                        originalActionsFrame = CGRect(origin: CGPoint(x: originalContentFrame.minX - contentActionsSpacing - actionsSize.width, y: originalContentFrame.minY), size: actionsSize)
                        if originalActionsFrame.minX < actionsSideInset {
                            let offset = actionsSideInset - originalActionsFrame.minX
                            originalActionsFrame.origin.x += offset
                            originalContentFrame.origin.x += offset
                        }
                    }
                    contentHeight = layout.size.height
                    contentHeight = max(contentHeight, originalActionsFrame.maxY + actionsBottomInset)
                    contentHeight = max(contentHeight, originalContentFrame.maxY + actionsBottomInset)
                }
                
                let scrollContentSize = CGSize(width: layout.size.width, height: contentSize.height)
                if self.scrollNode.view.contentSize != scrollContentSize {
                    self.scrollNode.view.contentSize = scrollContentSize
                }
                
                let overflowOffset = min(0.0, originalContentFrame.minY - contentTopInset)
                
                let contentContainerFrame = originalContentFrame
                transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame.offsetBy(dx: 0.0, dy: -overflowOffset))
                
                
                
//                let contentContainerFrame = CGRect(origin: CGPoint(x: floor(originalProjectedContentViewFrame.1.midX - contentSize.width / 2.0), y: floor(originalProjectedContentViewFrame.1.midY - contentSize.height / 2.0)), size: contentSize)
//                transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)

            }
        }
        
        transition.updateFrame(node: self.dismissNode, frame: CGRect(origin: CGPoint(), size: self.scrollNode.view.contentSize))
        self.dismissAccessibilityArea.frame = CGRect(origin: CGPoint(), size: self.scrollNode.view.contentSize)
    }

    
    func animateOut(targetNode: ASDisplayNode?, completion: (() -> Void)? = nil) {
        var dimCompleted = false
        
        let internalCompletion: () -> Void = { [weak self] in
            if let strongSelf = self, dimCompleted {
                strongSelf.dismiss?()
            }
            completion?()
        }
        
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
            dimCompleted = true
            internalCompletion()
        })
    }
    
    func updatePresentationArguments(_ arguments: ChatListPreviewPresentationData?, controller: ViewController?) {
        self.presentationArguments = arguments
        self.controller = controller
        guard
            let (sourceNode, sourceFrame) = arguments?.sourceNodeAndRect(),
            let contentArea = arguments?.contentArea(),
            let sourceChatItem = sourceNode.supernode as? ChatListItemNode,
            let controller = controller
        else { return }
                
        self.gesture?.endPressedAppearance()
        
        let titleNode = sourceChatItem.titleNode
        let titleSnapshot = titleNode.layer.snapshotContentTree()
        let titleSourceframe = sourceChatItem.convert(sourceChatItem.titleNode.frame, to: nil)

        let avatarNode = sourceChatItem.avatarContainerNode
        let avatarSnapshot = avatarNode.layer.snapshotContentTree()
        let avatarSourceFrame = sourceChatItem.convert(avatarNode.frame, to: nil)

        titleNode.isHidden = true
        avatarNode.isHidden = true

        guard
            let chatSnapshot = sourceChatItem.layer.snapshotContentTree(),
            let titleSnapshot,
            let avatarSnapshot,
            let navigationBar = controller.navigationBar,
            let avatarNode = navigationBar.subnodes?.compactMap({ $0.subnodes }).flatMap({ $0 }).first(where: { $0 is NavigationButtonNode }) as? NavigationButtonNode,
            let titleView = controller.navigationItem.titleView as? ChatTitleView,
            let navigationBackgroundSnapshot = navigationBar.layer.snapshotContentTree()
        else { return }
        
        let finalFrame = contentArea
        let titleFinalFrame = titleView.frame //update according to current content area
        let targetAvatarSize = avatarNode.bounds.size
        let avatarFinalFrame = CGRect(x: titleFinalFrame.minX / 2 - targetAvatarSize.width / 2, y: avatarNode.frame.minY, width: targetAvatarSize.width, height: targetAvatarSize.height)
        let targetAvatarStart = CGRect(origin: CGPoint(x: avatarNode.frame.minX, y: sourceFrame.midY - 12), size: CGSize(width: 24, height: 24))
        let targtetAvatarEnd = titleView.frame
        
        let targetBackgroundMaskLayer = CAShapeLayer()
        targetBackgroundMaskLayer.path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: sourceFrame.size), cornerRadius: .zero).cgPath
        navigationBackgroundSnapshot.mask = targetBackgroundMaskLayer
        
        chatSnapshot.bounds = sourceChatItem.convert(sourceFrame, to: nil)
        chatSnapshot.position = sourceChatItem.convert(sourceFrame.center, to: nil)
        self.layer.addSublayer(chatSnapshot)
        
        titleSnapshot.bounds = sourceChatItem.convert(titleSourceframe, to: nil)
        titleSnapshot.position = sourceChatItem.convert(titleSourceframe.center, to: nil)
        self.layer.addSublayer(titleSnapshot)

        avatarSnapshot.bounds = sourceChatItem.convert(avatarSourceFrame, to: nil)
        avatarSnapshot.position = sourceChatItem.convert(avatarSourceFrame.center, to: nil)
        self.layer.addSublayer(avatarSnapshot)

        self.transitionParams = TransitionParams(contentArea: contentArea,
                                                 sourceMessageFrame: sourceFrame,
                                                 sourceChatItemSnapshot: chatSnapshot,
                                                 sourceTitleSnapshot: titleSnapshot,
                                                 sourceTitleFrame: titleSourceframe,
                                                 sourceAvatarSnapshot: avatarSnapshot,
                                                 sourceAvatarStartFrame: avatarSourceFrame,
                                                 sourceAvatarFinalFrame: avatarFinalFrame,
                                                 targetTitleView: titleView,
                                                 targetTitleViewFrame: titleFinalFrame,
                                                 targetAvatarNode: avatarNode,
                                                 targetAvatarFrameStart: targetAvatarStart,
                                                 targetAvatarFrameEnd: targtetAvatarEnd,
                                                 targetBackgroundLayer: navigationBackgroundSnapshot,
                                                 targetBackgroundMaskLayer: targetBackgroundMaskLayer,
                                                 targetBackgroundStartFrame: sourceFrame,
                                                 targetBackgroundEndFrame: finalFrame)
        
        print("calculated transition params: \(self.transitionParams!) controller layout size: \(String(describing: controller.currentlyAppliedLayout)) contentArea: \(contentArea)")
    }
}

public final class ChatListPreviewController: ViewController {
    private weak var recognizer: TapLongTapOrDoubleTapGestureRecognizer?
    private weak var gesture: ContextGesture?

    private var animatedDidAppear = false
    private var wasDismissed = false
    
    private var controllerNode: ChatListPreviewControllerNode {
        return self.displayNode as! ChatListPreviewControllerNode
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private var chatLocation: ChatLocation
    private var chatPrevewController: ChatController
    
    public init(context: AccountContext, chatLocation: ChatLocation, recognizer: TapLongTapOrDoubleTapGestureRecognizer? = nil, gesture: ContextGesture? = nil) {
        self.context = context
        self.chatLocation = chatLocation
        self.chatPrevewController = context.sharedContext.makeChatController(context: context, chatLocation: chatLocation, subject: nil, botStart: nil, mode: .standard(previewing: true))
        self.recognizer = recognizer
        self.gesture = gesture
        super.init(navigationBarPresentationData: nil)
        self.statusBar.statusBarStyle = .Hide
        self.lockOrientation = true
        self.blocksBackgroundWhenInOverlay = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatListPreviewControllerNode(context: context, gesture: gesture)
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
        self.displayNodeDidLoad()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let _ = self.presentationArguments as? ChatListPreviewPresentationData {
            self.updateChatLocation(self.chatLocation)
            self.ready.set(.single(true))
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        super.viewDidAppear(animated)
        let _ = (self.ready.get() |> deliverOnMainQueue).start(next: { value in
            guard value else { return }
            
            self.controllerNode.initializeContent()
            
            print("content is ready: \(value)")
            if !self.wasDismissed && !self.animatedDidAppear {
                self.animatedDidAppear = true
                self.controllerNode.animateIn()
            }
        })
        
//        super.viewDidAppear(animated)
//        guard
//            let arguments = self.presentationArguments as? ChatListPreviewPresentationData,
//            let (sourceNode, _) = arguments.sourceAndRect()
//        else { return }
//
//        if !self.animatedIn {
//            self.animatedIn = true
//            self.controllerNode.animateIn(sourceNode: sourceNode)
//        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        guard
            let arguments = self.presentationArguments as? ChatListPreviewPresentationData,
            let (sourceNode, _) = arguments.sourceNodeAndRect()
        else { return }
        
        self.controllerNode.animateOut(targetNode: sourceNode, completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.chatPrevewController.updateNavigationBarLayout(layout, transition: transition)
        self.controllerNode.updateLayout(layout, transition: transition)
    }
    
    public func updateChatLocation(_ chatLocation: ChatLocation) {
        self.chatLocation = chatLocation
        let chatController = context.sharedContext.makeChatController(context: self.context, chatLocation: chatLocation, subject: nil, botStart: nil, mode: .standard(previewing: true))
        self.chatPrevewController = chatController
        if let layout = self.currentlyAppliedLayout {
            chatController.updateNavigationBarLayout(layout, transition: .immediate)
            self.controllerNode.updatePresentationArguments(self.presentationArguments as? ChatListPreviewPresentationData,
                                                            controller: chatController)
        }

//        if self.chatLocation != chatLocation {
//        }
    }
}
