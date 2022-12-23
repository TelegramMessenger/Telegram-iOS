public protocol CreateTicketUseCase {
    func createTicket(numbers: [Int], completion: @escaping (Error?) -> Void)
}

@available(iOS 13.0, *)
public class CreateTicketUseCaseImpl {
    
    //  MARK: - Dependencies
    
    private let createTicketService: CreateTicketService
    private let lotteryDataRepository: LotteryDataRepository
    
    //  MARK: - Lifecycle
    
    public init(createTicketService: CreateTicketService, lotteryDataRepository: LotteryDataRepository) {
        self.createTicketService = createTicketService
        self.lotteryDataRepository = lotteryDataRepository
    }
    
}

@available(iOS 13.0, *)
extension CreateTicketUseCaseImpl: CreateTicketUseCase {
    public func createTicket(numbers: [Int], completion: @escaping (Error?) -> Void) {
        createTicketService.createTicket(numbers: numbers) { result in
            switch result {
            case .success(let success):
                self.lotteryDataRepository.setLotteryData(success)
                completion(nil)
            case .failure(let failure):
                completion(failure)
            }
        }
    }
}
