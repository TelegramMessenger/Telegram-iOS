import Postbox

public final class SynchronizeChatInputStateOperation: PostboxCoding {
    public let previousState: SynchronizeableChatInputState?
    
    public init(previousState: SynchronizeableChatInputState?) {
        self.previousState = previousState
    }
    
    public init(decoder: PostboxDecoder) {
        self.previousState = decoder.decode(SynchronizeableChatInputState.self, forKey: "p")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let previousState = self.previousState {
            encoder.encode(previousState, forKey: "p")
        } else {
            encoder.encodeNil(forKey: "p")
        }
    }
}
