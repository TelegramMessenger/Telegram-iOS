import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
    import UIKit
#endif
import TelegramApi

public class TelegramMediaWebFile: Media {
    public let resource: TelegramMediaResource
    public let mimeType: String
    public let size: Int32
    public let attributes: [TelegramMediaFileAttribute]
    public let peerIds: [PeerId] = []
    
    public var id: MediaId? {
        return nil
    }
    
    public init(resource: TelegramMediaResource, mimeType: String, size: Int32, attributes: [TelegramMediaFileAttribute]) {
        self.resource = resource
        self.mimeType = mimeType
        self.size = size
        self.attributes = attributes
    }
    
    public required init(decoder: PostboxDecoder) {
        self.resource = decoder.decodeObjectForKey("r") as! TelegramMediaResource
        self.mimeType = decoder.decodeStringForKey("mt", orElse: "")
        self.size = decoder.decodeInt32ForKey("s", orElse: 0)
        self.attributes = decoder.decodeObjectArrayForKey("at")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.resource, forKey: "r")
        encoder.encodeString(self.mimeType, forKey: "mt")
        encoder.encodeInt32(self.size, forKey: "s")
        encoder.encodeObjectArray(self.attributes, forKey: "at")
    }
    
    public func isEqual(to other: Media) -> Bool {
        guard let other = other as? TelegramMediaWebFile else {
            return false
        }
        
        if !self.resource.isEqual(to: other.resource) {
            return false
        }
        
        if self.size != other.size {
            return false
        }
        
        if self.mimeType != other.mimeType {
            return false
        }

        return true
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }

    public var dimensions: CGSize? {
        return dimensionsForFileAttributes(self.attributes)
    }
    
    public var duration: Int32? {
        return durationForFileAttributes(self.attributes)
    }
}

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
