import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
#else
import Postbox
import SwiftSignalKit
#endif

public func deleteMessages(transaction: Transaction, mediaBox: MediaBox, ids: [MessageId]) {
    for id in ids {
        if id.peerId.namespace == Namespaces.Peer.SecretChat {
            if let message = transaction.getMessage(id) {
                for media in message.media {
                    if let image = media as? TelegramMediaImage {
                        let _ = mediaBox.removeCachedResources(Set(image.representations.map({ WrappedMediaResourceId($0.resource.id) }))).start()
                    } else if let file = media as? TelegramMediaFile {
                        let _ = mediaBox.removeCachedResources(Set(file.previewRepresentations.map({ WrappedMediaResourceId($0.resource.id) }))).start()
                        let _ = mediaBox.removeCachedResources(Set([WrappedMediaResourceId(file.resource.id)])).start()
                    }
                }
            }
        }
    }
    transaction.deleteMessages(ids)
}
