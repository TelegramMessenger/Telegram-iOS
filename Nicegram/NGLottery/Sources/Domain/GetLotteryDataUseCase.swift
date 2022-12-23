import Combine
import NGCore
import Foundation

@available(iOS 13.0, *)
public protocol GetLotteryDataUseCase {
    func lotteryDataPublisher() -> AnyPublisher<LotteryData?, Never>
}

@available(iOS 13.0, *)
public class GetLotteryDataUseCaseImpl {
    
    //  MARK: - Dependencies
    
    private let lotteryDataRepository: LotteryDataRepository
    
    //  MARK: - Lifecycle
    
    public init(lotteryDataRepository: LotteryDataRepository) {
        self.lotteryDataRepository = lotteryDataRepository
    }
    
}

@available(iOS 13.0, *)
extension GetLotteryDataUseCaseImpl: GetLotteryDataUseCase {
    public func lotteryDataPublisher() -> AnyPublisher<LotteryData?, Never> {
        lotteryDataRepository.lotteryDataPublisher()
            .map { networkData -> LotteryData? in
                guard let networkData else {
                    return nil
                }
                
                let lastDraw = networkData.pastDraws.max(by: { $0.date < $1.date })
                
                return LotteryData(
                    currentDraw: networkData.currentDraw,
                    nextDrawDate: networkData.nextDrawDate,
                    pastDraws: networkData.pastDraws,
                    lastDraw: lastDraw,
                    userActiveTickets: networkData.userActiveTickets,
                    userAvailableTicketsCount: networkData.userAvailableTicketsCount,
                    userPastTickets: networkData.userPastTickets.compactMap { ticket in
                        guard let draw = networkData.pastDraws.first(where: { $0.date == ticket.drawDate }) else {
                            return nil
                        }
                        return PastUserTicketWithDraw(ticket: ticket, draw: draw)
                    },
                    nextTicketForPremiumDate: networkData.nextTicketForPremiumDate
                )
            }
            .eraseToAnyPublisher()
    }
}
