import Foundation
import Postbox

public enum TelegramMediaWebFileDecodingError: Error {
    case generic
}

public class TelegramMediaWebFile: Media, Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case data
    }
    
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
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try container.decode(Data.self, forKey: .data)
        let postboxDecoder = PostboxDecoder(buffer: MemoryBuffer(data: data))
        guard let object = postboxDecoder.decodeRootObject() as? TelegramMediaWebFile else {
            throw TelegramMediaWebFileDecodingError.generic
        }
        self.resource = object.resource
        self.mimeType = object.mimeType
        self.size = object.size
        self.attributes = object.attributes
    }
    
    public func encode(to encoder: Encoder) throws {
        let postboxEncoder = PostboxEncoder()
        postboxEncoder.encodeRootObject(self)
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(postboxEncoder.makeData(), forKey: .data)
    }
    
    public func isEqual(to other: Media) -> Bool {
        guard let other = other as? TelegramMediaWebFile else {
            return false
        }
        
        return self == other
    }
    
    public static func ==(lhs: TelegramMediaWebFile, rhs: TelegramMediaWebFile) -> Bool {
        if !lhs.resource.isEqual(to: rhs.resource) {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        if lhs.mimeType != rhs.mimeType {
            return false
        }
        return true
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
}
