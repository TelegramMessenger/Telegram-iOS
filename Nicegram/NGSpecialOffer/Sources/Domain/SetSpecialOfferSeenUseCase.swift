public protocol SetSpecialOfferSeenUseCase {
    func markAsSeen(offerId: String)
}

public class SetSpecialOfferSeenUseCaseImpl {
    
    //  MARK: - Dependencies
    
    private let specialOfferService: SpecialOfferService
    private let scheduleService: SpecialOfferScheduleService
    
    //  MARK: - Lifecycle
    
    public init(specialOfferService: SpecialOfferService, specialOfferScheduleService: SpecialOfferScheduleService) {
        self.specialOfferService = specialOfferService
        self.scheduleService = specialOfferScheduleService
    }
}

extension SetSpecialOfferSeenUseCaseImpl: SetSpecialOfferSeenUseCase {
    public func markAsSeen(offerId: String) {
        specialOfferService.markAsSeen(offerId: offerId)
        scheduleService.cancelSchedule(forOfferWith: offerId)
    }
}
