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

extension SomeEsimServerError: CustomNSError {
    public var errorCode: Int { code }
}

extension SomeEsimServerError: LocalizedError {
    public var errorDescription: String? { return message }
}

//  MARK: - EsimApiError

public enum EsimApiError: Error {
    case connection(Error)
    case notAuthorized(String)
    case someServerError(SomeEsimServerError)
    case underlying(Error)
    case unexpected
}

extension EsimApiError: CustomNSError {
    public var errorCode: Int {
        switch self {
        case .notAuthorized(_):
            return 401
        case .connection(_):
            return 0
        case .someServerError(_):
            return 0
        case .underlying(_):
            return 0
        case .unexpected:
            return 0
        }
    }
    
    public var errorUserInfo: [String : Any] {
        let underlyingError: Error?
        switch self {
        case .notAuthorized(_), .unexpected:
            underlyingError = nil
        case .someServerError(let error):
            underlyingError = error
        case .underlying(let error), .connection(let error):
            underlyingError = error
        }
        
        var userInfo = [String: Any]()
        
        if let underlyingError = underlyingError {
            userInfo["NSUnderlyingError"] = underlyingError
        }
        
        return userInfo
    }
}

extension EsimApiError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notAuthorized(let string):
            return string
        case .someServerError(let someEsimServerError):
            return someEsimServerError.localizedDescription
        case .underlying(let error), .connection(let error):
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
