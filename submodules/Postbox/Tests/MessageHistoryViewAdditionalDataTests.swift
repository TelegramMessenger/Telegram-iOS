import Foundation
import XCTest
@testable import Postbox

/// A history view carries extra entries its consumer asked for. The value it starts
/// with and the value a later transaction updates it to must agree, or the screen
/// shows one thing until the first change and another afterwards.
final class MessageHistoryViewAdditionalDataTests: XCTestCase {
    private var fixture: PostboxFixture!

    private let container = FixturePeer(id: MessageHistoryTableFixture.peerId(499), title: "container")
    private let chat = FixturePeer(id: MessageHistoryTableFixture.peerId(500), title: "chat", containerPeerId: MessageHistoryTableFixture.peerId(499))
    private let bot = FixturePeer(id: MessageHistoryTableFixture.peerId(501), title: "bot")
    private let user = FixturePeer(id: MessageHistoryTableFixture.peerId(502), title: "user")
    /// Shows up under another peer's identity, the way a business account does.
    private let alias = FixturePeer(id: MessageHistoryTableFixture.peerId(503), title: "alias", associatedPeerId: MessageHistoryTableFixture.peerId(502), associatedPeerOverridesIdentity: true)

    override func setUp() {
        super.setUp()
        self.fixture = PostboxFixture(name: "MessageHistoryViewAdditionalDataTests")
        self.fixture.transaction { transaction in
            transaction.updatePeersInternal([self.container, self.chat, self.bot, self.user, self.alias], update: { _, updated in updated })
        }
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func setCachedPeers(_ peers: [FixturePeer]) {
        self.fixture.transaction { transaction in
            transaction.updatePeerCachedData(peerIds: [self.chat.id], update: { _, _ in FixtureCachedPeerData(peerIds: Set(peers.map { $0.id })) })
        }
    }

    private func cachedPeers(in view: MessageHistoryView?) -> [PeerId: Peer]? {
        for entry in view?.additionalData ?? [] {
            if case let .cachedPeerDataPeers(peerId, peers) = entry, peerId == self.chat.id {
                return peers
            }
        }
        return nil
    }

    private func isContact(_ peer: FixturePeer, in view: MessageHistoryView?) -> Bool? {
        for entry in view?.additionalData ?? [] {
            if case let .peerIsContact(peerId, value) = entry, peerId == peer.id {
                return value
            }
        }
        return nil
    }

    private func setContacts(_ peers: [FixturePeer]) {
        self.fixture.transaction { transaction in
            transaction.replaceContactPeerIds(Set(peers.map { $0.id }))
        }
    }

    // MARK: - Cached-data peers

    func testInitialCachedDataPeersAreTheCachedPeersThemselves() {
        self.setCachedPeers([self.bot])

        let views = self.fixture.observeHistory(peerId: self.chat.id, additionalData: [.cachedPeerDataPeers(self.chat.id)]).waitForValues(count: 1)

        let peers = self.cachedPeers(in: views.last)
        XCTAssertEqual(Set(peers?.keys.map { $0 } ?? []), [self.bot.id, self.container.id])
        XCTAssertEqual(peers?[self.bot.id]?.id, self.bot.id, "the entry for the bot must be the bot, not the chat")
        XCTAssertEqual(peers?[self.container.id]?.id, self.container.id)
    }

    func testUpdatedCachedDataPeersAgreeWithTheInitialLoad() {
        self.setCachedPeers([self.bot])
        // Only the peers entry is requested: it must refresh on its own.
        let recorder = self.fixture.observeHistory(peerId: self.chat.id, additionalData: [.cachedPeerDataPeers(self.chat.id)])
        recorder.waitForValues(count: 1)

        self.setCachedPeers([self.user])

        let peers = self.cachedPeers(in: recorder.waitForValues(count: 2).last)
        XCTAssertEqual(Set(peers?.keys.map { $0 } ?? []), [self.user.id, self.container.id], "the refreshed map must hold what a fresh load would: the cached peers and the chat's container peer")
        XCTAssertEqual(peers?[self.user.id]?.id, self.user.id)
    }

    // MARK: - Contact status

    func testInitialContactStatusReflectsTheContactList() {
        self.fixture.transaction { transaction in
            transaction.replaceContactPeerIds([self.user.id])
        }

        let views = self.fixture.observeHistory(peerId: self.chat.id, additionalData: [.peerIsContact(self.user.id)]).waitForValues(count: 1)

        XCTAssertEqual(self.isContact(self.user, in: views.last), true)
    }

    func testContactStatusFollowsAContactListChange() {
        let recorder = self.fixture.observeHistory(peerId: self.chat.id, additionalData: [.peerIsContact(self.user.id)])
        XCTAssertEqual(self.isContact(self.user, in: recorder.waitForValues(count: 1).last), false)

        // Add Contact.
        self.setContacts([self.user])
        XCTAssertEqual(self.isContact(self.user, in: recorder.waitForValues(count: 2).last), true)

        // Delete the only contact: the empty list is a change like any other.
        self.setContacts([])
        XCTAssertEqual(self.isContact(self.user, in: recorder.waitForValues(count: 3).last), false)
    }

    func testContactStatusOfAnIdentityOverridingPeerFollowsItsAssociatedPeer() {
        self.setContacts([self.user])
        let recorder = self.fixture.observeHistory(peerId: self.chat.id, additionalData: [.peerIsContact(self.alias.id)])
        XCTAssertEqual(self.isContact(self.alias, in: recorder.waitForValues(count: 1).last), true, "the alias is a contact because the peer it stands for is")

        self.setContacts([])
        XCTAssertEqual(self.isContact(self.alias, in: recorder.waitForValues(count: 2).last), false)
    }
}
