import Postbox

private enum SynchronizeSavedGifsOperationContentType: Int32 {
    case add
    case remove
    case sync
}

public enum SynchronizeSavedGifsOperationContent: PostboxCoding {
    case add(id: Int64, accessHash: Int64, fileReference: FileMediaReference?)
    case remove(id: Int64, accessHash: Int64)
    case sync
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case SynchronizeSavedGifsOperationContentType.add.rawValue:
                self = .add(id: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0), fileReference: decoder.decodeAnyObjectForKey("fr", decoder: { FileMediaReference(decoder: $0) }) as? FileMediaReference)
            case SynchronizeSavedGifsOperationContentType.remove.rawValue:
                self = .remove(id: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0))
            case SynchronizeSavedGifsOperationContentType.sync.rawValue:
                self = .sync
            default:
                assertionFailure()
                self = .sync
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .add(id, accessHash, fileReference):
                encoder.encodeInt32(SynchronizeSavedGifsOperationContentType.add.rawValue, forKey: "r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
                if let fileReference = fileReference {
                    encoder.encodeObjectWithEncoder(fileReference, encoder: fileReference.encode, forKey: "fr")
                } else {
                    encoder.encodeNil(forKey: "fr")
                }
            case let .remove(id, accessHash):
                encoder.encodeInt32(SynchronizeSavedGifsOperationContentType.remove.rawValue, forKey: "r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
            case .sync:
                encoder.encodeInt32(SynchronizeSavedGifsOperationContentType.sync.rawValue, forKey: "r")
        }
    }
}

public final class SynchronizeSavedGifsOperation: PostboxCoding {
    public let content: SynchronizeSavedGifsOperationContent
    
    public init(content: SynchronizeSavedGifsOperationContent) {
        self.content = content
    }
    
    public init(decoder: PostboxDecoder) {
        self.content = decoder.decodeObjectForKey("c", decoder: { SynchronizeSavedGifsOperationContent(decoder: $0) }) as! SynchronizeSavedGifsOperationContent
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.content, forKey: "c")
    }
}
