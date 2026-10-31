import Foundation
import AccountContext

/// Whether a group call's mute change may take effect, given the app's microphone access.
///
/// Without access an unmuted call sends no audio while showing the microphone as on, so an unmute without access leaves
/// the call muted and asks for access (the system prompt, or the "denied" alert with its way to Settings), as
/// voice-message recording does, and is carried out once access is granted. Push-to-talk without access changes nothing
/// and does not ask: every mic button sends it on touch down and an unmute (or a toggle) on release, which asks, so a
/// press is one request, also when a denial completes at once, before the finger lifts. Muting always applies, and
/// cancels a pending unmute.
struct GroupCallMicrophoneAccessGate: Equatable {
    enum Decision: Equatable {
        case apply
        case requestAccess
        /// Nothing changes: push-to-talk without access, or an unmute while a request is showing.
        case ignore
    }

    private(set) var isRequestingAccess: Bool = false
    private var unmutesOnGrant: Bool = false

    init() {
    }

    mutating func decide(action: PresentationGroupCallMuteAction, isAccessGranted: Bool) -> Decision {
        if action.isEffectivelyMuted {
            self.unmutesOnGrant = false
            return .apply
        }
        if isAccessGranted {
            return .apply
        }
        guard case .unmuted = action else {
            return .ignore
        }
        self.unmutesOnGrant = true
        if self.isRequestingAccess {
            return .ignore
        }
        self.isRequestingAccess = true
        return .requestAccess
    }

    /// The action to carry out now that the request has completed, if any.
    mutating func accessRequestCompleted(isGranted: Bool) -> PresentationGroupCallMuteAction? {
        let unmutes = isGranted && self.unmutesOnGrant
        self.isRequestingAccess = false
        self.unmutesOnGrant = false
        return unmutes ? .unmuted : nil
    }
}
