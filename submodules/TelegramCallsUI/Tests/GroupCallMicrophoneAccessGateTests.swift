import Foundation
import XCTest
import AccountContext
@testable import TelegramCallsUI

/// Pins when a group call's mute change waits for microphone access: an unmute (a tap, push-to-talk) without access
/// asks for it once and leaves the call muted; a tap is carried out when access is granted, a push-to-talk that has
/// been released by then is not. Muting always goes through.
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

    func testUnmuteWithoutAccessRequestsItAndAppliesOnGrant() {
        var gate = GroupCallMicrophoneAccessGate()
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: false), .requestAccess)
        XCTAssertTrue(gate.isRequestingAccess)
        XCTAssertEqual(gate.accessRequestCompleted(isGranted: true), .unmuted)
        XCTAssertFalse(gate.isRequestingAccess)
    }

    func testUnmuteWithoutAccessStaysMutedOnDenial() {
        var gate = GroupCallMicrophoneAccessGate()
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: false), .requestAccess)
        XCTAssertNil(gate.accessRequestCompleted(isGranted: false))
        XCTAssertFalse(gate.isRequestingAccess)
        // The next tap asks again (the denial alert with its way to Settings).
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: false), .requestAccess)
    }

    /// The big button sends push-to-talk on touch down and `.unmuted` on a quick release: one request, and the tap is
    /// carried out once access is granted.
    func testTapIsOneRequestAndUnmutesOnGrant() {
        var gate = GroupCallMicrophoneAccessGate()
        XCTAssertEqual(gate.decide(action: self.pushToTalk, isAccessGranted: false), .requestAccess)
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: false), .waitForAccess)
        XCTAssertEqual(gate.accessRequestCompleted(isGranted: true), .unmuted)
    }

    func testReleasedPushToTalkIsNotResumedOnGrant() {
        var gate = GroupCallMicrophoneAccessGate()
        XCTAssertEqual(gate.decide(action: self.pushToTalk, isAccessGranted: false), .requestAccess)
        XCTAssertEqual(gate.decide(action: self.muted, isAccessGranted: false), .apply)
        XCTAssertNil(gate.accessRequestCompleted(isGranted: true))
    }

    func testMuteWhileRequestingCancelsThePendingUnmute() {
        var gate = GroupCallMicrophoneAccessGate()
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: false), .requestAccess)
        XCTAssertEqual(gate.decide(action: self.muted, isAccessGranted: false), .apply)
        XCTAssertTrue(gate.isRequestingAccess)
        XCTAssertNil(gate.accessRequestCompleted(isGranted: true))
    }

    func testPushToTalkAloneIsNotResumedOnGrant() {
        var gate = GroupCallMicrophoneAccessGate()
        XCTAssertEqual(gate.decide(action: self.pushToTalk, isAccessGranted: false), .requestAccess)
        XCTAssertNil(gate.accessRequestCompleted(isGranted: true))
    }

    func testRepeatedUnmutesWhileRequestingAskOnce() {
        var gate = GroupCallMicrophoneAccessGate()
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: false), .requestAccess)
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: false), .waitForAccess)
        XCTAssertEqual(gate.decide(action: self.pushToTalk, isAccessGranted: false), .waitForAccess)
        XCTAssertEqual(gate.decide(action: .unmuted, isAccessGranted: false), .waitForAccess)
        XCTAssertEqual(gate.accessRequestCompleted(isGranted: true), .unmuted)
    }
}
