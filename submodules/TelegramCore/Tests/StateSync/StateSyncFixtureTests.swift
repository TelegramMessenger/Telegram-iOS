import XCTest
import Postbox
@testable import TelegramCore

/// The fixture alone, with no manager and no network: what is seeded reads back, and close()
/// releases the Postbox.
final class StateSyncFixtureTests: XCTestCase {
    private var fixture: StateSyncFixture!

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.fixture = try StateSyncFixture(name: "fixture")
    }

    override func tearDown() {
        if let fixture = self.fixture {
            XCTAssertTrue(fixture.close(), "the Postbox was still retained at close")
        }
        self.fixture = nil
        super.tearDown()
    }

    func testSeededAccountAndChannelReadBack() {
        let channelId = StateSyncFixture.channelPeerId(500)
        let state = AuthorizedAccountState.State(pts: 100, qts: 5, date: 1_700_000_000, seq: 3)
        let channelState = ChannelState(pts: 50, invalidatedPts: nil, synchronizedUntilMessageId: nil)

        self.fixture.seedAccount(state: state)
        self.fixture.seedChannel(StateSyncFixture.makeChannel(id: channelId, accessHash: 77, title: "News"), state: channelState)
        self.fixture.seedChat(peerId: channelId)
        self.fixture.seedReadState(peerId: channelId, maxIncomingReadId: 9, maxOutgoingReadId: 0, maxKnownId: 10, count: 1)
        self.fixture.storeMessage(peerId: channelId, id: 10, timestamp: 1_700_000_000, authorId: nil, text: "hello")

        XCTAssertEqual(self.fixture.accountState()?.state, state)
        XCTAssertEqual(self.fixture.accountState()?.peerId, StateSyncFixture.accountPeerId)
        XCTAssertTrue(self.fixture.peer(StateSyncFixture.accountPeerId) is TelegramUser)
        XCTAssertEqual((self.fixture.peer(channelId) as? TelegramChannel)?.participationStatus, .member)
        XCTAssertEqual(self.fixture.channelState(channelId), channelState)
        XCTAssertEqual(self.fixture.message(MessageId(peerId: channelId, namespace: Namespaces.Message.Cloud, id: 10))?.text, "hello")
        XCTAssertNotNil(self.fixture.combinedReadState(channelId))
        // The first touch adds 1...Int32.max-1; .UpperHistoryBlock removes 10... upward.
        XCTAssertEqual(self.fixture.holes(peerId: channelId), IndexSet(integersIn: 1 ... 9))
    }

    /// `AccountStateManager.defaultGapWaitTimeout`, the default of `init`'s `gapWaitTimeout` (the app passes none),
    /// is 2 s. Only the constant is asserted, not that a manager uses it; the harness passes
    /// `StateSyncFixture.gapWaitTimeout`.
    func testGapWaitDefaultsToTwoSeconds() {
        XCTAssertEqual(AccountStateManager.defaultGapWaitTimeout, 2.0)
    }

    func testNoInnerStateIsStoredAsNil() {
        self.fixture.seedAccount(state: nil)
        XCTAssertNotNil(self.fixture.accountState())
        XCTAssertNil(self.fixture.accountState()?.state)
    }
}
