import Foundation
import Postbox
import TelegramCore

func chatHistoryEntriesForView(_ view: MessageHistoryView, includeUnreadEntry: Bool, includeEmptyEntry: Bool, includeChatInfoEntry: Bool, theme: PresentationTheme, strings: PresentationStrings) -> [ChatHistoryEntry] {
    var entries: [ChatHistoryEntry] = []
    
    for entry in view.entries {
        switch entry {
            case let .HoleEntry(hole, _):
                entries.append(.HoleEntry(hole, theme, strings))
            case let .MessageEntry(message, read, _, monthLocation):
                var isClearHistory = false
                if !message.media.isEmpty {
                    if let action = message.media[0] as? TelegramMediaAction, case .historyCleared = action.action {
                        isClearHistory = true
                    }
                }
                if !isClearHistory {
                    entries.append(.MessageEntry(message, theme, strings, read, monthLocation))
                }
        }
    }
    
    if let maxReadIndex = view.maxReadIndex, includeUnreadEntry {
        var inserted = false
        var i = 0
        let unreadEntry: ChatHistoryEntry = .UnreadEntry(maxReadIndex, theme, strings)
        for entry in entries {
            if entry > unreadEntry {
                entries.insert(unreadEntry, at: i)
                inserted = true
                
                break
            }
            i += 1
        }
        if !inserted {
            //entries.append(.UnreadEntry(maxReadIndex))
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
                entries.insert(.ChatInfoEntry(botInfo.description, theme, strings), at: 0)
            } else if view.entries.isEmpty && includeEmptyEntry {
                entries.insert(.EmptyChatInfoEntry(theme, strings), at: 0)
            }
        }
    }
    
    return entries
}
