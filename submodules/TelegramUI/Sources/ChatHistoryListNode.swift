import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore
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

extension ChatReplyThreadMessage {
    var effectiveTopId: MessageId {
        return self.channelMessageId ?? self.messageId
    }
}

struct ChatTopVisibleMessageRange: Equatable {
    var lowerBound: MessageIndex
    var upperBound: MessageIndex
    var isLast: Bool
}

private let historyMessageCount: Int = 90

public enum ChatHistoryListDisplayHeaders {
    case none
    case all
    case allButLast
}

public enum ChatHistoryListMode: Equatable {
    case bubbles
    case list(search: Bool, reversed: Bool, displayHeaders: ChatHistoryListDisplayHeaders, hintLinks: Bool, isGlobalSearch: Bool)
}

enum ChatHistoryViewScrollPosition {
    case unread(index: MessageIndex)
    case positionRestoration(index: MessageIndex, relativeOffset: CGFloat)
    case index(index: MessageHistoryAnchorIndex, position: ListViewScrollPosition, directionHint: ListViewScrollToItemDirectionHint, animated: Bool, highlight: Bool)
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
    var scrolledToIndex: MessageHistoryAnchorIndex?
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
    var scrolledToIndex: MessageHistoryAnchorIndex?
    var scrolledToSomeIndex: Bool
    var peerType: MediaAutoDownloadPeerType
    var networkType: MediaAutoDownloadNetworkType
    var animateIn: Bool
    var reason: ChatHistoryViewTransitionReason
    var flashIndicators: Bool
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
            return controllerInteraction.openMessage(message, mode)
        }, openMessageContextMenu: { message, bool, node, rect, gesture in
            controllerInteraction.openMessageContextMenu(message, bool, node, rect, gesture)
        }, toggleMessagesSelection: { messageId, selected in
            controllerInteraction.toggleMessagesSelection(messageId, selected)
        }, openUrl: { url, param1, param2, message in
            controllerInteraction.openUrl(url, param1, param2, message)
        }, openInstantPage: { message, data in
            controllerInteraction.openInstantPage(message, data)
        }, longTap: { action, message in
            controllerInteraction.longTap(action, message)
        }, getHiddenMedia: {
            return controllerInteraction.hiddenMedia
        })
    }
}

private func mappedInsertEntries(context: AccountContext, chatLocation: ChatLocation, associatedData: ChatMessageItemAssociatedData, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, lastHeaderId: Int64, entries: [ChatHistoryViewTransitionInsertEntry]) -> [ListViewInsertItem] {
    return entries.map { entry -> ListViewInsertItem in
        switch entry.entry {
            case let .MessageEntry(message, presentationData, read, location, selection, attributes):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, content: .message(message: message, read: read, selection: selection, attributes: attributes, location: location))
                    case let .list(_, _, displayHeaders, hintLinks, isGlobalSearch):
                        let displayHeader: Bool
                        switch displayHeaders {
                        case .none:
                            displayHeader = false
                        case .all:
                            displayHeader = true
                        case .allButLast:
                            displayHeader = listMessageDateHeaderId(timestamp: message.timestamp) != lastHeaderId
                        }
                        item = ListMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: controllerInteraction), message: message, selection: selection, displayHeader: displayHeader, hintIsLink: hintLinks, isGlobalSearchResult: isGlobalSearch)
                }
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .MessageGroupEntry(_, messages, presentationData):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, content: .group(messages: messages))
                    case .list:
                        assertionFailure()
                        item = ListMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: controllerInteraction), message: messages[0].0, selection: .none, displayHeader: false)
                }
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .UnreadEntry(_, presentationData):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatUnreadItem(index: entry.entry.index, presentationData: presentationData, context: context), directionHint: entry.directionHint)
            case let .ReplyCountEntry(_, isComments, count, presentationData):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatReplyCountItem(index: entry.entry.index, isComments: isComments, count: count, presentationData: presentationData, context: context, controllerInteraction: controllerInteraction), directionHint: entry.directionHint)
            case let .ChatInfoEntry(title, text, photo, presentationData):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatBotInfoItem(title: title, text: text, photo: photo, controllerInteraction: controllerInteraction, presentationData: presentationData, context: context), directionHint: entry.directionHint)
            case let .SearchEntry(theme, strings):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListSearchItem(theme: theme, placeholder: strings.Common_Search, activate: {
                    controllerInteraction.openSearch()
                }), directionHint: entry.directionHint)
        }
    }
}

private func mappedUpdateEntries(context: AccountContext, chatLocation: ChatLocation, associatedData: ChatMessageItemAssociatedData, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, lastHeaderId: Int64, entries: [ChatHistoryViewTransitionUpdateEntry]) -> [ListViewUpdateItem] {
    return entries.map { entry -> ListViewUpdateItem in
        switch entry.entry {
            case let .MessageEntry(message, presentationData, read, location, selection, attributes):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, content: .message(message: message, read: read, selection: selection, attributes: attributes, location: location))
                    case let .list(_, _, displayHeaders, hintLinks, isGlobalSearch):
                        let displayHeader: Bool
                        switch displayHeaders {
                        case .none:
                            displayHeader = false
                        case .all:
                            displayHeader = true
                        case .allButLast:
                            displayHeader = listMessageDateHeaderId(timestamp: message.timestamp) != lastHeaderId
                        }
                        item = ListMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: controllerInteraction), message: message, selection: selection, displayHeader: displayHeader, hintIsLink: hintLinks, isGlobalSearchResult: isGlobalSearch)
                }
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .MessageGroupEntry(_, messages, presentationData):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, content: .group(messages: messages))
                    case .list:
                        assertionFailure()
                        item = ListMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: controllerInteraction), message: messages[0].0, selection: .none, displayHeader: false)
                }
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .UnreadEntry(_, presentationData):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatUnreadItem(index: entry.entry.index, presentationData: presentationData, context: context), directionHint: entry.directionHint)
            case let .ReplyCountEntry(_, isComments, count, presentationData):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatReplyCountItem(index: entry.entry.index, isComments: isComments, count: count, presentationData: presentationData, context: context, controllerInteraction: controllerInteraction), directionHint: entry.directionHint)
            case let .ChatInfoEntry(title, text, photo, presentationData):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatBotInfoItem(title: title, text: text, photo: photo, controllerInteraction: controllerInteraction, presentationData: presentationData, context: context), directionHint: entry.directionHint)
            case let .SearchEntry(theme, strings):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListSearchItem(theme: theme, placeholder: strings.Common_Search, activate: {
                    controllerInteraction.openSearch()
                }), directionHint: entry.directionHint)
        }
    }
}

private func mappedChatHistoryViewListTransition(context: AccountContext, chatLocation: ChatLocation, associatedData: ChatMessageItemAssociatedData, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, lastHeaderId: Int64, transition: ChatHistoryViewTransition) -> ChatHistoryListViewTransition {
    return ChatHistoryListViewTransition(historyView: transition.historyView, deleteItems: transition.deleteItems, insertItems: mappedInsertEntries(context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, mode: mode, lastHeaderId: lastHeaderId, entries: transition.insertEntries), updateItems: mappedUpdateEntries(context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, mode: mode, lastHeaderId: lastHeaderId, entries: transition.updateEntries), options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, initialData: transition.initialData, keyboardButtonsMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData, cachedDataMessages: transition.cachedDataMessages, readStateData: transition.readStateData, scrolledToIndex: transition.scrolledToIndex, scrolledToSomeIndex: transition.scrolledToSomeIndex, peerType: associatedData.automaticDownloadPeerType, networkType: associatedData.automaticDownloadNetworkType, animateIn: transition.animateIn, reason: transition.reason, flashIndicators: transition.flashIndicators)
}

private final class ChatHistoryTransactionOpaqueState {
    let historyView: ChatHistoryView
    
    init(historyView: ChatHistoryView) {
        self.historyView = historyView
    }
}

private func extractAssociatedData(chatLocation: ChatLocation, view: MessageHistoryView, automaticDownloadNetworkType: MediaAutoDownloadNetworkType, animatedEmojiStickers: [String: [StickerPackItem]], additionalAnimatedEmojiStickers: [String: [Int: StickerPackItem]], subject: ChatControllerSubject?, currentlyPlayingMessageId: MessageIndex?, isCopyProtectionEnabled: Bool, availableReactions: AvailableReactions?, defaultReaction: String?) -> ChatMessageItemAssociatedData {
    var automaticMediaDownloadPeerType: MediaAutoDownloadPeerType = .channel
    var contactsPeerIds: Set<PeerId> = Set()
    var channelDiscussionGroup: ChatMessageItemAssociatedData.ChannelDiscussionGroupStatus = .unknown
    if case let .peer(peerId) = chatLocation {
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
    }
    
    return ChatMessageItemAssociatedData(automaticDownloadPeerType: automaticMediaDownloadPeerType, automaticDownloadNetworkType: automaticDownloadNetworkType, isRecentActions: false, subject: subject, contactsPeerIds: contactsPeerIds, channelDiscussionGroup: channelDiscussionGroup, animatedEmojiStickers: animatedEmojiStickers, additionalAnimatedEmojiStickers: additionalAnimatedEmojiStickers, currentlyPlayingMessageId: currentlyPlayingMessageId, isCopyProtectionEnabled: isCopyProtectionEnabled, availableReactions: availableReactions, defaultReaction: defaultReaction)
}

private extension ChatHistoryLocationInput {
    var isAtUpperBound: Bool {
        switch self.content {
        case .Navigation(index: .upperBound, anchorIndex: .upperBound, count: _, highlight: _):
                return true
        case .Scroll(index: .upperBound, anchorIndex: .upperBound, sourceIndex: _, scrollPosition: _, animated: _, highlight: _):
                return true
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

public enum ChatHistoryListSource {
    case `default`
    case custom(messages: Signal<([Message], Int32, Bool), NoError>, messageId: MessageId, loadMore: (() -> Void)?)
}

public final class ChatHistoryListNode: ListView, ChatHistoryNode {
    private let context: AccountContext
    private let chatLocation: ChatLocation
    private let chatLocationContextHolder: Atomic<ChatLocationContextHolder?>
    private let subject: ChatControllerSubject?
    private let tagMask: MessageTags?
    private let controllerInteraction: ChatControllerInteraction
    private let mode: ChatHistoryListMode
    
    private var historyView: ChatHistoryView?
    
    private let historyDisposable = MetaDisposable()
    private let readHistoryDisposable = MetaDisposable()
    
    //private let messageViewQueue = Queue(name: "ChatHistoryListNode processing")
    
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

    private var messageIdsScheduledForMarkAsSeen = Set<MessageId>()
    private var messageIdsWithReactionsScheduledForMarkAsSeen = Set<MessageId>()
    
    private var chatHistoryLocationValue: ChatHistoryLocationInput? {
        didSet {
            if let chatHistoryLocationValue = self.chatHistoryLocationValue, chatHistoryLocationValue != oldValue {
                chatHistoryLocationPromise.set(chatHistoryLocationValue)
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
    
    private let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    
    private let messageProcessingManager = ChatMessageThrottledProcessingManager()
    private let messageWithReactionsProcessingManager = ChatMessageThrottledProcessingManager(submitInterval: 4.0)
    let adSeenProcessingManager = ChatMessageThrottledProcessingManager()
    private let seenLiveLocationProcessingManager = ChatMessageThrottledProcessingManager()
    private let unsupportedMessageProcessingManager = ChatMessageThrottledProcessingManager()
    private let refreshMediaProcessingManager = ChatMessageThrottledProcessingManager()
    private let messageMentionProcessingManager = ChatMessageThrottledProcessingManager(delay: 0.2)
    private let unseenReactionsProcessingManager = ChatMessageThrottledProcessingManager(delay: 0.2, submitInterval: 0.0)
    let prefetchManager: InChatPrefetchManager
    private var currentEarlierPrefetchMessages: [(Message, Media)] = []
    private var currentLaterPrefetchMessages: [(Message, Media)] = []
    private var currentPrefetchDirectionIsToLater: Bool = true
    
    private var maxVisibleMessageIndexReported: MessageIndex?
    var maxVisibleMessageIndexUpdated: ((MessageIndex) -> Void)?
    
    var scrolledToIndex: ((MessageHistoryAnchorIndex, Bool) -> Void)?
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
    
    private let currentlyPlayingMessageIdPromise = ValuePromise<MessageIndex?>(nil)
    private var appliedPlayingMessageId: MessageIndex? = nil
    
    private(set) var isScrollAtBottomPosition = false
    public var isScrollAtBottomPositionUpdated: (() -> Void)?
    
    private var interactiveReadActionDisposable: Disposable?
    private var interactiveReadReactionsDisposable: Disposable?
    private var displayUnseenReactionAnimationsTimestamps: [MessageId: Double] = [:]
    
    public var contentPositionChanged: (ListViewVisibleContentOffset) -> Void = { _ in }
    
    public private(set) var loadState: ChatHistoryNodeLoadState?
    private var loadStateUpdated: ((ChatHistoryNodeLoadState, Bool) -> Void)?
    
    private var loadedMessagesFromCachedDataDisposable: Disposable?
    
    let isTopReplyThreadMessageShown = ValuePromise<Bool>(false, ignoreRepeated: true)
    let topVisibleMessageRange = ValuePromise<ChatTopVisibleMessageRange?>(nil, ignoreRepeated: true)
    
    var isSelectionGestureEnabled = true

    private var overscrollView: ComponentHostView<Empty>?
    var nextChannelToRead: (peer: EnginePeer, unreadCount: Int, location: TelegramEngine.NextUnreadChannelLocation)?
    var offerNextChannelToRead: Bool = false
    var nextChannelToReadDisplayName: Bool = false
    private var currentOverscrollExpandProgress: CGFloat = 0.0
    private var freezeOverscrollControl: Bool = false
    private var freezeOverscrollControlProgress: Bool = false
    private var feedback: HapticFeedback?
    var openNextChannelToRead: ((EnginePeer, TelegramEngine.NextUnreadChannelLocation) -> Void)?
    private var contentInsetAnimator: DisplayLinkAnimator?

    private let adMessagesContext: AdMessagesHistoryContext?
    private var preloadAdPeerId: PeerId?
    private let preloadAdPeerDisposable = MetaDisposable()
    
    private var refreshDisplayedItemRangeTimer: SwiftSignalKit.Timer?
    
    private var visibleMessageRange = Atomic<VisibleMessageRange?>(value: nil)
    
    private let clientId: Atomic<Int32>
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>), chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>, tagMask: MessageTags?, source: ChatHistoryListSource = .default, subject: ChatControllerSubject?, controllerInteraction: ChatControllerInteraction, selectedMessages: Signal<Set<MessageId>?, NoError>, mode: ChatHistoryListMode = .bubbles, messageTransitionNode: @escaping () -> ChatMessageTransitionNode? = { nil }) {
        var tagMask = tagMask
        var appendMessagesFromTheSameGroup = false
        if case .pinnedMessages = subject {
            tagMask = .pinned
            appendMessagesFromTheSameGroup = true
        }
        
        self.context = context
        self.chatLocation = chatLocation
        self.chatLocationContextHolder = chatLocationContextHolder
        self.subject = subject
        self.tagMask = tagMask
        self.controllerInteraction = controllerInteraction
        self.mode = mode
        
        let presentationData = updatedPresentationData.initial
        self.currentPresentationData = ChatPresentationData(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper), fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true, largeEmoji: presentationData.largeEmoji, chatBubbleCorners: presentationData.chatBubbleCorners, animatedEmojiScale: 1.0)
        
        self.chatPresentationDataPromise = Promise()
        
        self.prefetchManager = InChatPrefetchManager(context: context)

        var displayAdPeer: PeerId?
        //var sparseScrollPeerId: PeerId?
        switch subject {
        case .none, .message:
            if case let .peer(peerId) = chatLocation {
                displayAdPeer = peerId
                //sparseScrollPeerId = peerId
            }
        default:
            break
        }
        var adMessages: Signal<[Message], NoError>
        if case .bubbles = mode, let peerId = displayAdPeer {
            let adMessagesContext = context.engine.messages.adMessages(peerId: peerId)
            self.adMessagesContext = adMessagesContext
            adMessages = adMessagesContext.state
        } else {
            self.adMessagesContext = nil
            adMessages = .single([])
        }

        /*if case .bubbles = mode, let peerId = sparseScrollPeerId {
            self.sparseScrollingContext = context.engine.messages.sparseMessageScrollingContext(peerId: peerId)
        } else {
            self.sparseScrollingContext = nil
        }*/
        
        let clientId = Atomic<Int32>(value: nextClientId)
        self.clientId = clientId
        nextClientId += 1
        
        super.init()

        adMessages = adMessages
        |> afterNext { [weak self] messages in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                var adPeerId: PeerId?
                adPeerId = messages.first?.author?.id

                if strongSelf.preloadAdPeerId != adPeerId {
                    strongSelf.preloadAdPeerId = adPeerId
                    if let adPeerId = adPeerId {
                        let combinedDisposable = DisposableSet()
                        strongSelf.preloadAdPeerDisposable.set(combinedDisposable)
                        combinedDisposable.add(strongSelf.context.account.viewTracker.polledChannel(peerId: adPeerId).start())
                        combinedDisposable.add(strongSelf.context.account.addAdditionalPreloadHistoryPeerId(peerId: adPeerId))
                    } else {
                        strongSelf.preloadAdPeerDisposable.set(nil)
                    }
                }
            }
        }

        self.clipsToBounds = false
        
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
            context?.account.viewTracker.updateViewCountForMessageIds(messageIds: messageIds, clientId: clientId.with { $0 })
        }
        self.messageWithReactionsProcessingManager.process = { [weak context] messageIds in
            context?.account.viewTracker.updateReactionsForMessageIds(messageIds: messageIds)
        }
        self.adSeenProcessingManager.process = { [weak self] messageIds in
            guard let strongSelf = self, let adMessagesContext = strongSelf.adMessagesContext else {
                return
            }
            for id in messageIds {
                if let message = strongSelf.messageInCurrentHistoryView(id), let adAttribute = message.adAttribute {
                    adMessagesContext.markAsSeen(opaqueId: adAttribute.opaqueId)
                }
            }
        }
        self.seenLiveLocationProcessingManager.process = { [weak context] messageIds in
            context?.account.viewTracker.updateSeenLiveLocationForMessageIds(messageIds: messageIds)
        }
        self.unsupportedMessageProcessingManager.process = { [weak context] messageIds in
            context?.account.viewTracker.updateUnsupportedMediaForMessageIds(messageIds: messageIds)
        }
        self.refreshMediaProcessingManager.process = { [weak context] messageIds in
            context?.account.viewTracker.refreshSecretMediaMediaForMessageIds(messageIds: messageIds)
        }
        
        self.messageMentionProcessingManager.process = { [weak self, weak context] messageIds in
            if let strongSelf = self {
                if strongSelf.canReadHistoryValue {
                    context?.account.viewTracker.updateMarkMentionsSeenForMessageIds(messageIds: messageIds)
                } else {
                    strongSelf.messageIdsScheduledForMarkAsSeen.formUnion(messageIds)
                }
            }
        }
        
        self.unseenReactionsProcessingManager.process = { [weak self] messageIds in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.canReadHistoryValue && !strongSelf.context.sharedContext.immediateExperimentalUISettings.skipReadHistory {
                strongSelf.context.account.viewTracker.updateMarkReactionsSeenForMessageIds(messageIds: messageIds)
            } else {
                strongSelf.messageIdsWithReactionsScheduledForMarkAsSeen.formUnion(messageIds)
            }
        }
        
        self.preloadPages = false
        switch self.mode {
            case .bubbles:
                self.transform = CATransform3DMakeRotation(CGFloat(Double.pi), 0.0, 0.0, 1.0)
            case .list:
                break
        }
        //self.snapToBottomInsetUntilFirstInteraction = true
        
        let messageViewQueue = Queue.mainQueue() //self.messageViewQueue
        
        let fixedCombinedReadStates = Atomic<MessageHistoryViewReadState?>(value: nil)
        
        var isScheduledMessages = false
        if let subject = subject, case .scheduledMessages = subject {
            isScheduledMessages = true
        }
        var isAuxiliaryChat = isScheduledMessages
        if case .replyThread = chatLocation {
            isAuxiliaryChat = true
        }
        
        var additionalData: [AdditionalMessageHistoryViewData] = []
        if case let .peer(peerId) = chatLocation {
            additionalData.append(.cachedPeerData(peerId))
            additionalData.append(.cachedPeerDataMessages(peerId))
            additionalData.append(.peerNotificationSettings(peerId))
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                additionalData.append(.cacheEntry(cachedChannelAdminRanksEntryId(peerId: peerId)))
            }
            if [Namespaces.Peer.CloudChannel, Namespaces.Peer.CloudGroup].contains(peerId.namespace) {
                additionalData.append(.peer(peerId))
            }
            if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.SecretChat {
                additionalData.append(.peerIsContact(peerId))
            }
        }
        if !isAuxiliaryChat {
            additionalData.append(.totalUnreadState)
        }
        if case let .replyThread(replyThreadMessage) = chatLocation {
            additionalData.append(.cachedPeerData(replyThreadMessage.messageId.peerId))
            additionalData.append(.peerNotificationSettings(replyThreadMessage.messageId.peerId))
            if replyThreadMessage.messageId.peerId.namespace == Namespaces.Peer.CloudChannel {
                additionalData.append(.cacheEntry(cachedChannelAdminRanksEntryId(peerId: replyThreadMessage.messageId.peerId)))
                additionalData.append(.peer(replyThreadMessage.messageId.peerId))
            }
            
            additionalData.append(.message(replyThreadMessage.effectiveTopId))
        }

        let currentViewVersion = Atomic<Int?>(value: nil)
        
        let historyViewUpdate: Signal<(ChatHistoryViewUpdate, Int, ChatHistoryLocationInput?, ClosedRange<Int32>?), NoError>
        var isFirstTime = true
        var updateAllOnEachVersion = false
        if case let .custom(messages, at, _) = source {
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
                    scrollPosition = .index(index: .message(messageIndex), position: .center(.bottom), directionHint: .Down, animated: false, highlight: false)
                    isFirstTime = false
                } else {
                    scrollPosition = nil
                }
                
                return (ChatHistoryViewUpdate.HistoryView(view: MessageHistoryView(tagMask: nil, namespaces: .all, entries: messages.reversed().map { MessageHistoryEntry(message: $0, isRead: false, location: nil, monthLocation: nil, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false)) }, holeEarlier: hasMore, holeLater: false, isLoading: false), type: .Generic(type: version > 0 ? ViewUpdateType.Generic : ViewUpdateType.Initial), scrollPosition: scrollPosition, flashIndicators: false, originalScrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: nil, buttonKeyboardMessage: nil, cachedData: nil, cachedDataMessages: nil, readStateData: nil), id: 0), version, nil, nil)
            }
        } else {
            historyViewUpdate = combineLatest(queue: .mainQueue(),
                self.chatHistoryLocationPromise.get(),
                self.ignoreMessagesInTimestampRangePromise.get()
            )
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                if lhs.0 != rhs.0 {
                    return false
                }
                if lhs.1 != rhs.1 {
                    return false
                }
                return true
            })
            |> mapToSignal { location, ignoreMessagesInTimestampRange in
                return chatHistoryViewForLocation(location, ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, context: context, chatLocation: chatLocation, chatLocationContextHolder: chatLocationContextHolder, scheduled: isScheduledMessages, fixedCombinedReadStates: fixedCombinedReadStates.with { $0 }, tagMask: tagMask, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, additionalData: additionalData, orderStatistics: [])
                |> beforeNext { viewUpdate in
                    switch viewUpdate {
                        case let .HistoryView(view, _, _, _, _, _, _):
                            let _ = fixedCombinedReadStates.swap(view.fixedReadStates)
                        default:
                            break
                    }
                }
                |> map { view -> (ChatHistoryViewUpdate, Int, ChatHistoryLocationInput?, ClosedRange<Int32>?) in
                    let version = currentViewVersion.modify({ value in
                        if let value = value {
                            return value + 1
                        } else {
                            return 0
                        }
                    })!
                    return (view, version, location, ignoreMessagesInTimestampRange)
                }
            }
        }
        
        let previousView = Atomic<(ChatHistoryView, Int, Set<MessageId>?)?>(value: nil)
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
                
        let animatedEmojiStickers = context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
        |> map { animatedEmoji -> [String: [StickerPackItem]] in
            var animatedEmojiStickers: [String: [StickerPackItem]] = [:]
            switch animatedEmoji {
                case let .result(_, items, _):
                    for item in items {
                        if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                            animatedEmojiStickers[emoji.basicEmoji.0] = [item]
                            let strippedEmoji = emoji.basicEmoji.0.strippedEmoji
                            if animatedEmojiStickers[strippedEmoji] == nil {
                                animatedEmojiStickers[strippedEmoji] = [item]
                            }
                        }
                    }
                default:
                    break
            }
            return animatedEmojiStickers
        }
        
        let additionalAnimatedEmojiStickers = context.engine.stickers.loadedStickerPack(reference: .animatedEmojiAnimations, forceActualized: false)
        |> map { animatedEmoji -> [String: [Int: StickerPackItem]] in
            let sequence = "0️⃣1️⃣2️⃣3️⃣4️⃣5️⃣6️⃣7️⃣8️⃣9️⃣".strippedEmoji
            var animatedEmojiStickers: [String: [Int: StickerPackItem]] = [:]
            switch animatedEmoji {
                case let .result(_, items, _):
                    for item in items {
                        let indexKeys = item.getStringRepresentationsOfIndexKeys()
                        if indexKeys.count > 1, let first = indexKeys.first, let last = indexKeys.last {
                            let emoji: String?
                            let indexEmoji: String?
                            if sequence.contains(first.strippedEmoji) {
                                emoji = last
                                indexEmoji = first
                            } else if sequence.contains(last.strippedEmoji) {
                                emoji = first
                                indexEmoji = last
                            } else {
                                emoji = nil
                                indexEmoji = nil
                            }
                            
                            if let emoji = emoji?.strippedEmoji, let indexEmoji = indexEmoji?.strippedEmoji.first, let strIndex = sequence.firstIndex(of: indexEmoji) {
                                let index = sequence.distance(from: sequence.startIndex, to: strIndex)
                                if animatedEmojiStickers[emoji] != nil {
                                    animatedEmojiStickers[emoji]![index] = item
                                } else {
                                    animatedEmojiStickers[emoji] = [index: item]
                                }
                            }
                        }
                    }
                default:
                    break
            }
            return animatedEmojiStickers
        }
        
        let previousHistoryAppearsCleared = Atomic<Bool?>(value: nil)
                
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
            let cachedDataKey = PostboxViewKey.cachedPeerData(peerId: peerId)
            let peerKey = PostboxViewKey.basicPeer(peerId)
            customChannelDiscussionReadState = context.account.postbox.combinedView(keys: [cachedDataKey, peerKey])
            |> mapToSignal { views -> Signal<PeerId?, NoError> in
                guard let view = views.views[cachedDataKey] as? CachedPeerDataView else {
                    return .single(nil)
                }
                guard let peer = (views.views[peerKey] as? BasicPeerView)?.peer as? TelegramChannel, case .broadcast = peer.info else {
                    return .single(nil)
                }
                guard let cachedData = view.cachedPeerData as? CachedChannelData else {
                    return .single(nil)
                }
                guard case let .known(value) = cachedData.linkedDiscussionPeerId else {
                    return .single(nil)
                }
                return .single(value)
            }
            |> distinctUntilChanged
            |> mapToSignal { discussionPeerId -> Signal<MessageId?, NoError> in
                guard let discussionPeerId = discussionPeerId else {
                    return .single(nil)
                }
                let key = PostboxViewKey.combinedReadState(peerId: discussionPeerId)
                return context.account.postbox.combinedView(keys: [key])
                |> map { views -> MessageId? in
                    guard let view = views.views[key] as? CombinedReadStateView else {
                        return nil
                    }
                    guard let state = view.state else {
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
        
        let availableReactions = context.engine.stickers.availableReactions()
        
        let defaultReaction = context.account.postbox.preferencesView(keys: [PreferencesKeys.reactionSettings])
        |> map { preferencesView -> String? in
            let reactionSettings: ReactionSettings
            if let entry = preferencesView.values[PreferencesKeys.reactionSettings], let value = entry.get(ReactionSettings.self) {
                reactionSettings = value
            } else {
                reactionSettings = .default
            }
            return reactionSettings.quickReaction
        }
        |> distinctUntilChanged
        
        let historyViewTransitionDisposable = combineLatest(queue: messageViewQueue,
            historyViewUpdate,
            self.chatPresentationDataPromise.get(),
            selectedMessages,
            updatingMedia,
            automaticDownloadNetworkType,
            self.historyAppearsClearedPromise.get(),
            self.pendingUnpinnedAllMessagesPromise.get(),
            self.pendingRemovedMessagesPromise.get(),
            animatedEmojiStickers,
            additionalAnimatedEmojiStickers,
            customChannelDiscussionReadState,
            customThreadOutgoingReadState,
            self.currentlyPlayingMessageIdPromise.get(),
            adMessages,
            availableReactions,
            defaultReaction
        ).start(next: { [weak self] update, chatPresentationData, selectedMessages, updatingMedia, networkType, historyAppearsCleared, pendingUnpinnedAllMessages, pendingRemovedMessages, animatedEmojiStickers, additionalAnimatedEmojiStickers, customChannelDiscussionReadState, customThreadOutgoingReadState, currentlyPlayingMessageId, adMessages, availableReactions, defaultReaction in
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
                            if let subject = subject, case let .message(messageSubject, highlight, _) = subject {
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
                                strongSelf.chatHistoryLocationValue = ChatHistoryLocationInput(content: .InitialSearch(location: initialSearchLocation, count: 60, highlight: highlight), id: (strongSelf.chatHistoryLocationValue?.id).flatMap({ $0 + 1 }) ?? 0)
                            } else if let subject = subject, case let .pinnedMessages(maybeMessageId) = subject, let messageId = maybeMessageId {
                                strongSelf.chatHistoryLocationValue = ChatHistoryLocationInput(content: .InitialSearch(location: .id(messageId), count: 60, highlight: true), id: (strongSelf.chatHistoryLocationValue?.id).flatMap({ $0 + 1 }) ?? 0)
                            } else if var chatHistoryLocation = strongSelf.chatHistoryLocationValue {
                                chatHistoryLocation.id += 1
                                strongSelf.chatHistoryLocationValue = chatHistoryLocation
                            } else {
                                strongSelf.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Initial(count: 60), id: (strongSelf.chatHistoryLocationValue?.id).flatMap({ $0 + 1 }) ?? 0)
                            }
                        }
                    }
                }
            }
            
            let initialData: ChatHistoryCombinedInitialData?
            switch update.0 {
            case let .Loading(combinedInitialData, type):
                if case .Generic(.FillHole) = type {
                    applyHole()
                    return
                }
                
                initialData = combinedInitialData
                Queue.mainQueue().async {
                    if let strongSelf = self {
                        if !strongSelf.didSetInitialData {
                            strongSelf.didSetInitialData = true
                            var combinedInitialData = combinedInitialData
                            combinedInitialData?.cachedData = nil
                            strongSelf._initialData.set(.single(combinedInitialData))
                        }
                        
                        let cachedData = initialData?.cachedData
                        let cachedDataMessages = initialData?.cachedDataMessages
                        
                        strongSelf._cachedPeerDataAndMessages.set(.single((cachedData, cachedDataMessages)))
                        
                        let loadState: ChatHistoryNodeLoadState = .loading
                        if strongSelf.loadState != loadState {
                            strongSelf.loadState = loadState
                            strongSelf.loadStateUpdated?(loadState, false)
                        }
                        
                        let historyState: ChatHistoryNodeHistoryState = .loading
                        if strongSelf.currentHistoryState != historyState {
                            strongSelf.currentHistoryState = historyState
                            strongSelf.historyState.set(historyState)
                        }
                    }
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
                var includeSearchEntry = false
                if case let .list(search, reverseValue, _, _, _) = mode {
                    includeSearchEntry = search
                    reverse = reverseValue
                }
                
                var isCopyProtectionEnabled: Bool =  data.initialData?.peer?.isCopyProtectionEnabled ?? false
                for entry in view.additionalData {
                    if case let .peer(_, maybePeer) = entry, let peer = maybePeer {
                        isCopyProtectionEnabled = peer.isCopyProtectionEnabled
                    }
                }
                let associatedData = extractAssociatedData(chatLocation: chatLocation, view: view, automaticDownloadNetworkType: networkType, animatedEmojiStickers: animatedEmojiStickers, additionalAnimatedEmojiStickers: additionalAnimatedEmojiStickers, subject: subject, currentlyPlayingMessageId: currentlyPlayingMessageId, isCopyProtectionEnabled: isCopyProtectionEnabled, availableReactions: availableReactions, defaultReaction: defaultReaction)
                
                let filteredEntries = chatHistoryEntriesForView(
                    location: chatLocation,
                    view: view,
                    includeUnreadEntry: mode == .bubbles,
                    includeEmptyEntry: mode == .bubbles && tagMask == nil,
                    includeChatInfoEntry: mode == .bubbles,
                    includeSearchEntry: includeSearchEntry && tagMask != nil,
                    reverse: reverse,
                    groupMessages: mode == .bubbles,
                    selectedMessages: selectedMessages,
                    presentationData: chatPresentationData,
                    historyAppearsCleared: historyAppearsCleared,
                    pendingUnpinnedAllMessages: pendingUnpinnedAllMessages,
                    pendingRemovedMessages: pendingRemovedMessages,
                    associatedData: associatedData,
                    updatingMedia: updatingMedia,
                    customChannelDiscussionReadState: customChannelDiscussionReadState,
                    customThreadOutgoingReadState: customThreadOutgoingReadState,
                    cachedData: data.cachedData,
                    adMessages: adMessages
                )
                let lastHeaderId = filteredEntries.last.flatMap { listMessageDateHeaderId(timestamp: $0.index.timestamp) } ?? 0
                let processedView = ChatHistoryView(originalView: view, filteredEntries: filteredEntries, associatedData: associatedData, lastHeaderId: lastHeaderId, id: id, locationInput: update.2, ignoreMessagesInTimestampRange: update.3)
                let previousValueAndVersion = previousView.swap((processedView, update.1, selectedMessages))
                let previous = previousValueAndVersion?.0
                let previousSelectedMessages = previousValueAndVersion?.2
                
                if let previousVersion = previousValueAndVersion?.1 {
                    if !GlobalExperimentalSettings.isAppStoreBuild {
                        precondition(update.1 >= previousVersion)
                    }
                    assert(update.1 >= previousVersion)
                }
                                
                if scrollPosition == nil, let originalScrollPosition = originalScrollPosition {
                    switch originalScrollPosition {
                    case let .index(index, position, _, _, highlight):
                        if case .upperBound = index {
                            if let previous = previous, previous.filteredEntries.isEmpty {
                                updatedScrollPosition = .index(index: index, position: position, directionHint: .Down, animated: false, highlight: highlight)
                            }
                        }
                    default:
                        break
                    }
                }
                
                let reason: ChatHistoryViewTransitionReason
                
                let previousHistoryAppearsClearedValue = previousHistoryAppearsCleared.swap(historyAppearsCleared)
                if previousHistoryAppearsClearedValue != nil && previousHistoryAppearsClearedValue != historyAppearsCleared && !historyAppearsCleared {
                    reason = ChatHistoryViewTransitionReason.Initial(fadeIn: !processedView.filteredEntries.isEmpty)
                } else if let previous = previous, previous.id == processedView.id, previous.originalView.entries == processedView.originalView.entries {
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
                
                var scrollAnimationCurve: ListViewAnimationCurve? = nil
                if let strongSelf = self, case .default = source {
                    if strongSelf.appliedPlayingMessageId != currentlyPlayingMessageId, let currentlyPlayingMessageId = currentlyPlayingMessageId  {
                        if isFirstTime {
                        } else if case let .peer(peerId) = chatLocation, currentlyPlayingMessageId.id.peerId != peerId {
                        } else {
                            updatedScrollPosition = .index(index: .message(currentlyPlayingMessageId), position: .center(.bottom), directionHint: .Up, animated: true, highlight: true)
                            scrollAnimationCurve = .Spring(duration: 0.4)
                        }
                    }
                    isFirstTime = false
                }

                var disableAnimations = false

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
                        updatedScrollPosition = .index(index: .message(firstNonAdIndex), position: .top(0.0), directionHint: .Up, animated: false, highlight: false)
                        disableAnimations = true
                    }
                }
                
                let rawTransition = preparedChatHistoryViewTransition(from: previous, to: processedView, reason: reason, reverse: reverse, chatLocation: chatLocation, controllerInteraction: controllerInteraction, scrollPosition: updatedScrollPosition, scrollAnimationCurve: scrollAnimationCurve, initialData: initialData?.initialData, keyboardButtonsMessage: view.topTaggedMessages.first, cachedData: initialData?.cachedData, cachedDataMessages: initialData?.cachedDataMessages, readStateData: initialData?.readStateData, flashIndicators: flashIndicators, updatedMessageSelection: previousSelectedMessages != selectedMessages, messageTransitionNode: messageTransitionNode(), allUpdated: updateAllOnEachVersion)
                var mappedTransition = mappedChatHistoryViewListTransition(context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, mode: mode, lastHeaderId: lastHeaderId, transition: rawTransition)
                
                if disableAnimations {
                    mappedTransition.options.remove(.AnimateInsertion)
                    mappedTransition.options.remove(.AnimateAlpha)
                    mappedTransition.options.remove(.AnimateTopItemPosition)
                    mappedTransition.options.remove(.RequestItemInsertionAnimations)
                }
                Queue.mainQueue().async {
                    guard let strongSelf = self else {
                        return
                    }
                    if strongSelf.appliedPlayingMessageId != currentlyPlayingMessageId {
                        strongSelf.appliedPlayingMessageId = currentlyPlayingMessageId
                    }
                    strongSelf.enqueueHistoryViewTransition(mappedTransition)
                }
            }
        })
        
        self.historyDisposable.set(historyViewTransitionDisposable)
        
        let previousMaxIncomingMessageIndexByNamespace = Atomic<[MessageId.Namespace: MessageIndex]>(value: [:])
        let readHistory = combineLatest(self.maxVisibleIncomingMessageIndex.get(), self.canReadHistory.get())
        |> map { messageIndex, canRead in
            if canRead {
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
                    switch chatLocation {
                    case .peer, .replyThread, .feed:
                        if !context.sharedContext.immediateExperimentalUISettings.skipReadHistory {
                            context.applyMaxReadIndex(for: chatLocation, contextHolder: chatLocationContextHolder, messageIndex: messageIndex)
                        }
                    }
                }
            }
        }
        
        self.readHistoryDisposable.set(readHistory.start())
        
        self.canReadHistoryDisposable = (self.canReadHistory.get() |> deliverOnMainQueue).start(next: { [weak self, weak context] value in
            if let strongSelf = self {
                if strongSelf.canReadHistoryValue != value {
                    strongSelf.canReadHistoryValue = value
                    strongSelf.updateReadHistoryActions()

                    if strongSelf.canReadHistoryValue && !strongSelf.messageIdsScheduledForMarkAsSeen.isEmpty {
                        let messageIds = strongSelf.messageIdsScheduledForMarkAsSeen
                        strongSelf.messageIdsScheduledForMarkAsSeen.removeAll()
                        context?.account.viewTracker.updateMarkMentionsSeenForMessageIds(messageIds: messageIds)
                    }
                    
                    if strongSelf.canReadHistoryValue && !strongSelf.context.sharedContext.immediateExperimentalUISettings.skipReadHistory && !strongSelf.messageIdsWithReactionsScheduledForMarkAsSeen.isEmpty {
                        let messageIds = strongSelf.messageIdsWithReactionsScheduledForMarkAsSeen
                        
                        let _ = strongSelf.displayUnseenReactionAnimations(messageIds: Array(messageIds))
                        
                        strongSelf.messageIdsWithReactionsScheduledForMarkAsSeen.removeAll()
                        context?.account.viewTracker.updateMarkReactionsSeenForMessageIds(messageIds: messageIds)
                    }
                }
            }
        })
        
        if let subject = subject, case let .message(messageSubject, highlight, _) = subject {
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
            self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .InitialSearch(location: initialSearchLocation, count: 60, highlight: highlight), id: 0)
        } else if let subject = subject, case let .pinnedMessages(maybeMessageId) = subject, let messageId = maybeMessageId {
            self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .InitialSearch(location: .id(messageId), count: 60, highlight: true), id: 0)
        } else {
            self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Initial(count: 60), id: 0)
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
        
        let appConfiguration = context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
        |> take(1)
        |> map { view in
            return view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? .defaultValue
        }
        
        var didSetPresentationData = false
        self.presentationDataDisposable = (
            combineLatest(queue: .mainQueue(),
                updatedPresentationData.signal,
                appConfiguration)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData, appConfiguration in
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
                        if let dateNode = itemHeaderNode as? ChatMessageDateHeaderNode {
                            dateNode.updatePresentationData(chatPresentationData, context: context)
                        } else if let avatarNode = itemHeaderNode as? ChatMessageAvatarHeaderNode {
                            avatarNode.updatePresentationData(chatPresentationData, context: context)
                        } else if let dateNode = itemHeaderNode as? ListMessageDateHeaderNode {
                            dateNode.updateThemeAndStrings(theme: presentationData.theme, strings: presentationData.strings)
                        }
                    }
                    strongSelf.chatPresentationDataPromise.set(.single(chatPresentationData))
                }
            }
        })
        
        self.visibleContentOffsetChanged = { [weak self] offset in
            if let strongSelf = self {
                strongSelf.contentPositionChanged(offset)
                
                if strongSelf.tagMask == nil {
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
            }
        }
        
        self.loadedMessagesFromCachedDataDisposable = (self._cachedPeerDataAndMessages.get() |> map { dataAndMessages -> MessageId? in
            return dataAndMessages.0?.messageIds.first
        } |> distinctUntilChanged(isEqual: { $0 == $1 })
        |> mapToSignal { messageId -> Signal<Void, NoError> in
            if let messageId = messageId {
                return context.engine.messages.getMessagesLoadIfNecessary([messageId]) |> map { _ -> Void in return Void() }
            } else {
                return .complete()
            }
        }).start()
        
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
                    strongSelf.openNextChannelToRead?(nextChannelToRead.peer, nextChannelToRead.location)
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
    }
    
    deinit {
        self.historyDisposable.dispose()
        self.readHistoryDisposable.dispose()
        self.interactiveReadActionDisposable?.dispose()
        self.interactiveReadReactionsDisposable?.dispose()
        self.canReadHistoryDisposable?.dispose()
        self.loadedMessagesFromCachedDataDisposable?.dispose()
        self.preloadAdPeerDisposable.dispose()
        self.refreshDisplayedItemRangeTimer?.invalidate()
    }
    
    public func setLoadStateUpdated(_ f: @escaping (ChatHistoryNodeLoadState, Bool) -> Void) {
        self.loadStateUpdated = f
    }

    /*private func updateHistoryScrollingArea(transition: ContainedViewLayoutTransition) {
        guard let historyScrollingArea = self.historyScrollingArea else {
            return
        }
        guard let transactionState = self.opaqueTransactionState as? ChatHistoryTransactionOpaqueState else {
            return
        }

        let historyView = transactionState.historyView

        var updatedScrollingState = self.scrollingState
        if var scrollingState = updatedScrollingState {
            let convertedIndex = historyView.filteredEntries.count - scrollingState.topItem.index - 1
            if convertedIndex < 0 || convertedIndex >= historyView.filteredEntries.count {
                return
            }
            let firstItem = historyView.filteredEntries[convertedIndex]
            var location: MessageHistoryEntryLocation?
            switch firstItem {
            case let .MessageEntry(_, _, _, locationValue, _, _):
                location = locationValue
            case let .MessageGroupEntry(_, group, _):
                if let locationValue = group.last?.4 {
                    location = locationValue
                }
            default:
                break
            }

            if let location = location {
                let locationDelta = (location.count - location.index - 1) - scrollingState.topItem.index
                scrollingState.topItem.index += locationDelta
                scrollingState.bottomItem.index += locationDelta
                scrollingState.itemCount = max(scrollingState.itemCount, location.count)
            }

            updatedScrollingState = scrollingState
        }

        historyScrollingArea.update(
            containerSize: self.bounds.size,
            containerInsets: UIEdgeInsets(top: self.scrollIndicatorInsets.top, left: 0.0, bottom: self.scrollIndicatorInsets.bottom, right: 0.0),
            scrollingState: updatedScrollingState,
            isScrolling: self.isDragging || self.isDeceleratingAfterTracking,
            theme: self.currentPresentationData.theme.theme,
            transition: transition
        )
    }

    private func navigateToAbsolutePosition(position: Float) {
        guard let transactionState = self.opaqueTransactionState as? ChatHistoryTransactionOpaqueState else {
            return
        }

        let historyView = transactionState.historyView

        let convertedIndex = 0
        if convertedIndex < 0 || convertedIndex >= historyView.filteredEntries.count {
            self.historyScrollingArea?.resetNavigatingToPosition()
            return
        }
        let firstItem = historyView.filteredEntries[convertedIndex]
        var location: MessageHistoryEntryLocation?
        switch firstItem {
        case let .MessageEntry(_, _, _, locationValue, _, _):
            location = locationValue
        case let .MessageGroupEntry(_, group, _):
            if let locationValue = group.last?.4 {
                location = locationValue
            }
        default:
            break
        }

        if let location = location {
            var absoluteIndex = Int(Float(location.count) * position)
            if absoluteIndex >= location.count {
                absoluteIndex = location.count - 1
            }
            if absoluteIndex < 0 {
                absoluteIndex = 0
            }
            if case let .peer(peerId) = self.chatLocation {
                let _ = (self.context.account.postbox.transaction { transaction -> MessageIndex? in
                    return transaction.findMessageAtAbsoluteIndex(peerId: peerId, namespace: Namespaces.Message.Cloud, index: absoluteIndex)
                }
                |> deliverOnMainQueue).start(next: { [weak self] index in
                    guard let strongSelf = self else {
                        return
                    }
                    if let index = index {
                        let content: ChatHistoryLocation = .Scroll(index: .message(index), anchorIndex: .message(index), sourceIndex: .message(index), scrollPosition: .top(0.0), animated: false, highlight: false)

                        strongSelf.scrollNavigationDisposable.set((preloadedChatHistoryViewForLocation(ChatHistoryLocationInput(content: content, id: 0), context: strongSelf.context, chatLocation: strongSelf.chatLocation, subject: strongSelf.subject, chatLocationContextHolder: strongSelf.chatLocationContextHolder, fixedCombinedReadStates: nil, tagMask: nil, additionalData: [])
                        |> map { historyView -> Bool in
                            switch historyView {
                            case .Loading:
                                return false
                            case .HistoryView:
                                return true
                            }
                        }
                        |> filter { $0 }
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { _ in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.chatHistoryLocationValue = ChatHistoryLocationInput(content: content, id: (strongSelf.chatHistoryLocationValue?.id).flatMap({ $0 + 1 }) ?? 0)
                            Queue.mainQueue().after(0.5, {
                                self?.historyScrollingArea?.resetNavigatingToPosition()
                            })
                        }))
                    } else {
                        strongSelf.historyScrollingArea?.resetNavigatingToPosition()
                    }
                })
            }
        } else {
            self.historyScrollingArea?.resetNavigatingToPosition()
        }
    }*/

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
                let swipeText: (String, [(Int, NSRange)])
                let releaseText: (String, [(Int, NSRange)])
                switch nextChannelToRead.location {
                case .same:
                    swipeText = (self.currentPresentationData.strings.Chat_NextChannelSameLocationSwipeProgress, [])
                    releaseText = (self.currentPresentationData.strings.Chat_NextChannelSameLocationSwipeAction, [])
                case .archived:
                    swipeText = (self.currentPresentationData.strings.Chat_NextChannelArchivedSwipeProgress, [])
                    releaseText = (self.currentPresentationData.strings.Chat_NextChannelArchivedSwipeAction, [])
                case .unarchived:
                    swipeText = (self.currentPresentationData.strings.Chat_NextChannelUnarchivedSwipeProgress, [])
                    releaseText = (self.currentPresentationData.strings.Chat_NextChannelUnarchivedSwipeAction, [])
                case let .folder(_, title):
                    swipeText = self.currentPresentationData.strings.Chat_NextChannelFolderSwipeProgress(title)._tuple
                    releaseText = self.currentPresentationData.strings.Chat_NextChannelFolderSwipeAction(title)._tuple
                }

                if expandProgress < 0.1 {
                    chatControllerNode.setChatInputPanelOverscrollNode(overscrollNode: nil)
                } else if expandProgress >= 1.0 {
                    if chatControllerNode.inputPanelOverscrollNode?.text.0 != releaseText.0 {
                        chatControllerNode.setChatInputPanelOverscrollNode(overscrollNode: ChatInputPanelOverscrollNode(text: releaseText, color: self.currentPresentationData.theme.theme.rootController.navigationBar.secondaryTextColor, priority: 1))
                    }
                } else {
                    if chatControllerNode.inputPanelOverscrollNode?.text.0 != swipeText.0 {
                        chatControllerNode.setChatInputPanelOverscrollNode(overscrollNode: ChatInputPanelOverscrollNode(text: swipeText, color: self.currentPresentationData.theme.theme.rootController.navigationBar.secondaryTextColor, priority: 2))
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
    
    private func processDisplayedItemRangeChanged(displayedRange: ListViewDisplayedItemRange, transactionState: ChatHistoryTransactionOpaqueState) {
        let historyView = transactionState.historyView
        var isTopReplyThreadMessageShownValue = false
        var topVisibleMessageRange: ChatTopVisibleMessageRange?
        
        if let visible = displayedRange.visibleRange {
            let indexRange = (historyView.filteredEntries.count - 1 - visible.lastIndex, historyView.filteredEntries.count - 1 - visible.firstIndex)
            if indexRange.0 > indexRange.1 {
                assert(false)
                return
            }
            
            let readIndexRange = (0, historyView.filteredEntries.count - 1 - visible.firstIndex)
            
            let toEarlierRange = (0, historyView.filteredEntries.count - 1 - visible.lastIndex - 1)
            let toLaterRange = (historyView.filteredEntries.count - 1 - (visible.firstIndex - 1), historyView.filteredEntries.count - 1)
            
            var messageIdsWithViewCount: [MessageId] = []
            var messageIdsWithLiveLocation: [MessageId] = []
            var messageIdsWithUnsupportedMedia: [MessageId] = []
            var messageIdsWithRefreshMedia: [MessageId] = []
            var messageIdsWithUnseenPersonalMention: [MessageId] = []
            var messageIdsWithUnseenReactions: [MessageId] = []
            var downloadableResourceIds: [(messageId: MessageId, resourceId: String)] = []
            
            if indexRange.0 <= indexRange.1 {
                for i in (indexRange.0 ... indexRange.1) {
                    switch historyView.filteredEntries[i] {
                    case let .MessageEntry(message, _, _, _, _, _):
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
                            }
                        }
                        for media in message.media {
                            if let _ = media as? TelegramMediaUnsupported {
                                contentRequiredValidation = true
                            } else if message.flags.contains(.Incoming), let media = media as? TelegramMediaMap, let liveBroadcastingTimeout = media.liveBroadcastingTimeout {
                                let timestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                                if message.timestamp + liveBroadcastingTimeout > timestamp {
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
                            }
                        }
                        if contentRequiredValidation {
                            messageIdsWithUnsupportedMedia.append(message.id)
                        }
                        if mediaRequiredValidation {
                            messageIdsWithRefreshMedia.append(message.id)
                        }
                        if hasUnconsumedMention && !hasUnconsumedContent {
                            messageIdsWithUnseenPersonalMention.append(message.id)
                        }
                        if hasUnseenReactions {
                            messageIdsWithUnseenReactions.append(message.id)
                        }
                        
                        if case let .replyThread(replyThreadMessage) = self.chatLocation, replyThreadMessage.effectiveTopId == message.id {
                            isTopReplyThreadMessageShownValue = true
                        }
                        if let topVisibleMessageRangeValue = topVisibleMessageRange {
                            topVisibleMessageRange = ChatTopVisibleMessageRange(lowerBound: topVisibleMessageRangeValue.lowerBound, upperBound: message.index, isLast: i == historyView.filteredEntries.count - 1)
                        } else {
                            topVisibleMessageRange = ChatTopVisibleMessageRange(lowerBound: message.index, upperBound: message.index, isLast: i == historyView.filteredEntries.count - 1)
                        }
                    case let .MessageGroupEntry(_, messages, _):
                        for (message, _, _, _, _) in messages {
                            var hasUnconsumedMention = false
                            var hasUnconsumedContent = false
                            var hasUnseenReactions = false
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
                                }
                            }
                            if hasUnconsumedMention && !hasUnconsumedContent {
                                messageIdsWithUnseenPersonalMention.append(message.id)
                            }
                            if hasUnseenReactions {
                                messageIdsWithUnseenReactions.append(message.id)
                            }
                            if case let .replyThread(replyThreadMessage) = self.chatLocation, replyThreadMessage.effectiveTopId == message.id {
                                isTopReplyThreadMessageShownValue = true
                            }
                            if let topVisibleMessageRangeValue = topVisibleMessageRange {
                                topVisibleMessageRange = ChatTopVisibleMessageRange(lowerBound: topVisibleMessageRangeValue.lowerBound, upperBound: message.index, isLast: i == historyView.filteredEntries.count - 1)
                            } else {
                                topVisibleMessageRange = ChatTopVisibleMessageRange(lowerBound: message.index, upperBound: message.index, isLast: i == historyView.filteredEntries.count - 1)
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
                    var hasAction = false
                    for media in message.media {
                        if let _ = media as? TelegramMediaAction {
                            hasAction = true
                        }
                    }
                    if !hasAction {
                        switch message.id.peerId.namespace {
                        case Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel:
                            messageIdsWithPossibleReactions.append(message.id)
                        default:
                            break
                        }
                    }
                case let .MessageGroupEntry(_, messages, _):
                    for (message, _, _, _, _) in messages {
                        var hasAction = false
                        for media in message.media {
                            if let _ = media as? TelegramMediaAction {
                                hasAction = true
                            }
                        }
                        if !hasAction {
                            switch message.id.peerId.namespace {
                            case Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel:
                                messageIdsWithPossibleReactions.append(message.id)
                            default:
                                break
                            }
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
                self.messageProcessingManager.add(messageIdsWithViewCount)
            }
            if !messageIdsWithLiveLocation.isEmpty {
                self.seenLiveLocationProcessingManager.add(messageIdsWithLiveLocation)
            }
            if !messageIdsWithUnsupportedMedia.isEmpty {
                self.unsupportedMessageProcessingManager.add(messageIdsWithUnsupportedMedia)
            }
            if !messageIdsWithRefreshMedia.isEmpty {
                self.refreshMediaProcessingManager.add(messageIdsWithRefreshMedia)
            }
            if !messageIdsWithUnseenPersonalMention.isEmpty {
                self.messageMentionProcessingManager.add(messageIdsWithUnseenPersonalMention)
            }
            if !messageIdsWithUnseenReactions.isEmpty {
                self.unseenReactionsProcessingManager.add(messageIdsWithUnseenReactions)
                
                if self.canReadHistoryValue && !self.context.sharedContext.immediateExperimentalUISettings.skipReadHistory {
                    let _ = self.displayUnseenReactionAnimations(messageIds: messageIdsWithUnseenReactions)
                }
            }
            if !messageIdsWithPossibleReactions.isEmpty {
                self.messageWithReactionsProcessingManager.add(messageIdsWithPossibleReactions)
            }
            if !downloadableResourceIds.isEmpty {
                let _ = markRecentDownloadItemsAsSeen(postbox: self.context.account.postbox, items: downloadableResourceIds).start()
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
                case .replyThread, .feed:
                    messageIndex = maxOverallIndex
                }
                
                if let messageIndex = messageIndex {
                    self.updateMaxVisibleReadIncomingMessageIndex(messageIndex)
                }
                
                if let maxOverallIndex = maxOverallIndex, maxOverallIndex != self.maxVisibleMessageIndexReported {
                    self.maxVisibleMessageIndexReported = maxOverallIndex
                    self.maxVisibleMessageIndexUpdated?(maxOverallIndex)
                }
            }
        }
        self.isTopReplyThreadMessageShown.set(isTopReplyThreadMessageShownValue)
        self.topVisibleMessageRange.set(topVisibleMessageRange)
        let _ = self.visibleMessageRange.swap(topVisibleMessageRange.flatMap { range in
            return VisibleMessageRange(lowerBound: range.lowerBound, upperBound: range.upperBound)
        })
        
        if let loaded = displayedRange.loadedRange, let firstEntry = historyView.filteredEntries.first, let lastEntry = historyView.filteredEntries.last {
            if loaded.firstIndex < 5 && historyView.originalView.laterId != nil {
                let locationInput: ChatHistoryLocation = .Navigation(index: .message(lastEntry.index), anchorIndex: .message(lastEntry.index), count: historyMessageCount, highlight: false)
                if self.chatHistoryLocationValue?.content != locationInput {
                    self.chatHistoryLocationValue = ChatHistoryLocationInput(content: locationInput, id: self.takeNextHistoryLocationId())
                }
            } else if loaded.firstIndex < 5, historyView.originalView.laterId == nil, !historyView.originalView.holeLater, let chatHistoryLocationValue = self.chatHistoryLocationValue, !chatHistoryLocationValue.isAtUpperBound, historyView.originalView.anchorIndex != .upperBound {
                if self.chatHistoryLocationValue == historyView.locationInput {
                    self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Navigation(index: .upperBound, anchorIndex: .upperBound, count: historyMessageCount, highlight: false), id: self.takeNextHistoryLocationId())
                }
            } else if loaded.lastIndex >= historyView.filteredEntries.count - 5 && historyView.originalView.earlierId != nil {
                let locationInput: ChatHistoryLocation = .Navigation(index: .message(firstEntry.index), anchorIndex: .message(firstEntry.index), count: historyMessageCount, highlight: false)
                if self.chatHistoryLocationValue?.content != locationInput {
                    self.chatHistoryLocationValue = ChatHistoryLocationInput(content: locationInput, id: self.takeNextHistoryLocationId())
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
                        self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Scroll(index: .message(message.index), anchorIndex: .message(message.index), sourceIndex: .upperBound, scrollPosition: .bottom(0.0), animated: true, highlight: false), id: self.takeNextHistoryLocationId())
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
                self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Scroll(index: .message(currentMessage.index), anchorIndex: .message(currentMessage.index), sourceIndex: .upperBound, scrollPosition: .top(0.0), animated: true, highlight: true), id: self.takeNextHistoryLocationId())
            }
        }
    }
    
    public func scrollToStartOfHistory() {
        self.beganDragging?()
        self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Scroll(index: .lowerBound, anchorIndex: .lowerBound, sourceIndex: .upperBound, scrollPosition: .bottom(0.0), animated: true, highlight: false), id: self.takeNextHistoryLocationId())
    }
    
    public func scrollToEndOfHistory() {
        self.beganDragging?()
        switch self.visibleContentOffset() {
            case let .known(value) where value <= CGFloat.ulpOfOne:
                break
            default:
                let locationInput = ChatHistoryLocationInput(content: .Scroll(index: .upperBound, anchorIndex: .upperBound, sourceIndex: .lowerBound, scrollPosition: .top(0.0), animated: true, highlight: false), id: self.takeNextHistoryLocationId())
                self.chatHistoryLocationValue = locationInput
        }
    }
    
    public func scrollToMessage(from fromIndex: MessageIndex, to toIndex: MessageIndex, animated: Bool, highlight: Bool = true, scrollPosition: ListViewScrollPosition = .center(.bottom)) {
        self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Scroll(index: .message(toIndex), anchorIndex: .message(toIndex), sourceIndex: .message(fromIndex), scrollPosition: scrollPosition, animated: animated, highlight: highlight), id: self.takeNextHistoryLocationId())
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
                        if canEditMessage(context: context, limitsConfiguration: context.currentLimitsConfiguration.with { $0 }, message: message) {
                            return message
                        }
                    }
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
                loadState = .messages
            }
            if self.loadState != loadState {
                self.loadState = loadState
                self.loadStateUpdated?(loadState, transition.options.contains(.AnimateInsertion))
            }
            
            let historyState: ChatHistoryNodeHistoryState = .loaded(isEmpty: transition.historyView.originalView.entries.isEmpty)
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
        
        let animated = transition.options.contains(.AnimateInsertion)

        let completion: (Bool, ListViewDisplayedItemRange) -> Void = { [weak self] wasTransformed, visibleRange in
            if let strongSelf = self {
                var newIncomingReactions: [MessageId: (value: String, isLarge: Bool)] = [:]
                if case .peer = strongSelf.chatLocation, let previousHistoryView = strongSelf.historyView {
                    var updatedIncomingReactions: [MessageId: (value: String, isLarge: Bool)] = [:]
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
                                var previousReaction: String?
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
                                    var previousReaction: String?
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
                
                strongSelf.historyView = transition.historyView
                
                let loadState: ChatHistoryNodeLoadState
                if let historyView = strongSelf.historyView {
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
                                    }
                                }
                            }
                            loadState = .empty(emptyType)
                        } else {
                            loadState = .empty(.generic)
                        }
                    } else {
                        loadState = .messages
                    }
                } else {
                    loadState = .loading
                }
                
                var animateIn = false
                if strongSelf.loadState != loadState {
                    if case .loading = strongSelf.loadState {
                        if case .messages = loadState {
                            animateIn = true
                        }
                    }
                    strongSelf.loadState = loadState
                    strongSelf.loadStateUpdated?(loadState, animated || transition.animateIn || animateIn)
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
                            case .replyThread, .feed:
                                messageIndex = overallIndex
                            }
                            
                            if let messageIndex = messageIndex {
                                strongSelf.updateMaxVisibleReadIncomingMessageIndex(messageIndex)
                            }
                        }
                    }
                } else if case .empty(.joined) = loadState, let entry = transition.historyView.originalView.entries.first {
                    strongSelf.updateMaxVisibleReadIncomingMessageIndex(entry.message.index)
                }
                
                if !strongSelf.didSetInitialData {
                    strongSelf.didSetInitialData = true
                    strongSelf._initialData.set(.single(ChatHistoryCombinedInitialData(initialData: transition.initialData, buttonKeyboardMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData, cachedDataMessages: transition.cachedDataMessages, readStateData: transition.readStateData)))
                }
                strongSelf._cachedPeerDataAndMessages.set(.single((transition.cachedData, transition.cachedDataMessages)))
                let historyState: ChatHistoryNodeHistoryState = .loaded(isEmpty: transition.historyView.originalView.entries.isEmpty)
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
                
                if transition.animateIn || animateIn {
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
                        strongSelf.unseenReactionsProcessingManager.add(visibleNewIncomingReactionMessageIds)
                    }
                }
                
                strongSelf.hasActiveTransition = false
                strongSelf.dequeueHistoryViewTransitions()
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
            }

            let (mappedTransition, updateSizeAndInsets) = layoutActionOnViewTransition(transition)

            self.transaction(deleteIndices: mappedTransition.deleteItems, insertIndicesAndItems: transition.insertItems, updateIndicesAndItems: transition.updateItems, options: mappedTransition.options, scrollToItem: mappedTransition.scrollToItem, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: mappedTransition.stationaryItemRange, updateOpaqueState: ChatHistoryTransactionOpaqueState(historyView: transition.historyView), completion: { result in
                completion(true, result)
            })
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
            
            var selectedReaction: (String, EnginePeer?, Bool)?
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
            
            if let availableReactions = item.associatedData.availableReactions, let targetView = itemNode.targetReactionView(value: updatedReaction) {
                for reaction in availableReactions.reactions {
                    guard let centerAnimation = reaction.centerAnimation else {
                        continue
                    }
                    guard let aroundAnimation = reaction.aroundAnimation else {
                        continue
                    }
                    
                    if reaction.value == updatedReaction {
                        let standaloneReactionAnimation = StandaloneReactionAnimation()
                        
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
                            reaction: ReactionContextItem(
                                reaction: ReactionContextItem.Reaction(rawValue: reaction.value),
                                appearAnimation: reaction.appearAnimation,
                                stillAnimation: reaction.selectAnimation,
                                listAnimation: centerAnimation,
                                largeListAnimation: reaction.activateAnimation,
                                applicationAnimation: aroundAnimation,
                                largeApplicationAnimation: reaction.effectAnimation
                            ),
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
            }
        }
        return visibleNewIncomingReactionMessageIds
    }
    
    public func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets) {
        self.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets, additionalScrollDistance: 0.0, scrollToTop: false, completion: {})
    }
        
    public func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets, additionalScrollDistance: CGFloat, scrollToTop: Bool, completion: @escaping () -> Void) {
        var scrollToItem: ListViewScrollToItem?
        if scrollToTop, case .known = self.visibleContentOffset() {
            scrollToItem = ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Spring(duration: updateSizeAndInsets.duration), directionHint: .Up)
        }
        self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: scrollToItem, additionalScrollDistance: scrollToTop ? 0.0 : additionalScrollDistance, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in
            completion()
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
                    if !self.context.sharedContext.immediateExperimentalUISettings.skipReadHistory {
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
    
    func requestMessageUpdate(_ id: MessageId) {
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
                
                loop: for i in 0 ..< historyView.filteredEntries.count {
                    switch historyView.filteredEntries[i] {
                        case let .MessageEntry(message, presentationData, read, location, selection, attributes):
                            if message.id == id {
                                let index = historyView.filteredEntries.count - 1 - i
                                let item: ListViewItem
                                switch self.mode {
                                    case .bubbles:
                                        item = ChatMessageItem(presentationData: presentationData, context: self.context, chatLocation: self.chatLocation, associatedData: associatedData, controllerInteraction: self.controllerInteraction, content: .message(message: message, read: read, selection: selection, attributes: attributes, location: location))
                                    case let .list(_, _, displayHeaders, hintLinks, isGlobalSearch):
                                        let displayHeader: Bool
                                        switch displayHeaders {
                                        case .none:
                                            displayHeader = false
                                        case .all:
                                            displayHeader = true
                                        case .allButLast:
                                            displayHeader = listMessageDateHeaderId(timestamp: message.timestamp) != historyView.lastHeaderId
                                        }
                                        item = ListMessageItem(presentationData: presentationData, context: self.context, chatLocation: self.chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: self.controllerInteraction), message: message, selection: selection, displayHeader: displayHeader, hintIsLink: hintLinks, isGlobalSearchResult: isGlobalSearch)
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

                loop: for i in 0 ..< historyView.filteredEntries.count {
                    switch historyView.filteredEntries[i] {
                        case let .MessageEntry(message, presentationData, read, location, selection, attributes):
                            if message.stableId == stableId {
                                let index = historyView.filteredEntries.count - 1 - i
                                let item: ListViewItem
                                switch self.mode {
                                    case .bubbles:
                                        item = ChatMessageItem(presentationData: presentationData, context: self.context, chatLocation: self.chatLocation, associatedData: associatedData, controllerInteraction: self.controllerInteraction, content: .message(message: message, read: read, selection: selection, attributes: attributes, location: location))
                                    case let .list(_, _, displayHeaders, hintLinks, isGlobalSearch):
                                        let displayHeader: Bool
                                        switch displayHeaders {
                                        case .none:
                                            displayHeader = false
                                        case .all:
                                            displayHeader = true
                                        case .allButLast:
                                            displayHeader = listMessageDateHeaderId(timestamp: message.timestamp) != historyView.lastHeaderId
                                        }
                                        item = ListMessageItem(presentationData: presentationData, context: self.context, chatLocation: self.chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: self.controllerInteraction), message: message, selection: selection, displayHeader: displayHeader, hintIsLink: hintLinks, isGlobalSearchResult: isGlobalSearch)
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
        if let currentItem = currentItem?.id as? PeerMessagesMediaPlaylistItemId {
            self.currentlyPlayingMessageIdPromise.set(currentItem.messageIndex)
        } else {
            self.currentlyPlayingMessageIdPromise.set(nil)
        }
    }

    private var currentSendAnimationCorrelationIds: Set<Int64>?
    func setCurrentSendAnimationCorrelationIds(_ value: Set<Int64>?) {
        self.currentSendAnimationCorrelationIds = value
    }

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

        let snapshotView = self.view.snapshotView(afterScreenUpdates: false)!

        snapshotView.frame = self.view.bounds
        if let sublayers = self.layer.sublayers {
            for sublayer in sublayers {
                sublayer.isHidden = true
            }
        }
        self.view.addSubview(snapshotView)

        let overscrollView = self.overscrollView
        if let overscrollView = overscrollView {
            self.overscrollView = nil

            overscrollView.frame = overscrollView.convert(overscrollView.bounds, to: self.view)
            snapshotView.addSubview(overscrollView)

            overscrollView.layer.sublayerTransform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
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
        snapshotParentView.layer.sublayerTransform = CATransform3DMakeRotation(CGFloat(Double.pi), 0.0, 0.0, 1.0)
        snapshotParentView.frame = self.view.frame

        snapshotState.snapshotView.frame = snapshotParentView.bounds
        self.view.superview?.insertSubview(snapshotParentView, belowSubview: self.view)

        snapshotParentView.layer.animatePosition(from: CGPoint(x: 0.0, y: 0.0), to: CGPoint(x: 0.0, y: -self.view.bounds.height - snapshotState.snapshotBottomInset - snapshotTopInset), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { [weak snapshotParentView] _ in
            snapshotParentView?.removeFromSuperview()
            completion()
        })

        self.view.layer.animatePosition(from: CGPoint(x: 0.0, y: self.view.bounds.height + snapshotTopInset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: true, additive: true)
    }
}
