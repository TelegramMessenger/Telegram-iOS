import Foundation
import XCTest
import AccountContext
@testable import TelegramCallsUI

/// Pins when a group call's mute change waits for microphone access: an unmute without access asks for it once and
/// leaves the call muted, and a grant does not unmute (the press that asked may have been a push-to-talk hold): the
/// next tap does. Push-to-talk alone never asks (the press's release does, one request per press). Muting always goes
/// through.
final class GroupCallMicrophoneAccessGateTests: XCTestCase {
    private let pushToTalk: PresentationGroupCallMuteAction = .muted(isPushToTalkActive: true)
    private let muted: PresentationGroupCallMuteAction = .muted(isPushToTalkActive: false)

    func testWithAccessEveryActionApplies() {
        var gate = GroupCallMicrophoneAccessGate()
        XCTAssertEqual(gate.decide(action: self.pushToTalk, isAccessGranted: true), .apply)
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: true), .apply)
        XCTAssertEqual(gate.decide(action: self.muted, isAccessGranted: true), .apply)
        XCTAssertFalse(gate.isRequestingAccess)
    }

    func testMutingAppliesWithoutAccess() {
        var gate = GroupCallMicrophoneAccessGate()
        XCTAssertEqual(gate.decide(action: self.muted, isAccessGranted: false), .apply)
        XCTAssertFalse(gate.isRequestingAccess)
    }

    func testUnmuteWithoutAccessRequestsItAndTheNextTapAfterAGrantUnmutes() {
        var gate = GroupCallMicrophoneAccessGate()
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: false), .requestAccess)
        XCTAssertTrue(gate.isRequestingAccess)
        gate.accessRequestCompleted()
        XCTAssertFalse(gate.isRequestingAccess)
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: true), .apply)
    }

    func testUnmuteWithoutAccessStaysMutedOnDenial() {
        var gate = GroupCallMicrophoneAccessGate()
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: false), .requestAccess)
        gate.accessRequestCompleted()
        XCTAssertFalse(gate.isRequestingAccess)
        // The next tap asks again (the denial alert with its way to Settings).
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: false), .requestAccess)
    }

    /// Every mic button sends push-to-talk on touch down and `.unmuted` (or a toggle) on release, which asks: one request
    /// per press, also when a denial completes at once, before the finger lifts.
    func testPushToTalkWithoutAccessDoesNotAsk() {
        var gate = GroupCallMicrophoneAccessGate()
        XCTAssertEqual(gate.decide(action: self.pushToTalk, isAccessGranted: false), .ignore)
        XCTAssertFalse(gate.isRequestingAccess)
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: false), .requestAccess)
        gate.accessRequestCompleted()
        XCTAssertFalse(gate.isRequestingAccess)
    }

    /// A push-to-talk hold that asked ends muted after the grant; the next hold talks only while held.
    func testAHoldThatAskedLeavesTheCallMutedAndTheNextHoldIsPushToTalk() {
        var gate = GroupCallMicrophoneAccessGate()
        XCTAssertEqual(gate.decide(action: self.pushToTalk, isAccessGranted: false), .ignore)
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: false), .requestAccess)
        gate.accessRequestCompleted()
        XCTAssertEqual(gate.decide(action: self.pushToTalk, isAccessGranted: true), .apply)
        XCTAssertEqual(gate.decide(action: self.muted, isAccessGranted: true), .apply)
    }

    func testMuteWhileRequestingApplies() {
        var gate = GroupCallMicrophoneAccessGate()
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: false), .requestAccess)
        XCTAssertEqual(gate.decide(action: self.muted, isAccessGranted: false), .apply)
        XCTAssertTrue(gate.isRequestingAccess)
        gate.accessRequestCompleted()
        XCTAssertFalse(gate.isRequestingAccess)
    }

    func testRepeatedUnmutesWhileRequestingAskOnce() {
        var gate = GroupCallMicrophoneAccessGate()
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: false), .requestAccess)
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: false), .ignore)
        XCTAssertEqual(gate.decide(action: self.pushToTalk, isAccessGranted: false), .ignore)
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: false), .ignore)
        gate.accessRequestCompleted()
        XCTAssertFalse(gate.isRequestingAccess)
    }
}
