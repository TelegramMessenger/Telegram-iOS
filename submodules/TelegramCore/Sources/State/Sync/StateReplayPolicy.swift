import Foundation
import Postbox
import EncryptionProvider

/// How `replayFinalState` treats a final state (state-sync seam 5). It replaced two booleans, `skipVerification` and
/// `ignoreDate`, of which three combinations were in use; the fourth (unverified, keeping the stored date) never was.
enum ReplayPolicy {
    /// The final state was built from a snapshot of the stored state: `ReplayRejection.verify` runs first and the
    /// replay is refused (nil, nothing written) unless every peer the snapshot was taken for is in the final state's
    /// `peers`, the stored account state still equals the snapshot's when the replay moves it (`.UpdateState`), and
    /// each channel whose state the replay moves (`.UpdateChannelState`) still has the snapshot's pts, or neither has a
    /// state. The account state is stored as the final state carries it. Used by the operation queue's getDifference
    /// (`fetchDifference`), its pushed update groups (`processBatch`) and its asynchronously built states
    /// (`replayPrebuilt`, from `pollChannelOnce`), and outside the operation queue by
    /// `standaloneReplayAsynchronouslyBuiltFinalState` (from `standalonePollChannelOnce`).
    case verified
    /// As `.verified`, but an account state is stored with the stored `date` instead of the final state's. The
    /// notification extension's getDifference (`standalonePollDifference`), which sends `date: Int32.max`.
    case verifiedKeepingStoredDate
    /// Not verified. The asynchronous channel reset (`ChannelResetCoordinator`): its per-channel states,
    /// each built from its own snapshot when its reset started, merged and replayed after the difference chain ended.
    case unverifiedChannelReset

    /// Whether `replayFinalState` runs `ReplayRejection.verify` first and returns nil when it fails.
    var verifiesTransaction: Bool {
        switch self {
        case .verified, .verifiedKeepingStoredDate:
            return true
        case .unverifiedChannelReset:
            return false
        }
    }

    /// Whether an `.UpdateState` operation keeps the stored `date` instead of storing the final state's.
    var keepsStoredDate: Bool {
        switch self {
        case .verifiedKeepingStoredDate:
            return true
        case .verified, .unverifiedChannelReset:
            return false
        }
    }
}
