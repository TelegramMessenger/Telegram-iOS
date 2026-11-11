import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import Markdown
import TextFormat
import TelegramPresentationData
import ItemListUI
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import ListSectionComponent
import ListActionItemComponent
import NavigationStackComponent
import UndoUI
import AccountContext
import ListTextFieldItemComponent
import ButtonComponent
import BundleIconComponent
import GlassBarButtonComponent
import ActivityIndicatorComponent
import ActivityIndicator

private func providerTitleComponent(theme: PresentationTheme, presentationData: PresentationData, provider: EngineAgentProvider) -> AnyComponent<Empty> {
    return AnyComponent(VStack([
        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
            text: .plain(NSAttributedString(
                string: provider.title,
                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                textColor: theme.list.itemPrimaryTextColor
            )),
            maximumNumberOfLines: 1
        ))),
        AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
            text: .plain(NSAttributedString(
                string: provider.vendor,
                font: Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 15.0 / 17.0)),
                textColor: theme.list.itemSecondaryTextColor
            )),
            maximumNumberOfLines: 1
        )))
    ], alignment: .left, spacing: 2.0))
}

private func sectionHeaderText(_ text: String, theme: PresentationTheme, presentationData: PresentationData, color: UIColor? = nil) -> NSAttributedString {
    return NSAttributedString(string: text.uppercased(), font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: color ?? theme.list.freeTextColor)
}

/// A section header with a text on each side: "API KEY" and, after a rejected key, "INVALID API KEY".
private final class SectionHeaderComponent: Component {
    let title: NSAttributedString
    let accessory: NSAttributedString?

    init(title: NSAttributedString, accessory: NSAttributedString?) {
        self.title = title
        self.accessory = accessory
    }

    static func ==(lhs: SectionHeaderComponent, rhs: SectionHeaderComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.accessory != rhs.accessory {
            return false
        }
        return true
    }

    final class View: UIView {
        private let title = ComponentView<Empty>()
        private let accessory = ComponentView<Empty>()

        func update(component: SectionHeaderComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            var accessoryWidth: CGFloat = 0.0
            var accessorySize = CGSize()
            if let accessoryText = component.accessory {
                accessorySize = self.accessory.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(text: .plain(accessoryText), maximumNumberOfLines: 1)),
                    environment: {},
                    containerSize: availableSize
                )
                accessoryWidth = accessorySize.width + 8.0
            }
            if let accessoryView = self.accessory.view {
                if accessoryView.superview == nil {
                    self.addSubview(accessoryView)
                }
                accessoryView.isHidden = component.accessory == nil
            }

            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(component.title), maximumNumberOfLines: 1)),
                environment: {},
                containerSize: CGSize(width: max(1.0, availableSize.width - accessoryWidth), height: availableSize.height)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = CGRect(origin: CGPoint(), size: titleSize)
            }

            let size = CGSize(width: availableSize.width, height: max(titleSize.height, accessorySize.height))
            if let accessoryView = self.accessory.view {
                accessoryView.frame = CGRect(origin: CGPoint(x: size.width - accessorySize.width, y: 0.0), size: accessorySize)
            }
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

/// The thin ring the button shows while connecting, sized to sit beside the title.
private final class ButtonProgressComponent: Component {
    let color: UIColor

    init(color: UIColor) {
        self.color = color
    }

    static func ==(lhs: ButtonProgressComponent, rhs: ButtonProgressComponent) -> Bool {
        return lhs.color == rhs.color
    }

    final class View: UIView {
        private var indicator: ActivityIndicator?
        private var color: UIColor?

        func update(component: ButtonProgressComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let size = CGSize(width: 16.0, height: 16.0)
            if self.color != component.color {
                self.color = component.color
                self.indicator?.view.removeFromSuperview()
                let indicator = ActivityIndicator(type: .custom(component.color, size.width, 2.0, true))
                self.indicator = indicator
                self.addSubview(indicator.view)
            }
            self.indicator?.view.frame = CGRect(origin: CGPoint(), size: size)
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class ProviderListPageComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let providers: [EngineAgentProvider]?
    let select: (EngineAgentProvider) -> Void

    init(context: AccountContext, providers: [EngineAgentProvider]?, select: @escaping (EngineAgentProvider) -> Void) {
        self.context = context
        self.providers = providers
        self.select = select
    }

    static func ==(lhs: ProviderListPageComponent, rhs: ProviderListPageComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.providers != rhs.providers {
            return false
        }
        return true
    }

    static var body: Body {
        let background = Child(Rectangle.self)
        let title = Child(Text.self)
        let section = Child(ListSectionComponent.self)
        let activity = Child(ActivityIndicatorComponent.self)

        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let theme = environment.theme
            let strings = environment.strings
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left

            var contentSize = CGSize(width: context.availableSize.width, height: 26.0)

            let background = background.update(
                component: Rectangle(color: theme.list.modalBlocksBackgroundColor),
                availableSize: CGSize(width: context.availableSize.width, height: 1000.0),
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: background.size.height / 2.0))
            )

            let title = title.update(
                component: Text(text: strings.Agent_Connect_Title, font: Font.semibold(17.0), color: theme.list.itemPrimaryTextColor),
                availableSize: CGSize(width: context.availableSize.width - 60.0 * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
            )
            contentSize.height += title.size.height
            contentSize.height += 40.0

            if let providers = component.providers {
                let select = component.select
                var items: [AnyComponentWithIdentity<Empty>] = []
                for provider in providers {
                    items.append(AnyComponentWithIdentity(id: provider.id, component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: providerTitleComponent(theme: theme, presentationData: presentationData, provider: provider),
                        leftIcon: .custom(AnyComponentWithIdentity(id: provider.id, component: AnyComponent(AgentProviderIconComponent(
                            context: component.context,
                            theme: theme,
                            provider: provider
                        ))), false),
                        accessory: .arrow,
                        action: { _ in
                            select(provider)
                        }
                    ))))
                }

                let section = section.update(
                    component: ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(sectionHeaderText(strings.Agent_Connect_ProviderHeader, theme: theme, presentationData: presentationData)),
                            maximumNumberOfLines: 0
                        )),
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: strings.Agent_Connect_ProviderInfo, font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: theme.list.freeTextColor)),
                            maximumNumberOfLines: 0
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
            } else {
                let activity = activity.update(
                    component: ActivityIndicatorComponent(color: theme.list.freeTextColor),
                    availableSize: CGSize(width: 100.0, height: 100.0),
                    transition: .immediate
                )
                context.add(activity
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + 60.0))
                )
                contentSize.height += 120.0
            }

            let bottomInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 26.0, sideInset: 16.0)
            contentSize.height += bottomInsets.bottom

            return contentSize
        }
    }
}

private final class ApiKeyPageComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let provider: EngineAgentProvider
    let hasText: Bool
    let isConnecting: Bool
    let isInvalid: Bool
    let keyUpdated: (String) -> Void
    let connect: () -> Void
    let openKeyUrl: () -> Void

    init(
        context: AccountContext,
        provider: EngineAgentProvider,
        hasText: Bool,
        isConnecting: Bool,
        isInvalid: Bool,
        keyUpdated: @escaping (String) -> Void,
        connect: @escaping () -> Void,
        openKeyUrl: @escaping () -> Void
    ) {
        self.context = context
        self.provider = provider
        self.hasText = hasText
        self.isConnecting = isConnecting
        self.isInvalid = isInvalid
        self.keyUpdated = keyUpdated
        self.connect = connect
        self.openKeyUrl = openKeyUrl
    }

    static func ==(lhs: ApiKeyPageComponent, rhs: ApiKeyPageComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.provider != rhs.provider {
            return false
        }
        if lhs.hasText != rhs.hasText {
            return false
        }
        if lhs.isConnecting != rhs.isConnecting {
            return false
        }
        if lhs.isInvalid != rhs.isInvalid {
            return false
        }
        return true
    }

    final class State: ComponentState {
        var didActivateInput = false
    }

    func makeState() -> State {
        return State()
    }

    static var body: Body {
        let background = Child(Rectangle.self)
        let title = Child(Text.self)
        let providerSection = Child(ListSectionComponent.self)
        let keySection = Child(ListSectionComponent.self)
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

            var contentSize = CGSize(width: context.availableSize.width, height: 26.0)

            let background = background.update(
                component: Rectangle(color: theme.list.modalBlocksBackgroundColor),
                availableSize: CGSize(width: context.availableSize.width, height: 1000.0),
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: background.size.height / 2.0))
            )

            let title = title.update(
                component: Text(text: strings.Agent_Key_Title, font: Font.semibold(17.0), color: theme.list.itemPrimaryTextColor),
                availableSize: CGSize(width: context.availableSize.width - 60.0 * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
            )
            contentSize.height += title.size.height
            contentSize.height += 29.0

            let providerSection = providerSection.update(
                component: ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                            theme: theme,
                            style: .glass,
                            title: providerTitleComponent(theme: theme, presentationData: presentationData, provider: component.provider),
                            leftIcon: .custom(AnyComponentWithIdentity(id: component.provider.id, component: AnyComponent(AgentProviderIconComponent(
                                context: component.context,
                                theme: theme,
                                provider: component.provider
                            ))), false),
                            accessory: nil,
                            action: nil
                        )))
                    ],
                    isModal: true
                ),
                environment: {},
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(providerSection
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + providerSection.size.height / 2.0))
            )
            contentSize.height += providerSection.size.height
            contentSize.height += 24.0

            let footerFont = Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize)
            let markdownAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: footerFont, textColor: theme.list.freeTextColor),
                bold: MarkdownAttributeSet(font: footerFont, textColor: theme.list.freeTextColor),
                link: MarkdownAttributeSet(font: footerFont, textColor: theme.list.itemAccentColor),
                linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }
            )
            let openKeyUrl = component.openKeyUrl
            let keySection = keySection.update(
                component: ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(SectionHeaderComponent(
                        title: sectionHeaderText(strings.Agent_Key_Header, theme: theme, presentationData: presentationData),
                        accessory: component.isInvalid ? sectionHeaderText(strings.Agent_Key_Invalid, theme: theme, presentationData: presentationData, color: theme.list.itemDestructiveColor) : nil
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .markdown(text: strings.Agent_Key_Info, attributes: markdownAttributes),
                        maximumNumberOfLines: 0,
                        highlightColor: theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                        highlightAction: { attributes in
                            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                            } else {
                                return nil
                            }
                        },
                        tapAction: { _, _ in
                            openKeyUrl()
                        }
                    )),
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListTextFieldItemComponent(
                            style: .glass,
                            theme: theme,
                            initialText: "",
                            placeholder: strings.Agent_Key_Placeholder(component.provider.vendor).string,
                            clearButtonAccessibilityLabel: strings.WebSearch_RecentSectionClear,
                            autocapitalizationType: .none,
                            autocorrectionType: .no,
                            returnKeyType: .done,
                            isSecureTextEntry: true,
                            updated: component.keyUpdated,
                            onReturn: component.connect,
                            tag: textInputTag
                        )))
                    ],
                    isModal: true
                ),
                environment: {},
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(keySection
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + keySection.size.height / 2.0))
            )
            contentSize.height += keySection.size.height
            contentSize.height += 24.0

            let bottomInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)

            let buttonContent: AnyComponentWithIdentity<Empty>
            if component.isConnecting {
                buttonContent = AnyComponentWithIdentity(id: AnyHashable(1 as Int), component: AnyComponent(HStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(ButtonProgressComponent(color: theme.list.itemCheckColors.foregroundColor))),
                    AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(Text(text: strings.Agent_Key_Connecting, font: Font.semibold(17.0), color: theme.list.itemCheckColors.foregroundColor)))
                ], spacing: 10.0)))
            } else {
                buttonContent = AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(Text(text: strings.Agent_Key_Connect(component.provider.title).string, font: Font.semibold(17.0), color: theme.list.itemCheckColors.foregroundColor)))
            }
            let button = button.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                    ),
                    content: buttonContent,
                    isEnabled: component.isConnecting || component.hasText,
                    tintWhenDisabled: !component.isConnecting,
                    allowActionWhenDisabled: false,
                    displaysProgress: false,
                    action: component.connect
                ),
                environment: {},
                availableSize: CGSize(width: context.availableSize.width - bottomInsets.left - bottomInsets.right, height: 52.0),
                transition: context.transition
            )
            context.add(button
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + button.size.height / 2.0))
            )
            contentSize.height += button.size.height

            if environment.inputHeight > 0.0 {
                contentSize.height += 8.0
            } else {
                contentSize.height += bottomInsets.bottom
            }
            contentSize.height += environment.inputHeight

            if !state.didActivateInput {
                state.didActivateInput = true
                Queue.mainQueue().after(0.45, {
                    if let controller = environment.controller() as? AgentConnectScreen, let textView = controller.node.hostView.findTaggedView(tag: textInputTag) as? ListTextFieldItemComponent.View {
                        textView.activateInput()
                    }
                })
            }

            return contentSize
        }
    }
}

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let settingsContext: AgentSettingsContext
    let pts: Int
    let complete: (EngineAgentProvider) -> Void
    let dismiss: () -> Void
    let update: (ComponentTransition) -> Void

    init(
        context: AccountContext,
        settingsContext: AgentSettingsContext,
        pts: Int,
        complete: @escaping (EngineAgentProvider) -> Void,
        dismiss: @escaping () -> Void,
        update: @escaping (ComponentTransition) -> Void
    ) {
        self.context = context
        self.settingsContext = settingsContext
        self.pts = pts
        self.complete = complete
        self.dismiss = dismiss
        self.update = update
    }

    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.settingsContext !== rhs.settingsContext {
            return false
        }
        if lhs.pts != rhs.pts {
            return false
        }
        return true
    }

    final class State: ComponentState {
        private let context: AccountContext
        private let settingsContext: AgentSettingsContext

        /// The providers without a key yet; nil until the catalog is loaded.
        var providers: [EngineAgentProvider]?
        var selectedProvider: EngineAgentProvider?
        /// The key as typed; it lives only as long as the sheet.
        var keyText = ""
        var isConnecting = false
        var isInvalid = false

        private var stateDisposable: Disposable?
        private let connectDisposable = MetaDisposable()

        init(context: AccountContext, settingsContext: AgentSettingsContext) {
            self.context = context
            self.settingsContext = settingsContext

            super.init()

            self.stateDisposable = (settingsContext.state
            |> deliverOnMainQueue).startStrict(next: { [weak self] state in
                guard let self else {
                    return
                }
                let connected = Set(state.settings?.keys.map(\.provider) ?? [])
                self.providers = state.providers?.filter { !connected.contains($0.id) }
                self.updated(transition: .immediate)
            })
        }

        deinit {
            self.stateDisposable?.dispose()
            self.connectDisposable.dispose()
        }

        func select(_ provider: EngineAgentProvider) {
            self.selectedProvider = provider
            self.keyText = ""
            self.isInvalid = false
            self.isConnecting = false
        }

        func pop() {
            self.connectDisposable.set(nil)
            self.selectedProvider = nil
            self.keyText = ""
            self.isInvalid = false
            self.isConnecting = false
        }

        func keyUpdated(_ text: String) {
            let wasEmpty = self.keyText.isEmpty
            self.keyText = text
            if self.isInvalid || wasEmpty != text.isEmpty {
                self.isInvalid = false
                self.updated(transition: .easeInOut(duration: 0.2))
            }
        }

        func connect(complete: @escaping (EngineAgentProvider) -> Void, presentError: @escaping (String) -> Void) {
            guard let provider = self.selectedProvider, !self.isConnecting else {
                return
            }
            let key = self.keyText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                return
            }
            self.isConnecting = true
            self.isInvalid = false
            self.updated(transition: .easeInOut(duration: 0.2))

            let strings = self.context.sharedContext.currentPresentationData.with { $0 }.strings
            self.connectDisposable.set((self.settingsContext.connect(provider: provider.id, key: key)
            |> deliverOnMainQueue).startStrict(next: { _ in
                complete(provider)
            }, error: { [weak self] error in
                guard let self else {
                    return
                }
                self.isConnecting = false
                switch error {
                case .keyInvalid:
                    self.isInvalid = true
                case .providerUnavailable:
                    presentError(strings.Agent_Key_ProviderUnavailable(provider.title).string)
                default:
                    presentError(strings.Login_UnknownError)
                }
                self.updated(transition: .easeInOut(duration: 0.2))
            }))
        }
    }

    func makeState() -> State {
        return State(context: self.context, settingsContext: self.settingsContext)
    }

    static var body: Body {
        let navigation = Child(NavigationStackComponent<EnvironmentType>.self)
        let backButton = Child(GlassBarButtonComponent.self)

        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            let update = component.update
            let accountContext = component.context
            let controller = environment.controller

            let pop: () -> Void = { [weak state] in
                state?.pop()
                update(.spring(duration: 0.45))
            }

            var items: [AnyComponentWithIdentity<EnvironmentType>] = []
            items.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ProviderListPageComponent(
                context: accountContext,
                providers: state.providers,
                select: { [weak state] provider in
                    state?.select(provider)
                    update(.spring(duration: 0.45))
                }
            ))))
            if let provider = state.selectedProvider {
                let complete = component.complete
                items.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(ApiKeyPageComponent(
                    context: accountContext,
                    provider: provider,
                    hasText: !state.keyText.isEmpty,
                    isConnecting: state.isConnecting,
                    isInvalid: state.isInvalid,
                    keyUpdated: { [weak state] text in
                        state?.keyUpdated(text)
                    },
                    connect: { [weak state] in
                        state?.connect(complete: complete, presentError: { text in
                            let presentationData = accountContext.sharedContext.currentPresentationData.with { $0 }
                            controller()?.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return true }), in: .current)
                        })
                    },
                    openKeyUrl: {
                        guard let navigationController = controller()?.navigationController as? NavigationController else {
                            return
                        }
                        let presentationData = accountContext.sharedContext.currentPresentationData.with { $0 }
                        accountContext.sharedContext.openExternalUrl(context: accountContext, urlContext: .generic, url: provider.keyUrl, forceExternal: true, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
                    }
                ))))
            }

            var contentSize = CGSize(width: context.availableSize.width, height: 0.0)
            let navigation = navigation.update(
                component: NavigationStackComponent(
                    items: items,
                    clipContent: false,
                    requestPop: {
                        pop()
                    }
                ),
                environment: { environment },
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: context.transition
            )
            context.add(navigation
                .position(CGPoint(x: context.availableSize.width / 2.0, y: navigation.size.height / 2.0))
            )
            contentSize.height += navigation.size.height

            let isBack = items.count > 1
            let barButtonSize = CGSize(width: 44.0, height: 44.0)
            let backButton = backButton.update(
                component: GlassBarButtonComponent(
                    size: barButtonSize,
                    backgroundColor: nil,
                    isDark: environment.theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: isBack ? "back" : "close", component: AnyComponent(
                        BundleIconComponent(
                            name: isBack ? "Navigation/Back" : "Navigation/Close",
                            tintColor: environment.theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { _ in
                        if isBack {
                            pop()
                        } else {
                            component.dismiss()
                        }
                    }
                ),
                environment: {},
                availableSize: barButtonSize,
                transition: context.transition
            )
            context.add(backButton
                .position(CGPoint(x: 16.0 + backButton.size.width / 2.0, y: 16.0 + backButton.size.height / 2.0))
            )

            return contentSize
        }
    }
}

private final class SheetContainerComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let settingsContext: AgentSettingsContext
    let complete: (EngineAgentProvider) -> Void

    init(context: AccountContext, settingsContext: AgentSettingsContext, complete: @escaping (EngineAgentProvider) -> Void) {
        self.context = context
        self.settingsContext = settingsContext
        self.complete = complete
    }

    static func ==(lhs: SheetContainerComponent, rhs: SheetContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.settingsContext !== rhs.settingsContext {
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

            let dismiss: (Bool) -> Void = { animated in
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

            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        context: context.component.context,
                        settingsContext: context.component.settingsContext,
                        pts: state.pts,
                        complete: context.component.complete,
                        dismiss: {
                            dismiss(true)
                        },
                        update: { [weak state] transition in
                            state?.pts += 1
                            state?.updated(transition: transition)
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.list.modalBlocksBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    externalState: sheetExternalState,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.presentsFloatingPanels,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            dismiss(animated)
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
                    reservedCorners: environment.reservedCorners,
                    division: nil,
                    additionalInsets: .zero,
                    statusBarHeight: environment.fullStatusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false,
                    presentedInFormSheet: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }

            return context.availableSize
        }
    }
}

/// Connects an AI provider's API key to the agent: the provider list, then the key page. The key is held only by the
/// text field while the sheet is open; it is never logged or stored.
public final class AgentConnectScreen: ViewControllerComponentContainer {
    public init(
        context: AccountContext,
        settingsContext: AgentSettingsContext,
        completion: @escaping (EngineAgentProvider) -> Void
    ) {
        var completeImpl: ((EngineAgentProvider) -> Void)?
        super.init(
            context: context,
            component: SheetContainerComponent(
                context: context,
                settingsContext: settingsContext,
                complete: { provider in
                    completeImpl?(provider)
                }
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.navigationPresentation = .flatModal

        completeImpl = { [weak self] provider in
            guard let self else {
                return
            }
            self.view.endEditing(true)
            self.dismissAnimated()
            completion(provider)
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}
