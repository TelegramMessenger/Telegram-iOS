import Foundation
import XCTest
@testable import Postbox

/// The history preload manager watches this view to learn which hole to fetch next for
/// a chat with unread messages. It must keep reporting the hole across read-state
/// changes and hole fills for as long as one exists near the unread anchor.
final class MessageOfInterestHolesViewTests: XCTestCase {
    private var fixture: PostboxFixture!

    private let peer = MessageHistoryTableFixture.peerId(400)
    private let namespace = PostboxFixture.messageNamespace

    override func setUp() {
        super.setUp()
        self.fixture = PostboxFixture(name: "MessageOfInterestHolesViewTests")
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func messageId(_ id: Int32) -> MessageId {
        return MessageId(peerId: self.peer, namespace: self.namespace, id: id)
    }

    /// Incoming, so reading one of them subtracts exactly that one from the unread count.
    /// (For a chat whose top message is outgoing, reading anything zeroes the count.)
    private func message(_ id: Int32) -> StoreMessage {
        return MessageHistoryTableFixture.storeMessage(id: self.messageId(id), timestamp: 1000 + id, text: "m\(id)", flags: [.Incoming])
    }

    private var expectedHole: MessageHistoryViewHole {
        return .peer(MessageHistoryViewPeerHole(peerId: self.peer, namespace: self.namespace, threadId: nil))
    }

    /// Messages 12...39 are loaded, 1...11 are still a hole, and 13...39 are unread. The
    /// view shows twenty messages around the unread anchor and looks past the bottom of
    /// that window only while fewer than half of them sit below the anchor, so the hole
    /// is in reach from an anchor at 12 or 13 and out of reach from the top of the chat.
    private func seedChatWithUnreadMessagesAboveAHole() {
        self.fixture.transaction { transaction in
            // A chat the hole table has never seen starts as one hole over its whole id
            // range (the seed configuration registers the namespace for holes); a history
            // fetch then stores what it got and removes the hole over that range.
            let _ = transaction.addMessages((12 ... 39).map(self.message), location: .Random)
            transaction.removeHole(peerId: self.peer, threadId: nil, namespace: self.namespace, space: .everywhere, range: 12 ... (Int32.max - 1))
            transaction.resetIncomingReadStates([self.peer: [self.namespace: .idBased(maxIncomingReadId: 12, maxOutgoingReadId: 12, maxKnownId: 39, count: 27, markedUnread: false)]])
        }
    }

    /// A fetch fills 10...11; 1...9 is still a hole.
    private func fillTopOfTheHole(_ transaction: Transaction) {
        transaction.removeHole(peerId: self.peer, threadId: nil, namespace: self.namespace, space: .everywhere, range: 10 ... 11)
        let _ = transaction.addMessages((10 ... 11).map(self.message), location: .Random)
    }

    /// The ids a hole direction asks to fetch, whichever way round the range is reported.
    private func coveredIds(_ direction: MessageHistoryViewRelativeHoleDirection?) -> ClosedRange<Int32>? {
        guard case let .range(start, end)? = direction else {
            return nil
        }
        return min(start.id, end.id) ... max(start.id, end.id)
    }

    private func observeHoles() -> PostboxFixture.Recorder<MessageOfInterestHolesView> {
        return self.fixture.observe(.messageOfInterestHole(location: .peer(peerId: self.peer, threadId: nil), namespace: self.namespace, count: 20), as: MessageOfInterestHolesView.self)
    }

    // MARK: - Tests

    func testHoleIsReportedForAChatWithUnreadMessages() {
        self.seedChatWithUnreadMessagesAboveAHole()

        let views = self.observeHoles().waitForValues(count: 1)

        XCTAssertEqual(views.last?.closestHole?.hole, self.expectedHole)
        XCTAssertEqual(self.coveredIds(views.last?.closestHole?.direction), 1 ... 11, "\(String(describing: views.last?.closestHole))")
    }

    /// The read state of another namespace must not decide the anchor. (Read states
    /// are kept in a dictionary, so against the old first-entry lookup this fails on
    /// roughly half of all process launches; it is a guard, not a reproduction.)
    func testAnchorComesFromTheViewsOwnNamespace() {
        self.seedChatWithUnreadMessagesAboveAHole()
        self.fixture.transaction { transaction in
            transaction.resetIncomingReadStates([self.peer: [self.namespace + 7: .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 0, count: 0, markedUnread: false)]])
        }

        let views = self.observeHoles().waitForValues(count: 1)

        XCTAssertEqual(self.coveredIds(views.last?.closestHole?.direction), 1 ... 11, "\(String(describing: views.last?.closestHole))")
    }

    func testHoleIsStillReportedAfterTheReadStateChanges() {
        self.seedChatWithUnreadMessagesAboveAHole()
        let recorder = self.observeHoles()
        recorder.waitForValues(count: 1)

        // One more message is read: the unread anchor moves from 12 to 13. The hole
        // below is unchanged, so a correct view has nothing new to say here.
        self.fixture.transaction { transaction in
            transaction.applyIncomingReadMaxId(self.messageId(13))
        }
        // A later fill makes the view speak again; whatever it said in between arrives first.
        self.fixture.transaction(self.fillTopOfTheHole)

        let views = recorder.waitForValues(count: 2)
        XCTAssertTrue(views.allSatisfy { $0.closestHole?.hole == self.expectedHole }, "the view must never stop reporting the hole below the unread messages: \(views.map { String(describing: $0.closestHole) })")
        XCTAssertEqual(self.coveredIds(views.last?.closestHole?.direction), 1 ... 9, "\(String(describing: views.last?.closestHole))")
    }

    func testRemainingHoleIsReportedAfterAPartialFill() {
        self.seedChatWithUnreadMessagesAboveAHole()
        let recorder = self.observeHoles()
        recorder.waitForValues(count: 1)

        self.fixture.transaction(self.fillTopOfTheHole)

        let views = recorder.waitForValues(count: 2)
        XCTAssertEqual(views.last?.closestHole?.hole, self.expectedHole)
        XCTAssertEqual(self.coveredIds(views.last?.closestHole?.direction), 1 ... 9, "\(String(describing: views.last?.closestHole))")
    }
}
