import Foundation
import SwiftSignalKit
import Display
import TelegramCore
import AccountContext

struct ChatListSearchSupportPresentation: Equatable {
    var hidesGlobalPeers: Bool = false
    var narrowPeerId: EnginePeer.Id?
    var selectedPeerId: EnginePeer.Id?
}

func supportSearchAppliesToPane(hasSupportContext: Bool, key: ChatListSearchPaneKey, location: ChatListControllerLocation) -> Bool {
    guard hasSupportContext, key == .chats, case .chatList = location else {
        return false
    }
    return true
}

func supportSearchSectionComesFirst(_ lhs: ChatListSearchEntry.MessageSection, _ rhs: ChatListSearchEntry.MessageSection) -> Bool? {
    let lhsIsPublicPost = lhs == .supportPublicPosts
    let rhsIsPublicPost = rhs == .supportPublicPosts
    if lhsIsPublicPost == rhsIsPublicPost {
        return nil
    }
    return rhsIsPublicPost
}

private let supportRecentHashtagNarrowedLimit = 5

func supportSearchedHashtag(_ text: String) -> String? {
    let hashtag = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard hashtag.count > 1, hashtag.hasPrefix("#"), !hashtag.contains(where: { $0.isWhitespace }) else {
        return nil
    }
    return hashtag
}

func supportRecentHashtags(_ hashtags: [String], matching query: String) -> [String] {
    let prefix = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard prefix.hasPrefix("#"), !prefix.contains(where: { $0.isWhitespace }) else {
        return []
    }
    let candidates = hashtags.filter { $0.hasPrefix("#") }
    if prefix == "#" {
        return candidates
    }
    let matches = candidates.filter { hashtag in
        let value = hashtag.lowercased()
        return value.hasPrefix(prefix) && value != prefix
    }
    return Array(matches.prefix(supportRecentHashtagNarrowedLimit))
}

func supportOneRowPerChat<Row>(_ rows: [Row], peerId: (Row) -> EnginePeer.Id, isRemoved: (Row) -> Bool, shownPeerIds: inout Set<EnginePeer.Id>) -> [Row] {
    var result: [Row] = []
    for row in rows where !isRemoved(row) {
        if shownPeerIds.insert(peerId(row)).inserted {
            result.append(row)
        }
    }
    return result
}

public func supportOneRowPerChat(messages: [EngineMessage]) -> [EngineMessage] {
    var shownPeerIds = Set<EnginePeer.Id>()
    return supportOneRowPerChat(messages, peerId: { message in
        return supportSearchRowPeer(message: message)?.id ?? message.id.peerId
    }, isRemoved: { _ in
        return false
    }, shownPeerIds: &shownPeerIds)
}

public func supportAllSearchResultsSignal(engine: TelegramEngine) -> Signal<Bool, NoError> {
    return engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: PreferencesKeys.supportSettings))
    |> map { entry -> Bool in
        return (entry?.get(SupportSettings.self) ?? .default).allSearchResults
    }
    |> distinctUntilChanged
}

// A message of a migrated group is drawn as its channel.
func supportSearchRowPeer(message: EngineMessage) -> EnginePeer? {
    if let group = message.peers[message.id.peerId] as? TelegramGroup, let migrationReference = group.migrationReference, let channel = message.peers[migrationReference.peerId] {
        return EnginePeer(channel)
    }
    return message.peers[message.id.peerId].flatMap(EnginePeer.init)
}

func supportSearchRowIsMuted(peer: EnginePeer, muteState: EnginePeer.NotificationSettings.MuteState?, privateChatsEnabled: Bool, groupChatsEnabled: Bool, channelsEnabled: Bool, timestamp: Int32) -> Bool {
    switch muteState {
    case let .muted(until):
        return until >= timestamp
    case .unmuted:
        return false
    case .default, .none:
        switch peer {
        case let .channel(channel):
            if case .broadcast = channel.info {
                return !channelsEnabled
            }
            return !groupChatsEnabled
        case .legacyGroup:
            return !groupChatsEnabled
        default:
            return !privateChatsEnabled
        }
    }
}

private func supportNarrowSearchPeerIndex(peer: EnginePeer) -> EngineChatList.Item.Index {
    return EngineChatList.Item.Index.chatList(EngineChatList.Item.Index.ChatList(pinningIndex: nil, messageIndex: EngineMessage.Index(id: EngineMessage.Id(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: 0), timestamp: 0)))
}

private func supportNarrowSearchPeerContent(peer: EnginePeer) -> ChatListItemContent {
    return .peer(ChatListItemContent.PeerData(
        messages: [],
        peer: EngineRenderedPeer(peer: peer),
        threadInfo: nil,
        combinedReadState: nil,
        isRemovedFromTotalUnreadCount: false,
        presence: nil,
        hasUnseenMentions: false,
        hasUnseenReactions: false,
        hasUnseenPollVotes: false,
        draftState: nil,
        mediaDraftContentType: nil,
        inputActivities: nil,
        promoInfo: nil,
        ignoreUnreadBadge: true,
        displayAsMessage: false,
        hasFailedMessages: false,
        forumTopicData: nil,
        topForumTopicItems: [],
        autoremoveTimeout: nil,
        storyState: nil,
        requiresPremiumForMessaging: false,
        displayAsTopicList: false,
        tags: []
    ))
}

func supportNarrowSearchPeerItem(context: AccountContext, presentationData: ChatListPresentationData, peer: EnginePeer, header: ListViewItemHeader?, interaction: ChatListNodeInteraction) -> ListViewItem {
    return ChatListItem(presentationData: presentationData, context: context, chatListLocation: .chatList(groupId: .root), filterData: nil, index: supportNarrowSearchPeerIndex(peer: peer), content: supportNarrowSearchPeerContent(peer: peer), editing: false, hasActiveRevealControls: false, selected: false, header: header, enabledContextActions: nil, hiddenOffset: false, interaction: interaction)
}

// A chat can be in this list twice, in Active and Recent: only the row that was tapped is marked.
final class SupportNarrowSearchRecentPeerItem: ChatListItem {
    let rowId: AnyHashable
    let isMarked: Bool
    private let onSelected: () -> Void

    init(context: AccountContext, presentationData: ChatListPresentationData, peer: EnginePeer, header: ListViewItemHeader?, interaction: ChatListNodeInteraction, rowId: AnyHashable, isMarked: Bool, onSelected: @escaping () -> Void) {
        self.rowId = rowId
        self.isMarked = isMarked
        self.onSelected = onSelected
        super.init(presentationData: presentationData, context: context, chatListLocation: .chatList(groupId: .root), filterData: nil, index: supportNarrowSearchPeerIndex(peer: peer), content: supportNarrowSearchPeerContent(peer: peer), editing: false, hasActiveRevealControls: false, selected: false, header: header, enabledContextActions: nil, hiddenOffset: false, interaction: interaction)
    }

    override func selected(listView: ListView) {
        self.onSelected()
    }
}
