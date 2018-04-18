import Foundation

public struct GroupFeedReadState: Equatable {
    public let maxReadIndex: MessageIndex
    
    public init(maxReadIndex: MessageIndex) {
        self.maxReadIndex = maxReadIndex
    }
    
    func isIncomingMessageIndexRead(_ index: MessageIndex) -> Bool {
        return self.maxReadIndex >= index
    }
}
