import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import AppBundle
import TextFieldComponent
import BundleIconComponent
import AccountContext
import TelegramPresentationData
import ChatPresentationInterfaceState
import LottieComponent
import ChatContextQuery
import TextFormat
import EmojiSuggestionsComponent
import AudioToolbox
import AnimatedTextComponent
import AnimatedCountLabelNode
import MessageInputActionButtonComponent
import ContextReferenceButtonComponent
import ForwardInfoPanelComponent
import MultilineTextComponent
import PlainButtonComponent

private var sharedIsReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled

private let timeoutButtonTag = GenericComponentViewTag()

public final class MessageInputPanelComponent: Component {
    public struct ContextQueryTypes: OptionSet {
        public var rawValue: Int32
        
        public init() {
            self.rawValue = 0
        }
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public static let emoji = ContextQueryTypes(rawValue: (1 << 0))
        public static let hashtag = ContextQueryTypes(rawValue: (1 << 1))
        public static let mention = ContextQueryTypes(rawValue: (1 << 2))
    }
    
    public enum Style {
        case story
        case editor
        case media
    }
    
    public enum InputMode: Hashable {
        case text
        case stickers
        case emoji
    }
    
    public enum AttachmentButtonMode: Hashable {
        case attach
        case captionUp
        case captionDown
    }
    
    public struct MyReaction: Equatable {
        public let reaction: MessageReaction.Reaction
        public let file: TelegramMediaFile?
        public let animationFileId: Int64?
        
        public init(reaction: MessageReaction.Reaction, file: TelegramMediaFile?, animationFileId: Int64?) {
            self.reaction = reaction
            self.file = file
            self.animationFileId = animationFileId
        }
    }
    
    public enum Placeholder: Equatable {
        public enum CounterItemContent: Equatable {
            case text(String)
            case number(Int, minDigits: Int)
        }
        
        public struct CounterItem: Equatable {
            public var id: Int
            public var content: CounterItemContent
            
            public init(id: Int, content: CounterItemContent) {
                self.id = id
                self.content = content
            }
        }
        
        case plain(String)
        case counter([CounterItem])
    }
    
    public enum DisabledPlaceholder: Equatable {
        enum Kind {
            case text
            case premiumRequired
            case boostRequired
        }
        
        case text(String)
        case premiumRequired(title: String, subtitle: String, action: () -> Void)
        case boostRequired(title: String, subtitle: String, action: () -> Void)
        
        var kind: Kind {
            switch self {
            case .text:
                return .text
            case .premiumRequired:
                return .premiumRequired
            case .boostRequired:
                return .boostRequired
            }
        }
        
        public static func ==(lhs: DisabledPlaceholder, rhs: DisabledPlaceholder) -> Bool {
            switch lhs {
            case let .text(value):
                if case .text(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .premiumRequired(title, subtitle, _):
                if case .premiumRequired(title, subtitle, _) = rhs {
                    return true
                } else {
                    return false
                }
            case let .boostRequired(title, subtitle, _):
                if case .boostRequired(title, subtitle, _) = rhs {
                    return true
                } else {
                    return false
                }
            }
        }
    }
    
    public final class ExternalState {
        public fileprivate(set) var isEditing: Bool = false
        public fileprivate(set) var hasText: Bool = false
        public fileprivate(set) var isKeyboardHidden: Bool = false
        
        public var initialText: NSAttributedString?
        
        public fileprivate(set) var insertText: (NSAttributedString) -> Void = { _ in }
        public fileprivate(set) var deleteBackward: () -> Void = { }
        
        public init() {
        }
    }
    
    public let externalState: ExternalState
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let style: Style
    public let placeholder: Placeholder
    public let sendPaidMessageStars: StarsAmount?
    public let maxLength: Int?
    public let queryTypes: ContextQueryTypes
    public let alwaysDarkWhenHasText: Bool
    public let useGrayBackground: Bool
    public let resetInputContents: SendMessageInput?
    public let nextInputMode: (Bool) -> InputMode?
    public let areVoiceMessagesAvailable: Bool
    public let presentController: (ViewController) -> Void
    public let presentInGlobalOverlay: (ViewController) -> Void
    public let sendMessageAction: () -> Void
    public let sendMessageOptionsAction: ((UIView, ContextGesture?) -> Void)?
    public let sendStickerAction: (TelegramMediaFile) -> Void
    public let setMediaRecordingActive: ((Bool, Bool, Bool, UIView?) -> Void)?
    public let lockMediaRecording: (() -> Void)?
    public let stopAndPreviewMediaRecording: (() -> Void)?
    public let discardMediaRecordingPreview: (() -> Void)?
    public let attachmentAction: (() -> Void)?
    public let attachmentButtonMode: AttachmentButtonMode?
    public let myReaction: MyReaction?
    public let likeAction: (() -> Void)?
    public let likeOptionsAction: ((UIView, ContextGesture?) -> Void)?
    public let inputModeAction: (() -> Void)?
    public let timeoutAction: ((UIView, ContextGesture?) -> Void)?
    public let forwardAction: (() -> Void)?
    public let moreAction: ((UIView, ContextGesture?) -> Void)?
    public let presentCaptionPositionTooltip: ((UIView) -> Void)?
    public let presentVoiceMessagesUnavailableTooltip: ((UIView) -> Void)?
    public let presentTextLengthLimitTooltip: (() -> Void)?
    public let presentTextFormattingTooltip: (() -> Void)?
    public let paste: (TextFieldComponent.PasteData) -> Void
    public let audioRecorder: ManagedAudioRecorder?
    public let videoRecordingStatus: InstantVideoControllerRecordingStatus?
    public let isRecordingLocked: Bool
    public let hasRecordedVideo: Bool
    public let recordedAudioPreview: ChatRecordedMediaPreview?
    public let hasRecordedVideoPreview: Bool
    public let wasRecordingDismissed: Bool
    public let timeoutValue: String?
    public let timeoutSelected: Bool
    public let displayGradient: Bool
    public let bottomInset: CGFloat
    public let isFormattingLocked: Bool
    public let hideKeyboard: Bool
    public let customInputView: UIView?
    public let forceIsEditing: Bool
    public let disabledPlaceholder: DisabledPlaceholder?
    public let header: AnyComponent<Empty>?
    public let isChannel: Bool
    public let storyItem: EngineStoryItem?
    public let chatLocation: ChatLocation?
    
    public init(
        externalState: ExternalState,
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        style: Style,
        placeholder: Placeholder,
        sendPaidMessageStars: StarsAmount?,
        maxLength: Int?,
        queryTypes: ContextQueryTypes,
        alwaysDarkWhenHasText: Bool,
        useGrayBackground: Bool = false,
        resetInputContents: SendMessageInput?,
        nextInputMode: @escaping (Bool) -> InputMode?,
        areVoiceMessagesAvailable: Bool,
        presentController: @escaping (ViewController) -> Void,
        presentInGlobalOverlay: @escaping (ViewController) -> Void,
        sendMessageAction: @escaping () -> Void,
        sendMessageOptionsAction: ((UIView, ContextGesture?) -> Void)?,
        sendStickerAction: @escaping (TelegramMediaFile) -> Void,
        setMediaRecordingActive: ((Bool, Bool, Bool, UIView?) -> Void)?,
        lockMediaRecording: (() -> Void)?,
        stopAndPreviewMediaRecording: (() -> Void)?,
        discardMediaRecordingPreview: (() -> Void)?,
        attachmentAction: (() -> Void)?,
        attachmentButtonMode: AttachmentButtonMode? = nil,
        myReaction: MyReaction?,
        likeAction: (() -> Void)?,
        likeOptionsAction: ((UIView, ContextGesture?) -> Void)?,
        inputModeAction: (() -> Void)?,
        timeoutAction: ((UIView, ContextGesture?) -> Void)?,
        forwardAction: (() -> Void)?,
        moreAction: ((UIView, ContextGesture?) -> Void)?,
        presentCaptionPositionTooltip: ((UIView) -> Void)?,
        presentVoiceMessagesUnavailableTooltip: ((UIView) -> Void)?,
        presentTextLengthLimitTooltip: (() -> Void)?,
        presentTextFormattingTooltip: (() -> Void)?,
        paste: @escaping (TextFieldComponent.PasteData) -> Void,
        audioRecorder: ManagedAudioRecorder?,
        videoRecordingStatus: InstantVideoControllerRecordingStatus?,
        isRecordingLocked: Bool,
        hasRecordedVideo: Bool,
        recordedAudioPreview: ChatRecordedMediaPreview?,
        hasRecordedVideoPreview: Bool,
        wasRecordingDismissed: Bool,
        timeoutValue: String?,
        timeoutSelected: Bool,
        displayGradient: Bool,
        bottomInset: CGFloat,
        isFormattingLocked: Bool,
        hideKeyboard: Bool,
        customInputView: UIView?,
        forceIsEditing: Bool,
        disabledPlaceholder: DisabledPlaceholder?,
        header: AnyComponent<Empty>?,
        isChannel: Bool,
        storyItem: EngineStoryItem?,
        chatLocation: ChatLocation?
    ) {
        self.externalState = externalState
        self.context = context
        self.theme = theme
        self.strings = strings
        self.style = style
        self.nextInputMode = nextInputMode
        self.placeholder = placeholder
        self.sendPaidMessageStars = sendPaidMessageStars
        self.maxLength = maxLength
        self.queryTypes = queryTypes
        self.alwaysDarkWhenHasText = alwaysDarkWhenHasText
        self.useGrayBackground = useGrayBackground
        self.resetInputContents = resetInputContents
        self.areVoiceMessagesAvailable = areVoiceMessagesAvailable
        self.presentController = presentController
        self.presentInGlobalOverlay = presentInGlobalOverlay
        self.sendMessageAction = sendMessageAction
        self.sendMessageOptionsAction = sendMessageOptionsAction
        self.sendStickerAction = sendStickerAction
        self.setMediaRecordingActive = setMediaRecordingActive
        self.lockMediaRecording = lockMediaRecording
        self.stopAndPreviewMediaRecording = stopAndPreviewMediaRecording
        self.discardMediaRecordingPreview = discardMediaRecordingPreview
        self.attachmentAction = attachmentAction
        self.attachmentButtonMode = attachmentButtonMode
        self.myReaction = myReaction
        self.likeAction = likeAction
        self.likeOptionsAction = likeOptionsAction
        self.inputModeAction = inputModeAction
        self.timeoutAction = timeoutAction
        self.forwardAction = forwardAction
        self.moreAction = moreAction
        self.presentCaptionPositionTooltip = presentCaptionPositionTooltip
        self.presentVoiceMessagesUnavailableTooltip = presentVoiceMessagesUnavailableTooltip
        self.presentTextLengthLimitTooltip = presentTextLengthLimitTooltip
        self.presentTextFormattingTooltip = presentTextFormattingTooltip
        self.paste = paste
        self.audioRecorder = audioRecorder
        self.videoRecordingStatus = videoRecordingStatus
        self.isRecordingLocked = isRecordingLocked
        self.hasRecordedVideo = hasRecordedVideo
        self.wasRecordingDismissed = wasRecordingDismissed
        self.recordedAudioPreview = recordedAudioPreview
        self.hasRecordedVideoPreview = hasRecordedVideoPreview
        self.timeoutValue = timeoutValue
        self.timeoutSelected = timeoutSelected
        self.displayGradient = displayGradient
        self.bottomInset = bottomInset
        self.isFormattingLocked = isFormattingLocked
        self.hideKeyboard = hideKeyboard
        self.customInputView = customInputView
        self.forceIsEditing = forceIsEditing
        self.disabledPlaceholder = disabledPlaceholder
        self.header = header
        self.isChannel = isChannel
        self.storyItem = storyItem
        self.chatLocation = chatLocation
    }
    
    public static func ==(lhs: MessageInputPanelComponent, rhs: MessageInputPanelComponent) -> Bool {
        if lhs.externalState !== rhs.externalState {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.style != rhs.style {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.sendPaidMessageStars != rhs.sendPaidMessageStars {
            return false
        }
        if lhs.maxLength != rhs.maxLength {
            return false
        }
        if lhs.queryTypes != rhs.queryTypes {
            return false
        }
        if lhs.alwaysDarkWhenHasText != rhs.alwaysDarkWhenHasText {
            return false
        }
        if lhs.useGrayBackground != rhs.useGrayBackground {
            return false
        }
        if lhs.resetInputContents != rhs.resetInputContents {
            return false
        }
        if lhs.areVoiceMessagesAvailable != rhs.areVoiceMessagesAvailable {
            return false
        }
        if lhs.audioRecorder !== rhs.audioRecorder {
            return false
        }
        if lhs.videoRecordingStatus !== rhs.videoRecordingStatus {
            return false
        }
        if lhs.isRecordingLocked != rhs.isRecordingLocked {
            return false
        }
        if lhs.hasRecordedVideo != rhs.hasRecordedVideo {
            return false
        }
        if lhs.wasRecordingDismissed != rhs.wasRecordingDismissed {
            return false
        }
        if lhs.recordedAudioPreview != rhs.recordedAudioPreview {
            return false
        }
        if lhs.hasRecordedVideoPreview != rhs.hasRecordedVideoPreview {
            return false
        }
        if lhs.timeoutValue != rhs.timeoutValue {
            return false
        }
        if lhs.timeoutSelected != rhs.timeoutSelected {
            return false
        }
        if lhs.displayGradient != rhs.displayGradient {
            return false
        }
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        if lhs.isFormattingLocked != rhs.isFormattingLocked {
            return false
        }
        if (lhs.forwardAction == nil) != (rhs.forwardAction == nil) {
            return false
        }
        if (lhs.moreAction == nil) != (rhs.moreAction == nil) {
            return false
        }
        if (lhs.setMediaRecordingActive == nil) != (rhs.setMediaRecordingActive == nil) {
            return false
        }
        if lhs.hideKeyboard != rhs.hideKeyboard {
            return false
        }
        if lhs.customInputView !== rhs.customInputView {
            return false
        }
        if lhs.forceIsEditing != rhs.forceIsEditing {
            return false
        }
        if lhs.disabledPlaceholder != rhs.disabledPlaceholder {
            return false
        }
        if lhs.header != rhs.header {
            return false
        }
        if (lhs.attachmentAction == nil) != (rhs.attachmentAction == nil) {
            return false
        }
        if lhs.attachmentButtonMode != rhs.attachmentButtonMode {
            return false
        }
        if lhs.myReaction != rhs.myReaction {
            return false
        }
        if (lhs.likeAction == nil) != (rhs.likeAction == nil) {
            return false
        }
        if (lhs.likeOptionsAction == nil) != (rhs.likeOptionsAction == nil) {
            return false
        }
        if lhs.isChannel != rhs.isChannel {
            return false
        }
        if lhs.storyItem != rhs.storyItem {
            return false
        }
        if lhs.chatLocation != rhs.chatLocation {
            return false
        }
        return true
    }
    
    public enum SendMessageInput: Equatable {
        case text(NSAttributedString)
    }
            
    public final class View: UIView {
        private let fieldBackgroundView: BlurredBackgroundView
        private let fieldBackgroundTint: UIView
        private let gradientView: UIImageView
        private let bottomGradientView: UIView
        
        private let placeholder = ComponentView<Empty>()
        private let vibrancyPlaceholder = ComponentView<Empty>()
        
        private let counter = ComponentView<Empty>()
        private var header: ComponentView<Empty>?
        
        private var disabledPlaceholder: ComponentView<Empty>?
        private var textClippingView = UIView()
        private let textField = ComponentView<Empty>()
        private let textFieldExternalState = TextFieldComponent.ExternalState()
        
        private let attachmentButton = ComponentView<Empty>()
        private var deleteMediaPreviewButton: ComponentView<Empty>?
        private let inputActionButton = ComponentView<Empty>()
        private let likeButton = ComponentView<Empty>()
        private let stickerButton = ComponentView<Empty>()
        private let timeoutButton = ComponentView<Empty>()
        
        private var mediaRecordingVibrancyContainer: UIView
        private var mediaRecordingPanel: ComponentView<Empty>?
        private weak var dismissingMediaRecordingPanel: UIView?
        
        private var mediaPreviewPanel: ComponentView<Empty>?
        
        private var currentMediaInputIsVoice: Bool = true
        private var mediaCancelFraction: CGFloat = 0.0
        
        private var currentInputMode: InputMode?
        
        private var contextQueryStates: [ChatPresentationInputQueryKind: (ChatPresentationInputQuery, Disposable)] = [:]
        private var contextQueryResults: [ChatPresentationInputQueryKind: ChatPresentationInputQueryResult] = [:]
        private var contextQueryPeer: EnginePeer?
        private var contextQueryResultPanel: ComponentView<Empty>?
        
        private var stickersResultPanel: ComponentView<Empty>?
        
        private var viewForOverlayContent: ViewForOverlayContent?
        private var currentEmojiSuggestionView: ComponentHostView<Empty>?
        private var currentEmojiSearchView: ComponentHostView<Empty>?
        
        private var viewsIconView: UIImageView?
        private var viewStatsCountText: AnimatedCountLabelView?
        private var reactionStatsCountText: AnimatedCountLabelView?
        
        private var didDisplayCaptionPositionTooltip = false
        
        private let hapticFeedback = HapticFeedback()
        
        private var component: MessageInputPanelComponent?
        private weak var state: EmptyComponentState?
        
        private var pendingSetMessageInput: SendMessageInput?
        
        public var likeButtonView: UIView? {
            return self.likeButton.view
        }
        
        public var likeIconView: UIView? {
            return (self.likeButton.view as? MessageInputActionButtonComponent.View)?.likeIconView
        }
        
        override init(frame: CGRect) {
            self.fieldBackgroundView = BlurredBackgroundView(color: nil, enableBlur: true)
            self.fieldBackgroundTint = UIView()
            self.fieldBackgroundTint.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
            
            self.mediaRecordingVibrancyContainer = UIView()
            if let filter = CALayer.luminanceToAlpha() {
                self.mediaRecordingVibrancyContainer.backgroundColor = .white
                self.mediaRecordingVibrancyContainer.layer.filters = [filter]
            }
            self.fieldBackgroundTint.mask = self.mediaRecordingVibrancyContainer
            
            self.gradientView = UIImageView()
            self.bottomGradientView = UIView()
            
            self.textClippingView.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.addSubview(self.bottomGradientView)
            self.addSubview(self.gradientView)
            self.addSubview(self.fieldBackgroundView)
            self.addSubview(self.fieldBackgroundTint)
            self.addSubview(self.textClippingView)
            
            self.viewForOverlayContent = ViewForOverlayContent(
                ignoreHit: { [weak self] view, point in
                    guard let self else {
                        return false
                    }
                    if self.hitTest(view.convert(point, to: self), with: nil) != nil {
                        return true
                    }
                    if view.convert(point, to: self).y > self.bounds.maxY {
                        return true
                    }
                    return false
                },
                dismissSuggestions: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.textFieldExternalState.dismissedEmojiSuggestionPosition = self.textFieldExternalState.currentEmojiSuggestion?.position
                    self.textFieldExternalState.dismissedEmojiSearchPosition = self.textFieldExternalState.currentEmojiSearch?.position
                    self.state?.updated()
                }
            )
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func hasFirstResponder() -> Bool {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                return textFieldView.hasFirstResponder()
            } else {
                return false
            }
        }
        
        public func getSendMessageInput() -> SendMessageInput {
            guard let textFieldView = self.textField.view as? TextFieldComponent.View else {
                return .text(NSAttributedString())
            }
            
            return .text(textFieldView.getAttributedText())
        }
        
        public func setSendMessageInput(value: SendMessageInput, updateState: Bool) {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                switch value {
                case let .text(text):
                    textFieldView.setAttributedText(text, updateState: updateState)
                }
            } else {
                self.pendingSetMessageInput = value
            }
        }
        
        public func getAttachmentButtonView() -> UIView? {
            guard let attachmentButtonView = self.attachmentButton.view else {
                return nil
            }
            return attachmentButtonView
        }
        
        public func clearSendMessageInput(updateState: Bool) {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                textFieldView.setAttributedText(NSAttributedString(), updateState: updateState)
            }
        }
        
        public func activateInput() {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                textFieldView.activateInput()
            }
        }
        
        public func canDeactivateInput() -> Bool {
            guard let component = self.component else {
                return true
            }
            if let maxLength = component.maxLength, self.textFieldExternalState.textLength > maxLength {
                return false
            } else {
                return true
            }
        }
        
        public var isActive: Bool {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                return textFieldView.isActive
            } else {
                return false
            }
        }
        
        public func deactivateInput(force: Bool = false) {
            if self.canDeactivateInput() || force {
                if let textFieldView = self.textField.view as? TextFieldComponent.View {
                    textFieldView.deactivateInput()
                }
            }
        }
        
        public func animateError() {
            self.textField.view?.layer.addShakeAnimation()
            self.hapticFeedback.error()
        }
        
        public func updateContextQueries() {
            guard let component = self.component, let textFieldView = self.textField.view as? TextFieldComponent.View else {
                return
            }
            let context = component.context
            let inputState = textFieldView.getInputState()
            
            var availableTypes: [ChatPresentationInputQueryKind] = []
            if component.queryTypes.contains(.mention) {
                availableTypes.append(.mention)
            }
            if component.queryTypes.contains(.hashtag) {
                availableTypes.append(.hashtag)
            }
            if component.queryTypes.contains(.emoji) {
                availableTypes.append(.emoji)
            }
            let contextQueryUpdates = contextQueryResultState(context: context, inputState: inputState, availableTypes: availableTypes, chatLocation: component.chatLocation, currentQueryStates: &self.contextQueryStates)

            if self.contextQueryPeer == nil, let peerId = component.chatLocation?.peerId {
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let self, let peer, case .channel = peer, peer.addressName != nil else {
                        return
                    }
                    self.contextQueryPeer = peer
                    self.state?.updated(transition: .immediate)
                })
            }
            
            for (kind, update) in contextQueryUpdates {
                switch update {
                case .remove:
                    if let (_, disposable) = self.contextQueryStates[kind] {
                        disposable.dispose()
                        self.contextQueryStates.removeValue(forKey: kind)
                        self.contextQueryResults[kind] = nil
                    }
                case let .update(query, signal):
                    let currentQueryAndDisposable = self.contextQueryStates[kind]
                    currentQueryAndDisposable?.1.dispose()

                    var inScope = true
                    var inScopeResult: ((ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?)?
                    self.contextQueryStates[kind] = (query, (signal
                    |> deliverOnMainQueue).start(next: { [weak self] result in
                        if let self {
                            if Thread.isMainThread && inScope {
                                inScope = false
                                inScopeResult = result
                            } else {
                                self.contextQueryResults[kind] = result(self.contextQueryResults[kind])
                                self.state?.updated(transition: .immediate)
                            }
                        }
                    }))
                    inScope = false
                    if let inScopeResult = inScopeResult {
                        self.contextQueryResults[kind] = inScopeResult(self.contextQueryResults[kind])
                    }
                }
            }
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            
            if let _ = self.textField.view, let currentEmojiSuggestion = self.textFieldExternalState.currentEmojiSuggestion, let currentEmojiSuggestionView = self.currentEmojiSuggestionView {
                if let result = currentEmojiSuggestionView.hitTest(self.convert(point, to: currentEmojiSuggestionView), with: event) {
                    return result
                }
                self.textFieldExternalState.dismissedEmojiSuggestionPosition = currentEmojiSuggestion.position
                if let textFieldView = self.textField.view as? TextFieldComponent.View {
                    textFieldView.updateEmojiSuggestion(transition: .immediate)
                }
                self.state?.updated()
            } else if let _ = self.textField.view, let currentEmojiSearch = self.textFieldExternalState.currentEmojiSearch, let currentEmojiSearchView = self.currentEmojiSearchView {
                if let result = currentEmojiSearchView.hitTest(self.convert(point, to: currentEmojiSearchView), with: event) {
                    return result
                }
                self.textFieldExternalState.dismissedEmojiSearchPosition = currentEmojiSearch.position
                if let textFieldView = self.textField.view as? TextFieldComponent.View {
                    textFieldView.updateEmojiSuggestion(transition: .immediate)
                }
                self.state?.updated()
            }
            
            if result == nil, let stickersResultPanel = self.stickersResultPanel?.view, let panelResult = stickersResultPanel.hitTest(self.convert(point, to: stickersResultPanel), with: event), panelResult !== stickersResultPanel {
                return panelResult
            }
            
            if result == nil, let contextQueryResultPanel = self.contextQueryResultPanel?.view, let panelResult = contextQueryResultPanel.hitTest(self.convert(point, to: contextQueryResultPanel), with: event), panelResult !== contextQueryResultPanel {
                return panelResult
            }
             
            return result
        }
        
        func update(component: MessageInputPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousPlaceholder = self.component?.placeholder
            
            let defaultInsets = UIEdgeInsets(top: 14.0, left: 9.0, bottom: 6.0, right: 41.0)
            var insets = defaultInsets
            
            let layoutFromTop = component.attachmentButtonMode == .captionDown
            
            if let _ = component.attachmentAction {
                insets.left = 41.0
            }
            if let _ = component.setMediaRecordingActive {
                insets.right = 41.0
            }
            
            var textFieldSideInset = 9.0
            if case .media = component.style {
                textFieldSideInset = 8.0
            }
            
            let mediaInsets = UIEdgeInsets(top: insets.top, left: textFieldSideInset, bottom: insets.bottom, right: 41.0)
            
            let baseFieldHeight: CGFloat = 40.0
            
            var transition = transition
            let previousComponent = self.component
            if transition.animation.isImmediate, let previousComponent, previousComponent.storyItem?.id == component.storyItem?.id, component.isChannel {
                transition = transition.withAnimation(.curve(duration: 0.3, curve: .spring))
            }

            self.component = component
            self.state = state
            
            if let initialText = component.externalState.initialText {
                component.externalState.initialText = nil
                self.textFieldExternalState.initialText = initialText
            }

            let hasMediaRecording = component.audioRecorder != nil || (component.videoRecordingStatus != nil && !component.hasRecordedVideoPreview)
            let hasMediaEditing = component.recordedAudioPreview != nil || component.hasRecordedVideoPreview
            
            let topGradientHeight: CGFloat = 32.0
            if self.gradientView.image == nil {
                let baseAlpha: CGFloat = 0.7
                
                self.gradientView.image = generateImage(CGSize(width: insets.left + insets.right + baseFieldHeight, height: topGradientHeight + insets.top + baseFieldHeight + insets.bottom), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    var locations: [CGFloat] = []
                    var colors: [CGColor] = []
                    let numStops = 10
                    for i in 0 ..< numStops {
                        let step = 1.0 - CGFloat(i) / CGFloat(numStops - 1)
                        locations.append((1.0 - step))
                        let alphaStep: CGFloat = pow(step, 1.5)
                        colors.append(UIColor.black.withAlphaComponent(alphaStep * baseAlpha).cgColor)
                    }
                    
                    if let gradient = CGGradient(colorsSpace: context.colorSpace, colors: colors as CFArray, locations: &locations) {
                        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: size.height), end: CGPoint(x: 0.0, y: 0.0), options: CGGradientDrawingOptions())
                    }
                    
                    context.setBlendMode(.copy)
                    context.setFillColor(UIColor.clear.cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: insets.left, y: topGradientHeight + insets.top), size: CGSize(width: baseFieldHeight, height: baseFieldHeight)).insetBy(dx: 3.0, dy: 3.0))
                })?.resizableImage(withCapInsets: UIEdgeInsets(top: topGradientHeight + insets.top + baseFieldHeight * 0.5, left: insets.left + baseFieldHeight * 0.5, bottom: insets.bottom + baseFieldHeight * 0.5, right: insets.right + baseFieldHeight * 0.5))
                
                self.bottomGradientView.backgroundColor = UIColor.black.withAlphaComponent(baseAlpha)
            }
            
            let availableTextFieldSize = CGSize(width: availableSize.width - insets.left - insets.right, height: availableSize.height - insets.top - insets.bottom)
            
            self.textField.parentState = state
            let textFieldSize = self.textField.update(
                transition: .immediate,
                component: AnyComponent(TextFieldComponent(
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    externalState: self.textFieldExternalState,
                    fontSize: 17.0,
                    textColor: UIColor(rgb: 0xffffff),
                    accentColor: UIColor(rgb: 0xffffff),
                    insets: UIEdgeInsets(top: 9.0, left: 8.0, bottom: 10.0, right: 48.0),
                    hideKeyboard: component.hideKeyboard,
                    customInputView: component.customInputView,
                    resetText: component.resetInputContents.flatMap { resetInputContents in
                        switch resetInputContents {
                        case let .text(value):
                            return value
                        }
                    },
                    isOneLineWhenUnfocused: component.style == .media,
                    formatMenuAvailability: component.isFormattingLocked ? .locked : .available(TextFieldComponent.FormatMenuAvailability.Action.all),
                    lockedFormatAction: {
                        component.presentTextFormattingTooltip?()
                    },
                    present: { c in
                        component.presentController(c)
                    },
                    paste: { data in
                        component.paste(data)
                    }
                )),
                environment: {},
                containerSize: availableTextFieldSize
            )
            let isEditing = self.textFieldExternalState.isEditing || component.forceIsEditing
            
            let placeholderTransition: ComponentTransition = (previousPlaceholder != nil && previousPlaceholder != component.placeholder) ? ComponentTransition(animation: .curve(duration: 0.3, curve: .spring)) : .immediate
            let placeholderSize: CGSize
            if case let .plain(string) = component.placeholder, string.contains("#") {
                let attributedPlaceholder = NSMutableAttributedString(string: string, font:Font.regular(17.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.4))
                if let range = attributedPlaceholder.string.range(of: "#") {
                    attributedPlaceholder.addAttribute(.attachment, value: PresentationResourcesChat.chatPlaceholderStarIcon(component.theme)!, range: NSRange(range, in: attributedPlaceholder.string))
                    attributedPlaceholder.addAttribute(.foregroundColor, value: UIColor(rgb: 0xffffff, alpha: 0.4), range: NSRange(range, in: attributedPlaceholder.string))
                    attributedPlaceholder.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: attributedPlaceholder.string))
                }
                
                placeholderSize = self.placeholder.update(
                    transition: placeholderTransition,
                    component: AnyComponent(MultilineTextComponent(text: .plain(attributedPlaceholder))),
                    environment: {},
                    containerSize: availableTextFieldSize
                )
                
                let vibrancyAttributedPlaceholder = NSMutableAttributedString(string: string, font:Font.regular(17.0), textColor: UIColor.black)
                if let range = vibrancyAttributedPlaceholder.string.range(of: "#") {
                    vibrancyAttributedPlaceholder.addAttribute(.attachment, value: PresentationResourcesChat.chatPlaceholderStarIcon(component.theme)!, range: NSRange(range, in: vibrancyAttributedPlaceholder.string))
                    vibrancyAttributedPlaceholder.addAttribute(.foregroundColor, value: UIColor.black, range: NSRange(range, in: vibrancyAttributedPlaceholder.string))
                    vibrancyAttributedPlaceholder.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: vibrancyAttributedPlaceholder.string))
                }
                
                let _ = self.vibrancyPlaceholder.update(
                    transition: placeholderTransition,
                    component: AnyComponent(MultilineTextComponent(text: .plain(attributedPlaceholder))),
                    environment: {},
                    containerSize: availableTextFieldSize
                )
            } else {
                var placeholderItems: [AnimatedTextComponent.Item] = []
                switch component.placeholder {
                case let .plain(string):
                    placeholderItems.append(AnimatedTextComponent.Item(id: AnyHashable(0 as Int), content: .text(string)))
                case let .counter(items):
                    for item in items {
                        switch item.content {
                        case let .text(string):
                            placeholderItems.append(AnimatedTextComponent.Item(id: AnyHashable(item.id), content: .text(string)))
                        case let .number(value, minDigits):
                            placeholderItems.append(AnimatedTextComponent.Item(id: AnyHashable(item.id), content: .number(value, minDigits: minDigits)))
                        }
                    }
                }
                
                placeholderSize = self.placeholder.update(
                    transition: placeholderTransition,
                    component: AnyComponent(AnimatedTextComponent(
                        font: Font.regular(17.0),
                        color: UIColor(rgb: 0xffffff, alpha: 0.4),
                        items: placeholderItems
                    )),
                    environment: {},
                    containerSize: availableTextFieldSize
                )
                
                let _ = self.vibrancyPlaceholder.update(
                    transition: placeholderTransition,
                    component: AnyComponent(AnimatedTextComponent(
                        font: Font.regular(17.0),
                        color: .black,
                        items: placeholderItems
                    )),
                    environment: {},
                    containerSize: availableTextFieldSize
                )
            }
            
            if !isEditing && component.setMediaRecordingActive == nil {
                insets.right = defaultInsets.left
            }
            if component.attachmentButtonMode != .attach && !isEditing && !self.textFieldExternalState.hasText {
                insets.left = defaultInsets.left
            }
            
            var headerHeight: CGFloat = 0.0
            if let headerComponent = component.header, !hasMediaRecording && !hasMediaEditing {
                let headerInset: CGFloat = 10.0
                let header: ComponentView<Empty>
                var headerTransition = transition
                if let current = self.header {
                    header = current
                } else {
                    headerTransition = .immediate
                    header = ComponentView()
                    self.header = header
                }
                let headerSize = header.update(
                    transition: .immediate,
                    component: headerComponent,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - insets.left - insets.right - headerInset * 2.0, height: 100.0)
                )
                let headerFrame = CGRect(origin: CGPoint(x: insets.left + headerInset, y: insets.top + headerInset), size: headerSize)
                if let headerView = header.view {
                    if let headerView = headerView as? ForwardInfoPanelComponent.View {
                        if headerView.superview == nil {
                            self.addSubview(headerView)
                            self.mediaRecordingVibrancyContainer.addSubview(headerView.backgroundView)
                            
                            headerView.backgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
                        }
                        headerView.backgroundView.frame = headerFrame.offsetBy(dx: -9.0, dy: -14.0)
                    } else {
                        if headerView.superview == nil {
                            self.addSubview(headerView)
                        }
                    }
                    headerTransition.setPosition(view: headerView, position: headerFrame.center)
                    headerView.bounds = CGRect(origin: CGPoint(), size: headerFrame.size)
                }
                headerHeight = headerFrame.height + headerInset
            } else {
                if let header = self.header {
                    self.header = nil
                    if let headerView = header.view as? ForwardInfoPanelComponent.View {
                        headerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                            headerView.removeFromSuperview()
                        })
                        headerView.backgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                            headerView.backgroundView.removeFromSuperview()
                        })
                    } else {
                        header.view?.removeFromSuperview()
                    }
                }
            }
            
            var fieldFrame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: CGSize(width: availableSize.width - insets.left - insets.right, height: textFieldSize.height))
            if hasMediaRecording || hasMediaEditing {
                fieldFrame.size.height = baseFieldHeight
            }
            
            var fieldBackgroundFrame: CGRect
            if hasMediaRecording {
                fieldBackgroundFrame = CGRect(origin: CGPoint(x: mediaInsets.left, y: insets.top), size: CGSize(width: availableSize.width - mediaInsets.left - mediaInsets.right, height: fieldFrame.height))
            } else if isEditing || component.style == .editor || component.style == .media {
                fieldBackgroundFrame = fieldFrame
            } else {
                if component.forwardAction != nil && component.likeAction != nil {
                    fieldBackgroundFrame = CGRect(origin: CGPoint(x: mediaInsets.left, y: insets.top), size: CGSize(width: availableSize.width - mediaInsets.left - insets.right - 49.0, height: textFieldSize.height))
                } else if component.forwardAction != nil {
                    fieldBackgroundFrame = CGRect(origin: CGPoint(x: mediaInsets.left, y: insets.top), size: CGSize(width: availableSize.width - mediaInsets.left - insets.right, height: textFieldSize.height))
                } else {
                    fieldBackgroundFrame = CGRect(origin: CGPoint(x: mediaInsets.left, y: insets.top), size: CGSize(width: availableSize.width - mediaInsets.left - 50.0, height: textFieldSize.height))
                }
            }
            
            let rawFieldBackgroundFrame = fieldBackgroundFrame
            fieldBackgroundFrame.size.height += headerHeight
                        
            //transition.setFrame(view: self.vibrancyEffectView, frame: CGRect(origin: CGPoint(), size: fieldBackgroundFrame.size))
            
            transition.setFrame(view: self.fieldBackgroundView, frame: fieldBackgroundFrame)
            self.fieldBackgroundView.update(size: fieldBackgroundFrame.size, cornerRadius: headerHeight > 0.0 ? 18.0 : baseFieldHeight * 0.5, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.fieldBackgroundTint, frame: fieldBackgroundFrame)
            transition.setFrame(view: self.mediaRecordingVibrancyContainer, frame: CGRect(origin: CGPoint(), size: fieldBackgroundFrame.size))
            
            //self.fieldBackgroundTint.backgroundColor = .blue
            transition.setCornerRadius(layer: self.fieldBackgroundTint.layer, cornerRadius: headerHeight > 0.0 ? 18.0 : baseFieldHeight * 0.5)
            
            var textClippingFrame = rawFieldBackgroundFrame.offsetBy(dx: 0.0, dy: headerHeight)
            if component.style == .media, !isEditing {
                textClippingFrame.size.height -= 10.0
            }
            transition.setFrame(view: self.textClippingView, frame: textClippingFrame)
            
            let gradientFrame = CGRect(origin: CGPoint(x: fieldBackgroundFrame.minX - fieldFrame.minX, y: -topGradientHeight), size: CGSize(width: availableSize.width - (fieldBackgroundFrame.minX - fieldFrame.minX), height: topGradientHeight + fieldBackgroundFrame.maxY + insets.bottom))
            transition.setFrame(view: self.gradientView, frame: gradientFrame)
            transition.setFrame(view: self.bottomGradientView, frame: CGRect(origin: CGPoint(x: 0.0, y: gradientFrame.maxY), size: CGSize(width: availableSize.width, height: component.bottomInset)))
            transition.setAlpha(view: self.gradientView, alpha: component.displayGradient ? 1.0 : 0.0)
            transition.setAlpha(view: self.bottomGradientView, alpha: component.displayGradient ? 1.0 : 0.0)

            let placeholderOriginX: CGFloat
            if isEditing || component.style == .story {
                placeholderOriginX = 16.0
            } else {
                placeholderOriginX = floorToScreenPixels(fieldBackgroundFrame.minX + (fieldBackgroundFrame.width - placeholderSize.width) / 2.0)
            }
            let placeholderFrame = CGRect(origin: CGPoint(x: placeholderOriginX, y: headerHeight + floor((rawFieldBackgroundFrame.height - placeholderSize.height) * 0.5)), size: placeholderSize)
            if let placeholderView = self.placeholder.view, let vibrancyPlaceholderView = self.vibrancyPlaceholder.view {
                if vibrancyPlaceholderView.superview == nil {
                    vibrancyPlaceholderView.layer.anchorPoint = CGPoint()
                    self.mediaRecordingVibrancyContainer.addSubview(vibrancyPlaceholderView)
                    
                    vibrancyPlaceholderView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
                }
                transition.setPosition(view: vibrancyPlaceholderView, position: placeholderFrame.origin)
                vibrancyPlaceholderView.bounds = CGRect(origin: CGPoint(), size: placeholderFrame.size)
                
                if placeholderView.superview == nil {
                    placeholderView.isUserInteractionEnabled = false
                    placeholderView.layer.anchorPoint = CGPoint()
                    self.addSubview(placeholderView)
                }
                transition.setPosition(view: placeholderView, position: placeholderFrame.origin.offsetBy(dx: self.fieldBackgroundView.frame.minX, dy: self.fieldBackgroundView.frame.minY))
                placeholderView.bounds = CGRect(origin: CGPoint(), size: placeholderFrame.size)
                
                transition.setAlpha(view: placeholderView, alpha: (hasMediaRecording || hasMediaEditing || component.disabledPlaceholder != nil || component.isChannel) ? 0.0 : 1.0)
                transition.setAlpha(view: vibrancyPlaceholderView, alpha: (hasMediaRecording || hasMediaEditing || component.disabledPlaceholder != nil || component.isChannel) || sharedIsReduceTransparencyEnabled ? 0.0 : 1.0)
            }
            
            let fieldAlpha = sharedIsReduceTransparencyEnabled ? 0.09 : 1.0
            transition.setAlpha(view: self.fieldBackgroundView, alpha: (component.disabledPlaceholder != nil || component.isChannel) ? 0.0 : fieldAlpha)
            
            var size = CGSize(width: availableSize.width, height: textFieldSize.height + insets.top + insets.bottom + headerHeight)
            if hasMediaRecording || hasMediaEditing {
                size.height = baseFieldHeight + insets.top + insets.bottom
            }
            
            var rightButtonsOffsetX: CGFloat = 0.0
            if component.isChannel, let storyItem = component.storyItem {
                var viewsTransition = transition
                
                let viewsIconView: UIImageView
                if let current = self.viewsIconView {
                    viewsIconView = current
                } else {
                    viewsTransition = viewsTransition.withAnimation(.none)
                    viewsIconView = UIImageView(image: UIImage(bundleImageName: "Stories/EmbeddedViewIcon"))
                    self.viewsIconView = viewsIconView
                    self.addSubview(viewsIconView)
                }
                
                let viewStatsCountText: AnimatedCountLabelView
                if let current = self.viewStatsCountText {
                    viewStatsCountText = current
                } else {
                    viewStatsCountText = AnimatedCountLabelView(frame: CGRect())
                    self.viewStatsCountText = viewStatsCountText
                    self.addSubview(viewStatsCountText)
                }
                
                let reactionStatsCountText: AnimatedCountLabelView
                if let current = self.reactionStatsCountText {
                    reactionStatsCountText = current
                } else {
                    reactionStatsCountText = AnimatedCountLabelView(frame: CGRect())
                    self.reactionStatsCountText = reactionStatsCountText
                    self.addSubview(reactionStatsCountText)
                }
                
                var viewCount = storyItem.views?.seenCount ?? 0
                if viewCount == 0 {
                    viewCount = 1
                }
                var reactionCount = storyItem.views?.reactedCount ?? 0
                if reactionCount == 0, storyItem.myReaction != nil {
                    reactionCount += 1
                }
                
                var regularSegments: [AnimatedCountLabelView.Segment] = []
                regularSegments.append(.number(viewCount, NSAttributedString(string: "\(viewCount)", font: Font.with(size: 15.0, traits: .monospacedNumbers), textColor: .white)))
                
                var reactionSegments: [AnimatedCountLabelView.Segment] = []
                reactionSegments.append(.number(reactionCount, NSAttributedString(string: "\(reactionCount)", font: Font.with(size: 15.0, traits: .monospacedNumbers), textColor: .white)))
                
                let viewStatsTextLayout = viewStatsCountText.update(size: CGSize(width: availableSize.width, height: size.height), segments: regularSegments, transition: viewsTransition.containedViewLayoutTransition)
                let reactionStatsTextLayout = reactionStatsCountText.update(size: CGSize(width: availableSize.width, height: size.height), segments: reactionSegments, transition: viewsTransition.containedViewLayoutTransition)
                
                var contentX: CGFloat = 16.0
                
                if let image = viewsIconView.image {
                    let viewsIconFrame = CGRect(origin: CGPoint(x: contentX, y: size.height - insets.bottom - baseFieldHeight + floor((baseFieldHeight - image.size.height) * 0.5)), size: image.size)
                    viewsTransition.setPosition(view: viewsIconView, position: viewsIconFrame.center)
                    viewsTransition.setBounds(view: viewsIconView, bounds: CGRect(origin: CGPoint(), size: viewsIconFrame.size))
                    
                    contentX += image.size.width + 5.0
                }
                
                transition.setFrame(view: viewStatsCountText, frame: CGRect(origin: CGPoint(x: contentX, y: size.height - insets.bottom - baseFieldHeight + floor((baseFieldHeight - viewStatsTextLayout.size.height) * 0.5)), size: viewStatsTextLayout.size))
                
                transition.setFrame(view: reactionStatsCountText, frame: CGRect(origin: CGPoint(x: availableSize.width - 11.0 - reactionStatsTextLayout.size.width, y: size.height - insets.bottom - baseFieldHeight + floor((baseFieldHeight - reactionStatsTextLayout.size.height) * 0.5)), size: reactionStatsTextLayout.size))
                
                rightButtonsOffsetX -= reactionStatsTextLayout.size.width + 4.0
            } else {
                if let viewsIconView = self.viewsIconView {
                    self.viewsIconView = nil
                    viewsIconView.removeFromSuperview()
                }
                if let viewStatsCountText = self.viewStatsCountText {
                    self.viewStatsCountText = nil
                    viewStatsCountText.removeFromSuperview()
                }
                if let reactionStatsCountText = self.reactionStatsCountText {
                    self.reactionStatsCountText = nil
                    reactionStatsCountText.removeFromSuperview()
                }
            }
            
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                if textFieldView.superview == nil {
                    self.textClippingView.addSubview(textFieldView)
                    
                    if let viewForOverlayContent = self.viewForOverlayContent {
                        self.addSubview(viewForOverlayContent)
                    }
                    
                    if let pendingSetMessageInput = self.pendingSetMessageInput {
                        self.pendingSetMessageInput = nil
                        switch pendingSetMessageInput {
                        case let .text(text):
                            textFieldView.setAttributedText(text, updateState: false)
                        }
                    }
                }
                let textFieldFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: textFieldSize)
                transition.setFrame(view: textFieldView, frame: textFieldFrame)
                transition.setAlpha(view: textFieldView, alpha: (hasMediaRecording || hasMediaEditing || component.disabledPlaceholder != nil || component.isChannel) ? 0.0 : 1.0)
                
                if let viewForOverlayContent = self.viewForOverlayContent {
                    transition.setFrame(view: viewForOverlayContent, frame: textFieldFrame)
                }
            }
            
            if let disabledPlaceholderValue = component.disabledPlaceholder, !component.isChannel {
                let disabledPlaceholder: ComponentView<Empty>
                var disabledPlaceholderTransition = transition
                if let current = self.disabledPlaceholder, let previous = previousComponent?.disabledPlaceholder, disabledPlaceholderValue.kind == previous.kind {
                    disabledPlaceholder = current
                } else {
                    self.disabledPlaceholder?.view?.removeFromSuperview()
                    
                    disabledPlaceholderTransition = .immediate
                    disabledPlaceholder = ComponentView()
                    self.disabledPlaceholder = disabledPlaceholder
                }
                
                let contents: AnyComponent<Empty>
                var leftAlignment = false
                switch disabledPlaceholderValue {
                case let .text(text):
                    contents = AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: text, font: Font.regular(17.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.3)))
                    ))
                case let .premiumRequired(title, subtitle, action), let .boostRequired(title, subtitle, action):
                    leftAlignment = true
                    
                    let text = NSMutableAttributedString(attributedString: NSAttributedString())
                    text.append(NSAttributedString(string: "\(title) ", font: Font.regular(13.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.3)))
                    text.append(NSAttributedString(string: subtitle, font: Font.regular(13.0), textColor: component.theme.list.itemAccentColor))
                    
                    contents = AnyComponent(PlainButtonComponent(
                        content: AnyComponent(MultilineTextComponent(
                            text: .plain(text),
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.1
                        )),
                        effectAlignment: .center,
                        action: {
                            action()
                        }
                    ))
                }
                
                let disabledPlaceholderSize = disabledPlaceholder.update(
                    transition: .immediate,
                    component: contents,
                    environment: {},
                    containerSize: CGSize(width: fieldBackgroundFrame.width - 8.0 * 2.0, height: 100.0)
                )
                let disabledPlaceholderFrame: CGRect
                if leftAlignment {
                    disabledPlaceholderFrame = CGRect(origin: CGPoint(x: 12.0, y: fieldBackgroundFrame.minY + floor((fieldBackgroundFrame.height - disabledPlaceholderSize.height) * 0.5)), size: disabledPlaceholderSize)
                } else {
                    disabledPlaceholderFrame = CGRect(origin: CGPoint(x: fieldBackgroundFrame.minX + floor((fieldBackgroundFrame.width - disabledPlaceholderSize.width) * 0.5), y: fieldBackgroundFrame.minY + floor((fieldBackgroundFrame.height - disabledPlaceholderSize.height) * 0.5)), size: disabledPlaceholderSize)
                }
                if let disabledPlaceholderView = disabledPlaceholder.view {
                    if disabledPlaceholderView.superview == nil {
                        self.addSubview(disabledPlaceholderView)
                    }
                    disabledPlaceholderTransition.setPosition(view: disabledPlaceholderView, position: disabledPlaceholderFrame.center)
                    disabledPlaceholderView.bounds = CGRect(origin: CGPoint(), size: disabledPlaceholderFrame.size)
                }
            } else {
                if let disabledPlaceholder = self.disabledPlaceholder {
                    self.disabledPlaceholder = nil
                    disabledPlaceholder.view?.removeFromSuperview()
                }
            }
            
            if let maxLength = component.maxLength, maxLength - self.textFieldExternalState.textLength < 5 && isEditing {
                let remainingLength = max(-999, maxLength - self.textFieldExternalState.textLength)
                let counterSize = self.counter.update(
                    transition: .immediate,
                    component: AnyComponent(Text(
                        text: "\(remainingLength)",
                        font: Font.with(size: 14.0, traits: .monospacedNumbers),
                        color: self.textFieldExternalState.textLength > maxLength ? UIColor(rgb: 0xff3b30) : UIColor(rgb: 0xffffff, alpha: 0.25)
                    )),
                    environment: {},
                    containerSize: availableTextFieldSize
                )
                let counterFrame = CGRect(origin: CGPoint(x: availableSize.width - insets.right + floorToScreenPixels((insets.right - counterSize.width) * 0.5), y: size.height - insets.bottom - baseFieldHeight - counterSize.height - 5.0), size: counterSize)
                if let counterView = self.counter.view {
                    if counterView.superview == nil {
                        self.addSubview(counterView)
                        counterView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        
                        counterView.center = counterFrame.center
                    } else {
                        transition.setPosition(view: counterView, position: counterFrame.center)
                    }
                    counterView.bounds = CGRect(origin: .zero, size: counterFrame.size)
                }
            } else if let counterView = self.counter.view, counterView.superview != nil {
                counterView.layer.animateAlpha(from: 1.00, to: 0.0, duration: 0.2, completion: { _ in
                    counterView.removeFromSuperview()
                })
            }
            
            if component.attachmentAction != nil {
                let attachmentButtonMode: MessageInputActionButtonComponent.Mode
        
                var attachmentVisible = isEditing || self.textFieldExternalState.hasText
                switch component.attachmentButtonMode {
                case .captionUp:
                    attachmentButtonMode = .captionUp
                case .captionDown:
                    attachmentButtonMode = .captionDown
                default:
                    attachmentButtonMode = .attach
                    attachmentVisible = !(hasMediaRecording || hasMediaEditing || !isEditing)
                }
                
                if attachmentButtonMode == .captionUp && !self.didDisplayCaptionPositionTooltip && self.textFieldExternalState.textLength > 3 {
                    self.didDisplayCaptionPositionTooltip = true
                    if let sourceView = self.attachmentButton.view {
                        component.presentCaptionPositionTooltip?(sourceView)
                    }
                }
                
                let attachmentButtonSize = self.attachmentButton.update(
                    transition: transition,
                    component: AnyComponent(MessageInputActionButtonComponent(
                        mode: attachmentButtonMode,
                        storyId: component.storyItem?.id,
                        action: { [weak self] mode, action, sendAction in
                            guard let self, let component = self.component, case .up = action else {
                                return
                            }
                            
                            switch mode {
                            case .delete:
                                break
                            case .attach, .captionUp, .captionDown:
                                component.attachmentAction?()
                            default:
                                break
                            }
                        },
                        longPressAction: nil,
                        switchMediaInputMode: {
                        },
                        updateMediaCancelFraction: { _ in
                        },
                        lockMediaRecording: {
                        },
                        stopAndPreviewMediaRecording: {
                        },
                        moreAction: { [weak self] view, gesture in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.moreAction?(view, gesture)
                        },
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        presentController: component.presentController,
                        audioRecorder: nil,
                        videoRecordingStatus: nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: 33.0, height: baseFieldHeight)
                )
                if let attachmentButtonView = self.attachmentButton.view {
                    if attachmentButtonView.superview == nil {
                        self.addSubview(attachmentButtonView)
                    }
                    var attachmentButtonPosition = floor((baseFieldHeight - attachmentButtonSize.height) * 0.5)
                    if layoutFromTop {
                        attachmentButtonPosition += 14.0
                    } else {
                        attachmentButtonPosition = size.height - insets.bottom - baseFieldHeight + attachmentButtonPosition
                    }
                    let attachmentButtonFrame = CGRect(origin: CGPoint(x: floor((insets.left - attachmentButtonSize.width) * 0.5) + (fieldBackgroundFrame.minX - fieldFrame.minX), y: attachmentButtonPosition), size: attachmentButtonSize)
                    transition.setPosition(view: attachmentButtonView, position: attachmentButtonFrame.center)
                    transition.setBounds(view: attachmentButtonView, bounds: CGRect(origin: CGPoint(), size: attachmentButtonFrame.size))
                    transition.setAlpha(view: attachmentButtonView, alpha: attachmentVisible ? 1.0 : 0.0)
                    transition.setScale(view: attachmentButtonView, scale: hasMediaEditing ? 0.001 : 1.0)
                }
            }
            
            if hasMediaEditing {
                let deleteMediaPreviewButton: ComponentView<Empty>
                var deleteMediaPreviewButtonTransition = transition
                if let current = self.deleteMediaPreviewButton {
                    deleteMediaPreviewButton = current
                } else {
                    if !transition.animation.isImmediate {
                        deleteMediaPreviewButtonTransition = .immediate
                    }
                    deleteMediaPreviewButton = ComponentView()
                    self.deleteMediaPreviewButton = deleteMediaPreviewButton
                }
                let buttonSize = CGSize(width: 40.0, height: 40.0)
                let deleteMediaPreviewButtonFrame = CGRect(origin: CGPoint(x: 1.0 + (fieldBackgroundFrame.minX - fieldFrame.minX), y: 3.0 + floor((size.height - buttonSize.height) * 0.5)), size: CGSize(width: buttonSize.width, height: buttonSize.height))
                let _ = deleteMediaPreviewButton.update(
                    transition: deleteMediaPreviewButtonTransition,
                    component: AnyComponent(Button(
                        content: AnyComponent(LottieComponent(
                            content: LottieComponent.AppBundleContent(name: "BinBlue"),
                            color: .white,
                            startingPosition: .begin
                        )),
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.discardMediaRecordingPreview?()
                        }
                    ).minSize(buttonSize)),
                    environment: {},
                    containerSize: buttonSize
                )
                if let deleteMediaPreviewButtonView = deleteMediaPreviewButton.view {
                    if deleteMediaPreviewButtonView.superview == nil {
                        self.addSubview(deleteMediaPreviewButtonView)
                        transition.animateAlpha(view: deleteMediaPreviewButtonView, from: 0.0, to: 1.0)
                        transition.animatePosition(view: deleteMediaPreviewButtonView, from: CGPoint(x: mediaInsets.left - insets.left, y: 0.0), to: CGPoint(), additive: true)
                    }
                    deleteMediaPreviewButtonTransition.setFrame(view: deleteMediaPreviewButtonView, frame: deleteMediaPreviewButtonFrame)
                }
            } else if let deleteMediaPreviewButton = self.deleteMediaPreviewButton {
                self.deleteMediaPreviewButton = nil
                if let deleteMediaPreviewButtonView = deleteMediaPreviewButton.view {
                    if component.wasRecordingDismissed, let deleteMediaPreviewButtonView = deleteMediaPreviewButtonView as? Button.View, let animationView = deleteMediaPreviewButtonView.content as? LottieComponent.View {
                        if let attachmentButtonView = self.attachmentButton.view {
                            attachmentButtonView.isHidden = true
                        }
                        animationView.playOnce(completion: { [weak self, weak deleteMediaPreviewButtonView] in
                            guard let self, let deleteMediaPreviewButtonView else {
                                return
                            }
                            let transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .spring))
                            transition.setAlpha(view: deleteMediaPreviewButtonView, alpha: 0.0, completion: { [weak deleteMediaPreviewButtonView] _ in
                                deleteMediaPreviewButtonView?.removeFromSuperview()
                            })
                            transition.setScale(view: deleteMediaPreviewButtonView, scale: 0.001)
                            
                            if let attachmentButtonView = self.attachmentButton.view {
                                attachmentButtonView.isHidden = false
                                
                                transition.animateAlpha(view: attachmentButtonView, from: 0.0, to: attachmentButtonView.alpha)
                                transition.animateScale(view: attachmentButtonView, from: 0.001, to: 1.0)
                            }
                        })
                    } else {
                        transition.setAlpha(view: deleteMediaPreviewButtonView, alpha: 0.0, completion: { [weak deleteMediaPreviewButtonView] _ in
                            deleteMediaPreviewButtonView?.removeFromSuperview()
                        })
                        transition.setScale(view: deleteMediaPreviewButtonView, scale: 0.001)
                    }
                }
            }
            
            var inputActionButtonAlpha = 1.0
            let inputActionButtonMode: MessageInputActionButtonComponent.Mode
            if case .editor = component.style {
                if isEditing {
                    inputActionButtonMode = .apply
                } else {
                    inputActionButtonMode = component.hasRecordedVideo ? .removeVideoInput : .videoInput
                }
            } else if case .media = component.style {
                inputActionButtonMode = .apply
                if !isEditing {
                    inputActionButtonAlpha = 0.0
                }
            } else {
                if hasMediaEditing {
                    inputActionButtonMode = .send
                } else {
                    if self.textFieldExternalState.hasText {
                        if let sendPaidMessageStars = component.sendPaidMessageStars, "".isEmpty {
                            inputActionButtonMode = .stars(sendPaidMessageStars.value)
                        } else {
                            inputActionButtonMode = .send
                        }
                    } else if !isEditing && component.forwardAction != nil {
                        inputActionButtonMode = .forward
                    } else {
                        if component.areVoiceMessagesAvailable {
                            inputActionButtonMode = self.currentMediaInputIsVoice ? .voiceInput : .videoInput
                        } else {
                            inputActionButtonMode = .unavailableVoiceInput
                        }
                    }
                }
            }
            let inputActionButtonSize = self.inputActionButton.update(
                transition: transition,
                component: AnyComponent(MessageInputActionButtonComponent(
                    mode: inputActionButtonMode,
                    storyId: component.storyItem?.id,
                    action: { [weak self] mode, action, sendAction in
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        switch mode {
                        case .none:
                            break
                        case .send, .stars:
                            if case .up = action {
                                if component.recordedAudioPreview != nil {
                                    component.sendMessageAction()
                                } else if component.hasRecordedVideoPreview {
                                    component.sendMessageAction()
                                } else if case let .text(string) = self.getSendMessageInput(), string.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                } else {
                                    if let maxLength = component.maxLength, self.textFieldExternalState.textLength > maxLength {
                                        self.animateError()
                                        component.presentTextLengthLimitTooltip?()
                                    } else {
                                        component.sendMessageAction()
                                    }
                                }
                            }
                        case .apply:
                            if case .up = action {
                                if let maxLength = component.maxLength, self.textFieldExternalState.textLength > maxLength {
                                    self.animateError()
                                    component.presentTextLengthLimitTooltip?()
                                } else {
                                    component.sendMessageAction()
                                }
                            }
                        case .voiceInput, .videoInput:
                            component.setMediaRecordingActive?(action == .down, mode == .videoInput, sendAction, self.inputActionButton.view)
                        case .removeVideoInput:
                            if case .up = action {
                                component.setMediaRecordingActive?(true, true, false, nil)
                            }
                        case .forward:
                            if case .up = action {
                                component.forwardAction?()
                            }
                        case .unavailableVoiceInput:
                            if let view = self.inputActionButton.view {
                                component.presentVoiceMessagesUnavailableTooltip?(view)
                            }
                        default:
                            break
                        }
                    },
                    longPressAction: inputActionButtonMode == .send ? component.sendMessageOptionsAction : nil,
                    switchMediaInputMode: { [weak self] in
                        guard let self else {
                            return
                        }
                        
                        self.currentMediaInputIsVoice = !self.currentMediaInputIsVoice
                        self.hapticFeedback.impact(.medium)
                        self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                    },
                    updateMediaCancelFraction: { [weak self] mediaCancelFraction in
                        guard let self else {
                            return
                        }
                        if self.mediaCancelFraction != mediaCancelFraction {
                            self.mediaCancelFraction = mediaCancelFraction
                            self.state?.updated(transition: .immediate)
                        }
                    },
                    lockMediaRecording: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.lockMediaRecording?()
                    },
                    stopAndPreviewMediaRecording: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.stopAndPreviewMediaRecording?()
                    },
                    moreAction: { _, _ in },
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    presentController: component.presentController,
                    audioRecorder: component.audioRecorder,
                    videoRecordingStatus: component.videoRecordingStatus,
                    hasShadow: component.style == .editor
                )),
                environment: {},
                containerSize: CGSize(width: 33.0, height: 33.0)
            )
            
            let hasLikeAction: Bool
            let displayLikeAction: Bool
            let likeActionReplacesInputAction: Bool
            if component.likeAction == nil {
                hasLikeAction = false
                displayLikeAction = false
                likeActionReplacesInputAction = false
            } else if isEditing {
                hasLikeAction = false
                displayLikeAction = false
                likeActionReplacesInputAction = false
            } else {
                hasLikeAction = component.forwardAction != nil
                likeActionReplacesInputAction = component.forwardAction == nil
                displayLikeAction = true
            }
            
            var inputActionButtonOriginX: CGFloat
            if rightButtonsOffsetX != 0.0 {
                inputActionButtonOriginX = availableSize.width - 3.0 + rightButtonsOffsetX
                if displayLikeAction {
                    inputActionButtonOriginX -= 39.0
                }
                if component.forwardAction != nil {
                    inputActionButtonOriginX -= 46.0
                }
            } else {
                if component.setMediaRecordingActive != nil || isEditing {
                    inputActionButtonOriginX = fieldBackgroundFrame.maxX + floorToScreenPixels((41.0 - inputActionButtonSize.width) * 0.5)
                } else {
                    inputActionButtonOriginX = size.width
                }
                
                if hasLikeAction {
                    inputActionButtonOriginX += 3.0
                }
            }
            
            if let inputActionButtonView = self.inputActionButton.view {
                if inputActionButtonView.superview == nil {
                    self.addSubview(inputActionButtonView)
                }
                var inputActionButtonPosition = floor((baseFieldHeight - inputActionButtonSize.height) * 0.5)
                if layoutFromTop {
                    inputActionButtonPosition += 14.0
                } else {
                    inputActionButtonPosition = size.height - insets.bottom - baseFieldHeight + inputActionButtonPosition
                }
                let inputActionButtonFrame = CGRect(origin: CGPoint(x: inputActionButtonOriginX, y: inputActionButtonPosition), size: inputActionButtonSize)
                transition.setPosition(view: inputActionButtonView, position: inputActionButtonFrame.center)
                transition.setBounds(view: inputActionButtonView, bounds: CGRect(origin: CGPoint(), size: inputActionButtonFrame.size))
                transition.setAlpha(view: inputActionButtonView, alpha: likeActionReplacesInputAction ? 0.0 : inputActionButtonAlpha)
                
                if rightButtonsOffsetX != 0.0 {
                    if hasLikeAction {
                        inputActionButtonOriginX += 46.0
                    }
                } else {
                    if hasLikeAction {
                        inputActionButtonOriginX += 41.0
                    }
                }
            }
            
            let likeButtonSize = self.likeButton.update(
                transition: transition,
                component: AnyComponent(MessageInputActionButtonComponent(
                    mode: .like(reaction: component.myReaction?.reaction, file: component.myReaction?.file, animationFileId: component.myReaction?.animationFileId),
                    storyId: component.storyItem?.id,
                    action: { [weak self] _, action, _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        guard case .up = action else {
                            return
                        }
                        component.likeAction?()
                    },
                    longPressAction: component.likeOptionsAction,
                    switchMediaInputMode: {
                    },
                    updateMediaCancelFraction: { _ in
                    },
                    lockMediaRecording: {
                    },
                    stopAndPreviewMediaRecording: {
                    },
                    moreAction: { _, _ in },
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    presentController: component.presentController,
                    audioRecorder: nil,
                    videoRecordingStatus: nil
                )),
                environment: {},
                containerSize: CGSize(width: 33.0, height: 33.0)
            )
            if let likeButtonView = self.likeButton.view {
                if likeButtonView.superview == nil {
                    self.addSubview(likeButtonView)
                }
                var likeButtonFrame = CGRect(origin: CGPoint(x: inputActionButtonOriginX, y: size.height - insets.bottom - baseFieldHeight + floor((baseFieldHeight - likeButtonSize.height) * 0.5)), size: likeButtonSize)
                if component.forwardAction == nil && rightButtonsOffsetX == 0.0 {
                    likeButtonFrame.origin.x += 3.0
                }
                transition.setPosition(view: likeButtonView, position: likeButtonFrame.center)
                transition.setBounds(view: likeButtonView, bounds: CGRect(origin: CGPoint(), size: likeButtonFrame.size))
                transition.setAlpha(view: likeButtonView, alpha: displayLikeAction ? 1.0 : 0.0)
                inputActionButtonOriginX += 41.0
            }
        
            var fieldIconNextX = fieldBackgroundFrame.maxX - 4.0
            
            var inputModeVisible = false
            if isEditing {
                inputModeVisible = true
            }
            
            let animationName: String
            var animationPlay = false
            
            let previousInputMode = self.currentInputMode
            let inputMode = component.nextInputMode(self.textFieldExternalState.hasText)
            self.currentInputMode = inputMode
            
            if let inputMode {
                self.currentInputMode = inputMode
                switch inputMode {
                case .text:
                    if let previousInputMode {
                        if case .stickers = previousInputMode {
                            animationName = "input_anim_stickerToKey"
                            animationPlay = true
                        } else if case .emoji = previousInputMode {
                            animationName = "input_anim_smileToKey"
                            animationPlay = true
                        } else {
                            animationName = "input_anim_stickerToKey"
                        }
                    } else {
                        animationName = "input_anim_stickerToKey"
                    }
                case .stickers:
                    if let previousInputMode {
                        if case .text = previousInputMode {
                            animationName = "input_anim_keyToSticker"
                            animationPlay = true
                        } else if case .emoji = previousInputMode {
                            animationName = "input_anim_smileToSticker"
                            animationPlay = true
                        } else {
                            animationName = "input_anim_keyToSticker"
                        }
                    } else {
                        animationName = "input_anim_keyToSticker"
                    }
                case .emoji:
                    if let previousInputMode {
                        if case .text = previousInputMode {
                            animationName = "input_anim_keyToSmile"
                            animationPlay = true
                        } else if case .stickers = previousInputMode {
                            animationName = "input_anim_stickerToSmile"
                            animationPlay = true
                        } else {
                            animationName = "input_anim_keyToSmile"
                        }
                    } else {
                        animationName = "input_anim_keyToSmile"
                    }
                }
            } else {
                animationName = ""
            }
            
            let stickerButtonSize = self.stickerButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: animationName),
                        color: .white
                    )),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.component?.inputModeAction?()
                    }
                ).minSize(CGSize(width: 32.0, height: 32.0))),
                environment: {},
                containerSize: CGSize(width: 32.0, height: 32.0)
            )
            if let stickerButtonView = self.stickerButton.view as? Button.View {
                if stickerButtonView.superview == nil {
                    self.addSubview(stickerButtonView)
                }
                let stickerIconFrame = CGRect(origin: CGPoint(x: fieldIconNextX - stickerButtonSize.width, y: fieldBackgroundFrame.maxY - 4.0 - stickerButtonSize.height), size: stickerButtonSize)
                transition.setPosition(view: stickerButtonView, position: stickerIconFrame.center)
                transition.setBounds(view: stickerButtonView, bounds: CGRect(origin: CGPoint(), size: stickerIconFrame.size))
                
                transition.setAlpha(view: stickerButtonView, alpha: (hasMediaRecording || hasMediaEditing || !inputModeVisible || component.disabledPlaceholder != nil) ? 0.0 : 1.0)
                transition.setScale(view: stickerButtonView, scale: (hasMediaRecording || hasMediaEditing || !inputModeVisible) ? 0.1 : 1.0)
                
                if inputModeVisible {
                    fieldIconNextX -= stickerButtonSize.width + 2.0
                    
                    if let animationView = stickerButtonView.content as? LottieComponent.View {
                        if animationPlay {
                            animationView.playOnce()
                        }
                    }
                }
            }
            
            let accentColor = component.theme.chat.inputPanel.panelControlAccentColor
            if let timeoutAction = component.timeoutAction, let timeoutValue = component.timeoutValue {
                let timeoutButtonSize = self.timeoutButton.update(
                    transition: transition,
                    component: AnyComponent(ContextReferenceButtonComponent(
                        content: AnyComponent(
                            TimeoutContentComponent(
                                color: .white,
                                accentColor: accentColor,
                                isSelected: component.timeoutSelected,
                                value: timeoutValue
                            )
                        ),
                        tag: timeoutButtonTag,
                        minSize: CGSize(width: 32.0, height: 32.0),
                        action: { view, gesture in
                            timeoutAction(view, gesture)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: 32.0, height: 32.0)
                )
                if let timeoutButtonView = self.timeoutButton.view {
                    if timeoutButtonView.superview == nil {
                        self.addSubview(timeoutButtonView)
                    }
                    let originX = fieldBackgroundFrame.maxX - 4.0
                    let timeoutIconFrame = CGRect(origin: CGPoint(x: originX - timeoutButtonSize.width, y: fieldBackgroundFrame.maxY - 4.0 - timeoutButtonSize.height), size: timeoutButtonSize)
                    transition.setPosition(view: timeoutButtonView, position: timeoutIconFrame.center)
                    transition.setBounds(view: timeoutButtonView, bounds: CGRect(origin: CGPoint(), size: timeoutIconFrame.size))
                    
                    let visible = !hasMediaRecording && !hasMediaEditing && !isEditing
                    transition.setAlpha(view: timeoutButtonView, alpha: visible ? 1.0 : 0.0)
                    transition.setScale(view: timeoutButtonView, scale: visible ? 1.0 : 0.1)
                }
            }
            
            var lightFieldColor = UIColor(white: 1.0, alpha: 0.09)
            var fieldBackgroundIsDark = false
            if component.useGrayBackground {
                fieldBackgroundIsDark = false
            } else if component.style == .media {
                fieldBackgroundIsDark = false
                lightFieldColor = UIColor(white: 0.2, alpha: 0.45)
            } else if self.textFieldExternalState.hasText && component.alwaysDarkWhenHasText {
                fieldBackgroundIsDark = true
            } else if isEditing || component.style == .story || component.style == .editor {
                fieldBackgroundIsDark = true
            }
            self.fieldBackgroundView.updateColor(color: fieldBackgroundIsDark ? UIColor(white: 0.0, alpha: 0.5) : lightFieldColor, transition: transition.containedViewLayoutTransition)
            if let placeholder = self.placeholder.view, let vibrancyPlaceholderView = self.vibrancyPlaceholder.view {
                placeholder.isHidden = self.textFieldExternalState.hasText
                vibrancyPlaceholderView.isHidden = placeholder.isHidden
            }
            
            component.externalState.isEditing = isEditing
            component.externalState.hasText = self.textFieldExternalState.hasText
            component.externalState.insertText = { [weak self] text in
                if let self, let view = self.textField.view as? TextFieldComponent.View {
                    view.insertText(text)
                }
            }
            component.externalState.deleteBackward = { [weak self] in
                if let self, let view = self.textField.view as? TextFieldComponent.View {
                    view.deleteBackward()
                }
            }
            component.externalState.isKeyboardHidden = component.hideKeyboard
            
            if hasMediaRecording {
                if let dismissingMediaRecordingPanel = self.dismissingMediaRecordingPanel {
                    self.dismissingMediaRecordingPanel = nil
                    transition.setAlpha(view: dismissingMediaRecordingPanel, alpha: 0.0, completion: { [weak dismissingMediaRecordingPanel] _ in
                        dismissingMediaRecordingPanel?.removeFromSuperview()
                    })
                }
                
                let mediaRecordingPanel: ComponentView<Empty>
                var mediaRecordingPanelTransition = transition
                if let current = self.mediaRecordingPanel {
                    mediaRecordingPanel = current
                } else {
                    mediaRecordingPanelTransition = .immediate
                    mediaRecordingPanel = ComponentView()
                    self.mediaRecordingPanel = mediaRecordingPanel
                }
                
                let _ = mediaRecordingPanel.update(
                    transition: mediaRecordingPanelTransition,
                    component: AnyComponent(MediaRecordingPanelComponent(
                        theme: component.theme,
                        strings: component.strings,
                        audioRecorder: component.audioRecorder,
                        videoRecordingStatus: component.videoRecordingStatus,
                        isRecordingLocked: component.isRecordingLocked,
                        cancelFraction: self.mediaCancelFraction,
                        inputInsets: insets,
                        insets: mediaInsets,
                        cancelAction: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.setMediaRecordingActive?(false, false, false, nil)
                        }
                    )),
                    environment: {},
                    containerSize: size
                )
                if let mediaRecordingPanelView = mediaRecordingPanel.view as? MediaRecordingPanelComponent.View {
                    var animateIn = false
                    if mediaRecordingPanelView.superview == nil {
                        animateIn = true
                        self.insertSubview(mediaRecordingPanelView, aboveSubview: self.textClippingView)
                        
                        self.mediaRecordingVibrancyContainer.addSubview(mediaRecordingPanelView.vibrancyContainer)
                    }
                    mediaRecordingPanelTransition.setFrame(view: mediaRecordingPanelView, frame: CGRect(origin: CGPoint(), size: size))
                    mediaRecordingPanelTransition.setFrame(view: self.mediaRecordingVibrancyContainer, frame: CGRect(origin: CGPoint(x: -fieldBackgroundFrame.minX, y: -fieldBackgroundFrame.minY), size: size))
                    
                    if animateIn && !transition.animation.isImmediate {
                        mediaRecordingPanelView.animateIn()
                    }
                }
            } else {
                if let mediaRecordingPanel = self.mediaRecordingPanel {
                    self.mediaRecordingPanel = nil
                    
                    if let dismissingMediaRecordingPanel = self.dismissingMediaRecordingPanel {
                        self.dismissingMediaRecordingPanel = nil
                        transition.setAlpha(view: dismissingMediaRecordingPanel, alpha: 0.0, completion: { [weak dismissingMediaRecordingPanel] _ in
                            dismissingMediaRecordingPanel?.removeFromSuperview()
                        })
                    }
                    
                    self.dismissingMediaRecordingPanel = mediaRecordingPanel.view
                    
                    if let mediaRecordingPanelView = mediaRecordingPanel.view as? MediaRecordingPanelComponent.View {
                        let wasRecordingDismissed = component.wasRecordingDismissed
                        if wasRecordingDismissed, let attachmentButtonView = self.attachmentButton.view {
                            attachmentButtonView.isHidden = true
                        }
                        mediaRecordingPanelView.animateOut(transition: transition, dismissRecording: wasRecordingDismissed, completion: { [weak self, weak mediaRecordingPanelView] in
                            let transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .spring))
                            
                            if let mediaRecordingPanelView = mediaRecordingPanelView {
                                transition.setAlpha(view: mediaRecordingPanelView, alpha: 0.0, completion: { [weak mediaRecordingPanelView] _ in
                                    mediaRecordingPanelView?.removeFromSuperview()
                                })
                            }
                            
                            guard let self else {
                                return
                            }
                            if wasRecordingDismissed, self.mediaRecordingPanel == nil, let attachmentButtonView = self.attachmentButton.view {
                                attachmentButtonView.isHidden = false
                                
                                transition.animateAlpha(view: attachmentButtonView, from: 0.0, to: attachmentButtonView.alpha)
                                transition.animateScale(view: attachmentButtonView, from: 0.001, to: 1.0)
                            }
                        })
                    }
                }
            }
            
            if let recordedAudioPreview = component.recordedAudioPreview {
                let mediaPreviewPanel: ComponentView<Empty>
                var mediaPreviewPanelTransition = transition
                if let current = self.mediaPreviewPanel {
                    mediaPreviewPanel = current
                } else {
                    mediaPreviewPanelTransition = .immediate
                    mediaPreviewPanel = ComponentView()
                    self.mediaPreviewPanel = mediaPreviewPanel
                }
                
                let _ = mediaPreviewPanel.update(
                    transition: mediaPreviewPanelTransition,
                    component: AnyComponent(MediaPreviewPanelComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        mediaPreview: recordedAudioPreview,
                        insets: insets
                    )),
                    environment: {},
                    containerSize: size
                )
                if let mediaPreviewPanelView = mediaPreviewPanel.view as? MediaPreviewPanelComponent.View {
                    var animateIn = false
                    if mediaPreviewPanelView.superview == nil {
                        animateIn = true
                        self.insertSubview(mediaPreviewPanelView, aboveSubview: self.fieldBackgroundView)
                        
                        self.mediaRecordingVibrancyContainer.addSubview(mediaPreviewPanelView.vibrancyContainer)
                    }
                    mediaPreviewPanelTransition.setFrame(view: mediaPreviewPanelView, frame: CGRect(origin: CGPoint(), size: size))
                    mediaPreviewPanelTransition.setFrame(view: self.mediaRecordingVibrancyContainer, frame: CGRect(origin: CGPoint(x: -fieldBackgroundFrame.minX, y: -fieldBackgroundFrame.minY), size: size))
                    
                    if animateIn && !transition.animation.isImmediate {
                        mediaPreviewPanelView.animateIn()
                    }
                }
            } else {
                if let mediaPreviewPanel = self.mediaPreviewPanel {
                    self.mediaPreviewPanel = nil
                    
                    if let mediaPreviewPanelView = mediaPreviewPanel.view as? MediaPreviewPanelComponent.View {
                        mediaPreviewPanelView.animateOut(transition: transition, completion: { [weak mediaPreviewPanelView] in
                            mediaPreviewPanelView?.removeFromSuperview()
                        })
                    }
                }
            }
            
            self.updateContextQueries()
                    
            var panelLeftInset: CGFloat = max(insets.left, 7.0)
            var panelRightInset: CGFloat = max(insets.right, 41.0)
            if case .media = component.style {
                panelLeftInset = 0.0
                panelRightInset = 0.0
            }
            
            var contextResults: ContextResultPanelComponent.Results?
            if let result = self.contextQueryResults[.mention], case let .mentions(mentions) = result, !mentions.isEmpty {
                contextResults = .mentions(mentions)
            } else if let result = self.contextQueryResults[.hashtag], case let .hashtags(hashtags, query) = result, !hashtags.isEmpty || (query.count >= 4 && self.contextQueryPeer != nil) {
                contextResults = .hashtags(self.contextQueryPeer, hashtags, query)
            }
            
            if let result = self.contextQueryResults[.emoji], case let .stickers(stickers) = result, !stickers.isEmpty {
                let availablePanelHeight: CGFloat = 413.0
                
                var animateIn = false
                let panel: ComponentView<Empty>
                var transition = transition
                if let current = self.stickersResultPanel {
                    panel = current
                } else {
                    panel = ComponentView<Empty>()
                    self.stickersResultPanel = panel
                    animateIn = true
                    transition = .immediate
                }
                let panelSize = panel.update(
                    transition: transition,
                    component: AnyComponent(StickersResultPanelComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        files: stickers.map { $0.file },
                        action: { [weak self] sticker in
                            if let self, let textView = self.textField.view as? TextFieldComponent.View {
                                textView.updateText(NSAttributedString(), selectionRange: 0 ..< 0)
                                self.component?.sendStickerAction(sticker)
                            }
                        },
                        present: { [weak self] c in
                            if let self, let component = self.component {
                                component.presentController(c)
                            }
                        },
                        presentInGlobalOverlay: { [weak self] c in
                            if let self, let component = self.component {
                                component.presentInGlobalOverlay(c)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: availablePanelHeight)
                )
                
                let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: -panelSize.height + 60.0), size: panelSize)
                if let panelView = panel.view as? StickersResultPanelComponent.View {
                    if panelView.superview == nil {
                        self.insertSubview(panelView, at: 0)
                    }
                    transition.setFrame(view: panelView, frame: panelFrame)
                    
                    if animateIn {
                        panelView.animateIn(transition: .spring(duration: 0.4))
                    }
                }
            } else if let stickersResultPanel = self.stickersResultPanel?.view as? StickersResultPanelComponent.View {
                self.stickersResultPanel = nil
                stickersResultPanel.animateOut(transition: .spring(duration: 0.4), completion: { [weak stickersResultPanel] in
                    stickersResultPanel?.removeFromSuperview()
                })
            }
            
            if let contextResults, isEditing {
                let availablePanelHeight: CGFloat = 413.0
                
                var animateIn = false
                let panel: ComponentView<Empty>
                var transition = transition
                if let current = self.contextQueryResultPanel {
                    panel = current
                } else {
                    panel = ComponentView<Empty>()
                    self.contextQueryResultPanel = panel
                    animateIn = true
                    transition = .immediate
                }
                let panelSize = panel.update(
                    transition: transition,
                    component: AnyComponent(ContextResultPanelComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        results: contextResults,
                        action: { [weak self] action in
                            if let self, let textView = self.textField.view as? TextFieldComponent.View {
                                let inputState = textView.getInputState()
                                
                                switch action {
                                case let .mention(peer):
                                    var mentionQueryRange: NSRange?
                                    inner: for (range, type, _) in textInputStateContextQueryRangeAndType(inputState: inputState) {
                                        if type == [.mention] {
                                            mentionQueryRange = range
                                            break inner
                                        }
                                    }
                                    
                                    if let range = mentionQueryRange {
                                        let inputText = NSMutableAttributedString(attributedString: inputState.inputText)
                                        if let addressName = peer.addressName, !addressName.isEmpty {
                                            let replacementText = addressName + " "
                                            inputText.replaceCharacters(in: range, with: replacementText)
                                            
                                            let selectionPosition = range.lowerBound + (replacementText as NSString).length
                                            textView.updateText(inputText, selectionRange: selectionPosition ..< selectionPosition)
                                        } else if !peer.compactDisplayTitle.isEmpty {
                                            let replacementText = NSMutableAttributedString()
                                            replacementText.append(NSAttributedString(string: peer.compactDisplayTitle, attributes: [ChatTextInputAttributes.textMention: ChatTextInputTextMentionAttribute(peerId: peer.id)]))
                                            replacementText.append(NSAttributedString(string: " "))
                                            
                                            let updatedRange = NSRange(location: range.location - 1, length: range.length + 1)
                                            inputText.replaceCharacters(in: updatedRange, with: replacementText)
                                            
                                            let selectionPosition = updatedRange.lowerBound + replacementText.length
                                            textView.updateText(inputText, selectionRange: selectionPosition ..< selectionPosition)
                                        }
                                    }
                                case let .hashtag(hashtag):
                                    var hashtagQueryRange: NSRange?
                                    inner: for (range, type, _) in textInputStateContextQueryRangeAndType(inputState: inputState) {
                                        if type == [.hashtag] {
                                            hashtagQueryRange = range
                                            break inner
                                        }
                                    }
                                    
                                    if let range = hashtagQueryRange {
                                        let inputText = NSMutableAttributedString(attributedString: inputState.inputText)
                                        
                                        let replacementText = hashtag
                                        inputText.replaceCharacters(in: range, with: replacementText)
                                        
                                        let selectionPosition = range.lowerBound + (replacementText as NSString).length
                                        textView.updateText(inputText, selectionRange: selectionPosition ..< selectionPosition)
                                    }
                                }
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - panelLeftInset - panelRightInset, height: availablePanelHeight)
                )
                
                var panelOriginY = -panelSize.height + 14.0
                var panelHeight = panelSize.height + 19.0
                if case .media = component.style {
                    panelOriginY -= 6.0
                    panelHeight = panelSize.height
                }
                let panelFrame = CGRect(origin: CGPoint(x: panelLeftInset, y: panelOriginY), size: CGSize(width: panelSize.width, height: panelHeight))
                if let panelView = panel.view as? ContextResultPanelComponent.View {
                    if panelView.superview == nil {
                        self.insertSubview(panelView, at: 0)
                    }
                    transition.setFrame(view: panelView, frame: panelFrame)
                    
                    if animateIn {
                        panelView.animateIn(transition: .spring(duration: 0.4))
                    }
                }
            } else if let contextQueryResultPanel = self.contextQueryResultPanel?.view as? ContextResultPanelComponent.View {
                self.contextQueryResultPanel = nil
                contextQueryResultPanel.animateOut(transition: .spring(duration: 0.4), completion: { [weak contextQueryResultPanel] in
                    contextQueryResultPanel?.removeFromSuperview()
                })
            }
            
            if let emojiSuggestion = self.textFieldExternalState.currentEmojiSuggestion, emojiSuggestion.disposable == nil {
                emojiSuggestion.disposable = (EmojiSuggestionsComponent.suggestionData(context: component.context, isSavedMessages: false, query: emojiSuggestion.position.value)
                |> deliverOnMainQueue).start(next: { [weak self, weak emojiSuggestion] result in
                    guard let self, let emojiSuggestion, self.textFieldExternalState.currentEmojiSuggestion === emojiSuggestion else {
                        return
                    }
                    
                    emojiSuggestion.value = result
                    self.state?.updated()
                })
            }
            
            if let emojiSearch = self.textFieldExternalState.currentEmojiSearch, emojiSearch.disposable == nil {
                emojiSearch.disposable = (EmojiSuggestionsComponent.searchData(context: component.context, isSavedMessages: false, query: emojiSearch.position.value)
                |> deliverOnMainQueue).start(next: { [weak self, weak emojiSearch] result in
                    guard let self, let emojiSearch, self.textFieldExternalState.currentEmojiSearch === emojiSearch else {
                        return
                    }
                    
                    emojiSearch.value = result
                    self.state?.updated()
                })
            }
            
            var hasTrackingView = self.textFieldExternalState.hasTrackingView
            if let currentEmojiSuggestion = self.textFieldExternalState.currentEmojiSuggestion, let value = currentEmojiSuggestion.value as? [TelegramMediaFile], value.isEmpty {
                hasTrackingView = false
            }
            if !self.textFieldExternalState.isEditing {
                hasTrackingView = false
            }
            
            if !hasTrackingView {
                if let currentEmojiSuggestion = self.textFieldExternalState.currentEmojiSuggestion {
                    self.textFieldExternalState.currentEmojiSuggestion = nil
                    currentEmojiSuggestion.disposable?.dispose()
                }
                
                if let currentEmojiSuggestionView = self.currentEmojiSuggestionView {
                    self.currentEmojiSuggestionView = nil
                    
                    currentEmojiSuggestionView.alpha = 0.0
                    currentEmojiSuggestionView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak currentEmojiSuggestionView] _ in
                        currentEmojiSuggestionView?.removeFromSuperview()
                    })
                }
                
                if let currentEmojiSearch = self.textFieldExternalState.currentEmojiSearch {
                    self.textFieldExternalState.currentEmojiSearch = nil
                    currentEmojiSearch.disposable?.dispose()
                }
                
                if let currentEmojiSearchView = self.currentEmojiSearchView {
                    self.currentEmojiSearchView = nil
                    
                    currentEmojiSearchView.alpha = 0.0
                    currentEmojiSearchView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak currentEmojiSearchView] _ in
                        currentEmojiSearchView?.removeFromSuperview()
                    })
                }
            }
            
            if let currentEmojiSuggestion = self.textFieldExternalState.currentEmojiSuggestion, let value = currentEmojiSuggestion.value as? [TelegramMediaFile] {
                let currentEmojiSuggestionView: ComponentHostView<Empty>
                if let current = self.currentEmojiSuggestionView {
                    currentEmojiSuggestionView = current
                } else {
                    currentEmojiSuggestionView = ComponentHostView<Empty>()
                    self.currentEmojiSuggestionView = currentEmojiSuggestionView
                    self.addSubview(currentEmojiSuggestionView)
                    
                    currentEmojiSuggestionView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                }
            
                let globalPosition: CGPoint
                if let textView = self.textField.view {
                    globalPosition = textView.convert(currentEmojiSuggestion.localPosition, to: self)
                } else {
                    globalPosition = .zero
                }
                
                let sideInset: CGFloat = 7.0
                
                let viewSize = currentEmojiSuggestionView.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiSuggestionsComponent(
                        context: component.context,
                        userLocation: .other,
                        theme: EmojiSuggestionsComponent.Theme(
                            backgroundColor: UIColor(white: 0.1, alpha: 1.0),
                            textColor: .white,
                            placeholderColor: UIColor(rgb: 0xffffff).mixedWith(UIColor(rgb: 0x1c1c1d), alpha: 0.9)
                        ),
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        files: value,
                        action: { [weak self] file in
                            guard let self, let textView = self.textField.view as? TextFieldComponent.View, let currentEmojiSuggestion = self.textFieldExternalState.currentEmojiSuggestion else {
                                return
                            }
                            
                            AudioServicesPlaySystemSound(0x450)
                            
                            let inputState = textView.getInputState()
                            let inputText = NSMutableAttributedString(attributedString: inputState.inputText)
                            
                            var text: String?
                            var emojiAttribute: ChatTextInputTextCustomEmojiAttribute?
                            loop: for attribute in file.attributes {
                                switch attribute {
                                case let .CustomEmoji(_, _, displayText, _):
                                    text = displayText
                                    emojiAttribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file)
                                    break loop
                                default:
                                    break
                                }
                            }
                            
                            if let emojiAttribute = emojiAttribute, let text = text {
                                let replacementText = NSAttributedString(string: text, attributes: [ChatTextInputAttributes.customEmoji: emojiAttribute])
                                
                                let range = currentEmojiSuggestion.position.range
                                let previousText = inputText.attributedSubstring(from: range)
                                inputText.replaceCharacters(in: range, with: replacementText)
                                
                                var replacedUpperBound = range.lowerBound
                                while true {
                                    if inputText.attributedSubstring(from: NSRange(location: 0, length: replacedUpperBound)).string.hasSuffix(previousText.string) {
                                        let replaceRange = NSRange(location: replacedUpperBound - previousText.length, length: previousText.length)
                                        if replaceRange.location < 0 {
                                            break
                                        }
                                        let adjacentString = inputText.attributedSubstring(from: replaceRange)
                                        if adjacentString.string != previousText.string || adjacentString.attribute(ChatTextInputAttributes.customEmoji, at: 0, effectiveRange: nil) != nil {
                                            break
                                        }
                                        inputText.replaceCharacters(in: replaceRange, with: NSAttributedString(string: text, attributes: [ChatTextInputAttributes.customEmoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: emojiAttribute.interactivelySelectedFromPackId, fileId: emojiAttribute.fileId, file: emojiAttribute.file)]))
                                        replacedUpperBound = replaceRange.lowerBound
                                    } else {
                                        break
                                    }
                                }
                                
                                let selectionPosition = range.lowerBound + (replacementText.string as NSString).length
                                textView.updateText(inputText, selectionRange: selectionPosition ..< selectionPosition)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: self.bounds.width - panelLeftInset - panelRightInset, height: 100.0)
                )
                
                let viewFrame = CGRect(origin: CGPoint(x: min(self.bounds.width - sideInset - viewSize.width, max(panelLeftInset, floor(globalPosition.x - viewSize.width / 2.0))), y: globalPosition.y - 4.0 - viewSize.height), size: viewSize)
                currentEmojiSuggestionView.frame = viewFrame
                if let componentView = currentEmojiSuggestionView.componentView as? EmojiSuggestionsComponent.View {
                    componentView.adjustBackground(relativePositionX: floor(globalPosition.x - viewFrame.minX))
                }
            }
            
            if let currentEmojiSearch = self.textFieldExternalState.currentEmojiSearch, let value = currentEmojiSearch.value as? [TelegramMediaFile], !value.isEmpty {
                let currentEmojiSearchView: ComponentHostView<Empty>
                if let current = self.currentEmojiSearchView {
                    currentEmojiSearchView = current
                } else {
                    currentEmojiSearchView = ComponentHostView<Empty>()
                    self.currentEmojiSearchView = currentEmojiSearchView
                    self.addSubview(currentEmojiSearchView)
                    
                    currentEmojiSearchView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                }
            
                var globalPosition: CGPoint
                if let textView = self.textField.view {
                    globalPosition = textView.convert(currentEmojiSearch.localPosition, to: self)
                    globalPosition.x += 16.0
                } else {
                    globalPosition = .zero
                }
                
                let sideInset: CGFloat = 7.0
                
                let viewSize = currentEmojiSearchView.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiSuggestionsComponent(
                        context: component.context,
                        userLocation: .other,
                        theme: EmojiSuggestionsComponent.Theme(
                            backgroundColor: UIColor(white: 0.1, alpha: 1.0),
                            textColor: .white,
                            placeholderColor: UIColor(rgb: 0xffffff).mixedWith(UIColor(rgb: 0x1c1c1d), alpha: 0.9)
                        ),
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        files: value,
                        action: { [weak self] file in
                            guard let self, let textView = self.textField.view as? TextFieldComponent.View, let currentEmojiSearch = self.textFieldExternalState.currentEmojiSearch else {
                                return
                            }
                            
                            AudioServicesPlaySystemSound(0x450)
                            
                            let inputState = textView.getInputState()
                            let inputText = NSMutableAttributedString(attributedString: inputState.inputText)
                            
                            var text: String?
                            var emojiAttribute: ChatTextInputTextCustomEmojiAttribute?
                            loop: for attribute in file.attributes {
                                switch attribute {
                                case let .CustomEmoji(_, _, displayText, _):
                                    text = displayText
                                    emojiAttribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file)
                                    break loop
                                default:
                                    break
                                }
                            }
                            
                            if let emojiAttribute = emojiAttribute, let text = text {
                                let replacementText = NSAttributedString(string: text, attributes: [ChatTextInputAttributes.customEmoji: emojiAttribute])
                                
                                var range = currentEmojiSearch.position.range
                                let previousText = inputText.attributedSubstring(from: range)
                                if range.location != 0 && inputText.attributedSubstring(from: NSRange(location: range.location - 1, length: range.length + 1)).string.hasPrefix(":") {
                                    range = NSRange(location: range.location - 1, length: range.length + 1)
                                }
                                inputText.replaceCharacters(in: range, with: replacementText)
                                
                                var replacedUpperBound = range.lowerBound
                                while true {
                                    if inputText.attributedSubstring(from: NSRange(location: 0, length: replacedUpperBound)).string.hasSuffix(previousText.string) {
                                        let replaceRange = NSRange(location: replacedUpperBound - previousText.length, length: previousText.length)
                                        if replaceRange.location < 0 {
                                            break
                                        }
                                        let adjacentString = inputText.attributedSubstring(from: replaceRange)
                                        if adjacentString.string != previousText.string || adjacentString.attribute(ChatTextInputAttributes.customEmoji, at: 0, effectiveRange: nil) != nil {
                                            break
                                        }
                                        inputText.replaceCharacters(in: replaceRange, with: NSAttributedString(string: text, attributes: [ChatTextInputAttributes.customEmoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: emojiAttribute.interactivelySelectedFromPackId, fileId: emojiAttribute.fileId, file: emojiAttribute.file)]))
                                        replacedUpperBound = replaceRange.lowerBound
                                    } else {
                                        break
                                    }
                                }
                                
                                let selectionPosition = range.lowerBound + (replacementText.string as NSString).length
                                textView.updateText(inputText, selectionRange: selectionPosition ..< selectionPosition)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: self.bounds.width - sideInset * 2.0, height: 100.0)
                )
                
                var viewFrame = CGRect(origin: CGPoint(x: globalPosition.x - floor((viewSize.width) * 0.5), y: globalPosition.y - 4.0 - viewSize.height), size: viewSize)
                if viewFrame.origin.x + viewFrame.width > self.bounds.width - sideInset {
                    viewFrame.origin.x = self.bounds.width - sideInset - viewFrame.width
                }
                viewFrame.origin.x = max(viewFrame.origin.x, sideInset)
                
                currentEmojiSearchView.frame = viewFrame
                if let componentView = currentEmojiSearchView.componentView as? EmojiSuggestionsComponent.View {
                    componentView.adjustBackground(relativePositionX: floor(globalPosition.x - viewFrame.minX))
                }
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class ViewForOverlayContent: UIView {
    let ignoreHit: (UIView, CGPoint) -> Bool
    let dismissSuggestions: () -> Void
    
    init(ignoreHit: @escaping (UIView, CGPoint) -> Bool, dismissSuggestions: @escaping () -> Void) {
        self.ignoreHit = ignoreHit
        self.dismissSuggestions = dismissSuggestions
        
        super.init(frame: CGRect())
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    func maybeDismissContent(point: CGPoint) {
        for subview in self.subviews.reversed() {
            if let _ = subview.hitTest(self.convert(point, to: subview), with: nil) {
                return
            }
        }
        
        self.dismissSuggestions()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for subview in self.subviews.reversed() {
            if let result = subview.hitTest(self.convert(point, to: subview), with: event) {
                return result
            }
        }
        
        if event == nil || self.ignoreHit(self, point) {
            return nil
        }
        
        self.dismissSuggestions()
        return nil
    }
}
