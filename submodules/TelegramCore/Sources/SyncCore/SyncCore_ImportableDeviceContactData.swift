import Postbox

public final class ImportableDeviceContactData: Equatable, PostboxCoding {
    public let firstName: String
    public let lastName: String
    public let localIdentifiers: [String]
    
    public init(firstName: String, lastName: String, localIdentifiers: [String]) {
        self.firstName = firstName
        self.lastName = lastName
        self.localIdentifiers = localIdentifiers
    }
    
    public init(decoder: PostboxDecoder) {
        self.firstName = decoder.decodeStringForKey("f", orElse: "")
        self.lastName = decoder.decodeStringForKey("l", orElse: "")
        self.localIdentifiers = decoder.decodeStringArrayForKey("dis")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.firstName, forKey: "f")
        encoder.encodeString(self.lastName, forKey: "l")
        encoder.encodeStringArray(self.localIdentifiers, forKey: "dis")
    }
    
    public static func ==(lhs: ImportableDeviceContactData, rhs: ImportableDeviceContactData) -> Bool {
        if lhs.firstName != rhs.firstName {
            return false
        }
        if lhs.lastName != rhs.lastName {
            return false
        }
        if lhs.localIdentifiers != rhs.localIdentifiers {
            return false
        }
        return true
    }
}
