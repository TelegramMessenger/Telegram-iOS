import Foundation
import Postbox

private enum SecretChatOutgoingFileValue: Int32 {
    case remote = 0
    case uploadedRegular = 1
    case uploadedLarge = 2
}

public enum SecretChatOutgoingFileReference: PostboxCoding {
    case remote(id: Int64, accessHash: Int64)
    case uploadedRegular(id: Int64, partCount: Int32, md5Digest: String, keyFingerprint: Int32)
    case uploadedLarge(id: Int64, partCount: Int32, keyFingerprint: Int32)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
            case SecretChatOutgoingFileValue.remote.rawValue:
                self = .remote(id: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("a", orElse: 0))
            case SecretChatOutgoingFileValue.uploadedRegular.rawValue:
                self = .uploadedRegular(id: decoder.decodeInt64ForKey("i", orElse: 0), partCount: decoder.decodeInt32ForKey("p", orElse: 0), md5Digest: decoder.decodeStringForKey("d", orElse: ""), keyFingerprint: decoder.decodeInt32ForKey("f", orElse: 0))
            case SecretChatOutgoingFileValue.uploadedLarge.rawValue:
                self = .uploadedLarge(id: decoder.decodeInt64ForKey("i", orElse: 0), partCount: decoder.decodeInt32ForKey("p", orElse: 0), keyFingerprint: decoder.decodeInt32ForKey("f", orElse: 0))
            default:
                assertionFailure()
                self = .remote(id: 0, accessHash: 0)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .remote(id, accessHash):
                encoder.encodeInt32(SecretChatOutgoingFileValue.remote.rawValue, forKey: "v")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "a")
            case let .uploadedRegular(id, partCount, md5Digest, keyFingerprint):
                encoder.encodeInt32(SecretChatOutgoingFileValue.uploadedRegular.rawValue, forKey: "v")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt32(partCount, forKey: "p")
                encoder.encodeString(md5Digest, forKey: "d")
                encoder.encodeInt32(keyFingerprint, forKey: "f")
            case let .uploadedLarge(id, partCount, keyFingerprint):
                encoder.encodeInt32(SecretChatOutgoingFileValue.uploadedLarge.rawValue, forKey: "v")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt32(partCount, forKey: "p")
                encoder.encodeInt32(keyFingerprint, forKey: "f")
        }
    }
}

public struct SecretChatOutgoingFile: PostboxCoding {
    public let reference: SecretChatOutgoingFileReference
    public let size: Int64
    public let key: SecretFileEncryptionKey
    
    public init(reference: SecretChatOutgoingFileReference, size: Int64, key: SecretFileEncryptionKey) {
        self.reference = reference
        self.size = size
        self.key = key
    }
    
    public init(decoder: PostboxDecoder) {
        self.reference = decoder.decodeObjectForKey("r", decoder: { SecretChatOutgoingFileReference(decoder: $0) }) as! SecretChatOutgoingFileReference
        if let size = decoder.decodeOptionalInt64ForKey("s64") {
            self.size = size
        } else {
            self.size = Int64(decoder.decodeInt32ForKey("s", orElse: 0))
        }
        self.key = SecretFileEncryptionKey(aesKey: decoder.decodeBytesForKey("k")!.makeData(), aesIv: decoder.decodeBytesForKey("i")!.makeData())
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.reference, forKey: "r")
        encoder.encodeInt64(self.size, forKey: "s64")
        encoder.encodeBytes(MemoryBuffer(data: self.key.aesKey), forKey: "k")
        encoder.encodeBytes(MemoryBuffer(data: self.key.aesIv), forKey: "i")
    }
}

public enum SecretChatSequenceBasedLayer: Int32 {
    case layer46 = 46
    case layer73 = 73
    case layer101 = 101
    case layer144 = 144
    
    public var secretChatLayer: SecretChatLayer {
        switch self {
            case .layer46:
                return .layer46
            case .layer73:
                return .layer73
            case .layer101:
                return .layer101
            case .layer144:
                return .layer144
        }
    }
}

private enum SecretChatOutgoingOperationValue: Int32 {
    case initialHandshakeAccept = 0
    case sendMessage = 1
    case readMessagesContent = 2
    case deleteMessages = 3
    case screenshotMessages = 4
    case clearHistory = 5
    case resendOperations = 6
    case reportLayerSupport = 7
    case pfsRequestKey = 8
    case pfsAcceptKey = 9
    case pfsAbortSession = 10
    case pfsCommitKey = 11
    case noop = 12
    case setMessageAutoremoveTimeout = 13
    case terminate = 14
}

public enum SecretChatOutgoingOperationContents: PostboxCoding {
    case initialHandshakeAccept(gA: MemoryBuffer, accessHash: Int64, b: MemoryBuffer)
    case sendMessage(layer: SecretChatLayer, id: MessageId, file: SecretChatOutgoingFile?)
    case readMessagesContent(layer: SecretChatLayer, actionGloballyUniqueId: Int64, globallyUniqueIds: [Int64])
    case deleteMessages(layer: SecretChatLayer, actionGloballyUniqueId: Int64, globallyUniqueIds: [Int64])
    case screenshotMessages(layer: SecretChatLayer, actionGloballyUniqueId: Int64, globallyUniqueIds: [Int64], messageId: MessageId)
    case clearHistory(layer: SecretChatLayer, actionGloballyUniqueId: Int64)
    case resendOperations(layer : SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, fromSeqNo: Int32, toSeqNo: Int32)
    case reportLayerSupport(layer: SecretChatLayer, actionGloballyUniqueId: Int64, layerSupport: Int32)
    case pfsRequestKey(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64, a: MemoryBuffer)
    case pfsAcceptKey(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64, gA: MemoryBuffer, b: MemoryBuffer)
    case pfsAbortSession(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64)
    case pfsCommitKey(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64, keyFingerprint: Int64)
    case noop(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64)
    case setMessageAutoremoveTimeout(layer: SecretChatLayer, actionGloballyUniqueId: Int64, timeout: Int32, messageId: MessageId)
    case terminate(reportSpam: Bool, requestRemoteHistoryRemoval: Bool)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case SecretChatOutgoingOperationValue.initialHandshakeAccept.rawValue:
                self = .initialHandshakeAccept(gA: decoder.decodeBytesForKey("g")!, accessHash: decoder.decodeInt64ForKey("h", orElse: 0), b: decoder.decodeBytesForKey("b")!)
            case SecretChatOutgoingOperationValue.sendMessage.rawValue:
                self = .sendMessage(layer: SecretChatLayer(rawValue: decoder.decodeInt32ForKey("l", orElse: 0))!, id: MessageId(peerId: PeerId(decoder.decodeInt64ForKey("i.p", orElse: 0)), namespace: decoder.decodeInt32ForKey("i.n", orElse: 0), id: decoder.decodeInt32ForKey("i.i", orElse: 0)), file: decoder.decodeObjectForKey("f", decoder: { SecretChatOutgoingFile(decoder: $0) }) as? SecretChatOutgoingFile)
            case SecretChatOutgoingOperationValue.readMessagesContent.rawValue:
                self = .readMessagesContent(layer: SecretChatLayer(rawValue: decoder.decodeInt32ForKey("l", orElse: 0))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i", orElse: 0), globallyUniqueIds: decoder.decodeInt64ArrayForKey("u"))
            case SecretChatOutgoingOperationValue.deleteMessages.rawValue:
                self = .deleteMessages(layer: SecretChatLayer(rawValue: decoder.decodeInt32ForKey("l", orElse: 0))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i", orElse: 0), globallyUniqueIds: decoder.decodeInt64ArrayForKey("u"))
            case SecretChatOutgoingOperationValue.screenshotMessages.rawValue:
                self = .screenshotMessages(layer: SecretChatLayer(rawValue: decoder.decodeInt32ForKey("l", orElse: 0))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i", orElse: 0), globallyUniqueIds: decoder.decodeInt64ArrayForKey("u"), messageId: MessageId(peerId: PeerId(decoder.decodeInt64ForKey("m.p", orElse: 0)), namespace: decoder.decodeInt32ForKey("m.n", orElse: 0), id: decoder.decodeInt32ForKey("m.i", orElse: 0)))
            case SecretChatOutgoingOperationValue.clearHistory.rawValue:
                self = .clearHistory(layer: SecretChatLayer(rawValue: decoder.decodeInt32ForKey("l", orElse: 0))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i", orElse: 0))
            case SecretChatOutgoingOperationValue.resendOperations.rawValue:
                self = .resendOperations(layer: SecretChatSequenceBasedLayer(rawValue: decoder.decodeInt32ForKey("l", orElse: 0))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i", orElse: 0), fromSeqNo: decoder.decodeInt32ForKey("f", orElse: 0), toSeqNo: decoder.decodeInt32ForKey("t", orElse: 0))
            case SecretChatOutgoingOperationValue.reportLayerSupport.rawValue:
                self = .reportLayerSupport(layer: SecretChatLayer(rawValue: decoder.decodeInt32ForKey("l", orElse: 0))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i", orElse: 0), layerSupport: decoder.decodeInt32ForKey("l", orElse: 0))
            case SecretChatOutgoingOperationValue.pfsRequestKey.rawValue:
                self = .pfsRequestKey(layer: SecretChatSequenceBasedLayer(rawValue: decoder.decodeInt32ForKey("l", orElse: 0))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i", orElse: 0), rekeySessionId: decoder.decodeInt64ForKey("s", orElse: 0), a: decoder.decodeBytesForKey("a")!)
            case SecretChatOutgoingOperationValue.pfsAcceptKey.rawValue:
                self = .pfsAcceptKey(layer: SecretChatSequenceBasedLayer(rawValue: decoder.decodeInt32ForKey("l", orElse: 0))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i", orElse: 0), rekeySessionId: decoder.decodeInt64ForKey("s", orElse: 0), gA: decoder.decodeBytesForKey("g")!, b: decoder.decodeBytesForKey("b")!)
            case SecretChatOutgoingOperationValue.pfsAbortSession.rawValue:
                self = .pfsAbortSession(layer: SecretChatSequenceBasedLayer(rawValue: decoder.decodeInt32ForKey("l", orElse: 0))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i", orElse: 0), rekeySessionId: decoder.decodeInt64ForKey("s", orElse: 0))
            case SecretChatOutgoingOperationValue.pfsCommitKey.rawValue:
                self = .pfsCommitKey(layer: SecretChatSequenceBasedLayer(rawValue: decoder.decodeInt32ForKey("l", orElse: 0))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i", orElse: 0), rekeySessionId: decoder.decodeInt64ForKey("s", orElse: 0), keyFingerprint: decoder.decodeInt64ForKey("f", orElse: 0))
            case SecretChatOutgoingOperationValue.noop.rawValue:
                self = .noop(layer: SecretChatSequenceBasedLayer(rawValue: decoder.decodeInt32ForKey("l", orElse: 0))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i", orElse: 0))
            case SecretChatOutgoingOperationValue.setMessageAutoremoveTimeout.rawValue:
                self = .setMessageAutoremoveTimeout(layer: SecretChatLayer(rawValue: decoder.decodeInt32ForKey("l", orElse: 0))!, actionGloballyUniqueId: decoder.decodeInt64ForKey("i", orElse: 0), timeout: decoder.decodeInt32ForKey("t", orElse: 0), messageId: MessageId(peerId: PeerId(decoder.decodeInt64ForKey("m.p", orElse: 0)), namespace: decoder.decodeInt32ForKey("m.n", orElse: 0), id: decoder.decodeInt32ForKey("m.i", orElse: 0)))
            case SecretChatOutgoingOperationValue.terminate.rawValue:
                self = .terminate(reportSpam: decoder.decodeInt32ForKey("rs", orElse: 0) != 0, requestRemoteHistoryRemoval: decoder.decodeInt32ForKey("requestRemoteHistoryRemoval", orElse: 0) != 0)
            default:
                self = .noop(layer: SecretChatSequenceBasedLayer(rawValue: decoder.decodeInt32ForKey("l", orElse: 0))!, actionGloballyUniqueId: 0)
                assertionFailure()
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .initialHandshakeAccept(gA, accessHash, b):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.initialHandshakeAccept.rawValue, forKey: "r")
                encoder.encodeBytes(gA, forKey: "g")
                encoder.encodeInt64(accessHash, forKey: "h")
                encoder.encodeBytes(b, forKey: "b")
            case let .sendMessage(layer, id, file):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.sendMessage.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(id.peerId.toInt64(), forKey: "i.p")
                encoder.encodeInt32(id.namespace, forKey: "i.n")
                encoder.encodeInt32(id.id, forKey: "i.i")
                if let file = file {
                    encoder.encodeObject(file, forKey: "f")
                } else {
                    encoder.encodeNil(forKey: "f")
                }
            case let .readMessagesContent(layer, actionGloballyUniqueId, globallyUniqueIds):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.readMessagesContent.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt64Array(globallyUniqueIds, forKey: "u")
            case let .deleteMessages(layer, actionGloballyUniqueId, globallyUniqueIds):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.deleteMessages.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt64Array(globallyUniqueIds, forKey: "u")
            case let .screenshotMessages(layer, actionGloballyUniqueId, globallyUniqueIds, messageId):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.screenshotMessages.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt64Array(globallyUniqueIds, forKey: "u")
                encoder.encodeInt64(messageId.peerId.toInt64(), forKey: "m.p")
                encoder.encodeInt32(messageId.namespace, forKey: "m.n")
                encoder.encodeInt32(messageId.id, forKey: "m.i")
            case let .clearHistory(layer, actionGloballyUniqueId):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.clearHistory.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
            case let .resendOperations(layer, actionGloballyUniqueId, fromSeqNo, toSeqNo):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.resendOperations.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt32(fromSeqNo, forKey: "f")
                encoder.encodeInt32(toSeqNo, forKey: "t")
            case let .reportLayerSupport(layer, actionGloballyUniqueId, layerSupport):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.reportLayerSupport.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt32(layerSupport, forKey: "l")
            case let .pfsRequestKey(layer, actionGloballyUniqueId, rekeySessionId, a):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.pfsRequestKey.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt64(rekeySessionId, forKey: "s")
                encoder.encodeBytes(a, forKey: "a")
            case let .pfsAcceptKey(layer, actionGloballyUniqueId, rekeySessionId, gA, b):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.pfsAcceptKey.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt64(rekeySessionId, forKey: "s")
                encoder.encodeBytes(gA, forKey: "g")
                encoder.encodeBytes(b, forKey: "b")
            case let .pfsAbortSession(layer, actionGloballyUniqueId, rekeySessionId):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.pfsAbortSession.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt64(rekeySessionId, forKey: "s")
            case let .pfsCommitKey(layer, actionGloballyUniqueId, rekeySessionId, keyFingerprint):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.pfsCommitKey.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt64(rekeySessionId, forKey: "s")
                encoder.encodeInt64(keyFingerprint, forKey: "f")
            case let .noop(layer, actionGloballyUniqueId):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.noop.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
            case let .setMessageAutoremoveTimeout(layer, actionGloballyUniqueId, timeout, messageId):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.setMessageAutoremoveTimeout.rawValue, forKey: "r")
                encoder.encodeInt32(layer.rawValue, forKey: "l")
                encoder.encodeInt64(actionGloballyUniqueId, forKey: "i")
                encoder.encodeInt32(timeout, forKey: "t")
                encoder.encodeInt64(messageId.peerId.toInt64(), forKey: "m.p")
                encoder.encodeInt32(messageId.namespace, forKey: "m.n")
                encoder.encodeInt32(messageId.id, forKey: "m.i")
            case let .terminate(reportSpam, requestRemoteHistoryRemoval):
                encoder.encodeInt32(SecretChatOutgoingOperationValue.terminate.rawValue, forKey: "r")
                encoder.encodeInt32(reportSpam ? 1 : 0, forKey: "rs")
                encoder.encodeInt32(requestRemoteHistoryRemoval ? 1 : 0, forKey: "requestRemoteHistoryRemoval")
        }
    }
}

public final class SecretChatOutgoingOperation: PostboxCoding {
    public let contents: SecretChatOutgoingOperationContents
    public let mutable: Bool
    public let delivered: Bool
    
    public init(contents: SecretChatOutgoingOperationContents, mutable: Bool, delivered: Bool) {
        self.contents = contents
        self.mutable = mutable
        self.delivered = delivered
    }
    
    public init(decoder: PostboxDecoder) {
        self.contents = decoder.decodeObjectForKey("c", decoder: { SecretChatOutgoingOperationContents(decoder: $0) }) as! SecretChatOutgoingOperationContents
        self.mutable = decoder.decodeInt32ForKey("m", orElse: 0) != 0
        self.delivered = decoder.decodeInt32ForKey("d", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.contents, forKey: "c")
        encoder.encodeInt32(self.mutable ? 1 : 0, forKey: "m")
        encoder.encodeInt32(self.delivered ? 1 : 0, forKey: "d")
    }
    
    public func withUpdatedDelivered(_ delivered: Bool) -> SecretChatOutgoingOperation {
        return SecretChatOutgoingOperation(contents: self.contents, mutable: self.mutable, delivered: delivered)
    }
}
