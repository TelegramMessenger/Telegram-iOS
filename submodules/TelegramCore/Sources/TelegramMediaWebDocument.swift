import Foundation
import Postbox
import TelegramApi

import SyncCore

extension TelegramMediaWebFile {
    convenience init(_ document: Api.WebDocument) {
        switch document {
            case let .webDocument(data):
                self.init(resource: WebFileReferenceMediaResource(url: data.url, size: data.size, accessHash: data.accessHash), mimeType: data.mimeType, size: data.size, attributes: telegramMediaFileAttributesFromApiAttributes(data.attributes))
            case let .webDocumentNoProxy(url, size, mimeType, attributes):
                self.init(resource: HttpReferenceMediaResource(url: url, size: Int(size)), mimeType: mimeType, size: size, attributes: telegramMediaFileAttributesFromApiAttributes(attributes))
        }
    }
}
