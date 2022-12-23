import Foundation
import NGStoreKitFacade

public protocol GetTicketForPremiumUseCase {
    func getTicket(completion: @escaping (Error?) -> Void)
}

@available(iOS 13.0, *)
public class GetTicketForPremiumUseCaseImpl {
    
    //  MARK: - Dependencies
    
    private let storeKitFacade: StoreKitFacade
    private let getTicketForPremiumService: GetTicketForPremiumService
    private let lotteryDataRepository: LotteryDataRepository
    
    //  MARK: - Lifecycle
    
    public init(storeKitFacade: StoreKitFacade, getTicketForPremiumService: GetTicketForPremiumService, lotteryDataRepository: LotteryDataRepository) {
        self.storeKitFacade = storeKitFacade
        self.getTicketForPremiumService = getTicketForPremiumService
        self.lotteryDataRepository = lotteryDataRepository
    }
}

@available(iOS 13.0, *)
extension GetTicketForPremiumUseCaseImpl: GetTicketForPremiumUseCase {
    public func getTicket(completion: @escaping (Error?) -> Void) {
        storeKitFacade.fetchReceipt(forceRefresh: false) { receiptResult in
            switch receiptResult {
            case .success(let receiptData):
                self.getTicketForPremiumService.getTicket(receiptData: receiptData) { result in
                    switch result {
                    case .success(let lotteryData):
                        self.lotteryDataRepository.setLotteryData(lotteryData)
                        completion(nil)
                    case .failure(let failure):
                        completion(failure)
                    }
                }
            case .failure(let error):
                completion(error)
            }
        }
    }
}
