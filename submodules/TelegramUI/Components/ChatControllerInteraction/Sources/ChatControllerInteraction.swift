import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
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
    public let subject: EngineMessageReplyInnerSubject?
    
    public init(messageStableId: UInt32, quote: Quote?, subject: EngineMessageReplyInnerSubject?) {
        self.messageStableId = messageStableId
        self.quote = quote
        self.subject = subject
    }
}

public struct ChatInterfacePollActionState: Equatable {
    public var pollMessageIdsInProgress: [EngineMessage.Id: [Data]] = [:]
    
    public init(pollMessageIdsInProgress: [EngineMessage.Id: [Data]] = [:]) {
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
    public var peerId: EnginePeer.Id
    public var namespace: Int32
    
    public init(peerId: EnginePeer.Id, namespace: Int32) {
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
    public var subject: EngineMessageReplyInnerSubject?
    public var progress: Promise<Bool>?
    public var forceNew: Bool
    public var setupReply: Bool
    
    public init(timestamp: Double? = nil, quote: Quote? = nil, subject: EngineMessageReplyInnerSubject? = nil, progress: Promise<Bool>? = nil, forceNew: Bool = false, setupReply: Bool = false) {
        self.timestamp = timestamp
        self.quote = quote
        self.subject = subject
        self.progress = progress
        self.forceNew = forceNew
        self.setupReply = setupReply
    }
}

public struct OpenMessageParams {
    public var mode: ChatControllerInteractionOpenMessageMode
    public var mediaSubject: GalleryMediaSubject?
    public var progress: Promise<Bool>?
    
    public init(mode: ChatControllerInteractionOpenMessageMode, mediaSubject: GalleryMediaSubject? = nil, progress: Promise<Bool>? = nil) {
        self.mode = mode
        self.mediaSubject = mediaSubject
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
        case groupParticipant(storyStats: EnginePeerStoryStats?, avatarHeaderNode: ASDisplayNode?)
    }
    
    public struct OpenUrl {
        public var url: String
        public var concealed: Bool
        public var external: Bool?
        public var message: EngineRawMessage?
        public var allowInlineWebpageResolution: Bool
        public var progress: Promise<Bool>?
        
        public init(url: String, concealed: Bool, external: Bool? = nil, message: EngineRawMessage? = nil, allowInlineWebpageResolution: Bool = false, progress: Promise<Bool>? = nil) {
            self.url = url
            self.concealed = concealed
            self.external = external
            self.message = message
            self.allowInlineWebpageResolution = allowInlineWebpageResolution
            self.progress = progress
        }
    }
    
    public struct OpenInstantPage {
        public var webpageId: EngineMedia.Id
        public var url: String
        public var anchor: String?
        public var concealed: Bool
        public var progress: Promise<Bool>?
        
        public init(webpageId: EngineMedia.Id, url: String, anchor: String?, concealed: Bool, progress: Promise<Bool>? = nil) {
            self.webpageId = webpageId
            self.url = url
            self.anchor = anchor
            self.concealed = concealed
            self.progress = progress
        }
    }
    
    public struct LongTapParams {
        public var message: EngineRawMessage?
        public var contentNode: ContextExtractedContentContainingNode?
        public var messageNode: ASDisplayNode?
        public var progress: Promise<Bool>?
        public var gesture: TapLongTapOrDoubleTapGestureRecognizer?
        
        public init(message: EngineRawMessage? = nil, contentNode: ContextExtractedContentContainingNode? = nil, messageNode: ASDisplayNode? = nil, progress: Promise<Bool>? = nil, gesture: TapLongTapOrDoubleTapGestureRecognizer? = nil) {
            self.message = message
            self.contentNode = contentNode
            self.messageNode = messageNode
            self.progress = progress
            self.gesture = gesture
        }
    }
    
    public enum PollMediaSubject {
        case option(TelegramMediaPollOption)
        case solution(TelegramMediaPollResults.Solution)
    }
    
    public let openMessage: (EngineRawMessage, OpenMessageParams) -> Bool
    public let openPeer: (EnginePeer, ChatControllerInteractionNavigateToPeer, MessageReference?, OpenPeerSource) -> Void
    public let openPeerMention: (String, Promise<Bool>?) -> Void
    public let openMessageContextMenu: (EngineRawMessage, Bool, ASDisplayNode, CGRect, UIGestureRecognizer?, CGPoint?) -> Void
    public let updateMessageReaction: (EngineRawMessage, ChatControllerInteractionReaction, Bool, ContextExtractedContentContainingView?) -> Void
    public let openMessageReactionContextMenu: (EngineRawMessage, ContextExtractedContentContainingView, ContextGesture?, MessageReaction.Reaction) -> Void
    public let activateMessagePinch: (PinchSourceContainerNode) -> Void
    public let openMessageContextActions: (EngineRawMessage, ASDisplayNode, CGRect, ContextGesture?) -> Void
    public let navigateToMessage: (EngineMessage.Id, EngineMessage.Id, NavigateToMessageParams) -> Void
    public let navigateToMessageStandalone: (EngineMessage.Id) -> Void
    public let navigateToThreadMessage: (EnginePeer.Id, Int64, EngineMessage.Id?) -> Void
    public let tapMessage: ((EngineRawMessage) -> Void)?
    public let clickThroughMessage: (UIView?, CGPoint?) -> Void
    public let toggleMessagesSelection: ([EngineMessage.Id], Bool) -> Void
    public let sendCurrentMessage: (Bool, ChatSendMessageEffect?) -> Void
    public let sendMessage: (String, EngineMessage.Id?) -> Void
    public let sendSticker: (FileMediaReference, Bool, Bool, String?, Bool, UIView?, CGRect?, CALayer?, [EngineItemCollectionId]) -> Bool
    public let sendEmoji: (String, ChatTextInputTextCustomEmojiAttribute, Bool) -> Void
    public let sendGif: (FileMediaReference, UIView, CGRect, Bool, Bool) -> Bool
    public let sendBotContextResultAsGif: (ChatContextResultCollection, ChatContextResult, UIView, CGRect, Bool, Bool) -> Bool
    public let editGif: (FileMediaReference, Bool) -> Void
    public let requestMessageActionCallback: (EngineRawMessage, EngineMemoryBuffer?, Bool, Bool, Promise<Bool>?) -> Void
    public let requestMessageActionUrlAuth: (String, MessageActionUrlSubject) -> Void
    public let activateSwitchInline: (EnginePeer.Id?, String, ReplyMarkupButtonAction.PeerTypes?) -> Void
    public let openUrl: (OpenUrl) -> Void
    public let openExternalInstantPage: (OpenInstantPage) -> Void
    public let shareCurrentLocation: (EngineMessage.Id?) -> Void
    public let shareAccountContact: (EngineMessage.Id?) -> Void
    public let sendBotCommand: (EngineMessage.Id?, String) -> Void
    public let openInstantPage: (EngineRawMessage, ChatMessageItemAssociatedData?) -> Void
    public let openWallpaper: (EngineRawMessage) -> Void
    public let openTheme: (EngineRawMessage) -> Void
    public let openHashtag: (String?, String) -> Void
    public let updateInputState: ((ChatTextInputState) -> ChatTextInputState) -> Void
    public let updateInputMode: ((ChatInputMode) -> ChatInputMode) -> Void
    public let updatePresentationState: ((ChatPresentationInterfaceState) -> ChatPresentationInterfaceState) -> Void
    public let openMessageShareMenu: (EngineMessage.Id) -> Void
    public let presentController: (ViewController, Any?) -> Void
    public let presentControllerInCurrent: (ViewController, Any?) -> Void
    public let navigationController: () -> NavigationController?
    public let chatControllerNode: () -> ASDisplayNode?
    public let presentGlobalOverlayController: (ViewController, Any?) -> Void
    public let callPeer: (EnginePeer.Id, Bool) -> Void
    public let openConferenceCall: (EngineRawMessage) -> Void
    public let longTap: (ChatControllerInteractionLongTapAction, LongTapParams?) -> Void
    public let todoItemLongTap: (Int32, LongTapParams?) -> Void
    public let pollOptionLongTap: (Data, LongTapParams?) -> Void
    public let openCheckoutOrReceipt: (EngineMessage.Id, OpenMessageParams?) -> Void
    public let openSearch: () -> Void
    public let setupReply: (EngineMessage.Id) -> Void
    public let canSetupReply: (EngineRawMessage) -> ChatControllerInteractionSwipeAction
    public let canSendMessages: () -> Bool
    public let navigateToFirstDateMessage: (Int32, Bool) -> Void
    public let requestRedeliveryOfFailedMessages: (EngineMessage.Id) -> Void
    public let addContact: (String) -> Void
    public let rateCall: (EngineRawMessage, CallId, Bool) -> Void
    public let requestSelectMessagePollOptions: (EngineMessage.Id, [Data]) -> Void
    public let requestAddMessagePollOption: (EngineMessage.Id, String, [MessageTextEntity], Data, AnyMediaReference?) -> Void
    public let requestOpenMessagePollResults: (EngineMessage.Id, EngineMedia.Id) -> Void
    public let openAppStorePage: () -> Void
    public let displayMessageTooltip: (EngineMessage.Id, String, Bool, ASDisplayNode?, CGRect?) -> Void
    public let seekToTimecode: (EngineRawMessage, Double, Bool) -> Void
    public let scheduleCurrentMessage: (ChatSendMessageActionSheetController.SendParameters?) -> Void
    public let sendScheduledMessagesNow: ([EngineMessage.Id]) -> Void
    public let editScheduledMessagesTime: ([EngineMessage.Id]) -> Void
    public let performTextSelectionAction: (EngineRawMessage?, Bool, NSAttributedString, [MessageTextEntity]?, TextSelectionAction) -> Void
    public let displayImportedMessageTooltip: (ASDisplayNode) -> Void
    public let displaySwipeToReplyHint: () -> Void
    public let dismissReplyMarkupMessage: (EngineRawMessage) -> Void
    public let openMessagePollResults: (EngineMessage.Id, Data) -> Void
    public let openPollCreation: (EngineMessage.Id?, Bool?) -> Void
    public let openPollMedia: (EngineRawMessage, PollMediaSubject) -> Void
    public let displayPollSolution: (TelegramMediaPollResults.Solution?, ASDisplayNode?) -> Void
    public let displayPsa: (String, ASDisplayNode) -> Void
    public let displayDiceTooltip: (TelegramMediaDice) -> Void
    public let animateDiceSuccess: (Bool, Bool) -> Void
    public let displayPremiumStickerTooltip: (TelegramMediaFile, EngineRawMessage) -> Void
    public let displayEmojiPackTooltip: (TelegramMediaFile, EngineRawMessage) -> Void
    public let openPeerContextMenu: (EngineRawPeer, EngineMessage.Id?, ASDisplayNode, CGRect, ContextGesture?) -> Void
    public let openMessageReplies: (EngineMessage.Id, Bool, Bool) -> Void
    public let openReplyThreadOriginalMessage: (EngineRawMessage) -> Void
    public let openMessageStats: (EngineMessage.Id) -> Void
    public let editMessageMedia: (EngineMessage.Id, Bool) -> Void
    public let copyText: (String) -> Void
    public let accessibilityForwardMessage: (EngineRawMessage) -> Void
    public let accessibilityDeleteMessage: (EngineRawMessage) -> Void
    public let canPerformAccessibilityMessageActions: Bool
    public var accessibilityNavigationTargetMessageId: EngineMessage.Id?
    public let displayUndo: (UndoOverlayContent) -> Void
    public let isAnimatingMessage: (UInt32) -> Bool
    public let getMessageTransitionNode: () -> ChatMessageTransitionProtocol?
    public let updateChoosingSticker: (Bool) -> Void
    public let commitEmojiInteraction: (EngineMessage.Id, String, EmojiInteraction, TelegramMediaFile) -> Void
    public let openLargeEmojiInfo: (String, String?, TelegramMediaFile) -> Void
    public let openJoinLink: (String) -> Void
    public let openWebView: (String, String, Bool, ChatOpenWebViewSource) -> Void
    public let activateAdAction: (EngineMessage.Id, Promise<Bool>?, Bool, Bool) -> Void
    public let adContextAction: (EngineRawMessage, ASDisplayNode, ContextGesture?) -> Void
    public let removeAd: (Data) -> Void
    public let openRequestedPeerSelection: (EngineMessage.Id, ReplyMarkupButtonRequestPeerType, Int32, Int32) -> Void
    public let saveMediaToFiles: (EngineMessage.Id) -> Void
    public let openNoAdsDemo: () -> Void
    public let openAdsInfo: () -> Void
    public let displayGiveawayParticipationStatus: (EngineMessage.Id) -> Void
    public let openPremiumStatusInfo: (EnginePeer.Id, UIView, Int64?, PeerColor) -> Void
    public let openRecommendedChannelContextMenu: (EnginePeer, UIView, ContextGesture?) -> Void
    public let openGroupBoostInfo: (EnginePeer.Id?, Int) -> Void
    public let openStickerEditor: () -> Void
    public let openAgeRestrictedMessageMedia: (EngineRawMessage, @escaping () -> Void) -> Void
    public let playMessageEffect: (EngineRawMessage) -> Void
    public let editMessageFactCheck: (EngineMessage.Id) -> Void
    public let sendGift: (EnginePeer.Id) -> Void
    public let openUniqueGift: (String) -> Void
    public let openMessageFeeException: () -> Void
    public let requestMessageUpdate: (EngineMessage.Id, Bool, ControlledTransition?) -> Void
    /// Synchronous editability predicate for rich-text checkbox toggling (bridges the
    /// internal `canEditMessage`, which the component module cannot call). Mirrors `canSetupReply`.
    public let canEditMessageRichText: (EngineRawMessage) -> Bool
    /// Toggle a rich-message checklist checkbox at `path` to `value` and persist via an edit.
    public let toggleMessageRichTextCheckbox: (EngineMessage.Id, [Int], Bool) -> Void
    public let cancelInteractiveKeyboardGestures: () -> Void
    public let dismissTextInput: () -> Void
    public let scrollToMessageId: (EngineMessage.Index, CGFloat) -> Void
    public let scrollToMessageIdWithAnchor: (EngineMessage.Index, String) -> Void
    public let navigateToStory: (EngineRawMessage, EngineStoryId) -> Void
    public let attemptedNavigationToPrivateQuote: (EngineRawPeer?) -> Void
    public let forceUpdateWarpContents: () -> Void
    public let playShakeAnimation:  () -> Void
    public let displayQuickShare: (EngineMessage.Id, ASDisplayNode, ContextGesture) -> Void
    public let updateChatLocationThread: (Int64?, ChatControllerAnimateInnerChatSwitchDirection?) -> Void
    public let requestToggleTodoMessageItem: (EngineMessage.Id, Int32, Bool) -> Void
    public let displayTodoToggleUnavailable: (EngineMessage.Id) -> Void
    public let openStarsPurchase: (Int64?) -> Void
    public let openRankInfo: (EnginePeer, ChatRankInfoScreenRole, String) -> Void
    public let openSetPeerAvatar: () -> Void
    public let displayPollRestrictedToast: (EngineMessage.Id) -> Void
    
    public var canPlayMedia: Bool = false
    public var hiddenMedia: [EngineMessage.Id: [EngineRawMedia]] = [:]
    public var expandedTranslationMessageStableIds: Set<UInt32> = Set()
    public var selectionState: ChatInterfaceSelectionState?
    public var highlightedState: ChatInterfaceHighlightedState?
    public var contextHighlightedState: ChatInterfaceHighlightedState?
    public var automaticMediaDownloadSettings: MediaAutoDownloadSettings
    public var pollActionState: ChatInterfacePollActionState
    public var currentPollMessageWithTooltip: EngineMessage.Id?
    public var currentPsaMessageWithTooltip: EngineMessage.Id?
    public var stickerSettings: ChatInterfaceStickerSettings
    public var searchTextHighightState: (String, [EngineMessage.Index])?
    public var unreadMessageRange: [UnreadMessageRangeKey: Range<Int32>] = [:]
    public var seenOneTimeAnimatedMedia = Set<EngineMessage.Id>()
    public var currentMessageWithLoadingReplyThread: EngineMessage.Id?
    public var updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    public let presentationContext: ChatPresentationContext
    public var playNextOutgoingGift: Bool = false
    public var recommendedChannelsOpenUp: Bool = false
    public var enableFullTranslucency: Bool = true
    public var chatIsRotated: Bool = true
    public var canReadHistory: Bool = false
    public var summarizedMessageIds: Set<EngineMessage.Id> = Set()
    public var focusedTextInputIsMedia: Bool = false
    public var focusedPollAddOptionMessageId: EngineMessage.Id?
    
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
        openMessage: @escaping (EngineRawMessage, OpenMessageParams) -> Bool,
        openPeer: @escaping (EnginePeer, ChatControllerInteractionNavigateToPeer, MessageReference?, OpenPeerSource) -> Void,
        openPeerMention: @escaping (String, Promise<Bool>?) -> Void,
        openMessageContextMenu: @escaping (EngineRawMessage, Bool, ASDisplayNode, CGRect, UIGestureRecognizer?, CGPoint?) -> Void,
        openMessageReactionContextMenu: @escaping (EngineRawMessage, ContextExtractedContentContainingView, ContextGesture?, MessageReaction.Reaction) -> Void,
        updateMessageReaction: @escaping (EngineRawMessage, ChatControllerInteractionReaction, Bool, ContextExtractedContentContainingView?) -> Void,
        activateMessagePinch: @escaping (PinchSourceContainerNode) -> Void,
        openMessageContextActions: @escaping (EngineRawMessage, ASDisplayNode, CGRect, ContextGesture?) -> Void,
        navigateToMessage: @escaping (EngineMessage.Id, EngineMessage.Id, NavigateToMessageParams) -> Void,
        navigateToMessageStandalone: @escaping (EngineMessage.Id) -> Void,
        navigateToThreadMessage: @escaping (EnginePeer.Id, Int64, EngineMessage.Id?) -> Void,
        tapMessage: ((EngineRawMessage) -> Void)?,
        clickThroughMessage: @escaping (UIView?, CGPoint?) -> Void,
        toggleMessagesSelection: @escaping ([EngineMessage.Id], Bool) -> Void,
        sendCurrentMessage: @escaping (Bool, ChatSendMessageEffect?) -> Void,
        sendMessage: @escaping (String, EngineMessage.Id?) -> Void,
        sendSticker: @escaping (FileMediaReference, Bool, Bool, String?, Bool, UIView?, CGRect?, CALayer?, [EngineItemCollectionId]) -> Bool,
        sendEmoji: @escaping (String, ChatTextInputTextCustomEmojiAttribute, Bool) -> Void,
        sendGif: @escaping (FileMediaReference, UIView, CGRect, Bool, Bool) -> Bool,
        sendBotContextResultAsGif: @escaping (ChatContextResultCollection, ChatContextResult, UIView, CGRect, Bool, Bool) -> Bool,
        editGif: @escaping (FileMediaReference, Bool) -> Void,
        requestMessageActionCallback: @escaping (EngineRawMessage, EngineMemoryBuffer?, Bool, Bool, Promise<Bool>?) -> Void,
        requestMessageActionUrlAuth: @escaping (String, MessageActionUrlSubject) -> Void,
        activateSwitchInline: @escaping (EnginePeer.Id?, String, ReplyMarkupButtonAction.PeerTypes?) -> Void,
        openUrl: @escaping (OpenUrl) -> Void,
        openExternalInstantPage: @escaping (OpenInstantPage) -> Void,
        shareCurrentLocation: @escaping (EngineMessage.Id?) -> Void,
        shareAccountContact: @escaping (EngineMessage.Id?) -> Void,
        sendBotCommand: @escaping (EngineMessage.Id?, String) -> Void,
        openInstantPage: @escaping (EngineRawMessage, ChatMessageItemAssociatedData?) -> Void,
        openWallpaper: @escaping (EngineRawMessage) -> Void,
        openTheme: @escaping (EngineRawMessage) -> Void,
        openHashtag: @escaping (String?, String) -> Void,
        updateInputState: @escaping ((ChatTextInputState) -> ChatTextInputState) -> Void,
        updateInputMode: @escaping ((ChatInputMode) -> ChatInputMode) -> Void,
        updatePresentationState: @escaping ((ChatPresentationInterfaceState) -> ChatPresentationInterfaceState) -> Void,
        openMessageShareMenu: @escaping (EngineMessage.Id) -> Void,
        presentController: @escaping (ViewController, Any?) -> Void,
        presentControllerInCurrent: @escaping (ViewController, Any?) -> Void,
        navigationController: @escaping () -> NavigationController?,
        chatControllerNode: @escaping () -> ASDisplayNode?,
        presentGlobalOverlayController: @escaping (ViewController, Any?) -> Void,
        callPeer: @escaping (EnginePeer.Id, Bool) -> Void,
        openConferenceCall: @escaping (EngineRawMessage) -> Void,
        longTap: @escaping (ChatControllerInteractionLongTapAction, LongTapParams?) -> Void,
        todoItemLongTap: @escaping (Int32, LongTapParams?) -> Void,
        pollOptionLongTap: @escaping (Data, LongTapParams?) -> Void,
        openCheckoutOrReceipt: @escaping (EngineMessage.Id, OpenMessageParams?) -> Void,
        openSearch: @escaping () -> Void,
        setupReply: @escaping (EngineMessage.Id) -> Void,
        canSetupReply: @escaping (EngineRawMessage) -> ChatControllerInteractionSwipeAction,
        canSendMessages: @escaping () -> Bool,
        navigateToFirstDateMessage: @escaping(Int32, Bool) ->Void,
        requestRedeliveryOfFailedMessages: @escaping (EngineMessage.Id) -> Void,
        addContact: @escaping (String) -> Void,
        rateCall: @escaping (EngineRawMessage, CallId, Bool) -> Void,
        requestSelectMessagePollOptions: @escaping (EngineMessage.Id, [Data]) -> Void,
        requestAddMessagePollOption: @escaping (EngineMessage.Id, String, [MessageTextEntity], Data, AnyMediaReference?) -> Void,
        requestOpenMessagePollResults: @escaping (EngineMessage.Id, EngineMedia.Id) -> Void,
        openAppStorePage: @escaping () -> Void,
        displayMessageTooltip: @escaping (EngineMessage.Id, String, Bool, ASDisplayNode?, CGRect?) -> Void,
        seekToTimecode: @escaping (EngineRawMessage, Double, Bool) -> Void,
        scheduleCurrentMessage: @escaping (ChatSendMessageActionSheetController.SendParameters?) -> Void,
        sendScheduledMessagesNow: @escaping ([EngineMessage.Id]) -> Void,
        editScheduledMessagesTime: @escaping ([EngineMessage.Id]) -> Void,
        performTextSelectionAction: @escaping (EngineRawMessage?, Bool, NSAttributedString, [MessageTextEntity]?, TextSelectionAction) -> Void,
        displayImportedMessageTooltip: @escaping (ASDisplayNode) -> Void,
        displaySwipeToReplyHint: @escaping () -> Void,
        dismissReplyMarkupMessage: @escaping (EngineRawMessage) -> Void,
        openMessagePollResults: @escaping (EngineMessage.Id, Data) -> Void,
        openPollCreation: @escaping (EngineMessage.Id?, Bool?) -> Void,
        openPollMedia: @escaping (EngineRawMessage, PollMediaSubject) -> Void,
        displayPollSolution: @escaping (TelegramMediaPollResults.Solution?, ASDisplayNode?) -> Void,
        displayPsa: @escaping (String, ASDisplayNode) -> Void,
        displayDiceTooltip: @escaping (TelegramMediaDice) -> Void,
        animateDiceSuccess: @escaping (Bool, Bool) -> Void,
        displayPremiumStickerTooltip: @escaping (TelegramMediaFile, EngineRawMessage) -> Void,
        displayEmojiPackTooltip: @escaping (TelegramMediaFile, EngineRawMessage) -> Void,
        openPeerContextMenu: @escaping (EngineRawPeer, EngineMessage.Id?, ASDisplayNode, CGRect, ContextGesture?) -> Void,
        openMessageReplies: @escaping (EngineMessage.Id, Bool, Bool) -> Void,
        openReplyThreadOriginalMessage: @escaping (EngineRawMessage) -> Void,
        openMessageStats: @escaping (EngineMessage.Id) -> Void,
        editMessageMedia: @escaping (EngineMessage.Id, Bool) -> Void,
        copyText: @escaping (String) -> Void,
        displayUndo: @escaping (UndoOverlayContent) -> Void,
        isAnimatingMessage: @escaping (UInt32) -> Bool,
        getMessageTransitionNode: @escaping () -> ChatMessageTransitionProtocol?,
        updateChoosingSticker: @escaping (Bool) -> Void,
        commitEmojiInteraction: @escaping (EngineMessage.Id, String, EmojiInteraction, TelegramMediaFile) -> Void,
        openLargeEmojiInfo: @escaping (String, String?, TelegramMediaFile) -> Void,
        openJoinLink: @escaping (String) -> Void,
        openWebView: @escaping (String, String, Bool, ChatOpenWebViewSource) -> Void,
        activateAdAction: @escaping (EngineMessage.Id, Promise<Bool>?, Bool, Bool) -> Void,
        adContextAction: @escaping (EngineRawMessage, ASDisplayNode, ContextGesture?) -> Void,
        removeAd: @escaping (Data) -> Void,
        openRequestedPeerSelection: @escaping (EngineMessage.Id, ReplyMarkupButtonRequestPeerType, Int32, Int32) -> Void,
        saveMediaToFiles: @escaping (EngineMessage.Id) -> Void,
        openNoAdsDemo: @escaping () -> Void,
        openAdsInfo: @escaping () -> Void,
        displayGiveawayParticipationStatus: @escaping (EngineMessage.Id) -> Void,
        openPremiumStatusInfo: @escaping (EnginePeer.Id, UIView, Int64?, PeerColor) -> Void,
        openRecommendedChannelContextMenu: @escaping (EnginePeer, UIView, ContextGesture?) -> Void,
        openGroupBoostInfo: @escaping (EnginePeer.Id?, Int) -> Void,
        openStickerEditor: @escaping () -> Void,
        openAgeRestrictedMessageMedia: @escaping (EngineRawMessage, @escaping () -> Void) -> Void,
        playMessageEffect: @escaping (EngineRawMessage) -> Void,
        editMessageFactCheck: @escaping (EngineMessage.Id) -> Void,
        sendGift: @escaping (EnginePeer.Id) -> Void,
        openUniqueGift: @escaping (String) -> Void,
        openMessageFeeException: @escaping () -> Void,
        requestMessageUpdate: @escaping (EngineMessage.Id, Bool, ControlledTransition?) -> Void,
        cancelInteractiveKeyboardGestures: @escaping () -> Void,
        dismissTextInput: @escaping () -> Void,
        scrollToMessageId: @escaping (EngineMessage.Index, CGFloat) -> Void,
        scrollToMessageIdWithAnchor: @escaping (EngineMessage.Index, String) -> Void,
        navigateToStory: @escaping (EngineRawMessage, EngineStoryId) -> Void,
        attemptedNavigationToPrivateQuote: @escaping (EngineRawPeer?) -> Void,
        forceUpdateWarpContents: @escaping () -> Void,
        playShakeAnimation: @escaping () -> Void,
        displayQuickShare: @escaping (EngineMessage.Id, ASDisplayNode, ContextGesture) -> Void,
        updateChatLocationThread: @escaping (Int64?, ChatControllerAnimateInnerChatSwitchDirection?) -> Void,
        requestToggleTodoMessageItem: @escaping (EngineMessage.Id, Int32, Bool) -> Void,
        displayTodoToggleUnavailable: @escaping (EngineMessage.Id) -> Void,
        canEditMessageRichText: @escaping (EngineRawMessage) -> Bool = { _ in false },
        toggleMessageRichTextCheckbox: @escaping (EngineMessage.Id, [Int], Bool) -> Void = { _, _, _ in },
        accessibilityForwardMessage: @escaping (EngineRawMessage) -> Void = { _ in },
        accessibilityDeleteMessage: @escaping (EngineRawMessage) -> Void = { _ in },
        canPerformAccessibilityMessageActions: Bool = false,
        openStarsPurchase: @escaping (Int64?) -> Void,
        openRankInfo: @escaping (EnginePeer, ChatRankInfoScreenRole, String) -> Void,
        openSetPeerAvatar: @escaping () -> Void,
        displayPollRestrictedToast: @escaping (EngineMessage.Id) -> Void,
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
        self.editGif = editGif
        self.requestMessageActionCallback = requestMessageActionCallback
        self.requestMessageActionUrlAuth = requestMessageActionUrlAuth
        self.activateSwitchInline = activateSwitchInline
        self.openUrl = openUrl
        self.openExternalInstantPage = openExternalInstantPage
        self.shareCurrentLocation = shareCurrentLocation
        self.shareAccountContact = shareAccountContact
        self.sendBotCommand = sendBotCommand
        self.openInstantPage = openInstantPage
        self.openWallpaper = openWallpaper
        self.openTheme = openTheme
        self.openHashtag = openHashtag
        self.updateInputState = updateInputState
        self.updateInputMode = updateInputMode
        self.updatePresentationState = updatePresentationState
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
        self.pollOptionLongTap = pollOptionLongTap
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
        self.requestAddMessagePollOption = requestAddMessagePollOption
        self.requestOpenMessagePollResults = requestOpenMessagePollResults
        self.openPollCreation = openPollCreation
        self.openPollMedia = openPollMedia
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
        self.accessibilityForwardMessage = accessibilityForwardMessage
        self.accessibilityDeleteMessage = accessibilityDeleteMessage
        self.canPerformAccessibilityMessageActions = canPerformAccessibilityMessageActions
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
        self.canEditMessageRichText = canEditMessageRichText
        self.toggleMessageRichTextCheckbox = toggleMessageRichTextCheckbox
        self.cancelInteractiveKeyboardGestures = cancelInteractiveKeyboardGestures
        self.dismissTextInput = dismissTextInput
        self.scrollToMessageId = scrollToMessageId
        self.scrollToMessageIdWithAnchor = scrollToMessageIdWithAnchor
        self.navigateToStory = navigateToStory
        self.attemptedNavigationToPrivateQuote = attemptedNavigationToPrivateQuote
        self.forceUpdateWarpContents = forceUpdateWarpContents
        self.playShakeAnimation = playShakeAnimation
        self.displayQuickShare = displayQuickShare
        self.updateChatLocationThread = updateChatLocationThread
        self.requestToggleTodoMessageItem = requestToggleTodoMessageItem
        self.displayTodoToggleUnavailable = displayTodoToggleUnavailable
        self.openStarsPurchase = openStarsPurchase
        self.openRankInfo = openRankInfo
        self.openSetPeerAvatar = openSetPeerAvatar
        self.displayPollRestrictedToast = displayPollRestrictedToast
        
        self.automaticMediaDownloadSettings = automaticMediaDownloadSettings
        
        self.pollActionState = pollActionState
        self.stickerSettings = stickerSettings

        self.presentationContext = presentationContext
    }
    
    deinit {
        self.isOpeningMediaDisposable?.dispose()
    }
}
