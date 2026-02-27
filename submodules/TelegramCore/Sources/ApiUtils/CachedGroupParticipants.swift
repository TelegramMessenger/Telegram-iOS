import Foundation
import Postbox
import TelegramApi


extension GroupParticipant {
    init(apiParticipant: Api.ChatParticipant) {
        switch apiParticipant {
            case let .chatParticipantCreator(chatParticipantCreatorData):
                let userId = chatParticipantCreatorData.userId
                self = .creator(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)))
            case let .chatParticipantAdmin(chatParticipantAdminData):
                let (userId, inviterId, date) = (chatParticipantAdminData.userId, chatParticipantAdminData.inviterId, chatParticipantAdminData.date)
                self = .admin(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), invitedBy: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(inviterId)), invitedAt: date)
            case let .chatParticipant(chatParticipantData):
                let (userId, inviterId, date) = (chatParticipantData.userId, chatParticipantData.inviterId, chatParticipantData.date)
                self = .member(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), invitedBy: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(inviterId)), invitedAt: date)
        }
    }
}

extension CachedGroupParticipants {
    convenience init?(apiParticipants: Api.ChatParticipants) {
        switch apiParticipants {
            case let .chatParticipants(chatParticipantsData):
                let (participants, version) = (chatParticipantsData.participants, chatParticipantsData.version)
                self.init(participants: participants.map { GroupParticipant(apiParticipant: $0) }, version: version)
            case .chatParticipantsForbidden:
                return nil
        }
    }
}
