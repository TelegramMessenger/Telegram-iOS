import UIKit

public protocol SubscriptionBuilder {
    func build(isNightTheme: Bool) -> UIViewController
}

public class SubscriptionBuilderImpl: SubscriptionBuilder {
    public init() { }

    public func build(isNightTheme: Bool) -> UIViewController {
        let controller = SubscriptionViewController(isNightTheme: isNightTheme)

        let router = SubscriptionRouter()
        router.parentViewController = controller

        let presenter = SubscriptionPresenter()
        presenter.output = controller

        let interactor = SubscriptionInteractor()
        interactor.output = presenter

        controller.output = interactor
        controller.router = router

        return controller
    }
}
