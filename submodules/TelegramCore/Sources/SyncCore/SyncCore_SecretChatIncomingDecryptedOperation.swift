import Foundation
import Postbox


public struct SecretChatOperationSequenceInfo: PostboxCoding {
    public let topReceivedOperationIndex: Int32
    public let operationIndex: Int32
    
    public init(topReceivedOperationIndex: Int32, operationIndex: Int32) {
        self.topReceivedOperationIndex = topReceivedOperationIndex
        self.operationIndex = operationIndex
    }
    
    public init(decoder: PostboxDecoder) {
        self.topReceivedOperationIndex = decoder.decodeInt32ForKey("r", orElse: 0)
        self.operationIndex = decoder.decodeInt32ForKey("o", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.topReceivedOperationIndex, forKey: "r")
        encoder.encodeInt32(self.operationIndex, forKey: "o")
    }
}

public final class SecretChatIncomingDecryptedOperation: PostboxCoding {
    public let timestamp: Int32
    public let layer: Int32
    public let sequenceInfo: SecretChatOperationSequenceInfo?
    public let contents: MemoryBuffer
    public let file: SecretChatFileReference?
    
    public init(timestamp: Int32, layer: Int32, sequenceInfo: SecretChatOperationSequenceInfo?, contents: MemoryBuffer, file: SecretChatFileReference?) {
        self.timestamp = timestamp
        self.layer = layer
        self.sequenceInfo = sequenceInfo
        self.contents = contents
        self.file = file
    }
    
    public init(decoder: PostboxDecoder) {
        self.timestamp = decoder.decodeInt32ForKey("t", orElse: 0)
        self.layer = decoder.decodeInt32ForKey("l", orElse: 0)
        self.sequenceInfo = decoder.decodeObjectForKey("s", decoder: { SecretChatOperationSequenceInfo(decoder: $0) }) as? SecretChatOperationSequenceInfo
        self.contents = decoder.decodeBytesForKey("c")!
        self.file = decoder.decodeObjectForKey("f", decoder: { SecretChatFileReference(decoder: $0) }) as? SecretChatFileReference
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.timestamp, forKey: "t")
        encoder.encodeInt32(self.layer, forKey: "l")
        if let sequenceInfo = self.sequenceInfo {
            encoder.encodeObject(sequenceInfo, forKey: "s")
        } else {
            encoder.encodeNil(forKey: "s")
        }
        encoder.encodeBytes(self.contents, forKey: "c")
        if let file = self.file {
            encoder.encodeObject(file, forKey: "f")
        } else {
            encoder.encodeNil(forKey: "f")
        }
    }
}
