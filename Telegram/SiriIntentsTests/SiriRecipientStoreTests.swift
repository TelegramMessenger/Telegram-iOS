import Foundation
import XCTest
import Postbox
import TelegramCore
@testable import IntentsExtensionLib

/// The store-backed recipient decisions: what resolution builds for Siri, and the yes/no the
/// send path needs, read from the same rows.
final class SiriRecipientStoreTests: XCTestCase {
    private var store: TestPostbox!
    private let me = IntentMessageFixtures.user(1, firstName: "Me", flags: [.requirePremium])
    private let alice = IntentMessageFixtures.user(1001, firstName: "Alice", phone: "15551234567")
    private let news = IntentMessageFixtures.broadcastChannel(4001, title: "Daily News")

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.store = try TestPostbox(name: "siri-recipient")
        self.store.transaction { transaction in
            transaction.updatePeersInternal([self.me, self.alice, self.news], update: { _, updated in updated })
        }
    }

    override func tearDownWithError() throws {
        self.store.close()
        self.store = nil
        try super.tearDownWithError()
    }

    func testSendAcceptsAUserAndRefusesAChannel() {
        let accepted = self.store.transaction { transaction in
            return (
                siriRecipientAccepted(transaction: transaction, accountPeerId: self.me.id, peerId: self.alice.id),
                siriRecipientAccepted(transaction: transaction, accountPeerId: self.me.id, peerId: self.news.id),
                siriRecipientAccepted(transaction: transaction, accountPeerId: self.me.id, peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(9999)))
            )
        }
        XCTAssertEqual(accepted?.0, true)
        XCTAssertEqual(accepted?.1, false)
        XCTAssertEqual(accepted?.2, false, "a peer that is not in the store cannot be sent to")
    }

    func testSendAcceptsTheAccountItselfDespiteItsOwnGate() {
        let accepted = self.store.transaction { transaction in
            return siriRecipientAccepted(transaction: transaction, accountPeerId: self.me.id, peerId: self.me.id)
        }
        XCTAssertEqual(accepted, true)
    }

    func testResolutionAndSendAgree() {
        let result = self.store.transaction { transaction -> (Bool, Bool) in
            let resolved: Bool
            if case .person = siriRecipientDecision(transaction: transaction, accountPeerId: self.me.id, peerId: self.alice.id) {
                resolved = true
            } else {
                resolved = false
            }
            return (resolved, siriRecipientAccepted(transaction: transaction, accountPeerId: self.me.id, peerId: self.alice.id))
        }
        XCTAssertEqual(result?.0, result?.1)
    }
}
