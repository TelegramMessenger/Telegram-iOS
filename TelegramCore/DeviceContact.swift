import Foundation

public final class DeviceContactPhoneNumber: Equatable {
    public let label: String
    public let number: String
    
    public init(label: String, number: String) {
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
