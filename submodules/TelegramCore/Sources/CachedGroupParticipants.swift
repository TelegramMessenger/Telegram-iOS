import Foundation
import Postbox
import TelegramApi

import SyncCore

extension GroupParticipant {
    init(apiParticipant: Api.ChatParticipant) {
        switch apiParticipant {
            case let .chatParticipantCreator(userId):
                self = .creator(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId))
            case let .chatParticipantAdmin(userId, inviterId, date):
                self = .admin(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), invitedBy: PeerId(namespace: Namespaces.Peer.CloudUser, id: inviterId), invitedAt: date)
            case let .chatParticipant(userId, inviterId, date):
                self = .member(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), invitedBy: PeerId(namespace: Namespaces.Peer.CloudUser, id: inviterId), invitedAt: date)
        }
    }
}

extension CachedGroupParticipants {
    convenience init?(apiParticipants: Api.ChatParticipants) {
        switch apiParticipants {
            case let .chatParticipants(_, participants, version):
                self.init(participants: participants.map { GroupParticipant(apiParticipant: $0) }, version: version)
            case .chatParticipantsForbidden:
                return nil
        }
    }
}
