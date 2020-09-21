import Foundation
import Postbox
import Display

public enum ChatHistoryInitialSearchLocation: Equatable {
    case index(MessageIndex)
    case id(MessageId)
}

public enum ChatHistoryLocation: Equatable {
    case Initial(count: Int)
    case InitialSearch(location: ChatHistoryInitialSearchLocation, count: Int)
    case Navigation(index: MessageHistoryAnchorIndex, anchorIndex: MessageHistoryAnchorIndex, count: Int)
    case Scroll(index: MessageHistoryAnchorIndex, anchorIndex: MessageHistoryAnchorIndex, sourceIndex: MessageHistoryAnchorIndex, scrollPosition: ListViewScrollPosition, animated: Bool)
}

public struct ChatHistoryLocationInput: Equatable {
    public let content: ChatHistoryLocation
    public let id: Int32
    
    public init(content: ChatHistoryLocation, id: Int32) {
        self.content = content
        self.id = id
    }
}
