import Foundation
import NGAppCache
import NGData

public protocol GetFeaturedSpecialOfferUseCase {
    func fetchFeaturedSpecialOffer(completion: ((SpecialOffer?) -> ())?)
}

public class GetFeaturedSpecialOfferUseCaseImpl {
    
    //  MARK: - Dependencies
    
    private let specialOfferService: SpecialOfferService
    private let scheduleService: SpecialOfferScheduleService
    
    //  MARK: - Lifecycle
    
    public init(specialOfferService: SpecialOfferService, specialOfferScheduleService: SpecialOfferScheduleService) {
        self.specialOfferService = specialOfferService
        self.scheduleService = specialOfferScheduleService
    }
}

extension GetFeaturedSpecialOfferUseCaseImpl: GetFeaturedSpecialOfferUseCase {
    public func fetchFeaturedSpecialOffer(completion: ((SpecialOffer?) -> ())?) {
        specialOfferService.fetchSpecialOffer { [weak self] specialOffer in
            guard let self = self else { return }
            
            guard let specialOffer = specialOffer else {
                self.cancelAllSpecialOfferSchedules()
                completion?(nil)
                return
            }
            
            if !specialOffer.shouldAutoshowToPremiumUser, isPremium() {
                self.cancelSchedule(forOfferWith: specialOffer.id)
                completion?(nil)
                return
            }
            
            if self.specialOfferService.wasSpecialOfferSeen(id: specialOffer.id) {
                self.cancelSchedule(forOfferWith: specialOffer.id)
                completion?(nil)
                return
            }
            
            if let scheduledAt = self.scheduleService.getScheduledAtDate(forOfferWith: specialOffer.id) {
                let fireDate: Date
                if let autoshowTimeInterval = specialOffer.autoshowTimeInterval {
                    fireDate = scheduledAt.addingTimeInterval(autoshowTimeInterval)
                } else {
                    fireDate = .distantPast
                }
                
                if fireDate < Date() {
                    self.cancelSchedule(forOfferWith: specialOffer.id)
                    
                    if AppCache.appLaunchCount > 1 {
                        completion?(specialOffer)
                    } else {
                        completion?(nil)
                    }
                } else {
                    completion?(nil)
                }
            } else {
                self.scheduleService.schedule(offer: specialOffer)
                completion?(nil)
            }
        }
    }
}

//  MARK: - Private Functions

private extension GetFeaturedSpecialOfferUseCaseImpl {
    func cancelSchedule(forOfferWith id: String) {
        scheduleService.cancelSchedule(forOfferWith: id)
    }
    
    func cancelAllSpecialOfferSchedules() {
        scheduleService.cancelAllSchedules()
    }
}
