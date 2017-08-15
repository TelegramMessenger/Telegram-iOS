import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

private final class ManagedConsumePersonalMessagesActionsHelper {
    var operationDisposables: [MessageId: Disposable] = [:]
    
    func update(_ entries: [PendingMessageActionsEntry]) -> (disposeOperations: [Disposable], beginOperations: [(PendingMessageActionsEntry, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PendingMessageActionsEntry, MetaDisposable)] = []
        
        var hasRunningOperationForPeerId = Set<PeerId>()
        var validIds = Set<MessageId>()
        for entry in entries {
            if !hasRunningOperationForPeerId.contains(entry.id.peerId) {
                hasRunningOperationForPeerId.insert(entry.id.peerId)
                validIds.insert(entry.id)
                
                if self.operationDisposables[entry.id] == nil {
                    let disposable = MetaDisposable()
                    beginOperations.append((entry, disposable))
                    self.operationDisposables[entry.id] = disposable
                }
            }
        }
        
        var removeMergedIds: [MessageId] = []
        for (id, disposable) in self.operationDisposables {
            if !validIds.contains(id) {
                removeMergedIds.append(id)
                disposeOperations.append(disposable)
            }
        }
        
        for id in removeMergedIds {
            self.operationDisposables.removeValue(forKey: id)
        }
        
        return (disposeOperations, beginOperations)
    }
    
    func reset() -> [Disposable] {
        let disposables = Array(self.operationDisposables.values)
        self.operationDisposables.removeAll()
        return disposables
    }
}

private func withTakenAction(postbox: Postbox, type: PendingMessageActionType, id: MessageId, _ f: @escaping (Modifier, PendingMessageActionsEntry?) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Signal<Void, NoError> in
        var result: PendingMessageActionsEntry?
        
        if let action = modifier.getPendingMessageAction(type: type, id: id) as? ConsumePersonalMessageAction {
            result = PendingMessageActionsEntry(id: id, action: action)
        }
        
        return f(modifier, result)
    } |> switchToLatest
}


func managedConsumePersonalMessagesActions(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic<ManagedConsumePersonalMessagesActionsHelper>(value: ManagedConsumePersonalMessagesActionsHelper())
        
        let key = PostboxViewKey.pendingMessageActions(type: .consumeUnseenPersonalMessage)
        let disposable = postbox.combinedView(keys: [key]).start(next: { view in
            var entries: [PendingMessageActionsEntry] = []
            if let v = view.views[key] as? PendingMessageActionsView {
                entries = v.entries
            }
            
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PendingMessageActionsEntry, MetaDisposable)]) in
                return helper.update(entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenAction(postbox: postbox, type: .consumeUnseenPersonalMessage, id: entry.id, { modifier, entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let _ = entry.action as? ConsumePersonalMessageAction {
                            return synchronizeConsumeMessageContents(modifier: modifier, postbox: postbox, network: network, stateManager: stateManager, id: entry.id)
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                |> then(postbox.modify { modifier -> Void in
                    modifier.setPendingMessageAction(type: .consumeUnseenPersonalMessage, id: entry.id, action: nil)
                })
                
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

private func synchronizeConsumeMessageContents(modifier: Modifier, postbox: Postbox, network: Network, stateManager: AccountStateManager, id: MessageId) -> Signal<Void, NoError> {
    if id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup {
        return network.request(Api.functions.messages.readMessageContents(id: [id.id]))
            |> map { Optional($0) }
            |> `catch` { _ -> Signal<Api.messages.AffectedMessages?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Void, NoError> in
                if let result = result {
                    switch result {
                        case let .affectedMessages(pts, ptsCount):
                            stateManager.addUpdateGroups([.updatePts(pts: pts, ptsCount: ptsCount)])
                    }
                }
                return postbox.modify { modifier -> Void in
                    modifier.setPendingMessageAction(type: .consumeUnseenPersonalMessage, id: id, action: nil)
                    modifier.updateMessage(id, update: { currentMessage in
                        var storeForwardInfo: StoreMessageForwardInfo?
                        if let forwardInfo = currentMessage.forwardInfo {
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                        }
                        var attributes = currentMessage.attributes
                        loop: for j in 0 ..< attributes.count {
                            if let attribute = attributes[j] as? ConsumablePersonalMentionMessageAttribute, !attribute.consumed {
                                attributes[j] = ConsumablePersonalMentionMessageAttribute(consumed: true, pending: false)
                                break loop
                            }
                        }
                        var updatedTags = currentMessage.tags
                        updatedTags.remove(.unseenPersonalMessage)
                        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: updatedTags, globalTags: currentMessage.globalTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                    })
                }
            }
    } else if id.peerId.namespace == Namespaces.Peer.CloudChannel {
        if let peer = modifier.getPeer(id.peerId), let inputChannel = apiInputChannel(peer) {
            return network.request(Api.functions.channels.readMessageContents(channel: inputChannel, id: [id.id]))
                |> `catch` { _ -> Signal<Api.Bool, NoError> in
                    return .single(.boolFalse)
                } |> mapToSignal { result -> Signal<Void, NoError> in
                    return postbox.modify { modifier -> Void in
                        modifier.setPendingMessageAction(type: .consumeUnseenPersonalMessage, id: id, action: nil)
                        modifier.updateMessage(id, update: { currentMessage in
                            var storeForwardInfo: StoreMessageForwardInfo?
                            if let forwardInfo = currentMessage.forwardInfo {
                                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                            }
                            var attributes = currentMessage.attributes
                            loop: for j in 0 ..< attributes.count {
                                if let attribute = attributes[j] as? ConsumablePersonalMentionMessageAttribute, !attribute.consumed {
                                    attributes[j] = ConsumablePersonalMentionMessageAttribute(consumed: true, pending: false)
                                    break loop
                                }
                            }
                            var updatedTags = currentMessage.tags
                            updatedTags.remove(.unseenPersonalMessage)
                            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: updatedTags, globalTags: currentMessage.globalTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                        })
                    }
                }
        } else {
            return .complete()
        }
    } else {
        return .complete()
    }
}
