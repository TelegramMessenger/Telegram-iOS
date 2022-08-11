import Foundation

public enum FetchUserEsimsError: Error {
    case notAuthorized
    case underlying(Error)
}

extension FetchUserEsimsError: LocalizedError {
    // TODO: !Localization
    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return ""
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}
