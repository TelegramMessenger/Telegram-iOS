
public enum PeerReadState: Equatable, CustomStringConvertible {
    case idBased(maxIncomingReadId: MessageId.Id, maxOutgoingReadId: MessageId.Id, maxKnownId: MessageId.Id, count: Int32)
    case indexBased(maxIncomingReadIndex: MessageIndex, maxOutgoingReadIndex: MessageIndex, count: Int32)
    
    public var count: Int32 {
        switch self {
            case let .idBased(_, _, _, count):
                return count
            case let .indexBased(_, _, count):
                return count
        }
    }
    
    func withAddedCount(_ value: Int32) -> PeerReadState {
        switch self {
            case let .idBased(maxIncomingReadId, maxOutgoingReadId, maxKnownId, count):
                return .idBased(maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: count + value)
            case let .indexBased(maxIncomingReadIndex, maxOutgoingReadIndex, count):
                return .indexBased(maxIncomingReadIndex: maxIncomingReadIndex, maxOutgoingReadIndex: maxOutgoingReadIndex, count: count + value)
        }
    }
    
    public var description: String {
        switch self {
            case let .idBased(maxIncomingReadId, maxOutgoingReadId, maxKnownId, count):
                return "(PeerReadState maxIncomingReadId: \(maxIncomingReadId), maxOutgoingReadId: \(maxOutgoingReadId) maxKnownId: \(maxKnownId), count: \(count)"
            case let .indexBased(maxIncomingReadIndex, maxOutgoingReadIndex, count):
                return "(PeerReadState maxIncomingReadIndex: \(maxIncomingReadIndex), maxOutgoingReadIndex: \(maxOutgoingReadIndex), count: \(count)"
        }
    }
    
    public static func ==(lhs: PeerReadState, rhs: PeerReadState) -> Bool {
        switch lhs {
            case let .idBased(maxIncomingReadId, maxOutgoingReadId, maxKnownId, count):
                if case .idBased(maxIncomingReadId, maxOutgoingReadId, maxKnownId, count) = rhs {
                    return true
                } else {
                    return false
                }
            case let .indexBased(maxIncomingReadIndex, maxOutgoingReadIndex, count):
                if case .indexBased(maxIncomingReadIndex, maxOutgoingReadIndex, count) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    func isIncomingMessageIndexRead(_ index: MessageIndex) -> Bool {
        switch self {
            case let .idBased(maxIncomingReadId, _, _, _):
                return maxIncomingReadId >= index.id.id
            case let .indexBased(maxIncomingReadIndex, _, _):
                return maxIncomingReadIndex >= index
        }
    }
    
    func isOutgoingMessageIndexRead(_ index: MessageIndex) -> Bool {
        switch self {
            case let .idBased(_, maxOutgoingReadId, _, _):
                return maxOutgoingReadId >= index.id.id
            case let .indexBased(_, maxOutgoingReadIndex, _):
                return maxOutgoingReadIndex >= index
        }
    }
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
    
    public func isOutgoingMessageIndexRead(_ index: MessageIndex) -> Bool {
        for (namespace, readState) in self.states {
            if namespace == index.id.namespace {
                return readState.isOutgoingMessageIndexRead(index)
            }
        }
        return false
    }
    
    public func isIncomingMessageIndexRead(_ index: MessageIndex) -> Bool {
        for (namespace, readState) in self.states {
            if namespace == index.id.namespace {
                return readState.isIncomingMessageIndexRead(index)
            }
        }
        return false
    }
}
