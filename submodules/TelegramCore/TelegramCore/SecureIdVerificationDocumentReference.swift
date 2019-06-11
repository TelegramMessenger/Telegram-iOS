import Foundation

public enum SecureIdVerificationDocumentReference: Equatable {
    case remote(SecureIdFileReference)
    case uploaded(UploadedSecureIdFile)
    
    public static func ==(lhs: SecureIdVerificationDocumentReference, rhs: SecureIdVerificationDocumentReference) -> Bool {
        switch lhs {
            case let .remote(file):
                if case .remote(file) = rhs {
                    return true
                } else {
                    return false
                }
            case let .uploaded(file):
                if case .uploaded(file) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}
