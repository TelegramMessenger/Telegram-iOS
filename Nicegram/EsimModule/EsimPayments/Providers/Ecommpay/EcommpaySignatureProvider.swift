import Foundation
import EsimModels

public enum EcommpaySignatureError: Error {
    case connection(Error)
    case underlying(Error)
    case unexpected
}

extension EcommpaySignatureError: CustomNSError {
    public var errorUserInfo: [String : Any] {
        let underlyingError: Error?
        switch self {
        case .connection(let error), .underlying(let error):
            underlyingError = error
        case .unexpected:
            underlyingError = nil
        }
        
        var userInfo = [String: Any]()
        
        if let underlyingError = underlyingError {
            userInfo["NSUnderlyingError"] = underlyingError
            userInfo["NSLocalizedDescription"] = underlyingError.localizedDescription
        } else {
            userInfo["NSLocalizedDescription"] = defaultErrorMessage
        }
        
        return userInfo
    }
}

public protocol EcommpaySignatureProvider {
    func getSignature(params: String, completion: @escaping (Result<String, EcommpaySignatureError>) -> ())
}
