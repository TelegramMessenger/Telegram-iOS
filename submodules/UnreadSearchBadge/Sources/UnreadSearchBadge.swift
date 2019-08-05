import Foundation

public enum UnreadSearchBadge: Equatable {
    case muted(Int32)
    case unmuted(Int32)
    
    public var count: Int32 {
        switch self {
        case let .muted(count), let .unmuted(count):
            return count
        }
    }
    
    public var isMuted: Bool {
        switch self {
        case .muted:
            return true
        case .unmuted:
            return false
        }
    }
}
