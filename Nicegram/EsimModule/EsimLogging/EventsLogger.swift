import Foundation
import EsimApiClientDefinition

public protocol EventsLogger {
    func logEvent(name: String, params: [String: Encodable])
    func logErrorEvent(name: String, error: Error, params: [String: Encodable])
}

public class EventsLoggerImpl {
    
    //  MARK: - Dependencies
    
    private let logger: Logger
    
    //  MARK: - Lifecycle
    
    public init(logger: Logger) {
        self.logger = logger
    }
}

extension EventsLoggerImpl: EventsLogger {
    public func logEvent(name: String, params: [String: Encodable]) {
        var params = params
        params["event_name"] = name
        logger.log(params)
    }
    
    public func logErrorEvent(name: String, error: Error, params: [String : Encodable]) {
        var params = params
        let (userInfo, mostUnderlyingError) = errorInfo(error)
        params["error"] = AnyEncodable(userInfo)
        params["mostUnderlyingError"] = AnyEncodable(errorInfo(mostUnderlyingError).0)
        logEvent(name: name, params: params)
    }
}

private extension EventsLoggerImpl {
    func errorInfo(_ error: Error) -> ([String: AnyEncodable], Error) {
        let nsError = error as NSError

        var info = [String: AnyEncodable]()
        info["code"] = AnyEncodable(nsError.code)
        info["message"] = AnyEncodable(nsError.localizedDescription)
        info["reason"] = AnyEncodable(nsError.localizedFailureReason)
        
        let mostUnderlyingError: Error
        
        if let underlyingError = nsError.userInfo["NSUnderlyingError"] as? Error {
            let errorInfo = self.errorInfo(underlyingError)
            mostUnderlyingError = errorInfo.1
            info["underlyingError"] = AnyEncodable(errorInfo.0)
        } else {
            mostUnderlyingError = error
        }
        
        return (info, mostUnderlyingError)
    }
}
