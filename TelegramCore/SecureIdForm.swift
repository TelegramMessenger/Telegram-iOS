import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public enum SecureIdValue: Equatable {
    case identity(SecureIdIdentityValue)
    case phone(SecureIdPhoneValue)
    case email(SecureIdEmailValue)
    
    public static func ==(lhs: SecureIdValue, rhs: SecureIdValue) -> Bool {
        switch lhs {
            case let .identity(value):
                if case .identity(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .phone(value):
                if case .phone(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .email(value):
                if case .email(value) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    func serialize() -> (Data, [SecureIdFileReference])? {
        switch self {
            case let .identity(value):
                return value.serialize()
            case .phone, .email:
                return nil
        }
    }
}

public enum SecureIdRequestedFormField {
    case identity
    case address
    case phone
    case email
}

public struct SecureIdForm: Equatable {
    public let peerId: PeerId
    public let requestedFields: [SecureIdRequestedFormField]
    public let values: [SecureIdValue]
    
    public init(peerId: PeerId, requestedFields: [SecureIdRequestedFormField], values: [SecureIdValue]) {
        self.peerId = peerId
        self.requestedFields = requestedFields
        self.values = values
    }
    
    public static func ==(lhs: SecureIdForm, rhs: SecureIdForm) -> Bool {
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.requestedFields != rhs.requestedFields {
            return false
        }
        if lhs.values != rhs.values {
            return false
        }
        return true
    }
}
