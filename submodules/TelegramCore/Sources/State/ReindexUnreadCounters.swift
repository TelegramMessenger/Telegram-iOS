import Foundation
import Postbox

// Version of the peerSummaryCounterTags mapping that the stored unread counters were built with.
//
// The counters in messageHistoryMetadataTable/groupMessageStatsTable are maintained incrementally:
// ChatListIndexTable only moves a chat between tag buckets when the peer itself changes and its
// tags differ, with both sides computed by the *current* mapping. A mapping that changes in code
// therefore produces no transition at all -- the old contribution stays stranded in the previous
// bucket while later deltas land in the new one, driving it negative. Bump this constant whenever
// the mapping changes so the stored counters are rebuilt once.
//
// 1: secret chats follow their associated user's contact status instead of always counting as
//    non-contacts, so folder badges agree with the chats the folder actually lists.
private let currentUnreadCounterTagsVersion: Int32 = 1

private struct UnreadCounterTagsState: Codable {
    var version: Int32

    init(version: Int32) {
        self.version = version
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.version = (try? container.decode(Int32.self, forKey: "version")) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.version, forKey: "version")
    }
}

func reindexUnreadCountersIfNeeded(transaction: Transaction) {
    let currentState = transaction.getPreferencesEntry(key: PreferencesKeys.unreadCounterTagsState)?.get(UnreadCounterTagsState.self)
    if currentState?.version == currentUnreadCounterTagsVersion {
        return
    }

    // A full rebuild, covering .root, which recalculateChatListGroupStats never touches. This is
    // the same operation a change to the global notification settings already triggers.
    transaction.reindexUnreadCounters()

    transaction.updatePreferencesEntry(key: PreferencesKeys.unreadCounterTagsState, { _ in
        return PreferencesEntry(UnreadCounterTagsState(version: currentUnreadCounterTagsVersion))
    })
}
