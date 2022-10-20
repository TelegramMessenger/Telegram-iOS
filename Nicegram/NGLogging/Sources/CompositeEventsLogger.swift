public class CompositeEventsLogger {
    
    //  MARK: - Logic
    
    private var childs: [EventsLogger]
    
    //  MARK: - Lifecycle
    
    public init(childs: [EventsLogger]) {
        self.childs = childs
    }
}

extension CompositeEventsLogger: EventsLogger {
    public func logEvent(name: String, params: [String : Encodable]) {
        // TODO: Async
        childs.forEach({ $0.logEvent(name: name, params: params) })
    }
}
