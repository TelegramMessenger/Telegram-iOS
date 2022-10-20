import Foundation
import EsimApiClientDefinition
import EsimAuth
import EsimLogging

public class EsimAuthInterceptor {
    
    //  MARK: - Dependencies
    
    private let auth: EsimAuth
    private let logger: EventsLogger?
    
    //  MARK: - Logic

    private let retryLimit: Int
    
    //  MARK: - Lifecycle
    
    public init(retryLimit: Int = 5, auth: EsimAuth, logger: EventsLogger? = nil) {
        self.retryLimit = retryLimit
        self.auth = auth
        self.logger = logger
    }
}

extension EsimAuthInterceptor: EsimApiClientInterceptor {
    public func adapt(_ urlRequest: URLRequest, completion: @escaping (Result<URLRequest, Error>) -> ()) {
        var urlRequest = urlRequest
        urlRequest.setValue(auth.currentUser?.token ?? "", forHTTPHeaderField: "X-firebase")
        urlRequest.setValue(auth.currentUser?.telegramToken, forHTTPHeaderField: "X-telegram")
        completion(.success(urlRequest))
    }
    
    public func retry(_ urlRequest: URLRequest, dueTo error: EsimApiError, withCurrentRetryCount count: Int, completion: @escaping (RetryResult) -> ()) {
        guard count < retryLimit else {
            logRetryLimitReached(request: urlRequest)
            completion(.doNotRetry)
            return
        }
        
        if case .notAuthorized = error,
           let currentUser = auth.currentUser {
            if let telegramToken = currentUser.telegramToken {
                logTelegramUserNotAuthorized(request: urlRequest, telegramToken: telegramToken)
                completion(.doNotRetry)
            } else {
                logFirebaseUserNotAuthorized(request: urlRequest, firebaseToken: currentUser.token)
                currentUser.refreshToken(forceRefresh: true) { [weak self] result in
                    self?.logFirebaseTokenRefreshResult(request: urlRequest, result: result)
                    
                    switch result {
                    case .success(_):
                        completion(.retry)
                    case .failure(_):
                        completion(.doNotRetry)
                    }
                }
            }
        } else {
            completion(.doNotRetry)
        }
    }
}

//  MARK: - Logging

private extension EsimAuthInterceptor {
    var notAuthorizedEventName: String { "not_authorized_request" }
    
    func logRetryLimitReached(request: URLRequest) {
        guard let logger = logger else { return }
        
        var params = [String: Encodable]()
        params["url"] = request.url?.absoluteString
        params["message"] = "max retry count reached"
        
        logger.logEvent(name: notAuthorizedEventName, params: params)
    }
    
    func logTelegramUserNotAuthorized(request: URLRequest, telegramToken: String) {
        guard let logger = logger else { return }
        
        var params = [String: Encodable]()
        params["url"] = request.url?.absoluteString
        params["telegramToken"] = telegramToken
        params["message"] = "cannot refresh tg token"
        
        logger.logEvent(name: notAuthorizedEventName, params: params)
    }
    
    func logFirebaseUserNotAuthorized(request: URLRequest, firebaseToken: String?) {
        guard let logger = logger else { return }
        
        var params = [String: Encodable]()
        params["url"] = request.url?.absoluteString
        params["firebaseToken"] = firebaseToken
        params["message"] = "trying to refresh firebase token"
        
        logger.logEvent(name: notAuthorizedEventName, params: params)
    }
    
    func logFirebaseTokenRefreshResult(request: URLRequest, result: Result<String, Error>) {
        guard let logger = logger else { return }
        
        var params = [String: Encodable]()
        params["url"] = request.url?.absoluteString
        
        switch result {
        case .success(let newToken):
            params["message"] = "firebase token refresh successful"
            params["newFirebaseToken"] = newToken
            logger.logEvent(name: notAuthorizedEventName, params: params)
        case .failure(let error):
            params["message"] = "firebase token refresh failed"
            logger.logErrorEvent(name: notAuthorizedEventName, error: error, params: params)
        }
    }
}
