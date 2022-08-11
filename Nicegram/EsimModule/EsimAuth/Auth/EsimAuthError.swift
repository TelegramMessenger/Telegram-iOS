import Foundation
import EsimApiClientDefinition

public enum EsimAuthError: Error {
    case authProviderError(AuthProviderError)
    case apiClientError(EsimApiError)
    case underlying(Error)
    case unexpected
}

extension EsimAuthError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .authProviderError(let authProviderError):
            return authProviderError.localizedDescription
        case .apiClientError(let esimApiError):
            return esimApiError.localizedDescription
        case .underlying(let error):
            return error.localizedDescription
        case .unexpected:
            return nil
        }
    }
}

public extension EsimAuthError {
    var isCancelled: Bool {
        if case let .authProviderError(authProviderError) = self,
           case .cancelled = authProviderError {
            return true
        } else {
            return false
        }
    }
}
