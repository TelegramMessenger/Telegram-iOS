import Foundation
import TelegramCore

/// A paid-reaction leaderboard entry the sheet can draw: `peer` is nil for an anonymous sender.
struct ChatSendStarsShownTopPeer {
    let peer: EnginePeer?
    let isMy: Bool
    let count: Int
}

/// The leaderboard the sheet shows, most Stars first. A sender whose peer is not stored locally has no name or avatar to
/// draw, so it is skipped before the list is cut to `limit` and the next sender takes its slot; cutting first left the
/// sheet with fewer senders than the message has. An anonymous sender is drawn without its peer, so it needs none.
func chatSendStarsShownTopPeers(_ topPeers: [ReactionsMessageAttribute.TopPeer], peer: (EnginePeer.Id) -> EnginePeer?, limit: Int) -> [ChatSendStarsShownTopPeer] {
    let shown = topPeers.sorted(by: { $0.count > $1.count }).compactMap { topPeer -> ChatSendStarsShownTopPeer? in
        guard let topPeerId = topPeer.peerId, !topPeer.isAnonymous else {
            return ChatSendStarsShownTopPeer(peer: nil, isMy: topPeer.isMy, count: Int(topPeer.count))
        }
        guard let topPeerValue = peer(topPeerId) else {
            return nil
        }
        return ChatSendStarsShownTopPeer(peer: topPeerValue, isMy: topPeer.isMy, count: Int(topPeer.count))
    }
    return Array(shown.prefix(limit))
}
