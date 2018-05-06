import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public enum SecureIdRequestedFormField: Equatable {
    case personalDetails
    case passport(selfie: Bool)
    case driversLicense(selfie: Bool)
    case idCard(selfie: Bool)
    case internalPassport(selfie: Bool)
    case passportRegistration
    case address
    case utilityBill
    case bankStatement
    case rentalAgreement
    case phone
    case email
    case temporaryRegistration
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
