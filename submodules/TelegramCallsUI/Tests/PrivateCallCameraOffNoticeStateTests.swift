import Foundation
import XCTest
import CallScreen

/// Pins when the call screen's "Your camera is off" notice is up: from the moment the other party turns on video
/// while the local camera is off until it is dismissed (its close button, the camera button), the local video turns on
/// or the remote video goes away; it returns only when the remote video starts again.
final class PrivateCallCameraOffNoticeStateTests: XCTestCase {
    func testShownWhenRemoteVideoStartsWhileLocalCameraIsOff() {
        var state = PrivateCallCameraOffNoticeState()
        state.update(hasRemoteVideo: false, hasLocalVideo: false)
        XCTAssertFalse(state.isVisible)
        state.update(hasRemoteVideo: true, hasLocalVideo: false)
        XCTAssertTrue(state.isVisible)
    }

    func testStaysUntilDismissed() {
        var state = PrivateCallCameraOffNoticeState()
        state.update(hasRemoteVideo: true, hasLocalVideo: false)
        for _ in 0 ..< 3 {
            state.update(hasRemoteVideo: true, hasLocalVideo: false)
            XCTAssertTrue(state.isVisible)
        }
        state.dismiss()
        XCTAssertFalse(state.isVisible)
        state.update(hasRemoteVideo: true, hasLocalVideo: false)
        XCTAssertFalse(state.isVisible)
    }

    func testNotShownWhenLocalVideoIsAlreadyOn() {
        var state = PrivateCallCameraOffNoticeState()
        state.update(hasRemoteVideo: false, hasLocalVideo: true)
        state.update(hasRemoteVideo: true, hasLocalVideo: true)
        XCTAssertFalse(state.isVisible)
    }

    func testLocalVideoTurningOnDismissesItForGood() {
        var state = PrivateCallCameraOffNoticeState()
        state.update(hasRemoteVideo: true, hasLocalVideo: false)
        state.update(hasRemoteVideo: true, hasLocalVideo: true)
        XCTAssertFalse(state.isVisible)
        state.update(hasRemoteVideo: true, hasLocalVideo: false)
        XCTAssertFalse(state.isVisible)
    }

    func testRemoteVideoStoppingHidesItAndRestartingShowsItAgain() {
        var state = PrivateCallCameraOffNoticeState()
        state.update(hasRemoteVideo: true, hasLocalVideo: false)
        state.dismiss()
        state.update(hasRemoteVideo: false, hasLocalVideo: false)
        XCTAssertFalse(state.isVisible)
        state.update(hasRemoteVideo: true, hasLocalVideo: false)
        XCTAssertTrue(state.isVisible)

        state.update(hasRemoteVideo: false, hasLocalVideo: false)
        XCTAssertFalse(state.isVisible)
    }

    func testShownWhenTheScreenOpensOnRemoteVideo() {
        var state = PrivateCallCameraOffNoticeState()
        state.update(hasRemoteVideo: true, hasLocalVideo: false)
        XCTAssertTrue(state.isVisible)
    }
}
