import Foundation
import EsimModels

public struct PaymentError: Error {
    public let kind: Kind
    public let meta: Meta?
    
    public init(kind: Kind, meta: Meta?) {
        self.kind = kind
        self.meta = meta
    }
    
    public enum Kind {
        case connection(Error)
        case cancelled
        case decline
        case provider(Error)
        case underlying(Error)
        case unknown
    }
    
    public struct Meta {
        public let paymentId: String?
    }
}

extension PaymentError: CustomNSError {
    public var errorUserInfo: [String : Any] {
        let underlyingError: Error?
        switch self.kind {
        case .cancelled, .decline, .unknown:
            underlyingError = nil
        case .connection(let error), .provider(let error), .underlying(let error):
            underlyingError = error
        }
        
        var userInfo = [String: Any]()
        
        if let underlyingError = underlyingError {
            userInfo["NSUnderlyingError"] = underlyingError
        }
        
        return userInfo
    }
}

public extension PaymentError {
    var isCancelled: Bool {
        if case .cancelled = kind {
            return true
        } else {
            return false
        }
    }
}

extension PaymentError: LocalizedError {
    public var errorDescription: String? {
        switch kind {
        case .cancelled, .decline, .unknown: return defaultErrorMessage
        case .connection(let error), .provider(let error), .underlying(let error): return error.localizedDescription
        }
    }
}

public extension PaymentError {
    static func connection(error: Error, meta: Meta?) -> PaymentError {
        return .init(kind: .connection(error), meta: meta)
    }
    
    static func cancelled(meta: Meta?) -> PaymentError {
        return .init(kind: .cancelled, meta: meta)
    }
    
    static func decline(meta: Meta?) -> PaymentError {
        return .init(kind: .decline, meta: meta)
    }
    
    static func provider(error: Error, meta: Meta?) -> PaymentError {
        return .init(kind: .provider(error), meta: meta)
    }
    
    static func underlying(error: Error, meta: Meta?) -> PaymentError {
        return .init(kind: .underlying(error), meta: meta)
    }
    
    static func unknown(meta: Meta?) -> PaymentError {
        return .init(kind: .unknown, meta: meta)
    }
}
