
public protocol PeerNotificationSettings: Coding {
    var isRemovedFromTotalUnreadCount: Bool { get }
    
    func isEqual(to: PeerNotificationSettings) -> Bool
}
