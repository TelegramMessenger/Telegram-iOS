import Foundation
import Postbox
import TelegramCore

func isServicePeer(_ peer: Peer) -> Bool {
    if let peer = peer as? TelegramUser {
        return (peer.id.namespace == Namespaces.Peer.CloudUser && (peer.id.id == 777000 || peer.id.id == 333000))
    }
    return false
}
