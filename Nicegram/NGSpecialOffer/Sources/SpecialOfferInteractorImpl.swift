import Foundation
import NGLogging

protocol SpecialOfferInteractorInput { }

protocol SpecialOfferInteractorOutput {
    func present(specialOffer: SpecialOffer)
}

class SpecialOfferInteractor: SpecialOfferInteractorInput {
    
    //  MARK: - VIP
    
    var output: SpecialOfferInteractorOutput!
    var router: SpecialOfferRouter!
    
    //  MARK: - Dependencies
    
    private let specialOfferService: SpecialOfferService
    private let eventsLogger: EventsLogger
    
    //  MARK: - Logic
    
    private var specialOffer: SpecialOffer?
    
    private var onCloseRequest: (() -> ())?
    
    //  MARK: - Lifecycle
    
    init(offerId: String, specialOfferService: SpecialOfferService, eventsLogger: EventsLogger, onCloseRequest: (() -> ())?) {
        self.specialOfferService = specialOfferService
        self.specialOffer = specialOfferService.getSpecialOffer(with: offerId)
        self.eventsLogger = eventsLogger
        self.onCloseRequest = onCloseRequest
    }
}

//  MARK: - Output

extension SpecialOfferInteractor: SpecialOfferViewControllerOutput {
    func viewDidLoad() {
        presentSpecialOffer()
    }
    
    func viewDidAppear() {
        if let specialOffer = specialOffer {
            specialOfferService.markAsViewed(offerId: specialOffer.id)
            eventsLogger.logEvent(name: "special_offer_show_with_id_\(specialOffer.id)")
        }
    }
    
    func didTapClose() {
        onCloseRequest?()
    }
    
    func didTapRetry() {
        presentSpecialOffer()
    }
    
    func didTapSpecialOffer(url: URL) {
        let url = mapSpecialOfferUrl(url)
        
        if let specialOffer = specialOffer {
            eventsLogger.logEvent(name: "special_offer_convert_with_id_\(specialOffer.id)")
        }
        
        router.open(url: url)
    }
}

//  MARK: - Private Functions

private extension SpecialOfferInteractor {
    func presentSpecialOffer() {
        if let specialOffer = specialOffer {
            output.present(specialOffer: specialOffer)
        }
    }
    
    func mapSpecialOfferUrl(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        if components.scheme == "tg" {
            components.scheme = "ncg"
        }
        return components.url ?? url
    }
}
