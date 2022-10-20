import Foundation

private struct SubscriptionWrapper<Subscription> {
    let token: String
    let subscription: Subscription
}

public class SubscriptionsContainer<Subscription> {
    
    //  MARK: - Logic
    
    private var subscriptions: [SubscriptionWrapper<Subscription>] = []
    
    //  MARK: - Lifecycle
    
    public init() {}
    
    //  MARK: - Public Functions

    public func subscribe(_ subscription: Subscription) -> String {
        let token = UUID().uuidString
        let subscription = SubscriptionWrapper(token: token, subscription: subscription)
        subscriptions.append(subscription)
        return token
    }
    
    public func unsubscibe(token: String?) {
        if let index = subscriptions.firstIndex(where: { $0.token == token }) {
            subscriptions.remove(at: index)
        }
    }
    
    public func currentSubscriptions() -> [Subscription] {
        return subscriptions.map(\.subscription)
    }
}
