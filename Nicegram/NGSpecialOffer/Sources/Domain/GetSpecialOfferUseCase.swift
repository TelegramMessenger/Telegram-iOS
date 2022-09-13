public protocol GetSpecialOfferUseCase {
    func fetchSpecialOffer(completion: ((SpecialOffer?) -> ())?)
}

public class GetSpecialOfferUseCaseImpl {
    
    //  MARK: - Dependencies
    
    private let specialOfferService: SpecialOfferService
    
    //  MARK: - Lifecycle
    
    public init(specialOfferService: SpecialOfferService) {
        self.specialOfferService = specialOfferService
    }
}

extension GetSpecialOfferUseCaseImpl: GetSpecialOfferUseCase {
    public func fetchSpecialOffer(completion: ((SpecialOffer?) -> ())?) {
        specialOfferService.fetchSpecialOffer(completion: completion)
    }
}
