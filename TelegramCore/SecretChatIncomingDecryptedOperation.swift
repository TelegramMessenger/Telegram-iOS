import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

struct SecretChatOperationSequenceInfo: Coding {
    let topReceivedOperationIndex: Int32
    let operationIndex: Int32
    
    init(topReceivedOperationIndex: Int32, operationIndex: Int32) {
        self.topReceivedOperationIndex = topReceivedOperationIndex
        self.operationIndex = operationIndex
    }
    
    init(decoder: Decoder) {
        self.topReceivedOperationIndex = decoder.decodeInt32ForKey("r")
        self.operationIndex = decoder.decodeInt32ForKey("o")
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.topReceivedOperationIndex, forKey: "r")
        encoder.encodeInt32(self.operationIndex, forKey: "o")
    }
}

final class SecretChatIncomingDecryptedOperation: Coding {
    let timestamp: Int32
    let layer: Int32
    let sequenceInfo: SecretChatOperationSequenceInfo?
    let contents: MemoryBuffer
    let file: SecretChatFileReference?
    
    init(timestamp: Int32, layer: Int32, sequenceInfo: SecretChatOperationSequenceInfo?, contents: MemoryBuffer, file: SecretChatFileReference?) {
        self.timestamp = timestamp
        self.layer = layer
        self.sequenceInfo = sequenceInfo
        self.contents = contents
        self.file = file
    }
    
    init(decoder: Decoder) {
        self.timestamp = decoder.decodeInt32ForKey("t")
        self.layer = decoder.decodeInt32ForKey("l")
        self.sequenceInfo = decoder.decodeObjectForKey("s", decoder: { SecretChatOperationSequenceInfo(decoder: $0) }) as? SecretChatOperationSequenceInfo
        self.contents = decoder.decodeBytesForKey("c")!
        self.file = decoder.decodeObjectForKey("f", decoder: { SecretChatFileReference(decoder: $0) }) as? SecretChatFileReference
    }
    
    func encode(_ encoder: Encoder) {
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
