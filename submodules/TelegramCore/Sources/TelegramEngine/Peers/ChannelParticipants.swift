import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public struct RenderedChannelParticipant: Equatable {
    public let participant: ChannelParticipant
    public let peer: Peer
    public let peers: [PeerId: Peer]
    public let presences: [PeerId: PeerPresence]
    
    public init(participant: ChannelParticipant, peer: Peer, peers: [PeerId: Peer] = [:], presences: [PeerId: PeerPresence] = [:]) {
        self.participant = participant
        self.peer = peer
        self.peers = peers
        self.presences = presences
    }
    
    public static func ==(lhs: RenderedChannelParticipant, rhs: RenderedChannelParticipant) -> Bool {
        return lhs.participant == rhs.participant && lhs.peer.isEqual(rhs.peer)
    }
}
