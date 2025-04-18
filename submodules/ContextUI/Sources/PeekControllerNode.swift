import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData

private let animationDurationFactor: Double = 1.0

final class PeekControllerNode: ViewControllerTracingNode {
    private let requestDismiss: () -> Void
    
    private let presentationData: PresentationData
    private let theme: PeekControllerTheme
    
    private weak var controller: PeekController?
    
    private let blurView: UIView
    private let dimNode: ASDisplayNode
    private let containerBackgroundNode: ASImageNode
    private let containerNode: ASDisplayNode
    private let darkDimNode: ASDisplayNode
    
    private var validLayout: ContainerViewLayout?
    
    private var content: PeekControllerContent
    var contentNode: PeekControllerContentNode & ASDisplayNode
    private var contentNodeHasValidLayout = false
    
    private var topAccessoryNode: ASDisplayNode?
    private var fullScreenAccessoryNode: (PeekControllerAccessoryNode & ASDisplayNode)?
        
    private var actionsStackNode: ContextControllerActionsStackNode
    
    private var hapticFeedback = HapticFeedback()
    
    private var initialContinueGesturePoint: CGPoint?
    private var didMoveFromInitialGesturePoint = false
    private var highlightedActionNode: ContextActionNodeProtocol?
    
    init(presentationData: PresentationData, controller: PeekController, content: PeekControllerContent, requestDismiss: @escaping () -> Void) {
        self.presentationData = presentationData
        self.requestDismiss = requestDismiss
        self.theme = PeekControllerTheme(presentationTheme: presentationData.theme)
        self.controller = controller
        
        self.dimNode = ASDisplayNode()
        
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: self.theme.isDark ? .dark : .light))
        blurView.isUserInteractionEnabled = false
        self.blurView = blurView
        
        self.darkDimNode = ASDisplayNode()
        self.darkDimNode.alpha = 0.0
        self.darkDimNode.backgroundColor = presentationData.theme.contextMenu.dimColor
        self.darkDimNode.isUserInteractionEnabled = false
        
        switch content.menuActivation() {
        case .drag:
            self.dimNode.backgroundColor = nil
            self.blurView.alpha = 1.0
        case .press:
            self.dimNode.backgroundColor = UIColor(white: self.theme.isDark ? 0.0 : 1.0, alpha: 0.5)
            self.blurView.alpha = 0.0
        }
        
        self.containerBackgroundNode = ASImageNode()
        self.containerBackgroundNode.isLayerBacked = true
        self.containerBackgroundNode.displaysAsynchronously = false
        
        self.containerNode = ASDisplayNode()
        
        self.content = content
        self.contentNode = content.node()
        self.topAccessoryNode = content.topAccessoryNode()
        self.fullScreenAccessoryNode = content.fullScreenAccessoryNode(blurView: blurView)
        self.fullScreenAccessoryNode?.alpha = 0.0
        
        var activatedActionImpl: (() -> Void)?
        var requestLayoutImpl: ((ContainedViewLayoutTransition) -> Void)?

        self.actionsStackNode = ContextControllerActionsStackNode(
            context: nil,
            getController: { [weak controller] in
                return controller
            },
            requestDismiss: { result in
                activatedActionImpl?()
            },
            requestUpdate: { transition in
                requestLayoutImpl?(transition)
            }
        )
        self.actionsStackNode.alpha = 0.0
        
        let items = ContextController.Items(
            id: 0,
            content: .list(content.menuItems()),
            context: nil,
            reactionItems: [],
            selectedReactionItems: Set(),
            reactionsTitle: nil,
            reactionsLocked: false,
            animationCache: nil,
            alwaysAllowPremiumReactions: false,
            allPresetReactionsAreAvailable: false,
            getEmojiContent: nil,
            disablePositionLock: false,
            tip: nil,
            tipSignal: nil,
            dismissed: nil
        )
        if let item = makeContextControllerActionsStackItem(items: items).first {
            self.actionsStackNode.replace(
                item: item,
                animated: false
            )
        }
        
        super.init()
                
        requestLayoutImpl = { [weak self] transition in
            self?.updateLayout(transition: transition)
        }
        
        if content.presentation() == .freeform {
            self.containerNode.isUserInteractionEnabled = false
        } else {
            self.containerNode.clipsToBounds = true
            self.containerNode.cornerRadius = 16.0
        }
        
        self.addSubnode(self.dimNode)
        self.view.addSubview(self.blurView)
        self.addSubnode(self.darkDimNode)
        self.containerNode.addSubnode(self.contentNode)
        
        self.addSubnode(self.actionsStackNode)
        self.addSubnode(self.containerNode)
        
        
        if let fullScreenAccessoryNode = self.fullScreenAccessoryNode {
            self.fullScreenAccessoryNode?.dismiss = { [weak self] in
                self?.requestDismiss()
            }
            self.addSubnode(fullScreenAccessoryNode)
        }
        
        activatedActionImpl = { [weak self] in
            self?.requestDismiss()
        }
        
        self.hapticFeedback.prepareTap()
        
        controller.ready.set(self.contentNode.ready())
    }
    
    deinit {
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimNodeTap(_:))))
        self.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
    }
    
    func updateLayout(transition: ContainedViewLayoutTransition = .immediate) {
        if let layout = self.validLayout {
            self.containerLayoutUpdated(layout, transition: transition)
        }
    }
    
    func replaceItem(items: Signal<ContextController.Items, NoError>) {
        let _ = (items
        |> deliverOnMainQueue).start(next: { [weak self] items in
            guard let self else {
                return
            }
            if let item = makeContextControllerActionsStackItem(items: items).first {
                self.actionsStackNode.replace(item: item, animated: false)
            }
        })
    }
    
    func pushItems(items: Signal<ContextController.Items, NoError>) {
        let _ = (items
        |> deliverOnMainQueue).start(next: { [weak self] items in
            guard let self else {
                return
            }
            if let item = makeContextControllerActionsStackItem(items: items).first {
                self.actionsStackNode.push(item: item, currentScrollingState: nil, positionLock: nil, animated: true)
            }
        })
    }
    
    func popItems() {
        self.actionsStackNode.pop()
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.darkDimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(view: self.blurView, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        var layoutInsets = layout.insets(options: [])
        let containerWidth = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: layout.safeInsets.left)
       
        layoutInsets.left = floor((layout.size.width - containerWidth) / 2.0)
        layoutInsets.right = layoutInsets.left
        if !layoutInsets.bottom.isZero {
            layoutInsets.bottom -= 12.0
        }
        
        let maxContainerSize = CGSize(width: layout.size.width - 14.0 * 2.0, height: layout.size.height - layoutInsets.top - layoutInsets.bottom - 90.0)
        
        let contentSize = self.contentNode.updateLayout(size: maxContainerSize, transition: self.contentNodeHasValidLayout ? transition : .immediate)
        if self.contentNodeHasValidLayout {
            transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(), size: contentSize))
        } else {
            self.contentNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        }
        
        let actionsSideInset: CGFloat = layout.safeInsets.left + 11.0
        
        let actionsSize = self.actionsStackNode.update(
            presentationData: self.presentationData,
            constrainedSize: CGSize(width: layout.size.width - actionsSideInset * 2.0, height: layout.size.height),
            presentation: .inline,
            transition: transition
        )
        
        let containerFrame: CGRect
        let actionsFrame: CGRect
        if layout.size.width > layout.size.height {
            if self.actionsStackNode.alpha.isZero {
                containerFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - contentSize.width) / 2.0), y: floor((layout.size.height - contentSize.height) / 2.0)), size: contentSize)
            } else {
                containerFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - contentSize.width) / 3.0), y: floor((layout.size.height - contentSize.height) / 2.0)), size: contentSize)
            }
            actionsFrame = CGRect(origin: CGPoint(x: containerFrame.maxX + 32.0, y: floor((layout.size.height - actionsSize.height) / 2.0)), size: actionsSize)
        } else {
            switch self.content.presentation() {
                case .contained:
                    containerFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - contentSize.width) / 2.0), y: floor((layout.size.height - contentSize.height) / 2.0)), size: contentSize)
                case .freeform:
                    var fraction: CGFloat = 1.0 / 3.0
                    if let _ = self.controller?.appeared {
                        fraction *= 1.33
                    }
                    containerFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - contentSize.width) / 2.0), y: floor((layout.size.height - contentSize.height) * fraction)), size: contentSize)
            }
            actionsFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - actionsSize.width) / 2.0), y: containerFrame.maxY + 64.0), size: actionsSize)
        }
        transition.updateFrame(node: self.containerNode, frame: containerFrame)
                
        transition.updateFrame(node: self.actionsStackNode, frame: actionsFrame)
        
        if let fullScreenAccessoryNode = self.fullScreenAccessoryNode {
            transition.updateFrame(node: fullScreenAccessoryNode, frame: CGRect(origin: .zero, size: layout.size))
            fullScreenAccessoryNode.updateLayout(size: layout.size, transition: transition)
        }
        
        self.contentNodeHasValidLayout = true
    }
    
    func animateIn(from rect: CGRect) {
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.blurView.layer.animateAlpha(from: 0.0, to: self.blurView.alpha, duration: 0.3)
        
        let offset = CGPoint(x: rect.midX - self.containerNode.position.x, y: rect.midY - self.containerNode.position.y)
        self.containerNode.layer.animateSpring(from: NSValue(cgPoint: offset), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.4, initialVelocity: 0.0, damping: 110.0, additive: true)
        
        if let appeared = self.controller?.appeared {
            appeared()
            let scale = rect.width / self.contentNode.frame.width
            self.containerNode.layer.animateSpring(from: scale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4, initialVelocity: 0.0, damping: 110.0)
        } else {
            self.containerNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4, initialVelocity: 0.0, damping: 110.0)
            self.containerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        }
        
        if let topAccessoryNode = self.topAccessoryNode {
            topAccessoryNode.layer.animateSpring(from: NSValue(cgPoint: offset), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.4, initialVelocity: 0.0, damping: 110.0, additive: true)
            topAccessoryNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4, initialVelocity: 0.0, damping: 110.0)
            topAccessoryNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        }
                        
        if case .press = self.content.menuActivation() {
            self.hapticFeedback.tap()
        } else {
            self.hapticFeedback.impact()
        }
    }
    
    func animateOut(to rect: CGRect, completion: @escaping () -> Void) {
        self.isUserInteractionEnabled = false
        
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.blurView.layer.animateAlpha(from: self.blurView.alpha, to: 0.0, duration: 0.25, removeOnCompletion: false)
        self.darkDimNode.layer.animateAlpha(from: self.darkDimNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        
        let springDuration: Double = 0.42 * animationDurationFactor
        let springDamping: CGFloat = 104.0
        
        var scaleCompleted = false
        var positionCompleted = false
        let outCompletion = {
            if scaleCompleted && positionCompleted {
            }
        }

        let offset = CGPoint(x: rect.midX - self.containerNode.position.x, y: rect.midY - self.containerNode.position.y)
        self.containerNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint()), to: NSValue(cgPoint: offset), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, removeOnCompletion: false, additive: true, completion: { _ in
            positionCompleted = true
            outCompletion()
            completion()
        })

        if let _ = self.controller?.disappeared {
            self.controller?.disappeared?()
            let scale = rect.width / self.contentNode.frame.width
            self.containerNode.layer.animateScale(from: 1.0, to: scale, duration: 0.25, removeOnCompletion: false, completion: { _ in
                scaleCompleted = true
                outCompletion()
            })
        } else {
            self.containerNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.25, removeOnCompletion: false, completion: { _ in
                scaleCompleted = true
                outCompletion()
            })
            self.containerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
        
        if !self.actionsStackNode.alpha.isZero {
            let actionsOffset = CGPoint(x: rect.midX - self.actionsStackNode.position.x, y: rect.midY - self.actionsStackNode.position.y)
            self.actionsStackNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2 * animationDurationFactor, removeOnCompletion: false)
            self.actionsStackNode.layer.animateSpring(from: 1.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping, removeOnCompletion: false)
            self.actionsStackNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint()), to: NSValue(cgPoint: actionsOffset), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, additive: true)
        }
        
        if let fullScreenAccessoryNode = self.fullScreenAccessoryNode, !fullScreenAccessoryNode.alpha.isZero {
            fullScreenAccessoryNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2 * animationDurationFactor, removeOnCompletion: false)
        }
    }
    
    @objc func dimNodeTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.requestDismiss()
        }
    }
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        guard case .drag = self.content.menuActivation() else {
            return
        }
        
        let location = recognizer.location(in: self.view)
        switch recognizer.state {
            case .began:
                break
            case .changed:
                self.applyDraggingOffset(location)
            case .cancelled, .ended:
                self.endDragging(location)
            default:
                break
        }
    }
    
    func applyDraggingOffset(_ offset: CGPoint) {
        let localPoint = offset
        let initialPoint: CGPoint
        if let current = self.initialContinueGesturePoint {
            initialPoint = current
        } else {
            initialPoint = localPoint
            self.initialContinueGesturePoint = localPoint
        }
        if !self.actionsStackNode.alpha.isZero {
            if !self.didMoveFromInitialGesturePoint {
                let distance = abs(localPoint.y - initialPoint.y)
                if distance > 12.0 {
                    self.didMoveFromInitialGesturePoint = true
                }
            }
            if self.didMoveFromInitialGesturePoint {
                let actionPoint = self.view.convert(localPoint, to: self.actionsStackNode.view)
                self.actionsStackNode.highlightGestureMoved(location: actionPoint)
            }
        }
    }
    
    func endDragging(_ location: CGPoint) {
        if self.didMoveFromInitialGesturePoint {
            self.actionsStackNode.highlightGestureFinished(performAction: true)
        } else if self.actionsStackNode.alpha.isZero {
            if let fullScreenAccessoryNode = self.fullScreenAccessoryNode, !fullScreenAccessoryNode.alpha.isZero {
            } else {
                self.requestDismiss()
            }
        }
    }
    
    func activateMenu(immediately: Bool = false) {
        if self.content.menuItems().isEmpty {
            if let fullScreenAccessoryNode = self.fullScreenAccessoryNode {
                fullScreenAccessoryNode.alpha = 1.0
                fullScreenAccessoryNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                
                let previousBlurAlpha = self.blurView.alpha
                self.blurView.alpha = 1.0
                self.blurView.layer.animateAlpha(from: previousBlurAlpha, to: self.blurView.alpha, duration: 0.3)
            }
            return
        } else {
            if let fullScreenAccessoryNode = self.fullScreenAccessoryNode {
                fullScreenAccessoryNode.alpha = 1.0
                fullScreenAccessoryNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
            }
        }
        if case .press = self.content.menuActivation() {
            self.hapticFeedback.impact()
        }
        
        let springDuration: Double = 0.42 * animationDurationFactor
        let springDamping: CGFloat = 104.0
        
        let previousBlurAlpha = self.blurView.alpha
        self.blurView.alpha = 1.0
        self.blurView.layer.animateAlpha(from: previousBlurAlpha, to: self.blurView.alpha, duration: 0.25)
        
        let previousDarkDimAlpha = self.darkDimNode.alpha
        self.darkDimNode.alpha = 1.0
        self.darkDimNode.layer.animateAlpha(from: previousDarkDimAlpha, to: 1.0, duration: 0.3)
        
        if let layout = self.validLayout {
            self.containerLayoutUpdated(layout, transition: .animated(duration: springDuration, curve: .spring))
        }
        
        let animateIn = {
            self.actionsStackNode.alpha = 1.0
            self.actionsStackNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2 * animationDurationFactor)
            self.actionsStackNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
            
            let localContentSourceFrame = self.containerNode.frame
            self.actionsStackNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: localContentSourceFrame.center.x - self.actionsStackNode.position.x, y: localContentSourceFrame.center.y - self.actionsStackNode.position.y)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, additive: true)
        }
        if immediately {
            animateIn()
        } else {
            Queue.mainQueue().after(0.02, animateIn)
        }
    }
    
    func updateContent(content: PeekControllerContent) {
        let contentNode = self.contentNode
        contentNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak contentNode] _ in
            contentNode?.removeFromSupernode()
        })
        contentNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.15, removeOnCompletion: false)
        
        self.content = content
        self.contentNode = content.node()
        self.containerNode.addSubnode(self.contentNode)
        self.contentNodeHasValidLayout = false
        
        self.replaceItem(items: .single(ContextController.Items(content: .list(content.menuItems()))))
        
        self.contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
        self.contentNode.layer.animateSpring(from: 0.35 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
        
        if let layout = self.validLayout {
            self.containerLayoutUpdated(layout, transition: .animated(duration: 0.15, curve: .easeInOut))
        }
        
        self.hapticFeedback.tap()
    }
}
