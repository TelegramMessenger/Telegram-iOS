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
import LegacyMessageInputPanel
import LegacyMessageInputPanelInputView
import AttachmentTextInputPanelNode
import ChatSendMessageActionUI
import MinimizedContainer

public enum AttachmentButtonType: Equatable {
    case gallery
    case file
    case location
    case todo
    case quickReply
    case contact
    case poll
    case app(AttachMenuBot)
    case gift
    case standalone
    
    public var key: String {
        switch self {
        case .gallery:
            return "gallery"
        case .file:
            return "file"
        case .location:
            return "location"
        case .todo:
            return "todo"
        case .quickReply:
            return "quickReply"
        case .contact:
            return "contact"
        case .poll:
            return "poll"
        case let .app(bot):
            return "app_\(bot.shortName)"
        case .gift:
            return "gift"
        case .standalone:
            return "standalone"
        }
    }
    
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
        case .todo:
            if case .todo = rhs {
                return true
            } else {
                return false
            }
        case .quickReply:
            if case .quickReply = rhs {
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
        case let .app(lhsBot):
            if case let .app(rhsBot) = rhs, lhsBot.peer.id == rhsBot.peer.id {
                return true
            } else {
                return false
            }
        case .gift:
            if case .gift = rhs {
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

public protocol AttachmentContainable: ViewController, MinimizableController {
    var requestAttachmentMenuExpansion: () -> Void { get set }
    var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void { get set }
    var parentController: () -> ViewController? { get set }
    var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void { get set }
    var updateTabBarVisibility: (Bool, ContainedViewLayoutTransition) -> Void { get set }
    var cancelPanGesture: () -> Void { get set }
    var isContainerPanning: () -> Bool { get set }
    var isContainerExpanded: () -> Bool { get set }
    var isPanGestureEnabled: (() -> Bool)? { get }
    var isInnerPanGestureEnabled: (() -> Bool)? { get }
    var mediaPickerContext: AttachmentMediaPickerContext? { get }
    var getCurrentSendMessageContextMediaPreview: (() -> ChatSendMessageContextScreenMediaPreview?)? { get }
        
    func isContainerPanningUpdated(_ panning: Bool)
    
    func resetForReuse()
    func prepareForReuse()
    
    func requestDismiss(completion: @escaping () -> Void)
    func shouldDismissImmediately() -> Bool
    
    func beforeMaximize(navigationController: NavigationController, completion: @escaping () -> Void)
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
    
    func shouldDismissImmediately() -> Bool {
         return true
    }
    
    func beforeMaximize(navigationController: NavigationController, completion: @escaping () -> Void) {
        completion()
    }
    
    var minimizedBounds: CGRect? {
        return nil
    }
    
    var isFullscreen: Bool {
        return false
    }
    
    var minimizedTopEdgeOffset: CGFloat? {
        return nil
    }
    
    var minimizedIcon: UIImage? {
        return nil
    }
    
    var minimizedProgress: Float? {
        return nil
    }
    
    var isPanGestureEnabled: (() -> Bool)? {
        return nil
    }
    
    var isInnerPanGestureEnabled: (() -> Bool)? {
        return nil
    }
    
    var getCurrentSendMessageContextMediaPreview: (() -> ChatSendMessageContextScreenMediaPreview?)? {
        return nil
    }
}

public enum AttachmentMediaPickerSendMode {
    case generic
    case silently
    case whenOnline
}

public enum AttachmentMediaPickerAttachmentMode {
    case media
    case files
}

public protocol AttachmentMediaPickerContext {
    var selectionCount: Signal<Int, NoError> { get }
    var caption: Signal<NSAttributedString?, NoError> { get }
    
    var hasCaption: Bool { get }
    var captionIsAboveMedia: Signal<Bool, NoError> { get }
    func setCaptionIsAboveMedia(_ captionIsAboveMedia: Bool) -> Void
    
    var canMakePaidContent: Bool { get }
    var price: Int64? { get }
    func setPrice(_ price: Int64) -> Void
    
    var hasTimers: Bool { get }
    
    var loadingProgress: Signal<CGFloat?, NoError> { get }
    var mainButtonState: Signal<AttachmentMainButtonState?, NoError> { get }
    var secondaryButtonState: Signal<AttachmentMainButtonState?, NoError> { get }
    var bottomPanelBackgroundColor: Signal<UIColor?, NoError> { get }
    
    func mainButtonAction()
    func secondaryButtonAction()
    
    func setCaption(_ caption: NSAttributedString)
    func send(mode: AttachmentMediaPickerSendMode, attachmentMode: AttachmentMediaPickerAttachmentMode, parameters: ChatSendMessageActionSheetController.SendParameters?)
    func schedule(parameters: ChatSendMessageActionSheetController.SendParameters?)
}

public extension AttachmentMediaPickerContext {
    var selectionCount: Signal<Int, NoError> {
        return .single(0)
    }
    
    var caption: Signal<NSAttributedString?, NoError> {
        return .single(nil)
    }
    
    var captionIsAboveMedia: Signal<Bool, NoError> {
        return .single(false)
    }
    
    var hasCaption: Bool {
        return false
    }
    
    func setCaptionIsAboveMedia(_ captionIsAboveMedia: Bool) -> Void {
    }

    var canMakePaidContent: Bool {
        return false
    }

    var price: Int64? {
        return nil
    }
    
    func setPrice(_ price: Int64) -> Void {
    }
    
    var hasTimers: Bool {
        return false
    }
    
    var loadingProgress: Signal<CGFloat?, NoError> {
        return .single(nil)
    }
    
    var mainButtonState: Signal<AttachmentMainButtonState?, NoError> {
        return .single(nil)
    }
    
    var secondaryButtonState: Signal<AttachmentMainButtonState?, NoError> {
        return .single(nil)
    }
    
    var bottomPanelBackgroundColor: Signal<UIColor?, NoError> {
        return .single(nil)
    }
            
    func setCaption(_ caption: NSAttributedString) {
    }
    
    func send(mode: AttachmentMediaPickerSendMode, attachmentMode: AttachmentMediaPickerAttachmentMode, parameters: ChatSendMessageActionSheetController.SendParameters?) {
    }
    
    func schedule(parameters: ChatSendMessageActionSheetController.SendParameters?) {
    }
    
    func mainButtonAction() {
    }
    
    func secondaryButtonAction() {
    }
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

public class AttachmentController: ViewController, MinimizableController {
    private let context: AccountContext
    private let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    private let chatLocation: ChatLocation?
    private let isScheduledMessages: Bool
    private var buttons: [AttachmentButtonType]
    private let initialButton: AttachmentButtonType
    private let fromMenu: Bool
    private var hasTextInput: Bool
    private let isFullSize: Bool
    private let makeEntityInputView: () -> AttachmentTextInputPanelInputView?
    public var animateAppearance: Bool = false
    
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
    
    public private(set) var minimizedTopEdgeOffset: CGFloat?
    public private(set) var minimizedBounds: CGRect?
    public var minimizedIcon: UIImage? {
        return self.mainController.minimizedIcon
    }
    
    public var isFullscreen: Bool {
        return self.mainController.isFullscreen
    }
        
    private final class Node: ASDisplayNode {
        private weak var controller: AttachmentController?
        fileprivate let dim: ASDisplayNode
        private let shadowNode: ASImageNode
        fileprivate let container: AttachmentContainer
        private let makeEntityInputView: () -> AttachmentTextInputPanelInputView?
        let panel: AttachmentPanel
        
        fileprivate var currentType: AttachmentButtonType?
        fileprivate var currentControllers: [AttachmentContainable] = []
        
        private var validLayout: ContainerViewLayout?
        private var modalProgress: CGFloat = 0.0
        fileprivate var isDismissing = false
                
        private let captionDisposable = MetaDisposable()
        private let mediaSelectionCountDisposable = MetaDisposable()
        
        private let loadingProgressDisposable = MetaDisposable()
        private let mainButtonStateDisposable = MetaDisposable()
        private let secondaryButtonStateDisposable = MetaDisposable()
        private let bottomPanelBackgroundColorDisposable = MetaDisposable()
        
        private var selectionCount: Int = 0
        
        var mediaPickerContext: AttachmentMediaPickerContext? {
            didSet {
                if let mediaPickerContext = self.mediaPickerContext {
                    self.captionDisposable.set((mediaPickerContext.caption
                    |> deliverOnMainQueue).startStrict(next: { [weak self] caption in
                        if let strongSelf = self {
                            strongSelf.panel.updateCaption(caption ?? NSAttributedString())
                        }
                    }))
                    self.mediaSelectionCountDisposable.set((mediaPickerContext.selectionCount
                    |> deliverOnMainQueue).startStrict(next: { [weak self] count in
                        if let strongSelf = self {
                            strongSelf.updateSelectionCount(count)
                        }
                    }))
                    self.loadingProgressDisposable.set((mediaPickerContext.loadingProgress
                    |> deliverOnMainQueue).startStrict(next: { [weak self] progress in
                        if let strongSelf = self {
                            strongSelf.panel.updateLoadingProgress(progress)
                            if let layout = strongSelf.validLayout {
                                strongSelf.containerLayoutUpdated(layout, transition: .animated(duration: 0.4, curve: .spring))
                            }
                        }
                    }))
                    self.mainButtonStateDisposable.set((mediaPickerContext.mainButtonState
                    |> deliverOnMainQueue).startStrict(next: { [weak self] mainButtonState in
                        if let strongSelf = self {
                            let _ = (strongSelf.panel.animatingTransitionPromise.get()
                            |> filter { value in
                                return !value
                            }
                            |> take(1)).startStandalone(next: { [weak self] _ in
                                if let strongSelf = self {
                                    strongSelf.panel.updateMainButtonState(mainButtonState)
                                    if let layout = strongSelf.validLayout {
                                        strongSelf.containerLayoutUpdated(layout, transition: .animated(duration: 0.4, curve: .spring))
                                    }
                                }
                            })
                        }
                    }))
                    self.secondaryButtonStateDisposable.set((mediaPickerContext.secondaryButtonState
                    |> deliverOnMainQueue).startStrict(next: { [weak self] mainButtonState in
                        if let strongSelf = self {
                            let _ = (strongSelf.panel.animatingTransitionPromise.get()
                            |> filter { value in
                                return !value
                            }
                            |> take(1)).startStandalone(next: { [weak self] _ in
                                if let strongSelf = self {
                                    strongSelf.panel.updateSecondaryButtonState(mainButtonState)
                                    if let layout = strongSelf.validLayout {
                                        strongSelf.containerLayoutUpdated(layout, transition: .animated(duration: 0.4, curve: .spring))
                                    }
                                }
                            })
                        }
                    }))
                    self.bottomPanelBackgroundColorDisposable.set((mediaPickerContext.bottomPanelBackgroundColor
                    |> deliverOnMainQueue).startStrict(next: { [weak self] color in
                        if let strongSelf = self {
                            let _ = (strongSelf.panel.animatingTransitionPromise.get()
                            |> filter { value in
                                return !value
                            }
                            |> take(1)).startStandalone(next: { [weak self] _ in
                                if let strongSelf = self {
                                    strongSelf.panel.updateCustomBottomPanelBackgroundColor(color)
                                }
                            })
                        }
                    }))
                } else {
                    self.updateSelectionCount(0)
                    self.mediaSelectionCountDisposable.set(nil)
                    self.loadingProgressDisposable.set(nil)
                    self.mainButtonStateDisposable.set(nil)
                    self.secondaryButtonStateDisposable.set(nil)
                    self.bottomPanelBackgroundColorDisposable.set(nil)
                }
            }
        }
                 
        private let wrapperNode: ASDisplayNode
        
        private var isMinimizing = false
        
        init(controller: AttachmentController, makeEntityInputView: @escaping () -> AttachmentTextInputPanelInputView?) {
            self.controller = controller
            self.makeEntityInputView = makeEntityInputView
            
            self.dim = ASDisplayNode()
            self.dim.alpha = 0.0
            self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
            
            self.shadowNode = ASImageNode()
            self.shadowNode.isUserInteractionEnabled = false
            
            self.wrapperNode = ASDisplayNode()
            self.wrapperNode.clipsToBounds = true
            
            self.container = AttachmentContainer(isFullSize: controller.isFullSize)
            self.container.canHaveKeyboardFocus = true
            self.panel = AttachmentPanel(controller: controller, context: controller.context, chatLocation: controller.chatLocation, isScheduledMessages: controller.isScheduledMessages, updatedPresentationData: controller.updatedPresentationData, makeEntityInputView: makeEntityInputView)
            self.panel.fromMenu = controller.fromMenu
            self.panel.isStandalone = controller.isStandalone
            
            super.init()
            
            self.clipsToBounds = false
            
            self.addSubnode(self.dim)
            self.addSubnode(self.shadowNode)
            self.addSubnode(self.wrapperNode)
                        
            self.container.controllerRemoved = { [weak self] controller in
                if let strongSelf = self, let layout = strongSelf.validLayout, !strongSelf.isDismissing {
                    strongSelf.currentControllers = strongSelf.currentControllers.filter { $0 !== controller }
                    strongSelf.containerLayoutUpdated(layout, transition: .immediate)
                }
            }
            
            self.container.updateModalProgress = { [weak self] progress, topInset, bounds, transition in
                if let strongSelf = self, let layout = strongSelf.validLayout, !strongSelf.isDismissing {
                    var transition = transition
                    if strongSelf.container.supernode == nil {
                        transition = .animated(duration: 0.4, curve: .spring)
                    }
                    
                    strongSelf.modalProgress = progress
                    strongSelf.controller?.minimizedTopEdgeOffset = topInset
                    strongSelf.controller?.minimizedBounds = bounds
                    
                    if !strongSelf.isMinimizing {
                        strongSelf.controller?.updateModalStyleOverlayTransitionFactor(progress, transition: transition)
                        strongSelf.containerLayoutUpdated(layout, transition: transition)
                    }
                }
            }
            self.container.isReadyUpdated = { [weak self] in
                if let strongSelf = self, let layout = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, transition: .animated(duration: 0.4, curve: .spring))
                }
            }
            
            self.container.interactivelyDismissed = { [weak self] velocity in
                if let strongSelf = self, let layout = strongSelf.validLayout {
                    if let controller = strongSelf.controller, controller.shouldMinimizeOnSwipe?(strongSelf.currentType) == true {
                        var delta = layout.size.height
                        if let minimizedTopEdgeOffset = controller.minimizedTopEdgeOffset {
                            delta -= minimizedTopEdgeOffset
                        }
                        let damping: CGFloat = 180.0
                        let initialVelocity: CGFloat = delta > 0.0 ? velocity / delta : 0.0

                        strongSelf.minimize(damping: damping, initialVelocity: initialVelocity)
                        
                        return false
                    } else {
                        strongSelf.controller?.dismiss(animated: true)
                    }
                }
                return true
            }
            
            self.container.isPanningUpdated = { [weak self] value in
                if let strongSelf = self, let currentController = strongSelf.currentControllers.last, !value {
                    currentController.isContainerPanningUpdated(value)
                }
            }
            
            self.container.isPanGestureEnabled = { [weak self] in
                guard let self, let currentController = self.currentControllers.last else {
                    return true
                }
                if let isPanGestureEnabled = currentController.isPanGestureEnabled {
                    return isPanGestureEnabled()
                } else {
                    return true
                }
            }
            
            self.container.isInnerPanGestureEnabled = { [weak self] in
                guard let self, let currentController = self.currentControllers.last else {
                    return true
                }
                if let isInnerPanGestureEnabled = currentController.isInnerPanGestureEnabled {
                    return isInnerPanGestureEnabled()
                } else {
                    return true
                }
            }
            
            self.container.shouldCancelPanGesture = { [weak self] in
                if let strongSelf = self, let currentController = strongSelf.currentControllers.last {
                    if !currentController.shouldDismissImmediately() {
                        return true
                    } else {
                        return false
                    }
                } else {
                    return false
                }
            }
            
            self.container.requestDismiss = { [weak self] in
                if let strongSelf = self, let currentController = strongSelf.currentControllers.last {
                    currentController.requestDismiss { [weak self] in
                        if let strongSelf = self {
                            strongSelf.controller?.dismiss(animated: true)
                        }
                    }
                }
            }
            
            self.panel.selectionChanged = { [weak self] type in
                if let strongSelf = self {
                    return strongSelf.switchToController(type)
                } else {
                    return false
                }
            }
            
            self.panel.longPressed = { [weak self] _ in
                if let strongSelf = self, let currentController = strongSelf.currentControllers.last {
                    currentController.longTapWithTabBar?()
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
            
            self.panel.sendMessagePressed = { [weak self] mode, parameters in
                if let strongSelf = self {
                    switch mode {
                    case .generic:
                        strongSelf.mediaPickerContext?.send(mode: .generic, attachmentMode: .media, parameters: parameters)
                    case .silent:
                        strongSelf.mediaPickerContext?.send(mode: .silently, attachmentMode: .media, parameters: parameters)
                    case .schedule:
                        strongSelf.mediaPickerContext?.schedule(parameters: parameters)
                    case .whenOnline:
                        strongSelf.mediaPickerContext?.send(mode: .whenOnline, attachmentMode: .media, parameters: parameters)
                    }
                }
            }
            
            self.panel.onMainButtonPressed = { [weak self] in
                if let strongSelf = self {
                    strongSelf.mediaPickerContext?.mainButtonAction()
                }
            }
            
            self.panel.onSecondaryButtonPressed = { [weak self] in
                if let strongSelf = self {
                    strongSelf.mediaPickerContext?.secondaryButtonAction()
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
            
            self.panel.getCurrentSendMessageContextMediaPreview = { [weak self] in
                guard let self, let currentController = self.currentControllers.last else {
                    return nil
                }
                
                return currentController.getCurrentSendMessageContextMediaPreview?()
            }
        }
        
        deinit {
            self.captionDisposable.dispose()
            self.mediaSelectionCountDisposable.dispose()
            self.loadingProgressDisposable.dispose()
            self.mainButtonStateDisposable.dispose()
            self.secondaryButtonStateDisposable.dispose()
            self.bottomPanelBackgroundColorDisposable.dispose()
        }
        
        private var inputContainerHeight: CGFloat?
        private var inputContainerNode: ASDisplayNode?
        override func didLoad() {
            super.didLoad()
            
            self.view.disablesInteractiveModalDismiss = true
            
            self.dim.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            if let controller = self.controller {
                let _ = self.switchToController(controller.initialButton)
                if case let .app(bot) = controller.initialButton {
                    if let index = controller.buttons.firstIndex(where: {
                        if case let .app(otherBot) = $0, otherBot.peer.id == bot.peer.id {
                            return true
                        } else {
                            return false
                        }
                    }) {
                        self.panel.updateSelectedIndex(index)
                    }
                } else if controller.initialButton != .standalone {
                    if let index = controller.buttons.firstIndex(where: {
                        if $0 == controller.initialButton {
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
        
        fileprivate func minimize(damping: CGFloat? = nil, initialVelocity: CGFloat? = nil) {
            guard let controller = self.controller, let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            navigationController.minimizeViewController(controller, damping: damping, velocity: initialVelocity, beforeMaximize: { navigationController, completion in
                controller.mainController.beforeMaximize(navigationController: navigationController, completion: completion)
            }, setupContainer: { [weak self] current in
                let minimizedContainer: MinimizedContainerImpl?
                if let current = current as? MinimizedContainerImpl {
                    minimizedContainer = current
                } else if let context = self?.controller?.context {
                    minimizedContainer = MinimizedContainerImpl(sharedContext: context.sharedContext)
                } else {
                    minimizedContainer = nil
                }
                return minimizedContainer
            }, animated: true)
            
            self.dim.isHidden = true
            
            self.isMinimizing = true
            self.container.update(isExpanded: true, force: true, transition: .immediate)
            self.isMinimizing = false
            
            Queue.mainQueue().after(0.45, {
                self.dim.isHidden = false
            })
        }
        
        fileprivate func updateSelectionCount(_ count: Int, animated: Bool = true) {
            self.selectionCount = count
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout, transition: animated ? .animated(duration: 0.4, curve: .spring) : .immediate)
            }
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            guard !self.isDismissing else {
                return
            }
            if case .ended = recognizer.state {
                if let lastController = self.currentControllers.last {
                    if let controller = self.controller, let layout = self.validLayout, !layout.metrics.isTablet, controller.shouldMinimizeOnSwipe?(self.currentType) == true {
                        self.minimize()
                        return
                    }
                    lastController.requestDismiss(completion: { [weak self] in
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
                        controller.parentController = { [weak self] in
                            guard let self else {
                                return nil
                            }
                            return self.controller
                        }
                        controller.updateTabBarAlpha = { [weak self, weak controller] alpha, transition in
                            if let strongSelf = self, strongSelf.currentControllers.contains(where: { $0 === controller }) {
                                strongSelf.panel.updateBackgroundAlpha(alpha, transition: transition)
                            }
                        }
                        controller.updateTabBarVisibility = { [weak self, weak controller] isVisible, transition in
                            if let strongSelf = self, strongSelf.currentControllers.contains(where: { $0 === controller }) {
                                strongSelf.updateIsPanelVisible(isVisible, transition: transition)
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
            |> deliverOnMainQueue).startStandalone(next: { [weak self, weak snapshotView] _ in
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
            guard let layout = self.validLayout, let controller = self.controller else {
                return
            }
            
            self.animating = true
            if case .regular = layout.metrics.widthClass {
                if controller.animateAppearance {
                    let targetPosition = self.position
                    let startPosition = targetPosition.offsetBy(dx: 0.0, dy: layout.size.height)
                    
                    self.position = startPosition
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    transition.animateView(allowUserInteraction: true, {
                        self.position = targetPosition
                    }, completion: { _ in
                        self.animating = false
                    })
                } else {
                    self.animating = false
                }
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
                    self?.layer.removeAllAnimations()
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
        
        private var isPanelVisible: Bool = true
        
        private func updateIsPanelVisible(_ isVisible: Bool, transition: ContainedViewLayoutTransition) {
            if self.isPanelVisible == isVisible {
                return
            }
            self.isPanelVisible = isVisible
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout, transition: transition)
            }
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
            self.validLayout = layout
            
            guard let controller = self.controller else {
                return
            }
            
            transition.updateFrame(node: self.dim, frame: CGRect(origin: CGPoint(x: 0.0, y: -layout.size.height), size: CGSize(width: layout.size.width, height: layout.size.height * 2.0)))
                     
            let fromMenu = controller.fromMenu
            
            var containerLayout = layout
            let containerRect: CGRect
            if case .regular = layout.metrics.widthClass {
                if controller.isFullscreen {
                    containerRect = CGRect(origin: .zero, size: layout.size)
                    self.wrapperNode.cornerRadius = 0.0
                    self.wrapperNode.view.mask = nil
                    self.shadowNode.alpha = 0.0
                } else {
                    let availableHeight = layout.size.height - (layout.inputHeight ?? 0.0) - 60.0
                    
                    let size = CGSize(width: 390.0, height: min(620.0, availableHeight))
                    
                    let insets = layout.insets(options: [.input])
                    let masterWidth = min(max(320.0, floor(layout.size.width / 3.0)), floor(layout.size.width / 2.0))
                    
                    let position: CGPoint
                    let positionY = layout.size.height - size.height - insets.bottom - 40.0
                    if let sourceRect = controller.getSourceRect?() {
                        position = CGPoint(x: min(layout.size.width - size.width - 28.0, floor(sourceRect.midX - size.width / 2.0)), y: min(positionY, sourceRect.minY - size.height))
                    } else {
                        position = CGPoint(x: masterWidth - 174.0, y: positionY)
                    }
                    
                    if controller.isStandalone && !controller.forceSourceRect {
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
//            let previousHasButton = self.hasButton
            let hasButton = self.panel.isButtonVisible && !self.isDismissing
            self.hasButton = hasButton
            if let controller = self.controller, controller.buttons.count > 1 || controller.hasTextInput {
                hasPanel = true
            }
            if !self.isPanelVisible {
                hasPanel = false
            }
                            
            let isEffecitvelyCollapsedUpdated = (self.selectionCount > 0) != (self.panel.isSelecting)
            let panelHeight = self.panel.update(layout: containerLayout, buttons: self.controller?.buttons ?? [], isSelecting: self.selectionCount > 0, selectionCount: self.selectionCount, elevateProgress: !hasPanel && !hasButton, transition: transition)
            if hasPanel || hasButton {
                containerInsets.bottom = panelHeight
            }
                        
            var panelTransition = transition
            if isEffecitvelyCollapsedUpdated {
                panelTransition = .animated(duration: 0.25, curve: .easeInOut)
            }
            var panelY = containerRect.height - panelHeight
            if !hasPanel && !hasButton {
                panelY = containerRect.height
            }
                        
            panelTransition.updateFrame(node: self.panel, frame: CGRect(origin: CGPoint(x: 0.0, y: panelY), size: CGSize(width: containerRect.width, height: panelHeight)))
            
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
                                    
                if self.container.supernode == nil, !controllers.isEmpty && self.container.isReady && !self.isDismissing {
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
    
    public var getSourceRect: (() -> CGRect?)?
    
    public var shouldMinimizeOnSwipe: ((AttachmentButtonType?) -> Bool)?
    
    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        chatLocation: ChatLocation?,
        isScheduledMessages: Bool = false,
        buttons: [AttachmentButtonType],
        initialButton: AttachmentButtonType = .gallery,
        fromMenu: Bool = false,
        hasTextInput: Bool = true,
        isFullSize: Bool = false,
        makeEntityInputView: @escaping () -> AttachmentTextInputPanelInputView? = { return nil })
    {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.chatLocation = chatLocation
        self.isScheduledMessages = isScheduledMessages
        self.buttons = buttons
        self.initialButton = initialButton
        self.fromMenu = fromMenu
        self.hasTextInput = hasTextInput
        self.isFullSize = isFullSize
        self.makeEntityInputView = makeEntityInputView
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        self.blocksBackgroundWhenInOverlay = true
        self.acceptsFocusWhenInOverlay = true
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.context.sharedContext.currentPresentationData.with { $0 }.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.node.scrollToTop()
            }
        }
    }
        
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public var forceSourceRect = false
    
    fileprivate var isStandalone: Bool {
        return self.buttons.contains(.standalone)
    }
    
    public func convertToStandalone() {
        guard self.buttons != [.standalone] else {
            return
        }
        if case let .app(bot) = self.node.currentType {
            self.title = bot.peer.compactDisplayTitle
        }
        self.buttons = [.standalone]
        self.hasTextInput = false
        self.requestLayout(transition: .immediate)
    }
    
    public func minimizeIfNeeded() {
        if self.shouldMinimizeOnSwipe?(self.node.currentType) == true {
            self.node.minimize()
        }
    }
        
    public func updateSelectionCount(_ count: Int) {
        self.node.updateSelectionCount(count, animated: false)
    }
    
    private var node: Node {
        return self.displayNode as! Node
    }
    
    open override func loadDisplayNode() {
        self.displayNode = Node(controller: self, makeEntityInputView: self.makeEntityInputView)
        self.displayNodeDidLoad()
    }
    
    private var dismissedFlag = false
    public func _dismiss() {
        super.dismiss(animated: false, completion: {})
    }
    
    public var ensureUnfocused = true
    
    public func requestMinimize(topEdgeOffset: CGFloat?, initialVelocity: CGFloat?) {
        self.node.minimize()
    }
    
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
                    self?.dismissedFlag = false
                    self?.node.isDismissing = false
                    self?.node.container.removeFromSupernode()
                })
            }
        } else {
            self.didDismiss()
            self._dismiss()
            completion?()
            self.node.isDismissing = false
            self.node.container.removeFromSupernode()
        }
    }
    
    private func isInteractionDisabled() -> Bool {
        return false
    }
    
    public var isMinimized: Bool = false {
        didSet {
            self.mainController.isMinimized = self.isMinimized
        }
    }
    
    public var isMinimizable: Bool {
        return self.mainController.isMinimizable
    }
    
    public func shouldDismissImmediately() -> Bool {
        return self.mainController.shouldDismissImmediately()
    }
    
    private var validLayout: ContainerViewLayout?
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let previousSize = self.validLayout?.size
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
        if let previousSize, previousSize != layout.size {
            Queue.mainQueue().after(0.1) {
                self.node.containerLayoutUpdated(layout, transition: transition)
            }
        }
        self.node.containerLayoutUpdated(layout, transition: transition)
    }
    
    public var mainController: AttachmentContainable {
        return self.node.currentControllers.first!
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
        |> deliverOnMainQueue).startStandalone(next: { bots in
            for bot in bots {
                for (name, file) in bot.icons {
                    if [.iOSAnimated, .placeholder].contains(name), let peer = PeerReference(bot.peer._asPeer()) {
                        if case .placeholder = name {
                            let path = context.account.postbox.mediaBox.cachedRepresentationCompletePath(file.resource.id, representation: CachedPreparedSvgRepresentation())
                            if !FileManager.default.fileExists(atPath: path) {
                                let accountFullSizeData = Signal<(Data?, Bool), NoError> { subscriber in
                                    let accountResource = context.account.postbox.mediaBox.cachedResourceRepresentation(file.resource, representation: CachedPreparedSvgRepresentation(), complete: false, fetch: true)
                                    
                                    let fetchedFullSize = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: MediaResourceUserContentType(file: file), reference: .media(media: .attachBot(peer: peer, media: file), resource: file.resource))
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
                            disposableSet.add(freeMediaFileInteractiveFetched(account: context.account, userLocation: .other, fileReference: .attachBot(peer: peer, media: file)).start())
                        }
                    }
                }
            }
        })
        return disposableSet
    }
    
    public func makeContentSnapshotView() -> UIView? {
        let snapshotView = self.view.snapshotView(afterScreenUpdates: false)
        if let contentSnapshotView = self.mainController.makeContentSnapshotView() {
            if !self.mainController.isFullscreen {
                if let layout = self.validLayout {
                    contentSnapshotView.frame = contentSnapshotView.frame.offsetBy(dx: 0.0, dy: (layout.statusBarHeight ?? 0.0) + 10.0 + 56.0)
                }
            }
            snapshotView?.addSubview(contentSnapshotView)
        }
        return snapshotView
    }
}
