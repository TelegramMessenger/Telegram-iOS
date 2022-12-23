import Foundation

public struct UserTicket {
    public let drawDate: Date
    public let numbers: [Int]
    
    public init(drawDate: Date, numbers: [Int]) {
        self.drawDate = drawDate
        self.numbers = numbers
    }
}
