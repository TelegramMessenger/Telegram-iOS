import Postbox
import TelegramCore

public func extractPeerId(peer: Peer) -> Int64 {
    let enginePeer = EnginePeer(peer)
    
    let idText: String
    switch enginePeer {
    case .user, .legacyGroup, .secretChat:
        idText = "\(peer.id.id._internalGetInt64Value())"
    case .channel:
        idText = "-100\(peer.id.id._internalGetInt64Value())"
    }
    
    return Int64(idText) ?? peer.id.id._internalGetInt64Value()
}
