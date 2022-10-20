import Foundation

protocol SpecialOfferPresenterInput { }

protocol SpecialOfferPresenterOutput: AnyObject {
    func display(url: URL)
}

final class SpecialOfferPresenter: SpecialOfferPresenterInput {
    
    //  MARK: - VIP
    
    weak var output: SpecialOfferPresenterOutput!
}

//  MARK: - Output

extension SpecialOfferPresenter: SpecialOfferInteractorOutput {
    func present(specialOffer: SpecialOffer) {
        output.display(url: specialOffer.url)
    }
}
