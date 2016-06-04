
public struct PeerReadState: Equatable, CustomStringConvertible {
    public let maxReadId: MessageId.Id
    public let maxKnownId: MessageId.Id
    public let count: Int32
    
    public init(maxReadId: MessageId.Id, maxKnownId: MessageId.Id, count: Int32) {
        self.maxReadId = maxReadId
        self.maxKnownId = maxKnownId
        self.count = count
    }
    
    public var description: String {
        return "(PeerReadState maxReadId: \(maxReadId), maxKnownId: \(maxKnownId), count: \(count))"
    }
}

public func ==(lhs: PeerReadState, rhs: PeerReadState) -> Bool {
    return lhs.maxReadId == rhs.maxReadId && lhs.maxKnownId == rhs.maxKnownId && lhs.count == rhs.count
}

public struct CombinedPeerReadState {
    let states: [(MessageId.Namespace, PeerReadState)]
    var count: Int32 {
        var result: Int32 = 0
        for (_, state) in self.states {
            result += state.count
        }
        return result
    }
}
