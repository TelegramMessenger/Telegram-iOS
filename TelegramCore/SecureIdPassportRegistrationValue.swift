import Foundation

public struct SecureIdPassportRegistrationValue: Equatable {
    public var verificationDocuments: [SecureIdVerificationDocumentReference]
    
    public init(verificationDocuments: [SecureIdVerificationDocumentReference]) {
        self.verificationDocuments = verificationDocuments
    }
    
    public static func ==(lhs: SecureIdPassportRegistrationValue, rhs: SecureIdPassportRegistrationValue) -> Bool {
        if lhs.verificationDocuments != rhs.verificationDocuments {
            return false
        }
        return true
    }
}

extension SecureIdPassportRegistrationValue {
    init?(fileReferences: [SecureIdVerificationDocumentReference]) {
        let verificationDocuments: [SecureIdVerificationDocumentReference] = fileReferences
        
        self.init(verificationDocuments: verificationDocuments)
    }
    
    func serialize() -> ([String: Any], [SecureIdVerificationDocumentReference]) {
        return ([:], self.verificationDocuments)
    }
}
