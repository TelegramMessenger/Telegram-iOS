import Foundation
import Postbox
import SwiftSignalKit

let supportChatHistoryLimit = 50

struct SupportChatHistory: Equatable {
    private(set) var peerIds: [PeerId] = []
    private(set) var position: Int = -1

    mutating func push(peerId: PeerId) {
        if self.position >= 0 && self.peerIds[self.position] == peerId {
            return
        }
        self.peerIds.removeLast(self.peerIds.count - self.position - 1)
        self.peerIds.removeAll(where: { $0 == peerId })
        self.peerIds.append(peerId)
        self.position = self.peerIds.count - 1
        if self.peerIds.count > supportChatHistoryLimit {
            self.peerIds.removeFirst()
            self.position -= 1
        }
    }

    func target(steps: Int) -> PeerId? {
        let position = self.position + steps
        guard !self.peerIds.isEmpty, position >= 0, position < self.peerIds.count else {
            return nil
        }
        return self.peerIds[position]
    }

    mutating func move(steps: Int) {
        if self.target(steps: steps) != nil {
            self.position += steps
        }
    }

    mutating func select(position: Int, peerId: PeerId) {
        if position >= 0, position < self.peerIds.count, self.peerIds[position] == peerId {
            self.position = position
        }
    }
}

public struct SupportActiveChat: Equatable {
    public let position: Int
    public let occurrence: Int
    public let peer: RecentlySearchedPeer
}

func supportActiveChatRows(peerIds: [PeerId]) -> [(position: Int, occurrence: Int, peerId: PeerId)] {
    var occurrences: [PeerId: Int] = [:]
    var rows: [(position: Int, occurrence: Int, peerId: PeerId)] = []
    for (position, peerId) in peerIds.enumerated() {
        let occurrence = occurrences[peerId, default: 0]
        occurrences[peerId] = occurrence + 1
        rows.append((position, occurrence, peerId))
    }
    return rows.reversed()
}

func _internal_supportActiveChats(account: Account) -> Signal<[SupportActiveChat], NoError> {
    guard let supportContext = account.supportContext else {
        return .single([])
    }
    let postbox = account.postbox
    return supportContext.chatHistoryPeerIds
    |> mapToSignal { peerIds -> Signal<[SupportActiveChat], NoError> in
        if peerIds.isEmpty {
            return .single([])
        }
        let uniquePeerIds = Array(Set(peerIds))
        let unreadCountsKey: PostboxViewKey = .unreadCounts(items: uniquePeerIds.map { UnreadMessageCountsItem.peer(id: $0, handleThreads: true) })
        var keys: [PostboxViewKey] = [unreadCountsKey]
        keys.append(contentsOf: uniquePeerIds.map { .peer(peerId: $0, components: .all) })

        return postbox.combinedView(keys: keys)
        |> map { view -> [SupportActiveChat] in
            var unreadCounts: [PeerId: Int32] = [:]
            if let unreadCountsView = view.views[unreadCountsKey] as? UnreadMessageCountsView {
                for entry in unreadCountsView.entries {
                    if case let .peer(peerId, state) = entry {
                        unreadCounts[peerId] = state?.count ?? 0
                    }
                }
            }

            var result: [SupportActiveChat] = []
            for row in supportActiveChatRows(peerIds: peerIds) {
                guard let peerView = view.views[.peer(peerId: row.peerId, components: .all)] as? PeerView, let peer = peerView.peers[row.peerId] else {
                    continue
                }
                var presence: TelegramUserPresence?
                if peer is TelegramSecretChat, let associatedPeerId = peer.associatedPeerId {
                    presence = peerView.peerPresences[associatedPeerId] as? TelegramUserPresence
                } else {
                    presence = peerView.peerPresences[row.peerId] as? TelegramUserPresence
                }
                var unreadCount = unreadCounts[row.peerId] ?? 0
                if let channel = peer as? TelegramChannel {
                    if case .member = channel.participationStatus {
                    } else {
                        unreadCount = 0
                    }
                }
                var subpeerSummary: RecentlySearchedPeerSubpeerSummary?
                if let cachedData = peerView.cachedData as? CachedChannelData {
                    subpeerSummary = RecentlySearchedPeerSubpeerSummary(count: Int(cachedData.participantsSummary.memberCount ?? 0))
                }
                result.append(SupportActiveChat(
                    position: row.position,
                    occurrence: row.occurrence,
                    peer: RecentlySearchedPeer(peer: RenderedPeer(peerId: row.peerId, peers: SimpleDictionary(peerView.peers), associatedMedia: peerView.media), presence: presence, notificationSettings: peerView.notificationSettings as? TelegramPeerNotificationSettings, unreadCount: unreadCount, subpeerSummary: subpeerSummary)
                ))
            }
            return result
        }
    }
}

public enum SupportHardwareKey: Hashable {
    case chatHistory
    case toggleMuted
    case reloadTemplates
    case composerReturn
    case escape
    case openAbuseBot

    var quietGap: Double {
        switch self {
        case .chatHistory, .escape:
            return 0.25
        case .toggleMuted, .reloadTemplates, .composerReturn, .openAbuseBot:
            return 0.8
        }
    }
}

// UIKit reports a held key as more presses and has no way to tell them apart before iOS 26, so a press
// counts only after a quiet gap, and every press restarts the gap. Holding Return must not walk the chats.
struct SupportHardwareKeyGate {
    private var lastPresses: [SupportHardwareKey: Double] = [:]

    mutating func allowsPress(of key: SupportHardwareKey, at timestamp: Double) -> Bool {
        let previous = self.lastPresses.updateValue(timestamp, forKey: key)
        guard let previous else {
            return true
        }
        return timestamp - previous >= key.quietGap
    }
}
