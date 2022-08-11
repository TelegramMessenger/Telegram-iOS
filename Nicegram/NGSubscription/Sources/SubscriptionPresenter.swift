protocol SubscriptionPresenterInput { }

protocol SubscriptionPresenterOutput: AnyObject {
    func display(isLoading: Bool)
    func onSuccess()
}

final class SubscriptionPresenter: SubscriptionPresenterInput {
    weak var output: SubscriptionPresenterOutput!
}

extension SubscriptionPresenter: SubscriptionInteractorOutput {
    func display(isLoading: Bool) {
        output.display(isLoading: isLoading)
    }

    func onSuccess() {
        output.onSuccess()
    }
}
