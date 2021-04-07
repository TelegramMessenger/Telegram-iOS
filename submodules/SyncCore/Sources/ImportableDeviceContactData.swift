import Postbox

public final class ImportableDeviceContactData: Equatable, PostboxCoding {
    public let firstName: String
    public let lastName: String
    
    public init(firstName: String, lastName: String) {
        self.firstName = firstName
        self.lastName = lastName
    }
    
    public init(decoder: PostboxDecoder) {
        self.firstName = decoder.decodeStringForKey("f", orElse: "")
        self.lastName = decoder.decodeStringForKey("l", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.firstName, forKey: "f")
        encoder.encodeString(self.lastName, forKey: "l")
    }
    
    public static func ==(lhs: ImportableDeviceContactData, rhs: ImportableDeviceContactData) -> Bool {
        if lhs.firstName != rhs.firstName {
            return false
        }
        if lhs.lastName != rhs.lastName {
            return false
        }
        return true
    }
}
