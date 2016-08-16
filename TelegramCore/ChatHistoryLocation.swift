import Postbox
import Display

enum ChatHistoryLocation: Equatable {
    case Initial(count: Int)
    case InitialSearch(messageId: MessageId, count: Int)
    case Navigation(index: MessageIndex, anchorIndex: MessageIndex)
    case Scroll(index: MessageIndex, anchorIndex: MessageIndex, sourceIndex: MessageIndex, scrollPosition: ListViewScrollPosition, animated: Bool)
}

func ==(lhs: ChatHistoryLocation, rhs: ChatHistoryLocation) -> Bool {
    switch lhs {
        case let .Navigation(lhsIndex, lhsAnchorIndex):
            switch rhs {
                case let .Navigation(rhsIndex, rhsAnchorIndex) where lhsIndex == rhsIndex && lhsAnchorIndex == rhsAnchorIndex:
                    return true
                default:
                    return false
            }
        default:
            return false
    }
}
