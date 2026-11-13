import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext

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
