import Foundation
import TelegramCore

func findIdentity(_ values: [SecureIdValue]) -> (Int, SecureIdIdentityValue)? {
    for i in 0 ..< values.count {
        switch values[i] {
            case let .identity(identity):
                return (i, identity)
            default:
                break
        }
    }
    return nil
}

func findPhone(_ values: [SecureIdValue]) -> (Int, SecureIdPhoneValue)? {
    for i in 0 ..< values.count {
        switch values[i] {
            case let .phone(phone):
                return (i, phone)
            default:
                break
        }
    }
    return nil
}

func findEmail(_ values: [SecureIdValue]) -> (Int, SecureIdEmailValue)? {
    for i in 0 ..< values.count {
        switch values[i] {
            case let .email(email):
                return (i, email)
            default:
                break
        }
    }
    return nil
}
