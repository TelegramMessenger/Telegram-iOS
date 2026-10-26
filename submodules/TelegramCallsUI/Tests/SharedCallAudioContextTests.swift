import Foundation
import XCTest
import SwiftSignalKit
import TelegramAudio
import TelegramCore
@testable import TelegramCallsUI

/// Stands in for `ManagedAudioSessionImpl`. It records what a call pushes and lets the test
/// hand out a control and drive activation by hand.
private final class FakeAudioSession: ManagedAudioSession {
    var isHeadsetPluggedIn: Bool = false
    var pushedParams: [ManagedAudioSessionClientParams] = []

    func getIsHeadsetPluggedIn() -> Bool {
        return self.isHeadsetPluggedIn
    }

    func getIsRecordingActive() -> Bool {
        return false
    }

    func headsetConnected() -> Signal<Bool, NoError> {
        return .single(self.isHeadsetPluggedIn)
    }

    func isActive() -> Signal<Bool, NoError> {
        return .single(false)
    }

    func isPlaybackActive() -> Signal<Bool, NoError> {
        return .single(false)
    }

    func isOtherAudioPlaying() -> Bool {
        return false
    }

    func didActivateWithZeroVolume() -> Signal<Void, NoError> {
        return .never()
    }

    func push(params: ManagedAudioSessionClientParams) -> Disposable {
        self.pushedParams.append(params)
        return EmptyDisposable
    }

    func dropAll() {
    }

    func applyVoiceChatOutputModeInCurrentAudioSession(outputMode: AudioSessionOutputMode) {
    }

    func callKitActivatedAudioSession() {
    }

    func callKitDeactivatedAudioSession() {
    }
}

/// A control whose activation completes only when the test says so, with the headset state the
/// test chooses. Every output mode the call applies is recorded in order.
private final class FakeControl {
    private(set) var appliedOutputModes: [AudioSessionOutputMode] = []
    private var pendingActivations: [(AudioSessionActivationState) -> Void] = []

    private(set) lazy var control: ManagedAudioSessionControl = ManagedAudioSessionControl(
        setup: { _ in },
        activate: { [unowned self] completion in
            self.pendingActivations.append(completion)
        },
        setOutputMode: { [unowned self] mode in
            self.appliedOutputModes.append(mode)
        },
        setupAndActivate: { [unowned self] _, completion in
            self.pendingActivations.append(completion)
        },
        setType: { _, completion in
            completion()
        }
    )

    func completeActivations(isHeadsetConnected: Bool) {
        let pending = self.pendingActivations
        self.pendingActivations = []
        for completion in pending {
            completion(AudioSessionActivationState(isHeadsetConnected: isHeadsetConnected))
        }
    }
}

/// `SharedCallAudioContext` decides the speaker default for a group call from
/// `getIsHeadsetPluggedIn()` at construction. That answer can be wrong: the cached route is
/// refreshed only by route-change notifications, and a paired headset is not the current route
/// until the call's category is set. Whatever the initial answer, a headset that the audio
/// session reports once the call is set up must win over the speaker default.
final class SharedCallAudioContextTests: XCTestCase {
    private static let loggerInstalled: Bool = {
        let path = NSTemporaryDirectory() + "SharedCallAudioContextTests-logs"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        let logger = Logger(rootPath: path, basePath: path)
        logger.logToFile = false
        logger.logToConsole = false
        Logger.setSharedLogger(logger)
        return true
    }()

    private var session: FakeAudioSession!
    private var control: FakeControl!

    override func setUp() {
        super.setUp()
        XCTAssertTrue(SharedCallAudioContextTests.loggerInstalled)
        self.session = FakeAudioSession()
        self.control = FakeControl()
    }

    override func tearDown() {
        self.control = nil
        self.session = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Lets blocks queued on the main queue, and timers scheduled on the main run loop, run.
    private func spinMainQueue(for interval: TimeInterval = 0.05) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: interval))
    }

    private func makeContext(defaultToSpeaker: Bool) -> SharedCallAudioContext {
        let context = SharedCallAudioContext.get(audioSession: self.session, callKitIntegration: nil, defaultToSpeaker: defaultToSpeaker, reuseCurrent: false, enableMicrophone: true, legacyBehavior: false)
        XCTAssertEqual(self.session.pushedParams.count, 1, "the context pushes exactly one audio session holder")
        return context
    }

    private var pushedParams: ManagedAudioSessionClientParams {
        return self.session.pushedParams[0]
    }

    /// The session hands the call its control; `SharedCallAudioContext` applies its initial
    /// output mode and asks for activation.
    private func handOutControl() {
        self.pushedParams.manualActivate(self.control.control)
        self.spinMainQueue()
    }

    /// What `ManagedAudioSessionImpl` does on activation: report the route under the call's
    /// category, then complete the activation with the headset state read at that moment.
    private func completeActivation(reporting outputs: [AudioSessionOutput], current: AudioSessionOutput, isHeadsetConnected: Bool) {
        self.pushedParams.availableOutputsChanged(outputs, current)
        self.control.completeActivations(isHeadsetConnected: isHeadsetConnected)
        self.spinMainQueue()
    }

    /// Long enough for the context's half-second re-apply timer to fire.
    private func waitForInitialSetupTimer() {
        self.spinMainQueue(for: 0.8)
    }

    // MARK: - Tests

    func testSpeakerDefaultYieldsToAHeadsetThatTheSessionReportsAtActivation() {
        // The cached headset flag is wrong: headphones are connected, the session says no.
        self.session.isHeadsetPluggedIn = false
        let context = self.makeContext(defaultToSpeaker: true)

        self.handOutControl()
        self.completeActivation(reporting: [.builtin, .headphones], current: .headphones, isHeadsetConnected: true)
        self.waitForInitialSetupTimer()

        XCTAssertFalse(self.control.appliedOutputModes.contains(.custom(.speaker)), "the speaker must not be forced over connected headphones; applied: \(self.control.appliedOutputModes)")
        XCTAssertEqual(context.currentAudioOutputValue, .headphones)
    }

    func testSpeakerDefaultIsAppliedWhenActivationReportsNoHeadset() {
        self.session.isHeadsetPluggedIn = false
        let context = self.makeContext(defaultToSpeaker: true)

        self.handOutControl()
        self.completeActivation(reporting: [.builtin, .speaker], current: .builtin, isHeadsetConnected: false)
        self.waitForInitialSetupTimer()

        XCTAssertTrue(self.control.appliedOutputModes.contains(.custom(.speaker)), "applied: \(self.control.appliedOutputModes)")
        XCTAssertEqual(self.control.appliedOutputModes.last, .custom(.speaker))
        XCTAssertEqual(context.currentAudioOutputValue, .speaker)
    }

    func testHeadsetKnownAtConstructionNeverGetsTheSpeakerDefault() {
        self.session.isHeadsetPluggedIn = true
        let context = self.makeContext(defaultToSpeaker: true)

        self.handOutControl()
        self.completeActivation(reporting: [.builtin, .headphones], current: .headphones, isHeadsetConnected: true)
        self.waitForInitialSetupTimer()

        XCTAssertFalse(self.control.appliedOutputModes.contains(.custom(.speaker)), "applied: \(self.control.appliedOutputModes)")
        XCTAssertEqual(context.currentAudioOutputValue, .headphones)
    }

    /// Activation of a Bluetooth headset can outlast the half-second re-apply timer; the timer
    /// must not decide the output before the session has reported the route.
    func testTimerFiringBeforeActivationCompletesDoesNotForceTheSpeaker() {
        self.session.isHeadsetPluggedIn = false
        let context = self.makeContext(defaultToSpeaker: true)

        self.handOutControl()
        self.waitForInitialSetupTimer()
        self.completeActivation(reporting: [.builtin, .headphones], current: .headphones, isHeadsetConnected: true)
        self.waitForInitialSetupTimer()

        XCTAssertFalse(self.control.appliedOutputModes.contains(.custom(.speaker)), "applied: \(self.control.appliedOutputModes)")
        XCTAssertEqual(context.currentAudioOutputValue, .headphones)
    }

    /// The cached flag can also be wrong the other way: it says headset while none is connected
    /// any more. The caller asked for the speaker, and activation shows no headset.
    func testSpeakerIsAppliedWhenAStaleHeadsetFlagIsContradictedAtActivation() {
        self.session.isHeadsetPluggedIn = true
        let context = self.makeContext(defaultToSpeaker: true)

        self.handOutControl()
        self.completeActivation(reporting: [.builtin, .speaker], current: .builtin, isHeadsetConnected: false)
        self.waitForInitialSetupTimer()

        XCTAssertEqual(self.control.appliedOutputModes.last, .custom(.speaker), "applied: \(self.control.appliedOutputModes)")
        XCTAssertEqual(context.currentAudioOutputValue, .speaker)
    }

    /// If the route report was skipped as unchanged, the activation state alone must still turn
    /// the announced output away from the speaker, for the UI as well as for the context.
    func testActivationReportingAHeadsetWithoutARouteReportUpdatesTheAnnouncedOutput() {
        self.session.isHeadsetPluggedIn = false
        let context = self.makeContext(defaultToSpeaker: true)
        var announced: [AudioSessionOutput?] = []
        let disposable = context.audioOutputState.start(next: { announced.append($0.1) })
        defer { disposable.dispose() }

        self.handOutControl()
        self.control.completeActivations(isHeadsetConnected: true)
        self.spinMainQueue()
        self.waitForInitialSetupTimer()

        XCTAssertFalse(self.control.appliedOutputModes.contains(.custom(.speaker)), "applied: \(self.control.appliedOutputModes)")
        XCTAssertEqual(context.currentAudioOutputValue, .headphones)
        XCTAssertEqual(announced.last, .headphones, "announced: \(announced)")
    }

    func testAnExplicitSelectionDuringActivationIsKept() {
        self.session.isHeadsetPluggedIn = false
        let context = self.makeContext(defaultToSpeaker: true)

        self.handOutControl()
        // The user picks the earpiece before the session has finished activating.
        context.setCurrentAudioOutput(.builtin)
        self.completeActivation(reporting: [.builtin, .speaker], current: .builtin, isHeadsetConnected: false)
        self.waitForInitialSetupTimer()

        XCTAssertEqual(self.control.appliedOutputModes.last, .custom(.builtin), "applied: \(self.control.appliedOutputModes)")
        XCTAssertEqual(context.currentAudioOutputValue, .builtin)
    }
}
