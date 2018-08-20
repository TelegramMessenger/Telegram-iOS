import Foundation

public struct SecureIdUtilityBillValue: Equatable {
    public var verificationDocuments: [SecureIdVerificationDocumentReference]
    public var translations: [SecureIdVerificationDocumentReference]
    
    public init(verificationDocuments: [SecureIdVerificationDocumentReference], translations: [SecureIdVerificationDocumentReference]) {
        self.verificationDocuments = verificationDocuments
        self.translations = translations
    }
    
    public static func ==(lhs: SecureIdUtilityBillValue, rhs: SecureIdUtilityBillValue) -> Bool {
        if lhs.verificationDocuments != rhs.verificationDocuments {
            return false
        }
        if lhs.translations != rhs.translations {
            return false
        }
        return true
    }
}

extension SecureIdUtilityBillValue {
    init?(fileReferences: [SecureIdVerificationDocumentReference], translations: [SecureIdVerificationDocumentReference]) {
        let verificationDocuments: [SecureIdVerificationDocumentReference] = fileReferences
        
        self.init(verificationDocuments: verificationDocuments, translations: translations)
    }
    
    func serialize() -> ([String: Any], [SecureIdVerificationDocumentReference], [SecureIdVerificationDocumentReference]) {
        return ([:], self.verificationDocuments, self.translations)
    }
}
