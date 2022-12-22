import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

private typealias SignalKitTimer = SwiftSignalKit.Timer

private final class ManagedPeerTimestampAttributeOperationsHelper {
    struct Entry: Equatable {
        var peerId: PeerId
        var timestamp: UInt32
    }
    
    var entry: (Entry, MetaDisposable)?
    
    func update(_ head: Entry?) -> (disposeOperations: [Disposable], beginOperations: [(Entry, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(Entry, MetaDisposable)] = []
        
        if self.entry?.0 != head {
            if let (_, disposable) = self.entry {
                self.entry = nil
                disposeOperations.append(disposable)
            }
            if let head = head {
                let disposable = MetaDisposable()
                self.entry = (head, disposable)
                beginOperations.append((head, disposable))
            }
        }
        
        return (disposeOperations, beginOperations)
    }
    
    func reset() -> [Disposable] {
        if let entry = entry {
            return [entry.1]
        } else {
            return []
        }
    }
}

func managedPeerTimestampAttributeOperations(network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic(value: ManagedPeerTimestampAttributeOperationsHelper())
        
        let timeOffsetOnce = Signal<Double, NoError> { subscriber in
            subscriber.putNext(network.globalTimeDifference)
            return EmptyDisposable
        }
        
        let timeOffset = (
            timeOffsetOnce
            |> then(
                Signal<Double, NoError>.complete()
                |> delay(1.0, queue: .mainQueue())
            )
        )
        |> restart
        |> map { value -> Double in
            round(value)
        }
        |> distinctUntilChanged

        let disposable = combineLatest(timeOffset, postbox.combinedView(keys: [PostboxViewKey.peerTimeoutAttributes])).start(next: { timeOffset, views in
            guard let view = views.views[PostboxViewKey.peerTimeoutAttributes] as? PeerTimeoutAttributesView else {
                return
            }
            let topEntry = view.minValue.flatMap { value in
                return ManagedPeerTimestampAttributeOperationsHelper.Entry(peerId: value.peerId, timestamp: value.timestamp)
            }
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(ManagedPeerTimestampAttributeOperationsHelper.Entry, MetaDisposable)]) in
                return helper.update(topEntry)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970 + timeOffset
                let delay = max(0.0, Double(entry.timestamp) - timestamp)
                let signal = Signal<Void, NoError>.complete()
                |> suspendAwareDelay(delay, queue: Queue.concurrentDefaultQueue())
                |> then(postbox.transaction { transaction -> Void in
                    if let peer = transaction.getPeer(entry.peerId) {
                        if let user = peer as? TelegramUser {
                            updatePeers(transaction: transaction, peers: [user.withUpdatedEmojiStatus(nil)], update: { _, updated in updated })
                        }
                    }
                    //failsafe
                    transaction.removePeerTimeoutAttributeEntry(peerId: entry.peerId, timestamp: entry.timestamp)
                })
                disposable.set(signal.start())
            }
        })
        
        return ActionDisposable {
            disposable.dispose()
            let disposables = helper.with { helper -> [Disposable] in
                return helper.reset()
            }
            for disposable in disposables {
                disposable.dispose()
            }
        }
    }
}
