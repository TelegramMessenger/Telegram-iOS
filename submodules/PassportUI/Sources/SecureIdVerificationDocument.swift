import Foundation
import TelegramCore

enum SecureIdVerificationLocalDocumentState: Equatable {
    case uploading(Float)
    case uploaded(UploadedSecureIdFile)
}

struct SecureIdVerificationLocalDocument: Equatable {
    let id: Int64
    let resource: TelegramMediaResource
    let timestamp: Int32
    var state: SecureIdVerificationLocalDocumentState
    
    static func ==(lhs: SecureIdVerificationLocalDocument, rhs: SecureIdVerificationLocalDocument) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if !lhs.resource.isEqual(to: rhs.resource) {
            return false
        }
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        if lhs.state != rhs.state {
            return false
        }
        return true
    }
}

enum SecureIdVerificationDocumentId: Hashable {
    case remote(Int64)
    case local(Int64)
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
    
    var timestamp: Int32 {
        switch self {
            case let .remote(file):
                return file.timestamp
            case let .local(file):
                return file.timestamp
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

