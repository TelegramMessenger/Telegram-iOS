import Foundation
import Postbox
import TelegramCore
import PersistentStringHash

public struct InstantPageExternalMediaResourceId {
    public let url: String

    public var uniqueId: String {
        return "instantpage-media-\(persistentHash32(self.url))"
    }
    
    public var hashValue: Int {
        return self.uniqueId.hashValue
    }
}

public class InstantPageExternalMediaResource: TelegramMediaResource {
    public let url: String
    
    public var size: Int64? {
        return nil
    }
    
    public init(url: String) {
        self.url = url
    }
    
    public required init(decoder: PostboxDecoder) {
        self.url = decoder.decodeStringForKey("u", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.url, forKey: "u")
    }
    
    public var id: MediaResourceId {
        return MediaResourceId(InstantPageExternalMediaResourceId(url: self.url).uniqueId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? InstantPageExternalMediaResource {
            return self.url == to.url
        } else {
            return false
        }
    }
}
