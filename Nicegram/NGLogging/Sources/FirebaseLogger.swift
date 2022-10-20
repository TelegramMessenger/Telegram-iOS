import FirebaseAnalytics

public class FirebaseLogger {
    
    //  MARK: - Lifecycle
    
    public init() {}
}

extension FirebaseLogger: EventsLogger {
    public func logEvent(name: String, params: [String : Encodable]) {
        Analytics.logEvent(name, parameters: params)
    }
}
