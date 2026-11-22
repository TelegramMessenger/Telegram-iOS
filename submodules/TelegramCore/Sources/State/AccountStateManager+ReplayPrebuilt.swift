import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

extension AccountStateManager.Impl {
    /// Replays a final state built off the queue (`addReplayAsynchronouslyBuiltFinalState`). On the queue, the
    /// operation is taken off the head, the replay's events are queued and the next operation starts; `completion` runs
    /// last.
    func runReplayPrebuilt(finalState: AccountFinalState, completion: @escaping () -> Void) {
        if !finalState.state.preCachedResources.isEmpty {
            for (resource, data) in finalState.state.preCachedResources {
                self.postbox.mediaBox.storeResourceData(resource.id, data: data)
            }
        }
        
        let replayer = self.replayer
        let removePossiblyDeliveredMessagesUniqueIds = self.removePossiblyDeliveredMessagesUniqueIds
        let signal = self.postbox.transaction { transaction -> AccountReplayedFinalState? in
            return replayer.applyReplay(finalState, policy: .verified, removePossiblyDeliveredMessagesUniqueIds: removePossiblyDeliveredMessagesUniqueIds, transaction: transaction)
        }
        |> map({ ($0, finalState) })
        |> deliverOn(self.queue)
        
        let _ = signal.start(next: { [weak self] replayedState, finalState in
            if let strongSelf = self {
                if strongSelf.operations.popReplayPrebuilt() {
                    if let replayedState = replayedState {
                        let events = AccountFinalStateEvents(state: replayedState)
                        if !events.isEmpty {
                            strongSelf.insertDispatchEvents(events)
                        }
                    }
                    strongSelf.startFirstOperation()
                }
                completion()
            }
        })
    }
}
