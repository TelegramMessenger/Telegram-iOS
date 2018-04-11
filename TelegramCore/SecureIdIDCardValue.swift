import Foundation

public struct SecureIdIDCardValue: Equatable {
    public var identifier: String
    public var expiryDate: SecureIdDate?
    public var verificationDocuments: [SecureIdVerificationDocumentReference]
    public var selfieDocument: SecureIdVerificationDocumentReference?
    
    public init(identifier: String, expiryDate: SecureIdDate?, verificationDocuments: [SecureIdVerificationDocumentReference], selfieDocument: SecureIdVerificationDocumentReference?) {
        self.identifier = identifier
        self.expiryDate = expiryDate
        self.verificationDocuments = verificationDocuments
        self.selfieDocument = selfieDocument
    }
    
    public static func ==(lhs: SecureIdIDCardValue, rhs: SecureIdIDCardValue) -> Bool {
        if lhs.identifier != rhs.identifier {
            return false
        }
        if lhs.expiryDate != rhs.expiryDate {
            return false
        }
        if lhs.verificationDocuments != rhs.verificationDocuments {
            return false
        }
        if lhs.selfieDocument != rhs.selfieDocument {
            return false
        }
        return true
    }
}

extension SecureIdIDCardValue {
    init?(dict: [String: Any], fileReferences: [SecureIdVerificationDocumentReference], selfieDocument: SecureIdVerificationDocumentReference?) {
        guard let identifier = dict["document_no"] as? String else {
            return nil
        }
        let expiryDate = (dict["expiry_date"] as? String).flatMap(SecureIdDate.init)
        
        let verificationDocuments: [SecureIdVerificationDocumentReference] = fileReferences
        
        self.init(identifier: identifier, expiryDate: expiryDate, verificationDocuments: verificationDocuments, selfieDocument: selfieDocument)
    }
    
    func serialize() -> ([String: Any], [SecureIdVerificationDocumentReference], SecureIdVerificationDocumentReference?) {
        var dict: [String: Any] = [:]
        dict["document_no"] = self.identifier
        if let expiryDate = self.expiryDate {
            dict["expiry_date"] = expiryDate.serialize()
        }
        
        return (dict, self.verificationDocuments, self.selfieDocument)
    }
}
