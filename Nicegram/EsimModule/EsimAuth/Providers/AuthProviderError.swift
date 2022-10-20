import Foundation

public enum AuthProviderError: Error {
    case underlying(Error)
    case cancelled(Error)
    case unexpected
}

extension AuthProviderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .underlying(let error):
            return error.localizedDescription
        case .cancelled(let error):
            return error.localizedDescription
        case .unexpected:
            return nil
        }
    }
}

