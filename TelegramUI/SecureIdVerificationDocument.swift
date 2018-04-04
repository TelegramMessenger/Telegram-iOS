import Foundation
import TelegramCore

enum SecureIdVerificationLocalDocumentState {
    case uploading(Float)
    case uploaded(UploadedSecureIdFile)
    
    func isEqual(to: SecureIdVerificationLocalDocumentState) -> Bool {
        switch self {
            case let .uploading(progress):
                if case .uploading(progress) = to {
                    return true
                } else {
                    return false
                }
            case let .uploaded(file):
                if case .uploaded(file) = to {
                    return true
                } else {
                    return false
                }
        }
    }
}

struct SecureIdVerificationLocalDocument: Equatable {
    let id: Int64
    let resource: TelegramMediaResource
    var state: SecureIdVerificationLocalDocumentState
    
    static func ==(lhs: SecureIdVerificationLocalDocument, rhs: SecureIdVerificationLocalDocument) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if !lhs.resource.isEqual(to: rhs.resource) {
            return false
        }
        if !lhs.state.isEqual(to: rhs.state) {
            return false
        }
        return true
    }
    
    func isEqual(to: SecureIdVerificationLocalDocument) -> Bool {
        if self.id != to.id {
            return false
        }
        if !self.resource.isEqual(to: to.resource) {
            return false
        }
        if !self.state.isEqual(to: to.state) {
            return false
        }
        return true
    }
}

enum SecureIdVerificationDocumentId: Hashable {
    case remote(Int64)
    case local(Int64)
    
    static func ==(lhs: SecureIdVerificationDocumentId, rhs: SecureIdVerificationDocumentId) -> Bool {
        switch lhs {
            case let .remote(id):
                if case .remote(id) = rhs {
                    return true
                } else {
                    return false
                }
            case let .local(id):
                if case .local(id) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case let .local(id):
                return id.hashValue
            case let .remote(id):
                return id.hashValue
        }
    }
}

enum SecureIdVerificationDocument: Equatable {
    case remote(SecureIdFileReference)
    case local(SecureIdVerificationLocalDocument)
    
    var id: SecureIdVerificationDocumentId {
        switch self {
            case let .remote(file):
                return .remote(file.id)
            case let .local(file):
                return .local(file.id)
        }
    }
    
    var resource: TelegramMediaResource {
        switch self {
            case let .remote(file):
                return SecureFileMediaResource(file: file)
            case let .local(file):
                return file.resource
        }
    }
    
    func isEqual(to: SecureIdVerificationDocument) -> Bool {
        switch self {
            case let .remote(reference):
                if case .remote(reference) = to {
                    return true
                } else {
                    return false
                }
            case let .local(lhsDocument):
                if case let .local(rhsDocument) = to, lhsDocument.isEqual(to: rhsDocument) {
                    return true
                } else {
                    return false
                }
        }
    }
}

extension SecureIdVerificationDocument {
    init?(_ reference: SecureIdVerificationDocumentReference) {
        switch reference {
            case let .remote(file):
                self = .remote(file)
            case .uploaded:
                return nil
        }
    }
}

