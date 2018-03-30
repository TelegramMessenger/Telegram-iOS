import Foundation

public enum SecureIdValue: Equatable {
    case identity(SecureIdIdentityValue)
    case address(SecureIdAddressValue)
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
            case let .address(value):
                if case .address(value) = rhs {
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
    
    func serialize() -> (Data, [SecureIdVerificationDocumentReference])? {
        switch self {
            case let .identity(value):
                return value.serialize()
            case let .address(value):
                return value.serialize()
            case .phone, .email:
                return nil
        }
    }
}

struct SecureIdEncryptedValueMetadata: Equatable {
    let valueDataHash: Data
    let fileHashes: [Data]
    let valueSecret: Data
    let encryptedSecret: Data
    
    static func ==(lhs: SecureIdEncryptedValueMetadata, rhs: SecureIdEncryptedValueMetadata) -> Bool {
        if lhs.valueDataHash != rhs.valueDataHash {
            return false
        }
        if lhs.fileHashes != rhs.fileHashes {
            return false
        }
        if lhs.valueSecret != rhs.valueSecret {
            return false
        }
        if lhs.encryptedSecret != rhs.encryptedSecret {
            return false
        }
        return true
    }
}

public struct SecureIdValueWithContext: Equatable {
    public let value: SecureIdValue
    public let context: SecureIdValueAccessContext
    let encryptedMetadata: SecureIdEncryptedValueMetadata?
    
    init(value: SecureIdValue, context: SecureIdValueAccessContext, encryptedMetadata: SecureIdEncryptedValueMetadata?) {
        self.value = value
        self.context = context
        self.encryptedMetadata = encryptedMetadata
    }
    
    public static func ==(lhs: SecureIdValueWithContext, rhs: SecureIdValueWithContext) -> Bool {
        if lhs.value != rhs.value {
            return false
        }
        if lhs.context != rhs.context {
            return false
        }
        return true
    }
}
