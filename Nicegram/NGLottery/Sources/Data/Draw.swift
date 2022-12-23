import NGCore
import Foundation

public struct CurrentDraw {
    public let blockDate: Date
    public let date: Date
    public let jackpot: Money
}

public struct PastDraw {
    public let date: Date
    public let winningNumbers: [Int]
    
    public init(date: Date, winningNumbers: [Int]) {
        self.date = date
        self.winningNumbers = winningNumbers
    }
}
