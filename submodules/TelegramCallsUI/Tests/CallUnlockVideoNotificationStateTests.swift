import Foundation
import XCTest
import AccountContext
@testable import TelegramCallsUI

/// Pins when the "Unlock your phone to see and share video" notification is shown: once, for an
/// incoming CallKit video call answered while the app is in the background (the lock screen),
/// after the post delay, and taken down when the call ends or the app comes to the foreground.
final class CallUnlockVideoNotificationStateTests: XCTestCase {
    private let active: PresentationCallState.State = .active(0.0, nil, Data())
    private let terminated: PresentationCallState.State = .terminated(nil, nil, false)

    private func incomingVideoCall() -> CallUnlockVideoNotificationState {
        return CallUnlockVideoNotificationState(isOutgoing: false, isIntegratedWithCallKit: true, isVideo: true)
    }

    func testVideoCallAnsweredInBackgroundIsShownAfterTheDelay() {
        var state = self.incomingVideoCall()
        state.update(callState: .ringing, applicationInForeground: false)
        XCTAssertEqual(state.phase, .awaitingAnswer)
        state.update(callState: .connecting(nil), applicationInForeground: false)
        XCTAssertEqual(state.phase, .pending)
        state.update(callState: self.active, applicationInForeground: false)
        XCTAssertEqual(state.phase, .pending)
        state.postDelayElapsed()
        XCTAssertEqual(state.phase, .shown)
    }

    func testVideoCallAnsweredInForegroundIsNeverShown() {
        var state = self.incomingVideoCall()
        state.update(callState: .ringing, applicationInForeground: true)
        state.update(callState: .connecting(nil), applicationInForeground: true)
        XCTAssertEqual(state.phase, .finished)
        state.update(callState: self.active, applicationInForeground: false)
        state.postDelayElapsed()
        XCTAssertEqual(state.phase, .finished)
    }

    func testVoiceCallIsNeverShown() {
        var state = CallUnlockVideoNotificationState(isOutgoing: false, isIntegratedWithCallKit: true, isVideo: false)
        state.update(callState: .connecting(nil), applicationInForeground: false)
        state.postDelayElapsed()
        XCTAssertEqual(state.phase, .finished)
    }

    func testOutgoingOrNonCallKitVideoCallIsNeverShown() {
        var outgoing = CallUnlockVideoNotificationState(isOutgoing: true, isIntegratedWithCallKit: true, isVideo: true)
        outgoing.update(callState: .connecting(nil), applicationInForeground: false)
        outgoing.postDelayElapsed()
        XCTAssertEqual(outgoing.phase, .finished)

        var withoutCallKit = CallUnlockVideoNotificationState(isOutgoing: false, isIntegratedWithCallKit: false, isVideo: true)
        withoutCallKit.update(callState: .connecting(nil), applicationInForeground: false)
        withoutCallKit.postDelayElapsed()
        XCTAssertEqual(withoutCallKit.phase, .finished)
    }

    /// Answering a video call on an unlocked device brings the app to the foreground by itself.
    func testForegroundWithinTheDelayCancelsTheNotification() {
        var state = self.incomingVideoCall()
        state.update(callState: .connecting(nil), applicationInForeground: false)
        state.update(callState: .connecting(nil), applicationInForeground: true)
        XCTAssertEqual(state.phase, .finished)
        state.postDelayElapsed()
        XCTAssertEqual(state.phase, .finished)
    }

    func testCallEndingWithinTheDelayCancelsTheNotification() {
        var state = self.incomingVideoCall()
        state.update(callState: .connecting(nil), applicationInForeground: false)
        state.update(callState: .terminating(nil), applicationInForeground: false)
        XCTAssertEqual(state.phase, .finished)
        state.postDelayElapsed()
        XCTAssertEqual(state.phase, .finished)
    }

    func testShownNotificationIsRemovedWhenTheCallEnds() {
        var state = self.incomingVideoCall()
        state.update(callState: self.active, applicationInForeground: false)
        state.postDelayElapsed()
        state.update(callState: self.terminated, applicationInForeground: false)
        XCTAssertEqual(state.phase, .finished)
    }

    func testShownNotificationIsRemovedWhenTheAppIsOpened() {
        var state = self.incomingVideoCall()
        state.update(callState: self.active, applicationInForeground: false)
        state.postDelayElapsed()
        state.update(callState: self.active, applicationInForeground: true)
        XCTAssertEqual(state.phase, .finished)
    }

    /// Leaving the app during the call later must not post it again: the device is unlocked then.
    func testNotificationIsNotShownAgainAfterTheAppWasOpened() {
        var state = self.incomingVideoCall()
        state.update(callState: self.active, applicationInForeground: false)
        state.postDelayElapsed()
        state.update(callState: self.active, applicationInForeground: true)
        state.update(callState: self.active, applicationInForeground: false)
        state.postDelayElapsed()
        XCTAssertEqual(state.phase, .finished)
    }

    func testCallDeclinedWhileRingingIsNeverShown() {
        var state = self.incomingVideoCall()
        state.update(callState: .ringing, applicationInForeground: false)
        state.update(callState: .terminating(nil), applicationInForeground: false)
        XCTAssertEqual(state.phase, .finished)
        state.postDelayElapsed()
        XCTAssertEqual(state.phase, .finished)
    }
}
