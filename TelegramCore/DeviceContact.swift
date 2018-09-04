import Foundation
#if os(macOS)
import PostboxMac
#else
import Postbox
#endif

public struct DeviceContactNormalizedPhoneNumber: Hashable, RawRepresentable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public final class DeviceContactPhoneNumberValue: Equatable {
    public let plain: String
    public let normalized: DeviceContactNormalizedPhoneNumber
    
    public init(plain: String, normalized: DeviceContactNormalizedPhoneNumber) {
        self.plain = plain
        self.normalized = normalized
    }
    
    public static func ==(lhs: DeviceContactPhoneNumberValue, rhs: DeviceContactPhoneNumberValue) -> Bool {
        if lhs.plain != rhs.plain {
            return false
        }
        if lhs.normalized != rhs.normalized {
            return false
        }
        return true
    }
}

public final class DeviceContactPhoneNumber: Equatable {
    public let label: String
    public let number: DeviceContactPhoneNumberValue
    
    public init(label: String, number: DeviceContactPhoneNumberValue) {
        self.label = label
        self.number = number
    }
    
    public static func ==(lhs: DeviceContactPhoneNumber, rhs: DeviceContactPhoneNumber) -> Bool {
        return lhs.label == rhs.label && lhs.number == rhs.number
    }
}

public final class DeviceContact: Equatable {
    public let id: String
    public let firstName: String
    public let lastName: String
    public let phoneNumbers: [DeviceContactPhoneNumber]
    
    public init(id: String, firstName: String, lastName: String, phoneNumbers: [DeviceContactPhoneNumber]) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumbers = phoneNumbers
    }
    
    public static func ==(lhs: DeviceContact, rhs: DeviceContact) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.firstName != rhs.firstName {
            return false
        }
        if lhs.lastName != rhs.lastName {
            return false
        }
        if lhs.phoneNumbers != rhs.phoneNumbers {
            return false
        }
        return true
    }
}

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
