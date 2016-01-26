import Foundation

public struct MessageHistoryHole: Equatable {
    let maxIndex: MessageIndex
    let min: MessageId.Id
    
    var id: MessageId {
        return maxIndex.id
    }
}

public func ==(lhs: MessageHistoryHole, rhs: MessageHistoryHole) -> Bool {
    return lhs.maxIndex == rhs.maxIndex && lhs.min == rhs.min
}
