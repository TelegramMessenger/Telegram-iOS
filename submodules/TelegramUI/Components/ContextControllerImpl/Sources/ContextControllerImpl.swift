import Foundation
import UIKit
import Display
import ContextUI
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import AsyncDisplayKit
import ReactionSelectionNode
import TelegramCore
import UIKitRuntimeUtils
import UndoUI
import TextSelectionNode

private let animationDurationFactor: Double = 1.0

func convertFrame(_ frame: CGRect, from fromView: UIView, to toView: UIView) -> CGRect {
    let sourceWindowFrame = fromView.convert(frame, to: nil)
    var targetWindowFrame = toView.convert(sourceWindowFrame, from: nil)
    
    if let fromWindow = fromView.window, let toWindow = toView.window {
        targetWindowFrame.origin.x += toWindow.bounds.width - fromWindow.bounds.width
    }
    return targetWindowFrame
}

final class ContextControllerNode: ViewControllerTracingNode, ASScrollViewDelegate {
    private weak var controller: ContextControllerImpl?
    private let context: AccountContext?
    private var presentationData: PresentationData
    
    private let configuration: ContextController.Configuration
    
    private let legacySource: ContextContentSource
    private var legacyItems: Signal<ContextController.Items, NoError>
    
    let beginDismiss: (ContextMenuActionResult) -> Void
    private let beganAnimatingOut: () -> Void
    private let attemptTransitionControllerIntoNavigation: () -> Void
    var dismissedForCancel: (() -> Void)?
    private let getController: () -> ContextControllerProtocol?
    private weak var gesture: ContextGesture?
        
    private var didSetItemsReady = false
    let itemsReady = Promise<Bool>()
    let contentReady = Promise<Bool>()
    
    private var currentItems: ContextController.Items?
    private var currentActionsMinHeight: ContextController.ActionsHeight?
    
    private var validLayout: ContainerViewLayout?
    
    private let effectView: UIVisualEffectView
    private var propertyAnimator: AnyObject?
    private var displayLinkAnimator: DisplayLinkAnimator?
    private let dimNode: ASDisplayNode
    private let withoutBlurDimNode: ASDisplayNode
    private let dismissNode: ASDisplayNode
    private let dismissAccessibilityArea: AccessibilityAreaNode
    
    private var sourceContainer: ContextSourceContainer?
    
    private let clippingNode: ASDisplayNode
    private let scrollNode: ASScrollNode
    
    private var originalProjectedContentViewFrame: (CGRect, CGRect)?
    private var contentAreaInScreenSpace: CGRect?
    private var customPosition: CGPoint?
    private let contentContainerNode: ContextContentContainerNode
    private var actionsContainerNode: ContextActionsContainerNode
    
    private var didCompleteAnimationIn = false
    private var initialContinueGesturePoint: CGPoint?
    private var didMoveFromInitialGesturePoint = false
    private var highlightedActionNode: ContextActionNodeProtocol?
    private var highlightedReaction: ReactionItem.Reaction?
    
    private let hapticFeedback = HapticFeedback()
    
    private var animatedIn = false
    private var isAnimatingOut = false
    
    private let itemsDisposable = MetaDisposable()
    
    private let blurBackground: Bool
    
    var overlayWantsToBeBelowKeyboard: Bool {
        guard let sourceContainer = self.sourceContainer else {
            return false
        }
        return sourceContainer.overlayWantsToBeBelowKeyboard
    }
    
    init(
        controller: ContextControllerImpl,
        context: AccountContext?,
        presentationData: PresentationData,
        configuration: ContextController.Configuration,
        beginDismiss: @escaping (ContextMenuActionResult) -> Void,
        recognizer: TapLongTapOrDoubleTapGestureRecognizer?,
        gesture: ContextGesture?,
        beganAnimatingOut: @escaping () -> Void,
        attemptTransitionControllerIntoNavigation: @escaping () -> Void
    ) {
        self.controller = controller
        self.context = context
        self.presentationData = presentationData
        self.configuration = configuration
        self.beginDismiss = beginDismiss
        self.beganAnimatingOut = beganAnimatingOut
        self.attemptTransitionControllerIntoNavigation = attemptTransitionControllerIntoNavigation
        self.gesture = gesture
        
        self.legacySource = configuration.sources[0].source
        self.legacyItems = configuration.sources[0].items
        
        self.getController = { [weak controller] in
            return controller
        }
        
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
        
        self.contentContainerNode = ContextContentContainerNode()
        
        var feedbackTap: (() -> Void)?
        var updateLayout: (() -> Void)?
        
        var blurBackground = true
        if let mainSource = configuration.sources.first(where: { $0.id == configuration.initialId }) {
            if case .reference = mainSource.source {
                blurBackground = false
            } else if case let .extracted(extractedSource) = mainSource.source, !extractedSource.blurBackground {
                blurBackground = false
            }
        }
        self.blurBackground = blurBackground
            
        self.actionsContainerNode = ContextActionsContainerNode(presentationData: presentationData, items: ContextController.Items(), getController: { [weak controller] in
            return controller
        }, actionSelected: { result in
            beginDismiss(result)
        }, requestLayout: {
            updateLayout?()
        }, feedbackTap: {
            feedbackTap?()
        }, blurBackground: blurBackground)
        
        super.init()
        
        feedbackTap = { [weak self] in
            self?.hapticFeedback.tap()
        }

        updateLayout = { [weak self] in
            self?.updateLayout()
        }
        
        self.scrollNode.view.delegate = self.wrappedScrollViewDelegate
        
        if blurBackground {
            self.view.addSubview(self.effectView)
            self.addSubnode(self.dimNode)
            self.addSubnode(self.withoutBlurDimNode)
        }
        
        self.addSubnode(self.clippingNode)
        
        self.clippingNode.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.dismissNode)
        self.scrollNode.addSubnode(self.dismissAccessibilityArea)
        
        self.scrollNode.addSubnode(self.actionsContainerNode)
        
        if let recognizer = recognizer {
            recognizer.externalUpdated = { [weak self, weak recognizer] view, point in
                guard let strongSelf = self, let _ = recognizer else {
                    return
                }
                let localPoint = strongSelf.view.convert(point, from: view)
                let initialPoint: CGPoint
                if let current = strongSelf.initialContinueGesturePoint {
                    initialPoint = current
                } else {
                    initialPoint = localPoint
                    strongSelf.initialContinueGesturePoint = localPoint
                }
                if strongSelf.didCompleteAnimationIn {
                    if !strongSelf.didMoveFromInitialGesturePoint {
                        let distance = abs(localPoint.y - initialPoint.y)
                        if distance > 12.0 {
                            strongSelf.didMoveFromInitialGesturePoint = true
                        }
                    }
                    if strongSelf.didMoveFromInitialGesturePoint {
                        if let sourceContainer = strongSelf.sourceContainer {
                            let presentationPoint = strongSelf.view.convert(localPoint, to: sourceContainer.view)
                            sourceContainer.highlightGestureMoved(location: presentationPoint, hover: false)
                        } else {
                            let actionPoint = strongSelf.view.convert(localPoint, to: strongSelf.actionsContainerNode.view)
                            let actionNode = strongSelf.actionsContainerNode.actionNode(at: actionPoint)
                            if strongSelf.highlightedActionNode !== actionNode {
                                strongSelf.highlightedActionNode?.setIsHighlighted(false)
                                strongSelf.highlightedActionNode = actionNode
                                if let actionNode = actionNode {
                                    actionNode.setIsHighlighted(true)
                                    strongSelf.hapticFeedback.tap()
                                }
                            }
                        }
                    }
                }
            }
            recognizer.externalEnded = { [weak self, weak recognizer] viewAndPoint in
                guard let strongSelf = self, let recognizer = recognizer else {
                    return
                }
                recognizer.externalUpdated = nil
                if strongSelf.didMoveFromInitialGesturePoint {
                    if let sourceContainer = strongSelf.sourceContainer {
                        sourceContainer.highlightGestureFinished(performAction: viewAndPoint != nil)
                    } else {
                        if let (_, _) = viewAndPoint {
                            if let highlightedActionNode = strongSelf.highlightedActionNode {
                                strongSelf.highlightedActionNode = nil
                                highlightedActionNode.performAction()
                            }
                        } else {
                            if let highlightedActionNode = strongSelf.highlightedActionNode {
                                strongSelf.highlightedActionNode = nil
                                highlightedActionNode.setIsHighlighted(false)
                            }
                        }
                    }
                }
            }
        } else if let gesture = gesture {
            gesture.externalUpdated = { [weak self, weak gesture] view, point in
                guard let strongSelf = self, let _ = gesture else {
                    return
                }
                let localPoint: CGPoint
                if let layout = strongSelf.validLayout, layout.metrics.isTablet, layout.size.width > layout.size.height, let view {
                    localPoint = view.convert(point, to: nil)
                } else {
                    localPoint = strongSelf.view.convert(point, from: view)
                }
                let initialPoint: CGPoint
                if let current = strongSelf.initialContinueGesturePoint {
                    initialPoint = current
                } else {
                    initialPoint = localPoint
                    strongSelf.initialContinueGesturePoint = localPoint
                }
                if strongSelf.didCompleteAnimationIn {
                    if !strongSelf.didMoveFromInitialGesturePoint {
                        let distance = abs(localPoint.y - initialPoint.y)
                        if distance > 4.0 {
                            strongSelf.didMoveFromInitialGesturePoint = true
                        }
                    }
                    if strongSelf.didMoveFromInitialGesturePoint {
                        if let sourceContainer = strongSelf.sourceContainer {
                            let presentationPoint = strongSelf.view.convert(localPoint, to: sourceContainer.view)
                            sourceContainer.highlightGestureMoved(location: presentationPoint, hover: false)
                        } else {
                            let actionPoint = strongSelf.view.convert(localPoint, to: strongSelf.actionsContainerNode.view)
                            var actionNode = strongSelf.actionsContainerNode.actionNode(at: actionPoint)
                            if let actionNodeValue = actionNode, !actionNodeValue.isActionEnabled {
                                actionNode = nil
                            }

                            if strongSelf.highlightedActionNode !== actionNode {
                                strongSelf.highlightedActionNode?.setIsHighlighted(false)
                                strongSelf.highlightedActionNode = actionNode
                                if let actionNode = actionNode {
                                    actionNode.setIsHighlighted(true)
                                    strongSelf.hapticFeedback.tap()
                                }
                            }
                        }
                    }
                }
            }
            gesture.externalEnded = { [weak self, weak gesture] viewAndPoint in
                guard let strongSelf = self, let gesture = gesture else {
                    return
                }
                gesture.externalUpdated = nil
                if strongSelf.didMoveFromInitialGesturePoint {
                    if let sourceContainer = strongSelf.sourceContainer {
                        sourceContainer.highlightGestureFinished(performAction: viewAndPoint != nil)
                    } else {
                        if let (_, _) = viewAndPoint {
                            if let highlightedActionNode = strongSelf.highlightedActionNode {
                                strongSelf.highlightedActionNode = nil
                                highlightedActionNode.performAction()
                            }
                        } else {
                            if let highlightedActionNode = strongSelf.highlightedActionNode {
                                strongSelf.highlightedActionNode = nil
                                highlightedActionNode.setIsHighlighted(false)
                            }
                        }
                    }
                }
            }
        }
        
        self.initializeContent()
        
        self.dismissAccessibilityArea.activate = { [weak self] in
            self?.dimNodeTapped()
            return true
        }
        
        if controller.disableScreenshots {
            setLayerDisableScreenshots(self.layer, true)
        }
    }
    
    deinit {
        if let propertyAnimator = self.propertyAnimator {
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                propertyAnimator?.stopAnimation(true)
            }
        }
        
        self.itemsDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dismissNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimNodeTapped)))
        
        if #available(iOS 13.0, *) {
            self.view.addGestureRecognizer(UIHoverGestureRecognizer(target: self, action: #selector(self.hoverGesture(_:))))
        }
    }
    
    @objc private func dimNodeTapped() {
        guard self.animatedIn else {
            return
        }
        self.dismissedForCancel?()
        self.beginDismiss(.default)
    }
    
    @available(iOS 13.0, *)
    @objc private func hoverGesture(_ gestureRecognizer: UIHoverGestureRecognizer) {
        guard self.didCompleteAnimationIn else {
            return
        }
        
        let localPoint = gestureRecognizer.location(in: self.view)
        
        switch gestureRecognizer.state {
            case .changed:
                if let sourceContainer = self.sourceContainer {
                    let presentationPoint = self.view.convert(localPoint, to: sourceContainer.view)
                    sourceContainer.highlightGestureMoved(location: presentationPoint, hover: true)
                } else {
                    let actionPoint = self.view.convert(localPoint, to: self.actionsContainerNode.view)
                    let actionNode = self.actionsContainerNode.actionNode(at: actionPoint)
                    if self.highlightedActionNode !== actionNode {
                        self.highlightedActionNode?.setIsHighlighted(false)
                        self.highlightedActionNode = actionNode
                        if let actionNode = actionNode {
                            actionNode.setIsHighlighted(true)
                        }
                    }
                }
            case .ended, .cancelled:
                if let sourceContainer = self.sourceContainer {
                    sourceContainer.highlightGestureMoved(location: CGPoint(x: -1, y: -1), hover: true)
                } else {
                    if let highlightedActionNode = self.highlightedActionNode {
                        self.highlightedActionNode = nil
                        highlightedActionNode.setIsHighlighted(false)
                    }
                }
            default:
                break
        }
    }
    
    private func initializeContent() {
        if self.configuration.sources.count == 1 {
            switch self.configuration.sources[0].source {
            case .location:
                break
            case let .reference(source):
                if let controller = self.getController() as? ContextControllerImpl, controller.workaroundUseLegacyImplementation {
                    self.contentReady.set(.single(true))
                    
                    let transitionInfo = source.transitionInfo()
                    if let transitionInfo {
                        let referenceView = transitionInfo.referenceView
                        self.contentContainerNode.contentNode = .reference(view: referenceView)
                        self.contentAreaInScreenSpace = transitionInfo.contentAreaInScreenSpace
                        self.customPosition = transitionInfo.customPosition
                        
                        var projectedFrame = convertFrame(referenceView.bounds, from: referenceView, to: self.view)
                        projectedFrame.origin.x += transitionInfo.insets.left
                        projectedFrame.size.width -= transitionInfo.insets.left + transitionInfo.insets.right
                        projectedFrame.origin.y += transitionInfo.insets.top
                        projectedFrame.size.width -= transitionInfo.insets.top + transitionInfo.insets.bottom
                        self.originalProjectedContentViewFrame = (projectedFrame, projectedFrame)
                    }
                    
                    self.itemsDisposable.set((self.configuration.sources[0].items
                    |> deliverOnMainQueue).start(next: { [weak self] items in
                        self?.setItems(items: items, minHeight: nil, previousActionsTransition: .scale)
                    }))
                    
                    return
                }
            case .extracted:
                break
            case let .controller(source):
                if let controller = self.getController() as? ContextControllerImpl, controller.workaroundUseLegacyImplementation {
                    self.contentReady.set(source.controller.ready.get())
                    
                    let transitionInfo = source.transitionInfo()
                    if let transitionInfo = transitionInfo, let (sourceView, sourceNodeRect) = transitionInfo.sourceNode() {
                        let contentParentNode = ContextControllerContentNode(sourceView: sourceView, controller: source.controller, tapped: { [weak self] in
                            self?.attemptTransitionControllerIntoNavigation()
                        })
                        self.contentContainerNode.contentNode = .controller(contentParentNode)
                        self.scrollNode.addSubnode(self.contentContainerNode)
                        self.contentContainerNode.clipsToBounds = true
                        self.contentContainerNode.cornerRadius = 30.0
                        self.contentContainerNode.addSubnode(contentParentNode)
                        
                        let projectedFrame = convertFrame(sourceNodeRect, from: sourceView, to: self.view)
                        self.originalProjectedContentViewFrame = (projectedFrame, projectedFrame)
                    }
                    
                    self.itemsDisposable.set((self.configuration.sources[0].items
                    |> deliverOnMainQueue).start(next: { [weak self] items in
                        self?.setItems(items: items, minHeight: nil, previousActionsTransition: .scale)
                    }))
                    
                    return
                }
            }
        }
        
        if let controller = self.controller {
            let sourceContainer = ContextSourceContainer(controller: controller, configuration: self.configuration, context: self.context)
            self.contentReady.set(sourceContainer.ready.get())
            self.itemsReady.set(.single(true))
            self.sourceContainer = sourceContainer
            self.addSubnode(sourceContainer)
        }
    }
    
    func animateIn() {
        self.gesture?.endPressedAppearance()
        self.hapticFeedback.impact()
        
        if let sourceContainer = self.sourceContainer {
            self.didCompleteAnimationIn = true
            sourceContainer.animateIn()
            return
        }
        
        switch self.legacySource {
        case .location, .reference:
            break
        case .extracted:
            if let contentAreaInScreenSpace = self.contentAreaInScreenSpace, let maybeContentNode = self.contentContainerNode.contentNode, case .extracted = maybeContentNode {
                var updatedContentAreaInScreenSpace = contentAreaInScreenSpace
                updatedContentAreaInScreenSpace.origin.x = 0.0
                updatedContentAreaInScreenSpace.size.width = self.bounds.width
                
                self.clippingNode.layer.animateFrame(from: updatedContentAreaInScreenSpace, to: self.clippingNode.frame, duration: 0.18 * animationDurationFactor, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                self.clippingNode.layer.animateBoundsOriginYAdditive(from: updatedContentAreaInScreenSpace.minY, to: 0.0, duration: 0.18 * animationDurationFactor, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
            }
        case let .controller(source):
            let transitionInfo = source.transitionInfo()
            if let transitionInfo = transitionInfo, let (sourceView, sourceNodeRect) = transitionInfo.sourceNode() {
                let projectedFrame = convertFrame(sourceNodeRect, from: sourceView, to: self.view)
                self.originalProjectedContentViewFrame = (projectedFrame, projectedFrame)
                
                var updatedContentAreaInScreenSpace = transitionInfo.contentAreaInScreenSpace
                updatedContentAreaInScreenSpace.origin.x = 0.0
                updatedContentAreaInScreenSpace.size.width = self.bounds.width
                self.contentAreaInScreenSpace = updatedContentAreaInScreenSpace
            }
        }
        
        if let validLayout = self.validLayout {
            self.updateLayout(layout: validLayout, transition: .immediate, previousActionsContainerNode: nil)
        }
        
        if !self.dimNode.isHidden {
            self.dimNode.alpha = 1.0
            self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2 * animationDurationFactor)
        } else {
            self.withoutBlurDimNode.alpha = 1.0
            self.withoutBlurDimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2 * animationDurationFactor)
        }
        
        if #available(iOS 10.0, *) {
            if let propertyAnimator = self.propertyAnimator {
                let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                propertyAnimator?.stopAnimation(true)
            }
            self.effectView.effect = makeCustomZoomBlurEffect(isLight: presentationData.theme.rootController.keyboardColor == .light)
            self.effectView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2 * animationDurationFactor)
            self.propertyAnimator = UIViewPropertyAnimator(duration: 0.2 * animationDurationFactor * UIView.animationDurationFactor(), curve: .easeInOut, animations: {
            })
        }
        
        if let _ = self.propertyAnimator {
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                self.displayLinkAnimator = DisplayLinkAnimator(duration: 0.2 * animationDurationFactor * UIView.animationDurationFactor(), from: 0.0, to: 1.0, update: { [weak self] value in
                    (self?.propertyAnimator as? UIViewPropertyAnimator)?.fractionComplete = value
                }, completion: { [weak self] in
                    self?.didCompleteAnimationIn = true
                    self?.hapticFeedback.prepareTap()
                    self?.actionsContainerNode.animateIn()
                })
            }
        } else {
            UIView.animate(withDuration: 0.2 * animationDurationFactor, animations: {
                self.effectView.effect = makeCustomZoomBlurEffect(isLight: self.presentationData.theme.rootController.keyboardColor == .light)
            }, completion: { [weak self] _ in
                self?.didCompleteAnimationIn = true
                self?.actionsContainerNode.animateIn()
            })
        }
        
        if let contentNode = self.contentContainerNode.contentNode {
            switch contentNode {
            case .reference:
                let springDuration: Double = 0.42 * animationDurationFactor
                let springDamping: CGFloat = 104.0
                
                self.actionsContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2 * animationDurationFactor)
                self.actionsContainerNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
                
                if let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
                    let localSourceFrame = self.view.convert(originalProjectedContentViewFrame.1, to: self.scrollNode.view)
                    
                    let localContentSourceFrame = self.view.convert(originalProjectedContentViewFrame.1, to: self.contentContainerNode.view.superview)
                    
                    self.actionsContainerNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: localSourceFrame.center.x - self.actionsContainerNode.position.x, y: localSourceFrame.center.y - self.actionsContainerNode.position.y)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, additive: true)
                    let contentContainerOffset = CGPoint(x: localContentSourceFrame.center.x - self.contentContainerNode.frame.center.x, y: localContentSourceFrame.center.y - self.contentContainerNode.frame.center.y)
                    self.contentContainerNode.layer.animateSpring(from: NSValue(cgPoint: contentContainerOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, additive: true, completion: { [weak self] _ in
                        self?.animatedIn = true
                    })
                }
            case .extractedContainer:
                break
            case let .extracted(extracted, keepInPlace):
                let springDuration: Double = 0.42 * animationDurationFactor
                var springDamping: CGFloat = 104.0
                if case let .extracted(source) = self.legacySource, source.centerVertically {
                    springDamping = 124.0
                }
                
                self.actionsContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2 * animationDurationFactor)
                self.actionsContainerNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
                 
                if let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
                    let contentParentNode = extracted
                    let localSourceFrame = self.view.convert(originalProjectedContentViewFrame.1, to: self.scrollNode.view)
                   
                    var actionsDuration = springDuration
                    var actionsOffset: CGFloat = 0.0
                    var contentDuration = springDuration
                    if case let .extracted(source) = self.legacySource, source.centerVertically {
                        actionsOffset = -(originalProjectedContentViewFrame.1.height - originalProjectedContentViewFrame.0.height) * 0.57
                        actionsDuration *= 1.0
                        contentDuration *= 0.9
                    }
                    
                    let localContentSourceFrame: CGRect
                    if keepInPlace {
                        localContentSourceFrame = self.view.convert(originalProjectedContentViewFrame.1, to: self.contentContainerNode.view.superview)
                    } else {
                        localContentSourceFrame = localSourceFrame
                    }
                    
                    self.actionsContainerNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: localSourceFrame.center.x - self.actionsContainerNode.position.x, y: localSourceFrame.center.y - self.actionsContainerNode.position.y + actionsOffset)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: actionsDuration, initialVelocity: 0.0, damping: springDamping, additive: true)
                    let contentContainerOffset = CGPoint(x: localContentSourceFrame.center.x - self.contentContainerNode.frame.center.x - contentParentNode.contentRect.minX, y: localContentSourceFrame.center.y - self.contentContainerNode.frame.center.y - contentParentNode.contentRect.minY)
                    self.contentContainerNode.layer.animateSpring(from: NSValue(cgPoint: contentContainerOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: contentDuration, initialVelocity: 0.0, damping: springDamping, additive: true, completion: { [weak self] _ in
                        self?.clippingNode.view.mask = nil
                        self?.animatedIn = true
                    })
                    contentParentNode.applyAbsoluteOffsetSpring?(-contentContainerOffset.y, springDuration, springDamping)
                }
                
                extracted.willUpdateIsExtractedToContextPreview?(true, .animated(duration: 0.2, curve: .easeInOut))
            case .controller:
                let springDuration: Double = 0.52 * animationDurationFactor
                let springDamping: CGFloat = 110.0
                
                self.actionsContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2 * animationDurationFactor)
                self.actionsContainerNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
                self.contentContainerNode.allowsGroupOpacity = true
                self.contentContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2 * animationDurationFactor, completion: { [weak self] _ in
                    self?.contentContainerNode.allowsGroupOpacity = false
                })
                
                if let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
                    let localSourceFrame = self.view.convert(CGRect(origin: CGPoint(x: originalProjectedContentViewFrame.1.minX, y: originalProjectedContentViewFrame.1.minY), size: CGSize(width: originalProjectedContentViewFrame.1.width, height: originalProjectedContentViewFrame.1.height)), to: self.scrollNode.view)
                    
                    self.contentContainerNode.layer.animateSpring(from: min(localSourceFrame.width / self.contentContainerNode.frame.width, localSourceFrame.height / self.contentContainerNode.frame.height) as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
                    
                    switch self.legacySource {
                    case let .controller(controller):
                        controller.animatedIn()
                    default:
                        break
                    }
                    
                    let contentContainerOffset = CGPoint(x: localSourceFrame.center.x - self.contentContainerNode.frame.center.x, y: localSourceFrame.center.y - self.contentContainerNode.frame.center.y)
                    if let contentNode = self.contentContainerNode.contentNode, case let .controller(controller) = contentNode {
                        let snapshotView: UIView? = nil// controller.sourceNode.view.snapshotContentTree()
                        if let snapshotView = snapshotView {
                            controller.sourceView.isHidden = true
                            
                            self.view.insertSubview(snapshotView, belowSubview: self.contentContainerNode.view)
                            snapshotView.layer.animateSpring(from: NSValue(cgPoint: localSourceFrame.center), to: NSValue(cgPoint: CGPoint(x: self.contentContainerNode.frame.midX, y: self.contentContainerNode.frame.minY + localSourceFrame.height / 2.0)), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, removeOnCompletion: false)
                            //snapshotView.layer.animateSpring(from: 1.0 as NSNumber, to: (self.contentContainerNode.frame.width / localSourceFrame.width) as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping, removeOnCompletion: false)
                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2 * animationDurationFactor, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                        }
                    }
                    self.actionsContainerNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: localSourceFrame.center.x - self.actionsContainerNode.position.x, y: localSourceFrame.center.y - self.actionsContainerNode.position.y)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, additive: true)
                    self.contentContainerNode.layer.animateSpring(from: NSValue(cgPoint: contentContainerOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, additive: true, completion: { [weak self] _ in
                        self?.animatedIn = true
                    })
                }
            }
        }
    }
    
    private var delayLayoutUpdate = false
    func animateOut(result initialResult: ContextMenuActionResult, completion: @escaping () -> Void) {
        self.isUserInteractionEnabled = false
        
        self.beganAnimatingOut()
        
        if let sourceContainer = self.sourceContainer {
            sourceContainer.animateOut(result: initialResult, completion: completion)
            return
        }
        
        var transitionDuration: Double = 0.2
        var transitionCurve: ContainedViewLayoutTransitionCurve = .easeInOut
        
        var result = initialResult
        
        switch self.legacySource {
        case let .location(source):
            let transitionInfo = source.transitionInfo()
            if transitionInfo == nil {
                result = .dismissWithoutContent
            }
            
            switch result {
            case let .custom(value):
                switch value {
                case let .animated(duration, curve):
                    transitionDuration = duration
                    transitionCurve = curve
                default:
                    break
                }
            default:
                break
            }
            
            self.isUserInteractionEnabled = false
            self.isAnimatingOut = true
            
            self.scrollNode.view.setContentOffset(self.scrollNode.view.contentOffset, animated: false)
                                                
            if !self.dimNode.isHidden {
                self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * animationDurationFactor, removeOnCompletion: false)
            } else {
                self.withoutBlurDimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * animationDurationFactor, removeOnCompletion: false)
            }
            
            self.actionsContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15 * animationDurationFactor, removeOnCompletion: false, completion: { _ in
                completion()
            })
            self.actionsContainerNode.layer.animateScale(from: 1.0, to: 0.1, duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
            
            let animateOutToItem: Bool
            switch result {
            case .default, .custom:
                animateOutToItem = true
            case .dismissWithoutContent:
                animateOutToItem = false
            }
            
            if animateOutToItem, let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
                let localSourceFrame = self.view.convert(originalProjectedContentViewFrame.1, to: self.scrollNode.view)
                self.actionsContainerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: localSourceFrame.center.x - self.actionsContainerNode.position.x, y: localSourceFrame.center.y - self.actionsContainerNode.position.y), duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false, additive: true)
            }
        case let .reference(source):
            guard let maybeContentNode = self.contentContainerNode.contentNode, case let .reference(referenceView) = maybeContentNode else {
                return
            }
            
            let transitionInfo = source.transitionInfo()
            if transitionInfo == nil {
                result = .dismissWithoutContent
            }
            
            switch result {
            case let .custom(value):
                switch value {
                case let .animated(duration, curve):
                    transitionDuration = duration
                    transitionCurve = curve
                default:
                    break
                }
            default:
                break
            }
            
            self.isUserInteractionEnabled = false
            self.isAnimatingOut = true
            
            self.scrollNode.view.setContentOffset(self.scrollNode.view.contentOffset, animated: false)
            
            if let transitionInfo = transitionInfo, let parentSuperview = referenceView.superview {
                self.originalProjectedContentViewFrame = (convertFrame(referenceView.frame, from: parentSuperview, to: self.view), convertFrame(referenceView.bounds, from: referenceView, to: self.view))
                
                var updatedContentAreaInScreenSpace = transitionInfo.contentAreaInScreenSpace
                updatedContentAreaInScreenSpace.origin.x = 0.0
                updatedContentAreaInScreenSpace.size.width = self.bounds.width
                
                self.clippingNode.layer.animateFrame(from: self.clippingNode.frame, to: updatedContentAreaInScreenSpace, duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
                self.clippingNode.layer.animateBoundsOriginYAdditive(from: 0.0, to: updatedContentAreaInScreenSpace.minY, duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
            }
                                    
            if !self.dimNode.isHidden {
                self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * animationDurationFactor, removeOnCompletion: false)
            } else {
                self.withoutBlurDimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * animationDurationFactor, removeOnCompletion: false)
            }
            
            self.actionsContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15 * animationDurationFactor, removeOnCompletion: false, completion: { _ in
                completion()
            })
            self.actionsContainerNode.layer.animateScale(from: 1.0, to: 0.1, duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
            
            let animateOutToItem: Bool
            switch result {
            case .default, .custom:
                animateOutToItem = true
            case .dismissWithoutContent:
                animateOutToItem = false
            }
            
            if animateOutToItem, let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
                let localSourceFrame = self.view.convert(originalProjectedContentViewFrame.1, to: self.scrollNode.view)
                self.actionsContainerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: localSourceFrame.center.x - self.actionsContainerNode.position.x, y: localSourceFrame.center.y - self.actionsContainerNode.position.y), duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false, additive: true)
            }
        case let .extracted(source):
            guard let maybeContentNode = self.contentContainerNode.contentNode, case let .extracted(contentParentNode, keepInPlace) = maybeContentNode else {
                return
            }
            
            let putBackInfo = source.putBack()
            
            if putBackInfo == nil {
                result = .dismissWithoutContent
            }
            
            switch result {
            case let .custom(value):
                switch value {
                case let .animated(duration, curve):
                    transitionDuration = duration
                    transitionCurve = curve
                default:
                    break
                }
            default:
                break
            }
            
            self.isUserInteractionEnabled = false
            self.isAnimatingOut = true
            
            self.scrollNode.view.setContentOffset(self.scrollNode.view.contentOffset, animated: false)
            
            var completedEffect = false
            var completedContentNode = false
            var completedActionsNode = false
            
            if let putBackInfo = putBackInfo, let parentSupernode = contentParentNode.supernode {
                self.originalProjectedContentViewFrame = (convertFrame(contentParentNode.frame, from: parentSupernode.view, to: self.view), convertFrame(contentParentNode.contentRect, from: contentParentNode.view, to: self.view))
                
                var updatedContentAreaInScreenSpace = putBackInfo.contentAreaInScreenSpace
                updatedContentAreaInScreenSpace.origin.x = 0.0
                updatedContentAreaInScreenSpace.size.width = self.bounds.width
                
                self.clippingNode.view.mask = putBackInfo.maskView
                let previousFrame = self.clippingNode.frame
                self.clippingNode.position = updatedContentAreaInScreenSpace.center
                self.clippingNode.bounds = CGRect(origin: CGPoint(), size: updatedContentAreaInScreenSpace.size)
                self.clippingNode.layer.animatePosition(from: previousFrame.center, to: updatedContentAreaInScreenSpace.center, duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: true)
                self.clippingNode.layer.animateBounds(from: CGRect(origin: CGPoint(), size: previousFrame.size), to: CGRect(origin: CGPoint(), size: updatedContentAreaInScreenSpace.size), duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: true)
                //self.clippingNode.layer.animateFrame(from: previousFrame, to: updatedContentAreaInScreenSpace, duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
                //self.clippingNode.layer.animateBoundsOriginYAdditive(from: 0.0, to: updatedContentAreaInScreenSpace.minY, duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
            }
            
            let intermediateCompletion: () -> Void = { [weak self, weak contentParentNode] in
                if completedEffect && completedContentNode && completedActionsNode {
                    switch result {
                    case .default, .custom:
                        if let contentParentNode = contentParentNode {
                            contentParentNode.addSubnode(contentParentNode.contentNode)
                            contentParentNode.isExtractedToContextPreview = false
                            contentParentNode.isExtractedToContextPreviewUpdated?(false)
                        }
                    case .dismissWithoutContent:
                        break
                    }
                    
                    self?.clippingNode.view.mask = nil
                    
                    completion()
                }
            }
            
            if #available(iOS 10.0, *) {
                if let propertyAnimator = self.propertyAnimator {
                    let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                    propertyAnimator?.stopAnimation(true)
                }
                self.propertyAnimator = UIViewPropertyAnimator(duration: transitionDuration * UIView.animationDurationFactor(), curve: .easeInOut, animations: {
                    //self?.effectView.effect = nil
                })
            }
            
            if let _ = self.propertyAnimator {
                if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                    self.displayLinkAnimator = DisplayLinkAnimator(duration: 0.2 * animationDurationFactor * UIView.animationDurationFactor(), from: 0.0, to: 0.999, update: { [weak self] value in
                        (self?.propertyAnimator as? UIViewPropertyAnimator)?.fractionComplete = value
                    }, completion: {
                        completedEffect = true
                        intermediateCompletion()
                    })
                }
                self.effectView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2 * animationDurationFactor, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false)
            } else {
                UIView.animate(withDuration: 0.21 * animationDurationFactor, animations: {
                    if #available(iOS 9.0, *) {
                        self.effectView.effect = nil
                    } else {
                        self.effectView.alpha = 0.0
                    }
                }, completion: { _ in
                    completedEffect = true
                    intermediateCompletion()
                })
            }
            
            if !self.dimNode.isHidden {
                self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * animationDurationFactor, removeOnCompletion: false)
            } else {
                self.withoutBlurDimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * animationDurationFactor, removeOnCompletion: false)
            }
            
            self.actionsContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15 * animationDurationFactor, removeOnCompletion: false, completion: { _ in
                completedActionsNode = true
                intermediateCompletion()
            })
            self.actionsContainerNode.layer.animateScale(from: 1.0, to: 0.1, duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
            
            let animateOutToItem: Bool
            switch result {
            case .default, .custom:
                animateOutToItem = true
            case .dismissWithoutContent:
                animateOutToItem = false
            }
            
            if animateOutToItem, let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
                let localSourceFrame = self.view.convert(originalProjectedContentViewFrame.1, to: self.scrollNode.view)
                let localContentSourceFrame: CGRect
                if keepInPlace {
                    localContentSourceFrame = self.view.convert(originalProjectedContentViewFrame.1, to: self.contentContainerNode.view.superview)
                } else {
                    localContentSourceFrame = localSourceFrame
                }
                
                var actionsOffset: CGFloat = 0.0
                if case let .extracted(source) = self.legacySource, source.centerVertically {
                    actionsOffset = -localSourceFrame.width * 0.6
                }
                
                self.actionsContainerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: localSourceFrame.center.x - self.actionsContainerNode.position.x, y: localSourceFrame.center.y - self.actionsContainerNode.position.y + actionsOffset), duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false, additive: true)
                let contentContainerOffset = CGPoint(x: localContentSourceFrame.center.x - self.contentContainerNode.frame.center.x - contentParentNode.contentRect.minX, y: localContentSourceFrame.center.y - self.contentContainerNode.frame.center.y - contentParentNode.contentRect.minY)
                self.contentContainerNode.layer.animatePosition(from: CGPoint(), to: contentContainerOffset, duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false, additive: true, completion: { _ in
                    completedContentNode = true
                    intermediateCompletion()
                })
                contentParentNode.updateAbsoluteRect?(self.contentContainerNode.frame.offsetBy(dx: 0.0, dy: -self.scrollNode.view.contentOffset.y + contentContainerOffset.y), self.bounds.size)
                contentParentNode.applyAbsoluteOffset?(CGPoint(x: 0.0, y: -contentContainerOffset.y), transitionCurve, transitionDuration)
                
                contentParentNode.willUpdateIsExtractedToContextPreview?(false, .animated(duration: 0.2, curve: .easeInOut))
            } else {
                if let snapshotView = contentParentNode.contentNode.view.snapshotContentTree(keepTransform: true) {
                    self.contentContainerNode.view.addSubview(snapshotView)
                }
                
                contentParentNode.addSubnode(contentParentNode.contentNode)
                contentParentNode.isExtractedToContextPreview = false
                contentParentNode.isExtractedToContextPreviewUpdated?(false)
                
                self.contentContainerNode.allowsGroupOpacity = true
                self.contentContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * animationDurationFactor, removeOnCompletion: false, completion: { _ in
                    completedContentNode = true
                    intermediateCompletion()
                })
                
                contentParentNode.contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                contentParentNode.willUpdateIsExtractedToContextPreview?(false, .animated(duration: 0.2, curve: .easeInOut))
            }
        case let .controller(source):
            guard let maybeContentNode = self.contentContainerNode.contentNode, case let .controller(controller) = maybeContentNode else {
                return
            }
            
            let transitionInfo = source.transitionInfo()
            
            if transitionInfo == nil {
                result = .dismissWithoutContent
            }
            
            switch result {
            case let .custom(value):
                switch value {
                case let .animated(duration, curve):
                    transitionDuration = duration
                    transitionCurve = curve
                default:
                    break
                }
            default:
                break
            }
            
            self.isUserInteractionEnabled = false
            self.isAnimatingOut = true
            
            self.scrollNode.view.setContentOffset(self.scrollNode.view.contentOffset, animated: false)
            
            var completedEffect = false
            var completedContentNode = false
            var completedActionsNode = false
            
            if let transitionInfo = transitionInfo, let (sourceView, sourceNodeRect) = transitionInfo.sourceNode() {
                let projectedFrame = convertFrame(sourceNodeRect, from: sourceView, to: self.view)
                self.originalProjectedContentViewFrame = (projectedFrame, projectedFrame)
                
                var updatedContentAreaInScreenSpace = transitionInfo.contentAreaInScreenSpace
                updatedContentAreaInScreenSpace.origin.x = 0.0
                updatedContentAreaInScreenSpace.size.width = self.bounds.width
            }
            
            let intermediateCompletion: () -> Void = {
                if completedEffect && completedContentNode && completedActionsNode {
                    switch result {
                    case .default, .custom:
                        break
                    case .dismissWithoutContent:
                        break
                    }
                    
                    completion()
                }
            }
            
            if #available(iOS 10.0, *) {
                if let propertyAnimator = self.propertyAnimator {
                    let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                    propertyAnimator?.stopAnimation(true)
                }
                self.propertyAnimator = UIViewPropertyAnimator(duration: transitionDuration * UIView.animationDurationFactor(), curve: .easeInOut, animations: { [weak self] in
                    self?.effectView.effect = nil
                })
            }
            
            if let _ = self.propertyAnimator {
                if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                    self.displayLinkAnimator = DisplayLinkAnimator(duration: 0.2 * animationDurationFactor * UIView.animationDurationFactor(), from: 0.0, to: 0.999, update: { [weak self] value in
                        (self?.propertyAnimator as? UIViewPropertyAnimator)?.fractionComplete = value
                    }, completion: {
                        completedEffect = true
                        intermediateCompletion()
                    })
                }
                self.effectView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.05 * animationDurationFactor, delay: 0.15, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false)
            } else {
                UIView.animate(withDuration: 0.21 * animationDurationFactor, animations: {
                    if #available(iOS 9.0, *) {
                        self.effectView.effect = nil
                    } else {
                        self.effectView.alpha = 0.0
                    }
                }, completion: { _ in
                    completedEffect = true
                    intermediateCompletion()
                })
            }
            
            if !self.dimNode.isHidden {
                self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * animationDurationFactor, removeOnCompletion: false)
            } else {
                self.withoutBlurDimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * animationDurationFactor, removeOnCompletion: false)
            }
            self.actionsContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2 * animationDurationFactor, removeOnCompletion: false, completion: { _ in
                completedActionsNode = true
                intermediateCompletion()
            })
            self.contentContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2 * animationDurationFactor, removeOnCompletion: false, completion: { _ in
            })
            self.actionsContainerNode.layer.animateScale(from: 1.0, to: 0.1, duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
            self.contentContainerNode.layer.animateScale(from: 1.0, to: 0.01, duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
            
            let animateOutToItem: Bool
            switch result {
            case .default, .custom:
                animateOutToItem = true
            case .dismissWithoutContent:
                animateOutToItem = false
            }
            
            if animateOutToItem, let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
                let localSourceFrame = self.view.convert(CGRect(origin: CGPoint(x: originalProjectedContentViewFrame.1.minX, y: originalProjectedContentViewFrame.1.minY), size: CGSize(width: originalProjectedContentViewFrame.1.width, height: originalProjectedContentViewFrame.1.height)), to: self.scrollNode.view)
                
                self.actionsContainerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: localSourceFrame.center.x - self.actionsContainerNode.position.x, y: localSourceFrame.center.y - self.actionsContainerNode.position.y), duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false, additive: true)
                let contentContainerOffset = CGPoint(x: localSourceFrame.center.x - self.contentContainerNode.frame.center.x, y: localSourceFrame.center.y - self.contentContainerNode.frame.center.y)
                self.contentContainerNode.layer.animatePosition(from: CGPoint(), to: contentContainerOffset, duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false, additive: true, completion: { [weak self] _ in
                    completedContentNode = true
                    if let strongSelf = self, let contentNode = strongSelf.contentContainerNode.contentNode, case let .controller(controller) = contentNode {
                        controller.sourceView.isHidden = false
                    }
                    intermediateCompletion()
                })
            } else {
                if let contentNode = self.contentContainerNode.contentNode, case let .controller(controller) = contentNode {
                    controller.sourceView.isHidden = false
                }
                
                if let snapshotView = controller.view.snapshotContentTree(keepTransform: true) {
                    self.contentContainerNode.view.addSubview(snapshotView)
                }
                
                self.contentContainerNode.allowsGroupOpacity = true
                self.contentContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * animationDurationFactor, removeOnCompletion: false, completion: { _ in
                    completedContentNode = true
                    intermediateCompletion()
                })
            }
        }
    }
    
    func addRelativeContentOffset(_ offset: CGPoint, transition: ContainedViewLayoutTransition) {
        if let sourceContainer = self.sourceContainer {
            sourceContainer.addRelativeContentOffset(offset, transition: transition)
        }
    }
    
    func cancelReactionAnimation() {
        if let sourceContainer = self.sourceContainer {
            sourceContainer.cancelReactionAnimation()
        }
    }
    
    func animateOutToReaction(value: MessageReaction.Reaction, targetView: UIView, hideNode: Bool, animateTargetContainer: UIView?, addStandaloneReactionAnimation: ((StandaloneReactionAnimation) -> Void)?, reducedCurve: Bool, onHit: (() -> Void)?, completion: @escaping () -> Void) {
        if let sourceContainer = self.sourceContainer {
            sourceContainer.animateOutToReaction(value: value, targetView: targetView, hideNode: hideNode, animateTargetContainer: animateTargetContainer, addStandaloneReactionAnimation: addStandaloneReactionAnimation, reducedCurve: reducedCurve, onHit: onHit, completion: completion)
        }
    }

    func animateDismissalIfNeeded() {
        guard let layout = self.validLayout, layout.metrics.isTablet else {
            return
        }
        if let sourceContainer = self.sourceContainer {
            sourceContainer.animateOut(result: .dismissWithoutContent, completion: {})
            return
        }
    }
    
    func getActionsMinHeight() -> ContextController.ActionsHeight? {
        if !self.actionsContainerNode.bounds.height.isZero {
            return ContextController.ActionsHeight(
                minY: self.actionsContainerNode.frame.minY,
                contentOffset: self.scrollNode.view.contentOffset.y
            )
        } else {
            return nil
        }
    }
    
    func setItemsSignal(items: Signal<ContextController.Items, NoError>, minHeight: ContextController.ActionsHeight?, previousActionsTransition: ContextController.PreviousActionsTransition, animated: Bool) {
        if let sourceContainer = self.sourceContainer {
            sourceContainer.setItems(items: items, animated: animated)
        } else {
            self.legacyItems = items
            self.itemsDisposable.set((items
            |> deliverOnMainQueue).start(next: { [weak self] items in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.setItems(items: items, minHeight: minHeight, previousActionsTransition: previousActionsTransition)
            }))
        }
    }
    
    private func setItems(items: ContextController.Items, minHeight: ContextController.ActionsHeight?, previousActionsTransition: ContextController.PreviousActionsTransition) {
        if let sourceContainer = self.sourceContainer {
            let disableAnimations = self.getController()?.immediateItemsTransitionAnimation == true
            sourceContainer.setItems(items: .single(items), animated: !disableAnimations)
            
            if !self.didSetItemsReady {
                self.didSetItemsReady = true
                self.itemsReady.set(.single(true))
            }
            return
        }
        
        if let _ = self.currentItems, !self.didCompleteAnimationIn && self.getController()?.immediateItemsTransitionAnimation == true {
            return
        }
        
        self.currentItems = items
        self.currentActionsMinHeight = minHeight

        let previousActionsContainerNode = self.actionsContainerNode
        let previousActionsContainerFrame = previousActionsContainerNode.view.convert(previousActionsContainerNode.bounds, to: self.view)
        self.actionsContainerNode = ContextActionsContainerNode(presentationData: self.presentationData, items: items, getController: { [weak self] in
            return self?.getController()
        }, actionSelected: { [weak self] result in
            self?.beginDismiss(result)
        }, requestLayout: { [weak self] in
            self?.updateLayout()
        }, feedbackTap: { [weak self] in
            self?.hapticFeedback.tap()
        }, blurBackground: self.blurBackground)
        self.scrollNode.insertSubnode(self.actionsContainerNode, aboveSubnode: previousActionsContainerNode)
        
        if let layout = self.validLayout {
            self.updateLayout(layout: layout, transition: self.didSetItemsReady ? .animated(duration: 0.3, curve: .spring) : .immediate, previousActionsContainerNode: previousActionsContainerNode, previousActionsContainerFrame: previousActionsContainerFrame, previousActionsTransition: previousActionsTransition)
        } else {
            previousActionsContainerNode.removeFromSupernode()
        }
        
        if !self.didSetItemsReady {
            self.didSetItemsReady = true
            self.itemsReady.set(.single(true))
        }
    }
    
    func pushItems(items: Signal<ContextController.Items, NoError>) {
        if let sourceContainer = self.sourceContainer {
            sourceContainer.pushItems(items: items)
        }
    }
    
    func popItems() {
        if let sourceContainer = self.sourceContainer {
            sourceContainer.popItems()
        }
    }
    
    func updateTheme(presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.dimNode.backgroundColor = presentationData.theme.contextMenu.dimColor
        self.actionsContainerNode.updateTheme(presentationData: presentationData)
        
        if let validLayout = self.validLayout {
            self.updateLayout(layout: validLayout, transition: .immediate, previousActionsContainerNode: nil, previousActionsContainerFrame: nil)
        }
    }

    func updateLayout() {
        if let layout = self.validLayout {
            self.updateLayout(layout: layout, transition: .immediate, previousActionsContainerNode: nil)
        }
    }
    
    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition, previousActionsContainerNode: ContextActionsContainerNode?, previousActionsContainerFrame: CGRect? = nil, previousActionsTransition: ContextController.PreviousActionsTransition = .scale) {
        if self.isAnimatingOut || self.delayLayoutUpdate {
            return
        }
        
        self.validLayout = layout
        
        if let sourceContainer = self.sourceContainer {
            transition.updateFrame(node: sourceContainer, frame: CGRect(origin: CGPoint(), size: layout.size))
            sourceContainer.update(
                presentationData: self.presentationData,
                layout: layout,
                transition: transition
            )
            return
        }
        
        var actionsContainerTransition = transition
        if previousActionsContainerNode != nil {
            actionsContainerTransition = .immediate
        }
        
        transition.updateFrame(view: self.effectView, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.withoutBlurDimNode, frame: CGRect(origin: CGPoint(), size: layout.size))

        switch layout.metrics.widthClass {
        case .compact:
            if case .reference = self.legacySource {
            } else if case let .extracted(extractedSource) = self.legacySource, !extractedSource.blurBackground {
            } else if self.effectView.superview == nil {
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
            if case .reference = self.legacySource {
            } else if case let .extracted(extractedSource) = self.legacySource, !extractedSource.blurBackground {
            } else if self.effectView.superview != nil {
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
        
        if let contentNode = self.contentContainerNode.contentNode {
            switch contentNode {
            case let .reference(referenceNode):
                let contentActionsSpacing: CGFloat = 8.0
                if let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
                    let isInitialLayout = self.actionsContainerNode.frame.size.width.isZero
                    let previousContainerFrame = self.view.convert(self.contentContainerNode.frame, from: self.scrollNode.view)
                    
                    let realActionsSize = self.actionsContainerNode.updateLayout(widthClass: layout.metrics.widthClass, presentation: .inline, constrainedWidth: layout.size.width - actionsSideInset * 2.0, constrainedHeight: layout.size.height, transition: actionsContainerTransition)
                    let adjustedActionsSize = realActionsSize

                    self.actionsContainerNode.updateSize(containerSize: realActionsSize, contentSize: realActionsSize)
                    let contentSize = originalProjectedContentViewFrame.1.size
                    self.contentContainerNode.updateLayout(size: contentSize, scaledSize: contentSize, transition: transition)
                    
                    let maximumActionsFrameOrigin = max(60.0, layout.size.height - layout.intrinsicInsets.bottom - actionsBottomInset - adjustedActionsSize.height)
                     
                    let originalActionsY = min(originalProjectedContentViewFrame.1.maxY + contentActionsSpacing, maximumActionsFrameOrigin)
                    let preferredActionsX = originalProjectedContentViewFrame.1.minX
                    
                    var originalActionsFrame = CGRect(origin: CGPoint(x: max(actionsSideInset, min(layout.size.width - adjustedActionsSize.width - actionsSideInset, preferredActionsX)), y: originalActionsY), size: realActionsSize)
                    let originalContentX: CGFloat = originalProjectedContentViewFrame.1.minX
                    let originalContentY = originalProjectedContentViewFrame.1.minY

                    var originalContentFrame = CGRect(origin: CGPoint(x: originalContentX, y: originalContentY), size: originalProjectedContentViewFrame.1.size)
                    let topEdge = max(contentTopInset, self.contentAreaInScreenSpace?.minY ?? 0.0)
                    let bottomEdge = min(layout.size.height - layout.intrinsicInsets.bottom, self.contentAreaInScreenSpace?.maxY ?? layout.size.height)
                    
                    if originalContentFrame.minY < topEdge {
                        let requiredOffset = topEdge - originalContentFrame.minY
                        let availableOffset = max(0.0, layout.size.height - layout.intrinsicInsets.bottom - actionsBottomInset - originalActionsFrame.maxY)
                        let offset = min(requiredOffset, availableOffset)
                        originalActionsFrame = originalActionsFrame.offsetBy(dx: 0.0, dy: offset)
                        originalContentFrame = originalContentFrame.offsetBy(dx: 0.0, dy: offset)
                    } else if originalActionsFrame.maxY > bottomEdge {
                        let requiredOffset = bottomEdge - originalActionsFrame.maxY
                        let offset = requiredOffset
                        originalActionsFrame = originalActionsFrame.offsetBy(dx: 0.0, dy: offset)
                        originalContentFrame = originalContentFrame.offsetBy(dx: 0.0, dy: offset)
                    }
                    
                    var contentHeight = max(layout.size.height, max(layout.size.height, originalActionsFrame.maxY + actionsBottomInset) - originalContentFrame.minY + contentTopInset)
                    contentHeight = max(contentHeight, adjustedActionsSize.height + originalActionsFrame.minY + actionsBottomInset)
                    
                    var overflowOffset: CGFloat
                    var contentContainerFrame: CGRect

                    overflowOffset = min(0.0, originalActionsFrame.minY - contentTopInset)
                    let contentParentNode = referenceNode
                    contentContainerFrame = originalContentFrame
                    if !overflowOffset.isZero {
                        let offsetDelta = contentParentNode.frame.height + 4.0
                        overflowOffset += offsetDelta
                        overflowOffset = min(0.0, overflowOffset)
                        
                        originalActionsFrame.origin.x -= contentParentNode.frame.width + 14.0
                        originalActionsFrame.origin.x = max(actionsSideInset, originalActionsFrame.origin.x)
                        
                        if originalActionsFrame.minX < contentContainerFrame.minX {
                            contentContainerFrame.origin.x = min(originalActionsFrame.maxX + 14.0, layout.size.width - actionsSideInset)
                        }
                        originalActionsFrame.origin.y += offsetDelta
                        if originalActionsFrame.maxY < originalContentFrame.maxY {
                            originalActionsFrame.origin.y += contentParentNode.frame.height
                            originalActionsFrame.origin.y = min(originalActionsFrame.origin.y, layout.size.height - originalActionsFrame.height - actionsBottomInset)
                        }
                        contentHeight -= offsetDelta
                    }
                    
                    if let customPosition = self.customPosition {
                        originalActionsFrame.origin.x = floor(originalContentFrame.center.x - originalActionsFrame.width / 2.0) + customPosition.x
                        originalActionsFrame.origin.y = floor(originalContentFrame.center.y - originalActionsFrame.height / 2.0) + customPosition.y
                    }

                    let scrollContentSize = CGSize(width: layout.size.width, height: contentHeight)
                    if self.scrollNode.view.contentSize != scrollContentSize {
                        self.scrollNode.view.contentSize = scrollContentSize
                    }
                    self.actionsContainerNode.panSelectionGestureEnabled = scrollContentSize.height <= layout.size.height
                    
                    transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
                    actionsContainerTransition.updateFrame(node: self.actionsContainerNode, frame: originalActionsFrame.offsetBy(dx: 0.0, dy: -overflowOffset))
                    
                    if isInitialLayout {
                        let currentContainerFrame = self.view.convert(self.contentContainerNode.frame, from: self.scrollNode.view)
                        if overflowOffset < 0.0 {
                            transition.animateOffsetAdditive(node: self.scrollNode, offset: currentContainerFrame.minY - previousContainerFrame.minY)
                        }
                    }
                }
            case .extractedContainer:
                break
            case let .extracted(contentParentNode, keepInPlace):
                var centerVertically = false
                if case let .extracted(source) = self.legacySource, source.centerVertically {
                    centerVertically = true
                }
                let contentActionsSpacing: CGFloat = keepInPlace ? 16.0 : 8.0
                if let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
                    let isInitialLayout = self.actionsContainerNode.frame.size.width.isZero
                    let previousContainerFrame = self.view.convert(self.contentContainerNode.frame, from: self.scrollNode.view)
                    
                    let constrainedActionsHeight: CGFloat
                    let constrainedActionsBottomInset: CGFloat
                    if let currentActionsMinHeight = self.currentActionsMinHeight {
                        constrainedActionsBottomInset = actionsBottomInset + layout.intrinsicInsets.bottom
                        constrainedActionsHeight = layout.size.height - currentActionsMinHeight.minY - constrainedActionsBottomInset
                    } else {
                        constrainedActionsHeight = layout.size.height
                        constrainedActionsBottomInset = 0.0
                    }
                    
                    let realActionsSize = self.actionsContainerNode.updateLayout(widthClass: layout.metrics.widthClass, presentation: .inline, constrainedWidth: layout.size.width - actionsSideInset * 2.0, constrainedHeight: constrainedActionsHeight, transition: actionsContainerTransition)
                    let adjustedActionsSize = realActionsSize

                    self.actionsContainerNode.updateSize(containerSize: realActionsSize, contentSize: realActionsSize)
                    let contentSize = originalProjectedContentViewFrame.1.size
                    self.contentContainerNode.updateLayout(size: contentSize, scaledSize: contentSize, transition: transition)
                    
                    let maximumActionsFrameOrigin = max(60.0, layout.size.height - layout.intrinsicInsets.bottom - actionsBottomInset - adjustedActionsSize.height)
                    let preferredActionsX: CGFloat
                    var originalActionsY: CGFloat
                    if centerVertically {
                        originalActionsY = min(originalProjectedContentViewFrame.1.maxY + contentActionsSpacing, maximumActionsFrameOrigin)
                        preferredActionsX = originalProjectedContentViewFrame.1.maxX - adjustedActionsSize.width
                    } else if keepInPlace {
                        originalActionsY = originalProjectedContentViewFrame.1.minY - contentActionsSpacing - adjustedActionsSize.height
                        preferredActionsX = max(actionsSideInset, originalProjectedContentViewFrame.1.maxX - adjustedActionsSize.width)
                    } else {
                        originalActionsY = min(originalProjectedContentViewFrame.1.maxY + contentActionsSpacing, maximumActionsFrameOrigin)
                        preferredActionsX = originalProjectedContentViewFrame.1.minX
                    }

                    if let currentActionsMinHeight = self.currentActionsMinHeight {
                        originalActionsY = currentActionsMinHeight.minY
                    }

                    var originalActionsFrame = CGRect(origin: CGPoint(x: max(actionsSideInset, min(layout.size.width - adjustedActionsSize.width - actionsSideInset, preferredActionsX)), y: originalActionsY), size: realActionsSize)
                    let originalContentX: CGFloat = originalProjectedContentViewFrame.1.minX
                    let originalContentY: CGFloat
                    if keepInPlace {
                        originalContentY = originalProjectedContentViewFrame.1.minY
                    } else {
                        originalContentY = originalActionsFrame.minY - contentActionsSpacing - originalProjectedContentViewFrame.1.size.height
                    }
                    var originalContentFrame = CGRect(origin: CGPoint(x: originalContentX, y: originalContentY), size: originalProjectedContentViewFrame.1.size)
                    let topEdge = max(contentTopInset, self.contentAreaInScreenSpace?.minY ?? 0.0)
                    if originalContentFrame.minY < topEdge {
                        let requiredOffset = topEdge - originalContentFrame.minY
                        let availableOffset = max(0.0, layout.size.height - layout.intrinsicInsets.bottom - actionsBottomInset - originalActionsFrame.maxY)
                        let offset = min(requiredOffset, availableOffset)
                        originalActionsFrame = originalActionsFrame.offsetBy(dx: 0.0, dy: offset)
                        originalContentFrame = originalContentFrame.offsetBy(dx: 0.0, dy: offset)
                    }
                    
                    var contentHeight: CGFloat
                    if keepInPlace {
                        contentHeight = max(layout.size.height, max(layout.size.height, originalActionsFrame.maxY + actionsBottomInset) - originalActionsFrame.minY + contentTopInset)
                    } else {
                        if self.currentActionsMinHeight != nil {
                            contentHeight = max(layout.size.height, max(layout.size.height, originalActionsFrame.maxY + actionsBottomInset + layout.intrinsicInsets.bottom))
                        } else {
                            contentHeight = max(layout.size.height, max(layout.size.height, originalActionsFrame.maxY + actionsBottomInset + layout.intrinsicInsets.bottom) - originalContentFrame.minY + contentTopInset)
                        }
                    }
                    
                    var overflowOffset: CGFloat
                    var contentContainerFrame: CGRect
                    if centerVertically {
                        overflowOffset = 0.0
                        if layout.size.width > layout.size.height, case .compact = layout.metrics.widthClass {
                            let totalWidth = originalContentFrame.width + originalActionsFrame.width + contentActionsSpacing
                            contentContainerFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - totalWidth) / 2.0 + originalContentFrame.width * 0.1), y: floor((layout.size.height - originalContentFrame.height) / 2.0)), size: originalContentFrame.size)
                            originalActionsFrame.origin.x = contentContainerFrame.maxX + contentActionsSpacing + 14.0
                            originalActionsFrame.origin.y = contentContainerFrame.origin.y
                            contentHeight = layout.size.height
                        } else {
                            let totalHeight = originalContentFrame.height + originalActionsFrame.height
                            contentContainerFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - originalContentFrame.width) / 2.0), y: floor((layout.size.height - totalHeight) / 2.0)), size: originalContentFrame.size)
                            originalActionsFrame.origin.y = contentContainerFrame.maxY + contentActionsSpacing
                        }
                    } else if keepInPlace {
                        overflowOffset = min(0.0, originalActionsFrame.minY - contentTopInset)
                        contentContainerFrame = originalContentFrame.offsetBy(dx: -contentParentNode.contentRect.minX, dy: -contentParentNode.contentRect.minY)
                        if !overflowOffset.isZero {
                            let offsetDelta = contentParentNode.contentRect.height + 4.0
                            overflowOffset += offsetDelta
                            overflowOffset = min(0.0, overflowOffset)
                            
                            originalActionsFrame.origin.x -= contentParentNode.contentRect.maxX - contentParentNode.contentRect.minX + 14.0
                            originalActionsFrame.origin.x = max(actionsSideInset, originalActionsFrame.origin.x)
                            //originalActionsFrame.origin.y += contentParentNode.contentRect.height
                            if originalActionsFrame.minX < contentContainerFrame.minX {
                                contentContainerFrame.origin.x = min(originalActionsFrame.maxX + 14.0, layout.size.width - actionsSideInset)
                            }
                            originalActionsFrame.origin.y += offsetDelta
                            if originalActionsFrame.maxY < originalContentFrame.maxY {
                                originalActionsFrame.origin.y += contentParentNode.contentRect.height
                                originalActionsFrame.origin.y = min(originalActionsFrame.origin.y, layout.size.height - originalActionsFrame.height - actionsBottomInset)
                            }
                            contentHeight -= offsetDelta
                        }
                    } else {
                        overflowOffset = min(0.0, originalContentFrame.minY - contentTopInset)
                        contentContainerFrame = originalContentFrame.offsetBy(dx: -contentParentNode.contentRect.minX, dy: -overflowOffset - contentParentNode.contentRect.minY)
                        
                        if contentContainerFrame.maxX > layout.size.width {
                            contentContainerFrame = CGRect(origin: CGPoint(x: layout.size.width - contentContainerFrame.width - 11.0, y: contentContainerFrame.minY), size: contentContainerFrame.size)
                        }
                    }
                    
                    let scrollContentSize = CGSize(width: layout.size.width, height: contentHeight)
                    if self.scrollNode.view.contentSize != scrollContentSize {
                        self.scrollNode.view.contentSize = scrollContentSize
                    }
                    self.actionsContainerNode.panSelectionGestureEnabled = scrollContentSize.height <= layout.size.height
                    
                    transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
                    actionsContainerTransition.updateFrame(node: self.actionsContainerNode, frame: originalActionsFrame.offsetBy(dx: 0.0, dy: -overflowOffset))
                    
                    if isInitialLayout {
                        //let previousContentOffset = self.scrollNode.view.contentOffset.y
                        if !keepInPlace {
                            if let currentActionsMinHeight = self.currentActionsMinHeight {
                                self.scrollNode.view.contentOffset = CGPoint(x: 0.0, y: currentActionsMinHeight.contentOffset)
                            } else {
                                self.scrollNode.view.contentOffset = CGPoint(x: 0.0, y: -overflowOffset)
                            }
                        }
                        let currentContainerFrame = self.view.convert(self.contentContainerNode.frame, from: self.scrollNode.view)
                        var offset: CGFloat = 0.0
                        //offset -= previousContentOffset - self.scrollNode.view.contentOffset.y
                        offset += previousContainerFrame.minY - currentContainerFrame.minY
                        transition.animatePositionAdditive(node: self.contentContainerNode, offset: CGPoint(x: 0.0, y: offset))
                        if overflowOffset < 0.0 {
                            let _ = currentContainerFrame
                            let _ = previousContainerFrame
                        }
                    }
                    
                    let absoluteContentRect = contentContainerFrame.offsetBy(dx: 0.0, dy: -self.scrollNode.view.contentOffset.y)
                    
                    contentParentNode.updateAbsoluteRect?(absoluteContentRect, layout.size)
                }
            case let .controller(contentParentNode):
                var projectedFrame: CGRect = convertFrame(contentParentNode.sourceView.bounds, from: contentParentNode.sourceView, to: self.view)
                switch self.legacySource {
                case let .controller(source):
                    let transitionInfo = source.transitionInfo()
                    if let (sourceView, sourceRect) = transitionInfo?.sourceNode() {
                        projectedFrame = convertFrame(sourceRect, from: sourceView, to: self.view)
                    }
                default:
                    break
                }
                self.originalProjectedContentViewFrame = (projectedFrame, projectedFrame)
                
                if let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
                    let contentActionsSpacing: CGFloat = actionsSideInset
                    let topEdge = max(contentTopInset, self.contentAreaInScreenSpace?.minY ?? 0.0)
                    
                    let isInitialLayout = self.actionsContainerNode.frame.size.width.isZero
                    let previousContainerFrame = self.view.convert(self.contentContainerNode.frame, from: self.scrollNode.view)
                    
                    let constrainedWidth: CGFloat
                    if layout.size.width < layout.size.height {
                        constrainedWidth = layout.size.width
                    } else {
                        constrainedWidth = floor(layout.size.width / 2.0)
                    }
                    
                    let actionsSize = self.actionsContainerNode.updateLayout(widthClass: layout.metrics.widthClass, presentation: .inline, constrainedWidth: constrainedWidth - actionsSideInset * 2.0, constrainedHeight: layout.size.height, transition: actionsContainerTransition)
                    let contentScale = (constrainedWidth - actionsSideInset * 2.0) / constrainedWidth
                    var contentUnscaledSize: CGSize
                    if case .compact = layout.metrics.widthClass {
                        self.actionsContainerNode.updateSize(containerSize: actionsSize, contentSize: actionsSize)
                        
                        let proposedContentHeight: CGFloat
                        if layout.size.width < layout.size.height {
                            proposedContentHeight = layout.size.height - topEdge - contentActionsSpacing - actionsSize.height - layout.intrinsicInsets.bottom - actionsBottomInset
                        } else {
                            proposedContentHeight = layout.size.height - topEdge - topEdge
                            
                            let maxActionsHeight = layout.size.height - topEdge - topEdge
                            self.actionsContainerNode.updateSize(containerSize: CGSize(width: actionsSize.width, height: min(actionsSize.height, maxActionsHeight)), contentSize: actionsSize)
                        }
                        contentUnscaledSize = CGSize(width: constrainedWidth, height: max(100.0, proposedContentHeight))
                        
                        if let preferredSize = contentParentNode.controller.preferredContentSizeForLayout(ContainerViewLayout(size: contentUnscaledSize, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact, orientation: nil), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false)) {
                            contentUnscaledSize = preferredSize
                        }
                    } else {
                        let maxActionsHeight = layout.size.height - layout.intrinsicInsets.bottom - actionsBottomInset - actionsSize.height
                        self.actionsContainerNode.updateSize(containerSize: CGSize(width: actionsSize.width, height: min(actionsSize.height, maxActionsHeight)), contentSize: actionsSize)
                        
                        let proposedContentHeight = layout.size.height - topEdge - contentActionsSpacing - actionsSize.height - layout.intrinsicInsets.bottom - actionsBottomInset
                        contentUnscaledSize = CGSize(width: min(layout.size.width, 340.0), height: min(568.0, proposedContentHeight))
                        
                        if let preferredSize = contentParentNode.controller.preferredContentSizeForLayout(ContainerViewLayout(size: contentUnscaledSize, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact, orientation: nil), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false)) {
                            contentUnscaledSize = preferredSize
                        }
                    }
                    let contentSize = CGSize(width: floor(contentUnscaledSize.width * contentScale), height: floor(contentUnscaledSize.height * contentScale))
                    
                    self.contentContainerNode.updateLayout(size: contentUnscaledSize, scaledSize: contentSize, transition: transition)
                    
                    let maximumActionsFrameOrigin = max(60.0, layout.size.height - layout.intrinsicInsets.bottom - actionsBottomInset - actionsSize.height)
                    var originalActionsFrame: CGRect
                    var originalContentFrame: CGRect
                    var contentHeight: CGFloat
                    if case .compact = layout.metrics.widthClass {
                        if layout.size.width < layout.size.height {
                            let sideInset = floor((layout.size.width - max(contentSize.width, actionsSize.width)) / 2.0)
                            originalActionsFrame = CGRect(origin: CGPoint(x: sideInset, y: min(maximumActionsFrameOrigin, floor((layout.size.height - contentActionsSpacing - contentSize.height) / 2.0) + contentSize.height + contentActionsSpacing)), size: actionsSize)
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
                    
                    let scrollContentSize = CGSize(width: layout.size.width, height: contentHeight)
                    if self.scrollNode.view.contentSize != scrollContentSize {
                        self.scrollNode.view.contentSize = scrollContentSize
                    }
                    self.actionsContainerNode.panSelectionGestureEnabled = true
                    
                    let overflowOffset = min(0.0, originalContentFrame.minY - contentTopInset)
                    
                    let contentContainerFrame = originalContentFrame
                    transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame.offsetBy(dx: 0.0, dy: -overflowOffset))
                    actionsContainerTransition.updateFrame(node: self.actionsContainerNode, frame: originalActionsFrame.offsetBy(dx: 0.0, dy: -overflowOffset))
                    
                    if isInitialLayout {
                        self.scrollNode.view.contentOffset = CGPoint(x: 0.0, y: -overflowOffset)
                        let currentContainerFrame = self.view.convert(self.contentContainerNode.frame, from: self.scrollNode.view)
                        if overflowOffset < 0.0 {
                            transition.animateOffsetAdditive(node: self.scrollNode, offset: currentContainerFrame.minY - previousContainerFrame.minY)
                        }
                    }
                }
            }
        }
            
        if let previousActionsContainerNode = previousActionsContainerNode {
            if transition.isAnimated && self.getController()?.immediateItemsTransitionAnimation == false {
                if previousActionsContainerNode.hasAdditionalActions && !self.actionsContainerNode.hasAdditionalActions && self.getController()?.useComplexItemsTransitionAnimation == true {
                    var initialFrame = self.actionsContainerNode.frame
                    let delta = (previousActionsContainerNode.frame.height - self.actionsContainerNode.frame.height)
                    initialFrame.origin.y = self.actionsContainerNode.frame.minY + previousActionsContainerNode.frame.height - self.actionsContainerNode.frame.height
                    transition.animateFrame(node: self.actionsContainerNode, from: initialFrame)
                    transition.animatePosition(node: previousActionsContainerNode, to: CGPoint(x: 0.0, y: -delta), removeOnCompletion: false, additive: true)
                    previousActionsContainerNode.animateOut(offset: delta, transition: transition)
                    
                    previousActionsContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previousActionsContainerNode] _ in
                        previousActionsContainerNode?.removeFromSupernode()
                    })
                    self.actionsContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                } else {
                    if let previousActionsContainerFrame = previousActionsContainerFrame {
                        previousActionsContainerNode.frame = self.view.convert(previousActionsContainerFrame, to: self.actionsContainerNode.view.superview!)
                    }

                    switch previousActionsTransition {
                    case .scale:
                        transition.updateTransformScale(node: previousActionsContainerNode, scale: 0.1)
                        previousActionsContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previousActionsContainerNode] _ in
                            previousActionsContainerNode?.removeFromSupernode()
                        })

                        transition.animateTransformScale(node: self.actionsContainerNode, from: 0.1)
                        self.actionsContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    case let .slide(forward):
                        let deltaY = self.actionsContainerNode.frame.minY - previousActionsContainerNode.frame.minY
                        var previousNodePosition = previousActionsContainerNode.position.offsetBy(dx: 0.0, dy: deltaY)
                        let additionalHorizontalOffset: CGFloat = 20.0
                        let currentNodeOffset: CGFloat
                        if forward {
                            previousNodePosition = previousNodePosition.offsetBy(dx: -previousActionsContainerNode.frame.width / 2.0 - additionalHorizontalOffset, dy: -previousActionsContainerNode.frame.height / 2.0)
                            currentNodeOffset = self.actionsContainerNode.bounds.width / 2.0 + additionalHorizontalOffset
                        } else {
                            previousNodePosition = previousNodePosition.offsetBy(dx: previousActionsContainerNode.frame.width / 2.0 + additionalHorizontalOffset, dy: -previousActionsContainerNode.frame.height / 2.0)
                            currentNodeOffset = -self.actionsContainerNode.bounds.width / 2.0 - additionalHorizontalOffset
                        }
                        transition.updatePosition(node: previousActionsContainerNode, position: previousNodePosition)
                        transition.updateTransformScale(node: previousActionsContainerNode, scale: 0.01)
                        previousActionsContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previousActionsContainerNode] _ in
                            previousActionsContainerNode?.removeFromSupernode()
                        })

                        transition.animatePositionAdditive(node: self.actionsContainerNode, offset: CGPoint(x: currentNodeOffset, y: -deltaY - self.actionsContainerNode.bounds.height / 2.0))
                        transition.animateTransformScale(node: self.actionsContainerNode, from: 0.01)
                        self.actionsContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
            } else {
                previousActionsContainerNode.removeFromSupernode()
            }
        }
        
        transition.updateFrame(node: self.dismissNode, frame: CGRect(origin: CGPoint(), size: self.scrollNode.view.contentSize))
        self.dismissAccessibilityArea.frame = CGRect(origin: CGPoint(), size: self.scrollNode.view.contentSize)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let layout = self.validLayout else {
            return
        }
        if let maybeContentNode = self.contentContainerNode.contentNode, case let .extracted(contentParentNode, keepInPlace) = maybeContentNode {
            let contentContainerFrame = self.contentContainerNode.frame
            let absoluteRect: CGRect
            if keepInPlace {
                absoluteRect = contentContainerFrame
            } else {
                absoluteRect = contentContainerFrame.offsetBy(dx: 0.0, dy: -self.scrollNode.view.contentOffset.y)
            }
            contentParentNode.updateAbsoluteRect?(absoluteRect, layout.size)
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        if !self.isUserInteractionEnabled {
            return nil
        }
        
        if let controller = self.getController() as? ContextController {
            var innerResult: UIView?
            controller.forEachController { c in
                if let c = c as? UndoOverlayController {
                    if let result = c.view.hitTest(self.view.convert(point, to: c.view), with: event) {
                        innerResult = result
                        return false
                    }
                }
                return true
            }
            if let innerResult = innerResult {
                return innerResult
            }
        }
        
        if let sourceContainer = self.sourceContainer {
            return sourceContainer.hitTest(self.view.convert(point, to: sourceContainer.view), with: event)
        }
        
        let mappedPoint = self.view.convert(point, to: self.scrollNode.view)
        var maybePassthrough: ContextControllerImpl.HandledTouchEvent?
        if let maybeContentNode = self.contentContainerNode.contentNode {
            switch maybeContentNode {
            case .reference:
                if let controller = self.getController() as? ContextControllerImpl, let passthroughTouchEvent = controller.passthroughTouchEvent {
                    maybePassthrough = passthroughTouchEvent(self.view, point)
                }
            case let .extracted(contentParentNode, _):
                if case let .extracted(source) = self.legacySource {
                    if !source.ignoreContentTouches {
                        let contentPoint = self.view.convert(point, to: contentParentNode.contentNode.view)
                        if let result = contentParentNode.contentNode.customHitTest?(contentPoint) {
                            return result
                        } else if let result = contentParentNode.contentNode.hitTest(contentPoint, with: event) {
                            if result is TextSelectionNodeView {
                                return result
                            } else if contentParentNode.contentRect.contains(contentPoint) {
                                return contentParentNode.contentNode.view
                            }
                        }
                    }
                }
            case .extractedContainer:
                break
            case let .controller(controller):
                var passthrough = false
                switch self.legacySource {
                case let .controller(controllerSource):
                    passthrough = controllerSource.passthroughTouches
                default:
                    break
                }
                if passthrough {
                    let controllerPoint = self.view.convert(point, to: controller.controller.view)
                    if let result = controller.controller.view.hitTest(controllerPoint, with: event) {
                        return result
                    }
                }
            }
        }
        
        if self.actionsContainerNode.frame.contains(mappedPoint) {
            return self.actionsContainerNode.hitTest(self.view.convert(point, to: self.actionsContainerNode.view), with: event)
        }

        if let maybePassthrough = maybePassthrough {
            switch maybePassthrough {
            case .ignore:
                break
            case let .dismiss(consume, hitTestResult):
                self.getController()?.dismiss(completion: nil)

                if let hitTestResult = hitTestResult {
                    return hitTestResult
                }
                if !consume {
                    return nil
                }
            }
        }
        
        return self.dismissNode.view
    }
    
    fileprivate func performHighlightedAction() {
        self.sourceContainer?.performHighlightedAction()
    }
    
    fileprivate func decreaseHighlightedIndex() {
        self.sourceContainer?.decreaseHighlightedIndex()
    }
    
    fileprivate func increaseHighlightedIndex() {
        self.sourceContainer?.increaseHighlightedIndex()
    }
}

public final class ContextControllerImpl: ViewController, ContextController, StandalonePresentableController, ContextControllerProtocol, KeyShortcutResponder {
    private let context: AccountContext?
    private var presentationData: PresentationData
    private let configuration: ContextController.Configuration
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private weak var recognizer: TapLongTapOrDoubleTapGestureRecognizer?
    private weak var gesture: ContextGesture?
    
    private var animatedDidAppear = false
    private var wasDismissed = false
    private var dismissOnInputClose: (result: ContextMenuActionResult, completion: (() -> Void)?)?
    private var dismissToReactionOnInputClose: (value: MessageReaction.Reaction, targetView: UIView, hideNode: Bool, animateTargetContainer: UIView?, addStandaloneReactionAnimation: ((StandaloneReactionAnimation) -> Void)?, completion: (() -> Void)?)?
    
    override public var overlayWantsToBeBelowKeyboard: Bool {
        if self.isNodeLoaded {
            return self.controllerNode.overlayWantsToBeBelowKeyboard
        } else {
            return false
        }
    }
    
    var controllerNode: ContextControllerNode {
        return self.displayNode as! ContextControllerNode
    }

    public var dismissed: (() -> Void)?
    public var dismissedForCancel: (() -> Void)? {
        didSet {
            self.controllerNode.dismissedForCancel = self.dismissedForCancel
        }
    }
    
    public var useComplexItemsTransitionAnimation = false
    public var immediateItemsTransitionAnimation = false
    let workaroundUseLegacyImplementation: Bool
    let disableScreenshots: Bool
    let hideReactionPanelTail: Bool

    public var passthroughTouchEvent: ((UIView, CGPoint) -> HandledTouchEvent)?
    
    private var shouldBeDismissedDisposable: Disposable?
    
    public var reactionSelected: ((UpdateMessageReaction, Bool) -> Void)?
    public var premiumReactionsSelected: (() -> Void)?
    
    public var getOverlayViews: (() -> [UIView])?
    
    public init(
        context: AccountContext? = nil,
        presentationData: PresentationData,
        configuration: ContextController.Configuration,
        recognizer: TapLongTapOrDoubleTapGestureRecognizer? = nil,
        gesture: ContextGesture? = nil,
        workaroundUseLegacyImplementation: Bool = false,
        disableScreenshots: Bool = false,
        hideReactionPanelTail: Bool = false
    ) {
        self.context = context
        self.presentationData = presentationData
        self.configuration = configuration
        self.recognizer = recognizer
        self.gesture = gesture
        self.workaroundUseLegacyImplementation = workaroundUseLegacyImplementation
        self.disableScreenshots = disableScreenshots
        self.hideReactionPanelTail = hideReactionPanelTail
        
        super.init(navigationBarPresentationData: nil)
        
        if let mainSource = configuration.sources.first(where: { $0.id == configuration.initialId }) {
            switch mainSource.source {
            case let .location(locationSource):
                self.statusBar.statusBarStyle = .Ignore
                
                self.shouldBeDismissedDisposable = (locationSource.shouldBeDismissed
                |> filter { $0 }
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.dismiss(result: .default, completion: {})
                }).strict()
            case let .reference(referenceSource):
                self.statusBar.statusBarStyle = .Ignore
                
                self.shouldBeDismissedDisposable = (referenceSource.shouldBeDismissed
                |> filter { $0 }
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.dismiss(result: .default, completion: {})
                }).strict()
            case let .extracted(extractedSource):
                if extractedSource.blurBackground {
                    self.statusBar.statusBarStyle = .Hide
                } else {
                    self.statusBar.statusBarStyle = .Ignore
                }
                self.shouldBeDismissedDisposable = (extractedSource.shouldBeDismissed
                |> filter { $0 }
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.dismiss(result: .default, completion: {})
                }).strict()
            case .controller:
                self.statusBar.statusBarStyle = .Hide
            }
        }

        self.lockOrientation = true
        self.blocksBackgroundWhenInOverlay = true
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.shouldBeDismissedDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ContextControllerNode(controller: self, context: self.context, presentationData: self.presentationData, configuration: self.configuration, beginDismiss: { [weak self] result in
            self?.dismiss(result: result, completion: nil)
        }, recognizer: self.recognizer, gesture: self.gesture, beganAnimatingOut: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.statusBar.statusBarStyle = .Ignore
            
            strongSelf.forEachController { c in
                if let c = c as? UndoOverlayController {
                    c.dismiss()
                }
                return true
            }
        }, attemptTransitionControllerIntoNavigation: {
        })
        self.controllerNode.dismissedForCancel = self.dismissedForCancel
        self.displayNodeDidLoad()
        
        self._ready.set(combineLatest(queue: .mainQueue(), self.controllerNode.itemsReady.get(), self.controllerNode.contentReady.get())
        |> map { values in
            return values.0 && values.1
        })
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.updateLayout(layout: layout, transition: transition, previousActionsContainerNode: nil)
        
        if (layout.inputHeight ?? 0.0) == 0.0 {
            if let dismissOnInputClose = self.dismissOnInputClose {
                self.dismissOnInputClose = nil
                DispatchQueue.main.async {
                    self.dismiss(result: dismissOnInputClose.result, completion: dismissOnInputClose.completion)
                }
            } else if let args = self.dismissToReactionOnInputClose {
                self.dismissToReactionOnInputClose = nil
                DispatchQueue.main.async {
                    self.dismissWithReactionImpl(value: args.value, targetView: args.targetView, hideNode: args.hideNode, animateTargetContainer: args.animateTargetContainer, addStandaloneReactionAnimation: args.addStandaloneReactionAnimation, reducedCurve: true, onHit: nil, completion: args.completion)
                }
            }
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        super.viewDidAppear(animated)
        
        if !self.wasDismissed && !self.animatedDidAppear {
            self.animatedDidAppear = true
            self.controllerNode.animateIn()
        }
    }

    public func getActionsMinHeight() -> ContextController.ActionsHeight? {
        if self.isNodeLoaded {
            return self.controllerNode.getActionsMinHeight()
        }
        return nil
    }
    
    public func setItems(_ items: Signal<ContextController.Items, NoError>, minHeight: ContextController.ActionsHeight?, animated: Bool) {
        //self.items = items
        
        if self.isNodeLoaded {
            self.immediateItemsTransitionAnimation = false
            self.controllerNode.setItemsSignal(items: items, minHeight: minHeight, previousActionsTransition: .scale, animated: animated)
        } else {
            assertionFailure()
        }
    }

    public func setItems(_ items: Signal<ContextController.Items, NoError>, minHeight: ContextController.ActionsHeight?, previousActionsTransition: ContextController.PreviousActionsTransition) {
        //self.items = items
        
        if self.isNodeLoaded {
            self.controllerNode.setItemsSignal(items: items, minHeight: minHeight, previousActionsTransition: previousActionsTransition, animated: true)
        } else {
            assertionFailure()
        }
    }
    
    public func pushItems(items: Signal<ContextController.Items, NoError>) {
        if !self.isNodeLoaded {
            return
        }
        self.controllerNode.pushItems(items: items)
    }
    
    public func popItems() {
        if !self.isNodeLoaded {
            return
        }
        self.controllerNode.popItems()
    }
    
    public func updateTheme(presentationData: PresentationData) {
        self.presentationData = presentationData
        if self.isNodeLoaded {
            self.controllerNode.updateTheme(presentationData: presentationData)
        }
    }
    
    public func dismiss(result: ContextMenuActionResult, completion: (() -> Void)?) {
        if let mainSource = self.configuration.sources.first(where: { $0.id == self.configuration.initialId }), case let .reference(source) = mainSource.source, source.forceDisplayBelowKeyboard {
            
        } else if viewTreeContainsFirstResponder(view: self.view) { 
            self.dismissOnInputClose = (result, completion)
            self.view.endEditing(true)
            return
        }
        
        if !self.wasDismissed {
            self.wasDismissed = true
            
            self.controllerNode.animateOut(result: result, completion: { [weak self] in
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
                completion?()
            })
            self.dismissed?()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.dismiss(result: .default, completion: completion)
    }
    
    public func dismissWithCustomTransition(transition: ContainedViewLayoutTransition, completion: (() -> Void)? = nil) {
        self.dismiss(result: .custom(transition), completion: nil)
    }
    
    public func dismissWithoutContent() {
        self.dismiss(result: .dismissWithoutContent, completion: nil)
    }
    
    public func dismissNow() {
        self.presentingViewController?.dismiss(animated: false, completion: nil)
        self.dismissed?()
    }
    
    public func dismissWithReaction(value: MessageReaction.Reaction, targetView: UIView, hideNode: Bool, animateTargetContainer: UIView?, addStandaloneReactionAnimation: ((StandaloneReactionAnimation) -> Void)?, onHit: (() -> Void)?, completion: (() -> Void)?) {
        self.dismissWithReactionImpl(value: value, targetView: targetView, hideNode: hideNode, animateTargetContainer: animateTargetContainer, addStandaloneReactionAnimation: addStandaloneReactionAnimation, reducedCurve: false, onHit: onHit, completion: completion)
    }
    
    private func dismissWithReactionImpl(value: MessageReaction.Reaction, targetView: UIView, hideNode: Bool, animateTargetContainer: UIView?, addStandaloneReactionAnimation: ((StandaloneReactionAnimation) -> Void)?, reducedCurve: Bool, onHit: (() -> Void)?, completion: (() -> Void)?) {
        if viewTreeContainsFirstResponder(view: self.view) {
            self.dismissToReactionOnInputClose = (value, targetView, hideNode, animateTargetContainer, addStandaloneReactionAnimation, completion)
            self.view.endEditing(true)
            return
        }
        
        if !self.wasDismissed {
            self.wasDismissed = true
            self.controllerNode.animateOutToReaction(value: value, targetView: targetView, hideNode: hideNode, animateTargetContainer: animateTargetContainer, addStandaloneReactionAnimation: addStandaloneReactionAnimation, reducedCurve: reducedCurve, onHit: onHit, completion: { [weak self] in
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
                completion?()
            })
            self.dismissed?()
        }
    }
    
    public func animateDismissalIfNeeded() {
        self.controllerNode.animateDismissalIfNeeded()
    }
    
    public func cancelReactionAnimation() {
        self.controllerNode.cancelReactionAnimation()
    }
    
    public func addRelativeContentOffset(_ offset: CGPoint, transition: ContainedViewLayoutTransition) {
        self.controllerNode.addRelativeContentOffset(offset, transition: transition)
    }
    
    public var keyShortcuts: [KeyShortcut] {
        return [
            KeyShortcut(
                input: UIKeyCommand.inputEscape,
                modifiers: [],
                action: { [weak self] in
                    self?.dismissWithoutContent()
                }
            ),
            KeyShortcut(
                input: "W",
                modifiers: [.command],
                action: { [weak self] in
                    self?.dismissWithoutContent()
                }
            ),
            KeyShortcut(
                input: "\r",
                modifiers: [],
                action: { [weak self] in
                    self?.controllerNode.performHighlightedAction()
                }
            ),
            KeyShortcut(
                input: UIKeyCommand.inputUpArrow,
                modifiers: [],
                action: { [weak self] in
                    self?.controllerNode.decreaseHighlightedIndex()
                }
            ),
            KeyShortcut(
                input: UIKeyCommand.inputDownArrow,
                modifiers: [],
                action: { [weak self] in
                    self?.controllerNode.increaseHighlightedIndex()
                }
            )
        ]
    }
}
