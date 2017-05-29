import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

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
    
    public required init(decoder: Decoder) {
        self.resource = decoder.decodeObjectForKey("r") as! TelegramMediaResource
        self.mimeType = decoder.decodeStringForKey("mt", orElse: "")
        self.size = decoder.decodeInt32ForKey("s", orElse: 0)
        self.attributes = decoder.decodeObjectArrayForKey("at")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeObject(self.resource, forKey: "r")
        encoder.encodeString(self.mimeType, forKey: "mt")
        encoder.encodeInt32(self.size, forKey: "s")
        encoder.encodeObjectArray(self.attributes, forKey: "at")
    }
    
    public func isEqual(_ other: Media) -> Bool {
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


}

extension TelegramMediaWebFile {
    convenience init(_ document:Api.WebDocument) {
        switch document {
        case let .webDocument(data):
            self.init(resource: WebFileReferenceMediaResource(url: data.url, size: data.size, datacenterId: data.dcId, accessHash: data.accessHash), mimeType: data.mimeType, size: data.size, attributes: telegramMediaFileAttributesFromApiAttributes(data.attributes))
        }
    }
}
