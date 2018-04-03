import Foundation

public struct SecureIdBankStatementValue: Equatable {
    public var verificationDocuments: [SecureIdVerificationDocumentReference]
    
    public init(verificationDocuments: [SecureIdVerificationDocumentReference]) {
        self.verificationDocuments = verificationDocuments
    }
    
    public static func ==(lhs: SecureIdBankStatementValue, rhs: SecureIdBankStatementValue) -> Bool {
        if lhs.verificationDocuments != rhs.verificationDocuments {
            return false
        }
        return true
    }
}

extension SecureIdBankStatementValue {
    init?(fileReferences: [SecureIdVerificationDocumentReference]) {
        let verificationDocuments: [SecureIdVerificationDocumentReference] = fileReferences
        
        self.init(verificationDocuments: verificationDocuments)
    }
    
    func serialize() -> ([String: Any], [SecureIdVerificationDocumentReference]) {
        return ([:], self.verificationDocuments)
    }
}
