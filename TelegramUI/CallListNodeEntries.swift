import Foundation
import Postbox
import TelegramCore

enum CallListNodeEntryId: Hashable {
    case hole(MessageIndex)
    case message(MessageIndex)
    
    var hashValue: Int {
        switch self {
            case let .hole(index):
                return index.hashValue
            case let .message(index):
                return index.hashValue
        }
    }
    
    static func <(lhs: CallListNodeEntryId, rhs: CallListNodeEntryId) -> Bool {
        return lhs.hashValue < rhs.hashValue
    }
    
    static func ==(lhs: CallListNodeEntryId, rhs: CallListNodeEntryId) -> Bool {
        switch lhs {
            case let .hole(index):
                if case .hole(index) = rhs {
                    return true
                } else {
                    return false
                }
            case let .message(index):
                if case .message(index) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private func areMessagesEqual(_ lhsMessage: Message, _ rhsMessage: Message) -> Bool {
    if lhsMessage.stableVersion != rhsMessage.stableVersion {
        return false
    }
    if lhsMessage.id != rhsMessage.id || lhsMessage.flags != rhsMessage.flags {
        return false
    }
    return true
}

enum CallListNodeEntry: Comparable, Identifiable {
    case messageEntry(topMessage: Message, messages: [Message], theme: PresentationTheme, strings: PresentationStrings, editing: Bool, hasActiveRevealControls: Bool)
    case holeEntry(index: MessageIndex, theme: PresentationTheme)
    
    var index: MessageIndex {
        switch self {
            case let .messageEntry(message, _, _, _, _, _):
                return MessageIndex(message)
            case let .holeEntry(index, _):
                return index
        }
    }
    
    var stableId: CallListNodeEntryId {
        switch self {
            case let .messageEntry(message, _, _, _, _, _):
                return .message(MessageIndex(message))
            case let .holeEntry(index, _):
                return .hole(index)
        }
    }
    
    static func <(lhs: CallListNodeEntry, rhs: CallListNodeEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    static func ==(lhs: CallListNodeEntry, rhs: CallListNodeEntry) -> Bool {
        switch lhs {
            case let .messageEntry(lhsMessage, lhsMessages, lhsTheme, lhsStrings, lhsEditing, lhsHasRevealControls):
                if case let .messageEntry(rhsMessage, rhsMessages, rhsTheme, rhsStrings, rhsEditing, rhsHasRevealControls) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsEditing != rhsEditing {
                        return false
                    }
                    if lhsHasRevealControls != rhsHasRevealControls {
                        return false
                    }
                    if !areMessagesEqual(lhsMessage, rhsMessage) {
                        return false
                    }
                    if lhsMessages.count != rhsMessages.count {
                        return false
                    }
                    for i in 0 ..< lhsMessages.count {
                        if !areMessagesEqual(lhsMessages[i], rhsMessages[i]) {
                            return false
                        }
                    }
                    return true
                } else {
                    return false
                }
            case let .holeEntry(lhsIndex, lhsTheme):
                if case let .holeEntry(rhsIndex, rhsTheme) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme {
                    return true
                } else {
                    return false
                }
        }
    }
}

func callListNodeEntriesForView(_ view: CallListView, state: CallListNodeState) -> [CallListNodeEntry] {
    var result: [CallListNodeEntry] = []
    for entry in view.entries {
        switch entry {
            case let .message(topMessage, messages):
                result.append(.messageEntry(topMessage: topMessage, messages: messages, theme: state.theme, strings: state.strings, editing: state.editing, hasActiveRevealControls: state.messageIdWithRevealedOptions == topMessage.id))
            case let .hole(index):
                result.append(.holeEntry(index: index, theme: state.theme))
        }
    }
    return result
}
