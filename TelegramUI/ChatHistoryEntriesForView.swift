import Foundation
import Postbox
import TelegramCore

func chatHistoryEntriesForView(_ view: MessageHistoryView, includeUnreadEntry: Bool, includeEmptyEntry: Bool, includeChatInfoEntry: Bool, includeSearchEntry: Bool, reverse: Bool, groupMessages: Bool, selectedMessages: Set<MessageId>?, presentationData: ChatPresentationData) -> [ChatHistoryEntry] {
    var entries: [ChatHistoryEntry] = []
    
    var groupBucket: [(Message, Bool, ChatHistoryMessageSelection)] = []
    for entry in view.entries {
        switch entry {
            case let .HoleEntry(hole, _):
                if !groupBucket.isEmpty {
                    entries.append(.MessageGroupEntry(groupBucket[0].0.groupInfo!, groupBucket, presentationData))
                    groupBucket.removeAll()
                }
                if view.tagMask == nil {
                    entries.append(.HoleEntry(hole, presentationData.theme, presentationData.strings))
                }
            case let .MessageEntry(message, read, _, monthLocation):
                if groupMessages {
                    if !groupBucket.isEmpty && message.groupInfo != groupBucket[0].0.groupInfo {
                        entries.append(.MessageGroupEntry(groupBucket[0].0.groupInfo!, groupBucket, presentationData))
                        groupBucket.removeAll()
                    }
                    if let _ = message.groupInfo {
                        let selection: ChatHistoryMessageSelection
                        if let selectedMessages = selectedMessages {
                            selection = .selectable(selected: selectedMessages.contains(message.id))
                        } else {
                            selection = .none
                        }
                        groupBucket.append((message, read, selection))
                    } else {
                        let selection: ChatHistoryMessageSelection
                        if let selectedMessages = selectedMessages {
                            selection = .selectable(selected: selectedMessages.contains(message.id))
                        } else {
                            selection = .none
                        }
                        entries.append(.MessageEntry(message, presentationData, read, monthLocation, selection))
                    }
                } else {
                    let selection: ChatHistoryMessageSelection
                    if let selectedMessages = selectedMessages {
                        selection = .selectable(selected: selectedMessages.contains(message.id))
                    } else {
                        selection = .none
                    }
                    entries.append(.MessageEntry(message, presentationData, read, monthLocation, selection))
                }
        }
    }
    
    if !groupBucket.isEmpty {
        assert(groupMessages)
        entries.append(.MessageGroupEntry(groupBucket[0].0.groupInfo!, groupBucket, presentationData))
    }
    
    if let maxReadIndex = view.maxReadIndex, includeUnreadEntry {
        var i = 0
        let unreadEntry: ChatHistoryEntry = .UnreadEntry(maxReadIndex, presentationData.theme, presentationData.strings)
        for entry in entries {
            if entry > unreadEntry {
                if i == 0, case .HoleEntry = entry {
                } else {
                    entries.insert(unreadEntry, at: i)
                }
                break
            }
            i += 1
        }
    }
    
    if includeChatInfoEntry {
        if view.earlierId == nil {
            var cachedPeerData: CachedPeerData?
            for entry in view.additionalData {
                if case let .cachedPeerData(_, data) = entry {
                    cachedPeerData = data
                    break
                }
            }
            if let cachedPeerData = cachedPeerData as? CachedUserData, let botInfo = cachedPeerData.botInfo, !botInfo.description.isEmpty {
                entries.insert(.ChatInfoEntry(botInfo.description, presentationData.theme, presentationData.strings), at: 0)
            } else if view.entries.isEmpty && includeEmptyEntry {
                entries.insert(.EmptyChatInfoEntry(presentationData.theme, presentationData.strings, view.tagMask), at: 0)
            }
        }
    } else if includeSearchEntry {
        if view.laterId == nil {
            var hasMessages = false
            loop: for entry in view.entries {
                if case .MessageEntry = entry {
                    hasMessages = true
                    break loop
                }
            }
            if hasMessages {
                entries.append(.SearchEntry(presentationData.theme, presentationData.strings))
            }
        }
    }
    
    if reverse {
        return entries.reversed()
    } else {
        return entries
    }
}
