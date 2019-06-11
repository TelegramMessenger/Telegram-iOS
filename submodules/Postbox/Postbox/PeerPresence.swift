
public protocol PeerPresence: class, PostboxCoding {
    func isEqual(to: PeerPresence) -> Bool
}
