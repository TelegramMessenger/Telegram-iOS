import Foundation

public struct ChatListHole: Hashable, CustomStringConvertible {
    public let index: MessageIndex
    
    public init(index: MessageIndex) {
        self.index = index
    }
    
    public var description: String {
        return "ChatListHole(\(self.index.id), \(self.index.timestamp))"
    }
    
    public var hashValue: Int {
        return self.index.hashValue
    }

    public static func <(lhs: ChatListHole, rhs: ChatListHole) -> Bool {
        return lhs.index < rhs.index
    }
}
