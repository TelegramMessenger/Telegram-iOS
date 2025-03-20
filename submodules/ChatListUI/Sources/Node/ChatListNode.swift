import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import TelegramNotices
import ContactsPeerItem
import ContextUI
import ItemListUI
import SearchUI
import ChatListSearchItemHeader
import PremiumUI
import AnimationCache
import MultiAnimationRenderer
import Postbox
import ChatFolderLinkPreviewScreen
import StoryContainerScreen
import ChatListHeaderComponent
import UndoUI
import NewSessionInfoScreen
import PresentationDataUtils

public enum ChatListNodeMode {
    case chatList(appendContacts: Bool)
    case peers(filter: ChatListNodePeersFilter, isSelecting: Bool, additionalCategories: [ChatListNodeAdditionalCategory], chatListFilters: [ChatListFilter]?, displayAutoremoveTimeout: Bool, displayPresence: Bool)
    case peerType(type: [ReplyMarkupButtonRequestPeerType], hasCreate: Bool)
}

struct ChatListNodeListViewTransition {
    let chatListView: ChatListNodeView
    let deleteItems: [ListViewDeleteItem]
    let insertItems: [ListViewInsertItem]
    let updateItems: [ListViewUpdateItem]
    let options: ListViewDeleteAndInsertOptions
    let scrollToItem: ListViewScrollToItem?
    let stationaryItemRange: (Int, Int)?
    let adjustScrollToFirstItem: Bool
    let animateCrossfade: Bool
}

final class ChatListHighlightedLocation: Equatable {
    let location: ChatLocation
    let progress: CGFloat
    
    init(location: ChatLocation, progress: CGFloat) {
        self.location = location
        self.progress = progress
    }
    
    func withUpdatedProgress(_ progress: CGFloat) -> ChatListHighlightedLocation {
        return ChatListHighlightedLocation(location: location, progress: progress)
    }
    
    static func ==(lhs: ChatListHighlightedLocation, rhs: ChatListHighlightedLocation) -> Bool {
        if lhs.location != rhs.location {
            return false
        }
        if lhs.progress != rhs.progress {
            return false
        }
        return true
    }
}

public final class ChatListNodeInteraction {
    public enum PeerEntry {
        case peerId(EnginePeer.Id)
        case peer(EnginePeer)
    }
    
    let activateSearch: () -> Void
    let peerSelected: (EnginePeer, EnginePeer?, Int64?, ChatListNodeEntryPromoInfo?, Bool) -> Void
    let disabledPeerSelected: (EnginePeer, Int64?, ChatListDisabledPeerReason) -> Void
    let togglePeerSelected: (EnginePeer, Int64?) -> Void
    let togglePeersSelection: ([PeerEntry], Bool) -> Void
    let additionalCategorySelected: (Int) -> Void
    let messageSelected: (EnginePeer, Int64?, EngineMessage, ChatListNodeEntryPromoInfo?) -> Void
    let groupSelected: (EngineChatList.Group) -> Void
    let addContact: (String) -> Void
    let setPeerIdWithRevealedOptions: (EnginePeer.Id?, EnginePeer.Id?) -> Void
    let setItemPinned: (EngineChatList.PinnedItem.Id, Bool) -> Void
    let setPeerMuted: (EnginePeer.Id, Bool) -> Void
    let setPeerThreadMuted: (EnginePeer.Id, Int64?, Bool) -> Void
    let deletePeer: (EnginePeer.Id, Bool) -> Void
    let deletePeerThread: (EnginePeer.Id, Int64) -> Void
    let setPeerThreadStopped: (EnginePeer.Id, Int64, Bool) -> Void
    let setPeerThreadPinned: (EnginePeer.Id, Int64, Bool) -> Void
    let setPeerThreadHidden: (EnginePeer.Id, Int64, Bool) -> Void
    let updatePeerGrouping: (EnginePeer.Id, Bool) -> Void
    let togglePeerMarkedUnread: (EnginePeer.Id, Bool) -> Void
    let toggleArchivedFolderHiddenByDefault: () -> Void
    let toggleThreadsSelection: ([Int64], Bool) -> Void
    let hidePsa: (EnginePeer.Id) -> Void
    let activateChatPreview: ((ChatListItem, Int64?, ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?
    let present: (ViewController) -> Void
    let openForumThread: (EnginePeer.Id, Int64) -> Void
    let openStorageManagement: () -> Void
    let openPasswordSetup: () -> Void
    let openPremiumIntro: () -> Void
    let openPremiumGift: ([EnginePeer], [EnginePeer.Id: TelegramBirthday]?) -> Void
    let openPremiumManagement: () -> Void
    let openActiveSessions: () -> Void
    let openBirthdaySetup: () -> Void
    let performActiveSessionAction: (NewSessionReview, Bool) -> Void
    let openChatFolderUpdates: () -> Void
    let hideChatFolderUpdates: () -> Void
    let openStories: (ChatListNode.OpenStoriesSubject, ASDisplayNode?) -> Void
    let openStarsTopup: (Int64?) -> Void
    let dismissNotice: (ChatListNotice) -> Void
    let editPeer: (ChatListItem) -> Void
    let openWebApp: (TelegramUser) -> Void
    let openPhotoSetup: () -> Void
    let openAdInfo: (ASDisplayNode) -> Void
    
    public var searchTextHighightState: String?
    var highlightedChatLocation: ChatListHighlightedLocation?
    
    var isSearchMode: Bool = false
    
    var isInlineMode: Bool = false
    var inlineNavigationLocation: ChatListHighlightedLocation?
    
    let animationCache: AnimationCache
    let animationRenderer: MultiAnimationRenderer
    
    public init(
        context: AccountContext,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        activateSearch: @escaping () -> Void,
        peerSelected: @escaping (EnginePeer, EnginePeer?, Int64?, ChatListNodeEntryPromoInfo?, Bool) -> Void,
        disabledPeerSelected: @escaping (EnginePeer, Int64?, ChatListDisabledPeerReason) -> Void,
        togglePeerSelected: @escaping (EnginePeer, Int64?) -> Void,
        togglePeersSelection: @escaping ([PeerEntry], Bool) -> Void,
        additionalCategorySelected: @escaping (Int) -> Void,
        messageSelected: @escaping (EnginePeer, Int64?, EngineMessage, ChatListNodeEntryPromoInfo?) -> Void,
        groupSelected: @escaping (EngineChatList.Group) -> Void,
        addContact: @escaping (String) -> Void,
        setPeerIdWithRevealedOptions: @escaping (EnginePeer.Id?, EnginePeer.Id?) -> Void,
        setItemPinned: @escaping (EngineChatList.PinnedItem.Id, Bool) -> Void,
        setPeerMuted: @escaping (EnginePeer.Id, Bool) -> Void,
        setPeerThreadMuted: @escaping (EnginePeer.Id, Int64?, Bool) -> Void,
        deletePeer: @escaping (EnginePeer.Id, Bool) -> Void,
        deletePeerThread: @escaping (EnginePeer.Id, Int64) -> Void,
        setPeerThreadStopped: @escaping (EnginePeer.Id, Int64, Bool) -> Void,
        setPeerThreadPinned: @escaping (EnginePeer.Id, Int64, Bool) -> Void,
        setPeerThreadHidden: @escaping (EnginePeer.Id, Int64, Bool) -> Void,
        updatePeerGrouping: @escaping (EnginePeer.Id, Bool) -> Void,
        togglePeerMarkedUnread: @escaping (EnginePeer.Id, Bool) -> Void,
        toggleArchivedFolderHiddenByDefault: @escaping () -> Void,
        toggleThreadsSelection: @escaping ([Int64], Bool) -> Void,
        hidePsa: @escaping (EnginePeer.Id) -> Void,
        activateChatPreview: ((ChatListItem, Int64?, ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?,
        present: @escaping (ViewController) -> Void,
        openForumThread: @escaping (EnginePeer.Id, Int64) -> Void,
        openStorageManagement: @escaping () -> Void,
        openPasswordSetup: @escaping () -> Void,
        openPremiumIntro: @escaping () -> Void,
        openPremiumGift: @escaping ([EnginePeer], [EnginePeer.Id: TelegramBirthday]?) -> Void,
        openPremiumManagement: @escaping () -> Void,
        openActiveSessions: @escaping () -> Void,
        openBirthdaySetup: @escaping () -> Void,
        performActiveSessionAction: @escaping (NewSessionReview, Bool) -> Void,
        openChatFolderUpdates: @escaping () -> Void,
        hideChatFolderUpdates: @escaping () -> Void,
        openStories: @escaping (ChatListNode.OpenStoriesSubject, ASDisplayNode?) -> Void,
        openStarsTopup: @escaping (Int64?) -> Void,
        dismissNotice: @escaping (ChatListNotice) -> Void,
        editPeer: @escaping (ChatListItem) -> Void,
        openWebApp: @escaping (TelegramUser) -> Void,
        openPhotoSetup: @escaping () -> Void,
        openAdInfo: @escaping (ASDisplayNode) -> Void
    ) {
        self.activateSearch = activateSearch
        self.peerSelected = peerSelected
        self.disabledPeerSelected = disabledPeerSelected
        self.togglePeerSelected = togglePeerSelected
        self.togglePeersSelection = togglePeersSelection
        self.additionalCategorySelected = additionalCategorySelected
        self.messageSelected = messageSelected
        self.groupSelected = groupSelected
        self.addContact = addContact
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.setItemPinned = setItemPinned
        self.setPeerMuted = setPeerMuted
        self.setPeerThreadMuted = setPeerThreadMuted
        self.deletePeer = deletePeer
        self.deletePeerThread = deletePeerThread
        self.setPeerThreadStopped = setPeerThreadStopped
        self.setPeerThreadPinned = setPeerThreadPinned
        self.setPeerThreadHidden = setPeerThreadHidden
        self.updatePeerGrouping = updatePeerGrouping
        self.togglePeerMarkedUnread = togglePeerMarkedUnread
        self.toggleArchivedFolderHiddenByDefault = toggleArchivedFolderHiddenByDefault
        self.toggleThreadsSelection = toggleThreadsSelection
        self.hidePsa = hidePsa
        self.activateChatPreview = activateChatPreview
        self.present = present
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.openForumThread = openForumThread
        self.openStorageManagement = openStorageManagement
        self.openPasswordSetup = openPasswordSetup
        self.openPremiumIntro = openPremiumIntro
        self.openPremiumGift = openPremiumGift
        self.openPremiumManagement = openPremiumManagement
        self.openActiveSessions = openActiveSessions
        self.openBirthdaySetup = openBirthdaySetup
        self.performActiveSessionAction = performActiveSessionAction
        self.openChatFolderUpdates = openChatFolderUpdates
        self.hideChatFolderUpdates = hideChatFolderUpdates
        self.openStories = openStories
        self.openStarsTopup = openStarsTopup
        self.dismissNotice = dismissNotice
        self.editPeer = editPeer
        self.openWebApp = openWebApp
        self.openPhotoSetup = openPhotoSetup
        self.openAdInfo = openAdInfo
    }
}

public final class ChatListNodePeerInputActivities {
    public struct ItemId: Hashable {
        public var peerId: EnginePeer.Id
        public var threadId: Int64?
        
        public init(peerId: EnginePeer.Id, threadId: Int64?) {
            self.peerId = peerId
            self.threadId = threadId
        }
    }
    
    public let activities: [ItemId: [(EnginePeer, PeerInputActivity)]]
    
    public init(activities: [ItemId: [(EnginePeer, PeerInputActivity)]]) {
        self.activities = activities
    }
}

private func areFoundPeerArraysEqual(_ lhs: [(EnginePeer, EnginePeer?)], _ rhs: [(EnginePeer, EnginePeer?)]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    for i in 0 ..< lhs.count {
        if lhs[i].0 != rhs[i].0 || lhs[i].1 != rhs[i].1 {
            return false
        }
    }
    return true
}

public struct ChatListNodeState: Equatable {
    public struct StoryState: Equatable {
        public var stats: EngineChatList.StoryStats
        public var hasUnseenCloseFriends: Bool
        
        public init(stats: EngineChatList.StoryStats, hasUnseenCloseFriends: Bool) {
            self.stats = stats
            self.hasUnseenCloseFriends = hasUnseenCloseFriends
        }
    }
    
    public struct ItemId: Hashable {
        public var peerId: EnginePeer.Id
        public var threadId: Int64?
        
        public init(peerId: EnginePeer.Id, threadId: Int64?) {
            self.peerId = peerId
            self.threadId = threadId
        }
    }
    
    public var presentationData: ChatListPresentationData
    public var editing: Bool
    public var peerIdWithRevealedOptions: ItemId?
    public var selectedPeerIds: Set<EnginePeer.Id>
    public var peerInputActivities: ChatListNodePeerInputActivities?
    public var pendingRemovalItemIds: Set<ItemId>
    public var pendingClearHistoryPeerIds: Set<ItemId>
    public var hiddenItemShouldBeTemporaryRevealed: Bool
    public var selectedAdditionalCategoryIds: Set<Int>
    public var hiddenPsaPeerId: EnginePeer.Id?
    public var foundPeers: [(EnginePeer, EnginePeer?)]
    public var selectedPeerMap: [EnginePeer.Id: EnginePeer]
    public var selectedThreadIds: Set<Int64>
    public var archiveStoryState: StoryState?
    
    public init(
        presentationData: ChatListPresentationData,
        editing: Bool,
        peerIdWithRevealedOptions: ItemId?,
        selectedPeerIds: Set<EnginePeer.Id>,
        foundPeers: [(EnginePeer, EnginePeer?)],
        selectedPeerMap: [EnginePeer.Id: EnginePeer],
        selectedAdditionalCategoryIds: Set<Int>,
        peerInputActivities: ChatListNodePeerInputActivities?,
        pendingRemovalItemIds: Set<ItemId>,
        pendingClearHistoryPeerIds: Set<ItemId>,
        hiddenItemShouldBeTemporaryRevealed: Bool,
        hiddenPsaPeerId: EnginePeer.Id?,
        selectedThreadIds: Set<Int64>,
        archiveStoryState: StoryState?
    ) {
        self.presentationData = presentationData
        self.editing = editing
        self.peerIdWithRevealedOptions = peerIdWithRevealedOptions
        self.selectedPeerIds = selectedPeerIds
        self.selectedAdditionalCategoryIds = selectedAdditionalCategoryIds
        self.foundPeers = foundPeers
        self.selectedPeerMap = selectedPeerMap
        self.peerInputActivities = peerInputActivities
        self.pendingRemovalItemIds = pendingRemovalItemIds
        self.pendingClearHistoryPeerIds = pendingClearHistoryPeerIds
        self.hiddenItemShouldBeTemporaryRevealed = hiddenItemShouldBeTemporaryRevealed
        self.hiddenPsaPeerId = hiddenPsaPeerId
        self.selectedThreadIds = selectedThreadIds
        self.archiveStoryState = archiveStoryState
    }
    
    public static func ==(lhs: ChatListNodeState, rhs: ChatListNodeState) -> Bool {
        if lhs.presentationData !== rhs.presentationData {
            return false
        }
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.peerIdWithRevealedOptions != rhs.peerIdWithRevealedOptions {
            return false
        }
        if lhs.selectedPeerIds != rhs.selectedPeerIds {
            return false
        }
        if areFoundPeerArraysEqual(lhs.foundPeers, rhs.foundPeers) {
            return false
        }
        if lhs.selectedPeerMap != rhs.selectedPeerMap {
            return false
        }
        if lhs.selectedAdditionalCategoryIds != rhs.selectedAdditionalCategoryIds {
            return false
        }
        if lhs.peerInputActivities !== rhs.peerInputActivities {
            return false
        }
        if lhs.pendingRemovalItemIds != rhs.pendingRemovalItemIds {
            return false
        }
        if lhs.pendingClearHistoryPeerIds != rhs.pendingClearHistoryPeerIds {
            return false
        }
        if lhs.hiddenItemShouldBeTemporaryRevealed != rhs.hiddenItemShouldBeTemporaryRevealed {
            return false
        }
        if lhs.hiddenPsaPeerId != rhs.hiddenPsaPeerId {
            return false
        }
        if lhs.selectedThreadIds != rhs.selectedThreadIds {
            return false
        }
        if lhs.archiveStoryState != rhs.archiveStoryState {
            return false
        }
        return true
    }
}

private func mappedInsertEntries(context: AccountContext, nodeInteraction: ChatListNodeInteraction, location: ChatListControllerLocation, isPremium: Bool, filterData: ChatListItemFilterData?, chatListFilters: [ChatListFilter]?, mode: ChatListNodeMode, isPeerEnabled: ((EnginePeer) -> Bool)?, entries: [ChatListNodeViewTransitionInsertEntry]) -> [ListViewInsertItem] {
    return entries.map { entry -> ListViewInsertItem in
        switch entry.entry {
            case .HeaderEntry:
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListEmptyHeaderItem(), directionHint: entry.directionHint)
            case let .AdditionalCategory(_, id, title, image, appearance, selected, presentationData):
                var header: ChatListSearchItemHeader?
                if case .peerType = mode {
                } else {
                    if case .action = appearance {
                        // TODO: hack, generalize
                        header = ChatListSearchItemHeader(type: .orImportIntoAnExistingGroup, theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil)
                    }
                }
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListAdditionalCategoryItem(
                    presentationData: ItemListPresentationData(theme: presentationData.theme, fontSize: presentationData.fontSize, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, dateTimeFormat: presentationData.dateTimeFormat),
                    context: context,
                    title: title,
                    image: image,
                    appearance: appearance,
                    isSelected: selected,
                    header: header,
                    action: {
                        nodeInteraction.additionalCategorySelected(id)
                    }
                ), directionHint: entry.directionHint)
            case let .PeerEntry(peerEntry):
                let index = peerEntry.index
                let presentationData = peerEntry.presentationData
                let combinedReadState = peerEntry.readState
                let isRemovedFromTotalUnreadCount = peerEntry.isRemovedFromTotalUnreadCount
                let draftState = peerEntry.draftState
                let peer = peerEntry.peer
                let threadInfo = peerEntry.threadInfo
                let presence = peerEntry.presence
                let hasUnseenMentions = peerEntry.hasUnseenMentions
                let hasUnseenReactions = peerEntry.hasUnseenReactions
                let editing = peerEntry.editing
                let hasActiveRevealControls = peerEntry.hasActiveRevealControls
                let selected = peerEntry.selected
                let inputActivities = peerEntry.inputActivities
                let promoInfo = peerEntry.promoInfo
                let hasFailedMessages = peerEntry.hasFailedMessages
                let isContact = peerEntry.isContact
                let forumTopicData = peerEntry.forumTopicData
                let topForumTopicItems = peerEntry.topForumTopicItems
                let revealed = peerEntry.revealed
            
                switch mode {
                    case .chatList:
                        return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(
                            presentationData: presentationData,
                            context: context,
                            chatListLocation: location,
                            filterData: filterData,
                            index: index,
                            content: .peer(ChatListItemContent.PeerData(
                                messages: peerEntry.messages,
                                peer: peer,
                                threadInfo: threadInfo,
                                combinedReadState: combinedReadState,
                                isRemovedFromTotalUnreadCount: isRemovedFromTotalUnreadCount,
                                presence: presence,
                                hasUnseenMentions: hasUnseenMentions,
                                hasUnseenReactions: hasUnseenReactions,
                                draftState: draftState,
                                mediaDraftContentType: peerEntry.mediaDraftContentType,
                                inputActivities: inputActivities,
                                promoInfo: promoInfo,
                                ignoreUnreadBadge: false,
                                displayAsMessage: false,
                                hasFailedMessages: hasFailedMessages,
                                forumTopicData: forumTopicData,
                                topForumTopicItems: topForumTopicItems,
                                autoremoveTimeout: peerEntry.autoremoveTimeout,
                                storyState: peerEntry.storyState.flatMap { storyState in
                                    return ChatListItemContent.StoryState(
                                        stats: storyState.stats,
                                        hasUnseenCloseFriends: storyState.hasUnseenCloseFriends
                                    )
                                },
                                requiresPremiumForMessaging: peerEntry.requiresPremiumForMessaging,
                                displayAsTopicList: peerEntry.displayAsTopicList,
                                tags: chatListItemTags(location: location, accountPeerId: context.account.peerId, isPremium: isPremium, peer: peer.chatMainPeer, isUnread: combinedReadState?.isUnread ?? false, isMuted: isRemovedFromTotalUnreadCount, isContact: isContact, hasUnseenMentions: hasUnseenMentions, chatListFilters: chatListFilters)
                            )),
                            editing: editing,
                            hasActiveRevealControls: hasActiveRevealControls,
                            selected: selected,
                            header: nil,
                            enableContextActions: true,
                            hiddenOffset: threadInfo?.isHidden == true && !revealed,
                            interaction: nodeInteraction
                        ), directionHint: entry.directionHint)
                    case let .peers(filter, isSelecting, _, filters, displayAutoremoveTimeout, displayPresence):
                        let itemPeer = peer.chatMainPeer
                        var chatPeer: EnginePeer?
                        if let peer = peer.peers[peer.peerId] {
                            chatPeer = peer
                        }
                        var enabled = true
                        if let isPeerEnabled {
                            if let itemPeer {
                                enabled = isPeerEnabled(itemPeer)
                            }
                        } else {
                            if filter.contains(.onlyWriteable) {
                                if let peer = peer.peers[peer.peerId] {
                                    if !canSendMessagesToPeer(peer._asPeer()) {
                                        enabled = false
                                    }
                                    if peerEntry.requiresPremiumForMessaging {
                                        enabled = false
                                    }
                                } else {
                                    enabled = false
                                }
                                
                                if let threadInfo, threadInfo.isClosed, case let .channel(channel) = itemPeer {
                                    if threadInfo.isOwnedByMe || channel.hasPermission(.manageTopics) {
                                    } else {
                                        enabled = false
                                    }
                                }
                            }
                            if filter.contains(.onlyPrivateChats) {
                                if let peer = peer.peers[peer.peerId] {
                                    switch peer {
                                    case .user, .secretChat:
                                        break
                                    default:
                                        enabled = false
                                    }
                                } else {
                                    enabled = false
                                }
                            }
                            if filter.contains(.onlyGroups) {
                                if let peer = peer.peers[peer.peerId] {
                                    if case .legacyGroup = peer {
                                    } else if case let .channel(peer) = peer, case .group = peer.info {
                                    } else {
                                        enabled = false
                                    }
                                } else {
                                    enabled = false
                                }
                            }
                            if filter.contains(.onlyManageable) {
                                if let peer = peer.peers[peer.peerId] {
                                    var canManage = false
                                    if case let .legacyGroup(peer) = peer {
                                        switch peer.role {
                                        case .creator, .admin:
                                            canManage = true
                                        default:
                                            break
                                        }
                                    } else if case let .channel(peer) = peer, case .group = peer.info, peer.hasPermission(.inviteMembers) {
                                        canManage = true
                                    } else if case let .channel(peer) = peer, case .broadcast = peer.info, peer.hasPermission(.addAdmins) {
                                        canManage = true
                                    }

                                    if canManage {
                                    } else {
                                        enabled = false
                                    }
                                } else {
                                    enabled = false
                                }
                            }
                            if filter.contains(.excludeChannels) {
                                if let peer = peer.peers[peer.peerId] {
                                    if case let .channel(peer) = peer, case .broadcast = peer.info {
                                        enabled = false
                                    }
                                }
                            }
                        }
                        
                        var header: ChatListSearchItemHeader?
                        switch mode {
                        case let .peers(_, _, additionalCategories, _, _, _):
                            if !additionalCategories.isEmpty {
                                let headerType: ChatListSearchItemHeaderType
                                if case .action = additionalCategories[0].appearance {
                                    // TODO: hack, generalize
                                    headerType = .orImportIntoAnExistingGroup
                                } else {
                                    headerType = .chats
                                }
                                header = ChatListSearchItemHeader(type: headerType, theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil)
                            }
                        default:
                            break
                        }
                        
                        var status: ContactsPeerItemStatus = .none
                        if isSelecting, let itemPeer = itemPeer {
                            if displayPresence, let presence = presence {
                                status = .presence(presence, presentationData.dateTimeFormat)
                            } else if let (string, multiline, isActive, icon) = statusStringForPeerType(accountPeerId: context.account.peerId, strings: presentationData.strings, peer: itemPeer, isMuted: isRemovedFromTotalUnreadCount, isUnread: combinedReadState?.isUnread ?? false, isContact: isContact, hasUnseenMentions: hasUnseenMentions, chatListFilters: filters, displayAutoremoveTimeout: displayAutoremoveTimeout, autoremoveTimeout: peerEntry.autoremoveTimeout) {
                                status = .custom(string: string, multiline: multiline, isActive: isActive, icon: icon)
                            } else {
                                status = .none
                            }
                        }
                    
                        let peerContent: ContactsPeerItemPeer
                        if let threadInfo = threadInfo, let itemPeer = itemPeer {
                            peerContent = .thread(peer: itemPeer, title: threadInfo.info.title, icon: threadInfo.info.icon, color: threadInfo.info.iconColor)
                        } else {
                            peerContent = .peer(peer: itemPeer, chatPeer: chatPeer)
                        }
                    
                        var threadId: Int64?
                        switch index {
                        case let .forum(_, _, threadIdValue, _, _):
                            threadId = threadIdValue
                        case .chatList:
                            break
                        }
                    
                        var isForum = false
                        if let peer = chatPeer, case let .channel(channel) = peer, channel.flags.contains(.isForum) {
                            isForum = true
                            if editing, case .chatList = mode {
                                enabled = false
                            }
                        }
                    
                        var selectable = editing
                        if case .chatList = mode {
                            if isForum {
                                selectable = false
                            }
                        }

                        return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ContactsPeerItem(
                            presentationData: ItemListPresentationData(theme: presentationData.theme, fontSize: presentationData.fontSize, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, dateTimeFormat: presentationData.dateTimeFormat),
                            sortOrder: presentationData.nameSortOrder,
                            displayOrder: presentationData.nameDisplayOrder,
                            context: context,
                            peerMode: .generalSearch(isSavedMessages: false),
                            peer: peerContent,
                            status: status,
                            requiresPremiumForMessaging: peerEntry.requiresPremiumForMessaging,
                            enabled: enabled,
                            selection: selectable ? .selectable(selected: selected) : .none,
                            editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false),
                            index: nil,
                            header: header,
                            action: { _ in
                                if let chatPeer = chatPeer {
                                    if editing {
                                        nodeInteraction.togglePeerSelected(chatPeer, threadId)
                                    } else {
                                        nodeInteraction.peerSelected(chatPeer, nil, threadId, nil, false)
                                    }
                                }
                            }, disabledAction: (isForum && editing) && !peerEntry.requiresPremiumForMessaging ? nil : { _ in
                                if let chatPeer = chatPeer {
                                    nodeInteraction.disabledPeerSelected(chatPeer, threadId, peerEntry.requiresPremiumForMessaging ? .premiumRequired : .generic)
                                }
                            },
                            animationCache: nodeInteraction.animationCache,
                            animationRenderer: nodeInteraction.animationRenderer
                        ), directionHint: entry.directionHint)
                case .peerType:
                    let itemPeer = peer.chatMainPeer
                    var chatPeer: EnginePeer?
                    if let peer = peer.peers[peer.peerId] {
                        chatPeer = peer
                    }
                    
                    let peerContent: ContactsPeerItemPeer = .peer(peer: itemPeer, chatPeer: chatPeer)
                    let status: ContactsPeerItemStatus = .none
                    
                    return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ContactsPeerItem(
                        presentationData: ItemListPresentationData(theme: presentationData.theme, fontSize: presentationData.fontSize, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, dateTimeFormat: presentationData.dateTimeFormat),
                        sortOrder: presentationData.nameSortOrder,
                        displayOrder: presentationData.nameDisplayOrder,
                        context: context,
                        peerMode: .generalSearch(isSavedMessages: false),
                        peer: peerContent,
                        status: status,
                        requiresPremiumForMessaging: peerEntry.requiresPremiumForMessaging,
                        enabled: true,
                        selection: editing ? .selectable(selected: selected) : .none,
                        editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false),
                        index: nil,
                        header: nil,
                        action: { _ in
                            if let chatPeer = chatPeer {
                                if editing {
                                    nodeInteraction.togglePeerSelected(chatPeer, nil)
                                } else {
                                    nodeInteraction.peerSelected(chatPeer, nil, nil, nil, false)
                                }
                            }
                        }, disabledAction: peerEntry.requiresPremiumForMessaging ? { _ in
                            if let chatPeer {
                                nodeInteraction.disabledPeerSelected(chatPeer, nil, .premiumRequired)
                            }
                        } : nil,
                        animationCache: nodeInteraction.animationCache,
                        animationRenderer: nodeInteraction.animationRenderer
                    ), directionHint: entry.directionHint)
                }
            case let .HoleEntry(_, theme):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListHoleItem(theme: theme), directionHint: entry.directionHint)
            case let .GroupReferenceEntry(groupReferenceEntry):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(
                    presentationData: groupReferenceEntry.presentationData,
                    context: context,
                    chatListLocation: location,
                    filterData: filterData,
                    index: groupReferenceEntry.index,
                    content: .groupReference(ChatListItemContent.GroupReferenceData(
                        groupId: groupReferenceEntry.groupId,
                        peers: groupReferenceEntry.peers,
                        message: groupReferenceEntry.message,
                        unreadCount: groupReferenceEntry.unreadCount,
                        hiddenByDefault: groupReferenceEntry.hiddenByDefault,
                        storyState: groupReferenceEntry.storyState.flatMap { storyState in
                            return ChatListItemContent.StoryState(
                                stats: storyState.stats,
                                hasUnseenCloseFriends: storyState.hasUnseenCloseFriends
                            )
                        }
                    )),
                    editing: groupReferenceEntry.editing,
                    hasActiveRevealControls: false,
                    selected: false,
                    header: nil,
                    enableContextActions: true,
                    hiddenOffset: groupReferenceEntry.hiddenByDefault && !groupReferenceEntry.revealed,
                    interaction: nodeInteraction
                ), directionHint: entry.directionHint)
            case let .ContactEntry(contactEntry):
                let header: ChatListSearchItemHeader? = nil
                
                var status: ContactsPeerItemStatus = .none
                status = .presence(contactEntry.presence, contactEntry.presentationData.dateTimeFormat)
            
                let presentationData = contactEntry.presentationData
            
                let peerContent: ContactsPeerItemPeer = .peer(peer: contactEntry.peer, chatPeer: contactEntry.peer)

                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ContactsPeerItem(
                    presentationData: ItemListPresentationData(theme: presentationData.theme, fontSize: presentationData.fontSize, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, dateTimeFormat: presentationData.dateTimeFormat),
                    sortOrder: presentationData.nameSortOrder,
                    displayOrder: presentationData.nameDisplayOrder,
                    context: context,
                    peerMode: .generalSearch(isSavedMessages: false),
                    peer: peerContent,
                    status: status,
                    enabled: true,
                    selection: .none,
                    editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false),
                    index: nil,
                    header: header,
                    action: { _ in
                        nodeInteraction.peerSelected(contactEntry.peer, nil, nil, nil, false)
                    },
                    disabledAction: nil,
                    animationCache: nodeInteraction.animationCache,
                    animationRenderer: nodeInteraction.animationRenderer
                ), directionHint: entry.directionHint)
            case let .ArchiveIntro(presentationData):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListArchiveInfoItem(theme: presentationData.theme, strings: presentationData.strings), directionHint: entry.directionHint)
            case let .EmptyIntro(presentationData):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListEmptyInfoItem(theme: presentationData.theme, strings: presentationData.strings), directionHint: entry.directionHint)
            case let .SectionHeader(presentationData, displayHide):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListSectionHeaderItem(theme: presentationData.theme, strings: presentationData.strings, hide: displayHide ? {
                    hideChatListContacts(context: context)
                } : nil), directionHint: entry.directionHint)
            case let .Notice(presentationData, notice):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListNoticeItem(context: context, theme: presentationData.theme, strings: presentationData.strings, notice: notice, action: { [weak nodeInteraction] action in
                    switch action {
                    case .activate:
                        switch notice {
                        case .clearStorage:
                            nodeInteraction?.openStorageManagement()
                        case .setupPassword:
                            nodeInteraction?.openPasswordSetup()
                        case .premiumUpgrade, .premiumAnnualDiscount, .premiumRestore:
                            nodeInteraction?.openPremiumIntro()
                        case .xmasPremiumGift:
                            nodeInteraction?.openPremiumGift([], nil)
                        case .premiumGrace:
                            nodeInteraction?.openPremiumManagement()
                        case .setupBirthday:
                            nodeInteraction?.openBirthdaySetup()
                        case let .birthdayPremiumGift(peers, birthdays):
                            nodeInteraction?.openPremiumGift(peers, birthdays)
                        case .reviewLogin:
                            break
                        case let .starsSubscriptionLowBalance(amount, _):
                            nodeInteraction?.openStarsTopup(amount.value)
                        case .setupPhoto:
                            nodeInteraction?.openPhotoSetup()
                        }
                    case .hide:
                        nodeInteraction?.dismissNotice(notice)
                    case let .buttonChoice(isPositive):
                        switch notice {
                        case let .reviewLogin(newSessionReview, _):
                            nodeInteraction?.performActiveSessionAction(newSessionReview, isPositive)
                        default:
                            break
                        }
                    }
                }), directionHint: entry.directionHint)
        }
    }
}

private func mappedUpdateEntries(context: AccountContext, nodeInteraction: ChatListNodeInteraction, location: ChatListControllerLocation, isPremium: Bool, filterData: ChatListItemFilterData?, chatListFilters: [ChatListFilter]?, mode: ChatListNodeMode, isPeerEnabled: ((EnginePeer) -> Bool)?, entries: [ChatListNodeViewTransitionUpdateEntry]) -> [ListViewUpdateItem] {
    return entries.map { entry -> ListViewUpdateItem in
        switch entry.entry {
            case let .PeerEntry(peerEntry):
                let index = peerEntry.index
                let presentationData = peerEntry.presentationData
                let combinedReadState = peerEntry.readState
                let isRemovedFromTotalUnreadCount = peerEntry.isRemovedFromTotalUnreadCount
                let draftState = peerEntry.draftState
                let peer = peerEntry.peer
                let threadInfo = peerEntry.threadInfo
                let presence = peerEntry.presence
                let hasUnseenMentions = peerEntry.hasUnseenMentions
                let hasUnseenReactions = peerEntry.hasUnseenReactions
                let editing = peerEntry.editing
                let hasActiveRevealControls = peerEntry.hasActiveRevealControls
                let selected = peerEntry.selected
                let inputActivities = peerEntry.inputActivities
                let promoInfo = peerEntry.promoInfo
                let hasFailedMessages = peerEntry.hasFailedMessages
                let isContact = peerEntry.isContact
                let forumTopicData = peerEntry.forumTopicData
                let topForumTopicItems = peerEntry.topForumTopicItems
                let revealed = peerEntry.revealed
            
                switch mode {
                    case .chatList:
                        return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(
                            presentationData: presentationData,
                            context: context,
                            chatListLocation: location,
                            filterData: filterData,
                            index: index,
                            content: .peer(ChatListItemContent.PeerData(
                                messages: peerEntry.messages,
                                peer: peer,
                                threadInfo: threadInfo,
                                combinedReadState: combinedReadState,
                                isRemovedFromTotalUnreadCount: isRemovedFromTotalUnreadCount,
                                presence: presence,
                                hasUnseenMentions: hasUnseenMentions,
                                hasUnseenReactions: hasUnseenReactions,
                                draftState: draftState,
                                mediaDraftContentType: peerEntry.mediaDraftContentType,
                                inputActivities: inputActivities,
                                promoInfo: promoInfo,
                                ignoreUnreadBadge: false,
                                displayAsMessage: false,
                                hasFailedMessages: hasFailedMessages,
                                forumTopicData: forumTopicData,
                                topForumTopicItems: topForumTopicItems,
                                autoremoveTimeout: peerEntry.autoremoveTimeout,
                                storyState: peerEntry.storyState.flatMap { storyState in
                                    return ChatListItemContent.StoryState(
                                        stats: storyState.stats,
                                        hasUnseenCloseFriends: storyState.hasUnseenCloseFriends
                                    )
                                },
                                requiresPremiumForMessaging: peerEntry.requiresPremiumForMessaging,
                                displayAsTopicList: peerEntry.displayAsTopicList,
                                tags: chatListItemTags(location: location, accountPeerId: context.account.peerId, isPremium: isPremium, peer: peer.chatMainPeer, isUnread: combinedReadState?.isUnread ?? false, isMuted: isRemovedFromTotalUnreadCount, isContact: isContact, hasUnseenMentions: hasUnseenMentions, chatListFilters: chatListFilters)
                            )),
                            editing: editing,
                            hasActiveRevealControls: hasActiveRevealControls,
                            selected: selected,
                            header: nil,
                            enableContextActions: true,
                            hiddenOffset: threadInfo?.isHidden == true && !revealed,
                            interaction: nodeInteraction
                    ), directionHint: entry.directionHint)
                    case let .peers(filter, isSelecting, _, filters, displayAutoremoveTimeout, displayPresence):
                        let itemPeer = peer.chatMainPeer
                        var chatPeer: EnginePeer?
                        if let peer = peer.peers[peer.peerId] {
                            chatPeer = peer
                        }
                        var enabled = true
                        if let isPeerEnabled {
                            if let itemPeer {
                                enabled = isPeerEnabled(itemPeer)
                            }
                        } else {
                            if filter.contains(.onlyWriteable) {
                                if let peer = peer.peers[peer.peerId] {
                                    if !canSendMessagesToPeer(peer._asPeer()) {
                                        enabled = false
                                    }
                                    if peerEntry.requiresPremiumForMessaging {
                                        enabled = false
                                    }
                                } else {
                                    enabled = false
                                }
                                
                                if let threadInfo, threadInfo.isClosed, case let .channel(channel) = itemPeer {
                                    if threadInfo.isOwnedByMe || channel.hasPermission(.manageTopics) {
                                    } else {
                                        enabled = false
                                    }
                                }
                            }
                            if filter.contains(.excludeChannels) {
                                if case let .channel(peer) = peer.chatMainPeer, case .broadcast = peer.info {
                                    enabled = false
                                }
                            }
                        }
                            
                        var header: ChatListSearchItemHeader?
                        switch mode {
                        case let .peers(_, _, additionalCategories, _, _, _):
                            if !additionalCategories.isEmpty {
                                let headerType: ChatListSearchItemHeaderType
                                if case .action = additionalCategories[0].appearance {
                                    // TODO: hack, generalize
                                    headerType = .orImportIntoAnExistingGroup
                                } else {
                                    headerType = .chats
                                }
                                header = ChatListSearchItemHeader(type: headerType, theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil)
                            }
                        default:
                            break
                        }
                        
                        var status: ContactsPeerItemStatus = .none
                        if isSelecting, let itemPeer = itemPeer {
                            if displayPresence, let presence = presence {
                                status = .presence(presence, presentationData.dateTimeFormat)
                            } else if let (string, multiline, isActive, icon) = statusStringForPeerType(accountPeerId: context.account.peerId, strings: presentationData.strings, peer: itemPeer, isMuted: isRemovedFromTotalUnreadCount, isUnread: combinedReadState?.isUnread ?? false, isContact: isContact, hasUnseenMentions: hasUnseenMentions, chatListFilters: filters, displayAutoremoveTimeout: displayAutoremoveTimeout, autoremoveTimeout: peerEntry.autoremoveTimeout) {
                                status = .custom(string: string, multiline: multiline, isActive: isActive, icon: icon)
                            } else {
                                status = .none
                            }
                        }
                    
                        let peerContent: ContactsPeerItemPeer
                        if let threadInfo = threadInfo, let itemPeer = itemPeer {
                            peerContent = .thread(peer: itemPeer, title: threadInfo.info.title, icon: threadInfo.info.icon, color: threadInfo.info.iconColor)
                        } else {
                            peerContent = .peer(peer: itemPeer, chatPeer: chatPeer)
                        }
                    
                        var threadId: Int64?
                        switch index {
                        case let .forum(_, _, threadIdValue, _, _):
                            threadId = threadIdValue
                        case .chatList:
                            break
                        }
                        
                        var isForum = false
                        if let peer = chatPeer, case let .channel(channel) = peer, channel.flags.contains(.isForum) {
                            isForum = true
                            if editing, case .chatList = mode {
                                enabled = false
                            }
                        }
                    
                        var selectable = editing
                        if case .chatList = mode {
                            if isForum {
                                selectable = false
                            }
                        }
                    
                        return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ContactsPeerItem(
                            presentationData: ItemListPresentationData(theme: presentationData.theme, fontSize: presentationData.fontSize, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, dateTimeFormat: presentationData.dateTimeFormat),
                            sortOrder: presentationData.nameSortOrder,
                            displayOrder: presentationData.nameDisplayOrder,
                            context: context,
                            peerMode: .generalSearch(isSavedMessages: false),
                            peer: peerContent,
                            status: status,
                            requiresPremiumForMessaging: peerEntry.requiresPremiumForMessaging,
                            enabled: enabled,
                            selection: selectable ? .selectable(selected: selected) : .none,
                            editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false),
                            index: nil,
                            header: header,
                            action: { _ in
                                if let chatPeer = chatPeer {
                                    if editing {
                                        nodeInteraction.togglePeerSelected(chatPeer, threadId)
                                    } else {
                                        nodeInteraction.peerSelected(chatPeer, nil, threadId, nil, false)
                                    }
                                }
                            }, disabledAction: (isForum && editing) && !peerEntry.requiresPremiumForMessaging ? nil : { _ in
                                if let chatPeer = chatPeer {
                                    nodeInteraction.disabledPeerSelected(chatPeer, threadId, peerEntry.requiresPremiumForMessaging ? .premiumRequired : .generic)
                                }
                            },
                            animationCache: nodeInteraction.animationCache,
                            animationRenderer: nodeInteraction.animationRenderer
                        ), directionHint: entry.directionHint)
                    case .peerType:
                        let itemPeer = peer.chatMainPeer
                        var chatPeer: EnginePeer?
                        if let peer = peer.peers[peer.peerId] {
                            chatPeer = peer
                        }
                        
                        let peerContent: ContactsPeerItemPeer = .peer(peer: itemPeer, chatPeer: chatPeer)
                        let status: ContactsPeerItemStatus = .none
                        
                        return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ContactsPeerItem(
                            presentationData: ItemListPresentationData(theme: presentationData.theme, fontSize: presentationData.fontSize, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, dateTimeFormat: presentationData.dateTimeFormat),
                            sortOrder: presentationData.nameSortOrder,
                            displayOrder: presentationData.nameDisplayOrder,
                            context: context,
                            peerMode: .generalSearch(isSavedMessages: false),
                            peer: peerContent,
                            status: status,
                            requiresPremiumForMessaging: peerEntry.requiresPremiumForMessaging,
                            enabled: true,
                            selection: editing ? .selectable(selected: selected) : .none,
                            editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false),
                            index: nil,
                            header: nil,
                            action: { _ in
                                if let chatPeer = chatPeer {
                                    if editing {
                                        nodeInteraction.togglePeerSelected(chatPeer, nil)
                                    } else {
                                        nodeInteraction.peerSelected(chatPeer, nil, nil, nil, false)
                                    }
                                }
                            }, disabledAction: peerEntry.requiresPremiumForMessaging ? { _ in
                                if let chatPeer {
                                    nodeInteraction.disabledPeerSelected(chatPeer, nil, .premiumRequired)
                                }
                            } : nil,
                            animationCache: nodeInteraction.animationCache,
                            animationRenderer: nodeInteraction.animationRenderer
                        ), directionHint: entry.directionHint)
                }
            case let .HoleEntry(_, theme):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListHoleItem(theme: theme), directionHint: entry.directionHint)
            case let .GroupReferenceEntry(groupReferenceEntry):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(
                        presentationData: groupReferenceEntry.presentationData,
                        context: context,
                        chatListLocation: location,
                        filterData: filterData,
                        index: groupReferenceEntry.index,
                        content: .groupReference(ChatListItemContent.GroupReferenceData(
                            groupId: groupReferenceEntry.groupId,
                            peers: groupReferenceEntry.peers,
                            message: groupReferenceEntry.message,
                            unreadCount: groupReferenceEntry.unreadCount,
                            hiddenByDefault: groupReferenceEntry.hiddenByDefault,
                            storyState: groupReferenceEntry.storyState.flatMap { storyState in
                                return ChatListItemContent.StoryState(
                                    stats: storyState.stats,
                                    hasUnseenCloseFriends: storyState.hasUnseenCloseFriends
                                )
                            }
                        )),
                        editing: groupReferenceEntry.editing,
                        hasActiveRevealControls: false,
                        selected: false,
                        header: nil,
                        enableContextActions: true,
                        hiddenOffset: groupReferenceEntry.hiddenByDefault && !groupReferenceEntry.revealed,
                        interaction: nodeInteraction
                ), directionHint: entry.directionHint)
            case let .ContactEntry(contactEntry):
                let header: ChatListSearchItemHeader? = nil
                
                var status: ContactsPeerItemStatus = .none
                status = .presence(contactEntry.presence, contactEntry.presentationData.dateTimeFormat)
            
                let presentationData = contactEntry.presentationData
            
                let peerContent: ContactsPeerItemPeer = .peer(peer: contactEntry.peer, chatPeer: contactEntry.peer)

                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ContactsPeerItem(
                    presentationData: ItemListPresentationData(theme: presentationData.theme, fontSize: presentationData.fontSize, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, dateTimeFormat: presentationData.dateTimeFormat),
                    sortOrder: presentationData.nameSortOrder,
                    displayOrder: presentationData.nameDisplayOrder,
                    context: context,
                    peerMode: .generalSearch(isSavedMessages: false),
                    peer: peerContent,
                    status: status,
                    enabled: true,
                    selection: .none,
                    editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false),
                    index: nil,
                    header: header,
                    action: { _ in
                        nodeInteraction.peerSelected(contactEntry.peer, nil, nil, nil, false)
                    },
                    disabledAction: nil,
                    animationCache: nodeInteraction.animationCache,
                    animationRenderer: nodeInteraction.animationRenderer
                ), directionHint: entry.directionHint)
            case let .ArchiveIntro(presentationData):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListArchiveInfoItem(theme: presentationData.theme, strings: presentationData.strings), directionHint: entry.directionHint)
            case let .EmptyIntro(presentationData):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListEmptyInfoItem(theme: presentationData.theme, strings: presentationData.strings), directionHint: entry.directionHint)
            case let .SectionHeader(presentationData, displayHide):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListSectionHeaderItem(theme: presentationData.theme, strings: presentationData.strings, hide: displayHide ? {
                    hideChatListContacts(context: context)
                } : nil), directionHint: entry.directionHint)
            case let .Notice(presentationData, notice):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListNoticeItem(context: context, theme: presentationData.theme, strings: presentationData.strings, notice: notice, action: { [weak nodeInteraction] action in
                    switch action {
                    case .activate:
                        switch notice {
                        case .clearStorage:
                            nodeInteraction?.openStorageManagement()
                        case .setupPassword:
                            nodeInteraction?.openPasswordSetup()
                        case .premiumUpgrade, .premiumAnnualDiscount, .premiumRestore:
                            nodeInteraction?.openPremiumIntro()
                        case .xmasPremiumGift:
                            nodeInteraction?.openPremiumGift([], nil)
                        case .premiumGrace:
                            nodeInteraction?.openPremiumManagement()
                        case .setupBirthday:
                            nodeInteraction?.openBirthdaySetup()
                        case let .birthdayPremiumGift(peers, birthdays):
                            nodeInteraction?.openPremiumGift(peers, birthdays)
                        case .reviewLogin:
                            break
                        case let .starsSubscriptionLowBalance(amount, _):
                            nodeInteraction?.openStarsTopup(amount.value)
                        case .setupPhoto:
                            nodeInteraction?.openPhotoSetup()
                        }
                    case .hide:
                        nodeInteraction?.dismissNotice(notice)
                    case let .buttonChoice(isPositive):
                        switch notice {
                        case let .reviewLogin(newSessionReview, _):
                            nodeInteraction?.performActiveSessionAction(newSessionReview, isPositive)
                        default:
                            break
                        }
                    }
                }), directionHint: entry.directionHint)
            case .HeaderEntry:
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListEmptyHeaderItem(), directionHint: entry.directionHint)
            case let .AdditionalCategory(index: _, id, title, image, appearance, selected, presentationData):
                var header: ChatListSearchItemHeader?
                if case .peerType = mode {
                } else {
                    if case .action = appearance {
                        // TODO: hack, generalize
                        header = ChatListSearchItemHeader(type: .orImportIntoAnExistingGroup, theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil)
                    }
                }
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListAdditionalCategoryItem(
                    presentationData: ItemListPresentationData(theme: presentationData.theme, fontSize: presentationData.fontSize, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, dateTimeFormat: presentationData.dateTimeFormat),
                    context: context,
                    title: title,
                    image: image,
                    appearance: appearance,
                    isSelected: selected,
                    header: header,
                    action: {
                        nodeInteraction.additionalCategorySelected(id)
                    }
                ), directionHint: entry.directionHint)
        }
    }
}

private func mappedChatListNodeViewListTransition(context: AccountContext, nodeInteraction: ChatListNodeInteraction, location: ChatListControllerLocation, isPremium: Bool, filterData: ChatListItemFilterData?, chatListFilters: [ChatListFilter]?, mode: ChatListNodeMode, isPeerEnabled: ((EnginePeer) -> Bool)?, transition: ChatListNodeViewTransition) -> ChatListNodeListViewTransition {
    return ChatListNodeListViewTransition(chatListView: transition.chatListView, deleteItems: transition.deleteItems, insertItems: mappedInsertEntries(context: context, nodeInteraction: nodeInteraction, location: location, isPremium: isPremium, filterData: filterData, chatListFilters: chatListFilters, mode: mode, isPeerEnabled: isPeerEnabled, entries: transition.insertEntries), updateItems: mappedUpdateEntries(context: context, nodeInteraction: nodeInteraction, location: location, isPremium: isPremium, filterData: filterData, chatListFilters: chatListFilters, mode: mode, isPeerEnabled: isPeerEnabled, entries: transition.updateEntries), options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, adjustScrollToFirstItem: transition.adjustScrollToFirstItem, animateCrossfade: transition.animateCrossfade)
}

private final class ChatListOpaqueTransactionState {
    let chatListView: ChatListNodeView
    
    init(chatListView: ChatListNodeView) {
        self.chatListView = chatListView
    }
}

public enum ChatListSelectionOption {
    case previous(unread: Bool)
    case next(unread: Bool)
    case peerId(EnginePeer.Id)
    case index(Int)
}

public enum ChatListGlobalScrollOption {
    case none
    case top
    case unread
}

public enum ChatListNodeScrollPosition {
    case top(adjustForTempInset: Bool)
}

public enum ChatListNodeEmptyState: Equatable {
    case notEmpty(containsChats: Bool, onlyArchive: Bool, onlyGeneralThread: Bool)
    case empty(isLoading: Bool, hasArchiveInfo: Bool)
}

public final class ChatListNode: ListView {
    public enum OpenStoriesSubject {
        case peer(EnginePeer.Id)
        case archive
    }
    
    private let fillPreloadItems: Bool
    private let context: AccountContext
    private let location: ChatListControllerLocation
    private let mode: ChatListNodeMode
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    
    private let _ready = ValuePromise<Bool>()
    private var didSetReady = false
    public var ready: Signal<Bool, NoError> {
        return _ready.get()
    }
    
    private let _contentsReady = ValuePromise<Bool>()
    private var didSetContentsReady = false
    public var contentsReady: Signal<Bool, NoError> {
        return _contentsReady.get()
    }
    
    public var peerSelected: ((EnginePeer, Int64?, Bool, Bool, ChatListNodeEntryPromoInfo?) -> Void)?
    public var disabledPeerSelected: ((EnginePeer, Int64?, ChatListDisabledPeerReason) -> Void)?
    public var additionalCategorySelected: ((Int) -> Void)?
    public var groupSelected: ((EngineChatList.Group) -> Void)?
    public var addContact: ((String) -> Void)?
    public var activateSearch: (() -> Void)?
    public var deletePeerChat: ((EnginePeer.Id, Bool) -> Void)?
    public var deletePeerThread: ((EnginePeer.Id, Int64) -> Void)?
    public var setPeerThreadStopped: ((EnginePeer.Id, Int64, Bool) -> Void)?
    public var setPeerThreadPinned: ((EnginePeer.Id, Int64, Bool) -> Void)?
    public var setPeerThreadHidden: ((EnginePeer.Id, Int64, Bool) -> Void)?
    public var updatePeerGrouping: ((EnginePeer.Id, Bool) -> Void)?
    public var presentAlert: ((String) -> Void)?
    public var present: ((ViewController) -> Void)?
    public var push: ((ViewController) -> Void)?
    public var toggleArchivedFolderHiddenByDefault: (() -> Void)?
    public var hidePsa: ((EnginePeer.Id) -> Void)?
    public var activateChatPreview: ((ChatListItem, Int64?, ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?
    public var openStories: ((ChatListNode.OpenStoriesSubject, ASDisplayNode?) -> Void)?
    public var openBirthdaySetup: (() -> Void)?
    public var openPremiumManagement: (() -> Void)?
    public var openStarsTopup: ((Int64?) -> Void)?
    public var openWebApp: ((TelegramUser) -> Void)?
    public var openPhotoSetup: (() -> Void)?
    public var openAdInfo: ((ASDisplayNode) -> Void)?
    
    private var theme: PresentationTheme
    
    private let viewProcessingQueue = Queue()
    private var chatListView: ChatListNodeView?
    public var entriesCount: Int {
        if let chatListView = self.chatListView {
            return chatListView.filteredEntries.count
        } else {
            return 0
        }
    }
    public var entryPeerIds: [EnginePeer.Id] {
        if let chatListView = self.chatListView {
            return chatListView.filteredEntries.compactMap { item -> EnginePeer.Id? in
                switch item.stableId {
                case .Header, .Hole:
                    return nil
                case let .PeerId(value):
                    return PeerId(value)
                case .ThreadId, .GroupId, .ContactId, .ArchiveIntro, .EmptyIntro, .SectionHeader, .Notice, .additionalCategory:
                    return nil
                }
            }
        } else {
            return []
        }
    }
    private var interaction: ChatListNodeInteraction?
    
    private var dequeuedInitialTransitionOnLayout = false
    private var enqueuedTransition: (ChatListNodeListViewTransition, () -> Void)?
    
    public private(set) var currentState: ChatListNodeState
    private let statePromise: ValuePromise<ChatListNodeState>
    public var state: Signal<ChatListNodeState, NoError> {
        return self.statePromise.get()
    }
    
    private var currentLocation: ChatListNodeLocation?
    public private(set) var chatListFilter: ChatListFilter? {
        didSet {
            self.chatListFilterValue.set(.single(self.chatListFilter))
            
            if self.chatListFilter != oldValue {
                self.setChatListLocation(.initial(count: 50, filter: self.chatListFilter))
            }
        }
    }
    private let updatedFilterDisposable = MetaDisposable()
    private let chatListFilterValue = Promise<ChatListFilter?>()
    var chatListFilterSignal: Signal<ChatListFilter?, NoError> {
        return self.chatListFilterValue.get()
    }
    private var hasUpdatedAppliedChatListFilterValueOnce = false
    private var currentAppliedChatListFilterValue: ChatListFilter?
    private let appliedChatListFilterValue = Promise<ChatListFilter?>()
    var appliedChatListFilterSignal: Signal<ChatListFilter?, NoError> {
        return self.appliedChatListFilterValue.get()
    }
    private let chatListLocation = ValuePromise<ChatListNodeLocation>()
    private let chatListDisposable = MetaDisposable()
    private var activityStatusesDisposable: Disposable?
    
    private let scrollToTopOptionPromise = Promise<ChatListGlobalScrollOption>(.none)
    public var scrollToTopOption: Signal<ChatListGlobalScrollOption, NoError> {
        return self.scrollToTopOptionPromise.get()
    }
    
    private let scrolledAtTop = ValuePromise<Bool>(true)
    private var scrolledAtTopValue: Bool = true {
        didSet {
            if self.scrolledAtTopValue != oldValue {
                self.scrolledAtTop.set(self.scrolledAtTopValue)
            }
        }
    }
    
    public var contentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)?
    public var contentScrollingEnded: ((ListView) -> Bool)?
    public var didBeginInteractiveDragging: ((ListView) -> Void)?
    
    public var isEmptyUpdated: ((ChatListNodeEmptyState, Bool, ContainedViewLayoutTransition) -> Void)?
    private var currentIsEmptyState: ChatListNodeEmptyState?
    
    public var canExpandHiddenItems: (() -> Bool)?
    
    public var addedVisibleChatsWithPeerIds: (([EnginePeer.Id]) -> Void)?
    
    private let currentRemovingItemId = Atomic<ChatListNodeState.ItemId?>(value: nil)
    public func setCurrentRemovingItemId(_ itemId: ChatListNodeState.ItemId?) {
        let _ = self.currentRemovingItemId.swap(itemId)
    }
    
    private var hapticFeedback: HapticFeedback?
    
    let preloadItems = Promise<[ChatHistoryPreloadItem]>([])
    
    var didBeginSelectingChats: (() -> Void)?
    public var selectionCountChanged: ((Int) -> Void)?
    
    var isSelectionGestureEnabled = true
    
    public var selectionLimit: Int32 = 100
    public var reachedSelectionLimit: ((Int32) -> Void)?
    
    private var visibleTopInset: CGFloat?
    private var originalTopInset: CGFloat?
    
    public var passthroughPeerSelection = false
    
    let hideArhiveIntro = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    private let chatFolderUpdates = Promise<ChatFolderUpdates?>()
    private var pollFilterUpdatesDisposable: Disposable?
    private var chatFilterUpdatesDisposable: Disposable?
    private var updateIsMainTabDisposable: Disposable?
    
    public var scrollHeightTopInset: CGFloat {
        didSet {
            self.keepMinimalScrollHeightWithTopInset = self.scrollHeightTopInset
        }
    }
    
    public var startedScrollingAtUpperBound: Bool = false
    
    private let autoSetReady: Bool
    
    public let isMainTab = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let suggestedChatListNotice = Promise<ChatListNotice?>(nil)
    
    public var synchronousDrawingWhenNotAnimated: Bool = false
    
    public init(context: AccountContext, location: ChatListControllerLocation, chatListFilter: ChatListFilter? = nil, previewing: Bool, fillPreloadItems: Bool, mode: ChatListNodeMode, isPeerEnabled: ((EnginePeer) -> Bool)? = nil, theme: PresentationTheme, fontSize: PresentationFontSize, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, disableAnimations: Bool, isInlineMode: Bool, autoSetReady: Bool, isMainTab: Bool?) {
        self.context = context
        self.location = location
        self.chatListFilter = chatListFilter
        self.chatListFilterValue.set(.single(chatListFilter))
        self.fillPreloadItems = fillPreloadItems
        self.mode = mode
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.autoSetReady = autoSetReady
        
        if let isMainTab {
            self.isMainTab.set(isMainTab)
        }
        
        var isSelecting = false
        if case .peers(_, true, _, _, _, _) = mode {
            isSelecting = true
        }
        
        self.currentState = ChatListNodeState(presentationData: ChatListPresentationData(theme: theme, fontSize: fontSize, strings: strings, dateTimeFormat: dateTimeFormat, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, disableAnimations: disableAnimations), editing: isSelecting, peerIdWithRevealedOptions: nil, selectedPeerIds: Set(), foundPeers: [], selectedPeerMap: [:], selectedAdditionalCategoryIds: Set(), peerInputActivities: nil, pendingRemovalItemIds: Set(), pendingClearHistoryPeerIds: Set(), hiddenItemShouldBeTemporaryRevealed: false, hiddenPsaPeerId: nil, selectedThreadIds: Set(), archiveStoryState: nil)
        self.statePromise = ValuePromise(self.currentState, ignoreRepeated: true)
        
        self.theme = theme
        
        self.scrollHeightTopInset = ChatListNavigationBar.searchScrollHeight
        
        super.init()
        
        if case .internal = context.sharedContext.applicationBindings.appBuildType {
            //self.useMainQueueTransactions = true
        }
        
        self.verticalScrollIndicatorColor = theme.list.scrollIndicatorColor
        self.verticalScrollIndicatorFollowsOverscroll = true
        
        self.keepMinimalScrollHeightWithTopInset = self.scrollHeightTopInset
        
        let nodeInteraction = ChatListNodeInteraction(context: context, animationCache: self.animationCache, animationRenderer: self.animationRenderer, activateSearch: { [weak self] in
            if let strongSelf = self, let activateSearch = strongSelf.activateSearch {
                activateSearch()
            }
        }, peerSelected: { [weak self] peer, _, threadId, promoInfo, _ in
            if let strongSelf = self, let peerSelected = strongSelf.peerSelected {
                peerSelected(peer, threadId, true, true, promoInfo)
            }
        }, disabledPeerSelected: { [weak self] peer, threadId, reason in
            if let strongSelf = self, let disabledPeerSelected = strongSelf.disabledPeerSelected {
                disabledPeerSelected(peer, threadId, reason)
            }
        }, togglePeerSelected: { [weak self] peer, _ in
            guard let strongSelf = self else {
                return
            }
            if case .peers = strongSelf.mode, strongSelf.passthroughPeerSelection {
                if let strongSelf = self, let peerSelected = strongSelf.peerSelected {
                    peerSelected(peer, nil, true, true, nil)
                }
                return
            }
            var didBeginSelecting = false
            var count = 0
            strongSelf.updateState { [weak self] state in
                var state = state
                if state.selectedPeerIds.contains(peer.id) {
                    state.selectedPeerIds.remove(peer.id)
                } else {
                    if state.selectedPeerIds.count < strongSelf.selectionLimit {
                        if state.selectedPeerIds.isEmpty {
                            didBeginSelecting = true
                        }
                        state.selectedPeerIds.insert(peer.id)
                        state.selectedPeerMap[peer.id] = peer
                    } else {
                        self?.reachedSelectionLimit?(Int32(state.selectedPeerIds.count))
                    }
                }
                count = state.selectedPeerIds.count
                return state
            }
            strongSelf.selectionCountChanged?(count)
            if didBeginSelecting {
                strongSelf.didBeginSelectingChats?()
            }
        }, togglePeersSelection: { [weak self] peers, selected in
            self?.updateState { state in
                var state = state
                if selected {
                    for peerEntry in peers {
                        switch peerEntry {
                            case let .peer(peer):
                                state.selectedPeerIds.insert(peer.id)
                                state.selectedPeerMap[peer.id] = peer
                            case let .peerId(peerId):
                                state.selectedPeerIds.insert(peerId)
                        }
                    }
                } else {
                    for peerEntry in peers {
                        switch peerEntry {
                            case let .peer(peer):
                                state.selectedPeerIds.remove(peer.id)
                            case let .peerId(peerId):
                                state.selectedPeerIds.remove(peerId)
                        }
                    }
                }
                return state
            }
            if selected && !peers.isEmpty {
                self?.didBeginSelectingChats?()
            }
        }, additionalCategorySelected: { [weak self] id in
            self?.additionalCategorySelected?(id)
        }, messageSelected: { [weak self] peer, threadId, message, promoInfo in
            if let strongSelf = self, let peerSelected = strongSelf.peerSelected {
                var activateInput = false
                for media in message.media {
                    if let action = media as? TelegramMediaAction {
                        switch action.action {
                            case .peerJoined, .groupCreated, .channelMigratedFromGroup, .historyCleared:
                                activateInput = true
                            default:
                                break
                        }
                    }
                }
                peerSelected(peer, threadId, true, activateInput, promoInfo)
            }
        }, groupSelected: { [weak self] groupId in
            if let strongSelf = self, let groupSelected = strongSelf.groupSelected {
                groupSelected(groupId)
            }
        }, addContact: { _ in
        }, setPeerIdWithRevealedOptions: { [weak self] peerId, fromPeerId in
            if let strongSelf = self {
                strongSelf.updateState { state in
                    if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions?.peerId) || (peerId != nil && fromPeerId == nil) || (peerId == nil && fromPeerId == nil) {
                        var state = state
                        if let peerId = peerId {
                            state.peerIdWithRevealedOptions = ChatListNodeState.ItemId(peerId: peerId, threadId: nil)
                        } else {
                            state.peerIdWithRevealedOptions = nil
                        }
                        return state
                    } else {
                        return state
                    }
                }
            }
        }, setItemPinned: { [weak self] itemId, _ in
            if case .savedMessagesChats = location {
                if case let .peer(itemPeerId) = itemId {
                    let _ = (context.engine.peers.toggleForumChannelTopicPinned(id: context.account.peerId, threadId: itemPeerId.toInt64())
                    |> deliverOnMainQueue).start(error: { error in
                        guard let self else {
                            return
                        }
                        switch error {
                        case let .limitReached(count):
                            var replaceImpl: ((ViewController) -> Void)?
                            let controller = PremiumLimitScreen(context: context, subject: .pinnedSavedPeers, count: Int32(count), action: {
                                let premiumScreen = PremiumIntroScreen(context: context, source: .pinnedChats)
                                replaceImpl?(premiumScreen)
                                return true
                            })
                            self.push?(controller)
                            replaceImpl = { [weak controller] c in
                                controller?.replace(with: c)
                            }
                        default:
                            break
                        }
                    })
                }
            } else {
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                |> deliverOnMainQueue).startStandalone(next: { peer in
                    guard let strongSelf = self else {
                        return
                    }
                    guard case let .chatList(groupId) = strongSelf.location else {
                        return
                    }
                    
                    let isPremium = peer?.isPremium ?? false
                    let location: TogglePeerChatPinnedLocation
                    if let chatListFilter = chatListFilter {
                        location = .filter(chatListFilter.id)
                    } else {
                        location = .group(groupId._asGroup())
                    }
                    let _ = (context.engine.peers.toggleItemPinned(location: location, itemId: itemId)
                    |> deliverOnMainQueue).startStandalone(next: { result in
                        if let strongSelf = self {
                            switch result {
                            case .done:
                                break
                            case let .limitExceeded(count, _):
                                if isPremium {
                                    if case .filter = location {
                                        let controller = PremiumLimitScreen(context: context, subject: .chatsPerFolder, count: Int32(count), action: {
                                            return true
                                        })
                                        strongSelf.push?(controller)
                                    } else {
                                        let controller = PremiumLimitScreen(context: context, subject: .pins, count: Int32(count), action: {
                                            return true
                                        })
                                        strongSelf.push?(controller)
                                    }
                                } else {
                                    if case .filter = location {
                                        var replaceImpl: ((ViewController) -> Void)?
                                        let controller = PremiumLimitScreen(context: context, subject: .chatsPerFolder, count: Int32(count), action: {
                                            let premiumScreen = PremiumIntroScreen(context: context, source: .pinnedChats)
                                            replaceImpl?(premiumScreen)
                                            return true
                                        })
                                        strongSelf.push?(controller)
                                        replaceImpl = { [weak controller] c in
                                            controller?.replace(with: c)
                                        }
                                    } else {
                                        var replaceImpl: ((ViewController) -> Void)?
                                        let controller = PremiumLimitScreen(context: context, subject: .pins, count: Int32(count), action: {
                                            let premiumScreen = PremiumIntroScreen(context: context, source: .pinnedChats)
                                            replaceImpl?(premiumScreen)
                                            return true
                                        })
                                        strongSelf.push?(controller)
                                        replaceImpl = { [weak controller] c in
                                            controller?.replace(with: c)
                                        }
                                    }
                                }
                            }
                        }
                    })
                })
            }
        }, setPeerMuted: { [weak self] peerId, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerId, threadId: nil))
            let _ = (context.engine.peers.togglePeerMuted(peerId: peerId, threadId: nil)
            |> deliverOnMainQueue).startStandalone(completed: {
                self?.updateState { state in
                    var state = state
                    state.peerIdWithRevealedOptions = nil
                    return state
                }
                self?.setCurrentRemovingItemId(nil)
            })
        }, setPeerThreadMuted: { [weak self] peerId, threadId, value in
            self?.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerId, threadId: threadId))
            let _ = (context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: value ? Int32.max : 0)
            |> deliverOnMainQueue).startStandalone(completed: {
                self?.updateState { state in
                    var state = state
                    state.peerIdWithRevealedOptions = nil
                    return state
                }
                self?.setCurrentRemovingItemId(nil)
            })
        }, deletePeer: { [weak self] peerId, joined in
            self?.deletePeerChat?(peerId, joined)
        }, deletePeerThread: { [weak self] peerId, threadId in
            self?.deletePeerThread?(peerId, threadId)
        }, setPeerThreadStopped: { [weak self] peerId, threadId, isStopped in
            self?.setPeerThreadStopped?(peerId, threadId, isStopped)
        }, setPeerThreadPinned: { [weak self] peerId, threadId, isPinned in
            self?.setPeerThreadPinned?(peerId, threadId, isPinned)
        }, setPeerThreadHidden: { [weak self] peerId, threadId, isHidden in
            self?.setPeerThreadHidden?(peerId, threadId, isHidden)
        }, updatePeerGrouping: { [weak self] peerId, group in
            self?.updatePeerGrouping?(peerId, group)
        }, togglePeerMarkedUnread: { [weak self, weak context] peerId, animated in
            guard let context = context else {
                return
            }
            self?.setCurrentRemovingItemId(ChatListNodeState.ItemId(peerId: peerId, threadId: nil))
            let _ = (context.engine.messages.togglePeersUnreadMarkInteractively(peerIds: [peerId], setToValue: nil)
            |> deliverOnMainQueue).startStandalone(completed: {
                self?.updateState { state in
                    var state = state
                    state.peerIdWithRevealedOptions = nil
                    return state
                }
                self?.setCurrentRemovingItemId(nil)
            })
        }, toggleArchivedFolderHiddenByDefault: { [weak self] in
            self?.toggleArchivedFolderHiddenByDefault?()
        }, toggleThreadsSelection: { [weak self] threadIds, selected in
            self?.updateState { state in
                var state = state
                if selected {
                    for threadId in threadIds {
                        state.selectedThreadIds.insert(threadId)
                    }
                } else {
                    for threadId in threadIds {
                        state.selectedThreadIds.remove(threadId)
                    }
                }
                return state
            }
            if selected && !threadIds.isEmpty {
                self?.didBeginSelectingChats?()
            }
        }, hidePsa: { [weak self] id in
            self?.hidePsa?(id)
        }, activateChatPreview: { [weak self] item, threadId, node, gesture, location in
            guard let strongSelf = self else {
                return
            }
            if let activateChatPreview = strongSelf.activateChatPreview {
                activateChatPreview(item, threadId, node, gesture, location)
            } else {
                gesture?.cancel()
            }
        }, present: { [weak self] c in
            self?.present?(c)
        }, openForumThread: { [weak self] peerId, threadId in
            guard let self else {
                return
            }
            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
                guard let self, let peer else {
                    return
                }
                self.peerSelected?(peer, threadId, true, true, nil)
            })
        }, openStorageManagement: { [weak self] in
            guard let self else {
                return
            }
            let controller = self.context.sharedContext.makeStorageManagementController(context: self.context)
            self.push?(controller)
        }, openPasswordSetup: { [weak self] in
            guard let self else {
                return
            }
            Queue.mainQueue().after(0.6) { [weak self] in
                if let self {
                    let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: .setupPassword).startStandalone()
                }
            }
            let controller = self.context.sharedContext.makeSetupTwoFactorAuthController(context: self.context)
            self.push?(controller)
        }, openPremiumIntro: { [weak self] in
            guard let self else {
                return
            }
            Queue.mainQueue().after(0.6) { [weak self] in
                if let self {
                    let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: .annualPremium).startStandalone()
                    let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: .upgradePremium).startStandalone()
                    let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: .restorePremium).startStandalone()
                }
            }
            let controller = self.context.sharedContext.makePremiumIntroController(context: self.context, source: .ads, forceDark: false, dismissed: nil)
            self.push?(controller)
        }, openPremiumGift: { [weak self] peers, birthdays in
            guard let self else {
                return
            }
            if peers.count == 1, let peerId = peers.first?.id {
                let _ = (self.context.engine.payments.premiumGiftCodeOptions(peerId: nil, onlyCached: true)
                |> filter { !$0.isEmpty }
                |> deliverOnMainQueue).start(next: { giftOptions in
                    let premiumOptions = giftOptions.filter { $0.users == 1 }.map { CachedPremiumGiftOption(months: $0.months, currency: $0.currency, amount: $0.amount, botUrl: "", storeProductId: $0.storeProductId) }
                    let controller = self.context.sharedContext.makeGiftOptionsController(context: self.context, peerId: peerId, premiumOptions: premiumOptions, hasBirthday: true, completion: nil)
                    controller.navigationPresentation = .modal
                    self.push?(controller)
                })
            } else {
                let controller = self.context.sharedContext.makePremiumGiftController(context: self.context, source: .chatList(birthdays), completion: nil)
                controller.navigationPresentation = .modal
                self.push?(controller)
            }
        }, openPremiumManagement: { [weak self] in
            guard let self else {
                return
            }
            self.openPremiumManagement?()
        }, openActiveSessions: { [weak self] in
            guard let self else {
                return
            }
            
            let activeSessionsContext = self.context.engine.privacy.activeSessions()
            let _ = (activeSessionsContext.state
            |> filter { state in
                return !state.sessions.isEmpty
            }
            |> take(1)
            |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                guard let self else {
                    return
                }
                
                let recentSessionsController = self.context.sharedContext.makeRecentSessionsController(context: self.context, activeSessionsContext: activeSessionsContext)
                self.push?(recentSessionsController)
            })
        }, openBirthdaySetup: { [weak self] in
            guard let self else {
                return
            }
            self.openBirthdaySetup?()
        }, performActiveSessionAction: { [weak self] newSessionReview, isPositive in
            guard let self else {
                return
            }
            
            if isPositive {
                let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                
                let animationBackgroundColor: UIColor
                if presentationData.theme.overallDarkAppearance {
                    animationBackgroundColor = presentationData.theme.rootController.tabBar.backgroundColor
                } else {
                    animationBackgroundColor = UIColor(rgb: 0x474747)
                }
                self.present?(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_success", scale: 1.0, colors: ["info1.info1.stroke": animationBackgroundColor, "info2.info2.Fill": animationBackgroundColor], title: presentationData.strings.ChatList_SessionReview_ConfirmToastTitle, text: presentationData.strings.ChatList_SessionReview_ConfirmToastText, customUndoText: nil, timeout: 5), elevatedLayout: false, action: { [weak self] action in
                    switch action {
                    case .info:
                        self?.interaction?.openActiveSessions()
                    default:
                        break
                    }
                    
                    return true
                }))
                
                let _ = self.context.engine.privacy.confirmNewSessionReview(id: newSessionReview.id).startStandalone()
            } else {
                self.push?(NewSessionInfoScreen(context: self.context, newSessionReview: newSessionReview))
                
                //#if DEBUG
                //#else
                let _ = self.context.engine.privacy.terminateAnotherSession(id: newSessionReview.id).startStandalone()
                //#endif
            }
        }, openChatFolderUpdates: { [weak self] in
            guard let self else {
                return
            }
            let _ = (self.chatFolderUpdates.get()
            |> take(1)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] result in
                guard let self, let result else {
                    return
                }
                
                self.push?(ChatFolderLinkPreviewScreen(context: self.context, subject: .updates(result), contents: result.chatFolderLinkContents))
            })
        }, hideChatFolderUpdates: { [weak self] in
            guard let self else {
                return
            }
            let _ = (self.chatFolderUpdates.get()
            |> take(1)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] result in
                guard let self, let result else {
                    return
                }
                
                if let localFilterId = result.chatFolderLinkContents.localFilterId {
                    let _ = self.context.engine.peers.hideChatFolderUpdates(folderId: localFilterId).startStandalone()
                }
            })
        }, openStories: { [weak self] subject, itemNode in
            guard let self else {
                return
            }
            self.openStories?(subject, itemNode)
        }, openStarsTopup: { [weak self] amount in
            guard let self else {
                return
            }
            self.openStarsTopup?(amount)
        }, dismissNotice: { [weak self] notice in
            guard let self else {
                return
            }
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            switch notice {
            case .xmasPremiumGift:
                let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: .xmasPremiumGift).startStandalone()
                self.present?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.ChatList_PremiumGiftInSettingsInfo, timeout: 5.0, customUndoText: nil), elevatedLayout: false, action: { _ in
                    return true
                }))
            case .setupBirthday:
                let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: .setupBirthday).startStandalone()
                self.present?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.ChatList_BirthdayInSettingsInfo, timeout: 5.0, customUndoText: nil), elevatedLayout: false, action: { _ in
                    return true
                }))
            case .birthdayPremiumGift:
                let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: .todayBirthdays).startStandalone()
                self.present?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.ChatList_PremiumGiftInSettingsInfo, timeout: 5.0, customUndoText: nil), elevatedLayout: false, action: { _ in
                    return true
                }))
            case .premiumGrace:
                let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: .gracePremium).startStandalone()
            case .setupPhoto:
                let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: .setupPhoto).startStandalone()
            case .starsSubscriptionLowBalance:
                let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: .starsSubscriptionLowBalance).startStandalone()
            default:
                break
            }
        }, editPeer: { _ in
        }, openWebApp: { [weak self] user in
            guard let self else {
                return
            }
            self.openWebApp?(user)
        }, openPhotoSetup: { [weak self] in
            guard let self else {
                return
            }
            self.openPhotoSetup?()
        }, openAdInfo: { [weak self] node in
            self?.openAdInfo?(node)
        })
        nodeInteraction.isInlineMode = isInlineMode
        
        let viewProcessingQueue = self.viewProcessingQueue
        
        let shouldLoadCanMessagePeer: Bool
        if case .peers = mode {
            shouldLoadCanMessagePeer = true
        } else {
            shouldLoadCanMessagePeer = false
        }
        
        let chatListViewUpdate = self.chatListLocation.get()
        |> distinctUntilChanged
        |> mapToSignal { listLocation -> Signal<(ChatListNodeViewUpdate, ChatListFilter?), NoError> in
            return chatListViewForLocation(chatListLocation: location, location: listLocation, account: context.account, shouldLoadCanMessagePeer: shouldLoadCanMessagePeer)
            |> map { update in
                return (update, listLocation.filter)
            }
        }
        
        let previousState = Atomic<ChatListNodeState>(value: self.currentState)
        let previousView = Atomic<ChatListNodeView?>(value: nil)
        let previousHideArchivedFolderByDefault = Atomic<Bool?>(value: nil)
        let currentRemovingItemId = self.currentRemovingItemId
        
        let savedMessagesPeer: Signal<EnginePeer?, NoError>
        if case let .peers(filter, _, _, _, _, _) = mode, filter.contains(.onlyWriteable), case .chatList = location, self.chatListFilter == nil {
            savedMessagesPeer = context.account.postbox.loadedPeerWithId(context.account.peerId)
            |> map(Optional.init)
            |> map { peer in
                return peer.flatMap(EnginePeer.init)
            }
        } else {
            savedMessagesPeer = .single(nil)
        }
        
        let hideArchivedFolderByDefault = context.account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.chatArchiveSettings])
        |> map { view -> Bool in
            let settings: ChatArchiveSettings = view.values[ApplicationSpecificPreferencesKeys.chatArchiveSettings]?.get(ChatArchiveSettings.self) ?? .default
            return settings.isHiddenByDefault
        }
        |> distinctUntilChanged
        
        let displayArchiveIntro: Signal<Bool, NoError>
        if case .chatList(.archive) = location {
            let displayArchiveIntroData = context.sharedContext.accountManager.noticeEntry(key: ApplicationSpecificNotice.archiveIntroDismissedKey())
            |> map { entry -> Bool in
                if let value = entry.value?.get(ApplicationSpecificVariantNotice.self) {
                    return !value.value
                } else {
                    return true
                }
            }
            |> take(1)
            |> afterNext { value in
                Queue.mainQueue().async {
                    if value {
                        let _ = (context.sharedContext.accountManager.transaction { transaction -> Void in
                            ApplicationSpecificNotice.setArchiveIntroDismissed(transaction: transaction, value: true)
                        }).startStandalone()
                    }
                }
            }
            displayArchiveIntro = combineLatest(displayArchiveIntroData, self.hideArhiveIntro.get())
            |> map { a, b -> Bool in
                return a && !b
            }
        } else {
            displayArchiveIntro = .single(false)
        }
        
        let starsSubscriptionsContextPromise = Promise<StarsSubscriptionsContext?>(nil)
    
        self.updateIsMainTabDisposable = (self.isMainTab.get()
        |> deliverOnMainQueue).startStrict(next: { [weak self] isMainTab in
            guard let self else {
                return
            }
            
            guard case .chatList(groupId: .root) = location, isMainTab else {
                self.suggestedChatListNotice.set(.single(nil))
                return
            }
            
            let _ = context.engine.privacy.cleanupSessionReviews().startStandalone()
            
            let twoStepData: Signal<TwoStepVerificationConfiguration?, NoError> = .single(nil) |> then(context.engine.auth.twoStepVerificationConfiguration() |> map(Optional.init))
            
            let suggestedChatListNoticeSignal: Signal<ChatListNotice?, NoError> = combineLatest(
                context.engine.notices.getServerProvidedSuggestions(),
                context.engine.notices.getServerDismissedSuggestions(),
                twoStepData,
                newSessionReviews(postbox: context.account.postbox),
                context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
                    TelegramEngine.EngineData.Item.Peer.Birthday(id: context.account.peerId)
                ),
                context.account.stateManager.contactBirthdays,
                starsSubscriptionsContextPromise.get()
            )
            |> mapToSignal { suggestions, dismissedSuggestions, configuration, newSessionReviews, data, birthdays, starsSubscriptionsContext -> Signal<ChatListNotice?, NoError> in                
                let (accountPeer, birthday) = data
                
                if let newSessionReview = newSessionReviews.first {
                    return .single(.reviewLogin(newSessionReview: newSessionReview, totalCount: newSessionReviews.count))
                }
                if suggestions.contains(.setupPassword), let configuration {
                    var notSet = false
                    switch configuration {
                    case let .notSet(pendingEmail):
                        if pendingEmail == nil {
                            notSet = true
                        }
                    case .set:
                        break
                    }
                    if notSet {
                        return .single(.setupPassword)
                    }
                }
                
                let today = Calendar(identifier: .gregorian).component(.day, from: Date())
                var todayBirthdayPeerIds: [EnginePeer.Id] = []
                for (peerId, birthday) in birthdays {
                    if birthday.day == today {
                        todayBirthdayPeerIds.append(peerId)
                    }
                }
                todayBirthdayPeerIds.sort { lhs, rhs in
                    return lhs < rhs
                }
                
                if dismissedSuggestions.contains(.todayBirthdays) {
                    todayBirthdayPeerIds = []
                }
                
                if suggestions.contains(.starsSubscriptionLowBalance) {
                    if let starsSubscriptionsContext {
                        return starsSubscriptionsContext.state
                        |> map { state in
                            if state.balance > StarsAmount.zero && !state.subscriptions.isEmpty {
                                return .starsSubscriptionLowBalance(
                                    amount: state.balance,
                                    peers: state.subscriptions.map { $0.peer }
                                )
                            } else {
                                return nil
                            }
                        }
                    } else {
                        starsSubscriptionsContextPromise.set(.single(context.engine.payments.peerStarsSubscriptionsContext(starsContext: nil, missingBalance: true)))
                        return .single(nil)
                    }
                } else if suggestions.contains(.setupPhoto), let accountPeer, accountPeer.smallProfileImage == nil {
                    return .single(.setupPhoto(accountPeer))
                } else if suggestions.contains(.gracePremium) {
                    return .single(.premiumGrace)
                } else if suggestions.contains(.setupBirthday) && birthday == nil {
                    return .single(.setupBirthday)
                } else if suggestions.contains(.xmasPremiumGift) {
                    return .single(.xmasPremiumGift)
                } else if suggestions.contains(.annualPremium) || suggestions.contains(.upgradePremium) || suggestions.contains(.restorePremium), let inAppPurchaseManager = context.inAppPurchaseManager {
                    return inAppPurchaseManager.availableProducts
                    |> map { products -> ChatListNotice? in
                        if products.count > 1 {
                            let shortestOptionPrice: (Int64, NSDecimalNumber)
                            if let product = products.first(where: { $0.id.hasSuffix(".monthly") }) {
                                shortestOptionPrice = (Int64(Float(product.priceCurrencyAndAmount.amount)), product.priceValue)
                            } else {
                                shortestOptionPrice = (1, NSDecimalNumber(decimal: 1))
                            }
                            for product in products {
                                if product.id.hasSuffix(".annual") {
                                    let fraction = Float(product.priceCurrencyAndAmount.amount) / Float(12) / Float(shortestOptionPrice.0)
                                    let discount = Int32(round((1.0 - fraction) * 20.0) * 5.0)
                                    if discount > 0 {
                                        if suggestions.contains(.restorePremium) {
                                            return .premiumRestore(discount: discount)
                                        } else if suggestions.contains(.annualPremium) {
                                            return .premiumAnnualDiscount(discount: discount)
                                        } else if suggestions.contains(.upgradePremium) {
                                            return .premiumUpgrade(discount: discount)
                                        }
                                    }
                                    break
                                }
                            }
                            return nil
                        } else {
                            if !GlobalExperimentalSettings.isAppStoreBuild {
                                if suggestions.contains(.restorePremium) {
                                    return .premiumRestore(discount: 0)
                                } else if suggestions.contains(.annualPremium) {
                                    return .premiumAnnualDiscount(discount: 0)
                                } else if suggestions.contains(.upgradePremium) {
                                    return .premiumUpgrade(discount: 0)
                                }
                            }
                            return nil
                        }
                    }
                } else if !todayBirthdayPeerIds.isEmpty {
                    return context.engine.data.get(
                        EngineDataMap(todayBirthdayPeerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
                    )
                    |> map { result -> ChatListNotice? in
                        var todayBirthdayPeers: [EnginePeer] = []
                        for (peerId, _) in birthdays {
                            if let maybePeer = result[peerId], let peer = maybePeer {
                                todayBirthdayPeers.append(peer)
                            }
                        }
                        return .birthdayPremiumGift(peers: todayBirthdayPeers, birthdays: birthdays)
                    }
                } else {
                    return .single(nil)
                }
            }
            |> distinctUntilChanged
            
            self.suggestedChatListNotice.set(suggestedChatListNoticeSignal)
            
            /*#if DEBUG
            let testNotice: Signal<ChatListNotice?, NoError> = Signal<ChatListNotice?, NoError>.single(.setupPassword) |> then(Signal<ChatListNotice?, NoError>.complete() |> delay(1.0, queue: .mainQueue())) |> then(Signal<ChatListNotice?, NoError>.single(.xmasPremiumGift)) |> then(Signal<ChatListNotice?, NoError>.complete() |> delay(1.0, queue: .mainQueue())) |> restart
            self.suggestedChatListNotice.set(testNotice)
            #endif*/
        }).strict()
        
        let storageInfo: Signal<Double?, NoError>
        if !"".isEmpty, case .chatList(groupId: .root) = location, chatListFilter == nil {
            let totalSizeSignal = combineLatest(context.account.postbox.mediaBox.storageBox.totalSize(), context.account.postbox.mediaBox.cacheStorageBox.totalSize())
            |> map { a, b -> Int64 in
                return a + b
            }
            
            storageInfo = totalSizeSignal
            |> take(1)
            |> mapToSignal { initialSize -> Signal<Double?, NoError> in
                #if DEBUG
                let fractionLimit: Double = 0.0001
                #else
                let fractionLimit: Double = 0.3
                #endif
                
                let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
                let deviceFreeSpace = (systemAttributes?[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value ?? 0
                
                let initialFraction: Double
                if deviceFreeSpace != 0 && initialSize != 0 {
                    initialFraction = Double(initialSize) / Double(deviceFreeSpace + initialSize)
                } else {
                    initialFraction = 0.0
                }
                
                let initialReportSize: Double?
                if initialFraction > fractionLimit {
                    initialReportSize = Double(initialSize)
                } else {
                    initialReportSize = nil
                }
                
                final class ReportState {
                    var lastSize: Int64
                    
                    init(lastSize: Int64) {
                        self.lastSize = lastSize
                    }
                }
                
                let state = Atomic(value: ReportState(lastSize: initialSize))
                let updatedReportSize: Signal<Double?, NoError> = Signal { subscriber in
                    let disposable = totalSizeSignal.start(next: { size in
                        let updatedSize = state.with { state -> Int64 in
                            if abs(initialSize - size) > 50 * 1024 * 1024 {
                                state.lastSize = size
                                return size
                            } else {
                                return -1
                            }
                        }
                        if updatedSize >= 0 {
                            let deviceFreeSpace = (systemAttributes?[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value ?? 0
                            
                            let updatedFraction: Double
                            if deviceFreeSpace != 0 && updatedSize != 0 {
                                updatedFraction = Double(updatedSize) / Double(deviceFreeSpace + updatedSize)
                            } else {
                                updatedFraction = 0.0
                            }
                            
                            let updatedReportSize: Double?
                            if updatedFraction > fractionLimit {
                                updatedReportSize = Double(updatedSize)
                            } else {
                                updatedReportSize = nil
                            }
                            
                            subscriber.putNext(updatedReportSize)
                        }
                    })
                    
                    return ActionDisposable {
                        disposable.dispose()
                    }
                }
                
                return .single(initialReportSize)
                |> then(
                    updatedReportSize
                )
            }
        } else {
            storageInfo = .single(nil)
        }
        
        let currentPeerId: EnginePeer.Id = context.account.peerId
        
        let contacts: Signal<[ChatListContactPeer], NoError>
        if case .chatList(groupId: .root) = location, chatListFilter == nil, case .chatList = mode {
            contacts = ApplicationSpecificNotice.displayChatListContacts(accountManager: context.sharedContext.accountManager)
            |> distinctUntilChanged
            |> mapToSignal { value -> Signal<[ChatListContactPeer], NoError> in
                if value {
                    return .single([])
                }
                
                return context.engine.messages.chatList(group: .root, count: 10)
                |> map { chatList -> Bool in
                    if chatList.items.count >= 5 {
                        return true
                    } else {
                        return false
                    }
                }
                |> distinctUntilChanged
                |> mapToSignal { hasChats -> Signal<[ChatListContactPeer], NoError> in
                    if hasChats {
                        return .single([])
                    }
                    
                    return context.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Contacts.List(includePresences: true)
                    )
                    |> mapToThrottled { next -> Signal<EngineContactList, NoError> in
                        return .single(next)
                        |> then(
                            .complete()
                            |> delay(5.0, queue: Queue.concurrentDefaultQueue())
                        )
                    }
                    |> map { contactList -> [ChatListContactPeer] in
                        var result: [ChatListContactPeer] = []
                        for peer in contactList.peers {
                            if peer.id == context.account.peerId {
                                continue
                            }
                            result.append(ChatListContactPeer(
                                peer: peer,
                                presence: contactList.presences[peer.id] ?? EnginePeer.Presence(status: .longTimeAgo, lastActivity: 0)
                            ))
                        }
                        result.sort(by: { lhs, rhs in
                            if lhs.presence.status != rhs.presence.status {
                                return lhs.presence.status < rhs.presence.status
                            } else {
                                return lhs.peer.id < rhs.peer.id
                            }
                        })
                        return result
                    }
                }
            }
        } else {
            contacts = .single([])
        }
        
        let accountPeerId = context.account.peerId
        
        let chatListFilters: Signal<[ChatListFilter]?, NoError>
        if case .chatList = mode {
            chatListFilters = combineLatest(queue: .mainQueue(),
                context.engine.peers.updatedChatListFilters(),
                context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.ChatList.FiltersDisplayTags()
                )
            )
            |> map { filters, displayTags -> [ChatListFilter]? in
                if !displayTags {
                    return nil
                }
                return filters.filter { filter in
                    return filter.id != chatListFilter?.id
                }
            }
            |> distinctUntilChanged
        } else {
            chatListFilters = .single(nil)
        }
        let previousChatListFilters = Atomic<[ChatListFilter]?>(value: nil)
        
        let previousAccountIsPremium = Atomic<Bool?>(value: nil)
        
        let accountIsPremium = context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)
        )
        |> map { peer -> Bool in
            return peer?.isPremium ?? false
        }
        |> distinctUntilChanged
        
        let chatListNodeViewTransition = combineLatest(queue: viewProcessingQueue,
            hideArchivedFolderByDefault,
            displayArchiveIntro,
            storageInfo,
            suggestedChatListNotice.get(),
            savedMessagesPeer,
            chatListViewUpdate,
            self.statePromise.get(),
            contacts,
            chatListFilters,
            accountIsPremium
        )
        |> mapToQueue { (hideArchivedFolderByDefault, displayArchiveIntro, storageInfo, suggestedChatListNotice, savedMessagesPeer, updateAndFilter, state, contacts, chatListFilters, accountIsPremium) -> Signal<ChatListNodeListViewTransition, NoError> in
            let (update, filter) = updateAndFilter
            
            let previousHideArchivedFolderByDefaultValue = previousHideArchivedFolderByDefault.swap(hideArchivedFolderByDefault)
            
            let notice: ChatListNotice?
            if let suggestedChatListNotice {
                notice = suggestedChatListNotice
            } else if let storageInfo {
                notice = .clearStorage(sizeFraction: storageInfo)
            } else {
                notice = nil
            }
            
            let innerIsMainTab = location == .chatList(groupId: .root) && chatListFilter == nil
            
            let (rawEntries, isLoading) = chatListNodeEntriesForView(view: update.list, state: state, savedMessagesPeer: savedMessagesPeer, foundPeers: state.foundPeers, hideArchivedFolderByDefault: hideArchivedFolderByDefault, displayArchiveIntro: displayArchiveIntro, notice: notice, mode: mode, chatListLocation: location, contacts: contacts, accountPeerId: accountPeerId, isMainTab: innerIsMainTab)
            var isEmpty = true
            var entries = rawEntries.filter { entry in
                switch entry {
                case let .PeerEntry(peerEntry):
                    let peer = peerEntry.peer
                    
                    switch mode {
                    case .chatList:
                        isEmpty = false
                        return true
                    case let .peers(filter, _, _, _, _, _):
                        guard !filter.contains(.excludeSavedMessages) || peer.peerId != currentPeerId else { return false }
                        guard !filter.contains(.excludeSavedMessages) || !peer.peerId.isReplies else { return false }
                        guard !filter.contains(.excludeSecretChats) || peer.peerId.namespace != Namespaces.Peer.SecretChat else { return false }
                        guard !filter.contains(.onlyPrivateChats) || peer.peerId.namespace == Namespaces.Peer.CloudUser else { return false }
                        
                        if let peer = peer.peer {
                            if peer.id.isRepliesOrVerificationCodes {
                                return false
                            }
                            
                            switch peer {
                            case let .user(user):
                                if user.botInfo != nil {
                                    if filter.contains(.excludeBots) {
                                        return false
                                    }
                                } else {
                                    if filter.contains(.excludeUsers) {
                                        return false
                                    }
                                }
                            case .legacyGroup:
                                if filter.contains(.excludeGroups) {
                                    return false
                                }
                            case let .channel(channel):
                                switch channel.info {
                                case .broadcast:
                                    if filter.contains(.excludeChannels) {
                                        return false
                                    }
                                case .group:
                                    if filter.contains(.excludeGroups) {
                                        return false
                                    }
                                }
                            default:
                                break
                            }
                        }
                        
                        if filter.contains(.onlyGroupsAndChannels) {
                            if case .channel = peer.chatMainPeer {
                            } else if case .legacyGroup = peer.chatMainPeer {
                            } else {
                                return false
                            }
                        } else {
                            if filter.contains(.onlyGroups) {
                                var isGroup: Bool = false
                                if case let .channel(peer) = peer.chatMainPeer, case .group = peer.info {
                                    isGroup = true
                                } else if peer.peerId.namespace == Namespaces.Peer.CloudGroup {
                                    isGroup = true
                                }
                                if !isGroup {
                                    return false
                                }
                            }
                            
                            if filter.contains(.onlyChannels) {
                                if case let .channel(peer) = peer.chatMainPeer, case .broadcast = peer.info {
                                } else {
                                    return false
                                }
                            }
                        }
                        
                        if filter.contains(.excludeChannels) {
                            if case let .channel(peer) = peer.chatMainPeer, case .broadcast = peer.info {
                            }
                        }
                        
                        if filter.contains(.onlyWriteable) && filter.contains(.excludeDisabled) {
                            if let peer = peer.peers[peer.peerId] {
                                if !canSendMessagesToPeer(peer._asPeer()) {
                                    return false
                                }
                            } else {
                                return false
                            }
                        }
                        
                        if filter.contains(.onlyManageable) && filter.contains(.excludeDisabled) {
                            if let peer = peer.peers[peer.peerId] {
                                var canManage = false
                                if case let .legacyGroup(peer) = peer {
                                    switch peer.role {
                                    case .creator, .admin:
                                        canManage = true
                                    default:
                                        break
                                    }
                                } else if case let .channel(peer) = peer, case .group = peer.info, peer.hasPermission(.inviteMembers) {
                                    canManage = true
                                } else if case let .channel(peer) = peer, case .broadcast = peer.info, peer.hasPermission(.addAdmins) {
                                    canManage = true
                                }
                                
                                if canManage {
                                } else {
                                    return false
                                }
                            } else {
                                return false
                            }
                        }
                        
                        isEmpty = false
                        return true
                    case let .peerType(peerTypes, _):
                        if let peer = peer.peer, !peer.isDeleted && peer.id != context.account.peerId {
                            var match = false
                            for peerType in peerTypes {
                                if match {
                                    break
                                }
                                switch peerType {
                                case let .user(userType):
                                    if case let .user(user) = peer {
                                        match = true
                                        if user.id.isVerificationCodes {
                                            match = false
                                        }
                                        if let isBot = userType.isBot {
                                            if isBot != (user.botInfo != nil) {
                                                match = false
                                            }
                                        }
                                        if let isPremium = userType.isPremium {
                                            if isPremium != user.isPremium {
                                                match = false
                                            }
                                        }
                                        isEmpty = false
                                    } else {
                                        match = false
                                    }
                                case let .group(groupType):
                                    if case let .legacyGroup(group) = peer {
                                        match = true
                                        if groupType.isCreator {
                                            if case .creator = group.role {
                                            } else {
                                                match = false
                                            }
                                        }
                                        if let isForum = groupType.isForum, isForum {
                                            match = false
                                        }
                                        if let hasUsername = groupType.hasUsername, hasUsername {
                                            match = false
                                        }
                                        if let userAdminRights = groupType.userAdminRights {
                                            if case .creator = group.role, userAdminRights.rights.contains(.canBeAnonymous) {
                                                match = false
                                            } else if case let .admin(rights, _) = group.role {
                                                if rights.rights.intersection(userAdminRights.rights) != userAdminRights.rights {
                                                    match = false
                                                }
                                            } else if case .member = group.role {
                                                match = false
                                            }
                                        }
                                        isEmpty = false
                                    } else if case let .channel(channel) = peer, case .group = channel.info {
                                        match = true
                                        if groupType.isCreator {
                                            if !channel.flags.contains(.isCreator) {
                                                match = false
                                            }
                                        }
                                        if let isForum = groupType.isForum {
                                            if isForum != channel.flags.contains(.isForum) {
                                                match = false
                                            }
                                        }
                                        if let hasUsername = groupType.hasUsername {
                                            if hasUsername != (!(channel.addressName ?? "").isEmpty) {
                                                match = false
                                            }
                                        }
                                        if let userAdminRights = groupType.userAdminRights {
                                            if channel.flags.contains(.isCreator) {
                                                if let rights = channel.adminRights, rights.rights.contains(.canBeAnonymous) != userAdminRights.rights.contains(.canBeAnonymous) {
                                                    match = false
                                                }
                                            } else if let rights = channel.adminRights {
                                                if rights.rights.intersection(userAdminRights.rights) != userAdminRights.rights {
                                                    match = false
                                                }
                                            } else {
                                                match = false
                                            }
                                        }
                                        isEmpty = false
                                    } else {
                                        match = false
                                    }
                                case let .channel(channelType):
                                    if case let .channel(channel) = peer, case .broadcast = channel.info {
                                        match = true
                                        if channelType.isCreator {
                                            if !channel.flags.contains(.isCreator) {
                                                match = false
                                            }
                                        }
                                        if let hasUsername = channelType.hasUsername {
                                            if hasUsername != (!(channel.addressName ?? "").isEmpty) {
                                                match = false
                                            }
                                        }
                                        if let userAdminRights = channelType.userAdminRights {
                                            if channel.flags.contains(.isCreator) {
                                                if let rights = channel.adminRights, rights.rights.contains(.canBeAnonymous) != userAdminRights.rights.contains(.canBeAnonymous) {
                                                    match = false
                                                }
                                            } else if let rights = channel.adminRights {
                                                if rights.rights.intersection(userAdminRights.rights) != userAdminRights.rights {
                                                    match = false
                                                }
                                            } else {
                                                match = false
                                            }
                                        }
                                        isEmpty = false
                                    } else {
                                        match = false
                                    }
                                }
                                if match {
                                    return true
                                }
                            }
                            return false
                        } else {
                            return false
                        }
                    }
                case .ContactEntry:
                    isEmpty = false
                    return true
                case .GroupReferenceEntry:
                    isEmpty = false
                    return true
                default:
                    return true
                }
            }
            if isEmpty {
                entries = [.HeaderEntry]
            }
            
            let processedView = ChatListNodeView(originalList: update.list, filteredEntries: entries, isLoading: isLoading, filter: filter)
            let previousView = previousView.swap(processedView)
            let previousState = previousState.swap(state)
            
            let reason: ChatListNodeViewTransitionReason
            var prepareOnMainQueue = false
            
            var previousWasEmptyOrSingleHole = false
            if let previous = previousView {
                if previous.filteredEntries.count == 1 {
                    if case .HoleEntry = previous.filteredEntries[0] {
                        previousWasEmptyOrSingleHole = true
                    } else if case .HeaderEntry = previous.filteredEntries[0] {
                        previousWasEmptyOrSingleHole = true
                    }
                } else if previous.filteredEntries.isEmpty && previous.isLoading {
                    previousWasEmptyOrSingleHole = true
                }
            } else {
                previousWasEmptyOrSingleHole = true
            }
            
            var updatedScrollPosition = update.scrollPosition
            
            if previousWasEmptyOrSingleHole {
                reason = .initial
                if previousView == nil {
                    prepareOnMainQueue = true
                }
            } else {
                if previousView?.originalList === update.list {
                    reason = .interactiveChanges
                    updatedScrollPosition = nil
                } else {
                    switch update.type {
                    case .InitialUnread, .Initial:
                        reason = .initial
                        prepareOnMainQueue = true
                    case .Generic:
                        reason = .interactiveChanges
                    case .UpdateVisible:
                        reason = .reload
                    case .FillHole:
                        reason = .reload
                    }
                }
            }
            
            let removingItemId = currentRemovingItemId.with { $0 }
            
            var disableAnimations = true
            if previousState.editing != state.editing {
                disableAnimations = false
            } else {
                var previousPinnedChats: [EnginePeer.Id] = []
                var updatedPinnedChats: [EnginePeer.Id] = []
                var previousPinnedThreads: [Int64] = []
                var updatedPinnedThreads: [Int64] = []
                
                var didIncludeRemovingPeerId = false
                var didIncludeHiddenByDefaultArchive = false
                var didIncludeHiddenThread = false
                var didIncludeNotice = false
                if let previous = previousView {
                    for entry in previous.filteredEntries {
                        if case let .PeerEntry(peerEntry) = entry {
                            let index = peerEntry.index
                            let threadInfo = peerEntry.threadInfo
                            
                            if let threadInfo, threadInfo.isHidden {
                                didIncludeHiddenThread = true
                            }
                            if case let .chatList(chatListIndex) = index {
                                if chatListIndex.pinningIndex != nil {
                                    previousPinnedChats.append(chatListIndex.messageIndex.id.peerId)
                                }
                                if ChatListNodeState.ItemId(peerId: chatListIndex.messageIndex.id.peerId, threadId: nil) == removingItemId {
                                    didIncludeRemovingPeerId = true
                                }
                            } else if case let .forum(pinnedIndex, _, threadId, _, _) = index {
                                if case .index = pinnedIndex {
                                    previousPinnedThreads.append(threadId)
                                }
                                if case let .forum(peerId) = location, ChatListNodeState.ItemId(peerId: peerId, threadId: threadId) == removingItemId {
                                    didIncludeRemovingPeerId = true
                                }
                            }
                        } else if case let .GroupReferenceEntry(groupReferenceEntry) = entry {
                            didIncludeHiddenByDefaultArchive = groupReferenceEntry.hiddenByDefault
                        } else if case .Notice = entry {
                            didIncludeNotice = true
                        }
                    }
                }
                var doesIncludeRemovingPeerId = false
                var doesIncludeArchive = false
                var doesIncludeHiddenByDefaultArchive = false
                var doesIncludeNotice = false
                
                var doesIncludeHiddenThread = false
                for entry in processedView.filteredEntries {
                    if case let .PeerEntry(peerEntry) = entry {
                        let index = peerEntry.index
                        let threadInfo = peerEntry.threadInfo
                        
                        if let threadInfo, threadInfo.isHidden {
                            doesIncludeHiddenThread = true
                        }
                        if case let .chatList(index) = index, index.pinningIndex != nil {
                            updatedPinnedChats.append(index.messageIndex.id.peerId)
                        } else if case let .forum(pinnedIndex, _, threadId, _, _) = index {
                            if case .index = pinnedIndex {
                                updatedPinnedThreads.append(threadId)
                            }
                        }
                        
                        if case let .chatList(index) = index, ChatListNodeState.ItemId(peerId: index.messageIndex.id.peerId, threadId: nil) == removingItemId {
                            doesIncludeRemovingPeerId = true
                        } else if case let .forum(_, _, threadId, _, _) = index {
                            if case let .forum(peerId) = location, ChatListNodeState.ItemId(peerId: peerId, threadId: threadId) == removingItemId {
                                doesIncludeRemovingPeerId = true
                            }
                        }
                    } else if case let .GroupReferenceEntry(groupReferenceEntry) = entry {
                        doesIncludeArchive = true
                        doesIncludeHiddenByDefaultArchive = groupReferenceEntry.hiddenByDefault
                    } else if case .Notice = entry {
                        doesIncludeNotice = true
                    }
                }
                if previousPinnedChats != updatedPinnedChats || previousPinnedThreads != updatedPinnedThreads {
                    disableAnimations = false
                }
                if previousState.selectedPeerIds != state.selectedPeerIds {
                    disableAnimations = false
                }
                if previousState.selectedAdditionalCategoryIds != state.selectedAdditionalCategoryIds {
                    disableAnimations = false
                }
                if doesIncludeRemovingPeerId != didIncludeRemovingPeerId {
                    disableAnimations = false
                }
                if hideArchivedFolderByDefault && previousState.hiddenItemShouldBeTemporaryRevealed != state.hiddenItemShouldBeTemporaryRevealed && doesIncludeArchive {
                    disableAnimations = false
                }
                if didIncludeHiddenByDefaultArchive != doesIncludeHiddenByDefaultArchive {
                    disableAnimations = false
                }
                if previousState.hiddenItemShouldBeTemporaryRevealed != state.hiddenItemShouldBeTemporaryRevealed && doesIncludeHiddenThread {
                    disableAnimations = false
                }
                if didIncludeHiddenThread != doesIncludeHiddenThread {
                    disableAnimations = false
                }
                if didIncludeNotice != doesIncludeNotice {
                    disableAnimations = false
                }
            }
            
            if let _ = previousHideArchivedFolderByDefaultValue, previousHideArchivedFolderByDefaultValue != hideArchivedFolderByDefault {
                disableAnimations = false
            }
            
            var searchMode = false
            if case .peers = mode {
                searchMode = true
            }
            
            if filter != previousView?.filter {
                disableAnimations = true
                updatedScrollPosition = nil
            }
            
            let filterData = filter.flatMap { filter -> ChatListItemFilterData? in
                if case let .filter(_, _, _, data) = filter {
                    return ChatListItemFilterData(excludesArchived: data.excludeArchived)
                } else {
                    return nil
                }
            }
            
            var forceAllUpdated = false
            let previousChatListFiltersValue = previousChatListFilters.swap(chatListFilters)
            if chatListFilters != previousChatListFiltersValue {
                forceAllUpdated = true
            }
            if accountIsPremium != previousAccountIsPremium.swap(accountIsPremium) {
                forceAllUpdated = true
            }
            
            return preparedChatListNodeViewTransition(from: previousView, to: processedView, reason: reason, previewing: previewing, disableAnimations: disableAnimations, account: context.account, scrollPosition: updatedScrollPosition, searchMode: searchMode, forceAllUpdated: forceAllUpdated)
            |> map({ mappedChatListNodeViewListTransition(context: context, nodeInteraction: nodeInteraction, location: location, isPremium: accountIsPremium, filterData: filterData, chatListFilters: chatListFilters, mode: mode, isPeerEnabled: isPeerEnabled, transition: $0) })
            |> runOn(prepareOnMainQueue ? Queue.mainQueue() : viewProcessingQueue)
        }
        
        let appliedTransition = chatListNodeViewTransition |> deliverOnMainQueue |> mapToQueue { [weak self] transition -> Signal<Void, NoError> in
            if let strongSelf = self {
                return strongSelf.enqueueTransition(transition)
            }
            return .complete()
        }
        
        self.displayedItemRangeChanged = { [weak self] range, transactionOpaqueState in
            if let strongSelf = self, let chatListView = (transactionOpaqueState as? ChatListOpaqueTransactionState)?.chatListView {
                let originalList = chatListView.originalList
                if let range = range.loadedRange {
                    var location: ChatListNodeLocation?
                    if range.firstIndex < 5, let lastItem = originalList.items.last, originalList.hasLater {
                        location = .navigation(index: lastItem.index, filter: strongSelf.chatListFilter)
                    } else if range.firstIndex >= 5, range.lastIndex >= originalList.items.count - 5, originalList.hasEarlier, let firstItem = originalList.items.first {
                        location = .navigation(index: firstItem.index, filter: strongSelf.chatListFilter)
                    }
                    
                    if let location = location, location != strongSelf.currentLocation {
                        strongSelf.setChatListLocation(location)
                    }
                    
                    strongSelf.enqueueHistoryPreloadUpdate()
                }
                
                var refreshStoryPeerIds: [PeerId] = []
                var isHiddenItemVisible = false
                if let range = range.visibleRange {
                    let entryCount = chatListView.filteredEntries.count
                    for i in max(0, range.firstIndex - 1) ..< range.lastIndex {
                        if i < 0 || i >= entryCount {
                            assertionFailure()
                            continue
                        }
                        switch chatListView.filteredEntries[entryCount - i - 1] {
                            case let .PeerEntry(peerEntry):
                                let threadInfo = peerEntry.threadInfo
                                
                                if let threadInfo, threadInfo.isHidden {
                                    isHiddenItemVisible = true
                                }
                            
                                if let peer = peerEntry.peer.chatMainPeer, !peerEntry.isContact, case let .user(user) = peer {
                                    refreshStoryPeerIds.append(user.id)
                                }
                            
                                break
                            case .GroupReferenceEntry:
                                isHiddenItemVisible = true
                            default:
                                break
                        }
                    }
                }
                if !isHiddenItemVisible && strongSelf.currentState.hiddenItemShouldBeTemporaryRevealed {
                    strongSelf.updateState { state in
                        var state = state
                        state.hiddenItemShouldBeTemporaryRevealed = false
                        return state
                    }
                }
                if !refreshStoryPeerIds.isEmpty {
                    strongSelf.context.account.viewTracker.refreshStoryStatsForPeerIds(peerIds: refreshStoryPeerIds)
                }
            }
        }
        
        self.interaction = nodeInteraction
        
        self.chatListDisposable.set(appliedTransition.startStrict())
        
        let initialLocation: ChatListNodeLocation
        switch mode {
        case .chatList:
            initialLocation = .initial(count: 50, filter: self.chatListFilter)
        case .peers, .peerType:
            initialLocation = .initial(count: 200, filter: self.chatListFilter)
        }
        self.setChatListLocation(initialLocation)
        
        let engine = context.engine
        let previousPeerCache = Atomic<[EnginePeer.Id: EnginePeer]>(value: [:])
        let previousActivities = Atomic<ChatListNodePeerInputActivities?>(value: nil)
        self.activityStatusesDisposable = (context.account.allPeerInputActivities()
        |> mapToSignal { activitiesByPeerId -> Signal<[ChatListNodePeerInputActivities.ItemId: [(EnginePeer, PeerInputActivity)]], NoError> in
            var activitiesByPeerId = activitiesByPeerId
            for key in activitiesByPeerId.keys {
                activitiesByPeerId[key]?.removeAll(where: { _, activity in
                    switch activity {
                    case .interactingWithEmoji:
                        return true
                    case .speakingInGroupCall:
                        return true
                    default:
                        return false
                    }
                })
            }
            
            var foundAllPeers = true
            var cachedResult: [ChatListNodePeerInputActivities.ItemId: [(EnginePeer, PeerInputActivity)]] = [:]
            previousPeerCache.with { dict -> Void in
                for (chatPeerId, activities) in activitiesByPeerId {
                    var threadId: Int64?
                    switch location {
                    case .chatList:
                        guard case .global = chatPeerId.category else {
                            continue
                        }
                    case let .forum(peerId):
                        if chatPeerId.peerId != peerId {
                            continue
                        }
                        guard case let .thread(threadIdValue) = chatPeerId.category else {
                            continue
                        }
                        threadId = threadIdValue
                    case .savedMessagesChats:
                        return
                    }
                    var cachedChatResult: [(EnginePeer, PeerInputActivity)] = []
                    for (peerId, activity) in activities {
                        if let peer = dict[peerId] {
                            cachedChatResult.append((peer, activity))
                        } else {
                            foundAllPeers = false
                            break
                        }
                        cachedResult[ChatListNodePeerInputActivities.ItemId(peerId: chatPeerId.peerId, threadId: threadId)] = cachedChatResult
                    }
                }
            }
            if foundAllPeers {
                return .single(cachedResult)
            } else {
                var dataKeys: [EnginePeer.Id] = []
                for (peerId, activities) in activitiesByPeerId {
                    dataKeys.append(peerId.peerId)
                    for activity in activities {
                        dataKeys.append(activity.0)
                    }
                }
                return engine.data.get(EngineDataMap(
                    Set(dataKeys).map {
                        TelegramEngine.EngineData.Item.Peer.Peer(id: $0)
                    }
                ))
                |> map { peerMap -> [ChatListNodePeerInputActivities.ItemId: [(EnginePeer, PeerInputActivity)]] in
                    var result: [ChatListNodePeerInputActivities.ItemId: [(EnginePeer, PeerInputActivity)]] = [:]
                    var peerCache: [EnginePeer.Id: EnginePeer] = [:]
                    for (chatPeerId, activities) in activitiesByPeerId {
                        let itemId: ChatListNodePeerInputActivities.ItemId
                        switch location {
                        case .chatList:
                            guard case .global = chatPeerId.category else {
                                continue
                            }
                            if case let .channel(channel) = peerMap[chatPeerId.peerId], channel.flags.contains(.isForum) {
                                continue
                            }
                            itemId = ChatListNodePeerInputActivities.ItemId(peerId: chatPeerId.peerId, threadId: nil)
                        case let .forum(peerId):
                            if chatPeerId.peerId != peerId {
                                continue
                            }
                            guard case let .thread(threadIdValue) = chatPeerId.category else {
                                continue
                            }
                            itemId = ChatListNodePeerInputActivities.ItemId(peerId: chatPeerId.peerId, threadId: threadIdValue)
                        case .savedMessagesChats:
                            return [:]
                        }
                        
                        var chatResult: [(EnginePeer, PeerInputActivity)] = []
                        
                        for (peerId, activity) in activities {
                            if let maybePeer = peerMap[peerId], let peer = maybePeer {
                                chatResult.append((peer, activity))
                                peerCache[peerId] = peer
                            }
                        }
                        
                        result[itemId] = chatResult
                    }
                    let _ = previousPeerCache.swap(peerCache)
                    return result
                }
            }
        }
        |> map { activities -> ChatListNodePeerInputActivities? in
            return previousActivities.modify { current in
                var updated = false
                let currentList: [ChatListNodePeerInputActivities.ItemId: [(EnginePeer, PeerInputActivity)]] = current?.activities ?? [:]
                if currentList.count != activities.count {
                    updated = true
                } else {
                    outer: for (peerId, currentValue) in currentList {
                        if let value = activities[peerId] {
                            if currentValue.count != value.count {
                                updated = true
                                break outer
                            } else {
                                for i in 0 ..< currentValue.count {
                                    if currentValue[i].0 != value[i].0 {
                                        updated = true
                                        break outer
                                    }
                                    if currentValue[i].1 != value[i].1 {
                                        updated = true
                                        break outer
                                    }
                                }
                            }
                        } else {
                            updated = true
                            break outer
                        }
                    }
                }
                if updated {
                    if activities.isEmpty {
                        return nil
                    } else {
                        return ChatListNodePeerInputActivities(activities: activities)
                    }
                } else {
                    return current
                }
            }
        }
        |> deliverOnMainQueue).startStrict(next: { [weak self] activities in
            if let strongSelf = self {
                strongSelf.updateState { state in
                    var state = state
                    state.peerInputActivities = activities
                    return state
                }
            }
        })
        
        self.reorderItem = { [weak self] fromIndex, toIndex, transactionOpaqueState -> Signal<Bool, NoError> in
            guard let strongSelf = self, let filteredEntries = (transactionOpaqueState as? ChatListOpaqueTransactionState)?.chatListView.filteredEntries else {
                return .single(false)
            }
            guard fromIndex >= 0 && fromIndex < filteredEntries.count && toIndex >= 0 && toIndex < filteredEntries.count else {
                return .single(false)
            }
            
            switch strongSelf.location {
            case let .chatList(groupId):
                let fromEntry = filteredEntries[filteredEntries.count - 1 - fromIndex]
                let toEntry = filteredEntries[filteredEntries.count - 1 - toIndex]
                
                var referenceId: EngineChatList.PinnedItem.Id?
                var beforeAll = false
                switch toEntry {
                case let .PeerEntry(peerEntry):
                    let index = peerEntry.index
                    let promoInfo = peerEntry.promoInfo
                    
                    if promoInfo != nil {
                        beforeAll = true
                    } else {
                        if case let .chatList(chatListIndex) = index {
                            referenceId = .peer(chatListIndex.messageIndex.id.peerId)
                        }
                    }
                default:
                    break
                }
                
                if case let .index(index) = fromEntry.sortIndex, case let .chatList(chatListIndex) = index, let _ = chatListIndex.pinningIndex {
                    let location: TogglePeerChatPinnedLocation
                    if let chatListFilter = chatListFilter {
                        location = .filter(chatListFilter.id)
                    } else {
                        location = .group(groupId._asGroup())
                    }
                    
                    let engine = strongSelf.context.engine
                    return engine.peers.getPinnedItemIds(location: location)
                    |> mapToSignal { itemIds -> Signal<Bool, NoError> in
                        var itemIds = itemIds
                        
                        var itemId: EngineChatList.PinnedItem.Id?
                        switch fromEntry {
                        case let .PeerEntry(peerEntry):
                            if case let .chatList(index) = peerEntry.index {
                                itemId = .peer(index.messageIndex.id.peerId)
                            }
                        default:
                            break
                        }
                        
                        if let itemId = itemId {
                            itemIds = itemIds.filter({ $0 != itemId })
                            if let referenceId = referenceId {
                                var inserted = false
                                for i in 0 ..< itemIds.count {
                                    if itemIds[i] == referenceId {
                                        if fromIndex < toIndex {
                                            itemIds.insert(itemId, at: i + 1)
                                        } else {
                                            itemIds.insert(itemId, at: i)
                                        }
                                        inserted = true
                                        break
                                    }
                                }
                                if !inserted {
                                    itemIds.append(itemId)
                                }
                            } else if beforeAll {
                                itemIds.insert(itemId, at: 0)
                            } else {
                                itemIds.append(itemId)
                            }
                            return engine.peers.reorderPinnedItemIds(location: location, itemIds: itemIds)
                        } else {
                            return .single(false)
                        }
                    }
                } else {
                    return .single(false)
                }
            case let .forum(peerId):
                let fromEntry = filteredEntries[filteredEntries.count - 1 - fromIndex]
                let toEntry = filteredEntries[filteredEntries.count - 1 - toIndex]
                
                var referenceId: Int64?
                var beforeAll = false
                switch toEntry {
                case let .PeerEntry(peerEntry):
                    if peerEntry.promoInfo != nil {
                        beforeAll = true
                    } else {
                        if case let .forum(_, _, threadId, _, _) = peerEntry.index {
                            referenceId = threadId
                        }
                    }
                default:
                    break
                }
                
                if case let .index(index) = fromEntry.sortIndex, case let .forum(pinningIndex, _, _, _, _) = index, case .index = pinningIndex {
                    let engine = strongSelf.context.engine
                    return engine.peers.getForumChannelPinnedTopics(id: peerId)
                    |> mapToSignal { itemIds -> Signal<Bool, NoError> in
                        var itemIds = itemIds
                        
                        var itemId: Int64?
                        switch fromEntry {
                        case let .PeerEntry(peerEntry):
                            if case let .forum(_, _, threadId, _, _) = peerEntry.index {
                                itemId = threadId
                            }
                        default:
                            break
                        }
                        
                        if let itemId = itemId {
                            itemIds = itemIds.filter({ $0 != itemId })
                            if let referenceId = referenceId {
                                var inserted = false
                                for i in 0 ..< itemIds.count {
                                    if itemIds[i] == referenceId {
                                        if fromIndex < toIndex {
                                            itemIds.insert(itemId, at: i + 1)
                                        } else {
                                            itemIds.insert(itemId, at: i)
                                        }
                                        inserted = true
                                        break
                                    }
                                }
                                if !inserted {
                                    itemIds.append(itemId)
                                }
                            } else if beforeAll {
                                itemIds.insert(itemId, at: 0)
                            } else {
                                itemIds.append(itemId)
                            }
                            return engine.peers.setForumChannelPinnedTopics(id: peerId, threadIds: itemIds)
                            |> map { _ -> Bool in
                            }
                            |> `catch` { _ -> Signal<Bool, NoError> in
                                return .single(false)
                            }
                            |> then(Signal<Bool, NoError>.single(true))
                        } else {
                            return .single(false)
                        }
                    }
                } else {
                    return .single(false)
                }
            case .savedMessagesChats:
                return .single(false)
            }
        }
        var startedScrollingWithCanExpandHiddenItems = false
        
        self.beganInteractiveDragging = { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.visibleContentOffset() {
            case .none, .unknown:
                strongSelf.startedScrollingAtUpperBound = false
            case let .known(value):
                strongSelf.startedScrollingAtUpperBound = value <= 0.001
            }
            
            if let canExpandHiddenItems = strongSelf.canExpandHiddenItems {
                startedScrollingWithCanExpandHiddenItems = canExpandHiddenItems()
            } else {
                startedScrollingWithCanExpandHiddenItems = true
            }
            
            if strongSelf.currentState.peerIdWithRevealedOptions != nil {
                strongSelf.updateState { state in
                    var state = state
                    state.peerIdWithRevealedOptions = nil
                    return state
                }
            }
            
            strongSelf.didBeginInteractiveDragging?(strongSelf)
        }
        
        self.didEndScrolling = { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            let _ = strongSelf.contentScrollingEnded?(strongSelf)
            let revealHiddenItems: Bool
            switch strongSelf.visibleContentOffset() {
                case .none, .unknown:
                    revealHiddenItems = false
                case let .known(value):
                    revealHiddenItems = value <= -strongSelf.tempTopInset - 60.0
            }
            if !revealHiddenItems && strongSelf.currentState.hiddenItemShouldBeTemporaryRevealed {
                /*strongSelf.updateState { state in
                    var state = state
                    state.hiddenItemShouldBeTemporaryRevealed = false
                    return state
                }*/
            }
        }
        
        self.scrollToTopOptionPromise.set(combineLatest(
            renderedTotalUnreadCount(accountManager: self.context.sharedContext.accountManager, engine: self.context.engine) |> deliverOnMainQueue,
            self.scrolledAtTop.get()
        ) |> map { badge, scrolledAtTop -> ChatListGlobalScrollOption in
            if scrolledAtTop {
                return .none
            } else {
                return .top
            }
        })
        
        self.visibleContentOffsetChanged = { [weak self] offset in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.dequeuedInitialTransitionOnLayout {
                return
            }
            let atTop: Bool
            var revealHiddenItems: Bool = false
            switch offset {
                case .none, .unknown:
                    atTop = false
                case let .known(value):
                atTop = value <= -strongSelf.tempTopInset
                    if strongSelf.startedScrollingAtUpperBound && startedScrollingWithCanExpandHiddenItems && strongSelf.isTracking {
                        revealHiddenItems = value <= -strongSelf.tempTopInset - 60.0
                    }
            }
            strongSelf.scrolledAtTopValue = atTop
            strongSelf.contentOffsetChanged?(offset)
            if revealHiddenItems && !strongSelf.currentState.hiddenItemShouldBeTemporaryRevealed {
                //strongSelf.revealScrollHiddenItem()
            }
        }
        
        self.dynamicVisualInsets = { [weak self] in
            guard let self else {
                return UIEdgeInsets()
            }
            
            let _ = self
            return UIEdgeInsets()
        }
        
        self.pollFilterUpdates()
        self.resetFilter()
        
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
        self.chatListDisposable.dispose()
        self.activityStatusesDisposable?.dispose()
        self.updatedFilterDisposable.dispose()
        self.pollFilterUpdatesDisposable?.dispose()
        self.chatFilterUpdatesDisposable?.dispose()
        self.updateIsMainTabDisposable?.dispose()
    }
    
    func updateFilter(_ filter: ChatListFilter?) {
        if filter?.id != self.chatListFilter?.id {
            self.chatListFilter = filter
            self.resetFilter()
        }
    }
    
    func hasItemsToBeRevealed() -> Bool {
        if self.currentState.hiddenItemShouldBeTemporaryRevealed {
            return false
        }
        var isHiddenItemVisible = false
        self.forEachItemNode({ itemNode in
            if let itemNode = itemNode as? ChatListItemNode, let item = itemNode.item {
                if case let .peer(peerData) = item.content, let threadInfo = peerData.threadInfo {
                    if threadInfo.isHidden {
                        isHiddenItemVisible = true
                    }
                }
                if case let .groupReference(groupReference) = item.content {
                    if groupReference.hiddenByDefault {
                        isHiddenItemVisible = true
                    }
                }
            }
        })
        
        return isHiddenItemVisible
    }
    
    func revealScrollHiddenItem() {
        var isHiddenItemVisible = false
        self.forEachItemNode({ itemNode in
            if let itemNode = itemNode as? ChatListItemNode, let item = itemNode.item {
                if case let .peer(peerData) = item.content, let threadInfo = peerData.threadInfo {
                    if threadInfo.isHidden {
                        isHiddenItemVisible = true
                    }
                }
                if case let .groupReference(groupReference) = item.content {
                    if groupReference.hiddenByDefault {
                        isHiddenItemVisible = true
                    }
                }
            }
        })
        if isHiddenItemVisible && !self.currentState.hiddenItemShouldBeTemporaryRevealed {
            if self.hapticFeedback == nil {
                self.hapticFeedback = HapticFeedback()
            }
            self.hapticFeedback?.impact(.medium)
            self.updateState { state in
                var state = state
                state.hiddenItemShouldBeTemporaryRevealed = true
                return state
            }
        }
    }
    
    private func pollFilterUpdates() {
        self.chatFolderUpdates.set(.single(nil))
        
        /*guard let chatListFilter, case let .filter(id, _, _, data) = chatListFilter, data.isShared else {
            self.chatFolderUpdates.set(.single(nil))
            return
        }
        self.pollFilterUpdatesDisposable = self.context.engine.peers.pollChatFolderUpdates(folderId: id).start()
        self.chatFilterUpdatesDisposable = (self.context.engine.peers.subscribedChatFolderUpdates(folderId: id)
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let self else {
                return
            }
            self.chatFolderUpdates.set(.single(result))
        })*/
    }
    
    private func resetFilter() {
        if let chatListFilter = self.chatListFilter, chatListFilter.id != Int32.max {
            self.updatedFilterDisposable.set((self.context.engine.peers.updatedChatListFilters()
            |> map { filters -> ChatListFilter? in
                for filter in filters {
                    if filter.id == chatListFilter.id {
                        return filter
                    }
                }
                return nil
            }
            |> deliverOnMainQueue).startStrict(next: { [weak self] updatedFilter in
                guard let strongSelf = self else {
                    return
                }
                if strongSelf.chatListFilter != updatedFilter {
                    strongSelf.chatListFilter = updatedFilter
                }
            }))
        } else {
            self.updatedFilterDisposable.set(nil)
        }
    }
    
    public func updateThemeAndStrings(theme: PresentationTheme, fontSize: PresentationFontSize, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, disableAnimations: Bool) {
        if theme !== self.currentState.presentationData.theme || strings !== self.currentState.presentationData.strings || dateTimeFormat != self.currentState.presentationData.dateTimeFormat {
            self.theme = theme
            if self.keepTopItemOverscrollBackground != nil {
                self.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color:  theme.chatList.pinnedItemBackgroundColor, direction: true)
            }
            self.verticalScrollIndicatorColor = theme.list.scrollIndicatorColor
            
            self.updateState { state in
                var state = state
                state.presentationData = ChatListPresentationData(theme: theme, fontSize: fontSize, strings: strings, dateTimeFormat: dateTimeFormat, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, disableAnimations: disableAnimations)
                return state
            }
        }
    }
    
    public func updateState(_ f: (ChatListNodeState) -> ChatListNodeState) {
        let state = f(self.currentState)
        if state != self.currentState {
            self.currentState = state
            self.statePromise.set(state)
        }
    }
    
    private func enqueueTransition(_ transition: ChatListNodeListViewTransition) -> Signal<Void, NoError> {
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                if let _ = strongSelf.enqueuedTransition {
                    preconditionFailure()
                }
                
                strongSelf.enqueuedTransition = (transition, {
                    subscriber.putCompletion()
                })
                
                if strongSelf.isNodeLoaded, strongSelf.dequeuedInitialTransitionOnLayout {
                    strongSelf.dequeueTransition()
                } else {
                    if !strongSelf.didSetReady && strongSelf.autoSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(true)
                    }
                }
            } else {
                subscriber.putCompletion()
            }
            
            return EmptyDisposable
        } |> runOn(Queue.mainQueue())
    }
    
    private func dequeueTransition() {
        if let (transition, completion) = self.enqueuedTransition {
            self.enqueuedTransition = nil
            
            let completion: (ListViewDisplayedItemRange) -> Void = { [weak self] visibleRange in
                if let strongSelf = self {
                    strongSelf.chatListView = transition.chatListView
                    
                    if strongSelf.fillPreloadItems {
                        let filteredEntries = transition.chatListView.filteredEntries
                        var preloadItems: [ChatHistoryPreloadItem] = []
                        if !transition.chatListView.originalList.hasLater {
                            for entry in filteredEntries.reversed() {
                                switch entry {
                                case let .PeerEntry(peerEntry):
                                    if peerEntry.promoInfo == nil {
                                        var hasUnread = false
                                        if let combinedReadState = peerEntry.readState {
                                            hasUnread = combinedReadState.count > 0
                                        }
                                        switch peerEntry.index {
                                        case let .chatList(index):
                                            preloadItems.append(ChatHistoryPreloadItem(index: index, threadId: nil, isMuted: peerEntry.isRemovedFromTotalUnreadCount, hasUnread: hasUnread))
                                        case .forum:
                                            break
                                        }
                                    }
                                default:
                                    break
                                }
                                if preloadItems.count >= 30 {
                                    break
                                }
                            }
                        }
                        strongSelf.preloadItems.set(.single(preloadItems))
                    }
                    
                    var pinnedOverscroll = false
                    if case .chatList = strongSelf.mode {
                        let entryCount = transition.chatListView.filteredEntries.count
                        if entryCount >= 1 {
                            for i in 0 ..< 2 {
                                if entryCount - 1 - i < 0 {
                                    continue
                                }
                                if case .PeerEntry = transition.chatListView.filteredEntries[entryCount - 1 - i] {
                                } else {
                                    continue
                                }
                                if case let .index(index) = transition.chatListView.filteredEntries[entryCount - 1 - i].sortIndex, case let .chatList(chatListIndex) = index, chatListIndex.pinningIndex != nil {
                                    pinnedOverscroll = true
                                }
                            }
                        }
                    }
                    
                    if pinnedOverscroll != (strongSelf.keepTopItemOverscrollBackground != nil) {
                        if pinnedOverscroll {
                            strongSelf.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color: strongSelf.theme.chatList.pinnedItemBackgroundColor, direction: true)
                        } else {
                            strongSelf.keepTopItemOverscrollBackground = nil
                        }
                    }
                    
                    if let scrollToItem = transition.scrollToItem, case .center = scrollToItem.position {
                        if let itemNode = strongSelf.itemNodeAtIndex(scrollToItem.index) as? ChatListItemNode {
                            itemNode.flashHighlight()
                        }
                    }
                    
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(true)
                    }
                    if !strongSelf.didSetContentsReady {
                        strongSelf.didSetContentsReady = true
                        strongSelf._contentsReady.set(true)
                    }
                    
                    var isEmpty = false
                    var isLoading = false
                    var hasArchiveInfo = false
                    if transition.chatListView.filteredEntries.isEmpty {
                        isEmpty = true
                    } else {
                        if transition.chatListView.filteredEntries.count <= 2 {
                            isEmpty = true
                            loop1: for entry in transition.chatListView.filteredEntries {
                                switch entry {
                                case .HeaderEntry, .HoleEntry:
                                    break
                                default:
                                    if case .ArchiveIntro = entry {
                                        hasArchiveInfo = true
                                    }
                                    isEmpty = false
                                    break loop1
                                }
                            }
                            isLoading = true
                            var hasHoles = false
                            loop2: for entry in transition.chatListView.filteredEntries {
                                switch entry {
                                case .HoleEntry:
                                    hasHoles = true
                                case .HeaderEntry:
                                    break
                                default:
                                    isLoading = false
                                    break loop2
                                }
                            }
                            if !hasHoles {
                                isLoading = false
                            }
                        } else {
                            for entry in transition.chatListView.filteredEntries.reversed().prefix(2) {
                                if case .ArchiveIntro = entry {
                                    hasArchiveInfo = true
                                    break
                                }
                            }
                        }
                    }
                
                    let isEmptyState: ChatListNodeEmptyState
                    if transition.chatListView.isLoading {
                        isEmptyState = .empty(isLoading: true, hasArchiveInfo: hasArchiveInfo)
                    } else if isEmpty {
                        isEmptyState = .empty(isLoading: isLoading, hasArchiveInfo: false)
                    } else {
                        var containsChats = false
                        var threadCount = 0
                        var hasGeneral = false
                        var hasArchive = false
                        loop: for entry in transition.chatListView.filteredEntries {
                            switch entry {
                            case .GroupReferenceEntry, .HoleEntry, .PeerEntry, .ContactEntry:
                                if case .GroupReferenceEntry = entry {
                                    hasArchive = true
                                } else {
                                    containsChats = true
                                }
                                if case .forum = strongSelf.location {
                                    if case let .PeerEntry(peerEntry) = entry, let threadInfo = peerEntry.threadInfo {
                                        if threadInfo.id == 1 {
                                            hasGeneral = true
                                        }
                                        threadCount += 1
                                        if threadCount > 1 {
                                            break loop
                                        }
                                    }
                                } else {
                                    break loop
                                }
                            case .ArchiveIntro, .EmptyIntro, .SectionHeader, .Notice, .HeaderEntry, .AdditionalCategory:
                                break
                            }
                        }
                        isEmptyState = .notEmpty(containsChats: containsChats || hasArchive, onlyArchive: hasArchive && !containsChats, onlyGeneralThread: hasGeneral && threadCount == 1)
                    }
                    
                    var insertedPeerIds: [EnginePeer.Id] = []
                    for item in transition.insertItems {
                        if let item = item.item as? ChatListItem {
                            switch item.content {
                            case .loading:
                                break
                            case let .peer(peerData):
                                insertedPeerIds.append(peerData.peer.peerId)
                            case .groupReference:
                                break
                            }
                        }
                    }
                    if !insertedPeerIds.isEmpty {
                        strongSelf.addedVisibleChatsWithPeerIds?(insertedPeerIds)
                    }
                    
                    var isEmptyUpdate: ContainedViewLayoutTransition = .immediate
                    if transition.options.contains(.AnimateInsertion) || transition.animateCrossfade {
                        isEmptyUpdate = .animated(duration: 0.25, curve: .easeInOut)
                    }
                    
                    if strongSelf.currentIsEmptyState != isEmptyState {
                        strongSelf.currentIsEmptyState = isEmptyState
                        strongSelf.isEmptyUpdated?(isEmptyState, transition.chatListView.filter != nil, isEmptyUpdate)
                    }
                    
                    if !strongSelf.hasUpdatedAppliedChatListFilterValueOnce || transition.chatListView.filter != strongSelf.currentAppliedChatListFilterValue {
                        strongSelf.currentAppliedChatListFilterValue = transition.chatListView.filter
                        strongSelf.appliedChatListFilterValue.set(.single(transition.chatListView.filter))
                    }
                    
                    completion()
                }
            }
            
            var options = transition.options
            //options.insert(.Synchronous)
            if self.view.window != nil || self.synchronousDrawingWhenNotAnimated {
                if !options.contains(.AnimateInsertion) {
                    options.insert(.PreferSynchronousDrawing)
                    options.insert(.PreferSynchronousResourceLoading)
                }
                if options.contains(.AnimateCrossfade) && !self.isDeceleratingAfterTracking {
                    options.insert(.PreferSynchronousDrawing)
                }
            }
            
            var scrollToItem = transition.scrollToItem
            if transition.adjustScrollToFirstItem {
                var offset: CGFloat = 0.0
                if let visibleTopInset = self.visibleTopInset {
                    offset = visibleTopInset - self.insets.top
                } else {
                    switch self.visibleContentOffset() {
                    case let .known(value) where abs(value) < .ulpOfOne:
                        offset = 0.0
                    default:
                        offset = -self.scrollHeightTopInset
                    }
                }
                scrollToItem = ListViewScrollToItem(index: 0, position: .top(offset), animated: false, curve: .Default(duration: 0.0), directionHint: .Up)
            }
            
            let updatedOpaqueState: Any? = ChatListOpaqueTransactionState(chatListView: transition.chatListView)
            self.transaction(deleteIndices: transition.deleteItems, insertIndicesAndItems: transition.insertItems, updateIndicesAndItems: transition.updateItems, options: options, scrollToItem: scrollToItem, stationaryItemRange: transition.stationaryItemRange, updateOpaqueState: updatedOpaqueState, completion: completion)
        }
    }
    
    var isNavigationHidden: Bool {
        switch self.visibleContentOffset() {
        case let .known(value) where abs(value) < self.scrollHeightTopInset - 1.0:
            return false
        case .none:
            return false
        default:
            return true
        }
    }
    
    var isNavigationInAFinalState: Bool {
        switch self.visibleContentOffset() {
        case let .known(value):
            let _ = value
            /*if value < self.scrollHeightTopInset - 1.0 {
                if abs(value - 0.0) < 1.0 {
                    return true
                }
                if abs(value - self.scrollHeightTopInset) < 1.0 {
                    return true
                }
                return false
            } else {*/
                return true
            //}
        default:
            return true
        }
    }
    
    func adjustScrollOffsetForNavigation(isNavigationHidden: Bool) {
        if self.isNavigationHidden == isNavigationHidden {
            return
        }
        var scrollToItem: ListViewScrollToItem?
        switch self.visibleContentOffset() {
        case let .known(value) where abs(value) < self.scrollHeightTopInset - 1.0:
            if isNavigationHidden {
                scrollToItem = ListViewScrollToItem(index: 0, position: .top(-self.scrollHeightTopInset), animated: false, curve: .Default(duration: 0.0), directionHint: .Up)
            }
        default:
            if !isNavigationHidden {
                scrollToItem = ListViewScrollToItem(index: 0, position: .top(0.0), animated: false, curve: .Default(duration: 0.0), directionHint: .Up)
            }
        }
        if let scrollToItem = scrollToItem {
            self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: scrollToItem, updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        }
    }
    
    public func fixContentOffset(offset: CGFloat) {
        let _ = self.scrollToOffsetFromTop(offset, animated: false)
        
        /*let scrollToItem: ListViewScrollToItem = ListViewScrollToItem(index: 0, position: .top(-offset), animated: false, curve: .Default(duration: 0.0), directionHint: .Up)
        self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: scrollToItem, updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })*/
    }
    
    public var ignoreStoryInsetAdjustment: Bool = false
    private var previousStoriesInset: CGFloat?
    
    public func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets, visibleTopInset: CGFloat, originalTopInset: CGFloat, storiesInset: CGFloat, inlineNavigationLocation: ChatListControllerLocation?, inlineNavigationTransitionFraction: CGFloat) {
        //print("inset: \(updateSizeAndInsets.insets.top)")
        
        var highlightedLocation: ChatListHighlightedLocation?
        if case let .forum(peerId) = inlineNavigationLocation {
            highlightedLocation = ChatListHighlightedLocation(location: .peer(id: peerId), progress: inlineNavigationTransitionFraction)
        }
        var navigationLocationPresenceUpdated = false
        if (self.interaction?.inlineNavigationLocation == nil) != (highlightedLocation == nil) {
            navigationLocationPresenceUpdated = true
        }
        
        var navigationLocationUpdated = false
        if self.interaction?.inlineNavigationLocation != highlightedLocation {
            self.interaction?.inlineNavigationLocation = highlightedLocation
            navigationLocationUpdated = true
        }
        
        let insetDelta: CGFloat = 0.0
        if navigationLocationPresenceUpdated {
            let targetTopInset: CGFloat
            if highlightedLocation != nil {
                targetTopInset = self.visibleTopInset ?? self.insets.top
            } else {
                targetTopInset = self.originalTopInset ?? self.insets.top
            }
            let immediateInsetDelta = self.insets.top - targetTopInset
            
            self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, additionalScrollDistance: immediateInsetDelta, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: self.visibleSize, insets: UIEdgeInsets(top: targetTopInset, left: self.insets.left, bottom: self.insets.bottom, right: self.insets.right), duration: 0.0, curve: .Default(duration: 0.0)), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        }
        
        self.visualInsets = UIEdgeInsets(top: visibleTopInset, left: 0.0, bottom: 0.0, right: 0.0)
            
        self.visibleTopInset = visibleTopInset
        self.originalTopInset = originalTopInset
        
        var additionalScrollDistance: CGFloat = 0.0
        
        if let previousStoriesInset = self.previousStoriesInset {
            if self.ignoreStoryInsetAdjustment {
                //additionalScrollDistance += -20.0
                switch self.visibleContentOffset() {
                case let .known(value):
                    additionalScrollDistance += min(0.0, value)
                default:
                    break
                }
                additionalScrollDistance = 0.0
            } else {
                additionalScrollDistance += previousStoriesInset - storiesInset
            }
        }
        self.previousStoriesInset = storiesInset
        //print("storiesInset: \(storiesInset), additionalScrollDistance: \(additionalScrollDistance)")
        
        var options: ListViewDeleteAndInsertOptions = [.Synchronous, .LowLatency]
        if navigationLocationUpdated {
            options.insert(.ForceUpdate)
            
            if transition.isAnimated {
                options.insert(.AnimateInsertion)
            }
            
            additionalScrollDistance += insetDelta
        }
        self.ignoreStopScrolling = true
        self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: options, scrollToItem: nil, additionalScrollDistance: additionalScrollDistance, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        self.ignoreStopScrolling = false
        
        if !self.dequeuedInitialTransitionOnLayout {
            self.dequeuedInitialTransitionOnLayout = true
            
            self.dequeueTransition()
        }
    }
    
    public func scrollToPosition(_ position: ChatListNodeScrollPosition, animated: Bool = true) {
        var additionalDelta: CGFloat = 0.0
        switch position {
        case let .top(adjustForTempInset):
            if adjustForTempInset {
                additionalDelta = ChatListNavigationBar.storiesScrollHeight
                self.tempTopInset = ChatListNavigationBar.storiesScrollHeight
            }
        }
        
        if let list = self.chatListView?.originalList {
            if !list.hasLater {
                self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: ListViewScrollToItem(index: 0, position: .top(additionalDelta), animated: animated, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            } else {
                let location: ChatListNodeLocation = .scroll(index: .chatList(.absoluteUpperBound), sourceIndex: .chatList(.absoluteLowerBound), scrollPosition: .top(additionalDelta), animated: animated, filter: self.chatListFilter)
                self.setChatListLocation(location)
            }
        } else {
            let location: ChatListNodeLocation = .scroll(index: .chatList(.absoluteUpperBound), sourceIndex: .chatList(.absoluteLowerBound), scrollPosition: .top(additionalDelta), animated: animated, filter: self.chatListFilter)
            self.setChatListLocation(location)
        }
    }
    
    private func setChatListLocation(_ location: ChatListNodeLocation) {
        self.currentLocation = location
        self.chatListLocation.set(location)
    }
    
    private func relativeUnreadChatListIndex(position: EngineChatList.RelativePosition) -> Signal<EngineChatList.Item.Index?, NoError> {
        guard case let .chatList(groupId) = self.location else {
            return .single(nil)
        }
        
        let engine = self.context.engine
        return self.context.sharedContext.accountManager.transaction { transaction -> Signal<EngineChatList.Item.Index?, NoError> in
            var filter = true
            if let inAppNotificationSettings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.inAppNotificationSettings)?.get(InAppNotificationSettings.self) {
                switch inAppNotificationSettings.totalUnreadCountDisplayStyle {
                    case .filtered:
                        filter = true
                }
            }
            return engine.messages.getRelativeUnreadChatListIndex(filtered: filter, position: position, groupId: groupId)
        }
        |> switchToLatest
    }
    
    public func selectChat(_ option: ChatListSelectionOption) {
        guard let interaction = self.interaction else {
            return
        }
        
        guard let chatListView = (self.opaqueTransactionState as? ChatListOpaqueTransactionState)?.chatListView else {
            return
        }
        
        guard let range = self.displayedItemRange.loadedRange else {
            return
        }
        
        let entryCount = chatListView.filteredEntries.count
        var current: (EngineChatList.Item.Index, EnginePeer, Int)? = nil
        var previous: (EngineChatList.Item.Index, EnginePeer)? = nil
        var next: (EngineChatList.Item.Index, EnginePeer)? = nil
        
        outer: for i in range.firstIndex ..< range.lastIndex {
            if i < 0 || i >= entryCount {
                assertionFailure()
                continue
            }
            switch chatListView.filteredEntries[entryCount - i - 1] {
                case let .PeerEntry(peerEntry):
                    if interaction.highlightedChatLocation?.location == ChatLocation.peer(id: peerEntry.peer.peerId) {
                        current = (peerEntry.index, peerEntry.peer.peer!, entryCount - i - 1)
                        break outer
                    }
                default:
                    break
            }
        }
        
        switch option {
            case .previous(unread: true), .next(unread: true):
                let position: EngineChatList.RelativePosition
                if let current = current {
                    if case .previous = option {
                        position = .earlier(than: current.0)
                    } else {
                        position = .later(than: current.0)
                    }
                } else {
                    position = .later(than: nil)
                }
                let engine = self.context.engine
                let _ = (relativeUnreadChatListIndex(position: position)
                |> mapToSignal { index -> Signal<(EngineChatList.Item.Index, EnginePeer)?, NoError> in
                    if case let .chatList(index) = index {
                        return engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: index.messageIndex.id.peerId))
                        |> map { peer -> (EngineChatList.Item.Index, EnginePeer)? in
                            return peer.flatMap { peer -> (EngineChatList.Item.Index, EnginePeer)? in
                                (.chatList(index), peer)
                            }
                        }
                    } else {
                        return .single(nil)
                    }
                }
                |> deliverOnMainQueue).startStandalone(next: { [weak self] indexAndPeer in
                    guard let strongSelf = self, let (index, peer) = indexAndPeer else {
                        return
                    }
                    let location: ChatListNodeLocation = .scroll(index: index, sourceIndex: strongSelf.currentlyVisibleLatestChatListIndex() ?? .chatList(.absoluteLowerBound), scrollPosition: .center(.top), animated: true, filter: strongSelf.chatListFilter)
                    strongSelf.setChatListLocation(location)
                    strongSelf.peerSelected?(peer, nil, false, false, nil)
                })
            case .previous(unread: false), .next(unread: false):
                var target: (EngineChatList.Item.Index, EnginePeer)? = nil
                if let current = current, entryCount > 1 {
                    if current.2 > 0, case let .PeerEntry(peerEntry) = chatListView.filteredEntries[current.2 - 1] {
                        next = (peerEntry.index, peerEntry.peer.peer!)
                    }
                    if current.2 <= entryCount - 2, case let .PeerEntry(peerEntry) = chatListView.filteredEntries[current.2 + 1] {
                        previous = (peerEntry.index, peerEntry.peer.peer!)
                    }
                    if case .previous = option {
                        target = previous
                    } else {
                        target = next
                    }
                } else if entryCount > 0 {
                    if case let .PeerEntry(peerEntry) = chatListView.filteredEntries[entryCount - 1] {
                        target = (peerEntry.index, peerEntry.peer.peer!)
                    }
                }
                if let target = target {
                    let location: ChatListNodeLocation = .scroll(index: target.0, sourceIndex: .chatList(.absoluteLowerBound), scrollPosition: .center(.top), animated: true, filter: self.chatListFilter)
                    self.setChatListLocation(location)
                    self.peerSelected?(target.1, nil, false, false, nil)
                }
            case let .peerId(peerId):
                let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
                    guard let strongSelf = self, let peer = peer else {
                        return
                    }
                    strongSelf.peerSelected?(peer, nil, false, false, nil)
                })
            case let .index(index):
                guard index < 10 else {
                    return
                }
                let _ = (self.chatListFilterValue.get()
                |> take(1)
                |> deliverOnMainQueue).startStandalone(next: { [weak self] filter in
                    guard let self = self else {
                        return
                    }
                    guard case let .chatList(groupId) = self.location else {
                        return
                    }
                    
                    let shouldLoadCanMessagePeer: Bool
                    if case .peers = self.mode {
                        shouldLoadCanMessagePeer = true
                    } else {
                        shouldLoadCanMessagePeer = false
                    }
                    
                    let _ = (chatListViewForLocation(chatListLocation: .chatList(groupId: groupId), location: .initial(count: 10, filter: filter), account: self.context.account, shouldLoadCanMessagePeer: shouldLoadCanMessagePeer)
                    |> take(1)
                    |> deliverOnMainQueue).startStandalone(next: { update in
                        let items = update.list.items
                        if items.count > index {
                            let item = items[9 - index - 1]
                            let location: ChatListNodeLocation = .scroll(index: item.index, sourceIndex: .chatList(.absoluteLowerBound), scrollPosition: .center(.top), animated: true, filter: filter)
                            self.setChatListLocation(location)
                            self.peerSelected?(EnginePeer(item.renderedPeer.peer!._asPeer()), nil, false, false, nil)
                        }
                    })
                })
        }
    }
    
    private func enqueueHistoryPreloadUpdate() {
    }
    
    public func updateSelectedChatLocation(_ chatLocation: ChatLocation?, progress: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let interaction = self.interaction else {
            return
        }
        
        if let chatLocation = chatLocation {
            interaction.highlightedChatLocation = ChatListHighlightedLocation(location: chatLocation, progress: progress)
        } else {
            interaction.highlightedChatLocation = nil
        }
        
        self.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatListItemNode {
                itemNode.updateIsHighlighted(transition: transition)
            }
        }
    }
    
    private func currentlyVisibleLatestChatListIndex() -> EngineChatList.Item.Index? {
        guard let chatListView = (self.opaqueTransactionState as? ChatListOpaqueTransactionState)?.chatListView else {
            return nil
        }
        if let range = self.displayedItemRange.visibleRange {
            let entryCount = chatListView.filteredEntries.count
            for i in range.firstIndex ..< range.lastIndex {
                if i < 0 || i >= entryCount {
                    assertionFailure()
                    continue
                }
                switch chatListView.filteredEntries[entryCount - i - 1] {
                    case let .PeerEntry(peerEntry):
                        return peerEntry.index
                    default:
                        break
                }
            }
        }
        return nil
    }
    
    private func peerAtPoint(_ point: CGPoint) -> EnginePeer? {
        var resultPeer: EnginePeer?
        self.forEachVisibleItemNode { itemNode in
            if resultPeer == nil, let itemNode = itemNode as? ListViewItemNode, itemNode.frame.contains(point) {
                if let itemNode = itemNode as? ChatListItemNode, let item = itemNode.item {
                    switch item.content {
                        case let .peer(peerData):
                            resultPeer = peerData.peer.peer
                        default:
                            break
                    }
                }
            }
        }
        return resultPeer
    }
    
    private func threadIdAtPoint(_ point: CGPoint) -> Int64? {
        var resultThreadId: Int64?
        self.forEachVisibleItemNode { itemNode in
            if resultThreadId == nil, let itemNode = itemNode as? ListViewItemNode, itemNode.frame.contains(point) {
                if let itemNode = itemNode as? ChatListItemNode, let item = itemNode.item {
                    switch item.content {
                        case let .peer(peerData):
                            resultThreadId = peerData.threadInfo?.id
                        default:
                            break
                    }
                }
            }
        }
        return resultThreadId
    }
    
    private var selectionPanState: (selecting: Bool, initialPeerId: EnginePeer.Id, toggledPeerIds: [[EnginePeer.Id]])?
    private var threadSelectionPanState: (selecting: Bool, initialThreadId: Int64, toggledThreadIds: [[Int64]])?
    private var selectionScrollActivationTimer: SwiftSignalKit.Timer?
    private var selectionScrollDisplayLink: ConstantDisplayLinkAnimator?
    private var selectionScrollDelta: CGFloat?
    private var selectionLastLocation: CGPoint?
    
    @objc private func selectionPanGesture(_ recognizer: UIGestureRecognizer) -> Void {
        let location = recognizer.location(in: self.view)
        switch recognizer.state {
            case .began:
                switch self .location {
                case .chatList:
                    if let peer = self.peerAtPoint(location) {
                        let selecting = !self.currentState.selectedPeerIds.contains(peer.id)
                        self.selectionPanState = (selecting, peer.id, [])
                        self.interaction?.togglePeersSelection([.peer(peer)], selecting)
                    }
                case .forum:
                    if let threadId = self.threadIdAtPoint(location) {
                        let selecting = !self.currentState.selectedThreadIds.contains(threadId)
                        self.threadSelectionPanState = (selecting, threadId, [])
                        self.interaction?.toggleThreadsSelection([threadId], selecting)
                    }
                case .savedMessagesChats:
                    break
                }
            case .changed:
                self.handlePanSelection(location: location)
                self.selectionLastLocation = location
            case .ended, .failed, .cancelled:
                self.threadSelectionPanState = nil
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
        
        var hasState = false
        switch self.location {
        case .chatList:
            if let state = self.selectionPanState {
                hasState = true
                if let peer = self.peerAtPoint(location) {
                    if peer.id == state.initialPeerId {
                        if !state.toggledPeerIds.isEmpty {
                            self.interaction?.togglePeersSelection(state.toggledPeerIds.flatMap { $0.compactMap({ .peerId($0) }) }, !state.selecting)
                            self.selectionPanState = (state.selecting, state.initialPeerId, [])
                        }
                    } else if state.toggledPeerIds.last?.first != peer.id {
                        var updatedToggledPeerIds: [[EnginePeer.Id]] = []
                        var previouslyToggled = false
                        for i in (0 ..< state.toggledPeerIds.count) {
                            if let peerId = state.toggledPeerIds[i].first {
                                if peerId == peer.id {
                                    previouslyToggled = true
                                    updatedToggledPeerIds = Array(state.toggledPeerIds.prefix(i + 1))
                                    
                                    let peerIdsToToggle = Array(state.toggledPeerIds.suffix(state.toggledPeerIds.count - i - 1)).flatMap { $0 }
                                    self.interaction?.togglePeersSelection(peerIdsToToggle.compactMap { .peerId($0) }, !state.selecting)
                                    break
                                }
                            }
                        }
                        
                        if !previouslyToggled {
                            updatedToggledPeerIds = state.toggledPeerIds
                            let isSelected = self.currentState.selectedPeerIds.contains(peer.id)
                            if state.selecting != isSelected {
                                updatedToggledPeerIds.append([peer.id])
                                self.interaction?.togglePeersSelection([.peer(peer)], state.selecting)
                            }
                        }
                        
                        self.selectionPanState = (state.selecting, state.initialPeerId, updatedToggledPeerIds)
                    }
                }
            }
        case .forum:
            if let state = self.threadSelectionPanState {
                hasState = true
                if let threadId = self.threadIdAtPoint(location) {
                    if threadId == state.initialThreadId {
                        if !state.toggledThreadIds.isEmpty {
                            self.interaction?.toggleThreadsSelection(Array(state.toggledThreadIds.joined()), !state.selecting)
                            self.threadSelectionPanState = (state.selecting, state.initialThreadId, [])
                        }
                    } else if state.toggledThreadIds.last?.first != threadId {
                        var updatedToggledThreadIds: [[Int64]] = []
                        var previouslyToggled = false
                        for i in (0 ..< state.toggledThreadIds.count) {
                            if let toggledThreadId = state.toggledThreadIds[i].first {
                                if toggledThreadId == threadId {
                                    previouslyToggled = true
                                    updatedToggledThreadIds = Array(state.toggledThreadIds.prefix(i + 1))
                                    
                                    let threadIdsToToggle = Array(state.toggledThreadIds.suffix(state.toggledThreadIds.count - i - 1)).flatMap { $0 }
                                    self.interaction?.toggleThreadsSelection(threadIdsToToggle.compactMap { $0 }, !state.selecting)
                                    break
                                }
                            }
                        }
                        
                        if !previouslyToggled {
                            updatedToggledThreadIds = state.toggledThreadIds
                            let isSelected = self.currentState.selectedThreadIds.contains(threadId)
                            if state.selecting != isSelected {
                                updatedToggledThreadIds.append([threadId])
                                self.interaction?.toggleThreadsSelection([threadId], state.selecting)
                            }
                        }
                        
                        self.threadSelectionPanState = (state.selecting, state.initialThreadId, updatedToggledThreadIds)
                    }
                }
            }
        case .savedMessagesChats:
            break
        }
        guard hasState else {
            return
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
}

private func statusStringForPeerType(accountPeerId: EnginePeer.Id, strings: PresentationStrings, peer: EnginePeer, isMuted: Bool, isUnread: Bool, isContact: Bool, hasUnseenMentions: Bool, chatListFilters: [ChatListFilter]?, displayAutoremoveTimeout: Bool, autoremoveTimeout: Int32?) -> (NSAttributedString, Bool, Bool, ContactsPeerItemStatus.Icon?)? {
    if accountPeerId == peer.id {
        return nil
    }
    
    if displayAutoremoveTimeout {
        if let autoremoveTimeout = autoremoveTimeout {
            return (NSAttributedString(string: strings.ChatList_LabelAutodeleteAfter(timeIntervalString(strings: strings, value: autoremoveTimeout, usage: .afterTime)).string), false, true, .autoremove)
        } else {
            return (NSAttributedString(string: strings.ChatList_LabelAutodeleteDisabled), false, false, .autoremove)
        }
    }
    
    if let chatListFilters = chatListFilters {
        let result = NSMutableAttributedString(string: "")
        for case let .filter(_, title, _, data) in chatListFilters {
            let predicate = chatListFilterPredicate(filter: data, accountPeerId: accountPeerId)
            if predicate.includes(peer: peer._asPeer(), groupId: .root, isRemovedFromTotalUnreadCount: isMuted, isUnread: isUnread, isContact: isContact, messageTagSummaryResult: hasUnseenMentions) {
                if result.length != 0 {
                    result.append(NSAttributedString(string: ", "))
                }
                result.append(title.rawAttributedString)
            }
        }
        
        if result.length == 0 {
            return nil
        } else {
            return (result, true, false, nil)
        }
    }
    
    if peer.id.isReplies || peer.id.isVerificationCodes {
        return nil
    } else if case let .user(user) = peer {
        if user.botInfo != nil || user.flags.contains(.isSupport) {
            return (NSAttributedString(string: strings.ChatList_PeerTypeBot), false, false, nil)
        } else {
            if isContact {
                return (NSAttributedString(string: strings.ChatList_PeerTypeContact), false, false, nil)
            } else {
                return (NSAttributedString(string: strings.ChatList_PeerTypeNonContactUser), false, false, nil)
            }
        }
    } else if case .secretChat = peer {
        if isContact {
            return (NSAttributedString(string: strings.ChatList_PeerTypeContact), false, false, nil)
        } else {
            return (NSAttributedString(string: strings.ChatList_PeerTypeNonContactUser), false, false, nil)
        }
    } else if case .legacyGroup = peer {
        return (NSAttributedString(string: strings.ChatList_PeerTypeGroup), false, false, nil)
    } else if case let .channel(channel) = peer {
        if case .group = channel.info {
            return (NSAttributedString(string: strings.ChatList_PeerTypeGroup), false, false, nil)
        } else {
            return (NSAttributedString(string: strings.ChatList_PeerTypeChannel), false, false, nil)
        }
    }
    return (NSAttributedString(string: strings.ChatList_PeerTypeNonContactUser), false, false, nil)
}

public class ChatHistoryListSelectionRecognizer: UIPanGestureRecognizer {
    private let selectionGestureActivationThreshold: CGFloat = 5.0
    
    var recognized: Bool? = nil
    var initialLocation: CGPoint = CGPoint()
    
    public var shouldBegin: (() -> Bool)?
    
    public override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.minimumNumberOfTouches = 2
        self.maximumNumberOfTouches = 2
    }
    
    public override func reset() {
        super.reset()
        
        self.recognized = nil
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if let shouldBegin = self.shouldBegin, !shouldBegin() {
            self.state = .failed
        } else {
            let touch = touches.first!
            self.initialLocation = touch.location(in: self.view)
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let location = touches.first!.location(in: self.view)
        let translation = location.offsetBy(dx: -self.initialLocation.x, dy: -self.initialLocation.y)
        
        let touchesArray = Array(touches)
        if self.recognized == nil, touchesArray.count == 2 {
            if let firstTouch = touchesArray.first, let secondTouch = touchesArray.last {
                let firstLocation = firstTouch.location(in: self.view)
                let secondLocation = secondTouch.location(in: self.view)
                
                func distance(_ v1: CGPoint, _ v2: CGPoint) -> CGFloat {
                    let dx = v1.x - v2.x
                    let dy = v1.y - v2.y
                    return sqrt(dx * dx + dy * dy)
                }
                if distance(firstLocation, secondLocation) > 200.0 {
                    self.state = .failed
                }
            }
            if self.state != .failed && (abs(translation.y) >= selectionGestureActivationThreshold) {
                self.recognized = true
            }
        }
        
        if let recognized = self.recognized, recognized {
            super.touchesMoved(touches, with: event)
        }
    }
}

func hideChatListContacts(context: AccountContext) {
    let _ = ApplicationSpecificNotice.setDisplayChatListContacts(accountManager: context.sharedContext.accountManager).startStandalone()
}

func chatListItemTags(location: ChatListControllerLocation, accountPeerId: EnginePeer.Id, isPremium: Bool, peer: EnginePeer?, isUnread: Bool, isMuted: Bool, isContact: Bool, hasUnseenMentions: Bool, chatListFilters: [ChatListFilter]?) -> [ChatListItemContent.Tag] {
    if !isPremium {
        return []
    }
    if case .chatList = location {
    } else {
        return []
    }
    guard let chatListFilters, !chatListFilters.isEmpty else {
        return []
    }
    guard let peer else {
        return []
    }
    
    var result: [ChatListItemContent.Tag] = []
    for case let .filter(id, title, _, data) in chatListFilters {
        if data.color != nil {
            let predicate = chatListFilterPredicate(filter: data, accountPeerId: accountPeerId)
            if predicate.pinnedPeerIds.contains(peer.id) || predicate.includes(peer: peer._asPeer(), groupId: .root, isRemovedFromTotalUnreadCount: isMuted, isUnread: isUnread, isContact: isContact, messageTagSummaryResult: hasUnseenMentions) {
                result.append(ChatListItemContent.Tag(
                    id: id,
                    title: title,
                    colorId: data.color?.rawValue ?? PeerNameColor.blue.rawValue
                ))
            }
        }
    }
    return result
}
