import Foundation
import Postbox
import TelegramApi


private func collectPreCachedResources(for photo: Api.Photo) -> [(MediaResource, Data)]? {
    switch photo {
        case let .photo(photoData):
            let (id, accessHash, fileReference, sizes, dcId) = (photoData.id, photoData.accessHash, photoData.fileReference, photoData.sizes, photoData.dcId)
            for size in sizes {
                switch size {
                    case let .photoCachedSize(photoCachedSizeData):
                        let (type, bytes) = (photoCachedSizeData.type, photoCachedSizeData.bytes)
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
        case let .document(documentData):
            let (id, accessHash, fileReference, thumbs, dcId) = (documentData.id, documentData.accessHash, documentData.fileReference, documentData.thumbs, documentData.dcId)
            if let thumbs = thumbs {
                for thumb in thumbs {
                    switch thumb {
                        case let .photoCachedSize(photoCachedSizeData):
                            let (type, bytes) = (photoCachedSizeData.type, photoCachedSizeData.bytes)
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
            case let .messageMediaPhoto(messageMediaPhotoData):
                let photo = messageMediaPhotoData.photo
                if let photo = photo {
                    return collectPreCachedResources(for: photo)
                } else {
                    return nil
                }
            case let .messageMediaDocument(messageMediaDocumentData):
                let document = messageMediaDocumentData.document
                if let document = document {
                    return collectPreCachedResources(for: document)
                }
                return nil
            case let .messageMediaWebPage(messageMediaWebPageData):
                let webpage = messageMediaWebPageData.webpage
                var result: [(MediaResource, Data)]?
                switch webpage {
                    case let .webPage(webPageData):
                        let (photo, document) = (webPageData.photo, webPageData.document)
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
    
    var preCachedStories: [StoryId: Api.StoryItem]? {
        switch self {
        case let .messageMediaStory(messageMediaStoryData):
            let (peer, id, story) = (messageMediaStoryData.peer, messageMediaStoryData.id, messageMediaStoryData.story)
            if let story = story {
                return [StoryId(peerId: peer.peerId, id: id): story]
            } else {
                return nil
            }
        default:
            return nil
        }
    }
}

extension Api.Message {
    var rawId: Int32 {
        switch self {
        case let .message(messageData):
                let id = messageData.id
                return id
            case let .messageEmpty(messageEmptyData):
                let id = messageEmptyData.id
                return id
            case let .messageService(messageServiceData):
                let id = messageServiceData.id
                return id
        }
    }
    
    func id(namespace: MessageId.Namespace = Namespaces.Message.Cloud) -> MessageId? {
        switch self {
            case let .message(messageData):
                let (flags2, id, messagePeerId) = (messageData.flags2, messageData.id, messageData.peerId)
                var namespace = namespace
                if (flags2 & (1 << 4)) != 0 {
                    namespace = Namespaces.Message.ScheduledCloud
                }
                let peerId: PeerId = messagePeerId.peerId
                return MessageId(peerId: peerId, namespace: namespace, id: id)
            case let .messageEmpty(messageEmptyData):
                let (id, peerId) = (messageEmptyData.id, messageEmptyData.peerId)
                if let peerId = peerId {
                    return MessageId(peerId: peerId.peerId, namespace: Namespaces.Message.Cloud, id: id)
                } else {
                    return nil
                }
            case let .messageService(messageServiceData):
                let (id, chatPeerId) = (messageServiceData.id, messageServiceData.peerId)
                let peerId: PeerId = chatPeerId.peerId
                return MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id)
        }
    }
    
    var peerId: PeerId? {
        switch self {
        case let .message(messageData):
            let messagePeerId = messageData.peerId
            let peerId: PeerId = messagePeerId.peerId
            return peerId
        case let .messageEmpty(messageEmptyData):
            let peerId = messageEmptyData.peerId
            return peerId?.peerId
        case let .messageService(messageServiceData):
            let chatPeerId = messageServiceData.peerId
            let peerId: PeerId = chatPeerId.peerId
            return peerId
        }
    }

    var timestamp: Int32? {
        switch self {
            case let .message(messageData):
                let date = messageData.date
                return date
            case let .messageService(messageServiceData):
                let date = messageServiceData.date
                return date
            case .messageEmpty:
                return nil
        }
    }
    
    var preCachedResources: [(MediaResource, Data)]? {
        switch self {
        case let .message(messageData):
            let media = messageData.media
            return media?.preCachedResources
        default:
            return nil
        }
    }

    var preCachedStories: [StoryId: Api.StoryItem]? {
        switch self {
        case let .message(messageData):
            let media = messageData.media
            return media?.preCachedStories
        default:
            return nil
        }
    }
}

extension Api.Chat {
    var peerId: PeerId {
        switch self {
            case let .chat(chatData):
                let id = chatData.id
                return PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(id))
            case let .chatEmpty(chatEmptyData):
                let id = chatEmptyData.id
                return PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(id))
            case let .chatForbidden(chatForbiddenData):
                let id = chatForbiddenData.id
                return PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(id))
            case let .channel(channelData):
                let id = channelData.id
                return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(id))
            case let .channelForbidden(channelForbiddenData):
                let id = channelForbiddenData.id
                return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(id))
        }
    }
}

extension Api.User {
    var peerId: PeerId {
        switch self {
            case let .user(userData):
                let id = userData.id
                return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))
            case let .userEmpty(userEmptyData):
                let id = userEmptyData.id
                return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))
        }
    }
}

extension Api.Peer {
    var peerId: PeerId {
        switch self {
            case let .peerChannel(peerChannelData):
                let channelId = peerChannelData.channelId
                return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
            case let .peerChat(peerChatData):
                let chatId = peerChatData.chatId
                return PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
            case let .peerUser(peerUserData):
                let userId = peerUserData.userId
                return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
        }
    }
}

extension Api.Dialog {
    var peerId: PeerId? {
        switch self {
            case let .dialog(dialogData):
                return dialogData.peer.peerId
            case .dialogFolder:
                return nil
        }
    }
}

extension Api.Update {
    var rawMessageId: Int32? {
        switch self {
            case let .updateMessageID(updateMessageIDData):
                let id = updateMessageIDData.id
                return id
            case let .updateNewMessage(updateNewMessageData):
                let message = updateNewMessageData.message
                return message.rawId
            case let .updateNewChannelMessage(updateNewChannelMessageData):
                let message = updateNewChannelMessageData.message
                return message.rawId
            default:
                return nil
        }
    }
    
    var updatedRawMessageId: (Int64, Int32)? {
        switch self {
            case let .updateMessageID(updateMessageIDData):
                let (id, randomId) = (updateMessageIDData.id, updateMessageIDData.randomId)
                return (randomId, id)
            default:
                return nil
        }
    }
    
    var messageId: MessageId? {
        switch self {
            case let .updateNewMessage(updateNewMessageData):
                let message = updateNewMessageData.message
                return message.id()
            case let .updateNewChannelMessage(updateNewChannelMessageData):
                let message = updateNewChannelMessageData.message
                return message.id()
            default:
                return nil
        }
    }
    
    var message: Api.Message? {
        switch self {
            case let .updateNewMessage(updateNewMessageData):
                let message = updateNewMessageData.message
                return message
            case let .updateNewChannelMessage(updateNewChannelMessageData):
                let message = updateNewChannelMessageData.message
                return message
            case let .updateEditMessage(updateEditMessageData):
                let message = updateEditMessageData.message
                return message
            case let .updateEditChannelMessage(updateEditChannelMessageData):
                let message = updateEditChannelMessageData.message
                return message
            case let .updateNewScheduledMessage(updateNewScheduledMessageData):
                let message = updateNewScheduledMessageData.message
                return message
            case let .updateQuickReplyMessage(updateQuickReplyMessageData):
                let message = updateQuickReplyMessageData.message
                return message
            default:
                return nil
        }
    }
    
    var peerIds: [PeerId] {
        switch self {
            case let .updateChannel(updateChannelData):
                let channelId = updateChannelData.channelId
                return [PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))]
            case let .updateChat(updateChatData):
                let chatId = updateChatData.chatId
                return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))]
            case let .updateChannelTooLong(updateChannelTooLongData):
                let channelId = updateChannelTooLongData.channelId
                return [PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))]
            case let .updateChatParticipantAdd(updateChatParticipantAddData):
                let (chatId, userId, inviterId) = (updateChatParticipantAddData.chatId, updateChatParticipantAddData.userId, updateChatParticipantAddData.inviterId)
                return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId)), PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(inviterId))]
            case let .updateChatParticipantAdmin(updateChatParticipantAdminData):
                let (chatId, userId) = (updateChatParticipantAdminData.chatId, updateChatParticipantAdminData.userId)
                return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId)), PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))]
            case let .updateChatParticipantDelete(updateChatParticipantDeleteData):
                let (chatId, userId) = (updateChatParticipantDeleteData.chatId, updateChatParticipantDeleteData.userId)
                return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId)), PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))]
            case let .updateChatParticipants(updateChatParticipantsData):
                let participants = updateChatParticipantsData.participants
                switch participants {
                    case let .chatParticipants(chatParticipantsData):
                        let chatId = chatParticipantsData.chatId
                        return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))]
                    case let .chatParticipantsForbidden(chatParticipantsForbiddenData):
                        let chatId = chatParticipantsForbiddenData.chatId
                        return [PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))]
                }
            case let .updateDeleteChannelMessages(updateDeleteChannelMessagesData):
                let channelId = updateDeleteChannelMessagesData.channelId
                return [PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))]
            case let .updatePinnedChannelMessages(updatePinnedChannelMessagesData):
                let channelId = updatePinnedChannelMessagesData.channelId
                return [PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))]
            case let .updateNewChannelMessage(updateNewChannelMessageData):
                let message = updateNewChannelMessageData.message
                return apiMessagePeerIds(message)
            case let .updateEditChannelMessage(updateEditChannelMessageData):
                let message = updateEditChannelMessageData.message
                return apiMessagePeerIds(message)
            case let .updateChannelWebPage(updateChannelWebPageData):
                let channelId = updateChannelWebPageData.channelId
                return [PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))]
            case let .updateNewMessage(updateNewMessageData):
                let message = updateNewMessageData.message
                return apiMessagePeerIds(message)
            case let .updateEditMessage(updateEditMessageData):
                let message = updateEditMessageData.message
                return apiMessagePeerIds(message)
            case let .updateReadChannelInbox(updateReadChannelInboxData):
                let channelId = updateReadChannelInboxData.channelId
                return [PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))]
            case let .updateNotifySettings(updateNotifySettingsData):
                let peer = updateNotifySettingsData.peer
                switch peer {
                    case let .notifyPeer(notifyPeerData):
                        let peer = notifyPeerData.peer
                        return [peer.peerId]
                    default:
                        return []
                }
            case let .updateUserName(updateUserNameData):
                let userId = updateUserNameData.userId
                return [PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))]
            case let .updateUserPhone(updateUserPhoneData):
                let userId = updateUserPhoneData.userId
                return [PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))]
            case let .updateServiceNotification(updateServiceNotificationData):
                let inboxDate = updateServiceNotificationData.inboxDate
                if let _ = inboxDate {
                    return [PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777000))]
                } else {
                    return []
                }
            case let .updateDraftMessage(updateDraftMessageData):
                let peer = updateDraftMessageData.peer
                return [peer.peerId]
            case let .updateNewScheduledMessage(updateNewScheduledMessageData):
                let message = updateNewScheduledMessageData.message
                return apiMessagePeerIds(message)
            case let .updateQuickReplyMessage(updateQuickReplyMessageData):
                let message = updateQuickReplyMessageData.message
                return apiMessagePeerIds(message)
            default:
                return []
        }
    }
    
    var associatedMessageIds: (replyIds: ReferencedReplyMessageIds, generalIds: [MessageId])? {
        switch self {
            case let .updateNewMessage(updateNewMessageData):
                let message = updateNewMessageData.message
                return apiMessageAssociatedMessageIds(message)
            case let .updateNewChannelMessage(updateNewChannelMessageData):
                let message = updateNewChannelMessageData.message
                return apiMessageAssociatedMessageIds(message)
            case let .updateEditChannelMessage(updateEditChannelMessageData):
                let message = updateEditChannelMessageData.message
                return apiMessageAssociatedMessageIds(message)
            case let .updateNewScheduledMessage(updateNewScheduledMessageData):
                let message = updateNewScheduledMessageData.message
                return apiMessageAssociatedMessageIds(message)
            case let .updateQuickReplyMessage(updateQuickReplyMessageData):
                let message = updateQuickReplyMessageData.message
                return apiMessageAssociatedMessageIds(message)
            default:
                break
        }
        return nil
    }
    
    var channelPts: Int32? {
        switch self {
            case let .updateNewChannelMessage(updateNewChannelMessageData):
                let pts = updateNewChannelMessageData.pts
                return pts
            case let .updateEditChannelMessage(updateEditChannelMessageData):
                let pts = updateEditChannelMessageData.pts
                return pts
            default:
                return nil
        }
    }
}

extension Api.Updates {
    var allUpdates: [Api.Update] {
        switch self {
        case let .updates(updatesData):
            let updates = updatesData.updates
            return updates
        case let .updatesCombined(updatesCombinedData):
            let updates = updatesCombinedData.updates
            return updates
        case let .updateShort(updateShortData):
            let update = updateShortData.update
            return [update]
        default:
            return []
        }
    }
}

extension Api.Updates {
    var rawMessageIds: [Int32] {
        switch self {
            case let .updates(updatesData):
                let updates = updatesData.updates
                var result: [Int32] = []
                for update in updates {
                    if let id = update.rawMessageId {
                        result.append(id)
                    }
                }
                return result
            case let .updatesCombined(updatesCombinedData):
                let updates = updatesCombinedData.updates
                var result: [Int32] = []
                for update in updates {
                    if let id = update.rawMessageId {
                        result.append(id)
                    }
                }
                return result
            case let .updateShort(updateShortData):
                let update = updateShortData.update
                if let id = update.rawMessageId {
                    return [id]
                } else {
                    return []
                }
            case let .updateShortSentMessage(updateShortSentMessageData):
                let id = updateShortSentMessageData.id
                return [id]
            case .updatesTooLong:
                return []
            case let .updateShortMessage(updateShortMessageData):
                let id = updateShortMessageData.id
                return [id]
            case let .updateShortChatMessage(updateShortChatMessageData):
                let id = updateShortChatMessageData.id
                return [id]
        }
    }
    
    var messageIds: [MessageId] {
        switch self {
            case let .updates(updatesData):
                let updates = updatesData.updates
                var result: [MessageId] = []
                for update in updates {
                    if let id = update.messageId {
                        result.append(id)
                    }
                }
                return result
            case let .updatesCombined(updatesCombinedData):
                let updates = updatesCombinedData.updates
                var result: [MessageId] = []
                for update in updates {
                    if let id = update.messageId {
                        result.append(id)
                    }
                }
                return result
            case let .updateShort(updateShortData):
                let update = updateShortData.update
                if let id = update.messageId {
                    return [id]
                } else {
                    return []
                }
            case .updateShortSentMessage:
                return []
            case .updatesTooLong:
                return []
            case let .updateShortMessage(updateShortMessageData):
                let (id, userId) = (updateShortMessageData.id, updateShortMessageData.userId)
                return [MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), namespace: Namespaces.Message.Cloud, id: id)]
            case let .updateShortChatMessage(updateShortChatMessageData):
                let (id, chatId) = (updateShortChatMessageData.id, updateShortChatMessageData.chatId)
                return [MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId)), namespace: Namespaces.Message.Cloud, id: id)]
        }
    }
    
    var updatedRawMessageIds: [Int64: Int32] {
        switch self {
            case let .updates(updatesData):
                let updates = updatesData.updates
                var result: [Int64: Int32] = [:]
                for update in updates {
                    if let (randomId, id) = update.updatedRawMessageId {
                        result[randomId] = id
                    }
                }
                return result
            case let .updatesCombined(updatesCombinedData):
                let updates = updatesCombinedData.updates
                var result: [Int64: Int32] = [:]
                for update in updates {
                    if let (randomId, id) = update.updatedRawMessageId {
                        result[randomId] = id
                    }
                }
                return result
            case let .updateShort(updateShortData):
                let update = updateShortData.update
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
            case let .updates(updatesData):
                let users = updatesData.users
                return users
            case let .updatesCombined(updatesCombinedData):
                let users = updatesCombinedData.users
               return users
            default:
                return []
        }
    }

    var messages: [Api.Message] {
        switch self {
            case let .updates(updatesData):
                let updates = updatesData.updates
                var result: [Api.Message] = []
                for update in updates {
                    if let message = update.message {
                        result.append(message)
                    }
                }
                return result
            case let .updatesCombined(updatesCombinedData):
                let updates = updatesCombinedData.updates
                var result: [Api.Message] = []
                for update in updates {
                    if let message = update.message {
                        result.append(message)
                    }
                }
                return result
            case let .updateShort(updateShortData):
                let update = updateShortData.update
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
            case let .updates(updatesData):
                let updates = updatesData.updates
                var result: Int32?
                for update in updates {
                    if let channelPts = update.channelPts {
                        if result == nil || channelPts > result! {
                            result = channelPts
                        }
                    }
                }
                return result
            case let .updatesCombined(updatesCombinedData):
                let updates = updatesCombinedData.updates
                var result: Int32?
                for update in updates {
                    if let channelPts = update.channelPts {
                        if result == nil || channelPts > result! {
                            result = channelPts
                        }
                    }
                }
                return result
            case let .updateShort(updateShortData):
                let update = updateShortData.update
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
        case let .updates(updatesData):
            let chats = updatesData.chats
            var result: [Api.Chat] = []
            for chat in chats {
                result.append(chat)
            }
            return result
        case let .updatesCombined(updatesCombinedData):
            let chats = updatesCombinedData.chats
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
            case let .encryptedChat(encryptedChatData):
                let id = encryptedChatData.id
                return PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(id)))
            case let .encryptedChatDiscarded(encryptedChatDiscardedData):
                let id = encryptedChatDiscardedData.id
                return PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(id)))
            case let .encryptedChatEmpty(encryptedChatEmptyData):
                let id = encryptedChatEmptyData.id
                return PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(id)))
            case let .encryptedChatRequested(encryptedChatRequestedData):
                let id = encryptedChatRequestedData.id
                return PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(id)))
            case let .encryptedChatWaiting(encryptedChatWaitingData):
                let id = encryptedChatWaitingData.id
                return PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(id)))
        }
    }
}

extension Api.EncryptedMessage {
    var peerId: PeerId {
        switch self {
            case let .encryptedMessage(encryptedMessageData):
                let chatId = encryptedMessageData.chatId
                return PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(chatId)))
            case let .encryptedMessageService(encryptedMessageServiceData):
                let chatId = encryptedMessageServiceData.chatId
                return PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(chatId)))
        }
    }
}

extension Api.InputMedia {
    func withUpdatedStickers(_ stickers: [Api.InputDocument]?) -> Api.InputMedia {
        switch self {
        case let .inputMediaUploadedDocument(inputMediaUploadedDocumentData):
            let (apiFlags, file, thumb, mimeType, apiAttributes, videoCover, videoTimestamp, ttlSeconds) = (inputMediaUploadedDocumentData.flags, inputMediaUploadedDocumentData.file, inputMediaUploadedDocumentData.thumb, inputMediaUploadedDocumentData.mimeType, inputMediaUploadedDocumentData.attributes, inputMediaUploadedDocumentData.videoCover, inputMediaUploadedDocumentData.videoTimestamp, inputMediaUploadedDocumentData.ttlSeconds)
            var flags = apiFlags
            var attributes = apiAttributes
            if let _ = stickers {
                flags |= (1 << 0)
                attributes.append(.documentAttributeHasStickers)
            }
            return .inputMediaUploadedDocument(.init(flags: flags, file: file, thumb: thumb, mimeType: mimeType, attributes: attributes, stickers: stickers, videoCover: videoCover, videoTimestamp: videoTimestamp, ttlSeconds: ttlSeconds))
        case let .inputMediaUploadedPhoto(inputMediaUploadedPhotoData):
            let (apiFlags, file, ttlSeconds) = (inputMediaUploadedPhotoData.flags, inputMediaUploadedPhotoData.file, inputMediaUploadedPhotoData.ttlSeconds)
            var flags = apiFlags
            if let _ = stickers {
                flags |= (1 << 0)
            }
            return .inputMediaUploadedPhoto(.init(flags: flags, file: file, stickers: stickers, ttlSeconds: ttlSeconds))
        default:
            return self
        }
    }
}
