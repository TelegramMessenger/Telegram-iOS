
public enum PeerReadState: Equatable, CustomStringConvertible {
    case idBased(maxIncomingReadId: MessageId.Id, maxOutgoingReadId: MessageId.Id, maxKnownId: MessageId.Id, count: Int32, markedUnread: Bool)
    case indexBased(maxIncomingReadIndex: MessageIndex, maxOutgoingReadIndex: MessageIndex, count: Int32, markedUnread: Bool)
    
    public var count: Int32 {
        switch self {
            case let .idBased(_, _, _, count, _):
                return count
            case let .indexBased(_, _, count, _):
                return count
        }
    }
    
    public var maxKnownId: MessageId.Id? {
        switch self {
            case let .idBased(_, _, maxKnownId, _, _):
                return maxKnownId
            case  .indexBased:
                return nil
        }
    }
    
    
    public var isUnread: Bool {
        switch self {
            case let .idBased(_, _, _, count, markedUnread):
                return count > 0 || markedUnread
            case let .indexBased(_, _, count, markedUnread):
                return count > 0 || markedUnread
        }
    }
    
    public var markedUnread: Bool {
        switch self {
            case let .idBased(_, _, _, _, markedUnread):
                return markedUnread
            case let .indexBased(_, _, _, markedUnread):
                return markedUnread
        }
    }
    
    func withAddedCount(_ value: Int32) -> PeerReadState {
        switch self {
            case let .idBased(maxIncomingReadId, maxOutgoingReadId, maxKnownId, count, markedUnread):
                return .idBased(maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: count + value, markedUnread: markedUnread)
            case let .indexBased(maxIncomingReadIndex, maxOutgoingReadIndex, count, markedUnread):
                return .indexBased(maxIncomingReadIndex: maxIncomingReadIndex, maxOutgoingReadIndex: maxOutgoingReadIndex, count: count + value, markedUnread: markedUnread)
        }
    }
    
    public var description: String {
        switch self {
            case let .idBased(maxIncomingReadId, maxOutgoingReadId, maxKnownId, count, markedUnread):
                return "(PeerReadState maxIncomingReadId: \(maxIncomingReadId), maxOutgoingReadId: \(maxOutgoingReadId) maxKnownId: \(maxKnownId), count: \(count), markedUnread: \(markedUnread)"
            case let .indexBased(maxIncomingReadIndex, maxOutgoingReadIndex, count, markedUnread):
                return "(PeerReadState maxIncomingReadIndex: \(maxIncomingReadIndex), maxOutgoingReadIndex: \(maxOutgoingReadIndex), count: \(count), markedUnread: \(markedUnread)"
        }
    }
    
    func isIncomingMessageIndexRead(_ index: MessageIndex) -> Bool {
        switch self {
            case let .idBased(maxIncomingReadId, _, _, _, _):
                return maxIncomingReadId >= index.id.id
            case let .indexBased(maxIncomingReadIndex, _, _, _):
                return maxIncomingReadIndex >= index
        }
    }
    
    func isOutgoingMessageIndexRead(_ index: MessageIndex) -> Bool {
        switch self {
            case let .idBased(_, maxOutgoingReadId, _, _, _):
                return maxOutgoingReadId >= index.id.id
            case let .indexBased(_, maxOutgoingReadIndex, _, _):
                return maxOutgoingReadIndex >= index
        }
    }
}

public struct CombinedPeerReadState: Equatable {
    public let states: [(MessageId.Namespace, PeerReadState)]
    
    public init(states: [(MessageId.Namespace, PeerReadState)]) {
        self.states = states
    }
    
    public var count: Int32 {
        var result: Int32 = 0
        for (_, state) in self.states {
            result += state.count
        }
        return result
    }
    
    
    public var markedUnread: Bool {
        for (_, state) in self.states {
            if state.markedUnread {
                return true
            }
        }
        return false
    }
    
    
    public var isUnread: Bool {
        for (_, state) in self.states {
            if state.isUnread {
                return true
            }
        }
        return false
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
