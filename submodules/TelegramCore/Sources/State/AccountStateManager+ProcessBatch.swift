import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

extension AccountStateManager.Impl {
    /// Runs a batch of pushed update groups: builds its final state against the stored state and replays it unless the
    /// batch is discarded. Then, on the queue, the operation is taken off the head, the replay's events are queued and
    /// the final state's `followUp` is done (nothing more, a gap wait at the end of the queue, or a getDifference in
    /// place of the queue) before the next operation starts.
    func runProcessBatch(groups: [UpdateGroup]) {
        self.operationTimer?.invalidate()
        let postbox = self.postbox
        let network = self.network
        let accountPeerId = self.accountPeerId
        let queue = self.queue
        let replayer = self.replayer
        
        let signal = initialStateWithUpdateGroups(postbox: postbox, groups: groups)
        |> mapToSignal { [weak self] state -> Signal<(AccountReplayedFinalState?, AccountFinalState), NoError> in
            return finalStateWithUpdateGroups(accountPeerId: accountPeerId, postbox: postbox, network: network, state: state, groups: groups, asyncResetChannels: nil)
            |> deliverOn(queue)
            |> mapToSignal { finalState in
                if finalState.followUp != .discard && !finalState.state.preCachedResources.isEmpty {
                    for (resource, data) in finalState.state.preCachedResources {
                        postbox.mediaBox.storeResourceData(resource.id, data: data)
                    }
                }
                
                let removePossiblyDeliveredMessagesUniqueIds = self?.removePossiblyDeliveredMessagesUniqueIds ?? Dictionary()
                
                return postbox.transaction { transaction -> AccountReplayedFinalState? in
                    if finalState.followUp == .discard {
                        return nil
                    } else {
                        return replayer.applyReplay(finalState, policy: .verified, removePossiblyDeliveredMessagesUniqueIds: removePossiblyDeliveredMessagesUniqueIds, transaction: transaction)
                    }
                }
                |> map({ ($0, finalState) })
                |> deliverOn(queue)
            }
        }
        let _ = signal.start(next: { [weak self] replayedState, finalState in
            if let strongSelf = self {
                if strongSelf.operations.popProcessBatch() {
                    if let replayedState = replayedState {
                        // A committed replay's events are queued whatever follows. Before a poll that is all of
                        // them, not only the alerts: pts moved past them, so the poll does not bring them again (Q4).
                        let events = AccountFinalStateEvents(state: replayedState)
                        if !events.isEmpty {
                            strongSelf.insertDispatchEvents(events)
                        }
                    }
                    switch (finalState.followUp, replayedState != nil) {
                    case (.apply, true):
                        break
                    case (.applyThenAwaitGap, true):
                        strongSelf.addOperation(.gapWait, position: .last)
                    case (.applyThenPoll, _), (.discard, _), (_, false):
                        // A forced poll, a batch that was not replayed (`.discard`), or a replay that
                        // `replayFinalState` refused: a getDifference replaces the batch.
                        strongSelf.replaceOperations(with: .fetchDifference(strongSelf.getNextId(), AccountFinalStateEvents()))
                    }
                    strongSelf.startFirstOperation()
                }
            }
        })
    }
}
