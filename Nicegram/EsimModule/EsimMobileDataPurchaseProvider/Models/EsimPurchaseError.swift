import Foundation
import EsimPayments

public enum EsimPurchaseError: Error {
    case notAuthorized
    case paymentError(PaymentError)
    case completePurchaseError(Error)
}

public extension EsimPurchaseError {
    var isNotAuthorized: Bool {
        if case .notAuthorized = self {
            return true
        } else {
            return false
        }
    }
    
    var isCancelled: Bool {
        if case let .paymentError(paymentError) = self {
            return paymentError.isCancelled
        } else {
            return false
        }
    }
}

extension EsimPurchaseError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notAuthorized: return ""
        case .paymentError(let paymentError): return paymentError.localizedDescription
        case .completePurchaseError(let error): return error.localizedDescription
        }
    }
}


