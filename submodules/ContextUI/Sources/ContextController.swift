import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TextSelectionNode

public enum ContextMenuActionItemTextLayout {
    case singleLine
    case twoLinesMax
    case secondLineWithValue(String)
}

public enum ContextMenuActionItemTextColor {
    case primary
    case destructive
}

public enum ContextMenuActionResult {
    case `default`
    case dismissWithoutContent
}

public final class ContextMenuActionItem {
    public let text: String
    public let textColor: ContextMenuActionItemTextColor
    public let textLayout: ContextMenuActionItemTextLayout
    public let icon: (PresentationTheme) -> UIImage?
    public let action: (ContextController, @escaping (ContextMenuActionResult) -> Void) -> Void
    
    public init(text: String, textColor: ContextMenuActionItemTextColor = .primary, textLayout: ContextMenuActionItemTextLayout = .twoLinesMax, icon: @escaping (PresentationTheme) -> UIImage?, action: @escaping (ContextController, @escaping (ContextMenuActionResult) -> Void) -> Void) {
        self.text = text
        self.textColor = textColor
        self.textLayout = textLayout
        self.icon = icon
        self.action = action
    }
}

public enum ContextMenuItem {
    case action(ContextMenuActionItem)
    case separator
}

private final class ContextControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private let source: ContextControllerContentSource
    private var items: [ContextMenuItem]
    private let beginDismiss: (ContextMenuActionResult) -> Void
    
    private var validLayout: ContainerViewLayout?
    
    private let effectView: UIVisualEffectView
    private var propertyAnimator: AnyObject?
    private var displayLinkAnimator: DisplayLinkAnimator?
    private let dimNode: ASDisplayNode
    
    private let clippingNode: ASDisplayNode
    private let scrollNode: ASScrollNode
    
    private var originalProjectedContentViewFrame: (CGRect, CGRect)?
    private var contentAreaInScreenSpace: CGRect?
    private var contentParentNode: ContextContentContainingNode?
    private let contentContainerNode: ContextContentContainerNode
    private var actionsContainerNode: ContextActionsContainerNode
    
    private var didCompleteAnimationIn = false
    private var initialContinueGesturePoint: CGPoint?
    private var didMoveFromInitialGesturePoint = false
    private var highlightedActionNode: ContextActionNode?
    
    private let hapticFeedback = HapticFeedback()
    
    init(controller: ContextController, theme: PresentationTheme, strings: PresentationStrings, source: ContextControllerContentSource, items: [ContextMenuItem], beginDismiss: @escaping (ContextMenuActionResult) -> Void, recognizer: TapLongTapOrDoubleTapGestureRecognizer?) {
        self.theme = theme
        self.strings = strings
        self.source = source
        self.items = items
        self.beginDismiss = beginDismiss
        
        self.effectView = UIVisualEffectView()
        if #available(iOS 9.0, *) {
        } else {
            if theme.chatList.searchBarKeyboardColor == .dark {
                self.effectView.effect = UIBlurEffect(style: .dark)
            } else {
                self.effectView.effect = UIBlurEffect(style: .light)
            }
            self.effectView.alpha = 0.0
        }
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = theme.contextMenu.dimColor
        self.dimNode.alpha = 0.0
        
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
        
        var getController: (() -> ContextController?)?
        self.actionsContainerNode = ContextActionsContainerNode(theme: theme, items: items, getController: {
            return getController?()
        }, actionSelected: { result in
            beginDismiss(result)
        })
        
        super.init()
        
        /*if #available(iOS 10.0, *) {
            let propertyAnimator = UIViewPropertyAnimator(duration: 0.4, curve: .linear)
            propertyAnimator.isInterruptible = true
            propertyAnimator.addAnimations {
                self.effectView.effect = makeCustomZoomBlurEffect()
            }
            self.propertyAnimator = propertyAnimator
        }*/
        
        self.scrollNode.view.delegate = self
        
        self.view.addSubview(self.effectView)
        self.addSubnode(self.dimNode)
        
        self.addSubnode(self.clippingNode)
        
        self.clippingNode.addSubnode(self.scrollNode)
        
        self.scrollNode.addSubnode(self.actionsContainerNode)
        self.scrollNode.addSubnode(self.contentContainerNode)
        
        getController = { [weak controller] in
            return controller
        }
        
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
                        if distance > 4.0 {
                            strongSelf.didMoveFromInitialGesturePoint = true
                        }
                    }
                    if strongSelf.didMoveFromInitialGesturePoint {
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
            recognizer.externalEnded = { [weak self, weak recognizer] viewAndPoint in
                guard let strongSelf = self, let recognizer = recognizer else {
                    return
                }
                recognizer.externalUpdated = nil
                if strongSelf.didMoveFromInitialGesturePoint {
                    if let (view, point) = viewAndPoint {
                        let _ = strongSelf.view.convert(point, from: view)
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
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimNodeTapped)))
    }
    
    @objc private func dimNodeTapped() {
        self.beginDismiss(.default)
    }
    
    func animateIn() {
        self.hapticFeedback.impact()
        
        let takenViewInfo = self.source.takeView()
        
        if let takenViewInfo = takenViewInfo, let parentSupernode = takenViewInfo.contentContainingNode.supernode {
            self.contentParentNode = takenViewInfo.contentContainingNode
            let contentParentNode = takenViewInfo.contentContainingNode
            takenViewInfo.contentContainingNode.layoutUpdated = { [weak contentParentNode, weak self] size in
                guard let strongSelf = self, let contentParentNode = contentParentNode, let parentSupernode = contentParentNode.supernode else {
                    return
                }
                strongSelf.originalProjectedContentViewFrame = (parentSupernode.view.convert(contentParentNode.frame, to: strongSelf.view), contentParentNode.view.convert(contentParentNode.contentRect, to: strongSelf.view))
                if let validLayout = strongSelf.validLayout {
                    strongSelf.updateLayout(layout: validLayout, transition: .animated(duration: 0.2, curve: .easeInOut), previousActionsContainerNode: nil)
                }
            }
            self.contentContainerNode.contentNode = takenViewInfo.contentContainingNode.contentNode
            self.contentAreaInScreenSpace = takenViewInfo.contentAreaInScreenSpace
            self.contentContainerNode.addSubnode(takenViewInfo.contentContainingNode.contentNode)
            takenViewInfo.contentContainingNode.isExtractedToContextPreview = true
            takenViewInfo.contentContainingNode.isExtractedToContextPreviewUpdated?(true)
            
            self.originalProjectedContentViewFrame = (parentSupernode.view.convert(takenViewInfo.contentContainingNode.frame, to: self.view), takenViewInfo.contentContainingNode.view.convert(takenViewInfo.contentContainingNode.contentRect, to: self.view))
            
            self.clippingNode.layer.animateFrame(from: takenViewInfo.contentAreaInScreenSpace, to: self.clippingNode.frame, duration: 0.18, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
            self.clippingNode.layer.animateBoundsOriginYAdditive(from: takenViewInfo.contentAreaInScreenSpace.minY, to: 0.0, duration: 0.18, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
        }
        
        if let validLayout = self.validLayout {
            self.updateLayout(layout: validLayout, transition: .immediate, previousActionsContainerNode: nil)
        }
        
        self.dimNode.alpha = 1.0
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        if let _ = self.propertyAnimator {
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                self.displayLinkAnimator = DisplayLinkAnimator(duration: 0.25, from: 0.0, to: 1.0, update: { [weak self] value in
                    (self?.propertyAnimator as? UIViewPropertyAnimator)?.fractionComplete = value
                }, completion: { [weak self] in
                    self?.didCompleteAnimationIn = true
                    self?.hapticFeedback.prepareTap()
                })
            }
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.effectView.effect = makeCustomZoomBlurEffect()
            })
        }
        self.actionsContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        let springDuration: Double = 0.42
        let springDamping: CGFloat = 104.0
        self.actionsContainerNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
        if let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame, let contentParentNode = self.contentParentNode {
            let localSourceFrame = self.view.convert(originalProjectedContentViewFrame.1, to: self.scrollNode.view)
            
            self.actionsContainerNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: localSourceFrame.center.x - self.actionsContainerNode.position.x, y: localSourceFrame.center.y - self.actionsContainerNode.position.y)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, additive: true)
            let contentContainerOffset = CGPoint(x: localSourceFrame.center.x - self.contentContainerNode.frame.center.x - contentParentNode.contentRect.minX, y: localSourceFrame.center.y - self.contentContainerNode.frame.center.y - contentParentNode.contentRect.minY)
            self.contentContainerNode.layer.animateSpring(from: NSValue(cgPoint: contentContainerOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, additive: true)
            contentParentNode.applyAbsoluteOffsetSpring?(-contentContainerOffset.y, springDuration, springDamping)
        }
    }
    
    func animateOut(result: ContextMenuActionResult, completion: @escaping () -> Void) {
        self.isUserInteractionEnabled = false
        
        var completedEffect = false
        var completedContentNode = false
        var completedActionsNode = false
        
        let putBackInfo = self.source.putBack()
        
        if let putBackInfo = putBackInfo, let contentParentNode = self.contentParentNode, let parentSupernode = contentParentNode.supernode {
            self.originalProjectedContentViewFrame = (parentSupernode.view.convert(contentParentNode.frame, to: self.view), contentParentNode.view.convert(contentParentNode.contentRect, to: self.view))
            
            self.clippingNode.layer.animateFrame(from: self.clippingNode.frame, to: putBackInfo.contentAreaInScreenSpace, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false)
            self.clippingNode.layer.animateBoundsOriginYAdditive(from: 0.0, to: putBackInfo.contentAreaInScreenSpace.minY, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false)
        }
        
        let contentParentNode = self.contentParentNode
        
        contentParentNode?.willUpdateIsExtractedToContextPreview?(false)
        
        let intermediateCompletion: () -> Void = { [weak contentParentNode] in
            if completedEffect && completedContentNode && completedActionsNode {
                switch result {
                case .default:
                    if let contentParentNode = contentParentNode {
                        contentParentNode.addSubnode(contentParentNode.contentNode)
                        contentParentNode.isExtractedToContextPreview = false
                        contentParentNode.isExtractedToContextPreviewUpdated?(false)
                    }
                case .dismissWithoutContent:
                    break
                }
                
                completion()
            }
        }
        
        if let propertyAnimator = self.propertyAnimator {
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                self.displayLinkAnimator = DisplayLinkAnimator(duration: 0.2, from: (propertyAnimator as? UIViewPropertyAnimator)?.fractionComplete ?? 0.2, to: 0.0, update: { [weak self] value in
                    (self?.propertyAnimator as? UIViewPropertyAnimator)?.fractionComplete = value
                }, completion: { [weak self] in
                    self?.effectView.isHidden = true
                    completedEffect = true
                    intermediateCompletion()
                })
            }
        } else {
            UIView.animate(withDuration: 0.2, animations: {
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
        
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.actionsContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
            completedActionsNode = true
            intermediateCompletion()
        })
        self.actionsContainerNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
        if case .default = result, let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame, let contentParentNode = self.contentParentNode {
            let localSourceFrame = self.view.convert(originalProjectedContentViewFrame.1, to: self.scrollNode.view)
            self.actionsContainerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: localSourceFrame.center.x - self.actionsContainerNode.position.x, y: localSourceFrame.center.y - self.actionsContainerNode.position.y), duration: 0.2, removeOnCompletion: false, additive: true)
            let contentContainerOffset = CGPoint(x: localSourceFrame.center.x - self.contentContainerNode.frame.center.x - contentParentNode.contentRect.minX, y: localSourceFrame.center.y - self.contentContainerNode.frame.center.y - contentParentNode.contentRect.minY)
            self.contentContainerNode.layer.animatePosition(from: CGPoint(), to: contentContainerOffset, duration: 0.2, removeOnCompletion: false, additive: true, completion: { _ in
                completedContentNode = true
                intermediateCompletion()
            })
            contentParentNode.updateAbsoluteRect?(self.contentContainerNode.frame.offsetBy(dx: 0.0, dy: -self.scrollNode.view.contentOffset.y + contentContainerOffset.y), self.bounds.size)
            contentParentNode.applyAbsoluteOffset?(-contentContainerOffset.y, .easeInOut, 0.2)
        } else if let contentParentNode = self.contentParentNode {
            if let snapshotView = contentParentNode.contentNode.view.snapshotContentTree() {
                self.contentContainerNode.view.addSubview(snapshotView)
            }
            
            contentParentNode.addSubnode(contentParentNode.contentNode)
            contentParentNode.isExtractedToContextPreview = false
            contentParentNode.isExtractedToContextPreviewUpdated?(false)
            
            self.contentContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                completedContentNode = true
                intermediateCompletion()
            })
        }
    }
    
    func setItems(controller: ContextController, items: [ContextMenuItem]) {
        self.items = items
        
        let previousActionsContainerNode = self.actionsContainerNode
        self.actionsContainerNode = ContextActionsContainerNode(theme: self.theme, items: items, getController: { [weak controller] in
            return controller
        }, actionSelected: { [weak self] result in
            self?.beginDismiss(result)
        })
        self.scrollNode.insertSubnode(self.actionsContainerNode, aboveSubnode: previousActionsContainerNode)
        
        if let layout = self.validLayout {
            self.updateLayout(layout: layout, transition: .animated(duration: 0.3, curve: .spring), previousActionsContainerNode: previousActionsContainerNode)
            
        } else {
            previousActionsContainerNode.removeFromSupernode()
        }
    }
    
    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition, previousActionsContainerNode: ContextActionsContainerNode?) {
        self.validLayout = layout
        
        var actionsContainerTransition = transition
        if previousActionsContainerNode != nil {
            actionsContainerTransition = .immediate
        }
        
        transition.updateFrame(view: self.effectView, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.clippingNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let contentActionsSpacing: CGFloat = 11.0
        let actionsSideInset: CGFloat = 11.0
        let contentTopInset: CGFloat = max(11.0, layout.statusBarHeight ?? 0.0)
        let actionsBottomInset: CGFloat = 11.0
        
        if let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame, let contentParentNode = self.contentParentNode {
            let isInitialLayout = self.actionsContainerNode.frame.size.width.isZero
            let previousContainerFrame = self.view.convert(self.contentContainerNode.frame, from: self.scrollNode.view)
            
            let actionsSize = self.actionsContainerNode.updateLayout(constrainedWidth: layout.size.width - actionsSideInset * 2.0, transition: actionsContainerTransition)
            let contentSize = originalProjectedContentViewFrame.1.size
            self.contentContainerNode.updateLayout(size: contentSize, transition: transition)
            
            let maximumActionsFrameOrigin = max(60.0, layout.size.height - layout.intrinsicInsets.bottom - actionsBottomInset - actionsSize.height)
            var originalActionsFrame = CGRect(origin: CGPoint(x: max(actionsSideInset, min(layout.size.width - actionsSize.width - actionsSideInset, originalProjectedContentViewFrame.1.minX)), y: min(originalProjectedContentViewFrame.1.maxY + contentActionsSpacing, maximumActionsFrameOrigin)), size: actionsSize)
            var originalContentFrame = CGRect(origin: CGPoint(x: originalProjectedContentViewFrame.1.minX, y: originalActionsFrame.minY - contentActionsSpacing - originalProjectedContentViewFrame.1.size.height), size: originalProjectedContentViewFrame.1.size)
            let topEdge = max(contentTopInset, self.contentAreaInScreenSpace?.minY ?? 0.0)
            if originalContentFrame.minY < topEdge {
                let requiredOffset = topEdge - originalContentFrame.minY
                let availableOffset = max(0.0, layout.size.height - layout.intrinsicInsets.bottom - actionsBottomInset - originalActionsFrame.maxY)
                let offset = min(requiredOffset, availableOffset)
                originalActionsFrame = originalActionsFrame.offsetBy(dx: 0.0, dy: offset)
                originalContentFrame = originalContentFrame.offsetBy(dx: 0.0, dy: offset)
            }
            
            let contentHeight = max(layout.size.height, max(layout.size.height, originalActionsFrame.maxY + actionsBottomInset) - originalContentFrame.minY + contentTopInset)
            
            let scrollContentSize = CGSize(width: layout.size.width, height: contentHeight)
            if self.scrollNode.view.contentSize != scrollContentSize {
                self.scrollNode.view.contentSize = scrollContentSize
            }
            
            let overflowOffset = min(0.0, originalContentFrame.minY - contentTopInset)
            
            let contentContainerFrame = originalContentFrame.offsetBy(dx: -contentParentNode.contentRect.minX, dy: -overflowOffset - contentParentNode.contentRect.minY)
            transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
            actionsContainerTransition.updateFrame(node: self.actionsContainerNode, frame: originalActionsFrame.offsetBy(dx: 0.0, dy: -overflowOffset))
            
            if isInitialLayout {
                self.scrollNode.view.contentOffset = CGPoint(x: 0.0, y: -overflowOffset)
                let currentContainerFrame = self.view.convert(self.contentContainerNode.frame, from: self.scrollNode.view)
                if overflowOffset < 0.0 {
                    transition.animateOffsetAdditive(node: self.scrollNode, offset: currentContainerFrame.minY - previousContainerFrame.minY)
                }
            }
            
            contentParentNode.updateAbsoluteRect?(contentContainerFrame.offsetBy(dx: 0.0, dy: -self.scrollNode.view.contentOffset.y), layout.size)
        }
        
        if let previousActionsContainerNode = previousActionsContainerNode {
            if transition.isAnimated {
                transition.updateTransformScale(node: previousActionsContainerNode, scale: 0.1)
                previousActionsContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previousActionsContainerNode] _ in
                    previousActionsContainerNode?.removeFromSupernode()
                })
                
                transition.animateTransformScale(node: self.actionsContainerNode, from: 0.1)
                if transition.isAnimated {
                    self.actionsContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            } else {
                previousActionsContainerNode.removeFromSupernode()
            }
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let contentParentNode = self.contentParentNode, let layout = self.validLayout {
            let contentContainerFrame = self.contentContainerNode.frame
            contentParentNode.updateAbsoluteRect?(contentContainerFrame.offsetBy(dx: 0.0, dy: -self.scrollNode.view.contentOffset.y), layout.size)
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        let mappedPoint = self.view.convert(point, to: self.scrollNode.view)
        if self.actionsContainerNode.frame.contains(mappedPoint) {
            return self.actionsContainerNode.hitTest(self.view.convert(point, to: self.actionsContainerNode.view), with: event)
        }
        if let contentParentNode = self.contentParentNode {
            let contentPoint = self.view.convert(point, to: contentParentNode.contentNode.view)
            if let result = contentParentNode.contentNode.hitTest(contentPoint, with: event) {
                if result is TextSelectionNodeView {
                    return result
                }
            }
        }
        
        return self.dimNode.view
    }
}

public final class ContextControllerTakeViewInfo {
    public let contentContainingNode: ContextContentContainingNode
    public let contentAreaInScreenSpace: CGRect
    
    public init(contentContainingNode: ContextContentContainingNode, contentAreaInScreenSpace: CGRect) {
        self.contentContainingNode = contentContainingNode
        self.contentAreaInScreenSpace = contentAreaInScreenSpace
    }
}

public final class ContextControllerPutBackViewInfo {
    public let contentAreaInScreenSpace: CGRect
    
    public init(contentAreaInScreenSpace: CGRect) {
        self.contentAreaInScreenSpace = contentAreaInScreenSpace
    }
}

public protocol ContextControllerContentSource: class {
    func takeView() -> ContextControllerTakeViewInfo?
    func putBack() -> ContextControllerPutBackViewInfo?
}

public final class ContextController: ViewController {
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private let source: ContextControllerContentSource
    private var items: [ContextMenuItem]
    
    private weak var recognizer: TapLongTapOrDoubleTapGestureRecognizer?
    
    private var animatedDidAppear = false
    private var wasDismissed = false
    
    private var controllerNode: ContextControllerNode {
        return self.displayNode as! ContextControllerNode
    }
    
    public init(theme: PresentationTheme, strings: PresentationStrings, source: ContextControllerContentSource, items: [ContextMenuItem], recognizer: TapLongTapOrDoubleTapGestureRecognizer? = nil) {
        self.theme = theme
        self.strings = strings
        self.source = source
        self.items = items
        self.recognizer = recognizer
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Hide
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ContextControllerNode(controller: self, theme: self.theme, strings: self.strings, source: self.source, items: self.items, beginDismiss: { [weak self] result in
            self?.dismiss(result: result, completion: nil)
        }, recognizer: self.recognizer)
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.updateLayout(layout: layout, transition: transition, previousActionsContainerNode: nil)
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
    
    public func setItems(_ items: [ContextMenuItem]) {
        self.items = items
        if self.isNodeLoaded {
            self.controllerNode.setItems(controller: self, items: items)
        }
    }
    
    private func dismiss(result: ContextMenuActionResult, completion: (() -> Void)?) {
        if !self.wasDismissed {
            self.wasDismissed = true
            self.controllerNode.animateOut(result: result, completion: { [weak self] in
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
                completion?()
            })
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.dismiss(result: .default, completion: completion)
    }
}
