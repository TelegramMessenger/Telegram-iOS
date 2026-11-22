import Foundation

/// What one getDifference attempt came to. The attempt is `fetchAndApplyDifference(policy:)`
/// (AccountStateManager.swift; its request and its answer's replay are in DifferencePolicy.swift), for the main app's
/// poll (the `fetchDifference` operation, run by `runFetchDifference` in AccountStateManager+FetchDifference.swift) or
/// the notification extension's (`standalonePollDifference`). The main app's runner handles it in one switch with no
/// default (`handleResult`), so every outcome is decided in one place:
/// - the chain of polls goes on: `.applied(_, isSlice: true)` and `.tooLong`;
/// - the chain and the poll cycle end through `finishPollCycle`, the cycle's single end: `.applied(_, isSlice: false)`
///   and `.authKeyDuplicated`;
/// - the chain ends without ending the cycle: `.stateChangedMeanwhile`, `.replayRejected` and `.noInnerState`. The
///   events so far are queued and `replaceOperations` puts a fresh poll in the queue; they are the only outcomes that
///   end the chain and start a fresh one inside the same cycle (isUpdating stays true until that poll's chain ends).
///   A slice and `.tooLong` poll again too, but as the next poll of the same chain.
///
/// The extension's poll sends `date: Int32.max` and only asks whether a slice was applied: its caller polls again
/// after `.applied(_, isSlice: true)` and is done after anything else.
enum DifferenceOutcome {
    /// The difference was replayed. A slice continues the chain from its intermediate state, carrying the events so
    /// far; a final difference (`updates.difference` or `updates.differenceEmpty`) ends it with its replayed state's pts.
    case applied(AccountReplayedFinalState, isSlice: Bool)
    /// updates.differenceTooLong with the pts it carries. The account is reset to that pts (qts, date and seq kept),
    /// after the consecutive-reset backoff, and the same cycle polls again with the events so far. The extension
    /// resets nothing and leaves the reset to the app (Q3).
    case tooLong(replyPts: Int32)
    /// getDifference failed with 406 AUTH_KEY_DUPLICATED: the key is dead and a re-login follows. Nothing was applied
    /// and the cycle ends (Q2).
    case authKeyDuplicated
    /// The stored state is not the one the request was built from (`initialStateWithDifference` read another one).
    /// Nothing was applied.
    case stateChangedMeanwhile
    /// `replayFinalState` refused the difference (its verification). Nothing was applied.
    case replayRejected
    /// The stored account state has no inner state yet (between login and the first updates.getState) or, in the main
    /// app, is missing. The main app's poll has fetched updates.getState and written it into the stored account state,
    /// if there is one; the extension's has done nothing. The extension produces this only for a stored account state
    /// without an inner state: while there is no stored account state its read (`stateView` under `take(1)`) waits,
    /// until its caller's timeout ends it.
    case noInnerState
}
