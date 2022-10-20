import Foundation
import EsimApiClientDefinition

public class EsimDefaultInterceptor {
    public init() {}
}

extension EsimDefaultInterceptor: EsimApiClientInterceptor {
    public func adapt(_ urlRequest: URLRequest, completion: @escaping (Result<URLRequest, Error>) -> ()) {
        completion(.success(urlRequest))
    }
    
    public func retry(_ urlRequest: URLRequest, dueTo error: EsimApiError, withCurrentRetryCount count: Int, completion: @escaping (RetryResult) -> ()) {
        completion(.doNotRetry)
    }
}
