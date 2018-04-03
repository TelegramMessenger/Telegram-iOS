import Foundation

public struct SecureIdRentalAgreementValue: Equatable {
    public var verificationDocuments: [SecureIdVerificationDocumentReference]
    
    public init(verificationDocuments: [SecureIdVerificationDocumentReference]) {
        self.verificationDocuments = verificationDocuments
    }
    
    public static func ==(lhs: SecureIdRentalAgreementValue, rhs: SecureIdRentalAgreementValue) -> Bool {
        if lhs.verificationDocuments != rhs.verificationDocuments {
            return false
        }
        return true
    }
}

extension SecureIdRentalAgreementValue {
    init?(fileReferences: [SecureIdVerificationDocumentReference]) {
        let verificationDocuments: [SecureIdVerificationDocumentReference] = fileReferences
        
        self.init(verificationDocuments: verificationDocuments)
    }
    
    func serialize() -> ([String: Any], [SecureIdVerificationDocumentReference]) {
        return ([:], self.verificationDocuments)
    }
}
