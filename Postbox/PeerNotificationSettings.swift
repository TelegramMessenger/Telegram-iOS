
public protocol PeerNotificationSettings: PostboxCoding {
    var isRemovedFromTotalUnreadCount: Bool { get }
    
    func isEqual(to: PeerNotificationSettings) -> Bool
}
