import Postbox
import Display

enum ChatHistoryInitialSearchLocation: Equatable {
    case index(MessageIndex)
    case id(MessageId)
}

struct ChatHistoryLocationInput: Equatable {
    let content: ChatHistoryLocation
    let id: Int32
}

enum ChatHistoryLocation: Equatable {
    case Initial(count: Int)
    case InitialSearch(location: ChatHistoryInitialSearchLocation, count: Int)
    case Navigation(index: MessageHistoryAnchorIndex, anchorIndex: MessageHistoryAnchorIndex, count: Int)
    case Scroll(index: MessageHistoryAnchorIndex, anchorIndex: MessageHistoryAnchorIndex, sourceIndex: MessageHistoryAnchorIndex, scrollPosition: ListViewScrollPosition, animated: Bool)
}
