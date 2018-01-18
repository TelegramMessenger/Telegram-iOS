import Foundation

public struct GroupFeedReadState: Equatable {
    public let maxReadIndex: MessageIndex
    
    public init(maxReadIndex: MessageIndex) {
        self.maxReadIndex = maxReadIndex
    }
    
    public static func ==(lhs: GroupFeedReadState, rhs: GroupFeedReadState) -> Bool {
        if lhs.maxReadIndex != rhs.maxReadIndex {
            return false
        }
        return true
    }
    
    func isIncomingMessageIndexRead(_ index: MessageIndex) -> Bool {
        return self.maxReadIndex >= index
    }
}
