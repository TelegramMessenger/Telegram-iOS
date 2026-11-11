import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

/// Which poller a getDifference attempt serves (state-sync spec 3.3). `AccountStateManager.Impl`'s
/// `fetchAndApplyDifference(policy:)` runs one attempt for either and comes to one `DifferenceOutcome`; what follows
/// it is the caller's: the `fetchDifference` operation's completion, or `standalonePollDifference`'s `Bool`.
///
/// | | `.mainApp` (the `fetchDifference` operation) | `.notificationExtension` (`standalonePollDifference`) |
/// | --- | --- | --- |
/// | stored state | one transaction reads the state, its invalidated channels, `ios_disable_parallel_channel_reset_v2` and `pts_total_limit`; then a hop to the manager's queue | `stateView`, waiting until it holds an `AuthorizedAccountState`, once (`take(1)`); no hop |
/// | `pts_total_limit` | the value that transaction read, for every retry of the request | read in a transaction of its own before every try of the request |
/// | `date` sent, replay | the stored date, `.verified` | `Int32.max`, `.verifiedKeepingStoredDate` |
/// | channel resets | asynchronous (`addAsyncResetChannels`): the invalidated channels of an earlier run when the request is made, the difference's own once its final state is built; with `ios_disable_parallel_channel_reset_v2` the invalidated channels are not read and the difference's are reset inline | inline, in the final state |
/// | differenceTooLong | `.tooLong`; the caller resets the account (consecutive-reset backoff) and polls again in the same cycle | `.tooLong`, logged; nothing is written, the app resets (Q3) |
/// | log | `DifferenceChainLog.noteRequest` and `logDifferenceAnswer` here; the caller logs the chain's end | the differenceTooLong line |
/// | events | the caller dispatches them | the caller drops them |
/// | no inner state | `updates.getState`, written into the stored account state when there is one; `.noInnerState` | `.noInnerState`; nothing is fetched |
///
/// The rest is shared: the request (`requestDifference`), AUTH_KEY_DUPLICATED as `.authKeyDuplicated` with every
/// other error retried (`retryingDifferenceRequest`), and the answer's replay (`applyDifferenceAnswer`), including
/// `.stateChangedMeanwhile` and `.replayRejected`.
enum DifferencePolicy {
    case mainApp
    case notificationExtension

    /// The `date` updates.getDifference sends. The extension sends `Int32.max` and keeps the stored date when it
    /// replays the answer (`replayPolicy`).
    func requestDate(storedDate: Int32) -> Int32 {
        switch self {
        case .mainApp:
            return storedDate
        case .notificationExtension:
            return Int32.max
        }
    }

    /// How an applied difference is replayed (`FinalStateReplayer.applyReplay`).
    var replayPolicy: ReplayPolicy {
        switch self {
        case .mainApp:
            return .verified
        case .notificationExtension:
            return .verifiedKeepingStoredDate
        }
    }
}

/// updates.getDifference from `state`, with the `date` `policy` sends and `pts_total_limit` when there is one: flags.0
/// marks it present (audit Q14); a set bit with no value cannot be serialized, and a value without the bit is not
/// sent. Builds the request; nothing is sent before the signal is started.
func requestDifference(network: Network, from state: AuthorizedAccountState.State, ptsTotalLimit: Int32?, policy: DifferencePolicy) -> Signal<Api.updates.Difference, MTRpcError> {
    let flags: Int32 = ptsTotalLimit != nil ? (1 << 0) : 0
    return network.request(Api.functions.updates.getDifference(flags: flags, pts: state.pts, ptsLimit: nil, ptsTotalLimit: ptsTotalLimit, date: policy.requestDate(storedDate: state.date), qts: state.qts, qtsLimit: nil))
}

/// `request` with 406 AUTH_KEY_DUPLICATED as nil and every other error retried (`retryRequest`, which never gives up),
/// so a getDifference attempt always comes to an answer. nil is `DifferenceOutcome.authKeyDuplicated` (Q2): the key is
/// dead, and retrying cannot help.
func retryingDifferenceRequest(_ request: Signal<Api.updates.Difference, MTRpcError>) -> Signal<Api.updates.Difference?, NoError> {
    return request
    |> map(Optional.init)
    |> `catch` { error -> Signal<Api.updates.Difference?, MTRpcError> in
        if error.errorCode == 406 && error.errorDescription == "AUTH_KEY_DUPLICATED" {
            return .single(nil)
        } else {
            return .fail(error)
        }
    }
    |> retryRequest
}

/// What getDifference's answer comes to, for either policy. nil (AUTH_KEY_DUPLICATED) and differenceTooLong apply
/// nothing here: `.authKeyDuplicated`, `.tooLong` (the main app's reset is its caller's). Any other answer is built
/// into a final state over a snapshot of the stored state, which must still be the state the request was made from
/// (`authorizedState`; otherwise `.stateChangedMeanwhile`), and replayed under `policy.replayPolicy` after a hop to
/// `queue`: `.applied`, or `.replayRejected` when the replay's verification refuses it.
///
/// `asyncResetChannels` is `finalStateWithDifference`'s: nil resets the difference's channels inline.
/// `possiblyDeliveredMessagesUniqueIds` is read on `queue` just before the replay's transaction: the manager's
/// `removePossiblyDeliveredMessagesUniqueIds`, empty once the manager is gone.
func applyDifferenceAnswer(_ answer: Api.updates.Difference?, requestedFrom authorizedState: AuthorizedAccountState.State, policy: DifferencePolicy, accountPeerId: PeerId, postbox: Postbox, network: Network, queue: Queue, replayer: FinalStateReplayer, asyncResetChannels: (([(peer: Peer, pts: Int32?)]) -> Void)?, possiblyDeliveredMessagesUniqueIds: @escaping () -> [Int64: PeerId]) -> Signal<DifferenceOutcome, NoError> {
    guard let difference = answer else {
        return .single(.authKeyDuplicated)
    }
    switch difference {
    case let .differenceTooLong(differenceTooLongData):
        // The main app's poll resets to the pts the answer carries (its completion); the extension leaves the reset
        // to the app (Q3).
        return .single(.tooLong(replyPts: differenceTooLongData.pts))
    default:
        let isSlice: Bool
        if case .differenceSlice = difference {
            isSlice = true
        } else {
            isSlice = false
        }
        let mediaBox = postbox.mediaBox
        return initialStateWithDifference(postbox: postbox, difference: difference)
        |> mapToSignal { state -> Signal<DifferenceOutcome, NoError> in
            if state.initialState.state != authorizedState {
                Logger.shared.log("State", "pollDifference initial state \(authorizedState) != current state \(state.initialState.state)")
                return .single(.stateChangedMeanwhile)
            } else {
                return finalStateWithDifference(accountPeerId: accountPeerId, postbox: postbox, network: network, state: state, difference: difference, asyncResetChannels: asyncResetChannels)
                |> deliverOn(queue)
                |> mapToSignal { finalState -> Signal<DifferenceOutcome, NoError> in
                    if !finalState.state.preCachedResources.isEmpty {
                        for (resource, data) in finalState.state.preCachedResources {
                            mediaBox.storeResourceData(resource.id, data: data)
                        }
                    }
                    let removePossiblyDeliveredMessagesUniqueIds = possiblyDeliveredMessagesUniqueIds()
                    return postbox.transaction { transaction -> DifferenceOutcome in
                        let replayedState = replayer.applyReplay(finalState, policy: policy.replayPolicy, removePossiblyDeliveredMessagesUniqueIds: removePossiblyDeliveredMessagesUniqueIds, transaction: transaction)

                        if let replayedState = replayedState {
                            return .applied(replayedState, isSlice: isSlice)
                        } else {
                            return .replayRejected
                        }
                    }
                }
            }
        }
    }
}
