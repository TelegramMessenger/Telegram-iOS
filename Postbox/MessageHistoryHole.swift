import Foundation

public struct MessageHistoryHole: Equatable, CustomStringConvertible {
    public let maxIndex: MessageIndex
    public let min: MessageId.Id
    
    var id: MessageId {
        return maxIndex.id
    }
    
    public var description: String {
        return "MessageHistoryHole(peerId: \(self.maxIndex.id.peerId), min: \(self.min), max: \(self.maxIndex.id.id))"
    }
}

public func ==(lhs: MessageHistoryHole, rhs: MessageHistoryHole) -> Bool {
    return lhs.maxIndex == rhs.maxIndex && lhs.min == rhs.min
}
