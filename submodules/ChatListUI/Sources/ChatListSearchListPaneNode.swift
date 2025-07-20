import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import PresentationDataUtils
import AccountContext
import MergeLists
import ItemListUI
import ContextUI
import ContactListUI
import ContactsPeerItem
import PhotoResources
import TelegramUIPreferences
import UniversalMediaPlayer
import TelegramBaseController
import OverlayStatusController
import ListMessageItem
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import ChatListSearchItemHeader
import PhoneNumberFormat
import InstantPageUI
import GalleryData
import AppBundle
import ShimmerEffect
import ChatListSearchRecentPeersNode
import UndoUI
import Postbox
import FetchManagerImpl
import AnimationCache
import MultiAnimationRenderer
import AvatarNode

private enum ChatListRecentEntryStableId: Hashable {
    case topPeers
    case peerId(EnginePeer.Id, ChatListRecentEntry.Section)
    case footer
}

private enum ChatListRecentEntry: Comparable, Identifiable {
    enum Section {
        case local
        case recommendedChannels
        case popularApps
    }
    
    case topPeers([EnginePeer], PresentationTheme, PresentationStrings)
    case peer(index: Int, peer: RecentlySearchedPeer, Section, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, PresentationPersonNameOrder, EngineGlobalNotificationSettings, PeerStoryStats?, Bool)
    case footer(PresentationTheme, String)
    
    var stableId: ChatListRecentEntryStableId {
        switch self {
        case .topPeers:
            return .topPeers
        case let .peer(_, peer, section, _, _, _, _, _, _, _, _):
            return .peerId(peer.peer.peerId, section)
        case .footer:
            return .footer
        }
    }
    
    static func ==(lhs: ChatListRecentEntry, rhs: ChatListRecentEntry) -> Bool {
        switch lhs {
            case let .topPeers(lhsPeers, lhsTheme, lhsStrings):
                if case let .topPeers(rhsPeers, rhsTheme, rhsStrings) = rhs {
                    if lhsPeers != rhsPeers {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .peer(lhsIndex, lhsPeer, lhsSection, lhsTheme, lhsStrings, lhsTimeFormat, lhsSortOrder, lhsDisplayOrder, lhsGlobalNotificationsSettings, lhsStoryStats, lhsRequiresPremiumForMessaging):
                if case let .peer(rhsIndex, rhsPeer, rhsSection, rhsTheme, rhsStrings, rhsTimeFormat, rhsSortOrder, rhsDisplayOrder, rhsGlobalNotificationsSettings, rhsStoryStats, rhsRequiresPremiumForMessaging) = rhs, lhsPeer == rhsPeer && lhsSection == rhsSection && lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings && lhsTimeFormat == rhsTimeFormat && lhsSortOrder == rhsSortOrder && lhsDisplayOrder == rhsDisplayOrder && lhsGlobalNotificationsSettings == rhsGlobalNotificationsSettings && lhsStoryStats == rhsStoryStats && lhsRequiresPremiumForMessaging == rhsRequiresPremiumForMessaging {
                    return true
                } else {
                    return false
                }
            case let .footer(lhsTheme, lhsText):
                if case let .footer(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChatListRecentEntry, rhs: ChatListRecentEntry) -> Bool {
        switch lhs {
            case .topPeers:
                return true
            case let .peer(lhsIndex, _, _, _, _, _, _, _, _, _, _):
                switch rhs {
                case .topPeers:
                    return false
                case let .peer(rhsIndex, _, _, _, _, _, _, _, _, _, _):
                    return lhsIndex <= rhsIndex
                case .footer:
                    return true
                }
            case .footer:
                return false
        }
    }
    
    func item(
        context: AccountContext,
        presentationData: ChatListPresentationData,
        filter: ChatListNodePeersFilter,
        key: ChatListSearchPaneKey,
        peerSelected: @escaping (EnginePeer, Int64?, Bool, OpenPeerAction) -> Void,
        disabledPeerSelected: @escaping (EnginePeer, Int64?, ChatListDisabledPeerReason) -> Void,
        peerContextAction: ((EnginePeer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?,
        clearRecentlySearchedPeers: @escaping () -> Void,
        deletePeer: @escaping (EnginePeer.Id) -> Void,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        openStories: @escaping (EnginePeer.Id, AvatarNode) -> Void,
        isChannelsTabExpanded: Bool?,
        toggleChannelsTabExpanded: @escaping () -> Void,
        openTopAppsInfo: @escaping () -> Void
    ) -> ListViewItem {
        switch self {
            case let .topPeers(peers, theme, strings):
                return ChatListRecentPeersListItem(theme: theme, strings: strings, context: context, peers: peers, peerSelected: { peer in
                    peerSelected(peer, nil, false, .generic)
                }, peerContextAction: { peer, node, gesture, location in
                    if let peerContextAction = peerContextAction {
                        peerContextAction(peer, .recentPeers(isTopPeer: true), node, gesture, location)
                    } else {
                        gesture?.cancel()
                    }
                })
            case let .peer(_, peer, section, theme, strings, timeFormat, nameSortOrder, nameDisplayOrder, globalNotificationSettings, storyStats, requiresPremiumForMessaging):
                let primaryPeer: EnginePeer
                var chatPeer: EnginePeer?
                let maybeChatPeer = EnginePeer(peer.peer.peers[peer.peer.peerId]!)
                if case .secretChat = maybeChatPeer, let associatedPeerId = maybeChatPeer._asPeer().associatedPeerId, let associatedPeer = peer.peer.peers[associatedPeerId] {
                    primaryPeer = EnginePeer(associatedPeer)
                    chatPeer = maybeChatPeer
                } else if case .channel = maybeChatPeer, let mainChannel = peer.peer.chatOrMonoforumMainPeer {
                    primaryPeer = EnginePeer(mainChannel)
                    chatPeer = maybeChatPeer
                } else {
                    primaryPeer = maybeChatPeer
                    chatPeer = maybeChatPeer
                }
                
                var enabled = true
                if filter.contains(.onlyWriteable) {
                    if let peer = chatPeer {
                        enabled = canSendMessagesToPeer(peer._asPeer())
                    } else {
                        enabled = canSendMessagesToPeer(primaryPeer._asPeer())
                    }
                    if requiresPremiumForMessaging {
                        enabled = false
                    }
                }
                if filter.contains(.onlyPrivateChats) {
                    if let peer = chatPeer {
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
                    if let peer = chatPeer {
                        if case .legacyGroup = peer {
                        } else if case let .channel(peer) = peer, case .group = peer.info {
                        } else {
                            enabled = false
                        }
                    } else {
                        enabled = false
                    }
                }
                
                if filter.contains(.excludeChannels) {
                    if case let .channel(channel) = primaryPeer, case .broadcast = channel.info {
                        enabled = false
                    }
                }
                
                let status: ContactsPeerItemStatus
                if primaryPeer.id.isRepliesOrVerificationCodes {
                    status = .none
                } else if case let .user(user) = primaryPeer {
                    let servicePeer = isServicePeer(primaryPeer._asPeer())
                    if user.flags.contains(.isSupport) && !servicePeer {
                        status = .custom(string: NSAttributedString(string: strings.Bot_GenericSupportStatus), multiline: false, isActive: false, icon: nil)
                    } else if let _ = user.botInfo {
                        if let subscriberCount = user.subscriberCount {
                            status = .custom(string: NSAttributedString(string: strings.Conversation_StatusBotSubscribers(subscriberCount)), multiline: false, isActive: false, icon: nil)
                        } else {
                            status = .custom(string: NSAttributedString(string: strings.Bot_GenericBotStatus), multiline: false, isActive: false, icon: nil)
                        }
                    } else if user.id != context.account.peerId && !servicePeer {
                        let presence = peer.presence ?? TelegramUserPresence(status: .none, lastActivity: 0)
                        status = .presence(EnginePeer.Presence(presence), timeFormat)
                    } else {
                        status = .none
                    }
                } else if case let .legacyGroup(group) = primaryPeer {
                    status = .custom(string: NSAttributedString(string: strings.GroupInfo_ParticipantCount(Int32(group.participantCount))), multiline: false, isActive: false, icon: nil)
                } else if case let .channel(channel) = primaryPeer {
                    if case .group = channel.info {
                        if let count = peer.subpeerSummary?.count, count > 0 {
                            status = .custom(string: NSAttributedString(string: strings.GroupInfo_ParticipantCount(Int32(count))), multiline: false, isActive: false, icon: nil)
                        } else {
                            status = .custom(string: NSAttributedString(string: strings.Group_Status), multiline: false, isActive: false, icon: nil)
                        }
                    } else {
                        if let count = peer.subpeerSummary?.count, count > 0 {
                            status = .custom(string: NSAttributedString(string: strings.Conversation_StatusSubscribers(Int32(count))), multiline: false, isActive: false, icon: nil)
                        } else {
                            status = .custom(string: NSAttributedString(string: strings.Channel_Status), multiline: false, isActive: false, icon: nil)
                        }
                    }
                } else {
                    status = .none
                }
            
                var isMuted = false
                if let notificationSettings = peer.notificationSettings {
                    if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                        isMuted = true
                    } else if case .default = notificationSettings.muteState {
                        if case .user = primaryPeer {
                            isMuted = !globalNotificationSettings.privateChats.enabled
                        } else if case .legacyGroup = primaryPeer {
                            isMuted = !globalNotificationSettings.groupChats.enabled
                        } else if case let .channel(channel) = primaryPeer {
                            switch channel.info {
                            case .group:
                                isMuted = !globalNotificationSettings.groupChats.enabled
                            case .broadcast:
                                isMuted = !globalNotificationSettings.channels.enabled
                            }
                        }
                    }
                }
                
                var badge: ContactsPeerItemBadge?
                if peer.unreadCount > 0 {
                    badge = ContactsPeerItemBadge(count: peer.unreadCount, type: isMuted ? .inactive : .active)
                }
            
                let header: ChatListSearchItemHeader?
                if case .channels = key {
                    if case .recommendedChannels = section {
                        header = ChatListSearchItemHeader(type: .text(presentationData.strings.ChatList_Search_SectionRecommendedChannels, 1), theme: theme, strings: strings)
                    } else {
                        if let isChannelsTabExpanded {
                            header = ChatListSearchItemHeader(type: .text(presentationData.strings.ChatList_Search_SectionLocalChannels, 0), theme: theme, strings: strings, actionTitle: isChannelsTabExpanded ? presentationData.strings.ChatList_Search_SectionActionShowLess : presentationData.strings.ChatList_Search_SectionActionShowMore, action: { _ in
                                toggleChannelsTabExpanded()
                            })
                        } else {
                            header = ChatListSearchItemHeader(type: .text(presentationData.strings.ChatList_Search_SectionLocalChannels, 0), theme: theme, strings: strings, actionTitle: nil, action: nil)
                        }
                    }
                } else if case .apps = key {
                    if case .popularApps = section {
                        header = ChatListSearchItemHeader(type: .text(presentationData.strings.ChatList_Search_SectionPopularApps, 1), theme: theme, strings: strings)
                    } else {
                        if let isChannelsTabExpanded {
                            header = ChatListSearchItemHeader(type: .text(presentationData.strings.ChatList_Search_SectionRecentApps, 0), theme: theme, strings: strings, actionTitle: isChannelsTabExpanded ? presentationData.strings.ChatList_Search_SectionActionShowLess : presentationData.strings.ChatList_Search_SectionActionShowMore, action: { _ in
                                toggleChannelsTabExpanded()
                            })
                        } else {
                            header = ChatListSearchItemHeader(type: .text(presentationData.strings.ChatList_Search_SectionRecentApps, 0), theme: theme, strings: strings, actionTitle: nil, action: nil)
                        }
                    }
                } else {
                    header = ChatListSearchItemHeader(type: .recentPeers, theme: theme, strings: strings, actionTitle: strings.WebSearch_RecentSectionClear, action: { _ in
                        clearRecentlySearchedPeers()
                    })
                }
            
                var buttonAction: ContactsPeerItemButtonAction?
                if [.chats, .apps].contains(key), case let .user(user) = primaryPeer, let botInfo = user.botInfo, botInfo.flags.contains(.hasWebApp) {
                    buttonAction = ContactsPeerItemButtonAction(
                        title: presentationData.strings.ChatList_Search_Open,
                        action: { peer, _, _ in
                            peerSelected(primaryPeer, nil, false, .openApp)
                        }
                    )
                }
            
                var peerMode: ContactsPeerItemPeerMode
                if case .apps = key {
                    peerMode = .app(isPopular: section == .popularApps)
                } else {
                    peerMode = .generalSearch(isSavedMessages: false)
                }
            
                return ContactsPeerItem(
                    presentationData: ItemListPresentationData(theme: presentationData.theme, fontSize: presentationData.fontSize, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, dateTimeFormat: presentationData.dateTimeFormat),
                    sortOrder: nameSortOrder,
                    displayOrder: nameDisplayOrder,
                    context: context,
                    peerMode: peerMode,
                    peer: .peer(peer: primaryPeer, chatPeer: chatPeer),
                    status: status,
                    badge: badge,
                    requiresPremiumForMessaging: requiresPremiumForMessaging,
                    enabled: enabled,
                    selection: .none,
                    editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false),
                    buttonAction: buttonAction,
                    index: nil,
                    header: header,
                    alwaysShowLastSeparator: key == .apps,
                    action: { _ in
                        if let chatPeer = peer.peer.peers[peer.peer.peerId] {
                            peerSelected(EnginePeer(chatPeer), nil, section == .recommendedChannels, section == .popularApps ? .info : .generic)
                        }
                    },
                    disabledAction: { _ in
                        if let chatPeer = peer.peer.peers[peer.peer.peerId] {
                            disabledPeerSelected(EnginePeer(chatPeer), nil, requiresPremiumForMessaging ? .premiumRequired : .generic)
                        }
                    },
                    deletePeer: deletePeer,
                    contextAction: (key == .channels || section == .popularApps) ? nil : peerContextAction.flatMap { peerContextAction in
                        return { node, gesture, location in
                            if let chatPeer = peer.peer.peers[peer.peer.peerId] {
                                let source: ChatListSearchContextActionSource
                                
                                if key == .apps {
                                    if case .popularApps = section {
                                        source = .popularApps
                                    } else {
                                        source = .recentApps
                                    }
                                } else {
                                    source = .recentSearch
                                }
                                
                                peerContextAction(EnginePeer(chatPeer), source, node, gesture, location)
                            } else {
                                gesture?.cancel()
                            }
                        }
                    },
                    animationCache: animationCache,
                    animationRenderer: animationRenderer,
                    storyStats: storyStats.flatMap { stats in
                        return (stats.totalCount, unseen: stats.unseenCount, stats.hasUnseenCloseFriends)
                    },
                    openStories: { itemPeer, sourceNode in
                        guard case let .peer(_, chatPeer) = itemPeer, let peer = chatPeer else {
                            return
                        }
                        if let sourceNode = sourceNode as? ContactsPeerItemNode {
                            openStories(peer.id, sourceNode.avatarNode)
                        }
                    }
                )
        case let .footer(_, text):
            return ItemListTextItem(presentationData: ItemListPresentationData(theme: presentationData.theme, fontSize: presentationData.fontSize, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, dateTimeFormat: presentationData.dateTimeFormat), text: .markdown(text), sectionId: 0, linkAction: { _ in
                openTopAppsInfo()
            }, style: .plain, textSize: .larger, textAlignment: .center, additionalInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0), additionalOuterInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: -44.0, right: 0.0))
        }
    }
}

public enum ChatListSearchEntryStableId: Hashable {
    case threadId(Int64)
    case localPeerId(EnginePeer.Id)
    case globalPeerId(EnginePeer.Id)
    case messageId(EngineMessage.Id, ChatListSearchEntry.MessageSection)
    case messagePlaceholder(Int32)
    case emptyMessagesFooter
    case addContact
}

public enum ChatListSearchSectionExpandType {
    case none
    case expand
    case collapse
}

public enum ChatListSearchEntry: Comparable, Identifiable {
    public enum MessageOrderingKey: Comparable {
        case index(MessageIndex)
        case downloading(FetchManagerPriorityKey)
        case downloaded(timestamp: Int32, index: MessageIndex)
        
        public static func <(lhs: MessageOrderingKey, rhs: MessageOrderingKey) -> Bool {
            switch lhs {
            case let .index(lhsIndex):
                if case let .index(rhsIndex) = rhs {
                    return lhsIndex > rhsIndex
                } else {
                    return true
                }
            case let .downloading(lhsKey):
                switch rhs {
                case let .downloading(rhsKey):
                    return lhsKey < rhsKey
                case .index:
                    return false
                case .downloaded:
                    return true
                }
            case let .downloaded(lhsTimestamp, lhsIndex):
                switch rhs {
                case let .downloaded(rhsTimestamp, rhsIndex):
                    if lhsTimestamp != rhsTimestamp {
                        return lhsTimestamp > rhsTimestamp
                    } else {
                        return lhsIndex > rhsIndex
                    }
                case .downloading:
                    return false
                case .index:
                    return false
                }
            }
        }
    }
    
    public enum MessageSection: Hashable {
        case generic
        case downloading
        case recentlyDownloaded
        case publicPosts
    }
    
    case topic(EnginePeer, ChatListItemContent.ThreadInfo, Int, PresentationTheme, PresentationStrings, ChatListSearchSectionExpandType)
    case recentlySearchedPeer(EnginePeer, EnginePeer?, (Int32, Bool)?, Int, PresentationTheme, PresentationStrings, PresentationPersonNameOrder, PresentationPersonNameOrder, PeerStoryStats?, Bool)
    case adPeer(AdPeer, Int, PresentationTheme, PresentationStrings, PresentationPersonNameOrder, PresentationPersonNameOrder, ChatListSearchSectionExpandType, String?)
    case localPeer(EnginePeer, EnginePeer?, (Int32, Bool)?, Int, PresentationTheme, PresentationStrings, PresentationPersonNameOrder, PresentationPersonNameOrder, ChatListSearchSectionExpandType, PeerStoryStats?, Bool, Bool)
    case globalPeer(FoundPeer, (Int32, Bool)?, Int, PresentationTheme, PresentationStrings, PresentationPersonNameOrder, PresentationPersonNameOrder, ChatListSearchSectionExpandType, PeerStoryStats?, Bool, String?)
    case message(EngineMessage, EngineRenderedPeer, EnginePeerReadCounters?, EngineMessageHistoryThread.Info?, ChatListPresentationData, Int32, Bool?, Bool, MessageOrderingKey, (id: String, size: Int64, isFirstInList: Bool)?, MessageSection, Bool, PeerStoryStats?, Bool, TelegramSearchPeersScope)
    case messagePlaceholder(Int32, ChatListPresentationData, TelegramSearchPeersScope)
    case emptyMessagesFooter(ChatListPresentationData, TelegramSearchPeersScope, String?)
    case addContact(String, PresentationTheme, PresentationStrings)
    
    public var stableId: ChatListSearchEntryStableId {
        switch self {
        case let .topic(_, threadInfo, _, _, _, _):
            return .threadId(threadInfo.id)
        case let .recentlySearchedPeer(peer, _, _, _, _, _, _, _, _, _):
            return .localPeerId(peer.id)
        case let .localPeer(peer, _, _, _, _, _, _, _, _, _, _, _):
            return .localPeerId(peer.id)
        case let .adPeer(peer, _, _, _, _, _, _, _):
            return .globalPeerId(peer.peer.id)
        case let .globalPeer(peer, _, _, _, _, _, _, _, _, _, _):
            return .globalPeerId(peer.peer.id)
        case let .message(message, _, _, _, _, _, _, _, _, _, section, _, _, _, _):
            return .messageId(message.id, section)
        case let .messagePlaceholder(index, _, _):
            return .messagePlaceholder(index)
        case .emptyMessagesFooter:
            return .emptyMessagesFooter
        case .addContact:
            return .addContact
        }
    }
    
    public static func ==(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        switch lhs {
        case let .topic(lhsPeer, lhsThreadInfo, lhsIndex, lhsTheme, lhsStrings, lhsExpandType):
            if case let .topic(rhsPeer, rhsThreadInfo, rhsIndex, rhsTheme, rhsStrings, rhsExpandType) = rhs, lhsPeer == rhsPeer, lhsThreadInfo == rhsThreadInfo, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsExpandType == rhsExpandType {
                return true
            } else {
                return false
            }
        case let .recentlySearchedPeer(lhsPeer, lhsAssociatedPeer, lhsUnreadBadge, lhsIndex, lhsTheme, lhsStrings, lhsSortOrder, lhsDisplayOrder, lhsStoryStats, lhsRequiresPremiumForMessaging):
            if case let .recentlySearchedPeer(rhsPeer, rhsAssociatedPeer, rhsUnreadBadge, rhsIndex, rhsTheme, rhsStrings, rhsSortOrder, rhsDisplayOrder, rhsStoryStats, rhsRequiresPremiumForMessaging) = rhs, lhsPeer == rhsPeer && lhsAssociatedPeer == rhsAssociatedPeer && lhsIndex == rhsIndex && lhsTheme === rhsTheme && lhsStrings === rhsStrings && lhsSortOrder == rhsSortOrder && lhsDisplayOrder == rhsDisplayOrder && lhsUnreadBadge?.0 == rhsUnreadBadge?.0 && lhsUnreadBadge?.1 == rhsUnreadBadge?.1 && lhsStoryStats == rhsStoryStats && lhsRequiresPremiumForMessaging == rhsRequiresPremiumForMessaging {
                return true
            } else {
                return false
            }
        case let .localPeer(lhsPeer, lhsAssociatedPeer, lhsUnreadBadge, lhsIndex, lhsTheme, lhsStrings, lhsSortOrder, lhsDisplayOrder, lhsExpandType, lhsStoryStats, lhsRequiresPremiumForMessaging, lhsIsSelf):
            if case let .localPeer(rhsPeer, rhsAssociatedPeer, rhsUnreadBadge, rhsIndex, rhsTheme, rhsStrings, rhsSortOrder, rhsDisplayOrder, rhsExpandType, rhsStoryStats, rhsRequiresPremiumForMessaging, rhsIsSelf) = rhs, lhsPeer == rhsPeer && lhsAssociatedPeer == rhsAssociatedPeer && lhsIndex == rhsIndex && lhsTheme === rhsTheme && lhsStrings === rhsStrings && lhsSortOrder == rhsSortOrder && lhsDisplayOrder == rhsDisplayOrder && lhsUnreadBadge?.0 == rhsUnreadBadge?.0 && lhsUnreadBadge?.1 == rhsUnreadBadge?.1 && lhsExpandType == rhsExpandType && lhsStoryStats == rhsStoryStats && lhsRequiresPremiumForMessaging == rhsRequiresPremiumForMessaging && lhsIsSelf == rhsIsSelf {
                return true
            } else {
                return false
            }
        case let .adPeer(lhsPeer, lhsIndex, lhsTheme, lhsStrings, lhsSortOrder, lhsDisplayOrder, lhsExpandType, lhsQuery):
            if case let .adPeer(rhsPeer, rhsIndex, rhsTheme, rhsStrings, rhsSortOrder, rhsDisplayOrder, rhsExpandType, rhsQuery) = rhs, lhsPeer == rhsPeer && lhsIndex == rhsIndex && lhsTheme === rhsTheme && lhsStrings === rhsStrings && lhsSortOrder == rhsSortOrder && lhsDisplayOrder == rhsDisplayOrder && lhsExpandType == rhsExpandType && lhsQuery == rhsQuery {
                return true
            } else {
                return false
            }
        case let .globalPeer(lhsPeer, lhsUnreadBadge, lhsIndex, lhsTheme, lhsStrings, lhsSortOrder, lhsDisplayOrder, lhsExpandType, lhsStoryStats, lhsRequiresPremiumForMessaging, lhsQuery):
            if case let .globalPeer(rhsPeer, rhsUnreadBadge, rhsIndex, rhsTheme, rhsStrings, rhsSortOrder, rhsDisplayOrder, rhsExpandType, rhsStoryStats, rhsRequiresPremiumForMessaging, rhsQuery) = rhs, lhsPeer == rhsPeer && lhsIndex == rhsIndex && lhsTheme === rhsTheme && lhsStrings === rhsStrings && lhsSortOrder == rhsSortOrder && lhsDisplayOrder == rhsDisplayOrder && lhsUnreadBadge?.0 == rhsUnreadBadge?.0 && lhsUnreadBadge?.1 == rhsUnreadBadge?.1 && lhsExpandType == rhsExpandType && lhsStoryStats == rhsStoryStats && lhsRequiresPremiumForMessaging == rhsRequiresPremiumForMessaging, lhsQuery == rhsQuery {
                return true
            } else {
                return false
            }
        case let .message(lhsMessage, lhsPeer, lhsCombinedPeerReadState, lhsThreadInfo, lhsPresentationData, lhsTotalCount, lhsSelected, lhsDisplayCustomHeader, lhsKey, lhsResourceId, lhsSection, lhsAllPaused, lhsStoryStats, lhsRequiresPremiumForMessaging, lhsSearchScope):
            if case let .message(rhsMessage, rhsPeer, rhsCombinedPeerReadState, rhsThreadInfo, rhsPresentationData, rhsTotalCount, rhsSelected, rhsDisplayCustomHeader, rhsKey, rhsResourceId, rhsSection, rhsAllPaused, rhsStoryStats, rhsRequiresPremiumForMessaging, rhsSearchScope) = rhs {
                if lhsMessage.id != rhsMessage.id {
                    return false
                }
                if lhsMessage.stableVersion != rhsMessage.stableVersion {
                    return false
                }
                if lhsPeer != rhsPeer {
                    return false
                }
                if lhsThreadInfo != rhsThreadInfo {
                    return false
                }
                if lhsPresentationData !== rhsPresentationData {
                    return false
                }
                if lhsCombinedPeerReadState != rhsCombinedPeerReadState {
                    return false
                }
                if lhsTotalCount != rhsTotalCount {
                    return false
                }
                if lhsSelected != rhsSelected {
                    return false
                }
                if lhsDisplayCustomHeader != rhsDisplayCustomHeader {
                    return false
                }
                if lhsKey != rhsKey {
                    return false
                }
                if lhsResourceId?.0 != rhsResourceId?.0 {
                    return false
                }
                if lhsResourceId?.1 != rhsResourceId?.1 {
                    return false
                }
                if lhsSection != rhsSection {
                    return false
                }
                if lhsAllPaused != rhsAllPaused {
                    return false
                }
                if lhsStoryStats != rhsStoryStats {
                    return false
                }
                if lhsRequiresPremiumForMessaging != rhsRequiresPremiumForMessaging {
                    return false
                }
                if lhsSearchScope != rhsSearchScope {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .messagePlaceholder(lhsIndex, lhsPresentationData, lhsSearchScope):
            if case let .messagePlaceholder(rhsIndex, rhsPresentationData, rhsSearchScope) = rhs {
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsPresentationData !== rhsPresentationData {
                    return false
                }
                if lhsSearchScope != rhsSearchScope {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .emptyMessagesFooter(lhsPresentationData, lhsSearchScope, lhsQuery):
            if case let .emptyMessagesFooter(rhsPresentationData, rhsSearchScope, rhsQuery) = rhs {
                if lhsPresentationData !== rhsPresentationData {
                    return false
                }
                if lhsSearchScope != rhsSearchScope {
                    return false
                }
                if lhsQuery != rhsQuery {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .addContact(lhsPhoneNumber, lhsTheme, lhsStrings):
            if case let .addContact(rhsPhoneNumber, rhsTheme, rhsStrings) = rhs {
                if lhsPhoneNumber != rhsPhoneNumber {
                    return false
                }
                if lhsTheme !== rhsTheme {
                    return false
                }
                if lhsStrings !== rhsStrings {
                    return false
                }
                return true
            } else {
                return false
            }
        }
    }
        
    public static func <(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        switch lhs {
        case let .topic(_, _, lhsIndex, _, _, _):
            if case let .topic(_, _, rhsIndex, _, _, _) = rhs {
                return lhsIndex <= rhsIndex
            } else {
                return true
            }
        case let .recentlySearchedPeer(_, _, _, lhsIndex, _, _, _, _, _, _):
            if case .topic = rhs {
                return false
            } else if case let .recentlySearchedPeer(_, _, _, rhsIndex, _, _, _, _, _, _) = rhs {
                return lhsIndex <= rhsIndex
            } else {
                return true
            }
        case let .localPeer(_, _, _, lhsIndex, _, _, _, _, _, _, _, _):
            switch rhs {
            case .topic, .recentlySearchedPeer:
                return false
            case let .localPeer(_, _, _, rhsIndex, _, _, _, _, _, _, _, _):
                return lhsIndex <= rhsIndex
            case .adPeer, .globalPeer, .message, .messagePlaceholder, .emptyMessagesFooter, .addContact:
                return true
            }
        case let .adPeer(_, lhsIndex, _, _, _, _, _, _):
            switch rhs {
            case .topic, .recentlySearchedPeer, .localPeer:
                return false
            case let .adPeer(_, rhsIndex, _, _, _, _, _, _):
                return lhsIndex <= rhsIndex
            case .globalPeer, .message, .messagePlaceholder, .emptyMessagesFooter, .addContact:
                return true
            }
        case let .globalPeer(_, _, lhsIndex, _, _, _, _, _, _, _, _):
            switch rhs {
            case .topic, .recentlySearchedPeer, .localPeer, .adPeer:
                return false
            case let .globalPeer(_, _, rhsIndex, _, _, _, _, _, _, _, _):
                return lhsIndex <= rhsIndex
            case .message, .messagePlaceholder, .emptyMessagesFooter, .addContact:
                return true
            }
        case let .message(_, _, _, _, _, _, _, _, lhsKey, _, _, _, _, _, _):
            if case let .message(_, _, _, _, _, _, _, _, rhsKey, _, _, _, _, _, _) = rhs {
                return lhsKey < rhsKey
            } else if case .messagePlaceholder = rhs {
                return true
            } else if case .emptyMessagesFooter = rhs {
                return true
            } else if case .addContact = rhs {
                return true
            } else {
                return false
            }
        case let .messagePlaceholder(lhsIndex, _, _):
            if case let .messagePlaceholder(rhsIndex, _, _) = rhs {
                return lhsIndex < rhsIndex
            } else if case .emptyMessagesFooter = rhs {
                return true
            } else if case .addContact = rhs {
                return true
            } else {
                return false
            }
        case .emptyMessagesFooter:
            if case .addContact = rhs {
                return true
            } else {
                return false
            }
        case .addContact:
            return false
        }
    }
    
    public func item(
        context: AccountContext,
        presentationData: PresentationData,
        enableHeaders: Bool,
        filter: ChatListNodePeersFilter,
        requestPeerType: [ReplyMarkupButtonRequestPeerType]?,
        location: ChatListControllerLocation,
        key: ChatListSearchPaneKey,
        tagMask: EngineMessage.Tags?,
        interaction: ChatListNodeInteraction,
        listInteraction: ListMessageItemInteraction,
        peerContextAction: ((EnginePeer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?,
        toggleExpandLocalResults: @escaping () -> Void,
        toggleExpandGlobalResults: @escaping () -> Void,
        searchPeer: @escaping (EnginePeer) -> Void,
        searchQuery: String?,
        searchOptions: ChatListSearchOptions?,
        messageContextAction: ((EngineMessage, ASDisplayNode?, CGRect?, UIGestureRecognizer?, ChatListSearchPaneKey, (id: String, size: Int64, isFirstInList: Bool)?) -> Void)?,
        openClearRecentlyDownloaded: @escaping () -> Void,
        toggleAllPaused: @escaping () -> Void,
        openStories: @escaping (EnginePeer.Id, AvatarNode) -> Void,
        openPublicPosts: @escaping () -> Void,
        openMessagesFilter: @escaping (ASDisplayNode) -> Void,
        switchMessagesFilter: @escaping (TelegramSearchPeersScope) -> Void
    ) -> ListViewItem {
        switch self {
            case let .topic(peer, threadInfo, _, theme, strings, expandType):
                let actionTitle: String?
                switch expandType {
                case .none:
                    actionTitle = nil
                case .expand:
                    actionTitle = strings.ChatList_Search_ShowMore
                case .collapse:
                    actionTitle = strings.ChatList_Search_ShowLess
                }
                let header = ChatListSearchItemHeader(type: .topics, theme: theme, strings: strings, actionTitle: actionTitle, action: actionTitle == nil ? nil : { _ in
                    toggleExpandGlobalResults()
                })
                
                return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: .firstLast, displayOrder: .firstLast, context: context, peerMode: .generalSearch(isSavedMessages: false), peer: .thread(peer: peer, title: threadInfo.info.title, icon: threadInfo.info.icon, color: threadInfo.info.iconColor), status: .none, badge: nil, enabled: true, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: header, action: { _ in
                    interaction.peerSelected(peer, nil, threadInfo.id, nil, false)
                }, contextAction: nil, animationCache: interaction.animationCache, animationRenderer: interaction.animationRenderer)
            case let .recentlySearchedPeer(peer, associatedPeer, unreadBadge, _, theme, strings, nameSortOrder, nameDisplayOrder, storyStats, requiresPremiumForMessaging):
                let primaryPeer: EnginePeer
                var chatPeer: EnginePeer?
                if let associatedPeer = associatedPeer {
                    primaryPeer = associatedPeer
                    chatPeer = peer
                } else {
                    primaryPeer = peer
                    chatPeer = peer
                }
                
                var enabled = true
                if filter.contains(.onlyWriteable) {
                    if let peer = chatPeer {
                        enabled = canSendMessagesToPeer(peer._asPeer())
                    } else {
                        enabled = false
                    }
                    if requiresPremiumForMessaging {
                        enabled = false
                    }
                }
                if filter.contains(.onlyPrivateChats) {
                    if let peer = chatPeer {
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
                    if let peer = chatPeer {
                        if case .legacyGroup = peer {
                        } else if case let .channel(peer) = peer, case .group = peer.info {
                        } else {
                            enabled = false
                        }
                    } else {
                        enabled = false
                    }
                }
                
                var badge: ContactsPeerItemBadge?
                if let unreadBadge = unreadBadge {
                    badge = ContactsPeerItemBadge(count: unreadBadge.0, type: unreadBadge.1 ? .inactive : .active)
                }
                
                var buttonAction: ContactsPeerItemButtonAction?
                let header: ChatListSearchItemHeader?
                if filter.contains(.removeSearchHeader) {
                    header = nil
                } else {
                    let headerType: ChatListSearchItemHeaderType
                    if filter.contains(.onlyGroups) {
                        headerType = .chats
                    } else {
                        headerType = .recentPeers
                        
                        if case .chats = key, case let .user(user) = primaryPeer, let botInfo = user.botInfo, botInfo.flags.contains(.hasWebApp) {
                            buttonAction = ContactsPeerItemButtonAction(
                                title: presentationData.strings.ChatList_Search_Open,
                                action: { peer, _, _ in
                                    interaction.peerSelected(primaryPeer, nil, nil, nil, true)
                                }
                            )
                        }
                    }
                    header = ChatListSearchItemHeader(type: headerType, theme: theme, strings: strings, actionTitle: nil, action: nil)
                }
            
                return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: .generalSearch(isSavedMessages: false), peer: .peer(peer: primaryPeer, chatPeer: chatPeer), status: .none, badge: badge, requiresPremiumForMessaging: requiresPremiumForMessaging, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), buttonAction: buttonAction, index: nil, header: header, action: { contactPeer in
                    if case let .peer(maybePeer, maybeChatPeer) = contactPeer, let peer = maybePeer, let chatPeer = maybeChatPeer {
                        interaction.peerSelected(chatPeer, peer, nil, nil, false)
                    } else {
                        interaction.peerSelected(peer, nil, nil, nil, false)
                    }
                }, disabledAction: { _ in
                    interaction.disabledPeerSelected(peer, nil, requiresPremiumForMessaging ? .premiumRequired : .generic)
                }, contextAction: peerContextAction.flatMap { peerContextAction in
                    return { node, gesture, location in
                        if let chatPeer = chatPeer, chatPeer.id.namespace != Namespaces.Peer.SecretChat {
                            peerContextAction(chatPeer, .search(nil), node, gesture, location)
                        } else {
                            gesture?.cancel()
                        }
                    }
                }, arrowAction: nil, animationCache: interaction.animationCache, animationRenderer: interaction.animationRenderer, storyStats: storyStats.flatMap { stats in
                    return (stats.totalCount, stats.unseenCount, stats.hasUnseenCloseFriends)
                }, openStories: { itemPeer, sourceNode in
                    guard case let .peer(_, chatPeer) = itemPeer, let peer = chatPeer else {
                        return
                    }
                    if let sourceNode = sourceNode as? ContactsPeerItemNode {
                        openStories(peer.id, sourceNode.avatarNode)
                    }
                })
            case let .adPeer(peer, _, theme, strings, nameSortOrder, nameDisplayOrder, expandType, _):
                let enabled = true
                var suffixString = ""
                if let subscribers = peer.subscribers, subscribers != 0 {
                    if case .user = peer.peer {
                        suffixString = ", \(strings.Conversation_StatusBotSubscribers(subscribers))"
                    } else if case let .channel(channel) = peer.peer, case .broadcast = channel.info {
                        suffixString = ", \(strings.Conversation_StatusSubscribers(subscribers))"
                    } else {
                        suffixString = ", \(strings.Conversation_StatusMembers(subscribers))"
                    }
                }
                
                let header: ChatListSearchItemHeader?
                let actionTitle: String?
                switch expandType {
                case .none:
                    actionTitle = nil
                case .expand:
                    actionTitle = strings.ChatList_Search_ShowMore
                case .collapse:
                    actionTitle = strings.ChatList_Search_ShowLess
                }
                header = ChatListSearchItemHeader(type: .globalPeers, theme: theme, strings: strings, actionTitle: actionTitle, action: actionTitle == nil ? nil : { _ in
                    toggleExpandGlobalResults()
                })
                            
                return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: .generalSearch(isSavedMessages: false), peer: .peer(peer: peer.peer, chatPeer: peer.peer), status: .addressName(suffixString), badge: nil, requiresPremiumForMessaging: false, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: header, searchQuery: nil, isAd: true, action: { _ in
                    interaction.peerSelected(peer.peer, nil, nil, nil, false)
                    context.engine.messages.markAdAction(opaqueId: peer.opaqueId, media: false, fullscreen: false)
                }, disabledAction: { _ in
                    interaction.disabledPeerSelected(peer.peer, nil, .generic)
                }, animationCache: interaction.animationCache, animationRenderer: interaction.animationRenderer, storyStats: nil, adButtonAction: { node in
                    interaction.openAdInfo(node, peer)
                }, visibilityUpdated: { isVisible in
                    if isVisible {
                        context.engine.messages.markAdAsSeen(opaqueId: peer.opaqueId)
                    }
                })
            case let .localPeer(peer, associatedPeer, unreadBadge, _, theme, strings, nameSortOrder, nameDisplayOrder, expandType, storyStats, requiresPremiumForMessaging, isSelf):
                let primaryPeer: EnginePeer
                var chatPeer: EnginePeer?
                if let associatedPeer = associatedPeer {
                    primaryPeer = associatedPeer
                    chatPeer = peer
                } else {
                    primaryPeer = peer
                    chatPeer = peer
                }
                
                var enabled = true
                if filter.contains(.onlyWriteable) {
                    if let peer = chatPeer {
                        enabled = canSendMessagesToPeer(peer._asPeer())
                    } else {
                        enabled = false
                    }
                    if requiresPremiumForMessaging {
                        enabled = false
                    }
                }
                if filter.contains(.onlyPrivateChats) {
                    if let peer = chatPeer {
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
                    if let peer = chatPeer {
                        if case .legacyGroup = peer {
                        } else if case let .channel(peer) = peer, case .group = peer.info {
                        } else {
                            enabled = false
                        }
                    } else {
                        enabled = false
                    }
                }
                
                var badge: ContactsPeerItemBadge?
                if let unreadBadge = unreadBadge {
                    badge = ContactsPeerItemBadge(count: unreadBadge.0, type: unreadBadge.1 ? .inactive : .active)
                }
                
                let header: ChatListSearchItemHeader?
                if filter.contains(.removeSearchHeader) {
                    header = nil
                } else {
                    let actionTitle: String?
                    switch expandType {
                    case .none:
                        actionTitle = nil
                    case .expand:
                        actionTitle = strings.ChatList_Search_ShowMore
                    case .collapse:
                        actionTitle = strings.ChatList_Search_ShowLess
                    }
                    let headerType: ChatListSearchItemHeaderType
                    if case .channels = key {
                        headerType = .channels
                    } else if case .apps = key {
                        headerType = .text(strings.ChatList_Search_SectionApps, AnyHashable("apps"))
                    } else {
                        if filter.contains(.onlyGroups) {
                            headerType = .chats
                        } else {
                            if let _ = requestPeerType {
                                headerType = .chats
                            } else {
                                headerType = .localPeers
                            }
                        }
                    }
                    header = ChatListSearchItemHeader(type: headerType, theme: theme, strings: strings, actionTitle: actionTitle, action: actionTitle == nil ? nil : { _ in
                        toggleExpandLocalResults()
                    })
                }
                var isSavedMessages = false
                if case .savedMessagesChats = location {
                    isSavedMessages = true
                }
            
                var status: ContactsPeerItemStatus = .none
                if case let .user(user) = primaryPeer, let _ = user.botInfo, !primaryPeer.id.isVerificationCodes {
                    if let subscriberCount = user.subscriberCount {
                        status = .custom(string: NSAttributedString(string: presentationData.strings.Conversation_StatusBotSubscribers(subscriberCount)), multiline: false, isActive: false, icon: nil)
                    } else {
                        status = .custom(string: NSAttributedString(string: presentationData.strings.Bot_GenericBotStatus), multiline: false, isActive: false, icon: nil)
                    }
                }
            
                var buttonAction: ContactsPeerItemButtonAction?
                if case .chats = key, case let .user(user) = primaryPeer, let botInfo = user.botInfo, botInfo.flags.contains(.hasWebApp) {
                    buttonAction = ContactsPeerItemButtonAction(
                        title: presentationData.strings.ChatList_Search_Open,
                        action: { peer, _, _ in
                            interaction.peerSelected(primaryPeer, nil, nil, nil, true)
                        }
                    )
                }
                
                return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: .generalSearch(isSavedMessages: isSavedMessages), aliasHandling: isSelf ? .standard : .treatSelfAsSaved, peer: .peer(peer: primaryPeer, chatPeer: chatPeer), status: status, badge: badge, requiresPremiumForMessaging: requiresPremiumForMessaging, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), buttonAction: buttonAction, index: nil, header: header, action: { contactPeer in
                    if case let .peer(maybePeer, maybeChatPeer) = contactPeer, let peer = maybePeer, let chatPeer = maybeChatPeer {
                        interaction.peerSelected(chatPeer, peer, nil, nil, false)
                    } else {
                        interaction.peerSelected(peer, nil, nil, nil, false)
                    }
                }, disabledAction: { _ in
                    interaction.disabledPeerSelected(peer, nil, requiresPremiumForMessaging ? .premiumRequired : .generic)
                }, contextAction: peerContextAction.flatMap { peerContextAction in
                    return { node, gesture, location in
                        if let chatPeer = chatPeer, chatPeer.id.namespace != Namespaces.Peer.SecretChat {
                            peerContextAction(chatPeer, .search(nil), node, gesture, location)
                        } else {
                            gesture?.cancel()
                        }
                    }
                }, arrowAction: nil, animationCache: interaction.animationCache, animationRenderer: interaction.animationRenderer, storyStats: storyStats.flatMap { stats in
                    return (stats.totalCount, stats.unseenCount, stats.hasUnseenCloseFriends)
                }, openStories: { itemPeer, sourceNode in
                    guard case let .peer(_, chatPeer) = itemPeer, let peer = chatPeer else {
                        return
                    }
                    if let sourceNode = sourceNode as? ContactsPeerItemNode {
                        openStories(peer.id, sourceNode.avatarNode)
                    }
                })
            case let .globalPeer(peer, unreadBadge, _, theme, strings, nameSortOrder, nameDisplayOrder, expandType, storyStats, requiresPremiumForMessaging, query):
                var enabled = true
                if filter.contains(.onlyWriteable) {
                    enabled = canSendMessagesToPeer(peer.peer)
                    if requiresPremiumForMessaging {
                        enabled = false
                    }
                }
                if filter.contains(.onlyPrivateChats) {
                    if !(peer.peer is TelegramUser || peer.peer is TelegramSecretChat) {
                        enabled = false
                    }
                }
                if filter.contains(.onlyGroups) {
                    if let _ = peer.peer as? TelegramGroup {
                    } else if let peer = peer.peer as? TelegramChannel, case .group = peer.info {
                    } else {
                        enabled = false
                    }
                }
                
                var suffixString = ""
                if let subscribers = peer.subscribers, subscribers != 0 {
                    if peer.peer is TelegramUser {
                        suffixString = ", \(strings.Conversation_StatusBotSubscribers(subscribers))"
                    } else if let channel = peer.peer as? TelegramChannel, case .broadcast = channel.info {
                        suffixString = ", \(strings.Conversation_StatusSubscribers(subscribers))"
                    } else {
                        suffixString = ", \(strings.Conversation_StatusMembers(subscribers))"
                    }
                }
                
                var badge: ContactsPeerItemBadge?
                if let unreadBadge = unreadBadge {
                    badge = ContactsPeerItemBadge(count: unreadBadge.0, type: unreadBadge.1 ? .inactive : .active)
                }
                
                let header: ChatListSearchItemHeader?
                if filter.contains(.removeSearchHeader) {
                    header = nil
                } else {
                    let actionTitle: String?
                    switch expandType {
                    case .none:
                        actionTitle = nil
                    case .expand:
                        actionTitle = strings.ChatList_Search_ShowMore
                    case .collapse:
                        actionTitle = strings.ChatList_Search_ShowLess
                    }
                    header = ChatListSearchItemHeader(type: .globalPeers, theme: theme, strings: strings, actionTitle: actionTitle, action: actionTitle == nil ? nil : { _ in
                        toggleExpandGlobalResults()
                    })
                }
            
                var isSavedMessages = false
                if case .savedMessagesChats = location {
                    isSavedMessages = true
                }
                
                return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: .generalSearch(isSavedMessages: isSavedMessages), peer: .peer(peer: EnginePeer(peer.peer), chatPeer: EnginePeer(peer.peer)), status: .addressName(suffixString), badge: badge, requiresPremiumForMessaging: requiresPremiumForMessaging, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: header, searchQuery: query, isAd: false, action: { _ in
                    interaction.peerSelected(EnginePeer(peer.peer), nil, nil, nil, false)
                }, disabledAction: { _ in
                    interaction.disabledPeerSelected(EnginePeer(peer.peer), nil, requiresPremiumForMessaging ? .premiumRequired : .generic)
                }, contextAction: peerContextAction.flatMap { peerContextAction in
                    return { node, gesture, location in
                        peerContextAction(EnginePeer(peer.peer), .search(nil), node, gesture, location)
                    }
                }, animationCache: interaction.animationCache, animationRenderer: interaction.animationRenderer, storyStats: storyStats.flatMap { stats in
                    return (stats.totalCount, stats.unseenCount, stats.hasUnseenCloseFriends)
                }, openStories: { itemPeer, sourceNode in
                    guard case let .peer(_, chatPeer) = itemPeer, let peer = chatPeer else {
                        return
                    }
                    if let sourceNode = sourceNode as? ContactsPeerItemNode {
                        openStories(peer.id, sourceNode.avatarNode)
                    }
                }, adButtonAction: { _ in
                })
            case let .message(message, peer, readState, threadInfo, presentationData, _, selected, displayCustomHeader, orderingKey, _, section, allPaused, storyStats, requiresPremiumForMessaging, searchScope):
                let header: ChatListSearchItemHeader
                switch orderingKey {
                case .downloading:
                    if allPaused {
                        header = ChatListSearchItemHeader(type: .downloading, theme: presentationData.theme, strings: presentationData.strings, actionTitle: presentationData.strings.DownloadList_ResumeAll, action: { _ in
                            toggleAllPaused()
                        })
                    } else {
                        header = ChatListSearchItemHeader(type: .downloading, theme: presentationData.theme, strings: presentationData.strings, actionTitle: presentationData.strings.DownloadList_PauseAll, action: { _ in
                            toggleAllPaused()
                        })
                    }
                case .downloaded:
                    header = ChatListSearchItemHeader(type: .recentDownloads, theme: presentationData.theme, strings: presentationData.strings, actionTitle: presentationData.strings.DownloadList_Clear, action: { _ in
                        openClearRecentlyDownloaded()
                    })
                case .index:
                    if case .publicPosts = section {
                        if case .publicPosts = key {
                            header = ChatListSearchItemHeader(type: .publicPosts, theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil)
                        } else {
                            header = ChatListSearchItemHeader(type: .publicPosts, theme: presentationData.theme, strings: presentationData.strings, actionTitle: "\(presentationData.strings.ChatList_Search_ShowMore) >", action: { _ in
                                openPublicPosts()
                            })
                        }
                    } else {
                        var headerType: ChatListSearchItemHeaderType = .messages(location: nil)
                        if case let .forum(peerId) = location, let peer = peer.peer, peer.id == peerId {
                            headerType = .messages(location: peer.compactDisplayTitle)
                        }
                        var actionTitle: String?
                        if case .generic = section {
                            let filterTitle: String
                            switch searchScope {
                            case .everywhere:
                                filterTitle = presentationData.strings.ChatList_Search_Messages_AllChats
                            case .channels:
                                filterTitle = presentationData.strings.ChatList_Search_Messages_Channels
                            case .groups:
                                filterTitle = presentationData.strings.ChatList_Search_Messages_GroupChats
                            case .privateChats:
                                filterTitle = presentationData.strings.ChatList_Search_Messages_PrivateChats
                            }
                            actionTitle = "\(filterTitle)  <"
                        }
                        header = ChatListSearchItemHeader(type: headerType, theme: presentationData.theme, strings: presentationData.strings, actionTitle: actionTitle, action: { sourceNode in
                            openMessagesFilter(sourceNode)
                        })
                    }
                }
                let selection: ChatHistoryMessageSelection = selected.flatMap { .selectable(selected: $0) } ?? .none
                var isMedia = false
                if let tagMask, tagMask != .photoOrVideo {
                    isMedia = true
                } else if key == .downloads {
                    isMedia = true
                }
                if isMedia {
                    return ListMessageItem(presentationData: ChatPresentationData(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: .builtin(WallpaperSettings())), fontSize: presentationData.fontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true, largeEmoji: false, chatBubbleCorners: PresentationChatBubbleCorners(mainRadius: 0.0, auxiliaryRadius: 0.0, mergeBubbleCorners: false)), context: context, chatLocation: .peer(id: peer.peerId), interaction: listInteraction, message: message._asMessage(), selection: selection, displayHeader: enableHeaders && !displayCustomHeader, customHeader: key == .downloads ? header : nil, hintIsLink: tagMask == .webPage, isGlobalSearchResult: key != .downloads, isDownloadList: key == .downloads)
                } else {
                    let index: EngineChatList.Item.Index
                    var chatThreadInfo: ChatListItemContent.ThreadInfo?
                    chatThreadInfo = nil
                    var displayAsMessage = false
                    switch location {
                    case .chatList, .savedMessagesChats:
                        index = .chatList(EngineChatList.Item.Index.ChatList(pinningIndex: nil, messageIndex: message.index))
                    case let .forum(peerId):
                        let _ = peerId
                        let _ = threadInfo
                        
                        displayAsMessage = true
                        
                        if message.id.peerId == peerId {
                            if let threadId = message.threadId, let threadInfo = threadInfo {
                                chatThreadInfo = ChatListItemContent.ThreadInfo(id: threadId, info: threadInfo, isOwnedByMe: false, isClosed: false, isHidden: false, threadPeer: nil)
                                index = .forum(pinnedIndex: .none, timestamp: message.index.timestamp, threadId: threadId, namespace: message.index.id.namespace, id: message.index.id.id)
                            } else {
                                index = .chatList(EngineChatList.Item.Index.ChatList(pinningIndex: nil, messageIndex: message.index))
                            }
                        } else {
                            index = .chatList(EngineChatList.Item.Index.ChatList(pinningIndex: nil, messageIndex: message.index))
                        }
                    }
                    return ChatListItem(presentationData: presentationData, context: context, chatListLocation: location, filterData: nil, index: index, content: .peer(ChatListItemContent.PeerData(
                        messages: [message],
                        peer: peer,
                        threadInfo: chatThreadInfo,
                        combinedReadState: readState,
                        isRemovedFromTotalUnreadCount: false,
                        presence: nil,
                        hasUnseenMentions: false,
                        hasUnseenReactions: false,
                        draftState: nil,
                        mediaDraftContentType: nil,
                        inputActivities: nil,
                        promoInfo: nil,
                        ignoreUnreadBadge: true,
                        displayAsMessage: displayAsMessage,
                        hasFailedMessages: false,
                        forumTopicData: nil,
                        topForumTopicItems: [],
                        autoremoveTimeout: nil,
                        storyState: storyStats.flatMap { stats in
                            return ChatListItemContent.StoryState(
                                stats: EngineChatList.StoryStats(
                                    totalCount: stats.totalCount,
                                    unseenCount: stats.unseenCount,
                                    hasUnseenCloseFriends: stats.hasUnseenCloseFriends
                                ),
                                hasUnseenCloseFriends: stats.hasUnseenCloseFriends
                            )
                        },
                        requiresPremiumForMessaging: requiresPremiumForMessaging,
                        displayAsTopicList: false,
                        tags: []
                    )), editing: false, hasActiveRevealControls: false, selected: false, header: tagMask == nil ? header : nil, enabledContextActions: nil, hiddenOffset: false, interaction: interaction)
                }
            case let .messagePlaceholder(_, presentationData, searchScope):
                var actionTitle: String?
                let filterTitle: String
                switch searchScope {
                case .everywhere:
                    filterTitle = presentationData.strings.ChatList_Search_Messages_AllChats
                case .channels:
                    filterTitle = presentationData.strings.ChatList_Search_Messages_Channels
                case .groups:
                    filterTitle = presentationData.strings.ChatList_Search_Messages_GroupChats
                case .privateChats:
                    filterTitle = presentationData.strings.ChatList_Search_Messages_PrivateChats
                }
                actionTitle = "\(filterTitle)  <"
                
                let header = ChatListSearchItemHeader(type: .messages(location: nil), theme: presentationData.theme, strings: presentationData.strings, actionTitle: actionTitle, action: { sourceNode in
                    openMessagesFilter(sourceNode)
                })
                return ChatListItem(presentationData: presentationData, context: context, chatListLocation: location, filterData: nil, index: EngineChatList.Item.Index.chatList(ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: PeerId(0), namespace: Namespaces.Message.Cloud, id: 0), timestamp: 0))), content: .loading, editing: false, hasActiveRevealControls: false, selected: false, header: header, enabledContextActions: nil, hiddenOffset: false, interaction: interaction)
            case let .emptyMessagesFooter(presentationData, searchScope, searchQuery):
                var actionTitle: String?
                let filterTitle: String
                switch searchScope {
                case .everywhere:
                    filterTitle = presentationData.strings.ChatList_Search_Messages_AllChats
                case .channels:
                    filterTitle = presentationData.strings.ChatList_Search_Messages_Channels
                case .groups:
                    filterTitle = presentationData.strings.ChatList_Search_Messages_GroupChats
                case .privateChats:
                    filterTitle = presentationData.strings.ChatList_Search_Messages_PrivateChats
                }
                actionTitle = "\(filterTitle)  <"
                
                let header = ChatListSearchItemHeader(type: .messages(location: nil), theme: presentationData.theme, strings: presentationData.strings, actionTitle: actionTitle, action: { sourceNode in
                    openMessagesFilter(sourceNode)
                })
                return ChatListSearchEmptyFooterItem(
                    theme: presentationData.theme,
                    strings: presentationData.strings,
                    header: header,
                    searchQuery: searchQuery,
                    searchAllMessages: searchScope == .everywhere ? nil : {
                        switchMessagesFilter(.everywhere)
                    }
                )
            case let .addContact(phoneNumber, theme, strings):
                return ContactsAddItem(context: context, theme: theme, strings: strings, phoneNumber: phoneNumber, header: ChatListSearchItemHeader(type: .phoneNumber, theme: theme, strings: strings, actionTitle: nil, action: nil), action: {
                    interaction.addContact(phoneNumber)
                })
        }
    }
}

private struct ChatListSearchContainerRecentTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isEmpty: Bool
}

public struct ChatListSearchContainerTransition {
    public let deletions: [ListViewDeleteItem]
    public let insertions: [ListViewInsertItem]
    public let updates: [ListViewUpdateItem]
    public let displayingResults: Bool
    public let isEmpty: Bool
    public let isLoading: Bool
    public let query: String?
    public var animated: Bool
    
    public init(deletions: [ListViewDeleteItem], insertions: [ListViewInsertItem], updates: [ListViewUpdateItem], displayingResults: Bool, isEmpty: Bool, isLoading: Bool, query: String?, animated: Bool) {
        self.deletions = deletions
        self.insertions = insertions
        self.updates = updates
        self.displayingResults = displayingResults
        self.isEmpty = isEmpty
        self.isLoading = isLoading
        self.query = query
        self.animated = animated
    }
}

enum OpenPeerAction {
    case generic
    case info
    case openApp
}

private func chatListSearchContainerPreparedRecentTransition(
    from fromEntries: [ChatListRecentEntry],
    to toEntries: [ChatListRecentEntry],
    forceUpdateAll: Bool,
    context: AccountContext,
    presentationData: ChatListPresentationData,
    filter: ChatListNodePeersFilter,
    key: ChatListSearchPaneKey,
    peerSelected: @escaping (EnginePeer, Int64?, Bool, OpenPeerAction) -> Void,
    disabledPeerSelected: @escaping (EnginePeer, Int64?, ChatListDisabledPeerReason) -> Void,
    peerContextAction: ((EnginePeer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?,
    clearRecentlySearchedPeers: @escaping () -> Void,
    deletePeer: @escaping (EnginePeer.Id) -> Void,
    animationCache: AnimationCache,
    animationRenderer: MultiAnimationRenderer,
    openStories: @escaping (EnginePeer.Id, AvatarNode) -> Void,
    openTopAppsInfo: @escaping () -> Void,
    isChannelsTabExpanded: Bool?,
    toggleChannelsTabExpanded: @escaping () -> Void,
    isEmpty: Bool
) -> ChatListSearchContainerRecentTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, allUpdated: forceUpdateAll)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, filter: filter, key: key, peerSelected: peerSelected, disabledPeerSelected: disabledPeerSelected, peerContextAction: peerContextAction, clearRecentlySearchedPeers: clearRecentlySearchedPeers, deletePeer: deletePeer, animationCache: animationCache, animationRenderer: animationRenderer, openStories: openStories, isChannelsTabExpanded: isChannelsTabExpanded, toggleChannelsTabExpanded: toggleChannelsTabExpanded, openTopAppsInfo: openTopAppsInfo), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, filter: filter, key: key, peerSelected: peerSelected, disabledPeerSelected: disabledPeerSelected, peerContextAction: peerContextAction, clearRecentlySearchedPeers: clearRecentlySearchedPeers, deletePeer: deletePeer, animationCache: animationCache, animationRenderer: animationRenderer, openStories: openStories, isChannelsTabExpanded: isChannelsTabExpanded, toggleChannelsTabExpanded: toggleChannelsTabExpanded, openTopAppsInfo: openTopAppsInfo), directionHint: nil) }
    
    return ChatListSearchContainerRecentTransition(deletions: deletions, insertions: insertions, updates: updates, isEmpty: isEmpty)
}

public func chatListSearchContainerPreparedTransition(
    from fromEntries: [ChatListSearchEntry],
    to toEntries: [ChatListSearchEntry],
    displayingResults: Bool,
    isEmpty: Bool,
    isLoading: Bool,
    animated: Bool,
    context: AccountContext,
    presentationData: PresentationData,
    enableHeaders: Bool,
    filter: ChatListNodePeersFilter,
    requestPeerType: [ReplyMarkupButtonRequestPeerType]?,
    location: ChatListControllerLocation,
    key: ChatListSearchPaneKey,
    tagMask: EngineMessage.Tags?,
    interaction: ChatListNodeInteraction,
    listInteraction: ListMessageItemInteraction,
    peerContextAction: ((EnginePeer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?,
    toggleExpandLocalResults: @escaping () -> Void,
    toggleExpandGlobalResults: @escaping () -> Void,
    searchPeer: @escaping (EnginePeer) -> Void,
    searchQuery: String?,
    searchOptions: ChatListSearchOptions?,
    messageContextAction: ((EngineMessage, ASDisplayNode?, CGRect?, UIGestureRecognizer?, ChatListSearchPaneKey, (id: String, size: Int64, isFirstInList: Bool)?) -> Void)?,
    openClearRecentlyDownloaded: @escaping () -> Void,
    toggleAllPaused: @escaping () -> Void,
    openStories: @escaping (EnginePeer.Id, AvatarNode) -> Void,
    openPublicPosts: @escaping () -> Void,
    openMessagesFilter: @escaping (ASDisplayNode) -> Void,
    switchMessagesFilter: @escaping (TelegramSearchPeersScope) -> Void
) -> ChatListSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, enableHeaders: enableHeaders, filter: filter, requestPeerType: requestPeerType, location: location, key: key, tagMask: tagMask, interaction: interaction, listInteraction: listInteraction, peerContextAction: peerContextAction, toggleExpandLocalResults: toggleExpandLocalResults, toggleExpandGlobalResults: toggleExpandGlobalResults, searchPeer: searchPeer, searchQuery: searchQuery, searchOptions: searchOptions, messageContextAction: messageContextAction, openClearRecentlyDownloaded: openClearRecentlyDownloaded, toggleAllPaused: toggleAllPaused, openStories: openStories, openPublicPosts: openPublicPosts, openMessagesFilter: openMessagesFilter, switchMessagesFilter: switchMessagesFilter), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, enableHeaders: enableHeaders, filter: filter, requestPeerType: requestPeerType, location: location, key: key, tagMask: tagMask,  interaction: interaction, listInteraction: listInteraction, peerContextAction: peerContextAction, toggleExpandLocalResults: toggleExpandLocalResults, toggleExpandGlobalResults: toggleExpandGlobalResults, searchPeer: searchPeer, searchQuery: searchQuery, searchOptions: searchOptions, messageContextAction: messageContextAction, openClearRecentlyDownloaded: openClearRecentlyDownloaded, toggleAllPaused: toggleAllPaused, openStories: openStories, openPublicPosts: openPublicPosts, openMessagesFilter: openMessagesFilter, switchMessagesFilter: switchMessagesFilter), directionHint: nil) }
    
    return ChatListSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, displayingResults: displayingResults, isEmpty: isEmpty, isLoading: isLoading, query: searchQuery, animated: animated)
}

private struct ChatListSearchListPaneNodeState: Equatable {
    var expandLocalSearch: Bool = false
    var expandGlobalSearch: Bool = false
    var deletedMessageIds = Set<EngineMessage.Id>()
    var deletedGlobalMessageIds = Set<Int32>()
}

private func doesPeerMatchFilter(peer: EnginePeer, filter: ChatListNodePeersFilter) -> Bool {
    var enabled = true
    if filter.contains(.onlyWriteable), !canSendMessagesToPeer(peer._asPeer()) {
        enabled = false
    }
    if filter.contains(.onlyPrivateChats) {
        switch peer {
        case .user, .secretChat:
            break
        default:
            enabled = false
        }
    }
    if filter.contains(.onlyGroups) {
        if case .legacyGroup = peer {
        } else if case let .channel(peer) = peer, case .group = peer.info {
        } else {
            enabled = false
        }
    }
    return enabled
}

private struct ChatListSearchMessagesResult {
    let query: String
    let messages: [EngineMessage]
    let readStates: [EnginePeer.Id: EnginePeerReadCounters]
    let threadInfo: [EngineMessage.Id: MessageHistoryThreadData]
    let hasMore: Bool
    let totalCount: Int32
    let state: SearchMessagesState
}

private struct ChatListSearchMessagesContext {
    let result: ChatListSearchMessagesResult
    let loadMoreIndex: EngineMessage.Index?
}

public enum ChatListSearchContextActionSource {
    case recentPeers(isTopPeer: Bool)
    case recentSearch
    case recentApps
    case popularApps
    case search(EngineMessage.Id?)
}

public struct ChatListSearchOptions {
    let peer: (EnginePeer.Id, Bool, String)?
    let date: (Int32?, Int32, String)?
    
    var isEmpty: Bool {
        return self.peer == nil && self.date == nil
    }
    
    func withUpdatedPeer(_ peerIdIsGroupAndName: (EnginePeer.Id, Bool, String)?) -> ChatListSearchOptions {
        return ChatListSearchOptions(peer: peerIdIsGroupAndName, date: self.date)
    }
    
    func withUpdatedDate(_ minDateMaxDateAndTitle: (Int32?, Int32, String)?) -> ChatListSearchOptions {
        return ChatListSearchOptions(peer: self.peer, date: minDateMaxDateAndTitle)
    }
}

private struct DownloadItem: Equatable {
    let resourceId: MediaResourceId
    let message: EngineMessage
    let priority: FetchManagerPriorityKey
    let isPaused: Bool
    
    static func ==(lhs: DownloadItem, rhs: DownloadItem) -> Bool {
        if lhs.resourceId != rhs.resourceId {
            return false
        }
        if lhs.message.id != rhs.message.id {
            return false
        }
        if lhs.priority != rhs.priority {
            return false
        }
        if lhs.isPaused != rhs.isPaused {
            return false
        }
        return true
    }
}

private func filteredPeerSearchQueryResults(value: ([FoundPeer], [FoundPeer]), scope: TelegramSearchPeersScope) -> ([FoundPeer], [FoundPeer]) {
    switch scope {
    case .everywhere, .privateChats, .groups:
        return value
    case .channels:
        return (
            value.0.filter { peer in
                if let channel = peer.peer as? TelegramChannel, case .broadcast = channel.info {
                    return true
                } else {
                    return false
                }
            },
            value.1.filter { peer in
                if let channel = peer.peer as? TelegramChannel, case .broadcast = channel.info {
                    return true
                } else {
                    return false
                }
            }
        )
    }
}

final class GlobalPeerSearchContext {
    private struct SearchKey: Hashable {
        var query: String
        
        init(query: String) {
            self.query = query
        }
    }
    
    private final class QueryContext {
        var value: ([FoundPeer], [FoundPeer])?
        let subscribers = Bag<(TelegramSearchPeersScope, (([FoundPeer], [FoundPeer])) -> Void)>()
        let disposable = MetaDisposable()
        
        init() {
        }
        
        deinit {
            self.disposable.dispose()
        }
    }
    
    private final class Impl {
        private let queue: Queue
        private var queryContexts: [SearchKey: QueryContext] = [:]
        
        init(queue: Queue) {
            self.queue = queue
        }
        
        func searchRemotePeers(engine: TelegramEngine, query: String, scope: TelegramSearchPeersScope, onNext: @escaping (([FoundPeer], [FoundPeer])) -> Void) -> Disposable {
            let searchKey = SearchKey(query: query)
            let queryContext: QueryContext
            if let current = self.queryContexts[searchKey] {
                queryContext = current
                
                if let value = queryContext.value {
                    onNext(filteredPeerSearchQueryResults(value: value, scope: scope))
                }
            } else {
                queryContext = QueryContext()
                self.queryContexts[searchKey] = queryContext
                queryContext.disposable.set((engine.contacts.searchRemotePeers(
                    query: query,
                    scope: .everywhere
                )
                |> delay(0.4, queue: Queue.mainQueue())
                |> deliverOn(self.queue)).start(next: { [weak queryContext] value in
                    guard let queryContext else {
                        return
                    }
                    queryContext.value = value
                    for (scope, f) in queryContext.subscribers.copyItems() {
                        f(filteredPeerSearchQueryResults(value: value, scope: scope))
                    }
                }))
            }
            
            let index = queryContext.subscribers.add((scope, onNext))
            
            let queue = self.queue
            return ActionDisposable { [weak self, weak queryContext] in
                queue.async {
                    guard let self, let queryContext else {
                        return
                    }
                    guard let currentContext = self.queryContexts[searchKey], queryContext === queryContext else {
                        return
                    }
                    currentContext.subscribers.remove(index)
                    if currentContext.subscribers.isEmpty {
                        currentContext.disposable.dispose()
                        self.queryContexts.removeValue(forKey: searchKey)
                    }
                }
            }
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    init() {
        let queue = Queue.mainQueue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue)
        })
    }
    
    func searchRemotePeers(engine: TelegramEngine, query: String, scope: TelegramSearchPeersScope = .everywhere) -> Signal<([FoundPeer], [FoundPeer]), NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.searchRemotePeers(engine: engine, query: query, scope: scope, onNext: subscriber.putNext)
        }
    }
}

final class ChatListSearchListPaneNode: ASDisplayNode, ChatListSearchPaneNode {
    private let context: AccountContext
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    private let interaction: ChatListSearchInteraction
    private let peersFilter: ChatListNodePeersFilter
    private let requestPeerType: [ReplyMarkupButtonRequestPeerType]?
    private var presentationData: PresentationData
    private let globalPeerSearchContext: GlobalPeerSearchContext?
    private let key: ChatListSearchPaneKey
    private let tagMask: EngineMessage.Tags?
    private let location: ChatListControllerLocation
    private let navigationController: NavigationController?
    private weak var parentController: ViewController?
    
    private let recentListNode: ListView
    private let shimmerNode: ChatListSearchShimmerNode
    private let listNode: ListView?
    private let mediaNode: ChatListSearchMediaNode?
    private var enqueuedRecentTransitions: [(ChatListSearchContainerRecentTransition, Bool)] = []
    private var enqueuedTransitions: [(ChatListSearchContainerTransition, Bool)] = []
    
    private var presentationDataDisposable: Disposable?
    private let updatedRecentPeersDisposable = MetaDisposable()
    private let recentDisposable = MetaDisposable()
    
    private let searchDisposable = MetaDisposable()
    private let presentationDataPromise = Promise<ChatListPresentationData>()
    private var searchStateValue = ChatListSearchListPaneNodeState()
    private let searchStatePromise = ValuePromise<ChatListSearchListPaneNodeState>()
    private let searchContextsValue = Atomic<[Int: ChatListSearchMessagesContext]>(value: [:])
    var searchCurrentMessages: [EngineMessage]?
    var currentEntries: [ChatListSearchEntry]?
    
    private var deletedMessagesDisposable: Disposable?
    
    private var adsHiddenPromise = ValuePromise<Bool>(false)
    private var adsHidden = false {
        didSet {
            self.adsHiddenPromise.set(self.adsHidden)
        }
    }
    
    private var searchQueryValue: String?
    private var searchOptionsValue: ChatListSearchOptions?
    
    var isCurrent: Bool = false
    
    private let _isSearching = ValuePromise<Bool>(false, ignoreRepeated: true)
    public var isSearching: Signal<Bool, NoError> {
        return self._isSearching.get()
    }
    
    private var mediaStatusDisposable: Disposable?
    private var playlistPreloadDisposable: Disposable?
    
    private var playlistStateAndType: (SharedMediaPlaylistItem, SharedMediaPlaylistItem?, SharedMediaPlaylistItem?, MusicPlaybackSettingsOrder, MediaManagerPlayerType, Account)?
    private var playlistLocation: SharedMediaPlaylistLocation?
    
    private var mediaAccessoryPanelContainer: PassthroughContainerNode
    private var mediaAccessoryPanel: (MediaNavigationAccessoryPanel, MediaManagerPlayerType)?
    private var dismissingPanel: ASDisplayNode?
    
    private let emptyResultsTitleNode: ImmediateTextNode
    private let emptyResultsTextNode: ImmediateTextNode
    private let emptyResultsAnimationNode: AnimatedStickerNode
    private var emptyResultsAnimationSize = CGSize()
    
    private var recentEmptyNode: ASDisplayNode?
    private var emptyRecentTitleNode: ImmediateTextNode?
    private var emptyRecentTextNode: ImmediateTextNode?
    private var emptyRecentAnimationNode: AnimatedStickerNode?
    private var emptyRecentAnimationSize = CGSize()
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, presentationData: PresentationData)?
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }
        
    private let selectedMessagesPromise = Promise<Set<EngineMessage.Id>?>(nil)
    private var selectedMessages: Set<EngineMessage.Id>? {
        didSet {
            if self.selectedMessages != oldValue {
                self.selectedMessagesPromise.set(.single(self.selectedMessages))
            }
        }
    }
    
    private var hiddenMediaDisposable: Disposable?
    private var searchQueryDisposable: Disposable?
    private var searchOptionsDisposable: Disposable?
  
    private let searchScopePromise = ValuePromise<TelegramSearchPeersScope>(.everywhere)
    
    init(context: AccountContext, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, interaction: ChatListSearchInteraction, key: ChatListSearchPaneKey, peersFilter: ChatListNodePeersFilter, requestPeerType: [ReplyMarkupButtonRequestPeerType]?, location: ChatListControllerLocation, searchQuery: Signal<String?, NoError>, searchOptions: Signal<ChatListSearchOptions?, NoError>, navigationController: NavigationController?, parentController: ViewController?, globalPeerSearchContext: GlobalPeerSearchContext?) {
        self.context = context
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.interaction = interaction
        self.key = key
        self.location = location
        self.navigationController = navigationController
        self.parentController = parentController
        
        let globalPeerSearchContext = globalPeerSearchContext ?? GlobalPeerSearchContext()
        
        self.globalPeerSearchContext = globalPeerSearchContext

        var peersFilter = peersFilter
        if case .forum = location {
            //peersFilter.insert(.excludeRecent)
        } else if case .chatList(.archive) = location {
            peersFilter.insert(.excludeRecent)
        }
        self.peersFilter = peersFilter
        self.requestPeerType = requestPeerType
        
        let tagMask: EngineMessage.Tags?
        switch key {
        case .chats:
            tagMask = nil
        case .topics:
            tagMask = nil
        case .publicPosts:
            tagMask = nil
        case .channels:
            tagMask = nil
        case .apps:
            tagMask = nil
        case .media:
            tagMask = .photoOrVideo
        case .downloads:
            tagMask = nil
        case .links:
            tagMask = .webPage
        case .files:
            tagMask = .file
        case .music:
            tagMask = .music
        case .voice:
            tagMask = .voiceOrInstantVideo
        case .instantVideo:
            tagMask = .roundVideo
        }
        self.tagMask = tagMask
        
        let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        self.presentationDataPromise.set(.single(ChatListPresentationData(theme: self.presentationData.theme, fontSize: self.presentationData.listsFontSize, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: true)))
        
        self.searchStatePromise.set(self.searchStateValue)
        self.selectedMessages = interaction.getSelectedMessageIds()
        self.selectedMessagesPromise.set(.single(self.selectedMessages))
        
        self.recentListNode = ListView()
        self.recentListNode.preloadPages = false
        self.recentListNode.verticalScrollIndicatorColor = self.presentationData.theme.list.scrollIndicatorColor
        self.recentListNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.shimmerNode = ChatListSearchShimmerNode(key: key)
        self.shimmerNode.isUserInteractionEnabled = false
        self.shimmerNode.allowsGroupOpacity = true
            
        self.listNode = ListView()
        self.listNode?.verticalScrollIndicatorColor = self.presentationData.theme.list.scrollIndicatorColor
        self.listNode?.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
    
        var openMediaMessageImpl: ((EngineMessage, ChatControllerInteractionOpenMessageMode) -> Void)?
        var transitionNodeImpl: ((EngineMessage.Id, EngineMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?)?
        var addToTransitionSurfaceImpl: ((UIView) -> Void)?
        
        if key == .media {
            self.mediaNode = ChatListSearchMediaNode(context: self.context, contentType: .photoOrVideo, openMessage: { message, mode in
                openMediaMessageImpl?(EngineMessage(message), mode)
            }, messageContextAction: { message, node, rect, gesture in
                interaction.mediaMessageContextAction(EngineMessage(message), node, rect, gesture)
            }, toggleMessageSelection: { messageId, selected in
                interaction.toggleMessageSelection(messageId, selected)
            })
        } else {
            self.mediaNode = nil
        }
        
        self.mediaAccessoryPanelContainer = PassthroughContainerNode()
        self.mediaAccessoryPanelContainer.clipsToBounds = true
        
        self.emptyResultsTitleNode = ImmediateTextNode()
        self.emptyResultsTitleNode.displaysAsynchronously = false
        self.emptyResultsTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.ChatList_Search_NoResults, font: Font.semibold(17.0), textColor: self.presentationData.theme.list.freeTextColor)
        self.emptyResultsTitleNode.textAlignment = .center
        self.emptyResultsTitleNode.isHidden = true
        
        self.emptyResultsTextNode = ImmediateTextNode()
        self.emptyResultsTextNode.displaysAsynchronously = false
        self.emptyResultsTextNode.maximumNumberOfLines = 0
        self.emptyResultsTextNode.textAlignment = .center
        self.emptyResultsTextNode.isHidden = true
             
        self.emptyResultsAnimationNode = DefaultAnimatedStickerNodeImpl()
        self.emptyResultsAnimationNode.isHidden = true
        
        if key == .channels || key == .apps {
            let emptyRecentTitleNode = ImmediateTextNode()
            emptyRecentTitleNode.displaysAsynchronously = false
            emptyRecentTitleNode.attributedText = NSAttributedString(string: presentationData.strings.ChatList_Search_RecommendedChannelsEmpty_Title, font: Font.semibold(17.0), textColor: self.presentationData.theme.list.freeTextColor)
            emptyRecentTitleNode.textAlignment = .center
            emptyRecentTitleNode.isHidden = true
            self.emptyRecentTitleNode = emptyRecentTitleNode
            
            let emptyRecentTextNode = ImmediateTextNode()
            emptyResultsTextNode.displaysAsynchronously = false
            emptyRecentTextNode.maximumNumberOfLines = 0
            emptyRecentTextNode.textAlignment = .center
            emptyRecentTextNode.isHidden = true
            if key == .channels {
                emptyRecentTextNode.attributedText = NSAttributedString(string: presentationData.strings.ChatList_Search_RecommendedChannelsEmpty_Text, font: Font.regular(15.0), textColor: presentationData.theme.list.freeTextColor)
            } else if key == .apps {
                emptyRecentTextNode.attributedText = NSAttributedString(string: presentationData.strings.ChatList_Search_Apps_Empty_Text, font: Font.regular(15.0), textColor: presentationData.theme.list.freeTextColor)
            }
            self.emptyRecentTextNode = emptyRecentTextNode
                 
            let emptyRecentAnimationNode = DefaultAnimatedStickerNodeImpl()
            emptyRecentAnimationNode.isHidden = true
            self.emptyRecentAnimationNode = emptyRecentAnimationNode
                    
            emptyRecentAnimationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "ChatListNoResults"), width: 256, height: 256, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
            self.emptyRecentAnimationSize = CGSize(width: 148.0, height: 148.0)
            
            let recentEmptyNode = ASDisplayNode()
            
            recentEmptyNode.addSubnode(emptyRecentTitleNode)
            recentEmptyNode.addSubnode(emptyRecentTextNode)
            recentEmptyNode.addSubnode(emptyRecentAnimationNode)
            
            recentEmptyNode.isUserInteractionEnabled = false
            recentEmptyNode.isHidden = true
            
            self.recentEmptyNode = recentEmptyNode
        }
        
        super.init()
                
        self.emptyResultsAnimationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "ChatListNoResults"), width: 256, height: 256, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
        self.emptyResultsAnimationSize = CGSize(width: 148.0, height: 148.0)
        
        self.addSubnode(self.recentListNode)
        
        if let recentEmptyNode = self.recentEmptyNode {
            self.addSubnode(recentEmptyNode)
        }
        
        if let listNode = self.listNode {
            self.addSubnode(listNode)
        }
        if let mediaNode = self.mediaNode {
            self.addSubnode(mediaNode)
        }
        
        self.addSubnode(self.emptyResultsAnimationNode)
        self.addSubnode(self.emptyResultsTitleNode)
        self.addSubnode(self.emptyResultsTextNode)

        self.addSubnode(self.shimmerNode)
        self.addSubnode(self.mediaAccessoryPanelContainer)
        
        let searchContexts = Promise<[Int: ChatListSearchMessagesContext]>([:])
        let searchContextsValue = self.searchContextsValue
        let updateSearchContexts: (([Int: ChatListSearchMessagesContext]) -> ([Int: ChatListSearchMessagesContext], Bool)) -> Void = { f in
            var shouldUpdate = false
            let updated = searchContextsValue.modify { current in
                let (u, s) = f(current)
                shouldUpdate = s
                if s {
                    return u
                } else {
                    return current
                }
            }
            if shouldUpdate {
                searchContexts.set(.single(updated))
            }
        }
        
        self.listNode?.isHidden = true
        self.mediaNode?.isHidden = true
        self.recentListNode.isHidden = peersFilter.contains(.excludeRecent)
        
        let currentRemotePeers = Atomic<([FoundPeer], [FoundPeer], [AdPeer])?>(value: nil)
        let presentationDataPromise = self.presentationDataPromise
        let searchStatePromise = self.searchStatePromise
        let selectionPromise = self.selectedMessagesPromise
        
        let previousRecentlySearchedPeerOrder = Atomic<[EnginePeer.Id]>(value: [])
        let fixedRecentlySearchedPeers: Signal<[RecentlySearchedPeer], NoError>
        
        var enableRecentlySearched = false
        if !self.peersFilter.contains(.excludeRecent) {
            if case .chats = key {
                if case .chatList(.root) = location {
                    enableRecentlySearched = true
                } else if case .forum = location {
                    enableRecentlySearched = true
                }
            } else if case .topics = key, case .forum = location {
                enableRecentlySearched = true
            }
        }
        if case .savedMessagesChats = location {
            enableRecentlySearched = false
        }
        
        if enableRecentlySearched {
            fixedRecentlySearchedPeers = context.engine.peers.recentlySearchedPeers()
            |> map { peers -> [RecentlySearchedPeer] in
                var result: [RecentlySearchedPeer] = []
                let _ = previousRecentlySearchedPeerOrder.modify { current in
                    var updated: [EnginePeer.Id] = []
                    for id in current {
                        inner: for peer in peers {
                            if peer.peer.peerId == id {
                                updated.append(id)
                                result.append(peer)
                                break inner
                            }
                        }
                    }
                    for peer in peers.reversed() {
                        if !updated.contains(peer.peer.peerId) {
                            updated.insert(peer.peer.peerId, at: 0)
                            result.insert(peer, at: 0)
                        }
                    }
                    return updated
                }
                return result
            }
        } else {
            fixedRecentlySearchedPeers = .single([])
        }
            
        let downloadItems: Signal<(inProgressItems: [DownloadItem], doneItems: [RenderedRecentDownloadItem]), NoError>
        if key == .downloads {
            var firstTime = true
            downloadItems = combineLatest(queue: .mainQueue(), (context.fetchManager as! FetchManagerImpl).entriesSummary, recentDownloadItems(postbox: context.account.postbox))
            |> mapToSignal { entries, recentDownloadItems -> Signal<(inProgressItems: [DownloadItem], doneItems: [RenderedRecentDownloadItem]), NoError> in
                var itemSignals: [Signal<DownloadItem?, NoError>] = []
                
                for entry in entries {
                    switch entry.id.locationKey {
                    case let .messageId(id):
                        itemSignals.append(context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: id))
                        |> map { message -> DownloadItem? in
                            if let message = message {
                                return DownloadItem(resourceId: entry.resourceReference.resource.id, message: message, priority: entry.priority, isPaused: entry.isPaused)
                            }
                            return nil
                        })
                    default:
                        break
                    }
                }
                
                return combineLatest(queue: .mainQueue(), itemSignals)
                |> map { items -> (inProgressItems: [DownloadItem], doneItems: [RenderedRecentDownloadItem]) in
                    return (items.compactMap { $0 }, recentDownloadItems)
                }
                |> mapToSignal { value -> Signal<(inProgressItems: [DownloadItem], doneItems: [RenderedRecentDownloadItem]), NoError> in
                    if firstTime {
                        firstTime = false
                        return .single(value)
                    } else {
                        return .single(value)
                        |> delay(0.1, queue: .mainQueue())
                    }
                }
            }
        } else {
            downloadItems = .single(([], []))
        }
        
        struct SearchedPeersState {
            var ids: [EnginePeer.Id] = []
            var query: String?
        }
        let previousRecentlySearchedPeersState = Atomic<SearchedPeersState?>(value: nil)
        let hadAnySearchMessages = Atomic<Bool>(value: false)
        
        let adsHiddenPromise = self.adsHiddenPromise
        
        let foundItems: Signal<([ChatListSearchEntry], Bool)?, NoError> = combineLatest(queue: .mainQueue(), searchQuery, searchOptions, self.searchScopePromise.get(), downloadItems)
        |> mapToSignal { [weak self] query, options, searchScope, downloadItems -> Signal<([ChatListSearchEntry], Bool)?, NoError> in
            if query == nil && options == nil && [.chats, .topics, .channels, .apps].contains(key) {
                let _ = currentRemotePeers.swap(nil)
                return .single(nil)
            }
            
            if key == .downloads {
                let queryTokens = stringIndexTokens(query ?? "", transliteration: .combined)
                
                func messageMatchesTokens(message: EngineMessage, tokens: [ValueBoxKey]) -> Bool {
                    for media in message.media {
                        if let file = media as? TelegramMediaFile {
                            if let fileName = file.fileName {
                                if matchStringIndexTokens(stringIndexTokens(fileName, transliteration: .none), with: tokens) {
                                    return true
                                }
                            }
                        } else if let _ = media as? TelegramMediaImage {
                            if matchStringIndexTokens(stringIndexTokens("Photo Image", transliteration: .none), with: tokens) {
                                return true
                            }
                        }
                    }
                    return false
                }
                
                return combineLatest(queue: .mainQueue(), presentationDataPromise.get(), selectionPromise.get())
                |> map { presentationData, selectionState -> ([ChatListSearchEntry], Bool)? in
                    var entries: [ChatListSearchEntry] = []
                    var existingMessageIds = Set<MessageId>()
                    
                    var allPaused = true
                    for item in downloadItems.inProgressItems {
                        if !item.isPaused {
                            allPaused = false
                            break
                        }
                    }
                    
                    for item in downloadItems.inProgressItems.sorted(by: { $0.priority < $1.priority }) {
                        if existingMessageIds.contains(item.message.id) {
                            continue
                        }
                        existingMessageIds.insert(item.message.id)
                        
                        let message = item.message
                        
                        if !queryTokens.isEmpty {
                            if !messageMatchesTokens(message: message, tokens: queryTokens) {
                                continue
                            }
                        }
                        
                        var peer = EngineRenderedPeer(message: message)
                        if let group = item.message.peers[message.id.peerId] as? TelegramGroup, let migrationReference = group.migrationReference {
                            if let channelPeer = message.peers[migrationReference.peerId] {
                                peer = EngineRenderedPeer(peer: EnginePeer(channelPeer))
                            }
                        }
                        
                        var resource: (id: String, size: Int64, isFirstInList: Bool)?
                        if let resourceValue = findMediaResourceById(message: item.message, resourceId: item.resourceId), let size = resourceValue.size {
                            resource = (resourceValue.id.stringRepresentation, size, entries.isEmpty)
                        }
                                                
                        entries.append(.message(message, peer, nil, nil, presentationData, 1, nil, false, .downloading(item.priority), resource, .downloading, allPaused, nil, false, .everywhere))
                    }
                    for item in downloadItems.doneItems.sorted(by: { ChatListSearchEntry.MessageOrderingKey.downloaded(timestamp: $0.timestamp, index: $0.message.index) < ChatListSearchEntry.MessageOrderingKey.downloaded(timestamp: $1.timestamp, index: $1.message.index) }) {
                        if !item.isSeen {
                            Queue.mainQueue().async {
                                self?.scheduleMarkRecentDownloadsAsSeen()
                            }
                        }
                        if existingMessageIds.contains(item.message.id) {
                            continue
                        }
                        existingMessageIds.insert(item.message.id)
                        
                        let message = EngineMessage(item.message)
                        
                        if !queryTokens.isEmpty {
                            if !messageMatchesTokens(message: message, tokens: queryTokens) {
                                continue
                            }
                        }
                        
                        var peer = EngineRenderedPeer(message: message)
                        if let group = item.message.peers[message.id.peerId] as? TelegramGroup, let migrationReference = group.migrationReference {
                            if let channelPeer = message.peers[migrationReference.peerId] {
                                peer = EngineRenderedPeer(peer: EnginePeer(channelPeer))
                            }
                        }
                        
                        entries.append(.message(message, peer, nil, nil, presentationData, 1, selectionState?.contains(message.id), false, .downloaded(timestamp: item.timestamp, index: message.index), (item.resourceId, item.size, false), .recentlyDownloaded, false, nil, false, .everywhere))
                    }
                    return (entries.sorted(), false)
                }
            }
            
            let accountPeer = context.account.postbox.loadedPeerWithId(context.account.peerId) |> take(1)
            let foundLocalPeers: Signal<(peers: [EngineRenderedPeer], unread: [EnginePeer.Id: (Int32, Bool)], recentlySearchedPeerIds: Set<EnginePeer.Id>), NoError>
            
            if case .savedMessagesChats = location {
                if let query {
                    foundLocalPeers = context.engine.messages.searchLocalSavedMessagesPeers(query: query.lowercased(), indexNameMapping: [
                        context.account.peerId: [
                            PeerIndexNameRepresentation.title(title: presentationData.strings.DialogList_MyNotes.lowercased(), addressNames: []),
                            PeerIndexNameRepresentation.title(title: "my notes".lowercased(), addressNames: [])
                        ],
                        PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(2666000)): [
                            PeerIndexNameRepresentation.title(title: presentationData.strings.ChatList_AuthorHidden.lowercased(), addressNames: [])
                        ]
                    ])
                    |> map { peers -> (peers: [EngineRenderedPeer], unread: [EnginePeer.Id: (Int32, Bool)], recentlySearchedPeerIds: Set<EnginePeer.Id>) in
                        return (peers.map(EngineRenderedPeer.init(peer:)), [:], Set())
                    }
                } else {
                    foundLocalPeers = .single(([], [:], Set()))
                }
            } else if let query = query, (key == .chats || key == .topics) {
                if query.hasPrefix("#") {
                    foundLocalPeers = .single(([], [:], Set()))
                } else {
                    let fixedOrRemovedRecentlySearchedPeers = context.engine.peers.recentlySearchedPeers()
                    |> map { peers -> [RecentlySearchedPeer] in
                        let allIds = peers.map(\.peer.peerId)
                        
                        let updatedState = previousRecentlySearchedPeersState.modify { current in
                            if var current = current, current.query == query {
                                current.ids = current.ids.filter { id in
                                    allIds.contains(id)
                                }
                                
                                return current
                            } else {
                                var state = SearchedPeersState()
                                state.ids = allIds
                                state.query = query
                                return state
                            }
                        }
                        
                        var result: [RecentlySearchedPeer] = []
                        if let updatedState = updatedState {
                            for id in updatedState.ids {
                                for peer in peers {
                                    if id == peer.peer.peerId {
                                        result.append(peer)
                                    }
                                }
                            }
                        }
                        
                        return result
                    }
                    
                    let updatedLocalPeers = context.engine.contacts.searchLocalPeers(query: query.lowercased())
                    |> mapToSignal { peers -> Signal<[EngineRenderedPeer], NoError> in
                        return context.engine.data.subscribe(
                            EngineDataMap(peers.map { peer in
                                return TelegramEngine.EngineData.Item.Messages.ChatListIndex(id: peer.peerId)
                            })
                        )
                        |> map { chatListIndices -> [EngineRenderedPeer] in
                            return peers.filter { peer in
                                if peer.peerId.namespace == Namespaces.Peer.CloudUser || peer.peerId.namespace == Namespaces.Peer.SecretChat {
                                    return true
                                }
                                if let maybeIndex = chatListIndices[peer.peerId], maybeIndex != nil {
                                    return true
                                }
                                return false
                            }
                        }
                    }
                    
                    foundLocalPeers = combineLatest(
                        updatedLocalPeers,
                        fixedOrRemovedRecentlySearchedPeers
                    )
                    |> mapToSignal { local, allRecentlySearched -> Signal<([EnginePeer.Id: Optional<EnginePeer.NotificationSettings>], [EnginePeer.Id: TelegramEngine.EngineData.Item.Messages.PeerUnreadState.Result], [EngineRenderedPeer], Set<EnginePeer.Id>, EngineGlobalNotificationSettings), NoError> in
                        let recentlySearched = allRecentlySearched.filter { peer in
                            guard let peer = peer.peer.peer else {
                                return false
                            }
                            return peer.indexName.matchesByTokens(query)
                        }
                        
                        var peerIds = Set<EnginePeer.Id>()
                        
                        var peers: [EngineRenderedPeer] = []
                        for peer in recentlySearched {
                            if !peerIds.contains(peer.peer.peerId) {
                                peerIds.insert(peer.peer.peerId)
                                peers.append(EngineRenderedPeer(peer.peer))
                            }
                        }
                        for peer in local {
                            if !peerIds.contains(peer.peerId) {
                                peerIds.insert(peer.peerId)
                                peers.append(peer)
                            }
                        }
                        
                        return context.engine.data.subscribe(
                            EngineDataMap(
                                peerIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.NotificationSettings in
                                    return TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peerId)
                                }
                            ),
                            EngineDataMap(
                                peerIds.map { peerId -> TelegramEngine.EngineData.Item.Messages.PeerUnreadState in
                                    return TelegramEngine.EngineData.Item.Messages.PeerUnreadState(id: peerId)
                                }
                            ),
                            TelegramEngine.EngineData.Item.NotificationSettings.Global()
                        )
                        |> map { notificationSettings, unreadCounts, globalNotificationSettings in
                            return (notificationSettings, unreadCounts, peers, Set(recentlySearched.map(\.peer.peerId)), globalNotificationSettings)
                        }
                    }
                    |> map { notificationSettings, unreadCounts, peers, recentlySearchedPeerIds, globalNotificationSettings -> (peers: [EngineRenderedPeer], unread: [EnginePeer.Id: (Int32, Bool)], recentlySearchedPeerIds: Set<EnginePeer.Id>) in
                        var unread: [EnginePeer.Id: (Int32, Bool)] = [:]
                        for peer in peers {
                            var isMuted = false
                            if let peerNotificationSettings = notificationSettings[peer.peerId], let peerNotificationSettings {
                                if case let .muted(until) = peerNotificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                                    isMuted = true
                                } else if case .default = peerNotificationSettings.muteState {
                                    if let peer = peer.peer {
                                        if case .user = peer {
                                            isMuted = !globalNotificationSettings.privateChats.enabled
                                        } else if case .legacyGroup = peer {
                                            isMuted = !globalNotificationSettings.groupChats.enabled
                                        } else if case let .channel(channel) = peer {
                                            switch channel.info {
                                            case .group:
                                                isMuted = !globalNotificationSettings.groupChats.enabled
                                            case .broadcast:
                                                isMuted = !globalNotificationSettings.channels.enabled
                                            }
                                        }
                                    }
                                }
                            }
                            let unreadCount = unreadCounts[peer.peerId]
                            if let unreadCount = unreadCount, (unreadCount.count > 0 || unreadCount.isMarkedUnread) {
                                unread[peer.peerId] = (Int32(unreadCount.count), isMuted)
                            }
                        }
                        return (peers: peers, unread: unread, recentlySearchedPeerIds: recentlySearchedPeerIds)
                    }
                }
            } else if let query = query, key == .channels {
                foundLocalPeers = combineLatest(
                    context.engine.contacts.searchLocalPeers(query: query.lowercased(), scope: .channels),
                    context.engine.peers.recommendedChannelPeerIds(peerId: nil)
                )
                |> mapToSignal { local, recommended -> Signal<(peers: [EngineRenderedPeer], unread: [EnginePeer.Id: (Int32, Bool)], recentlySearchedPeerIds: Set<EnginePeer.Id>), NoError> in
                    var peerIds: [EnginePeer.Id] = []
                    
                    for peer in local {
                        if !peerIds.contains(peer.peerId) {
                            peerIds.append(peer.peerId)
                        }
                    }
                    if let recommended {
                        for id in recommended {
                            if !peerIds.contains(id) {
                                peerIds.append(id)
                            }
                        }
                    }
                    
                    return context.engine.data.subscribe(
                        EngineDataMap(
                            peerIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                                return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                            }
                        ),
                        EngineDataMap(
                            peerIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.NotificationSettings in
                                return TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peerId)
                            }
                        ),
                        EngineDataMap(
                            peerIds.map { peerId -> TelegramEngine.EngineData.Item.Messages.PeerUnreadCount in
                                return TelegramEngine.EngineData.Item.Messages.PeerUnreadCount(id: peerId)
                            }
                        ),
                        TelegramEngine.EngineData.Item.NotificationSettings.Global()
                    )
                    |> map { peers, notificationSettings, unreadCounts, globalNotificationSettings -> (peers: [EngineRenderedPeer], unread: [EnginePeer.Id: (Int32, Bool)], recentlySearchedPeerIds: Set<EnginePeer.Id>) in
                        var resultPeers: [EngineRenderedPeer] = []
                        var unread: [EnginePeer.Id: (Int32, Bool)] = [:]
                        
                        var matchingIds: [EnginePeer.Id] = []
                        for peer in local {
                            if !matchingIds.contains(peer.peerId) {
                                matchingIds.append(peer.peerId)
                            }
                        }
                        
                        let queryTokens = stringIndexTokens(query.lowercased(), transliteration: .combined)
                        if let recommended {
                            for id in recommended {
                                guard let maybePeer = peers[id], let peer = maybePeer else {
                                    continue
                                }
                                
                                if peer.indexName.matchesByTokens(queryTokens) {
                                    if !matchingIds.contains(id) {
                                        matchingIds.append(id)
                                    }
                                }
                            }
                        }
                        
                        for id in matchingIds {
                            guard let maybePeer = peers[id], let peer = maybePeer else {
                                continue
                            }
                            resultPeers.append(EngineRenderedPeer(peer: peer))
                            var isMuted = false
                            if let peerNotificationSettings = notificationSettings[peer.id] {
                                if case let .muted(until) = peerNotificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                                    isMuted = true
                                } else if case .default = peerNotificationSettings.muteState {
                                    if case .user = peer {
                                        isMuted = !globalNotificationSettings.privateChats.enabled
                                    } else if case .legacyGroup = peer {
                                        isMuted = !globalNotificationSettings.groupChats.enabled
                                    } else if case let .channel(channel) = peer {
                                        switch channel.info {
                                        case .group:
                                            isMuted = !globalNotificationSettings.groupChats.enabled
                                        case .broadcast:
                                            isMuted = !globalNotificationSettings.channels.enabled
                                        }
                                    }
                                }
                            }
                            let unreadCount = unreadCounts[peer.id]
                            if let unreadCount = unreadCount, unreadCount > 0 {
                                unread[peer.id] = (Int32(unreadCount), isMuted)
                            }
                        }
                        return (peers: resultPeers, unread: unread, recentlySearchedPeerIds: Set())
                    }
                }
            } else if let query, key == .apps {
                foundLocalPeers = combineLatest(
                    context.engine.peers.recentApps(),
                    context.engine.peers.recommendedAppPeerIds()
                )
                |> mapToSignal { local, recommended -> Signal<(peers: [EngineRenderedPeer], unread: [EnginePeer.Id: (Int32, Bool)], recentlySearchedPeerIds: Set<EnginePeer.Id>), NoError> in
                    var peerIds: [EnginePeer.Id] = []
                    
                    for peer in local {
                        if !peerIds.contains(peer) {
                            peerIds.append(peer)
                        }
                    }
                    if let recommended {
                        for id in recommended {
                            if !peerIds.contains(id) {
                                peerIds.append(id)
                            }
                        }
                    }
                    
                    return context.engine.data.subscribe(
                        EngineDataMap(
                            peerIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                                return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                            }
                        ),
                        EngineDataMap(
                            peerIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.NotificationSettings in
                                return TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peerId)
                            }
                        ),
                        EngineDataMap(
                            peerIds.map { peerId -> TelegramEngine.EngineData.Item.Messages.PeerUnreadCount in
                                return TelegramEngine.EngineData.Item.Messages.PeerUnreadCount(id: peerId)
                            }
                        ),
                        TelegramEngine.EngineData.Item.NotificationSettings.Global()
                    )
                    |> map { peers, notificationSettings, unreadCounts, globalNotificationSettings -> (peers: [EngineRenderedPeer], unread: [EnginePeer.Id: (Int32, Bool)], recentlySearchedPeerIds: Set<EnginePeer.Id>) in
                        var resultPeers: [EngineRenderedPeer] = []
                        var unread: [EnginePeer.Id: (Int32, Bool)] = [:]
                        
                        let queryTokens = stringIndexTokens(query.lowercased(), transliteration: .combined)
                        
                        var matchingIds: [EnginePeer.Id] = []
                        for peerId in local {
                            guard let maybePeer = peers[peerId], let peer = maybePeer else {
                                continue
                            }
                            if peer.indexName.matchesByTokens(queryTokens) {
                                if !matchingIds.contains(peerId) {
                                    matchingIds.append(peerId)
                                }
                            }
                        }
                        
                        if let recommended {
                            for id in recommended {
                                guard let maybePeer = peers[id], let peer = maybePeer else {
                                    continue
                                }
                                
                                if peer.indexName.matchesByTokens(queryTokens) {
                                    if !matchingIds.contains(id) {
                                        matchingIds.append(id)
                                    }
                                }
                            }
                        }
                        
                        for id in matchingIds {
                            guard let maybePeer = peers[id], let peer = maybePeer else {
                                continue
                            }
                            resultPeers.append(EngineRenderedPeer(peer: peer))
                            var isMuted = false
                            if let peerNotificationSettings = notificationSettings[peer.id] {
                                if case let .muted(until) = peerNotificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                                    isMuted = true
                                } else if case .default = peerNotificationSettings.muteState {
                                    if case .user = peer {
                                        isMuted = !globalNotificationSettings.privateChats.enabled
                                    } else if case .legacyGroup = peer {
                                        isMuted = !globalNotificationSettings.groupChats.enabled
                                    } else if case let .channel(channel) = peer {
                                        switch channel.info {
                                        case .group:
                                            isMuted = !globalNotificationSettings.groupChats.enabled
                                        case .broadcast:
                                            isMuted = !globalNotificationSettings.channels.enabled
                                        }
                                    }
                                }
                            }
                            let unreadCount = unreadCounts[peer.id]
                            if let unreadCount = unreadCount, unreadCount > 0 {
                                unread[peer.id] = (Int32(unreadCount), isMuted)
                            }
                        }
                        return (peers: resultPeers, unread: unread, recentlySearchedPeerIds: Set())
                    }
                }
            } else {
                foundLocalPeers = .single((peers: [], unread: [:], recentlySearchedPeerIds: Set()))
                
                let _ = previousRecentlySearchedPeersState.swap(nil)
            }
            
            let foundRemotePeers: Signal<([FoundPeer], [FoundPeer], [AdPeer], Bool), NoError>
            let currentRemotePeersValue: ([FoundPeer], [FoundPeer], [AdPeer]) = currentRemotePeers.with { $0 } ?? ([], [], [])
            if case .savedMessagesChats = location {
                foundRemotePeers = .single(([], [], [], false))
            } else if let query = query, case .chats = key {
                if query.hasPrefix("#") {
                    foundRemotePeers = .single(([], [], [], false))
                } else {
                    foundRemotePeers = (
                        .single((currentRemotePeersValue.0, currentRemotePeersValue.1, currentRemotePeersValue.2, true))
                        |> then(
                            globalPeerSearchContext.searchRemotePeers(engine: context.engine, query: query)
                            |> mapToSignal { result in
                                return context.engine.peers.searchAdPeers(query: query)
                                |> map { adPeers in
                                    return (result.0, result.1, adPeers, false)
                                }
                            }
                        )
                    )
                }
            } else if let query = query, case .channels = key {
                foundRemotePeers = (
                    .single((currentRemotePeersValue.0, currentRemotePeersValue.1, currentRemotePeersValue.2, true))
                    |> then(
                        globalPeerSearchContext.searchRemotePeers(engine: context.engine, query: query, scope: .channels)
                        |> map { ($0.0, $0.1, [], false) }
                    )
                )
            } else if let query, case .apps = key {
                let _ = query
                foundRemotePeers = .single(([], [], [], false))
            } else {
                foundRemotePeers = .single(([], [], [], false))
            }
            let searchLocations: [SearchMessagesLocation]
            if let options = options {
                if case let .forum(peerId) = location {
                    searchLocations = [.peer(peerId: peerId, fromId: nil, tags: tagMask, reactions: nil, threadId: nil, minDate: options.date?.0, maxDate: options.date?.1), .general(scope: .everywhere, tags: tagMask, minDate: options.date?.0, maxDate: options.date?.1)]
                } else if let (peerId, _, _) = options.peer {
                    searchLocations = [.peer(peerId: peerId, fromId: nil, tags: tagMask, reactions: nil, threadId: nil, minDate: options.date?.0, maxDate: options.date?.1)]
                } else {
                    if case let .chatList(groupId) = location, case .archive = groupId {
                        searchLocations = [.group(groupId: groupId._asGroup(), tags: tagMask, minDate: options.date?.0, maxDate: options.date?.1)]
                    } else {
                        searchLocations = [.general(scope: searchScope, tags: tagMask, minDate: options.date?.0, maxDate: options.date?.1)]
                    }
                }
            } else {
                if case .channels = key {
                    searchLocations = [.general(scope: .channels, tags: tagMask, minDate: nil, maxDate: nil)]
                } else if case let .forum(peerId) = location {
                    searchLocations = [.peer(peerId: peerId, fromId: nil, tags: tagMask, reactions: nil, threadId: nil, minDate: nil, maxDate: nil), .general(scope: .everywhere, tags: tagMask, minDate: nil, maxDate: nil)]
                } else if case let .chatList(groupId) = location, case .archive = groupId {
                    searchLocations = [.group(groupId: groupId._asGroup(), tags: tagMask, minDate: nil, maxDate: nil)]
                } else {
                    searchLocations = [.general(scope: searchScope, tags: tagMask, minDate: nil, maxDate: nil)]
                }
            }
            
            let finalQuery = query ?? ""
            updateSearchContexts { _ in
                return ([:], true)
            }
            
            struct FoundRemoteMessages {
                var messages: [EngineMessage]
                var readCounters: [EnginePeer.Id: EnginePeerReadCounters]
                var threadsData: [EngineMessage.Id: MessageHistoryThreadData]
                var totalCount: Int32
                
                init(messages: [EngineMessage], readCounters: [EnginePeer.Id: EnginePeerReadCounters], threadsData: [EngineMessage.Id: MessageHistoryThreadData], totalCount: Int32) {
                    self.messages = messages
                    self.readCounters = readCounters
                    self.threadsData = threadsData
                    self.totalCount = totalCount
                }
            }
            
            let foundPublicMessages: Signal<([FoundRemoteMessages], Bool), NoError>
            if key == .chats || key == .publicPosts, let query, query.hasPrefix("#") {
                let searchSignal = context.engine.messages.searchHashtagPosts(hashtag: finalQuery, state: nil, limit: 10)
                
                let loadMore: Signal<([FoundRemoteMessages], Bool), NoError>
                if key == .publicPosts {
                    loadMore = searchContexts.get()
                    |> mapToSignal { searchContexts -> Signal<([FoundRemoteMessages], Bool), NoError> in
                        let i = 0
                        if let searchContext = searchContexts[i], searchContext.result.hasMore {
                            if let _ = searchContext.loadMoreIndex {
                                return context.engine.messages.searchHashtagPosts(hashtag: finalQuery, state: searchContext.result.state, limit: 80)
                                |> map { result, updatedState -> ChatListSearchMessagesResult in
                                    return ChatListSearchMessagesResult(query: finalQuery, messages: result.messages.map({ EngineMessage($0) }).sorted(by: { $0.index > $1.index }), readStates: result.readStates.mapValues { EnginePeerReadCounters(state: $0, isMuted: false) }, threadInfo: result.threadInfo, hasMore: !result.completed, totalCount: result.totalCount, state: updatedState)
                                }
                                |> mapToSignal { foundMessages -> Signal<([FoundRemoteMessages], Bool), NoError> in
                                    updateSearchContexts { previous in
                                        let updated = ChatListSearchMessagesContext(result: foundMessages, loadMoreIndex: nil)
                                        var previous = previous
                                        previous[i] = updated
                                        return (previous, true)
                                    }
                                    return .complete()
                                }
                            } else {
                                var currentResults: [FoundRemoteMessages] = []
                                if let currentContext = searchContexts[i] {
                                    currentResults.append(FoundRemoteMessages(messages: currentContext.result.messages, readCounters: currentContext.result.readStates, threadsData: currentContext.result.threadInfo, totalCount: currentContext.result.totalCount))
                                }
                                return .single((currentResults, false))
                            }
                        }
                        
                        return .complete()
                    }
                } else {
                    loadMore = .complete()
                }
                    
                foundPublicMessages = .single(([FoundRemoteMessages(messages: [], readCounters: [:], threadsData: [:], totalCount: 0)], true))
                |> then(
                    searchSignal
                    |> map { result -> ([FoundRemoteMessages], Bool) in
                        updateSearchContexts { _ in
                            var resultContexts: [Int: ChatListSearchMessagesContext] = [:]
                            resultContexts[0] = ChatListSearchMessagesContext(result: ChatListSearchMessagesResult(query: finalQuery, messages: result.0.messages.map({ EngineMessage($0) }).sorted(by: { $0.index > $1.index }), readStates: result.0.readStates.mapValues { EnginePeerReadCounters(state: $0, isMuted: false) }, threadInfo: result.0.threadInfo, hasMore: !result.0.completed, totalCount: result.0.totalCount, state: result.1), loadMoreIndex: nil)
                            return (resultContexts, true)
                        }
                        
                        let foundMessages = result.0
                        let messages: [EngineMessage]
                        if key == .chats {
                            messages = foundMessages.messages.prefix(3).map { EngineMessage($0) }
                        } else {
                            messages = foundMessages.messages.map { EngineMessage($0) }
                        }
                        return ([FoundRemoteMessages(messages: messages, readCounters: foundMessages.readStates.mapValues { EnginePeerReadCounters(state: $0, isMuted: false) }, threadsData: foundMessages.threadInfo, totalCount: foundMessages.totalCount)], false)
                    }
                    |> delay(0.2, queue: Queue.concurrentDefaultQueue())
                    |> then(loadMore)
                )
            } else {
                foundPublicMessages = .single(([FoundRemoteMessages(messages: [], readCounters: [:], threadsData: [:], totalCount: 0)], false))
            }
            
            let foundRemoteMessages: Signal<([FoundRemoteMessages], Bool), NoError>
            if key == .publicPosts {
                foundRemoteMessages = .single(([FoundRemoteMessages(messages: [], readCounters: [:], threadsData: [:], totalCount: 0)], false))
            } else if case .savedMessagesChats = location {
                foundRemoteMessages = .single(([FoundRemoteMessages(messages: [], readCounters: [:], threadsData: [:], totalCount: 0)], false))
            } else if peersFilter.contains(.doNotSearchMessages) {
                foundRemoteMessages = .single(([FoundRemoteMessages(messages: [], readCounters: [:], threadsData: [:], totalCount: 0)], false))
            } else if key == .apps {
                foundRemoteMessages = .single(([FoundRemoteMessages(messages: [], readCounters: [:], threadsData: [:], totalCount: 0)], false))
            } else {
                if !finalQuery.isEmpty {
                    addAppLogEvent(postbox: context.account.postbox, type: "search_global_query")
                }
                
                let searchSignals: [Signal<(SearchMessagesResult, SearchMessagesState), NoError>] = searchLocations.map { searchLocation in
                    return context.engine.messages.searchMessages(location: searchLocation, query: finalQuery, state: nil, limit: 50)
                }
                
                let searchSignal = combineLatest(searchSignals)
                |> map { results -> [ChatListSearchMessagesResult] in
                    var mappedResults: [ChatListSearchMessagesResult] = []
                    for resultData in results {
                        let (result, updatedState) = resultData
                        
                        mappedResults.append(ChatListSearchMessagesResult(query: finalQuery, messages: result.messages.map({ EngineMessage($0) }).sorted(by: { $0.index > $1.index }), readStates: result.readStates.mapValues { EnginePeerReadCounters(state: $0, isMuted: false) }, threadInfo: result.threadInfo, hasMore: !result.completed, totalCount: result.totalCount, state: updatedState))
                    }
                    return mappedResults
                }
                
                let loadMore = searchContexts.get()
                |> mapToSignal { searchContexts -> Signal<([FoundRemoteMessages], Bool), NoError> in
                    for i in 0 ..< 2 {
                        if let searchContext = searchContexts[i], searchContext.result.hasMore {
                            var restResults: [Int: FoundRemoteMessages] = [:]
                            for j in 0 ..< 2 {
                                if j != i {
                                    if let otherContext = searchContexts[j] {
                                        restResults[j] = FoundRemoteMessages(messages: otherContext.result.messages, readCounters: otherContext.result.readStates, threadsData: otherContext.result.threadInfo, totalCount: otherContext.result.totalCount)
                                    }
                                }
                            }
                            if let _ = searchContext.loadMoreIndex {
                                return context.engine.messages.searchMessages(location: searchLocations[i], query: finalQuery, state: searchContext.result.state, limit: 80)
                                |> map { result, updatedState -> ChatListSearchMessagesResult in
                                    return ChatListSearchMessagesResult(query: finalQuery, messages: result.messages.map({ EngineMessage($0) }).sorted(by: { $0.index > $1.index }), readStates: result.readStates.mapValues { EnginePeerReadCounters(state: $0, isMuted: false) }, threadInfo: result.threadInfo, hasMore: !result.completed, totalCount: result.totalCount, state: updatedState)
                                }
                                |> mapToSignal { foundMessages -> Signal<([FoundRemoteMessages], Bool), NoError> in
                                    updateSearchContexts { previous in
                                        let updated = ChatListSearchMessagesContext(result: foundMessages, loadMoreIndex: nil)
                                        var previous = previous
                                        previous[i] = updated
                                        return (previous, true)
                                    }
                                    return .complete()
                                }
                            } else {
                                var currentResults: [FoundRemoteMessages] = []
                                for i in 0 ..< 2 {
                                    if let currentContext = searchContexts[i] {
                                        currentResults.append(FoundRemoteMessages(messages: currentContext.result.messages, readCounters: currentContext.result.readStates, threadsData: currentContext.result.threadInfo, totalCount: currentContext.result.totalCount))
                                        if currentContext.result.hasMore {
                                            break
                                        }
                                    }
                                }
                                return .single((currentResults, false))
                            }
                        }
                    }
                    
                    return .complete()
                }
                
                foundRemoteMessages = .single(([FoundRemoteMessages(messages: [], readCounters: [:], threadsData: [:], totalCount: 0)], true))
                |> then(
                    searchSignal
                    |> map { foundMessages -> ([FoundRemoteMessages], Bool) in
                        updateSearchContexts { _ in
                            var resultContexts: [Int: ChatListSearchMessagesContext] = [:]
                            for i in 0 ..< foundMessages.count {
                                resultContexts[i] = ChatListSearchMessagesContext(result: foundMessages[i], loadMoreIndex: nil)
                            }
                            return (resultContexts, true)
                        }
                        var result: [FoundRemoteMessages] = []
                        for i in 0 ..< foundMessages.count {
                            result.append(FoundRemoteMessages(messages: foundMessages[i].messages, readCounters: foundMessages[i].readStates, threadsData: foundMessages[i].threadInfo, totalCount: foundMessages[i].totalCount))
                            if foundMessages[i].hasMore {
                                break
                            }
                        }
                        return (result, false)
                    }
                    |> delay(0.2, queue: Queue.concurrentDefaultQueue())
                    |> then(loadMore)
                )
            }
            
            let resolvedMessage: Signal<EngineMessage?, NoError>
            if case .savedMessagesChats = location {
                resolvedMessage = .single(nil)
            } else {
                resolvedMessage = .single(nil)
                |> then(context.sharedContext.resolveUrl(context: context, peerId: nil, url: finalQuery, skipUrlAuth: true)
                |> mapToSignal { resolvedUrl -> Signal<EngineMessage?, NoError> in
                    if case let .channelMessage(_, messageId, _) = resolvedUrl {
                        return context.engine.messages.downloadMessage(messageId: messageId)
                        |> map { message -> EngineMessage? in
                            return message.flatMap(EngineMessage.init)
                        }
                    } else {
                        return .single(nil)
                    }
                })
            }
            
            let foundThreads: Signal<[EngineChatList.Item], NoError>
            if case let .forum(peerId) = location, (key == .topics || key == .chats) {
                foundThreads = chatListViewForLocation(chatListLocation: location, location: .initial(count: 1000, filter: nil), account: context.account, shouldLoadCanMessagePeer: true)
                |> map { view -> [EngineChatList.Item] in
                    var filteredItems: [EngineChatList.Item] = []
                    let queryTokens = stringIndexTokens(finalQuery, transliteration: .combined)
                    for item in view.list.items {
                        if !finalQuery.isEmpty {
                            if let title = item.threadData?.info.title {
                                let tokens = stringIndexTokens(title, transliteration: .combined)
                                if matchStringIndexTokens(tokens, with: queryTokens) {
                                    filteredItems.append(item)
                                }
                            }
                        }
                    }
                    
                    return filteredItems
                }
                |> mapToSignal { local -> Signal<[EngineChatList.Item], NoError> in
                    return .single(local)
                    |> then(context.engine.messages.searchForumTopics(peerId: peerId, query: finalQuery)
                    |> map { remoteResult in
                        var mergedResult = local
                        for item in remoteResult {
                            guard case let .forum(threadId) = item.id else {
                                continue
                            }
                            if !mergedResult.contains(where: { $0.id == .forum(threadId) }) {
                                mergedResult.append(item)
                            }
                        }
                        
                        return mergedResult
                    })
                }
                |> distinctUntilChanged
            } else {
                foundThreads = .single([])
            }
            
            return combineLatest(
                accountPeer,
                foundLocalPeers,
                foundRemotePeers,
                foundRemoteMessages,
                foundPublicMessages,
                presentationDataPromise.get(),
                searchStatePromise.get(),
                selectionPromise.get(),
                resolvedMessage,
                fixedRecentlySearchedPeers,
                foundThreads,
                adsHiddenPromise.get()
            )
            |> map { accountPeer, foundLocalPeers, foundRemotePeers, foundRemoteMessages, foundPublicMessages, presentationData, searchState, selectionState, resolvedMessage, recentPeers, allAndFoundThreads, adsHidden -> ([ChatListSearchEntry], Bool)? in
                let isSearching = foundRemotePeers.3 || foundRemoteMessages.1 || foundPublicMessages.1
                var entries: [ChatListSearchEntry] = []
                var index = 0
                
                for thread in allAndFoundThreads {
                    if let peer = thread.renderedPeer.peer, let threadData = thread.threadData, case let .forum(_, _, id, _, _) = thread.index {
                        entries.append(.topic(peer, ChatListItemContent.ThreadInfo(id: id, info: threadData.info, isOwnedByMe: threadData.isOwnedByMe, isClosed: threadData.isClosed, isHidden: threadData.isHidden, threadPeer: nil), index, presentationData.theme, presentationData.strings, .none))
                        index += 1
                    }
                }
                
                var recentPeers = recentPeers
                if query != nil {
                    recentPeers = []
                }
                
                let _ = currentRemotePeers.swap((foundRemotePeers.0, foundRemotePeers.1, foundRemotePeers.2))
                
                let filteredPeer: (EnginePeer, EnginePeer) -> Bool = { peer, accountPeer in
                    if let requestPeerType {
                        guard !peer.isDeleted && peer.id != context.account.peerId else {
                            return false
                        }
                        
                        var match = false
                        for peerType in requestPeerType {
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
                        guard !peersFilter.contains(.excludeSavedMessages) || peersFilter.contains(.includeSelf) || peer.id != accountPeer.id else { return false }
                        guard !peersFilter.contains(.excludeSecretChats) || peer.id.namespace != Namespaces.Peer.SecretChat else { return false }
                        guard !peersFilter.contains(.onlyPrivateChats) || peer.id.namespace == Namespaces.Peer.CloudUser else { return false }
                        
                        if peersFilter.contains(.onlyGroups) {
                            var isGroup: Bool = false
                            if case let .channel(peer) = peer, case .group = peer.info {
                                isGroup = true
                            } else if peer.id.namespace == Namespaces.Peer.CloudGroup {
                                isGroup = true
                            }
                            if !isGroup {
                                return false
                            }
                        }
                        
                        if peersFilter.contains(.onlyChannels) {
                            if case let .channel(peer) = peer, case .broadcast = peer.info {
                                return true
                            } else {
                                return false
                            }
                        }
                        
                        if peersFilter.contains(.excludeChannels) {
                            if case let .channel(peer) = peer, case .broadcast = peer.info {
                                return false
                            }
                        }
                    }
                    
                    return true
                }
                
                var existingPeerIds = Set<EnginePeer.Id>()
                
                var totalNumberOfLocalPeers = 0
                for renderedPeer in foundLocalPeers.peers {
                    if let peer = renderedPeer.peers[renderedPeer.peerId], peer.id != context.account.peerId || peersFilter.contains(.includeSelf), filteredPeer(peer, EnginePeer(accountPeer)) {
                        if !existingPeerIds.contains(peer.id) {
                            existingPeerIds.insert(peer.id)
                            totalNumberOfLocalPeers += 1
                        }
                    }
                }
                for peer in foundRemotePeers.0 {
                    if !existingPeerIds.contains(peer.peer.id), filteredPeer(EnginePeer(peer.peer), EnginePeer(accountPeer)) {
                        existingPeerIds.insert(peer.peer.id)
                        totalNumberOfLocalPeers += 1
                    }
                }
                
                var totalNumberOfGlobalPeers = 0
                for peer in foundRemotePeers.1 {
                    if !existingPeerIds.contains(peer.peer.id), filteredPeer(EnginePeer(peer.peer), EnginePeer(accountPeer)) {
                        totalNumberOfGlobalPeers += 1
                    }
                }
                
                existingPeerIds.removeAll()
                
                let localExpandType: ChatListSearchSectionExpandType = .none
                let globalExpandType: ChatListSearchSectionExpandType
                if totalNumberOfGlobalPeers > 3 {
                    globalExpandType = searchState.expandGlobalSearch ? .collapse : .expand
                } else {
                    globalExpandType = .none
                }
                
                let lowercasedQuery = finalQuery.lowercased()
                if lowercasedQuery.count > 1 && (presentationData.strings.DialogList_SavedMessages.lowercased().hasPrefix(lowercasedQuery) || "saved messages".hasPrefix(lowercasedQuery)) {
                    if !existingPeerIds.contains(accountPeer.id), filteredPeer(EnginePeer(accountPeer), EnginePeer(accountPeer)) {
                        existingPeerIds.insert(accountPeer.id)
                        entries.append(.localPeer(EnginePeer(accountPeer), nil, nil, index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder, localExpandType, nil, false, false))
                        index += 1
                    }
                }
                                
                if peersFilter.contains(.includeSelf) {
                    for renderedPeer in foundLocalPeers.peers {
                        if renderedPeer.peerId == context.account.peerId, let peer = renderedPeer.peers[renderedPeer.peerId], filteredPeer(peer, EnginePeer(accountPeer)) {
                            if !existingPeerIds.contains(peer.id) {
                                existingPeerIds.insert(peer.id)
                                entries.append(.localPeer(peer, nil, nil, index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder, localExpandType, nil, false, true))
                            }
                            break
                        }
                    }
                }
                
                for renderedPeer in foundLocalPeers.peers {
                    if !foundLocalPeers.recentlySearchedPeerIds.contains(renderedPeer.peerId) {
                        continue
                    }
                    
                    if let peer = renderedPeer.peers[renderedPeer.peerId], peer.id != context.account.peerId, filteredPeer(peer, EnginePeer(accountPeer)) {
                        if !existingPeerIds.contains(peer.id) {
                            existingPeerIds.insert(peer.id)
                            var associatedPeer: EnginePeer?
                            if case let .secretChat(secretChat) = peer, let associatedPeerId = secretChat.associatedPeerId {
                                associatedPeer = renderedPeer.peers[associatedPeerId]
                            } else if case let .channel(channel) = peer, channel.isMonoForum {
                                associatedPeer = renderedPeer.chatOrMonoforumMainPeer
                            }
                            
                            entries.append(.recentlySearchedPeer(peer, associatedPeer, foundLocalPeers.unread[peer.id], index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder, nil, false))
                            
                            index += 1
                        }
                    }
                }
                
                if lowercasedQuery.count > 1 {
                    for peer in recentPeers {
                        let renderedPeer = peer
                        if let peer = peer.peer.chatMainPeer, !existingPeerIds.contains(peer.id) {
                            let peer = EnginePeer(peer)
                            var associatedPeer: EnginePeer?
                            if case let .channel(channel) = peer, channel.isMonoForum {
                                associatedPeer = renderedPeer.peer.chatOrMonoforumMainPeer.flatMap(EnginePeer.init)
                            }
                            
                            var matches = false
                            if case let .user(user) = peer {
                                if let firstName = user.firstName, firstName.lowercased().hasPrefix(lowercasedQuery) {
                                    matches = true
                                } else if let lastName = user.lastName, lastName.lowercased().hasPrefix(lowercasedQuery) {
                                    matches = true
                                }
                            } else if peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder).lowercased().hasPrefix(lowercasedQuery) {
                                matches = true
                            }
                            
                            if matches {
                                existingPeerIds.insert(peer.id)
                                entries.append(.localPeer(peer, associatedPeer, nil, index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder, localExpandType, nil, false, false))
                            }
                        }
                    }
                }
                
                var numberOfLocalPeers = 0
                for renderedPeer in foundLocalPeers.peers {
                    if case .expand = localExpandType, numberOfLocalPeers >= 3 {
                        break
                    }
                    if foundLocalPeers.recentlySearchedPeerIds.contains(renderedPeer.peerId) {
                        continue
                    }
                    
                    if let peer = renderedPeer.peers[renderedPeer.peerId], peer.id != context.account.peerId, filteredPeer(peer, EnginePeer(accountPeer)) {
                        if !existingPeerIds.contains(peer.id) {
                            existingPeerIds.insert(peer.id)
                            var associatedPeer: EnginePeer?
                            if case let .secretChat(secretChat) = peer, let associatedPeerId = secretChat.associatedPeerId {
                                associatedPeer = renderedPeer.peers[associatedPeerId]
                            } else if case let .channel(channel) = peer, channel.isMonoForum {
                                associatedPeer = renderedPeer.chatOrMonoforumMainPeer
                            }
                            
                            entries.append(.localPeer(peer, associatedPeer, foundLocalPeers.unread[peer.id], index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder, localExpandType, nil, false, false))
                            index += 1
                            numberOfLocalPeers += 1
                        }
                    }
                }
                                
                for peer in foundRemotePeers.0 {
                    if case .expand = localExpandType, numberOfLocalPeers >= 3 {
                        break
                    }
                    
                    if !existingPeerIds.contains(peer.peer.id), filteredPeer(EnginePeer(peer.peer), EnginePeer(accountPeer)) {
                        existingPeerIds.insert(peer.peer.id)
                        entries.append(.localPeer(EnginePeer(peer.peer), nil, nil, index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder, localExpandType, nil, false, false))
                        index += 1
                        numberOfLocalPeers += 1
                    }
                }

                var numberOfGlobalPeers = 0
                index = 0
                if !adsHidden {
                    for peer in foundRemotePeers.2 {
                        if !existingPeerIds.contains(peer.peer.id) {
                            existingPeerIds.insert(peer.peer.id)
                            entries.append(.adPeer(peer, index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder, globalExpandType, finalQuery))
                            index += 1
                        }
                    }
                }
                
                if let _ = tagMask {
                } else {
                    for peer in foundRemotePeers.1 {
                        if case .expand = globalExpandType, numberOfGlobalPeers >= 3 {
                            break
                        }
                        
                        if !existingPeerIds.contains(peer.peer.id), filteredPeer(EnginePeer(peer.peer), EnginePeer(accountPeer)) {
                            existingPeerIds.insert(peer.peer.id)
                            
                            entries.append(.globalPeer(peer, nil, index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder, globalExpandType, nil, false, finalQuery))
                            index += 1
                            numberOfGlobalPeers += 1
                        }
                    }
                }
                
                if let message = resolvedMessage {
                    var peer = EngineRenderedPeer(message: message)
                    if let group = message.peers[message.id.peerId] as? TelegramGroup, let migrationReference = group.migrationReference {
                        if let channelPeer = message.peers[migrationReference.peerId] {
                            peer = EngineRenderedPeer(peer: EnginePeer(channelPeer))
                        }
                    }
                    //TODO:requiresPremiumForMessaging
                    entries.append(.message(message, peer, nil, nil, presentationData, 1, nil, true, .index(message.index), nil, .generic, false, nil, false, .everywhere))
                    index += 1
                }
                
                var firstHeaderId: Int64?
                if !foundRemotePeers.3 {
                    index = 0
                    var existingPostIds = Set<MessageId>()
                    for foundPublicMessageSet in foundPublicMessages.0 {
                        for message in foundPublicMessageSet.messages {
                            if existingPostIds.contains(message.id) {
                                continue
                            }
                            existingPostIds.insert(message.id)
                        
                            let headerId = listMessageDateHeaderId(timestamp: message.timestamp)
                            if firstHeaderId == nil {
                                firstHeaderId = headerId
                            }
                            let peer = EngineRenderedPeer(message: message)
                            entries.append(.message(message, peer, foundPublicMessageSet.readCounters[message.id.peerId], foundPublicMessageSet.threadsData[message.id]?.info, presentationData, foundPublicMessageSet.totalCount, nil, headerId == firstHeaderId, .index(message.index), nil, .publicPosts, false, nil, false, .everywhere))
                            index += 1
                        }
                    }
                    
                    let hadAnySearchMessagesBefore = hadAnySearchMessages.with { $0 }
                    var existingMessageIds = Set<MessageId>()
                    if foundRemoteMessages.1 && (searchScope != .everywhere || hadAnySearchMessagesBefore) {
                        for i in 0 ..< 6 {
                            entries.append(.messagePlaceholder(Int32(i), presentationData, searchScope))
                            index += 1
                        }
                    } else {
                        var hasAnyMessages = false
                        for foundRemoteMessageSet in foundRemoteMessages.0 {
                            for message in foundRemoteMessageSet.messages {
                                if existingMessageIds.contains(message.id) {
                                    continue
                                }
                                existingMessageIds.insert(message.id)
                                
                                if searchState.deletedMessageIds.contains(message.id) {
                                    continue
                                } else if message.id.namespace == Namespaces.Message.Cloud && searchState.deletedGlobalMessageIds.contains(message.id.id) {
                                    continue
                                }
                                let headerId = listMessageDateHeaderId(timestamp: message.timestamp)
                                if firstHeaderId == nil {
                                    firstHeaderId = headerId
                                }
                                var peer = EngineRenderedPeer(message: message)
                                if let group = message.peers[message.id.peerId] as? TelegramGroup, let migrationReference = group.migrationReference {
                                    if let channelPeer = message.peers[migrationReference.peerId] {
                                        peer = EngineRenderedPeer(peer: EnginePeer(channelPeer))
                                    }
                                }
                                
                                //TODO:requiresPremiumForMessaging
                                hasAnyMessages = true
                                entries.append(.message(message, peer, foundRemoteMessageSet.readCounters[message.id.peerId], foundRemoteMessageSet.threadsData[message.id]?.info, presentationData, foundRemoteMessageSet.totalCount, selectionState?.contains(message.id), headerId == firstHeaderId, .index(message.index), nil, .generic, false, nil, false, searchScope))
                                index += 1
                            }
                        }
                        
                        if hasAnyMessages {
                            let _ = hadAnySearchMessages.swap(true)
                        } else {
                            switch searchScope {
                            case .everywhere:
                                break
                            default:
                                if let data = context.currentAppConfiguration.with({ $0 }).data, data["ios_killswitch_empty_search_footer"] != nil {
                                } else {
                                    entries.append(.emptyMessagesFooter(presentationData, searchScope, query))
                                }
                            }
                        }
                    }
                }
                
                if case .chats = key, !peersFilter.contains(.excludeRecent), isViablePhoneNumber(finalQuery) {
                    entries.append(.addContact(finalQuery, presentationData.theme, presentationData.strings))
                }
                
                return (entries, isSearching)
            }
        }
        
        let foundMessages = searchContexts.get() |> map { searchContexts -> ([EngineMessage], Int32, Bool) in
            let searchContext = searchContexts[0]
            if let result = searchContext?.result {
                return (result.messages, result.totalCount, result.hasMore)
            } else {
                return ([], 0, false)
            }
        }
        
        let loadMore = {
            updateSearchContexts { previousMap in
                var updatedMap = previousMap
                var isSearching = false
                for i in 0 ..< 2 {
                    if let previous = updatedMap[i] {
                        if previous.loadMoreIndex != nil {
                            continue
                        }
                        guard let last = previous.result.messages.last else {
                            continue
                        }
                        updatedMap[i] = ChatListSearchMessagesContext(result: previous.result, loadMoreIndex: last.index)
                        isSearching = true
                        
                        if previous.result.hasMore {
                            break
                        }
                    }
                }
                return (updatedMap, isSearching)
            }
        }
        
        openMediaMessageImpl = { message, mode in
            let _ = context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, chatLocation: nil, chatFilterTag: nil, chatLocationContextHolder: nil, message: message._asMessage(), standalone: false, reverseMessageGalleryOrder: true, mode: mode, navigationController: navigationController, dismissInput: {
                interaction.dismissInput()
            }, present: { c, a, _ in
                interaction.present(c, a)
            }, transitionNode: { messageId, media, _ in
                return transitionNodeImpl?(messageId, EngineMedia(media))
            }, addToTransitionSurface: { view in
                addToTransitionSurfaceImpl?(view)
            }, openUrl: { url in
                interaction.openUrl(url)
            }, openPeer: { _, _ in
            }, callPeer: { _, _ in
            }, openConferenceCall: { _ in
            }, enqueueMessage: { _ in
            }, sendSticker: nil, sendEmoji: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in }, gallerySource: .custom(messages: foundMessages |> map { message, a, b in
                return (message.map { $0._asMessage() }, a, b)
            }, messageId: message.id, loadMore: {
                loadMore()
            })))
        }
        
        transitionNodeImpl = { [weak self] messageId, media in
            if let self {
                return self.mediaNode?.transitionNodeForGallery(messageId: messageId, media: media._asMedia())
            } else {
                return nil
            }
        }
        
        addToTransitionSurfaceImpl = { [weak self] view in
            if let self {
                self.mediaNode?.addToTransitionSurface(view: view)
            }
        }
        
        let chatListInteraction = ChatListNodeInteraction(context: context, animationCache: self.animationCache, animationRenderer: self.animationRenderer, activateSearch: {
        }, peerSelected: { [weak self] peer, chatPeer, threadId, _, openApp in
            interaction.dismissInput()
            if openApp, let self {
                if case let .user(user) = peer, let botInfo = user.botInfo, botInfo.flags.contains(.hasWebApp), let parentController = self.parentController {
                    context.sharedContext.openWebApp(
                        context: context,
                        parentController: parentController,
                        updatedPresentationData: nil,
                        botPeer: peer,
                        chatPeer: nil,
                        threadId: nil,
                        buttonText: "",
                        url: "",
                        simple: true,
                        source: .generic,
                        skipTermsOfService: true,
                        payload: nil
                    )
                    interaction.dismissSearch()
                }
            } else {
                interaction.openPeer(peer, chatPeer, threadId, false)
            }
            switch location {
            case .chatList, .forum:
                let _ = context.engine.peers.addRecentlySearchedPeer(peerId: peer.id).startStandalone()
            case .savedMessagesChats:
                break
            }
            self?.listNode?.clearHighlightAnimated(true)
        }, disabledPeerSelected: { _, _, _ in
        }, togglePeerSelected: { _, _ in
        }, togglePeersSelection: { _, _ in
        }, additionalCategorySelected: { _ in
        }, messageSelected: { [weak self] peer, threadId, message, _ in
            interaction.dismissInput()
            if let strongSelf = self, let peer = message.peers[message.id.peerId] {
                interaction.openMessage(EnginePeer(peer), threadId, message.id, strongSelf.key == .chats)
            }
            self?.listNode?.clearHighlightAnimated(true)
        }, groupSelected: { _ in
        }, addContact: { [weak self] phoneNumber in
            interaction.dismissInput()
            interaction.addContact(phoneNumber)
            self?.listNode?.clearHighlightAnimated(true)
        }, setPeerIdWithRevealedOptions: { _, _ in
        }, setItemPinned: { _, _ in
        }, setPeerMuted: { _, _ in
        }, setPeerThreadMuted: { _, _, _ in
        }, deletePeer: { _, _ in
        }, deletePeerThread: { _, _ in
        }, setPeerThreadStopped: { _, _, _ in
        }, setPeerThreadPinned: { _, _, _ in
        }, setPeerThreadHidden: { _, _, _ in
        }, updatePeerGrouping: { _, _ in
        }, togglePeerMarkedUnread: { _, _ in
        }, toggleArchivedFolderHiddenByDefault: {
        }, toggleThreadsSelection: { _, _ in
        }, hidePsa: { _ in
        }, activateChatPreview: { item, _, node, gesture, location in
            guard let peerContextAction = interaction.peerContextAction else {
                gesture?.cancel()
                return
            }
            switch item.content {
            case .loading:
                break
            case let .peer(peerData):
                if let peer = peerData.peer.peer, let message = peerData.messages.first {
                    peerContextAction(peer, .search(message.id), node, gesture, location)
                }
            case .groupReference:
                gesture?.cancel()
            }
        }, present: { c in
            interaction.present(c, nil)
        }, openForumThread: { [weak self] peerId, threadId in
            guard let self else {
                return
            }
            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
                guard let self, let peer else {
                    return
                }
                interaction.dismissInput()
                interaction.openPeer(peer, peer, threadId, false)
                self.listNode?.clearHighlightAnimated(true)
            })
        }, openStorageManagement: {
        }, openPasswordSetup: {
        }, openPremiumIntro: {
        }, openPremiumGift: { _, _ in
        }, openPremiumManagement: {
        }, openActiveSessions: {
        }, openBirthdaySetup: {
        }, performActiveSessionAction: { _, _ in
        }, openChatFolderUpdates: {
        }, hideChatFolderUpdates: {
        }, openStories: { [weak self] subject, sourceNode in
            guard let self else {
                return
            }
            guard case let .peer(id) = subject else {
                return
            }
            if let sourceNode = sourceNode as? ChatListItemNode {
                self.interaction.openStories?(id, sourceNode.avatarNode)
            }
        }, openStarsTopup: { _ in
        }, dismissNotice: { _ in
        }, editPeer: { _ in
        }, openWebApp: { _ in
        }, openPhotoSetup: {
        }, openAdInfo: { node, adPeer in
            interaction.openAdInfo(node, adPeer)
        }, openAccountFreezeInfo: {
        }, openUrl: { _ in
        })
        chatListInteraction.isSearchMode = true
        
        let listInteraction = ListMessageItemInteraction(openMessage: { [weak self] message, mode -> Bool in
            guard let strongSelf = self else {
                return false
            }
            interaction.dismissInput()
            
            let gallerySource: GalleryControllerItemSource
            
            if strongSelf.key == .downloads {
                gallerySource = .peerMessagesAtId(messageId: message.id, chatLocation: .peer(id: message.id.peerId), customTag: nil, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil))
            } else {
                gallerySource = .custom(messages: foundMessages |> map { message, a, b in
                    return (message.map { $0._asMessage() }, a, b)
                }, messageId: message.id, loadMore: {
                    loadMore()
                })
            }
            
            let playlistLocation: PeerMessagesPlaylistLocation?
            if strongSelf.key == .downloads {
                playlistLocation = nil
            } else {
                playlistLocation = .custom(messages: foundMessages |> map { message, a, b in
                    return (message.map { $0._asMessage() }, a, b)
                }, at: message.id, loadMore: {
                    loadMore()
                })
            }
            
            return context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, chatLocation: .peer(id: message.id.peerId), chatFilterTag: nil, chatLocationContextHolder: nil, message: message, standalone: false, reverseMessageGalleryOrder: true, mode: mode, navigationController: navigationController, dismissInput: {
                interaction.dismissInput()
            }, present: { c, a, _ in
                interaction.present(c, a)
            }, transitionNode: { messageId, media, _ in
                var transitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
                if let strongSelf = self {
                    strongSelf.listNode?.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? ListMessageNode {
                            if let result = itemNode.transitionNode(id: messageId, media: media, adjustRect: false) {
                                transitionNode = result
                            }
                        }
                    }
                }
                return transitionNode
            }, addToTransitionSurface: { view in
                self?.addToTransitionSurface(view: view)
            }, openUrl: { url in
                interaction.openUrl(url)
            }, openPeer: { peer, navigation in
            }, callPeer: { _, _ in
            }, openConferenceCall: { _ in
            }, enqueueMessage: { _ in
            }, sendSticker: nil, sendEmoji: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in }, playlistLocation: playlistLocation, gallerySource: gallerySource))
        }, openMessageContextMenu: { [weak self] message, _, node, rect, gesture in
            guard let strongSelf = self, let currentEntries = strongSelf.currentEntries else {
                return
            }
            
            var fetchResourceId: (id: String, size: Int64, isFirstInList: Bool)?
            for entry in currentEntries {
                switch entry {
                case let .message(m, _, _, _, _, _, _, _, _, resource, _, _, _, _, _):
                    if m.id == message.id {
                        fetchResourceId = resource
                    }
                default:
                    break
                }
            }
            
            interaction.messageContextAction(EngineMessage(message), node, rect, gesture, key, fetchResourceId)
        }, toggleMessagesSelection: { messageId, selected in
            if let messageId = messageId.first {
                interaction.toggleMessageSelection(messageId, selected)
            }
        }, openUrl: { url, _, _, message in
            interaction.openUrl(url)
        }, openInstantPage: { [weak self] message, data in
            if let self, let navigationController = self.navigationController {
                if let controller = self.context.sharedContext.makeInstantPageController(context: self.context, message: message, sourcePeerType: .channel) {
                    navigationController.pushViewController(controller)
                }
            }
        }, longTap: { action, message in
        }, getHiddenMedia: {
            return [:]
        })
        
        listInteraction.preferredStoryHighQuality = context.sharedContext.currentAutomaticMediaDownloadSettings.highQualityStories
        
        let previousSearchItems = Atomic<[ChatListSearchEntry]?>(value: nil)
        let previousSelectedMessages = Atomic<Set<EngineMessage.Id>?>(value: nil)
        let previousExpandGlobalSearch = Atomic<Bool>(value: false)
        let previousAdsHidden = Atomic<Bool>(value: false)
        
        self.searchQueryDisposable = (searchQuery
        |> deliverOnMainQueue).startStrict(next: { [weak self, weak listInteraction, weak chatListInteraction] query in
            self?.searchQueryValue = query
            listInteraction?.searchTextHighightState = query
            chatListInteraction?.searchTextHighightState = query
        })
        
        self.searchOptionsDisposable = (searchOptions
        |> deliverOnMainQueue).startStrict(next: { [weak self] options in
            self?.searchOptionsValue = options
        })

        
        self.searchDisposable.set((foundItems |> mapToSignal { items -> Signal<([ChatListSearchEntry], Bool)?, NoError> in
            guard let (items, isSearching) = items else {
                return .single(nil)
            }
            var storyStatsIds: [EnginePeer.Id] = []
            var requiresPremiumForMessagingPeerIds: [EnginePeer.Id] = []
            for item in items {
                switch item {
                case let .recentlySearchedPeer(peer, _, _, _, _, _, _, _, _, _):
                    storyStatsIds.append(peer.id)
                    if case let .user(user) = peer, user.flags.contains(.requirePremium) {
                        requiresPremiumForMessagingPeerIds.append(peer.id)
                    }
                case let .localPeer(peer, _, _, _, _, _, _, _, _, _, _, _):
                    storyStatsIds.append(peer.id)
                    if case let .user(user) = peer, user.flags.contains(.requirePremium) {
                        requiresPremiumForMessagingPeerIds.append(peer.id)
                    }
                case let .globalPeer(foundPeer, _, _, _, _, _, _, _, _, _, _):
                    storyStatsIds.append(foundPeer.peer.id)
                    if let user = foundPeer.peer as? TelegramUser, user.flags.contains(.requirePremium) {
                        requiresPremiumForMessagingPeerIds.append(foundPeer.peer.id)
                    }
                case let .message(_, peer, _, _, _, _, _, _, _, _, _, _, _, _, _):
                    if let peer = peer.peer {
                        storyStatsIds.append(peer.id)
                        if case let .user(user) = peer, user.flags.contains(.requirePremium) {
                            requiresPremiumForMessagingPeerIds.append(peer.id)
                        }
                    }
                default:
                    break
                }
            }
            storyStatsIds.removeAll(where: { $0 == context.account.peerId })
            
            return context.engine.data.subscribe(
                EngineDataMap(
                    storyStatsIds.map(TelegramEngine.EngineData.Item.Peer.StoryStats.init(id:))
                ),
                EngineDataMap(
                    requiresPremiumForMessagingPeerIds.map(TelegramEngine.EngineData.Item.Peer.IsPremiumRequiredForMessaging.init(id:))
                )
            )
            |> map { stats, requiresPremiumForMessaging -> ([ChatListSearchEntry], Bool)? in
                var requiresPremiumForMessaging = requiresPremiumForMessaging
                if !peersFilter.contains(.onlyWriteable) {
                    requiresPremiumForMessaging = [:]
                } else {
                    context.account.viewTracker.refreshCanSendMessagesForPeerIds(peerIds: requiresPremiumForMessagingPeerIds)
                }
                
                var mappedItems = items
                for i in 0 ..< mappedItems.count {
                    switch mappedItems[i] {
                    case let .recentlySearchedPeer(peer, associatedPeer, unreadBadge, index, theme, strings, sortOrder, displayOrder, _, _):
                        mappedItems[i] = .recentlySearchedPeer(peer, associatedPeer, unreadBadge, index, theme, strings, sortOrder, displayOrder, stats[peer.id] ?? nil, requiresPremiumForMessaging[peer.id] ?? false)
                    case let .localPeer(peer, associatedPeer, unreadBadge, index, theme, strings, sortOrder, displayOrder, expandType, _, _, isSelf):
                        mappedItems[i] = .localPeer(peer, associatedPeer, unreadBadge, index, theme, strings, sortOrder, displayOrder, expandType, stats[peer.id] ?? nil, requiresPremiumForMessaging[peer.id] ?? false, isSelf)
                    case let .globalPeer(peer, unreadBadge, index, theme, strings, sortOrder, displayOrder, expandType, _, _, searchQuery):
                        mappedItems[i] = .globalPeer(peer, unreadBadge, index, theme, strings, sortOrder, displayOrder, expandType, stats[peer.peer.id] ?? nil, requiresPremiumForMessaging[peer.peer.id] ?? false, searchQuery)
                    case let .message(message, peer, combinedPeerReadState, threadInfo, presentationData, totalCount, selected, displayCustomHeader, key, resourceId, section, allPaused, _, _, searchScope):
                        mappedItems[i] = .message(message, peer, combinedPeerReadState, threadInfo, presentationData, totalCount, selected, displayCustomHeader, key, resourceId, section, allPaused, stats[peer.peerId] ?? nil, requiresPremiumForMessaging[peer.peerId] ?? false, searchScope)
                    default:
                        break
                    }
                }
                return (mappedItems, isSearching)
            }
        }
        |> deliverOnMainQueue).startStrict(next: { [weak self] foundItems in
            if let strongSelf = self {
                let previousSelectedMessageIds = previousSelectedMessages.swap(strongSelf.selectedMessages)
                let previousExpandGlobalSearch = previousExpandGlobalSearch.swap(strongSelf.searchStateValue.expandGlobalSearch)
                let previousAdsHidden = previousAdsHidden.swap(strongSelf.adsHidden)
                
                var entriesAndFlags = foundItems?.0
                
                let isSearching = foundItems?.1 ?? false
                strongSelf._isSearching.set(isSearching)
                
                if strongSelf.tagMask == .photoOrVideo {
                    var entries: [ChatListSearchEntry]? = entriesAndFlags ?? []
                    if isSearching && (entries?.isEmpty ?? true) {
                        entries = nil
                    }
                    strongSelf.mediaNode?.updateHistory(entries: entries, totalCount: 0, updateType: .Initial)
                } else if strongSelf.tagMask == .roundVideo {
                    
                }
                
                var peers: [EnginePeer] = []
                if let entries = entriesAndFlags {
                    var filteredEntries: [ChatListSearchEntry] = []
                    for entry in entries {
                        if case let .localPeer(peer, _, _, _, _, _, _, _, _, _, _, _) = entry {
                            peers.append(peer)
                        } else if case .globalPeer = entry {    
                        } else {
                            filteredEntries.append(entry)
                        }
                    }
                    
                    if strongSelf.tagMask != nil || strongSelf.searchOptionsValue?.date != nil || strongSelf.searchOptionsValue?.peer != nil {
                        entriesAndFlags = filteredEntries
                    }
                }
                
                let previousEntries = previousSearchItems.swap(entriesAndFlags)
                let newEntries = entriesAndFlags ?? []
                
                let selectionChanged = (previousSelectedMessageIds == nil) != (strongSelf.selectedMessages == nil)
                let expandGlobalSearchChanged = previousExpandGlobalSearch != strongSelf.searchStateValue.expandGlobalSearch
                let adsHiddenChanged = previousAdsHidden != strongSelf.adsHidden
                
                let animated = selectionChanged || expandGlobalSearchChanged || adsHiddenChanged
                let firstTime = previousEntries == nil
                var transition = chatListSearchContainerPreparedTransition(from: previousEntries ?? [], to: newEntries, displayingResults: entriesAndFlags != nil, isEmpty: !isSearching && (entriesAndFlags?.isEmpty ?? false), isLoading: isSearching, animated: animated, context: context, presentationData: strongSelf.presentationData, enableHeaders: true, filter: peersFilter, requestPeerType: requestPeerType, location: location, key: strongSelf.key, tagMask: tagMask, interaction: chatListInteraction, listInteraction: listInteraction, peerContextAction: { message, node, rect, gesture, location in
                    interaction.peerContextAction?(message, node, rect, gesture, location)
                }, toggleExpandLocalResults: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateState { state in
                        var state = state
                        state.expandLocalSearch = !state.expandLocalSearch
                        return state
                    }
                }, toggleExpandGlobalResults: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateState { state in
                        var state = state
                        state.expandGlobalSearch = !state.expandGlobalSearch
                        return state
                    }
                }, searchPeer: { peer in
                }, searchQuery: strongSelf.searchQueryValue, searchOptions: strongSelf.searchOptionsValue, messageContextAction: { message, node, rect, gesture, paneKey, downloadResource in
                    interaction.messageContextAction(message, node, rect, gesture, paneKey, downloadResource)
                }, openClearRecentlyDownloaded: {
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                    var items: [ActionSheetItem] = []
                    
                    items.append(ActionSheetAnimationAndTextItem(title: strongSelf.presentationData.strings.DownloadList_ClearAlertTitle, text: strongSelf.presentationData.strings.DownloadList_ClearAlertText))
                    
                    items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.DownloadList_OptionManageDeviceStorage, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        guard let strongSelf = self else {
                            return
                        }
                        
                        strongSelf.context.sharedContext.openStorageUsage(context: strongSelf.context)
                    }))
                    
                    items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.DownloadList_ClearDownloadList, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        guard let strongSelf = self else {
                            return
                        }
                        
                        let _ = clearRecentDownloadList(postbox: strongSelf.context.account.postbox).startStandalone()
                    }))
                    
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    strongSelf.interaction.dismissInput()
                    strongSelf.interaction.present(actionSheet, nil)
                }, toggleAllPaused: {
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let _ = ((strongSelf.context.fetchManager as! FetchManagerImpl).entriesSummary
                    |> take(1)
                    |> deliverOnMainQueue).startStandalone(next: { entries in
                        guard let strongSelf = self, !entries.isEmpty else {
                            return
                        }
                        var allPaused = true
                        for entry in entries {
                            if !entry.isPaused {
                                allPaused = false
                                break
                            }
                        }
                        
                        for entry in entries {
                            strongSelf.context.fetchManager.toggleInteractiveFetchPaused(resourceId: entry.resourceReference.resource.id.stringRepresentation, isPaused: !allPaused)
                        }
                    })
                }, openStories: { peerId, avatarNode in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.interaction.openStories?(peerId, avatarNode)
                }, openPublicPosts: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.interaction.switchToFilter(.publicPosts)
                }, openMessagesFilter: { sourceNode in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.openMessagesFilter(sourceNode: sourceNode)
                }, switchMessagesFilter: { filter in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.searchScopePromise.set(.everywhere)
                })
                strongSelf.currentEntries = newEntries
                if strongSelf.key == .downloads {
                    if !firstTime, !"".isEmpty {
                        transition.animated = true
                    }
                }
                strongSelf.enqueueTransition(transition, firstTime: firstTime)
                
                var messages: [EngineMessage] = []
                for entry in newEntries {
                    if case let .message(message, _, _, _, _, _, _, _, _, _, _, _, _, _, _) = entry {
                        messages.append(message)
                    }
                }
                strongSelf.searchCurrentMessages = messages
            }
        }))
        
        let previousRecentItemsValue = Atomic<RecentItems?>(value: nil)
        let hasRecentPeers: Signal<Bool, NoError>
        if case .channels = key {
            hasRecentPeers = .single(false)
        } else if case .apps = key {
            hasRecentPeers = .single(false)
        } else {
            hasRecentPeers = context.engine.peers.recentPeers()
            |> map { value -> Bool in
                switch value {
                case let .peers(peers):
                    return !peers.isEmpty
                case .disabled:
                    return false
                }
            }
            |> distinctUntilChanged
        }
        
        struct RecentItems {
            var entries: [ChatListRecentEntry]
            var isChannelsTabExpanded: Bool?
            var recommendedChannelOrder: [EnginePeer.Id]
            var isEmpty: Bool
        }
        
        let isChannelsTabExpandedValue = ValuePromise<Bool>(false, ignoreRepeated: true)
        let toggleChannelsTabExpanded: () -> Void = {
            let _ = (isChannelsTabExpandedValue.get() |> take(1)).startStandalone(next: { value in
                isChannelsTabExpandedValue.set(!value)
                
                Queue.mainQueue().async {
                    interaction.dismissInput()
                }
            })
        }
        
        var recentItems: Signal<RecentItems, NoError> = combineLatest(
            hasRecentPeers,
            fixedRecentlySearchedPeers |> mapToSignal { peers -> Signal<([RecentlySearchedPeer], [EnginePeer.Id: PeerStoryStats], [EnginePeer.Id: Bool], Set<EnginePeer.Id>), NoError> in
                return context.engine.data.subscribe(
                    EngineDataMap(peers.map(\.peer.peerId).map { id in
                        return TelegramEngine.EngineData.Item.Peer.StoryStats(id: id)
                    }),
                    EngineDataMap(peers.map(\.peer.peerId).map { id in
                        return TelegramEngine.EngineData.Item.Peer.IsPremiumRequiredForMessaging(id: id)
                    })
                )
                |> map { stats, isPremiumRequiredForMessaging -> ([RecentlySearchedPeer], [EnginePeer.Id: PeerStoryStats], [EnginePeer.Id: Bool], Set<EnginePeer.Id>) in
                    var isPremiumRequiredForMessaging = isPremiumRequiredForMessaging
                    var refreshIsPremiumRequiredForMessaging = Set<EnginePeer.Id>()
                    if !peersFilter.contains(.onlyWriteable) {
                        isPremiumRequiredForMessaging = [:]
                    } else {
                        for peer in peers {
                            if let user = peer.peer.peer as? TelegramUser, user.flags.contains(.requirePremium) {
                                refreshIsPremiumRequiredForMessaging.insert(user.id)
                            }
                        }
                    }
                    
                    var mappedStats: [EnginePeer.Id: PeerStoryStats] = [:]
                    for (id, value) in stats {
                        if id == context.account.peerId {
                            continue
                        }
                        if let value {
                            mappedStats[id] = value
                        }
                    }
                    var mappedIsPremiumRequiredForMessaging: [EnginePeer.Id: Bool] = [:]
                    for (id, value) in isPremiumRequiredForMessaging {
                        mappedIsPremiumRequiredForMessaging[id] = value
                    }
                    return (peers, mappedStats, mappedIsPremiumRequiredForMessaging, refreshIsPremiumRequiredForMessaging)
                }
            },
            presentationDataPromise.get(),
            context.engine.data.subscribe(TelegramEngine.EngineData.Item.NotificationSettings.Global())
        )
        |> mapToSignal { hasRecentPeers, peersAndStories, presentationData, globalNotificationSettings -> Signal<RecentItems, NoError> in
            let (peers, peerStoryStats, requiresPremiumForMessaging, refreshIsPremiumRequiredForMessaging) = peersAndStories
            
            if !refreshIsPremiumRequiredForMessaging.isEmpty {
                context.account.viewTracker.refreshCanSendMessagesForPeerIds(peerIds: Array(refreshIsPremiumRequiredForMessaging))
            }
            
            var entries: [ChatListRecentEntry] = []
            if !peersFilter.contains(.onlyGroups) {
                if hasRecentPeers {
                    entries.append(.topPeers([], presentationData.theme, presentationData.strings))
                }
            }
            var peerIds = Set<EnginePeer.Id>()
            var index = 0
            loop: for searchedPeer in peers {
                if let peer = searchedPeer.peer.peers[searchedPeer.peer.peerId] {
                    if peerIds.contains(peer.id) {
                        continue loop
                    }
                    if !doesPeerMatchFilter(peer: EnginePeer(peer), filter: peersFilter) {
                        continue
                    }
                    peerIds.insert(peer.id)
                    
                    entries.append(.peer(index: index, peer: searchedPeer, .local, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameSortOrder, presentationData.nameDisplayOrder, globalNotificationSettings, peerStoryStats[peer.id], requiresPremiumForMessaging[peer.id] ?? false))
                    index += 1
                }
            }
           
            return .single(RecentItems(entries: entries, isChannelsTabExpanded: nil, recommendedChannelOrder: [], isEmpty: false))
        }
        
        if peersFilter.contains(.excludeRecent) {
            recentItems = .single(RecentItems(entries: [], isChannelsTabExpanded: nil, recommendedChannelOrder: [], isEmpty: false))
        }
        if case .savedMessagesChats = location {
            recentItems = .single(RecentItems(entries: [], isChannelsTabExpanded: nil, recommendedChannelOrder: [], isEmpty: false))
        }
        if case .channels = key {
            struct LocalChannels {
                var peerIds: [EnginePeer.Id]
                var isExpanded: Bool?
            }
            let localChannels = isChannelsTabExpandedValue.get()
            |> mapToSignal { isChannelsTabExpanded -> Signal<LocalChannels, NoError> in
                return context.engine.messages.getAllLocalChannels(count: isChannelsTabExpanded ? 500 : 5)
                |> map { peerIds -> LocalChannels in
                    return LocalChannels(peerIds: peerIds, isExpanded: isChannelsTabExpanded)
                }
            }
            
            let remoteChannels: Signal<RecommendedChannels?, NoError> = context.engine.peers.recommendedChannels(peerId: nil)
            
            let _ = self.context.engine.peers.requestGlobalRecommendedChannelsIfNeeded().startStandalone()
            
            recentItems = combineLatest(
                localChannels,
                remoteChannels
            )
            |> mapToSignal { localChannels, remoteChannels -> Signal<RecentItems, NoError> in
                var allChannelIds = localChannels.peerIds
                let isChannelsTabExpanded = localChannels.isExpanded
                
                var cachedSubscribers: [EnginePeer.Id: Int32] = [:]
                var recommendedChannelOrder: [EnginePeer.Id] = []
                if let remoteChannels {
                    for channel in remoteChannels.channels {
                        if !allChannelIds.contains(channel.peer.id) {
                            allChannelIds.append(channel.peer.id)
                        }
                        cachedSubscribers[channel.peer.id] = channel.subscribers
                        recommendedChannelOrder.append(channel.peer.id)
                    }
                }
                
                return context.engine.data.subscribe(
                    EngineDataMap(
                        allChannelIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                            return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                        }
                    ),
                    EngineDataMap(
                        allChannelIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.NotificationSettings in
                            return TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peerId)
                        }
                    ),
                    EngineDataMap(
                        allChannelIds.map { peerId -> TelegramEngine.EngineData.Item.Messages.PeerUnreadCount in
                            return TelegramEngine.EngineData.Item.Messages.PeerUnreadCount(id: peerId)
                        }
                    ),
                    EngineDataMap(
                        allChannelIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.StoryStats in
                            return TelegramEngine.EngineData.Item.Peer.StoryStats(id: peerId)
                        }
                    ),
                    EngineDataMap(
                        allChannelIds.map { peerId -> TelegramEngine.EngineData.Item.Messages.PeerReadCounters in
                            return TelegramEngine.EngineData.Item.Messages.PeerReadCounters(id: peerId)
                        }
                    ),
                    EngineDataMap(
                        allChannelIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.ParticipantCount in
                            return TelegramEngine.EngineData.Item.Peer.ParticipantCount(id: peerId)
                        }
                    ),
                    TelegramEngine.EngineData.Item.NotificationSettings.Global()
                )
                |> map { peers, notificationSettings, unreadCounts, storyStats, readCounters, participantCounts, globalNotificationSettings -> RecentItems in
                    /*#if DEBUG
                    var localChannels = localChannels
                    localChannels.peerIds = []
                    
                    var remoteChannels = remoteChannels
                    remoteChannels?.channels = []
                    #endif*/
                    
                    var result: [ChatListRecentEntry] = []
                    var existingIds = Set<PeerId>()
                    
                    for id in localChannels.peerIds {
                        if existingIds.contains(id) {
                            continue
                        }
                        existingIds.insert(id)
                        guard let peer = peers[id], let peer else {
                            continue
                        }
                        let peerNotificationSettings = notificationSettings[id]
                        var subpeerSummary: RecentlySearchedPeerSubpeerSummary?
                        if let count = participantCounts[id], let count {
                            subpeerSummary = RecentlySearchedPeerSubpeerSummary(count: Int(count))
                        } else if let count = cachedSubscribers[id] {
                            subpeerSummary = RecentlySearchedPeerSubpeerSummary(count: Int(count))
                        }
                        var peerStoryStats: PeerStoryStats?
                        if let value = storyStats[peer.id] {
                            peerStoryStats = value
                        }
                        var unreadCount: Int32 = 0
                        if let value = readCounters[peer.id] {
                            unreadCount = value.count
                        }
                        result.append(.peer(
                            index: result.count,
                            peer: RecentlySearchedPeer(
                                peer: RenderedPeer(peer: peer._asPeer()),
                                presence: nil,
                                notificationSettings: peerNotificationSettings.flatMap({ $0._asNotificationSettings() }),
                                unreadCount: unreadCount,
                                subpeerSummary: subpeerSummary
                            ),
                            .local,
                            presentationData.theme,
                            presentationData.strings,
                            presentationData.dateTimeFormat,
                            presentationData.nameSortOrder,
                            presentationData.nameDisplayOrder,
                            globalNotificationSettings,
                            peerStoryStats,
                            false
                        ))
                    }
                    if let remoteChannels {
                        for channel in remoteChannels.channels {
                            if existingIds.contains(channel.peer.id) {
                                continue
                            }
                            existingIds.insert(channel.peer.id)
                            guard let peer = peers[channel.peer.id], let peer else {
                                continue
                            }
                            let peerNotificationSettings = notificationSettings[channel.peer.id]
                            var subpeerSummary: RecentlySearchedPeerSubpeerSummary?
                            if let count = participantCounts[channel.peer.id], let count {
                                subpeerSummary = RecentlySearchedPeerSubpeerSummary(count: Int(count))
                            } else if let count = cachedSubscribers[channel.peer.id] {
                                subpeerSummary = RecentlySearchedPeerSubpeerSummary(count: Int(count))
                            }
                            var peerStoryStats: PeerStoryStats?
                            if let value = storyStats[peer.id] {
                                peerStoryStats = value
                            }
                            result.append(.peer(
                                index: result.count,
                                peer: RecentlySearchedPeer(
                                    peer: RenderedPeer(peer: peer._asPeer()),
                                    presence: nil,
                                    notificationSettings: peerNotificationSettings.flatMap({ $0._asNotificationSettings() }),
                                    unreadCount: 0,
                                    subpeerSummary: subpeerSummary
                                ),
                                .recommendedChannels,
                                presentationData.theme,
                                presentationData.strings,
                                presentationData.dateTimeFormat,
                                presentationData.nameSortOrder,
                                presentationData.nameDisplayOrder,
                                globalNotificationSettings,
                                peerStoryStats,
                                false
                            ))
                        }
                    }
                    
                    var isEmpty = false
                    if localChannels.peerIds.isEmpty, let remoteChannels, remoteChannels.channels.isEmpty {
                        isEmpty = true
                    }
                    
                    return RecentItems(entries: result, isChannelsTabExpanded: isChannelsTabExpanded, recommendedChannelOrder: recommendedChannelOrder, isEmpty: isEmpty)
                }
            }
        } else if case .apps = key {
            struct LocalApps {
                var peerIds: [EnginePeer.Id]
                var isExpanded: Bool?
            }
            let localApps = isChannelsTabExpandedValue.get()
            |> mapToSignal { isChannelsTabExpanded -> Signal<LocalApps, NoError> in
                return context.engine.peers.recentApps()
                |> map { peerIds -> LocalApps in
                    var isExpanded: Bool? = isChannelsTabExpanded
                    var peerIds = peerIds
                    if peerIds.count > 5 {
                        if !isChannelsTabExpanded {
                            peerIds = Array(peerIds.prefix(5))
                        }
                    } else {
                        isExpanded = nil
                    }
                    return LocalApps(peerIds: peerIds, isExpanded: isExpanded)
                }
            }
            
            let remoteApps: Signal<[EnginePeer.Id]?, NoError> = context.engine.peers.recommendedAppPeerIds()
            
            let _ = self.context.engine.peers.requestRecommendedAppsIfNeeded().startStandalone()
            
            recentItems = combineLatest(
                localApps,
                remoteApps
            )
            |> mapToSignal { localApps, remoteApps -> Signal<RecentItems, NoError> in
                var allAppIds = localApps.peerIds
                
                var recommendedAppOrder: [EnginePeer.Id] = []
                if let remoteApps {
                    for peerId in remoteApps {
                        if !allAppIds.contains(peerId) {
                            allAppIds.append(peerId)
                        }
                        recommendedAppOrder.append(peerId)
                    }
                }
                
                return context.engine.data.subscribe(
                    EngineDataMap(
                        allAppIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                            return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                        }
                    ),
                    EngineDataMap(
                        allAppIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.NotificationSettings in
                            return TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peerId)
                        }
                    ),
                    EngineDataMap(
                        allAppIds.map { peerId -> TelegramEngine.EngineData.Item.Messages.PeerUnreadCount in
                            return TelegramEngine.EngineData.Item.Messages.PeerUnreadCount(id: peerId)
                        }
                    ),
                    EngineDataMap(
                        allAppIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.StoryStats in
                            return TelegramEngine.EngineData.Item.Peer.StoryStats(id: peerId)
                        }
                    ),
                    EngineDataMap(
                        allAppIds.map { peerId -> TelegramEngine.EngineData.Item.Messages.PeerReadCounters in
                            return TelegramEngine.EngineData.Item.Messages.PeerReadCounters(id: peerId)
                        }
                    ),
                    TelegramEngine.EngineData.Item.NotificationSettings.Global()
                )
                |> map { peers, notificationSettings, unreadCounts, storyStats, readCounters, globalNotificationSettings -> RecentItems in
                    var result: [ChatListRecentEntry] = []
                    var existingIds = Set<PeerId>()
                    
                    for id in localApps.peerIds {
                        if existingIds.contains(id) {
                            continue
                        }
                        existingIds.insert(id)
                        guard let peer = peers[id], let peer else {
                            continue
                        }
                        let peerNotificationSettings = notificationSettings[id]
                        let subpeerSummary: RecentlySearchedPeerSubpeerSummary? = nil
                        var peerStoryStats: PeerStoryStats?
                        if let value = storyStats[peer.id] {
                            peerStoryStats = value
                        }
                        var unreadCount: Int32 = 0
                        if let value = readCounters[peer.id] {
                            unreadCount = value.count
                        }
                        result.append(.peer(
                            index: result.count,
                            peer: RecentlySearchedPeer(
                                peer: RenderedPeer(peer: peer._asPeer()),
                                presence: nil,
                                notificationSettings: peerNotificationSettings.flatMap({ $0._asNotificationSettings() }),
                                unreadCount: unreadCount,
                                subpeerSummary: subpeerSummary
                            ),
                            .local,
                            presentationData.theme,
                            presentationData.strings,
                            presentationData.dateTimeFormat,
                            presentationData.nameSortOrder,
                            presentationData.nameDisplayOrder,
                            globalNotificationSettings,
                            peerStoryStats,
                            false
                        ))
                    }
                    if let remoteApps {
                        for appPeerId in remoteApps {
                            if existingIds.contains(appPeerId) {
                                continue
                            }
                            existingIds.insert(appPeerId)
                            guard let peer = peers[appPeerId], let peer else {
                                continue
                            }
                            let peerNotificationSettings = notificationSettings[appPeerId]
                            let subpeerSummary: RecentlySearchedPeerSubpeerSummary? = nil
                            var peerStoryStats: PeerStoryStats?
                            if let value = storyStats[peer.id] {
                                peerStoryStats = value
                            }
                            result.append(.peer(
                                index: result.count,
                                peer: RecentlySearchedPeer(
                                    peer: RenderedPeer(peer: peer._asPeer()),
                                    presence: nil,
                                    notificationSettings: peerNotificationSettings.flatMap({ $0._asNotificationSettings() }),
                                    unreadCount: 0,
                                    subpeerSummary: subpeerSummary
                                ),
                                .popularApps,
                                presentationData.theme,
                                presentationData.strings,
                                presentationData.dateTimeFormat,
                                presentationData.nameSortOrder,
                                presentationData.nameDisplayOrder,
                                globalNotificationSettings,
                                peerStoryStats,
                                false
                            ))
                        }
                        
                        result.append(.footer(presentationData.theme, presentationData.strings.ChatList_Search_TopAppsInfo))
                    }
                    
                    var isEmpty = false
                    if localApps.peerIds.isEmpty, let remoteApps, remoteApps.isEmpty {
                        isEmpty = true
                    }
                    
                    return RecentItems(entries: result, isChannelsTabExpanded: localApps.isExpanded, recommendedChannelOrder: recommendedAppOrder, isEmpty: isEmpty)
                }
            }
        }
        
        if case .chats = key, !peersFilter.contains(.excludeRecent) {
            self.updatedRecentPeersDisposable.set(context.engine.peers.managedUpdatedRecentPeers().startStrict())
        }
        
        self.recentDisposable.set((combineLatest(queue: .mainQueue(),
            presentationDataPromise.get(),
            recentItems
        )
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData, recentItems in
            if let strongSelf = self {
                let previousRecentItems = previousRecentItemsValue.swap(recentItems)
                
                var firstTime = previousRecentItems == nil
                var forceUpdateAll = false
                if let previousRecentItems {
                    if previousRecentItems.entries.count < recentItems.entries.count {
                        firstTime = true
                    }
                    if previousRecentItems.recommendedChannelOrder != recentItems.recommendedChannelOrder {
                        firstTime = true
                    }
                    if previousRecentItems.isChannelsTabExpanded != recentItems.isChannelsTabExpanded {
                        firstTime = true
                        forceUpdateAll = true
                    }
                }
                
                let transition = chatListSearchContainerPreparedRecentTransition(from: previousRecentItems?.entries ?? [], to: recentItems.entries, forceUpdateAll: forceUpdateAll, context: context, presentationData: presentationData, filter: peersFilter, key: key, peerSelected: { peer, threadId, isRecommended, action in
                    guard let self else {
                        return
                    }
                    
                    if case .channels = key {
                        if let navigationController = self.navigationController {
                            var customChatNavigationStack: [EnginePeer.Id]?
                            if isRecommended {
                                if let recommendedChannelOrder = previousRecentItemsValue.with({ $0 })?.recommendedChannelOrder {
                                    var customChatNavigationStackValue: [EnginePeer.Id] = []
                                    customChatNavigationStackValue.append(contentsOf: recommendedChannelOrder)
                                    customChatNavigationStack = customChatNavigationStackValue
                                }
                            }
                            
                            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                                navigationController: navigationController,
                                context: self.context,
                                chatLocation: .peer(peer),
                                keepStack: .always,
                                customChatNavigationStack: customChatNavigationStack
                            ))
                        }
                    } else if case .apps = key {
                        if let navigationController = self.navigationController {
                            switch action {
                            case .generic:
                                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                                    navigationController: navigationController,
                                    context: self.context,
                                    chatLocation: .peer(peer),
                                    keepStack: .always
                                ))
                            case .info:
                                if let peerInfoScreen = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                                    navigationController.pushViewController(peerInfoScreen)
                                }
                            case .openApp:
                                if let parentController = self.parentController {
                                    self.context.sharedContext.openWebApp(
                                        context: self.context,
                                        parentController: parentController,
                                        updatedPresentationData: nil,
                                        botPeer: peer,
                                        chatPeer: nil,
                                        threadId: nil,
                                        buttonText: "",
                                        url: "",
                                        simple: true,
                                        source: .generic,
                                        skipTermsOfService: true,
                                        payload: nil
                                    )
                                }
                            }
                        }
                    } else {
                        if case .openApp = action, case let .user(user) = peer, let botInfo = user.botInfo, botInfo.flags.contains(.hasWebApp), let parentController = self.parentController {
                            self.context.sharedContext.openWebApp(
                                context: self.context,
                                parentController: parentController,
                                updatedPresentationData: nil,
                                botPeer: peer,
                                chatPeer: nil,
                                threadId: nil,
                                buttonText: "",
                                url: "",
                                simple: true,
                                source: .generic,
                                skipTermsOfService: true,
                                payload: nil
                            )
                            interaction.dismissSearch()
                        } else {
                            interaction.openPeer(peer, nil, threadId, true)
                        }
                        if threadId == nil {
                            switch location {
                            case .chatList, .forum:
                                let _ = context.engine.peers.addRecentlySearchedPeer(peerId: peer.id).startStandalone()
                            case .savedMessagesChats:
                                break
                            }
                        }
                    }
                    self.recentListNode.clearHighlightAnimated(true)
                }, disabledPeerSelected: { peer, threadId, reason in
                    interaction.openDisabledPeer(peer, threadId, reason)
                }, peerContextAction: { peer, source, node, gesture, location in
                    if let peerContextAction = interaction.peerContextAction {
                        peerContextAction(peer, source, node, gesture, location)
                    } else {
                        gesture?.cancel()
                    }
                }, clearRecentlySearchedPeers: {
                    interaction.clearRecentSearch()
                }, deletePeer: { peerId in
                    let _ = context.engine.peers.removeRecentlySearchedPeer(peerId: peerId).startStandalone()
                }, animationCache: strongSelf.animationCache, animationRenderer: strongSelf.animationRenderer, openStories: { peerId, avatarNode in
                    interaction.openStories?(peerId, avatarNode)
                }, openTopAppsInfo: {
                    var dismissImpl: (() -> Void)?
                    let alertController = textAlertController(
                        context: context,
                        title: presentationData.strings.TopApps_Info_Title,
                        text: presentationData.strings.TopApps_Info_Text,
                        actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.TopApps_Info_Done, action: {})],
                        parseMarkdown: true,
                        linkAction: { attributes, _ in
                            guard let self, let navigationController = self.navigationController else {
                                return
                            }
                            dismissImpl?()
                            if let value = attributes[NSAttributedString.Key(rawValue: "URL")] as? String {
                                if !value.isEmpty {
                                    context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: value, forceExternal: false, presentationData: context.sharedContext.currentPresentationData.with { $0 }, navigationController: navigationController, dismissInput: {})
                                } else {
                                    let _ = (context.engine.peers.resolvePeerByName(name: "botfather", referrer: nil)
                                    |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
                                        guard case let .result(result) = result else {
                                            return .complete()
                                        }
                                        return .single(result)
                                    }
                                    |> deliverOnMainQueue).start(next: { [weak navigationController] peer in
                                        guard let navigationController, let peer else {
                                            return
                                        }
                                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                                            navigationController: navigationController,
                                            context: context,
                                            chatLocation: .peer(peer),
                                            keepStack: .always
                                        ))
                                    })
                                }
                            }
                        }
                    )
                    interaction.present(alertController, nil)
                    dismissImpl = { [weak alertController] in
                        alertController?.dismissAnimated()
                    }
                },
                isChannelsTabExpanded: recentItems.isChannelsTabExpanded,
                toggleChannelsTabExpanded: {
                    toggleChannelsTabExpanded()
                }, isEmpty: recentItems.isEmpty)
                strongSelf.enqueueRecentTransition(transition, firstTime: firstTime)
            }
        }))
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
                strongSelf.presentationDataPromise.set(.single(ChatListPresentationData(theme: presentationData.theme, fontSize: presentationData.listsFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true)))
                if strongSelf.backgroundColor != nil {
                    strongSelf.backgroundColor = presentationData.theme.chatList.backgroundColor
                }
                strongSelf.listNode?.forEachItemHeaderNode({ itemHeaderNode in
                    if let itemHeaderNode = itemHeaderNode as? ChatListSearchItemHeaderNode {
                        itemHeaderNode.updateTheme(theme: presentationData.theme)
                    }
                })
                
                strongSelf.recentListNode.forEachItemHeaderNode({ itemHeaderNode in
                    if let itemHeaderNode = itemHeaderNode as? ChatListSearchItemHeaderNode {
                        itemHeaderNode.updateTheme(theme: presentationData.theme)
                    }
                })
            }
        }).strict()
                        
        self.recentListNode.beganInteractiveDragging = { _ in
            interaction.dismissInput()
        }
        
        self.listNode?.beganInteractiveDragging = { _ in
            interaction.dismissInput()
        }
        
        self.mediaNode?.beganInteractiveDragging = {
            interaction.dismissInput()
        }
        
        self.listNode?.visibleBottomContentOffsetChanged = { offset in
            guard case let .known(value) = offset, value < 160.0 else {
                return
            }
            loadMore()
        }
        
        self.mediaNode?.loadMore = {
            loadMore()
        }
        
        if [.file, .music, .voiceOrInstantVideo, .voice, .roundVideo].contains(tagMask) || self.key == .downloads {
            let key = self.key
            self.mediaStatusDisposable = (context.sharedContext.mediaManager.globalMediaPlayerState
            |> mapToSignal { playlistStateAndType -> Signal<(Account, SharedMediaPlayerItemPlaybackState, MediaManagerPlayerType)?, NoError> in
                if let (account, state, type) = playlistStateAndType {
                    switch state {
                    case let .state(state):
                        if let playlistId = state.playlistId as? PeerMessagesMediaPlaylistId, case .custom = playlistId {
                            switch type {
                            case .voice:
                                if ![.voiceOrInstantVideo, .voice, .roundVideo].contains(tagMask) {
                                    return .single(nil) |> delay(0.2, queue: .mainQueue())
                                }
                            case .music:
                                if tagMask != .music && key != .downloads {
                                    return .single(nil) |> delay(0.2, queue: .mainQueue())
                                }
                            case .file:
                                if tagMask != .file {
                                    return .single(nil) |> delay(0.2, queue: .mainQueue())
                                }
                            }
                            return .single((account, state, type))
                        } else {
                            return .single(nil) |> delay(0.2, queue: .mainQueue())
                        }
                    case .loading:
                        return .single(nil) |> delay(0.2, queue: .mainQueue())
                    }
                } else {
                    return .single(nil)
                }
            }
            |> deliverOnMainQueue).startStrict(next: { [weak self] playlistStateAndType in
                guard let self else {
                    return
                }
                if !arePlaylistItemsEqual(self.playlistStateAndType?.0, playlistStateAndType?.1.item) ||
                    !arePlaylistItemsEqual(self.playlistStateAndType?.1, playlistStateAndType?.1.previousItem) ||
                    !arePlaylistItemsEqual(self.playlistStateAndType?.2, playlistStateAndType?.1.nextItem) ||
                    self.playlistStateAndType?.3 != playlistStateAndType?.1.order || self.playlistStateAndType?.4 != playlistStateAndType?.2 {
                    
                    if let playlistStateAndType = playlistStateAndType {
                        self.playlistStateAndType = (playlistStateAndType.1.item, playlistStateAndType.1.previousItem, playlistStateAndType.1.nextItem, playlistStateAndType.1.order, playlistStateAndType.2, playlistStateAndType.0)
                    } else {
                        self.playlistStateAndType = nil
                    }
                    
                    if let (size, sideInset, bottomInset, visibleHeight, presentationData) = self.currentParams {
                        self.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, presentationData: presentationData, synchronous: true, transition: .animated(duration: 0.4, curve: .spring))
                    }
                }
                self.playlistLocation = playlistStateAndType?.1.playlistLocation
            })
        }
        
        self.deletedMessagesDisposable = (context.account.stateManager.deletedMessages
        |> deliverOnMainQueue).startStrict(next: { [weak self] messageIds in
            if let strongSelf = self {
                strongSelf.updateState { state in
                    var state = state
                    var deletedMessageIds = state.deletedMessageIds
                    var deletedGlobalMessageIds = state.deletedGlobalMessageIds

                    for messageId in messageIds {
                        switch messageId {
                            case let .messageId(id):
                                deletedMessageIds.insert(id)
                            case let .global(id):
                                deletedGlobalMessageIds.insert(id)
                        }
                    }
                    
                    state.deletedMessageIds = deletedMessageIds
                    state.deletedGlobalMessageIds = deletedGlobalMessageIds
                    return state
                }
            }
        }).strict()
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.searchDisposable.dispose()
        self.hiddenMediaDisposable?.dispose()
        self.mediaStatusDisposable?.dispose()
        self.playlistPreloadDisposable?.dispose()
        self.recentDisposable.dispose()
        self.updatedRecentPeersDisposable.dispose()
        self.deletedMessagesDisposable?.dispose()
        self.searchQueryDisposable?.dispose()
        self.searchOptionsDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.emptyResultsAnimationNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.animationTapGesture(_:))))
        
        self.updateSelectedMessages(animated: false)
    }
    
    private func updateState(_ f: (ChatListSearchListPaneNodeState) -> ChatListSearchListPaneNodeState) {
        let state = f(self.searchStateValue)
        if state != self.searchStateValue {
            self.searchStateValue = state
            self.searchStatePromise.set(state)
        }
    }
    
    @objc private func animationTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state, !self.emptyResultsAnimationNode.isPlaying {
            let _ = self.emptyResultsAnimationNode.playIfNeeded()
        }
    }
    
    func didBecomeFocused() {
        if self.key == .downloads {
            self.scheduleMarkRecentDownloadsAsSeen()
        }
    }
    
    private var scheduledMarkRecentDownloadsAsSeen: Bool = false
    
    func scheduleMarkRecentDownloadsAsSeen() {
        if !self.scheduledMarkRecentDownloadsAsSeen {
            self.scheduledMarkRecentDownloadsAsSeen = true
            Queue.mainQueue().after(0.1, { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.scheduledMarkRecentDownloadsAsSeen = false
                let _ = markAllRecentDownloadItemsAsSeen(postbox: strongSelf.context.account.postbox).startStandalone()
            })
        }
    }
    
    func scrollToTop() -> Bool {
        if let mediaNode = self.mediaNode, !mediaNode.isHidden {
            return mediaNode.scrollToTop()
        } else if !self.recentListNode.isHidden {
            let offset = self.recentListNode.visibleContentOffset()
            switch offset {
            case let .known(value) where value <= CGFloat.ulpOfOne:
                return false
            default:
                self.recentListNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                return true
            }
        } else if let listNode = self.listNode {
            let offset = listNode.visibleContentOffset()
            switch offset {
            case let .known(value) where value <= CGFloat.ulpOfOne:
                return false
            default:
                listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                return true
            }
        } else {
            return false
        }
    }
    
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.currentParams != nil
        self.currentParams = (size, sideInset, bottomInset, visibleHeight, presentationData)
        
        var topPanelHeight: CGFloat = 0.0
        if let (item, previousItem, nextItem, order, type, _) = self.playlistStateAndType {
            let panelHeight = MediaNavigationAccessoryHeaderNode.minimizedHeight
            topPanelHeight = panelHeight
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight - panelHeight), size: CGSize(width: size.width, height: panelHeight))
            if let (mediaAccessoryPanel, mediaType) = self.mediaAccessoryPanel, mediaType == type {
                transition.updateFrame(layer: mediaAccessoryPanel.layer, frame: panelFrame)
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: sideInset, rightInset: sideInset, isHidden: false, transition: transition)
                switch order {
                case .regular:
                    mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, previousItem, nextItem)
                case .reversed:
                    mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, nextItem, previousItem)
                case .random:
                    mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, nil, nil)
                }
                let delayedStatus = self.context.sharedContext.mediaManager.globalMediaPlayerState
                |> mapToSignal { value -> Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?, NoError> in
                    guard let value = value else {
                        return .single(nil)
                    }
                    switch value.1 {
                        case .state:
                            return .single(value)
                        case .loading:
                            return .single(value) |> delay(0.1, queue: .mainQueue())
                    }
                }
                
                mediaAccessoryPanel.containerNode.headerNode.playbackStatus = delayedStatus
                |> map { state -> MediaPlayerStatus in
                    if let stateOrLoading = state?.1, case let .state(state) = stateOrLoading {
                        return state.status
                    } else {
                        return MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
                    }
                }
            } else {
                if let (mediaAccessoryPanel, _) = self.mediaAccessoryPanel {
                    self.mediaAccessoryPanel = nil
                    self.dismissingPanel = mediaAccessoryPanel
                    mediaAccessoryPanel.animateOut(transition: transition, completion: { [weak self, weak mediaAccessoryPanel] in
                        mediaAccessoryPanel?.removeFromSupernode()
                        if let strongSelf = self, strongSelf.dismissingPanel === mediaAccessoryPanel {
                            strongSelf.dismissingPanel = nil
                        }
                    })
                }
                
                let mediaAccessoryPanel = MediaNavigationAccessoryPanel(context: self.context, presentationData: self.presentationData, displayBackground: true)
                mediaAccessoryPanel.containerNode.headerNode.displayScrubber = item.playbackData?.type != .instantVideo
                mediaAccessoryPanel.getController = { [weak self] in
                    return self?.navigationController?.topViewController as? ViewController
                }
                mediaAccessoryPanel.presentInGlobalOverlay = { [weak self] c in
                    (self?.navigationController?.topViewController as? ViewController)?.presentInGlobalOverlay(c)
                }
                mediaAccessoryPanel.close = { [weak self] in
                    if let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType {
                        strongSelf.context.sharedContext.mediaManager.setPlaylist(nil, type: type, control: SharedMediaPlayerControlAction.playback(.pause))
                    }
                }
                mediaAccessoryPanel.setRate = { [weak self] rate, changeType in
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = (strongSelf.context.sharedContext.accountManager.transaction { transaction -> AudioPlaybackRate in
                        let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.musicPlaybackSettings)?.get(MusicPlaybackSettings.self) ?? MusicPlaybackSettings.defaultSettings
 
                        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.musicPlaybackSettings, { _ in
                            return AccountManagerPreferencesEntry(settings.withUpdatedVoicePlaybackRate(rate))
                        })
                        return rate
                    }
                    |> deliverOnMainQueue).startStandalone(next: { baseRate in
                        guard let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType else {
                            return
                        }
                        strongSelf.context.sharedContext.mediaManager.playlistControl(.setBaseRate(baseRate), type: type)
                        
                        if let controller = strongSelf.navigationController?.topViewController as? ViewController {
                            var hasTooltip = false
                            controller.forEachController({ controller in
                                if let controller = controller as? UndoOverlayController {
                                    hasTooltip = true
                                    controller.dismissWithCommitAction()
                                }
                                return true
                            })
                            
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            let text: String?
                            let rate: CGFloat?
                            if case let .sliderCommit(previousValue, newValue) = changeType {
                                let value = String(format: "%0.1f", baseRate.doubleValue)
                                if baseRate == .x1 {
                                    text = presentationData.strings.Conversation_AudioRateTooltipNormal
                                } else {
                                    text = presentationData.strings.Conversation_AudioRateTooltipCustom(value).string
                                }
                                if newValue > previousValue {
                                    rate = .infinity
                                } else if newValue < previousValue {
                                    rate = -.infinity
                                } else {
                                    rate = nil
                                }
                            } else if baseRate == .x1 {
                                text = presentationData.strings.Conversation_AudioRateTooltipNormal
                                rate = 1.0
                            } else if baseRate == .x1_5 {
                                text = presentationData.strings.Conversation_AudioRateTooltip15X
                                rate = 1.5
                            } else if baseRate == .x2 {
                                text = presentationData.strings.Conversation_AudioRateTooltipSpeedUp
                                rate = 2.0
                            } else {
                                text = nil
                                rate = nil
                            }
                            var showTooltip = true
                            if case .sliderChange = changeType {
                                showTooltip = false
                            }
                            if let rate, let text, showTooltip {
                                controller.present(
                                    UndoOverlayController(
                                        presentationData: presentationData,
                                        content: .audioRate(
                                            rate: rate,
                                            text: text
                                        ),
                                        elevatedLayout: false,
                                        animateInAsReplacement: hasTooltip,
                                        action: { action in
                                            return true
                                        }
                                    ),
                                    in: .current
                                )
                            }
                        }
                    })
                }
                mediaAccessoryPanel.togglePlayPause = { [weak self] in
                    if let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType {
                        strongSelf.context.sharedContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: type)
                    }
                }
                mediaAccessoryPanel.playPrevious = { [weak self] in
                    if let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType {
                        strongSelf.context.sharedContext.mediaManager.playlistControl(.next, type: type)
                    }
                }
                mediaAccessoryPanel.playNext = { [weak self] in
                    if let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType {
                        strongSelf.context.sharedContext.mediaManager.playlistControl(.previous, type: type)
                    }
                }
                mediaAccessoryPanel.tapAction = { [weak self] in
                    guard let strongSelf = self, let navigationController = strongSelf.navigationController, let (state, _, _, order, type, account) = strongSelf.playlistStateAndType else {
                        return
                    }
                    if let id = state.id as? PeerMessagesMediaPlaylistItemId, let playlistLocation = strongSelf.playlistLocation as? PeerMessagesPlaylistLocation {
                        if type == .music {
                            if case .custom = playlistLocation {
                                let controllerContext: AccountContext
                                if account.id == strongSelf.context.account.id {
                                    controllerContext = strongSelf.context
                                } else {
                                    controllerContext = strongSelf.context.sharedContext.makeTempAccountContext(account: account)
                                }
                                let controller = strongSelf.context.sharedContext.makeOverlayAudioPlayerController(context: controllerContext, chatLocation: .peer(id: id.messageId.peerId), type: type, initialMessageId: id.messageId, initialOrder: order, playlistLocation: playlistLocation, parentNavigationController: navigationController)
                                strongSelf.interaction.dismissInput()
                                strongSelf.interaction.present(controller, nil)
                            } else if case let .messages(chatLocation, _, _) = playlistLocation {
                                let signal = strongSelf.context.sharedContext.messageFromPreloadedChatHistoryViewForLocation(id: id.messageId, location: ChatHistoryLocationInput(content: .InitialSearch(subject: MessageHistoryInitialSearchSubject(location: .id(id.messageId)), count: 60, highlight: true, setupReply: false), id: 0), context: strongSelf.context, chatLocation: chatLocation, subject: nil, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil), tag: .tag(EngineMessage.Tags.music))
                                
                                var cancelImpl: (() -> Void)?
                                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                let progressSignal = Signal<Never, NoError> { subscriber in
                                    let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                                        cancelImpl?()
                                    }))
                                    self?.interaction.present(controller, nil)
                                    return ActionDisposable { [weak controller] in
                                        Queue.mainQueue().async() {
                                            controller?.dismiss()
                                        }
                                    }
                                }
                                |> runOn(Queue.mainQueue())
                                |> delay(0.15, queue: Queue.mainQueue())
                                let progressDisposable = MetaDisposable()
                                var progressStarted = false
                                strongSelf.playlistPreloadDisposable?.dispose()
                                strongSelf.playlistPreloadDisposable = (signal
                                |> afterDisposed {
                                    Queue.mainQueue().async {
                                        progressDisposable.dispose()
                                    }
                                }
                                |> deliverOnMainQueue).startStrict(next: { index in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    if let _ = index.0 {
                                        let controllerContext: AccountContext
                                        if account.id == strongSelf.context.account.id {
                                            controllerContext = strongSelf.context
                                        } else {
                                            controllerContext = strongSelf.context.sharedContext.makeTempAccountContext(account: account)
                                        }
                                        let controller = strongSelf.context.sharedContext.makeOverlayAudioPlayerController(context: controllerContext, chatLocation: chatLocation, type: type, initialMessageId: id.messageId, initialOrder: order, playlistLocation: nil, parentNavigationController: navigationController)
                                        strongSelf.interaction.dismissInput()
                                        strongSelf.interaction.present(controller, nil)
                                    } else if index.1 {
                                        if !progressStarted {
                                            progressStarted = true
                                            progressDisposable.set(progressSignal.start())
                                        }
                                    }
                                }, completed: {
                                }).strict()
                                cancelImpl = {
                                    self?.playlistPreloadDisposable?.dispose()
                                }
                            }
                        } else {
                            strongSelf.context.sharedContext.navigateToChat(accountId: strongSelf.context.account.id, peerId: id.messageId.peerId, messageId: id.messageId)
                        }
                    }
                }
                mediaAccessoryPanel.frame = panelFrame
                if let dismissingPanel = self.dismissingPanel {
                    self.mediaAccessoryPanelContainer.insertSubnode(mediaAccessoryPanel, aboveSubnode: dismissingPanel)
                } else {
                    self.mediaAccessoryPanelContainer.addSubnode(mediaAccessoryPanel)
                }
                self.mediaAccessoryPanel = (mediaAccessoryPanel, type)
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: sideInset, rightInset: sideInset, isHidden: false, transition: .immediate)
                switch order {
                    case .regular:
                        mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, previousItem, nextItem)
                    case .reversed:
                        mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, nextItem, previousItem)
                    case .random:
                        mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, nil, nil)
                }
                mediaAccessoryPanel.containerNode.headerNode.playbackStatus = self.context.sharedContext.mediaManager.globalMediaPlayerState
                |> map { state -> MediaPlayerStatus in
                    if let stateOrLoading = state?.1, case let .state(state) = stateOrLoading {
                        return state.status
                    } else {
                        return MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
                    }
                }
                mediaAccessoryPanel.animateIn(transition: transition)
            }
        } else if let (mediaAccessoryPanel, _) = self.mediaAccessoryPanel {
            self.mediaAccessoryPanel = nil
            self.dismissingPanel = mediaAccessoryPanel
            mediaAccessoryPanel.animateOut(transition: transition, completion: { [weak self, weak mediaAccessoryPanel] in
                mediaAccessoryPanel?.removeFromSupernode()
                if let strongSelf = self, strongSelf.dismissingPanel === mediaAccessoryPanel {
                    strongSelf.dismissingPanel = nil
                }
            })
        }
        
        transition.updateFrame(node: self.mediaAccessoryPanelContainer, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: MediaNavigationAccessoryHeaderNode.minimizedHeight)))
        
        let topInset: CGFloat = topPanelHeight
        let overflowInset: CGFloat = 20.0
        let insets = UIEdgeInsets(top: topPanelHeight, left: sideInset, bottom: bottomInset, right: sideInset)
        
        self.shimmerNode.frame = CGRect(origin: CGPoint(x: overflowInset, y: topInset), size: CGSize(width: size.width - overflowInset * 2.0, height: size.height))
        self.shimmerNode.update(context: self.context, size: CGSize(width: size.width - overflowInset * 2.0, height: size.height), presentationData: self.presentationData, animationCache: self.animationCache, animationRenderer: self.animationRenderer, key: !(self.searchQueryValue?.isEmpty ?? true) && self.key == .media ? .chats : self.key, hasSelection: self.selectedMessages != nil, transition: transition)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        self.recentListNode.frame = CGRect(origin: CGPoint(), size: size)
        self.recentListNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if let emptyRecentTitleNode = self.emptyRecentTitleNode, let emptyRecentTextNode = self.emptyRecentTextNode, let emptyRecentAnimationNode = self.emptyRecentAnimationNode {
            let padding: CGFloat = 16.0
            let emptyTitleSize = emptyRecentTitleNode.updateLayout(CGSize(width: size.width - sideInset * 2.0 - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
            let emptyTextSize = emptyRecentTextNode.updateLayout(CGSize(width: size.width - sideInset * 2.0 - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
            
            let emptyAnimationHeight = emptyRecentAnimationSize.height
            let emptyAnimationSpacing: CGFloat = 8.0
            let emptyTextSpacing: CGFloat = 8.0
            let emptyTotalHeight = emptyAnimationHeight + emptyAnimationSpacing + emptyTitleSize.height + emptyTextSize.height + emptyTextSpacing
            let emptyAnimationY = topInset + floorToScreenPixels((visibleHeight - topInset - bottomInset - emptyTotalHeight) / 2.0)
            
            let textTransition = ContainedViewLayoutTransition.immediate
            textTransition.updateFrame(node: emptyRecentAnimationNode, frame: CGRect(origin: CGPoint(x: sideInset + padding + (size.width - sideInset * 2.0 - padding * 2.0 - emptyRecentAnimationSize.width) / 2.0, y: emptyAnimationY), size: emptyRecentAnimationSize))
            textTransition.updateFrame(node: emptyRecentTitleNode, frame: CGRect(origin: CGPoint(x: sideInset + padding + (size.width - sideInset * 2.0 - padding * 2.0 - emptyTitleSize.width) / 2.0, y: emptyAnimationY + emptyAnimationHeight + emptyAnimationSpacing), size: emptyTitleSize))
            textTransition.updateFrame(node: emptyRecentTextNode, frame: CGRect(origin: CGPoint(x: sideInset + padding + (size.width - sideInset * 2.0 - padding * 2.0 - emptyTextSize.width) / 2.0, y: emptyAnimationY + emptyAnimationHeight + emptyAnimationSpacing + emptyTitleSize.height + emptyTextSpacing), size: emptyTextSize))
            emptyRecentAnimationNode.updateLayout(size: emptyRecentAnimationSize)
        }
        
        self.listNode?.frame = CGRect(origin: CGPoint(), size: size)
        self.listNode?.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.mediaNode?.frame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: size.width, height: size.height))
        self.mediaNode?.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: false, expandProgress: 1.0, presentationData: self.presentationData, synchronous: true, transition: transition)
        
        do {
            let padding: CGFloat = 16.0
            let emptyTitleSize = self.emptyResultsTitleNode.updateLayout(CGSize(width: size.width - sideInset * 2.0 - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
            let emptyTextSize = self.emptyResultsTextNode.updateLayout(CGSize(width: size.width - sideInset * 2.0 - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
            
            let emptyAnimationHeight = self.emptyResultsAnimationSize.height
            let emptyAnimationSpacing: CGFloat = 8.0
            let emptyTextSpacing: CGFloat = 8.0
            let emptyTotalHeight = emptyAnimationHeight + emptyAnimationSpacing + emptyTitleSize.height + emptyTextSize.height + emptyTextSpacing
            let emptyAnimationY = topInset + floorToScreenPixels((visibleHeight - topInset - bottomInset - emptyTotalHeight) / 2.0)
            
            let textTransition = ContainedViewLayoutTransition.immediate
            textTransition.updateFrame(node: self.emptyResultsAnimationNode, frame: CGRect(origin: CGPoint(x: sideInset + padding + (size.width - sideInset * 2.0 - padding * 2.0 - self.emptyResultsAnimationSize.width) / 2.0, y: emptyAnimationY), size: self.emptyResultsAnimationSize))
            textTransition.updateFrame(node: self.emptyResultsTitleNode, frame: CGRect(origin: CGPoint(x: sideInset + padding + (size.width - sideInset * 2.0 - padding * 2.0 - emptyTitleSize.width) / 2.0, y: emptyAnimationY + emptyAnimationHeight + emptyAnimationSpacing), size: emptyTitleSize))
            textTransition.updateFrame(node: self.emptyResultsTextNode, frame: CGRect(origin: CGPoint(x: sideInset + padding + (size.width - sideInset * 2.0 - padding * 2.0 - emptyTextSize.width) / 2.0, y: emptyAnimationY + emptyAnimationHeight + emptyAnimationSpacing + emptyTitleSize.height + emptyTextSpacing), size: emptyTextSize))
            self.emptyResultsAnimationNode.updateLayout(size: self.emptyResultsAnimationSize)
        }
        
        if !hadValidLayout {
            while !self.enqueuedRecentTransitions.isEmpty {
                self.dequeueRecentTransition()
            }
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    func updateHiddenMedia() {
        self.listNode?.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListMessageNode {
                itemNode.updateHiddenMedia()
            }
        }
    }
    
    func cancelPreviewGestures() {
    }
    
    func transitionNodeForGallery(messageId: EngineMessage.Id, media: EngineMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        var transitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
        self.listNode?.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListMessageNode {
                if let result = itemNode.transitionNode(id: messageId, media: media._asMedia(), adjustRect: false) {
                    transitionNode = result
                }
            }
        }
        return transitionNode
    }
    
    func addToTransitionSurface(view: UIView) {
        self.view.addSubview(view)
    }
    
    func updateSelectedMessages(animated: Bool) {
        self.selectedMessages = self.interaction.getSelectedMessageIds()
        self.mediaNode?.selectedMessageIds = self.selectedMessages
        self.mediaNode?.updateSelectedMessages(animated: animated)
    }
    
    func removeAds() {
        self.adsHidden = true
    }
    
    private func enqueueRecentTransition(_ transition: ChatListSearchContainerRecentTransition, firstTime: Bool) {
        self.enqueuedRecentTransitions.append((transition, firstTime))
        
        if self.currentParams != nil {
            while !self.enqueuedRecentTransitions.isEmpty {
                self.dequeueRecentTransition()
            }
        }
    }
    
    private func dequeueRecentTransition() {
        if let (transition, firstTime) = self.enqueuedRecentTransitions.first {
            self.enqueuedRecentTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            if firstTime {
                options.insert(.PreferSynchronousResourceLoading)
                options.insert(.PreferSynchronousDrawing)
            } else {
                options.insert(.AnimateInsertion)
            }
            
            self.recentListNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                
                if !strongSelf.didSetReady && !strongSelf.recentListNode.isHidden {
                    var ready: Signal<Bool, NoError>?
                    strongSelf.recentListNode.forEachItemNode { node in
                        if let node = node as? ChatListRecentPeersListItemNode {
                            ready = node.isReady
                        }
                    }
                    
                    if let ready = ready {
                        strongSelf.ready.set(ready)
                    } else {
                        strongSelf.ready.set(.single(true))
                    }
                    strongSelf.didSetReady = true
                    if !strongSelf.recentListNode.preloadPages {
                        Queue.mainQueue().after(0.5) {
                            strongSelf.recentListNode.preloadPages = true
                        }
                    }
                    
                    strongSelf.emptyRecentAnimationNode?.isHidden = !transition.isEmpty
                    strongSelf.emptyRecentTitleNode?.isHidden = !transition.isEmpty
                    strongSelf.emptyRecentTextNode?.isHidden = !transition.isEmpty
                    strongSelf.emptyRecentAnimationNode?.visibility = transition.isEmpty
                }
            })
        }
    }
    
    private func enqueueTransition(_ transition: ChatListSearchContainerTransition, firstTime: Bool) {
        self.enqueuedTransitions.append((transition, firstTime))
        
        if self.currentParams != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, isFirstTime) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            if isFirstTime && [.chats, .topics, .channels, .apps].contains(self.key) {
                options.insert(.PreferSynchronousDrawing)
                options.insert(.PreferSynchronousResourceLoading)
            } else if transition.animated {
                options.insert(.AnimateInsertion)
            }
            
            if self.key == .downloads {
                options.insert(.PreferSynchronousDrawing)
                options.insert(.PreferSynchronousResourceLoading)
            }
            
            self.listNode?.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self {
                    let searchOptions = strongSelf.searchOptionsValue
                    strongSelf.listNode?.isHidden = strongSelf.tagMask == .photoOrVideo && (strongSelf.searchQueryValue ?? "").isEmpty
                    strongSelf.mediaNode?.isHidden = !(strongSelf.listNode?.isHidden ?? true)
                    
                    let displayingResults = transition.displayingResults
                    if !displayingResults {
                        strongSelf.listNode?.isHidden = true
                        strongSelf.mediaNode?.isHidden = true
                    }
                    
                    let emptyResults = displayingResults && transition.isEmpty
                    if emptyResults {
                        let emptyResultsTitle: String
                        let emptyResultsText: String
                        if let query = transition.query, !query.isEmpty {
                            emptyResultsTitle = strongSelf.presentationData.strings.ChatList_Search_NoResults
                            emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsQueryDescription(query).string
                        } else {
                            if let searchOptions = searchOptions, searchOptions.date == nil && searchOptions.peer == nil {
                                emptyResultsTitle = strongSelf.presentationData.strings.ChatList_Search_NoResultsFilter
                                if strongSelf.tagMask == .photoOrVideo {
                                    emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsFitlerMedia
                                } else if strongSelf.tagMask == .webPage {
                                    emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsFitlerLinks
                                } else if strongSelf.tagMask == .file {
                                    emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsFitlerFiles
                                } else if strongSelf.tagMask == .music {
                                    emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsFitlerMusic
                                } else if strongSelf.tagMask == .voiceOrInstantVideo {
                                    emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsFitlerVoice
                                } else {
                                    emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsDescription
                                }
                            } else {
                                emptyResultsTitle = strongSelf.presentationData.strings.ChatList_Search_NoResults
                                emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsDescription
                            }
                        }
                        
                        strongSelf.emptyResultsTitleNode.attributedText = NSAttributedString(string: emptyResultsTitle, font: Font.semibold(17.0), textColor: strongSelf.presentationData.theme.list.freeTextColor)
                        strongSelf.emptyResultsTextNode.attributedText = NSAttributedString(string: emptyResultsText, font: Font.regular(15.0), textColor: strongSelf.presentationData.theme.list.freeTextColor)
                    }

                    if let (size, sideInset, bottomInset, visibleHeight, presentationData) = strongSelf.currentParams {
                        strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, presentationData: presentationData, synchronous: true, transition: .animated(duration: 0.4, curve: .spring))
                    }
                    
                    if strongSelf.key == .downloads {
                        strongSelf.emptyResultsAnimationNode.isHidden = true
                        strongSelf.emptyResultsTitleNode.isHidden = true
                        strongSelf.emptyResultsTextNode.isHidden = true
                        strongSelf.emptyResultsAnimationNode.visibility = false
                    } else {
                        strongSelf.emptyResultsAnimationNode.isHidden = !emptyResults
                        strongSelf.emptyResultsTitleNode.isHidden = !emptyResults
                        strongSelf.emptyResultsTextNode.isHidden = !emptyResults
                        strongSelf.emptyResultsAnimationNode.visibility = emptyResults
                    }
                                             
                    var displayPlaceholder = transition.isLoading && (![.chats, .topics, .channels, .apps].contains(strongSelf.key) || (strongSelf.currentEntries?.isEmpty ?? true))
                    if strongSelf.key == .downloads {
                        displayPlaceholder = false
                    }

                    let targetAlpha: CGFloat = displayPlaceholder ? 1.0 : 0.0
                    if strongSelf.shimmerNode.alpha != targetAlpha {
                        let transition: ContainedViewLayoutTransition = (displayPlaceholder || isFirstTime) ? .immediate : .animated(duration: 0.2, curve: .linear)
                        transition.updateAlpha(node: strongSelf.shimmerNode, alpha: targetAlpha, delay: 0.1)
                    }
           
                    strongSelf.recentListNode.isHidden = displayingResults || strongSelf.peersFilter.contains(.excludeRecent)
                    strongSelf.recentEmptyNode?.isHidden = strongSelf.recentListNode.isHidden
                    strongSelf.backgroundColor = !displayingResults && strongSelf.peersFilter.contains(.excludeRecent) ? nil : strongSelf.presentationData.theme.chatList.backgroundColor
                    
                    if !strongSelf.didSetReady && strongSelf.recentListNode.isHidden {
                        strongSelf.ready.set(.single(true))
                        strongSelf.didSetReady = true
                    }
                }
            })
        }
    }
    
    func previewViewAndActionAtLocation(_ location: CGPoint) -> (UIView, CGRect, Any)? {
        var selectedItemNode: ASDisplayNode?
        var bounds: CGRect
        if !self.recentListNode.isHidden {
            let adjustedLocation = self.convert(location, to: self.recentListNode)
            self.recentListNode.forEachItemNode { itemNode in
                if itemNode.frame.contains(adjustedLocation) {
                    selectedItemNode = itemNode
                }
            }
        } else {
            let adjustedLocation = self.convert(location, to: self.listNode)
            self.listNode?.forEachItemNode { itemNode in
                if itemNode.frame.contains(adjustedLocation) {
                    selectedItemNode = itemNode
                }
            }
        }
        if let selectedItemNode = selectedItemNode as? ChatListRecentPeersListItemNode {
            if let result = selectedItemNode.viewAndPeerAtPoint(self.convert(location, to: selectedItemNode)) {
                return (result.0, result.0.bounds, result.1)
            }
        } else if let selectedItemNode = selectedItemNode as? ContactsPeerItemNode, let peer = selectedItemNode.chatPeer {
            if selectedItemNode.frame.height > 50.0 {
                bounds = CGRect(x: 0.0, y: selectedItemNode.frame.height - 50.0, width: selectedItemNode.frame.width, height: 50.0)
            } else {
                bounds = selectedItemNode.bounds
            }
            return (selectedItemNode.view, bounds, peer.id)
        } else if let selectedItemNode = selectedItemNode as? ChatListItemNode, let item = selectedItemNode.item {
            if selectedItemNode.frame.height > 76.0 {
                bounds = CGRect(x: 0.0, y: selectedItemNode.frame.height - 76.0, width: selectedItemNode.frame.width, height: 76.0)
            } else {
                bounds = selectedItemNode.bounds
            }
            switch item.content {
            case .loading:
                return nil
            case let .peer(peerData):
                return (selectedItemNode.view, bounds, peerData.messages.last?.id ?? peerData.peer.peerId)
            case let .groupReference(groupReference):
                return (selectedItemNode.view, bounds, groupReference.groupId)
            }
        }
        return nil
    }
    
    func openMessagesFilter(sourceNode: ASDisplayNode) {
        self.interaction.dismissInput()
        let _ = (self.searchScopePromise.get()
        |> take(1)).start(next: { [weak self] scope in
            guard let self else {
                return
            }
            var items: [ContextMenuItem] = []
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.ChatList_Search_Messages_Menu_AllChats, icon: { theme in
                return scope == .everywhere ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }, action: { [weak self] _, f in
                guard let self else {
                    return
                }
                f(.default)
                self.searchScopePromise.set(.everywhere)
            })))
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.ChatList_Search_Messages_Menu_PrivateChats, icon: { theme in
                return scope == .privateChats ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }, action: { [weak self] _, f in
                guard let self else {
                    return
                }
                f(.default)
                self.searchScopePromise.set(.privateChats)
            })))
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.ChatList_Search_Messages_Menu_GroupChats, icon: { theme in
                return scope == .groups ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }, action: { [weak self] _, f in
                guard let self else {
                    return
                }
                f(.default)
                self.searchScopePromise.set(.groups)
            })))
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.ChatList_Search_Messages_Menu_Channels, icon: { theme in
                return scope == .channels ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }, action: { [weak self] _, f in
                guard let self else {
                    return
                }
                f(.default)
                self.searchScopePromise.set(.channels)
            })))
            let contextController = ContextController(presentationData: self.presentationData, source: .reference(ChatListSearchReferenceContentSource(sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
            self.interaction.present(contextController, nil)
        })
    }
}

private final class SearchShimmerEffectNode: ASDisplayNode {
    private var currentBackgroundColor: UIColor?
    private var currentForegroundColor: UIColor?
    private let imageNodeContainer: ASDisplayNode
    private let imageNode: ASImageNode
    
    private var absoluteLocation: (CGRect, CGSize)?
    private var isCurrentlyInHierarchy = false
    private var shouldBeAnimating = false
    
    override init() {
        self.imageNodeContainer = ASDisplayNode()
        self.imageNodeContainer.isLayerBacked = true
        
        self.imageNode = ASImageNode()
        self.imageNode.isLayerBacked = true
        self.imageNode.displaysAsynchronously = false
        self.imageNode.displayWithoutProcessing = true
        self.imageNode.contentMode = .scaleToFill
        
        super.init()
        
        self.isLayerBacked = true
        self.clipsToBounds = true
        
        self.imageNodeContainer.addSubnode(self.imageNode)
        self.addSubnode(self.imageNodeContainer)
    }
    
    override func didEnterHierarchy() {
        super.didEnterHierarchy()
        
        self.isCurrentlyInHierarchy = true
        self.updateAnimation()
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.isCurrentlyInHierarchy = false
        self.updateAnimation()
    }
    
    func update(backgroundColor: UIColor, foregroundColor: UIColor) {
        if let currentBackgroundColor = self.currentBackgroundColor, currentBackgroundColor.argb == backgroundColor.argb, let currentForegroundColor = self.currentForegroundColor, currentForegroundColor.argb == foregroundColor.argb {
            return
        }
        self.currentBackgroundColor = backgroundColor
        self.currentForegroundColor = foregroundColor
        
        self.imageNode.image = generateImage(CGSize(width: 4.0, height: 320.0), opaque: true, scale: 1.0, rotatedContext: { size, context in
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
            
            context.clip(to: CGRect(origin: CGPoint(), size: size))
            
            let transparentColor = foregroundColor.withAlphaComponent(0.0).cgColor
            let peakColor = foregroundColor.cgColor
            
            var locations: [CGFloat] = [0.0, 0.5, 1.0]
            let colors: [CGColor] = [transparentColor, peakColor, transparentColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        })
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        if let absoluteLocation = self.absoluteLocation, absoluteLocation.0 == rect && absoluteLocation.1 == containerSize {
            return
        }
        let sizeUpdated = self.absoluteLocation?.1 != containerSize
        let frameUpdated = self.absoluteLocation?.0 != rect
        self.absoluteLocation = (rect, containerSize)
        
        if sizeUpdated {
            if self.shouldBeAnimating {
                self.imageNode.layer.removeAnimation(forKey: "shimmer")
                self.addImageAnimation()
            }
        }
        
        if frameUpdated {
            self.imageNodeContainer.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
        }
        
        self.updateAnimation()
    }
    
    private func updateAnimation() {
        let shouldBeAnimating = self.isCurrentlyInHierarchy && self.absoluteLocation != nil
        if shouldBeAnimating != self.shouldBeAnimating {
            self.shouldBeAnimating = shouldBeAnimating
            if shouldBeAnimating {
                self.addImageAnimation()
            } else {
                self.imageNode.layer.removeAnimation(forKey: "shimmer")
            }
        }
    }
    
    private func addImageAnimation() {
        guard let containerSize = self.absoluteLocation?.1 else {
            return
        }
        let gradientHeight: CGFloat = 250.0
        self.imageNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -gradientHeight), size: CGSize(width: containerSize.width, height: gradientHeight))
        let animation = self.imageNode.layer.makeAnimation(from: 0.0 as NSNumber, to: (containerSize.height + gradientHeight) as NSNumber, keyPath: "position.y", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 1.3 * 1.0, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
        animation.repeatCount = Float.infinity
        animation.beginTime = 1.0
        self.imageNode.layer.add(animation, forKey: "shimmer")
    }
}

public final class ChatListSearchShimmerNode: ASDisplayNode {
    private let backgroundColorNode: ASDisplayNode
    private let effectNode: SearchShimmerEffectNode
    private let maskNode: ASImageNode
    private var currentParams: (size: CGSize, presentationData: PresentationData, key: ChatListSearchPaneKey)?
    
    public init(key: ChatListSearchPaneKey) {
        self.backgroundColorNode = ASDisplayNode()
        self.effectNode = SearchShimmerEffectNode()
        self.maskNode = ASImageNode()
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.backgroundColorNode)
        self.addSubnode(self.effectNode)
        self.addSubnode(self.maskNode)
    }
    
    public func update(context: AccountContext, size: CGSize, presentationData: PresentationData, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, key: ChatListSearchPaneKey, hasSelection: Bool, transition: ContainedViewLayoutTransition) {
        if self.currentParams?.size != size || self.currentParams?.presentationData !== presentationData || self.currentParams?.key != key {
            self.currentParams = (size, presentationData, key)
            
            let chatListPresentationData = ChatListPresentationData(theme: presentationData.theme, fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true)
            
            let peer1: EnginePeer = .user(TelegramUser(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(0)), accessHash: nil, firstName: "FirstName", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil))
            let timestamp1: Int32 = 100000
            var peers: [EnginePeer.Id: EnginePeer] = [:]
            peers[peer1.id] = peer1
            let interaction = ChatListNodeInteraction(context: context, animationCache: animationCache, animationRenderer: animationRenderer, activateSearch: {}, peerSelected: { _, _, _, _, _ in }, disabledPeerSelected: { _, _, _ in }, togglePeerSelected: { _, _ in }, togglePeersSelection: { _, _ in }, additionalCategorySelected: { _ in
            }, messageSelected: { _, _, _, _ in}, groupSelected: { _ in }, addContact: { _ in }, setPeerIdWithRevealedOptions: { _, _ in }, setItemPinned: { _, _ in }, setPeerMuted: { _, _ in }, setPeerThreadMuted: { _, _, _ in }, deletePeer: { _, _ in }, deletePeerThread: { _, _ in }, setPeerThreadStopped: { _, _, _ in }, setPeerThreadPinned: { _, _, _ in }, setPeerThreadHidden: { _, _, _ in }, updatePeerGrouping: { _, _ in }, togglePeerMarkedUnread: { _, _ in}, toggleArchivedFolderHiddenByDefault: {}, toggleThreadsSelection: { _, _ in }, hidePsa: { _ in }, activateChatPreview: { _, _, _, gesture, _ in
                gesture?.cancel()
            }, present: { _ in }, openForumThread: { _, _ in }, openStorageManagement: {}, openPasswordSetup: {}, openPremiumIntro: {}, openPremiumGift: { _, _ in }, openPremiumManagement: {}, openActiveSessions: {
            }, openBirthdaySetup: {
            }, performActiveSessionAction: { _, _ in
            }, openChatFolderUpdates: {}, hideChatFolderUpdates: {
            }, openStories: { _, _ in
            }, openStarsTopup: { _ in
            }, dismissNotice: { _ in
            }, editPeer: { _ in
            }, openWebApp: { _ in
            }, openPhotoSetup: {
            }, openAdInfo: { _, _ in
            }, openAccountFreezeInfo: {
            }, openUrl: { _ in
            })
            var isInlineMode = false
            if case .topics = key {
                isInlineMode = false
            }
            interaction.isSearchMode = true
            interaction.isInlineMode = isInlineMode
            
            let items = (0 ..< 2).compactMap { _ -> ListViewItem? in
                switch key {
                    case .chats, .topics, .channels, .apps, .downloads, .publicPosts:
                        let message = EngineMessage(
                            stableId: 0,
                            stableVersion: 0,
                            id: EngineMessage.Id(peerId: peer1.id, namespace: 0, id: 0),
                            globallyUniqueId: nil,
                            groupingKey: nil,
                            groupInfo: nil,
                            threadId: nil,
                            timestamp: timestamp1,
                            flags: [],
                            tags: [],
                            globalTags: [],
                            localTags: [],
                            customTags: [],
                            forwardInfo: nil,
                            author: peer1,
                            text: "Text",
                            attributes: [],
                            media: [],
                            peers: peers,
                            associatedMessages: [:],
                            associatedMessageIds: [],
                            associatedMedia: [:],
                            associatedThreadInfo: nil,
                            associatedStories: [:]
                        )
                        let readState = EnginePeerReadCounters()
                        return ChatListItem(presentationData: chatListPresentationData, context: context, chatListLocation: .chatList(groupId: .root), filterData: nil, index: .chatList(EngineChatList.Item.Index.ChatList(pinningIndex: 0, messageIndex: EngineMessage.Index(id: EngineMessage.Id(peerId: peer1.id, namespace: 0, id: 0), timestamp: timestamp1))), content: .peer(ChatListItemContent.PeerData(
                            messages: [message],
                            peer: EngineRenderedPeer(peer: peer1),
                            threadInfo: nil,
                            combinedReadState: readState,
                            isRemovedFromTotalUnreadCount: false,
                            presence: nil,
                            hasUnseenMentions: false,
                            hasUnseenReactions: false,
                            draftState: nil,
                            mediaDraftContentType: nil,
                            inputActivities: nil,
                            promoInfo: nil,
                            ignoreUnreadBadge: false,
                            displayAsMessage: false,
                            hasFailedMessages: false,
                            forumTopicData: nil,
                            topForumTopicItems: [],
                            autoremoveTimeout: nil,
                            storyState: nil,
                            requiresPremiumForMessaging: false,
                            displayAsTopicList: false,
                            tags: []
                        )), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enabledContextActions: nil, hiddenOffset: false, interaction: interaction)
                    case .media:
                        return nil
                    case .links:
                        var media: [EngineMedia] = []
                        media.append(.webpage(TelegramMediaWebpage(webpageId: EngineMedia.Id(namespace: 0, id: 0), content: .Loaded(TelegramMediaWebpageLoadedContent(url: "https://telegram.org", displayUrl: "https://telegram.org", hash: 0, type: nil, websiteName: "Telegram", title: "Telegram Telegram", text: "Telegram", embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, isMediaLargeByDefault: nil, imageIsVideoCover: false, image: nil, file: nil, story: nil, attributes: [], instantPage: nil)))))
                        let message = EngineMessage(
                            stableId: 0,
                            stableVersion: 0,
                            id: EngineMessage.Id(peerId: peer1.id, namespace: 0, id: 0),
                            globallyUniqueId: nil,
                            groupingKey: nil,
                            groupInfo: nil,
                            threadId: nil,
                            timestamp: timestamp1,
                            flags: [],
                            tags: [],
                            globalTags: [],
                            localTags: [],
                            customTags: [],
                            forwardInfo: nil,
                            author: peer1,
                            text: "Text",
                            attributes: [],
                            media: media,
                            peers: peers,
                            associatedMessages: [:],
                            associatedMessageIds: [],
                            associatedMedia: [:],
                            associatedThreadInfo: nil,
                            associatedStories: [:]
                        )
                        
                        return ListMessageItem(presentationData: ChatPresentationData(presentationData: presentationData), context: context, chatLocation: .peer(id: peer1.id), interaction: ListMessageItemInteraction.default, message: message._asMessage(), selection: hasSelection ? .selectable(selected: false) : .none, displayHeader: false, customHeader: nil, hintIsLink: true, isGlobalSearchResult: true)
                    case .files:
                        var media: [EngineMedia] = []
                        media.append(.file(TelegramMediaFile(fileId: EngineMedia.Id(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: 0, attributes: [.FileName(fileName: "Text.txt")], alternativeRepresentations: [])))
                        let message = EngineMessage(
                            stableId: 0,
                            stableVersion: 0,
                            id: EngineMessage.Id(peerId: peer1.id, namespace: 0, id: 0),
                            globallyUniqueId: nil,
                            groupingKey: nil,
                            groupInfo: nil,
                            threadId: nil,
                            timestamp: timestamp1,
                            flags: [],
                            tags: [],
                            globalTags: [],
                            localTags: [],
                            customTags: [],
                            forwardInfo: nil,
                            author: peer1,
                            text: "Text",
                            attributes: [],
                            media: media,
                            peers: peers,
                            associatedMessages: [:],
                            associatedMessageIds: [],
                            associatedMedia: [:],
                            associatedThreadInfo: nil,
                            associatedStories: [:]
                        )
                        
                        return ListMessageItem(presentationData: ChatPresentationData(presentationData: presentationData), context: context, chatLocation: .peer(id: peer1.id), interaction: ListMessageItemInteraction.default, message: message._asMessage(), selection: hasSelection ? .selectable(selected: false) : .none, displayHeader: false, customHeader: nil, hintIsLink: false, isGlobalSearchResult: true)
                    case .music:
                        var media: [EngineMedia] = []
                        media.append(.file(TelegramMediaFile(fileId: EngineMedia.Id(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: 0, attributes: [.Audio(isVoice: false, duration: 0, title: nil, performer: nil, waveform: Data())], alternativeRepresentations: [])))
                        let message = EngineMessage(
                            stableId: 0,
                            stableVersion: 0,
                            id: EngineMessage.Id(peerId: peer1.id, namespace: 0, id: 0),
                            globallyUniqueId: nil,
                            groupingKey: nil,
                            groupInfo: nil,
                            threadId: nil,
                            timestamp: timestamp1,
                            flags: [],
                            tags: [],
                            globalTags: [],
                            localTags: [],
                            customTags: [],
                            forwardInfo: nil,
                            author: peer1,
                            text: "Text",
                            attributes: [],
                            media: media,
                            peers: peers,
                            associatedMessages: [:],
                            associatedMessageIds: [],
                            associatedMedia: [:],
                            associatedThreadInfo: nil,
                            associatedStories: [:]
                        )
                        
                        return ListMessageItem(presentationData: ChatPresentationData(presentationData: presentationData), context: context, chatLocation: .peer(id: peer1.id), interaction: ListMessageItemInteraction.default, message: message._asMessage(), selection: hasSelection ? .selectable(selected: false) : .none, displayHeader: false, customHeader: nil, hintIsLink: false, isGlobalSearchResult: true)
                    case .voice, .instantVideo:
                        var media: [EngineMedia] = []
                        media.append(.file(TelegramMediaFile(fileId: EngineMedia.Id(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: 0, attributes: [.Audio(isVoice: true, duration: 0, title: nil, performer: nil, waveform: Data())], alternativeRepresentations: [])))
                        let message = EngineMessage(
                            stableId: 0,
                            stableVersion: 0,
                            id: EngineMessage.Id(peerId: peer1.id, namespace: 0, id: 0),
                            globallyUniqueId: nil,
                            groupingKey: nil,
                            groupInfo: nil,
                            threadId: nil,
                            timestamp: timestamp1,
                            flags: [],
                            tags: [],
                            globalTags: [],
                            localTags: [],
                            customTags: [],
                            forwardInfo: nil,
                            author: peer1,
                            text: "Text",
                            attributes: [],
                            media: media,
                            peers: peers,
                            associatedMessages: [:],
                            associatedMessageIds: [],
                            associatedMedia: [:],
                            associatedThreadInfo: nil,
                            associatedStories: [:]
                        )
                        
                        return ListMessageItem(presentationData: ChatPresentationData(presentationData: presentationData), context: context, chatLocation: .peer(id: peer1.id), interaction: ListMessageItemInteraction.default, message: message._asMessage(), selection: hasSelection ? .selectable(selected: false) : .none, displayHeader: false, customHeader: nil, hintIsLink: false, isGlobalSearchResult: true)
                }
            }
            
            var itemNodes: [ListViewItemNode] = []
            for i in 0 ..< items.count {
                items[i].nodeConfiguredForParams(async: { f in f() }, params: ListViewItemLayoutParams(width: size.width, leftInset: 0.0, rightInset: 0.0, availableHeight: 100.0), synchronousLoads: false, previousItem: i == 0 ? nil : items[i - 1], nextItem: (i == items.count - 1) ? nil : items[i + 1], completion: { node, apply in
                    itemNodes.append(node)
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
            }
            
            self.backgroundColorNode.backgroundColor = presentationData.theme.list.mediaPlaceholderColor
            
            self.maskNode.image = generateImage(size, rotatedContext: { size, context in
                context.setFillColor(presentationData.theme.chatList.backgroundColor.cgColor)
                context.fill(CGRect(origin: CGPoint(), size: size))
                
                if key == .media {
                    var currentY: CGFloat = 0.0
                    var rowIndex: Int = 0
                    
                    let itemSpacing: CGFloat = 1.0
                    let itemsInRow = max(3, min(6, Int(size.width / 140.0)))
                    let itemSize: CGFloat = floor(size.width / CGFloat(itemsInRow))
                    
                    context.setBlendMode(.copy)
                    context.setFillColor(UIColor.clear.cgColor)
                    
                    while currentY < size.height {
                        for i in 0 ..< itemsInRow {
                            let itemOrigin = CGPoint(x: CGFloat(i) * (itemSize + itemSpacing), y: itemSpacing + CGFloat(rowIndex) * (itemSize + itemSpacing))
                            context.fill(CGRect(origin: itemOrigin, size: CGSize(width: itemSize, height: itemSize)))
                        }
                        currentY += itemSize
                        rowIndex += 1
                    }
                } else {
                    var currentY: CGFloat = 0.0
                    let fakeLabelPlaceholderHeight: CGFloat = 8.0
                    
                    func fillLabelPlaceholderRect(origin: CGPoint, width: CGFloat) {
                        let startPoint = origin
                        let diameter = fakeLabelPlaceholderHeight
                        context.fillEllipse(in: CGRect(origin: startPoint, size: CGSize(width: diameter, height: diameter)))
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: startPoint.x + width - diameter, y: startPoint.y), size: CGSize(width: diameter, height: diameter)))
                        context.fill(CGRect(origin: CGPoint(x: startPoint.x + diameter / 2.0, y: startPoint.y), size: CGSize(width: width - diameter, height: diameter)))
                    }
                    
                    while currentY < size.height {
                        let sampleIndex = 0
                        let itemHeight: CGFloat = itemNodes[sampleIndex].contentSize.height
                        
                        context.setBlendMode(.copy)
                        context.setFillColor(UIColor.clear.cgColor)
                        
                        let selectionOffset: CGFloat = hasSelection ? 45.0 : 0.0
                        
                        if let itemNode = itemNodes[sampleIndex] as? ChatListItemNode {
                            if !isInlineMode {
                                if !itemNode.avatarNode.isHidden {
                                    context.fillEllipse(in: itemNode.avatarNode.view.convert(itemNode.avatarNode.bounds, to: itemNode.view).offsetBy(dx: 0.0, dy: currentY))
                                }
                            }
                            
                            let titleFrame = itemNode.titleNode.frame.offsetBy(dx: 0.0, dy: currentY)
                            if isInlineMode {
                                fillLabelPlaceholderRect(origin: CGPoint(x: titleFrame.minX + 22.0, y: floor(titleFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 60.0 - 22.0)
                            } else {
                                fillLabelPlaceholderRect(origin: CGPoint(x: titleFrame.minX, y: floor(titleFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 60.0)
                            }
                            
                            let textFrame = itemNode.textNode.textNode.frame.offsetBy(dx: 0.0, dy: currentY)
                            
                            if isInlineMode {
                                context.fillEllipse(in: CGRect(origin: CGPoint(x: textFrame.minX, y: titleFrame.minY + 2.0), size: CGSize(width: 16.0, height: 16.0)))
                            }
                            
                            fillLabelPlaceholderRect(origin: CGPoint(x: textFrame.minX, y: currentY + itemHeight - floor(itemNode.titleNode.frame.midY - fakeLabelPlaceholderHeight / 2.0) - fakeLabelPlaceholderHeight), width: 60.0)
                            
                            fillLabelPlaceholderRect(origin: CGPoint(x: textFrame.minX, y: currentY + floor((itemHeight - fakeLabelPlaceholderHeight) / 2.0)), width: 120.0)
                            fillLabelPlaceholderRect(origin: CGPoint(x: textFrame.minX + 120.0 + 10.0, y: currentY + floor((itemHeight - fakeLabelPlaceholderHeight) / 2.0)), width: 60.0)
                            
                            let dateFrame = itemNode.dateNode.frame.offsetBy(dx: 0.0, dy: currentY)
                            fillLabelPlaceholderRect(origin: CGPoint(x: dateFrame.maxX - 30.0, y: dateFrame.minY), width: 30.0)
                            
                            context.setBlendMode(.normal)
                            context.setFillColor(presentationData.theme.chatList.itemSeparatorColor.cgColor)
                            context.fill(itemNode.separatorNode.frame.offsetBy(dx: 0.0, dy: currentY))
                            
                            context.setBlendMode(.normal)
                            context.setFillColor(presentationData.theme.chatList.itemSeparatorColor.cgColor)
                            context.fill(itemNode.separatorNode.frame.offsetBy(dx: 0.0, dy: currentY))
                        } else if let itemNode = itemNodes[sampleIndex] as? ListMessageFileItemNode {
                            var isVoice = false
                            if let media = itemNode.currentMedia as? TelegramMediaFile {
                                isVoice = media.isVoice
                                if media.isMusic || media.isVoice {
                                    context.fillEllipse(in: CGRect(x: 12.0 + selectionOffset, y: currentY + 8.0, width: 40.0, height: 40.0))
                                } else {
                                    let path = UIBezierPath(roundedRect: CGRect(x: 12.0 + selectionOffset, y: currentY + 8.0, width: 40.0, height: 40.0), cornerRadius: 6.0)
                                    context.addPath(path.cgPath)
                                    context.fillPath()
                                }
                            }
                            
                            let titleFrame = itemNode.titleNode.frame.offsetBy(dx: 0.0, dy: currentY)
                            fillLabelPlaceholderRect(origin: CGPoint(x: titleFrame.minX, y: floor(titleFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: isVoice ? 240.0 : 60.0)
                            
                            let descriptionFrame = itemNode.descriptionNode.frame.offsetBy(dx: 0.0, dy: currentY)
                            fillLabelPlaceholderRect(origin: CGPoint(x: descriptionFrame.minX, y: floor(descriptionFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: isVoice ? 60.0 : 240.0)
                            
                            let dateFrame = itemNode.dateNode.frame.offsetBy(dx: 0.0, dy: currentY)
                            fillLabelPlaceholderRect(origin: CGPoint(x: dateFrame.maxX - 30.0, y: floor(dateFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 30.0)
                            
                            context.setBlendMode(.normal)
                            context.setFillColor(presentationData.theme.chatList.itemSeparatorColor.cgColor)
                            context.fill(itemNode.separatorNode.frame.offsetBy(dx: 0.0, dy: currentY))
                        } else if let itemNode = itemNodes[sampleIndex] as? ListMessageSnippetItemNode {
                            let path = UIBezierPath(roundedRect: CGRect(x: 12.0 + selectionOffset, y: currentY + 12.0, width: 40.0, height: 40.0), cornerRadius: 6.0)
                            context.addPath(path.cgPath)
                            context.fillPath()
                            
                            let titleFrame = itemNode.titleNode.frame.offsetBy(dx: 0.0, dy: currentY)
                            fillLabelPlaceholderRect(origin: CGPoint(x: titleFrame.minX, y: floor(titleFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 120.0)
                            
                            let linkFrame = itemNode.linkNode.frame.offsetBy(dx: 0.0, dy: currentY - 1.0)
                            fillLabelPlaceholderRect(origin: CGPoint(x: linkFrame.minX, y: floor(linkFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 240.0)
                            
                            let authorFrame = itemNode.authorNode.frame.offsetBy(dx: 0.0, dy: currentY)
                            fillLabelPlaceholderRect(origin: CGPoint(x: authorFrame.minX, y: floor(authorFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 60.0)
                            
                            let dateFrame = itemNode.dateNode.frame.offsetBy(dx: 0.0, dy: currentY)
                            fillLabelPlaceholderRect(origin: CGPoint(x: dateFrame.maxX - 30.0, y: floor(dateFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 30.0)
                            
                            context.setBlendMode(.normal)
                            context.setFillColor(presentationData.theme.chatList.itemSeparatorColor.cgColor)
                            context.fill(itemNode.separatorNode.frame.offsetBy(dx: 0.0, dy: currentY))
                        }
                        
                        currentY += itemHeight
                    }
                }
            })
            
            self.effectNode.update(backgroundColor: presentationData.theme.list.mediaPlaceholderColor, foregroundColor: presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4))
            self.effectNode.updateAbsoluteRect(CGRect(origin: CGPoint(), size: size), within: size)
        }
        transition.updateFrame(node: self.backgroundColorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
        transition.updateFrame(node: self.maskNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
        transition.updateFrame(node: self.effectNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
    }
}

private final class ChatListSearchReferenceContentSource: ContextReferenceContentSource {
    private let sourceNode: ASDisplayNode
    var keepInPlace: Bool {
        return true
    }
    
    init(sourceNode: ASDisplayNode) {
        self.sourceNode = sourceNode
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds, actionsPosition: .bottom)
    }
}
