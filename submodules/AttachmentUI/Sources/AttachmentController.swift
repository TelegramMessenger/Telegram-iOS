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
    
    func resetForReuse()
    func prepareForReuse()
}

public extension AttachmentContainable {
    func resetForReuse() {
        
    }
    
    func prepareForReuse() {
        
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

public class AttachmentController: ViewController {
    private let context: AccountContext
    private let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    private let buttons: [AttachmentButtonType]
    
    public var mediaPickerContext: AttachmentMediaPickerContext? {
        get {
            return self.node.mediaPickerContext
        }
        set {
            self.node.mediaPickerContext = newValue
        }
    }
        
    private final class Node: ASDisplayNode {
        private weak var controller: AttachmentController?
        private let dim: ASDisplayNode
        private let container: AttachmentContainer
        let panel: AttachmentPanel
        
        private var currentType: AttachmentButtonType?
        private var currentController: AttachmentContainable?
        
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
                        
        init(controller: AttachmentController) {
            self.controller = controller
            
            self.dim = ASDisplayNode()
            self.dim.alpha = 0.0
            self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
            
            self.container = AttachmentContainer()
            self.container.canHaveKeyboardFocus = true
            self.panel = AttachmentPanel(context: controller.context, updatedPresentationData: controller.updatedPresentationData)
                        
            super.init()
            
            self.addSubnode(self.dim)
                        
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
                    strongSelf.switchToController(type, ascending)
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
            
            self.switchToController(.gallery, false)
        }
        
        private func updateSelectionCount(_ count: Int) {
            self.selectionCount = count
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout, transition: .animated(duration: 0.4, curve: .spring))
            }
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.controller?.dismiss(animated: true)
            }
        }
        
        func switchToController(_ type: AttachmentButtonType, _ ascending: Bool) {
            guard self.currentType != type else {
                if let controller = self.currentController {
                    controller.scrollToTopWithTabBar?()
                }
                return
            }
            let previousType = self.currentType
            self.currentType = type
            self.controller?.requestController(type, { [weak self] controller, mediaPickerContext in
                if let strongSelf = self {
                    strongSelf.mediaPickerContext = mediaPickerContext
                    if let controller = controller  {
                        controller._presentedInModal = true
                        controller.navigation_setPresenting(strongSelf.controller)
                        controller.requestAttachmentMenuExpansion = { [weak self] in
                            self?.container.update(isExpanded: true, transition: .animated(duration: 0.4, curve: .spring))
                        }
                        
                        let previousController = strongSelf.currentController
                        let animateTransition = previousType != nil
                        strongSelf.currentController = controller
                        
                        if animateTransition, let snapshotView = strongSelf.container.container.view.snapshotView(afterScreenUpdates: false) {
                            snapshotView.frame = strongSelf.container.container.frame
                            strongSelf.container.clipNode.view.addSubview(snapshotView)
                            
                            let _ = (controller.ready.get()
                            |> filter {
                                $0
                            }
                            |> take(1)
                            |> deliverOnMainQueue).start(next: { [weak self, weak snapshotView] _ in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.container.container.view.layer.animatePosition(from: CGPoint(x: ascending ? 70.0 : -70.0, y: 0.0), to: CGPoint(), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                                snapshotView?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                    snapshotView?.removeFromSuperview()
                                    previousController?.prepareForReuse()
                                })
                            })
                        }
                        
                        if let layout = strongSelf.validLayout {
                            strongSelf.switchingController = true
                            strongSelf.containerLayoutUpdated(layout, transition: .animated(duration: 0.3, curve: .spring))
                            strongSelf.switchingController = false
                        }
                    }
                }
            })
        }
        
        func animateIn() {
            ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear).updateAlpha(node: self.dim, alpha: 1.0)
            
            let targetPosition = self.container.position
            let startPosition = targetPosition.offsetBy(dx: 0.0, dy: self.bounds.height)
            
            self.container.position = startPosition
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            transition.animateView(allowUserInteraction: true, {
                self.container.position = targetPosition
            })
        }
        
        func animateOut(completion: @escaping () -> Void = {}) {
            self.isDismissing = true
            
            let positionTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            positionTransition.updatePosition(node: self.container, position: CGPoint(x: self.container.position.x, y: self.bounds.height + self.container.bounds.height / 2.0), completion: { [weak self] _ in
                let _ = self?.container.dismiss(transition: .immediate, completion: completion)
            })
            let alphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            alphaTransition.updateAlpha(node: self.dim, alpha: 0.0)
            
            self.controller?.updateModalStyleOverlayTransitionFactor(0.0, transition: positionTransition)
        }
        
        func scrollToTop() {
            self.currentController?.scrollToTop?()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let controller = self.controller, controller.isInteractionDisabled() {
                return self.view
            } else {
                return super.hitTest(point, with: event)
            }
        }
        
        private var isCollapsed: Bool = false
        private var isUpdatingContainer = false
        private var switchingController = false
        func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
            self.validLayout = layout
            
            transition.updateFrame(node: self.dim, frame: CGRect(origin: CGPoint(), size: layout.size))
                          
            if self.modalProgress < 0.5 {
                self.isCollapsed = false
            } else if self.modalProgress == 1.0 {
                self.isCollapsed = true
            }
            
            let isEffecitvelyCollapsedUpdated = (self.isCollapsed || self.selectionCount > 0) != (self.panel.isCollapsed || self.panel.isSelecting)
            let panelHeight = self.panel.update(layout: layout, buttons: self.controller?.buttons ?? [], isCollapsed: self.isCollapsed, isSelecting: self.selectionCount > 0, transition: transition)
            var panelTransition = transition
            if isEffecitvelyCollapsedUpdated {
                panelTransition = .animated(duration: 0.25, curve: .easeInOut)
            }
            panelTransition.updateFrame(node: self.panel, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - panelHeight), size: CGSize(width: layout.size.width, height: panelHeight)))
            
            if !self.isUpdatingContainer && !self.isDismissing {
                self.isUpdatingContainer = true
            
                let containerTransition: ContainedViewLayoutTransition
                if self.container.supernode == nil {
                    containerTransition = .immediate
                } else {
                    containerTransition = transition
                }
                
                let controllers = self.currentController.flatMap { [$0] } ?? []
                containerTransition.updateFrame(node: self.container, frame: CGRect(origin: CGPoint(), size: layout.size))
                
                var containerInsets = layout.intrinsicInsets
                containerInsets.bottom = panelHeight
                let containerLayout = layout.withUpdatedIntrinsicInsets(containerInsets)
                
                self.container.update(layout: containerLayout, controllers: controllers, coveredByModalTransition: 0.0, transition: self.switchingController ? .immediate : transition)
                                    
                if self.container.supernode == nil, !controllers.isEmpty && self.container.isReady {
                    self.addSubnode(self.container)
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
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, buttons: [AttachmentButtonType]) {
        self.context = context
        self.buttons = buttons
        self.updatedPresentationData = updatedPresentationData
        
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
