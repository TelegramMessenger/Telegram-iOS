import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

extension AccountStateManager.Impl {
    /// Runs an operation added by `addCustomOperation`: the next operation starts, on the queue, once its signal has
    /// ended (`addCustomOperation` forwards its values and its error to its caller).
    func runCustom(operationId: Int32, signal: Signal<Void, NoError>) {
        self.operationTimer?.invalidate()
        let completed: () -> Void = { [weak self] in
            if let strongSelf = self {
                if strongSelf.operations.popCustom(id: operationId) {
                    strongSelf.startFirstOperation()
                }
            }
        }
        let _ = (signal |> deliverOn(self.queue)).start(completed: {
            completed()
        })
    }
}
