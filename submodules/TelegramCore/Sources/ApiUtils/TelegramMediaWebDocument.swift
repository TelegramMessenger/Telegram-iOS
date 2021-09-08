import Foundation
import Postbox
import TelegramApi


extension TelegramMediaWebFile {
    convenience init(_ document: Api.WebDocument) {
        switch document {
            case let .webDocument(url, accessHash, size, mimeType, attributes):
                self.init(resource: WebFileReferenceMediaResource(url: url, size: size, accessHash: accessHash), mimeType: mimeType, size: size, attributes: telegramMediaFileAttributesFromApiAttributes(attributes))
            case let .webDocumentNoProxy(url, size, mimeType, attributes):
                self.init(resource: HttpReferenceMediaResource(url: url, size: Int(size)), mimeType: mimeType, size: size, attributes: telegramMediaFileAttributesFromApiAttributes(attributes))
        }
    }
}
