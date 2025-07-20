import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import MediaResources
import AccountContext
import TemporaryCachedPeerDataManager
import ChatListSearchItemNode
import Emoji
import AppBundle
import ListMessageItem
import AccountContext
import ChatInterfaceState
import ChatListUI
import ComponentFlow
import ReactionSelectionNode
import ChatPresentationInterfaceState
import TelegramNotices
import ChatControllerInteraction
import TranslateUI
import ChatHistoryEntry
import ChatOverscrollControl
import ChatBotInfoItem
import ChatUserInfoItem
import ChatMessageItem
import ChatMessageItemImpl
import ChatMessageItemView
import ChatMessageBubbleItemNode
import ChatMessageTransitionNode
import ChatControllerInteraction
import DustEffect
import UrlHandling
import TextFormat

struct ChatTopVisibleMessageRange: Equatable {
    var lowerBound: MessageIndex
    var upperBound: MessageIndex
    var isLast: Bool
    var isLoading: Bool
}

private let historyMessageCount: Int = 44

enum ChatHistoryViewScrollPosition {
    case unread(index: MessageIndex)
    case positionRestoration(index: MessageIndex, relativeOffset: CGFloat)
    case index(subject: MessageHistoryScrollToSubject, position: ListViewScrollPosition, directionHint: ListViewScrollToItemDirectionHint, animated: Bool, highlight: Bool, displayLink: Bool, setupReply: Bool)
}

enum ChatHistoryViewUpdateType {
    case Initial(fadeIn: Bool)
    case Generic(type: ViewUpdateType)
}

public struct ChatHistoryCombinedInitialReadStateData {
    public let unreadCount: Int32
    public let totalState: ChatListTotalUnreadState?
    public let notificationSettings: PeerNotificationSettings?
}

public struct ChatHistoryCombinedInitialData {
    var initialData: InitialMessageHistoryData?
    var buttonKeyboardMessage: Message?
    var cachedData: CachedPeerData?
    var cachedDataMessages: [MessageId: Message]?
    var readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData]?
}

enum ChatHistoryViewUpdate {
    case Loading(initialData: ChatHistoryCombinedInitialData?, type: ChatHistoryViewUpdateType)
    case HistoryView(view: MessageHistoryView, type: ChatHistoryViewUpdateType, scrollPosition: ChatHistoryViewScrollPosition?, flashIndicators: Bool, originalScrollPosition: ChatHistoryViewScrollPosition?, initialData: ChatHistoryCombinedInitialData, id: Int32)
}

struct ChatHistoryView {
    let originalView: MessageHistoryView
    let filteredEntries: [ChatHistoryEntry]
    let associatedData: ChatMessageItemAssociatedData
    let lastHeaderId: Int64
    let id: Int32
    let locationInput: ChatHistoryLocationInput?
    let ignoreMessagesInTimestampRange: ClosedRange<Int32>?
    let ignoreMessageIds: Set<MessageId>
}

enum ChatHistoryViewTransitionReason {
    case Initial(fadeIn: Bool)
    case InteractiveChanges
    case Reload
    case HoleReload
}

struct ChatHistoryViewTransitionInsertEntry {
    let index: Int
    let previousIndex: Int?
    let entry: ChatHistoryEntry
    let directionHint: ListViewItemOperationDirectionHint?
}

struct ChatHistoryViewTransitionUpdateEntry {
    let index: Int
    let previousIndex: Int
    let entry: ChatHistoryEntry
    let directionHint: ListViewItemOperationDirectionHint?
}

struct ChatHistoryViewTransition {
    var historyView: ChatHistoryView
    var deleteItems: [ListViewDeleteItem]
    var insertEntries: [ChatHistoryViewTransitionInsertEntry]
    var updateEntries: [ChatHistoryViewTransitionUpdateEntry]
    var options: ListViewDeleteAndInsertOptions
    var scrollToItem: ListViewScrollToItem?
    var stationaryItemRange: (Int, Int)?
    var initialData: InitialMessageHistoryData?
    var keyboardButtonsMessage: Message?
    var cachedData: CachedPeerData?
    var cachedDataMessages: [MessageId: Message]?
    var readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData]?
    var scrolledToIndex: MessageHistoryScrollToSubject?
    var scrolledToSomeIndex: Bool
    var animateIn: Bool
    var reason: ChatHistoryViewTransitionReason
    var flashIndicators: Bool
}

struct ChatHistoryListViewTransition {
    var historyView: ChatHistoryView
    var deleteItems: [ListViewDeleteItem]
    var insertItems: [ListViewInsertItem]
    var updateItems: [ListViewUpdateItem]
    var options: ListViewDeleteAndInsertOptions
    var scrollToItem: ListViewScrollToItem?
    var stationaryItemRange: (Int, Int)?
    var initialData: InitialMessageHistoryData?
    var keyboardButtonsMessage: Message?
    var cachedData: CachedPeerData?
    var cachedDataMessages: [MessageId: Message]?
    var readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData]?
    var scrolledToIndex: MessageHistoryScrollToSubject?
    var scrolledToSomeIndex: Bool
    var peerType: MediaAutoDownloadPeerType
    var networkType: MediaAutoDownloadNetworkType
    var animateIn: Bool
    var reason: ChatHistoryViewTransitionReason
    var flashIndicators: Bool
    var animateFromPreviousFilter: Bool
}

private func maxMessageIndexForEntries(_ view: ChatHistoryView, indexRange: (Int, Int)) -> (incoming: MessageIndex?, overall: MessageIndex?) {
    var incoming: MessageIndex?
    var overall: MessageIndex?
    var nextLowestIndex: MessageIndex?
    if indexRange.0 >= 0 && indexRange.0 < view.filteredEntries.count {
        if indexRange.0 > 0 {
            nextLowestIndex = view.filteredEntries[indexRange.0 - 1].index
        }
    }
    var nextHighestIndex: MessageIndex?
    if indexRange.1 >= 0 && indexRange.1 < view.filteredEntries.count {
        if indexRange.1 < view.filteredEntries.count - 1 {
            nextHighestIndex = view.filteredEntries[indexRange.1 + 1].index
        }
    }
    for i in (0 ..< view.originalView.entries.count).reversed() {
        let index = view.originalView.entries[i].index
        if let nextLowestIndex = nextLowestIndex {
            if index <= nextLowestIndex {
                continue
            }
        }
        if let nextHighestIndex = nextHighestIndex {
            if index >= nextHighestIndex {
                continue
            }
        }
        let messageEntry = view.originalView.entries[i]
        if overall == nil || overall! < index {
            overall = index
        }
        if !messageEntry.message.flags.intersection(.IsIncomingMask).isEmpty {
            if incoming == nil || incoming! < index {
                incoming = index
            }
        }
        if incoming != nil {
            return (incoming, overall)
        }
    }
    return (incoming, overall)
}

extension ListMessageItemInteraction {
    convenience init(controllerInteraction: ChatControllerInteraction) {
        self.init(openMessage: { message, mode -> Bool in
            return controllerInteraction.openMessage(message, OpenMessageParams(mode: mode))
        }, openMessageContextMenu: { message, bool, node, rect, gesture in
            controllerInteraction.openMessageContextMenu(message, bool, node, rect, gesture, nil)
        }, toggleMessagesSelection: { messageId, selected in
            controllerInteraction.toggleMessagesSelection(messageId, selected)
        }, openUrl: { url, param1, param2, message in
            controllerInteraction.openUrl(ChatControllerInteraction.OpenUrl(url: url, concealed: param1, external: param2, message: message, progress: Promise()))
        }, openInstantPage: { message, data in
            controllerInteraction.openInstantPage(message, data)
        }, longTap: { action, message in
            controllerInteraction.longTap(action, ChatControllerInteraction.LongTapParams(message: message))
        }, getHiddenMedia: {
            return controllerInteraction.hiddenMedia
        })
    }
}

private func mappedInsertEntries(context: AccountContext, chatLocation: ChatLocation, associatedData: ChatMessageItemAssociatedData, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, lastHeaderId: Int64, entries: [ChatHistoryViewTransitionInsertEntry]) -> [ListViewInsertItem] {
    var disableFloatingDateHeaders = false
    if case .customChatContents = chatLocation {
        disableFloatingDateHeaders = true
    }
    
    return entries.map { entry -> ListViewInsertItem in
        switch entry.entry {
            case let .MessageEntry(message, presentationData, read, location, selection, attributes):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatMessageItemImpl(presentationData: presentationData, context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, content: .message(message: message, read: read, selection: selection, attributes: attributes, location: location), disableDate: disableFloatingDateHeaders || message.timestamp < 10)
                    case let .list(_, _, _, displayHeaders, hintLinks, isGlobalSearch):
                        let displayHeader: Bool
                        switch displayHeaders {
                        case .none:
                            displayHeader = false
                        case .all:
                            displayHeader = true
                        case .allButLast:
                            displayHeader = listMessageDateHeaderId(timestamp: message.timestamp) != lastHeaderId
                        }
                        item = ListMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: controllerInteraction), message: message, translateToLanguage: associatedData.translateToLanguage, selection: selection, displayHeader: displayHeader, hintIsLink: hintLinks, isGlobalSearchResult: isGlobalSearch)
                }
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .MessageGroupEntry(_, messages, presentationData):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatMessageItemImpl(presentationData: presentationData, context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, content: .group(messages: messages), disableDate: disableFloatingDateHeaders)
                    case .list:
                        assertionFailure()
                        item = ListMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: controllerInteraction), message: messages[0].0, selection: .none, displayHeader: false)
                }
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .UnreadEntry(_, presentationData):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatUnreadItem(index: entry.entry.index, presentationData: presentationData, controllerInteraction: controllerInteraction, context: context), directionHint: entry.directionHint)
            case let .ReplyCountEntry(_, isComments, count, presentationData):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatReplyCountItem(index: entry.entry.index, isComments: isComments, count: count, presentationData: presentationData, context: context, controllerInteraction: controllerInteraction), directionHint: entry.directionHint)
            case let .ChatInfoEntry(data, presentationData):
                let item: ListViewItem
                switch data {
                case let .botInfo(title, text, photo, video):
                    item = ChatBotInfoItem(title: title, text: text, photo: photo, video: video, controllerInteraction: controllerInteraction, presentationData: presentationData, context: context)
                case let .userInfo(peer, verification, registrationDate, phoneCountry, groupsInCommonCount):
                    item = ChatUserInfoItem(peer: peer, verification: verification, registrationDate: registrationDate, phoneCountry: phoneCountry, groupsInCommonCount: groupsInCommonCount, controllerInteraction: controllerInteraction, presentationData: presentationData, context: context)
                }
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .SearchEntry(theme, strings):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListSearchItem(theme: theme, placeholder: strings.Common_Search, activate: {
                    controllerInteraction.openSearch()
                }), directionHint: entry.directionHint)
        }
    }
}

private func mappedUpdateEntries(context: AccountContext, chatLocation: ChatLocation, associatedData: ChatMessageItemAssociatedData, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, lastHeaderId: Int64, entries: [ChatHistoryViewTransitionUpdateEntry]) -> [ListViewUpdateItem] {
    var disableFloatingDateHeaders = false
    if case .customChatContents = chatLocation {
        disableFloatingDateHeaders = true
    }
    
    return entries.map { entry -> ListViewUpdateItem in
        switch entry.entry {
            case let .MessageEntry(message, presentationData, read, location, selection, attributes):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatMessageItemImpl(presentationData: presentationData, context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, content: .message(message: message, read: read, selection: selection, attributes: attributes, location: location), disableDate: disableFloatingDateHeaders || message.timestamp < 10)
                    case let .list(_, _, _, displayHeaders, hintLinks, isGlobalSearch):
                        let displayHeader: Bool
                        switch displayHeaders {
                        case .none:
                            displayHeader = false
                        case .all:
                            displayHeader = true
                        case .allButLast:
                            displayHeader = listMessageDateHeaderId(timestamp: message.timestamp) != lastHeaderId
                        }
                        item = ListMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: controllerInteraction), message: message, translateToLanguage: associatedData.translateToLanguage, selection: selection, displayHeader: displayHeader, hintIsLink: hintLinks, isGlobalSearchResult: isGlobalSearch)
                }
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .MessageGroupEntry(_, messages, presentationData):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatMessageItemImpl(presentationData: presentationData, context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, content: .group(messages: messages), disableDate: disableFloatingDateHeaders)
                    case .list:
                        assertionFailure()
                        item = ListMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: controllerInteraction), message: messages[0].0, selection: .none, displayHeader: false)
                }
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .UnreadEntry(_, presentationData):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatUnreadItem(index: entry.entry.index, presentationData: presentationData, controllerInteraction: controllerInteraction, context: context), directionHint: entry.directionHint)
            case let .ReplyCountEntry(_, isComments, count, presentationData):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatReplyCountItem(index: entry.entry.index, isComments: isComments, count: count, presentationData: presentationData, context: context, controllerInteraction: controllerInteraction), directionHint: entry.directionHint)
            case let .ChatInfoEntry(data, presentationData):
                let item: ListViewItem
                switch data {
                case let .botInfo(title, text, photo, video):
                    item = ChatBotInfoItem(title: title, text: text, photo: photo, video: video, controllerInteraction: controllerInteraction, presentationData: presentationData, context: context)
                case let .userInfo(peer, verification, registrationDate, phoneCountry, groupsInCommonCount):
                    item = ChatUserInfoItem(peer: peer, verification: verification, registrationDate: registrationDate, phoneCountry: phoneCountry, groupsInCommonCount: groupsInCommonCount, controllerInteraction: controllerInteraction, presentationData: presentationData, context: context)
                }
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .SearchEntry(theme, strings):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListSearchItem(theme: theme, placeholder: strings.Common_Search, activate: {
                    controllerInteraction.openSearch()
                }), directionHint: entry.directionHint)
        }
    }
}

private func mappedChatHistoryViewListTransition(context: AccountContext, chatLocation: ChatLocation, associatedData: ChatMessageItemAssociatedData, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, lastHeaderId: Int64, animateFromPreviousFilter: Bool, transition: ChatHistoryViewTransition) -> ChatHistoryListViewTransition {
    return ChatHistoryListViewTransition(historyView: transition.historyView, deleteItems: transition.deleteItems, insertItems: mappedInsertEntries(context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, mode: mode, lastHeaderId: lastHeaderId, entries: transition.insertEntries), updateItems: mappedUpdateEntries(context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, mode: mode, lastHeaderId: lastHeaderId, entries: transition.updateEntries), options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, initialData: transition.initialData, keyboardButtonsMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData, cachedDataMessages: transition.cachedDataMessages, readStateData: transition.readStateData, scrolledToIndex: transition.scrolledToIndex, scrolledToSomeIndex: transition.scrolledToSomeIndex, peerType: associatedData.automaticDownloadPeerType, networkType: associatedData.automaticDownloadNetworkType, animateIn: transition.animateIn, reason: transition.reason, flashIndicators: transition.flashIndicators, animateFromPreviousFilter: animateFromPreviousFilter)
}

private final class ChatHistoryTransactionOpaqueState {
    let historyView: ChatHistoryView
    
    init(historyView: ChatHistoryView) {
        self.historyView = historyView
    }
}

private func extractAssociatedData(
    chatLocation: ChatLocation,
    view: MessageHistoryView,
    automaticDownloadNetworkType: MediaAutoDownloadNetworkType,
    preferredStoryHighQuality: Bool,
    animatedEmojiStickers: [String: [StickerPackItem]],
    additionalAnimatedEmojiStickers: [String: [Int: StickerPackItem]],
    subject: ChatControllerSubject?,
    currentlyPlayingMessageId: MessageIndex?,
    isCopyProtectionEnabled: Bool,
    availableReactions: AvailableReactions?,
    availableMessageEffects: AvailableMessageEffects?,
    savedMessageTags: SavedMessageTags?,
    defaultReaction: MessageReaction.Reaction?,
    isPremium: Bool,
    alwaysDisplayTranscribeButton: ChatMessageItemAssociatedData.DisplayTranscribeButton,
    accountPeer: EnginePeer?,
    topicAuthorId: EnginePeer.Id?,
    hasBots: Bool,
    translateToLanguage: String?,
    maxReadStoryId: Int32?,
    recommendedChannels: RecommendedChannels?,
    audioTranscriptionTrial: AudioTranscription.TrialState,
    chatThemes: [TelegramTheme],
    deviceContactsNumbers: Set<String>,
    isInline: Bool,
    showSensitiveContent: Bool,
    isSuspiciousPeer: Bool
) -> ChatMessageItemAssociatedData {
    var automaticDownloadPeerId: EnginePeer.Id?
    var automaticMediaDownloadPeerType: MediaAutoDownloadPeerType = .channel
    var contactsPeerIds: Set<PeerId> = Set()
    var channelDiscussionGroup: ChatMessageItemAssociatedData.ChannelDiscussionGroupStatus = .unknown
    if case let .peer(peerId) = chatLocation {
        automaticDownloadPeerId = peerId
        
        if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.SecretChat {
            var isContact = false
            for entry in view.additionalData {
                if case let .peerIsContact(_, value) = entry {
                    isContact = value
                    break
                }
            }
            automaticMediaDownloadPeerType = isContact ? .contact : .otherPrivate
        } else if peerId.namespace == Namespaces.Peer.CloudGroup {
            automaticMediaDownloadPeerType = .group
            
            for entry in view.entries {
                if entry.attributes.authorIsContact, let peerId = entry.message.author?.id {
                    contactsPeerIds.insert(peerId)
                }
            }
        } else if peerId.namespace == Namespaces.Peer.CloudChannel {
            for entry in view.additionalData {
                if case let .peer(_, value) = entry {
                    if let channel = value as? TelegramChannel, case .group = channel.info {
                        automaticMediaDownloadPeerType = .group
                    }
                } else if case let .cachedPeerData(dataPeerId, cachedData) = entry, dataPeerId == peerId {
                    if let cachedData = cachedData as? CachedChannelData {
                        switch cachedData.linkedDiscussionPeerId {
                        case let .known(value):
                            channelDiscussionGroup = .known(value)
                        case .unknown:
                            channelDiscussionGroup = .unknown
                        }
                    }
                }
            }
            if automaticMediaDownloadPeerType == .group {
                for entry in view.entries {
                    if entry.attributes.authorIsContact, let peerId = entry.message.author?.id {
                        contactsPeerIds.insert(peerId)
                    }
                }
            }
        }
    } else if case let .replyThread(message) = chatLocation, message.isForumPost {
        automaticDownloadPeerId = message.peerId
    }
    
    return ChatMessageItemAssociatedData(automaticDownloadPeerType: automaticMediaDownloadPeerType, automaticDownloadPeerId: automaticDownloadPeerId, automaticDownloadNetworkType: automaticDownloadNetworkType, preferredStoryHighQuality: preferredStoryHighQuality, isRecentActions: false, subject: subject, contactsPeerIds: contactsPeerIds, channelDiscussionGroup: channelDiscussionGroup, animatedEmojiStickers: animatedEmojiStickers, additionalAnimatedEmojiStickers: additionalAnimatedEmojiStickers, currentlyPlayingMessageId: currentlyPlayingMessageId, isCopyProtectionEnabled: isCopyProtectionEnabled, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: savedMessageTags, defaultReaction: defaultReaction, isPremium: isPremium, accountPeer: accountPeer, alwaysDisplayTranscribeButton: alwaysDisplayTranscribeButton, topicAuthorId: topicAuthorId, hasBots: hasBots, translateToLanguage: translateToLanguage, maxReadStoryId: maxReadStoryId, recommendedChannels: recommendedChannels, audioTranscriptionTrial: audioTranscriptionTrial, chatThemes: chatThemes, deviceContactsNumbers: deviceContactsNumbers, isInline: isInline, showSensitiveContent: showSensitiveContent, isSuspiciousPeer: isSuspiciousPeer)
}

private extension ChatHistoryLocationInput {
    var isAtUpperBound: Bool {
        switch self.content {
        case .Navigation(index: .upperBound, anchorIndex: .upperBound, count: _, highlight: _):
                return true
        case let .Scroll(subject, anchorIndex, _, _, _, _, _):
            if case .upperBound = anchorIndex, case .upperBound = subject.index {
                return true
            } else {
                return false
            }
        default:
            return false
        }
    }
}

private struct ChatHistoryAnimatedEmojiConfiguration {
    static var defaultValue: ChatHistoryAnimatedEmojiConfiguration {
        return ChatHistoryAnimatedEmojiConfiguration(scale: 0.625)
    }
    
    public let scale: CGFloat
    
    fileprivate init(scale: CGFloat) {
        self.scale = scale
    }
    
    static func with(appConfiguration: AppConfiguration) -> ChatHistoryAnimatedEmojiConfiguration {
        if let data = appConfiguration.data, let scale = data["emojies_animated_zoom"] as? Double {
            return ChatHistoryAnimatedEmojiConfiguration(scale: CGFloat(scale))
        } else {
            return .defaultValue
        }
    }
}

private var nextClientId: Int32 = 1

public final class ChatHistoryListNodeImpl: ListView, ChatHistoryNode, ChatHistoryListNode {
    static let fixedAdMessageStableId: UInt32 = UInt32.max - 5000
    
    public let context: AccountContext
    private(set) var chatLocation: ChatLocation
    private let chatLocationContextHolder: Atomic<ChatLocationContextHolder?>
    private let source: ChatHistoryListSource
    private let subject: ChatControllerSubject?
    private(set) var tag: HistoryViewInputTag?
    private let controllerInteraction: ChatControllerInteraction
    private let selectedMessages: Signal<Set<MessageId>?, NoError>
    var messageTransitionNode: () -> ChatMessageTransitionNodeImpl?
    private let mode: ChatHistoryListMode
    
    var enableUnreadAlignment: Bool = true
    var areContentAnimationsEnabled: Bool = false
    
    private var historyView: ChatHistoryView?
    public var originalHistoryView: MessageHistoryView? {
        return self.historyView?.originalView
    }
    
    private let historyDisposable = MetaDisposable()
    private let readHistoryDisposable = MetaDisposable()
    
    private var dequeuedInitialTransitionOnLayout = false
    private var enqueuedHistoryViewTransitions: [ChatHistoryListViewTransition] = []
    private var hasActiveTransition = false
    var layoutActionOnViewTransition: ((ChatHistoryListViewTransition) -> (ChatHistoryListViewTransition, ListViewUpdateSizeAndInsets?), Int64?)?
    
    public let historyState = ValuePromise<ChatHistoryNodeHistoryState>()
    public var currentHistoryState: ChatHistoryNodeHistoryState?
    
    private let _initialData = Promise<ChatHistoryCombinedInitialData?>()
    private var didSetInitialData = false
    public var initialData: Signal<ChatHistoryCombinedInitialData?, NoError> {
        return self._initialData.get()
    }
    
    private let _cachedPeerDataAndMessages = Promise<(CachedPeerData?, [MessageId: Message]?)>()
    public var cachedPeerDataAndMessages: Signal<(CachedPeerData?, [MessageId: Message]?), NoError> {
        return self._cachedPeerDataAndMessages.get()
    }
    
    private var _buttonKeyboardMessage = Promise<Message?>(nil)
    private var currentButtonKeyboardMessage: Message?
    public var buttonKeyboardMessage: Signal<Message?, NoError> {
        return self._buttonKeyboardMessage.get()
    }
    
    private let maxVisibleIncomingMessageIndex = ValuePromise<MessageIndex>(ignoreRepeated: true)
    let canReadHistory = Promise<Bool>()
    private var canReadHistoryValue: Bool = false
    private var canReadHistoryDisposable: Disposable?
    
    var suspendReadingReactions: Bool = false {
        didSet {
            if self.suspendReadingReactions != oldValue {
                if !self.suspendReadingReactions {
                    self.attemptReadingReactions()
                }
            }
        }
    }

    private var messageIdsScheduledForMarkAsSeen = Set<MessageId>()
    private var messageIdsWithReactionsScheduledForMarkAsSeen = Set<MessageId>()
    
    private var chatHistoryLocationValue: ChatHistoryLocationInput? {
        didSet {
            if let chatHistoryLocationValue = self.chatHistoryLocationValue, chatHistoryLocationValue != oldValue {
                self.chatHistoryLocationPromise.set(chatHistoryLocationValue)
            }
        }
    }
    private let chatHistoryLocationPromise = ValuePromise<ChatHistoryLocationInput>()
    private var nextHistoryLocationId: Int32 = 1
    private func takeNextHistoryLocationId() -> Int32 {
        let id = self.nextHistoryLocationId
        self.nextHistoryLocationId += 5
        return id
    }
    
    private let ignoreMessagesInTimestampRangePromise = ValuePromise<ClosedRange<Int32>?>(nil)
    var ignoreMessagesInTimestampRange: ClosedRange<Int32>? = nil {
        didSet {
            if self.ignoreMessagesInTimestampRange != oldValue {
                self.ignoreMessagesInTimestampRangePromise.set(self.ignoreMessagesInTimestampRange)
            }
        }
    }
    
    private let ignoreMessageIdsPromise = ValuePromise<Set<EngineMessage.Id>>(Set())
    var ignoreMessageIds: Set<EngineMessage.Id> = Set() {
        didSet {
            if self.ignoreMessageIds != oldValue {
                self.ignoreMessageIdsPromise.set(self.ignoreMessageIds)
            }
        }
    }
    
    private let chatHasBotsPromise = ValuePromise<Bool>(false)
    var chatHasBots: Bool = false {
        didSet {
            if self.chatHasBots != oldValue {
                self.chatHasBotsPromise.set(self.chatHasBots)
            }
        }
    }
        
    private let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    
    private let messageProcessingManager = ChatMessageThrottledProcessingManager()
    private let messageWithReactionsProcessingManager = ChatMessageThrottledProcessingManager(submitInterval: 4.0)
    private let seenLiveLocationProcessingManager = ChatMessageThrottledProcessingManager()
    private let unsupportedMessageProcessingManager = ChatMessageThrottledProcessingManager()
    private let refreshMediaProcessingManager = ChatMessageThrottledProcessingManager()
    private let messageMentionProcessingManager = ChatMessageThrottledProcessingManager(delay: 0.2)
    private let unseenReactionsProcessingManager = ChatMessageThrottledProcessingManager(delay: 0.2, submitInterval: 0.0)
    private let extendedMediaProcessingManager = ChatMessageVisibleThrottledProcessingManager(interval: 5.0)
    private let translationProcessingManager = ChatMessageThrottledProcessingManager(submitInterval: 1.0)
    private let refreshStoriesProcessingManager = ChatMessageThrottledProcessingManager()
    private let factCheckProcessingManager = ChatMessageThrottledProcessingManager(submitInterval: 1.0)
    private let inlineGroupCallsProcessingManager = ChatMessageThrottledProcessingManager(submitInterval: 1.0)
    
    let prefetchManager: InChatPrefetchManager
    private var currentEarlierPrefetchMessages: [(Message, Media)] = []
    private var currentLaterPrefetchMessages: [(Message, Media)] = []
    private var currentPrefetchDirectionIsToLater: Bool = false
    
    private var maxVisibleMessageIndexReported: MessageIndex?
    var maxVisibleMessageIndexUpdated: ((MessageIndex) -> Void)?
    
    var scrolledToIndex: ((MessageHistoryScrollToSubject, Bool) -> Void)?
    var scrolledToSomeIndex: (() -> Void)?
    var beganDragging: (() -> Void)?
    
    private let hasVisiblePlayableItemNodesPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    var hasVisiblePlayableItemNodes: Signal<Bool, NoError> {
        return self.hasVisiblePlayableItemNodesPromise.get()
    }
    
    private var isInteractivelyScrollingValue: Bool = false
    private let isInteractivelyScrollingPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    var isInteractivelyScrolling: Signal<Bool, NoError> {
        return self.isInteractivelyScrollingPromise.get()
    }
    
    private var currentPresentationData: ChatPresentationData
    private var chatPresentationDataPromise: Promise<ChatPresentationData>
    private var presentationDataDisposable: Disposable?
    
    private let historyAppearsClearedPromise = ValuePromise<Bool>(false)
    var historyAppearsCleared: Bool = false {
        didSet {
            if self.historyAppearsCleared != oldValue {
                self.historyAppearsClearedPromise.set(self.historyAppearsCleared)
            }
        }
    }
    
    private let pendingUnpinnedAllMessagesPromise = ValuePromise<Bool>(false)
    var pendingUnpinnedAllMessages: Bool = false {
        didSet {
            if self.pendingUnpinnedAllMessages != oldValue {
                self.pendingUnpinnedAllMessagesPromise.set(self.pendingUnpinnedAllMessages)
            }
        }
    }
    
    private let pendingRemovedMessagesPromise = ValuePromise<Set<MessageId>>(Set())
    var pendingRemovedMessages: Set<MessageId> = Set() {
        didSet {
            if self.pendingRemovedMessages != oldValue {
                self.pendingRemovedMessagesPromise.set(self.pendingRemovedMessages)
            }
        }
    }
    
    private let justSentTextMessagePromise = ValuePromise<Bool>(false)
    var justSentTextMessage: Bool = false {
        didSet {
            if self.justSentTextMessage != oldValue {
                self.justSentTextMessagePromise.set(self.justSentTextMessage)
            }
        }
    }
    
    private var appliedScrollToMessageId: MessageIndex? = nil
    private let scrollToMessageIdPromise = Promise<MessageIndex?>(nil)
    
    private let currentlyPlayingMessageIdPromise = Promise<(MessageIndex, Bool)?>(nil)
    private var appliedPlayingMessageId: (MessageIndex, Bool)? = nil
    
    private(set) var isScrollAtBottomPosition = false
    public var isScrollAtBottomPositionUpdated: (() -> Void)?
    
    private var interactiveReadActionDisposable: Disposable?
    private var interactiveReadReactionsDisposable: Disposable?
    private var displayUnseenReactionAnimationsTimestamps: [MessageId: Double] = [:]
    
    public var contentPositionChanged: (ListViewVisibleContentOffset) -> Void = { _ in }
    
    public private(set) var loadState: ChatHistoryNodeLoadState?
    public private(set) var loadStateUpdated: ((ChatHistoryNodeLoadState, Bool) -> Void)?
    private var additionalLoadStateUpdated: [(ChatHistoryNodeLoadState, Bool) -> Void] = []
    
    public private(set) var hasAtLeast3Messages: Bool = false
    public var hasAtLeast3MessagesUpdated: ((Bool) -> Void)?
    
    public private(set) var hasPlentyOfMessages: Bool = false
    public var hasPlentyOfMessagesUpdated: ((Bool) -> Void)?
    
    public private(set) var hasLotsOfMessages: Bool = false
    public var hasLotsOfMessagesUpdated: ((Bool) -> Void)?
    
    private var loadedMessagesFromCachedDataDisposable: Disposable?
    
    private var isSettingTopReplyThreadMessageShown: Bool = false
    let isTopReplyThreadMessageShown = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    private var topVisibleMessageRangeValueInitialized: Bool = false
    private var topVisibleMessageRangeValue: ChatTopVisibleMessageRange?
    private func updateTopVisibleMessageRange(_ value: ChatTopVisibleMessageRange?) {
        if value != self.topVisibleMessageRangeValue || !self.topVisibleMessageRangeValueInitialized {
            self.topVisibleMessageRangeValueInitialized = true
            self.topVisibleMessageRangeValue = value
            self.topVisibleMessageRange.set(.single(value))
        }
    }
    let topVisibleMessageRange = Promise<ChatTopVisibleMessageRange?>(nil)
    
    var isSelectionGestureEnabled = true

    private var overscrollView: ComponentHostView<Empty>?
    var nextChannelToRead: (peer: EnginePeer, threadData: (id: Int64, data: MessageHistoryThreadData)?, unreadCount: Int, location: TelegramEngine.NextUnreadChannelLocation)?
    var offerNextChannelToRead: Bool = false
    var nextChannelToReadDisplayName: Bool = false
    private var currentOverscrollExpandProgress: CGFloat = 0.0
    private var freezeOverscrollControl: Bool = false
    private var freezeOverscrollControlProgress: Bool = false
    private var feedback: HapticFeedback?
    var openNextChannelToRead: ((EnginePeer, (id: Int64, data: MessageHistoryThreadData)?, TelegramEngine.NextUnreadChannelLocation) -> Void)?
    private var contentInsetAnimator: DisplayLinkAnimator?

    private let adMessagesContext: AdMessagesHistoryContext?
    private var adMessagesDisposable: Disposable?
    private var preloadAdPeerName: String?
    private let preloadAdPeerDisposable = MetaDisposable()
    private var didSetupRecommendedChannelsPreload = false
    private let preloadRecommendedChannelsDisposable = MetaDisposable()
    private var seenAdIds: [Data] = []
    private var pendingDynamicAdMessages: [Message] = []
    private var pendingDynamicAdMessageInterval: Int?
    private var remainingDynamicAdMessageInterval: Int?
    private var remainingDynamicAdMessageDistance: CGFloat?
    private var nextPendingDynamicMessageId: Int32 = 1
    private var allAdMessages: (fixed: Message?, opportunistic: [Message], version: Int) = (nil, [], 0) {
        didSet {
            self.allAdMessagesPromise.set(.single(self.allAdMessages))
        }
    }
    private let allAdMessagesPromise = Promise<(fixed: Message?, opportunistic: [Message], version: Int)>((nil, [], 0))
    private var seenMessageIds = Set<MessageId>()
    
    private var refreshDisplayedItemRangeTimer: SwiftSignalKit.Timer?
    
    private var genericReactionEffect: String?
    private var genericReactionEffectDisposable: Disposable?
    
    private var visibleMessageRange = Atomic<VisibleMessageRange?>(value: nil)
    
    private let clientId: Atomic<Int32>
    
    private var translationLang: (fromLang: String?, toLang: String)?
    
    private var allowDustEffect: Bool = true
    private var dustEffectLayer: DustEffectLayer?
    
    var frozenMessageForScrollingReset: EngineMessage.Id?
    
    private var hasDisplayedBusinessBotMessageTooltip: Bool = false
    
    private let _isReady = ValuePromise<Bool>(false, ignoreRepeated: true)
    public var isReady: Signal<Bool, NoError> {
        return self._isReady.get()
    }
    private var didSetReady: Bool = false
    
    private let initTimestamp: Double
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>), chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>, adMessagesContext: AdMessagesHistoryContext?, tag: HistoryViewInputTag?, source: ChatHistoryListSource, subject: ChatControllerSubject?, controllerInteraction: ChatControllerInteraction, selectedMessages: Signal<Set<MessageId>?, NoError>, mode: ChatHistoryListMode = .bubbles, rotated: Bool = false, isChatPreview: Bool, messageTransitionNode: @escaping () -> ChatMessageTransitionNodeImpl?) {
        self.initTimestamp = CFAbsoluteTimeGetCurrent()
        
        var tag = tag
        if case .pinnedMessages = subject {
            tag = .tag(.pinned)
        }
        
        self.context = context
        self.chatLocation = chatLocation
        self.chatLocationContextHolder = chatLocationContextHolder
        self.source = source
        self.subject = subject
        self.tag = tag
        self.controllerInteraction = controllerInteraction
        self.selectedMessages = selectedMessages
        self.messageTransitionNode = messageTransitionNode
        self.mode = mode
        
        if let data = context.currentAppConfiguration.with({ $0 }).data {
            if let _ = data["ios_killswitch_disable_unread_alignment"] {
                self.enableUnreadAlignment = false
            }
            if let _ = data["ios_killswitch_disable_dust_effect"] {
                self.allowDustEffect = false
            }
        }
        
        let presentationData = updatedPresentationData.initial
        self.currentPresentationData = ChatPresentationData(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper), fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true, largeEmoji: presentationData.largeEmoji, chatBubbleCorners: presentationData.chatBubbleCorners, animatedEmojiScale: 1.0)
        
        self.chatPresentationDataPromise = Promise()
        
        self.prefetchManager = InChatPrefetchManager(context: context)
        
        self.adMessagesContext = adMessagesContext
        var adMessages: Signal<(interPostInterval: Int32?, messages: [Message], startDelay: Int32?, betweenDelay: Int32?), NoError>
        if case .bubbles = mode, let adMessagesContext {
            let peerId = adMessagesContext.peerId
            if peerId.namespace == Namespaces.Peer.CloudUser {
                adMessages = .single((nil, [], nil, nil))
            } else {
                if context.sharedContext.immediateExperimentalUISettings.fakeAds {
                    adMessages = context.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                    )
                    |> map { peer -> (interPostInterval: Int32?, messages: [Message], startDelay: Int32?, betweenDelay: Int32?) in
                        let fakeAdMessages: [Message] = (0 ..< 10).map { i -> Message in
                            var attributes: [MessageAttribute] = []
                            
                            let mappedMessageType: AdMessageAttribute.MessageType = .sponsored
                            attributes.append(AdMessageAttribute(opaqueId: "fake_ad_\(i)".data(using: .utf8)!, messageType: mappedMessageType, url: "t.me/telegram", buttonText: "VIEW", sponsorInfo: nil, additionalInfo: nil, canReport: false, hasContentMedia: false, minDisplayDuration: nil, maxDisplayDuration: nil))
                            
                            var messagePeers = SimpleDictionary<PeerId, Peer>()
                            
                            if let peer {
                                messagePeers[peer.id] = peer._asPeer()
                            }
                            
                            let author: Peer = TelegramChannel(
                                id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1)),
                                accessHash: nil,
                                title: "Fake Ad",
                                username: nil,
                                photo: [],
                                creationDate: 0,
                                version: 0,
                                participationStatus: .left,
                                info: .broadcast(TelegramChannelBroadcastInfo(flags: [])),
                                flags: [],
                                restrictionInfo: nil,
                                adminRights: nil,
                                bannedRights: nil,
                                defaultBannedRights: nil,
                                usernames: [],
                                storiesHidden: nil,
                                nameColor: .blue,
                                backgroundEmojiId: nil,
                                profileColor: nil,
                                profileBackgroundEmojiId: nil,
                                emojiStatus: nil,
                                approximateBoostLevel: nil,
                                subscriptionUntilDate: nil,
                                verificationIconFileId: nil,
                                sendPaidMessageStars: nil,
                                linkedMonoforumId: nil
                            )
                            messagePeers[author.id] = author
                            
                            let messageText = "Fake Ad N\(i)"
                            let messageHash = (messageText.hashValue &+ 31 &* peerId.hashValue) &* 31 &+ author.id.hashValue
                            let messageStableVersion = UInt32(bitPattern: Int32(truncatingIfNeeded: messageHash))
                            
                            return Message(
                                stableId: 0,
                                stableVersion: messageStableVersion,
                                id: MessageId(peerId: peerId, namespace: Namespaces.Message.Local, id: 0),
                                globallyUniqueId: nil,
                                groupingKey: nil,
                                groupInfo: nil,
                                threadId: nil,
                                timestamp: Int32.max - 1,
                                flags: [.Incoming],
                                tags: [],
                                globalTags: [],
                                localTags: [],
                                customTags: [],
                                forwardInfo: nil,
                                author: author,
                                text: messageText,
                                attributes: attributes,
                                media: [],
                                peers: messagePeers,
                                associatedMessages: SimpleDictionary<MessageId, Message>(),
                                associatedMessageIds: [],
                                associatedMedia: [:],
                                associatedThreadInfo: nil,
                                associatedStories: [:]
                            )
                        }
                        return (10, fakeAdMessages, nil, nil)
                    }
                } else {
                    adMessages = adMessagesContext.state
                }
            }
        } else {
            adMessages = .single((nil, [], nil, nil))
        }
        
        let clientId = Atomic<Int32>(value: nextClientId)
        self.clientId = clientId
        nextClientId += 1
        
        super.init()
        
        self.rotated = rotated
        if rotated {
            self.transform = CATransform3DMakeRotation(CGFloat(Double.pi), 0.0, 0.0, 1.0)
        }

        self.clipsToBounds = false
        
        self.beginAdMessageManagement(adMessages: adMessages)
        
        self.accessibilityPageScrolledString = { [weak self] row, count in
            if let strongSelf = self {
                return strongSelf.currentPresentationData.strings.VoiceOver_ScrollStatus(row, count).string
            } else {
                return ""
            }
        }
        
        self.dynamicBounceEnabled = !self.currentPresentationData.disableAnimations
        self.experimentalSnapScrollToItem = true
        
        //self.debugInfo = true
        
        self.messageProcessingManager.process = { [weak context] messageIds in
            context?.account.viewTracker.updateViewCountForMessageIds(messageIds: Set(messageIds.map(\.messageId)), clientId: clientId.with { $0 })
        }
        self.messageWithReactionsProcessingManager.process = { [weak context] messageIds in
            context?.account.viewTracker.updateReactionsForMessageIds(messageIds: Set(messageIds.map(\.messageId)))
        }
        self.seenLiveLocationProcessingManager.process = { [weak context] messageIds in
            context?.account.viewTracker.updateSeenLiveLocationForMessageIds(messageIds: Set(messageIds.map(\.messageId)))
        }
        self.unsupportedMessageProcessingManager.process = { [weak context] messageIds in
            context?.account.viewTracker.updateUnsupportedMediaForMessageIds(messageIds: messageIds)
        }
        self.refreshMediaProcessingManager.process = { [weak context] messageIds in
            context?.account.viewTracker.refreshSecretMediaMediaForMessageIds(messageIds: Set(messageIds.map(\.messageId)))
        }
        self.refreshStoriesProcessingManager.process = { [weak context] messageIds in
            context?.account.viewTracker.refreshStoriesForMessageIds(messageIds: Set(messageIds.map(\.messageId)))
        }
        self.translationProcessingManager.process = { [weak self, weak context] messageIds in
            if let context = context, let translationLang = self?.translationLang {
                let _ = translateMessageIds(context: context, messageIds: Array(messageIds.map(\.messageId)), fromLang: translationLang.fromLang, toLang: translationLang.toLang).startStandalone()
            }
        }
        self.factCheckProcessingManager.process = { [weak self, weak context] messageIds in
            if let context = context, let translationLang = self?.translationLang {
                let _ = translateMessageIds(context: context, messageIds: Array(messageIds.map(\.messageId)), fromLang: translationLang.fromLang, toLang: translationLang.toLang).startStandalone()
            }
        }
        
        self.messageMentionProcessingManager.process = { [weak self, weak context] messageIds in
            if let strongSelf = self {
                if strongSelf.canReadHistoryValue {
                    context?.account.viewTracker.updateMarkMentionsSeenForMessageIds(messageIds: Set(messageIds.map(\.messageId)))
                } else {
                    strongSelf.messageIdsScheduledForMarkAsSeen.formUnion(messageIds.map(\.messageId))
                }
            }
        }
        
        self.unseenReactionsProcessingManager.process = { [weak self] messageIds in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.canReadHistoryValue && !strongSelf.suspendReadingReactions && !strongSelf.context.sharedContext.immediateExperimentalUISettings.skipReadHistory {
                strongSelf.context.account.viewTracker.updateMarkReactionsSeenForMessageIds(messageIds: Set(messageIds.map(\.messageId)))
            } else {
                strongSelf.messageIdsWithReactionsScheduledForMarkAsSeen.formUnion(messageIds.map(\.messageId))
            }
        }
        
        self.extendedMediaProcessingManager.process = { [weak self] messageIds in
            guard let strongSelf = self else {
                return
            }
            strongSelf.context.account.viewTracker.updatedExtendedMediaForMessageIds(messageIds: Set(messageIds.map(\.messageId)))
        }
        
        self.inlineGroupCallsProcessingManager.process = { [weak context] messageIds in
            context?.account.viewTracker.refreshInlineGroupCallsForMessageIds(messageIds: Set(messageIds.map(\.messageId)))
        }
        
        self.preloadPages = false
        
        self.beginChatHistoryTransitions(resetScrolling: false, switchedToAnotherSource: false)
        
        self.beginReadHistoryManagement()
        
        if let subject = subject, case let .message(messageSubject, highlight, _, setupReply) = subject {
            let initialSearchLocation: ChatHistoryInitialSearchLocation
            switch messageSubject {
            case let .id(id):
                initialSearchLocation = .id(id)
            case let .timestamp(timestamp):
                if let peerId = self.chatLocation.peerId {
                    initialSearchLocation = .index(MessageIndex(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 1), timestamp: timestamp))
                } else {
                    //TODO:implement
                    initialSearchLocation = .index(MessageIndex.absoluteUpperBound())
                }
            }
            self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .InitialSearch(subject: MessageHistoryInitialSearchSubject(location: initialSearchLocation, quote: (highlight?.quote).flatMap { quote in MessageHistoryInitialSearchSubject.Quote(string: quote.string, offset: quote.offset) }, todoTaskId: highlight?.todoTaskId), count: historyMessageCount, highlight: highlight != nil, setupReply: setupReply), id: 0)
        } else if let subject = subject, case let .pinnedMessages(maybeMessageId) = subject, let messageId = maybeMessageId {
            self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .InitialSearch(subject: MessageHistoryInitialSearchSubject(location: .id(messageId)), count: historyMessageCount, highlight: true, setupReply: false), id: 0)
        } else {
            self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Initial(count: historyMessageCount), id: 0)
        }
        self.chatHistoryLocationPromise.set(self.chatHistoryLocationValue!)
        
        self.generalScrollDirectionUpdated = { [weak self] direction in
            guard let strongSelf = self else {
                return
            }
            let prefetchDirectionIsToLater = direction == .up
            if strongSelf.currentPrefetchDirectionIsToLater != prefetchDirectionIsToLater {
                strongSelf.currentPrefetchDirectionIsToLater = prefetchDirectionIsToLater
                if strongSelf.currentPrefetchDirectionIsToLater {
                    strongSelf.prefetchManager.updateMessages(strongSelf.currentLaterPrefetchMessages, directionIsToLater: strongSelf.currentPrefetchDirectionIsToLater)
                } else {
                    strongSelf.prefetchManager.updateMessages(strongSelf.currentEarlierPrefetchMessages, directionIsToLater: strongSelf.currentPrefetchDirectionIsToLater)
                }
            }
        }
        
        self.displayedItemRangeChanged = { [weak self] displayedRange, opaqueTransactionState in
            if let strongSelf = self, let transactionState = opaqueTransactionState as? ChatHistoryTransactionOpaqueState {
                strongSelf.processDisplayedItemRangeChanged(displayedRange: displayedRange, transactionState: transactionState)
            }
        }
        
        self.refreshDisplayedItemRangeTimer = SwiftSignalKit.Timer(timeout: 10.0, repeat: true, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateVisibleItemRange(force: true)
        }, queue: .mainQueue())
        self.refreshDisplayedItemRangeTimer?.start()
        
        self.beginPresentationDataManagement(updated: updatedPresentationData.signal)
        
        self.visibleContentOffsetChanged = { [weak self] offset in
            if let strongSelf = self {
                strongSelf.contentPositionChanged(offset)
                
                if strongSelf.tag == nil {
                    var atBottom = false
                    var offsetFromBottom: CGFloat?
                    switch offset {
                        case let .known(offsetValue):
                            if offsetValue.isLessThanOrEqualTo(0.0) {
                                atBottom = true
                                offsetFromBottom = offsetValue
                            }
                            //print("offsetValue: \(offsetValue)")
                        default:
                            break
                    }
                    
                    if atBottom != strongSelf.isScrollAtBottomPosition {
                        strongSelf.isScrollAtBottomPosition = atBottom
                        strongSelf.updateReadHistoryActions()
                        
                        strongSelf.isScrollAtBottomPositionUpdated?()
                    }

                    strongSelf.maybeUpdateOverscrollAction(offset: offsetFromBottom)
                }
                
                var lastMessageId: MessageId?
                if let historyView = (strongSelf.opaqueTransactionState as? ChatHistoryTransactionOpaqueState)?.historyView {
                    if historyView.originalView.laterId == nil && !historyView.originalView.holeLater {
                        lastMessageId = historyView.originalView.entries.last?.message.id
                    }
                }
                
                var maxMessage: MessageIndex?
                strongSelf.forEachVisibleMessageItemNode { itemNode in
                    if let item = itemNode.item {
                        var matches = false
                        if itemNode.frame.maxY < strongSelf.insets.top {
                            return
                        }
                        if itemNode.frame.minY >= strongSelf.insets.top {
                            matches = true
                        } else if itemNode.frame.minY >= strongSelf.insets.top - 100.0 {
                            matches = true
                        } else if let lastMessageId {
                            for (message, _) in item.content {
                                if message.id == lastMessageId {
                                    matches = true
                                }
                            }
                        }
                        
                        if matches {
                            var maxItemIndex: MessageIndex?
                            for (message, _) in item.content {
                                if let maxItemIndexValue = maxItemIndex {
                                    if maxItemIndexValue < message.index {
                                        maxItemIndex = message.index
                                    }
                                } else {
                                    maxItemIndex = message.index
                                }
                            }
                            
                            if let maxItemIndex {
                                if let maxMessageValue = maxMessage {
                                    if maxMessageValue < maxItemIndex {
                                        maxMessage = maxItemIndex
                                    }
                                } else {
                                    maxMessage = maxItemIndex
                                }
                            }
                        }
                    }
                }
                if let maxMessage {
                    strongSelf.updateMaxVisibleReadIncomingMessageIndex(maxMessage)
                }
            }
        }
        
        self.loadedMessagesFromCachedDataDisposable = (self._cachedPeerDataAndMessages.get() |> map { dataAndMessages -> MessageId? in
            return dataAndMessages.0?.messageIds.first
        } |> distinctUntilChanged(isEqual: { $0 == $1 })
        |> mapToSignal { messageId -> Signal<Void, NoError> in
            if let messageId = messageId {
                return context.engine.messages.getMessagesLoadIfNecessary([messageId])
                |> `catch` { _ in
                    return .single(.result([]))
                }
                |> map { _ -> Void in return Void() }
            } else {
                return .complete()
            }
        }).startStrict()
        
        self.beganInteractiveDragging = { [weak self] _ in
            self?.isInteractivelyScrollingValue = true
            self?.isInteractivelyScrollingPromise.set(true)
            self?.beganDragging?()
            //self?.updateHistoryScrollingArea(transition: .immediate)
        }

        self.endedInteractiveDragging = { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.offerNextChannelToRead, strongSelf.currentOverscrollExpandProgress >= 0.99 {
                if let nextChannelToRead = strongSelf.nextChannelToRead {
                    strongSelf.freezeOverscrollControl = true
                    strongSelf.openNextChannelToRead?(nextChannelToRead.peer, nextChannelToRead.threadData, nextChannelToRead.location)
                } else {
                    strongSelf.freezeOverscrollControlProgress = true
                    strongSelf.scroller.contentInset = UIEdgeInsets(top: 94.0 + 12.0, left: 0.0, bottom: 0.0, right: 0.0)
                    Queue.mainQueue().after(0.3, {
                        let animator = DisplayLinkAnimator(duration: 0.2, from: 1.0, to: 0.0, update: { rawT in
                            guard let strongSelf = self else {
                                return
                            }
                            let t = listViewAnimationCurveEaseInOut(rawT)
                            let value = (94.0 + 12.0) * t
                            strongSelf.scroller.contentInset = UIEdgeInsets(top: value, left: 0.0, bottom: 0.0, right: 0.0)
                        }, completion: {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.contentInsetAnimator = nil
                            strongSelf.scroller.contentInset = UIEdgeInsets()
                            strongSelf.freezeOverscrollControlProgress = false
                        })
                        strongSelf.contentInsetAnimator = animator
                    })
                }
            }
        }
        
        self.didEndScrolling = { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isInteractivelyScrollingValue = false
            strongSelf.isInteractivelyScrollingPromise.set(false)
            //strongSelf.updateHistoryScrollingArea(transition: .immediate)
        }

        /*self.updateScrollingIndicator = { [weak self] scrollingState, transition in
            guard let strongSelf = self else {
                return
            }
            strongSelf.scrollingState = scrollingState
            strongSelf.updateHistoryScrollingArea(transition: transition)
        }*/
        
        let selectionRecognizer = ChatHistoryListSelectionRecognizer(target: self, action: #selector(self.selectionPanGesture(_:)))
        selectionRecognizer.shouldBegin = { [weak self] in
            guard let strongSelf = self else {
                return false
            }
            return strongSelf.isSelectionGestureEnabled
        }
        self.view.addGestureRecognizer(selectionRecognizer)
        
        self.loadNextGenericReactionEffect(context: context)
    }
    
    deinit {
        self.historyDisposable.dispose()
        self.readHistoryDisposable.dispose()
        self.interactiveReadActionDisposable?.dispose()
        self.interactiveReadReactionsDisposable?.dispose()
        self.canReadHistoryDisposable?.dispose()
        self.loadedMessagesFromCachedDataDisposable?.dispose()
        self.preloadAdPeerDisposable.dispose()
        self.preloadRecommendedChannelsDisposable.dispose()
        self.refreshDisplayedItemRangeTimer?.invalidate()
        self.genericReactionEffectDisposable?.dispose()
        self.adMessagesDisposable?.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    public func updateTag(tag: HistoryViewInputTag?) {
        if self.tag == tag {
            return
        }
        self.tag = tag
        
        self.beginChatHistoryTransitions(resetScrolling: true, switchedToAnotherSource: false)
    }
    
    private func beginAdMessageManagement(adMessages: Signal<(interPostInterval: Int32?, messages: [Message], startDelay: Int32?, betweenDelay: Int32?), NoError>) {
        self.adMessagesDisposable = (adMessages
        |> deliverOnMainQueue).startStrict(next: { [weak self] interPostInterval, messages, _, _ in
            guard let self else {
                return
            }
            
            if let interPostInterval = interPostInterval {
                self.pendingDynamicAdMessages = messages
                self.pendingDynamicAdMessageInterval = Int(interPostInterval)
                
                if self.remainingDynamicAdMessageInterval == nil {
                    self.remainingDynamicAdMessageInterval = Int(interPostInterval)
                }
                if self.remainingDynamicAdMessageDistance == nil {
                    self.remainingDynamicAdMessageDistance = self.bounds.height
                }
                
                self.allAdMessages = (messages.first, [], 0)
            } else {
                var adPeerName: String?
                if let adAttribute = messages.first?.adAttribute, let parsedUrl = parseAdUrl(sharedContext: self.context.sharedContext, context: self.context, url: adAttribute.url), case let .peer(reference, _) = parsedUrl, case let .name(peerName) = reference {
                    adPeerName = peerName
                }
                
                if self.preloadAdPeerName != adPeerName {
                    self.preloadAdPeerName = adPeerName
                    if let adPeerName {
                        let context = self.context
                        let combinedDisposable = DisposableSet()
                        self.preloadAdPeerDisposable.set(combinedDisposable)
                        combinedDisposable.add(context.engine.peers.resolvePeerByName(name: adPeerName, referrer: nil).startStrict(next: { result in
                            if case let .result(maybePeer) = result, let peer = maybePeer {
                                combinedDisposable.add(context.account.viewTracker.polledChannel(peerId: peer.id).startStrict())
                                combinedDisposable.add(context.account.addAdditionalPreloadHistoryPeerId(peerId: peer.id))
                            }
                        }))
                    } else {
                        self.preloadAdPeerDisposable.set(nil)
                    }
                }
                
                self.allAdMessages = (messages.first, [], 0)
            }
        }).strict()
    }
    
    private let fixedCombinedReadStates = Atomic<MessageHistoryViewReadState?>(value: nil)
    private let currentViewVersion = Atomic<Int?>(value: nil)
    private let previousView = Atomic<(ChatHistoryView, Int, Set<MessageId>?, Int)?>(value: nil)
    private let previousHistoryAppearsCleared = Atomic<Bool?>(value: nil)
    
    private func beginChatHistoryTransitions(resetScrolling: Bool, switchedToAnotherSource: Bool) {
        self.historyDisposable.set(nil)
        self._isReady.set(false)
        
        let context = self.context
        let chatLocation = self.chatLocation
        let subject = self.subject
        let source = self.source
        let tag = self.tag
        let chatLocationContextHolder = self.chatLocationContextHolder
        let controllerInteraction = self.controllerInteraction
        let selectedMessages = self.selectedMessages
        let messageTransitionNode = self.messageTransitionNode
        let mode = self.mode
        let rotated = self.rotated
        
        var resetScrollingMessageId: (index: MessageIndex, offset: CGFloat)?
        
        let useRootInterfaceStateForThread: Bool
        if case let .replyThread(message) = self.chatLocation, message.peerId == self.context.account.peerId, message.threadId == self.context.account.peerId.toInt64() {
            useRootInterfaceStateForThread = true
        } else {
            useRootInterfaceStateForThread = false
        }
        
        var resetScrolling = resetScrolling
        if resetScrolling {
            if let frozenMessageForScrollingReset = self.frozenMessageForScrollingReset {
                self.forEachVisibleMessageItemNode { itemNode in
                    if resetScrollingMessageId != nil {
                        return
                    }
                    if let item = itemNode.item, item.message.id == frozenMessageForScrollingReset {
                        let distanceToNode = self.insets.top - itemNode.frame.minY
                        resetScrollingMessageId = (item.message.index, -distanceToNode)
                    }
                }
            }
            
            self.forEachVisibleMessageItemNode { itemNode in
                if resetScrollingMessageId != nil {
                    return
                }
                if let item = itemNode.item {
                    let distanceToNode = self.insets.top - itemNode.frame.minY
                    resetScrollingMessageId = (item.message.index, -distanceToNode)
                }
            }
            
            if let resetScrollingMessageId {
                self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Scroll(subject: MessageHistoryScrollToSubject(index: .message(resetScrollingMessageId.index), quote: nil), anchorIndex: .message(resetScrollingMessageId.index), sourceIndex: .message(resetScrollingMessageId.index), scrollPosition: .top(resetScrollingMessageId.offset), animated: false, highlight: false, setupReply: false), id: (self.chatHistoryLocationValue?.id).flatMap({ $0 + 1 }) ?? 0)
            } else {
                self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Initial(count: historyMessageCount), id: (self.chatHistoryLocationValue?.id).flatMap({ $0 + 1 }) ?? 0)
            }
        }
        self.frozenMessageForScrollingReset = nil
        
        var appendMessagesFromTheSameGroup = false
        if case .pinnedMessages = subject {
            appendMessagesFromTheSameGroup = true
        }
        
        let fixedCombinedReadStates = self.fixedCombinedReadStates
        
        var isScheduledMessages = false
        if let subject = self.subject, case .scheduledMessages = subject {
            isScheduledMessages = true
        }
        var isAuxiliaryChat = isScheduledMessages
        if case .replyThread = self.chatLocation {
            isAuxiliaryChat = true
        }
        
        var additionalData: [AdditionalMessageHistoryViewData] = []
        if case let .peer(peerId) = self.chatLocation {
            additionalData.append(.cachedPeerData(peerId))
            additionalData.append(.cachedPeerDataMessages(peerId))
            additionalData.append(.peerNotificationSettings(peerId))
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                additionalData.append(.cacheEntry(cachedChannelAdminRanksEntryId(peerId: peerId)))
            }
            additionalData.append(.peer(peerId))
            if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.SecretChat {
                additionalData.append(.peerIsContact(peerId))
            }
        }
        if !isAuxiliaryChat {
            additionalData.append(.totalUnreadState)
        }
        if case let .replyThread(replyThreadMessage) = self.chatLocation {
            additionalData.append(.cachedPeerData(replyThreadMessage.peerId))
            additionalData.append(.peerNotificationSettings(replyThreadMessage.peerId))
            if replyThreadMessage.peerId.namespace == Namespaces.Peer.CloudChannel {
                additionalData.append(.cacheEntry(cachedChannelAdminRanksEntryId(peerId: replyThreadMessage.peerId)))
                additionalData.append(.peer(replyThreadMessage.peerId))
            }
            
            additionalData.append(.message(replyThreadMessage.effectiveTopId))
        }

        let currentViewVersion = self.currentViewVersion
        
        let historyViewUpdate: Signal<(ChatHistoryViewUpdate, Int, ChatHistoryLocationInput?, ClosedRange<Int32>?, Set<MessageId>), NoError>
        var isFirstTime = true
        var updateAllOnEachVersion = false
        if case let .custom(messages, at, quote, _) = self.source {
            updateAllOnEachVersion = true
            historyViewUpdate = messages
            |> map { messages, _, hasMore in
                let version = currentViewVersion.modify({ value in
                    if let value = value {
                        return value + 1
                    } else {
                        return 0
                    }
                })!
                
                let scrollPosition: ChatHistoryViewScrollPosition?
                if isFirstTime, let messageIndex = messages.first(where: { $0.id == at })?.index {
                    scrollPosition = .index(subject: MessageHistoryScrollToSubject(index: .message(messageIndex), quote: quote.flatMap { quote in MessageHistoryScrollToSubject.Quote(string: quote.text, offset: quote.offset) }), position: .center(.bottom), directionHint: .Down, animated: false, highlight: false, displayLink: false, setupReply: false)
                    isFirstTime = false
                } else {
                    scrollPosition = nil
                }
                
                return (ChatHistoryViewUpdate.HistoryView(view: MessageHistoryView(tag: nil, namespaces: .all, entries: messages.reversed().map { MessageHistoryEntry(message: $0, isRead: false, location: nil, monthLocation: nil, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false)) }, holeEarlier: hasMore, holeLater: false, isLoading: false), type: .Generic(type: version > 0 ? ViewUpdateType.Generic : ViewUpdateType.Initial), scrollPosition: scrollPosition, flashIndicators: false, originalScrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: nil, buttonKeyboardMessage: nil, cachedData: nil, cachedDataMessages: nil, readStateData: nil), id: 0), version, nil, nil, Set())
            }
        } else if case let .customView(historyView) = self.source {
            historyViewUpdate = combineLatest(queue: .mainQueue(),
                self.chatHistoryLocationPromise.get(),
                self.ignoreMessagesInTimestampRangePromise.get(),
                self.ignoreMessageIdsPromise.get()
            )
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                if lhs.0 != rhs.0 {
                    return false
                }
                if lhs.1 != rhs.1 {
                    return false
                }
                if lhs.2 != rhs.2 {
                    return false
                }
                return true
            })
            |> mapToSignal { location, _, _ -> Signal<((MessageHistoryView, ViewUpdateType), ChatHistoryLocationInput?), NoError> in
                return historyView
                |> map { historyView in
                    return (historyView, location)
                }
            }
            |> map { viewAndUpdate, location in
                let (view, update) = viewAndUpdate
                
                let version = currentViewVersion.modify({ value in
                    if let value = value {
                        return value + 1
                    } else {
                        return 0
                    }
                })!
                
                var scrollPositionValue: ChatHistoryViewScrollPosition?
                if let location {
                    switch location.content {
                    case let .Scroll(subject, _, _, scrollPosition, animated, highlight, setupReply):
                        scrollPositionValue = .index(subject: subject, position: scrollPosition, directionHint: .Up, animated: animated, highlight: highlight, displayLink: false, setupReply: setupReply)
                    default:
                        break
                    }
                }
                
                return (
                    ChatHistoryViewUpdate.HistoryView(
                        view: view,
                        type: .Generic(type: update),
                        scrollPosition: scrollPositionValue,
                        flashIndicators: false,
                        originalScrollPosition: nil,
                        initialData: ChatHistoryCombinedInitialData(
                            initialData: nil,
                            buttonKeyboardMessage: nil,
                            cachedData: nil,
                            cachedDataMessages: nil,
                            readStateData: nil
                        ),
                        id: location?.id ?? 0
                    ),
                    version,
                    location,
                    nil,
                    Set()
                )
            }
        } else {
            historyViewUpdate = combineLatest(queue: .mainQueue(),
                self.chatHistoryLocationPromise.get(),
                self.ignoreMessagesInTimestampRangePromise.get(),
                self.ignoreMessageIdsPromise.get()
            )
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                if lhs.0 != rhs.0 {
                    return false
                }
                if lhs.1 != rhs.1 {
                    return false
                }
                if lhs.2 != rhs.2 {
                    return false
                }
                return true
            })
            |> mapToSignal { location, ignoreMessagesInTimestampRange, ignoreMessageIds in
                return chatHistoryViewForLocation(location, ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, ignoreMessageIds: ignoreMessageIds, context: context, chatLocation: chatLocation, chatLocationContextHolder: chatLocationContextHolder, scheduled: isScheduledMessages, fixedCombinedReadStates: fixedCombinedReadStates.with { $0 }, tag: tag, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, additionalData: additionalData, orderStatistics: [], useRootInterfaceStateForThread: useRootInterfaceStateForThread)
                |> beforeNext { viewUpdate in
                    switch viewUpdate {
                        case let .HistoryView(view, _, _, _, _, _, _):
                            let _ = fixedCombinedReadStates.swap(view.fixedReadStates)
                        default:
                            break
                    }
                }
                |> map { view -> (ChatHistoryViewUpdate, Int, ChatHistoryLocationInput?, ClosedRange<Int32>?, Set<MessageId>) in
                    let version = currentViewVersion.modify({ value in
                        if let value = value {
                            return value + 1
                        } else {
                            return 0
                        }
                    })!
                    return (view, version, location, ignoreMessagesInTimestampRange, ignoreMessageIds)
                }
            }
        }
        
        let previousView = self.previousView
        let automaticDownloadNetworkType = context.account.networkType
        |> map { type -> MediaAutoDownloadNetworkType in
            switch type {
                case .none, .wifi:
                    return .wifi
                case .cellular:
                    return .cellular
            }
        }
        |> distinctUntilChanged
        
        let chatHistoryEntriesForViewState = Atomic<ChatHistoryEntriesForViewState>(value: ChatHistoryEntriesForViewState())
        
        let animatedEmojiStickers: Signal<[String: [StickerPackItem]], NoError> = context.animatedEmojiStickers
        let additionalAnimatedEmojiStickers = context.additionalAnimatedEmojiStickers
        
        let previousHistoryAppearsCleared = self.previousHistoryAppearsCleared
                
        let updatingMedia = context.account.pendingUpdateMessageManager.updatingMessageMedia
        |> map { value -> [MessageId: ChatUpdatingMessageMedia] in
            var result = value
            for id in value.keys {
                if id.peerId != chatLocation.peerId {
                    result.removeValue(forKey: id)
                }
            }
            return result
        }
        |> distinctUntilChanged
        
        let customChannelDiscussionReadState: Signal<MessageId?, NoError>
        if case let .peer(peerId) = chatLocation, peerId.namespace == Namespaces.Peer.CloudChannel {
            customChannelDiscussionReadState = context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.LinkedDiscussionPeerId(id: peerId),
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
            )
            |> mapToSignal { linkedDiscussionPeerId, peer -> Signal<PeerId?, NoError> in
                guard case let .channel(peer) = peer, case .broadcast = peer.info else {
                    return .single(nil)
                }
                guard case let .known(value) = linkedDiscussionPeerId else {
                    return .single(nil)
                }
                return .single(value)
            }
            |> distinctUntilChanged
            |> mapToSignal { discussionPeerId -> Signal<MessageId?, NoError> in
                guard let discussionPeerId = discussionPeerId else {
                    return .single(nil)
                }
                
                return context.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.PeerReadCounters(id: discussionPeerId))
                |> map { readCounters -> MessageId? in
                    guard let state = readCounters._asReadCounters() else {
                        return nil
                    }
                    for (namespace, namespaceState) in state.states {
                        if namespace == Namespaces.Message.Cloud {
                            switch namespaceState {
                            case let .idBased(maxIncomingReadId, _, _, _, _):
                                return MessageId(peerId: discussionPeerId, namespace: Namespaces.Message.Cloud, id: maxIncomingReadId)
                            default:
                                break
                            }
                        }
                    }
                    return nil
                }
                |> distinctUntilChanged
            }
        } else {
            customChannelDiscussionReadState = .single(nil)
        }
        
        let customThreadOutgoingReadState: Signal<MessageId?, NoError>
        if case .replyThread = chatLocation {
            customThreadOutgoingReadState = context.chatLocationOutgoingReadState(for: chatLocation, contextHolder: chatLocationContextHolder)
        } else {
            customThreadOutgoingReadState = .single(nil)
        }
        
        let availableReactions: Signal<AvailableReactions?, NoError> = (context as! AccountContextImpl).availableReactions
        let availableMessageEffects: Signal<AvailableMessageEffects?, NoError> = (context as! AccountContextImpl).availableMessageEffects
        
        let savedMessageTags: Signal<SavedMessageTags?, NoError>
        if chatLocation.peerId == self.context.account.peerId {
            savedMessageTags = context.engine.stickers.savedMessageTagData()
        } else {
            savedMessageTags = .single(nil)
        }
        
        let defaultReaction = combineLatest(
            self.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)),
            self.context.account.postbox.preferencesView(keys: [PreferencesKeys.reactionSettings])
        )
        |> map { peer, preferencesView -> MessageReaction.Reaction? in
            let reactionSettings: ReactionSettings
            if let entry = preferencesView.values[PreferencesKeys.reactionSettings], let value = entry.get(ReactionSettings.self) {
                reactionSettings = value
            } else {
                reactionSettings = .default
            }
            var hasPremium = false
            if case let .user(user) = peer {
                hasPremium = user.isPremium
            }
            return reactionSettings.effectiveQuickReaction(hasPremium: hasPremium)
        }
        |> distinctUntilChanged
        
        let accountPeer = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        |> map { peer -> EnginePeer? in
            return peer
        }
        |> distinctUntilChanged

        let topicAuthorId: Signal<EnginePeer.Id?, NoError>
        if let peerId = chatLocation.peerId, let threadId = chatLocation.threadId {
            topicAuthorId = context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
                TelegramEngine.EngineData.Item.Peer.ThreadData(id: peerId, threadId: threadId)
            )
            |> map { peer, data -> EnginePeer.Id? in
                guard let peer else {
                    return nil
                }
                if case let .channel(channel) = peer, channel.flags.contains(.isMonoforum) {
                    return nil
                }
                
                return data?.author
            }
            |> distinctUntilChanged
        } else {
            topicAuthorId = .single(nil)
        }

        let audioTranscriptionSuggestion = combineLatest(
            ApplicationSpecificNotice.getAudioTranscriptionSuggestion(accountManager: context.sharedContext.accountManager),
            self.justSentTextMessagePromise.get()
        )
        
        let translationState: Signal<ChatTranslationState?, NoError>
        if let peerId = chatLocation.peerId, peerId.namespace != Namespaces.Peer.SecretChat && peerId != context.account.peerId && subject != .scheduledMessages {
            translationState = chatTranslationState(context: context, peerId: peerId, threadId: self.chatLocation.threadId)
        } else {
            translationState = .single(nil)
        }
        
        let promises = combineLatest(
            self.historyAppearsClearedPromise.get(),
            self.pendingUnpinnedAllMessagesPromise.get(),
            self.pendingRemovedMessagesPromise.get(),
            self.currentlyPlayingMessageIdPromise.get(),
            self.scrollToMessageIdPromise.get(),
            self.chatHasBotsPromise.get(),
            self.allAdMessagesPromise.get()
        )
        
        let contentSettings = self.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ContentSettings())
        
        let maxReadStoryId: Signal<Int32?, NoError>
        if let peerId = self.chatLocation.peerId, peerId.namespace == Namespaces.Peer.CloudUser {
            maxReadStoryId = self.context.account.postbox.combinedView(keys: [PostboxViewKey.storiesState(key: .peer(peerId))])
            |> map { views -> Int32? in
                guard let view = views.views[PostboxViewKey.storiesState(key: .peer(peerId))] as? StoryStatesView else {
                    return nil
                }
                if let state = view.value?.get(Stories.PeerState.self) {
                    return state.maxReadId
                } else {
                    return nil
                }
            }
            |> distinctUntilChanged
        } else {
            maxReadStoryId = .single(nil)
        }
        
        let recommendedChannels: Signal<RecommendedChannels?, NoError>
        if let peerId = self.chatLocation.peerId, peerId.namespace == Namespaces.Peer.CloudChannel {
            recommendedChannels = self.context.engine.peers.recommendedChannels(peerId: peerId)
        } else {
            recommendedChannels = .single(nil)
        }
        
        let audioTranscriptionTrial = self.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.AudioTranscriptionTrial())
        
        let chatThemes = self.context.engine.themes.getChatThemes(accountManager: self.context.sharedContext.accountManager)
        
        let deviceContactsNumbers = self.context.sharedContext.deviceContactPhoneNumbers.get()
        |> distinctUntilChanged
        
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
        
        let preferredStoryHighQuality: Signal<Bool, NoError> = combineLatest(
            context.sharedContext.automaticMediaDownloadSettings
            |> map { settings in
                return settings.highQualityStories
            }
            |> distinctUntilChanged,
            context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)
            )
        )
        |> map { setting, peer -> Bool in
            let isPremium = peer?.isPremium ?? false
            return setting && isPremium
        }
        |> distinctUntilChanged
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var measure_isFirstTime = true
        let messageViewQueue = Queue.mainQueue()
        let historyViewTransitionDisposable = (combineLatest(queue: messageViewQueue,
            historyViewUpdate |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_historyViewUpdate"),
            self.chatPresentationDataPromise.get() |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_chatPresentationData"),
            selectedMessages |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_selectedMessages"),
            updatingMedia |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_updatingMedia"),
            automaticDownloadNetworkType |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_automaticDownloadNetworkType"),
            preferredStoryHighQuality |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_preferredStoryHighQuality"),
            animatedEmojiStickers |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_animatedEmojiStickers"),
            additionalAnimatedEmojiStickers |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_additionalAnimatedEmojiStickers"),
            customChannelDiscussionReadState |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_customChannelDiscussionReadState"),
            customThreadOutgoingReadState |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_customThreadOutgoingReadState"),
            availableReactions |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_availableReactions"),
            availableMessageEffects |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_availableMessageEffects"),
            savedMessageTags |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_savedMessageTags"),
            defaultReaction |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_defaultReaction"),
            accountPeer |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_accountPeer"),
            audioTranscriptionSuggestion |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_audioTranscriptionSuggestion"),
            promises |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_promises"),
            topicAuthorId |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_topicAuthorId"),
            translationState |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_translationState"),
            maxReadStoryId |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_maxReadStoryId"),
            recommendedChannels |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_recommendedChannels"),
            audioTranscriptionTrial |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_audioTranscriptionTrial"),
            chatThemes |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_chatThemes"),
            deviceContactsNumbers |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_deviceContactsNumbers"),
            contentSettings |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_contentSettings")
        ) |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_firstChatHistoryTransition")).startStrict(next: { [weak self] update, chatPresentationData, selectedMessages, updatingMedia, networkType, preferredStoryHighQuality, animatedEmojiStickers, additionalAnimatedEmojiStickers, customChannelDiscussionReadState, customThreadOutgoingReadState, availableReactions, availableMessageEffects, savedMessageTags, defaultReaction, accountPeer, suggestAudioTranscription, promises, topicAuthorId, translationState, maxReadStoryId, recommendedChannels, audioTranscriptionTrial, chatThemes, deviceContactsNumbers, contentSettings in
            let (historyAppearsCleared, pendingUnpinnedAllMessages, pendingRemovedMessages, currentlyPlayingMessageIdAndType, scrollToMessageId, chatHasBots, allAdMessages) = promises
            
            if measure_isFirstTime {
                measure_isFirstTime = false
                #if DEBUG
                let deltaTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                print("Chat load time: \(deltaTime) ms")
                #endif
            }
            
            func applyHole() {
                Queue.mainQueue().async {
                    if let strongSelf = self {
                        if update.2 != strongSelf.chatHistoryLocationValue {
                            return
                        }
                        
                        let historyView = (strongSelf.opaqueTransactionState as? ChatHistoryTransactionOpaqueState)?.historyView
                        let displayRange = strongSelf.displayedItemRange
                        if let filteredEntries = historyView?.filteredEntries, let visibleRange = displayRange.visibleRange {
                            var anchorIndex: MessageIndex?
                            loop: for index in visibleRange.firstIndex ..< filteredEntries.count {
                                switch filteredEntries[filteredEntries.count - 1 - index] {
                                case let .MessageEntry(message, _, _, _, _, _):
                                    if message.adAttribute == nil {
                                        anchorIndex = message.index
                                        break loop
                                    }
                                case let .MessageGroupEntry(_, messages, _):
                                    for (message, _, _, _, _) in messages {
                                        if message.adAttribute == nil {
                                            anchorIndex = message.index
                                            break loop
                                        }
                                    }
                                default:
                                    break
                                }
                            }
                            if anchorIndex == nil, let historyView = historyView {
                                for entry in historyView.originalView.entries {
                                    anchorIndex = entry.message.index
                                    break
                                }
                            }
                            if let anchorIndex = anchorIndex {
                                strongSelf.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Navigation(index: .message(anchorIndex), anchorIndex: .message(anchorIndex), count: historyMessageCount, highlight: false), id: (strongSelf.chatHistoryLocationValue?.id).flatMap({ $0 + 1 }) ?? 0)
                            }
                        } else {
                            if let subject = subject, case let .message(messageSubject, highlight, _, setupReply) = subject {
                                let initialSearchLocation: ChatHistoryInitialSearchLocation
                                switch messageSubject {
                                case let .id(id):
                                    initialSearchLocation = .id(id)
                                case let .timestamp(timestamp):
                                    if let peerId = strongSelf.chatLocation.peerId {
                                        initialSearchLocation = .index(MessageIndex(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 1), timestamp: timestamp))
                                    } else {
                                        //TODO:implement
                                        initialSearchLocation = .index(.absoluteUpperBound())
                                    }
                                }
                                strongSelf.chatHistoryLocationValue = ChatHistoryLocationInput(content: .InitialSearch(subject: MessageHistoryInitialSearchSubject(location: initialSearchLocation, quote: (highlight?.quote).flatMap { quote in MessageHistoryInitialSearchSubject.Quote(string: quote.string, offset: quote.offset) }, todoTaskId: highlight?.todoTaskId), count: historyMessageCount, highlight: highlight != nil, setupReply: setupReply), id: (strongSelf.chatHistoryLocationValue?.id).flatMap({ $0 + 1 }) ?? 0)
                            } else if let subject = subject, case let .pinnedMessages(maybeMessageId) = subject, let messageId = maybeMessageId {
                                strongSelf.chatHistoryLocationValue = ChatHistoryLocationInput(content: .InitialSearch(subject: MessageHistoryInitialSearchSubject(location: .id(messageId)), count: historyMessageCount, highlight: true, setupReply: false), id: (strongSelf.chatHistoryLocationValue?.id).flatMap({ $0 + 1 }) ?? 0)
                            } else if var chatHistoryLocation = strongSelf.chatHistoryLocationValue {
                                chatHistoryLocation.id += 1
                                strongSelf.chatHistoryLocationValue = chatHistoryLocation
                            } else {
                                strongSelf.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Initial(count: historyMessageCount), id: (strongSelf.chatHistoryLocationValue?.id).flatMap({ $0 + 1 }) ?? 0)
                            }
                        }
                    }
                }
            }
            
            let initialData: ChatHistoryCombinedInitialData?
            switch update.0 {
            case let .Loading(combinedInitialData, type):
                initialData = combinedInitialData
                
                if resetScrolling, let previousViewValue = previousView.with({ $0 })?.0 {
                    let filteredEntries: [ChatHistoryEntry] = []
                    let processedView = ChatHistoryView(originalView: MessageHistoryView(tag: nil, namespaces: .all, entries: [], holeEarlier: false, holeLater: false, isLoading: true), filteredEntries: filteredEntries, associatedData: previousViewValue.associatedData, lastHeaderId: 0, id: previousViewValue.id, locationInput: previousViewValue.locationInput, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set())
                    let previousValueAndVersion = previousView.swap((processedView, update.1, selectedMessages, allAdMessages.version))
                    let previous = previousValueAndVersion?.0
                    let previousSelectedMessages = previousValueAndVersion?.2
                    
                    if let previousVersion = previousValueAndVersion?.1 {
                        assert(update.1 >= previousVersion)
                    }
                    
                    var reason: ChatHistoryViewTransitionReason
                    reason = ChatHistoryViewTransitionReason.InteractiveChanges
                    
                    let disableAnimations = true
                    let forceSynchronous = true
                    
                    let rawTransition = preparedChatHistoryViewTransition(from: previous, to: processedView, reason: reason, reverse: false, chatLocation: chatLocation, controllerInteraction: controllerInteraction, scrollPosition: nil, scrollAnimationCurve: nil, initialData: initialData?.initialData, keyboardButtonsMessage: nil, cachedData: initialData?.cachedData, cachedDataMessages: initialData?.cachedDataMessages, readStateData: initialData?.readStateData, flashIndicators: false, updatedMessageSelection: previousSelectedMessages != selectedMessages, messageTransitionNode: messageTransitionNode(), allUpdated: false)
                    var mappedTransition = mappedChatHistoryViewListTransition(context: context, chatLocation: chatLocation, associatedData: previousViewValue.associatedData, controllerInteraction: controllerInteraction, mode: mode, lastHeaderId: 0, animateFromPreviousFilter: resetScrolling, transition: rawTransition)
                    
                    if disableAnimations {
                        mappedTransition.options.remove(.AnimateInsertion)
                        mappedTransition.options.remove(.AnimateAlpha)
                        mappedTransition.options.remove(.AnimateTopItemPosition)
                        mappedTransition.options.remove(.RequestItemInsertionAnimations)
                    }
                    if forceSynchronous || resetScrolling {
                        mappedTransition.options.insert(.Synchronous)
                    }
                    if resetScrolling {
                        mappedTransition.options.insert(.AnimateAlpha)
                        mappedTransition.options.insert(.AnimateFullTransition)
                    }
                    
                    if resetScrolling {
                        resetScrolling = false
                    }
                    
                    Queue.mainQueue().async {
                        guard let strongSelf = self else {
                            return
                        }
                        if strongSelf.appliedPlayingMessageId?.0 != currentlyPlayingMessageIdAndType?.0 {
                            strongSelf.appliedPlayingMessageId = currentlyPlayingMessageIdAndType
                        }
                        if strongSelf.appliedScrollToMessageId != scrollToMessageId {
                            strongSelf.appliedScrollToMessageId = scrollToMessageId
                        }
                        strongSelf.enqueueHistoryViewTransition(mappedTransition)
                    }
                }
                
                Queue.mainQueue().async {
                    if let strongSelf = self {
                        let cachedData = initialData?.cachedData
                        let cachedDataMessages = initialData?.cachedDataMessages
                        
                        strongSelf._cachedPeerDataAndMessages.set(.single((cachedData, cachedDataMessages)))
                        
                        let loadState: ChatHistoryNodeLoadState = .loading(false)
                        if strongSelf.loadState != loadState {
                            strongSelf.loadState = loadState
                            strongSelf.loadStateUpdated?(loadState, false)
                            for f in strongSelf.additionalLoadStateUpdated {
                                f(loadState, false)
                            }
                        }
                        
                        let historyState: ChatHistoryNodeHistoryState = .loading
                        if strongSelf.currentHistoryState != historyState {
                            strongSelf.currentHistoryState = historyState
                            strongSelf.historyState.set(historyState)
                        }
                        
                        if !strongSelf.didSetInitialData {
                            strongSelf.didSetInitialData = true
                            var combinedInitialData = combinedInitialData
                            combinedInitialData?.cachedData = nil
                            strongSelf._initialData.set(.single(combinedInitialData))
                        }
                        
                        strongSelf._isReady.set(true)
                        if !strongSelf.didSetReady {
                            strongSelf.didSetReady = true
                            #if DEBUG
                            let deltaTime = (CFAbsoluteTimeGetCurrent() - strongSelf.initTimestamp) * 1000.0
                            print("Chat init to dequeue time: \(deltaTime) ms")
                            #endif
                        }
                    }
                }
                
                if case .Generic(.FillHole) = type {
                    applyHole()
                    return
                }
                
                return
            case let .HistoryView(view, type, scrollPosition, flashIndicators, originalScrollPosition, data, id):
                if case .Generic(.FillHole) = type {
                    applyHole()
                    return
                }
                
                initialData = data
                var updatedScrollPosition = scrollPosition
                
                var reverse = false
                var reverseGroups = false
                var includeSearchEntry = false
                if case let .list(search, reverseValue, reverseGroupsValue, _, _, _) = mode {
                    includeSearchEntry = search
                    reverse = reverseValue
                    reverseGroups = reverseGroupsValue
                }
                
                
                var isPremium = false
                if case let .user(user) = accountPeer, user.isPremium {
                    isPremium = true
                }
                
                var audioTranscriptionProvidedByBoost = false
                var autoTranslate = false
                var isCopyProtectionEnabled: Bool = data.initialData?.peer?.isCopyProtectionEnabled ?? false
                for entry in view.additionalData {
                    if case let .peer(_, maybePeer) = entry, let peer = maybePeer {
                        isCopyProtectionEnabled = peer.isCopyProtectionEnabled
                        if let channel = peer as? TelegramChannel {
                            autoTranslate = channel.flags.contains(.autoTranslateEnabled)
                            if let boostLevel = channel.approximateBoostLevel, boostLevel >= premiumConfiguration.minGroupAudioTranscriptionLevel {
                                audioTranscriptionProvidedByBoost = true
                            }
                        }
                    }
                }
                let alwaysDisplayTranscribeButton = ChatMessageItemAssociatedData.DisplayTranscribeButton(
                    canBeDisplayed: suggestAudioTranscription.0 < 2,
                    displayForNotConsumed: suggestAudioTranscription.1,
                    providedByGroupBoost: audioTranscriptionProvidedByBoost
                )
                
                var translateToLanguage: (fromLang: String, toLang: String)?
                if let translationState, (isPremium || autoTranslate)  && translationState.isEnabled {
                    var languageCode = translationState.toLang ?? chatPresentationData.strings.baseLanguageCode
                    let rawSuffix = "-raw"
                    if languageCode.hasSuffix(rawSuffix) {
                        languageCode = String(languageCode.dropLast(rawSuffix.count))
                    }
                    translateToLanguage = (normalizeTranslationLanguage(translationState.fromLang), normalizeTranslationLanguage(languageCode))
                }
                
                var isSuspiciousPeer = false
                if let cachedUserData = data.cachedData as? CachedUserData, let peerStatusSettings = cachedUserData.peerStatusSettings, peerStatusSettings.flags.contains(.canBlock) {
                    isSuspiciousPeer = true
                }
                
                let associatedData = extractAssociatedData(chatLocation: chatLocation, view: view, automaticDownloadNetworkType: networkType, preferredStoryHighQuality: preferredStoryHighQuality, animatedEmojiStickers: animatedEmojiStickers, additionalAnimatedEmojiStickers: additionalAnimatedEmojiStickers, subject: subject, currentlyPlayingMessageId: currentlyPlayingMessageIdAndType?.0, isCopyProtectionEnabled: isCopyProtectionEnabled, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: savedMessageTags, defaultReaction: defaultReaction, isPremium: isPremium, alwaysDisplayTranscribeButton: alwaysDisplayTranscribeButton, accountPeer: accountPeer, topicAuthorId: topicAuthorId, hasBots: chatHasBots, translateToLanguage: translateToLanguage?.toLang, maxReadStoryId: maxReadStoryId, recommendedChannels: recommendedChannels, audioTranscriptionTrial: audioTranscriptionTrial, chatThemes: chatThemes, deviceContactsNumbers: deviceContactsNumbers, isInline: !rotated, showSensitiveContent: contentSettings.ignoreContentRestrictionReasons.contains("sensitive"), isSuspiciousPeer: isSuspiciousPeer)
                
                var includeEmbeddedSavedChatInfo = false
                if case let .replyThread(message) = chatLocation, message.peerId == context.account.peerId, !rotated {
                    includeEmbeddedSavedChatInfo = true
                }
                
                let previousChatHistoryEntriesForViewState = chatHistoryEntriesForViewState.with({ $0 })
                
                let (filteredEntries, updatedChatHistoryEntriesForViewState) = chatHistoryEntriesForView(
                    currentState: previousChatHistoryEntriesForViewState,
                    context: context,
                    location: chatLocation,
                    view: view,
                    includeUnreadEntry: mode == .bubbles,
                    includeEmptyEntry: mode == .bubbles && tag == nil,
                    includeChatInfoEntry: mode == .bubbles,
                    includeSearchEntry: includeSearchEntry && tag != nil,
                    includeEmbeddedSavedChatInfo: includeEmbeddedSavedChatInfo,
                    reverse: reverse,
                    groupMessages: mode == .bubbles,
                    reverseGroupedMessages: reverseGroups,
                    selectedMessages: selectedMessages,
                    presentationData: chatPresentationData,
                    historyAppearsCleared: historyAppearsCleared,
                    skipViewOnceMedia: mode != .bubbles,
                    pendingUnpinnedAllMessages: pendingUnpinnedAllMessages,
                    pendingRemovedMessages: pendingRemovedMessages,
                    associatedData: associatedData,
                    updatingMedia: updatingMedia,
                    customChannelDiscussionReadState: customChannelDiscussionReadState,
                    customThreadOutgoingReadState: customThreadOutgoingReadState,
                    cachedData: data.cachedData,
                    adMessage: allAdMessages.fixed,
                    dynamicAdMessages: allAdMessages.opportunistic
                )
                let lastHeaderId = filteredEntries.last.flatMap { listMessageDateHeaderId(timestamp: $0.index.timestamp) } ?? 0
                let processedView = ChatHistoryView(originalView: view, filteredEntries: filteredEntries, associatedData: associatedData, lastHeaderId: lastHeaderId, id: id, locationInput: update.2, ignoreMessagesInTimestampRange: update.3, ignoreMessageIds: update.4)
                let previousValueAndVersion = previousView.swap((processedView, update.1, selectedMessages, allAdMessages.version))
                let _ = chatHistoryEntriesForViewState.swap(updatedChatHistoryEntriesForViewState)
                let previous = previousValueAndVersion?.0
                let previousSelectedMessages = previousValueAndVersion?.2
                
                if let previousVersion = previousValueAndVersion?.1 {
                    assert(update.1 >= previousVersion)
                }
                                
                if scrollPosition == nil, let originalScrollPosition = originalScrollPosition {
                    switch originalScrollPosition {
                    case let .index(subject, position, _, _, highlight, displayLink, setupReply):
                        if case .upperBound = subject.index {
                            if let previous = previous, previous.filteredEntries.isEmpty {
                                updatedScrollPosition = .index(subject: subject, position: position, directionHint: .Down, animated: false, highlight: highlight, displayLink: displayLink, setupReply: setupReply)
                            }
                        }
                    default:
                        break
                    }
                }
                
                var reason: ChatHistoryViewTransitionReason
                
                let previousHistoryAppearsClearedValue = previousHistoryAppearsCleared.swap(historyAppearsCleared)
                if previousHistoryAppearsClearedValue != nil && previousHistoryAppearsClearedValue != historyAppearsCleared && !historyAppearsCleared {
                    reason = ChatHistoryViewTransitionReason.Initial(fadeIn: !processedView.filteredEntries.isEmpty)
                } else if let previous = previous, previous.id == processedView.id, previous.originalView.entries == processedView.originalView.entries {
                    reason = ChatHistoryViewTransitionReason.InteractiveChanges
                    updatedScrollPosition = nil
                } else if let previous = previous, previous.id == processedView.id, previous.ignoreMessageIds != processedView.ignoreMessageIds {
                    reason = ChatHistoryViewTransitionReason.InteractiveChanges
                    updatedScrollPosition = nil
                } else {
                    switch type {
                        case let .Initial(fadeIn):
                            reason = ChatHistoryViewTransitionReason.Initial(fadeIn: fadeIn)
                        case let .Generic(genericType):
                            switch genericType {
                                case .InitialUnread, .Initial:
                                    reason = ChatHistoryViewTransitionReason.Initial(fadeIn: false)
                                case .Generic:
                                    reason = ChatHistoryViewTransitionReason.InteractiveChanges
                                case .UpdateVisible:
                                    reason = ChatHistoryViewTransitionReason.Reload
                                case .FillHole:
                                    reason = ChatHistoryViewTransitionReason.HoleReload
                            }
                    }
                }
                
                var disableAnimations = false
                var forceSynchronous = false
                
                if let strongSelf = self {
                    if !strongSelf.areContentAnimationsEnabled {
                        disableAnimations = true
                    }
                }
                
                if switchedToAnotherSource {
                    disableAnimations = true
                }
                
                if let previousValueAndVersion = previousValueAndVersion, allAdMessages.version != previousValueAndVersion.3 {
                    reason = ChatHistoryViewTransitionReason.Reload
                    disableAnimations = true
                    forceSynchronous = true
                }
                
                var scrollAnimationCurve: ListViewAnimationCurve? = nil
                if let strongSelf = self, case .default = source {
                    if let translateToLanguage {
                        strongSelf.translationLang = (fromLang: translateToLanguage.fromLang, toLang: translateToLanguage.toLang)
                    } else {
                        strongSelf.translationLang = nil
                    }
                    if strongSelf.appliedScrollToMessageId == nil, let scrollToMessageId = scrollToMessageId {
                        updatedScrollPosition = .index(subject: MessageHistoryScrollToSubject(index: .message(scrollToMessageId), quote: nil), position: .center(.top), directionHint: .Up, animated: true, highlight: false, displayLink: true, setupReply: false)
                        scrollAnimationCurve = .Spring(duration: 0.4)
                    } else {
                        let wasPlaying = strongSelf.appliedPlayingMessageId != nil
                        if strongSelf.appliedPlayingMessageId?.0 != currentlyPlayingMessageIdAndType?.0, let (currentlyPlayingMessageId, currentlyPlayingVideo) = currentlyPlayingMessageIdAndType {
                            if isFirstTime {
                            } else if case let .peer(peerId) = chatLocation, currentlyPlayingMessageId.id.peerId != peerId {
                            } else {
                                var isChat = false
                                if case .peer = chatLocation {
                                    isChat = true
                                }
                                
                                if (isChat && (wasPlaying || currentlyPlayingVideo)) || (!isChat && !wasPlaying && currentlyPlayingVideo) {
                                    var currentIsVisible = true
                                    var nextIsVisible = false
                                    if let appliedPlayingMessageId = strongSelf.appliedPlayingMessageId {
                                        currentIsVisible = false
                                        strongSelf.forEachVisibleMessageItemNode({ view in
                                            if view.item?.message.id == appliedPlayingMessageId.0.id && appliedPlayingMessageId.1 == true {
                                                currentIsVisible = true
                                            }
                                        })
                                    }
                                    strongSelf.forEachVisibleMessageItemNode({ view in
                                        if view.item?.message.id == currentlyPlayingMessageId.id {
                                            nextIsVisible = true
                                        }
                                    })
                                    if currentIsVisible && nextIsVisible && currentlyPlayingVideo {
                                        updatedScrollPosition = .index(subject: MessageHistoryScrollToSubject(index: .message(currentlyPlayingMessageId), quote: nil), position: .center(.bottom), directionHint: .Up, animated: true, highlight: true, displayLink: true, setupReply: false)
                                        scrollAnimationCurve = .Spring(duration: 0.4)
                                    }
                                }
                            }
                        }
                    }
                    isFirstTime = false
                }
                
                if let strongSelf = self {
                    if let recommendedChannels, !recommendedChannels.channels.isEmpty && !recommendedChannels.isHidden {
                        if !strongSelf.didSetupRecommendedChannelsPreload {
                            strongSelf.didSetupRecommendedChannelsPreload = true
                            let preloadDisposable = DisposableSet()
                            for channel in recommendedChannels.channels.prefix(5) {
                                preloadDisposable.add(strongSelf.context.account.viewTracker.polledChannel(peerId: channel.peer.id).startStrict())
                                preloadDisposable.add(strongSelf.context.account.addAdditionalPreloadHistoryPeerId(peerId: channel.peer.id))
                            }
                            strongSelf.preloadRecommendedChannelsDisposable.set(preloadDisposable)
                        }
                    } else {
                        strongSelf.didSetupRecommendedChannelsPreload = false
                        strongSelf.preloadRecommendedChannelsDisposable.set(nil)
                    }
                }

                if let strongSelf = self, updatedScrollPosition == nil, case .InteractiveChanges = reason, case let .known(offset) = strongSelf.visibleContentOffset(), abs(offset) <= 0.9, let previous = previous {
                    var fillsScreen = true
                    switch strongSelf.visibleBottomContentOffset() {
                    case let .known(bottomOffset):
                        if bottomOffset <= strongSelf.visibleSize.height - strongSelf.insets.bottom {
                            fillsScreen = false
                        }
                    default:
                        break
                    }

                    var previousNumAds = 0
                    for entry in previous.filteredEntries {
                        if case let .MessageEntry(message, _, _, _, _, _) = entry {
                            if message.adAttribute != nil {
                                previousNumAds += 1
                            }
                        }
                    }

                    var updatedNumAds = 0
                    var firstNonAdIndex: MessageIndex?
                    for entry in processedView.filteredEntries.reversed() {
                        if case let .MessageEntry(message, _, _, _, _, _) = entry {
                            if message.adAttribute != nil {
                                updatedNumAds += 1
                            } else {
                                if firstNonAdIndex == nil {
                                    firstNonAdIndex = message.index
                                }
                            }
                        }
                    }

                    if fillsScreen, let firstNonAdIndex = firstNonAdIndex, previousNumAds == 0, updatedNumAds != 0 {
                        updatedScrollPosition = .index(subject: MessageHistoryScrollToSubject(index: .message(firstNonAdIndex), quote: nil), position: .top(0.0), directionHint: .Up, animated: false, highlight: false, displayLink: false, setupReply: false)
                        disableAnimations = true
                    }
                }
                
                if let strongSelf = self, updatedScrollPosition == nil, case .InteractiveChanges = reason, let previous = previous, case let .known(offset) = strongSelf.visibleContentOffset(), abs(offset) <= 320.0 {
                    var hadJoin = false
                    var hadAd = false
                    for entry in previous.filteredEntries.reversed() {
                        if case let .MessageEntry(message, _, _, _, _, _) = entry {
                            if let action = message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction, case .joinedChannel = action.action {
                                hadJoin = true
                                break
                            } else if message.adAttribute != nil {
                                hadAd = true
                            }
                        }
                    }
                    
                    if !hadJoin && hadAd {
                        for entry in processedView.filteredEntries.reversed() {
                            if case let .MessageEntry(message, _, _, _, _, _) = entry {
                                if message.adAttribute == nil {
                                    if let action = message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction, case .joinedChannel = action.action {
                                        updatedScrollPosition = .index(subject: MessageHistoryScrollToSubject(index: .message(message.index), quote: nil), position: .top(0.0), directionHint: .Up, animated: true, highlight: false, displayLink: false, setupReply: false)
                                    }
                                    break
                                }
                            }
                        }
                    }
                }
                
                var forceUpdateAll = false
                if let previous = previous, previous.associatedData.isPremium != processedView.associatedData.isPremium {
                    forceUpdateAll = true
                }
                
                var keyboardButtonsMessage = view.topTaggedMessages.first
                if let keyboardButtonsMessageValue = keyboardButtonsMessage, keyboardButtonsMessageValue.isRestricted(platform: "ios", contentSettings: context.currentContentSettings.with({ $0 })) {
                    keyboardButtonsMessage = nil
                }
                
                let rawTransition = preparedChatHistoryViewTransition(from: previous, to: processedView, reason: reason, reverse: reverse, chatLocation: chatLocation, controllerInteraction: controllerInteraction, scrollPosition: updatedScrollPosition, scrollAnimationCurve: scrollAnimationCurve, initialData: initialData?.initialData, keyboardButtonsMessage: keyboardButtonsMessage, cachedData: initialData?.cachedData, cachedDataMessages: initialData?.cachedDataMessages, readStateData: initialData?.readStateData, flashIndicators: flashIndicators, updatedMessageSelection: previousSelectedMessages != selectedMessages, messageTransitionNode: messageTransitionNode(), allUpdated: updateAllOnEachVersion || forceUpdateAll)
                var mappedTransition = mappedChatHistoryViewListTransition(context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, mode: mode, lastHeaderId: lastHeaderId, animateFromPreviousFilter: resetScrolling, transition: rawTransition)
                
                if disableAnimations {
                    mappedTransition.options.remove(.AnimateInsertion)
                    mappedTransition.options.remove(.AnimateAlpha)
                    mappedTransition.options.remove(.AnimateTopItemPosition)
                    mappedTransition.options.remove(.RequestItemInsertionAnimations)
                }
                if forceSynchronous || resetScrolling || switchedToAnotherSource {
                    mappedTransition.options.insert(.Synchronous)
                }
                if resetScrolling {
                    mappedTransition.options.insert(.AnimateAlpha)
                    mappedTransition.options.insert(.AnimateFullTransition)
                }
                
                if resetScrolling {
                    resetScrolling = false
                }
                
                Queue.mainQueue().async {
                    guard let strongSelf = self else {
                        return
                    }
                    if strongSelf.appliedPlayingMessageId?.0 != currentlyPlayingMessageIdAndType?.0 {
                        strongSelf.appliedPlayingMessageId = currentlyPlayingMessageIdAndType
                    }
                    if strongSelf.appliedScrollToMessageId != scrollToMessageId {
                        strongSelf.appliedScrollToMessageId = scrollToMessageId
                    }
                    strongSelf.enqueueHistoryViewTransition(mappedTransition)
                }
            }
        })
        
        self.historyDisposable.set(historyViewTransitionDisposable.strict())
    }
    
    private func beginReadHistoryManagement() {
        let previousMaxIncomingMessageIndexByNamespace = Atomic<[MessageId.Namespace: MessageIndex]>(value: [:])
        let readHistory = combineLatest(self.maxVisibleIncomingMessageIndex.get(), self.canReadHistory.get())
        
        self.readHistoryDisposable.set((readHistory |> deliverOnMainQueue).startStrict(next: { [weak self] messageIndex, canRead in
            guard let strongSelf = self else {
                return
            }
            if !canRead {
                return
            }
            
            var apply = false
            let _ = previousMaxIncomingMessageIndexByNamespace.modify { dict in
                let previousIndex = dict[messageIndex.id.namespace]
                if previousIndex == nil || previousIndex! < messageIndex {
                    apply = true
                    var dict = dict
                    dict[messageIndex.id.namespace] = messageIndex
                    return dict
                }
                return dict
            }
            if apply {
                switch strongSelf.chatLocation {
                case .peer, .replyThread:
                    if !strongSelf.context.sharedContext.immediateExperimentalUISettings.skipReadHistory && !strongSelf.context.account.isSupportUser {
                        strongSelf.context.applyMaxReadIndex(for: strongSelf.chatLocation, contextHolder: strongSelf.chatLocationContextHolder, messageIndex: messageIndex)
                    }
                case .customChatContents:
                    break
                }
            }
        }).strict())
        
        self.canReadHistoryDisposable = (self.canReadHistory.get() |> deliverOnMainQueue).startStrict(next: { [weak self, weak context] value in
            if let strongSelf = self {
                if strongSelf.canReadHistoryValue != value {
                    strongSelf.canReadHistoryValue = value
                    strongSelf.controllerInteraction.canReadHistory = value
                    strongSelf.updateReadHistoryActions()

                    if strongSelf.canReadHistoryValue && !strongSelf.suspendReadingReactions && !strongSelf.messageIdsScheduledForMarkAsSeen.isEmpty {
                        let messageIds = strongSelf.messageIdsScheduledForMarkAsSeen
                        strongSelf.messageIdsScheduledForMarkAsSeen.removeAll()
                        context?.account.viewTracker.updateMarkMentionsSeenForMessageIds(messageIds: messageIds)
                    }
                    
                    strongSelf.attemptReadingReactions()
                }
            }
        }).strict()
    }
    
    private func beginPresentationDataManagement(updated: Signal<PresentationData, NoError>) {
        let appConfiguration = self.context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
        |> take(1)
        |> map { view in
            return view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? .defaultValue
        }
        
        var didSetPresentationData = false
        self.presentationDataDisposable = (combineLatest(queue: .mainQueue(),
            updated |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_beginPresentationDataManagement_updated"),
            appConfiguration |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_beginPresentationDataManagement_appConfiguration")
        )
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData, appConfiguration in
            if let strongSelf = self {
                let previousTheme = strongSelf.currentPresentationData.theme
                let previousStrings = strongSelf.currentPresentationData.strings
                let previousWallpaper = strongSelf.currentPresentationData.theme.wallpaper
                let previousAnimatedEmojiScale = strongSelf.currentPresentationData.animatedEmojiScale
                
                let animatedEmojiConfig = ChatHistoryAnimatedEmojiConfiguration.with(appConfiguration: appConfiguration)
                
                if !didSetPresentationData || previousTheme !== presentationData.theme || previousStrings !== presentationData.strings || previousWallpaper != presentationData.chatWallpaper || previousAnimatedEmojiScale != animatedEmojiConfig.scale {
                    didSetPresentationData = true
                    
                    let themeData = ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper)
                    let chatPresentationData = ChatPresentationData(theme: themeData, fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true, largeEmoji: presentationData.largeEmoji, chatBubbleCorners: presentationData.chatBubbleCorners, animatedEmojiScale: animatedEmojiConfig.scale)
                    
                    strongSelf.currentPresentationData = chatPresentationData
                    strongSelf.dynamicBounceEnabled = false
                    
                    strongSelf.forEachItemHeaderNode { itemHeaderNode in
                        if let dateNode = itemHeaderNode as? ChatMessageDateHeaderNodeImpl {
                            dateNode.updatePresentationData(chatPresentationData, context: strongSelf.context)
                        } else if let avatarNode = itemHeaderNode as? ChatMessageAvatarHeaderNodeImpl {
                            avatarNode.updatePresentationData(chatPresentationData, context: strongSelf.context)
                        } else if let dateNode = itemHeaderNode as? ListMessageDateHeaderNode {
                            dateNode.updateThemeAndStrings(theme: presentationData.theme, strings: presentationData.strings)
                        }
                    }
                    strongSelf.chatPresentationDataPromise.set(.single(chatPresentationData))
                }
            }
        }).strict()
    }
    
    private func attemptReadingReactions() {
        if self.canReadHistoryValue && !self.suspendReadingReactions && !self.context.sharedContext.immediateExperimentalUISettings.skipReadHistory && !self.messageIdsWithReactionsScheduledForMarkAsSeen.isEmpty {
            let messageIds = self.messageIdsWithReactionsScheduledForMarkAsSeen
            
            let _ = self.displayUnseenReactionAnimations(messageIds: Array(messageIds))
            
            self.messageIdsWithReactionsScheduledForMarkAsSeen.removeAll()
            self.context.account.viewTracker.updateMarkReactionsSeenForMessageIds(messageIds: messageIds)
        }
        
        if self.canReadHistoryValue {
            self.forEachVisibleMessageItemNode { itemNode in
                itemNode.unreadMessageRangeUpdated()
            }
        }
    }
    
    func takeGenericReactionEffect() -> String? {
        let result = self.genericReactionEffect
        self.loadNextGenericReactionEffect(context: self.context)
        
        return result
    }
    
    private func loadNextGenericReactionEffect(context: AccountContext) {
        self.genericReactionEffectDisposable?.dispose()
        self.genericReactionEffectDisposable = (ReactionContextNode.randomGenericReactionEffect(context: context) |> deliverOnMainQueue).startStrict(next: { [weak self] path in
            guard let strongSelf = self else {
                return
            }
            strongSelf.genericReactionEffect = path
        })
    }
    
    public func setLoadStateUpdated(_ f: @escaping (ChatHistoryNodeLoadState, Bool) -> Void) {
        self.loadStateUpdated = f
    }
    
    public func addSetLoadStateUpdated(_ f: @escaping (ChatHistoryNodeLoadState, Bool) -> Void) {
        self.additionalLoadStateUpdated.append(f)
    }

    private func maybeUpdateOverscrollAction(offset: CGFloat?) {
        if self.freezeOverscrollControl {
            return
        }
        if let offset = offset, offset < -0.1, self.offerNextChannelToRead, let chatControllerNode = self.controllerInteraction.chatControllerNode() as? ChatControllerNode, chatControllerNode.shouldAllowOverscrollActions {
            let overscrollView: ComponentHostView<Empty>
            if let current = self.overscrollView {
                overscrollView = current
            } else {
                overscrollView = ComponentHostView<Empty>()
                self.overscrollView = overscrollView
                self.view.superview?.insertSubview(overscrollView, aboveSubview: self.view)
            }

            let expandDistance = max(-offset - 12.0, 0.0)
            let expandProgress: CGFloat = min(1.0, expandDistance / 94.0)

            let previousType = self.currentOverscrollExpandProgress >= 1.0
            let currentType = expandProgress >= 1.0

            if previousType != currentType, currentType {
                if self.feedback == nil {
                    self.feedback = HapticFeedback()
                }
                if let _ = nextChannelToRead {
                    self.feedback?.tap()
                } else {
                    self.feedback?.success()
                }
            }

            self.currentOverscrollExpandProgress = expandProgress

            if let nextChannelToRead = self.nextChannelToRead {
                let swipeText: NSAttributedString
                let releaseText: NSAttributedString
                switch nextChannelToRead.location {
                case .same:
                    if let controllerNode = self.controllerInteraction.chatControllerNode() as? ChatControllerNode, let chatController = controllerNode.interfaceInteraction?.chatController() as? ChatControllerImpl, chatController.customChatNavigationStack != nil {
                        swipeText = NSAttributedString(string: self.currentPresentationData.strings.Chat_NextSuggestedChannelSwipeProgress)
                        releaseText = NSAttributedString(string: self.currentPresentationData.strings.Chat_NextSuggestedChannelSwipeAction)
                    } else if nextChannelToRead.threadData != nil {
                        swipeText = NSAttributedString(string: self.currentPresentationData.strings.Chat_NextUnreadTopicSwipeProgress)
                        releaseText = NSAttributedString(string: self.currentPresentationData.strings.Chat_NextUnreadTopicSwipeAction)
                    } else {
                        swipeText = NSAttributedString(string: self.currentPresentationData.strings.Chat_NextChannelSameLocationSwipeProgress)
                        releaseText = NSAttributedString(string: self.currentPresentationData.strings.Chat_NextChannelSameLocationSwipeAction)
                    }
                case .archived:
                    swipeText = NSAttributedString(string: self.currentPresentationData.strings.Chat_NextChannelArchivedSwipeProgress)
                    releaseText = NSAttributedString(string: self.currentPresentationData.strings.Chat_NextChannelArchivedSwipeAction)
                case .unarchived:
                    swipeText = NSAttributedString(string: self.currentPresentationData.strings.Chat_NextChannelUnarchivedSwipeProgress)
                    releaseText = NSAttributedString(string: self.currentPresentationData.strings.Chat_NextChannelUnarchivedSwipeAction)
                case let .folder(_, title):
                    let swipeTextValue = NSMutableAttributedString(string: self.currentPresentationData.strings.Chat_NextChannelFolderSwipeProgressV2)
                    let swipeFolderRange = (swipeTextValue.string as NSString).range(of: "{folder}")
                    if swipeFolderRange.location != NSNotFound {
                        swipeTextValue.replaceCharacters(in: swipeFolderRange, with: "")
                        swipeTextValue.insert(title.attributedString(attributes: [
                            ChatTextInputAttributes.bold: true
                        ]), at: swipeFolderRange.location)
                    }
                    swipeText = swipeTextValue
                    
                    let releaseTextValue = NSMutableAttributedString(string: self.currentPresentationData.strings.Chat_NextChannelFolderSwipeActionV2)
                    let releaseTextFolderRange = (releaseTextValue.string as NSString).range(of: "{folder}")
                    if releaseTextFolderRange.location != NSNotFound {
                        releaseTextValue.replaceCharacters(in: releaseTextFolderRange, with: "")
                        releaseTextValue.insert(title.attributedString(attributes: [
                            ChatTextInputAttributes.bold: true
                        ]), at: releaseTextFolderRange.location)
                    }
                    releaseText = releaseTextValue
                }

                if expandProgress < 0.1 {
                    chatControllerNode.setChatInputPanelOverscrollNode(overscrollNode: nil)
                } else if expandProgress >= 1.0 {
                    if chatControllerNode.inputPanelOverscrollNode?.text.string != releaseText.string {
                        chatControllerNode.setChatInputPanelOverscrollNode(overscrollNode: ChatInputPanelOverscrollNode(context: self.context, text: releaseText, color: self.currentPresentationData.theme.theme.rootController.navigationBar.secondaryTextColor, priority: 1))
                    }
                } else {
                    if chatControllerNode.inputPanelOverscrollNode?.text.string != swipeText.string {
                        chatControllerNode.setChatInputPanelOverscrollNode(overscrollNode: ChatInputPanelOverscrollNode(context: self.context, text: swipeText, color: self.currentPresentationData.theme.theme.rootController.navigationBar.secondaryTextColor, priority: 2))
                    }
                }
            } else {
                chatControllerNode.setChatInputPanelOverscrollNode(overscrollNode: nil)
            }

            var overscrollFrame = CGRect(origin: CGPoint(x: 0.0, y: self.insets.top), size: CGSize(width: self.bounds.width, height: 94.0))
            if self.freezeOverscrollControlProgress {
                overscrollFrame.origin.y -= max(0.0, 94.0 - expandDistance)
            }

            overscrollView.frame = self.view.convert(overscrollFrame, to: self.view.superview!)

            let _ = overscrollView.update(
                transition: .immediate,
                component: AnyComponent(ChatOverscrollControl(
                    backgroundColor: selectDateFillStaticColor(theme: self.currentPresentationData.theme.theme, wallpaper: self.currentPresentationData.theme.wallpaper),
                    foregroundColor: bubbleVariableColor(variableColor: self.currentPresentationData.theme.theme.chat.serviceMessage.dateTextColor, wallpaper: self.currentPresentationData.theme.wallpaper),
                    peer: self.nextChannelToRead?.peer,
                    threadData: (self.nextChannelToRead?.threadData).flatMap { threadData in
                        return ChatOverscrollThreadData(
                            id: threadData.id,
                            data: threadData.data
                        )
                    },
                    isForumThread: self.chatLocation.threadId != nil,
                    unreadCount: self.nextChannelToRead?.unreadCount ?? 0,
                    location: self.nextChannelToRead?.location ?? .same,
                    context: self.context,
                    expandDistance: self.freezeOverscrollControl ? 94.0 : expandDistance,
                    freezeProgress: false,
                    absoluteRect: CGRect(origin: CGPoint(x: overscrollFrame.minX, y: self.bounds.height - overscrollFrame.minY), size: overscrollFrame.size),
                    absoluteSize: self.bounds.size,
                    wallpaperNode: chatControllerNode.backgroundNode
                )),
                environment: {},
                containerSize: CGSize(width: self.bounds.width, height: 200.0)
            )
        } else if let overscrollView = self.overscrollView {
            self.overscrollView = nil
            overscrollView.removeFromSuperview()

            if let chatControllerNode = self.controllerInteraction.chatControllerNode() as? ChatControllerNode {
                chatControllerNode.setChatInputPanelOverscrollNode(overscrollNode: nil)
            }
        }
    }
    
    func refreshPollActionsForVisibleMessages() {
        let _ = self.clientId.swap(nextClientId)
        nextClientId += 1
        
        self.updateVisibleItemRange(force: true)
    }
    
    func refocusOnUnreadMessagesIfNeeded() {
        self.forEachItemNode({ itemNode in
            if let itemNode = itemNode as? ChatUnreadItemNode {
                self.ensureItemNodeVisible(itemNode, animated: false, overflow: 0.0, curve: .Default(duration: nil))
            }
        })
    }
    
    private func maybeInsertPendingAdMessage(historyView: ChatHistoryView, toLaterRange: (Int, Int), toEarlierRange: (Int, Int)) {
        if self.pendingDynamicAdMessages.isEmpty {
            return
        }
        
        let selectedRange: (Int, Int)
        if self.currentPrefetchDirectionIsToLater {
            selectedRange = (toLaterRange.0 + 1, toLaterRange.1)
        } else {
            selectedRange = (toEarlierRange.0, toEarlierRange.1 - 1)
        }
        
        if selectedRange.0 <= selectedRange.1 {
            var insertionTimestamp: Int32?
            if self.currentPrefetchDirectionIsToLater {
                outer: for i in selectedRange.0 ... selectedRange.1 {
                    if historyView.originalView.laterId == nil && i >= historyView.filteredEntries.count - 4 {
                        break
                    }
                    
                    switch historyView.filteredEntries[i] {
                    case let .MessageEntry(message, _, _, _, _, _):
                        if message.id.namespace == Namespaces.Message.Cloud {
                            insertionTimestamp = message.timestamp
                            break outer
                        }
                    case let .MessageGroupEntry(_, messages, _):
                        for (message, _, _, _, _) in messages {
                            if message.id.namespace == Namespaces.Message.Cloud {
                                insertionTimestamp = message.timestamp
                                break outer
                            }
                        }
                    default:
                        break
                    }
                }
            } else {
                outer: for i in (selectedRange.0 ... selectedRange.1).reversed() {
                    switch historyView.filteredEntries[i] {
                    case let .MessageEntry(message, _, _, _, _, _):
                        if message.id.namespace == Namespaces.Message.Cloud {
                            insertionTimestamp = message.timestamp
                            break outer
                        }
                    case let .MessageGroupEntry(_, messages, _):
                        for (message, _, _, _, _) in messages {
                            if message.id.namespace == Namespaces.Message.Cloud {
                                insertionTimestamp = message.timestamp
                                break outer
                            }
                        }
                    default:
                        break
                    }
                }
            }
            if let insertionTimestamp = insertionTimestamp {
                let initialMessage = self.pendingDynamicAdMessages.removeFirst()
                let message = Message(
                    stableId: UInt32.max - 1 - UInt32(self.nextPendingDynamicMessageId),
                    stableVersion: initialMessage.stableVersion,
                    id: MessageId(peerId: initialMessage.id.peerId, namespace: initialMessage.id.namespace, id: self.nextPendingDynamicMessageId),
                    globallyUniqueId: nil,
                    groupingKey: nil,
                    groupInfo: nil,
                    threadId: nil,
                    timestamp: insertionTimestamp,
                    flags: initialMessage.flags,
                    tags: initialMessage.tags,
                    globalTags: initialMessage.globalTags,
                    localTags: initialMessage.localTags,
                    customTags: initialMessage.customTags,
                    forwardInfo: initialMessage.forwardInfo,
                    author: initialMessage.author,
                    text: /*"\(initialMessage.adAttribute!.opaqueId.hashValue)" + */initialMessage.text,
                    attributes: initialMessage.attributes,
                    media: initialMessage.media,
                    peers: initialMessage.peers,
                    associatedMessages: initialMessage.associatedMessages,
                    associatedMessageIds: initialMessage.associatedMessageIds,
                    associatedMedia: initialMessage.associatedMedia,
                    associatedThreadInfo: initialMessage.associatedThreadInfo,
                    associatedStories: initialMessage.associatedStories
                )
                self.nextPendingDynamicMessageId += 1
                
                var allAdMessages = self.allAdMessages
                if allAdMessages.fixed?.adAttribute?.opaqueId == message.adAttribute?.opaqueId {
                    allAdMessages.fixed = self.pendingDynamicAdMessages.first?.withUpdatedStableVersion(stableVersion: UInt32(self.nextPendingDynamicMessageId))
                }
                allAdMessages.opportunistic.append(message)
                allAdMessages.version += 1
                self.allAdMessages = allAdMessages
            }
        }
        //TODO:loc mark all ads as seen
    }
    
    func markAdAsSeen(opaqueId: Data) {
        for i in 0 ..< self.pendingDynamicAdMessages.count {
            if let pendingAttribute = self.pendingDynamicAdMessages[i].adAttribute, pendingAttribute.opaqueId == opaqueId {
                self.pendingDynamicAdMessages.remove(at: i)
                break
            }
        }
        if !self.seenAdIds.contains(opaqueId) {
            self.seenAdIds.append(opaqueId)
            self.adMessagesContext?.markAsSeen(opaqueId: opaqueId)
        }
    }
    
    private func processDisplayedItemRangeChanged(displayedRange: ListViewDisplayedItemRange, transactionState: ChatHistoryTransactionOpaqueState) {
        let historyView = transactionState.historyView
        var isTopReplyThreadMessageShownValue = false
        var topVisibleMessageRange: ChatTopVisibleMessageRange?
        let isLoading = historyView.originalView.isLoading
        let translateToLanguage = transactionState.historyView.associatedData.translateToLanguage
        
        if let visible = displayedRange.visibleRange {
            let indexRange = (historyView.filteredEntries.count - 1 - visible.lastIndex, historyView.filteredEntries.count - 1 - visible.firstIndex)
            if indexRange.0 > indexRange.1 {
                assert(false)
                return
            }
            
            var messageIdsToTranslate: [MessageId] = []
            var messageIdsToFactCheck: [MessageId] = []
            if let translateToLanguage {
                let extendedRange: Int = 2
                var wideIndexRange = (historyView.filteredEntries.count - 1 - visible.lastIndex - extendedRange, historyView.filteredEntries.count - 1 - visible.firstIndex + extendedRange)
                wideIndexRange = (max(0, min(historyView.filteredEntries.count - 1, wideIndexRange.0)), max(0, min(historyView.filteredEntries.count - 1, wideIndexRange.1)))
                if wideIndexRange.0 > wideIndexRange.1 {
                    assert(false)
                    return
                }
                
                if wideIndexRange.0 <= wideIndexRange.1 {
                    for i in (wideIndexRange.0 ... wideIndexRange.1) {
                        switch historyView.filteredEntries[i] {
                        case let .MessageEntry(message, _, _, _, _, _):
                            guard message.adAttribute == nil && message.id.namespace == Namespaces.Message.Cloud else {
                                continue
                            }
                            guard message.author?.id != self.context.account.peerId else {
                                continue
                            }
                            if let translation = message.attributes.first(where: { $0 is TranslationMessageAttribute }) as? TranslationMessageAttribute, translation.toLang == translateToLanguage {
                                continue
                            }
                            if !message.text.isEmpty {
                                messageIdsToTranslate.append(message.id)
                            } else if let _ = message.media.first(where: { $0 is TelegramMediaPoll }) {
                                messageIdsToTranslate.append(message.id)
                            }
                        case let .MessageGroupEntry(_, messages, _):
                            for (message, _, _, _, _) in messages {
                                guard message.adAttribute == nil && message.id.namespace == Namespaces.Message.Cloud else {
                                    continue
                                }
                                guard message.author?.id != self.context.account.peerId else {
                                    continue
                                }
                                if let translation = message.attributes.first(where: { $0 is TranslationMessageAttribute }) as? TranslationMessageAttribute, translation.toLang == translateToLanguage {
                                    continue
                                }
                                if !message.text.isEmpty {
                                    messageIdsToTranslate.append(message.id)
                                }
                            }
                        default:
                            break
                        }
                    }
                }
            }
            
            
            let readIndexRange = (0, historyView.filteredEntries.count - 1 - visible.firstIndex)
            
            let toEarlierRange = (0, historyView.filteredEntries.count - 1 - visible.lastIndex - 1)
            let toLaterRange = (historyView.filteredEntries.count - 1 - (visible.firstIndex - 1), historyView.filteredEntries.count - 1)
            
            var messageIdsWithViewCount: [MessageId] = []
            var messageIdsWithLiveLocation: [MessageId] = []
            var messageIdsWithUnsupportedMedia: [MessageAndThreadId] = []
            var messageIdsWithRefreshMedia: [MessageId] = []
            var messageIdsWithRefreshStories: [MessageId] = []
            var messageIdsWithUnseenPersonalMention: [MessageId] = []
            var messageIdsWithUnseenReactions: [MessageId] = []
            var messageIdsWithInactiveExtendedMedia = Set<MessageId>()
            var downloadableResourceIds: [(messageId: MessageId, resourceId: String)] = []
            var allVisibleAnchorMessageIds: [(MessageId, Int)] = []
            var visibleAdOpaqueIds: [Data] = []
            var peerIdsWithRefreshStories: [PeerId] = []
            var visibleBusinessBotMessageId: EngineMessage.Id?
            
            if indexRange.0 <= indexRange.1 {
                for i in (indexRange.0 ... indexRange.1) {
                    let nodeIndex = historyView.filteredEntries.count - 1 - i
                    
                    switch historyView.filteredEntries[i] {
                    case let .MessageEntry(message, _, _, _, _, _):
                        if let author = message.author as? TelegramUser {
                            peerIdsWithRefreshStories.append(author.id)
                        }
                        
                        var hasUnconsumedMention = false
                        var hasUnconsumedContent = false
                        if message.tags.contains(.unseenPersonalMessage) {
                            for attribute in message.attributes {
                                if let attribute = attribute as? ConsumablePersonalMentionMessageAttribute, !attribute.pending {
                                    hasUnconsumedMention = true
                                }
                            }
                        }
                        var contentRequiredValidation = false
                        var mediaRequiredValidation = false
                        var hasUnseenReactions = false
                        var storiesRequiredValidation = false
                        var factCheckRequired = false
                        for attribute in message.attributes {
                            if attribute is ViewCountMessageAttribute {
                                if message.id.namespace == Namespaces.Message.Cloud {
                                    messageIdsWithViewCount.append(message.id)
                                }
                            } else if attribute is ReplyThreadMessageAttribute {
                                if message.id.namespace == Namespaces.Message.Cloud {
                                    messageIdsWithViewCount.append(message.id)
                                }
                            } else if let attribute = attribute as? ConsumableContentMessageAttribute, !attribute.consumed {
                                hasUnconsumedContent = true
                            } else if let _ = attribute as? ContentRequiresValidationMessageAttribute {
                                contentRequiredValidation = true
                            } else if let attribute = attribute as? ReactionsMessageAttribute, attribute.hasUnseen {
                                hasUnseenReactions = true
                            } else if let attribute = attribute as? AdMessageAttribute {
                                if message.stableId != ChatHistoryListNodeImpl.fixedAdMessageStableId {
                                    visibleAdOpaqueIds.append(attribute.opaqueId)
                                }
                            } else if let _ = attribute as? ReplyStoryAttribute {
                                storiesRequiredValidation = true
                            } else if let attribute = attribute as? FactCheckMessageAttribute, case .Pending = attribute.content {
                                factCheckRequired = true
                            }
                        }
                        
                        for media in message.media {
                            if let _ = media as? TelegramMediaUnsupported {
                                contentRequiredValidation = true
                            } else if message.flags.contains(.Incoming), let media = media as? TelegramMediaMap, let liveBroadcastingTimeout = media.liveBroadcastingTimeout {
                                let timestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                                if liveBroadcastingTimeout == liveLocationIndefinitePeriod || message.timestamp + liveBroadcastingTimeout > timestamp {
                                    messageIdsWithLiveLocation.append(message.id)
                                }
                            } else if let telegramFile = media as? TelegramMediaFile {
                                if telegramFile.isAnimatedSticker, (message.id.peerId.namespace == Namespaces.Peer.SecretChat || !telegramFile.previewRepresentations.isEmpty), let size = telegramFile.size, size > 0 && size <= 128 * 1024 {
                                    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                                        if telegramFile.fileId.namespace == Namespaces.Media.CloudFile {
                                            var isValidated = false
                                            attributes: for attribute in telegramFile.attributes {
                                                if case .hintIsValidated = attribute {
                                                    isValidated = true
                                                    break attributes
                                                }
                                            }
                                            
                                            if !isValidated {
                                                mediaRequiredValidation = true
                                            }
                                        }
                                    }
                                }
                                downloadableResourceIds.append((message.id, telegramFile.resource.id.stringRepresentation))
                            } else if let image = media as? TelegramMediaImage {
                                if let representation = image.representations.last {
                                    downloadableResourceIds.append((message.id, representation.resource.id.stringRepresentation))
                                }
                            } else if let invoice = media as? TelegramMediaInvoice, let extendedMedia = invoice.extendedMedia, case .preview = extendedMedia {
                                messageIdsWithInactiveExtendedMedia.insert(message.id)
                                if invoice.version != TelegramMediaInvoice.lastVersion {
                                    contentRequiredValidation = true
                                }
                            } else if let paidContent = media as? TelegramMediaPaidContent, let extendedMedia = paidContent.extendedMedia.first, case .preview = extendedMedia {
                                messageIdsWithInactiveExtendedMedia.insert(message.id)
                            } else if let _ = media as? TelegramMediaStory {
                                storiesRequiredValidation = true
                            } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content, let _ = content.story {
                                storiesRequiredValidation = true
                            }
                        }
                        if contentRequiredValidation {
                            messageIdsWithUnsupportedMedia.append(MessageAndThreadId(messageId: message.id, threadId: message.threadId))
                        }
                        if mediaRequiredValidation {
                            messageIdsWithRefreshMedia.append(message.id)
                        }
                        if storiesRequiredValidation {
                            messageIdsWithRefreshStories.append(message.id)
                        }
                        if hasUnconsumedMention && !hasUnconsumedContent {
                            messageIdsWithUnseenPersonalMention.append(message.id)
                        }
                        if hasUnseenReactions {
                            messageIdsWithUnseenReactions.append(message.id)
                        }
                        if factCheckRequired {
                            messageIdsToFactCheck.append(message.id)
                        }
                        
                        if case let .replyThread(replyThreadMessage) = self.chatLocation, replyThreadMessage.effectiveTopId == message.id {
                            isTopReplyThreadMessageShownValue = true
                        }
                        if let topVisibleMessageRangeValue = topVisibleMessageRange {
                            topVisibleMessageRange = ChatTopVisibleMessageRange(lowerBound: topVisibleMessageRangeValue.lowerBound, upperBound: message.index, isLast: i == historyView.filteredEntries.count - 1, isLoading: isLoading)
                        } else {
                            topVisibleMessageRange = ChatTopVisibleMessageRange(lowerBound: message.index, upperBound: message.index, isLast: i == historyView.filteredEntries.count - 1, isLoading: isLoading)
                        }
                        if message.id.namespace == Namespaces.Message.Cloud, self.remainingDynamicAdMessageInterval != nil {
                            allVisibleAnchorMessageIds.append((message.id, nodeIndex))
                        }
                    case let .MessageGroupEntry(_, messages, _):
                        if let author = messages.first?.0.author as? TelegramUser {
                            peerIdsWithRefreshStories.append(author.id)
                        }
                        
                        for (message, _, _, _, _) in messages {
                            var hasUnconsumedMention = false
                            var hasUnconsumedContent = false
                            var hasUnseenReactions = false
                            var factCheckRequired = false
                            if message.tags.contains(.unseenPersonalMessage) {
                                for attribute in message.attributes {
                                    if let attribute = attribute as? ConsumablePersonalMentionMessageAttribute, !attribute.pending {
                                        hasUnconsumedMention = true
                                    }
                                }
                            }
                            for media in message.media {
                                if let telegramFile = media as? TelegramMediaFile {
                                    downloadableResourceIds.append((message.id, telegramFile.resource.id.stringRepresentation))
                                } else if let image = media as? TelegramMediaImage {
                                    if let representation = image.representations.last {
                                        downloadableResourceIds.append((message.id, representation.resource.id.stringRepresentation))
                                    }
                                }
                            }
                            for attribute in message.attributes {
                                if attribute is ViewCountMessageAttribute {
                                    if message.id.namespace == Namespaces.Message.Cloud {
                                        messageIdsWithViewCount.append(message.id)
                                    }
                                } else if attribute is ReplyThreadMessageAttribute {
                                    if message.id.namespace == Namespaces.Message.Cloud {
                                        messageIdsWithViewCount.append(message.id)
                                    }
                                } else if let attribute = attribute as? ConsumableContentMessageAttribute, !attribute.consumed {
                                    hasUnconsumedContent = true
                                } else if let attribute = attribute as? ReactionsMessageAttribute, attribute.hasUnseen {
                                    hasUnseenReactions = true
                                } else if let attribute = attribute as? FactCheckMessageAttribute, case .Pending = attribute.content {
                                    factCheckRequired = true
                                }
                            }
                            if hasUnconsumedMention && !hasUnconsumedContent {
                                messageIdsWithUnseenPersonalMention.append(message.id)
                            }
                            if hasUnseenReactions {
                                messageIdsWithUnseenReactions.append(message.id)
                            }
                            if factCheckRequired {
                                messageIdsToFactCheck.append(message.id)
                            }
                            if case let .replyThread(replyThreadMessage) = self.chatLocation, replyThreadMessage.effectiveTopId == message.id {
                                isTopReplyThreadMessageShownValue = true
                            }
                            if let topVisibleMessageRangeValue = topVisibleMessageRange {
                                topVisibleMessageRange = ChatTopVisibleMessageRange(lowerBound: topVisibleMessageRangeValue.lowerBound, upperBound: message.index, isLast: i == historyView.filteredEntries.count - 1, isLoading: isLoading)
                            } else {
                                topVisibleMessageRange = ChatTopVisibleMessageRange(lowerBound: message.index, upperBound: message.index, isLast: i == historyView.filteredEntries.count - 1, isLoading: isLoading)
                            }
                        }
                        if let message = messages.first {
                            if message.0.id.namespace == Namespaces.Message.Cloud, self.remainingDynamicAdMessageInterval != nil {
                                allVisibleAnchorMessageIds.append((message.0.id, nodeIndex))
                            }
                        }
                    default:
                        break
                    }
                }
            }
            
            var messageIdsWithPossibleReactions: [MessageId] = []
            for entry in historyView.filteredEntries {
                switch entry {
                case let .MessageEntry(message, _, _, _, _, _):
                    if let _ = message.inlineBotAttribute {
                        if let visibleBusinessBotMessageIdValue = visibleBusinessBotMessageId {
                            if visibleBusinessBotMessageIdValue < message.id {
                                visibleBusinessBotMessageId = message.id
                            }
                        } else {
                            visibleBusinessBotMessageId = message.id
                        }
                    }
                    switch message.id.peerId.namespace {
                    case Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel:
                        messageIdsWithPossibleReactions.append(message.id)
                    default:
                        break
                    }
                case let .MessageGroupEntry(_, messages, _):
                    for (message, _, _, _, _) in messages {
                        if let _ = message.inlineBotAttribute {
                            if let visibleBusinessBotMessageIdValue = visibleBusinessBotMessageId {
                                if visibleBusinessBotMessageIdValue < message.id {
                                    visibleBusinessBotMessageId = message.id
                                }
                            } else {
                                visibleBusinessBotMessageId = message.id
                            }
                        }
                        switch message.id.peerId.namespace {
                        case Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel:
                            messageIdsWithPossibleReactions.append(message.id)
                        default:
                            break
                        }
                    }
                default:
                    break
                }
            }
            
            func addMediaToPrefetch(_ message: Message, _ media: Media, _ messages: inout [(Message, Media)]) -> Bool {
                if media is TelegramMediaImage || media is TelegramMediaFile {
                    messages.append((message, media))
                }
                if messages.count >= 3 {
                    return false
                } else {
                    return true
                }
            }
            
            var toEarlierMediaMessages: [(Message, Media)] = []
            if toEarlierRange.0 <= toEarlierRange.1 {
                outer: for i in (toEarlierRange.0 ... toEarlierRange.1).reversed() {
                    switch historyView.filteredEntries[i] {
                    case let .MessageEntry(message, _, _, _, _, _):
                        for media in message.media {
                            if !addMediaToPrefetch(message, media, &toEarlierMediaMessages) {
                                break outer
                            }
                        }
                    case let .MessageGroupEntry(_, messages, _):
                        for (message, _, _, _, _) in messages {
                            var stop = false
                            for media in message.media {
                                if !addMediaToPrefetch(message, media, &toEarlierMediaMessages) {
                                    stop = true
                                }
                            }
                            if stop {
                                break outer
                            }
                        }
                    default:
                        break
                    }
                }
            }
            
            var toLaterMediaMessages: [(Message, Media)] = []
            if toLaterRange.0 <= toLaterRange.1 {
                outer: for i in (toLaterRange.0 ... toLaterRange.1) {
                    switch historyView.filteredEntries[i] {
                    case let .MessageEntry(message, _, _, _, _, _):
                        for media in message.media {
                            if !addMediaToPrefetch(message, media, &toLaterMediaMessages) {
                                break outer
                            }
                        }
                    case let .MessageGroupEntry(_, messages, _):
                        for (message, _, _, _, _) in messages {
                            for media in message.media {
                                if !addMediaToPrefetch(message, media, &toLaterMediaMessages) {
                                    break outer
                                }
                            }
                        }
                    default:
                        break
                    }
                }
            }
            
            if !messageIdsWithViewCount.isEmpty {
                self.messageProcessingManager.add(messageIdsWithViewCount.map { MessageAndThreadId(messageId: $0, threadId: nil) })
            }
            if !messageIdsWithLiveLocation.isEmpty {
                self.seenLiveLocationProcessingManager.add(messageIdsWithLiveLocation.map { MessageAndThreadId(messageId: $0, threadId: nil) })
            }
            if !messageIdsWithUnsupportedMedia.isEmpty {
                self.unsupportedMessageProcessingManager.add(messageIdsWithUnsupportedMedia)
            }
            if !messageIdsWithRefreshMedia.isEmpty {
                self.refreshMediaProcessingManager.add(messageIdsWithRefreshMedia.map { MessageAndThreadId(messageId: $0, threadId: nil) })
            }
            if !messageIdsWithRefreshStories.isEmpty {
                self.refreshStoriesProcessingManager.add(messageIdsWithRefreshStories.map { MessageAndThreadId(messageId: $0, threadId: nil) })
            }
            if !messageIdsWithUnseenPersonalMention.isEmpty {
                self.messageMentionProcessingManager.add(messageIdsWithUnseenPersonalMention.map { MessageAndThreadId(messageId: $0, threadId: nil) })
            }
            if !messageIdsWithUnseenReactions.isEmpty {
                self.unseenReactionsProcessingManager.add(messageIdsWithUnseenReactions.map { MessageAndThreadId(messageId: $0, threadId: nil) })
                
                if self.canReadHistoryValue && !self.context.sharedContext.immediateExperimentalUISettings.skipReadHistory {
                    let _ = self.displayUnseenReactionAnimations(messageIds: messageIdsWithUnseenReactions)
                }
            }
            if !messageIdsWithPossibleReactions.isEmpty {
                self.messageWithReactionsProcessingManager.add(messageIdsWithPossibleReactions.map { MessageAndThreadId(messageId: $0, threadId: nil) })
            }
            if !downloadableResourceIds.isEmpty {
                let _ = markRecentDownloadItemsAsSeen(postbox: self.context.account.postbox, items: downloadableResourceIds).startStandalone()
            }
            if !messageIdsWithInactiveExtendedMedia.isEmpty {
                self.extendedMediaProcessingManager.update(Set(messageIdsWithInactiveExtendedMedia.map { MessageAndThreadId(messageId: $0, threadId: nil) }))
            }
            if !messageIdsToTranslate.isEmpty {
                self.translationProcessingManager.add(messageIdsToTranslate.map { MessageAndThreadId(messageId: $0, threadId: nil) })
            }
            if !messageIdsToFactCheck.isEmpty {
                self.factCheckProcessingManager.add(messageIdsToFactCheck.map { MessageAndThreadId(messageId: $0, threadId: nil) })
            }
            if !visibleAdOpaqueIds.isEmpty {
                for opaqueId in visibleAdOpaqueIds {
                    self.markAdAsSeen(opaqueId: opaqueId)
                }
            }
            if !peerIdsWithRefreshStories.isEmpty {
                self.context.account.viewTracker.refreshStoryStatsForPeerIds(peerIds: peerIdsWithRefreshStories)
            }
            
            self.currentEarlierPrefetchMessages = toEarlierMediaMessages
            self.currentLaterPrefetchMessages = toLaterMediaMessages
            if self.currentPrefetchDirectionIsToLater {
                self.prefetchManager.updateMessages(toLaterMediaMessages, directionIsToLater: self.currentPrefetchDirectionIsToLater)
            } else {
                self.prefetchManager.updateMessages(toEarlierMediaMessages, directionIsToLater: self.currentPrefetchDirectionIsToLater)
            }
            
            if readIndexRange.0 <= readIndexRange.1 {
                let (maxIncomingIndex, maxOverallIndex) = maxMessageIndexForEntries(historyView, indexRange: readIndexRange)
                
                let messageIndex: MessageIndex?
                switch self.chatLocation {
                case .peer:
                    messageIndex = maxIncomingIndex
                case .replyThread, .customChatContents:
                    messageIndex = maxOverallIndex
                }
                
                if let messageIndex = messageIndex {
                    let _ = messageIndex
                    //self.updateMaxVisibleReadIncomingMessageIndex(messageIndex)
                }
                
                if let maxOverallIndex = maxOverallIndex, maxOverallIndex != self.maxVisibleMessageIndexReported {
                    self.maxVisibleMessageIndexReported = maxOverallIndex
                    self.maxVisibleMessageIndexUpdated?(maxOverallIndex)
                }
            }
            
            if let visible = displayedRange.visibleRange {
                let indexRange = (historyView.filteredEntries.count - 1 - visible.lastIndex, historyView.filteredEntries.count - 1 - visible.firstIndex)
                if indexRange.0 <= indexRange.1 {
                    for (messageId, nodeIndex) in allVisibleAnchorMessageIds {
                        guard let itemNode = self.itemNodeAtIndex(nodeIndex) else {
                            continue
                        }
                        //TODO:loc optimize eviction
                        if self.seenMessageIds.insert(messageId).inserted, let remainingDynamicAdMessageIntervalValue = self.remainingDynamicAdMessageInterval, let remainingDynamicAdMessageDistanceValue = self.remainingDynamicAdMessageDistance {
                            let itemHeight = itemNode.bounds.height
                            
                            let remainingDynamicAdMessageInterval = remainingDynamicAdMessageIntervalValue - 1
                            let remainingDynamicAdMessageDistance = remainingDynamicAdMessageDistanceValue - itemHeight
                            if remainingDynamicAdMessageInterval <= 0 && remainingDynamicAdMessageDistance <= 0.0 {
                                self.remainingDynamicAdMessageInterval = self.pendingDynamicAdMessageInterval
                                self.remainingDynamicAdMessageDistance = self.bounds.height
                                self.maybeInsertPendingAdMessage(historyView: historyView, toLaterRange: toLaterRange, toEarlierRange: toEarlierRange)
                            } else {
                                self.remainingDynamicAdMessageInterval = remainingDynamicAdMessageInterval
                                self.remainingDynamicAdMessageDistance = remainingDynamicAdMessageDistance
                            }
                        }
                    }
                }
            }
            
            if let visibleBusinessBotMessageId, !self.hasDisplayedBusinessBotMessageTooltip {
                var foundItemNode: ChatMessageItemView?
                self.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item, item.message.id == visibleBusinessBotMessageId {
                        foundItemNode = itemNode
                    }
                }
                
                if let foundItemNode {
                    self.hasDisplayedBusinessBotMessageTooltip = true
                    
                    if let controllerNode = self.controllerInteraction.chatControllerNode() as? ChatControllerNode, let chatController = controllerNode.interfaceInteraction?.chatController() as? ChatControllerImpl {
                        chatController.displayBusinessBotMessageTooltip(itemNode: foundItemNode)
                    }
                }
            }
        }
        
        if !self.isSettingTopReplyThreadMessageShown {
            self.isSettingTopReplyThreadMessageShown = true
            self.isTopReplyThreadMessageShown.set(isTopReplyThreadMessageShownValue)
            self.isSettingTopReplyThreadMessageShown = false
        } else {
            #if DEBUG
            print("Ignore repeated isTopReplyThreadMessageShown update")
            #endif
        }
        self.updateTopVisibleMessageRange(topVisibleMessageRange)
        let _ = self.visibleMessageRange.swap(topVisibleMessageRange.flatMap { range in
            return VisibleMessageRange(lowerBound: range.lowerBound, upperBound: range.upperBound)
        })
        
        if let loaded = displayedRange.visibleRange, let firstEntry = historyView.filteredEntries.first, let lastEntry = historyView.filteredEntries.last {
            var mathesFirst = false
            if loaded.firstIndex <= 5 {
                var firstHasGroups = false
                for index in (max(0, historyView.filteredEntries.count - 5) ..< historyView.filteredEntries.count).reversed() {
                    switch historyView.filteredEntries[index] {
                    case .MessageEntry:
                        break
                    case .MessageGroupEntry:
                        firstHasGroups = true
                    default:
                        break
                    }
                }
                if firstHasGroups {
                    mathesFirst = loaded.firstIndex <= 1
                } else {
                    mathesFirst = loaded.firstIndex <= 5
                }
            }
            
            var mathesLast = false
            if loaded.lastIndex >= historyView.filteredEntries.count - 5 {
                var lastHasGroups = false
                for index in 0 ..< min(5, historyView.filteredEntries.count) {
                    switch historyView.filteredEntries[index] {
                    case .MessageEntry:
                        break
                    case .MessageGroupEntry:
                        lastHasGroups = true
                    default:
                        break
                    }
                }
                if lastHasGroups {
                    mathesLast = loaded.lastIndex >= historyView.filteredEntries.count - 1
                } else {
                    mathesLast = loaded.lastIndex >= historyView.filteredEntries.count - 5
                }
            }
            
            if mathesFirst && historyView.originalView.laterId != nil {
                let locationInput: ChatHistoryLocation = .Navigation(index: .message(lastEntry.index), anchorIndex: .message(lastEntry.index), count: historyMessageCount, highlight: false)
                if self.chatHistoryLocationValue?.content != locationInput {
                    self.chatHistoryLocationValue = ChatHistoryLocationInput(content: locationInput, id: self.takeNextHistoryLocationId())
                }
            } else if mathesFirst, historyView.originalView.laterId == nil, !historyView.originalView.holeLater, let chatHistoryLocationValue = self.chatHistoryLocationValue, !chatHistoryLocationValue.isAtUpperBound, historyView.originalView.anchorIndex != .upperBound {
                if self.chatHistoryLocationValue == historyView.locationInput {
                    self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Navigation(index: .upperBound, anchorIndex: .upperBound, count: historyMessageCount, highlight: false), id: self.takeNextHistoryLocationId())
                }
            } else if mathesLast {
                let locationInput: ChatHistoryLocation = .Navigation(index: .message(firstEntry.index), anchorIndex: .message(firstEntry.index), count: historyMessageCount, highlight: false)
                if historyView.originalView.earlierId != nil {
                    if self.chatHistoryLocationValue?.content != locationInput {
                        self.chatHistoryLocationValue = ChatHistoryLocationInput(content: locationInput, id: self.takeNextHistoryLocationId())
                    }
                } else if case let .customChatContents(customChatContents) = self.subject, case .hashTagSearch = customChatContents.kind {
                    if self.chatHistoryLocationValue?.content != locationInput {
                        self.chatHistoryLocationValue = ChatHistoryLocationInput(content: locationInput, id: self.takeNextHistoryLocationId())
                        customChatContents.loadMore()
                    }
                }
            }
        }
        
        var containsPlayableWithSoundItemNode = false
        self.forEachVisibleItemNode { itemNode in
            if let chatItemView = itemNode as? ChatMessageItemView, chatItemView.playMediaWithSound() != nil {
                containsPlayableWithSoundItemNode = true
            }
        }
        self.hasVisiblePlayableItemNodesPromise.set(containsPlayableWithSoundItemNode)
        
        if containsPlayableWithSoundItemNode && !self.isInteractivelyScrollingValue {
            self.isInteractivelyScrollingPromise.set(true)
            self.isInteractivelyScrollingPromise.set(false)
        }
    }
    
    public func scrollScreenToTop() {
        if let subject = self.subject, case .scheduledMessages = subject {
            if let historyView = self.historyView {
                if let entry = historyView.filteredEntries.first {
                    var currentMessage: Message?
                    if case let .MessageEntry(message, _, _, _, _, _) = entry {
                        currentMessage = message
                    } else if case let .MessageGroupEntry(_, messages, _) = entry {
                        currentMessage = messages.first?.0
                    }
                    if let message = currentMessage, let _ = self.anchorMessageInCurrentHistoryView() {
                        self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Scroll(subject: MessageHistoryScrollToSubject(index: .message(message.index), quote: nil), anchorIndex: .message(message.index), sourceIndex: .upperBound, scrollPosition: .bottom(0.0), animated: true, highlight: false, setupReply: false), id: self.takeNextHistoryLocationId())
                    }
                }
            }
        } else {
            var currentMessage: Message?
            if let historyView = self.historyView {
                if let visibleRange = self.displayedItemRange.loadedRange {
                    var index = historyView.filteredEntries.count - 1
                    loop: for entry in historyView.filteredEntries {
                        let isVisible = index >= visibleRange.firstIndex && index <= visibleRange.lastIndex
                        if case let .MessageEntry(message, _, _, _, _, _) = entry {
                            if !isVisible || currentMessage == nil {
                                currentMessage = message
                            }
                        } else if case let .MessageGroupEntry(_, messages, _) = entry {
                            if !isVisible || currentMessage == nil {
                                currentMessage = messages.first?.0
                            }
                        }
                        if isVisible {
                            break loop
                        }
                        index -= 1
                    }
                }
            }
            
            if let currentMessage = currentMessage {
                self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Scroll(subject: MessageHistoryScrollToSubject(index: .message(currentMessage.index), quote: nil), anchorIndex: .message(currentMessage.index), sourceIndex: .upperBound, scrollPosition: .top(0.0), animated: true, highlight: true, setupReply: false), id: self.takeNextHistoryLocationId())
            }
        }
    }
    
    public func scrollToStartOfHistory() {
        self.beganDragging?()
        self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Scroll(subject: MessageHistoryScrollToSubject(index: .lowerBound, quote: nil), anchorIndex: .lowerBound, sourceIndex: .upperBound, scrollPosition: .bottom(0.0), animated: true, highlight: false, setupReply: false), id: self.takeNextHistoryLocationId())
    }
    
    public func scrollToEndOfHistory() {
        self.beganDragging?()
        switch self.visibleContentOffset() {
            case let .known(value) where value <= CGFloat.ulpOfOne:
                break
            default:
                let locationInput = ChatHistoryLocationInput(content: .Scroll(subject: MessageHistoryScrollToSubject(index: .upperBound, quote: nil), anchorIndex: .upperBound, sourceIndex: .lowerBound, scrollPosition: .top(0.0), animated: true, highlight: false, setupReply: false), id: self.takeNextHistoryLocationId())
                self.chatHistoryLocationValue = locationInput
        }
    }
    
    public func scrollToMessage(from fromIndex: MessageIndex, to toIndex: MessageIndex, animated: Bool, highlight: Bool = true, quote: (string: String, offset: Int?)? = nil, todoTaskId: Int32? = nil, scrollPosition: ListViewScrollPosition = .center(.bottom), setupReply: Bool = false) {
        self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Scroll(subject: MessageHistoryScrollToSubject(index: .message(toIndex), quote: quote.flatMap { quote in MessageHistoryScrollToSubject.Quote(string: quote.string, offset: quote.offset) }, todoTaskId: todoTaskId, setupReply: setupReply), anchorIndex: .message(toIndex), sourceIndex: .message(fromIndex), scrollPosition: scrollPosition, animated: animated, highlight: highlight, setupReply: setupReply), id: self.takeNextHistoryLocationId())
    }
    
    public func anchorMessageInCurrentHistoryView() -> Message? {
        if let historyView = self.historyView {
            if let visibleRange = self.displayedItemRange.visibleRange {
                var index = 0
                for entry in historyView.filteredEntries.reversed() {
                    if index >= visibleRange.firstIndex && index <= visibleRange.lastIndex {
                        if case let .MessageEntry(message, _, _, _, _, _) = entry {
                            return message
                        }
                    }
                    index += 1
                }
            }
            
            for case let .MessageEntry(message, _, _, _, _, _) in historyView.filteredEntries {
                return message
            }
        }
        return nil
    }
    
    public func isMessageVisibleOnScreen(_ id: MessageId) -> Bool {
        var result = false
        self.forEachItemNode({ itemNode in
            if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item, item.content.contains(where: { $0.0.id == id }) {
                if self.itemNodeVisibleInsideInsets(itemNode) {
                    result = true
                }
            }
        })
        return result
    }
    
    public func forEachVisibleMessageItemNode(_ f: (ChatMessageItemView) -> Void) {
        self.forEachVisibleItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                f(itemNode)
            }
        }
    }
    
    public func latestMessageInCurrentHistoryView() -> Message? {
        if let historyView = self.historyView {
            if historyView.originalView.laterId == nil, let firstEntry = historyView.filteredEntries.last {
                if case let .MessageEntry(message, _, _, _, _, _) = firstEntry {
                    return message
                }
            }
        }
        return nil
    }
    
    public func firstMessageForEditInCurrentHistoryView() -> Message? {
        if let historyView = self.historyView {
            if historyView.originalView.laterId == nil {
                for entry in historyView.filteredEntries.reversed()  {
                    if case let .MessageEntry(message, _, _, _, _, _) = entry {
                        if canEditMessage(context: context, limitsConfiguration: context.currentLimitsConfiguration.with { EngineConfiguration.Limits($0) }, message: message) {
                            return message
                        }
                    }
                }
            }
        }
        return nil
    }
    
    public func messageInCurrentHistoryView(after messageId: MessageId) -> Message? {
        if let historyView = self.historyView {
            if let index = historyView.filteredEntries.firstIndex(where: { $0.firstIndex.id == messageId }), index < historyView.filteredEntries.count - 1 {
                let nextEntry = historyView.filteredEntries[index + 1]
                if case let .MessageEntry(message, _, _, _, _, _) = nextEntry {
                    return message
                } else if case let .MessageGroupEntry(_, messages, _) = nextEntry, let firstMessage = messages.first {
                    return firstMessage.0
                }
            }
        }
        return nil
    }
    
    public func messageInCurrentHistoryView(before messageId: MessageId) -> Message? {
        if let historyView = self.historyView {
            if let index = historyView.filteredEntries.firstIndex(where: { $0.firstIndex.id == messageId }), index > 0 {
                let nextEntry = historyView.filteredEntries[index - 1]
                if case let .MessageEntry(message, _, _, _, _, _) = nextEntry {
                    return message
                } else if case let .MessageGroupEntry(_, messages, _) = nextEntry, let firstMessage = messages.first {
                    return firstMessage.0
                }
            }
        }
        return nil
    }
    
    public func messageInCurrentHistoryView(_ id: MessageId) -> Message? {
        if let historyView = self.historyView {
            for entry in historyView.filteredEntries {
                if case let .MessageEntry(message, _, _, _, _, _) = entry {
                    if message.id == id {
                        return message
                    }
                } else if case let .MessageGroupEntry(_, messages, _) = entry {
                    for (message, _, _, _, _) in messages {
                        if message.id == id {
                            return message
                        }
                    }
                }
            }
        }
        return nil
    }
    
    public func messageGroupInCurrentHistoryView(_ id: MessageId) -> [Message]? {
        if let historyView = self.historyView {
            for entry in historyView.filteredEntries {
                if case let .MessageEntry(message, _, _, _, _, _) = entry {
                    if message.id == id {
                        return [message]
                    }
                } else if case let .MessageGroupEntry(_, messages, _) = entry {
                    for (message, _, _, _, _) in messages {
                        if message.id == id {
                            return messages.map { $0.0 }
                        }
                    }
                }
            }
        }
        return nil
    }
    
    public func forEachMessageInCurrentHistoryView(_ f: (Message) -> Bool) {
        if let historyView = self.historyView {
            for entry in historyView.filteredEntries {
                if case let .MessageEntry(message, _, _, _, _, _) = entry {
                    if !f(message) {
                        return
                    }
                } else if case let .MessageGroupEntry(_, messages, _) = entry {
                    for (message, _, _, _, _) in messages {
                        if !f(message) {
                            return
                        }
                    }
                }
            }
        }
    }
    
    private func updateMaxVisibleReadIncomingMessageIndex(_ index: MessageIndex) {
        self.maxVisibleIncomingMessageIndex.set(index)
    }
    
    private func enqueueHistoryViewTransition(_ transition: ChatHistoryListViewTransition) {
        self.enqueuedHistoryViewTransitions.append(transition)
        self.prefetchManager.updateOptions(InChatPrefetchOptions(networkType: transition.networkType, peerType: transition.peerType))
                
        if !self.didSetInitialData {
            self.didSetInitialData = true
            self._initialData.set(.single(ChatHistoryCombinedInitialData(initialData: transition.initialData, buttonKeyboardMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData, cachedDataMessages: transition.cachedDataMessages, readStateData: transition.readStateData)))
        }
                
        if self.isNodeLoaded {
            self.dequeueHistoryViewTransitions()
        } else {
            self._cachedPeerDataAndMessages.set(.single((transition.cachedData, transition.cachedDataMessages)))
            
            let loadState: ChatHistoryNodeLoadState
            if transition.historyView.filteredEntries.isEmpty {
                if let firstEntry = transition.historyView.originalView.entries.first {
                    var isPeerJoined = false
                    for media in firstEntry.message.media {
                        if let action = media as? TelegramMediaAction, action.action == .peerJoined {
                            isPeerJoined = true
                            break
                        }
                    }
                    loadState = .empty(isPeerJoined ? .joined : .generic)
                } else {
                    loadState = .empty(.generic)
                }
            } else {
                if transition.historyView.filteredEntries.count == 1, let entry = transition.historyView.filteredEntries.first, case .ChatInfoEntry = entry {
                    loadState = .empty(.botInfo)
                } else {
                    loadState = .messages
                }
            }
            if self.loadState != loadState {
                self.loadState = loadState
                self.loadStateUpdated?(loadState, transition.options.contains(.AnimateInsertion))
                for f in self.additionalLoadStateUpdated {
                    f(loadState, transition.options.contains(.AnimateInsertion))
                }
            }
            
            let isEmpty = transition.historyView.originalView.entries.isEmpty || loadState == .empty(.botInfo)
            
            var hasReachedLimits = false
            if case let .customChatContents(customChatContents) = self.subject, let messageLimit = customChatContents.messageLimit {
                hasReachedLimits = transition.historyView.originalView.entries.count >= messageLimit
            }
            
            let historyState: ChatHistoryNodeHistoryState = .loaded(isEmpty: isEmpty, hasReachedLimits: hasReachedLimits)
            if self.currentHistoryState != historyState {
                self.currentHistoryState = historyState
                self.historyState.set(historyState)
            }
        }
    }
    
    private func dequeueHistoryViewTransitions() {
        if self.enqueuedHistoryViewTransitions.isEmpty || self.hasActiveTransition {
            return
        }
        self.hasActiveTransition = true
        let transition = self.enqueuedHistoryViewTransitions.removeFirst()
        
        var expiredMessageStableIds = Set<UInt32>()
        if let previousHistoryView = self.historyView, transition.options.contains(.AnimateInsertion) {
            var existingStableIds = Set<UInt32>()
            for entry in transition.historyView.filteredEntries {
                switch entry {
                case let .MessageEntry(message, _, _, _, _, _):
                    existingStableIds.insert(message.stableId)
                case let .MessageGroupEntry(_, messages, _):
                    for message in messages {
                        existingStableIds.insert(message.0.stableId)
                    }
                default:
                    break
                }
            }
            let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent())
            var maybeRemovedInteractivelyMessageIds: [(UInt32, EngineMessage.Id)] = []
            for entry in previousHistoryView.filteredEntries {
                switch entry {
                case let .MessageEntry(message, _, _, _, _, _):
                    if !existingStableIds.contains(message.stableId) {
                        if let autoremoveAttribute = message.autoremoveAttribute, let countdownBeginTime = autoremoveAttribute.countdownBeginTime {
                            let exipiresAt = countdownBeginTime + autoremoveAttribute.timeout
                            if exipiresAt >= currentTimestamp - 1 {
                                expiredMessageStableIds.insert(message.stableId)
                            }
                        } else {
                            maybeRemovedInteractivelyMessageIds.append((message.stableId, message.id))
                        }
                    }
                case let .MessageGroupEntry(_, messages, _):
                    var isRemoved = true
                    inner: for message in messages {
                        if existingStableIds.contains(message.0.stableId) {
                            isRemoved = false
                            break inner
                        }
                    }
                    if isRemoved, let message = messages.first?.0 {
                        if let autoremoveAttribute = message.autoremoveAttribute, let countdownBeginTime = autoremoveAttribute.countdownBeginTime {
                            let exipiresAt = countdownBeginTime + autoremoveAttribute.timeout
                            if exipiresAt >= currentTimestamp - 1 {
                                expiredMessageStableIds.insert(message.stableId)
                            }
                        } else {
                            maybeRemovedInteractivelyMessageIds.append((message.stableId, message.id))
                        }
                    }
                default:
                    break
                }
            }
            
            var testIds: [MessageId] = []
            if !maybeRemovedInteractivelyMessageIds.isEmpty {
                for (_, id) in maybeRemovedInteractivelyMessageIds {
                    testIds.append(id)
                }
            }
            for id in self.context.engine.messages.synchronouslyIsMessageDeletedInteractively(ids: testIds) {
                if id.namespace == Namespaces.Message.ScheduledCloud {
                    continue
                }
                inner: for (stableId, listId) in maybeRemovedInteractivelyMessageIds {
                    if listId == id {
                        expiredMessageStableIds.insert(stableId)
                        break inner
                    }
                }
            }
            for id in self.ignoreMessageIds {
                inner: for (stableId, listId) in maybeRemovedInteractivelyMessageIds {
                    if listId == id {
                        expiredMessageStableIds.insert(stableId)
                        break inner
                    }
                }
            }
        }
        self.currentDeleteAnimationCorrelationIds.formUnion(expiredMessageStableIds)
        
        var appliedDeleteAnimationCorrelationIds = Set<UInt32>()
        if !self.currentDeleteAnimationCorrelationIds.isEmpty && self.allowDustEffect {
            var foundItemNodes: [ChatMessageItemView] = []
            self.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item {
                    for (message, _) in item.content {
                        if let itemNode = itemNode as? ChatMessageBubbleItemNode {
                            if itemNode.isServiceLikeMessage() {
                                continue
                            }
                        }
                        
                        if self.currentDeleteAnimationCorrelationIds.contains(message.stableId) {
                            appliedDeleteAnimationCorrelationIds.insert(message.stableId)
                            self.currentDeleteAnimationCorrelationIds.remove(message.stableId)
                            foundItemNodes.append(itemNode)
                        }
                    }
                }
            }
            if !foundItemNodes.isEmpty {
                if self.dustEffectLayer == nil {
                    let dustEffectLayer = DustEffectLayer()
                    dustEffectLayer.position = self.bounds.center
                    dustEffectLayer.bounds = CGRect(origin: CGPoint(), size: self.bounds.size)
                    self.dustEffectLayer = dustEffectLayer
                    dustEffectLayer.zPosition = 10.0
                    if self.rotated {
                        dustEffectLayer.transform = CATransform3DMakeRotation(CGFloat(Double.pi), 0.0, 0.0, 1.0)
                    }
                    self.layer.addSublayer(dustEffectLayer)
                    dustEffectLayer.becameEmpty = { [weak self] in
                        guard let self else {
                            return
                        }
                        self.dustEffectLayer?.removeFromSuperlayer()
                        self.dustEffectLayer = nil
                    }
                }
                if let dustEffectLayer = self.dustEffectLayer {
                    for itemNode in foundItemNodes {
                        guard let (image, subFrame) = itemNode.makeContentSnapshot() else {
                            continue
                        }
                        let itemFrame = itemNode.layer.convert(subFrame, to: dustEffectLayer)
                        dustEffectLayer.addItem(frame: itemFrame, image: image)
                        itemNode.isHidden = true
                    }
                }
            }
        }
        
        self.currentAppliedDeleteAnimationCorrelationIds = appliedDeleteAnimationCorrelationIds
        
        let animated = transition.options.contains(.AnimateInsertion)
        
        var previousCloneView: UIView?
        if transition.animateFromPreviousFilter, !"".isEmpty {
            previousCloneView = self.view.snapshotView(afterScreenUpdates: false)
        }

        let completion: (Bool, ListViewDisplayedItemRange) -> Void = { [weak self] wasTransformed, visibleRange in
            if let strongSelf = self {
                strongSelf.currentAppliedDeleteAnimationCorrelationIds.removeAll()
                
                var newIncomingReactions: [MessageId: (value: MessageReaction.Reaction, isLarge: Bool)] = [:]
                
                if case .peer = strongSelf.chatLocation, let previousHistoryView = strongSelf.historyView {
                    var updatedIncomingReactions: [MessageId: (value: MessageReaction.Reaction, isLarge: Bool)] = [:]
                    for entry in transition.historyView.filteredEntries {
                        switch entry {
                        case let .MessageEntry(message, _, _, _, _, _):
                            if message.flags.contains(.Incoming) {
                                continue
                            }
                            if let reactions = message.reactionsAttribute {
                                for recentPeer in reactions.recentPeers {
                                    if recentPeer.isUnseen {
                                        updatedIncomingReactions[message.id] = (recentPeer.value, recentPeer.isLarge)
                                    }
                                }
                            }
                        case let .MessageGroupEntry(_, messages, _):
                            for message in messages {
                                if message.0.flags.contains(.Incoming) {
                                    continue
                                }
                                if let reactions = message.0.reactionsAttribute {
                                    for recentPeer in reactions.recentPeers {
                                        if recentPeer.isUnseen {
                                            updatedIncomingReactions[message.0.id] = (recentPeer.value, recentPeer.isLarge)
                                        }
                                    }
                                }
                            }
                        default:
                            break
                        }
                    }
                    for entry in previousHistoryView.filteredEntries {
                        switch entry {
                        case let .MessageEntry(message, _, _, _, _, _):
                            if let updatedReaction = updatedIncomingReactions[message.id] {
                                var previousReaction: MessageReaction.Reaction?
                                if let reactions = message.reactionsAttribute {
                                    for recentPeer in reactions.recentPeers {
                                        if recentPeer.isUnseen {
                                            previousReaction = recentPeer.value
                                        }
                                    }
                                }
                                if previousReaction != updatedReaction.value {
                                    newIncomingReactions[message.id] = updatedReaction
                                }
                            }
                        case let .MessageGroupEntry(_, messages, _):
                            for message in messages {
                                if let updatedReaction = updatedIncomingReactions[message.0.id] {
                                    var previousReaction: MessageReaction.Reaction?
                                    if let reactions = message.0.reactionsAttribute {
                                        for recentPeer in reactions.recentPeers {
                                            if recentPeer.isUnseen {
                                                previousReaction = recentPeer.value
                                            }
                                        }
                                    }
                                    if previousReaction != updatedReaction.value {
                                        newIncomingReactions[message.0.id] = updatedReaction
                                    }
                                }
                            }
                        default:
                            break
                        }
                    }
                }
                
                var unreadMessageRangeUpdated = false
                
                if case let .peer(peerId) = strongSelf.chatLocation, let previousReadStatesValue = strongSelf.historyView?.originalView.transientReadStates, case let .peer(previousReadStates) = previousReadStatesValue, case let .peer(updatedReadStates) = transition.historyView.originalView.transientReadStates {
                    if let previousPeerReadState = previousReadStates[peerId], let updatedPeerReadState = updatedReadStates[peerId] {
                        if previousPeerReadState != updatedPeerReadState {
                            for (namespace, state) in previousPeerReadState.states {
                                inner: for (updatedNamespace, updatedState) in updatedPeerReadState.states {
                                    if namespace == updatedNamespace {
                                        switch state {
                                        case let .idBased(previousIncomingId, _, _, _, _):
                                            if case let .idBased(updatedIncomingId, _, _, _, _) = updatedState, previousIncomingId <= updatedIncomingId {
                                                let rangeKey = UnreadMessageRangeKey(peerId: peerId, namespace: namespace)
                                                
                                                if let currentRange = strongSelf.controllerInteraction.unreadMessageRange[rangeKey] {
                                                    if currentRange.upperBound < (updatedIncomingId + 1) {
                                                        let updatedRange = currentRange.lowerBound ..< (updatedIncomingId + 1)
                                                        if strongSelf.controllerInteraction.unreadMessageRange[rangeKey] != updatedRange {
                                                            strongSelf.controllerInteraction.unreadMessageRange[rangeKey] = updatedRange
                                                            unreadMessageRangeUpdated = true
                                                        }
                                                    }
                                                } else {
                                                    let updatedRange = (previousIncomingId + 1) ..< (updatedIncomingId + 1)
                                                    if strongSelf.controllerInteraction.unreadMessageRange[rangeKey] != updatedRange {
                                                        strongSelf.controllerInteraction.unreadMessageRange[rangeKey] = updatedRange
                                                        unreadMessageRangeUpdated = true
                                                    }
                                                }
                                            }
                                        case .indexBased:
                                            break
                                        }
                                        
                                        break inner
                                    }
                                }
                            }
                            //print("Read from \(previousPeerReadState) up to \(updatedPeerReadState)")
                        }
                    }
                } else if case let .peer(peerId) = strongSelf.chatLocation, case let .peer(updatedReadStates) = transition.historyView.originalView.transientReadStates {
                    if let updatedPeerReadState = updatedReadStates[peerId] {
                        for (namespace, updatedState) in updatedPeerReadState.states {
                            switch updatedState {
                            case let .idBased(updatedIncomingId, _, _, _, _):
                                let rangeKey = UnreadMessageRangeKey(peerId: peerId, namespace: namespace)
                                
                                if let currentRange = strongSelf.controllerInteraction.unreadMessageRange[rangeKey] {
                                    if currentRange.upperBound < (updatedIncomingId + 1) {
                                        let updatedRange = currentRange.lowerBound ..< (updatedIncomingId + 1)
                                        if strongSelf.controllerInteraction.unreadMessageRange[rangeKey] != updatedRange {
                                            strongSelf.controllerInteraction.unreadMessageRange[rangeKey] = updatedRange
                                            unreadMessageRangeUpdated = true
                                        }
                                    }
                                } else {
                                    let updatedRange = (updatedIncomingId + 1) ..< (Int32.max - 1)
                                    if strongSelf.controllerInteraction.unreadMessageRange[rangeKey] != updatedRange {
                                        strongSelf.controllerInteraction.unreadMessageRange[rangeKey] = updatedRange
                                        unreadMessageRangeUpdated = true
                                    }
                                }
                            case .indexBased:
                                break
                            }
                        }
                    }
                }
                
                strongSelf.historyView = transition.historyView
                
                let loadState: ChatHistoryNodeLoadState
                var alwaysHasMessages = false
                if case .custom = strongSelf.source {
                    if case .customChatContents = strongSelf.chatLocation {
                    } else {
                        alwaysHasMessages = true
                    }
                }
                if alwaysHasMessages {
                    loadState = .messages
                } else if let historyView = strongSelf.historyView {
                    if historyView.filteredEntries.isEmpty {
                        if let firstEntry = historyView.originalView.entries.first {
                            var emptyType = ChatHistoryNodeLoadState.EmptyType.generic
                            for media in firstEntry.message.media {
                                if let action = media as? TelegramMediaAction {
                                    if action.action == .peerJoined {
                                        emptyType = .joined
                                        break
                                    } else if action.action == .historyCleared {
                                        emptyType = .clearedHistory
                                        break
                                    } else if case .topicCreated = action.action, firstEntry.message.author?.id == strongSelf.context.account.peerId {
                                        emptyType = .topic
                                        break
                                    }
                                }
                            }
                            loadState = .empty(emptyType)
                        } else {
                            var emptyType = ChatHistoryNodeLoadState.EmptyType.generic
                            if case let .replyThread(replyThreadMessage) = strongSelf.chatLocation {
                                loop: for entry in historyView.originalView.additionalData {
                                    switch entry {
                                        case let .message(id, messages) where id == replyThreadMessage.effectiveTopId:
                                            if let message = messages.first {
                                                for media in message.media {
                                                    if let action = media as? TelegramMediaAction {
                                                        if case .topicCreated = action.action {
                                                            emptyType = .topic
                                                            break
                                                        }
                                                    }
                                                }
                                                break loop
                                            }
                                        default:
                                            break
                                    }
                                }
                            }
                            loadState = .empty(emptyType)
                        }
                    } else {
                        if historyView.originalView.isLoadingEarlier && strongSelf.chatLocation.peerId?.namespace != Namespaces.Peer.CloudUser {
                            loadState = .loading(true)
                        } else {
                            if historyView.filteredEntries.count == 1, let entry = historyView.filteredEntries.first, case .ChatInfoEntry = entry {
                                loadState = .empty(.botInfo)
                            } else {
                                loadState = .messages
                            }
                        }
                    }
                } else {
                    loadState = .loading(false)
                }
                
                var animateIn = false
                if strongSelf.loadState != loadState {
                    if case .loading = strongSelf.loadState {
                        if case .messages = loadState {
                            animateIn = true
                        }
                    }
                    strongSelf.loadState = loadState
                    let isAnimated = animated || transition.animateIn || animateIn
                    strongSelf.loadStateUpdated?(loadState, isAnimated)
                    for f in strongSelf.additionalLoadStateUpdated {
                        f(loadState, isAnimated)
                    }
                }
                
                var hasAtLeast3Messages = false
                var hasPlentyOfMessages = false
                var hasLotsOfMessages = false
                if let historyView = strongSelf.historyView {
                    if historyView.originalView.holeEarlier || historyView.originalView.holeLater {
                        hasAtLeast3Messages = true
                        hasPlentyOfMessages = true
                        hasLotsOfMessages = true
                    } else if !historyView.originalView.holeEarlier && !historyView.originalView.holeLater {
                        if historyView.filteredEntries.count >= 3 {
                            hasAtLeast3Messages = true
                        }
                        if historyView.filteredEntries.count >= 10 {
                            hasPlentyOfMessages = true
                        }
                        if historyView.filteredEntries.count >= 40 {
                            hasLotsOfMessages = true
                        }
                    }
                }
                
                if strongSelf.hasAtLeast3Messages != hasAtLeast3Messages {
                    strongSelf.hasAtLeast3Messages = hasAtLeast3Messages
                    strongSelf.hasAtLeast3MessagesUpdated?(hasAtLeast3Messages)
                }
                if strongSelf.hasPlentyOfMessages != hasPlentyOfMessages {
                    strongSelf.hasPlentyOfMessages = hasPlentyOfMessages
                    strongSelf.hasPlentyOfMessagesUpdated?(hasPlentyOfMessages)
                }
                if strongSelf.hasLotsOfMessages != hasLotsOfMessages {
                    strongSelf.hasLotsOfMessages = hasLotsOfMessages
                    strongSelf.hasLotsOfMessagesUpdated?(hasLotsOfMessages)
                }
                
                if let _ = visibleRange.loadedRange {
                    if let visible = visibleRange.visibleRange {
                        let visibleFirstIndex = visible.firstIndex
                        if visibleFirstIndex <= visible.lastIndex {
                            let (incomingIndex, overallIndex) = maxMessageIndexForEntries(transition.historyView, indexRange: (transition.historyView.filteredEntries.count - 1 - visible.lastIndex, transition.historyView.filteredEntries.count - 1 - visibleFirstIndex))
                            
                            let messageIndex: MessageIndex?
                            switch strongSelf.chatLocation {
                            case .peer:
                                messageIndex = incomingIndex
                            case .replyThread, .customChatContents:
                                messageIndex = overallIndex
                            }
                            
                            if let messageIndex = messageIndex {
                                let _ = messageIndex
                            }
                        }
                    }
                } else if case .empty(.joined) = loadState, let entry = transition.historyView.originalView.entries.first {
                    strongSelf.updateMaxVisibleReadIncomingMessageIndex(entry.message.index)
                } else if case .empty(.topic) = loadState, let entry = transition.historyView.originalView.entries.first {
                    strongSelf.updateMaxVisibleReadIncomingMessageIndex(entry.message.index)
                }
                
                if !strongSelf.didSetInitialData {
                    strongSelf.didSetInitialData = true
                    strongSelf._initialData.set(.single(ChatHistoryCombinedInitialData(initialData: transition.initialData, buttonKeyboardMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData, cachedDataMessages: transition.cachedDataMessages, readStateData: transition.readStateData)))
                }
                strongSelf._cachedPeerDataAndMessages.set(.single((transition.cachedData, transition.cachedDataMessages)))
                let isEmpty = transition.historyView.originalView.entries.isEmpty || loadState == .empty(.botInfo)
                var hasReachedLimits = false
                if case let .customChatContents(customChatContents) = strongSelf.subject, let messageLimit = customChatContents.messageLimit {
                    hasReachedLimits = transition.historyView.originalView.entries.count >= messageLimit
                }
                let historyState: ChatHistoryNodeHistoryState = .loaded(isEmpty: isEmpty, hasReachedLimits: hasReachedLimits)
                if strongSelf.currentHistoryState != historyState {
                    strongSelf.currentHistoryState = historyState
                    strongSelf.historyState.set(historyState)
                }
                
                var buttonKeyboardMessageUpdated = false
                if let currentButtonKeyboardMessage = strongSelf.currentButtonKeyboardMessage, let buttonKeyboardMessage = transition.keyboardButtonsMessage {
                    if currentButtonKeyboardMessage.id != buttonKeyboardMessage.id || currentButtonKeyboardMessage.stableVersion != buttonKeyboardMessage.stableVersion {
                        buttonKeyboardMessageUpdated = true
                    }
                } else if (strongSelf.currentButtonKeyboardMessage != nil) != (transition.keyboardButtonsMessage != nil) {
                    buttonKeyboardMessageUpdated = true
                }
                if buttonKeyboardMessageUpdated {
                    strongSelf.currentButtonKeyboardMessage = transition.keyboardButtonsMessage
                    strongSelf._buttonKeyboardMessage.set(.single(transition.keyboardButtonsMessage))
                }
                
                if (transition.animateIn || animateIn) && !"".isEmpty {
                    let heightNorm = strongSelf.bounds.height - strongSelf.insets.top
                    strongSelf.forEachVisibleItemNode { itemNode in
                        let delayFactor = itemNode.frame.minY / heightNorm
                        let delay = Double(delayFactor * 0.1)

                        if let itemNode = itemNode as? ChatMessageItemView {
                            itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
                            itemNode.layer.animateScale(from: 0.94, to: 1.0, duration: 0.4, delay: delay, timingFunction: kCAMediaTimingFunctionSpring)
                        } else if let itemNode = itemNode as? ChatUnreadItemNode {
                            itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
                        } else if let itemNode = itemNode as? ChatReplyCountItemNode {
                            itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
                        }
                    }
                    strongSelf.forEachItemHeaderNode { itemNode in
                        let delayFactor = itemNode.frame.minY / heightNorm
                        let delay = Double(delayFactor * 0.2)

                        itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
                        itemNode.layer.animateScale(from: 0.94, to: 1.0, duration: 0.4, delay: delay, timingFunction: kCAMediaTimingFunctionSpring)
                    }
                }
                
                if let scrolledToIndex = transition.scrolledToIndex {
                    if let strongSelf = self {
                        let isInitial: Bool
                        if case .Initial = transition.reason {
                            isInitial = true
                        } else {
                            isInitial = false
                        }
                        strongSelf.scrolledToIndex?(scrolledToIndex, isInitial)
                    }
                } else if transition.scrolledToSomeIndex {
                    self?.scrolledToSomeIndex?()
                }

                if let currentSendAnimationCorrelationIds = strongSelf.currentSendAnimationCorrelationIds {
                    var foundItemNodes: [Int64: ChatMessageItemView] = [:]
                    strongSelf.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item {
                            for (message, _) in item.content {
                                for attribute in message.attributes {
                                    if let attribute = attribute as? OutgoingMessageInfoAttribute, let correlationId = attribute.correlationId {
                                        if currentSendAnimationCorrelationIds.contains(correlationId) {
                                            foundItemNodes[correlationId] = itemNode
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !foundItemNodes.isEmpty {
                        strongSelf.currentSendAnimationCorrelationIds = nil
                        strongSelf.animationCorrelationMessagesFound?(foundItemNodes)
                    }
                }
                
                if !newIncomingReactions.isEmpty {
                    let messageIds = Array(newIncomingReactions.keys)
                    
                    let visibleNewIncomingReactionMessageIds = strongSelf.displayUnseenReactionAnimations(messageIds: messageIds)
                    if !visibleNewIncomingReactionMessageIds.isEmpty {
                        strongSelf.unseenReactionsProcessingManager.add(visibleNewIncomingReactionMessageIds.map { MessageAndThreadId(messageId: $0, threadId: nil) })
                    }
                }
                
                if unreadMessageRangeUpdated {
                    strongSelf.forEachVisibleMessageItemNode { itemNode in
                        itemNode.unreadMessageRangeUpdated()
                    }
                }
                
                strongSelf.hasActiveTransition = false
                
                if let previousCloneView {
                    previousCloneView.transform = strongSelf.view.transform
                    previousCloneView.center = strongSelf.view.center
                    previousCloneView.bounds = strongSelf.view.bounds
                    strongSelf.view.superview?.insertSubview(previousCloneView, belowSubview: strongSelf.view)
                    strongSelf.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    previousCloneView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previousCloneView] _ in
                        previousCloneView?.removeFromSuperview()
                    })
                }
                
                strongSelf.dequeueHistoryViewTransitions()
                
                strongSelf._isReady.set(true)
                
                if !strongSelf.didSetReady {
                    strongSelf.didSetReady = true
                    #if DEBUG
                    let deltaTime = (CFAbsoluteTimeGetCurrent() - strongSelf.initTimestamp) * 1000.0
                    print("Chat init to dequeue time: \(deltaTime) ms")
                    #endif
                }
            }
        }
        
        if let (layoutActionOnViewTransition, layoutCorrelationId) = self.layoutActionOnViewTransition {
            var foundCorrelationMessage = false
            if let layoutCorrelationId = layoutCorrelationId {
                itemSearch: for item in transition.insertItems {
                    if let messageItem = item.item as? ChatMessageItem {
                        for (message, _) in messageItem.content {
                            for attribute in message.attributes {
                                if let attribute = attribute as? OutgoingMessageInfoAttribute {
                                    if attribute.correlationId == layoutCorrelationId {
                                        foundCorrelationMessage = true
                                        break itemSearch
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                foundCorrelationMessage = true
            }

            if foundCorrelationMessage {
                self.layoutActionOnViewTransition = nil
                let (mappedTransition, updateSizeAndInsets) = layoutActionOnViewTransition(transition)
                self.transaction(deleteIndices: mappedTransition.deleteItems, insertIndicesAndItems: transition.insertItems, updateIndicesAndItems: transition.updateItems, options: mappedTransition.options, scrollToItem: mappedTransition.scrollToItem, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: mappedTransition.stationaryItemRange, updateOpaqueState: ChatHistoryTransactionOpaqueState(historyView: transition.historyView), completion: { result in
                    completion(true, result)
                })
            } else {
                self.transaction(deleteIndices: transition.deleteItems, insertIndicesAndItems: transition.insertItems, updateIndicesAndItems: transition.updateItems, options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, updateOpaqueState: ChatHistoryTransactionOpaqueState(historyView: transition.historyView), completion: { result in
                    completion(false, result)
                })
            }
        } else {
            self.transaction(deleteIndices: transition.deleteItems, insertIndicesAndItems: transition.insertItems, updateIndicesAndItems: transition.updateItems, options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, updateOpaqueState: ChatHistoryTransactionOpaqueState(historyView: transition.historyView), completion: { result in
                completion(false, result)
            })
        }
        
        if transition.flashIndicators {
            //self.flashHeaderItems()
        }
    }
    
    private func displayUnseenReactionAnimations(messageIds: [MessageId], forceMapping: [MessageId: [ReactionsMessageAttribute.RecentPeer]] = [:]) -> [MessageId] {
        let timestamp = CACurrentMediaTime()
        var messageIds = messageIds
        for i in (0 ..< messageIds.count).reversed() {
            if let previousTimestamp = self.displayUnseenReactionAnimationsTimestamps[messageIds[i]], previousTimestamp + 1.0 > timestamp {
                messageIds.remove(at: i)
            } else {
                self.displayUnseenReactionAnimationsTimestamps[messageIds[i]] = timestamp
            }
        }
        
        if messageIds.isEmpty {
            return []
        }
        
        guard let chatDisplayNode = self.controllerInteraction.chatControllerNode() as? ChatControllerNode else {
            return []
        }
        var visibleNewIncomingReactionMessageIds: [MessageId] = []
        self.forEachVisibleItemNode { itemNode in
            guard let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item, let reactionsAttribute = item.content.firstMessage.reactionsAttribute, messageIds.contains(item.content.firstMessage.id) else {
                return
            }
            
            var selectedReaction: (MessageReaction.Reaction, EnginePeer?, Bool)?
            let recentPeers = forceMapping[item.content.firstMessage.id] ?? reactionsAttribute.recentPeers
            for recentPeer in recentPeers {
                if recentPeer.isUnseen {
                    selectedReaction = (recentPeer.value, item.content.firstMessage.peers[recentPeer.peerId].flatMap(EnginePeer.init), recentPeer.isLarge)
                    break
                }
            }
            
            guard let (updatedReaction, updateReactionPeer, updatedReactionIsLarge) = selectedReaction else {
                return
            }
            
            visibleNewIncomingReactionMessageIds.append(item.content.firstMessage.id)
            
            var reactionItem: ReactionItem?
            
            switch updatedReaction {
            case .builtin, .stars:
                if let availableReactions = item.associatedData.availableReactions {
                    for reaction in availableReactions.reactions {
                        guard let centerAnimation = reaction.centerAnimation else {
                            continue
                        }
                        guard let aroundAnimation = reaction.aroundAnimation else {
                            continue
                        }
                        if reaction.value == updatedReaction {
                            reactionItem = ReactionItem(
                                reaction: ReactionItem.Reaction(rawValue: reaction.value),
                                appearAnimation: reaction.appearAnimation,
                                stillAnimation: reaction.selectAnimation,
                                listAnimation: centerAnimation,
                                largeListAnimation: reaction.activateAnimation,
                                applicationAnimation: aroundAnimation,
                                largeApplicationAnimation: reaction.effectAnimation,
                                isCustom: false
                            )
                            break
                        }
                    }
                }
            case let .custom(fileId):
                if let itemFile = item.message.associatedMedia[MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)] as? TelegramMediaFile {
                    let itemFile = TelegramMediaFile.Accessor(itemFile)
                    reactionItem = ReactionItem(
                        reaction: ReactionItem.Reaction(rawValue: updatedReaction),
                        appearAnimation: itemFile,
                        stillAnimation: itemFile,
                        listAnimation: itemFile,
                        largeListAnimation: itemFile,
                        applicationAnimation: nil,
                        largeApplicationAnimation: nil,
                        isCustom: true
                    )
                }
            }
            
            if let reactionItem = reactionItem, let targetView = itemNode.targetReactionView(value: updatedReaction) {
                let standaloneReactionAnimation = StandaloneReactionAnimation(genericReactionEffect: self.genericReactionEffect)
                
                chatDisplayNode.messageTransitionNode.addMessageStandaloneReactionAnimation(messageId: item.message.id, standaloneReactionAnimation: standaloneReactionAnimation)
                
                var avatarPeers: [EnginePeer] = []
                if item.message.id.peerId.namespace != Namespaces.Peer.CloudUser, let updateReactionPeer = updateReactionPeer {
                    avatarPeers = [updateReactionPeer]
                }
                
                chatDisplayNode.addSubnode(standaloneReactionAnimation)
                standaloneReactionAnimation.frame = chatDisplayNode.bounds
                standaloneReactionAnimation.animateReactionSelection(
                    context: self.context,
                    theme: item.presentationData.theme.theme,
                    animationCache: self.controllerInteraction.presentationContext.animationCache,
                    reaction: reactionItem,
                    avatarPeers: avatarPeers,
                    playHaptic: true,
                    isLarge: updatedReactionIsLarge,
                    targetView: targetView,
                    addStandaloneReactionAnimation: { [weak self] standaloneReactionAnimation in
                        guard let strongSelf = self, let chatDisplayNode = strongSelf.controllerInteraction.chatControllerNode() as? ChatControllerNode else {
                            return
                        }
                        chatDisplayNode.messageTransitionNode.addMessageStandaloneReactionAnimation(messageId: item.message.id, standaloneReactionAnimation: standaloneReactionAnimation)
                        standaloneReactionAnimation.frame = chatDisplayNode.bounds
                        chatDisplayNode.addSubnode(standaloneReactionAnimation)
                    },
                    completion: { [weak standaloneReactionAnimation] in
                        standaloneReactionAnimation?.removeFromSupernode()
                    }
                )
            }
        }
        return visibleNewIncomingReactionMessageIds
    }
    
    public func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets) {
        self.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets, additionalScrollDistance: 0.0, scrollToTop: false, completion: {})
    }
        
    public func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets, additionalScrollDistance: CGFloat, scrollToTop: Bool, completion: @escaping () -> Void) {
        /*if updateSizeAndInsets.insets.top == 83.0 {
            if !transition.isAnimated {
                assert(true)
            }
        }*/
        var scrollToItem: ListViewScrollToItem?
        var postScrollToItem: ListViewScrollToItem?
        if scrollToTop, case .known = self.visibleContentOffset() {
            scrollToItem = ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Spring(duration: updateSizeAndInsets.duration), directionHint: .Up)
        } else if self.enableUnreadAlignment {
            if updateSizeAndInsets.insets.bottom != self.insets.bottom {
                self.forEachVisibleItemNode { itemNode in
                    if let itemNode = itemNode as? ChatUnreadItemNode, let index = itemNode.index {
                        if abs(itemNode.frame.maxY - (self.visibleSize.height - self.insets.bottom + 6.0)) < 1.0 {
                            postScrollToItem = ListViewScrollToItem(index: index, position: .bottom(0.0), animated: updateSizeAndInsets.duration != 0.0, curve: updateSizeAndInsets.curve, directionHint: .Up)
                        }
                    }
                }
            }
        }
        self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: scrollToItem, additionalScrollDistance: scrollToTop ? 0.0 : additionalScrollDistance, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { [weak self] _ in
            guard let self else {
                return
            }
            if let postScrollToItem = postScrollToItem {
                self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: postScrollToItem, additionalScrollDistance: 0.0, updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in
                    completion()
                })
            } else {
                completion()
            }
        })
        
        if !self.dequeuedInitialTransitionOnLayout {
            self.dequeuedInitialTransitionOnLayout = true
            self.dequeueHistoryViewTransitions()
        }
    }
    
    public func disconnect() {
        self.historyDisposable.set(nil)
    }
    
    private func updateReadHistoryActions() {
        let canRead = self.canReadHistoryValue && self.isScrollAtBottomPosition
        
        if canRead != (self.interactiveReadActionDisposable != nil) {
            if let interactiveReadActionDisposable = self.interactiveReadActionDisposable {
                if !canRead {
                    interactiveReadActionDisposable.dispose()
                    self.interactiveReadActionDisposable = nil
                }
            } else if self.interactiveReadActionDisposable == nil {
                if case let .peer(peerId) = self.chatLocation {
                    if !self.context.sharedContext.immediateExperimentalUISettings.skipReadHistory && !self.context.account.isSupportUser {
                        self.interactiveReadActionDisposable = self.context.engine.messages.installInteractiveReadMessagesAction(peerId: peerId)
                    }
                }
            }
        }
        
        if canRead != (self.interactiveReadReactionsDisposable != nil) {
            if let interactiveReadReactionsDisposable = self.interactiveReadReactionsDisposable {
                if !canRead {
                    interactiveReadReactionsDisposable.dispose()
                    self.interactiveReadReactionsDisposable = nil
                }
            } else if self.interactiveReadReactionsDisposable == nil {
                if case let .peer(peerId) = self.chatLocation {
                    if !self.context.sharedContext.immediateExperimentalUISettings.skipReadHistory {
                        let visibleMessageRange = self.visibleMessageRange
                        self.interactiveReadReactionsDisposable = context.engine.messages.installInteractiveReadReactionsAction(peerId: peerId, getVisibleRange: {
                            return visibleMessageRange.with { $0 }
                        }, didReadReactionsInMessages: { [weak self] idsAndReactions in
                            Queue.mainQueue().after(0.2, {
                                guard let strongSelf = self else {
                                    return
                                }
                                let _ = strongSelf.displayUnseenReactionAnimations(messageIds: Array(idsAndReactions.keys), forceMapping: idsAndReactions)
                            })
                        })
                    }
                }
            }
        }
    }
    
    func lastVisbleMesssage() -> Message? {
        var currentMessage: Message?
        if let historyView = self.historyView {
            if let visibleRange = self.displayedItemRange.visibleRange {
                var index = 0
                loop: for entry in historyView.filteredEntries.reversed() {
                    if index >= visibleRange.firstIndex && index <= visibleRange.lastIndex {
                        if case let .MessageEntry(message, _, _, _, _, _) = entry {
                            currentMessage = message
                            break loop
                        } else if case let .MessageGroupEntry(_, messages, _) = entry {
                            currentMessage = messages.first?.0
                            break loop
                        }
                    }
                    index += 1
                }
            }
        }
        return currentMessage
    }
    
    func immediateScrollState() -> ChatInterfaceHistoryScrollState? {
        var currentMessage: Message?
        if let historyView = self.historyView {
            if let visibleRange = self.displayedItemRange.visibleRange {
                var index = 0
                loop: for entry in historyView.filteredEntries.reversed() {
                    if index >= visibleRange.firstIndex && index <= visibleRange.lastIndex {
                        if case let .MessageEntry(message, _, _, _, _, _) = entry {
                            if message.adAttribute != nil {
                                continue
                            }
                            if index != 0 || historyView.originalView.laterId != nil {
                                currentMessage = message
                            }
                            break loop
                        } else if case let .MessageGroupEntry(_, messages, _) = entry {
                            if index != 0 || historyView.originalView.laterId != nil {
                                currentMessage = messages.first?.0
                            }
                            break loop
                        }
                    }
                    index += 1
                }
            }
        }
        
        if let message = currentMessage {
            var relativeOffset: CGFloat = 0.0
            self.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item, item.message.id == message.id {
                    if let offsetValue = self.itemNodeRelativeOffset(itemNode) {
                        relativeOffset = offsetValue
                    }
                }
            }
            return ChatInterfaceHistoryScrollState(messageIndex: message.index, relativeOffset: Double(relativeOffset))
        }
        return nil
    }
    
    func scrollToNextMessage() {
        if let historyView = self.historyView {
            var scrolled = false
            if let scrollState = self.immediateScrollState() {
                var index = historyView.filteredEntries.count - 1
                loop: for entry in historyView.filteredEntries.reversed() {
                    if entry.index == scrollState.messageIndex {
                        break loop
                    }
                    index -= 1
                }
                
                if index != 0 {
                    var nextItem = false
                    self.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? ChatMessageItemView, itemNode.item?.content.index == scrollState.messageIndex {
                            if itemNode.frame.maxY >= self.bounds.size.height - self.insets.bottom - 4.0 {
                                nextItem = true
                            }
                        }
                    }
                    
                    if !nextItem {
                        scrolled = true
                        self.scrollToMessage(from: scrollState.messageIndex, to: scrollState.messageIndex, animated: true, highlight: false)
                    } else {
                        loop: for i in (index + 1) ..< historyView.filteredEntries.count {
                            let entry = historyView.filteredEntries[i]
                            switch entry {
                                case .MessageEntry, .MessageGroupEntry:
                                    scrolled = true
                                    self.scrollToMessage(from: scrollState.messageIndex, to: entry.index, animated: true, highlight: false)
                                    break loop
                                default:
                                    break
                            }
                        }
                    }
                }
            }
            
            if !scrolled {
                self.scrollToEndOfHistory()
            }
        }
    }
    
    func requestMessageUpdate(_ id: MessageId, andScrollToItem scroll: Bool = false) {
        if let historyView = self.historyView {
            var messageItem: ChatMessageItem?
            self.forEachItemNode({ itemNode in
                if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item {
                    for (message, _) in item.content {
                        if message.id == id {
                            messageItem = item
                            break
                        }
                    }
                }
            })
            
            if let messageItem = messageItem {
                let associatedData = messageItem.associatedData
                let disableFloatingDateHeaders = messageItem.disableDate
                
                loop: for i in 0 ..< historyView.filteredEntries.count {
                    switch historyView.filteredEntries[i] {
                    case let .MessageEntry(message, presentationData, read, location, selection, attributes):
                        if message.id == id {
                            let index = historyView.filteredEntries.count - 1 - i
                            let item: ListViewItem
                            switch self.mode {
                            case .bubbles:
                                item = ChatMessageItemImpl(presentationData: presentationData, context: self.context, chatLocation: self.chatLocation, associatedData: associatedData, controllerInteraction: self.controllerInteraction, content: .message(message: message, read: read, selection: selection, attributes: attributes, location: location), disableDate: disableFloatingDateHeaders)
                            case let .list(_, _, _, displayHeaders, hintLinks, isGlobalSearch):
                                let displayHeader: Bool
                                switch displayHeaders {
                                case .none:
                                    displayHeader = false
                                case .all:
                                    displayHeader = true
                                case .allButLast:
                                    displayHeader = listMessageDateHeaderId(timestamp: message.timestamp) != historyView.lastHeaderId
                                }
                                item = ListMessageItem(presentationData: presentationData, context: self.context, chatLocation: self.chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: self.controllerInteraction), message: message, translateToLanguage: associatedData.translateToLanguage, selection: selection, displayHeader: displayHeader, hintIsLink: hintLinks, isGlobalSearchResult: isGlobalSearch)
                            }
                            let updateItem = ListViewUpdateItem(index: index, previousIndex: index, item: item, directionHint: nil)
                            
                            var scrollToItem: ListViewScrollToItem?
                            if scroll {
                                scrollToItem = ListViewScrollToItem(index: index, position: .center(.top), animated: true, curve: .Spring(duration: 0.4), directionHint: .Down, displayLink: true)
                            }
                            
                            self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [updateItem], options: [.AnimateInsertion], scrollToItem: scrollToItem, additionalScrollDistance: 0.0, updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                            break loop
                        }
                    case let .MessageGroupEntry(_, messages, presentationData):
                        if messages.contains(where: { $0.0.id == id }) {
                            let index = historyView.filteredEntries.count - 1 - i
                            let item: ListViewItem
                            switch self.mode {
                            case .bubbles:
                            item = ChatMessageItemImpl(presentationData: presentationData, context: self.context, chatLocation: self.chatLocation, associatedData: associatedData, controllerInteraction: self.controllerInteraction, content: .group(messages: messages), disableDate: disableFloatingDateHeaders)
                            case .list:
                                assertionFailure()
                                item = ListMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: controllerInteraction), message: messages[0].0, selection: .none, displayHeader: false)
                            }
                            let updateItem = ListViewUpdateItem(index: index, previousIndex: index, item: item, directionHint: nil)
                            
                            var scrollToItem: ListViewScrollToItem?
                            if scroll {
                                scrollToItem = ListViewScrollToItem(index: index, position: .center(.top), animated: true, curve: .Spring(duration: 0.4), directionHint: .Down, displayLink: true)
                            }
                            
                            self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [updateItem], options: [.AnimateInsertion], scrollToItem: scrollToItem, additionalScrollDistance: 0.0, updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                            break loop
                        }
                    default:
                        break
                    }
                }
            }
        }
    }

    func requestMessageUpdate(stableId: UInt32) {
        if let historyView = self.historyView {
            var messageItem: ChatMessageItem?
            self.forEachItemNode({ itemNode in
                if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item {
                    for (message, _) in item.content {
                        if message.stableId == stableId {
                            messageItem = item
                            break
                        }
                    }
                }
            })

            if let messageItem = messageItem {
                let associatedData = messageItem.associatedData
                let disableFloatingDateHeaders = messageItem.disableDate

                loop: for i in 0 ..< historyView.filteredEntries.count {
                    switch historyView.filteredEntries[i] {
                        case let .MessageEntry(message, presentationData, read, location, selection, attributes):
                            if message.stableId == stableId {
                                let index = historyView.filteredEntries.count - 1 - i
                                let item: ListViewItem
                                switch self.mode {
                                    case .bubbles:
                                        item = ChatMessageItemImpl(presentationData: presentationData, context: self.context, chatLocation: self.chatLocation, associatedData: associatedData, controllerInteraction: self.controllerInteraction, content: .message(message: message, read: read, selection: selection, attributes: attributes, location: location), disableDate: disableFloatingDateHeaders)
                                    case let .list(_, _, _, displayHeaders, hintLinks, isGlobalSearch):
                                        let displayHeader: Bool
                                        switch displayHeaders {
                                        case .none:
                                            displayHeader = false
                                        case .all:
                                            displayHeader = true
                                        case .allButLast:
                                            displayHeader = listMessageDateHeaderId(timestamp: message.timestamp) != historyView.lastHeaderId
                                        }
                                        item = ListMessageItem(presentationData: presentationData, context: self.context, chatLocation: self.chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: self.controllerInteraction), message: message, translateToLanguage: associatedData.translateToLanguage, selection: selection, displayHeader: displayHeader, hintIsLink: hintLinks, isGlobalSearchResult: isGlobalSearch)
                                }
                                let updateItem = ListViewUpdateItem(index: index, previousIndex: index, item: item, directionHint: nil)
                                self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [updateItem], options: [.AnimateInsertion], scrollToItem: nil, additionalScrollDistance: 0.0, updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                                break loop
                            }
                        default:
                            break
                    }
                }
            }
        }
    }

    private func messagesAtPoint(_ point: CGPoint) -> [Message]? {
        var resultMessages: [Message]?
        self.forEachVisibleItemNode { itemNode in
            if resultMessages == nil, let itemNode = itemNode as? ListViewItemNode, itemNode.frame.contains(point) {
                if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item {
                    switch item.content {
                        case let .message(message, _, _ , _, _):
                            resultMessages = [message]
                        case let .group(messages):
                            resultMessages = messages.map { $0.0 }
                    }
                }
            }
        }
        return resultMessages
    }
    
    func isMessageVisible(id: MessageId) -> Bool {
        var found = false
        self.forEachVisibleItemNode { itemNode in
            if !found, let itemNode = itemNode as? ListViewItemNode {
                if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item {
                    switch item.content {
                    case let .message(message, _, _ , _, _):
                        if message.id == id {
                            found = true
                        }
                    case let .group(messages):
                        for message in messages {
                            if message.0.id == id {
                                found = true
                            }
                        }
                    }
                }
            }
        }
        return found
    }
    
    private var selectionPanState: (selecting: Bool, initialMessageId: MessageId, toggledMessageIds: [[MessageId]])?
    private var selectionScrollActivationTimer: SwiftSignalKit.Timer?
    private var selectionScrollDisplayLink: ConstantDisplayLinkAnimator?
    private var selectionScrollDelta: CGFloat?
    private var selectionLastLocation: CGPoint?
    
    @objc private func selectionPanGesture(_ recognizer: UIGestureRecognizer) -> Void {
        let location = recognizer.location(in: self.view)
        switch recognizer.state {
            case .began:
                if let messages = self.messagesAtPoint(location), let message = messages.first {
                    let selecting = !(self.controllerInteraction.selectionState?.selectedIds.contains(message.id) ?? false)
                    self.selectionPanState = (selecting, message.id, [])
                    self.controllerInteraction.toggleMessagesSelection(messages.map { $0.id }, selecting)
                }
            case .changed:
                self.handlePanSelection(location: location)
                self.selectionLastLocation = location
            case .ended, .failed, .cancelled:
                self.selectionPanState = nil
                self.selectionScrollDisplayLink = nil
                self.selectionScrollActivationTimer?.invalidate()
                self.selectionScrollActivationTimer = nil
                self.selectionScrollDelta = nil
                self.selectionLastLocation = nil
                self.selectionScrollSkipUpdate = false
            case .possible:
                break
            @unknown default:
                fatalError()
        }
    }
    
    private func handlePanSelection(location: CGPoint) {
        var location = location
        if location.y < self.insets.top {
            location.y = self.insets.top + 5.0
        } else if location.y > self.frame.height - self.insets.bottom {
            location.y = self.frame.height - self.insets.bottom - 5.0
        }
        
        if let state = self.selectionPanState {
            if let messages = self.messagesAtPoint(location), let message = messages.first {
                if message.id == state.initialMessageId {
                    if !state.toggledMessageIds.isEmpty {
                        self.controllerInteraction.toggleMessagesSelection(state.toggledMessageIds.flatMap { $0 }, !state.selecting)
                        self.selectionPanState = (state.selecting, state.initialMessageId, [])
                    }
                } else if state.toggledMessageIds.last?.first != message.id {
                    var updatedToggledMessageIds: [[MessageId]] = []
                    var previouslyToggled = false
                    for i in (0 ..< state.toggledMessageIds.count) {
                        if let messageId = state.toggledMessageIds[i].first {
                            if messageId == message.id {
                                previouslyToggled = true
                                updatedToggledMessageIds = Array(state.toggledMessageIds.prefix(i + 1))
                                
                                let messageIdsToToggle = Array(state.toggledMessageIds.suffix(state.toggledMessageIds.count - i - 1)).flatMap { $0 }
                                self.controllerInteraction.toggleMessagesSelection(messageIdsToToggle, !state.selecting)
                                break
                            }
                        }
                    }
                    
                    if !previouslyToggled {
                        updatedToggledMessageIds = state.toggledMessageIds
                        let isSelected = (self.controllerInteraction.selectionState?.selectedIds.contains(message.id) ?? false)
                        if state.selecting != isSelected {
                            let messageIds = messages.filter { message -> Bool in
                                for media in message.media {
                                    if media is TelegramMediaAction {
                                        return false
                                    }
                                }
                                return true
                            }.map { $0.id }
                            updatedToggledMessageIds.append(messageIds)
                            self.controllerInteraction.toggleMessagesSelection(messageIds, state.selecting)
                        }
                    }
                    
                    self.selectionPanState = (state.selecting, state.initialMessageId, updatedToggledMessageIds)
                }
            }
        
            let scrollingAreaHeight: CGFloat = 50.0
            if location.y < scrollingAreaHeight + self.insets.top || location.y > self.frame.height - scrollingAreaHeight - self.insets.bottom {
                if location.y < self.frame.height / 2.0 {
                    self.selectionScrollDelta = (scrollingAreaHeight - (location.y - self.insets.top)) / scrollingAreaHeight
                } else {
                    self.selectionScrollDelta = -(scrollingAreaHeight - min(scrollingAreaHeight, max(0.0, (self.frame.height - self.insets.bottom - location.y)))) / scrollingAreaHeight
                }
                if let displayLink = self.selectionScrollDisplayLink {
                    displayLink.isPaused = false
                } else {
                    if let _ = self.selectionScrollActivationTimer {
                    } else {
                        let timer = SwiftSignalKit.Timer(timeout: 0.45, repeat: false, completion: { [weak self] in
                            self?.setupSelectionScrolling()
                        }, queue: .mainQueue())
                        timer.start()
                        self.selectionScrollActivationTimer = timer
                    }
                }
            } else {
                self.selectionScrollDisplayLink?.isPaused = true
                self.selectionScrollActivationTimer?.invalidate()
                self.selectionScrollActivationTimer = nil
            }
        }
    }
    
    private var selectionScrollSkipUpdate = false
    private func setupSelectionScrolling() {
        self.selectionScrollDisplayLink = ConstantDisplayLinkAnimator(update: { [weak self] in
            self?.selectionScrollActivationTimer = nil
            if let strongSelf = self, let delta = strongSelf.selectionScrollDelta {
                let distance: CGFloat = 15.0 * min(1.0, 0.15 + abs(delta * delta))
                let direction: ListViewScrollDirection = delta > 0.0 ? .up : .down
                let _ = strongSelf.scrollWithDirection(direction, distance: distance)
                
                if let location = strongSelf.selectionLastLocation {
                    if !strongSelf.selectionScrollSkipUpdate {
                        strongSelf.handlePanSelection(location: location)
                    }
                    strongSelf.selectionScrollSkipUpdate = !strongSelf.selectionScrollSkipUpdate
                }
            }
        })
        self.selectionScrollDisplayLink?.isPaused = false
    }

    
    func voicePlaylistItemChanged(_ previousItem: SharedMediaPlaylistItem?, _ currentItem: SharedMediaPlaylistItem?) -> Void {
        if let currentItemId = currentItem?.id as? PeerMessagesMediaPlaylistItemId {
            if let source = currentItem?.playbackData?.source, case let .telegramFile(_, _, isViewOnce) = source, isViewOnce {
                self.currentlyPlayingMessageIdPromise.set(.single(nil))
            } else {
                let isVideo = currentItem?.playbackData?.type == .instantVideo
                self.currentlyPlayingMessageIdPromise.set(.single((currentItemId.messageIndex, isVideo)))
            }
        } else {
            self.currentlyPlayingMessageIdPromise.set(.single(nil))
        }
    }
    
    func scrollToMessage(index: MessageIndex) {
        self.appliedScrollToMessageId = nil
        self.scrollToMessageIdPromise.set(.single(index))
    }

    private var currentSendAnimationCorrelationIds: Set<Int64>?
    func setCurrentSendAnimationCorrelationIds(_ value: Set<Int64>?) {
        self.currentSendAnimationCorrelationIds = value
    }
    
    private var currentDeleteAnimationCorrelationIds = Set<UInt32>()
    func setCurrentDeleteAnimationCorrelationIds(_ value: Set<UInt32>) {
        self.currentDeleteAnimationCorrelationIds = value
    }
    private var currentAppliedDeleteAnimationCorrelationIds = Set<UInt32>()

    var animationCorrelationMessagesFound: (([Int64: ChatMessageItemView]) -> Void)?

    final class SnapshotState {
        fileprivate let snapshotTopInset: CGFloat
        fileprivate let snapshotBottomInset: CGFloat
        fileprivate let snapshotView: UIView
        fileprivate let overscrollView: UIView?

        fileprivate init(
            snapshotTopInset: CGFloat,
            snapshotBottomInset: CGFloat,
            snapshotView: UIView,
            overscrollView: UIView?
        ) {
            self.snapshotTopInset = snapshotTopInset
            self.snapshotBottomInset = snapshotBottomInset
            self.snapshotView = snapshotView
            self.overscrollView = overscrollView
        }
    }

    func prepareSnapshotState() -> SnapshotState {
        var snapshotTopInset: CGFloat = 0.0
        var snapshotBottomInset: CGFloat = 0.0
        self.forEachItemNode { itemNode in
            let topOverflow = itemNode.frame.maxY - self.bounds.height
            snapshotTopInset = max(snapshotTopInset, topOverflow)

            if itemNode.frame.minY < 0.0 {
                snapshotBottomInset = max(snapshotBottomInset, -itemNode.frame.minY)
            }
        }

        let snapshotView = self.view//.snapshotView(afterScreenUpdates: false)!
        self.globalIgnoreScrollingEvents = true

        //snapshotView.frame = self.view.bounds
        /*if let sublayers = self.layer.sublayers {
            for sublayer in sublayers {
                sublayer.isHidden = true
            }
        }*/
        //self.view.addSubview(snapshotView)

        let overscrollView = self.overscrollView
        if let overscrollView = overscrollView {
            self.overscrollView = nil

            overscrollView.frame = overscrollView.convert(overscrollView.bounds, to: self.view)
            snapshotView.addSubview(overscrollView)

            if self.rotated {
                overscrollView.layer.sublayerTransform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
            }
        }

        return SnapshotState(
            snapshotTopInset: snapshotTopInset,
            snapshotBottomInset: snapshotBottomInset,
            snapshotView: snapshotView,
            overscrollView: overscrollView
        )
    }

    func animateFromSnapshot(_ snapshotState: SnapshotState, completion: @escaping () -> Void) {
        var snapshotTopInset: CGFloat = 0.0
        var snapshotBottomInset: CGFloat = 0.0
        self.forEachItemNode { itemNode in
            let topOverflow = itemNode.frame.maxY - self.bounds.height
            snapshotTopInset = max(snapshotTopInset, topOverflow)

            if itemNode.frame.minY < 0.0 {
                snapshotBottomInset = max(snapshotBottomInset, -itemNode.frame.minY)
            }
        }

        let snapshotParentView = UIView()
        snapshotParentView.addSubview(snapshotState.snapshotView)
        if self.rotated {
            snapshotParentView.layer.sublayerTransform = CATransform3DMakeRotation(CGFloat(Double.pi), 0.0, 0.0, 1.0)
        }
        snapshotParentView.frame = self.view.frame

        snapshotState.snapshotView.frame = snapshotParentView.bounds
        
        snapshotState.snapshotView.clipsToBounds = true
        if self.rotated {
            snapshotState.snapshotView.layer.sublayerTransform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        }
        
        self.view.superview?.insertSubview(snapshotParentView, belowSubview: self.view)

        snapshotParentView.layer.animatePosition(from: CGPoint(x: 0.0, y: 0.0), to: CGPoint(x: 0.0, y: -self.view.bounds.height - snapshotState.snapshotBottomInset - snapshotTopInset), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { [weak snapshotParentView] _ in
            snapshotParentView?.removeFromSuperview()
            completion()
        })

        self.view.layer.animatePosition(from: CGPoint(x: 0.0, y: self.view.bounds.height + snapshotTopInset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: true, additive: true)
    }
    
    override public func customItemDeleteAnimationDuration(itemNode: ListViewItemNode) -> Double? {
        if !self.currentAppliedDeleteAnimationCorrelationIds.isEmpty {
            if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item {
                for (message, _) in item.content {
                    if self.currentAppliedDeleteAnimationCorrelationIds.contains(message.stableId) {
                        return 0.8
                    }
                }
            }
        }
        return nil
    }
}
