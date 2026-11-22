import Foundation
import TelegramCore

/// A paid-reaction leaderboard entry the sheet can draw: `peer` is nil for an anonymous sender.
struct ChatSendStarsShownTopPeer {
    let peer: EnginePeer?
    let isMy: Bool
    let count: Int
}

/// The leaderboard the sheet shows, most Stars first. A sender whose peer is not stored locally has no name or avatar to
/// draw, so it is skipped, and only then is the list cut to `limit`, so a longer list can fill the slot. A message's
/// reactions carry only the top three senders (and the account's own entry), so the sender being stored is what keeps
/// three on screen: the reactions poll stores the peers it receives (`updateReactionsForMessageIds`). An anonymous sender
/// is drawn without its peer, so it needs none.
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
