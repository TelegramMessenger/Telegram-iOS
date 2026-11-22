import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

private typealias SignalKitTimer = SwiftSignalKit.Timer

extension AccountStateManager.Impl {
    /// Runs a batch of pushed update groups that waits to be processed: a zero-length timer on the queue lets groups
    /// pushed meanwhile join it (`addUpdateGroups`); when it fires, the operation is taken off the head and its groups
    /// are processed next.
    func runBatchUpdates() {
        self.operationTimer?.invalidate()
        let operationTimer = SignalKitTimer(timeout: 0.0, repeat: false, completion: { [weak self] in
            if let strongSelf = self {
                if let groups = strongSelf.operations.popBatchUpdates() {
                    strongSelf.addOperation(.processBatch(groups), position: .first)
                    strongSelf.startFirstOperation()
                }
            }
        }, queue: self.queue)
        self.operationTimer = operationTimer
        operationTimer.start()
    }
}
