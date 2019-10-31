import Postbox

public final class SynchronizeChatInputStateOperation: PostboxCoding {
    public let previousState: SynchronizeableChatInputState?
    
    public init(previousState: SynchronizeableChatInputState?) {
        self.previousState = previousState
    }
    
    public init(decoder: PostboxDecoder) {
        self.previousState = decoder.decodeObjectForKey("p", decoder: { SynchronizeableChatInputState(decoder: $0) }) as? SynchronizeableChatInputState
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let previousState = self.previousState {
            encoder.encodeObject(previousState, forKey: "p")
        } else {
            encoder.encodeNil(forKey: "p")
        }
    }
}
