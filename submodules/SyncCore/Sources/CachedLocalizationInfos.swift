import Postbox

public final class CachedLocalizationInfos: PostboxCoding {
    public let list: [LocalizationInfo]
    
    public init(list: [LocalizationInfo]) {
        self.list = list
    }
    
    public init(decoder: PostboxDecoder) {
        self.list = decoder.decodeObjectArrayWithDecoderForKey("l")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.list, forKey: "l")
    }
}
