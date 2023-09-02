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
    
    private var presentationArguments: ChatListPreviewPresentationData?
    private var controller: ViewController?
    
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
              let (sourceNode, sourceRect) = presentationArguments.sourceAndRect()
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
        guard let presentationArguments, let (sourceNode, sourceRect) = presentationArguments.sourceAndRect() else { return }
        let projectedFrame = convertFrame(sourceRect, from: sourceNode.view, to: self.view)
        self.originalProjectedContentViewFrame = (projectedFrame, projectedFrame)

        var updatedContentAreaInScreenSpace = UIScreen.main.bounds
        updatedContentAreaInScreenSpace.origin.x = 0.0
        updatedContentAreaInScreenSpace.size.width = self.bounds.width
        self.contentAreaInScreenSpace = updatedContentAreaInScreenSpace

        if let validLayout = self.validLayout {
            self.updateLayout(validLayout, transition: .immediate)
        }
        
        if !self.dimNode.isHidden {
            self.dimNode.alpha = 1.0
            self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        } else {
            self.withoutBlurDimNode.alpha = 1.0
            self.withoutBlurDimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
        
        if #available(iOS 10.0, *) {
            if let propertyAnimator = self.propertyAnimator {
                let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                propertyAnimator?.stopAnimation(true)
            }
            self.effectView.effect = makeCustomZoomBlurEffect(isLight: presentationData.theme.rootController.keyboardColor == .light)
            self.effectView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.propertyAnimator = UIViewPropertyAnimator(duration: 0.2 * UIView.animationDurationFactor(), curve: .easeInOut, animations: {
            })
        }

        if let _ = self.propertyAnimator {
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                self.displayLinkAnimator = DisplayLinkAnimator(duration: 0.2 * UIView.animationDurationFactor(), from: 0.0, to: 1.0, update: { [weak self] value in
                    (self?.propertyAnimator as? UIViewPropertyAnimator)?.fractionComplete = value
                }, completion: { //[weak self] in
//                    self?.didCompleteAnimationIn = true
                })
            }
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.effectView.effect = makeCustomZoomBlurEffect(isLight: self.presentationData.theme.rootController.keyboardColor == .light)
            }, completion: { _ in //[weak self] _ in
//                self?.didCompleteAnimationIn = true
//                self?.actionsContainerNode.animateIn()
            })
        }

        let springDuration: Double = 0.52
        let springDamping: CGFloat = 110.0
        
        self.contentContainerNode.allowsGroupOpacity = true
        self.contentContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, completion: { [weak self] _ in
            self?.contentContainerNode.allowsGroupOpacity = false
        })
        
        if let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
            let localSourceFrame = self.view.convert(CGRect(origin: CGPoint(x: originalProjectedContentViewFrame.1.minX, y: originalProjectedContentViewFrame.1.minY), size: CGSize(width: originalProjectedContentViewFrame.1.width, height: originalProjectedContentViewFrame.1.height)), to: self.scrollNode.view)
            
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
                    //snapshotView.layer.animateSpring(from: 1.0 as NSNumber, to: (self.contentContainerNode.frame.width / localSourceFrame.width) as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping, removeOnCompletion: false)
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                }
            }
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
                if #available(iOS 10.0, *) {
                    if let propertyAnimator = self.propertyAnimator {
                        let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                        propertyAnimator?.stopAnimation(true)
                    }
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
        
        if let contentParentNode = contentContainerNode.controllerNode {
            var projectedFrame: CGRect = convertFrame(contentParentNode.sourceView.bounds, from: contentParentNode.sourceView, to: self.view)
            if let presentationArguments, let (sourceNode, sourceRect) = presentationArguments.sourceAndRect() {
                projectedFrame = convertFrame(sourceRect, from: sourceNode.view, to: self.view)
            }
            self.originalProjectedContentViewFrame = (projectedFrame, projectedFrame)
            if let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
                let constrainedWidth: CGFloat
                if layout.size.width < layout.size.height {
                    constrainedWidth = layout.size.width
                } else {
                    constrainedWidth = floor(layout.size.width / 2.0)
                }
                var contentUnscaledSize: CGSize
                if case .compact = layout.metrics.widthClass {
                    contentUnscaledSize = CGSize(width: constrainedWidth, height: max(100.0, layout.size.height))
                    if let preferredSize = contentParentNode.controller.preferredContentSizeForLayout(ContainerViewLayout(size: contentUnscaledSize, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false)) {
                        contentUnscaledSize = preferredSize
                    }
                } else {
                    contentUnscaledSize = CGSize(width: min(layout.size.width, 340.0), height: min(568.0, layout.size.height - layout.intrinsicInsets.bottom))
                    if let preferredSize = contentParentNode.controller.preferredContentSizeForLayout(ContainerViewLayout(size: contentUnscaledSize, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false)) {
                        contentUnscaledSize = preferredSize
                    }
                }
                let contentSize = CGSize(width: floor(contentUnscaledSize.width), height: floor(contentUnscaledSize.height))
                self.contentContainerNode.updateLayout(size: contentUnscaledSize, scaledSize: contentSize, transition: transition)
                let scrollContentSize = layout.size
                if self.scrollNode.view.contentSize != scrollContentSize {
                    self.scrollNode.view.contentSize = scrollContentSize
                }
                
                let contentContainerFrame = CGRect(origin: CGPoint(x: floor(originalProjectedContentViewFrame.1.midX - contentSize.width / 2.0), y: floor(originalProjectedContentViewFrame.1.midY - contentSize.height / 2.0)), size: contentSize)
                transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)

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
            let (sourceNode, _) = arguments.sourceAndRect()
        else { return }

        self.controllerNode.animateOut(targetNode: sourceNode, completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.controllerNode.updateLayout(layout, transition: transition)
        
    }
    
    public func updateChatLocation(_ chatLocation: ChatLocation) {
        self.chatLocation = chatLocation
        let chatController = context.sharedContext.makeChatController(context: self.context, chatLocation: chatLocation, subject: nil, botStart: nil, mode: .standard(previewing: true))
        self.chatPrevewController = chatController
        self.controllerNode.updatePresentationArguments(self.presentationArguments as? ChatListPreviewPresentationData,
                                                        controller: chatController)

//        if self.chatLocation != chatLocation {
//        }
    }
}
