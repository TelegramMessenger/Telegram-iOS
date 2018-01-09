import Postbox
import Display

enum ChatHistoryInitialSearchLocation {
    case index(MessageIndex)
    case id(MessageId)
}

enum ChatHistoryLocation: Equatable {
    case Initial(count: Int)
    case InitialSearch(location: ChatHistoryInitialSearchLocation, count: Int)
    case Navigation(index: MessageHistoryAnchorIndex, anchorIndex: MessageHistoryAnchorIndex, count: Int)
    case Scroll(index: MessageHistoryAnchorIndex, anchorIndex: MessageHistoryAnchorIndex, sourceIndex: MessageHistoryAnchorIndex, scrollPosition: ListViewScrollPosition, animated: Bool)
}

func ==(lhs: ChatHistoryLocation, rhs: ChatHistoryLocation) -> Bool {
    switch lhs {
        case let .Navigation(lhsIndex, lhsAnchorIndex, lhsCount):
            switch rhs {
                case let .Navigation(rhsIndex, rhsAnchorIndex, rhsCount) where lhsIndex == rhsIndex && lhsAnchorIndex == rhsAnchorIndex && lhsCount == rhsCount:
                    return true
                default:
                    return false
            }
        default:
            return false
    }
}
