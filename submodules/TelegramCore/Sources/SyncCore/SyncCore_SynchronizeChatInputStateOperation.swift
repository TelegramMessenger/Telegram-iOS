import Postbox

public final class SynchronizeChatInputStateOperation: PostboxCoding {
    public let previousState: SynchronizeableChatInputState?
    public let threadId: Int64?
    
    public init(previousState: SynchronizeableChatInputState?, threadId: Int64?) {
        self.previousState = previousState
        self.threadId = threadId
    }
    
    public init(decoder: PostboxDecoder) {
        self.previousState = decoder.decode(SynchronizeableChatInputState.self, forKey: "p")
        self.threadId = decoder.decodeOptionalInt64ForKey("threadId")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let previousState = self.previousState {
            encoder.encode(previousState, forKey: "p")
        } else {
            encoder.encodeNil(forKey: "p")
        }
        if let threadId = self.threadId {
            encoder.encodeInt64(threadId, forKey: "threadId")
        } else {
            encoder.encodeNil(forKey: "threadId")
        }
    }
}
