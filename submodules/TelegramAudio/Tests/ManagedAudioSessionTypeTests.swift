import XCTest
import TelegramAudio

/// The session type a voice-message recording asks for is derived from the Data & Storage
/// "Pause Music While Recording" toggle (bugs.telegram.org/c/24902). Whether the resulting
/// session mixes with other apps' audio is decided entirely by `withOthers`.
final class ManagedAudioSessionTypeTests: XCTestCase {
    func testVoiceMessageRecordingPausesOtherAudioWhenToggleIsOn() {
        let type = ManagedAudioSessionType.voiceMessageRecording(beginWithTone: false, pauseMusicOnRecording: true)
        XCTAssertEqual(type, .record(speaker: false, video: false, withOthers: false))
    }

    func testVoiceMessageRecordingMixesWithOtherAudioWhenToggleIsOff() {
        let type = ManagedAudioSessionType.voiceMessageRecording(beginWithTone: false, pauseMusicOnRecording: false)
        XCTAssertEqual(type, .record(speaker: false, video: false, withOthers: true))
    }

    func testVoiceMessageRecordingKeepsSpeakerForToneRegardlessOfToggle() {
        XCTAssertEqual(
            ManagedAudioSessionType.voiceMessageRecording(beginWithTone: true, pauseMusicOnRecording: true),
            .record(speaker: true, video: false, withOthers: false)
        )
        XCTAssertEqual(
            ManagedAudioSessionType.voiceMessageRecording(beginWithTone: true, pauseMusicOnRecording: false),
            .record(speaker: true, video: false, withOthers: true)
        )
    }
}
