import UIKit
import SubscriptionAnalytics
import TelegramPresentationData

public protocol SubscriptionBuilder {
    func build() -> UIViewController
}

public class SubscriptionBuilderImpl: SubscriptionBuilder {
    
    private let presentationData: PresentationData
    
    public init(presentationData: PresentationData) {
        self.presentationData = presentationData
    }

    public func build() -> UIViewController {
        let controller = SubscriptionViewController()

        let router = SubscriptionRouter()
        router.parentViewController = controller

        let presenter = SubscriptionPresenter(
            presentationData: presentationData
        )
        presenter.output = controller

        let interactor = SubscriptionInteractor(
            subscriptionService: SubscriptionService.shared
        )
        interactor.output = presenter
        interactor.router = router

        controller.output = interactor

        return controller
    }
}
