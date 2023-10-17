import Foundation
import Postbox
import Display

public enum ChatHistoryInitialSearchLocation: Equatable {
    case index(MessageIndex)
    case id(MessageId)
}

public struct MessageHistoryScrollToSubject: Equatable {
    public var index: MessageHistoryAnchorIndex
    public var quote: String?
    
    public init(index: MessageHistoryAnchorIndex, quote: String?) {
        self.index = index
        self.quote = quote
    }
}

public struct MessageHistoryInitialSearchSubject: Equatable {
    public var location: ChatHistoryInitialSearchLocation
    public var quote: String?
    
    public init(location: ChatHistoryInitialSearchLocation, quote: String?) {
        self.location = location
        self.quote = quote
    }
}

public enum ChatHistoryLocation: Equatable {
    case Initial(count: Int)
    case InitialSearch(subject: MessageHistoryInitialSearchSubject, count: Int, highlight: Bool)
    case Navigation(index: MessageHistoryAnchorIndex, anchorIndex: MessageHistoryAnchorIndex, count: Int, highlight: Bool)
    case Scroll(subject: MessageHistoryScrollToSubject, anchorIndex: MessageHistoryAnchorIndex, sourceIndex: MessageHistoryAnchorIndex, scrollPosition: ListViewScrollPosition, animated: Bool, highlight: Bool)
}

public struct ChatHistoryLocationInput: Equatable {
    public var content: ChatHistoryLocation
    public var id: Int32
    
    public init(content: ChatHistoryLocation, id: Int32) {
        self.content = content
        self.id = id
    }
}
