import Foundation
import Postbox
import SwiftSignalKit

import SyncCore

func addMessageMediaResourceIdsToRemove(media: Media, resourceIds: inout [WrappedMediaResourceId]) {
    if let image = media as? TelegramMediaImage {
        for representation in image.representations {
            resourceIds.append(WrappedMediaResourceId(representation.resource.id))
        }
    } else if let file = media as? TelegramMediaFile {
        for representation in file.previewRepresentations {
            resourceIds.append(WrappedMediaResourceId(representation.resource.id))
        }
        resourceIds.append(WrappedMediaResourceId(file.resource.id))
    }
}

func addMessageMediaResourceIdsToRemove(message: Message, resourceIds: inout [WrappedMediaResourceId]) {
    for media in message.media {
        addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
    }
}

public func deleteMessages(transaction: Transaction, mediaBox: MediaBox, ids: [MessageId], deleteMedia: Bool = true, manualAddMessageThreadStatsDifference: ((MessageId, Int, Int) -> Void)? = nil) {
    var resourceIds: [WrappedMediaResourceId] = []
    if deleteMedia {
        for id in ids {
            if id.peerId.namespace == Namespaces.Peer.SecretChat {
                if let message = transaction.getMessage(id) {
                    addMessageMediaResourceIdsToRemove(message: message, resourceIds: &resourceIds)
                }
            }
        }
    }
    if !resourceIds.isEmpty {
        let _ = mediaBox.removeCachedResources(Set(resourceIds)).start()
    }
    for id in ids {
        if id.peerId.namespace == Namespaces.Peer.CloudChannel && id.namespace == Namespaces.Message.Cloud {
            if let message = transaction.getMessage(id) {
                if let threadId = message.threadId {
                    let messageThreadId = makeThreadIdMessageId(peerId: message.id.peerId, threadId: threadId)
                    if id.peerId.namespace == Namespaces.Peer.CloudChannel {
                        if let manualAddMessageThreadStatsDifference = manualAddMessageThreadStatsDifference {
                            manualAddMessageThreadStatsDifference(messageThreadId, 0, 1)
                        } else {
                            updateMessageThreadStats(transaction: transaction, threadMessageId: messageThreadId, removedCount: 1, addedMessagePeers: [])
                        }
                    }
                }
            }
        }
    }
    transaction.deleteMessages(ids, forEachMedia: { _ in
    })
}

public func deleteAllMessagesWithAuthor(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, authorId: PeerId, namespace: MessageId.Namespace) {
    var resourceIds: [WrappedMediaResourceId] = []
    transaction.removeAllMessagesWithAuthor(peerId, authorId: authorId, namespace: namespace, forEachMedia: { media in
        addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
    })
    if !resourceIds.isEmpty {
        let _ = mediaBox.removeCachedResources(Set(resourceIds)).start()
    }
}

public func deleteAllMessagesWithForwardAuthor(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, forwardAuthorId: PeerId, namespace: MessageId.Namespace) {
    var resourceIds: [WrappedMediaResourceId] = []
    transaction.removeAllMessagesWithForwardAuthor(peerId, forwardAuthorId: forwardAuthorId, namespace: namespace, forEachMedia: { media in
        addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
    })
    if !resourceIds.isEmpty {
        let _ = mediaBox.removeCachedResources(Set(resourceIds)).start()
    }
}

public func clearHistory(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, namespaces: MessageIdNamespaces) {
    if peerId.namespace == Namespaces.Peer.SecretChat {
        var resourceIds: [WrappedMediaResourceId] = []
        transaction.withAllMessages(peerId: peerId, { message in
            addMessageMediaResourceIdsToRemove(message: message, resourceIds: &resourceIds)
            return true
        })
        if !resourceIds.isEmpty {
            let _ = mediaBox.removeCachedResources(Set(resourceIds)).start()
        }
    }
    transaction.clearHistory(peerId, namespaces: namespaces, forEachMedia: { _ in
    })
}
