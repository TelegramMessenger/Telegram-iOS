import Postbox
import TelegramCore
import TelegramPresentationData
import MergeLists
import TemporaryCachedPeerDataManager
import AccountContext

public enum ChatMessageEntryContentType {
    case generic
    case largeEmoji
    case animatedEmoji
}

public struct ChatMessageEntryAttributes: Equatable {
    public var rank: CachedChannelAdminRank?
    public var isContact: Bool
    public var contentTypeHint: ChatMessageEntryContentType
    public var updatingMedia: ChatUpdatingMessageMedia?
    public var isPlaying: Bool
    public var isCentered: Bool
    public var authorStoryStats: PeerStoryStats?
    
    public init(rank: CachedChannelAdminRank?, isContact: Bool, contentTypeHint: ChatMessageEntryContentType, updatingMedia: ChatUpdatingMessageMedia?, isPlaying: Bool, isCentered: Bool, authorStoryStats: PeerStoryStats?) {
        self.rank = rank
        self.isContact = isContact
        self.contentTypeHint = contentTypeHint
        self.updatingMedia = updatingMedia
        self.isPlaying = isPlaying
        self.isCentered = isCentered
        self.authorStoryStats = authorStoryStats
    }
    
    public init() {
        self.rank = nil
        self.isContact = false
        self.contentTypeHint = .generic
        self.updatingMedia = nil
        self.isPlaying = false
        self.isCentered = false
        self.authorStoryStats = nil
    }
}

public enum ChatInfoData: Equatable {
    case botInfo(title: String, text: String, photo: TelegramMediaImage?, video: TelegramMediaFile?)
    case userInfo(peer: EnginePeer, verification: PeerVerification?, registrationDate: String?, phoneCountry: String?, groupsInCommonCount: Int32)
}

public enum ChatHistoryEntry: Identifiable, Comparable {
    case MessageEntry(Message, ChatPresentationData, Bool, MessageHistoryEntryLocation?, ChatHistoryMessageSelection, ChatMessageEntryAttributes)
    case MessageGroupEntry(Int64, [(Message, Bool, ChatHistoryMessageSelection, ChatMessageEntryAttributes, MessageHistoryEntryLocation?)], ChatPresentationData)
    case UnreadEntry(MessageIndex, ChatPresentationData)
    case ReplyCountEntry(MessageIndex, Bool, Int, ChatPresentationData)
    case ChatInfoEntry(ChatInfoData, ChatPresentationData)
    case SearchEntry(PresentationTheme, PresentationStrings)
    
    public var stableId: UInt64 {
        switch self {
            case let .MessageEntry(message, _, _, _, _, attributes):
                let type: UInt64
                switch attributes.contentTypeHint {
                    case .generic:
                        type = 2
                    case .largeEmoji:
                        type = 3
                    case .animatedEmoji:
                        type = 4
                }
                return UInt64(message.stableId) | ((type << 40))
            case let .MessageGroupEntry(groupInfo, _, _):
                return UInt64(bitPattern: groupInfo) | ((UInt64(2) << 40))
            case .UnreadEntry:
                return UInt64(4) << 40
            case .ReplyCountEntry:
                return UInt64(5) << 40
            case .ChatInfoEntry:
                return UInt64(6) << 40
            case .SearchEntry:
                return UInt64(7) << 40
        }
    }
    
    public var index: MessageIndex {
        switch self {
            case let .MessageEntry(message, _, _, _, _, _):
                return message.index
            case let .MessageGroupEntry(_, messages, _):
                return messages[messages.count - 1].0.index
            case let .UnreadEntry(index, _):
                return index
            case let .ReplyCountEntry(index, _, _, _):
                return index
            case .ChatInfoEntry:
                return MessageIndex.absoluteLowerBound()
            case .SearchEntry:
                return MessageIndex.absoluteLowerBound()
        }
    }
    
    public var firstIndex: MessageIndex {
        switch self {
            case let .MessageEntry(message, _, _, _, _, _):
                return message.index
            case let .MessageGroupEntry(_, messages, _):
                return messages[0].0.index
            case let .UnreadEntry(index, _):
                return index
            case let .ReplyCountEntry(index, _, _, _):
                return index
            case .ChatInfoEntry:
                return MessageIndex.absoluteLowerBound()
            case .SearchEntry:
                return MessageIndex.absoluteLowerBound()
        }
    }
    
    public var timestamp: Int32? {
        switch self {
        case let .MessageEntry(message, _, _, _, _, _):
            return message.timestamp
        case let .MessageGroupEntry(_, messages, _):
            return messages[0].0.timestamp
        default:
            return nil
        }
    }

    public static func ==(lhs: ChatHistoryEntry, rhs: ChatHistoryEntry) -> Bool {
        switch lhs {
            case let .MessageEntry(lhsMessage, lhsPresentationData, lhsRead, _, lhsSelection, lhsAttributes):
                switch rhs {
                    case let .MessageEntry(rhsMessage, rhsPresentationData, rhsRead, _, rhsSelection, rhsAttributes) where lhsMessage.index == rhsMessage.index && lhsMessage.flags == rhsMessage.flags && lhsRead == rhsRead:
                        if lhsPresentationData !== rhsPresentationData {
                            return false
                        }
                        if lhsMessage.stableVersion != rhsMessage.stableVersion {
                            return false
                        }
                        
                        if lhsMessage.peers.count != rhsMessage.peers.count {
                            return false
                        }
                        for (id, peer) in lhsMessage.peers {
                            if let otherPeer = rhsMessage.peers[id] {
                                if !peer.isEqual(otherPeer) {
                                    return false
                                }
                            }
                        }
                        
                        if lhsMessage.media.count != rhsMessage.media.count {
                            return false
                        }
                        for i in 0 ..< lhsMessage.media.count {
                            if !lhsMessage.media[i].isEqual(to: rhsMessage.media[i]) {
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
                        if lhsMessage.associatedStories.count != rhsMessage.associatedStories.count {
                            return false
                        }
                        if !lhsMessage.associatedStories.isEmpty {
                            for (id, story) in lhsMessage.associatedStories {
                                if let otherStory = rhsMessage.associatedStories[id] {
                                    if story != otherStory {
                                        return false
                                    }
                                } else {
                                    return false
                                }
                            }
                        }
                        if lhsSelection != rhsSelection {
                            return false
                        }
                        if lhsAttributes != rhsAttributes {
                            return false
                        }
                        return true
                    default:
                        return false
                }
            case let .MessageGroupEntry(lhsGroupInfo, lhsMessages, lhsPresentationData):
                if case let .MessageGroupEntry(rhsGroupInfo, rhsMessages, rhsPresentationData) = rhs, lhsGroupInfo == rhsGroupInfo, lhsPresentationData === rhsPresentationData, lhsMessages.count == rhsMessages.count {
                    for i in 0 ..< lhsMessages.count {
                        let (lhsMessage, lhsRead, lhsSelection, lhsAttributes, lhsLocation) = lhsMessages[i]
                        let (rhsMessage, rhsRead, rhsSelection, rhsAttributes, rhsLocation) = rhsMessages[i]
                        
                        if lhsMessage.id != rhsMessage.id {
                            return false
                        }
                        if lhsMessage.timestamp != rhsMessage.timestamp {
                            return false
                        }
                        if lhsMessage.flags != rhsMessage.flags {
                            return false
                        }
                        if lhsRead != rhsRead {
                            return false
                        }
                        if lhsSelection != rhsSelection {
                            return false
                        }
                        if lhsPresentationData !== rhsPresentationData {
                            return false
                        }
                        if lhsMessage.stableVersion != rhsMessage.stableVersion {
                            return false
                        }
                        if lhsMessage.media.count != rhsMessage.media.count {
                            return false
                        }
                        for i in 0 ..< lhsMessage.media.count {
                            if !lhsMessage.media[i].isEqual(to: rhsMessage.media[i]) {
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
                        if lhsMessage.associatedStories.count != rhsMessage.associatedStories.count {
                            return false
                        }
                        if !lhsMessage.associatedStories.isEmpty {
                            for (id, story) in lhsMessage.associatedStories {
                                if let otherStory = rhsMessage.associatedStories[id] {
                                    if story != otherStory {
                                        return false
                                    }
                                } else {
                                    return false
                                }
                            }
                        }
                        if lhsAttributes != rhsAttributes {
                            return false
                        }
                        if lhsLocation != rhsLocation {
                            return false
                        }
                    }
                    
                    return true
                } else {
                    return false
                }
            case let .UnreadEntry(lhsIndex, lhsPresentationData):
                if case let .UnreadEntry(rhsIndex, rhsPresentationData) = rhs, lhsIndex == rhsIndex, lhsPresentationData === rhsPresentationData {
                    return true
                } else {
                    return false
                }
            case let .ReplyCountEntry(lhsIndex, lhsIsComments, lhsCount, lhsPresentationData):
                if case let .ReplyCountEntry(rhsIndex, rhsIsComments, rhsCount, rhsPresentationData) = rhs, lhsIndex == rhsIndex, lhsIsComments == rhsIsComments, lhsCount == rhsCount, lhsPresentationData === rhsPresentationData {
                    return true
                } else {
                    return false
                }
            case let .ChatInfoEntry(lhsData, lhsPresentationData):
                if case let .ChatInfoEntry(rhsData, rhsPresentationData) = rhs, lhsData == rhsData, lhsPresentationData === rhsPresentationData {
                    return true
                } else {
                    return false
                }
            case let .SearchEntry(lhsTheme, lhsStrings):
                if case let .SearchEntry(rhsTheme, rhsStrings) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public static func <(lhs: ChatHistoryEntry, rhs: ChatHistoryEntry) -> Bool {
        let lhsIndex = lhs.index
        let rhsIndex = rhs.index
        if lhsIndex == rhsIndex {
            return lhs.stableId < rhs.stableId
        } else {
            return lhsIndex < rhsIndex
        }
    }
}
