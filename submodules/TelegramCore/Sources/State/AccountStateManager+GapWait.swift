import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

private typealias SignalKitTimer = SwiftSignalKit.Timer

extension AccountStateManager.Impl {
    /// Runs the gap wait queued after a batch with a common pts, qts or seq hole: a timer on the queue, during which
    /// pushed update groups are absorbed and dropped (audit Q5); when it fires, the operation is taken off the head and
    /// a getDifference replaces the queue.
    func runGapWait() {
        self.operationTimer?.invalidate()
        let operationTimer = SignalKitTimer(timeout: self.gapWaitTimeout, repeat: false, completion: { [weak self] in
            if let strongSelf = self {
                if strongSelf.operations.popGapWait() {
                    Logger.shared.log("AccountStateManager", "timeout while waiting for updates")
                    strongSelf.replaceOperations(with: .fetchDifference(strongSelf.getNextId(), AccountFinalStateEvents()))
                    strongSelf.startFirstOperation()
                }
            }
        }, queue: self.queue)
        self.operationTimer = operationTimer
        operationTimer.start()
    }
}
