import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

extension AccountStateManager.Impl {
    /// Runs the poll at the head of the queue: one getDifference attempt of the running poll cycle, carrying the events
    /// of the attempts before it in the same chain (`currentEvents`). The attempt ends on the queue once its result is
    /// handled (for a differenceTooLong, once the account reset has completed): the poll is taken off the head, the
    /// next attempt is queued first when the chain goes on (a slice, a reset), and the next operation starts.
    func runFetchDifference(currentEvents: AccountFinalStateEvents) {
        self.operationTimer?.invalidate()
        self.currentIsUpdatingValue = true
        let queue = self.queue
        let postbox = self.postbox
        let network = self.network
        let accountPeerId = self.accountPeerId
        
        let signal = self.fetchAndApplyDifference(policy: .mainApp)
        
        // Runs on `queue`. There is no trailing `deliverOn(queue)`: it runs an event that arrives on
        // `queue` inline and dispatches one from another thread, so a completion that ended the chain on
        // `queue` overtook the result dispatched there a moment earlier, the terminated subscriber dropped
        // the result and this poll stayed running at the head of the queue for good (Q13). The `next`
        // handler below hops itself, with the result captured in the block.
        let handleResult: (DifferenceOutcome) -> Void = { [weak self] outcome in
            guard let strongSelf = self else {
                return
            }
            // Every outcome is handled, with no default (DifferenceOutcome.swift): a slice and a differenceTooLong
            // reset continue the chain; an applied final difference and AUTH_KEY_DUPLICATED end it and the cycle
            // through finishPollCycle, the cycle's single end; the three outcomes that replayed no difference share
            // the last arm, the only one that ends the chain but not the cycle: it starts a fresh chain
            // (`replaceOperations`) inside the same cycle.
            switch outcome {
            case let .tooLong(replyPts):
                // The reset moves pts to the one differenceTooLong carried and keeps qts, date and seq.
                // It does not end the chain: the same cycle polls again from the new pts (G10), and the
                // events gathered so far are delivered when that chain ends (Q1).
                strongSelf.differenceChainLog?.noteTooLong(replyPts: replyPts)
                strongSelf.consecutiveResetCount += 1
                let resetDelay = AccountStateManager.consecutiveResetDelay(strongSelf.consecutiveResetCount)
                let resetSignal: Signal<Never, NoError>
                if resetDelay > 0.0 {
                    // Not the first reset in a row in this cycle: wait first. The poll stays at the head of
                    // the queue meanwhile and isUpdating stays true, as for any request this path retries.
                    Logger.shared.log("State", "differenceTooLong: reset \(strongSelf.consecutiveResetCount) in a row in this cycle, waiting \(resetDelay) s first")
                    resetSignal = _internal_resetAccountState(postbox: postbox, network: network, accountPeerId: accountPeerId, pts: replyPts)
                    |> delay(resetDelay, queue: strongSelf.queue)
                } else {
                    resetSignal = _internal_resetAccountState(postbox: postbox, network: network, accountPeerId: accountPeerId, pts: replyPts)
                }
                // Held by the Impl, so it is cancelled when the account's manager goes (`accountResetDisposable`).
                strongSelf.accountResetDisposable.set((resetSignal
                |> deliverOn(strongSelf.queue)).start(completed: {
                    guard let strongSelf = self else {
                        return
                    }
                    if strongSelf.operations.popFetchDifference() {
                        strongSelf.addOperation(.fetchDifference(strongSelf.getNextId(), currentEvents), position: .first)
                        strongSelf.startFirstOperation()
                    }
                }))
            case let .applied(replayedState, isSlice: true):
                if strongSelf.removeFinishedPoll() {
                    let events = currentEvents.union(with: AccountFinalStateEvents(state: replayedState))
                    strongSelf.addOperation(.fetchDifference(strongSelf.getNextId(), events), position: .first)
                    strongSelf.startFirstOperation()
                }
            case let .applied(replayedState, isSlice: false):
                if strongSelf.removeFinishedPoll() {
                    let events = currentEvents.union(with: AccountFinalStateEvents(state: replayedState))
                    strongSelf.differenceChainLog?.logEnd(endPts: replayedState.state.state.state.pts)
                    strongSelf.differenceChainLog = nil
                    strongSelf.finishPollCycle(events: events)
                    strongSelf.startFirstOperation()
                }
            case .authKeyDuplicated:
                if strongSelf.removeFinishedPoll() {
                    strongSelf.differenceChainLog?.logEnd(endPts: nil)
                    strongSelf.differenceChainLog = nil
                    strongSelf.finishPollCycle(events: currentEvents)
                    strongSelf.startFirstOperation()
                }
            case .stateChangedMeanwhile, .replayRejected, .noInnerState:
                if strongSelf.removeFinishedPoll() {
                    // The poll replayed no difference: this attempt's chain ends here, its events are queued, and
                    // the replacing poll starts a chain of its own in the same cycle (isUpdating stays true).
                    strongSelf.differenceChainLog?.logEnd(endPts: nil)
                    strongSelf.differenceChainLog = nil
                    if !currentEvents.isEmpty {
                        strongSelf.insertDispatchEvents(currentEvents)
                    }
                    strongSelf.replaceOperations(with: .fetchDifference(strongSelf.getNextId(), AccountFinalStateEvents()))
                    strongSelf.startFirstOperation()
                }
            }
        }
        let _ = signal.start(next: { outcome in
            queue.async {
                handleResult(outcome)
            }
        })
    }
}
