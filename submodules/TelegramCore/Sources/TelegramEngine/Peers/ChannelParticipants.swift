import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit


public struct RenderedChannelParticipant: Equatable {
    public let participant: ChannelParticipant
    public let peer: EnginePeer
    public let peers: [EnginePeer.Id: EnginePeer]
    public let presences: [PeerId: PeerPresence]

    public init(participant: ChannelParticipant, peer: EnginePeer, peers: [EnginePeer.Id: EnginePeer] = [:], presences: [PeerId: PeerPresence] = [:]) {
        self.participant = participant
        self.peer = peer
        self.peers = peers
        self.presences = presences
    }

    public static func ==(lhs: RenderedChannelParticipant, rhs: RenderedChannelParticipant) -> Bool {
        return lhs.participant == rhs.participant && lhs.peer == rhs.peer
    }
}
