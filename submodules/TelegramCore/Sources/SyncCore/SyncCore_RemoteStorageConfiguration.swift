import Postbox

public final class RemoteStorageConfiguration: Codable, Equatable {
    public let webDocumentsHostDatacenterId: Int32
    
    public init(webDocumentsHostDatacenterId: Int32) {
        self.webDocumentsHostDatacenterId = webDocumentsHostDatacenterId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.webDocumentsHostDatacenterId = try container.decode(Int32.self, forKey: "webDocumentsHostDatacenterId")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.webDocumentsHostDatacenterId, forKey: "webDocumentsHostDatacenterId")
    }

    public static func ==(lhs: RemoteStorageConfiguration, rhs: RemoteStorageConfiguration) -> Bool {
        if lhs.webDocumentsHostDatacenterId != rhs.webDocumentsHostDatacenterId {
            return false
        }
        return true
    }
}
