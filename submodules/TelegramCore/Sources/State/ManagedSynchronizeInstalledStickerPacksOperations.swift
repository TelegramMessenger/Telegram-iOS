import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


private final class ManagedSynchronizeInstalledStickerPacksOperationsHelper {
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

private func withTakenOperation(postbox: Postbox, peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: Int32, _ f: @escaping (Transaction, PeerMergedOperationLogEntry?) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var result: PeerMergedOperationLogEntry?
        transaction.operationLogUpdateEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, { entry in
            if let entry = entry, let _ = entry.mergedIndex, entry.contents is SynchronizeInstalledStickerPacksOperation  {
                result = entry.mergedEntry!
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            } else {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            }
        })
        
        return f(transaction, result)
        } |> switchToLatest
}

func managedSynchronizeInstalledStickerPacksOperations(postbox: Postbox, network: Network, stateManager: AccountStateManager, namespace: SynchronizeInstalledStickerPacksOperationNamespace) -> Signal<Void, NoError> {
    return Signal { _ in
        let tag: PeerOperationLogTag
        switch namespace {
            case .stickers:
                tag = OperationLogTags.SynchronizeInstalledStickerPacks
            case .masks:
                tag = OperationLogTags.SynchronizeInstalledMasks
        }
        
        let helper = Atomic<ManagedSynchronizeInstalledStickerPacksOperationsHelper>(value: ManagedSynchronizeInstalledStickerPacksOperationsHelper())
        
        let disposable = postbox.mergedOperationLogView(tag: tag, limit: 10).start(next: { view in
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) in
                return helper.update(view.entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenOperation(postbox: postbox, peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex, { transaction, entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let operation = entry.contents as? SynchronizeInstalledStickerPacksOperation {
                            return stateManager.pollStateUpdateCompletion()
                            |> mapToSignal { _ -> Signal<Void, NoError> in
                                return postbox.transaction { transaction -> Signal<Void, NoError> in
                                    return synchronizeInstalledStickerPacks(transaction: transaction, postbox: postbox, network: network, stateManager: stateManager, namespace: namespace, operation: operation)
                                }
                                |> switchToLatest
                            }
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                |> then(postbox.transaction { transaction -> Void in
                    let _ = transaction.operationLogRemoveEntry(peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex)
                })
                
                disposable.set((signal |> delay(0.0, queue: Queue.concurrentDefaultQueue())).start())
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

private func hashForStickerPackInfos(_ infos: [StickerPackCollectionInfo]) -> Int64 {
    var acc: UInt64 = 0
    
    for info in infos {
        combineInt64Hash(&acc, with: UInt64(UInt32(bitPattern: info.hash)))
    }
    
    return finalizeInt64Hash(acc)
}

private enum SynchronizeInstalledStickerPacksError {
    case restart
    case done
}

private func fetchStickerPack(network: Network, info: StickerPackCollectionInfo) -> Signal<(StickerPackCollectionInfo, [ItemCollectionItem]), NoError> {
    return network.request(Api.functions.messages.getStickerSet(stickerset: .inputStickerSetID(id: info.id.id, accessHash: info.accessHash), hash: 0))
    |> map { result -> (StickerPackCollectionInfo, [ItemCollectionItem]) in
        var items: [ItemCollectionItem] = []
        var updatedInfo = info
        switch result {
        case .stickerSetNotModified:
            break
        case let .stickerSet(stickerSet, packs, documents):
            updatedInfo = StickerPackCollectionInfo(apiSet: stickerSet, namespace: info.id.namespace)
            var indexKeysByFile: [MediaId: [MemoryBuffer]] = [:]
            for pack in packs {
                switch pack {
                case let .stickerPack(text, fileIds):
                    let key = ValueBoxKey(text).toMemoryBuffer()
                    for fileId in fileIds {
                        let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                        if indexKeysByFile[mediaId] == nil {
                            indexKeysByFile[mediaId] = [key]
                        } else {
                            indexKeysByFile[mediaId]!.append(key)
                        }
                    }
                    break
                }
            }
            
            for apiDocument in documents {
                if let file = telegramMediaFileFromApiDocument(apiDocument), let id = file.id {
                    let fileIndexKeys: [MemoryBuffer]
                    if let indexKeys = indexKeysByFile[id] {
                        fileIndexKeys = indexKeys
                    } else {
                        fileIndexKeys = []
                    }
                    items.append(StickerPackItem(index: ItemCollectionItemIndex(index: Int32(items.count), id: id.id), file: file, indexKeys: fileIndexKeys))
                }
            }
            break
        }
        return (updatedInfo, items)
    }
    |> `catch` { _ -> Signal<(StickerPackCollectionInfo, [ItemCollectionItem]), NoError> in
        return .single((info, []))
    }
}

private func resolveStickerPacks(network: Network, remoteInfos: [ItemCollectionId: (StickerPackCollectionInfo, Bool)], localInfos: [ItemCollectionId: StickerPackCollectionInfo]) -> Signal<[ItemCollectionId: [ItemCollectionItem]], NoError> {
    var signals: [Signal<(ItemCollectionId, [ItemCollectionItem]), NoError>] = []
    for (id, remoteInfoAndIsStale) in remoteInfos {
        let (remoteInfo, isStale) = remoteInfoAndIsStale
        let localInfo = localInfos[id]
        if localInfo == nil || localInfo!.hash != remoteInfo.hash || isStale {
            signals.append(fetchStickerPack(network: network, info: remoteInfo)
            |> map { (info, items) in
                return (info.id, items)
            })
        }
    }
    return combineLatest(signals)
        |> map { result -> [ItemCollectionId: [ItemCollectionItem]] in
            var dict: [ItemCollectionId: [ItemCollectionItem]] = [:]
            for (id, items) in result {
                dict[id] = items
            }
            return dict
        }
}

private func installRemoteStickerPacks(network: Network, infos: [StickerPackCollectionInfo]) -> Signal<Set<ItemCollectionId>, NoError> {
    var signals: [Signal<Set<ItemCollectionId>, NoError>] = []
    for info in infos {
        let install = network.request(Api.functions.messages.installStickerSet(stickerset: .inputStickerSetID(id: info.id.id, accessHash: info.accessHash), archived: .boolFalse))
            |> map { result -> Set<ItemCollectionId> in
                switch result {
                    case .stickerSetInstallResultSuccess:
                        return Set()
                    case let .stickerSetInstallResultArchive(archivedSets):
                        var archivedIds = Set<ItemCollectionId>()
                        for archivedSet in archivedSets {
                            switch archivedSet {
                                case let .stickerSetCovered(set, _):
                                    archivedIds.insert(StickerPackCollectionInfo(apiSet: set, namespace: info.id.namespace).id)
                                case let .stickerSetMultiCovered(set, _):
                                    archivedIds.insert(StickerPackCollectionInfo(apiSet: set, namespace: info.id.namespace).id)
                            }
                        }
                        return archivedIds
                }
            }
            |> `catch` { _ -> Signal<Set<ItemCollectionId>, NoError> in
                return .single(Set())
            }
        signals.append(install)
    }
    return combineLatest(signals)
        |> map { idsSets -> Set<ItemCollectionId> in
            var result = Set<ItemCollectionId>()
            for ids in idsSets {
                result.formUnion(ids)
            }
            return result
        }
}

private func removeRemoteStickerPacks(network: Network, infos: [StickerPackCollectionInfo]) -> Signal<Void, NoError> {
    if infos.count > 0 {
        if infos.count > 1 {
            return network.request(Api.functions.messages.toggleStickerSets(flags: 1 << 0, stickersets: infos.map { .inputStickerSetID(id: $0.id.id, accessHash: $0.accessHash) }))
            |> mapToSignal { _ -> Signal<Void, MTRpcError> in
                return .single(Void())
            }
            |> `catch` { _ -> Signal<Void, NoError> in
                return .single(Void())
            }
        } else if let info = infos.first {
            return network.request(Api.functions.messages.uninstallStickerSet(stickerset: .inputStickerSetID(id: info.id.id, accessHash: info.accessHash)))
            |> mapToSignal { _ -> Signal<Void, MTRpcError> in
                return .single(Void())
            }
            |> `catch` { _ -> Signal<Void, NoError> in
                return .single(Void())
            }
        }
    }
    return .single(Void())
}

private func archiveRemoteStickerPacks(network: Network, infos: [StickerPackCollectionInfo]) -> Signal<Void, NoError> {
    if infos.count > 0 {
        if infos.count > 1 {
            return network.request(Api.functions.messages.toggleStickerSets(flags: 1 << 1, stickersets: infos.map { .inputStickerSetID(id: $0.id.id, accessHash: $0.accessHash) }))
            |> mapToSignal { _ -> Signal<Void, MTRpcError> in
                return .single(Void())
            }
            |> `catch` { _ -> Signal<Void, NoError> in
                return .single(Void())
            }
        } else if let info = infos.first {
            return network.request(Api.functions.messages.installStickerSet(stickerset: .inputStickerSetID(id: info.id.id, accessHash: info.accessHash), archived: .boolTrue))
            |> mapToSignal { _ -> Signal<Void, MTRpcError> in
                return .single(Void())
            }
            |> `catch` { _ -> Signal<Void, NoError> in
                return .single(Void())
            }
        }
    }
    return .single(Void())
}

private func reorderRemoteStickerPacks(network: Network, namespace: SynchronizeInstalledStickerPacksOperationNamespace, ids: [ItemCollectionId]) -> Signal<Void, NoError> {
    var flags: Int32 = 0
    switch namespace {
        case .stickers:
            break
        case .masks:
            flags |= (1 << 0)
    }
    return network.request(Api.functions.messages.reorderStickerSets(flags: flags, order: ids.map { $0.id }))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
}

private func synchronizeInstalledStickerPacks(transaction: Transaction, postbox: Postbox, network: Network, stateManager: AccountStateManager, namespace: SynchronizeInstalledStickerPacksOperationNamespace, operation: SynchronizeInstalledStickerPacksOperation) -> Signal<Void, NoError> {
    let collectionNamespace: ItemCollectionId.Namespace
    switch namespace {
        case .stickers:
            collectionNamespace = Namespaces.ItemCollection.CloudStickerPacks
        case .masks:
            collectionNamespace = Namespaces.ItemCollection.CloudMaskPacks
    }
    
    let localCollectionInfos = transaction.getItemCollectionsInfos(namespace: collectionNamespace).map { $0.1 as! StickerPackCollectionInfo }
    let localStateCollectionOrder = localCollectionInfos.map({ $0.id })
    let localPreviousStateCollectionOrder = operation.previousPacks
    
    if localStateCollectionOrder == localPreviousStateCollectionOrder {
        return continueSynchronizeInstalledStickerPacks(
            transaction: transaction,
            postbox: postbox,
            network: network,
            stateManager: stateManager,
            namespace: namespace,
            operation: operation
        )
    }
    
    let locallyAddedInfos = localCollectionInfos.filter { !localPreviousStateCollectionOrder.contains($0.id) }
    
    if locallyAddedInfos.isEmpty {
        return continueSynchronizeInstalledStickerPacks(
            transaction: transaction,
            postbox: postbox,
            network: network,
            stateManager: stateManager,
            namespace: namespace,
            operation: operation
        )
    }
    
    var fetchSignals: [Signal<(StickerPackCollectionInfo, [ItemCollectionItem]), NoError>] = []
    for info in locallyAddedInfos {
        fetchSignals.append(fetchStickerPack(network: network, info: info)
        )
    }
    let fetchedPacks = combineLatest(fetchSignals)
    
    return fetchedPacks
    |> mapToSignal { fetchedPacks -> Signal<Void, NoError> in
        return postbox.transaction { transaction -> Signal<Void, NoError> in
            var currentInfos = transaction.getItemCollectionsInfos(namespace: collectionNamespace).map { $0.1 as! StickerPackCollectionInfo }
            for (info, items) in fetchedPacks {
                if let index = currentInfos.firstIndex(where: { $0.id == info.id }) {
                    currentInfos[index] = info
                    transaction.replaceItemCollectionItems(collectionId: info.id, items: items)
                }
            }
            transaction.replaceItemCollectionInfos(namespace: collectionNamespace, itemCollectionInfos: currentInfos.map { ($0.id, $0) })
            
            return continueSynchronizeInstalledStickerPacks(
                transaction: transaction,
                postbox: postbox,
                network: network,
                stateManager: stateManager,
                namespace: namespace,
                operation: operation
            )
        }
        |> switchToLatest
    }
}

private func continueSynchronizeInstalledStickerPacks(transaction: Transaction, postbox: Postbox, network: Network, stateManager: AccountStateManager, namespace: SynchronizeInstalledStickerPacksOperationNamespace, operation: SynchronizeInstalledStickerPacksOperation) -> Signal<Void, NoError> {
    let collectionNamespace: ItemCollectionId.Namespace
    switch namespace {
        case .stickers:
            collectionNamespace = Namespaces.ItemCollection.CloudStickerPacks
        case .masks:
            collectionNamespace = Namespaces.ItemCollection.CloudMaskPacks
    }
    
    let localCollectionInfos = transaction.getItemCollectionsInfos(namespace: collectionNamespace).map { $0.1 as! StickerPackCollectionInfo }
    let initialLocalHash = hashForStickerPackInfos(localCollectionInfos)
    
    let request: Signal<Api.messages.AllStickers, MTRpcError>
    switch namespace {
        case .stickers:
            request = network.request(Api.functions.messages.getAllStickers(hash: initialLocalHash))
        case .masks:
            request = network.request(Api.functions.messages.getMaskStickers(hash: initialLocalHash))
    }
    
    let sequence = request
    |> retryRequest
    |> mapError { _ -> SynchronizeInstalledStickerPacksError in
    }
    |> mapToSignal { result -> Signal<Void, SynchronizeInstalledStickerPacksError> in
        return postbox.transaction { transaction -> Signal<Void, SynchronizeInstalledStickerPacksError> in
            let checkLocalCollectionInfos = transaction.getItemCollectionsInfos(namespace: collectionNamespace).map { $0.1 as! StickerPackCollectionInfo }
            if checkLocalCollectionInfos != localCollectionInfos {
                return .fail(.restart)
            }
            
            let localInitialStateCollectionOrder = operation.previousPacks
            let localInitialStateCollectionIds = Set(localInitialStateCollectionOrder)
            
            let localCollectionOrder = checkLocalCollectionInfos.map { $0.id }
            let localCollectionIds = Set(localCollectionOrder)
            
            var remoteCollectionInfos: [StickerPackCollectionInfo] = []
            switch result {
                case let .allStickers(_, sets):
                    for apiSet in sets {
                        let info = StickerPackCollectionInfo(apiSet: apiSet, namespace: collectionNamespace)
                        remoteCollectionInfos.append(info)
                    }
                case .allStickersNotModified:
                    remoteCollectionInfos = checkLocalCollectionInfos
            }
            
            let remoteCollectionOrder = remoteCollectionInfos.map { $0.id }
            let remoteCollectionIds = Set(remoteCollectionOrder)
            
            var remoteInfos: [ItemCollectionId: StickerPackCollectionInfo] = [:]
            for info in remoteCollectionInfos {
                remoteInfos[info.id] = info
            }
            var localInfos: [ItemCollectionId: StickerPackCollectionInfo] = [:]
            for info in checkLocalCollectionInfos {
                localInfos[info.id] = info
            }
            
            if localInitialStateCollectionOrder == localCollectionOrder {
                if checkLocalCollectionInfos == remoteCollectionInfos {
                    return .fail(.done)
                } else {
                    var resolveRemoteInfos: [ItemCollectionId: (StickerPackCollectionInfo, Bool)] = [:]
                    for (id, info) in remoteInfos {
                        resolveRemoteInfos[id] = (info, false)
                    }
                    return resolveStickerPacks(network: network, remoteInfos: resolveRemoteInfos, localInfos: localInfos)
                    |> mapError { _ -> SynchronizeInstalledStickerPacksError in
                    }
                    |> mapToSignal { replaceItems -> Signal<Void, SynchronizeInstalledStickerPacksError> in
                        return postbox.transaction { transaction -> Signal<Void, SynchronizeInstalledStickerPacksError> in
                            let storeSignal: Signal<Void, NoError>
                            if localCollectionIds.isEmpty {
                                var incrementalSignal = postbox.transaction { transaction -> Void in
                                    transaction.replaceItemCollectionInfos(namespace: collectionNamespace, itemCollectionInfos: remoteCollectionInfos.map { ($0.id, $0) })
                                    for id in localCollectionIds.subtracting(remoteCollectionIds) {
                                        transaction.replaceItemCollectionItems(collectionId: id, items: [])
                                    }
                                }
                                for (id, items) in replaceItems {
                                    let partSignal = postbox.transaction { transaction -> Void in
                                        transaction.replaceItemCollectionItems(collectionId: id, items: items)
                                    }
                                    incrementalSignal = incrementalSignal
                                    |> then(
                                        partSignal
                                        |> delay(0.01, queue: Queue.concurrentDefaultQueue())
                                    )
                                }
                                storeSignal = incrementalSignal
                            } else {
                                storeSignal = postbox.transaction { transaction -> Void in
                                    transaction.replaceItemCollectionInfos(namespace: collectionNamespace, itemCollectionInfos: remoteCollectionInfos.map { ($0.id, $0) })
                                    for (id, items) in replaceItems {
                                        transaction.replaceItemCollectionItems(collectionId: id, items: items)
                                    }
                                    for id in localCollectionIds.subtracting(remoteCollectionIds) {
                                        transaction.replaceItemCollectionItems(collectionId: id, items: [])
                                    }
                                }
                            }
                            
                            return (
                                storeSignal
                                |> mapError { _ -> SynchronizeInstalledStickerPacksError in }
                            )
                            |> then(.fail(.done))
                        }
                        |> castError(SynchronizeInstalledStickerPacksError.self)
                        |> switchToLatest
                    }
                }
            } else {
                let locallyRemovedCollectionIds = localInitialStateCollectionIds.subtracting(localCollectionIds)
                let locallyAddedCollectionIds = localCollectionIds.subtracting(localInitialStateCollectionIds)
                let remotelyAddedCollections = remoteCollectionInfos.filter { info in
                    return !locallyRemovedCollectionIds.contains(info.id) && !localCollectionIds.contains(info.id)
                }
                let remotelyRemovedCollectionIds = remoteCollectionIds.subtracting(localInitialStateCollectionIds).subtracting(locallyAddedCollectionIds)
                
                var resultingCollectionInfos: [(StickerPackCollectionInfo, Bool)] = []
                resultingCollectionInfos.append(contentsOf: remotelyAddedCollections.map { ($0, false) })
                var remoteCollectionInfoMap: [ItemCollectionId: StickerPackCollectionInfo] = [:]
                for info in remoteCollectionInfos {
                    remoteCollectionInfoMap[info.id] = info
                }
                for info in checkLocalCollectionInfos {
                    if !remotelyRemovedCollectionIds.contains(info.id) {
                        if let remoteInfo = remoteCollectionInfoMap[info.id] {
                            resultingCollectionInfos.append((remoteInfo, false))
                        } else {
                            resultingCollectionInfos.append((info, true))
                        }
                    }
                }
                
                let resultingCollectionIds = Set(resultingCollectionInfos.map { $0.0.id })
                let removeRemoteCollectionIds = remoteCollectionIds.subtracting(resultingCollectionIds)
                let addRemoteCollectionIds = resultingCollectionIds.subtracting(remoteCollectionIds)
                
                var removeRemoteCollectionInfos: [StickerPackCollectionInfo] = []
                for id in removeRemoteCollectionIds {
                    if let info = remoteInfos[id] {
                        removeRemoteCollectionInfos.append(info)
                    } else if let info = localInfos[id] {
                        removeRemoteCollectionInfos.append(info)
                    }
                }
                
                var addRemoteCollectionInfos: [StickerPackCollectionInfo] = []
                for id in addRemoteCollectionIds {
                    if let info = remoteInfos[id] {
                        addRemoteCollectionInfos.append(info)
                    } else if let info = localInfos[id] {
                        addRemoteCollectionInfos.append(info)
                    }
                }
                
                let infosToArchive = removeRemoteCollectionInfos.filter { info in
                    return operation.archivedPacks.contains(info.id)
                }
                let infosToRemove = removeRemoteCollectionInfos.filter { info in
                    return !operation.archivedPacks.contains(info.id)
                }
                
                let archivedOrRemovedIds = (combineLatest(archiveRemoteStickerPacks(network: network, infos: infosToArchive), removeRemoteStickerPacks(network: network, infos: infosToRemove))
                |> mapToSignal { _ -> Signal<Void, NoError> in
                    return .complete()
                }
                |> then(Signal<Void, NoError>.single(Void())))
                |> mapToSignal { _ -> Signal<Set<ItemCollectionId>, NoError> in
                    return installRemoteStickerPacks(network: network, infos: addRemoteCollectionInfos)
                    |> mapToSignal { ids -> Signal<Set<ItemCollectionId>, NoError> in
                        return (reorderRemoteStickerPacks(network: network, namespace: namespace, ids: resultingCollectionInfos.map({ $0.0.id }).filter({ !ids.contains($0) }))
                        |> then(Signal<Void, NoError>.single(Void())))
                        |> map { _ -> Set<ItemCollectionId> in
                            return ids
                        }
                    }
                }
                
                var resultingInfos: [ItemCollectionId: (StickerPackCollectionInfo, Bool)] = [:]
                for info in resultingCollectionInfos {
                    resultingInfos[info.0.id] = info
                }
                
                let resolvedItems = resolveStickerPacks(network: network, remoteInfos: resultingInfos, localInfos: localInfos)
                
                return combineLatest(archivedOrRemovedIds, resolvedItems)
                |> mapError { _ -> SynchronizeInstalledStickerPacksError in }
                |> mapToSignal { archivedOrRemovedIds, replaceItems -> Signal<Void, SynchronizeInstalledStickerPacksError> in
                    return (postbox.transaction { transaction -> Signal<Void, SynchronizeInstalledStickerPacksError> in
                        let finalCheckLocalCollectionInfos = transaction.getItemCollectionsInfos(namespace: collectionNamespace).map { $0.1 as! StickerPackCollectionInfo }
                        if finalCheckLocalCollectionInfos != localCollectionInfos {
                            return .fail(.restart)
                        }
                        
                        transaction.replaceItemCollectionInfos(namespace: collectionNamespace, itemCollectionInfos: resultingCollectionInfos.filter({ info in
                            return !archivedOrRemovedIds.contains(info.0.id)
                        }).map({ ($0.0.id, $0.0) }))
                        for (id, items) in replaceItems {
                            if !archivedOrRemovedIds.contains(id) {
                                transaction.replaceItemCollectionItems(collectionId: id, items: items)
                            }
                        }
                        for id in localCollectionIds.subtracting(resultingCollectionIds).union(archivedOrRemovedIds) {
                            transaction.replaceItemCollectionItems(collectionId: id, items: [])
                        }
                        
                        return .complete()
                    }
                    |> mapError { _ -> SynchronizeInstalledStickerPacksError in
                    })
                    |> switchToLatest
                    |> then(.fail(.done))
                }
            }
        }
        |> mapError { _ -> SynchronizeInstalledStickerPacksError in
        }
        |> switchToLatest
    }
    
    return ((sequence
    |> `catch` { error -> Signal<Void, SynchronizeInstalledStickerPacksError> in
        switch error {
            case .done:
                return .fail(.done)
            case .restart:
                return .complete()
        }
    }) |> restart) |> `catch` { _ -> Signal<Void, NoError> in
        return .complete()
    }
}
