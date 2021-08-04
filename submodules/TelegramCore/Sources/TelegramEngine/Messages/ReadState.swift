import Postbox

public struct EngineReadState: Equatable {
    public var unreadCount: Int
    public var isMarkedAsUnread: Bool

    public init(unreadCount: Int, isMarkedAsUnread: Bool) {
        self.unreadCount = unreadCount
        self.isMarkedAsUnread = isMarkedAsUnread
    }
}

public extension EngineReadState {
    var isUnread: Bool {
        return self.unreadCount != 0 || self.isMarkedAsUnread
    }
}

public extension EngineReadState {
    init(_ readState: CombinedPeerReadState) {
        self.init(unreadCount: Int(readState.count), isMarkedAsUnread: readState.markedUnread)
    }
}
