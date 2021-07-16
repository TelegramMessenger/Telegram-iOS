import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit

private typealias SignalKitTimer = SwiftSignalKit.Timer


private final class NotificationAutolockReportManagerImpl {
    private let queue: Queue
    private let network: Network
    let isPerformingUpdate = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    private var deadlineDisposable: Disposable?
    private let currentRequestDisposable = MetaDisposable()
    private var onlineTimer: SignalKitTimer?
    
    init(queue: Queue, deadline: Signal<Int32?, NoError>, network: Network) {
        self.queue = queue
        self.network = network
        
        self.deadlineDisposable = (deadline
        |> distinctUntilChanged
        |> deliverOn(self.queue)).start(next: { [weak self] value in
            self?.updateDeadline(value)
        })
    }
    
    deinit {
        assert(self.queue.isCurrent())
        self.deadlineDisposable?.dispose()
        self.currentRequestDisposable.dispose()
        self.onlineTimer?.invalidate()
    }
    
    private func updateDeadline(_ deadline: Int32?) {
        self.isPerformingUpdate.set(true)
        let value: Int32
        if let deadline = deadline {
            value = max(0, deadline - Int32(CFAbsoluteTimeGetCurrent()))
        } else {
            value = -1
        }
        self.currentRequestDisposable.set((self.network.request(Api.functions.account.updateDeviceLocked(period: value))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> deliverOn(self.queue)).start(completed: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isPerformingUpdate.set(false)
        }))
    }
}

final class NotificationAutolockReportManager {
    private let queue = Queue()
    private let impl: QueueLocalObject<NotificationAutolockReportManagerImpl>
    
    init(deadline: Signal<Int32?, NoError>, network: Network) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: self.queue, generate: {
            return NotificationAutolockReportManagerImpl(queue: queue, deadline: deadline, network: network)
        })
    }
    
    func isPerformingUpdate() -> Signal<Bool, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.isPerformingUpdate.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
}
