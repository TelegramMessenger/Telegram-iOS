import Postbox

public enum TelegramDeviceContactImportedData: PostboxCoding {
    case imported(data: ImportableDeviceContactData, importedByCount: Int32, peerId: PeerId?)
    case retryLater
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_t", orElse: 0) {
            case 0:
            self = .imported(data: decoder.decodeObjectForKey("d", decoder: { ImportableDeviceContactData(decoder: $0) }) as! ImportableDeviceContactData, importedByCount: decoder.decodeInt32ForKey("c", orElse: 0), peerId: decoder.decodeOptionalInt64ForKey("pid").flatMap(PeerId.init))
            case 1:
                self = .retryLater
            default:
                assertionFailure()
                self = .retryLater
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .imported(data, importedByCount, peerId):
                encoder.encodeInt32(0, forKey: "_t")
                encoder.encodeObject(data, forKey: "d")
                encoder.encodeInt32(importedByCount, forKey: "c")
                if let peerId = peerId {
                    encoder.encodeInt64(peerId.toInt64(), forKey: "pid")
                } else {
                    encoder.encodeNil(forKey: "pid")
                }
            case .retryLater:
                encoder.encodeInt32(1, forKey: "_t")
        }
    }
}
