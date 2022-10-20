public protocol ValueChangeObservble {
    associatedtype Value
    
    var subscriptionsContainer: ValueChangeSubscriptionsContainer<Value> { get }
    
    func subscribe(onChange: @escaping ((Value) -> ())) -> String
    func unsubscribe(_: String?)
    func notify(_: Value)
}

public extension ValueChangeObservble {
    func subscribe(onChange: @escaping ((Value) -> ())) -> String {
        return subscriptionsContainer.subscribe(onChange: onChange)
    }
    
    func unsubscribe(_ token: String?) {
        subscriptionsContainer.unsubscribe(token)
    }
    
    func notify(_ value: Value) {
        subscriptionsContainer.notify(value)
    }
}
