import Foundation
import Postbox
import TelegramCore

enum ChatListNodeEntryId: Hashable, CustomStringConvertible {
    case Search
    case Hole(Int64)
    case PeerId(Int64)
    
    var hashValue: Int {
        switch self {
        case .Search:
            return 0
        case let .Hole(peerId):
            return peerId.hashValue
        case let .PeerId(peerId):
            return peerId.hashValue
        }
    }
    
    var description: String {
        switch self {
            case .Search:
                return "search"
            case let .Hole(value):
                return "hole(\(value))"
            case let .PeerId(value):
                return "peerId(\(value))"
        }
    }
    
    static func <(lhs: ChatListNodeEntryId, rhs: ChatListNodeEntryId) -> Bool {
        return lhs.hashValue < rhs.hashValue
    }
    
    static func ==(lhs: ChatListNodeEntryId, rhs: ChatListNodeEntryId) -> Bool {
        switch lhs {
        case .Search:
            switch rhs {
            case .Search:
                return true
            default:
                return false
            }
        case let .Hole(lhsId):
            switch rhs {
            case .Hole(lhsId):
                return true
            default:
                return false
            }
        case let .PeerId(lhsId):
            switch rhs {
            case let .PeerId(rhsId):
                return lhsId == rhsId
            default:
                return false
            }
        }
    }
}

enum ChatListNodeEntry: Comparable, Identifiable {
    case SearchEntry(theme: PresentationTheme, text: String)
    case PeerEntry(index: ChatListIndex, theme: PresentationTheme, strings: PresentationStrings, message: Message?, readState: CombinedPeerReadState?, notificationSettings: PeerNotificationSettings?, embeddedInterfaceState: PeerChatListEmbeddedInterfaceState?, peer: RenderedPeer, editing: Bool, hasActiveRevealControls: Bool)
    case HoleEntry(ChatListHole, theme: PresentationTheme)
    
    var index: ChatListIndex {
        switch self {
            case .SearchEntry:
                return ChatListIndex.absoluteUpperBound
            case let .PeerEntry(index, _, _, _, _, _, _, _, _, _):
                return index
            case let .HoleEntry(hole, _):
                return ChatListIndex(pinningIndex: nil, messageIndex: hole.index)
        }
    }
    
    var stableId: ChatListNodeEntryId {
        switch self {
            case .SearchEntry:
                return .Search
            case let .PeerEntry(index, _, _, _, _, _, _, _, _, _):
                return .PeerId(index.messageIndex.id.peerId.toInt64())
            case let .HoleEntry(hole, _):
                return .Hole(Int64(hole.index.id.id))
        }
    }
    
    static func <(lhs: ChatListNodeEntry, rhs: ChatListNodeEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    static func ==(lhs: ChatListNodeEntry, rhs: ChatListNodeEntry) -> Bool {
        switch lhs {
            case let .SearchEntry(lhsTheme, lhsText):
                if case let .SearchEntry(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .PeerEntry(lhsIndex, lhsTheme, lhsStrings, lhsMessage, lhsUnreadCount, lhsNotificationSettings, lhsEmbeddedState, lhsPeer, lhsEditing, lhsHasRevealControls):
                switch rhs {
                    case let .PeerEntry(rhsIndex, rhsTheme, rhsStrings, rhsMessage, rhsUnreadCount, rhsNotificationSettings, rhsEmbeddedState, rhsPeer, rhsEditing, rhsHasRevealControls):
                        if lhsIndex != rhsIndex {
                            return false
                        }
                        if lhsTheme !== rhsTheme {
                            return false
                        }
                        if lhsStrings !== rhsStrings {
                            return false
                        }
                        if lhsMessage?.stableVersion != rhsMessage?.stableVersion {
                            return false
                        }
                        if lhsMessage?.id != rhsMessage?.id || lhsMessage?.flags != rhsMessage?.flags || lhsUnreadCount != rhsUnreadCount {
                            return false
                        }
                        if let lhsNotificationSettings = lhsNotificationSettings, let rhsNotificationSettings = rhsNotificationSettings {
                            if !lhsNotificationSettings.isEqual(to: rhsNotificationSettings) {
                                return false
                            }
                        } else if (lhsNotificationSettings != nil) != (rhsNotificationSettings != nil) {
                            return false
                        }
                        if let lhsEmbeddedState = lhsEmbeddedState, let rhsEmbeddedState = rhsEmbeddedState {
                            if !lhsEmbeddedState.isEqual(to: rhsEmbeddedState) {
                                return false
                            }
                        } else if (lhsEmbeddedState != nil) != (rhsEmbeddedState != nil) {
                            return false
                        }
                        if lhsEditing != rhsEditing {
                            return false
                        }
                        if lhsHasRevealControls != rhsHasRevealControls {
                            return false
                        }
                        if lhsPeer != rhsPeer {
                            return false
                        }
                        
                        return true
                    default:
                        return false
                }
            case let .HoleEntry(lhsHole, lhsTheme):
                switch rhs {
                    case let .HoleEntry(rhsHole, rhsTheme):
                        return lhsHole == rhsHole && lhsTheme === rhsTheme
                    default:
                        return false
                }
        }
    }
}

func chatListNodeEntriesForView(_ view: ChatListView, state: ChatListNodeState) -> [ChatListNodeEntry] {
    var result: [ChatListNodeEntry] = []
    for entry in view.entries {
        switch entry {
            case let .MessageEntry(index, message, combinedReadState, notificationSettings, embeddedState, peer):
                result.append(.PeerEntry(index: index, theme: state.theme, strings: state.strings, message: message, readState: combinedReadState, notificationSettings: notificationSettings, embeddedInterfaceState: embeddedState, peer: peer, editing: state.editing, hasActiveRevealControls: index.messageIndex.id.peerId == state.peerIdWithRevealedOptions))
            case let .HoleEntry(hole):
                result.append(.HoleEntry(hole, theme: state.theme))
        }
    }
    if view.laterIndex == nil {
        result.append(.SearchEntry(theme: state.theme, text: state.strings.ChatSearch_SearchPlaceholder))
    }
    return result
}
