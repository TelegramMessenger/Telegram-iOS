import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ComponentFlow
import ChatControllerInteraction
import AccountContext
import ChatPresentationInterfaceState
import TelegramCore
import ComponentDisplayAdapters

private final class EmptyInputView: UIView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool {
        return true
    }
}

public final class ChatTextInputPanelComponent: Component {
    public final class ExternalState {
        public fileprivate(set) var isEditing: Bool = false
        public fileprivate(set) var textInputState: ChatTextInputState = ChatTextInputState()
        public var resetInputState: ChatTextInputState?
        
        public init() {
        }
    }
    
    public enum InputMode {
        case text
        case emoji
        case stickers
        case commands
    }
    
    public final class InlineAction: Equatable {
        public enum Kind: Equatable {
            case paidMessage
            case inputMode(InputMode)
        }

        public let kind: Kind
        public let action: () -> Void
        
        public init(kind: Kind, action: @escaping () -> Void) {
            self.kind = kind
            self.action = action
        }
        
        public static func ==(lhs: InlineAction, rhs: InlineAction) -> Bool {
            if lhs.kind != rhs.kind {
                return false
            }
            return true
        }
    }
    
    public final class LeftAction: Equatable {
        public enum Kind: Equatable {
            case empty
            case attach
            case toggleExpanded(isVisible: Bool, isExpanded: Bool, hasUnseen: Bool)
            case settings
        }
        
        public let kind: Kind
        public let action: () -> Void
        
        public init(kind: Kind, action: @escaping () -> Void) {
            self.kind = kind
            self.action = action
        }
        
        public static func ==(lhs: LeftAction, rhs: LeftAction) -> Bool {
            if lhs.kind != rhs.kind {
                return false
            }
            return true
        }
    }
    
    public final class RightAction: Equatable {
        public enum Kind: Equatable {
            case empty
            case stars(count: Int, isFilled: Bool)
            case liveMicrophone(call: AnyObject?)
            
            public static func ==(lhs: Kind, rhs: Kind) -> Bool {
                switch lhs {
                case .empty:
                    if case .empty = rhs {
                        return true
                    } else {
                        return false
                    }
                case let .stars(count, isFilled):
                    if case .stars(count, isFilled) = rhs {
                        return true
                    } else {
                        return false
                    }
                case let .liveMicrophone(lhsCall):
                    if case let .liveMicrophone(rhsCall) = rhs, lhsCall === rhsCall {
                        return true
                    } else {
                        return false
                    }
                }
            }
        }
        
        public let kind: Kind
        public let action: (UIView) -> Void
        public let longPressAction: ((UIView) -> Void)?
        
        public init(kind: Kind, action: @escaping (UIView) -> Void, longPressAction: ((UIView) -> Void)? = nil) {
            self.kind = kind
            self.action = action
            self.longPressAction = longPressAction
        }
        
        public static func ==(lhs: RightAction, rhs: RightAction) -> Bool {
            if lhs.kind != rhs.kind {
                return false
            }
            if (lhs.longPressAction == nil) != (rhs.longPressAction == nil) {
                return false
            }
            return true
        }
    }
    
    public final class SendAsConfiguration: Equatable {
        public let currentPeer: EnginePeer
        public let subscriberCount: Int?
        public let isPremiumLocked: Bool
        public let isSelecting: Bool
        public let action: (UIView, ContextGesture?) -> Void
        
        public init(currentPeer: EnginePeer, subscriberCount: Int?, isPremiumLocked: Bool, isSelecting: Bool, action: @escaping (UIView, ContextGesture?) -> Void) {
            self.currentPeer = currentPeer
            self.subscriberCount = subscriberCount
            self.isPremiumLocked = isPremiumLocked
            self.isSelecting = isSelecting
            self.action = action
        }
        
        public static func ==(lhs: SendAsConfiguration, rhs: SendAsConfiguration) -> Bool {
            if lhs.currentPeer != rhs.currentPeer {
                return false
            }
            if lhs.subscriberCount != rhs.subscriberCount {
                return false
            }
            if lhs.isPremiumLocked != rhs.isPremiumLocked {
                return false
            }
            if lhs.isSelecting != rhs.isSelecting {
                return false
            }
            return true
        }
    }
    
    let externalState: ExternalState
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let chatPeerId: EnginePeer.Id
    let inlineActions: [InlineAction]
    let leftAction: LeftAction?
    let secondaryLeftAction: LeftAction?
    let rightAction: RightAction?
    let secondaryRightAction: RightAction?
    let sendAsConfiguration: SendAsConfiguration?
    let placeholder: String
    let isEnabled: Bool
    let paidMessagePrice: StarsAmount?
    let sendColor: UIColor?
    let isSendDisabled: Bool
    let hideKeyboard: Bool
    let insets: UIEdgeInsets
    let maxHeight: CGFloat
    let maxLength: Int?
    let allowConsecutiveNewlines: Bool
    let sendAction: (() -> Void)?
    let sendContextAction: ((UIView, ContextGesture) -> Void)?
    
    public init(
        externalState: ExternalState,
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        chatPeerId: EnginePeer.Id,
        inlineActions: [InlineAction],
        leftAction: LeftAction?,
        secondaryLeftAction: LeftAction?,
        rightAction: RightAction?,
        secondaryRightAction: RightAction?,
        sendAsConfiguration: SendAsConfiguration?,
        placeholder: String,
        isEnabled: Bool,
        paidMessagePrice: StarsAmount?,
        sendColor: UIColor?,
        isSendDisabled: Bool,
        hideKeyboard: Bool,
        insets: UIEdgeInsets,
        maxHeight: CGFloat,
        maxLength: Int?,
        allowConsecutiveNewlines: Bool,
        sendAction: (() -> Void)?,
        sendContextAction: ((UIView, ContextGesture) -> Void)?
    ) {
        self.externalState = externalState
        self.context = context
        self.theme = theme
        self.strings = strings
        self.chatPeerId = chatPeerId
        self.inlineActions = inlineActions
        self.leftAction = leftAction
        self.secondaryLeftAction = secondaryLeftAction
        self.rightAction = rightAction
        self.secondaryRightAction = secondaryRightAction
        self.sendAsConfiguration = sendAsConfiguration
        self.placeholder = placeholder
        self.isEnabled = isEnabled
        self.paidMessagePrice = paidMessagePrice
        self.sendColor = sendColor
        self.isSendDisabled = isSendDisabled
        self.hideKeyboard = hideKeyboard
        self.insets = insets
        self.maxHeight = maxHeight
        self.maxLength = maxLength
        self.allowConsecutiveNewlines = allowConsecutiveNewlines
        self.sendAction = sendAction
        self.sendContextAction = sendContextAction
    }

    public static func ==(lhs: ChatTextInputPanelComponent, rhs: ChatTextInputPanelComponent) -> Bool {
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
        if lhs.chatPeerId != rhs.chatPeerId {
            return false
        }
        if lhs.inlineActions != rhs.inlineActions {
            return false
        }
        if lhs.leftAction != rhs.leftAction {
            return false
        }
        if lhs.secondaryLeftAction != rhs.secondaryLeftAction {
            return false
        }
        if lhs.rightAction != rhs.rightAction {
            return false
        }
        if lhs.secondaryRightAction != rhs.secondaryRightAction {
            return false
        }
        if lhs.sendAsConfiguration != rhs.sendAsConfiguration {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.paidMessagePrice != rhs.paidMessagePrice {
            return false
        }
        if lhs.sendColor != rhs.sendColor {
            return false
        }
        if lhs.isSendDisabled != rhs.isSendDisabled {
            return false
        }
        if lhs.hideKeyboard != rhs.hideKeyboard {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.maxHeight != rhs.maxHeight {
            return false
        }
        if lhs.maxLength != rhs.maxLength {
            return false
        }
        if lhs.allowConsecutiveNewlines != rhs.allowConsecutiveNewlines {
            return false
        }
        if (lhs.sendAction == nil) != (rhs.sendAction == nil) {
            return false
        }
        if (lhs.sendContextAction == nil) != (rhs.sendContextAction == nil) {
            return false
        }
        return true
    }

    public final class View: UIView {
        private var panelNode: ChatTextInputPanelNode?
        
        private var interfaceInteraction: ChatPanelInterfaceInteraction?
        private var hasPendingInputTextRefresh: Bool = false
        
        private var component: ChatTextInputPanelComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        override public init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func insertText(text: NSAttributedString) {
            guard let panelNode = self.panelNode else {
                return
            }
            panelNode.insertText(text: text)
        }
        
        public func deleteBackward() {
            guard let panelNode = self.panelNode, let textView = panelNode.textInputNode?.textView else {
                return
            }
            textView.deleteBackward()
        }
        
        public func activateInput() {
            guard let panelNode = self.panelNode else {
                return
            }
            panelNode.ensureFocused()
        }
        
        public func deactivateInput() {
            guard let panelNode = self.panelNode else {
                return
            }
            panelNode.ensureUnfocused()
        }
        
        public var isActive: Bool {
            guard let panelNode = self.panelNode else {
                return false
            }
            return panelNode.isFocused
        }
        
        public func updateState(transition: ComponentTransition) {
            self.state?.updated(transition: transition)
        }
        
        func update(component: ChatTextInputPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            self.state = state
            
            if self.interfaceInteraction == nil {
                let inputModeFromComponent: (ChatTextInputPanelComponent) -> ChatInputMode = { component in
                    for inlineAction in component.inlineActions {
                        switch inlineAction.kind {
                        case let .inputMode(inputMode):
                            switch inputMode {
                            case .text:
                                return .media(mode: .other, expanded: nil, focused: false)
                            case .commands:
                                return .text
                            case .stickers:
                                return .media(mode: .other, expanded: nil, focused: false)
                            case .emoji:
                                return .text
                            }
                        default:
                            break
                        }
                    }
                    
                    return .text
                }
                
                self.interfaceInteraction = ChatPanelInterfaceInteraction(
                    setupReplyMessage: { _, _, _  in
                    },
                    setupEditMessage: { _, _ in
                    },
                    beginMessageSelection: { _, _ in
                    },
                    cancelMessageSelection: { _ in
                    },
                    deleteSelectedMessages: {
                    },
                    reportSelectedMessages: {
                    },
                    reportMessages: { _, _ in
                    },
                    blockMessageAuthor: { _, _ in
                    },
                    deleteMessages: { _, _, f in
                        f(.default)
                    },
                    forwardSelectedMessages: {
                    },
                    forwardCurrentForwardMessages: {
                    },
                    forwardMessages: { _ in
                    },
                    updateForwardOptionsState: { _ in
                    },
                    presentForwardOptions: { _ in
                    },
                    presentReplyOptions: { _ in
                    },
                    presentLinkOptions: { _ in
                    },
                    presentSuggestPostOptions: {
                    },
                    shareSelectedMessages: {
                    },
                    updateTextInputStateAndMode: { [weak self] f in
                        guard let self else {
                            return
                        }
                        if let component = self.component {
                            let currentMode = inputModeFromComponent(component)
                            let (updatedTextInputState, updatedMode) = f(component.externalState.textInputState, currentMode)
                            if component.externalState.textInputState != updatedTextInputState {
                                component.externalState.textInputState = updatedTextInputState
                                self.hasPendingInputTextRefresh = true
                            }
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                            
                            if updatedMode != currentMode {
                                /*for inlineAction in component.inlineActions {
                                    switch inlineAction.kind {
                                    case .inputMode:
                                        inlineAction.action()
                                        return
                                    default:
                                        break
                                    }
                                }*/
                            }
                        }
                    },
                    updateInputModeAndDismissedButtonKeyboardMessageId: { [weak self] f in
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        var presentationInterfaceState = ChatPresentationInterfaceState(
                            chatWallpaper: .color(0),
                            theme: component.theme,
                            preferredGlassType: .default,
                            strings: component.strings,
                            dateTimeFormat: PresentationDateTimeFormat(),
                            nameDisplayOrder: .firstLast,
                            limitsConfiguration: component.context.currentLimitsConfiguration.with({ $0 }),
                            fontSize: .regular,
                            bubbleCorners: PresentationChatBubbleCorners(
                                mainRadius: 16.0,
                                auxiliaryRadius: 8.0,
                                mergeBubbleCorners: true
                            ),
                            accountPeerId: component.context.account.peerId,
                            mode: .standard(.default),
                            chatLocation: .peer(id: component.chatPeerId),
                            subject: nil,
                            peerNearbyData: nil,
                            greetingData: nil,
                            pendingUnpinnedAllMessages: false,
                            activeGroupCallInfo: nil,
                            hasActiveGroupCall: false,
                            threadData: nil,
                            isGeneralThreadClosed: false,
                            replyMessage: nil,
                            accountPeerColor: nil,
                            businessIntro: nil
                        )
                        let currentMode = inputModeFromComponent(component)
                        presentationInterfaceState = presentationInterfaceState.updatedInputMode { _ in
                            return currentMode
                        }
                        
                        let (updatedMode, _) = f(presentationInterfaceState)
                        
                        if updatedMode != currentMode {
                            /*for inlineAction in component.inlineActions {
                                switch inlineAction.kind {
                                case .inputMode:
                                    inlineAction.action()
                                    return
                                default:
                                    break
                                }
                            }*/
                        }
                        
                        if let panelNode = self.panelNode, let textView = panelNode.textInputNode?.textView {
                            component.externalState.isEditing = textView.isFirstResponder
                        } else {
                            component.externalState.isEditing = false
                        }
                    },
                    openStickers: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        for inlineAction in component.inlineActions {
                            switch inlineAction.kind {
                            case .inputMode:
                                inlineAction.action()
                                return
                            default:
                                break
                            }
                        }
                    },
                    editMessage: {
                    },
                    beginMessageSearch: { _, _ in
                    },
                    dismissMessageSearch: {
                    },
                    updateMessageSearch: { _ in
                    },
                    openSearchResults: {
                    },
                    navigateMessageSearch: { _ in
                    },
                    openCalendarSearch: {
                    },
                    toggleMembersSearch: { _ in
                    },
                    navigateToMessage: { _, _, _, _ in
                    },
                    navigateToChat: { _ in
                    },
                    navigateToProfile: { _ in
                    },
                    openPeerInfo: {
                    },
                    togglePeerNotifications: {
                    },
                    sendContextResult: { _, _, _, _ in
                        return false
                    },
                    sendBotCommand: { _, _ in
                    },
                    sendShortcut: { _ in
                    },
                    openEditShortcuts: {
                    },
                    sendBotStart: { _ in
                    },
                    botSwitchChatWithPayload: { _, _ in
                    },
                    beginMediaRecording: { _ in
                    },
                    finishMediaRecording: { _ in
                    },
                    stopMediaRecording: {
                    },
                    lockMediaRecording: {
                    },
                    resumeMediaRecording: {
                    },
                    deleteRecordedMedia: {
                    },
                    sendRecordedMedia: { _, _ in
                    },
                    displayRestrictedInfo: { _, _ in
                    },
                    displayVideoUnmuteTip: { _ in
                    },
                    switchMediaRecordingMode: {
                    },
                    setupMessageAutoremoveTimeout: {
                    },
                    sendSticker: { _, _, _, _, _, _ in
                        return false
                    },
                    unblockPeer: {
                    },
                    pinMessage: { _, _ in
                    },
                    unpinMessage: { _, _, _ in
                    },
                    unpinAllMessages: {
                    },
                    openPinnedList: { _ in
                    },
                    shareAccountContact: {
                    },
                    reportPeer: {
                    },
                    presentPeerContact: {
                    },
                    dismissReportPeer: {
                    },
                    deleteChat: {
                    },
                    beginCall: { _ in
                    },
                    toggleMessageStickerStarred: { _ in
                    },
                    presentController: { _, _ in
                    },
                    presentControllerInCurrent: { _, _ in
                    },
                    getNavigationController: {
                        return nil
                    },
                    presentGlobalOverlayController: { _, _ in
                    },
                    navigateFeed: {
                    },
                    openGrouping: {
                    },
                    toggleSilentPost: {
                    },
                    requestUnvoteInMessage: { _ in
                    },
                    requestStopPollInMessage: { _ in
                    },
                    updateInputLanguage: { _ in
                    },
                    unarchiveChat: {
                    },
                    openLinkEditing: {
                    },
                    displaySlowmodeTooltip: { _, _ in
                    },
                    displaySendMessageOptions: { [weak self] node, gesture in
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        component.sendContextAction?(node.view, gesture)
                    },
                    openScheduledMessages: {
                    },
                    openPeersNearby: {
                    },
                    displaySearchResultsTooltip: { _, _ in
                    },
                    unarchivePeer: {
                    },
                    scrollToTop: {
                    },
                    viewReplies: { _, _ in
                    },
                    activatePinnedListPreview: { _, _ in
                    },
                    joinGroupCall: { _ in
                    },
                    presentInviteMembers: {
                    },
                    presentGigagroupHelp: {
                    },
                    openMonoforum: {
                    },
                    editMessageMedia: { _, _ in
                    },
                    updateShowCommands: { _ in
                    },
                    updateShowSendAsPeers: { _ in
                    },
                    openInviteRequests: {
                    },
                    openSendAsPeer: { [weak self] sourceNode, gesture in
                        guard let self, let component = self.component, let sendAsConfiguration = component.sendAsConfiguration else {
                            return
                        }
                        sendAsConfiguration.action(sourceNode.view, gesture)
                    },
                    presentChatRequestAdminInfo: {
                    },
                    displayCopyProtectionTip: { _, _ in
                    },
                    openWebView: { _, _, _, _ in
                    },
                    updateShowWebView: { _ in
                    },
                    insertText: { _ in
                    },
                    backwardsDeleteText: {
                    },
                    restartTopic: {
                    },
                    toggleTranslation: { _ in
                    },
                    changeTranslationLanguage: { _ in
                    },
                    addDoNotTranslateLanguage: { _ in
                    },
                    hideTranslationPanel: {
                    },
                    openPremiumGift: {
                    },
                    openSuggestPost: { [weak self] _, _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        for action in component.inlineActions {
                            if case .paidMessage = action.kind {
                                action.action()
                                break
                            }
                        }
                    },
                    openPremiumRequiredForMessaging: {
                    },
                    openStarsPurchase: { _ in
                    },
                    openMessagePayment: {
                    },
                    openBoostToUnrestrict: {
                    },
                    updateRecordingTrimRange: { _, _, _, _ in
                    },
                    dismissAllTooltips: {
                    },
                    editTodoMessage: { _, _, _ in
                    },
                    dismissUrlPreview: {
                    },
                    dismissForwardMessages: {
                    },
                    dismissSuggestPost: {
                    },
                    displayUndo: { _ in
                    },
                    sendEmoji: { _, _, _ in
                    },
                    updateHistoryFilter: { _ in
                    },
                    updateChatLocationThread: { _, _ in
                    },
                    toggleChatSidebarMode: {
                    },
                    updateDisplayHistoryFilterAsList: { _ in
                    },
                    requestLayout: { _ in
                    },
                    chatController: {
                        return nil
                    },
                    statuses: nil
                )
            }
            
            var presentationInterfaceState = ChatPresentationInterfaceState(
                chatWallpaper: .color(0),
                theme: component.theme,
                preferredGlassType: .default,
                strings: component.strings,
                dateTimeFormat: PresentationDateTimeFormat(),
                nameDisplayOrder: .firstLast,
                limitsConfiguration: component.context.currentLimitsConfiguration.with({ $0 }),
                fontSize: .regular,
                bubbleCorners: PresentationChatBubbleCorners(
                    mainRadius: 16.0,
                    auxiliaryRadius: 8.0,
                    mergeBubbleCorners: true
                ),
                accountPeerId: component.context.account.peerId,
                mode: .standard(.default),
                chatLocation: .peer(id: component.chatPeerId),
                subject: nil,
                peerNearbyData: nil,
                greetingData: nil,
                pendingUnpinnedAllMessages: false,
                activeGroupCallInfo: nil,
                hasActiveGroupCall: false,
                threadData: nil,
                isGeneralThreadClosed: false,
                replyMessage: nil,
                accountPeerColor: nil,
                businessIntro: nil
            )
            
            var inputAccessoryItems: [ChatTextInputAccessoryItem] = []
            for inlineAction in component.inlineActions {
                switch inlineAction.kind {
                case .paidMessage:
                    inputAccessoryItems.append(.suggestPost)
                case let .inputMode(inputMode):
                    let mappedInputMode: ChatTextInputAccessoryItem.InputMode
                    switch inputMode {
                    case .emoji:
                        mappedInputMode = .emoji
                    case .stickers:
                        mappedInputMode = .stickers
                    case .text:
                        mappedInputMode = .keyboard
                    case .commands:
                        mappedInputMode = .bot
                    }
                    inputAccessoryItems.append(.input(isEnabled: true, inputMode: mappedInputMode))
                }
            }
            presentationInterfaceState = presentationInterfaceState.updatedInputTextPanelState { _ in
                return ChatTextInputPanelState(
                    accessoryItems: inputAccessoryItems,
                    contextPlaceholder: nil,
                    mediaRecordingState: nil
                )
            }
            presentationInterfaceState = presentationInterfaceState.updatedInterfaceState { interfaceState in
                return interfaceState.withUpdatedEffectiveInputState(component.externalState.textInputState)
            }
            presentationInterfaceState = presentationInterfaceState.updatedSendPaidMessageStars(component.paidMessagePrice)
            
            if let sendAsConfiguration = component.sendAsConfiguration {
                presentationInterfaceState = presentationInterfaceState.updatedSendAsPeers([SendAsPeer(
                    peer: sendAsConfiguration.currentPeer._asPeer(),
                    subscribers: sendAsConfiguration.subscriberCount.flatMap(Int32.init(clamping:)),
                    isPremiumRequired: sendAsConfiguration.isPremiumLocked
                )]).updatedShowSendAsPeers(sendAsConfiguration.isSelecting).updatedCurrentSendAsPeerId(sendAsConfiguration.currentPeer.id)
            }
            
            let panelNode: ChatTextInputPanelNode
            if let current = self.panelNode {
                panelNode = current
            } else {
                panelNode = ChatTextInputPanelNode(
                    context: component.context,
                    presentationInterfaceState: presentationInterfaceState,
                    presentationContext: ChatPresentationContext(
                        context: component.context,
                        backgroundNode: nil
                    ),
                    presentController: { c in
                        
                    }
                )
                self.panelNode = panelNode
                self.addSubview(panelNode.view)
                panelNode.interfaceInteraction = self.interfaceInteraction
                panelNode.loadTextInputNodeIfNeeded()
                
                panelNode.sendMessage = { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.sendAction?()
                }
                panelNode.updateHeight = { [weak self] _ in
                    guard let self else {
                        return
                    }
                    if !self.isUpdating {
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                }
                panelNode.displayAttachmentMenu = { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    if let leftAction = component.leftAction {
                        leftAction.action()
                    }
                }
            }
            
            if let textView = panelNode.textInputNode?.textView {
                if component.hideKeyboard {
                    if textView.inputView == nil {
                        textView.inputView = EmptyInputView()
                        textView.reloadInputViews()
                    }
                } else if textView.inputView != nil {
                    textView.inputView = nil
                    textView.reloadInputViews()
                }
            }
            
            panelNode.customPlaceholder = component.placeholder
            panelNode.customIsDisabled = !component.isEnabled
            
            if let leftAction = component.leftAction {
                switch leftAction.kind {
                case .empty:
                    panelNode.customLeftAction = .empty
                case .attach:
                    panelNode.customLeftAction = nil
                case let .toggleExpanded(isVisible, isExpanded, hasUnseen):
                    var isVisible = isVisible
                    if component.insets.bottom > 40.0 {
                        isVisible = false
                    }
                    panelNode.customLeftAction = .toggleExpanded(isVisible: isVisible, isExpanded: isExpanded, hasUnseen: hasUnseen)
                case .settings:
                    var isVisible = true
                    if component.insets.bottom > 40.0 {
                        isVisible = false
                    }
                    panelNode.customLeftAction = .settings(isVisible: isVisible, action: { [weak self] _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        if let leftAction = component.leftAction {
                            leftAction.action()
                        }
                    })
                }
            } else {
                panelNode.customLeftAction = nil
            }
            if let secondaryLeftAction = component.secondaryLeftAction {
                switch secondaryLeftAction.kind {
                case .empty:
                    panelNode.customSecondaryLeftAction = .empty
                case .attach:
                    panelNode.customSecondaryLeftAction = nil
                case let .toggleExpanded(isVisible, isExpanded, hasUnseen):
                    var isVisible = isVisible
                    if component.insets.bottom > 40.0 {
                        isVisible = false
                    }
                    panelNode.customSecondaryLeftAction = .toggleExpanded(isVisible: isVisible, isExpanded: isExpanded, hasUnseen: hasUnseen)
                case .settings:
                    var isVisible = true
                    if component.insets.bottom > 40.0 {
                        isVisible = false
                    }
                    panelNode.customSecondaryLeftAction = .settings(isVisible: isVisible, action: { [weak self] _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        if let secondaryLeftAction = component.secondaryLeftAction {
                            secondaryLeftAction.action()
                        }
                    })
                }
            } else {
                panelNode.customSecondaryLeftAction = nil
            }
            
            if let rightAction = component.rightAction {
                switch rightAction.kind {
                case .empty:
                    panelNode.customRightAction = .empty
                case let .liveMicrophone(call):
                    panelNode.customSecondaryRightAction = .liveMicrophone(call: call, action: { sourceView in
                        rightAction.action(sourceView)
                    })
                case let .stars(count, isFilled):
                    panelNode.customRightAction = .stars(count: count, isFilled: isFilled, action: { sourceView in
                        rightAction.action(sourceView)
                    }, longPressAction: rightAction.longPressAction.flatMap { longPressAction in
                        return { sourceView in
                            longPressAction(sourceView)
                        }
                    })
                }
            } else {
                panelNode.customRightAction = nil
            }
            
            if let secondaryRightAction = component.secondaryRightAction {
                switch secondaryRightAction.kind {
                case .empty:
                    panelNode.customSecondaryRightAction = .empty
                case let .liveMicrophone(call):
                    panelNode.customSecondaryRightAction = .liveMicrophone(call: call, action: { sourceView in
                        secondaryRightAction.action(sourceView)
                    })
                case let .stars(count, isFilled):
                    panelNode.customSecondaryRightAction = .stars(count: count, isFilled: isFilled, action: { sourceView in
                        secondaryRightAction.action(sourceView)
                    }, longPressAction: secondaryRightAction.longPressAction.flatMap { longPressAction in
                        return { sourceView in
                            longPressAction(sourceView)
                        }
                    })
                }
            } else {
                panelNode.customSecondaryRightAction = nil
            }
            
            panelNode.customSendColor = component.sendColor
            panelNode.customSendIsDisabled = component.isSendDisabled
            panelNode.customInputTextMaxLength = component.maxLength
            panelNode.customSwitchToKeyboard = { [weak self] in
                guard let self, let component = self.component else {
                    return
                }
                for inlineAction in component.inlineActions {
                    switch inlineAction.kind {
                    case .inputMode:
                        inlineAction.action()
                        return
                    default:
                        break
                    }
                }
            }
            
            panelNode.allowConsecutiveNewlines = component.allowConsecutiveNewlines
            
            if let resetInputState = component.externalState.resetInputState {
                component.externalState.resetInputState = nil
                let _ = resetInputState
                panelNode.text = ""
            } else if self.hasPendingInputTextRefresh {
                panelNode.updateInputTextState(component.externalState.textInputState)
            }
            self.hasPendingInputTextRefresh = false
            
            let panelHeight = panelNode.updateLayout(
                width: availableSize.width,
                leftInset: component.insets.left,
                rightInset: component.insets.right,
                bottomInset: component.insets.bottom,
                additionalSideInsets: UIEdgeInsets(),
                maxHeight: component.maxHeight,
                maxOverlayHeight: component.maxHeight,
                isSecondary: false,
                transition: transition.containedViewLayoutTransition,
                interfaceState: presentationInterfaceState,
                metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact, orientation: nil),
                isMediaInputExpanded: false
            )
            
            let panelSize = CGSize(width: availableSize.width, height: panelHeight)
            let panelFrame = CGRect(origin: CGPoint(), size: panelSize)
            
            transition.setFrame(view: panelNode.view, frame: panelFrame)
            
            return panelSize
        }
    }

    public func makeView() -> View {
        return View()
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
