import Foundation

//  MARK: - SomeEsimServerError

public struct SomeEsimServerError: Error {
    public let code: Int
    public let message: String
    public let payload: SingleValueDecodingContainer?
    
    public init(code: Int, message: String, payload: SingleValueDecodingContainer?) {
        self.code = code
        self.message = message
        self.payload = payload
    }
}

extension SomeEsimServerError: LocalizedError {
    public var errorDescription: String? { return message }
}

//  MARK: - EsimApiError

public enum EsimApiError: Error {
    case notAuthorized(String)
    case someServerError(SomeEsimServerError)
    case underlying(Error)
    case unexpected
}

extension EsimApiError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notAuthorized(let string):
            return string
        case .someServerError(let someEsimServerError):
            return someEsimServerError.localizedDescription
        case .underlying(let error):
            return error.localizedDescription
        case .unexpected:
            return nil
        }
    }
}

public extension EsimApiError {
    var isNotAuthorized: Bool {
        if case .notAuthorized = self {
            return true
        } else {
            return false
        }
    }
}
