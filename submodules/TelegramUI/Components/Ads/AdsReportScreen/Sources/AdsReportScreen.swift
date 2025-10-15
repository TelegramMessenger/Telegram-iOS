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

private enum ReportResult {
    case reported
    case hidden
    case premiumRequired
}

private final class SheetPageContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    struct Item: Equatable {
        let title: String
        let option: Data
    }
    
    let context: AccountContext
    let title: String?
    let subtitle: String
    let items: [Item]
    let action: (Item) -> Void
    let pop: () -> Void
    
    init(
        context: AccountContext,
        title: String?,
        subtitle: String,
        items: [Item],
        action: @escaping (Item) -> Void,
        pop: @escaping () -> Void
    ) {
        self.context = context
        self.title = title
        self.subtitle = subtitle
        self.items = items
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
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var backArrowImage: (UIImage, PresentationTheme)?
    }
    
    func makeState() -> State {
        return State()
    }
        
    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let back = Child(Button.self)
        let title = Child(Text.self)
        let subtitle = Child(MultilineTextComponent.self)
        let section = Child(ListSectionComponent.self)
        
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
            if component.title == nil {
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
                .position(CGPoint(x: sideInset + back.size.width / 2.0 - (component.title != nil ? 8.0 : 0.0), y: contentSize.height + back.size.height / 2.0))
            )
            
            let constrainedTitleWidth = context.availableSize.width - (back.size.width + 16.0) * 2.0
            
            let title = title.update(
                component: Text(text: strings.ReportAd_Title, font: Font.semibold(17.0), color: theme.list.itemPrimaryTextColor),
                availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                transition: .immediate
            )
            if let subtitleText = component.title {
                let subtitle = subtitle.update(
                    component: MultilineTextComponent(text: .plain(NSAttributedString(string: subtitleText, font: Font.regular(13.0), textColor: theme.list.itemSecondaryTextColor)), truncationType: .end, maximumNumberOfLines: 1),
                    availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                    transition: .immediate
                )
                context.add(title
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0 - 8.0))
                )
                contentSize.height += title.size.height
                context.add(subtitle
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + subtitle.size.height / 2.0 - 9.0))
                )
                contentSize.height += subtitle.size.height
                contentSize.height += 8.0
            } else {
                context.add(title
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
                )
                contentSize.height += title.size.height
                contentSize.height += 24.0
            }
            
            var items: [AnyComponentWithIdentity<Empty>] = []
            for item in component.items  {
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
                        component.action(item)
                    }
                ))))
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
                    footer: AnyComponent(MultilineTextComponent(
                        text: .markdown(
                            text: strings.ReportAd_Help,
                            attributes: MarkdownAttributes(
                                body: MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: theme.list.freeTextColor),
                                bold: MarkdownAttributeSet(font: Font.semibold(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: theme.list.freeTextColor),
                                link: MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: theme.list.itemAccentColor),
                                linkAttribute: { contents in
                                    return (TelegramTextAttributes.URL, contents)
                                }
                            )
                        ),
                        maximumNumberOfLines: 0,
                        highlightColor: theme.list.itemAccentColor.withAlphaComponent(0.2),
                        highlightAction: { attributes in
                            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                            } else {
                                return nil
                            }
                        },
                        tapAction: { _, _ in
                            component.context.sharedContext.openExternalUrl(context: component.context, urlContext: .generic, url: strings.ReportAd_Help_URL, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
                        }
                    )),
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
            
            return contentSize
        }
    }
}

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let opaqueId: Data
    let title: String
    let options: [ReportAdMessageResult.Option]
    let pts: Int
    let openMore: () -> Void
    let complete: (ReportResult) -> Void
    let dismiss: () -> Void
    let update: (ComponentTransition) -> Void
    
    init(
        context: AccountContext,
        opaqueId: Data,
        title: String,
        options: [ReportAdMessageResult.Option],
        pts: Int,
        openMore: @escaping () -> Void,
        complete: @escaping (ReportResult) -> Void,
        dismiss: @escaping () -> Void,
        update: @escaping (ComponentTransition) -> Void
    ) {
        self.context = context
        self.opaqueId = opaqueId
        self.title = title
        self.options = options
        self.pts = pts
        self.openMore = openMore
        self.complete = complete
        self.dismiss = dismiss
        self.update = update
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.opaqueId != rhs.opaqueId {
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
        var pushedOptions: [(title: String, subtitle: String, options: [ReportAdMessageResult.Option])] = []
        let disposable = MetaDisposable()
        
        deinit {
            self.disposable.dispose()
        }
    }
    
    func makeState() -> State {
        return State()
    }
        
    static var body: Body {
        let navigation = Child(NavigationStackComponent<EnvironmentType>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            let update = component.update
            
            let accountContext = component.context
            let opaqueId = component.opaqueId
            let complete = component.complete
            let action: (SheetPageContent.Item) -> Void = { [weak state] item in
                guard let state else {
                    return
                }
                state.disposable.set(
                    (accountContext.engine.messages.reportAdMessage(opaqueId: opaqueId, option: item.option)
                    |> deliverOnMainQueue).start(next: { [weak state] result in
                        switch result {
                        case let .options(title, options):
                            state?.pushedOptions.append((item.title, title, options))
                            state?.updated(transition: .spring(duration: 0.45))
                        case .adsHidden:
                            complete(.hidden)
                        case .reported:
                            complete(.reported)
                        }
                    }, error: { error in
                        if case .premiumRequired = error {
                            complete(.premiumRequired)
                        }
                    })
                )
            }
            
            var items: [AnyComponentWithIdentity<EnvironmentType>] = []
            items.append(AnyComponentWithIdentity(id: items.count, component: AnyComponent(
                SheetPageContent(
                    context: component.context,
                    title: nil,
                    subtitle: component.title,
                    items: component.options.map {
                        SheetPageContent.Item(title: $0.text, option: $0.option)
                    },
                    action: { item in
                        action(item)
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
                        title: pushedOption.title,
                        subtitle: pushedOption.subtitle,
                        items: pushedOption.options.map {
                            SheetPageContent.Item(title: $0.text, option: $0.option)
                        },
                        action: { item in
                            action(item)
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
    let opaqueId: Data
    let title: String
    let options: [ReportAdMessageResult.Option]
    let openMore: () -> Void
    let complete: (ReportResult) -> Void
    
    init(
        context: AccountContext,
        opaqueId: Data,
        title: String,
        options: [ReportAdMessageResult.Option],
        openMore: @escaping () -> Void,
        complete: @escaping (ReportResult) -> Void
    ) {
        self.context = context
        self.opaqueId = opaqueId
        self.title = title
        self.options = options
        self.openMore = openMore
        self.complete = complete
    }
    
    static func ==(lhs: SheetContainerComponent, rhs: SheetContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.opaqueId != rhs.opaqueId {
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
                        opaqueId: context.component.opaqueId,
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
                        }
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


public final class AdsReportScreen: ViewControllerComponentContainer {
    private let context: AccountContext
        
    public init(
        context: AccountContext,
        opaqueId: Data,
        title: String,
        options: [ReportAdMessageResult.Option],
        forceDark: Bool = false,
        completed: @escaping () -> Void
    ) {
        self.context = context
                
        var completeImpl: ((ReportResult) -> Void)?
        super.init(
            context: context,
            component: SheetContainerComponent(
                context: context,
                opaqueId: opaqueId,
                title: title,
                options: options,
                openMore: {},
                complete: { hidden in
                    completeImpl?(hidden)
                }
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
            case .reported, .hidden:
                completed()
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let text: String
                if case .reported = result {
                    text = presentationData.strings.ReportAd_Reported
                } else {
                    text = presentationData.strings.ReportAd_Hidden
                }
                Queue.mainQueue().after(0.4, {
                    (navigationController?.viewControllers.last as? ViewController)?.present(UndoOverlayController(presentationData: presentationData, content: .actionSucceeded(title: nil, text: text, cancel: nil, destructive: false), elevatedLayout: false, action: { action in
                        if case .info = action, case .reported = result {
                            context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: presentationData.strings.ReportAd_Help_URL, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
                        }
                        return true
                    }), in: .current)
                })
            case .premiumRequired:
                var replaceImpl: ((ViewController) -> Void)?
                let controller = context.sharedContext.makePremiumDemoController(context: context, subject: .noAds, forceDark: false, action: {
                    let controller = context.sharedContext.makePremiumIntroController(context: context, source: .ads, forceDark: false, dismissed: nil)
                    replaceImpl?(controller)
                }, dismissed: nil)
                replaceImpl = { [weak controller] c in
                    controller?.replace(with: c)
                }
                Queue.mainQueue().after(0.4, {
                    navigationController?.pushViewController(controller, animated: true)
                })
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
