import Foundation

public struct PastUserTicketWithDraw {
    public let ticket: UserTicket
    public let draw: PastDraw
}

public struct LotteryData {
    public let currentDraw: CurrentDraw
    public let nextDrawDate: Date
    public let pastDraws: [PastDraw]
    public let lastDraw: PastDraw?
    public let userActiveTickets: [UserTicket]
    public let userAvailableTicketsCount: Int
    public let userPastTickets: [PastUserTicketWithDraw]
    public let nextTicketForPremiumDate: Date?
}
