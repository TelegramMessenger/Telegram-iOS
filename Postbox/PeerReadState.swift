
public struct PeerReadState: Equatable {
    public let maxReadId: MessageId.Id
    public let maxKnownId: MessageId.Id
    public let count: Int32
    
    public init(maxReadId: MessageId.Id, maxKnownId: MessageId.Id, count: Int32) {
        self.maxReadId = maxReadId
        self.maxKnownId = maxKnownId
        self.count = count
    }
}

public func ==(lhs: PeerReadState, rhs: PeerReadState) -> Bool {
    return lhs.maxReadId == rhs.maxReadId && lhs.maxKnownId == rhs.maxKnownId && lhs.count == rhs.count
}

struct CombinedPeerReadState {
    let states: [(MessageId.Namespace, PeerReadState)]
}
