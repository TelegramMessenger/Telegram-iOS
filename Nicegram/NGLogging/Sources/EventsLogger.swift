public protocol EventsLogger {
    func logEvent(name: String)
    func logEvent(name: String, params: [String: Encodable])
}

extension EventsLogger {
    public func logEvent(name: String) {
        logEvent(name: name, params: [:])
    }
}
