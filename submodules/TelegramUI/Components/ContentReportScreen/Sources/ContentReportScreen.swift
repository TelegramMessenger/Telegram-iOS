import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import Markdown
import TextFormat
import TelegramPresentationData
import ViewControllerComponent
import SheetComponent
import BalancedTextComponent
import MultilineTextComponent
import ListSectionComponent
import ListActionItemComponent
import NavigationStackComponent
import ItemListUI
import UndoUI
import AccountContext
import LottieComponent
import TextFieldComponent
import ListMultilineTextFieldItemComponent
import ButtonComponent

private enum ReportResult {
    case reported
    case requestedMessageSelection
}

private final class SheetPageContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    enum Content: Equatable {
        struct Item: Equatable {
            let title: String
            let option: Data
        }
        
        case options(items: [Item])
        case comment(isOptional: Bool, option: Data)
    }
    
    let context: AccountContext
    let isFirst: Bool
    let title: String?
    let subtitle: String
    let content: Content
    let action: (Content.Item, String?) -> Void
    let pop: () -> Void
    
    init(
        context: AccountContext,
        isFirst: Bool,
        title: String?,
        subtitle: String,
        content: Content,
        action: @escaping (Content.Item, String?) -> Void,
        pop: @escaping () -> Void
    ) {
        self.context = context
        self.isFirst = isFirst
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.action = action
        self.pop = pop
    }
    
    static func ==(lhs: SheetPageContent, rhs: SheetPageContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var backArrowImage: (UIImage, PresentationTheme)?

        let playOnce =  ActionSlot<Void>()
        private var didPlayAnimation = false

        let textInputState = ListMultilineTextFieldItemComponent.ExternalState()
        
        func playAnimationIfNeeded() {
            guard !self.didPlayAnimation else {
                return
            }
            self.didPlayAnimation = true
            self.playOnce.invoke(Void())
        }
    }
    
    func makeState() -> State {
        return State()
    }
        
    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let back = Child(Button.self)
        let title = Child(Text.self)
        let animation = Child(LottieComponent.self)
        let section = Child(ListSectionComponent.self)
        let button = Child(ButtonComponent.self)
        
        let textInputTag = NSObject()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let theme = environment.theme
            let strings = environment.strings
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            var contentSize = CGSize(width: context.availableSize.width, height: 18.0)
                        
            let background = background.update(
                component: RoundedRectangle(color: theme.list.modalBlocksBackgroundColor, cornerRadius: 8.0),
                availableSize: CGSize(width: context.availableSize.width, height: 1000.0),
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: background.size.height / 2.0))
            )
            
            let backArrowImage: UIImage
            if let (cached, cachedTheme) = state.backArrowImage, cachedTheme === theme {
                backArrowImage = cached
            } else {
                backArrowImage = NavigationBarTheme.generateBackArrowImage(color: theme.list.itemAccentColor)!
                state.backArrowImage = (backArrowImage, theme)
            }
            
            let backContents: AnyComponent<Empty>
            if component.isFirst {
                backContents = AnyComponent(Text(text: strings.Common_Cancel, font: Font.regular(17.0), color: theme.list.itemAccentColor))
            } else {
                backContents = AnyComponent(
                    HStack([
                        AnyComponentWithIdentity(id: "arrow", component: AnyComponent(Image(image: backArrowImage, contentMode: .center))),
                        AnyComponentWithIdentity(id: "label", component: AnyComponent(Text(text: strings.Common_Back, font: Font.regular(17.0), color: theme.list.itemAccentColor)))
                    ], spacing: 6.0)
                )
            }
            let back = back.update(
                component: Button(
                    content: backContents,
                    action: {
                        component.pop()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(back
                .position(CGPoint(x: sideInset + back.size.width / 2.0 - (!component.isFirst ? 8.0 : 0.0), y: contentSize.height + back.size.height / 2.0))
            )
            
            let constrainedTitleWidth = context.availableSize.width - (back.size.width + 16.0) * 2.0
            
            let titleString: String
            if let title = component.title {
                titleString = title
            } else {
                titleString = ""
            }
            
            let title = title.update(
                component: Text(text: titleString, font: Font.semibold(17.0), color: theme.list.itemPrimaryTextColor),
                availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
            )
            contentSize.height += title.size.height
            contentSize.height += 24.0
                                    
            var items: [AnyComponentWithIdentity<Empty>] = []
            var footer: AnyComponent<Empty>?
                                        
            switch component.content {
            case let .options(options):
                for item in options  {
                    items.append(AnyComponentWithIdentity(id: item.title, component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: item.title,
                                    font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                    textColor: theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            ))),
                        ], alignment: .left, spacing: 2.0)),
                        accessory: .arrow,
                        action: { _ in
                            component.action(item, nil)
                        }
                    ))))
                }
            case let .comment(isOptional, _):
                contentSize.height -= 11.0
                
                let animationHeight: CGFloat = 120.0
                let animation = animation.update(
                    component: LottieComponent(
                        content: LottieComponent.AppBundleContent(name: "Cop"),
                        startingPosition: .begin,
                        playOnce: state.playOnce
                    ),
                    environment: {},
                    availableSize: CGSize(width: animationHeight, height: animationHeight),
                    transition: .immediate
                )
                context.add(animation
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + animation.size.height / 2.0))
                )
                contentSize.height += animation.size.height
                contentSize.height += 18.0
                
                items.append(
                    AnyComponentWithIdentity(id: items.count, component: AnyComponent(ListMultilineTextFieldItemComponent(
                        externalState: state.textInputState,
                        context: component.context,
                        theme: theme,
                        strings: strings,
                        initialText: "",
                        resetText: nil,
                        placeholder: isOptional ? strings.Report_Comment_Placeholder_Optional : strings.Report_Comment_Placeholder,
                        autocapitalizationType: .none,
                        autocorrectionType: .no,
                        returnKeyType: .done,
                        characterLimit: 140,
                        displayCharacterLimit: true,
                        emptyLineHandling: .notAllowed,
                        updated: { [weak state] _ in
                            state?.updated()
                        },
                        returnKeyAction: {
//                            guard let self else {
//                                return
//                            }
//                            if let titleView = self.introSection.findTaggedView(tag: self.textInputTag) as? ListMultilineTextFieldItemComponent.View {
//                                titleView.endEditing(true)
//                            }
                        },
                        textUpdateTransition: .spring(duration: 0.4),
                        tag: textInputTag
                    )))
                )
                
                footer = AnyComponent(MultilineTextComponent(
                    text: .plain(
                        NSAttributedString(string: strings.Report_Comment_Info, font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: theme.list.freeTextColor)
                    ),
                    maximumNumberOfLines: 0
                ))
            }

            let section = section.update(
                component: ListSectionComponent(
                    theme: theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: component.subtitle.uppercased(),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: footer,
                    items: items,
                    isModal: true
                ),
                environment: {},
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(section
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + section.size.height / 2.0))
            )
            contentSize.height += section.size.height
            contentSize.height += 54.0
            
            if case let .comment(isOptional, option) = component.content {
                contentSize.height -= 16.0
                
                let action = component.action
                let button = button.update(
                    component: ButtonComponent(
                        background: ButtonComponent.Background(
                            color: theme.list.itemCheckColors.fillColor,
                            foreground: theme.list.itemCheckColors.foregroundColor,
                            pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                        ),
                        content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(Text(text: strings.Report_Send, font: Font.semibold(17.0), color: theme.list.itemCheckColors.foregroundColor))),
                        isEnabled: isOptional || state.textInputState.hasText,
                        allowActionWhenDisabled: false,
                        displaysProgress: false,
                        action: {
                            action(SheetPageContent.Content.Item(title: "", option: option), state.textInputState.text.string)
                        }
                    ),
                    environment: {},
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                    transition: context.transition
                )
                context.add(button
                    .clipsToBounds(true)
                    .cornerRadius(10.0)
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + button.size.height / 2.0))
                )
                contentSize.height += button.size.height
                contentSize.height += 16.0
                
                if environment.inputHeight.isZero && environment.safeInsets.bottom > 0.0 {
                    contentSize.height += environment.safeInsets.bottom
                }
            }
            
            contentSize.height += environment.inputHeight
            
            state.playAnimationIfNeeded()
            
            return contentSize
        }
    }
}

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: ReportContentSubject
    let title: String
    let options: [ReportContentResult.Option]
    let pts: Int
    let openMore: () -> Void
    let complete: (ReportResult) -> Void
    let dismiss: () -> Void
    let update: (ComponentTransition) -> Void
    let requestSelectMessages: ((String, Data, String?) -> Void)?
    
    init(
        context: AccountContext,
        subject: ReportContentSubject,
        title: String,
        options: [ReportContentResult.Option],
        pts: Int,
        openMore: @escaping () -> Void,
        complete: @escaping (ReportResult) -> Void,
        dismiss: @escaping () -> Void,
        update: @escaping (ComponentTransition) -> Void,
        requestSelectMessages: ((String, Data, String?) -> Void)?
    ) {
        self.context = context
        self.subject = subject
        self.title = title
        self.options = options
        self.pts = pts
        self.openMore = openMore
        self.complete = complete
        self.dismiss = dismiss
        self.update = update
        self.requestSelectMessages = requestSelectMessages
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.options != rhs.options {
            return false
        }
        if lhs.pts != rhs.pts {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var pushedOptions: [(title: String, subtitle: String, content: SheetPageContent.Content)] = []
        let disposable = MetaDisposable()
        
        var peer: EnginePeer?
        private var peerDisposable: Disposable?
        
        init(context: AccountContext, subject: ReportContentSubject) {
            super.init()
            
            self.peerDisposable = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: subject.peerId))
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                self?.peer = peer
                self?.updated()
            })
        }
        
        deinit {
            self.disposable.dispose()
            self.peerDisposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, subject: self.subject)
    }
        
    static var body: Body {
        let navigation = Child(NavigationStackComponent<EnvironmentType>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            let update = component.update
            
            let accountContext = component.context
            let subject = component.subject
            let complete = component.complete
            let requestSelectMessages = component.requestSelectMessages
            let action: (SheetPageContent.Content.Item, String?) -> Void = { [weak state] item, message in
                guard let state else {
                    return
                }
                state.disposable.set(
                    (accountContext.engine.messages.reportContent(subject: subject, option: item.option, message: message)
                    |> deliverOnMainQueue).start(next: { [weak state] result in
                        switch result {
                        case let .options(title, options):
                            state?.pushedOptions.append((item.title, title, .options(items: options.map { SheetPageContent.Content.Item(title: $0.text, option: $0.option) })))
                            state?.updated(transition: .spring(duration: 0.45))
                        case let .addComment(isOptional, option):
                            state?.pushedOptions.append((item.title, "", .comment(isOptional: isOptional, option: option)))
                            state?.updated(transition: .spring(duration: 0.45))
                        case .reported:
                            complete(.reported)
                        }
                    }, error: { error in
                        if case .messageIdRequired = error {
                            requestSelectMessages?(item.title, item.option, message)
                            complete(.requestedMessageSelection)
                        }
                    })
                )
            }
            
            let mainTitle: String
            switch component.subject {
            case .peer:
                if let peer = state.peer {
                    if case .user = peer {
                        mainTitle = environment.strings.Report_Title_User
                    } else if case let .channel(channel) = peer, case .broadcast = channel.info {
                        mainTitle = environment.strings.Report_Title_Channel
                    } else {
                        mainTitle = environment.strings.Report_Title_Group
                    }
                } else {
                    mainTitle = ""
                }
            case .messages:
                mainTitle = environment.strings.Report_Title_Message
            case .stories:
                mainTitle = environment.strings.Report_Title_Story
            }
            
            var items: [AnyComponentWithIdentity<EnvironmentType>] = []
            items.append(AnyComponentWithIdentity(id: items.count, component: AnyComponent(
                SheetPageContent(
                    context: component.context,
                    isFirst: true,
                    title: mainTitle,
                    subtitle: component.title,
                    content: .options(items: component.options.map {
                        SheetPageContent.Content.Item(title: $0.text, option: $0.option)
                    }),
                    action: { item, message in
                        action(item, message)
                    },
                    pop: {
                        component.dismiss()
                    }
                )
            )))
            for pushedOption in state.pushedOptions {
                items.append(AnyComponentWithIdentity(id: items.count, component: AnyComponent(
                    SheetPageContent(
                        context: component.context,
                        isFirst: false,
                        title: pushedOption.title,
                        subtitle: pushedOption.subtitle,
                        content: pushedOption.content,
                        action: { item, message in
                            action(item, message)
                        },
                        pop: { [weak state] in
                            state?.pushedOptions.removeLast()
                            update(.spring(duration: 0.45))
                        }
                    )
                )))
            }
            
            var contentSize = CGSize(width: context.availableSize.width, height: 0.0)
            let navigation = navigation.update(
                component: NavigationStackComponent(
                    items: items,
                    clipContent: false,
                    requestPop: { [weak state] in
                        state?.pushedOptions.removeLast()
                        update(.spring(duration: 0.45))
                    }
                ),
                environment: { environment },
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: context.transition
            )
            context.add(navigation
                .position(CGPoint(x: context.availableSize.width / 2.0, y: navigation.size.height / 2.0))
                .clipsToBounds(true)
                .cornerRadius(8.0)
            )
            contentSize.height += navigation.size.height
                        
            return contentSize
        }
    }
}

private final class SheetContainerComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: ReportContentSubject
    let title: String
    let options: [ReportContentResult.Option]
    let openMore: () -> Void
    let complete: (ReportResult) -> Void
    let requestSelectMessages: ((String, Data, String?) -> Void)?
    
    init(
        context: AccountContext,
        subject: ReportContentSubject,
        title: String,
        options: [ReportContentResult.Option],
        openMore: @escaping () -> Void,
        complete: @escaping (ReportResult) -> Void,
        requestSelectMessages: ((String, Data, String?) -> Void)?
    ) {
        self.context = context
        self.subject = subject
        self.title = title
        self.options = options
        self.openMore = openMore
        self.complete = complete
        self.requestSelectMessages = requestSelectMessages
    }
    
    static func ==(lhs: SheetContainerComponent, rhs: SheetContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.options != rhs.options {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var pts: Int = 0
    }
    
    func makeState() -> State {
        return State()
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let state = context.state
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        context: context.component.context,
                        subject: context.component.subject,
                        title: context.component.title,
                        options: context.component.options,
                        pts: state.pts,
                        openMore: context.component.openMore,
                        complete: context.component.complete,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        },
                        update: { [weak state] transition in
                            state?.pts += 1
                            state?.updated(transition: transition)
                        },
                        requestSelectMessages: context.component.requestSelectMessages
                    )),
                    backgroundColor: .color(environment.theme.list.modalBlocksBackgroundColor),
                    followContentSizeChanges: true,
                    externalState: sheetExternalState,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                animateOut.invoke(Action { _ in
                                    if let controller = controller() {
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else {
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: max(environment.safeInsets.bottom, sheetExternalState.contentHeight), right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left, bottom: 0.0, right: environment.safeInsets.right),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }
            
            return context.availableSize
        }
    }
}


public final class ContentReportScreen: ViewControllerComponentContainer {
    private let context: AccountContext
        
    public init(
        context: AccountContext,
        subject: ReportContentSubject,
        title: String,
        options: [ReportContentResult.Option],
        forceDark: Bool = false,
        completed: @escaping () -> Void,
        requestSelectMessages: ((String, Data, String?) -> Void)?
    ) {
        self.context = context
                
        var completeImpl: ((ReportResult) -> Void)?
        super.init(
            context: context,
            component: SheetContainerComponent(
                context: context,
                subject: subject,
                title: title,
                options: options,
                openMore: {},
                complete: { hidden in
                    completeImpl?(hidden)
                },
                requestSelectMessages: requestSelectMessages
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: forceDark ? .dark : .default
        )
        
        self.navigationPresentation = .flatModal
        
        completeImpl = { [weak self] result in
            guard let self else {
                return
            }
            let navigationController = self.navigationController
            self.dismissAnimated()
            
            switch result {
            case .reported:
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                Queue.mainQueue().after(0.4, {
                    completed()
                    
                    (navigationController?.viewControllers.last as? ViewController)?.present(UndoOverlayController(presentationData: presentationData, content: .emoji(name: "PoliceCar", text: presentationData.strings.Report_Succeed), elevatedLayout: false, action: { _ in return true }), in: .current)
                })
            case .requestedMessageSelection:
                break
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}
