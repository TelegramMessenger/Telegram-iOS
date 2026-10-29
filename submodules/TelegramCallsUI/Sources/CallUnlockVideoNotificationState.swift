import Foundation
import AccountContext

/// When the "Unlock your phone to see and share video" notification ("your iPad" on iPad) is shown for a call.
///
/// An incoming video call answered from the system call screen while Telegram is in the background
/// (the lock screen) continues in the CallKit UI, which has no video. The notification leads the user
/// to unlock and open Telegram's call screen. It is shown once, `postDelay` after the answer, because
/// answering a video call on an unlocked device brings the app to the foreground by itself, and taken
/// down when the call ends or the app comes to the foreground. One left behind by a call that ended while the app was
/// not running is removed at the next launch (`SharedAccountContextImpl`).
///
/// "In the background" stands for "locked", which iOS does not report: an answer that never brings
/// the app forward on an unlocked device (headset, Apple Watch, CarPlay) posts it too.
public struct CallUnlockVideoNotificationState: Equatable {
    public enum Phase: Equatable {
        case awaitingAnswer
        /// Answered in the background; shown once `postDelay` passes without the app coming to the foreground.
        case pending
        case shown
        case finished
    }

    public static let postDelay: Double = 1.0
    public static let userInfoKey = "callUnlockVideo"
    /// The notification's category: its text is the lock screen's placeholder, so it shows while previews are hidden
    /// ("When Unlocked", the default), when the phone is locked, which is when it is read.
    public static let categoryIdentifier = "cuv"

    public static func identifier(internalId: UUID) -> String {
        return "call_unlock_video_\(internalId)"
    }

    public private(set) var phase: Phase

    public init(isOutgoing: Bool, isIntegratedWithCallKit: Bool, isVideo: Bool) {
        if !isOutgoing && isIntegratedWithCallKit && isVideo {
            self.phase = .awaitingAnswer
        } else {
            self.phase = .finished
        }
    }

    public mutating func update(callState: PresentationCallState.State, applicationInForeground: Bool) {
        let isEnded: Bool
        let isAnswered: Bool
        switch callState {
        case .waiting, .ringing:
            isEnded = false
            isAnswered = false
        case .terminating, .terminated:
            isEnded = true
            isAnswered = false
        case .requesting, .connecting, .active, .reconnecting:
            isEnded = false
            isAnswered = true
        }

        switch self.phase {
        case .awaitingAnswer:
            if isEnded {
                self.phase = .finished
            } else if isAnswered {
                self.phase = applicationInForeground ? .finished : .pending
            }
        case .pending, .shown:
            if isEnded || applicationInForeground {
                self.phase = .finished
            }
        case .finished:
            break
        }
    }

    public mutating func postDelayElapsed() {
        if case .pending = self.phase {
            self.phase = .shown
        }
    }
}
