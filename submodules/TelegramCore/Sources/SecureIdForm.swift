import Foundation
import Postbox

public enum SecureIdRequestedFormField: Equatable {
    case just(SecureIdRequestedFormFieldValue)
    case oneOf([SecureIdRequestedFormFieldValue])
}

public enum SecureIdRequestedFormFieldValue: Equatable {
    case personalDetails(nativeName: Bool)
    case passport(selfie: Bool, translation: Bool)
    case driversLicense(selfie: Bool, translation: Bool)
    case idCard(selfie: Bool, translation: Bool)
    case internalPassport(selfie: Bool, translation: Bool)
    case passportRegistration(translation: Bool)
    case address
    case utilityBill(translation: Bool)
    case bankStatement(translation: Bool)
    case rentalAgreement(translation: Bool)
    case phone
    case email
    case temporaryRegistration(translation: Bool)
}

public struct SecureIdForm: Equatable {
    public let peerId: PeerId
    public let requestedFields: [SecureIdRequestedFormField]
    public let values: [SecureIdValueWithContext]
    
    public init(peerId: PeerId, requestedFields: [SecureIdRequestedFormField], values: [SecureIdValueWithContext]) {
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
