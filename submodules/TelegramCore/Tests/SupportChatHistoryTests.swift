import XCTest
import Postbox
@testable import TelegramCore

final class SupportChatHistoryTests: XCTestCase {
    private func peerId(_ value: Int64) -> PeerId {
        return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(value))
    }

    func testSelectMovesToThatEntryAndAPushOfItKeepsTheList() {
        var history = SupportChatHistory()
        history.push(peerId: self.peerId(1))
        history.push(peerId: self.peerId(2))
        history.push(peerId: self.peerId(3))

        history.select(position: 0, peerId: self.peerId(1))
        history.push(peerId: self.peerId(1))

        XCTAssertEqual(history.peerIds, [self.peerId(1), self.peerId(2), self.peerId(3)])
        XCTAssertEqual(history.position, 0)
        XCTAssertEqual(history.target(steps: 1), self.peerId(2))
    }

    func testSelectIgnoresAPositionHoldingAnotherChat() {
        var history = SupportChatHistory()
        history.push(peerId: self.peerId(1))
        history.push(peerId: self.peerId(2))

        history.select(position: 0, peerId: self.peerId(2))
        XCTAssertEqual(history.position, 1)
        history.select(position: 5, peerId: self.peerId(2))
        XCTAssertEqual(history.position, 1)
    }

    func testActiveRowsAreNewestFirstAndKeepRepeats() {
        let rows = supportActiveChatRows(peerIds: [self.peerId(1), self.peerId(2), self.peerId(1)])
        XCTAssertEqual(rows.map { $0.position }, [2, 1, 0])
        XCTAssertEqual(rows.map { $0.peerId }, [self.peerId(1), self.peerId(2), self.peerId(1)])
        XCTAssertEqual(rows.map { $0.occurrence }, [1, 0, 0])
    }

    func testAnEmptyHistoryHasNoTarget() {
        let history = SupportChatHistory()
        XCTAssertNil(history.target(steps: -1))
        XCTAssertNil(history.target(steps: 0))
        XCTAssertNil(history.target(steps: 1))
    }

    func testBackAndForwardWalkTheOpenedChats() {
        var history = SupportChatHistory()
        history.push(peerId: self.peerId(1))
        history.push(peerId: self.peerId(2))
        history.push(peerId: self.peerId(3))

        XCTAssertNil(history.target(steps: 1))
        XCTAssertEqual(history.target(steps: -1), self.peerId(2))
        history.move(steps: -1)
        XCTAssertEqual(history.target(steps: -1), self.peerId(1))
        XCTAssertEqual(history.target(steps: 1), self.peerId(3))
        history.move(steps: -1)
        XCTAssertNil(history.target(steps: -1))
        history.move(steps: 1)
        history.move(steps: 1)
        XCTAssertNil(history.target(steps: 1))
    }

    func testMovingPastAnEndChangesNothing() {
        var history = SupportChatHistory()
        history.push(peerId: self.peerId(1))
        history.move(steps: -1)
        history.move(steps: 1)
        XCTAssertEqual(history.position, 0)
    }

    func testTheOpenChatIsNotPushedTwice() {
        var history = SupportChatHistory()
        history.push(peerId: self.peerId(1))
        history.push(peerId: self.peerId(1))
        XCTAssertEqual(history.peerIds, [self.peerId(1)])
    }

    func testLandingOnAnEntryKeepsWhatIsAhead() {
        var history = SupportChatHistory()
        history.push(peerId: self.peerId(1))
        history.push(peerId: self.peerId(2))
        history.move(steps: -1)
        history.push(peerId: self.peerId(1))
        XCTAssertEqual(history.target(steps: 1), self.peerId(2))
    }

    func testOpeningANewChatDropsWhatIsAhead() {
        var history = SupportChatHistory()
        history.push(peerId: self.peerId(1))
        history.push(peerId: self.peerId(2))
        history.push(peerId: self.peerId(3))
        history.move(steps: -2)
        history.push(peerId: self.peerId(4))
        XCTAssertEqual(history.peerIds, [self.peerId(1), self.peerId(4)])
        XCTAssertNil(history.target(steps: 1))
    }

    func testARevisitedChatMovesToTheNewestEntry() {
        var history = SupportChatHistory()
        history.push(peerId: self.peerId(1))
        history.push(peerId: self.peerId(2))
        history.push(peerId: self.peerId(3))
        history.push(peerId: self.peerId(1))
        XCTAssertEqual(history.peerIds, [self.peerId(2), self.peerId(3), self.peerId(1)])
        XCTAssertEqual(history.position, 2)
        XCTAssertEqual(history.target(steps: -1), self.peerId(3))
    }

    func testARevisitedChatBehindThePositionMovesToTheNewestEntry() {
        var history = SupportChatHistory()
        history.push(peerId: self.peerId(1))
        history.push(peerId: self.peerId(2))
        history.push(peerId: self.peerId(3))
        history.move(steps: -1)
        history.push(peerId: self.peerId(1))
        XCTAssertEqual(history.peerIds, [self.peerId(2), self.peerId(1)])
        XCTAssertEqual(history.position, 1)
        XCTAssertNil(history.target(steps: 1))
    }

    func testTheOldestEntryGoesPastTheLimit() {
        var history = SupportChatHistory()
        for value in 1 ... Int64(supportChatHistoryLimit + 1) {
            history.push(peerId: self.peerId(value))
        }
        XCTAssertEqual(history.peerIds.count, supportChatHistoryLimit)
        XCTAssertEqual(history.peerIds.first, self.peerId(2))
        XCTAssertEqual(history.position, supportChatHistoryLimit - 1)
        XCTAssertEqual(history.target(steps: -1), self.peerId(Int64(supportChatHistoryLimit)))
    }

    func testAHeldKeyCountsOnce() {
        var gate = SupportHardwareKeyGate()
        XCTAssertTrue(gate.allowsPress(of: .composerReturn, at: 100.0))
        XCTAssertFalse(gate.allowsPress(of: .composerReturn, at: 100.5))
        for step in 1 ... 40 {
            XCTAssertFalse(gate.allowsPress(of: .composerReturn, at: 100.5 + Double(step) * 0.05))
        }
        XCTAssertFalse(gate.allowsPress(of: .composerReturn, at: 103.0))
        XCTAssertTrue(gate.allowsPress(of: .composerReturn, at: 103.9))
    }

    func testHistoryKeepsUpWithRepeatedTaps() {
        var gate = SupportHardwareKeyGate()
        XCTAssertTrue(gate.allowsPress(of: .chatHistory, at: 10.0))
        XCTAssertTrue(gate.allowsPress(of: .chatHistory, at: 10.3))
        XCTAssertTrue(gate.allowsPress(of: .chatHistory, at: 10.6))
        XCTAssertFalse(gate.allowsPress(of: .chatHistory, at: 10.7))
    }

    func testKeysDoNotShareAGap() {
        var gate = SupportHardwareKeyGate()
        XCTAssertTrue(gate.allowsPress(of: .composerReturn, at: 10.0))
        XCTAssertTrue(gate.allowsPress(of: .toggleMuted, at: 10.1))
        XCTAssertTrue(gate.allowsPress(of: .reloadTemplates, at: 10.1))
        XCTAssertTrue(gate.allowsPress(of: .chatHistory, at: 10.1))
    }
}
