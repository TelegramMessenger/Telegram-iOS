import XCTest
import ChatPresentationInterfaceState

/// A slow mode countdown restricts sending until it reaches zero. The chat drops the state at that moment, so the
/// input panel never shows a finished "0:00" countdown.
final class ChatSlowmodeStateTests: XCTestCase {
    func testACountdownIsActiveUntilItsLastSecond() {
        let state = ChatSlowmodeState(timeout: 30, variant: .timestamp(1000))
        XCTAssertTrue(state.isActive(at: 970))
        XCTAssertTrue(state.isActive(at: 999))
    }

    func testACountdownThatReachedZeroIsNotActive() {
        let state = ChatSlowmodeState(timeout: 30, variant: .timestamp(1000))
        XCTAssertFalse(state.isActive(at: 1000))
        XCTAssertFalse(state.isActive(at: 1001))
    }

    // Pending messages keep slow mode on until they are sent, whatever the time.
    func testPendingMessagesKeepItActive() {
        let state = ChatSlowmodeState(timeout: 30, variant: .pendingMessages)
        XCTAssertTrue(state.isActive(at: Int32.max))
    }
}
