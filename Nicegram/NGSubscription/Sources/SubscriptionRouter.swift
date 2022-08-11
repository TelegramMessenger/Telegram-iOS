protocol SubscriptionRouterInput: AnyObject {
    /// Test method
    func dismiss()
}

final class SubscriptionRouter: SubscriptionRouterInput {
    weak var parentViewController: SubscriptionViewController?

    func dismiss() {
        parentViewController?.dismiss(animated: true, completion: nil)
    }
}
