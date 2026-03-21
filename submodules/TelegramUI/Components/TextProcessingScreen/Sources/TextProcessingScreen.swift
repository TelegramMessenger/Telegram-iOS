import Foundation
import UIKit
import SwiftSignalKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AccountContext
import ViewControllerComponent
import MultilineTextComponent
import ButtonComponent
import BundleIconComponent
import TelegramCore
import PresentationDataUtils
import ResizableSheetComponent
import GlassBarButtonComponent
import TabBarComponent
import TranslateUI
import LottieComponent
import ListSectionComponent
import ListActionItemComponent

final class TextProcessingContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    final class ExternalState {
        fileprivate(set) var isProcessing: Bool = false
        fileprivate(set) var nonPremiumFloodTriggered: Bool = false
        fileprivate(set) var result: TextWithEntities?
        
        init() {
        }
    }

    let externalState: ExternalState
    let context: AccountContext
    let mode: TextProcessingScreen.Mode
    let styles: [TelegramComposeAIMessageMode.Style]
    let inputText: TextWithEntities
    let copyCurrentResult: (() -> Void)?
    let translateChat: ((String) -> Void)?
    let displayLanguageSelectionMenu: (UIView, String, TelegramComposeAIMessageMode.StyleId, Bool,  @escaping (String, TelegramComposeAIMessageMode.StyleId) -> Void) -> Void

    init(
        externalState: ExternalState,
        context: AccountContext,
        mode: TextProcessingScreen.Mode,
        styles: [TelegramComposeAIMessageMode.Style],
        inputText: TextWithEntities,
        copyCurrentResult: (() -> Void)?,
        translateChat: ((String) -> Void)?,
        displayLanguageSelectionMenu: @escaping (UIView, String, TelegramComposeAIMessageMode.StyleId, Bool, @escaping (String, TelegramComposeAIMessageMode.StyleId) -> Void) -> Void
    ) {
        self.externalState = externalState
        self.styles = styles
        self.context = context
        self.mode = mode
        self.inputText = inputText
        self.copyCurrentResult = copyCurrentResult
        self.translateChat = translateChat
        self.displayLanguageSelectionMenu = displayLanguageSelectionMenu
    }

    static func ==(lhs: TextProcessingContentComponent, rhs: TextProcessingContentComponent) -> Bool {
        return true
    }
    
    private enum Mode {
        case translate
        case stylize
        case fix
    }

    final class View: UIView {
        private var component: TextProcessingContentComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private let modeTabs = ComponentView<Empty>()
        private let actionsSection = ComponentView<Empty>()
        
        private let currentContentBackground: UIImageView
        private let currentContentContainer: UIView
        
        private let translateState = TextProcessingTranslateContentComponent.ExternalState()
        private let stylizeState = TextProcessingTranslateContentComponent.ExternalState()
        private let fixState = TextProcessingTranslateContentComponent.ExternalState()
        
        private var currentContent: (mode: Mode, view: ComponentView<Empty>)?
        
        private var currentMode: Mode = .translate
        
        override init(frame: CGRect) {
            self.currentContentBackground = UIImageView()
            self.currentContentContainer = UIView()
            self.currentContentContainer.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.addSubview(self.currentContentBackground)
            self.addSubview(self.currentContentContainer)
            
            self.translateState.resultUpdated = { [weak self] result in
                guard let self, let component = self.component else {
                    return
                }
                if case .translate = self.currentMode {
                    component.externalState.result = result?.text
                }
            }
            self.translateState.isProcessingUpdated = { [weak self] isProcessing in
                guard let self, let component = self.component else {
                    return
                }
                if case .translate = self.currentMode {
                    component.externalState.isProcessing = isProcessing
                }
            }
            self.translateState.nonPremiumFloodTriggeredUpdated = { [weak self] _ in
                guard let self else {
                    return
                }
                self.nonPremiumFloodTriggeredUpdated()
            }
            self.stylizeState.resultUpdated = { [weak self] result in
                guard let self, let component = self.component else {
                    return
                }
                if case .stylize = self.currentMode {
                    component.externalState.result = result?.text
                }
            }
            self.stylizeState.isProcessingUpdated = { [weak self] isProcessing in
                guard let self, let component = self.component else {
                    return
                }
                if case .stylize = self.currentMode {
                    component.externalState.isProcessing = isProcessing
                }
            }
            self.stylizeState.nonPremiumFloodTriggeredUpdated = { [weak self] _ in
                guard let self else {
                    return
                }
                self.nonPremiumFloodTriggeredUpdated()
            }
            self.fixState.resultUpdated = { [weak self] result in
                guard let self, let component = self.component else {
                    return
                }
                if case .fix = self.currentMode {
                    component.externalState.result = result?.text
                }
            }
            self.fixState.isProcessingUpdated = { [weak self] isProcessing in
                guard let self, let component = self.component else {
                    return
                }
                if case .fix = self.currentMode {
                    component.externalState.isProcessing = isProcessing
                }
            }
            self.fixState.nonPremiumFloodTriggeredUpdated = { [weak self] _ in
                guard let self else {
                    return
                }
                self.nonPremiumFloodTriggeredUpdated()
            }
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        private func nonPremiumFloodTriggeredUpdated() {
            guard let component = self.component else {
                return
            }
            component.externalState.nonPremiumFloodTriggered = self.translateState.nonPremiumFloodTriggered || self.stylizeState.nonPremiumFloodTriggered || self.fixState.nonPremiumFloodTriggered
        }

        func update(component: TextProcessingContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            
            self.component = component
            self.state = state
            
            let sideInset: CGFloat = 16.0

            var contentHeight: CGFloat = 0.0
            contentHeight += 82.0
            
            switch component.mode {
            case .edit:
                contentHeight += 3.0
                var tabs: [TabBarComponent.Item] = []
                tabs.append(TabBarComponent.Item(
                    content: .customItem(TabBarComponent.Item.Content.CustomItem(
                        id: "translate",
                        title: "Translate",
                        icon: .bundleIcon(name: "TextProcessing/TabTranslate")
                    )),
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        if self.currentMode != .translate {
                            self.currentMode = .translate
                        }
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    },
                    doubleTapAction: nil,
                    contextAction: nil
                ))
                tabs.append(TabBarComponent.Item(
                    content: .customItem(TabBarComponent.Item.Content.CustomItem(
                        id: "stylize",
                        title: "Style",
                        icon: .bundleIcon(name: "TextProcessing/TabStylize")
                    )),
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        if self.currentMode != .stylize {
                            self.currentMode = .stylize
                        }
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    },
                    doubleTapAction: nil,
                    contextAction: nil
                ))
                tabs.append(TabBarComponent.Item(
                    content: .customItem(TabBarComponent.Item.Content.CustomItem(
                        id: "fix",
                        title: "Fix",
                        icon: .bundleIcon(name: "TextProcessing/TabFix")
                    )),
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        if self.currentMode != .fix {
                            self.currentMode = .fix
                        }
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    },
                    doubleTapAction: nil,
                    contextAction: nil
                ))
                
                let currentModeId: String
                switch self.currentMode {
                case .translate:
                    currentModeId = "translate"
                case .stylize:
                    currentModeId = "stylize"
                case .fix:
                    currentModeId = "fix"
                }
                let modeTabsSize = self.modeTabs.update(
                    transition: transition,
                    component: AnyComponent(TabBarComponent(
                        theme: environment.theme,
                        tintSelectedItem: false,
                        isLiftedStateEnabled: false,
                        strings: environment.strings,
                        items: tabs,
                        search: nil,
                        selectedId: currentModeId,
                        outerInsets: UIEdgeInsets()
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 62.0)
                )
                let modeTabsFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: modeTabsSize)
                if let modeTabsView = self.modeTabs.view {
                    if modeTabsView.superview == nil {
                        self.modeTabs.parentState = state
                        self.addSubview(modeTabsView)
                    }
                    transition.setFrame(view: modeTabsView, frame: modeTabsFrame)
                }
                contentHeight += modeTabsSize.height
                contentHeight += 24.0
            case .translate:
                break
            }
            
            if let currentContent = self.currentContent, currentContent.mode != self.currentMode {
                if let currentContentView = currentContent.view.view {
                    transition.setAlpha(view: currentContentView, alpha: 0.0, completion: { [weak currentContentView] _ in
                        currentContentView?.removeFromSuperview()
                    })
                }
                self.currentContent = nil
            }
            
            let contentComponent: AnyComponent<Empty>
            switch self.currentMode {
            case .translate:
                contentComponent = AnyComponent(TextProcessingTranslateContentComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    styles: component.styles,
                    externalState: self.translateState,
                    inputText: component.inputText,
                    mode: .translate,
                    copyAction: component.copyCurrentResult,
                    displayLanguageSelectionMenu: component.displayLanguageSelectionMenu
                ))
            case .stylize:
                contentComponent = AnyComponent(TextProcessingTranslateContentComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    styles: component.styles,
                    externalState: self.stylizeState,
                    inputText: component.inputText,
                    mode: .stylize,
                    copyAction: component.copyCurrentResult,
                    displayLanguageSelectionMenu: component.displayLanguageSelectionMenu
                ))
            case .fix:
                contentComponent = AnyComponent(TextProcessingTranslateContentComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    styles: component.styles,
                    externalState: self.fixState,
                    inputText: component.inputText,
                    mode: .fix,
                    copyAction: component.copyCurrentResult,
                    displayLanguageSelectionMenu: component.displayLanguageSelectionMenu
                ))
            }
            
            let content: ComponentView<Empty>
            var contentTransition = transition
            if let current = self.currentContent {
                content = current.view
            } else {
                content = ComponentView()
                self.currentContent = (self.currentMode, content)
                contentTransition = contentTransition.withAnimation(.none)
            }
            let contentSize = content.update(
                transition: contentTransition,
                component: contentComponent,
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000000.0)
            )
            if let contentView = content.view {
                if contentView.superview == nil {
                    content.parentState = state
                    self.currentContentContainer.addSubview(contentView)
                    contentView.layer.allowsGroupOpacity = true
                    contentView.alpha = 0.0
                }
                alphaTransition.setAlpha(view: contentView, alpha: 1.0)
                contentTransition.setFrame(view: contentView, frame: CGRect(origin: CGPoint(), size: contentSize))
            }
            let contentFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: contentSize)
            transition.setFrame(view: self.currentContentContainer, frame: contentFrame)
            
            if self.currentContentBackground.image == nil {
                self.currentContentBackground.image = generateStretchableFilledCircleImage(diameter: 60.0, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            self.currentContentBackground.tintColor = environment.theme.list.itemBlocksBackgroundColor
            transition.setFrame(view: self.currentContentBackground, frame: contentFrame)
            
            contentHeight += contentSize.height
            
            var actionsSectionItems: [AnyComponentWithIdentity<Empty>] = []
            if case .translate = component.mode {
                /*if let replaceText = component.replaceText {
                 //TODO:localize
                 actionsSectionItems.append(AnyComponentWithIdentity(id: "replace", component: AnyComponent(ListActionItemComponent(
                 theme: theme,
                 style: .glass,
                 title: AnyComponent(
                 MultilineTextComponent(
                 text: .plain(NSAttributedString(
                 string: "Replace with Translation",
                 font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                 textColor: theme.list.itemAccentColor
                 )),
                 maximumNumberOfLines: 1
                 )
                 ),
                 leftIcon: .custom(AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Chat/Context Menu/Replace", tintColor: theme.list.itemAccentColor))), false),
                 action: { [weak state] _ in
                 guard let state else {
                 return
                 }
                 replaceText(state.translatedText?.0 ?? state.text, state.translatedText?.1 ?? state.entities)
                 component.dismiss()
                 }
                 ))))
                 }*/
                if let copyTranslation = component.copyCurrentResult {
                    actionsSectionItems.append(AnyComponentWithIdentity(id: "copy", component: AnyComponent(ListActionItemComponent(
                        theme: environment.theme,
                        style: .glass,
                        title: AnyComponent(
                            MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: environment.strings.Translate_CopyTranslation,
                                    font: Font.regular(17.0),
                                    textColor: environment.theme.list.itemAccentColor
                                )),
                                maximumNumberOfLines: 1
                            )
                        ),
                        leftIcon: .custom(AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Chat/Context Menu/Copy", tintColor: environment.theme.list.itemAccentColor))), false),
                        action: { _ in
                            copyTranslation()
                        }
                    ))))
                }
                if let translateChat = component.translateChat {
                    actionsSectionItems.append(AnyComponentWithIdentity(id: "translate", component: AnyComponent(ListActionItemComponent(
                        theme: environment.theme,
                        style: .glass,
                        title: AnyComponent(
                            MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: "Translate Entire Chat",
                                    font: Font.regular(17.0),
                                    textColor: environment.theme.list.itemAccentColor
                                )),
                                maximumNumberOfLines: 1
                            )
                        ),
                        leftIcon: .custom(AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Chat/Context Menu/Translate", tintColor: environment.theme.list.itemAccentColor))), false),
                        action: { [weak self] _ in
                            guard let self, let language = self.translateState.result?.language else {
                                return
                            }
                            translateChat(language)
                        }
                    ))))
                }
            }
            
            if !actionsSectionItems.isEmpty {
                contentHeight += 24.0
                let actionsSectionSize = self.actionsSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        style: .glass,
                        header: nil,
                        footer: nil,
                        items: actionsSectionItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
                )
                let actionsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: actionsSectionSize)
                self.actionsSection.parentState = state
                if let actionsSectionView = self.actionsSection.view {
                    if actionsSectionView.superview == nil {
                        self.addSubview(actionsSectionView)
                    }
                    transition.setFrame(view: actionsSectionView, frame: actionsSectionFrame)
                }
                contentHeight += actionsSectionSize.height + 3.0
            }
            
            contentHeight += 106.0

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class TextProcessingSheetComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let mode: TextProcessingScreen.Mode
    let ignoredTranslationLanguages: [String]
    let styles: [TelegramComposeAIMessageMode.Style]
    let inputText: TextWithEntities
    let copyCurrentResult: ((TextWithEntities) -> Void)?
    let translateChat: ((String) -> Void)?

    init(
        context: AccountContext,
        mode: TextProcessingScreen.Mode,
        ignoredTranslationLanguages: [String],
        styles: [TelegramComposeAIMessageMode.Style],
        inputText: TextWithEntities,
        copyCurrentResult: ((TextWithEntities) -> Void)?,
        translateChat: ((String) -> Void)?
    ) {
        self.context = context
        self.mode = mode
        self.ignoredTranslationLanguages = ignoredTranslationLanguages
        self.styles = styles
        self.inputText = inputText
        self.copyCurrentResult = copyCurrentResult
        self.translateChat = translateChat
    }

    static func ==(lhs: TextProcessingSheetComponent, rhs: TextProcessingSheetComponent) -> Bool {
        return true
    }

    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, ResizableSheetComponentEnvironment)>()
        private var languageSelectionMenu: ComponentView<Empty>?
        private let animateOut = ActionSlot<Action<Void>>()
        private let contentExternalState = TextProcessingContentComponent.ExternalState()

        private final class LanguageSelectionMenuData {
            let sourceView: UIView
            let currentLanguage: String
            let currentStyle: TelegramComposeAIMessageMode.StyleId
            let displayStyle: Bool
            let completion: (String, TelegramComposeAIMessageMode.StyleId) -> Void

            init(sourceView: UIView, currentLanguage: String, currentStyle: TelegramComposeAIMessageMode.StyleId, displayStyle: Bool, completion: @escaping (String, TelegramComposeAIMessageMode.StyleId) -> Void) {
                self.sourceView = sourceView
                self.currentLanguage = currentLanguage
                self.currentStyle = currentStyle
                self.displayStyle = displayStyle
                self.completion = completion
            }
        }
        private var languageSelectionMenuData: LanguageSelectionMenuData?

        private var component: TextProcessingSheetComponent?
        private var environment: ViewControllerComponentContainer.Environment?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: TextProcessingSheetComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state

            let environmentValue = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environmentValue
            let controller = environmentValue.controller
            let theme = environmentValue.theme

            let dismiss: (Bool) -> Void = { [weak self] animated in
                if animated {
                    self?.animateOut.invoke(Action { _ in
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

            let performMainAction: () -> Void
            var performSendAction: ((TextWithEntities) -> Void)?
            let isMainActionEnabled: Bool
            //TODO:localize (for AI: don't remove this line)
            let actionButtonTitle: String
            
            if self.contentExternalState.nonPremiumFloodTriggered {
                isMainActionEnabled = true
                actionButtonTitle = "Increase Limit"
                performMainAction = { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    
                    let context = component.context
                    var replaceImpl: ((ViewController) -> Void)?
                    let controller = component.context.sharedContext.makePremiumDemoController(context: component.context, subject: .doubleLimits, forceDark: false, action: {
                        let controller = component.context.sharedContext.makePremiumIntroController(context: context, source: .settings, forceDark: false, dismissed: nil)
                        replaceImpl?(controller)
                    }, dismissed: nil)
                    replaceImpl = { [weak controller] c in
                        controller?.replace(with: c)
                    }
                    self.environment?.controller()?.push(controller)
                }
            } else {
                switch component.mode {
                case let .edit(completion, send):
                    actionButtonTitle = "Apply"
                    performSendAction = send
                    isMainActionEnabled = !self.contentExternalState.isProcessing
                    performMainAction = { [weak self] in
                        guard let self else {
                            return
                        }
                        if let result = self.contentExternalState.result {
                            completion(result)
                        }
                        dismiss(true)
                    }
                case .translate:
                    actionButtonTitle = "Close"
                    isMainActionEnabled = true
                    performMainAction = {
                        dismiss(true)
                    }
                }
            }
            let copyCurrentResult = component.copyCurrentResult
            let copyCurrentResultImpl: () -> Void = { [weak self] in
                guard let self else {
                    return
                }
                if let result = self.contentExternalState.result {
                    copyCurrentResult?(result)
                    dismiss(true)
                }
            }

            let titleString: String
            switch component.mode {
            case .edit:
                titleString = "AI Editor"
            case .translate:
                titleString = "Translation"
            }

            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(ResizableSheetComponent<ViewControllerComponentContainer.Environment>(
                    content: AnyComponent<ViewControllerComponentContainer.Environment>(TextProcessingContentComponent(
                        externalState: self.contentExternalState,
                        context: component.context,
                        mode: component.mode,
                        styles: component.styles,
                        inputText: component.inputText,
                        copyCurrentResult: component.copyCurrentResult != nil ? {
                            copyCurrentResultImpl()
                        } : nil,
                        translateChat: component.translateChat.flatMap { translateChat in
                            { language in
                                translateChat(language)
                                dismiss(true)
                            }
                        },
                        displayLanguageSelectionMenu: { [weak self] sourceView, currentLanguage, currentStyle, displayStyle, completion in
                            guard let self else { return }
                            self.languageSelectionMenuData = LanguageSelectionMenuData(sourceView: sourceView, currentLanguage: currentLanguage, currentStyle: currentStyle, displayStyle: displayStyle, completion: completion)
                            self.state?.updated(transition: .immediate)
                        }
                    )),
                    titleItem: AnyComponent(TitleComponent(
                        theme: theme,
                        title: titleString,
                        isProcessing: self.contentExternalState.isProcessing
                    )),
                    leftItem: AnyComponent(
                        GlassBarButtonComponent(
                            size: CGSize(width: 44.0, height: 44.0),
                            backgroundColor: nil,
                            isDark: theme.overallDarkAppearance,
                            state: .glass,
                            component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                                BundleIconComponent(
                                    name: "Navigation/Close",
                                    tintColor: theme.chat.inputPanel.panelControlColor
                                )
                            )),
                            action: { _ in
                                dismiss(true)
                            }
                        )
                    ),
                    rightItem: AnyComponent(
                        GlassBarButtonComponent(
                            size: CGSize(width: 44.0, height: 44.0),
                            backgroundColor: nil,
                            isDark: theme.overallDarkAppearance,
                            state: .glass,
                            component: AnyComponentWithIdentity(id: "info", component: AnyComponent(
                                BundleIconComponent(
                                    name: "Navigation/Info",
                                    tintColor: theme.chat.inputPanel.panelControlColor
                                )
                            )),
                            action: { [weak self] _ in
                                guard let self, let component = self.component, let environment = self.environment else {
                                    return
                                }
                                environment.controller()?.push(component.context.sharedContext.makeCocoonInfoScreen(context: component.context))
                            }
                        )
                    ),
                    bottomItem: AnyComponent(
                        ActionButtonsComponent(
                            theme: theme,
                            actionTitle: actionButtonTitle,
                            action: isMainActionEnabled ? performMainAction : nil,
                            sendAction: performSendAction.flatMap { [weak self] performSendAction in
                                return {
                                    guard let self else {
                                        return
                                    }
                                    if let result = self.contentExternalState.result {
                                        performSendAction(result)
                                        dismiss(true)
                                    }
                                }
                            }
                        )
                        /*ButtonComponent(
                            background: ButtonComponent.Background(
                                style: .glass,
                                color: theme.list.itemCheckColors.fillColor,
                                foreground: theme.list.itemCheckColors.foregroundColor,
                                pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                            ),
                            content: AnyComponentWithIdentity(
                                id: AnyHashable(0),
                                component: AnyComponent(ButtonTextContentComponent(
                                    text: actionButtonTitle,
                                    badge: 0,
                                    textColor: theme.list.itemCheckColors.foregroundColor,
                                    badgeBackground: theme.list.itemCheckColors.foregroundColor,
                                    badgeForeground: theme.list.itemCheckColors.fillColor
                                ))
                            ),
                            isEnabled: isMainActionEnabled,
                            displaysProgress: false,
                            action: {
                                performMainAction()
                            }
                        )*/
                    ),
                    backgroundColor: .color(theme.list.blocksBackgroundColor),
                    animateOut: self.animateOut
                )),
                environment: {
                    environmentValue
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environmentValue.statusBarHeight,
                        safeInsets: environmentValue.safeInsets,
                        inputHeight: 0.0,
                        metrics: environmentValue.metrics,
                        deviceMetrics: environmentValue.deviceMetrics,
                        isDisplaying: environmentValue.isVisible,
                        isCentered: environmentValue.metrics.widthClass == .regular,
                        screenSize: availableSize,
                        regularMetricsSize: nil,
                        dismiss: { animated in
                            dismiss(animated)
                        }
                    )
                },
                containerSize: availableSize
            )
            self.sheet.parentState = state
            if let sheetView = self.sheet.view {
                if sheetView.superview == nil {
                    self.addSubview(sheetView)
                }
                transition.setFrame(view: sheetView, frame: CGRect(origin: .zero, size: sheetSize))
            }

            if let languageSelectionMenuDataValue = self.languageSelectionMenuData {
                let languageSelectionMenu: ComponentView<Empty>
                if let current = self.languageSelectionMenu {
                    languageSelectionMenu = current
                } else {
                    languageSelectionMenu = ComponentView<Empty>()
                    self.languageSelectionMenu = languageSelectionMenu
                }

                let menuSize = languageSelectionMenu.update(
                    transition: transition,
                    component: AnyComponent(TextProcessingLanguageSelectionComponent(
                        theme: theme,
                        strings: environmentValue.strings,
                        sourceView: languageSelectionMenuDataValue.sourceView,
                        topLanguages: [],
                        selectedLanguageCode: languageSelectionMenuDataValue.currentLanguage,
                        currentStyle: languageSelectionMenuDataValue.currentStyle,
                        displayStyles: languageSelectionMenuDataValue.displayStyle ? component.styles : nil,
                        completion: languageSelectionMenuDataValue.completion,
                        dismissed: { [weak self] in
                            guard let self else { return }
                            self.languageSelectionMenuData = nil
                            self.state?.updated(transition: .immediate)
                        },
                        inputHeight: environmentValue.inputHeight
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                languageSelectionMenu.parentState = state
                if let menuView = languageSelectionMenu.view {
                    if menuView.superview == nil {
                        self.addSubview(menuView)
                    }
                    transition.setFrame(view: menuView, frame: CGRect(origin: .zero, size: menuSize))
                }
            } else if let languageSelectionMenu = self.languageSelectionMenu {
                self.languageSelectionMenu = nil
                languageSelectionMenu.view?.removeFromSuperview()
            }

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

public class TextProcessingScreen: ViewControllerComponentContainer {
    public enum Mode {
        case edit(completion: (TextWithEntities) -> Void, send: ((TextWithEntities) -> Void)?)
        case translate(fromLanguage: String?)
    }
    
    private let context: AccountContext

    public init(
        context: AccountContext,
        mode: Mode,
        ignoredTranslationLanguages: [String],
        inputText: TextWithEntities,
        copyResult: ((TextWithEntities) -> Void)?,
        translateChat: ((String) -> Void)?
    ) async {
        self.context = context
        
        let styles = await context.engine.messages.composeAIMessageStyles().get()

        super.init(
            context: context,
            component: TextProcessingSheetComponent(
                context: context,
                mode: mode,
                ignoredTranslationLanguages: ignoredTranslationLanguages,
                styles: styles,
                inputText: inputText,
                copyCurrentResult: copyResult,
                translateChat: translateChat
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

private final class TitleComponent: Component {
    let theme: PresentationTheme
    let title: String
    let isProcessing: Bool
    
    init(
        theme: PresentationTheme,
        title: String,
        isProcessing: Bool
    ) {
        self.theme = theme
        self.title = title
        self.isProcessing = isProcessing
    }
    
    static func ==(lhs: TitleComponent, rhs: TitleComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.isProcessing != rhs.isProcessing {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var animationIcon: ComponentView<Empty>?
        private let title = ComponentView<Empty>()
        
        private var component: TitleComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: TitleComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.semibold(17.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            if component.isProcessing {
                let animationIcon: ComponentView<Empty>
                var animationIconTransition = transition
                if let current = self.animationIcon {
                    animationIcon = current
                } else {
                    animationIconTransition = animationIconTransition.withAnimation(.none)
                    animationIcon = ComponentView()
                    self.animationIcon = animationIcon
                }
                
                let animationIconSize = animationIcon.update(
                    transition: animationIconTransition,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(
                            name: "SparklesEmoji"
                        ),
                        placeholderColor: nil,
                        startingPosition: .begin,
                        size: CGSize(width: 30.0, height: 30.0),
                        loop: true
                    )),
                    environment: {},
                    containerSize: CGSize(width: 30.0, height: 30.0)
                )
                let animationIconFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: titleFrame.minY + floorToScreenPixels((titleFrame.height - animationIconSize.height) * 0.5) - 2.0), size: animationIconSize)
                if let animationIconView = animationIcon.view {
                    if animationIconView.superview == nil {
                        self.addSubview(animationIconView)
                        animationIconView.alpha = 0.0
                    }
                    animationIconTransition.setFrame(view: animationIconView, frame: animationIconFrame)
                    transition.setAlpha(view: animationIconView, alpha: 1.0)
                }
            } else {
                if let animationIcon = self.animationIcon {
                    self.animationIcon = nil
                    if let animationIconView = animationIcon.view {
                        transition.setAlpha(view: animationIconView, alpha: 0.0, completion: { [weak animationIconView] _ in
                            animationIconView?.removeFromSuperview()
                        })
                    }
                }
            }

            return titleSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ActionButtonsComponent: Component {
    let theme: PresentationTheme
    let actionTitle: String
    let action: (() -> Void)?
    let sendAction: (() -> Void)?
    
    init(
        theme: PresentationTheme,
        actionTitle: String,
        action: (() -> Void)?,
        sendAction: (() -> Void)?
    ) {
        self.theme = theme
        self.actionTitle = actionTitle
        self.action = action
        self.sendAction = sendAction
    }
    
    static func ==(lhs: ActionButtonsComponent, rhs: ActionButtonsComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.actionTitle != rhs.actionTitle {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        if (lhs.sendAction == nil) != (rhs.sendAction == nil) {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let actionButton = ComponentView<Empty>()
        private let sendButton = ComponentView<Empty>()
        
        private var component: ActionButtonsComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ActionButtonsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let spacing: CGFloat = 10.0
            var actionButtonWidth: CGFloat = availableSize.width
            if component.sendAction != nil {
                actionButtonWidth -= 52.0 + spacing
            }
            
            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.list.itemCheckColors.fillColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(ButtonTextContentComponent(
                            text: component.actionTitle,
                            badge: 0,
                            textColor: component.theme.list.itemCheckColors.foregroundColor,
                            badgeBackground: component.theme.list.itemCheckColors.foregroundColor,
                            badgeForeground: component.theme.list.itemCheckColors.fillColor
                        ))
                    ),
                    isEnabled: component.action != nil,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.action?()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: actionButtonWidth, height: availableSize.height)
            )
            let actionButtonFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: actionButtonSize)
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
            }
            
            let sendButtonSize = self.sendButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.list.itemCheckColors.fillColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(TransformContents(content: AnyComponent(BundleIconComponent(
                            name: "TextProcessing/SendIcon",
                            tintColor: component.theme.list.itemCheckColors.foregroundColor
                        )), translation: CGPoint(x: -2.0, y: 0.0)))
                    ),
                    contentInsets: UIEdgeInsets(),
                    isEnabled: component.action != nil,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.sendAction?()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 52.0, height: 52.0)
            )
            let sendButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - sendButtonSize.width, y: 0.0), size: sendButtonSize)
            if let sendButtonView = self.sendButton.view {
                if sendButtonView.superview == nil {
                    self.addSubview(sendButtonView)
                }
                transition.setPosition(view: sendButtonView, position: sendButtonFrame.center)
                transition.setBounds(view: sendButtonView, bounds: CGRect(origin: CGPoint(), size: sendButtonFrame.size))
                transition.setAlpha(view: sendButtonView, alpha: component.sendAction != nil ? 1.0 : 0.0)
                transition.setScale(view: sendButtonView, scale: component.sendAction != nil ? 1.0 : 0.001)
            }

            return CGSize(width: availableSize.width, height: actionButtonSize.height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
