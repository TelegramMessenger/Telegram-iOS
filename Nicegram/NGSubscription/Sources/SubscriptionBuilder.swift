import UIKit
import SubscriptionAnalytics
import TelegramPresentationData

public protocol SubscriptionBuilder {
    func build() -> UIViewController
    func build(handlers: SubscriptionHandlers) -> UIViewController
}

public class SubscriptionBuilderImpl {
    
    //  MARK: - Dependencies
    
    private let languageCode: String
    
    //  MARK: - Lifecycle
    
    public init(languageCode: String) {
        self.languageCode = languageCode
    }
    
    //  MARK: - Private Functions

    private func internalBuild(handlers: SubscriptionHandlers?) -> UIViewController {
        let controller = SubscriptionViewController()

        let router = SubscriptionRouter()
        router.parentViewController = controller

        let presenter = SubscriptionPresenter(
            languageCode: languageCode
        )
        presenter.output = controller

        let closeHandler: () -> Void = { [weak router] in
            router?.dismiss()
        }
        
        let interactor = SubscriptionInteractor(
            subscriptionService: SubscriptionService.shared,
            handlers: handlers ?? SubscriptionHandlers(
                onSuccessPurchase: closeHandler,
                onSuccessRestore: closeHandler,
                onClose: closeHandler
            )
        )
        interactor.output = presenter
        interactor.router = router

        controller.output = interactor

        return controller
    }
}

extension SubscriptionBuilderImpl: SubscriptionBuilder {
    public func build() -> UIViewController {
        internalBuild(handlers: nil)
    }
    
    public func build(handlers: SubscriptionHandlers) -> UIViewController {
        internalBuild(handlers: handlers)
    }
}

public extension SubscriptionBuilderImpl {
    convenience init(presentationData: PresentationData) {
        self.init(languageCode: presentationData.strings.baseLanguageCode)
    }
}
