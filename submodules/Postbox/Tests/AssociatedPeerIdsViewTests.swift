import Foundation
import XCTest
@testable import Postbox

/// A folder's badge observes which secret chats belong to the users its folders name, so that one created later counts
/// as soon as it is unread. The view must report a peer stored with an association in the transaction that stores it,
/// and only for the peers it watches.
final class AssociatedPeerIdsViewTests: XCTestCase {
    private var fixture: PostboxFixture!

    private let user = FixturePeer(id: MessageHistoryTableFixture.peerId(600), title: "user")
    private let otherUser = FixturePeer(id: MessageHistoryTableFixture.peerId(601), title: "other user")

    private func secretChat(_ id: Int64, of user: FixturePeer) -> FixturePeer {
        return FixturePeer(id: MessageHistoryTableFixture.peerId(id), title: "secret chat", associatedPeerId: user.id, associatedPeerOverridesIdentity: true)
    }

    override func setUp() {
        super.setUp()
        self.fixture = PostboxFixture(name: "AssociatedPeerIdsViewTests")
        self.fixture.transaction { transaction in
            transaction.updatePeersInternal([self.user, self.otherUser], update: { _, updated in updated })
        }
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    private func store(_ peers: [FixturePeer]) {
        self.fixture.transaction { transaction in
            transaction.updatePeersInternal(peers, update: { _, updated in updated })
        }
    }

    func testAnAssociationThatExistsIsReadAtStart() {
        let secretChat = self.secretChat(610, of: self.user)
        self.store([secretChat])

        let recorder = self.fixture.observe(.associatedPeerIds(peerIds: [self.user.id]), as: AssociatedPeerIdsView.self)
        XCTAssertEqual(recorder.waitForValues(count: 1).last?.associatedPeerIds, [self.user.id: [secretChat.id]])
    }

    func testAPeerStoredWithAnAssociationIsReportedInItsTransaction() {
        let recorder = self.fixture.observe(.associatedPeerIds(peerIds: [self.user.id]), as: AssociatedPeerIdsView.self)
        XCTAssertEqual(recorder.waitForValues(count: 1).last?.associatedPeerIds, [:])

        let secretChat = self.secretChat(610, of: self.user)
        self.store([secretChat])
        XCTAssertEqual(recorder.waitForValues(count: 2).last?.associatedPeerIds, [self.user.id: [secretChat.id]])

        let secondSecretChat = self.secretChat(611, of: self.user)
        self.store([secondSecretChat])
        XCTAssertEqual(recorder.waitForValues(count: 3).last?.associatedPeerIds, [self.user.id: [secretChat.id, secondSecretChat.id]])
    }

    func testAnAssociationWithAnUnwatchedPeerDoesNotUpdateTheView() {
        let recorder = self.fixture.observe(.associatedPeerIds(peerIds: [self.user.id]), as: AssociatedPeerIdsView.self)
        recorder.waitForValues(count: 1)

        self.store([self.secretChat(620, of: self.otherUser)])
        let secretChat = self.secretChat(610, of: self.user)
        self.store([secretChat])

        // The second value is the watched user's secret chat: the other user's made none.
        let values = recorder.waitForValues(count: 2)
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(values.last?.associatedPeerIds, [self.user.id: [secretChat.id]])
    }

    func testAPeerStoredWithAnotherAssociationLeavesTheWatchedPeer() {
        let secretChat = self.secretChat(610, of: self.user)
        self.store([secretChat])
        let recorder = self.fixture.observe(.associatedPeerIds(peerIds: [self.user.id]), as: AssociatedPeerIdsView.self)
        XCTAssertEqual(recorder.waitForValues(count: 1).last?.associatedPeerIds, [self.user.id: [secretChat.id]])

        self.store([self.secretChat(610, of: self.otherUser)])
        XCTAssertEqual(recorder.waitForValues(count: 2).last?.associatedPeerIds, [:])
    }
}
