import UIKit
import NGLogging
import NGTheme

public protocol SpecialOfferBuilder {
    func build(offerId: String, onCloseRequest: (() -> ())?) -> UIViewController
}

public class SpecialOfferBuilderImpl: SpecialOfferBuilder {
    
    //  MARK: - Dependencies
    
    private let specialOfferService: SpecialOfferService
    private let ngTheme: NGThemeColors
    
    //  MARK: - Lifecycle
    
    public init(specialOfferService: SpecialOfferService, ngTheme: NGThemeColors) {
        self.specialOfferService = specialOfferService
        self.ngTheme = ngTheme
    }
    
    //  MARK: - Public Functions

    public func build(offerId: String, onCloseRequest: (() -> ())?) -> UIViewController {
        let controller = SpecialOfferViewController(ngTheme: ngTheme)

        let router = SpecialOfferRouter()
        router.parentViewController = controller

        let presenter = SpecialOfferPresenter()
        presenter.output = controller

        let interactor = SpecialOfferInteractor(
            offerId: offerId,
            specialOfferService: specialOfferService,
            eventsLogger: LoggersFactory().createDefaultEventsLogger(),
            onCloseRequest: onCloseRequest
        )
        interactor.output = presenter
        interactor.router = router

        controller.output = interactor

        return controller
    }
}
