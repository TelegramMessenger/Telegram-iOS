import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
#else
import Postbox
import SwiftSignalKit
#endif

private func removeMessageMedia(message: Message, mediaBox: MediaBox) {
    for media in message.media {
        if let image = media as? TelegramMediaImage {
            let _ = mediaBox.removeCachedResources(Set(image.representations.map({ WrappedMediaResourceId($0.resource.id) }))).start()
        } else if let file = media as? TelegramMediaFile {
            let _ = mediaBox.removeCachedResources(Set(file.previewRepresentations.map({ WrappedMediaResourceId($0.resource.id) }))).start()
            let _ = mediaBox.removeCachedResources(Set([WrappedMediaResourceId(file.resource.id)])).start()
        }
    }
}

public func deleteMessages(transaction: Transaction, mediaBox: MediaBox, ids: [MessageId]) {
    for id in ids {
        if id.peerId.namespace == Namespaces.Peer.SecretChat {
            if let message = transaction.getMessage(id) {
                removeMessageMedia(message: message, mediaBox: mediaBox)
            }
        }
    }
    transaction.deleteMessages(ids, forEachMedia: { media in
        processRemovedMedia(mediaBox, media)
    })
}

public func deleteAllMessagesWithAuthor(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, authorId: PeerId, namespace: MessageId.Namespace) {
    transaction.removeAllMessagesWithAuthor(peerId, authorId: authorId, namespace: namespace, forEachMedia: { media in
        processRemovedMedia(mediaBox, media)
    })
}

public func clearHistory(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, namespaces: MessageIdNamespaces) {
    if peerId.namespace == Namespaces.Peer.SecretChat {
        transaction.withAllMessages(peerId: peerId, { message in
            removeMessageMedia(message: message, mediaBox: mediaBox)
            return true
        })
    }
    transaction.clearHistory(peerId, namespaces: namespaces, forEachMedia: { media in
        processRemovedMedia(mediaBox, media)
    })
}
