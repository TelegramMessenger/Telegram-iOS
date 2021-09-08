import Postbox

public final class RemoteStorageConfiguration: PreferencesEntry {
    public let webDocumentsHostDatacenterId: Int32
    
    public init(webDocumentsHostDatacenterId: Int32) {
        self.webDocumentsHostDatacenterId = webDocumentsHostDatacenterId
    }
    
    public init(decoder: PostboxDecoder) {
        self.webDocumentsHostDatacenterId = decoder.decodeInt32ForKey("webDocumentsHostDatacenterId", orElse: 4)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.webDocumentsHostDatacenterId, forKey: "webDocumentsHostDatacenterId")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? RemoteStorageConfiguration else {
            return false
        }
        if self.webDocumentsHostDatacenterId != to.webDocumentsHostDatacenterId {
            return false
        }
        return true
    }
}
