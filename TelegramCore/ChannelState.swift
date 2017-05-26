import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

final class ChannelState: PeerChatState, Equatable, CustomStringConvertible {
    let pts: Int32
    
    init(pts: Int32) {
        self.pts = pts
    }
    
    init(decoder: Decoder) {
        self.pts = decoder.decodeInt32ForKey("pts", orElse: 0)
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.pts, forKey: "pts")
    }
    
    func setPts(_ pts: Int32) -> ChannelState {
        return ChannelState(pts: pts)
    }
    
    func equals(_ other: PeerChatState) -> Bool {
        if let other = other as? ChannelState, other == self {
            return true
        }
        return false
    }
    
    var description: String {
        return "(pts: \(self.pts))"
    }
}

func ==(lhs: ChannelState, rhs: ChannelState) -> Bool {
    return lhs.pts == rhs.pts
}

struct ChannelUpdate {
    let update: Api.Update
    let ptsRange: (Int32, Int32)?
}

func channelUpdatesByPeerId(updates: [ChannelUpdate]) -> [PeerId: [ChannelUpdate]] {
    var grouped: [PeerId: [ChannelUpdate]] = [:]
    
    for update in updates {
        var peerId: PeerId?
        switch update.update {
            case let .updateNewChannelMessage(message, _, _):
                peerId = message.peerId
            case let .updateDeleteChannelMessages(channelId, _, _, _):
                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
            case let .updateEditChannelMessage(message, _, _):
                peerId = message.peerId
            case let .updateChannelWebPage(channelId, _, _, _):
                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
            default:
                break
        }
        
        if let peerId = peerId {
            if grouped[peerId] == nil {
                grouped[peerId] = [update]
            } else {
                grouped[peerId]!.append(update)
            }
        }
    }
    
    return grouped
}
