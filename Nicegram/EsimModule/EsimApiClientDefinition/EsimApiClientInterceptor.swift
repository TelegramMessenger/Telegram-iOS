import Foundation

public enum RetryResult {
    case retry
    case doNotRetry
}

public protocol EsimApiClientInterceptor {
    func adapt(_ urlRequest: URLRequest, completion: @escaping (Result<URLRequest, Error>) -> ())
    func retry(_ urlRequest: URLRequest, dueTo error: EsimApiError, withCurrentRetryCount count: Int, completion: @escaping (RetryResult) -> ())
}
