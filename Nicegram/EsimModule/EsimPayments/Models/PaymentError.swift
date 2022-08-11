import Foundation

public struct PaymentError: Error {
    public let kind: Kind
    public let meta: Meta?
    
    public init(kind: Kind, meta: Meta?) {
        self.kind = kind
        self.meta = meta
    }
    
    public enum Kind {
        case cancelled
        case decline
        case underlying(Error)
        case unknown
    }
    
    public struct Meta {
        public let paymentId: String?
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
        case .cancelled, .decline, .unknown: return NSLocalizedString("Nicegram.Alert.BaseError", comment: "")
        case .underlying(let error): return error.localizedDescription
        }
    }
}

public extension PaymentError {
    static func cancelled(meta: Meta?) -> PaymentError {
        return .init(kind: .cancelled, meta: meta)
    }
    
    static func decline(meta: Meta?) -> PaymentError {
        return .init(kind: .decline, meta: meta)
    }
    
    static func underlying(error: Error, meta: Meta?) -> PaymentError {
        return .init(kind: .underlying(error), meta: meta)
    }
    
    static func unknown(meta: Meta?) -> PaymentError {
        return .init(kind: .unknown, meta: meta)
    }
}
