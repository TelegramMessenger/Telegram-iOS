import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import TelegramStringFormatting
import UIKitRuntimeUtils
import MediaResources

public enum AttachmentButtonType: Equatable {
    case gallery
    case file
    case location
    case contact
    case poll
    case app(Peer, String, [AttachMenuBots.Bot.IconName: TelegramMediaFile])
    case standalone
    
    public static func ==(lhs: AttachmentButtonType, rhs: AttachmentButtonType) -> Bool {
        switch lhs {
            case .gallery:
                if case .gallery = rhs {
                    return true
                } else {
                    return false
                }
            case .file:
                if case .file = rhs {
                    return true
                } else {
                    return false
                }
            case .location:
                if case .location = rhs {
                    return true
                } else {
                    return false
                }
            case .contact:
                if case .contact = rhs {
                    return true
                } else {
                    return false
                }
            case .poll:
                if case .poll = rhs {
                    return true
                } else {
                    return false
                }
            case let .app(lhsPeer, lhsTitle, lhsIcons):
                if case let .app(rhsPeer, rhsTitle, rhsIcons) = rhs, arePeersEqual(lhsPeer, rhsPeer), lhsTitle == rhsTitle, lhsIcons == rhsIcons {
                    return true
                } else {
                    return false
                }
            case .standalone:
                if case .standalone = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public protocol AttachmentContainable: ViewController {
    var requestAttachmentMenuExpansion: () -> Void { get set }
    var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void { get set }
    var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void { get set }
    var cancelPanGesture: () -> Void { get set }
    var isContainerPanning: () -> Bool { get set }
    var isContainerExpanded: () -> Bool { get set }
    
    func isContainerPanningUpdated(_ panning: Bool)
    
    func resetForReuse()
    func prepareForReuse()
    
    func requestDismiss(completion: @escaping () -> Void)
}

public extension AttachmentContainable {
    func isContainerPanningUpdated(_ panning: Bool) {
        
    }
    
    func resetForReuse() {
        
    }
    
    func prepareForReuse() {
        
    }
    
    func requestDismiss(completion: @escaping () -> Void) {
        completion()
    }
}

public enum AttachmentMediaPickerSendMode {
    case media
    case files
}

public protocol AttachmentMediaPickerContext {
    var selectionCount: Signal<Int, NoError> { get }
    var caption: Signal<NSAttributedString?, NoError> { get }
    
    var loadingProgress: Signal<CGFloat?, NoError> { get }
    var mainButtonState: Signal<AttachmentMainButtonState?, NoError> { get }
    
    func mainButtonAction()
    
    func setCaption(_ caption: NSAttributedString)
    func send(silently: Bool, mode: AttachmentMediaPickerSendMode)
    func schedule()
}

private func generateShadowImage() -> UIImage? {
    return generateImage(CGSize(width: 140.0, height: 140.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.saveGState()
        context.setShadow(offset: CGSize(), blur: 60.0, color: UIColor(white: 0.0, alpha: 0.4).cgColor)

        let path = UIBezierPath(roundedRect: CGRect(x: 60.0, y: 60.0, width: 20.0, height: 20.0), cornerRadius: 10.0).cgPath
        context.addPath(path)
        context.fillPath()
        
        context.restoreGState()
        
        context.setBlendMode(.clear)
        context.addPath(path)
        context.fillPath()
    })?.stretchableImage(withLeftCapWidth: 70, topCapHeight: 70)
}

private func generateMaskImage() -> UIImage? {
    return generateImage(CGSize(width: 390.0, height: 220.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor.white.cgColor)
        
        let path = UIBezierPath(roundedRect: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 209.0), cornerRadius: 10.0).cgPath
        context.addPath(path)
        context.fillPath()
        
        try? drawSvgPath(context, path: "M183.219,208.89 H206.781 C205.648,208.89 204.567,209.371 203.808,210.214 L197.23,217.523 C196.038,218.848 193.962,218.848 192.77,217.523 L186.192,210.214 C185.433,209.371 184.352,208.89 183.219,208.89 Z ")
    })?.stretchableImage(withLeftCapWidth: 195, topCapHeight: 110)
}

public class AttachmentController: ViewController {
    private let context: AccountContext
    private let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    private let chatLocation: ChatLocation
    private let buttons: [AttachmentButtonType]
    private let initialButton: AttachmentButtonType
    private let fromMenu: Bool
    
    public var willDismiss: () -> Void = {}
    public var didDismiss: () -> Void = {}
    
    public var mediaPickerContext: AttachmentMediaPickerContext? {
        get {
            return self.node.mediaPickerContext
        }
        set {
            self.node.mediaPickerContext = newValue
        }
    }
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
        
    private final class Node: ASDisplayNode {
        private weak var controller: AttachmentController?
        private let dim: ASDisplayNode
        private let shadowNode: ASImageNode
        private let container: AttachmentContainer
        let panel: AttachmentPanel
        
        private var currentType: AttachmentButtonType?
        private var currentControllers: [AttachmentContainable] = []
        
        private var validLayout: ContainerViewLayout?
        private var modalProgress: CGFloat = 0.0
        private var isDismissing = false
                
        private let captionDisposable = MetaDisposable()
        private let mediaSelectionCountDisposable = MetaDisposable()
        
        private let loadingProgressDisposable = MetaDisposable()
        private let mainButtonStateDisposable = MetaDisposable()
        
        private var selectionCount: Int = 0
        
        fileprivate var mediaPickerContext: AttachmentMediaPickerContext? {
            didSet {
                if let mediaPickerContext = self.mediaPickerContext {
                    self.captionDisposable.set((mediaPickerContext.caption
                    |> deliverOnMainQueue).start(next: { [weak self] caption in
                        if let strongSelf = self {
                            strongSelf.panel.updateCaption(caption ?? NSAttributedString())
                        }
                    }))
                    self.mediaSelectionCountDisposable.set((mediaPickerContext.selectionCount
                    |> deliverOnMainQueue).start(next: { [weak self] count in
                        if let strongSelf = self {
                            strongSelf.updateSelectionCount(count)
                        }
                    }))
                    self.loadingProgressDisposable.set((mediaPickerContext.loadingProgress
                    |> deliverOnMainQueue).start(next: { [weak self] progress in
                        if let strongSelf = self {
                            strongSelf.panel.updateLoadingProgress(progress)
                            if let layout = strongSelf.validLayout {
                                strongSelf.containerLayoutUpdated(layout, transition: .animated(duration: 0.4, curve: .spring))
                            }
                        }
                    }))
                    self.mainButtonStateDisposable.set((mediaPickerContext.mainButtonState
                    |> deliverOnMainQueue).start(next: { [weak self] mainButtonState in
                        if let strongSelf = self {
                            let _ = (strongSelf.panel.animatingTransitionPromise.get()
                            |> filter { value in
                                return !value
                            }
                            |> take(1)).start(next: { [weak self] _ in
                                if let strongSelf = self {
                                    strongSelf.panel.updateMainButtonState(mainButtonState)
                                    if let layout = strongSelf.validLayout {
                                        strongSelf.containerLayoutUpdated(layout, transition: .animated(duration: 0.4, curve: .spring))
                                    }
                                }
                            })
                        }
                    }))
                } else {
                    self.updateSelectionCount(0)
                    self.mediaSelectionCountDisposable.set(nil)
                    self.loadingProgressDisposable.set(nil)
                    self.mainButtonStateDisposable.set(nil)
                }
            }
        }
                 
        private let wrapperNode: ASDisplayNode
        
        init(controller: AttachmentController) {
            self.controller = controller
            
            self.dim = ASDisplayNode()
            self.dim.alpha = 0.0
            self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
            
            self.shadowNode = ASImageNode()
            self.shadowNode.isUserInteractionEnabled = false
            
            self.wrapperNode = ASDisplayNode()
            self.wrapperNode.clipsToBounds = true
            
            self.container = AttachmentContainer()
            self.container.canHaveKeyboardFocus = true
            self.panel = AttachmentPanel(context: controller.context, chatLocation: controller.chatLocation, updatedPresentationData: controller.updatedPresentationData)
            self.panel.fromMenu = controller.fromMenu
            self.panel.isStandalone = controller.isStandalone
            
            super.init()
            
            self.addSubnode(self.dim)
            self.addSubnode(self.shadowNode)
            self.addSubnode(self.wrapperNode)
                        
            self.container.controllerRemoved = { [weak self] controller in
                if let strongSelf = self, let layout = strongSelf.validLayout, !strongSelf.isDismissing {
                    strongSelf.currentControllers = strongSelf.currentControllers.filter { $0 !== controller }
                    strongSelf.containerLayoutUpdated(layout, transition: .immediate)
                }
            }
            
            self.container.updateModalProgress = { [weak self] progress, transition in
                if let strongSelf = self, let layout = strongSelf.validLayout, !strongSelf.isDismissing {
                    strongSelf.controller?.updateModalStyleOverlayTransitionFactor(progress, transition: transition)
                    
                    strongSelf.modalProgress = progress
                    strongSelf.containerLayoutUpdated(layout, transition: transition)
                }
            }
            self.container.isReadyUpdated = { [weak self] in
                if let strongSelf = self, let layout = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, transition: .animated(duration: 0.4, curve: .spring))
                }
            }
            
            self.container.interactivelyDismissed = { [weak self] in
                if let strongSelf = self {
                    strongSelf.controller?.dismiss(animated: true)
                }
            }
            
            self.container.isPanningUpdated = { [weak self] value in
                if let strongSelf = self, let currentController = strongSelf.currentControllers.last, !value {
                    currentController.isContainerPanningUpdated(value)
                }
            }
            
            self.panel.selectionChanged = { [weak self] type in
                if let strongSelf = self {
                    return strongSelf.switchToController(type)
                } else {
                    return false
                }
            }
            
            self.panel.beganTextEditing = { [weak self] in
                if let strongSelf = self {
                    strongSelf.container.update(isExpanded: true, transition: .animated(duration: 0.4, curve: .spring))
                }
            }
            
            self.panel.textUpdated = { [weak self] text in
                if let strongSelf = self {
                    strongSelf.mediaPickerContext?.setCaption(text)
                }
            }
            
            self.panel.sendMessagePressed = { [weak self] mode in
                if let strongSelf = self {
                    switch mode {
                        case .generic:
                            strongSelf.mediaPickerContext?.send(silently: false, mode: .media)
                        case .silent:
                            strongSelf.mediaPickerContext?.send(silently: true, mode: .media)
                        case .schedule:
                            strongSelf.mediaPickerContext?.schedule()
                    }
                }
            }
            
            self.panel.mainButtonPressed = { [weak self] in
                if let strongSelf = self {
                    strongSelf.mediaPickerContext?.mainButtonAction()
                }
            }
            
            self.panel.requestLayout = { [weak self] in
                if let strongSelf = self, let layout = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, transition: .animated(duration: 0.2, curve: .easeInOut))
                }
            }
            
            self.panel.present = { [weak self] c in
                if let strongSelf = self {
                    strongSelf.controller?.present(c, in: .window(.root))
                }
            }
            
            self.panel.presentInGlobalOverlay = { [weak self] c in
                if let strongSelf = self {
                    strongSelf.controller?.presentInGlobalOverlay(c, with: nil)
                }
            }
        }
        
        deinit {
            self.captionDisposable.dispose()
            self.mediaSelectionCountDisposable.dispose()
        }
        
        private var inputContainerHeight: CGFloat?
        private var inputContainerNode: ASDisplayNode?
        override func didLoad() {
            super.didLoad()
            
            self.view.disablesInteractiveModalDismiss = true
            
            self.dim.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            if let controller = self.controller {
                let _ = self.switchToController(controller.initialButton)
                if case let .app(bot, _, _) = controller.initialButton {
                    if let index = controller.buttons.firstIndex(where: {
                        if case let .app(otherBot, _, _) = $0, otherBot.id == bot.id {
                            return true
                        } else {
                            return false
                        }
                    }) {
                        self.panel.updateSelectedIndex(index)
                    }
                }
            }
            
            if let (inputContainerHeight, inputContainerNode, _) = self.controller?.getInputContainerNode() {
                self.inputContainerHeight = inputContainerHeight
                self.inputContainerNode = inputContainerNode
                self.addSubnode(inputContainerNode)
            }
        }
        
        private func updateSelectionCount(_ count: Int) {
            self.selectionCount = count
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout, transition: .animated(duration: 0.4, curve: .spring))
            }
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            guard !self.isDismissing else {
                return
            }
            if case .ended = recognizer.state {
                if let controller = self.currentControllers.last {
                    controller.requestDismiss(completion: { [weak self] in
                        self?.controller?.dismiss(animated: true)
                    })
                } else {
                    self.controller?.dismiss(animated: true)
                }
            }
        }
        
        func switchToController(_ type: AttachmentButtonType, animated: Bool = true) -> Bool {
            guard self.currentType != type else {
                if self.animating {
                    return false
                }
                if let controller = self.currentControllers.last {
                    controller.scrollToTopWithTabBar?()
                    controller.requestAttachmentMenuExpansion()
                }
                return true
            }
            let previousType = self.currentType
            self.currentType = type
            self.controller?.requestController(type, { [weak self] controller, mediaPickerContext in
                if let strongSelf = self {
                    if let controller = controller  {
                        strongSelf.controller?._ready.set(controller.ready.get())
                        controller._presentedInModal = true
                        controller.navigation_setPresenting(strongSelf.controller)
                        controller.requestAttachmentMenuExpansion = { [weak self] in
                            if let strongSelf = self, !strongSelf.container.isTracking {
                                strongSelf.container.update(isExpanded: true, transition: .animated(duration: 0.4, curve: .spring))
                            }
                        }
                        controller.updateNavigationStack = { [weak self] f in
                            if let strongSelf = self {
                                let (controllers, mediaPickerContext) = f(strongSelf.currentControllers)
                                strongSelf.currentControllers = controllers
                                strongSelf.mediaPickerContext = mediaPickerContext
                                if let layout = strongSelf.validLayout {
                                    strongSelf.containerLayoutUpdated(layout, transition: .animated(duration: 0.4, curve: .spring))
                                }
                            }
                        }
                        controller.updateTabBarAlpha = { [weak self, weak controller] alpha, transition in
                            if let strongSelf = self, strongSelf.currentControllers.contains(where: { $0 === controller }) {
                                strongSelf.panel.updateBackgroundAlpha(alpha, transition: transition)
                            }
                        }
                        controller.cancelPanGesture = { [weak self] in
                            if let strongSelf = self {
                                strongSelf.container.cancelPanGesture()
                            }
                        }
                        
                        controller.isContainerPanning = { [weak self] in
                            if let strongSelf = self {
                                return strongSelf.container.isPanning
                            } else {
                                return false
                            }
                        }
                        
                        controller.isContainerExpanded = { [weak self] in
                            if let strongSelf = self {
                                return strongSelf.container.isExpanded
                            } else {
                                return false
                            }
                        }
                        
                        let previousController = strongSelf.currentControllers.last
                        strongSelf.currentControllers = [controller]
                        
                        if previousType != nil && animated {
                            strongSelf.animateSwitchTransition(controller, previousController: previousController)
                        }
                        
                        if let layout = strongSelf.validLayout {
                            strongSelf.switchingController = true
                            strongSelf.containerLayoutUpdated(layout, transition: animated ? .animated(duration: 0.3, curve: .spring) : .immediate)
                            strongSelf.switchingController = false
                        }
                    }
                    strongSelf.mediaPickerContext = mediaPickerContext
                }
            })
            return true
        }
        
        private func animateSwitchTransition(_ controller: AttachmentContainable, previousController: AttachmentContainable?) {
            guard let snapshotView = self.container.container.view.snapshotView(afterScreenUpdates: false) else {
                return
            }
            
            snapshotView.frame = self.container.container.frame
            self.container.clipNode.view.addSubview(snapshotView)
            
            let _ = (controller.ready.get()
            |> filter {
                $0
            }
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self, weak snapshotView] _ in
                guard let strongSelf = self, let layout = strongSelf.validLayout else {
                    return
                }
                
                if case .compact = layout.metrics.widthClass {
                    let offset = 25.0
                    
                    let initialPosition = strongSelf.container.clipNode.layer.position
                    let targetPosition = initialPosition.offsetBy(dx: 0.0, dy: offset)
                    var startPosition = initialPosition
                    if let presentation = strongSelf.container.clipNode.layer.presentation() {
                        startPosition = presentation.position
                    }
                    
                    strongSelf.container.clipNode.layer.animatePosition(from: startPosition, to: targetPosition, duration: 0.2, removeOnCompletion: false, completion: { [weak self] finished in
                        if let strongSelf = self, finished {
                            strongSelf.container.clipNode.layer.animateSpring(from: NSValue(cgPoint: targetPosition), to: NSValue(cgPoint: initialPosition), keyPath: "position", duration: 0.4, delay: 0.0, initialVelocity: 0.0, damping: 70.0, removeOnCompletion: false, completion: { [weak self] finished in
                                if finished {
                                    self?.container.clipNode.layer.removeAllAnimations()
                                }
                            })
                        }
                    })
                }
                
                snapshotView?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.23, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                    previousController?.resetForReuse()
                })
            })
        }
        
        private var animating = false
        func animateIn() {
            guard let layout = self.validLayout else {
                return
            }
            
            self.animating = true
            if case .regular = layout.metrics.widthClass {
                self.animating = false
                
                ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear).updateAlpha(node: self.dim, alpha: 0.1)
            } else {
                ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear).updateAlpha(node: self.dim, alpha: 1.0)
                
                let targetPosition = self.container.position
                let startPosition = targetPosition.offsetBy(dx: 0.0, dy: layout.size.height)
                
                self.container.position = startPosition
                let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                transition.animateView(allowUserInteraction: true, {
                    self.container.position = targetPosition
                }, completion: { _ in
                    self.animating = false
                })
            }
        }
        
        func animateOut(completion: @escaping () -> Void = {}) {
            guard let controller = self.controller else {
                return
            }
            self.isDismissing = true
            
            guard let layout = self.validLayout else {
                return
            }
            
            self.animating = true
            if case .regular = layout.metrics.widthClass {
                self.layer.allowsGroupOpacity = true
                self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak self] _ in
                    let _ = self?.container.dismiss(transition: .immediate, completion: completion)
                    self?.animating = false
                })
            } else {
                let positionTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
                positionTransition.updatePosition(node: self.container, position: CGPoint(x: self.container.position.x, y: self.bounds.height + self.container.bounds.height / 2.0), completion: { [weak self] _ in
                    let _ = self?.container.dismiss(transition: .immediate, completion: completion)
                    self?.animating = false
                })
                let alphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
                alphaTransition.updateAlpha(node: self.dim, alpha: 0.0)
                
                self.controller?.updateModalStyleOverlayTransitionFactor(0.0, transition: positionTransition)
                
                if controller.fromMenu && self.hasButton, let (_, _, getTransition) = controller.getInputContainerNode(), let inputTransition = getTransition() {
                    self.panel.animateTransitionOut(inputTransition: inputTransition, dismissed: true, transition: positionTransition)
                    self.containerLayoutUpdated(layout, transition: positionTransition)
                }
            }
        }
        
        func scrollToTop() {
            self.currentControllers.last?.scrollToTop?()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let controller = self.controller, controller.isInteractionDisabled() {
                return self.view
            } else {
                let result = super.hitTest(point, with: event)
                if result == self.wrapperNode.view {
                    return self.dim.view
                }
                return result
            }
        }
        
        private var isUpdatingContainer = false
        private var switchingController = false
        
        private var hasButton = false
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
            self.validLayout = layout
            
            guard let controller = self.controller else {
                return
            }
            
            transition.updateFrame(node: self.dim, frame: CGRect(origin: CGPoint(), size: layout.size))
                     
            let fromMenu = controller.fromMenu
            
            var containerLayout = layout
            let containerRect: CGRect
            var isCompact = true
            if case .regular = layout.metrics.widthClass {
                isCompact = false
                
                let availableHeight = layout.size.height - (layout.inputHeight ?? 0.0) - 60.0
                
                let size = CGSize(width: 390.0, height: min(620.0, availableHeight))
                
                let insets = layout.insets(options: [.input])
                let masterWidth = min(max(320.0, floor(layout.size.width / 3.0)), floor(layout.size.width / 2.0))
                let position: CGPoint = CGPoint(x: masterWidth - 174.0, y: layout.size.height - size.height - insets.bottom - 40.0)
                
                if controller.isStandalone {
                    var containerY = floorToScreenPixels((layout.size.height - size.height) / 2.0)
                    if let inputHeight = layout.inputHeight, inputHeight > 88.0 {
                        containerY = layout.size.height - inputHeight - size.height - 80.0
                    }
                    containerRect = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - size.width) / 2.0), y: containerY), size: size)
                } else {
                    containerRect = CGRect(origin: position, size: size)
                }
                containerLayout.size = containerRect.size
                containerLayout.intrinsicInsets.bottom = 12.0
                containerLayout.inputHeight = nil
                
                if controller.isStandalone {
                    self.wrapperNode.cornerRadius = 10.0
                } else if self.wrapperNode.view.mask == nil {
                    let maskView = UIImageView()
                    maskView.image = generateMaskImage()
                    maskView.contentMode = .scaleToFill
                    self.wrapperNode.view.mask = maskView
                }
                
                if let maskView = self.wrapperNode.view.mask {
                    transition.updateFrame(view: maskView, frame: CGRect(origin: CGPoint(), size: size))
                }
                
                self.shadowNode.alpha = 1.0
                if self.shadowNode.image == nil {
                    self.shadowNode.image = generateShadowImage()
                }
            } else {
                let containerHeight: CGFloat
                if fromMenu {
                    if let inputContainerHeight = self.inputContainerHeight {
                        containerHeight = layout.size.height - inputContainerHeight
                    } else {
                        containerHeight = layout.size.height
                    }
                } else {
                    containerHeight = layout.size.height
                }
                containerRect = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: containerHeight))
                
                self.wrapperNode.cornerRadius = 0.0
                self.shadowNode.alpha = 0.0
                
                self.wrapperNode.view.mask = nil
            }
            
            var containerInsets = containerLayout.intrinsicInsets
            var hasPanel = false
            let previousHasButton = self.hasButton
            let hasButton = self.panel.isButtonVisible && !self.isDismissing
            self.hasButton = hasButton
            if let controller = self.controller, controller.buttons.count > 1 {
                hasPanel = true
            }
                            
            let isEffecitvelyCollapsedUpdated = (self.selectionCount > 0) != (self.panel.isSelecting)
            var panelHeight = self.panel.update(layout: containerLayout, buttons: self.controller?.buttons ?? [], isSelecting: self.selectionCount > 0, elevateProgress: !hasPanel && !hasButton, transition: transition)
            if fromMenu && !hasButton, let inputContainerHeight = self.inputContainerHeight {
               panelHeight = inputContainerHeight
            }
            if hasPanel || hasButton || (fromMenu && isCompact) {
                containerInsets.bottom = panelHeight
            }
            
            var transitioning = false
            if fromMenu && previousHasButton != hasButton, let (_, _, getTransition) = controller.getInputContainerNode(), let inputTransition = getTransition() {
                if hasButton {
                    self.panel.animateTransitionIn(inputTransition: inputTransition, transition: transition)
                } else {
                    self.panel.animateTransitionOut(inputTransition: inputTransition, dismissed: false, transition: transition)
                }
                transitioning = true
            }
                        
            var panelTransition = transition
            if isEffecitvelyCollapsedUpdated {
                panelTransition = .animated(duration: 0.25, curve: .easeInOut)
            }
            var panelY = containerRect.height - panelHeight
            if fromMenu && isCompact {
                panelY = layout.size.height - panelHeight
            } else if !hasPanel && !hasButton {
                panelY = containerRect.height
            }
            
            if fromMenu && isCompact {
                if hasButton {
                    self.panel.isHidden = false
                    self.inputContainerNode?.isHidden = true
                } else if !transitioning {
                    if !self.panel.animatingTransition {
                        self.panel.isHidden = true
                        self.inputContainerNode?.isHidden = false
                    }
                }
            }
            
            panelTransition.updateFrame(node: self.panel, frame: CGRect(origin: CGPoint(x: 0.0, y: panelY), size: CGSize(width: containerRect.width, height: panelHeight)), completion: { [weak self] finished in
                if transitioning && finished, isCompact {
                    self?.panel.isHidden = !hasButton
                    self?.inputContainerNode?.isHidden = hasButton
                }
            })
            
            var shadowFrame = containerRect.insetBy(dx: -60.0, dy: -60.0)
            shadowFrame.size.height -= 12.0
            transition.updateFrame(node: self.shadowNode, frame: shadowFrame)
            transition.updateFrame(node: self.wrapperNode, frame: containerRect)
            
            if !self.isUpdatingContainer && !self.isDismissing {
                self.isUpdatingContainer = true
            
                let containerTransition: ContainedViewLayoutTransition
                if self.container.supernode == nil {
                    containerTransition = .immediate
                } else {
                    containerTransition = transition
                }
                
                let controllers = self.currentControllers
                if !self.animating {
                    containerTransition.updateFrame(node: self.container, frame: CGRect(origin: CGPoint(), size: containerRect.size))
                }
                
                let containerLayout = containerLayout.withUpdatedIntrinsicInsets(containerInsets)
                
                self.container.update(layout: containerLayout, controllers: controllers, coveredByModalTransition: 0.0, transition: self.switchingController ? .immediate : transition)
                                    
                if self.container.supernode == nil, !controllers.isEmpty && self.container.isReady {
                    self.wrapperNode.addSubnode(self.container)
                    
                    if fromMenu, let _ = controller.getInputContainerNode() {
                        self.addSubnode(self.panel)
                    } else {
                        self.container.addSubnode(self.panel)
                    }
                    
                    self.animateIn()
                }
                
                self.isUpdatingContainer = false
            }
        }
    }
    
    public var requestController: (AttachmentButtonType, @escaping (AttachmentContainable?, AttachmentMediaPickerContext?) -> Void) -> Void = { _, completion in
        completion(nil, nil)
    }
    
    public var getInputContainerNode: () -> (CGFloat, ASDisplayNode, () -> AttachmentController.InputPanelTransition?)? = { return nil }
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, chatLocation: ChatLocation, buttons: [AttachmentButtonType], initialButton: AttachmentButtonType = .gallery, fromMenu: Bool = false) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.chatLocation = chatLocation
        self.buttons = buttons
        self.initialButton = initialButton
        self.fromMenu = fromMenu
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        self.blocksBackgroundWhenInOverlay = true
        self.acceptsFocusWhenInOverlay = true
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.node.scrollToTop()
            }
        }
    }
        
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate var isStandalone: Bool {
        return self.buttons.contains(.standalone)
    }
    
    private var node: Node {
        return self.displayNode as! Node
    }
    
    open override func loadDisplayNode() {
        self.displayNode = Node(controller: self)
        self.displayNodeDidLoad()
    }
    
    private var dismissedFlag = false
    public func _dismiss() {
        super.dismiss(animated: false, completion: {})
    }
    
    public var ensureUnfocused = true
    
    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if self.ensureUnfocused {
            self.view.endEditing(true)
        }
        if flag {
            if !self.dismissedFlag {
                self.dismissedFlag = true
                self.willDismiss()
                self.node.animateOut(completion: { [weak self] in
                    self?.didDismiss()
                    self?._dismiss()
                    completion?()
                })
            }
        } else {
            self.didDismiss()
            self._dismiss()
            completion?()
        }
    }
    
    private func isInteractionDisabled() -> Bool {
        return false
    }
    
    private var validLayout: ContainerViewLayout?
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
        self.node.containerLayoutUpdated(layout, transition: transition)
    }
    
    public final class InputPanelTransition {
        let inputNode: ASDisplayNode
        let accessoryPanelNode: ASDisplayNode?
        let menuButtonNode: ASDisplayNode
        let menuButtonBackgroundNode: ASDisplayNode
        let menuIconNode: ASDisplayNode
        let menuTextNode: ASDisplayNode
        let prepareForDismiss: () -> Void

        public init(
            inputNode: ASDisplayNode,
            accessoryPanelNode: ASDisplayNode?,
            menuButtonNode: ASDisplayNode,
            menuButtonBackgroundNode: ASDisplayNode,
            menuIconNode: ASDisplayNode,
            menuTextNode: ASDisplayNode,
            prepareForDismiss: @escaping () -> Void
        ) {
            self.inputNode = inputNode
            self.accessoryPanelNode = accessoryPanelNode
            self.menuButtonNode = menuButtonNode
            self.menuButtonBackgroundNode = menuButtonBackgroundNode
            self.menuIconNode = menuIconNode
            self.menuTextNode = menuTextNode
            self.prepareForDismiss = prepareForDismiss
        }
    }
    
    public static func preloadAttachBotIcons(context: AccountContext) -> DisposableSet {
        let disposableSet = DisposableSet()
        let _ = (context.engine.messages.attachMenuBots()
        |> take(1)
        |> deliverOnMainQueue).start(next: { bots in
            for bot in bots {
                for (name, file) in bot.icons {
                    if [.iOSAnimated, .placeholder].contains(name), let peer = PeerReference(bot.peer) {
                        if case .placeholder = name {
                            let path = context.account.postbox.mediaBox.cachedRepresentationCompletePath(file.resource.id, representation: CachedPreparedSvgRepresentation())
                            if !FileManager.default.fileExists(atPath: path) {
                                let accountFullSizeData = Signal<(Data?, Bool), NoError> { subscriber in
                                    let accountResource = context.account.postbox.mediaBox.cachedResourceRepresentation(file.resource, representation: CachedPreparedSvgRepresentation(), complete: false, fetch: true)
                                    
                                    let fetchedFullSize = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .media(media: .attachBot(peer: peer, media: file), resource: file.resource))
                                    let fetchedFullSizeDisposable = fetchedFullSize.start()
                                    let fullSizeDisposable = accountResource.start()
                                    
                                    return ActionDisposable {
                                        fetchedFullSizeDisposable.dispose()
                                        fullSizeDisposable.dispose()
                                    }
                                }
                                disposableSet.add(accountFullSizeData.start())
                            }
                        } else {
                            disposableSet.add(freeMediaFileInteractiveFetched(account: context.account, fileReference: .attachBot(peer: peer, media: file)).start())
                        }
                    }
                }
            }
        })
        return disposableSet
    }
}
