import Foundation

public struct SecureIdInternalPassportValue: Equatable {
    public var identifier: String
    public var expiryDate: SecureIdDate?
    public var verificationDocuments: [SecureIdVerificationDocumentReference]
    public var translations: [SecureIdVerificationDocumentReference]
    public var selfieDocument: SecureIdVerificationDocumentReference?
    public var frontSideDocument: SecureIdVerificationDocumentReference?
    
    public init(identifier: String, expiryDate: SecureIdDate?, verificationDocuments: [SecureIdVerificationDocumentReference], translations: [SecureIdVerificationDocumentReference], selfieDocument: SecureIdVerificationDocumentReference?, frontSideDocument: SecureIdVerificationDocumentReference?) {
        self.identifier = identifier
        self.expiryDate = expiryDate
        self.verificationDocuments = verificationDocuments
        self.translations = translations
        self.selfieDocument = selfieDocument
        self.frontSideDocument = frontSideDocument
    }
    
    public static func ==(lhs: SecureIdInternalPassportValue, rhs: SecureIdInternalPassportValue) -> Bool {
        if lhs.identifier != rhs.identifier {
            return false
        }
        if lhs.expiryDate != rhs.expiryDate {
            return false
        }
        if lhs.verificationDocuments != rhs.verificationDocuments {
            return false
        }
        if lhs.translations != rhs.translations {
            return false
        }
        if lhs.selfieDocument != rhs.selfieDocument {
            return false
        }
        if lhs.frontSideDocument != rhs.frontSideDocument {
            return false
        }
        return true
    }
}

extension SecureIdInternalPassportValue {
    init?(dict: [String: Any], fileReferences: [SecureIdVerificationDocumentReference], translations: [SecureIdVerificationDocumentReference], selfieDocument: SecureIdVerificationDocumentReference?, frontSideDocument: SecureIdVerificationDocumentReference?) {
        guard let identifier = dict["document_no"] as? String else {
            return nil
        }
        let expiryDate = (dict["expiry_date"] as? String).flatMap(SecureIdDate.init)
        
        let verificationDocuments: [SecureIdVerificationDocumentReference] = fileReferences
        
        self.init(identifier: identifier, expiryDate: expiryDate, verificationDocuments: verificationDocuments, translations: translations, selfieDocument: selfieDocument, frontSideDocument: frontSideDocument)
    }
    
    func serialize() -> ([String: Any], [SecureIdVerificationDocumentReference], [SecureIdVerificationDocumentReference], SecureIdVerificationDocumentReference?, SecureIdVerificationDocumentReference?) {
        var dict: [String: Any] = [:]
        dict["document_no"] = self.identifier
        if let expiryDate = self.expiryDate {
            dict["expiry_date"] = expiryDate.serialize()
        }
        
        return (dict, self.verificationDocuments, self.translations, self.selfieDocument, self.frontSideDocument)
    }
}
