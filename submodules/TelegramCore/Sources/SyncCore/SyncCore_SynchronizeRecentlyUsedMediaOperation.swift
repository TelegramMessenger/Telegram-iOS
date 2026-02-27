import Postbox

private enum SynchronizeRecentlyUsedMediaOperationContentType: Int32 {
    case add
    case remove
    case clear
    case sync
}

public enum SynchronizeRecentlyUsedMediaOperationContent: PostboxCoding {
    case add(id: Int64, accessHash: Int64, fileReference: FileMediaReference?)
    case remove(id: Int64, accessHash: Int64)
    case clear
    case sync
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case SynchronizeRecentlyUsedMediaOperationContentType.add.rawValue:
                self = .add(id: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0), fileReference: decoder.decodeAnyObjectForKey("fr", decoder: { FileMediaReference(decoder: $0) }) as? FileMediaReference)
            case SynchronizeRecentlyUsedMediaOperationContentType.remove.rawValue:
                self = .remove(id: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0))
            case SynchronizeRecentlyUsedMediaOperationContentType.clear.rawValue:
                self = .clear
            case SynchronizeRecentlyUsedMediaOperationContentType.sync.rawValue:
                self = .sync
            default:
                assertionFailure()
                self = .sync
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .add(id, accessHash, fileReference):
                encoder.encodeInt32(SynchronizeRecentlyUsedMediaOperationContentType.add.rawValue, forKey: "r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
                if let fileReference = fileReference {
                    encoder.encodeObjectWithEncoder(fileReference, encoder: fileReference.encode, forKey: "fr")
                } else {
                    encoder.encodeNil(forKey: "fr")
                }
            case let .remove(id, accessHash):
                encoder.encodeInt32(SynchronizeRecentlyUsedMediaOperationContentType.remove.rawValue, forKey: "r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
            case .clear:
                encoder.encodeInt32(SynchronizeRecentlyUsedMediaOperationContentType.clear.rawValue, forKey: "r")
            case .sync:
                encoder.encodeInt32(SynchronizeRecentlyUsedMediaOperationContentType.sync.rawValue, forKey: "r")
        }
    }
}

public final class SynchronizeRecentlyUsedMediaOperation: PostboxCoding {
    public let content: SynchronizeRecentlyUsedMediaOperationContent
    
    public init(content: SynchronizeRecentlyUsedMediaOperationContent) {
        self.content = content
    }
    
    public init(decoder: PostboxDecoder) {
        self.content = decoder.decodeObjectForKey("c", decoder: { SynchronizeRecentlyUsedMediaOperationContent(decoder: $0) }) as! SynchronizeRecentlyUsedMediaOperationContent
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.content, forKey: "c")
    }
}
