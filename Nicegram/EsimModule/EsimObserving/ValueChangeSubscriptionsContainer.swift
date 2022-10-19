private struct ValueChangeSubscription<Value> {
    let onChange: ((Value) -> ())
}

public class ValueChangeSubscriptionsContainer<Value> {
    
    //  MARK: - Dependencies
    
    private let subscriptions: SubscriptionsContainer<ValueChangeSubscription<Value>>
    
    //  MARK: - Lifecycle
    
    public init() {
        self.subscriptions = .init()
    }
    
    //  MARK: - Public Functions

    public func subscribe(onChange: @escaping ((Value) -> ())) -> String {
        return subscriptions.subscribe(.init(onChange: onChange))
    }
    
    public func unsubscribe(_ token: String?) {
        subscriptions.unsubscibe(token: token)
    }
    
    public func notify(_ value: Value) {
        subscriptions.currentSubscriptions().forEach({ $0.onChange(value) })
    }
}
