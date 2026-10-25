import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

extension AccountStateManager.Impl {
    /// Runs a `pollStateUpdateCompletion` barrier. While other operations are queued, it moves itself to the end of the
    /// queue at once; once it is the only one, it waits for a `help.test` round trip and then calls its subscribers
    /// with the incoming message ids collected meanwhile, or moves to the end again when operations arrived during the
    /// round trip.
    func runStateBarrier(pollId: Int32, preMessageIds: [MessageId], preSubscribers: [(Int32, ([MessageId]) -> Void)]) {
        if self.operations.barrierStepsAside() {
            self.postponeStateBarrier(messageIds: preMessageIds, subscribers: preSubscribers)
            self.startFirstOperation()
        } else {
            self.operationTimer?.invalidate()
            let signal = self.network.request(Api.functions.help.test())
            |> deliverOn(self.queue)
            let completed: () -> Void = { [weak self] in
                if let strongSelf = self {
                    if case let (messageIds, subscribers)? = strongSelf.operations.popStateBarrier(id: pollId) {
                        if strongSelf.operations.isEmpty {
                            for (_, f) in subscribers {
                                f(messageIds)
                            }
                        } else {
                            strongSelf.postponeStateBarrier(messageIds: messageIds, subscribers: subscribers)
                        }
                        strongSelf.startFirstOperation()
                    }
                }
            }
            let _ = (signal |> deliverOn(self.queue)).start(error: { _ in
                completed()
            }, completed: {
                completed()
            })
        }
    }
}
