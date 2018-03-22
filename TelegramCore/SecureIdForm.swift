import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public enum SecureIdFieldValue<T>: Equatable where T: Equatable {
    case empty
    case value(T)
    
    public static func ==(lhs: SecureIdFieldValue<T>, rhs: SecureIdFieldValue<T>) -> Bool {
        switch lhs {
            case .empty:
                if case .empty = rhs {
                    return true
                } else {
                    return false
                }
            case let .value(value):
                if case .value(value) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public struct SecureIdFields: Equatable {
    public var identity: SecureIdFieldValue<SecureIdIdentityField>?
    public var phone: SecureIdFieldValue<SecureIdPhoneField>?
    public var email: SecureIdFieldValue<SecureIdEmailField>?
    
    public static func ==(lhs: SecureIdFields, rhs: SecureIdFields) -> Bool {
        if lhs.identity != rhs.identity {
            return false
        }
        if lhs.phone != rhs.phone {
            return false
        }
        if lhs.email != rhs.email {
            return false
        }
        return true
    }
}

public enum SecureIdField: Equatable {
    case identity(SecureIdIdentityField)
    case phone(SecureIdPhoneField)
    case email(SecureIdEmailField)
    
    public static func ==(lhs: SecureIdField, rhs: SecureIdField) -> Bool {
        switch lhs {
            case let .identity(field):
                if case .identity(field) = rhs {
                    return true
                } else {
                    return false
                }
            case let .phone(field):
                if case .phone(field) = rhs {
                    return true
                } else {
                    return false
                }
            case let .email(field):
                if case .email(field) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public struct SecureIdForm {
    public let peerId: PeerId
    public let fields: SecureIdFields
}
