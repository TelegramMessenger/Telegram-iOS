import Foundation

public struct SecureIdUtilityBillValue: Equatable {
    public var verificationDocuments: [SecureIdVerificationDocumentReference]
    
    public init(verificationDocuments: [SecureIdVerificationDocumentReference]) {
        self.verificationDocuments = verificationDocuments
    }
    
    public static func ==(lhs: SecureIdUtilityBillValue, rhs: SecureIdUtilityBillValue) -> Bool {
        if lhs.verificationDocuments != rhs.verificationDocuments {
            return false
        }
        return true
    }
}

extension SecureIdUtilityBillValue {
    init?(fileReferences: [SecureIdVerificationDocumentReference]) {
        let verificationDocuments: [SecureIdVerificationDocumentReference] = fileReferences
        
        self.init(verificationDocuments: verificationDocuments)
    }
    
    func serialize() -> ([String: Any], [SecureIdVerificationDocumentReference]) {
        return ([:], self.verificationDocuments)
    }
}
