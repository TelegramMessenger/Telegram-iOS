import Foundation

public struct MessageHistoryHole: Equatable, CustomStringConvertible {
    public let stableId: UInt32
    public let maxIndex: MessageIndex
    public let min: MessageId.Id
    let tags: UInt32
    
    public init(stableId: UInt32, maxIndex: MessageIndex, min: MessageId.Id, tags: UInt32) {
        self.stableId = stableId
        self.maxIndex = maxIndex
        self.min = min
        self.tags = tags
    }
    
    var id: MessageId {
        return maxIndex.id
    }
    
    public var description: String {
        return "MessageHistoryHole(peerId: \(self.maxIndex.id.peerId), min: \(self.min), max: \(self.maxIndex.id.id))"
    }
}
