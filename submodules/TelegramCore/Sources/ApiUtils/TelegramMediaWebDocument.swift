import Foundation
import Postbox
import TelegramApi


extension TelegramMediaWebFile {
    convenience init(_ document: Api.WebDocument) {
        switch document {
            case let .webDocument(webDocumentData):
                let (url, accessHash, size, mimeType, attributes) = (webDocumentData.url, webDocumentData.accessHash, webDocumentData.size, webDocumentData.mimeType, webDocumentData.attributes)
                self.init(resource: WebFileReferenceMediaResource(url: url, size: Int64(size), accessHash: accessHash), mimeType: mimeType, size: size, attributes: telegramMediaFileAttributesFromApiAttributes(attributes))
            case let .webDocumentNoProxy(webDocumentNoProxyData):
                let (url, size, mimeType, attributes) = (webDocumentNoProxyData.url, webDocumentNoProxyData.size, webDocumentNoProxyData.mimeType, webDocumentNoProxyData.attributes)
                self.init(resource: HttpReferenceMediaResource(url: url, size: Int64(size)), mimeType: mimeType, size: size, attributes: telegramMediaFileAttributesFromApiAttributes(attributes))
        }
    }
}
