import Foundation
import LottieSettings
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
import ContextUI
import EmojiStatusComponent
import TextFieldComponent

final class TextProcessingContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    final class ExternalState {
        fileprivate(set) var isProcessing: Bool = false
        fileprivate(set) var nonPremiumFloodTriggered: Bool = false
        fileprivate(set) var result: ComposedRichMessage?
        fileprivate(set) var isPromptMode: Bool = false
        fileprivate(set) var promptText: String = ""
        
        fileprivate(set) var refreshResult: (() -> Void)?
        
        init() {
        }
    }

    let externalState: ExternalState
    let context: AccountContext
    let mode: TextProcessingScreen.Mode
    let previewIconFile: TelegramMediaFile?
    let styles: [TextProcessingScreen.Style]
    let inputText: ComposedRichMessage
    let initialEditState: TextProcessingScreen.EditState?
    let ignoredTranslationLanguages: [String]
    let shouldDisplayStyleNotice: Bool
    let appliedPromptText: String?
    let copyCurrentResult: (() -> Void)?
    let translateChat: ((String) -> Void)?
    let displayLanguageSelectionMenu: (UIView, String, TelegramComposeAIMessageMode.StyleId, Bool,  @escaping (String, TelegramComposeAIMessageMode.StyleReference) -> Void) -> Void
    let newStyleAdded: (TelegramComposeAIMessageMode.CloudStyle) -> Void
    let styleUpdated: (TelegramComposeAIMessageMode.CloudStyle) -> Void
    let styleDeleted: (TelegramComposeAIMessageMode.StyleId) -> Void
    let displayToast: (String) -> Void
    let dismiss: (@escaping () -> Void) -> Void

    init(
        externalState: ExternalState,
        context: AccountContext,
        mode: TextProcessingScreen.Mode,
        previewIconFile: TelegramMediaFile?,
        styles: [TextProcessingScreen.Style],
        inputText: ComposedRichMessage,
        initialEditState: TextProcessingScreen.EditState?,
        ignoredTranslationLanguages: [String],
        shouldDisplayStyleNotice: Bool,
        appliedPromptText: String?,
        copyCurrentResult: (() -> Void)?,
        translateChat: ((String) -> Void)?,
        displayLanguageSelectionMenu: @escaping (UIView, String, TelegramComposeAIMessageMode.StyleId, Bool, @escaping (String, TelegramComposeAIMessageMode.StyleReference) -> Void) -> Void,
        newStyleAdded: @escaping (TelegramComposeAIMessageMode.CloudStyle) -> Void,
        styleUpdated: @escaping (TelegramComposeAIMessageMode.CloudStyle) -> Void,
        styleDeleted: @escaping (TelegramComposeAIMessageMode.StyleId) -> Void,
        displayToast: @escaping (String) -> Void,
        dismiss: @escaping (@escaping () -> Void) -> Void
    ) {
        self.externalState = externalState
        self.styles = styles
        self.context = context
        self.mode = mode
        self.previewIconFile = previewIconFile
        self.inputText = inputText
        self.initialEditState = initialEditState
        self.ignoredTranslationLanguages = ignoredTranslationLanguages
        self.shouldDisplayStyleNotice = shouldDisplayStyleNotice
        self.appliedPromptText = appliedPromptText
        self.copyCurrentResult = copyCurrentResult
        self.translateChat = translateChat
        self.displayLanguageSelectionMenu = displayLanguageSelectionMenu
        self.newStyleAdded = newStyleAdded
        self.styleUpdated = styleUpdated
        self.styleDeleted = styleDeleted
        self.displayToast = displayToast
        self.dismiss = dismiss
    }

    static func ==(lhs: TextProcessingContentComponent, rhs: TextProcessingContentComponent) -> Bool {
        if lhs.styles != rhs.styles {
            return false
        }
        if lhs.appliedPromptText != rhs.appliedPromptText {
            return false
        }
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
        private var previousEnvironment: ViewControllerComponentContainer.Environment?

        private let modeTabs = ComponentView<Empty>()
        private let actionsSection = ComponentView<Empty>()
        
        private var previewIcon: ComponentView<Empty>?
        private var previewTitle: ComponentView<Empty>?
        private var previewDescription: ComponentView<Empty>?
        
        private let currentContentBackground = ComponentView<Empty>()
        private let currentContentContainer: UIView
        private var currentContentHeader: (id: AnyHashable, view: ComponentView<Empty>)?
        private var currentContentFooter: (id: AnyHashable, view: ComponentView<Empty>)?
        
        private let translateState = TextProcessingTranslateContentComponent.ExternalState()
        private let stylizeState = TextProcessingTranslateContentComponent.ExternalState()
        private let fixState = TextProcessingTranslateContentComponent.ExternalState()
        
        private var currentContent: (mode: Mode, view: ComponentView<Empty>)?
        
        private var currentMode: Mode = .translate
        
        private var isRequestingStylePreview: Bool = false
        private var currentStylePreview: AIMessageStylePreview?
        private var currentStylePreviewDisposable: Disposable?
        
        override init(frame: CGRect) {
            self.currentContentContainer = UIView()
            self.currentContentContainer.clipsToBounds = true
            
            super.init(frame: frame)
            
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
            self.stylizeState.promptTextUpdated = { [weak self] in
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
        
        deinit {
            self.currentStylePreviewDisposable?.dispose()
        }
        
        private func externalStatesUpdated() {
            guard let component = self.component else {
                return
            }
            
            switch self.currentMode {
            case .translate:
                component.externalState.isProcessing = self.translateState.isProcessing
                component.externalState.result = self.translateState.result?.text
                component.externalState.isPromptMode = false
                component.externalState.promptText = ""
            case .stylize:
                component.externalState.isProcessing = self.stylizeState.isProcessing
                component.externalState.result = self.stylizeState.result?.text
                if case .prompt = self.stylizeState.style {
                    component.externalState.isPromptMode = true
                } else {
                    component.externalState.isPromptMode = false
                }
                component.externalState.promptText = self.stylizeState.promptText
            case .fix:
                component.externalState.isProcessing = self.fixState.isProcessing
                component.externalState.result = self.fixState.result?.text
                component.externalState.isPromptMode = false
                component.externalState.promptText = ""
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
        
        private func requestShareStyle(id: TelegramComposeAIMessageMode.StyleReference) {
            guard let component = self.component else {
                return
            }
            guard let style = component.styles.first(where: { .style($0.reference.id) == id.id }) else {
                return
            }
            guard let slug = style.slug else {
                return
            }
            let shareController = component.context.sharedContext.makeShareController(context: component.context, params: ShareControllerParams(
                subject: .url("https://t.me/addstyle/\(slug)"),
                completed: { [weak self] peerIds in
                    Task { @MainActor in
                        guard let self, let component = self.component, let environment = self.environment, let peerId = peerIds.first else {
                            return
                        }
                        let text: String
                        if peerId == component.context.account.peerId {
                            text = environment.strings.WebBrowser_LinkForwardTooltip_SavedMessages_One
                        } else {
                            guard let peer = await component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)).get() else {
                                return
                            }
                            text = environment.strings.Conversation_ShareLinkTooltip_Chat_One(peer.displayTitle(strings: environment.strings, displayOrder: .firstLast).replacingOccurrences(of: "*", with: "")).string
                        }
                        component.displayToast(text)
                    }
                }
            ))
            self.environment?.controller()?.present(shareController, in: .window(.root))
        }
        
        private func requestEditStyle(id: TelegramComposeAIMessageMode.StyleReference) {
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                guard let component = self.component, let environment = self.environment else {
                    return
                }
                guard let style = component.styles.first(where: { .style($0.reference.id) == id.id }) else {
                    return
                }
                environment.controller()?.push(await TextStyleEditScreen(
                    context: component.context,
                    mode: .edit(style.cloudStyle),
                    completion: { [weak self] style in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.styleUpdated(style)
                    },
                    styleDeleted: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.styleDeleted(style.id.id)
                    }
                ))
            }
        }
        
        private func requestDeleteStyle(id: TelegramComposeAIMessageMode.StyleReference) {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            guard let style = component.styles.first(where: { .style($0.reference.id) == id.id }) else {
                return
            }
            guard case let .custom(style) = style.cloudStyle.content else {
                return
            }
            
            if style.isCreator {
                environment.controller()?.push(textAlertController(
                    context: component.context,
                    title: environment.strings.TextProcessing_AlertCreatorDeleteStyle_Title,
                    text: environment.strings.TextProcessing_AlertCreatorDeleteStyle_Text,
                    actions: [
                        TextAlertAction(type: .genericAction, title: environment.strings.Common_Cancel, action: {}),
                        TextAlertAction(type: .destructiveAction, title: environment.strings.Common_Delete, action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            let _ = component.context.engine.messages.deleteAITextStyle(id: style.id, accessHash: style.accessHash).startStandalone()
                            component.styleDeleted(id.id)
                        }),
                    ]
                ))
            } else {
                environment.controller()?.push(textAlertController(
                    context: component.context,
                    title: environment.strings.TextProcessing_AlertDeleteStyle_Title,
                    text: environment.strings.TextProcessing_AlertDeleteStyle_Text,
                    actions: [
                        TextAlertAction(type: .genericAction, title: environment.strings.Common_Cancel, action: {}),
                        TextAlertAction(type: .destructiveAction, title: environment.strings.Common_Delete, action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            let _ = component.context.engine.messages.unsaveAITextStyle(id: style.id, accessHash: style.accessHash).startStandalone()
                            component.styleDeleted(id.id)
                        }),
                    ]
                ))
            }
        }
        
        private func openStyleContextMenu(id: TelegramComposeAIMessageMode.StyleReference, gesture:  ContextGesture, sourceView: ContextExtractedContentContainingView) {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            
            guard let style = component.styles.first(where: { .style($0.reference.id) == id.id }) else {
                return
            }
            
            var items: [ContextMenuItem] = []
            if style.isAuthor {
                items.append(.action(ContextMenuActionItem(
                    text: environment.strings.TextProcessing_StyleMenu_Edit,
                    icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor)
                    },
                    action: { [weak self] c, _ in
                        c?.dismiss(completion: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.requestEditStyle(id: id)
                        })
                    })
                ))
            }
            items.append(.action(ContextMenuActionItem(
                text: environment.strings.TextProcessing_StyleMenu_Share,
                icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
                },
                action: { [weak self] c, _ in
                    c?.dismiss(completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.requestShareStyle(id: id)
                    })
                })
            ))
            items.append(.action(ContextMenuActionItem(
                text: environment.strings.TextProcessing_StyleMenu_Delete,
                textColor: .destructive,
                icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                },
                action: { [weak self] c, _ in
                    c?.dismiss(completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.requestDeleteStyle(id: id)
                    })
                })
            ))
            
            final class ContextExtractedContentSourceImpl: ContextExtractedContentSource {
                let keepInPlace: Bool = false
                let ignoreContentTouches: Bool = false
                let blurBackground: Bool = false
                let actionsHorizontalAlignment: ContextActionsHorizontalAlignment = .center
                
                private let contentView: ContextExtractedContentContainingView
                
                init(contentView: ContextExtractedContentContainingView) {
                    self.contentView = contentView
                }
                
                func takeView() -> ContextControllerTakeViewInfo? {
                    return ContextControllerTakeViewInfo(containingItem: .view(self.contentView), contentAreaInScreenSpace: UIScreen.main.bounds)
                }
                
                func putBack() -> ContextControllerPutBackViewInfo? {
                    return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
                }
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
            let controller = makeContextController(
                presentationData: presentationData,
                source: .extracted(ContextExtractedContentSourceImpl(contentView: sourceView)), items: .single(ContextController.Items(content: .list(items))), recognizer: nil, gesture: gesture
            )
            environment.controller()?.presentInGlobalOverlay(controller)
        }
        
        private func requestStylePreview() {
            guard let component = self.component else {
                return
            }
            guard case let .preview(style, _, _, _, _) = component.mode else {
                return
            }
            
            var index = 0
            if let currentStylePreview = self.currentStylePreview, let currentIndex = currentStylePreview.index {
                var maxPreviewCount = 3
                if let data = component.context.currentAppConfiguration.with({ $0 }).data, let value = data["aicompose_tone_examples_num"] as? Double {
                    maxPreviewCount = max(1, Int(value))
                }
                index = (currentIndex + 1) % maxPreviewCount
            }
            
            self.isRequestingStylePreview = true
            if !self.isUpdating {
                self.state?.updated(transition: .spring(duration: 0.4))
            }
            
            self.currentStylePreviewDisposable?.dispose()
            self.currentStylePreviewDisposable = (component.context.engine.messages.requestAIMessageStylePreview(reference: TelegramComposeAIMessageMode.CloudStyle(content: .custom(style)).reference, index: index) |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                guard let self, let result else {
                    return
                }
                self.isRequestingStylePreview = false
                self.currentStylePreview = result
                if !self.isUpdating {
                    self.state?.updated(transition: .spring(duration: 0.4))
                }
            })
        }

        private func firstResponderTextFieldView(in view: UIView) -> TextFieldComponent.View? {
            if let candidate = view as? TextFieldComponent.View, candidate.inputTextView.isFirstResponder {
                return candidate
            }
            for subview in view.subviews {
                if let found = self.firstResponderTextFieldView(in: subview) {
                    return found
                }
            }
            return nil
        }

        private func recenterCaret(hintView: UIView, transition: ComponentTransition) {
            var fieldView: TextFieldComponent.View?
            var ancestor: UIView? = hintView
            while let current = ancestor {
                if let candidate = current as? TextFieldComponent.View {
                    fieldView = candidate
                    break
                }
                ancestor = current.superview
            }
            guard let fieldView else {
                return
            }
            let inputTextView = fieldView.inputTextView
            let caretPosition = inputTextView.selectedTextRange?.end ?? inputTextView.endOfDocument
            let caretRect = inputTextView.caretRect(for: caretPosition)
            if caretRect.isNull || caretRect.isInfinite {
                return
            }

            var scrollAncestor: UIView? = self.superview
            var scrollView: UIScrollView?
            while let current = scrollAncestor {
                if let candidate = current as? UIScrollView {
                    scrollView = candidate
                    break
                }
                scrollAncestor = current.superview
            }
            guard let scrollView, let environment = self.environment else {
                return
            }

            let caretInScroll = inputTextView.convert(caretRect, to: scrollView)

            // ResizableSheetComponent bottom action button (52pt) + gap above it (8pt).
            let bottomActionAreaHeight: CGFloat = 60.0
            let caretTopInset: CGFloat = 24.0
            let caretBottomInset: CGFloat = 24.0
            let visibleTop = scrollView.bounds.minY + caretTopInset
            let visibleBottom = scrollView.bounds.maxY - environment.inputHeight - bottomActionAreaHeight - caretBottomInset

            let previousBounds = scrollView.bounds
            var newBounds = previousBounds
            if caretInScroll.maxY > visibleBottom {
                newBounds.origin.y += (caretInScroll.maxY - visibleBottom)
            } else if caretInScroll.minY < visibleTop {
                newBounds.origin.y -= (visibleTop - caretInScroll.minY)
            }
            let maxOriginY = max(0.0, scrollView.contentSize.height - scrollView.bounds.height)
            newBounds.origin.y = min(max(0.0, newBounds.origin.y), maxOriginY)

            if newBounds != previousBounds {
                scrollView.bounds = newBounds
                if !transition.animation.isImmediate {
                    let offsetY = previousBounds.origin.y - newBounds.origin.y
                    transition.animateBoundsOrigin(view: scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                }
            }
        }

        func update(component: TextProcessingContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let theme = environment.theme.withModalBlocksBackground()
            
            let isFirstTime = self.component == nil

            let previousEnvironment = self.previousEnvironment
            self.previousEnvironment = environment

            self.component = component
            self.environment = environment
            self.state = state
            
            if isFirstTime {
                self.stylizeState.displayStyleTooltip = component.shouldDisplayStyleNotice
                switch component.mode {
                case .edit, .generate:
                    self.currentMode = .stylize
                case let .preview(_, _, initialPreview, _, _):
                    self.currentMode = .stylize
                    self.currentStylePreview = initialPreview
                    self.requestStylePreview()
                case .translate:
                    self.currentMode = .translate
                }
            }
            
            let sideInset: CGFloat = 16.0

            var contentHeight: CGFloat = 0.0
            
            if case let .preview(style, _, _, _, _) = component.mode {
                contentHeight += 40.0
                if let previewIconFile = component.previewIconFile {
                    let previewIcon: ComponentView<Empty>
                    if let current = self.previewIcon {
                        previewIcon = current
                    } else {
                        previewIcon = ComponentView()
                        self.previewIcon = previewIcon
                    }
                    let previewIconSize = CGSize(width: 60.0, height: 60.0)
                    let _ = previewIcon.update(
                        transition: transition,
                        component: AnyComponent(EmojiStatusComponent(
                            context: component.context,
                            animationCache: component.context.animationCache,
                            animationRenderer: component.context.animationRenderer,
                            content: .animation(
                                content: .file(file: previewIconFile),
                                size: previewIconSize,
                                placeholderColor: theme.list.mediaPlaceholderColor,
                                themeColor: theme.list.itemPrimaryTextColor,
                                loopMode: .count(1)
                            ),
                            isVisibleForAnimations: true,
                            action: nil
                        )),
                        environment: {},
                        containerSize: previewIconSize
                    )
                    let previewIconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - previewIconSize.width) * 0.5), y: contentHeight), size: previewIconSize)
                    if let previewIconView = previewIcon.view {
                        if previewIconView.superview == nil {
                            self.addSubview(previewIconView)
                            previewIconView.isUserInteractionEnabled = false
                        }
                        transition.setFrame(view: previewIconView, frame: previewIconFrame)
                    }
                    contentHeight += previewIconSize.height
                    contentHeight += 10.0
                }
                
                let previewTitle: ComponentView<Empty>
                if let current = self.previewTitle {
                    previewTitle = current
                } else {
                    previewTitle = ComponentView()
                    self.previewTitle = previewTitle
                }
                
                let previewDescription: ComponentView<Empty>
                if let current = self.previewDescription {
                    previewDescription = current
                } else {
                    previewDescription = ComponentView()
                    self.previewDescription = previewDescription
                }
                
                let titleSize = previewTitle.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: style.title, font: Font.bold(30.0), textColor: theme.list.itemPrimaryTextColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: 100.0)
                )
                let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: contentHeight), size: titleSize)
                if let previewTitleView = previewTitle.view {
                    if previewTitleView.superview == nil {
                        previewTitleView.isUserInteractionEnabled = false
                        self.addSubview(previewTitleView)
                    }
                    transition.setPosition(view: previewTitleView, position: titleFrame.center)
                    previewTitleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                }
                contentHeight += titleSize.height + 5.0
                
                let descriptionSize = previewDescription.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: environment.strings.TextProcessing_StylePreview_Subtitle, font: Font.regular(15.0), textColor: theme.list.itemPrimaryTextColor)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.12
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: 100.0)
                )
                let descriptionFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - descriptionSize.width) * 0.5), y: contentHeight), size: descriptionSize)
                if let previewDescriptionView = previewDescription.view {
                    if previewDescriptionView.superview == nil {
                        previewDescriptionView.isUserInteractionEnabled = false
                        self.addSubview(previewDescriptionView)
                    }
                    transition.setPosition(view: previewDescriptionView, position: descriptionFrame.center)
                    previewDescriptionView.bounds = CGRect(origin: CGPoint(), size: descriptionFrame.size)
                }
                contentHeight += descriptionSize.height
                contentHeight += 30.0
            } else {
                contentHeight += 82.0
            }
            
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
                        theme: theme,
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
            case .generate:
                break
            case .translate, .preview:
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
            
            let contentExternalState: TextProcessingTranslateContentComponent.ExternalState
            let contentComponent: AnyComponent<Empty>
            switch self.currentMode {
            case .translate:
                contentExternalState = self.translateState
                contentComponent = AnyComponent(TextProcessingTranslateContentComponent(
                    context: component.context,
                    theme: theme,
                    strings: environment.strings,
                    styles: component.styles,
                    externalState: self.translateState,
                    inputText: component.inputText,
                    mode: .translate(ignoredLanguages: component.ignoredTranslationLanguages),
                    appliedPrompt: nil,
                    copyAction: component.copyCurrentResult,
                    displayLanguageSelectionMenu: component.displayLanguageSelectionMenu,
                    createStyle: {
                    },
                    openStyleContextMenu: { _, _, _ in
                    },
                    present: { [weak self] c, a in
                        self?.environment?.controller()?.present(c, in: .window(.root), with: a)
                    },
                    rootViewForTextSelection: { [weak self] in
                        return self?.environment?.controller()?.view
                    },
                    openPeer: { _ in
                    },
                    requestAnotherPreviewExample: {
                    }
                ))
            case .stylize:
                var inputText = component.inputText
                var isPreview = false
                var fromText: ComposedRichMessage?
                var toText: ComposedRichMessage?
                var isRequestingPreview: Bool = false
                var authorPeer: EnginePeer?
                var userCount: Int = 0
                if case let .preview(style, authorPeerValue, _, _, _) = component.mode {
                    isPreview = true
                    inputText = .plain(text: "", entities: [])
                    authorPeer = authorPeerValue
                    userCount = style.userCount ?? 0
                    isRequestingPreview = self.isRequestingStylePreview
                    if let currentStylePreview = self.currentStylePreview {
                        fromText = currentStylePreview.from
                        toText = currentStylePreview.to
                    }
                }
                
                let mappedMode: TextProcessingTranslateContentComponent.Mode
                var mappedAppliedPrompt: String?
                if isPreview {
                    mappedMode = .preview(from: fromText, to: toText, authorPeer: authorPeer, userCount: userCount, isRequesting: isRequestingPreview)
                } else {
                    mappedAppliedPrompt = component.appliedPromptText
                    if case .generate = component.mode {
                        mappedMode = .stylize(isComposeWithAI: true)
                    } else {
                        mappedMode = .stylize(isComposeWithAI: false)
                    }
                }
                
                contentExternalState = self.stylizeState
                contentComponent = AnyComponent(TextProcessingTranslateContentComponent(
                    context: component.context,
                    theme: theme,
                    strings: environment.strings,
                    styles: component.styles,
                    externalState: self.stylizeState,
                    inputText: inputText,
                    mode: mappedMode,
                    appliedPrompt: mappedAppliedPrompt,
                    copyAction: component.copyCurrentResult,
                    displayLanguageSelectionMenu: component.displayLanguageSelectionMenu,
                    createStyle: { [weak self] in
                        Task { @MainActor in
                            guard let self else {
                                return
                            }
                            guard let component = self.component, let environment = self.environment else {
                                return
                            }
                            
                            let hasPremium = await (component.context.engine.data.get(
                                TelegramEngine.EngineData.Item.Peer.Peer(id: component.context.account.peerId)
                            )
                            |> map { peer -> Bool in
                                guard case let .user(user) = peer else {
                                    return false
                                }
                                return user.isPremium
                            }).get()
                            let userLimits = await component.context.engine.data.get(
                                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: hasPremium)
                            ).get()
                            
                            let maxStyles = Int(userLimits.maxOwnedAITextStyles)
                                                        
                            if component.styles.filter({ $0.isAuthor }).count >= maxStyles {
                                if !hasPremium {
                                    let context = component.context
                                    var replaceImpl: ((ViewController) -> Void)?
                                    let controller = context.sharedContext.makePremiumDemoController(context: context, subject: .aiTools, forceDark: false, action: {
                                        let controller = context.sharedContext.makePremiumIntroController(context: context, source: .storiesStealthMode, forceDark: false, dismissed: nil)
                                        replaceImpl?(controller)
                                    }, dismissed: nil)
                                    replaceImpl = { [weak self, weak controller] c in
                                        controller?.dismiss(animated: true, completion: {
                                            guard let self else {
                                                return
                                            }
                                            self.environment?.controller()?.push(c)
                                        })
                                    }
                                    environment.controller()?.push(controller)
                                } else {
                                    environment.controller()?.push(textAlertController(
                                        context: component.context,
                                        title: environment.strings.TextProcessing_AlertTooManyStyles_Title,
                                        text: environment.strings.TextProcessing_AlertTooManyStyles_Text,
                                        actions: [
                                            TextAlertAction(type: .defaultAction, title: environment.strings.Common_OK, action: {}),
                                        ]
                                    ))
                                }
                                return
                            }
                            
                            environment.controller()?.push(await TextStyleEditScreen(
                                context: component.context,
                                mode: .create,
                                completion: { [weak self] style in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    
                                    if let contentComponentView = self.currentContent?.view.view as? TextProcessingTranslateContentComponent.View {
                                        contentComponentView.scrollStylesToStart()
                                    }
                                    
                                    component.newStyleAdded(style)
                                },
                                styleDeleted: {
                                }
                            ))
                        }
                    },
                    openStyleContextMenu: { [weak self] styleId, gesture, sourceView in
                        guard let self else {
                            return
                        }
                        self.openStyleContextMenu(id: styleId, gesture: gesture, sourceView: sourceView)
                    },
                    present: { [weak self] c, a in
                        self?.environment?.controller()?.present(c, in: .window(.root), with: a)
                    },
                    rootViewForTextSelection: { [weak self] in
                        return self?.environment?.controller()?.view
                    },
                    openPeer: { [weak self] peer in
                        guard let self, let component = self.component, let environment = self.environment else {
                            return
                        }
                        guard let navigationController = environment.controller()?.navigationController as? NavigationController else {
                            return
                        }
                        let context = component.context
                        component.dismiss({ [weak context, weak navigationController] in
                            guard let context, let navigationController else {
                                return
                            }
                            if let peerInfoController = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                                navigationController.pushViewController(peerInfoController)
                            }
                        })
                    },
                    requestAnotherPreviewExample: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.requestStylePreview()
                    }
                ))
            case .fix:
                contentExternalState = self.fixState
                contentComponent = AnyComponent(TextProcessingTranslateContentComponent(
                    context: component.context,
                    theme: theme,
                    strings: environment.strings,
                    styles: component.styles,
                    externalState: self.fixState,
                    inputText: component.inputText,
                    mode: .fix,
                    appliedPrompt: nil,
                    copyAction: component.copyCurrentResult,
                    displayLanguageSelectionMenu: component.displayLanguageSelectionMenu,
                    createStyle: {
                    },
                    openStyleContextMenu: { _, _, _ in
                    },
                    present: { [weak self] c, a in
                        self?.environment?.controller()?.present(c, in: .window(.root), with: a)
                    },
                    rootViewForTextSelection: { [weak self] in
                        return self?.environment?.controller()?.view
                    },
                    openPeer: { _ in
                    },
                    requestAnotherPreviewExample: {
                    }
                ))
            }
            
            if let sectionHeader = contentExternalState.sectionHeader {
                let headerView: ComponentView<Empty>
                var headerTransition = transition
                if let current = self.currentContentHeader, current.id == sectionHeader.id {
                    headerView = current.view
                } else {
                    headerTransition = headerTransition.withAnimation(.none)
                    
                    if let currentContentHeader = self.currentContentHeader {
                        self.currentContentHeader = nil
                        if let componentView = currentContentHeader.view.view {
                            alphaTransition.setAlpha(view: componentView, alpha: 0.0, completion: { [weak componentView] _ in
                                componentView?.removeFromSuperview()
                            })
                        }
                    }
                    
                    headerView = ComponentView()
                    self.currentContentHeader = (sectionHeader.id, headerView)
                }
                let headerSideInset: CGFloat = sideInset + 16.0
                let headerSize = headerView.update(
                    transition: .immediate,
                    component: sectionHeader.component,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - headerSideInset * 2.0, height: 10000.0)
                )
                let headerFrame = CGRect(origin: CGPoint(x: headerSideInset, y: contentHeight), size: headerSize)
                if let headerComponentView = headerView.view {
                    if headerComponentView.superview == nil {
                        headerComponentView.layer.anchorPoint = CGPoint()
                        self.addSubview(headerComponentView)
                        alphaTransition.animateAlpha(view: headerComponentView, from: 0.0, to: 1.0)
                    }
                    headerTransition.setPosition(view: headerComponentView, position: headerFrame.origin)
                    headerComponentView.bounds = CGRect(origin: CGPoint(), size: headerFrame.size)
                }
                contentHeight += headerSize.height + 7.0
            } else {
                if let currentContentHeader = self.currentContentHeader {
                    self.currentContentHeader = nil
                    if let componentView = currentContentHeader.view.view {
                        alphaTransition.setAlpha(view: componentView, alpha: 0.0, completion: { [weak componentView] _ in
                            componentView?.removeFromSuperview()
                        })
                    }
                }
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
            self.currentContentContainer.layer.cornerRadius = 30.0
            
            let _ = self.currentContentBackground.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(
                    color: theme.list.itemBlocksBackgroundColor,
                    cornerRadius: .value(30.0),
                    smoothCorners: true
                )),
                environment: {},
                containerSize: contentFrame.size
            )
            if let currentContentBackgroundView = self.currentContentBackground.view {
                if currentContentBackgroundView.superview == nil {
                    self.insertSubview(currentContentBackgroundView, at: 0)
                }
                transition.setFrame(view: currentContentBackgroundView, frame: contentFrame)
            }
            contentHeight += contentSize.height
            
            if let sectionFooter = contentExternalState.sectionFooter {
                let footerView: ComponentView<Empty>
                var footerTransition = transition
                if let current = self.currentContentFooter, current.id == sectionFooter.id {
                    footerView = current.view
                } else {
                    footerTransition = footerTransition.withAnimation(.none)
                    
                    if let currentContentFooter = self.currentContentFooter {
                        self.currentContentFooter = nil
                        if let componentView = currentContentFooter.view.view {
                            alphaTransition.setAlpha(view: componentView, alpha: 0.0, completion: { [weak componentView] _ in
                                componentView?.removeFromSuperview()
                            })
                        }
                    }
                    
                    footerView = ComponentView()
                    self.currentContentFooter = (sectionFooter.id, footerView)
                }
                let headerSideInset: CGFloat = sideInset + 16.0
                let footerSize = footerView.update(
                    transition: .immediate,
                    component: sectionFooter.component,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - headerSideInset * 2.0, height: 10000.0)
                )
                if contentHeight != 0.0 {
                    contentHeight += 8.0 - UIScreenPixel
                }
                let footerFrame = CGRect(origin: CGPoint(x: headerSideInset, y: contentHeight), size: footerSize)
                if let footerComponentView = footerView.view {
                    if footerComponentView.superview == nil {
                        footerComponentView.layer.anchorPoint = CGPoint()
                        self.addSubview(footerComponentView)
                        alphaTransition.animateAlpha(view: footerComponentView, from: 0.0, to: 1.0)
                    }
                    footerTransition.setPosition(view: footerComponentView, position: footerFrame.origin)
                    footerComponentView.bounds = CGRect(origin: CGPoint(), size: footerFrame.size)
                }
                contentHeight += footerSize.height
            } else {
                if let currentContentFooter = self.currentContentFooter {
                    self.currentContentFooter = nil
                    if let componentView = currentContentFooter.view.view {
                        alphaTransition.setAlpha(view: componentView, alpha: 0.0, completion: { [weak componentView] _ in
                            componentView?.removeFromSuperview()
                        })
                    }
                }
            }
            
            var actionsSectionItems: [AnyComponentWithIdentity<Empty>] = []
            if case .translate = component.mode {
                if let copyTranslation = component.copyCurrentResult {
                    actionsSectionItems.append(AnyComponentWithIdentity(id: "copy", component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(
                            MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: environment.strings.Translate_CopyTranslation,
                                    font: Font.regular(17.0),
                                    textColor: theme.list.itemAccentColor
                                )),
                                maximumNumberOfLines: 1
                            )
                        ),
                        leftIcon: .custom(AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Chat/Context Menu/Copy", tintColor: theme.list.itemAccentColor))), false),
                        action: { _ in
                            copyTranslation()
                        }
                    ))))
                }
                if let translateChat = component.translateChat {
                    actionsSectionItems.append(AnyComponentWithIdentity(id: "translate", component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(
                            MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: environment.strings.Localization_TranslateEntireChat,
                                    font: Font.regular(17.0),
                                    textColor: theme.list.itemAccentColor
                                )),
                                maximumNumberOfLines: 1
                            )
                        ),
                        leftIcon: .custom(AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Chat/Context Menu/Translate", tintColor: theme.list.itemAccentColor))), false),
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
                        theme: theme,
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
            
            component.externalState.refreshResult = { [weak self] in
                guard let self, case .stylize = self.currentMode else {
                    return
                }
                guard let contentComponentView = self.currentContent?.view.view as? TextProcessingTranslateContentComponent.View else {
                    return
                }
                contentComponentView.refreshResult()
            }

            if let hint = transition.userData(TextFieldComponent.AnimationHint.self), let hintView = hint.view {
                switch hint.kind {
                case .textChanged:
                    self.recenterCaret(hintView: hintView, transition: transition)
                default:
                    break
                }
            }
            if let previousEnvironment {
                if (environment.inputHeight == 0.0) != (previousEnvironment.inputHeight == 0.0) {
                    if let editingFieldView = self.firstResponderTextFieldView(in: self) {
                        DispatchQueue.main.async { [weak self] in
                            guard let self else {
                                return
                            }
                            self.recenterCaret(hintView: editingFieldView, transition: transition)
                        }
                    }
                }
            }

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
    let initialStyles: [TextProcessingScreen.Style]
    let inputText: ComposedRichMessage
    let initialEditState: TextProcessingScreen.EditState?
    let shouldDisplayStyleNotice: Bool
    let previewIconFile: TelegramMediaFile?
    let copyCurrentResult: ((ComposedRichMessage) -> Void)?
    let translateChat: ((String) -> Void)?

    init(
        context: AccountContext,
        mode: TextProcessingScreen.Mode,
        ignoredTranslationLanguages: [String],
        initialStyles: [TextProcessingScreen.Style],
        inputText: ComposedRichMessage,
        initialEditState: TextProcessingScreen.EditState?,
        shouldDisplayStyleNotice: Bool,
        previewIconFile: TelegramMediaFile?,
        copyCurrentResult: ((ComposedRichMessage) -> Void)?,
        translateChat: ((String) -> Void)?
    ) {
        self.context = context
        self.mode = mode
        self.ignoredTranslationLanguages = ignoredTranslationLanguages
        self.initialStyles = initialStyles
        self.inputText = inputText
        self.initialEditState = initialEditState
        self.shouldDisplayStyleNotice = shouldDisplayStyleNotice
        self.previewIconFile = previewIconFile
        self.copyCurrentResult = copyCurrentResult
        self.translateChat = translateChat
    }

    static func ==(lhs: TextProcessingSheetComponent, rhs: TextProcessingSheetComponent) -> Bool {
        return true
    }

    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, ResizableSheetComponentEnvironment)>()
        private var toast: ComponentView<Empty>?
        private let animateOut = ActionSlot<Action<Void>>()
        private let contentExternalState = TextProcessingContentComponent.ExternalState()
        
        private var styles: [TextProcessingScreen.Style] = []

        private final class LanguageSelectionMenuData {
            let sourceView: UIView
            let currentLanguage: String
            let currentStyle: TelegramComposeAIMessageMode.StyleId
            let displayStyle: Bool
            let completion: (String, TelegramComposeAIMessageMode.StyleReference) -> Void

            init(sourceView: UIView, currentLanguage: String, currentStyle: TelegramComposeAIMessageMode.StyleId, displayStyle: Bool, completion: @escaping (String, TelegramComposeAIMessageMode.StyleReference) -> Void) {
                self.sourceView = sourceView
                self.currentLanguage = currentLanguage
                self.currentStyle = currentStyle
                self.displayStyle = displayStyle
                self.completion = completion
            }
        }
        private var languageSelectionMenuData: LanguageSelectionMenuData?
        private var languageSelectionMenu: ComponentView<Empty>?
        
        private var styleCreatedToastData: (timer: Foundation.Timer, emojiFile: TelegramMediaFile, style: TelegramComposeAIMessageMode.CloudStyle.Custom)?
        private var styleCreatedToast: ComponentView<Empty>?
        
        private var customToastData: (timer: Foundation.Timer, text: String)?
        private var customToast: ComponentView<Empty>?
        
        private var appliedPromptText: String?

        private var component: TextProcessingSheetComponent?
        private var environment: ViewControllerComponentContainer.Environment?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var actionDisposable: Disposable?
        private var isPerformingMainAction: Bool = false

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.actionDisposable?.dispose()
            self.styleCreatedToastData?.timer.invalidate()
            self.customToastData?.timer.invalidate()
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
                        isMonoforum: peer.isMonoForum
                    )),
                    hasEntityKeyboard: false,
                    gesture: nil,
                    sourceSendButton: sourceSendButton,
                    textInputSource: nil,
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
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                self.styles = component.initialStyles
            }
            
            self.component = component
            self.state = state

            let environmentValue = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environmentValue
            let controller = environmentValue.controller
            let theme = environmentValue.theme.withModalBlocksBackground()

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

            var performMainAction: () -> Void = {}
            var performSecondaryAction: ((ComposedRichMessage) -> Bool)?
            var secondaryActionIcon: ActionButtonsComponent.SecondaryActionIcon = .send
            var hasLongPressActions = false
            var isMainActionEnabled = false
            var actionButtonTitle = ""
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
                var isPrompt = false
                switch component.mode {
                case let .edit(_, completion, send, sendContextActions):
                    if self.contentExternalState.isPromptMode {
                        isPrompt = true
                    } else {
                        actionButtonTitle = environmentValue.strings.TextProcessing_ActionApply
                        performSecondaryAction = { data in
                            send?(data)
                            return true
                        }
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
                    }
                case let .translate(_, applyResult):
                    if let applyResult {
                        actionButtonTitle = environmentValue.strings.TextProcessing_ActionApply
                        isMainActionEnabled = !self.contentExternalState.isProcessing && self.contentExternalState.result != nil
                        performMainAction = { [weak self] in
                            guard let self, let result = self.contentExternalState.result else {
                                return
                            }
                            applyResult(result)
                            dismiss(true)
                        }
                    } else {
                        actionButtonTitle = environmentValue.strings.TextProcessing_ActionClose
                        isMainActionEnabled = true
                        performMainAction = {
                            dismiss(true)
                        }
                    }
                case let .preview(style, _, _, isAlreadyAdded, added):
                    actionButtonTitle = isAlreadyAdded ? environmentValue.strings.TextProcessing_StyleMenu_ButtonClose : environmentValue.strings.TextProcessing_StyleMenu_ButtonAdd
                    isMainActionEnabled = !self.isPerformingMainAction
                    performMainAction = { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        self.isPerformingMainAction = true
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                        
                        if isAlreadyAdded {
                            dismiss(true)
                        } else {
                            self.actionDisposable?.dispose()
                            self.actionDisposable = (component.context.engine.messages.installAIMessageStyle(style: style) |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                self.isPerformingMainAction = false
                                if !self.isUpdating {
                                    self.state?.updated(transition: .spring(duration: 0.4))
                                }
                            }, completed: {
                                dismiss(true)
                                added()
                            })
                        }
                    }
                case .generate:
                    isPrompt = true
                }
                
                if isPrompt {
                    if let _ = self.contentExternalState.result {
                        if case .generate = component.mode {
                            actionButtonTitle = environmentValue.strings.TextProcessing_ActionAddToPage
                        } else {
                            actionButtonTitle = environmentValue.strings.TextProcessing_ActionApply
                            secondaryActionIcon = .refresh
                        }
                        isMainActionEnabled = !self.contentExternalState.isProcessing
                    } else {
                        actionButtonTitle = environmentValue.strings.TextProcessing_ActionGenerate
                        isMainActionEnabled = !self.contentExternalState.isProcessing && !self.contentExternalState.promptText.isEmpty
                        
                        if case .generate = component.mode {
                        } else {
                            secondaryActionIcon = .refresh
                        }
                    }
                    performMainAction = { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        self.endEditing(true)
                        
                        if let result = self.contentExternalState.result {
                            if case let .generate(completion) = component.mode {
                                completion(result)
                                dismiss(true)
                            } else if case let .edit(_, completion, _, _) = component.mode {
                                completion(result)
                                dismiss(true)
                            }
                        } else {
                            guard !self.contentExternalState.promptText.isEmpty else {
                                return
                            }
                            self.appliedPromptText = self.contentExternalState.promptText
                            
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        }
                    }
                    if self.contentExternalState.result != nil && !self.contentExternalState.isProcessing && !self.contentExternalState.promptText.isEmpty {
                        performSecondaryAction = { [weak self] _ in
                            guard let self else {
                                return false
                            }
                            guard !self.contentExternalState.promptText.isEmpty else {
                                return false
                            }
                            self.appliedPromptText = self.contentExternalState.promptText
                            self.state?.updated(transition: .immediate)
                            self.contentExternalState.refreshResult?()
                            
                            return false
                        }
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

            var displayInfoButton = true
            let titleString: String
            switch component.mode {
            case .edit:
                titleString = environmentValue.strings.TextProcessing_TitleEdit
            case .translate:
                titleString = environmentValue.strings.TextProcessing_TitleTranslate
            case .preview:
                titleString = ""
                displayInfoButton = false
            case .generate:
                titleString = environmentValue.strings.TextProcessing_TitleAICompose
                displayInfoButton = false
            }
            

            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(ResizableSheetComponent<ViewControllerComponentContainer.Environment>(
                    content: AnyComponent<ViewControllerComponentContainer.Environment>(TextProcessingContentComponent(
                        externalState: self.contentExternalState,
                        context: component.context,
                        mode: component.mode,
                        previewIconFile: component.previewIconFile,
                        styles: self.styles,
                        inputText: component.inputText,
                        initialEditState: component.initialEditState,
                        ignoredTranslationLanguages: component.ignoredTranslationLanguages,
                        shouldDisplayStyleNotice: component.shouldDisplayStyleNotice,
                        appliedPromptText: self.appliedPromptText,
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
                            guard let self else {
                                return
                            }
                            self.languageSelectionMenuData = LanguageSelectionMenuData(sourceView: sourceView, currentLanguage: currentLanguage, currentStyle: currentStyle, displayStyle: displayStyle, completion: completion)
                            self.state?.updated(transition: .immediate)
                        },
                        newStyleAdded: { [weak self] style in
                            Task { @MainActor in
                                guard let self, let component = self.component else {
                                    return
                                }
                                var authorPeer: EnginePeer?
                                if case let .custom(style) = style.content, let authorId = style.authorId {
                                    authorPeer = await component.context.engine.data.get(
                                        TelegramEngine.EngineData.Item.Peer.Peer(id: authorId)
                                    ).get()
                                }
                                
                                if case let .custom(style) = style.content, let emojiFileId = style.emojiFileId {
                                    let emojiFile = await component.context.engine.stickers.resolveInlineStickersLocal(fileIds: [emojiFileId]).get().first?.value
                                    
                                    if let emojiFile {
                                        self.styleCreatedToastData = (Foundation.Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false, block: { [weak self] _ in
                                            guard let self else {
                                                return
                                            }
                                            self.styleCreatedToastData = nil
                                            self.state?.updated(transition: .spring(duration: 0.4))
                                        }), emojiFile, style)
                                    }
                                }
                                
                                self.styles.insert(TextProcessingScreen.Style(cloudStyle: style, authorPeer: authorPeer), at: 0)
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        },
                        styleUpdated: { [weak self] style in
                            Task { @MainActor in
                                guard let self, let component = self.component else {
                                    return
                                }
                                guard let index = self.styles.firstIndex(where: { $0.id.id == style.id }) else {
                                    return
                                }
                                var authorPeer: EnginePeer?
                                if case let .custom(style) = style.content, let authorId = style.authorId {
                                    authorPeer = await component.context.engine.data.get(
                                        TelegramEngine.EngineData.Item.Peer.Peer(id: authorId)
                                    ).get()
                                }
                                self.styles[index] = TextProcessingScreen.Style(cloudStyle: style, authorPeer: authorPeer)
                                self.state?.updated(transition: .immediate)
                            }
                        },
                        styleDeleted: { [weak self] id in
                            guard let self else {
                                return
                            }
                            guard let index = self.styles.firstIndex(where: { $0.id.id == id }) else {
                                return
                            }
                            self.styles.remove(at: index)
                            self.state?.updated(transition: .spring(duration: 0.4))
                        },
                        displayToast: { [weak self] text in
                            guard let self else {
                                return
                            }
                            self.customToastData = (Foundation.Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false, block: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                self.customToastData = nil
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }), text)
                            self.state?.updated(transition: .spring(duration: 0.4))
                        },
                        dismiss: { [weak self] completion in
                            self?.animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                                completion()
                            })
                        }
                    )),
                    titleItem: titleString.isEmpty ? nil : AnyComponent(TitleComponent(
                        theme: theme,
                        title: titleString,
                        isProcessing: self.contentExternalState.isProcessing,
                        lottieSettings: component.context.lottieRenderingSettings
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
                    rightItem: displayInfoButton ? AnyComponent(
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
                    ) : nil,
                    hasTopEdgeEffect: displayInfoButton,
                    bottomItem: AnyComponent(
                        ActionButtonsComponent(
                            theme: theme,
                            strings: environmentValue.strings,
                            actionTitle: actionButtonTitle,
                            actionButtonShowsIncreaseLimit: actionButtonShowsIncreaseLimit,
                            action: isMainActionEnabled ? performMainAction : nil,
                            sendAction: performSecondaryAction.flatMap { [weak self] performSecondaryAction in
                                return {
                                    guard let self else {
                                        return
                                    }
                                    if let result = self.contentExternalState.result {
                                        if performSecondaryAction(result) {
                                            dismiss(true)
                                        }
                                    }
                                }
                            },
                            secondaryActionIcon: (performSecondaryAction != nil || secondaryActionIcon == .refresh) ? secondaryActionIcon : nil,
                            longPressSendAction: (performSecondaryAction != nil && hasLongPressActions) ? { [weak self] sourceView in
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
                        inputHeight: environmentValue.inputHeight,
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
                            playOnce: playOnce,
                            lottieSettings: component.context.lottieRenderingSettings
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
            
            if let styleCreatedToastData = self.styleCreatedToastData, !self.contentExternalState.nonPremiumFloodTriggered {
                let sideInset: CGFloat = 8.0
                
                let styleCreatedToast: ComponentView<Empty>
                var styleCreatedToastTransition = transition
                if let current = self.styleCreatedToast {
                    styleCreatedToast = current
                } else {
                    styleCreatedToastTransition = styleCreatedToastTransition.withAnimation(.none)
                    styleCreatedToast = ComponentView()
                    self.styleCreatedToast = styleCreatedToast
                }
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let styleCreatedToastSize = styleCreatedToast.update(
                    transition: styleCreatedToastTransition,
                    component: AnyComponent(ToastContentComponent(
                        icon: AnyComponent(EmojiStatusComponent(
                            context: component.context,
                            animationCache: component.context.animationCache,
                            animationRenderer: component.context.animationRenderer,
                            content: .animation(
                                content: .file(file: styleCreatedToastData.emojiFile),
                                size: CGSize(width: 32.0, height: 32.0),
                                placeholderColor: environmentValue.theme.list.mediaPlaceholderColor,
                                themeColor: environmentValue.theme.list.itemPrimaryTextColor,
                                loopMode: .count(1)
                            ),
                            size: CGSize(width: 32.0, height: 32.0),
                            isVisibleForAnimations: true,
                            action: nil
                        )),
                        content: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(string: environmentValue.strings.TextProcessing_ToastStyleCreated_Title(styleCreatedToastData.style.title).string, font: Font.semibold(14.0), textColor: .white)),
                            ))),
                            AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                                text: .markdown(text: environmentValue.strings.TextProcessing_ToastStyleCreated_Text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in nil })),
                                maximumNumberOfLines: 0
                            )))
                        ], alignment: .left, spacing: 6.0)),
                        insets: UIEdgeInsets(top: 10.0, left: 12.0, bottom: 10.0, right: 10.0),
                        iconSpacing: 12.0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
                )
                if let styleCreatedToastView = styleCreatedToast.view {
                    if styleCreatedToastView.superview == nil, let sheetView = self.sheet.view as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
                        sheetView.containerView.addSubview(styleCreatedToastView)
                        if !transition.animation.isImmediate {
                            styleCreatedToastView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        }
                    }
                    styleCreatedToastTransition.setFrame(view: styleCreatedToastView, frame: CGRect(origin: CGPoint(x: sideInset, y: availableSize.height - 94.0 - styleCreatedToastSize.height), size: styleCreatedToastSize))
                }
            } else {
                if let styleCreatedToast = self.styleCreatedToast {
                    self.styleCreatedToast = nil
                    if let styleCreatedToastView = styleCreatedToast.view {
                        styleCreatedToastView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak styleCreatedToastView] _ in
                            styleCreatedToastView?.removeFromSuperview()
                        })
                    }
                }
            }
            
            if let customToastData = self.customToastData, !self.contentExternalState.nonPremiumFloodTriggered, self.styleCreatedToastData == nil {
                let sideInset: CGFloat = 8.0
                
                let customToast: ComponentView<Empty>
                var customToastTransition = transition
                if let current = self.customToast {
                    customToast = current
                } else {
                    customToastTransition = customToastTransition.withAnimation(.none)
                    customToast = ComponentView()
                    self.customToast = customToast
                }
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let playOnce = ActionSlot<Void>()
                let customToastSize = customToast.update(
                    transition: customToastTransition,
                    component: AnyComponent(ToastContentComponent(
                        icon: AnyComponent(LottieComponent(
                            content: LottieComponent.AppBundleContent(name: "anim_infotip"),
                            startingPosition: .begin,
                            size: CGSize(width: 32.0, height: 32.0),
                            playOnce: playOnce,
                            lottieSettings: component.context.lottieRenderingSettings
                        )),
                        content: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                                text: .markdown(text: customToastData.text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in nil })),
                                maximumNumberOfLines: 0
                            )))
                        ], alignment: .left, spacing: 6.0)),
                        insets: UIEdgeInsets(top: 10.0, left: 12.0, bottom: 10.0, right: 10.0),
                        iconSpacing: 12.0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
                )
                if let customToastView = customToast.view {
                    if customToastView.superview == nil, let sheetView = self.sheet.view as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
                        sheetView.containerView.addSubview(customToastView)
                        if !transition.animation.isImmediate {
                            customToastView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        }
                        playOnce.invoke(())
                    }
                    customToastTransition.setFrame(view: customToastView, frame: CGRect(origin: CGPoint(x: sideInset, y: availableSize.height - 94.0 - customToastSize.height), size: customToastSize))
                }
            } else {
                if let customToast = self.customToast {
                    self.customToast = nil
                    if let customToastView = customToast.view {
                        customToastView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak customToastView] _ in
                            customToastView?.removeFromSuperview()
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
                        displayStyles: languageSelectionMenuDataValue.displayStyle ? self.styles : nil,
                        completion: languageSelectionMenuDataValue.completion,
                        dismissed: { [weak self] in
                            guard let self else {
                                return
                            }
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
    
    public final class Style: Equatable {
        public let reference: TelegramComposeAIMessageMode.CloudStyle.Reference
        public let title: String
        public let emojiFileId: Int64?
        public let emojiFile: TelegramMediaFile?
        public let isAuthor: Bool
        public let slug: String?
        public let cloudStyle: TelegramComposeAIMessageMode.CloudStyle
        public let authorPeer: EnginePeer?
        
        public var id: TelegramComposeAIMessageMode.StyleReference {
            return .style(self.reference)
        }
        
        public init(reference: TelegramComposeAIMessageMode.CloudStyle.Reference, title: String, emojiFileId: Int64?, emojiFile: TelegramMediaFile?, isAuthor: Bool, slug: String?, cloudStyle: TelegramComposeAIMessageMode.CloudStyle, authorPeer: EnginePeer?) {
            self.reference = reference
            self.title = title
            self.emojiFileId = emojiFileId
            self.emojiFile = emojiFile
            self.isAuthor = isAuthor
            self.slug = slug
            self.cloudStyle = cloudStyle
            self.authorPeer = authorPeer
        }
        
        convenience init(cloudStyle: TelegramComposeAIMessageMode.CloudStyle, authorPeer: EnginePeer?) {
            let title: String
            let emojiFileId: Int64?
            var isAuthor = false
            var slug: String?
            switch cloudStyle.content {
            case let .standard(standard):
                title = standard.title
                emojiFileId = standard.emojiFileId
            case let .custom(custom):
                title = custom.title
                emojiFileId = custom.emojiFileId
                isAuthor = custom.isCreator
                slug = custom.slug
            }
            self.init(
                reference: cloudStyle.reference,
                title: title,
                emojiFileId: emojiFileId,
                emojiFile: nil,
                isAuthor: isAuthor,
                slug: slug,
                cloudStyle: cloudStyle,
                authorPeer: authorPeer
            )
        }
        
        public static func ==(lhs: Style, rhs: Style) -> Bool {
            if lhs.reference != rhs.reference {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.emojiFileId != rhs.emojiFileId {
                return false
            }
            if lhs.emojiFile != rhs.emojiFile {
                return false
            }
            if lhs.cloudStyle != rhs.cloudStyle {
                return false
            }
            return true
        }
    }
    
    private let context: AccountContext

    public init(
        context: AccountContext,
        theme: PresentationTheme? = nil,
        mode: Mode,
        inputText: ComposedRichMessage,
        copyResult: ((ComposedRichMessage) -> Void)?,
        translateChat: ((String) -> Void)?
    ) async {
        self.context = context
        
        let rawStyles = await context.engine.messages.composeAIMessageStyles().get()
        var styles: [Style] = []
        let resolvedEmojiFiles: [Int64: TelegramMediaFile] = await context.engine.stickers.resolveInlineStickersLocal(fileIds: Array(Set(rawStyles.compactMap({ style in
            switch style.content {
            case let .standard(standard):
                return standard.emojiFileId
            case let .custom(custom):
                return custom.emojiFileId
            }
        })))).get()
        for value in rawStyles {
            let title: String
            let emojiFileId: Int64?
            var isAuthor = false
            var slug: String?
            var authorPeer: EnginePeer?
            switch value.content {
            case let .standard(standard):
                title = standard.title
                emojiFileId = standard.emojiFileId
            case let .custom(custom):
                title = custom.title
                emojiFileId = custom.emojiFileId
                isAuthor = custom.isCreator
                slug = custom.slug
                if let authorId = custom.authorId {
                    authorPeer = await context.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: authorId)
                    ).get()
                }
            }
            styles.append(Style(
                reference: value.reference,
                title: title,
                emojiFileId: emojiFileId,
                emojiFile: emojiFileId.flatMap { resolvedEmojiFiles[$0] },
                isAuthor: isAuthor,
                slug: slug,
                cloudStyle: value,
                authorPeer: authorPeer
            ))
        }
        
        var shouldDisplayStyleNotice = false
        var previewIconFile: TelegramMediaFile?
        if case let .preview(style, _, _, _, _) = mode {
            if let emojiFileId = style.emojiFileId {
                previewIconFile = await context.engine.stickers.resolveInlineStickersLocal(fileIds: [emojiFileId]).get().first?.value
            }
        } else {
            shouldDisplayStyleNotice = await ApplicationSpecificNotice.getAITextProcessingStyleSelection(accountManager: context.sharedContext.accountManager).get() < 3
        }
        
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
                initialStyles: styles,
                inputText: inputText,
                initialEditState: initialEditState,
                shouldDisplayStyleNotice: shouldDisplayStyleNotice,
                previewIconFile: previewIconFile,
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
    let lottieSettings: LottieRenderingSettings
    
    init(
        theme: PresentationTheme,
        title: String,
        isProcessing: Bool,
        lottieSettings: LottieRenderingSettings
    ) {
        self.theme = theme
        self.title = title
        self.isProcessing = isProcessing
        self.lottieSettings = lottieSettings
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
                        loop: true,
                        lottieSettings: component.lottieSettings
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
    enum SecondaryActionIcon {
        case send
        case refresh
    }
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    let actionTitle: String
    let actionButtonShowsIncreaseLimit: Bool
    let action: (() -> Void)?
    let sendAction: (() -> Void)?
    let secondaryActionIcon: SecondaryActionIcon?
    let longPressSendAction: ((UIView) -> Void)?
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        actionTitle: String,
        actionButtonShowsIncreaseLimit: Bool,
        action: (() -> Void)?,
        sendAction: (() -> Void)?,
        secondaryActionIcon: SecondaryActionIcon?,
        longPressSendAction: ((UIView) -> Void)?
    ) {
        self.theme = theme
        self.strings = strings
        self.actionTitle = actionTitle
        self.actionButtonShowsIncreaseLimit = actionButtonShowsIncreaseLimit
        self.action = action
        self.sendAction = sendAction
        self.secondaryActionIcon = secondaryActionIcon
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
        if lhs.secondaryActionIcon != rhs.secondaryActionIcon {
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
            if component.secondaryActionIcon != nil {
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
                    restrictContentAnimations: true,
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
                            name: component.secondaryActionIcon == .refresh ? "TextProcessing/RefreshButton" : "TextProcessing/SendIcon",
                            tintColor: component.theme.list.itemCheckColors.foregroundColor,
                            scaleFactor: 1.0
                        )), translation: CGPoint(x: component.secondaryActionIcon == .refresh ? 0.0 : -2.0, y: 0.0)))
                    ),
                    restrictContentAnimations: true,
                    contentInsets: UIEdgeInsets(),
                    isEnabled: component.sendAction != nil,
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
            transition.setAlpha(view: self.extractedContainerView, alpha: component.secondaryActionIcon != nil ? 1.0 : 0.0)
            transition.setScale(view: self.extractedContainerView, scale: component.secondaryActionIcon != nil ? 1.0 : 0.001)

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
