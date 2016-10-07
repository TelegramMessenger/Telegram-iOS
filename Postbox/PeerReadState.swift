
public struct PeerReadState: Equatable, CustomStringConvertible {
    public let maxIncomingReadId: MessageId.Id
    public let maxOutgoingReadId: MessageId.Id
    public let maxKnownId: MessageId.Id
    public let count: Int32
    
    public init(maxIncomingReadId: MessageId.Id, maxOutgoingReadId: MessageId.Id, maxKnownId: MessageId.Id, count: Int32) {
        self.maxIncomingReadId = maxIncomingReadId
        self.maxOutgoingReadId = maxOutgoingReadId
        self.maxKnownId = maxKnownId
        self.count = count
    }
    
    public var description: String {
        return "(PeerReadState maxIncomingReadId: \(maxIncomingReadId), maxOutgoingReadId: \(maxOutgoingReadId) maxKnownId: \(maxKnownId), count: \(count)"
    }
}

public func ==(lhs: PeerReadState, rhs: PeerReadState) -> Bool {
    return lhs.maxIncomingReadId == rhs.maxIncomingReadId && lhs.maxOutgoingReadId == rhs.maxOutgoingReadId && lhs.maxKnownId == rhs.maxKnownId && lhs.count == rhs.count
}

public struct CombinedPeerReadState: Equatable {
    let states: [(MessageId.Namespace, PeerReadState)]
    public var count: Int32 {
        var result: Int32 = 0
        for (_, state) in self.states {
            result += state.count
        }
        return result
    }
    
    public static func ==(lhs: CombinedPeerReadState, rhs: CombinedPeerReadState) -> Bool {
        if lhs.states.count != rhs.states.count {
            return false
        }
        for (lhsNamespace, lhsState) in lhs.states {
            var rhsFound = false
            inner: for (rhsNamespace, rhsState) in rhs.states {
                if rhsNamespace == lhsNamespace {
                    if lhsState != rhsState {
                        return false
                    }
                    rhsFound = true
                    break inner
                }
            }
            if !rhsFound {
                return false
            }
        }
        return true
    }
    
    public func isOutgoingMessageIdRead(_ id: MessageId) -> Bool {
        for (namespace, readState) in self.states {
            if namespace == id.namespace {
                return readState.maxOutgoingReadId >= id.id
            }
        }
        return false
    }
    
    public func isIncomingMessageIdRead(_ id: MessageId) -> Bool {
        for (namespace, readState) in self.states {
            if namespace == id.namespace {
                return readState.maxIncomingReadId >= id.id
            }
        }
        return false
    }
}
