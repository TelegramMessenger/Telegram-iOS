import Foundation

public struct UnreadSearchBadge: Equatable {
    public var unreadCount: Int32
    public var isMuted: Bool
    
    public init(unreadCount: Int32, isMuted: Bool) {
        self.unreadCount = unreadCount
        self.isMuted = isMuted
    }
}
