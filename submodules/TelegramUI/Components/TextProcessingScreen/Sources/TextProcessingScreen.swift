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
import ToastComponent
import TelegramNotices
import Markdown
import TelegramUIPreferences
import ChatSendMessageActionUI

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
    let styles: [TextProcessingScreen.Style]
    let inputText: TextWithEntities
    let initialEditState: TextProcessingScreen.EditState?
    let ignoredTranslationLanguages: [String]
    let shouldDisplayStyleNotice: Bool
    let copyCurrentResult: (() -> Void)?
    let translateChat: ((String) -> Void)?
    let displayLanguageSelectionMenu: (UIView, String, TelegramComposeAIMessageMode.StyleId, Bool,  @escaping (String, TelegramComposeAIMessageMode.StyleId) -> Void) -> Void

    init(
        externalState: ExternalState,
        context: AccountContext,
        mode: TextProcessingScreen.Mode,
        styles: [TextProcessingScreen.Style],
        inputText: TextWithEntities,
        initialEditState: TextProcessingScreen.EditState?,
        ignoredTranslationLanguages: [String],
        shouldDisplayStyleNotice: Bool,
        copyCurrentResult: (() -> Void)?,
        translateChat: ((String) -> Void)?,
        displayLanguageSelectionMenu: @escaping (UIView, String, TelegramComposeAIMessageMode.StyleId, Bool, @escaping (String, TelegramComposeAIMessageMode.StyleId) -> Void) -> Void
    ) {
        self.externalState = externalState
        self.styles = styles
        self.context = context
        self.mode = mode
        self.inputText = inputText
        self.initialEditState = initialEditState
        self.ignoredTranslationLanguages = ignoredTranslationLanguages
        self.shouldDisplayStyleNotice = shouldDisplayStyleNotice
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
        private var environment: ViewControllerComponentContainer.Environment?
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
            
            self.translateState.resultUpdated = { [weak self] _ in
                self?.externalStatesUpdated()
            }
            self.translateState.isProcessingUpdated = { [weak self] _ in
                self?.externalStatesUpdated()
            }
            self.translateState.nonPremiumFloodTriggeredUpdated = { [weak self] _ in
                self?.externalStatesUpdated()
            }
            self.stylizeState.resultUpdated = { [weak self] _ in
                self?.externalStatesUpdated()
            }
            self.stylizeState.isProcessingUpdated = { [weak self] _ in
                self?.externalStatesUpdated()
            }
            self.stylizeState.nonPremiumFloodTriggeredUpdated = { [weak self] _ in
                self?.externalStatesUpdated()
            }
            self.fixState.resultUpdated = { [weak self] _ in
                self?.externalStatesUpdated()
            }
            self.fixState.isProcessingUpdated = { [weak self] _ in
                self?.externalStatesUpdated()
            }
            self.fixState.nonPremiumFloodTriggeredUpdated = { [weak self] _ in
                self?.externalStatesUpdated()
            }
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        private func externalStatesUpdated() {
            guard let component = self.component else {
                return
            }
            
            switch self.currentMode {
            case .translate:
                component.externalState.isProcessing = self.translateState.isProcessing
                component.externalState.result = self.translateState.result?.text
            case .stylize:
                component.externalState.isProcessing = self.stylizeState.isProcessing
                component.externalState.result = self.stylizeState.result?.text
            case .fix:
                component.externalState.isProcessing = self.fixState.isProcessing
                component.externalState.result = self.fixState.result?.text
            }
            
            component.externalState.nonPremiumFloodTriggered = self.translateState.nonPremiumFloodTriggered || self.stylizeState.nonPremiumFloodTriggered || self.fixState.nonPremiumFloodTriggered
            
            /*#if DEBUG
            component.externalState.nonPremiumFloodTriggered = true
            #endif*/
        }
        
        private func saveState() {
            guard let component = self.component else {
                return
            }
            if case let .edit(saveRestoreStateId, _, _, _) = component.mode, let saveRestoreStateId {
                let mappedMode: Int32
                switch self.currentMode {
                case .translate:
                    mappedMode = 0
                case .stylize:
                    mappedMode = 1
                case .fix:
                    mappedMode = 2
                }
                
                let state = TextProcessingScreen.EditState(
                    selectedMode: mappedMode
                )
                let _ = component.context.engine.preferences.update(id: ApplicationSpecificPreferencesKeys.textProcessingEditingState(peerId: saveRestoreStateId), { _ in
                    return EnginePreferencesEntry(state)
                })
            }
        }

        func update(component: TextProcessingContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            
            if self.component == nil {
                self.stylizeState.displayStyleTooltip = component.shouldDisplayStyleNotice
                switch component.mode {
                case .edit:
                    self.currentMode = .stylize
                case .translate:
                    self.currentMode = .translate
                }
            }
            
            self.component = component
            self.environment = environment
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
                        title: environment.strings.TextProcessing_TabTranslate,
                        icon: .bundleIcon(name: "TextProcessing/TabTranslate")
                    )),
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        if self.currentMode != .translate {
                            self.currentMode = .translate
                            self.saveState()
                            self.externalStatesUpdated()
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
                        title: environment.strings.TextProcessing_TabStylize,
                        icon: .bundleIcon(name: "TextProcessing/TabStylize")
                    )),
                    action: { [weak self] _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        if self.currentMode != .stylize {
                            self.currentMode = .stylize
                            self.saveState()
                            let _ = ApplicationSpecificNotice.incrementAITextProcessingStyleSelection(accountManager: component.context.sharedContext.accountManager).startStandalone()
                            self.externalStatesUpdated()
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
                        title: environment.strings.TextProcessing_TabFix,
                        icon: .bundleIcon(name: "TextProcessing/TabFix")
                    )),
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        if self.currentMode != .fix {
                            self.currentMode = .fix
                            self.saveState()
                            self.externalStatesUpdated()
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
                    mode: .translate(ignoredLanguages: component.ignoredTranslationLanguages),
                    copyAction: component.copyCurrentResult,
                    displayLanguageSelectionMenu: component.displayLanguageSelectionMenu,
                    present: { [weak self] c, a in
                        self?.environment?.controller()?.present(c, in: .window(.root), with: a)
                    },
                    rootViewForTextSelection: { [weak self] in
                        return self?.environment?.controller()?.view
                    }
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
                    displayLanguageSelectionMenu: component.displayLanguageSelectionMenu,
                    present: { [weak self] c, a in
                        self?.environment?.controller()?.present(c, in: .window(.root), with: a)
                    },
                    rootViewForTextSelection: { [weak self] in
                        return self?.environment?.controller()?.view
                    }
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
                    displayLanguageSelectionMenu: component.displayLanguageSelectionMenu,
                    present: { [weak self] c, a in
                        self?.environment?.controller()?.present(c, in: .window(.root), with: a)
                    },
                    rootViewForTextSelection: { [weak self] in
                        return self?.environment?.controller()?.view
                    }
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
                                    string: environment.strings.Localization_TranslateEntireChat,
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
    let styles: [TextProcessingScreen.Style]
    let inputText: TextWithEntities
    let initialEditState: TextProcessingScreen.EditState?
    let shouldDisplayStyleNotice: Bool
    let copyCurrentResult: ((TextWithEntities) -> Void)?
    let translateChat: ((String) -> Void)?

    init(
        context: AccountContext,
        mode: TextProcessingScreen.Mode,
        ignoredTranslationLanguages: [String],
        styles: [TextProcessingScreen.Style],
        inputText: TextWithEntities,
        initialEditState: TextProcessingScreen.EditState?,
        shouldDisplayStyleNotice: Bool,
        copyCurrentResult: ((TextWithEntities) -> Void)?,
        translateChat: ((String) -> Void)?
    ) {
        self.context = context
        self.mode = mode
        self.ignoredTranslationLanguages = ignoredTranslationLanguages
        self.styles = styles
        self.inputText = inputText
        self.initialEditState = initialEditState
        self.shouldDisplayStyleNotice = shouldDisplayStyleNotice
        self.copyCurrentResult = copyCurrentResult
        self.translateChat = translateChat
    }

    static func ==(lhs: TextProcessingSheetComponent, rhs: TextProcessingSheetComponent) -> Bool {
        return true
    }

    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, ResizableSheetComponentEnvironment)>()
        private var toast: ComponentView<Empty>?
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
        
        private func displayLongPressSendMenu(sourceSendButton: UIView) {
            Task { @MainActor [weak self, weak sourceSendButton] in
                guard let self, let sourceSendButton, let component = self.component, case let .edit(_, _, _, sendContextActions) = component.mode, let sendContextActions else {
                    return
                }
                guard let controller = self.environment?.controller() else {
                    return
                }
                let peerId = sendContextActions.peerId
                let previousSupportedOrientations = controller.supportedOrientations
                
                let availableMessageEffects = await (component.context.availableMessageEffects |> take(1)).get()
                let hasPremium = await (component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: component.context.account.peerId))
                |> map { peer -> Bool in
                    guard case let .user(user) = peer else {
                        return false
                    }
                    return user.isPremium
                }).get()
                
                let peerStatus = await (component.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Presence(id: peerId)
                )).get()
                guard let peer = await (component.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                )).get() else {
                    return
                }
                
                let initialData = await ChatSendMessageContextScreen.initialData(context: component.context, currentMessageEffectId: nil).get()
                
                var sendWhenOnlineAvailable = false
                if let peerStatus, case let .present(until) = peerStatus.status {
                    let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                    if currentTime > until {
                        sendWhenOnlineAvailable = true
                    }
                }
                if peerId.namespace == Namespaces.Peer.CloudUser && peerId.id._internalGetInt64Value() == 777000 {
                    sendWhenOnlineAvailable = false
                }
                
                let messageActionsController = makeChatSendMessageActionSheetController(
                    initialData: initialData,
                    context: component.context,
                    updatedPresentationData: nil,
                    peerId: peerId,
                    params: .sendMessage(SendMessageActionSheetControllerParams.SendMessage(
                        isScheduledMessages: false,
                        mediaPreview: nil,
                        mediaCaptionIsAbove: nil,
                        messageEffect: (nil, { [weak self] updatedEffect in
                            guard let self else {
                                return
                            }
                            let _ = self
                            let _ = updatedEffect
                        }),
                        attachment: false,
                        canSendWhenOnline: sendWhenOnlineAvailable,
                        forwardMessageIds: [],
                        canMakePaidContent: false,
                        currentPrice: nil,
                        hasTimers: false,
                        sendPaidMessageStars: nil,
                        isMonoforum: peer._asPeer().isMonoForum
                    )),
                    hasEntityKeyboard: false,
                    gesture: nil,
                    sourceSendButton: sourceSendButton,
                    textInputView: UITextView(),
                    emojiViewProvider: nil,
                    completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.environment?.controller()?.supportedOrientations = previousSupportedOrientations
                    },
                    sendMessage: { [weak self] mode, parameters in
                        guard let self, let result = self.contentExternalState.result else {
                            return
                        }
                        sendContextActions.send(result, mode, parameters)
                        let controller = self.environment?.controller
                        self.animateOut.invoke(Action { _ in
                            if let controller = controller?() {
                                controller.dismiss(completion: nil)
                            }
                        })
                    },
                    schedule: { [weak self] params in
                        guard let self, let result = self.contentExternalState.result else {
                            return
                        }
                        sendContextActions.schedule(result, params)
                        let controller = self.environment?.controller
                        self.animateOut.invoke(Action { _ in
                            if let controller = controller?() {
                                controller.dismiss(completion: nil)
                            }
                        })
                    }, editPrice: { _ in
                    }, openPremiumPaywall: { [weak self] c in
                        guard let self else {
                            return
                        }
                        self.environment?.controller()?.push(c)
                    },
                    reactionItems: nil,
                    availableMessageEffects: availableMessageEffects,
                    isPremium: hasPremium
                )
                controller.present(messageActionsController, in: .window(.root))
            }
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
            var hasLongPressActions = false
            let isMainActionEnabled: Bool
            let actionButtonTitle: String
            var actionButtonShowsIncreaseLimit = false
            
            if self.contentExternalState.nonPremiumFloodTriggered {
                isMainActionEnabled = true
                actionButtonTitle = environmentValue.strings.TextProcessing_ActionTitleNonPremium
                actionButtonShowsIncreaseLimit = true
                performMainAction = { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    
                    let context = component.context
                    var replaceImpl: ((ViewController) -> Void)?
                    let controller = component.context.sharedContext.makePremiumDemoController(context: component.context, subject: .aiTools, forceDark: false, action: {
                        let controller = component.context.sharedContext.makePremiumIntroController(context: context, source: .aiTools, forceDark: false, dismissed: nil)
                        replaceImpl?(controller)
                    }, dismissed: nil)
                    replaceImpl = { [weak controller] c in
                        controller?.replace(with: c)
                    }
                    self.environment?.controller()?.push(controller)
                }
            } else {
                switch component.mode {
                case let .edit(_, completion, send, sendContextActions):
                    actionButtonTitle = environmentValue.strings.TextProcessing_ActionApply
                    performSendAction = send
                    isMainActionEnabled = !self.contentExternalState.isProcessing
                    hasLongPressActions = sendContextActions != nil
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
                    actionButtonTitle = environmentValue.strings.TextProcessing_ActionClose
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
                titleString = environmentValue.strings.TextProcessing_TitleEdit
            case .translate:
                titleString = environmentValue.strings.TextProcessing_TitleTranslate
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
                        initialEditState: component.initialEditState,
                        ignoredTranslationLanguages: component.ignoredTranslationLanguages,
                        shouldDisplayStyleNotice: component.shouldDisplayStyleNotice,
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
                            strings: environmentValue.strings,
                            actionTitle: actionButtonTitle,
                            actionButtonShowsIncreaseLimit: actionButtonShowsIncreaseLimit,
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
                            },
                            longPressSendAction: (performSendAction != nil && hasLongPressActions) ? { [weak self] sourceView in
                                guard let self else {
                                    return
                                }
                                self.displayLongPressSendMenu(sourceSendButton: sourceView)
                            } : nil
                        )
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
            
            if self.contentExternalState.nonPremiumFloodTriggered {
                let sideInset: CGFloat = 8.0
                
                let toast: ComponentView<Empty>
                var toastTransition = transition
                if let current = self.toast {
                    toast = current
                } else {
                    toastTransition = toastTransition.withAnimation(.none)
                    toast = ComponentView()
                    self.toast = toast
                }
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let playOnce = ActionSlot<Void>()
                let toastSize = toast.update(
                    transition: toastTransition,
                    component: AnyComponent(ToastContentComponent(
                        icon: AnyComponent(LottieComponent(
                            content: LottieComponent.AppBundleContent(name: "PremiumStar"),
                            startingPosition: .begin,
                            size: CGSize(width: 32.0, height: 32.0),
                            playOnce: playOnce
                        )),
                        content: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(string: environmentValue.strings.TextProcessing_LimitToast_Title, font: Font.semibold(14.0), textColor: .white)),
                            ))),
                            AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                                text: .markdown(text: environmentValue.strings.TextProcessing_LimitToast_Text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in nil })),
                                maximumNumberOfLines: 0
                            )))
                        ], alignment: .left, spacing: 6.0)),
                        insets: UIEdgeInsets(top: 10.0, left: 12.0, bottom: 10.0, right: 10.0),
                        iconSpacing: 12.0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
                )
                if let toastView = toast.view {
                    if toastView.superview == nil, let sheetView = self.sheet.view as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
                        sheetView.containerView.addSubview(toastView)
                        if !transition.animation.isImmediate {
                            toastView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        }
                        
                        if let toastView = toastView as? ToastContentComponent.View, let iconView = toastView.iconView as? LottieComponent.View {
                            iconView.playOnce()
                        }
                    }
                    toastTransition.setFrame(view: toastView, frame: CGRect(origin: CGPoint(x: sideInset, y: availableSize.height - 94.0 - toastSize.height), size: toastSize))
                }
            } else {
                if let toast = self.toast {
                    self.toast = nil
                    if let toastView = toast.view {
                        toastView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak toastView] _ in
                            toastView?.removeFromSuperview()
                        })
                    }
                }
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
                        context: component.context,
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
    public typealias SendContextActions = TextProcessingScreenSendContextActions
    
    public typealias Mode = TextProcessingScreenMode
    
    struct EditState: Codable {
        var selectedMode: Int32
        
        init(selectedMode: Int32) {
            self.selectedMode = selectedMode
        }
    }
    
    public struct Style: Equatable {
        public let type: String
        public let title: String
        public let emojiFileId: Int64?
        public let emojiFile: TelegramMediaFile?
        
        public var id: TelegramComposeAIMessageMode.StyleId {
            return .style(self.type)
        }
        
        public init(type: String, title: String, emojiFileId: Int64?, emojiFile: TelegramMediaFile?) {
            self.type = type
            self.title = title
            self.emojiFileId = emojiFileId
            self.emojiFile = emojiFile
        }
    }
    
    private let context: AccountContext

    public init(
        context: AccountContext,
        theme: PresentationTheme? = nil,
        mode: Mode,
        inputText: TextWithEntities,
        copyResult: ((TextWithEntities) -> Void)?,
        translateChat: ((String) -> Void)?
    ) async {
        self.context = context
        
        let rawStyles = await context.engine.messages.composeAIMessageStyles().get()
        var styles: [Style] = []
        let resolvedEmojiFiles: [Int64: TelegramMediaFile] = await context.engine.stickers.resolveInlineStickersLocal(fileIds: Array(Set(rawStyles.compactMap({ $0.emojiFileId })))).get()
        for value in rawStyles {
            styles.append(Style(
                type: value.type,
                title: value.title,
                emojiFileId: value.emojiFileId,
                emojiFile: value.emojiFileId.flatMap { resolvedEmojiFiles[$0] }
            ))
        }
        
        let shouldDisplayStyleNotice = await ApplicationSpecificNotice.getAITextProcessingStyleSelection(accountManager: context.sharedContext.accountManager).get() < 3
        
        var initialEditState: EditState?
        if case let .edit(saveRestoreStateId, _, _, _) = mode, let saveRestoreStateId {
            initialEditState = await context.engine.data.get(
                TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ApplicationSpecificPreferencesKeys.textProcessingEditingState(peerId: saveRestoreStateId))
            ).get()?.get(EditState.self)
        }
        
        let sharedDataEntries = await context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings]).get()
        let translationSettings: TranslationSettings
        if let value = sharedDataEntries.entries[ApplicationSpecificSharedDataKeys.translationSettings], let parsedValue = value.get(TranslationSettings.self) {
            translationSettings = parsedValue
        } else {
            translationSettings = .defaultSettings
        }

        super.init(
            context: context,
            component: TextProcessingSheetComponent(
                context: context,
                mode: mode,
                ignoredTranslationLanguages: translationSettings.ignoredLanguages ?? [],
                styles: styles,
                inputText: inputText,
                initialEditState: initialEditState,
                shouldDisplayStyleNotice: shouldDisplayStyleNotice,
                copyCurrentResult: copyResult,
                translateChat: translateChat
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: theme.flatMap({ .custom($0) }) ?? .default
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
    let strings: PresentationStrings
    let actionTitle: String
    let actionButtonShowsIncreaseLimit: Bool
    let action: (() -> Void)?
    let sendAction: (() -> Void)?
    let longPressSendAction: ((UIView) -> Void)?
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        actionTitle: String,
        actionButtonShowsIncreaseLimit: Bool,
        action: (() -> Void)?,
        sendAction: (() -> Void)?,
        longPressSendAction: ((UIView) -> Void)?
    ) {
        self.theme = theme
        self.strings = strings
        self.actionTitle = actionTitle
        self.actionButtonShowsIncreaseLimit = actionButtonShowsIncreaseLimit
        self.action = action
        self.sendAction = sendAction
        self.longPressSendAction = longPressSendAction
    }
    
    static func ==(lhs: ActionButtonsComponent, rhs: ActionButtonsComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.actionTitle != rhs.actionTitle {
            return false
        }
        if lhs.actionButtonShowsIncreaseLimit != rhs.actionButtonShowsIncreaseLimit {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        if (lhs.sendAction == nil) != (rhs.sendAction == nil) {
            return false
        }
        if (lhs.longPressSendAction == nil) != (rhs.longPressSendAction == nil) {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let actionButton = ComponentView<Empty>()
        private let sendButton = ComponentView<Empty>()
        private let extractedContainerView = ContextExtractedContentContainingView()

        private var component: ActionButtonsComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.addSubview(self.extractedContainerView)
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
            
            var actionButtonContents: [AnyComponentWithIdentity<Empty>] = []
            actionButtonContents.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: component.actionTitle, font: Font.semibold(17.0), textColor: component.theme.list.itemCheckColors.foregroundColor))
            ))))
            if component.actionButtonShowsIncreaseLimit {
                actionButtonContents.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(IncreaseLimitBadgeComponent(
                    title: component.strings.TextProcessing_ActionValueNonPremium,
                    fillColor: component.theme.list.itemCheckColors.foregroundColor,
                    foregroundColor: .clear
                ))))
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
                        component: AnyComponent(HStack(
                            actionButtonContents,
                            spacing: 6.0
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
                    },
                    longPressAction: component.longPressSendAction == nil ? nil : { [weak self] in
                        guard let self else {
                            return
                        }
                        component.longPressSendAction?(self.extractedContainerView)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 52.0, height: 52.0)
            )
            let sendButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - sendButtonSize.width, y: 0.0), size: sendButtonSize)
            if let sendButtonView = self.sendButton.view {
                if sendButtonView.superview == nil {
                    self.extractedContainerView.contentView.addSubview(sendButtonView)
                }
                sendButtonView.frame = CGRect(origin: CGPoint(), size: sendButtonFrame.size)
            }
            transition.setPosition(view: self.extractedContainerView, position: sendButtonFrame.center)
            transition.setBounds(view: self.extractedContainerView, bounds: CGRect(origin: CGPoint(), size: sendButtonFrame.size))
            transition.setPosition(view: self.extractedContainerView.contentView, position: CGPoint(x: sendButtonFrame.width * 0.5, y: sendButtonFrame.height * 0.5))
            transition.setBounds(view: self.extractedContainerView.contentView, bounds: CGRect(origin: CGPoint(), size: sendButtonFrame.size))
            transition.setAlpha(view: self.extractedContainerView, alpha: component.sendAction != nil ? 1.0 : 0.0)
            transition.setScale(view: self.extractedContainerView, scale: component.sendAction != nil ? 1.0 : 0.001)

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

private final class IncreaseLimitBadgeComponent: Component {
    let title: String
    let fillColor: UIColor
    let foregroundColor: UIColor
    
    init(
        title: String,
        fillColor: UIColor,
        foregroundColor: UIColor
    ) {
        self.title = title
        self.fillColor = fillColor
        self.foregroundColor = foregroundColor
    }
    
    static func ==(lhs: IncreaseLimitBadgeComponent, rhs: IncreaseLimitBadgeComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.fillColor != rhs.fillColor {
            return false
        }
        if lhs.foregroundColor != rhs.foregroundColor {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let iconView: UIImageView
        
        private var component: IncreaseLimitBadgeComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            self.iconView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.iconView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: IncreaseLimitBadgeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let leftInset: CGFloat = 4.0
            let rightInset: CGFloat = 3.0
            let topInset: CGFloat = 1.0
            let bottomInset: CGFloat = 0.0
            
            let text = NSAttributedString(string: component.title, font: Font.with(size: 14.0, design: .round, weight: .semibold), textColor: .clear)
            let rawTextSize = text.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: [.usesLineFragmentOrigin], context: nil)
            let textSize = CGSize(width: ceil(rawTextSize.width), height: ceil(rawTextSize.height))
            let backgroundSize = CGSize(width: leftInset + rightInset + textSize.width, height: topInset + bottomInset + textSize.height)
            
            self.iconView.image = generateImage(backgroundSize, rotatedContext: { size, context in
                UIGraphicsPushContext(context)
                defer {
                    UIGraphicsPopContext()
                }
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(component.fillColor.cgColor)
                UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: 4.0).fill()
                
                if component.foregroundColor.alpha != 1.0 {
                    context.setBlendMode(.copy)
                }
                text.draw(at: CGPoint(x: leftInset, y: topInset))
            })
            self.iconView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: backgroundSize)

            return backgroundSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
