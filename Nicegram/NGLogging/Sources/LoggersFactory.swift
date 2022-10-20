public class LoggersFactory {
    
    //  MARK: - Lifecycle
    
    public init() {}
    
    //  MARK: - Public Functions

    public func createDefaultEventsLogger() -> EventsLogger {
        let firebaseLogger = FirebaseLogger()
        return CompositeEventsLogger(childs: [firebaseLogger])
    }
}
