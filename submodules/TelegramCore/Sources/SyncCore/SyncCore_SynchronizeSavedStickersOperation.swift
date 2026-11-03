import Postbox

private enum SynchronizeSavedStickersOperationContentType: Int32 {
    case add
    case remove
    case sync
}

public enum SynchronizeSavedStickersOperationContent: PostboxCoding {
    case add(id: Int64, accessHash: Int64, fileReference: FileMediaReference?)
    case remove(id: Int64, accessHash: Int64)
    case sync
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case SynchronizeSavedStickersOperationContentType.add.rawValue:
                self = .add(id: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0), fileReference: decoder.decodeAnyObjectForKey("fr", decoder: { FileMediaReference(decoder: $0) }) as? FileMediaReference)
            case SynchronizeSavedStickersOperationContentType.remove.rawValue:
                self = .remove(id: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0))
            case SynchronizeSavedStickersOperationContentType.sync.rawValue:
                self = .sync
            default:
                assertionFailure()
                self = .sync
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .add(id, accessHash, fileReference):
                encoder.encodeInt32(SynchronizeSavedStickersOperationContentType.add.rawValue, forKey: "r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
                if let fileReference = fileReference {
                    encoder.encodeObjectWithEncoder(fileReference, encoder: fileReference.encode, forKey: "fr")
                } else {
                    encoder.encodeNil(forKey: "fr")
                }
            case let .remove(id, accessHash):
                encoder.encodeInt32(SynchronizeSavedStickersOperationContentType.remove.rawValue, forKey: "r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
            case .sync:
                encoder.encodeInt32(SynchronizeSavedStickersOperationContentType.sync.rawValue, forKey: "r")
        }
    }
}

public final class SynchronizeSavedStickersOperation: PostboxCoding {
    public let content: SynchronizeSavedStickersOperationContent
    
    public init(content: SynchronizeSavedStickersOperationContent) {
        self.content = content
    }
    
    public init(decoder: PostboxDecoder) {
        self.content = decoder.decodeObjectForKey("c", decoder: { SynchronizeSavedStickersOperationContent(decoder: $0) }) as! SynchronizeSavedStickersOperationContent
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.content, forKey: "c")
    }
}
