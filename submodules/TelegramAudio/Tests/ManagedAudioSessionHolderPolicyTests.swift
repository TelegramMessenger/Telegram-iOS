import XCTest
import SwiftSignalKit
import TelegramAudio

/// Holder-precedence policy of the real `ManagedAudioSessionImpl`.
///
/// A recording that mixes with other audio (`withOthers: true`) is allowed to *temporarily* displace
/// an ordinary playback holder, but it must never displace an active call: deactivating the call's
/// holder makes `PresentationCall` drop its audio-session control and tear down the call's audio.
/// The non-mixing record path already gave the call precedence; the mixing path must too.
final class ManagedAudioSessionHolderPolicyTests: XCTestCase {
    private var disposables: [Disposable] = []

    override func tearDown() {
        for disposable in self.disposables {
            disposable.dispose()
        }
        self.disposables.removeAll()
        super.tearDown()
    }

    /// Pushes `type` with a manual activation and returns once the manager has made it the active
    /// holder. The activation control is deliberately left untouched so the test never configures
    /// the process's `AVAudioSession`.
    private func pushAndAwaitActivation(_ session: ManagedAudioSessionImpl, _ type: ManagedAudioSessionType, deactivated: @escaping (Bool) -> Void) {
        let activated = self.expectation(description: "\(type) activated")
        let disposable = session.push(audioSessionType: type, manualActivate: { _ in
            activated.fulfill()
        }, deactivate: { temporary in
            deactivated(temporary)
            return .single(Void())
        })
        self.disposables.append(disposable)
        self.wait(for: [activated], timeout: 2.0)
    }

    private func pushMixingRecording(_ session: ManagedAudioSessionImpl, activated: @escaping () -> Void) {
        let disposable = session.push(audioSessionType: .record(speaker: false, video: false, withOthers: true), manualActivate: { _ in
            activated()
        }, deactivate: { _ in
            return .single(Void())
        })
        self.disposables.append(disposable)
    }

    private func settle() {
        let settled = self.expectation(description: "holders settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            settled.fulfill()
        }
        self.wait(for: [settled], timeout: 2.0)
    }

    func testMixingRecordingTemporarilyDisplacesPlayback() {
        let session = ManagedAudioSessionImpl()
        var playbackDeactivations: [Bool] = []
        self.pushAndAwaitActivation(session, .play(mixWithOthers: false)) { temporary in
            playbackDeactivations.append(temporary)
        }

        var recordingActivated = false
        self.pushMixingRecording(session) {
            recordingActivated = true
        }
        self.settle()

        XCTAssertEqual(playbackDeactivations, [true], "playback should be deactivated exactly once, and temporarily")
        XCTAssertTrue(recordingActivated, "the recording should take over the session")
    }

    func testMixingRecordingNeverDisplacesAnActiveCall() {
        let session = ManagedAudioSessionImpl()
        var callDeactivations: [Bool] = []
        self.pushAndAwaitActivation(session, .voiceCall) { temporary in
            callDeactivations.append(temporary)
        }

        var recordingActivated = false
        self.pushMixingRecording(session) {
            recordingActivated = true
        }
        self.settle()

        XCTAssertEqual(callDeactivations, [], "an active call must keep its audio session")
        XCTAssertFalse(recordingActivated, "the recording must wait behind the call, as a non-mixing recording does")
    }
}
