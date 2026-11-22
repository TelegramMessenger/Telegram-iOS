import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// The story events a replayed `updateStory` delivers to `AccountStateManager.storyUpdates`; the profile
/// and search story lists replace their item with the event's (StoryListContext).
final class StoryUpdateEventTests: StateSyncTestCase {
    /// `storyItem#16a4b93c` with `.messageMediaUnsupported` (parsed as `TelegramMediaUnsupported`). `min`
    /// is flags.9, `views` flags.3, `out` flags.16 (read as `isMy`).
    private func storyItem(id: Int32, isMin: Bool, viewsCount: Int32?, isOut: Bool) -> Api.StoryItem {
        var flags: Int32 = 0
        if isMin {
            flags |= 1 << 9
        }
        if viewsCount != nil {
            flags |= 1 << 3
        }
        if isOut {
            flags |= 1 << 16
        }
        let views: Api.StoryViews? = viewsCount.map { count -> Api.StoryViews in
            return .storyViews(.init(flags: 0, viewsCount: count, forwardsCount: nil, reactions: nil, reactionsCount: nil, recentViewers: nil))
        }
        return .storyItem(.init(flags: flags, id: id, date: self.baseDate, fromId: nil, fwdFrom: nil, expireDate: self.baseDate + 86400, caption: nil, entities: nil, media: .messageMediaUnsupported, mediaAreas: nil, privacy: nil, views: views, sentReaction: nil, albums: nil, music: nil))
    }

    /// A date group (no pts), as the server pushes `updateStory`.
    private func push(story: Api.StoryItem, of userId: Int64) {
        self.server.push(StateSyncApi.updates([
            .updateStory(.init(peer: StateSyncApi.peerUser(userId), story: story))
        ], date: self.baseDate + 2, seq: 0))
    }

    private func addedItems(_ batches: [[InternalStoryUpdate]], peerId: PeerId, id: Int32) -> [Stories.Item] {
        var result: [Stories.Item] = []
        for batch in batches {
            for update in batch {
                if case let .added(updatePeerId, storedItem) = update, updatePeerId == peerId, case let .item(item) = storedItem, item.id == id {
                    result.append(item)
                }
            }
        }
        return result
    }

    private func storedItem(_ id: StoryId) -> Stories.Item? {
        return self.fixture.transaction { transaction -> Stories.Item? in
            if case let .item(item)? = transaction.getStory(id: id)?.get(Stories.StoredItem.self) {
                return item
            } else {
                return nil
            }
        } ?? nil
    }

    /// Pins R6. A min story carries no views, reaction, `out` flag or forward header of its own: the replay
    /// stores it merged with the item it updates, and the event must carry that stored item, not a parse
    /// of the update alone.
    func testMinStoryUpdateEventCarriesTheStoredItem() {
        let user = self.seedUserChat(200)
        self.launchIdle()
        let storyUpdates = self.fixture.observe(self.stateManager.storyUpdates)
        self.managerQueueRoundTrip()

        // The full item: 5 views, posted by the account. Each push is checked on its own, so a lost one is
        // named instead of ending in a timeout: the drain returns after the batch's dispatchEvents, which
        // delivers the story event before the drain's own operation starts.
        self.push(story: self.storyItem(id: 1, isMin: false, viewsCount: 5, isOut: true), of: 200)
        self.drainOperationQueue()
        XCTAssertEqual(self.server.droppedPushes, 0, "the full story's push reached no update sink")
        XCTAssertEqual(self.storedItem(StoryId(peerId: user, id: 1))?.views?.seenCount, 5, "the full story's push was not applied")
        XCTAssertEqual(self.addedItems(storyUpdates.values, peerId: user, id: 1).count, 1, "the full story's push delivered no story event")
        // The same story again as a min item.
        self.push(story: self.storyItem(id: 1, isMin: true, viewsCount: nil, isOut: false), of: 200)
        self.drainOperationQueue()
        XCTAssertEqual(self.server.droppedPushes, 0, "the min story's push reached no update sink")
        XCTAssertEqual(self.addedItems(storyUpdates.values, peerId: user, id: 1).count, 2, "the min story's push delivered no story event")

        // Control: storage keeps the merged item.
        let stored = self.storedItem(StoryId(peerId: user, id: 1))
        XCTAssertEqual(stored?.views?.seenCount, 5)
        XCTAssertEqual(stored?.isMy, true)

        let added = self.addedItems(storyUpdates.values, peerId: user, id: 1)
        XCTAssertEqual(added.count, 2)
        XCTAssertEqual(added.first?.views?.seenCount, 5)
        // R6: the min update's event lost the views and isMy that storage kept.
        XCTAssertEqual(added.last?.views?.seenCount, 5)
        XCTAssertEqual(added.last?.views, stored?.views)
        XCTAssertEqual(added.last?.isMy, true)
    }
}
