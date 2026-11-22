import Foundation
import XCTest
import SwiftSignalKit
import Postbox
@testable import TelegramCore

/// `AccountStateEventHub` (state-sync spec 3.4) on its own, over the harness's Postbox and network, without a state
/// manager: the order of the three phases of one `dispatchEvents` dispatch, and how its web-page subscriber contexts
/// deliver an update and a removal.
final class AccountStateEventHubTests: StateSyncTestCase {
    /// Entries appended on the hub's queue and read on the test thread.
    private final class EventLog {
        private let lock = NSLock()
        private var entries: [String] = []

        func append(_ entry: String) {
            self.lock.lock()
            self.entries.append(entry)
            self.lock.unlock()
        }

        var values: [String] {
            self.lock.lock()
            defer {
                self.lock.unlock()
            }
            return self.entries
        }
    }

    private func makeHub(queue: Queue) -> AccountStateEventHub {
        return AccountStateEventHub(queue: queue, postbox: self.fixture.postbox, network: self.network, callSessionManager: nil, peerInputActivityManager: nil, updateConfigRequested: nil, isPremiumUpdated: nil)
    }

    /// Phases 1 and 2 run inside `dispatch`: the events that need no storage read reach their pipes before it
    /// returns, the reactions first and even when there are none. Phase 3 runs later, on the queue: the notification
    /// messages the transaction `dispatch` started has read (none here), then the operation's completion.
    func testDispatchFansOutBeforeItReturnsThenDeliversTheNotificationMessagesThenCompletes() {
        let queue = Queue(name: "AccountStateEventHubTests")
        let hub = self.makeHub(queue: queue)
        let log = EventLog()
        let completed = DispatchSemaphore(value: 0)
        var disposables: [Disposable] = []
        queue.sync {
            disposables.append(hub.reactionNotifications.start(next: { reactions in
                log.append("reactions \(reactions.count)")
            }))
            disposables.append(hub.displayAlerts.start(next: { alerts in
                log.append("alerts \(alerts.count)")
            }))
            disposables.append(hub.deletedMessages.start(next: { ids in
                log.append("deleted \(ids.count)")
            }))
            disposables.append(hub.notificationMessages.start(next: { batch in
                log.append("notifications \(batch.count)")
            }))
        }
        let events = AccountFinalStateEvents.testing(deletedMessageIds: [.global(5)], displayAlerts: [(text: "alert", isDropAuth: false)])

        // The notification read holds the hub weakly, as it held the state manager's Impl: keep the hub alive until
        // the completion has run.
        withExtendedLifetime(hub) {
            queue.async {
                hub.dispatch(events, completed: {
                    log.append("completed")
                    completed.signal()
                })
                log.append("returned")
            }
            XCTAssertEqual(completed.wait(timeout: .now() + 10.0), .success)
        }

        XCTAssertEqual(log.values, ["reactions 0", "alerts 1", "deleted 1", "returned", "notifications 0", "completed"])
        for disposable in disposables {
            disposable.dispose()
        }
    }

    /// Phase 3's fan-out: a web page's subscribers get its update; a key holding nil (the page resolved to
    /// `webPageEmpty`) reaches the page's subscribers as nil; an update of a page with no subscriber adds nothing
    /// (three values in all); the sent scheduled messages come after the web pages.
    func testDispatchAfterNotificationMessagesDeliversWebpageUpdatesAndRemovals() {
        let queue = Queue(name: "AccountStateEventHubTests")
        let hub = self.makeHub(queue: queue)
        let removedId = MediaId(namespace: Namespaces.Media.CloudWebpage, id: 1)
        let updatedId = MediaId(namespace: Namespaces.Media.CloudWebpage, id: 2)
        let unwatchedId = MediaId(namespace: Namespaces.Media.CloudWebpage, id: 3)
        let page = TelegramMediaWebpage(webpageId: updatedId, content: .Pending(0, "https://telegram.org/"))
        let scheduledId = MessageId(peerId: StateSyncFixture.userPeerId(200), namespace: Namespaces.Message.Cloud, id: 7)
        let log = EventLog()
        var disposables: [Disposable] = []
        queue.sync {
            disposables.append(hub.updatedWebpage(removedId).start(next: { media in
                log.append("removed: \(media == nil ? "nil" : "page")")
            }))
            disposables.append(hub.updatedWebpage(updatedId).start(next: { media in
                log.append("updated: \(media == nil ? "nil" : "page")")
            }))
            disposables.append(hub.sentScheduledMessageIds.start(next: { ids in
                log.append("scheduled \(ids.count)")
            }))
            hub.dispatchAfterNotificationMessages(AccountFinalStateEvents.testing(
                updatedWebpages: [removedId: nil, updatedId: page, unwatchedId: page],
                sentScheduledMessageIds: [scheduledId]
            ))
        }

        let values = log.values
        XCTAssertEqual(values.count, 3, "log: \(values)")
        // The subscriber contexts are a dictionary: the two pages arrive in its order.
        XCTAssertEqual(Set(values.prefix(2)), ["removed: nil", "updated: page"])
        XCTAssertEqual(values.last, "scheduled 1")
        for disposable in disposables {
            disposable.dispose()
        }
    }
}
