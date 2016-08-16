import Foundation
import Postbox

extension Api.Message {
    var id: Int32 {
        switch self {
            case let .message(_, id, _, _, _, _, _, _, _, _, _, _, _, _):
                return id
            case let .messageEmpty(id):
                return id
            case let .messageService(_, id, _, _, _, _, _):
                return id
        }
    }
    
    var timestamp: Int32? {
        switch self {
            case let .message(_, _, _, _, _, _, _, date, _, _, _, _, _, _):
                return date
            case let .messageService(_, _, _, _, _, date, _):
                return date
            case .messageEmpty:
                return nil
        }
    }
}

extension Api.Chat {
    var peerId: PeerId {
        switch self {
            case let .chat(_, id, _, _, _, _, _, _):
                return PeerId(namespace: Namespaces.Peer.CloudGroup, id: id)
            case let .chatEmpty(id):
                return PeerId(namespace: Namespaces.Peer.CloudGroup, id: id)
            case let .chatForbidden(id, _):
                return PeerId(namespace: Namespaces.Peer.CloudGroup, id: id)
            case let .channel(_, id, _, _, _, _, _, _, _):
                return PeerId(namespace: Namespaces.Peer.CloudChannel, id: id)
            case let .channelForbidden(_, id, _, _):
                return PeerId(namespace: Namespaces.Peer.CloudChannel, id: id)
        }
    }
}

extension Api.User {
    var peerId: PeerId {
        switch self {
            case .user(_, let id, _, _, _, _, _, _, _, _, _, _):
                return PeerId(namespace: Namespaces.Peer.CloudUser, id: id)
            case let .userEmpty(id):
                return PeerId(namespace: Namespaces.Peer.CloudUser, id: id)
        }
    }
}

extension Api.Peer {
    var peerId: PeerId {
        switch self {
            case let .peerChannel(channelId):
                return PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
            case let .peerChat(chatId):
                return PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
            case let .peerUser(userId):
                return PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
        }
    }
}

extension Api.Dialog {
    var peerId: PeerId {
        switch self {
            case let .dialog(_, peer, _, _, _, _, _, _, _):
                return peer.peerId
        }
    }
}

extension Api.Update {
    var messageId: Int32? {
        switch self {
            case let .updateMessageID(id, _):
                return id
            case let .updateNewMessage(message, _, _):
                return message.id
            case let .updateNewChannelMessage(message, _, _):
                return message.id
            default:
                return nil
        }
    }
    
    var message: Api.Message? {
        switch self {
            case let .updateNewMessage(message, _, _):
                return message
            case let .updateNewChannelMessage(message, _, _):
                return message
            default:
                return nil
        }
    }
    
    var peerIds: [PeerId] {
        switch self {
            case let .updateChannel(channelId):
                return [PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)]
            case let .updateChannelTooLong(_, channelId, _):
                return [PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)]
            case let .updateChatAdmins(chatId, _, _):
                return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)]
            case let .updateChatParticipantAdd(chatId, userId, inviterId, _, _):
                return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId), PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), PeerId(namespace: Namespaces.Peer.CloudUser, id: inviterId)]
            case let .updateChatParticipantAdmin(chatId, userId, _, _):
                return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId), PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)]
            case let .updateChatParticipantDelete(chatId, userId, _):
                return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId), PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)]
            case let .updateChatParticipants(participants):
                switch participants {
                    case let .chatParticipants(chatId, _, _):
                        return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)]
                    case let .chatParticipantsForbidden(_, chatId, _):
                        return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)]
                }
            case let .updateContactRegistered(userId, _):
                return [PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)]
            case let .updateDeleteChannelMessages(channelId, _, _, _):
                return [PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)]
            case let .updateNewChannelMessage(message, _, _):
                return message.peerIds
            case let .updateNewMessage(message, _, _):
                return message.peerIds
            //case let .updateReadChannelInbox(channelId, _):
            //    return [PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)]
            case let .updateUserName(userId, _, _, _):
                return [PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)]
            case let .updateUserPhone(userId, _):
                return [PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)]
            case let .updateUserPhoto(userId, _, _, _):
                return [PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)]
            default:
                return []
        }
    }
    
    var associatedMessageIds: [MessageId]? {
        switch self {
            case let .updateNewMessage(message, _, _):
                return message.associatedMessageIds
            case let .updateNewChannelMessage(message, _, _):
                return message.associatedMessageIds
            default:
                break
        }
        return nil
    }
}

extension Api.Updates {
    var messageIds: [Int32] {
        switch self {
            case let .updates(updates, _, _, _, _):
                var result: [Int32] = []
                for update in updates {
                    if let id = update.messageId {
                        result.append(id)
                    }
                }
                return result
            case let .updatesCombined(updates, _, _, _, _, _):
                var result: [Int32] = []
                for update in updates {
                    if let id = update.messageId {
                        result.append(id)
                    }
                }
                return result
            case let .updateShort(update, _):
                if let id = update.messageId {
                    return [id]
                } else {
                    return []
                }
            case let .updateShortSentMessage(_, id, _, _, _, _, _):
                return [id]
            case .updatesTooLong:
                return []
            case let .updateShortMessage(_, id, _, _, _, _, _, _, _, _, _):
                return [id]
            case let .updateShortChatMessage(_, id, _, _, _, _, _, _, _, _, _, _):
                return [id]
        }
    }
}

extension Api.Updates {
    var messages: [Api.Message] {
        switch self {
            case let .updates(updates, _, _, _, _):
                var result: [Api.Message] = []
                for update in updates {
                    if let message = update.message {
                        result.append(message)
                    }
                }
                return result
            case let .updatesCombined(updates, _, _, _, _, _):
                var result: [Api.Message] = []
                for update in updates {
                    if let message = update.message {
                        result.append(message)
                    }
                }
                return result
            case let .updateShort(update, _):
                if let message = update.message {
                    return [message]
                } else {
                    return []
                }
            default:
                return []
        }
    }
}

