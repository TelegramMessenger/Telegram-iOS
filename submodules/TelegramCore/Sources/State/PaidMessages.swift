import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit

func _internal_getPaidMessagesRevenue(account: Account, peerId: PeerId) -> Signal<StarsAmount?, NoError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(peerId).flatMap(apiInputUser)
    }
    |> mapToSignal { inputUser -> Signal<StarsAmount?, NoError> in
        guard let inputUser else {
            return .single(nil)
        }
        return account.network.request(Api.functions.account.getPaidMessagesRevenue(userId: inputUser))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.account.PaidMessagesRevenue?, NoError> in
            return .single(nil)
        }
        |> map { result -> StarsAmount? in
            guard let result else {
                return nil
            }
            switch result {
            case let .paidMessagesRevenue(amount):
                return StarsAmount(value: amount, nanos: 0)
            }
        }
    }
}

func _internal_addNoPaidMessagesException(account: Account, peerId: PeerId, refundCharged: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(peerId).flatMap(apiInputUser)
    }
    |> mapToSignal { inputUser -> Signal<Never, NoError> in
        guard let inputUser else {
            return .never()
        }
        var flags: Int32 = 0
        if refundCharged {
            flags |= (1 << 0)
        }
        return account.network.request(Api.functions.account.addNoPaidMessagesException(flags: flags, userId: inputUser))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        } |> mapToSignal { _ in
            return account.postbox.transaction { transaction -> Void in
                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData in
                    if let cachedData = cachedData as? CachedUserData {
                        var settings = cachedData.peerStatusSettings ?? .init()
                        settings.paidMessageStars = nil
                        return cachedData.withUpdatedPeerStatusSettings(settings)
                    }
                    return cachedData
                })
            }
            |> ignoreValues
        }
        |> ignoreValues
    }
}

func _internal_updateChannelPaidMessagesStars(account: Account, peerId: PeerId, stars: StarsAmount?, broadcastMessagesAllowed: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Signal<Never, NoError> in
        guard let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer) else {
            return .complete()
        }
        var flags: Int32 = 0
        var stars = stars
        if broadcastMessagesAllowed {
            flags |= (1 << 0)
            if stars == nil {
                stars = StarsAmount(value: 0, nanos: 0)
            }
        }
        
        if let channel = peer as? TelegramChannel, case let .broadcast(broadcastInfo) = channel.info {
            var infoFlags = broadcastInfo.flags
            if broadcastMessagesAllowed {
                infoFlags.insert(.hasMonoforum)
            } else {
                infoFlags.remove(.hasMonoforum)
            }
            let channel = channel
                .withUpdatedInfo(.broadcast(TelegramChannelBroadcastInfo(flags: infoFlags)))
            transaction.updatePeersInternal([channel], update: { _, channel in
                return channel
            })
            
            if let linkedMonoforumId = channel.linkedMonoforumId, let monoforumChannel = transaction.getPeer(linkedMonoforumId) as? TelegramChannel {
                let monoforumChannel = monoforumChannel
                    .withUpdatedSendPaidMessageStars(stars)
                transaction.updatePeersInternal([monoforumChannel], update: { _, channel in
                    return monoforumChannel
                })
            }
        }
        
        return account.network.request(Api.functions.channels.updatePaidMessagesPrice(flags: flags, channel: inputChannel, sendPaidMessagesStars: stars?.value ?? 0))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            guard let result = result else {
                return .complete()
            }
            account.stateManager.addUpdates(result)
            
            return .complete()
        }
    }
    |> switchToLatest
}

public final class PostponeSendPaidMessageAction: PendingMessageActionData {
    public let randomId: Int64
    
    public init(randomId: Int64) {
        self.randomId = randomId
    }
    
    public init(decoder: PostboxDecoder) {
        self.randomId = decoder.decodeInt64ForKey("id", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.randomId, forKey: "id")
    }
    
    public func isEqual(to: PendingMessageActionData) -> Bool {
        if let other = to as? PostponeSendPaidMessageAction {
            if self.randomId != other.randomId {
                return false
            }
            return true
        } else {
            return false
        }
    }
}

private final class ManagedApplyPendingPaidMessageActionsHelper {
    var operationDisposables: [MessageId: (PendingMessageActionData, Disposable)] = [:]
    
    func update(entries: [PendingMessageActionsEntry]) -> (disposeOperations: [Disposable], beginOperations: [(PendingMessageActionsEntry, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PendingMessageActionsEntry, MetaDisposable)] = []
        
        var hasRunningOperationForPeerId = Set<PeerId>()
        var validIds = Set<MessageId>()
        for entry in entries {
            if let current = self.operationDisposables[entry.id], !current.0.isEqual(to: entry.action) {
                self.operationDisposables.removeValue(forKey: entry.id)
                disposeOperations.append(current.1)
            }
            
            if !hasRunningOperationForPeerId.contains(entry.id.peerId) {
                hasRunningOperationForPeerId.insert(entry.id.peerId)
                validIds.insert(entry.id)
                
                let disposable = MetaDisposable()
                beginOperations.append((entry, disposable))
                self.operationDisposables[entry.id] = (entry.action, disposable)
            }
        }
        
        var removeMergedIds: [MessageId] = []
        for (id, actionAndDisposable) in self.operationDisposables {
            if !validIds.contains(id) {
                removeMergedIds.append(id)
                disposeOperations.append(actionAndDisposable.1)
            }
        }
        
        for id in removeMergedIds {
            self.operationDisposables.removeValue(forKey: id)
        }
        
        return (disposeOperations, beginOperations)
    }
    
    func reset() -> [Disposable] {
        let disposables = Array(self.operationDisposables.values.map(\.1))
        self.operationDisposables.removeAll()
        return disposables
    }
}

private func withTakenStarsAction(postbox: Postbox, type: PendingMessageActionType, id: MessageId, _ f: @escaping (Transaction, PendingMessageActionsEntry?) -> Signal<Never, NoError>) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Signal<Never, NoError> in
        var result: PendingMessageActionsEntry?
        
        if let action = transaction.getPendingMessageAction(type: type, id: id) as? PostponeSendPaidMessageAction {
            result = PendingMessageActionsEntry(id: id, action: action)
        }
        
        return f(transaction, result)
    }
    |> switchToLatest
}

private func sendPostponedPaidMessage(transaction: Transaction, postbox: Postbox, network: Network, stateManager: AccountStateManager, id: MessageId) -> Signal<Never, NoError> {
    stateManager.commitSendPendingPaidMessage(messageId: id)
    return postbox.transaction { transaction -> Void in
        transaction.setPendingMessageAction(type: .sendPostponedPaidMessage, id: id, action: nil)
    }
    |> ignoreValues
}

func managedApplyPendingPaidMessageActions(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic<ManagedApplyPendingPaidMessageActionsHelper>(value: ManagedApplyPendingPaidMessageActionsHelper())
        
        let actionsKey = PostboxViewKey.pendingMessageActions(type: .sendPostponedPaidMessage)
        let disposable = postbox.combinedView(keys: [actionsKey]).start(next: { view in
            var entries: [PendingMessageActionsEntry] = []
            if let v = view.views[actionsKey] as? PendingMessageActionsView {
                entries = v.entries
            }
            
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PendingMessageActionsEntry, MetaDisposable)]) in
                return helper.update(entries: entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenStarsAction(postbox: postbox, type: .sendPostponedPaidMessage, id: entry.id, { transaction, entry -> Signal<Never, NoError> in
                    if let entry = entry {
                        if let _ = entry.action as? PostponeSendPaidMessageAction {
                            let triggerSignal: Signal<Void, NoError> = stateManager.forceSendPendingPaidMessage
                            |> filter {
                                $0 == entry.id.peerId
                            }
                            |> map { _ -> Void in
                                return Void()
                            }
                            |> take(1)
                            |> timeout(5.0, queue: .mainQueue(), alternate: .single(Void()))
                            
                            return triggerSignal
                            |> mapToSignal { _ -> Signal<Never, NoError> in
                                return sendPostponedPaidMessage(transaction: transaction, postbox: postbox, network: network, stateManager: stateManager, id: entry.id)
                            }
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                |> then(
                    postbox.transaction { transaction -> Void in
                    transaction.setPendingMessageAction(type: .sendPostponedPaidMessage, id: entry.id, action: nil)
                    }
                    |> ignoreValues
                )
                
                disposable.set(signal.start())
            }
        })
        
        return ActionDisposable {
            let disposables = helper.with { helper -> [Disposable] in
                return helper.reset()
            }
            for disposable in disposables {
                disposable.dispose()
            }
            disposable.dispose()
        }
    }
}

func _internal_forceSendPostponedPaidMessage(account: Account, peerId: PeerId) -> Signal<Never, NoError> {
    account.stateManager.forceSendPendingPaidMessage(peerId: peerId)
    
    return .complete()
}
