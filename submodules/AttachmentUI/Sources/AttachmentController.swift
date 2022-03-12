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

public enum AttachmentButtonType: Equatable {
    case gallery
    case file
    case location
    case contact
    case poll
    case app(String)
}

public protocol AttachmentContainable: ViewController {
    var requestAttachmentMenuExpansion: () -> Void { get set }
    var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void { get set }
    var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void { get set }
    var cancelPanGesture: () -> Void { get set }
    
    func resetForReuse()
    func prepareForReuse()
    
    func requestDismiss(completion: @escaping () -> Void)
}

public extension AttachmentContainable {
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
                } else {
                    self.updateSelectionCount(0)
                    self.mediaSelectionCountDisposable.set(nil)
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
            
            self.panel.selectionChanged = { [weak self] type, ascending in
                if let strongSelf = self {
                    return strongSelf.switchToController(type, ascending)
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
        
        override func didLoad() {
            super.didLoad()
            
            self.dim.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            let _ = self.switchToController(.gallery, false)
        }
        
        private func updateSelectionCount(_ count: Int) {
            self.selectionCount = count
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout, transition: .animated(duration: 0.4, curve: .spring))
            }
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
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
        
        func switchToController(_ type: AttachmentButtonType, _ ascending: Bool) -> Bool {
            guard self.currentType != type else {
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
                            self?.container.update(isExpanded: true, transition: .animated(duration: 0.4, curve: .spring))
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
                        let previousController = strongSelf.currentControllers.last
                        strongSelf.currentControllers = [controller]
                        
                        if previousType != nil {
                            strongSelf.animateSwitchTransition(controller, previousController: previousController)
                        }
                        
                        if let layout = strongSelf.validLayout {
                            strongSelf.switchingController = true
                            strongSelf.containerLayoutUpdated(layout, transition: .animated(duration: 0.3, curve: .spring))
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
            
            self.animating = true
            
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
                                    self?.animating = false
                                }
                            })
                        }
                    })
                } else {
                    strongSelf.animating = false
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
                let startPosition = targetPosition.offsetBy(dx: 0.0, dy: self.bounds.height)
                
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
            self.isDismissing = true
            
            guard let layout = self.validLayout else {
                return
            }
            
            self.animating = true
            if case .regular = layout.metrics.widthClass {
                self.layer.allowsGroupOpacity = true
                self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
                    let _ = self.container.dismiss(transition: .immediate, completion: completion)
                    self.animating = false
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
        func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
            self.validLayout = layout
            
            transition.updateFrame(node: self.dim, frame: CGRect(origin: CGPoint(), size: layout.size))
                          
            var containerLayout = layout
            let containerRect: CGRect
            if case .regular = layout.metrics.widthClass {
                let availableHeight = layout.size.height - (layout.inputHeight ?? 0.0) - 60.0
                
                let size = CGSize(width: 390.0, height: min(620.0, availableHeight))
                
                let insets = layout.insets(options: [.input])
                let masterWidth = min(max(320.0, floor(layout.size.width / 3.0)), floor(layout.size.width / 2.0))
                let position: CGPoint = CGPoint(x: masterWidth - 174.0, y: layout.size.height - size.height - insets.bottom - 40.0)
                
                containerRect = CGRect(origin: position, size: size)
                containerLayout.size = containerRect.size
                containerLayout.intrinsicInsets.bottom = 12.0
                containerLayout.inputHeight = nil
                
                if self.wrapperNode.view.mask == nil {
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
                containerRect = CGRect(origin: CGPoint(), size: layout.size)
                
                self.wrapperNode.cornerRadius = 0.0
                self.shadowNode.alpha = 0.0
                
                self.wrapperNode.view.mask = nil
            }
            
            
            let isEffecitvelyCollapsedUpdated = (self.selectionCount > 0) != (self.panel.isSelecting)
            let panelHeight = self.panel.update(layout: containerLayout, buttons: self.controller?.buttons ?? [], isSelecting: self.selectionCount > 0, transition: transition)
            var panelTransition = transition
            if isEffecitvelyCollapsedUpdated {
                panelTransition = .animated(duration: 0.25, curve: .easeInOut)
            }
            panelTransition.updateFrame(node: self.panel, frame: CGRect(origin: CGPoint(x: 0.0, y: containerRect.height - panelHeight), size: CGSize(width: containerRect.width, height: panelHeight)))
            
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
                containerTransition.updateFrame(node: self.container, frame: CGRect(origin: CGPoint(), size: containerRect.size))
                
                var containerInsets = containerLayout.intrinsicInsets
                containerInsets.bottom = panelHeight
                let containerLayout = containerLayout.withUpdatedIntrinsicInsets(containerInsets)
                
                self.container.update(layout: containerLayout, controllers: controllers, coveredByModalTransition: 0.0, transition: self.switchingController ? .immediate : transition)
                                    
                if self.container.supernode == nil, !controllers.isEmpty && self.container.isReady {
                    self.wrapperNode.addSubnode(self.container)
                    self.container.addSubnode(self.panel)
                    
                    self.animateIn()
                }
                
                self.isUpdatingContainer = false
            }
        }
    }
    
    public var requestController: (AttachmentButtonType, @escaping (AttachmentContainable?, AttachmentMediaPickerContext?) -> Void) -> Void = { _, completion in
        completion(nil, nil)
    }
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, chatLocation: ChatLocation, buttons: [AttachmentButtonType]) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.chatLocation = chatLocation
        self.buttons = buttons
        
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
    
    private var node: Node {
        return self.displayNode as! Node
    }
    
    open override func loadDisplayNode() {
        self.displayNode = Node(controller: self)
        self.displayNodeDidLoad()
    }
    
    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        self.view.endEditing(true)
        if flag {
            self.node.animateOut(completion: {
                super.dismiss(animated: false, completion: {})
                completion?()
            })
        } else {
            super.dismiss(animated: false, completion: {})
            completion?()
        }
    }
    
    private func isInteractionDisabled() -> Bool {
        return false
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.node.containerLayoutUpdated(layout, transition: transition)
    }
}
