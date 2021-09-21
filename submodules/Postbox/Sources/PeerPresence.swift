
public protocol PeerPresence: AnyObject, PostboxCoding {
    func isEqual(to: PeerPresence) -> Bool
}

public func arePeerPresencesEqual(_ lhs: PeerPresence?, _ rhs: PeerPresence?) -> Bool {
    if let lhs = lhs, let rhs = rhs {
        return lhs.isEqual(to: rhs)
    } else {
        return (lhs == nil) == (rhs == nil)
    }
}
