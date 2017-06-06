import Postbox
import TelegramCore

enum ChatHistoryEntry: Identifiable, Comparable {
    case HoleEntry(MessageHistoryHole, PresentationTheme, PresentationStrings)
    case MessageEntry(Message, PresentationTheme, PresentationStrings, Bool, MessageHistoryEntryMonthLocation?)
    case UnreadEntry(MessageIndex, PresentationTheme, PresentationStrings)
    case ChatInfoEntry(String, PresentationTheme, PresentationStrings)
    case EmptyChatInfoEntry(PresentationTheme, PresentationStrings)
    
    var stableId: UInt64 {
        switch self {
            case let .HoleEntry(hole, _, _):
                return UInt64(hole.stableId) | ((UInt64(1) << 40))
            case let .MessageEntry(message, _, _, _, _):
                return UInt64(message.stableId) | ((UInt64(2) << 40))
            case .UnreadEntry:
                return UInt64(3) << 40
            case .ChatInfoEntry:
                return UInt64(4) << 40
            case .EmptyChatInfoEntry:
                return UInt64(5) << 40
        }
    }
    
    var index: MessageIndex {
        switch self {
            case let .HoleEntry(hole, _, _):
                return hole.maxIndex
            case let .MessageEntry(message, _, _, _, _):
                return MessageIndex(message)
            case let .UnreadEntry(index, _, _):
                return index
            case .ChatInfoEntry:
                return MessageIndex.absoluteLowerBound()
            case .EmptyChatInfoEntry:
                return MessageIndex.absoluteLowerBound()
        }
    }
}

func ==(lhs: ChatHistoryEntry, rhs: ChatHistoryEntry) -> Bool {
    switch lhs {
        case let .HoleEntry(lhsHole, lhsTheme, lhsStrings):
            if case let .HoleEntry(rhsHole, rhsTheme, rhsStrings) = rhs, lhsHole == rhsHole, lhsTheme === rhsTheme, lhsStrings === rhsStrings {
                return true
            } else {
                return false
            }
        case let .MessageEntry(lhsMessage, lhsTheme, lhsStrings, lhsRead, _):
            switch rhs {
                case let .MessageEntry(rhsMessage, rhsTheme, rhsStrings, rhsRead, _) where MessageIndex(lhsMessage) == MessageIndex(rhsMessage) && lhsMessage.flags == rhsMessage.flags && lhsRead == rhsRead:
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsMessage.stableVersion != rhsMessage.stableVersion {
                        return false
                    }
                    if lhsMessage.media.count != rhsMessage.media.count {
                        return false
                    }
                    for i in 0 ..< lhsMessage.media.count {
                        if !lhsMessage.media[i].isEqual(rhsMessage.media[i]) {
                            return false
                        }
                    }
                    if lhsMessage.associatedMessages.count != rhsMessage.associatedMessages.count {
                        return false
                    }
                    if !lhsMessage.associatedMessages.isEmpty {
                        for (id, message) in lhsMessage.associatedMessages {
                            if let otherMessage = rhsMessage.associatedMessages[id] {
                                if otherMessage.stableVersion != message.stableVersion {
                                    return false
                                }
                            }
                        }
                    }
                    return true
                default:
                    return false
            }
        case let .UnreadEntry(lhsIndex, lhsTheme, lhsStrings):
            if case let .UnreadEntry(rhsIndex, rhsTheme, rhsStrings) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings {
                return true
            } else {
                return false
            }
        case let .ChatInfoEntry(lhsText, lhsTheme, lhsStrings):
            if case let .ChatInfoEntry(rhsText, rhsTheme, rhsStrings) = rhs, lhsText == rhsText, lhsTheme === rhsTheme, lhsStrings === rhsStrings {
                return true
            } else {
                return false
            }
        case let .EmptyChatInfoEntry(lhsTheme, lhsStrings):
            if case let .EmptyChatInfoEntry(rhsTheme, rhsStrings) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings {
                return true
            } else {
                return false
            }
    }
}

func <(lhs: ChatHistoryEntry, rhs: ChatHistoryEntry) -> Bool {
    let lhsIndex = lhs.index
    let rhsIndex = rhs.index
    if lhsIndex == rhsIndex {
        return lhs.stableId < rhs.stableId
    } else {
        return lhsIndex < rhsIndex
    }
}
