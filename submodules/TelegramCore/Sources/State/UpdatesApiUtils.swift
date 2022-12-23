import Foundation
import Postbox
import TelegramApi


private func collectPreCachedResources(for photo: Api.Photo) -> [(MediaResource, Data)]? {
    switch photo {
        case let .photo(_, id, accessHash, fileReference, _, sizes, _, dcId):
            for size in sizes {
                switch size {
                    case let .photoCachedSize(type, _, _, bytes):
                        let resource = CloudPhotoSizeMediaResource(datacenterId: dcId, photoId: id, accessHash: accessHash, sizeSpec: type, size: nil, fileReference: fileReference.makeData())
                        let data = bytes.makeData()
                        return [(resource, data)]
                    default:
                        break
                }
            }
            return nil
        case .photoEmpty:
            return nil
    }
}

private func collectPreCachedResources(for document: Api.Document) -> [(MediaResource, Data)]? {
    switch document {
        case let .document(_, id, accessHash, fileReference, _, _, _, thumbs, _, dcId, _):
            if let thumbs = thumbs {
                for thumb in thumbs {
                    switch thumb {
                        case let .photoCachedSize(type, _, _, bytes):
                            let resource = CloudDocumentSizeMediaResource(datacenterId: dcId, documentId: id, accessHash: accessHash, sizeSpec: type, fileReference: fileReference.makeData())
                            let data = bytes.makeData()
                            return [(resource, data)]
                        default:
                            break
                    }
                }
            }
        default:
            break
    }
    return nil
}

extension Api.MessageMedia {
    var preCachedResources: [(MediaResource, Data)]? {
        switch self {
            case let .messageMediaPhoto(_, photo, _):
                if let photo = photo {
                    return collectPreCachedResources(for: photo)
                } else {
                    return nil
                }
            case let .messageMediaDocument(_, document, _):
                if let document = document {
                    return collectPreCachedResources(for: document)
                }
                return nil
            case let .messageMediaWebPage(webPage):
                var result: [(MediaResource, Data)]?
                switch webPage {
                    case let .webPage(_, _, _, _, _, _, _, _, _, photo, _, _, _, _, _, _, document, _, _):
                        if let photo = photo {
                            if let photoResult = collectPreCachedResources(for: photo) {
                                if result == nil {
                                    result = []
                                }
                                result!.append(contentsOf: photoResult)
                            }
                        }
                        if let file = document {
                            if let fileResult = collectPreCachedResources(for: file) {
                                if result == nil {
                                    result = []
                                }
                                result!.append(contentsOf: fileResult)
                            }
                        }
                    default:
                        break
                }
                return result
            default:
                return nil
        }
    }
}

extension Api.Message {
    var rawId: Int32 {
        switch self {
        case let .message(_, id, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                return id
            case let .messageEmpty(_, id, _):
                return id
            case let .messageService(_, id, _, _, _, _, _, _):
                return id
        }
    }
    
    func id(namespace: MessageId.Namespace = Namespaces.Message.Cloud) -> MessageId? {
        switch self {
            case let .message(_, id, _, messagePeerId, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                let peerId: PeerId = messagePeerId.peerId
                return MessageId(peerId: peerId, namespace: namespace, id: id)
            case let .messageEmpty(_, id, peerId):
                if let peerId = peerId {
                    return MessageId(peerId: peerId.peerId, namespace: Namespaces.Message.Cloud, id: id)
                } else {
                    return nil
                }
            case let .messageService(_, id, _, chatPeerId, _, _, _, _):
                let peerId: PeerId = chatPeerId.peerId
                return MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id)
        }
    }

    var timestamp: Int32? {
        switch self {
            case let .message(_, _, _, _, _, _, _, date, _, _, _, _, _, _, _, _, _, _, _, _, _):
                return date
            case let .messageService(_, _, _, _, _, date, _, _):
                return date
            case .messageEmpty:
                return nil
        }
    }
    
    var preCachedResources: [(MediaResource, Data)]? {
        switch self {
            case let .message(_, _, _, _, _, _, _, _, _, media, _, _, _, _, _, _, _, _, _, _, _):
                return media?.preCachedResources
            default:
                return nil
        }
    }
}

extension Api.Chat {
    var peerId: PeerId {
        switch self {
            case let .chat(_, id, _, _, _, _, _, _, _, _):
                return PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(id))
            case let .chatEmpty(id):
                return PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(id))
            case let .chatForbidden(id, _):
                return PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(id))
            case let .channel(_, _, id, _, _, _, _, _, _, _, _, _, _, _):
                return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(id))
            case let .channelForbidden(_, id, _, _, _):
                return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(id))
        }
    }
}

extension Api.User {
    var peerId: PeerId {
        switch self {
            case let .user(_, _, id, _, _, _, _, _, _, _, _, _, _, _, _, _):
                return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))
            case let .userEmpty(id):
                return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))
        }
    }
}

extension Api.Peer {
    var peerId: PeerId {
        switch self {
            case let .peerChannel(channelId):
                return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
            case let .peerChat(chatId):
                return PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
            case let .peerUser(userId):
                return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
        }
    }
}

extension Api.Dialog {
    var peerId: PeerId? {
        switch self {
            case let .dialog(_, peer, _, _, _, _, _, _, _, _, _, _):
                return peer.peerId
            case .dialogFolder:
                return nil
        }
    }
}

extension Api.Update {
    var rawMessageId: Int32? {
        switch self {
            case let .updateMessageID(id, _):
                return id
            case let .updateNewMessage(message, _, _):
                return message.rawId
            case let .updateNewChannelMessage(message, _, _):
                return message.rawId
            default:
                return nil
        }
    }
    
    var updatedRawMessageId: (Int64, Int32)? {
        switch self {
            case let .updateMessageID(id, randomId):
                return (randomId, id)
            default:
                return nil
        }
    }
    
    var messageId: MessageId? {
        switch self {
            case let .updateNewMessage(message, _, _):
                return message.id()
            case let .updateNewChannelMessage(message, _, _):
                return message.id()
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
            case let .updateEditMessage(message, _, _):
                return message
            case let .updateEditChannelMessage(message, _, _):
                return message
            case let .updateNewScheduledMessage(message):
                return message
            default:
                return nil
        }
    }
    
    var peerIds: [PeerId] {
        switch self {
            case let .updateChannel(channelId):
                return [PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))]
            case let .updateChat(chatId):
                return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))]
            case let .updateChannelTooLong(_, channelId, _):
                return [PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))]
            case let .updateChatParticipantAdd(chatId, userId, inviterId, _, _):
                return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId)), PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(inviterId))]
            case let .updateChatParticipantAdmin(chatId, userId, _, _):
                return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId)), PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))]
            case let .updateChatParticipantDelete(chatId, userId, _):
                return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId)), PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))]
            case let .updateChatParticipants(participants):
                switch participants {
                    case let .chatParticipants(chatId, _, _):
                        return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))]
                    case let .chatParticipantsForbidden(_, chatId, _):
                        return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))]
                }
            case let .updateDeleteChannelMessages(channelId, _, _, _):
                return [PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))]
            case let .updatePinnedChannelMessages(_, channelId, _, _, _):
                return [PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))]
            case let .updateNewChannelMessage(message, _, _):
                return apiMessagePeerIds(message)
            case let .updateEditChannelMessage(message, _, _):
                return apiMessagePeerIds(message)
            case let .updateChannelWebPage(channelId, _, _, _):
                return [PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))]
            case let .updateNewMessage(message, _, _):
                return apiMessagePeerIds(message)
            case let .updateEditMessage(message, _, _):
                return apiMessagePeerIds(message)
            case let .updateReadChannelInbox(_, _, channelId, _, _, _):
                return [PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))]
            case let .updateNotifySettings(peer, _):
                switch peer {
                    case let .notifyPeer(peer):
                        return [peer.peerId]
                    default:
                        return []
                }
            case let .updateUserName(userId, _, _, _):
                return [PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))]
            case let .updateUserPhone(userId, _):
                return [PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))]
            case let .updateUserPhoto(userId, _, _, _):
                return [PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))]
            case let .updateServiceNotification(_, inboxDate, _, _, _, _):
                if let _ = inboxDate {
                    return [PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777000))]
                } else {
                    return []
                }
            case let .updateDraftMessage(_, peer, _, _):
                return [peer.peerId]
            case let .updateNewScheduledMessage(message):
                return apiMessagePeerIds(message)
            default:
                return []
        }
    }
    
    var associatedMessageIds: [MessageId]? {
        switch self {
            case let .updateNewMessage(message, _, _):
                return apiMessageAssociatedMessageIds(message)
            case let .updateNewChannelMessage(message, _, _):
                return apiMessageAssociatedMessageIds(message)
            case let .updateEditChannelMessage(message, _, _):
                return apiMessageAssociatedMessageIds(message)
            case let .updateNewScheduledMessage(message):
                return apiMessageAssociatedMessageIds(message)
            default:
                break
        }
        return nil
    }
    
    var channelPts: Int32? {
        switch self {
            case let .updateNewChannelMessage(_, pts, _):
                return pts
            case let .updateEditChannelMessage(_, pts, _):
                return pts
            default:
                return nil
        }
    }
}

extension Api.Updates {
    var allUpdates: [Api.Update] {
        switch self {
        case let .updates(updates, _, _, _, _):
            return updates
        case let .updatesCombined(updates, _, _, _, _, _):
            return updates
        case let .updateShort(update, _):
            return [update]
        default:
            return []
        }
    }
}

extension Api.Updates {
    var rawMessageIds: [Int32] {
        switch self {
            case let .updates(updates, _, _, _, _):
                var result: [Int32] = []
                for update in updates {
                    if let id = update.rawMessageId {
                        result.append(id)
                    }
                }
                return result
            case let .updatesCombined(updates, _, _, _, _, _):
                var result: [Int32] = []
                for update in updates {
                    if let id = update.rawMessageId {
                        result.append(id)
                    }
                }
                return result
            case let .updateShort(update, _):
                if let id = update.rawMessageId {
                    return [id]
                } else {
                    return []
                }
            case let .updateShortSentMessage(_, id, _, _, _, _, _, _):
                return [id]
            case .updatesTooLong:
                return []
            case let .updateShortMessage(_, id, _, _, _, _, _, _, _, _, _, _):
                return [id]
            case let .updateShortChatMessage(_, id, _, _, _, _, _, _, _, _, _, _, _):
                return [id]
        }
    }
    
    var messageIds: [MessageId] {
        switch self {
            case let .updates(updates, _, _, _, _):
                var result: [MessageId] = []
                for update in updates {
                    if let id = update.messageId {
                        result.append(id)
                    }
                }
                return result
            case let .updatesCombined(updates, _, _, _, _, _):
                var result: [MessageId] = []
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
            case .updateShortSentMessage:
                return []
            case .updatesTooLong:
                return []
            case let .updateShortMessage(_, id, userId, _, _, _, _, _, _, _, _, _):
                return [MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), namespace: Namespaces.Message.Cloud, id: id)]
            case let .updateShortChatMessage(_, id, _, chatId, _, _, _, _, _, _, _, _, _):
                return [MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId)), namespace: Namespaces.Message.Cloud, id: id)]
        }
    }
    
    var updatedRawMessageIds: [Int64: Int32] {
        switch self {
            case let .updates(updates, _, _, _, _):
                var result: [Int64: Int32] = [:]
                for update in updates {
                    if let (randomId, id) = update.updatedRawMessageId {
                        result[randomId] = id
                    }
                }
                return result
            case let .updatesCombined(updates, _, _, _, _, _):
                var result: [Int64: Int32] = [:]
                for update in updates {
                    if let (randomId, id) = update.updatedRawMessageId {
                        result[randomId] = id
                    }
                }
                return result
            case let .updateShort(update, _):
                if let (randomId, id) = update.updatedRawMessageId {
                    return [randomId: id]
                } else {
                    return [:]
                }
            case .updateShortSentMessage:
                return [:]
            case .updatesTooLong:
                return [:]
            case .updateShortMessage:
                return [:]
            case .updateShortChatMessage:
                return [:]
        }
    }
}

extension Api.Updates {
    var users: [Api.User] {
        switch self {
            case let .updates(_, users, _, _, _):
                return users
            case let .updatesCombined(_, users, _, _, _, _):
               return users
            default:
                return []
        }
    }
    
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
    
    var channelPts: Int32? {
        switch self {
            case let .updates(updates, _, _, _, _):
                var result: Int32?
                for update in updates {
                    if let channelPts = update.channelPts {
                        if result == nil || channelPts > result! {
                            result = channelPts
                        }
                    }
                }
                return result
            case let .updatesCombined(updates, _, _, _, _, _):
                var result: Int32?
                for update in updates {
                    if let channelPts = update.channelPts {
                        if result == nil || channelPts > result! {
                            result = channelPts
                        }
                    }
                }
                return result
            case let .updateShort(update, _):
                if let channelPts = update.channelPts {
                    return channelPts
                } else {
                    return nil
                }
            default:
                return nil
        }
    }
}

extension Api.Updates {
    var chats: [Api.Chat] {
        switch self {
        case let .updates(_, _, chats, _, _):
            var result: [Api.Chat] = []
            for chat in chats {
                result.append(chat)
            }
            return result
        case let .updatesCombined(_, _, chats, _, _, _):
            var result: [Api.Chat] = []
            for chat in chats {
                result.append(chat)
            }
            return result
        default:
            return []
        }
    }
}

extension Api.EncryptedChat {
    var peerId: PeerId {
        switch self {
            case let .encryptedChat(id, _, _, _, _, _, _):
                return PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(id)))
            case let .encryptedChatDiscarded(_, id):
                return PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(id)))
            case let .encryptedChatEmpty(id):
                return PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(id)))
            case let .encryptedChatRequested(_, _, id, _, _, _, _, _):
                return PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(id)))
            case let .encryptedChatWaiting(id, _, _, _, _):
                return PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(id)))
        }
    }
}

extension Api.EncryptedMessage {
    var peerId: PeerId {
        switch self {
            case let .encryptedMessage(_, chatId, _, _, _):
                return PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(chatId)))
            case let .encryptedMessageService(_, chatId, _, _):
                return PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(chatId)))
        }
    }
}
