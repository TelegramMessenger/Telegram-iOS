import Foundation
import AccountContext

/// Whether a group call's mute change may take effect, given the app's microphone access.
///
/// Without access an unmuted call sends no audio while showing the microphone as on, so an unmute (a tap or
/// push-to-talk) without access leaves the call muted and asks for access once (the system prompt, or the "denied"
/// alert with its way to Settings), as voice-message recording does. A tap (`.unmuted`) made while asking is carried
/// out once access is granted; push-to-talk is not, since its press has ended by then. Muting always applies, and
/// cancels a pending unmute.
struct GroupCallMicrophoneAccessGate: Equatable {
    enum Decision: Equatable {
        case apply
        case requestAccess
        /// A request is already showing; the call stays as it is until it completes.
        case waitForAccess
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
        if case .unmuted = action {
            self.unmutesOnGrant = true
        }
        if self.isRequestingAccess {
            return .waitForAccess
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
