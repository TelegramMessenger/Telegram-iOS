import Foundation

public struct LotteryNetworkData {
    public let currentDraw: CurrentDraw
    public let nextDrawDate: Date
    public let pastDraws: [PastDraw]
    public let userActiveTickets: [UserTicket]
    public let userAvailableTicketsCount: Int
    public let userPastTickets: [UserTicket]
    public let nextTicketForPremiumDate: Date?
}
