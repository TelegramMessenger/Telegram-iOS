import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import MergeLists

enum CallListNodeEntryId: Hashable {
    case setting(Int32)
    case hole(MessageIndex)
    case message(MessageIndex)
    
    var hashValue: Int {
        switch self {
            case let .setting(value):
                return value.hashValue
            case let .hole(index):
                return index.hashValue
            case let .message(index):
                return index.hashValue
        }
    }
    
    static func ==(lhs: CallListNodeEntryId, rhs: CallListNodeEntryId) -> Bool {
        switch lhs {
            case let .setting(value):
                if case .setting(value) = rhs {
                    return true
                } else {
                    return false
                }
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
    case displayTab(PresentationTheme, String, Bool)
    case displayTabInfo(PresentationTheme, String)
    case messageEntry(topMessage: Message, messages: [Message], theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, editing: Bool, hasActiveRevealControls: Bool)
    case holeEntry(index: MessageIndex, theme: PresentationTheme)
    
    var index: MessageIndex {
        switch self {
            case .displayTab:
                return MessageIndex.absoluteUpperBound()
            case .displayTabInfo:
                return MessageIndex.absoluteUpperBound().predecessor()
            case let .messageEntry(message, _, _, _, _, _, _):
                return message.index
            case let .holeEntry(index, _):
                return index
        }
    }
    
    var stableId: CallListNodeEntryId {
        switch self {
            case .displayTab:
                return .setting(0)
            case .displayTabInfo:
                return .setting(1)
            case let .messageEntry(message, _, _, _, _, _, _):
                return .message(message.index)
            case let .holeEntry(index, _):
                return .hole(index)
        }
    }
    
    static func <(lhs: CallListNodeEntry, rhs: CallListNodeEntry) -> Bool {
        switch lhs {
            case .displayTab:
                return false
            case .displayTabInfo:
                switch rhs {
                    case .displayTab:
                        return true
                    default:
                        return false
                }
            case let .holeEntry(lhsIndex, _):
                switch rhs {
                    case let .holeEntry(rhsIndex, _):
                        return lhsIndex < rhsIndex
                    case let .messageEntry(topMessage, _, _, _, _, _, _):
                        return lhsIndex < topMessage.index
                    default:
                        return true
                }
            case let .messageEntry(lhsTopMessage, _, _, _, _, _, _):
                let lhsIndex = lhsTopMessage.index
                switch rhs {
                    case let .holeEntry(rhsIndex, _):
                        return lhsIndex < rhsIndex
                    case let .messageEntry(topMessage, _, _, _, _, _, _):
                        return lhsIndex < topMessage.index
                    default:
                        return true
                }
            
        }
    }
    
    static func ==(lhs: CallListNodeEntry, rhs: CallListNodeEntry) -> Bool {
        switch lhs {
            case let .displayTab(lhsTheme, lhsText, lhsValue):
                if case let .displayTab(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .displayTabInfo(lhsTheme, lhsText):
                if case let .displayTabInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .messageEntry(lhsMessage, lhsMessages, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsEditing, lhsHasRevealControls):
                if case let .messageEntry(rhsMessage, rhsMessages, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsEditing, rhsHasRevealControls) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
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

func callListNodeEntriesForView(_ view: CallListView, state: CallListNodeState, showSettings: Bool, showCallsTab: Bool) -> [CallListNodeEntry] {
    var result: [CallListNodeEntry] = []
    for entry in view.entries {
        switch entry {
            case let .message(topMessage, messages):
                result.append(.messageEntry(topMessage: topMessage, messages: messages, theme: state.presentationData.theme, strings: state.presentationData.strings, dateTimeFormat: state.dateTimeFormat, editing: state.editing, hasActiveRevealControls: state.messageIdWithRevealedOptions == topMessage.id))
            case let .hole(index):
                result.append(.holeEntry(index: index, theme: state.presentationData.theme))
        }
    }
    if showSettings {
        result.append(.displayTabInfo(state.presentationData.theme, state.presentationData.strings.CallSettings_TabIconDescription))
        result.append(.displayTab(state.presentationData.theme, state.presentationData.strings.CallSettings_TabIcon, showCallsTab))
    }
    return result
}

func countMeaningfulCallListEntries(_ entries: [CallListNodeEntry]) -> Int {
    var count: Int = 0
    for entry in entries {
        if case .setting = entry.stableId {} else {
            count += 1
        }
    }
    return count
}
