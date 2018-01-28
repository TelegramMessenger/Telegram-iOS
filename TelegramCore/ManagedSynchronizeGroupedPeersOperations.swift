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

private final class ManagedSynchronizeGroupedPeersOperationsHelper {
    var operationDisposables: [Int32: Disposable] = [:]
    
    func update(_ entries: [PeerMergedOperationLogEntry]) -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)] = []
        
        var hasRunningOperationForPeerId = Set<PeerId>()
        var validMergedIndices = Set<Int32>()
        for entry in entries {
            if !hasRunningOperationForPeerId.contains(entry.peerId) {
                hasRunningOperationForPeerId.insert(entry.peerId)
                validMergedIndices.insert(entry.mergedIndex)
                
                if self.operationDisposables[entry.mergedIndex] == nil {
                    let disposable = MetaDisposable()
                    beginOperations.append((entry, disposable))
                    self.operationDisposables[entry.mergedIndex] = disposable
                }
            }
        }
        
        var removeMergedIndices: [Int32] = []
        for (mergedIndex, disposable) in self.operationDisposables {
            if !validMergedIndices.contains(mergedIndex) {
                removeMergedIndices.append(mergedIndex)
                disposeOperations.append(disposable)
            }
        }
        
        for mergedIndex in removeMergedIndices {
            self.operationDisposables.removeValue(forKey: mergedIndex)
        }
        
        return (disposeOperations, beginOperations)
    }
    
    func reset() -> [Disposable] {
        let disposables = Array(self.operationDisposables.values)
        self.operationDisposables.removeAll()
        return disposables
    }
}

private func withTakenOperation(postbox: Postbox, peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: Int32, _ f: @escaping (Modifier, PeerMergedOperationLogEntry?) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Signal<Void, NoError> in
        var result: PeerMergedOperationLogEntry?
        modifier.operationLogUpdateEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, { entry in
            if let entry = entry, let _ = entry.mergedIndex, entry.contents is SynchronizeGroupedPeersOperation  {
                result = entry.mergedEntry!
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            } else {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            }
        })
        
        return f(modifier, result)
        } |> switchToLatest
}

func managedSynchronizeGroupedPeersOperations(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return Signal { _ in
        let tag: PeerOperationLogTag = OperationLogTags.SynchronizeGroupedPeers
        
        let helper = Atomic<ManagedSynchronizeGroupedPeersOperationsHelper>(value: ManagedSynchronizeGroupedPeersOperationsHelper())
        
        let disposable = postbox.mergedOperationLogView(tag: tag, limit: 10).start(next: { view in
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) in
                return helper.update(view.entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenOperation(postbox: postbox, peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex, { modifier, entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let operation = entry.contents as? SynchronizeGroupedPeersOperation {
                            return synchronizeGroupedPeers(modifier: modifier, postbox: postbox, network: network, operation: operation)
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                    |> then(postbox.modify { modifier -> Void in
                        let _ = modifier.operationLogRemoveEntry(peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex)
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

private func hashForIds(_ ids: [Int32]) -> Int32 {
    var acc: UInt32 = 0
    
    for id in ids {
        let low = UInt32(bitPattern: id)
        acc = (acc &* 20261) &+ low
    }
    return Int32(bitPattern: acc & UInt32(0x7FFFFFFF))
}

private func synchronizeGroupedPeers(modifier: Modifier, postbox: Postbox, network: Network, operation: SynchronizeGroupedPeersOperation) -> Signal<Void, NoError> {
    /*%layer76*/
    return .complete()
    /*let initialRemotePeerIds = operation.initialPeerIds
    let localPeerIds = modifier.getPeerIdsInGroup(operation.groupId)
    
    return network.request(Api.functions.channels.getFeedSources(flags: 1 << 0, feedId: operation.groupId.rawValue, hash: hashForIds(localPeerIds.map({ $0.id }).sorted())))
    |> retryRequest
    |> mapToSignal { sources -> Signal<Void, NoError> in
        switch sources {
            case .feedSourcesNotModified:
                return .complete()
            case let .feedSources(_, newlyJoinedFeed, feeds, chats, users):
                var remotePeerIds = Set<PeerId>()
                for feedsInfo in feeds {
                    switch feedsInfo {
                        case let .feedBroadcasts(feedId, channels):
                            if feedId == operation.groupId.rawValue {
                                for id in channels {
                                    remotePeerIds.insert(PeerId(namespace: Namespaces.Peer.CloudChannel, id: id))
                                }
                            }
                        case .feedBroadcastsUngrouped:
                            break
                    }
                }
            
                let remoteAdded = remotePeerIds.subtracting(initialRemotePeerIds)
                let remoteRemoved = initialRemotePeerIds.subtracting(remotePeerIds)
                var finalPeerIds = localPeerIds
                finalPeerIds.formUnion(remoteAdded)
                finalPeerIds.subtract(remoteRemoved)
                
                //channels.setFeedBroadcasts feed_id:int channels:Vector<InputChannel> also_newly_joined:Bool = Bool;
                return postbox.modify { modifier -> Signal<Void, NoError> in
                    var peers: [PeerId: Peer] = [:]
                    var peerPresences: [PeerId: PeerPresence] = [:]
                    for chat in chats {
                        if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                            peers[groupOrChannel.id] = groupOrChannel
                        }
                    }
                    for user in users {
                        let telegramUser = TelegramUser(user: user)
                        peers[telegramUser.id] = telegramUser
                        if let presence = TelegramUserPresence(apiUser: user) {
                            peerPresences[telegramUser.id] = presence
                        }
                    }
                    
                    var inputChannels: [Api.InputChannel] = []
                    for peerId in finalPeerIds {
                        if let peer = modifier.getPeer(peerId) ?? peers[peerId], let inputChannel = apiInputChannel(peer) {
                            inputChannels.append(inputChannel)
                        } else {
                            assertionFailure()
                        }
                    }
                    
                    updatePeers(modifier: modifier, peers: Array(peers.values), update: { _, updated -> Peer in
                        return updated
                    })
                    modifier.updatePeerPresences(peerPresences)
                    
                    return network.request(Api.functions.channels.setFeedBroadcasts(feedId: operation.groupId.rawValue, channels: inputChannels, alsoNewlyJoined: .boolFalse))
                    |> retryRequest
                    |> mapToSignal { _ -> Signal<Void, NoError> in
                        return postbox.modify { modifier -> Void in
                            let currentLocalPeerIds = modifier.getPeerIdsInGroup(operation.groupId)
                            
                            for peerId in currentLocalPeerIds {
                                if !finalPeerIds.contains(peerId) {
                                    modifier.updatePeerGroupId(peerId, groupId: nil)
                                }
                            }
                            
                            for peerId in finalPeerIds {
                                modifier.updatePeerGroupId(peerId, groupId: operation.groupId)
                            }
                        }
                    }
                } |> switchToLatest
        }
    }*/
}

