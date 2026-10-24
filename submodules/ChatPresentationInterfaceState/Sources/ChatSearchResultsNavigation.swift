import Foundation
import TelegramCore

/// The current result's position counted from the newest (1-based), as the search panel's "n of N" shows it.
/// `messageIndices` is `ChatSearchResultsState.messageIndices`, oldest first.
public func chatSearchResultsPosition(messageIndices: [EngineMessage.Index], currentId: EngineMessage.Id?) -> Int? {
    guard let currentId, let index = messageIndices.firstIndex(where: { $0.id == currentId }) else {
        return nil
    }
    return messageIndices.count - index
}

/// The result that picking `messageId` from the results list makes current: that message, if it is one of the loaded
/// results, so the counter and the arrows go on from it.
public func chatSearchResultsCurrentId(selecting messageId: EngineMessage.Id, in messageIndices: [EngineMessage.Index]) -> EngineMessage.Id? {
    guard messageIndices.contains(where: { $0.id == messageId }) else {
        return nil
    }
    return messageId
}
