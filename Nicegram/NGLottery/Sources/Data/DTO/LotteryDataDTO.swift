import EsimApiClientDefinition
import Foundation
import NGCore

struct LotteryDataDTO: Decodable {
    private let info: InfoDTO
    
    func mapToLotteryData() -> LotteryNetworkData {
        return info.mapToLotteryData()
    }
}

private struct InfoDTO: Decodable {
    @DrawDate var currentDrawDate: Date
    @DrawDate var nextDrawDate: Date
    @DrawDate var currentDrawBlockedAtDate: Date
    let lastWinningTickets: [PastDrawDTO]
    let lottoPrize: Double
    let availableToGenerateCount: Int?
    let ticketsForCurrentDraw: [UserTicketDTO]?
    let ticketsDrawHistory: [UserTicketDTO]?
    @EsimApiOptionalDate var dateReceiveTicketViaSubscription: Date?
    
    struct PastDrawDTO: Decodable {
        @DrawDate var date: Date
        let number: TicketNumbersDTO
    }
    
    struct UserTicketDTO: Decodable {
        @DrawDate var date: Date
        let number: TicketNumbersDTO
    }
    
    func mapToLotteryData() -> LotteryNetworkData {
        return LotteryNetworkData(
            currentDraw: CurrentDraw(
                blockDate: currentDrawBlockedAtDate,
                date: currentDrawDate,
                jackpot: Money(amount: lottoPrize, currency: .usd)
            ),
            nextDrawDate: self.nextDrawDate,
            pastDraws: lastWinningTickets.map { dto in
                return .init(date: dto.date, winningNumbers: dto.number.numbers)
            },
            userActiveTickets: ticketsForCurrentDraw?.map { dto in
                return .init(drawDate: dto.date, numbers: dto.number.numbers)
            } ?? [],
            userAvailableTicketsCount: self.availableToGenerateCount ?? 0,
            userPastTickets: ticketsDrawHistory?.map { dto in
                return .init(drawDate: dto.date, numbers: dto.number.numbers)
            } ?? [],
            nextTicketForPremiumDate: dateReceiveTicketViaSubscription
        )
    }
}

@propertyWrapper
private struct DrawDate: Decodable {
    public var wrappedValue: Date
    
    public init(from decoder: Decoder) throws {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "EST")
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let container = try decoder.singleValueContainer()
        
        let string = try container.decode(String.self)
        if let dateFromString = dateFormatter.date(from: string) {
            wrappedValue = dateFromString
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected \(dateFormatter.dateFormat ?? ""), but found \(string) instead")
        }
    }
}
