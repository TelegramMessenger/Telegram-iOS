import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import MultilineTextComponent
import ViewControllerComponent
import ComponentDisplayAdapters
import GlassBackgroundComponent

public final class AlertComponentEnvironment: Equatable {
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    
    public init(
        theme: PresentationTheme,
        strings: PresentationStrings
    ) {
        self.theme = theme
        self.strings = strings
    }
    
    public static func ==(lhs: AlertComponentEnvironment, rhs: AlertComponentEnvironment) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        return true
    }
}

private final class AlertScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let configuration: AlertScreen.Configuration
    let content: Signal<[AnyComponentWithIdentity<AlertComponentEnvironment>], NoError>
    let actions: Signal<[AlertScreen.Action], NoError>
    let ready: Promise<Bool>
    
    init(
        configuration: AlertScreen.Configuration,
        content: Signal<[AnyComponentWithIdentity<AlertComponentEnvironment>], NoError>,
        actions: Signal<[AlertScreen.Action], NoError>,
        ready: Promise<Bool>
    ) {
        self.configuration = configuration
        self.content = content
        self.actions = actions
        self.ready = ready
    }
    
    static func ==(lhs: AlertScreenComponent, rhs: AlertScreenComponent) -> Bool {
        return true
    }
    
    enum KeyCommand {
        case up
        case down
        case left
        case right
        case escape
        case enter
    }
    
    final class View: UIView, UIGestureRecognizerDelegate {
        private let dimView = UIView()
        private let containerView = GlassBackgroundContainerView()
        private let backgroundView = GlassBackgroundView()
        
        private var disposable: Disposable?
        private var content: [AnyComponentWithIdentity<AlertComponentEnvironment>]?
        private var actions: [AlertScreen.Action]?
        
        private var contentItems: [AnyHashable: ComponentView<AlertComponentEnvironment>] = [:]
        private var actionItems: [AnyHashable: ComponentView<AlertComponentEnvironment>] = [:]
        
        private var highlightedAction: AnyHashable?
        private let hapticFeedback = HapticFeedback()
                
        private enum ActionLayout {
            case horizontal
            case vertical
            case verticalReversed
            
            var isVertical: Bool {
                switch self {
                case .vertical, .verticalReversed:
                    return true
                default:
                    return false
                }
            }
        }
        private var effectiveActionLayout: ActionLayout = .horizontal
        
        fileprivate var dismissedByTapOutside = false
        
        private var isUpdating: Bool = false
        private var component: AlertScreenComponent?
        private var environment: EnvironmentType?
        private weak var state: EmptyComponentState?
                
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.dimView.alpha = 0.0
            self.dimView.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.2)
            
            self.addSubview(self.dimView)
            self.addSubview(self.containerView)
            self.containerView.contentView.addSubview(self.backgroundView)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapped)))
            
            let tapRecognizer = ActionSelectionGestureRecognizer(target: self, action: #selector(self.actionTapped(_:)))
            tapRecognizer.delegate = self
            self.backgroundView.addGestureRecognizer(tapRecognizer)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        deinit {
            self.disposable?.dispose()
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is ActionSelectionGestureRecognizer {
                let location = gestureRecognizer.location(in: self.backgroundView)
                for (_, action) in self.actionItems {
                    if let actionView = action.view, actionView.frame.contains(location) {
                        return true
                    }
                }
                return false
            } else {
                return super.gestureRecognizerShouldBegin(gestureRecognizer)
            }
        }
        
        @objc private func actionTapped(_ gestureRecognizer: ActionSelectionGestureRecognizer) {
            let location = gestureRecognizer.location(in: self.backgroundView)
            switch gestureRecognizer.state {
            case .began, .changed:
                var highlightedActionId: AnyHashable?
                for (actionId, action) in self.actionItems {
                    if let actionView = action.view, actionView.frame.contains(location) {
                        highlightedActionId = actionId
                        break
                    }
                }
                if self.highlightedAction != highlightedActionId {
                    self.highlightedAction = highlightedActionId
                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                    
                    if case .changed = gestureRecognizer.state, highlightedActionId != nil {
                        self.hapticFeedback.tap()
                    }
                }
            case .ended:
                if let _ = self.highlightedAction {
                    self.performHighlightedAction()
                    self.highlightedAction = nil
                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                }
            case .cancelled:
                self.highlightedAction = nil
                self.state?.updated(transition: .easeInOut(duration: 0.2))
            default:
                break
            }
        }
        
        @objc private func dimTapped() {
            guard let component = self.component, component.configuration.dismissOnOutsideTap else {
                return
            }
            self.dismissedByTapOutside = true
            self.requestDismiss()
        }
        
        func animateIn() {
            let alphaTransition = ComponentTransition(animation: .curve(duration: 0.2, curve: .linear))
            let scaleTransition = ComponentTransition(animation: .curve(duration: 0.4, curve: .spring))
            alphaTransition.setAlpha(view: self.dimView, alpha: 1.0)
            
            scaleTransition.animateScale(view: self.backgroundView, from: 1.15, to: 1.0)
            alphaTransition.animateAlpha(view: self.containerView, from: 0.0, to: 1.0)
        }
        
        func animateOut(completion: @escaping () -> Void) {
            let transition = ComponentTransition(animation: .curve(duration: 0.2, curve: .linear))
            transition.setAlpha(view: self.dimView, alpha: 0.0, completion: { _ in
                completion()
            })
            var initialAlpha: CGFloat = 1.0
            if let presentationLayer = self.containerView.layer.presentation() {
                initialAlpha = CGFloat(presentationLayer.opacity)
            }
            self.containerView.layer.animateAlpha(from: initialAlpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result === self.containerView.contentView {
                return self.dimView
            }
            return result
        }
        
        func requestDismiss() {
            guard let controller = self.environment?.controller() as? AlertScreen else {
                return
            }
            controller.dismiss(completion: nil)
        }
        
        func handleKeyCommand(_ command: KeyCommand) {
            switch command {
            case .up:
                guard self.effectiveActionLayout.isVertical else {
                    return
                }
                self.updateActionHighlight(previous: false)
            case .down:
                guard self.effectiveActionLayout.isVertical else {
                    return
                }
                self.updateActionHighlight(previous: true)
            case .left:
                guard !self.effectiveActionLayout.isVertical else {
                    return
                }
                self.updateActionHighlight(previous: true)
            case .right:
                guard !self.effectiveActionLayout.isVertical else {
                    return
                }
                self.updateActionHighlight(previous: false)
            case .escape:
                self.requestDismiss()
            case .enter:
                self.performHighlightedAction()
            }
        }
        
        func updateActionHighlight(previous: Bool) {
            guard let actions = self.actions else {
                return
            }
            guard let highlightedAction = self.highlightedAction else {
                if let action = actions.first(where: { $0.type == .default }) {
                    self.highlightedAction = action.id
                } else if let action = actions.first(where: { $0.type == .defaultDestructive }) {
                    self.highlightedAction = action.id
                } else if case .verticalReversed = self.effectiveActionLayout, let action = actions.last {
                    self.highlightedAction = action.id
                } else if let action = actions.first {
                    self.highlightedAction = action.id
                }
                self.state?.updated(transition: .easeInOut(duration: 0.2))
                return
            }
            
            let sequence = previous ? actions.reversed() : actions
            var selectNext = false
            var newHighlightedAction: AnyHashable?
            
            for action in sequence {
                let id = AnyHashable(action.id)
                if selectNext {
                    newHighlightedAction = id
                    break
                } else if id == highlightedAction {
                    selectNext = true
                }
            }
            guard let newHighlightedAction else {
                return
            }
            self.highlightedAction = newHighlightedAction
            self.state?.updated(transition: .easeInOut(duration: 0.2))
        }
        
        func performHighlightedAction() {
            guard let actions = self.actions else {
                return
            }
            guard let highlightedAction = self.highlightedAction else {
                return
            }
            guard let action = actions.first(where: { AnyHashable($0.id) == highlightedAction }) else {
                return
            }
            action.action()
            if action.autoDismiss {
                self.requestDismiss()
            }
        }
                        
        func update(component: AlertScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            self.state = state
            
            if self.component == nil {
                self.disposable = (combineLatest(
                    queue: Queue.mainQueue(),
                    component.content,
                    component.actions
                ) |> deliverOnMainQueue).start(next: { [weak self] content, actions in
                    guard let self else {
                        return
                    }
                    self.content = content
                    self.actions = actions
                    
                    if !self.isUpdating {
                        self.state?.updated(transition: .easeInOut(duration: 0.25))
                    }
                })
            }
            
            self.component = component
            
            var alertHeight: CGFloat = 0.0
            let alertWidth: CGFloat = 300.0
            let contentTopInset: CGFloat = 22.0
            let contentBottomInset: CGFloat = 21.0
            let contentSideInset: CGFloat = 30.0
            let contentSpacing: CGFloat = 8.0
            let actionSideInset: CGFloat = 16.0
            let actionSpacing: CGFloat = 8.0
            let fullWidthActionSize = CGSize(width: alertWidth - actionSideInset * 2.0, height: AlertActionComponent.actionHeight)
            let halfWidthActionSize = CGSize(width: (alertWidth - actionSideInset * 2.0 - actionSpacing) / 2.0, height: AlertActionComponent.actionHeight)
    
            let alertEnvironment = AlertComponentEnvironment(theme: environment.theme, strings: environment.strings)
            
            var contentOriginY: CGFloat = 0.0
            var validContentIds: Set<AnyHashable> = Set()
            if let content = self.content {
                for content in content {
                    if contentOriginY.isZero {
                        contentOriginY += contentTopInset
                    } else {
                        contentOriginY += contentSpacing
                    }
                    validContentIds.insert(content.id)
                    
                    let item: ComponentView<AlertComponentEnvironment>
                    var itemTransition = transition
                    if let current = self.contentItems[content.id] {
                        item = current
                    } else {
                        item = ComponentView()
                        if !transition.animation.isImmediate {
                            itemTransition = .immediate
                        }
                        self.contentItems[content.id] = item
                    }
                    
                    let itemSize = item.update(
                        transition: itemTransition,
                        component: content.component,
                        environment: { alertEnvironment },
                        containerSize: CGSize(width: alertWidth - contentSideInset * 2.0, height: availableSize.height)
                    )
                    let itemFrame = CGRect(origin: CGPoint(x: contentSideInset, y: contentOriginY), size: itemSize)
                    if let itemView = item.view {
                        if itemView.superview == nil {
                            self.backgroundView.contentView.addSubview(itemView)
                            item.parentState = state
                        }
                        transition.setFrame(view: itemView, frame: itemFrame)
                    }
                    contentOriginY += itemSize.height
                }
            }
            
            if !contentOriginY.isZero {
                alertHeight += contentOriginY
                alertHeight += contentBottomInset
            }
            
            if let actions = self.actions {
                let genericActionTheme = AlertActionComponent.Theme(
                    background: environment.theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.1),
                    foreground: environment.theme.actionSheet.primaryTextColor,
                    secondary: environment.theme.actionSheet.secondaryTextColor,
                    font: .regular
                )
                let defaultActionTheme = AlertActionComponent.Theme(
                    background: environment.theme.actionSheet.controlAccentColor,
                    foreground: environment.theme.list.itemCheckColors.foregroundColor,
                    secondary: environment.theme.list.itemCheckColors.foregroundColor.withMultipliedAlpha(0.85),
                    font: .bold
                )
                let destructiveActionTheme = AlertActionComponent.Theme(
                    background: environment.theme.list.itemDestructiveColor,
                    foreground: .white,
                    secondary: .white.withMultipliedAlpha(0.6),
                    font: .regular
                )
                let defaultDestructiveActionTheme = AlertActionComponent.Theme(
                    background: environment.theme.list.itemDestructiveColor,
                    foreground: .white,
                    secondary: .white.withMultipliedAlpha(0.6),
                    font: .bold
                )
                
                var effectiveActionLayout: ActionLayout = .horizontal
                if case .vertical = component.configuration.actionAlignment {
                    effectiveActionLayout = .vertical
                } else if actions.count == 1 {
                    effectiveActionLayout = .vertical
                }
                var actionTransitions: [AnyHashable: ComponentTransition] = [:]
                var validActionIds: Set<AnyHashable> = Set()
                for action in actions {
                    validActionIds.insert(action.id)
                    
                    let item: ComponentView<AlertComponentEnvironment>
                    var itemTransition = transition
                    if let current = self.actionItems[action.id] {
                        item = current
                    } else {
                        item = ComponentView()
                        if !transition.animation.isImmediate {
                            itemTransition = .immediate
                        }
                        self.actionItems[action.id] = item
                    }
                    actionTransitions[action.id] = itemTransition
                    
                    let actionTheme: AlertActionComponent.Theme
                    switch action.type {
                    case .generic:
                        actionTheme = genericActionTheme
                    case .default:
                        actionTheme = defaultActionTheme
                    case .destructive:
                        actionTheme = destructiveActionTheme
                    case .defaultDestructive:
                        actionTheme = defaultDestructiveActionTheme
                    }
                    let itemSize = item.update(
                        transition: itemTransition,
                        component: AnyComponent(AlertActionComponent(
                            theme: actionTheme,
                            title: action.title,
                            isHighlighted: AnyHashable(action.id) == self.highlightedAction,
                            isEnabled: action.isEnabled,
                            progress: action.progress
                        )),
                        environment: { alertEnvironment },
                        containerSize: fullWidthActionSize
                    )
                    if let itemView = item.view {
                        if itemView.superview == nil {
                            self.backgroundView.contentView.addSubview(itemView)
                        }
                    }
                    
                    if case .horizontal = effectiveActionLayout, itemSize.width > halfWidthActionSize.width {
                        effectiveActionLayout = .verticalReversed
                    }
                }
                self.effectiveActionLayout = effectiveActionLayout
                
                if !actions.isEmpty {
                    let actionsHeight: CGFloat
                    if self.effectiveActionLayout.isVertical {
                        actionsHeight = fullWidthActionSize.height * CGFloat(actions.count) + actionSpacing * CGFloat(actions.count - 1)
                    } else {
                        actionsHeight = fullWidthActionSize.height
                    }
                    alertHeight += actionsHeight
                    alertHeight += actionSideInset
                }
                
                var actionOriginX: CGFloat = actionSideInset
                var actionOriginY: CGFloat
                switch self.effectiveActionLayout {
                case .horizontal, .verticalReversed:
                    actionOriginY = alertHeight - actionSideInset - fullWidthActionSize.height
                case .vertical:
                    actionOriginY = alertHeight - actionSideInset - fullWidthActionSize.height * CGFloat( actions.count) - actionSpacing * CGFloat(actions.count - 1)
                }
                for action in actions {
                    guard let item = self.actionItems[action.id], let itemView = item.view as? AlertActionComponent.View else {
                        continue
                    }
                    let itemTransition = actionTransitions[action.id] ?? transition
                    let itemFrame: CGRect
                    switch self.effectiveActionLayout {
                    case .horizontal:
                        itemFrame = CGRect(origin: CGPoint(x: actionOriginX, y: actionOriginY), size: halfWidthActionSize)
                        actionOriginX += halfWidthActionSize.width + actionSpacing
                    case .vertical:
                        itemFrame = CGRect(origin: CGPoint(x: actionOriginX, y: actionOriginY), size: fullWidthActionSize)
                        actionOriginY += fullWidthActionSize.height + actionSpacing
                    case .verticalReversed:
                        itemFrame = CGRect(origin: CGPoint(x: actionOriginX, y: actionOriginY), size: fullWidthActionSize)
                        actionOriginY -= fullWidthActionSize.height + actionSpacing
                    }
                    itemView.applySize(size: itemFrame.size, transition: itemTransition)
                    itemTransition.setFrame(view: itemView, frame: itemFrame)
                }
                
                var removeActionIds: [AnyHashable] = []
                for (id, item) in self.actionItems {
                    if !validActionIds.contains(id) {
                        removeActionIds.append(id)
                        if let itemView = item.view {
                            if !transition.animation.isImmediate {
                                itemView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.25, removeOnCompletion: false)
                                itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                                    itemView.removeFromSuperview()
                                })
                            } else {
                                itemView.removeFromSuperview()
                            }
                        }
                    }
                }
                for id in removeActionIds {
                    self.actionItems.removeValue(forKey: id)
                }
            }
            
            let alertSize = CGSize(width: alertWidth, height: alertHeight)
            let bounds = CGRect(origin: .zero, size: availableSize)
            
            transition.setFrame(view: self.dimView, frame: bounds)
            transition.setFrame(view: self.containerView, frame: bounds)
            self.containerView.update(size: availableSize, isDark: environment.theme.overallDarkAppearance, transition: transition)
            
            var availableHeight = availableSize.height
            availableHeight -= environment.statusBarHeight
            if component.configuration.allowInputInset, environment.inputHeight > 0.0 {
                availableHeight -= environment.inputHeight
            }
                        
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - alertSize.width) / 2.0), y: environment.statusBarHeight +  floorToScreenPixels((availableHeight - alertSize.height) / 2.0)), size: alertSize))
            self.backgroundView.update(size: alertSize, cornerRadius: 35.0, isDark: environment.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

open class AlertScreen: ViewControllerComponentContainer, KeyShortcutResponder {
    public enum ActionAligmnent: Equatable {
        case `default`
        case vertical
    }
    
    public struct Configuration: Equatable {
        let actionAlignment: ActionAligmnent
        let dismissOnOutsideTap: Bool
        let allowInputInset: Bool
        
        public init(
            actionAlignment: ActionAligmnent = .default,
            dismissOnOutsideTap: Bool = true,
            allowInputInset: Bool = false
        ) {
            self.actionAlignment = actionAlignment
            self.dismissOnOutsideTap = dismissOnOutsideTap
            self.allowInputInset = allowInputInset
        }
    }
    
    public struct Action: Equatable {
        public enum ActionType: Equatable {
            case generic
            case `default`
            case destructive
            case defaultDestructive
        }
        public let title: String
        public let type: ActionType
        public let action: () -> Void
        public let autoDismiss: Bool
        public let isEnabled: Signal<Bool, NoError>
        public let progress: Signal<Bool, NoError>
        
        public init(
            id: AnyHashable? = nil,
            title: String,
            type: ActionType = .generic,
            action: @escaping () -> Void = {},
            autoDismiss: Bool = true,
            isEnabled: Signal<Bool, NoError> = .single(true),
            progress: Signal<Bool, NoError> = .single(false)
        ) {
            self.type = type
            self.title = title
            self.action = action
            self.autoDismiss = autoDismiss
            self.isEnabled = isEnabled
            self.progress = progress
            
            if let id {
                self.id = id
            } else {
                self.id = title
            }
        }
        
        public static func ==(lhs: Action, rhs: Action) -> Bool {
            if lhs.title != rhs.title {
                return false
            }
            if lhs.type != rhs.type {
                return false
            }
            if lhs.autoDismiss != rhs.autoDismiss {
                return false
            }
            return true
        }
        
        fileprivate let id: AnyHashable
    }
    
    private var processedDidAppear: Bool = false
    private var processedDidDisappear: Bool = false
    
    private let readyValue = Promise<Bool>(true)
    override public var ready: Promise<Bool> {
        return self.readyValue
    }
    
    public var dismissed: ((Bool) -> Void)?
    
    public init(
        configuration: Configuration = Configuration(),
        contentSignal: Signal<[AnyComponentWithIdentity<AlertComponentEnvironment>], NoError>,
        actionsSignal: Signal<[Action], NoError>,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)
    ) {
        let componentReady = Promise<Bool>()
        
        super.init(
            component: AlertScreenComponent(
                configuration: configuration,
                content: contentSignal,
                actions: actionsSignal,
                ready: componentReady
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            presentationMode: .default,
            updatedPresentationData: updatedPresentationData
        )
        self.navigationPresentation = .flatModal
        
        //self.readyValue.set(componentReady.get() |> timeout(1.0, queue: .mainQueue(), alternate: .single(true)))
    }
    
    public convenience init(
        configuration: Configuration = Configuration(),
        content: [AnyComponentWithIdentity<AlertComponentEnvironment>],
        actions: [Action],
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)
    ) {
        self.init(
            configuration: configuration,
            contentSignal: .single(content),
            actionsSignal: .single(actions),
            updatedPresentationData: updatedPresentationData
        )
    }
    
    public convenience init(
        context: AccountContext,
        configuration: Configuration = Configuration(),
        content: [AnyComponentWithIdentity<AlertComponentEnvironment>],
        actions: [Action]
    ) {
        self.init(
            sharedContext: context.sharedContext,
            configuration: configuration,
            content: content,
            actions: actions,
        )
    }
    
    public convenience init(
        sharedContext: SharedAccountContext,
        configuration: Configuration = Configuration(),
        content: [AnyComponentWithIdentity<AlertComponentEnvironment>],
        actions: [Action]
    ) {
        let presentationData = sharedContext.currentPresentationData.with { $0 }
        let updatedPresentationDataSignal = sharedContext.presentationData
        self.init(
            configuration: configuration,
            content: content,
            actions: actions,
            updatedPresentationData: (initial: presentationData, signal: updatedPresentationDataSignal)
        )
    }
    
    public convenience init(
        configuration: Configuration = Configuration(),
        title: String? = nil,
        text: String,
        textAction: @escaping ([NSAttributedString.Key: Any]) -> Void = { _ in },
        actions: [Action],
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)
    ) {
        var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
        if let title {
            content.append(AnyComponentWithIdentity(
                id: "title",
                component: AnyComponent(
                    AlertTitleComponent(title: title)
                )
            ))
        }
        if !text.isEmpty {
            content.append(AnyComponentWithIdentity(
                id: "text",
                component: AnyComponent(
                    AlertTextComponent(content: .plain(text), action: textAction)
                )
            ))
        }
        
        if content.isEmpty {
            content.append(AnyComponentWithIdentity(
                id: "text",
                component: AnyComponent(
                    AlertTextComponent(content: .plain(" "), action: textAction)
                )
            ))
        }
        
        self.init(
            configuration: configuration,
            content: content,
            actions: actions,
            updatedPresentationData: updatedPresentationData
        )
    }
    
    public convenience init(
        context: AccountContext,
        configuration: Configuration = Configuration(),
        title: String? = nil,
        text: String,
        actions: [Action]
    ) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let updatedPresentationDataSignal = context.sharedContext.presentationData
        self.init(
            configuration: configuration,
            title: title,
            text: text,
            actions: actions,
            updatedPresentationData: (initial: presentationData, signal: updatedPresentationDataSignal)
        )
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.processedDidAppear {
            self.processedDidAppear = true
            if let componentView = self.node.hostView.componentView as? AlertScreenComponent.View {
                componentView.animateIn()
            }
        }
    }
    
    private func superDismiss() {
        super.dismiss()
    }
    
    override open func dismiss(completion: (() -> Void)? = nil) {
        if !self.processedDidDisappear {
            self.processedDidDisappear = true
            
            if let componentView = self.node.hostView.componentView as? AlertScreenComponent.View {
                let dismissedByTapOutside = componentView.dismissedByTapOutside
                componentView.animateOut(completion: { [weak self] in
                    if let self {
                        self.dismissed?(dismissedByTapOutside)
                        self.superDismiss()
                    }
                    completion?()
                })
            } else {
                super.dismiss(completion: completion)
            }
        }
    }
    
    public var keyShortcuts: [KeyShortcut] {
        return [
            KeyShortcut(
                input: UIKeyCommand.inputEscape,
                modifiers: [],
                action: { [weak self] in
                    if let componentView = self?.node.hostView.componentView as? AlertScreenComponent.View {
                        componentView.handleKeyCommand(.escape)
                    }
                }
            ),
            KeyShortcut(
                input: "W",
                modifiers: [.command],
                action: { [weak self] in
                    if let componentView = self?.node.hostView.componentView as? AlertScreenComponent.View {
                        componentView.handleKeyCommand(.escape)
                    }
                }
            ),
            KeyShortcut(
                input: "\r",
                modifiers: [],
                action: { [weak self] in
                    if let componentView = self?.node.hostView.componentView as? AlertScreenComponent.View {
                        componentView.handleKeyCommand(.enter)
                    }
                }
            ),
            KeyShortcut(
                input: UIKeyCommand.inputUpArrow,
                modifiers: [],
                action: { [weak self] in
                    if let componentView = self?.node.hostView.componentView as? AlertScreenComponent.View {
                        componentView.handleKeyCommand(.up)
                    }
                }
            ),
            KeyShortcut(
                input: UIKeyCommand.inputDownArrow,
                modifiers: [],
                action: { [weak self] in
                    if let componentView = self?.node.hostView.componentView as? AlertScreenComponent.View {
                        componentView.handleKeyCommand(.down)
                    }
                }
            ),
            KeyShortcut(
                input: UIKeyCommand.inputLeftArrow,
                modifiers: [],
                action: { [weak self] in
                    if let componentView = self?.node.hostView.componentView as? AlertScreenComponent.View {
                        componentView.handleKeyCommand(.left)
                    }
                }
            ),
            KeyShortcut(
                input: UIKeyCommand.inputRightArrow,
                modifiers: [],
                action: { [weak self] in
                    if let componentView = self?.node.hostView.componentView as? AlertScreenComponent.View {
                        componentView.handleKeyCommand(.right)
                    }
                }
            )
        ]
    }
}

public final class ActionSelectionGestureRecognizer: UIGestureRecognizer {
    private var initialLocation: CGPoint?
    private var currentLocation: CGPoint?
    
    public override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delaysTouchesBegan = false
        self.delaysTouchesEnded = false
    }
    
    public override func reset() {
        super.reset()
        
        self.initialLocation = nil
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if self.initialLocation == nil {
            self.initialLocation = touches.first?.location(in: self.view)
        }
        self.currentLocation = self.initialLocation
        
        self.state = .began
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.state = .ended
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.state = .cancelled
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        self.currentLocation = touches.first?.location(in: self.view)
        
        self.state = .changed
    }
    
    public func translation(in: UIView?) -> CGPoint {
        if let initialLocation = self.initialLocation, let currentLocation = self.currentLocation {
            return CGPoint(x: currentLocation.x - initialLocation.x, y: currentLocation.y - initialLocation.y)
        }
        return CGPoint()
    }
}
