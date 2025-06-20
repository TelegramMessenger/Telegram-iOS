import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display
import TelegramUIPreferences
import AccountContext
import TextSelectionNode
import ContextUI
import ChatInterfaceState
import UndoUI
import TelegramPresentationData
import ChatPresentationInterfaceState
import TextFormat
import WallpaperBackgroundNode
import AnimationCache
import MultiAnimationRenderer

public struct ChatInterfaceHighlightedState: Equatable {
    public struct Quote: Equatable {
        public var string: String
        public var offset: Int?
        
        public init(string: String, offset: Int?) {
            self.string = string
            self.offset = offset
        }
    }
    
    public let messageStableId: UInt32
    public let quote: Quote?
    public let todoTaskId: Int32?
    
    public init(messageStableId: UInt32, quote: Quote?, todoTaskId: Int32?) {
        self.messageStableId = messageStableId
        self.quote = quote
        self.todoTaskId = todoTaskId
    }
}

public struct ChatInterfacePollActionState: Equatable {
    public var pollMessageIdsInProgress: [MessageId: [Data]] = [:]
    
    public init(pollMessageIdsInProgress: [MessageId: [Data]] = [:]) {
        self.pollMessageIdsInProgress = pollMessageIdsInProgress
    }
}

public enum ChatControllerInteractionSwipeAction {
    case none
    case reply
}

public enum ChatControllerInteractionReaction {
    case `default`
    case reaction(MessageReaction.Reaction)
}

public struct UnreadMessageRangeKey: Hashable {
    public var peerId: PeerId
    public var namespace: MessageId.Namespace
    
    public init(peerId: PeerId, namespace: MessageId.Namespace) {
        self.peerId = peerId
        self.namespace = namespace
    }
}

public class ChatPresentationContext {
    public weak var backgroundNode: WallpaperBackgroundNode?
    public let animationCache: AnimationCache
    public let animationRenderer: MultiAnimationRenderer

    public init(context: AccountContext, backgroundNode: WallpaperBackgroundNode?) {
        self.backgroundNode = backgroundNode
        
        self.animationCache = context.animationCache
        self.animationRenderer = context.animationRenderer
    }
}

public protocol ChatMessageTransitionProtocol: ASDisplayNode {
    
}

public struct NavigateToMessageParams {
    public struct Quote {
        public var string: String
        public var offset: Int?
        
        public init(string: String, offset: Int?) {
            self.string = string
            self.offset = offset
        }
    }
    
    public var timestamp: Double?
    public var quote: Quote?
    public var todoTaskId: Int32?
    public var progress: Promise<Bool>?
    public var forceNew: Bool
    public var setupReply: Bool
    
    public init(timestamp: Double?, quote: Quote?, todoTaskId: Int32? = nil, progress: Promise<Bool>? = nil, forceNew: Bool = false, setupReply: Bool = false) {
        self.timestamp = timestamp
        self.quote = quote
        self.todoTaskId = todoTaskId
        self.progress = progress
        self.forceNew = forceNew
        self.setupReply = setupReply
    }
}

public struct OpenMessageParams {
    public var mode: ChatControllerInteractionOpenMessageMode
    public var mediaIndex: Int?
    public var progress: Promise<Bool>?
    
    public init(mode: ChatControllerInteractionOpenMessageMode, mediaIndex: Int? = nil, progress: Promise<Bool>? = nil) {
        self.mode = mode
        self.mediaIndex = mediaIndex
        self.progress = progress
    }
}

public final class ChatSendMessageEffect {
    public let id: Int64
    
    public init(id: Int64) {
        self.id = id
    }
}

public final class ChatControllerInteraction: ChatControllerInteractionProtocol {
    public enum OpenPeerSource {
        case `default`
        case reaction
        case groupParticipant(storyStats: PeerStoryStats?, avatarHeaderNode: ASDisplayNode?)
    }
    
    public struct OpenUrl {
        public var url: String
        public var concealed: Bool
        public var external: Bool?
        public var message: Message?
        public var allowInlineWebpageResolution: Bool
        public var progress: Promise<Bool>?
        
        public init(url: String, concealed: Bool, external: Bool? = nil, message: Message? = nil, allowInlineWebpageResolution: Bool = false, progress: Promise<Bool>? = nil) {
            self.url = url
            self.concealed = concealed
            self.external = external
            self.message = message
            self.allowInlineWebpageResolution = allowInlineWebpageResolution
            self.progress = progress
        }
    }
    
    public struct LongTapParams {
        public var message: Message?
        public var contentNode: ContextExtractedContentContainingNode?
        public var messageNode: ASDisplayNode?
        public var progress: Promise<Bool>?
        
        public init(message: Message? = nil, contentNode: ContextExtractedContentContainingNode? = nil, messageNode: ASDisplayNode? = nil, progress: Promise<Bool>? = nil) {
            self.message = message
            self.contentNode = contentNode
            self.messageNode = messageNode
            self.progress = progress
        }
    }
    
    public let openMessage: (Message, OpenMessageParams) -> Bool
    public let openPeer: (EnginePeer, ChatControllerInteractionNavigateToPeer, MessageReference?, OpenPeerSource) -> Void
    public let openPeerMention: (String, Promise<Bool>?) -> Void
    public let openMessageContextMenu: (Message, Bool, ASDisplayNode, CGRect, UIGestureRecognizer?, CGPoint?) -> Void
    public let updateMessageReaction: (Message, ChatControllerInteractionReaction, Bool, ContextExtractedContentContainingView?) -> Void
    public let openMessageReactionContextMenu: (Message, ContextExtractedContentContainingView, ContextGesture?, MessageReaction.Reaction) -> Void
    public let activateMessagePinch: (PinchSourceContainerNode) -> Void
    public let openMessageContextActions: (Message, ASDisplayNode, CGRect, ContextGesture?) -> Void
    public let navigateToMessage: (MessageId, MessageId, NavigateToMessageParams) -> Void
    public let navigateToMessageStandalone: (MessageId) -> Void
    public let navigateToThreadMessage: (PeerId, Int64, MessageId?) -> Void
    public let tapMessage: ((Message) -> Void)?
    public let clickThroughMessage: (UIView?, CGPoint?) -> Void
    public let toggleMessagesSelection: ([MessageId], Bool) -> Void
    public let sendCurrentMessage: (Bool, ChatSendMessageEffect?) -> Void
    public let sendMessage: (String) -> Void
    public let sendSticker: (FileMediaReference, Bool, Bool, String?, Bool, UIView, CGRect, CALayer?, [ItemCollectionId]) -> Bool
    public let sendEmoji: (String, ChatTextInputTextCustomEmojiAttribute, Bool) -> Void
    public let sendGif: (FileMediaReference, UIView, CGRect, Bool, Bool) -> Bool
    public let sendBotContextResultAsGif: (ChatContextResultCollection, ChatContextResult, UIView, CGRect, Bool, Bool) -> Bool
    public let requestMessageActionCallback: (Message, MemoryBuffer?, Bool, Bool, Promise<Bool>?) -> Void
    public let requestMessageActionUrlAuth: (String, MessageActionUrlSubject) -> Void
    public let activateSwitchInline: (PeerId?, String, ReplyMarkupButtonAction.PeerTypes?) -> Void
    public let openUrl: (OpenUrl) -> Void
    public let shareCurrentLocation: () -> Void
    public let shareAccountContact: () -> Void
    public let sendBotCommand: (MessageId?, String) -> Void
    public let openInstantPage: (Message, ChatMessageItemAssociatedData?) -> Void
    public let openWallpaper: (Message) -> Void
    public let openTheme: (Message) -> Void
    public let openHashtag: (String?, String) -> Void
    public let updateInputState: ((ChatTextInputState) -> ChatTextInputState) -> Void
    public let updateInputMode: ((ChatInputMode) -> ChatInputMode) -> Void
    public let openMessageShareMenu: (MessageId) -> Void
    public let presentController: (ViewController, Any?) -> Void
    public let presentControllerInCurrent: (ViewController, Any?) -> Void
    public let navigationController: () -> NavigationController?
    public let chatControllerNode: () -> ASDisplayNode?
    public let presentGlobalOverlayController: (ViewController, Any?) -> Void
    public let callPeer: (PeerId, Bool) -> Void
    public let openConferenceCall: (Message) -> Void
    public let longTap: (ChatControllerInteractionLongTapAction, LongTapParams?) -> Void
    public let todoItemLongTap: (Int32, LongTapParams?) -> Void
    public let openCheckoutOrReceipt: (MessageId, OpenMessageParams?) -> Void
    public let openSearch: () -> Void
    public let setupReply: (MessageId) -> Void
    public let canSetupReply: (Message) -> ChatControllerInteractionSwipeAction
    public let canSendMessages: () -> Bool
    public let navigateToFirstDateMessage: (Int32, Bool) -> Void
    public let requestRedeliveryOfFailedMessages: (MessageId) -> Void
    public let addContact: (String) -> Void
    public let rateCall: (Message, CallId, Bool) -> Void
    public let requestSelectMessagePollOptions: (MessageId, [Data]) -> Void
    public let requestOpenMessagePollResults: (MessageId, MediaId) -> Void
    public let openAppStorePage: () -> Void
    public let displayMessageTooltip: (MessageId, String, Bool, ASDisplayNode?, CGRect?) -> Void
    public let seekToTimecode: (Message, Double, Bool) -> Void
    public let scheduleCurrentMessage: (ChatSendMessageActionSheetController.SendParameters?) -> Void
    public let sendScheduledMessagesNow: ([MessageId]) -> Void
    public let editScheduledMessagesTime: ([MessageId]) -> Void
    public let performTextSelectionAction: (Message?, Bool, NSAttributedString, TextSelectionAction) -> Void
    public let displayImportedMessageTooltip: (ASDisplayNode) -> Void
    public let displaySwipeToReplyHint: () -> Void
    public let dismissReplyMarkupMessage: (Message) -> Void
    public let openMessagePollResults: (MessageId, Data) -> Void
    public let openPollCreation: (Bool?) -> Void
    public let displayPollSolution: (TelegramMediaPollResults.Solution, ASDisplayNode) -> Void
    public let displayPsa: (String, ASDisplayNode) -> Void
    public let displayDiceTooltip: (TelegramMediaDice) -> Void
    public let animateDiceSuccess: (Bool, Bool) -> Void
    public let displayPremiumStickerTooltip: (TelegramMediaFile, Message) -> Void
    public let displayEmojiPackTooltip: (TelegramMediaFile, Message) -> Void
    public let openPeerContextMenu: (Peer, MessageId?, ASDisplayNode, CGRect, ContextGesture?) -> Void
    public let openMessageReplies: (MessageId, Bool, Bool) -> Void
    public let openReplyThreadOriginalMessage: (Message) -> Void
    public let openMessageStats: (MessageId) -> Void
    public let editMessageMedia: (MessageId, Bool) -> Void
    public let copyText: (String) -> Void
    public let displayUndo: (UndoOverlayContent) -> Void
    public let isAnimatingMessage: (UInt32) -> Bool
    public let getMessageTransitionNode: () -> ChatMessageTransitionProtocol?
    public let updateChoosingSticker: (Bool) -> Void
    public let commitEmojiInteraction: (MessageId, String, EmojiInteraction, TelegramMediaFile) -> Void
    public let openLargeEmojiInfo: (String, String?, TelegramMediaFile) -> Void
    public let openJoinLink: (String) -> Void
    public let openWebView: (String, String, Bool, ChatOpenWebViewSource) -> Void
    public let activateAdAction: (EngineMessage.Id, Promise<Bool>?, Bool, Bool) -> Void
    public let adContextAction: (Message, ASDisplayNode, ContextGesture?) -> Void
    public let removeAd: (Data) -> Void
    public let openRequestedPeerSelection: (EngineMessage.Id, ReplyMarkupButtonRequestPeerType, Int32, Int32) -> Void
    public let saveMediaToFiles: (EngineMessage.Id) -> Void
    public let openNoAdsDemo: () -> Void
    public let openAdsInfo: () -> Void
    public let displayGiveawayParticipationStatus: (EngineMessage.Id) -> Void
    public let openPremiumStatusInfo: (EnginePeer.Id, UIView, Int64?, PeerNameColor) -> Void
    public let openRecommendedChannelContextMenu: (EnginePeer, UIView, ContextGesture?) -> Void
    public let openGroupBoostInfo: (EnginePeer.Id?, Int) -> Void
    public let openStickerEditor: () -> Void
    public let openAgeRestrictedMessageMedia: (Message, @escaping () -> Void) -> Void
    public let playMessageEffect: (Message) -> Void
    public let editMessageFactCheck: (MessageId) -> Void
    public let sendGift: (EnginePeer.Id) -> Void
    public let openUniqueGift: (String) -> Void
    public let openMessageFeeException: () -> Void
    public let requestMessageUpdate: (MessageId, Bool) -> Void
    public let cancelInteractiveKeyboardGestures: () -> Void
    public let dismissTextInput: () -> Void
    public let scrollToMessageId: (MessageIndex) -> Void
    public let navigateToStory: (Message, StoryId) -> Void
    public let attemptedNavigationToPrivateQuote: (Peer?) -> Void
    public let forceUpdateWarpContents: () -> Void
    public let playShakeAnimation:  () -> Void
    public let displayQuickShare: (MessageId, ASDisplayNode, ContextGesture) -> Void
    public let updateChatLocationThread: (Int64?, ChatControllerAnimateInnerChatSwitchDirection?) -> Void
    public let requestToggleTodoMessageItem: (MessageId, Int32, Bool) -> Void
    public let displayTodoToggleUnavailable: (MessageId) -> Void
    public let openStarsPurchase: (Int64?) -> Void
    
    public var canPlayMedia: Bool = false
    public var hiddenMedia: [MessageId: [Media]] = [:]
    public var expandedTranslationMessageStableIds: Set<UInt32> = Set()
    public var selectionState: ChatInterfaceSelectionState?
    public var highlightedState: ChatInterfaceHighlightedState?
    public var contextHighlightedState: ChatInterfaceHighlightedState?
    public var automaticMediaDownloadSettings: MediaAutoDownloadSettings
    public var pollActionState: ChatInterfacePollActionState
    public var currentPollMessageWithTooltip: MessageId?
    public var currentPsaMessageWithTooltip: MessageId?
    public var stickerSettings: ChatInterfaceStickerSettings
    public var searchTextHighightState: (String, [MessageIndex])?
    public var unreadMessageRange: [UnreadMessageRangeKey: Range<MessageId.Id>] = [:]
    public var seenOneTimeAnimatedMedia = Set<MessageId>()
    public var currentMessageWithLoadingReplyThread: MessageId?
    public var updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    public let presentationContext: ChatPresentationContext
    public var playNextOutgoingGift: Bool = false
    public var recommendedChannelsOpenUp: Bool = false
    public var enableFullTranslucency: Bool = true
    public var chatIsRotated: Bool = true
    public var canReadHistory: Bool = false
    
    private var isOpeningMediaValue: Bool = false
    public var isOpeningMedia: Bool {
        return self.isOpeningMediaValue
    }
    private var isOpeningMediaDisposable: Disposable?
    public var isOpeningMediaSignal: Signal<Bool, NoError>? {
        didSet {
            self.isOpeningMediaDisposable?.dispose()
            self.isOpeningMediaDisposable = nil
            self.isOpeningMediaValue = false
            
            if let isOpeningMediaSignal = self.isOpeningMediaSignal {
                self.isOpeningMediaValue = true
                self.isOpeningMediaDisposable = (isOpeningMediaSignal |> filter { !$0 } |> take(1) |> timeout(1.0, queue: .mainQueue(), alternate: .single(false)) |> deliverOnMainQueue).startStrict(next: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.isOpeningMediaValue = false
                })
            }
        }
    }
    
    public var isSidePanelOpen: Bool = false
    
    public init(
        openMessage: @escaping (Message, OpenMessageParams) -> Bool,
        openPeer: @escaping (EnginePeer, ChatControllerInteractionNavigateToPeer, MessageReference?, OpenPeerSource) -> Void,
        openPeerMention: @escaping (String, Promise<Bool>?) -> Void,
        openMessageContextMenu: @escaping (Message, Bool, ASDisplayNode, CGRect, UIGestureRecognizer?, CGPoint?) -> Void,
        openMessageReactionContextMenu: @escaping (Message, ContextExtractedContentContainingView, ContextGesture?, MessageReaction.Reaction) -> Void,
        updateMessageReaction: @escaping (Message, ChatControllerInteractionReaction, Bool, ContextExtractedContentContainingView?) -> Void,
        activateMessagePinch: @escaping (PinchSourceContainerNode) -> Void,
        openMessageContextActions: @escaping (Message, ASDisplayNode, CGRect, ContextGesture?) -> Void,
        navigateToMessage: @escaping (MessageId, MessageId, NavigateToMessageParams) -> Void,
        navigateToMessageStandalone: @escaping (MessageId) -> Void,
        navigateToThreadMessage: @escaping (PeerId, Int64, MessageId?) -> Void,
        tapMessage: ((Message) -> Void)?,
        clickThroughMessage: @escaping (UIView?, CGPoint?) -> Void,
        toggleMessagesSelection: @escaping ([MessageId], Bool) -> Void,
        sendCurrentMessage: @escaping (Bool, ChatSendMessageEffect?) -> Void,
        sendMessage: @escaping (String) -> Void,
        sendSticker: @escaping (FileMediaReference, Bool, Bool, String?, Bool, UIView, CGRect, CALayer?, [ItemCollectionId]) -> Bool,
        sendEmoji: @escaping (String, ChatTextInputTextCustomEmojiAttribute, Bool) -> Void,
        sendGif: @escaping (FileMediaReference, UIView, CGRect, Bool, Bool) -> Bool,
        sendBotContextResultAsGif: @escaping (ChatContextResultCollection, ChatContextResult, UIView, CGRect, Bool, Bool) -> Bool,
        requestMessageActionCallback: @escaping (Message, MemoryBuffer?, Bool, Bool, Promise<Bool>?) -> Void,
        requestMessageActionUrlAuth: @escaping (String, MessageActionUrlSubject) -> Void,
        activateSwitchInline: @escaping (PeerId?, String, ReplyMarkupButtonAction.PeerTypes?) -> Void,
        openUrl: @escaping (OpenUrl) -> Void,
        shareCurrentLocation: @escaping () -> Void,
        shareAccountContact: @escaping () -> Void,
        sendBotCommand: @escaping (MessageId?, String) -> Void,
        openInstantPage: @escaping (Message, ChatMessageItemAssociatedData?) -> Void,
        openWallpaper: @escaping (Message) -> Void,
        openTheme: @escaping (Message) -> Void,
        openHashtag: @escaping (String?, String) -> Void,
        updateInputState: @escaping ((ChatTextInputState) -> ChatTextInputState) -> Void,
        updateInputMode: @escaping ((ChatInputMode) -> ChatInputMode) -> Void,
        openMessageShareMenu: @escaping (MessageId) -> Void,
        presentController: @escaping (ViewController, Any?) -> Void,
        presentControllerInCurrent: @escaping (ViewController, Any?) -> Void,
        navigationController: @escaping () -> NavigationController?,
        chatControllerNode: @escaping () -> ASDisplayNode?,
        presentGlobalOverlayController: @escaping (ViewController, Any?) -> Void,
        callPeer: @escaping (PeerId, Bool) -> Void,
        openConferenceCall: @escaping (Message) -> Void,
        longTap: @escaping (ChatControllerInteractionLongTapAction, LongTapParams?) -> Void,
        todoItemLongTap: @escaping (Int32, LongTapParams?) -> Void,
        openCheckoutOrReceipt: @escaping (MessageId, OpenMessageParams?) -> Void,
        openSearch: @escaping () -> Void,
        setupReply: @escaping (MessageId) -> Void,
        canSetupReply: @escaping (Message) -> ChatControllerInteractionSwipeAction,
        canSendMessages: @escaping () -> Bool,
        navigateToFirstDateMessage: @escaping(Int32, Bool) ->Void,
        requestRedeliveryOfFailedMessages: @escaping (MessageId) -> Void,
        addContact: @escaping (String) -> Void,
        rateCall: @escaping (Message, CallId, Bool) -> Void,
        requestSelectMessagePollOptions: @escaping (MessageId, [Data]) -> Void,
        requestOpenMessagePollResults: @escaping (MessageId, MediaId) -> Void,
        openAppStorePage: @escaping () -> Void,
        displayMessageTooltip: @escaping (MessageId, String, Bool, ASDisplayNode?, CGRect?) -> Void,
        seekToTimecode: @escaping (Message, Double, Bool) -> Void,
        scheduleCurrentMessage: @escaping (ChatSendMessageActionSheetController.SendParameters?) -> Void,
        sendScheduledMessagesNow: @escaping ([MessageId]) -> Void,
        editScheduledMessagesTime: @escaping ([MessageId]) -> Void,
        performTextSelectionAction: @escaping (Message?, Bool, NSAttributedString, TextSelectionAction) -> Void,
        displayImportedMessageTooltip: @escaping (ASDisplayNode) -> Void,
        displaySwipeToReplyHint: @escaping () -> Void,
        dismissReplyMarkupMessage: @escaping (Message) -> Void,
        openMessagePollResults: @escaping (MessageId, Data) -> Void,
        openPollCreation: @escaping (Bool?) -> Void,
        displayPollSolution: @escaping (TelegramMediaPollResults.Solution, ASDisplayNode) -> Void,
        displayPsa: @escaping (String, ASDisplayNode) -> Void,
        displayDiceTooltip: @escaping (TelegramMediaDice) -> Void,
        animateDiceSuccess: @escaping (Bool, Bool) -> Void,
        displayPremiumStickerTooltip: @escaping (TelegramMediaFile, Message) -> Void,
        displayEmojiPackTooltip: @escaping (TelegramMediaFile, Message) -> Void,
        openPeerContextMenu: @escaping (Peer, MessageId?, ASDisplayNode, CGRect, ContextGesture?) -> Void,
        openMessageReplies: @escaping (MessageId, Bool, Bool) -> Void,
        openReplyThreadOriginalMessage: @escaping (Message) -> Void,
        openMessageStats: @escaping (MessageId) -> Void,
        editMessageMedia: @escaping (MessageId, Bool) -> Void,
        copyText: @escaping (String) -> Void,
        displayUndo: @escaping (UndoOverlayContent) -> Void,
        isAnimatingMessage: @escaping (UInt32) -> Bool,
        getMessageTransitionNode: @escaping () -> ChatMessageTransitionProtocol?,
        updateChoosingSticker: @escaping (Bool) -> Void,
        commitEmojiInteraction: @escaping (MessageId, String, EmojiInteraction, TelegramMediaFile) -> Void,
        openLargeEmojiInfo: @escaping (String, String?, TelegramMediaFile) -> Void,
        openJoinLink: @escaping (String) -> Void,
        openWebView: @escaping (String, String, Bool, ChatOpenWebViewSource) -> Void,
        activateAdAction: @escaping (EngineMessage.Id, Promise<Bool>?, Bool, Bool) -> Void,
        adContextAction: @escaping (Message, ASDisplayNode, ContextGesture?) -> Void,
        removeAd: @escaping (Data) -> Void,
        openRequestedPeerSelection: @escaping (EngineMessage.Id, ReplyMarkupButtonRequestPeerType, Int32, Int32) -> Void,
        saveMediaToFiles: @escaping (EngineMessage.Id) -> Void,
        openNoAdsDemo: @escaping () -> Void,
        openAdsInfo: @escaping () -> Void,
        displayGiveawayParticipationStatus: @escaping (EngineMessage.Id) -> Void,
        openPremiumStatusInfo: @escaping (EnginePeer.Id, UIView, Int64?, PeerNameColor) -> Void,
        openRecommendedChannelContextMenu: @escaping (EnginePeer, UIView, ContextGesture?) -> Void,
        openGroupBoostInfo: @escaping (EnginePeer.Id?, Int) -> Void,
        openStickerEditor: @escaping () -> Void,
        openAgeRestrictedMessageMedia: @escaping (Message, @escaping () -> Void) -> Void,
        playMessageEffect: @escaping (Message) -> Void,
        editMessageFactCheck: @escaping (MessageId) -> Void,
        sendGift: @escaping (EnginePeer.Id) -> Void,
        openUniqueGift: @escaping (String) -> Void,
        openMessageFeeException: @escaping () -> Void,
        requestMessageUpdate: @escaping (MessageId, Bool) -> Void,
        cancelInteractiveKeyboardGestures: @escaping () -> Void,
        dismissTextInput: @escaping () -> Void,
        scrollToMessageId: @escaping (MessageIndex) -> Void,
        navigateToStory: @escaping (Message, StoryId) -> Void,
        attemptedNavigationToPrivateQuote: @escaping (Peer?) -> Void,
        forceUpdateWarpContents: @escaping () -> Void,
        playShakeAnimation: @escaping () -> Void,
        displayQuickShare: @escaping (MessageId, ASDisplayNode, ContextGesture) -> Void,
        updateChatLocationThread: @escaping (Int64?, ChatControllerAnimateInnerChatSwitchDirection?) -> Void,
        requestToggleTodoMessageItem: @escaping (MessageId, Int32, Bool) -> Void,
        displayTodoToggleUnavailable: @escaping (MessageId) -> Void,
        openStarsPurchase: @escaping (Int64?) -> Void,
        automaticMediaDownloadSettings: MediaAutoDownloadSettings,
        pollActionState: ChatInterfacePollActionState,
        stickerSettings: ChatInterfaceStickerSettings,
        presentationContext: ChatPresentationContext
    ) {
        self.openMessage = openMessage
        self.openPeer = openPeer
        self.openPeerMention = openPeerMention
        self.openMessageContextMenu = openMessageContextMenu
        self.openMessageReactionContextMenu = openMessageReactionContextMenu
        self.updateMessageReaction = updateMessageReaction
        self.activateMessagePinch = activateMessagePinch
        self.openMessageContextActions = openMessageContextActions
        self.navigateToMessage = navigateToMessage
        self.navigateToMessageStandalone = navigateToMessageStandalone
        self.navigateToThreadMessage = navigateToThreadMessage
        self.tapMessage = tapMessage
        self.clickThroughMessage = clickThroughMessage
        self.toggleMessagesSelection = toggleMessagesSelection
        self.sendCurrentMessage = sendCurrentMessage
        self.sendMessage = sendMessage
        self.sendSticker = sendSticker
        self.sendEmoji = sendEmoji
        self.sendGif = sendGif
        self.sendBotContextResultAsGif = sendBotContextResultAsGif
        self.requestMessageActionCallback = requestMessageActionCallback
        self.requestMessageActionUrlAuth = requestMessageActionUrlAuth
        self.activateSwitchInline = activateSwitchInline
        self.openUrl = openUrl
        self.shareCurrentLocation = shareCurrentLocation
        self.shareAccountContact = shareAccountContact
        self.sendBotCommand = sendBotCommand
        self.openInstantPage = openInstantPage
        self.openWallpaper = openWallpaper
        self.openTheme = openTheme
        self.openHashtag = openHashtag
        self.updateInputState = updateInputState
        self.updateInputMode = updateInputMode
        self.openMessageShareMenu = openMessageShareMenu
        self.presentController = presentController
        self.presentControllerInCurrent = presentControllerInCurrent
        self.navigationController = navigationController
        self.chatControllerNode = chatControllerNode
        self.presentGlobalOverlayController = presentGlobalOverlayController
        self.callPeer = callPeer
        self.openConferenceCall = openConferenceCall
        self.longTap = longTap
        self.todoItemLongTap = todoItemLongTap
        self.openCheckoutOrReceipt = openCheckoutOrReceipt
        self.openSearch = openSearch
        self.setupReply = setupReply
        self.canSetupReply = canSetupReply
        self.canSendMessages = canSendMessages
        self.navigateToFirstDateMessage = navigateToFirstDateMessage
        self.requestRedeliveryOfFailedMessages = requestRedeliveryOfFailedMessages
        self.addContact = addContact
        self.rateCall = rateCall
        self.requestSelectMessagePollOptions = requestSelectMessagePollOptions
        self.requestOpenMessagePollResults = requestOpenMessagePollResults
        self.openPollCreation = openPollCreation
        self.displayPollSolution = displayPollSolution
        self.displayPsa = displayPsa
        self.openAppStorePage = openAppStorePage
        self.displayMessageTooltip = displayMessageTooltip
        self.seekToTimecode = seekToTimecode
        self.scheduleCurrentMessage = scheduleCurrentMessage
        self.sendScheduledMessagesNow = sendScheduledMessagesNow
        self.editScheduledMessagesTime = editScheduledMessagesTime
        self.performTextSelectionAction = performTextSelectionAction
        self.displayImportedMessageTooltip = displayImportedMessageTooltip
        self.displaySwipeToReplyHint = displaySwipeToReplyHint
        self.dismissReplyMarkupMessage = dismissReplyMarkupMessage
        self.openMessagePollResults = openMessagePollResults
        self.displayDiceTooltip = displayDiceTooltip
        self.animateDiceSuccess = animateDiceSuccess
        self.displayPremiumStickerTooltip = displayPremiumStickerTooltip
        self.displayEmojiPackTooltip = displayEmojiPackTooltip
        self.openPeerContextMenu = openPeerContextMenu
        self.openMessageReplies = openMessageReplies
        self.openReplyThreadOriginalMessage = openReplyThreadOriginalMessage
        self.openMessageStats = openMessageStats
        self.editMessageMedia = editMessageMedia
        self.copyText = copyText
        self.displayUndo = displayUndo
        self.isAnimatingMessage = isAnimatingMessage
        self.getMessageTransitionNode = getMessageTransitionNode
        self.updateChoosingSticker = updateChoosingSticker
        self.commitEmojiInteraction = commitEmojiInteraction
        self.openLargeEmojiInfo = openLargeEmojiInfo
        self.openJoinLink = openJoinLink
        self.openWebView = openWebView
        self.activateAdAction = activateAdAction
        self.adContextAction = adContextAction
        self.removeAd = removeAd
        self.openRequestedPeerSelection = openRequestedPeerSelection
        self.saveMediaToFiles = saveMediaToFiles
        self.openNoAdsDemo = openNoAdsDemo
        self.openAdsInfo = openAdsInfo
        self.displayGiveawayParticipationStatus = displayGiveawayParticipationStatus
        self.openPremiumStatusInfo = openPremiumStatusInfo
        self.openRecommendedChannelContextMenu = openRecommendedChannelContextMenu
        self.openGroupBoostInfo = openGroupBoostInfo
        self.openStickerEditor = openStickerEditor
        self.openAgeRestrictedMessageMedia = openAgeRestrictedMessageMedia
        self.playMessageEffect = playMessageEffect
        self.editMessageFactCheck = editMessageFactCheck
        self.sendGift = sendGift
        self.openUniqueGift = openUniqueGift
        self.openMessageFeeException = openMessageFeeException
        
        self.requestMessageUpdate = requestMessageUpdate
        self.cancelInteractiveKeyboardGestures = cancelInteractiveKeyboardGestures
        self.dismissTextInput = dismissTextInput
        self.scrollToMessageId = scrollToMessageId
        self.navigateToStory = navigateToStory
        self.attemptedNavigationToPrivateQuote = attemptedNavigationToPrivateQuote
        self.forceUpdateWarpContents = forceUpdateWarpContents
        self.playShakeAnimation = playShakeAnimation
        self.displayQuickShare = displayQuickShare
        self.updateChatLocationThread = updateChatLocationThread
        self.requestToggleTodoMessageItem = requestToggleTodoMessageItem
        self.displayTodoToggleUnavailable = displayTodoToggleUnavailable
        self.openStarsPurchase = openStarsPurchase
        
        self.automaticMediaDownloadSettings = automaticMediaDownloadSettings
        
        self.pollActionState = pollActionState
        self.stickerSettings = stickerSettings

        self.presentationContext = presentationContext
    }
    
    deinit {
        self.isOpeningMediaDisposable?.dispose()
    }
}
