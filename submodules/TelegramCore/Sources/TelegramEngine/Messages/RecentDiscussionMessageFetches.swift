import Foundation
import Postbox
import SwiftSignalKit

/// Threads whose `messages.getDiscussionMessage` the opener fetched moments ago. The thread's history
/// context, created right after, fetches the same answer for its outgoing read mark; within
/// `freshness` it uses the opener's instead (both forms of the request return the same read state,
/// measured 2026-10-20).
final class RecentDiscussionMessageFetches {
    static let freshness: Double = 30.0
    
    private let now: () -> Double
    private let timestamps = Atomic<[PeerAndBoundThreadId: Double]>(value: [:])
    
    init(now: @escaping () -> Double = { CFAbsoluteTimeGetCurrent() }) {
        self.now = now
    }
    
    func noteFetched(_ id: PeerAndBoundThreadId) {
        let timestamp = self.now()
        let _ = self.timestamps.modify { timestamps in
            var timestamps = timestamps.filter { timestamp - $0.value < RecentDiscussionMessageFetches.freshness }
            timestamps[id] = timestamp
            return timestamps
        }
    }
    
    func wasFetchedRecently(_ id: PeerAndBoundThreadId) -> Bool {
        let timestamp = self.now()
        return self.timestamps.with { timestamps in
            if let fetched = timestamps[id] {
                return timestamp - fetched < RecentDiscussionMessageFetches.freshness
            } else {
                return false
            }
        }
    }
}
