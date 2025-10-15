import Foundation
import Postbox

public final class SynchronizeConsumeMessageContentsOperation: PostboxCoding {
    public let messageIds: [MessageId]
    
    public init(messageIds: [MessageId]) {
        self.messageIds = messageIds
    }
    
    public init(decoder: PostboxDecoder) {
        self.messageIds = MessageId.decodeArrayFromBuffer(decoder.decodeBytesForKeyNoCopy("i")!)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let buffer = WriteBuffer()
        MessageId.encodeArrayToBuffer(self.messageIds, buffer: buffer)
        encoder.encodeBytes(buffer, forKey: "i")
    }
}
