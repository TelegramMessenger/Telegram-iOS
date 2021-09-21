import Postbox

public final class ReactionsMessageAttribute: MessageAttribute {
    public init() {
    }
    
    required public init(decoder: PostboxDecoder) {
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
}

public final class PendingReactionsMessageAttribute: MessageAttribute {
    public let value: String?
    
    public init(value: String?) {
        self.value = value
    }
    
    required public init(decoder: PostboxDecoder) {
        self.value = decoder.decodeOptionalStringForKey("v")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let value = self.value {
            encoder.encodeString(value, forKey: "v")
        } else {
            encoder.encodeNil(forKey: "v")
        }
    }
}
