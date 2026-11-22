import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

extension AccountStateManager.Impl {
    /// Delivers one batch of account events to their pipes and subscribers, in three steps, the last two on the queue:
    /// part of them at once; the notification messages, read in a Postbox transaction, when that transaction delivers
    /// them; and the rest when it completes, which is also when the operation is taken off the head and the next one
    /// starts.
    func runDispatchEvents(operationId: Int32, events: AccountFinalStateEvents) {
        self.operationTimer?.invalidate()
        let completed: () -> Void = { [weak self] in
            if let strongSelf = self {
                if strongSelf.operations.popDispatchEvents(id: operationId) {
                    strongSelf.eventHub.dispatchAfterNotificationMessages(events)
                    if let updatedQts = events.updatedQts {
                        strongSelf.appliedQtsPromise.set(.single(updatedQts))
                    }
                    strongSelf.operations.addIncomingMessageIdsToBarriers(events.addedIncomingMessageIds)
                    strongSelf.startFirstOperation()
                }
            }
        }
        
        self.eventHub.dispatch(events, completed: completed)
    }
}
