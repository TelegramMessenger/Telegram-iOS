import Foundation
import Postbox

func chatHistoryEntriesForView(_ view: MessageHistoryView, includeUnreadEntry: Bool) -> [ChatHistoryEntry] {
    var entries: [ChatHistoryEntry] = []
    
    for entry in view.entries {
        switch entry {
            case let .HoleEntry(hole, _):
                entries.append(.HoleEntry(hole))
            case let .MessageEntry(message, read, _):
                entries.append(.MessageEntry(message, read))
        }
    }
    
    if let maxReadIndex = view.maxReadIndex, includeUnreadEntry {
        var inserted = false
        var i = 0
        let unreadEntry: ChatHistoryEntry = .UnreadEntry(maxReadIndex)
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
    
    return entries
}
