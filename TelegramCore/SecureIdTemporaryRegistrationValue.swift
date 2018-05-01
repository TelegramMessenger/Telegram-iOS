import Foundation

public struct SecureIdTemporaryRegistrationValue: Equatable {
    public var verificationDocuments: [SecureIdVerificationDocumentReference]
    
    public init(verificationDocuments: [SecureIdVerificationDocumentReference]) {
        self.verificationDocuments = verificationDocuments
    }
    
    public static func ==(lhs: SecureIdTemporaryRegistrationValue, rhs: SecureIdTemporaryRegistrationValue) -> Bool {
        if lhs.verificationDocuments != rhs.verificationDocuments {
            return false
        }
        return true
    }
}

extension SecureIdTemporaryRegistrationValue {
    init?(fileReferences: [SecureIdVerificationDocumentReference]) {
        let verificationDocuments: [SecureIdVerificationDocumentReference] = fileReferences
        
        self.init(verificationDocuments: verificationDocuments)
    }
    
    func serialize() -> ([String: Any], [SecureIdVerificationDocumentReference]) {
        return ([:], self.verificationDocuments)
    }
}
