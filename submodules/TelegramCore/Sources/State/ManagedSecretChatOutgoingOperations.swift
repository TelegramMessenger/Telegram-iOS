import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit
import MtProtoKit


func addSecretChatOutgoingOperation(transaction: Transaction, peerId: PeerId, operation: SecretChatOutgoingOperationContents, state: SecretChatState) -> SecretChatState {
    var updatedState = state
    switch updatedState.embeddedState {
        case let .sequenceBasedLayer(sequenceState):
            let keyValidityOperationIndex = transaction.operationLogGetNextEntryLocalIndex(peerId: peerId, tag: OperationLogTags.SecretOutgoing)
            let keyValidityOperationCanonicalIndex = sequenceState.canonicalIncomingOperationIndex(keyValidityOperationIndex)
            if let key = state.keychain.latestKey(validForSequenceBasedCanonicalIndex: keyValidityOperationCanonicalIndex) {
                updatedState = updatedState.withUpdatedKeychain(updatedState.keychain.withUpdatedKey(fingerprint: key.fingerprint, { key in
                    return key?.withIncrementedUseCount()
                }))
            }
        default:
            break
    }
    transaction.operationLogAddEntry(peerId: peerId, tag: OperationLogTags.SecretOutgoing, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SecretChatOutgoingOperation(contents: operation, mutable: true, delivered: false))
    return secretChatInitiateRekeySessionIfNeeded(transaction: transaction, peerId: peerId, state: updatedState)
}

private final class ManagedSecretChatOutgoingOperationsHelper {
    var operationDisposables: [Int32: (PeerMergedOperationLogEntry, Disposable)] = [:]
    
    func update(_ entries: [PeerMergedOperationLogEntry]) -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)] = []
        
        var hasRunningOperationForPeerId = Set<PeerId>()
        var validMergedIndices = Set<Int32>()
        for entry in entries {
            if let entryAndDisposable = self.operationDisposables[entry.mergedIndex] {
                if let lhsOperation = entryAndDisposable.0.contents as? SecretChatOutgoingOperation, let rhsOperation = entry.contents as? SecretChatOutgoingOperation {
                    var lhsDelete = false
                    if case .deleteMessages = lhsOperation.contents {
                        lhsDelete = true
                    }
                    var rhsDelete = false
                    if case .deleteMessages = rhsOperation.contents {
                        rhsDelete = true
                    }
                    if lhsDelete != rhsDelete {
                        disposeOperations.append(entryAndDisposable.1)
                        self.operationDisposables.removeValue(forKey: entry.mergedIndex)
                    }
                }
            }
            
            if !hasRunningOperationForPeerId.contains(entry.peerId) {
                hasRunningOperationForPeerId.insert(entry.peerId)
                validMergedIndices.insert(entry.mergedIndex)
                
                if self.operationDisposables[entry.mergedIndex] == nil {
                    let disposable = MetaDisposable()
                    beginOperations.append((entry, disposable))
                    self.operationDisposables[entry.mergedIndex] = (entry, disposable)
                }
            }
        }
        
        var removeMergedIndices: [Int32] = []
        for (mergedIndex, entryAndDisposable) in self.operationDisposables {
            if !validMergedIndices.contains(mergedIndex) {
                removeMergedIndices.append(mergedIndex)
                disposeOperations.append(entryAndDisposable.1)
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
        return disposables.map { $0.1 }
    }
}

private func takenImmutableOperation(postbox: Postbox, peerId: PeerId, tagLocalIndex: Int32) -> Signal<PeerMergedOperationLogEntry?, NoError> {
    return postbox.transaction { transaction -> PeerMergedOperationLogEntry? in
        var result: PeerMergedOperationLogEntry?
        transaction.operationLogUpdateEntry(peerId: peerId, tag: OperationLogTags.SecretOutgoing, tagLocalIndex: tagLocalIndex, { entry in
            if let entry = entry, let _ = entry.mergedIndex, let operation = entry.contents as? SecretChatOutgoingOperation {
                if operation.mutable {
                    let updatedContents = SecretChatOutgoingOperation(contents: operation.contents, mutable: false, delivered: operation.delivered)
                    result = entry.withUpdatedContents(updatedContents).mergedEntry!
                    return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .update(updatedContents))
                } else {
                    result = entry.mergedEntry!
                }
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            } else {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            }
        })
        return result
    }
}

func managedSecretChatOutgoingOperations(auxiliaryMethods: AccountAuxiliaryMethods, postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic<ManagedSecretChatOutgoingOperationsHelper>(value: ManagedSecretChatOutgoingOperationsHelper())
        
        let disposable = postbox.mergedOperationLogView(tag: OperationLogTags.SecretOutgoing, limit: 10).start(next: { view in
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) in
                return helper.update(view.entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = takenImmutableOperation(postbox: postbox, peerId: entry.peerId, tagLocalIndex: entry.tagLocalIndex)
                |> mapToSignal { entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let operation = entry.contents as? SecretChatOutgoingOperation {
                            switch operation.contents {
                                case let .initialHandshakeAccept(gA, accessHash, b):
                                    return initialHandshakeAccept(postbox: postbox, network: network, peerId: entry.peerId, accessHash: accessHash, gA: gA, b: b, tagLocalIndex: entry.tagLocalIndex)
                                case let .sendMessage(layer, id, file):
                                    return sendMessage(auxiliaryMethods: auxiliaryMethods, postbox: postbox, network: network, messageId: id, file: file, tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered, layer: layer)
                                case let .reportLayerSupport(layer, actionGloballyUniqueId, layerSupport):
                                    return sendServiceActionMessage(postbox: postbox, network: network, peerId: entry.peerId, action: .reportLayerSupport(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, layerSupport: layerSupport), tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                case let .deleteMessages(layer, actionGloballyUniqueId, globallyUniqueIds):
                                    return sendServiceActionMessage(postbox: postbox, network: network, peerId: entry.peerId, action: .deleteMessages(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, globallyUniqueIds: globallyUniqueIds), tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                case let .clearHistory(layer, actionGloballyUniqueId):
                                    return sendServiceActionMessage(postbox: postbox, network: network, peerId: entry.peerId, action: .clearHistory(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId), tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                case let .pfsRequestKey(layer, actionGloballyUniqueId, rekeySessionId, a):
                                    return pfsRequestKey(postbox: postbox, network: network, peerId: entry.peerId, layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, rekeySessionId: rekeySessionId, a: a, tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                case let .pfsCommitKey(layer, actionGloballyUniqueId, rekeySessionId, keyFingerprint):
                                    return sendServiceActionMessage(postbox: postbox, network: network, peerId: entry.peerId, action: .pfsCommitKey(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, rekeySessionId: rekeySessionId, keyFingerprint: keyFingerprint), tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                case let .pfsAcceptKey(layer, actionGloballyUniqueId, rekeySessionId, gA, b):
                                    return pfsAcceptKey(postbox: postbox, network: network, peerId: entry.peerId, layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, rekeySessionId: rekeySessionId, gA: gA, b: b, tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                case let .pfsAbortSession(layer, actionGloballyUniqueId, rekeySessionId):
                                    return sendServiceActionMessage(postbox: postbox, network: network, peerId: entry.peerId, action: .pfsAbortSession(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, rekeySessionId: rekeySessionId), tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                case let .noop(layer, actionGloballyUniqueId):
                                    return sendServiceActionMessage(postbox: postbox, network: network, peerId: entry.peerId, action: .noop(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId), tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                case let .readMessagesContent(layer, actionGloballyUniqueId, globallyUniqueIds):
                                    return sendServiceActionMessage(postbox: postbox, network: network, peerId: entry.peerId, action: .readMessageContents(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, globallyUniqueIds: globallyUniqueIds), tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                case let .setMessageAutoremoveTimeout(layer, actionGloballyUniqueId, timeout, messageId):
                                    return sendServiceActionMessage(postbox: postbox, network: network, peerId: entry.peerId, action: .setMessageAutoremoveTimeout(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, timeout: timeout, messageId: messageId), tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                case let .resendOperations(layer, actionGloballyUniqueId, fromSeqNo, toSeqNo):
                                    return sendServiceActionMessage(postbox: postbox, network: network, peerId: entry.peerId, action: .resendOperations(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, fromSeqNo: fromSeqNo, toSeqNo: toSeqNo), tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                case let .screenshotMessages(layer, actionGloballyUniqueId, globallyUniqueIds, messageId):
                                    return sendServiceActionMessage(postbox: postbox, network: network, peerId: entry.peerId, action: .screenshotMessages(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, globallyUniqueIds: globallyUniqueIds, messageId: messageId), tagLocalIndex: entry.tagLocalIndex, wasDelivered: operation.delivered)
                                case let .terminate(reportSpam, requestRemoteHistoryRemoval):
                                    return requestTerminateSecretChat(postbox: postbox, network: network, peerId: entry.peerId, tagLocalIndex: entry.tagLocalIndex, reportSpam: reportSpam, requestRemoteHistoryRemoval: requestRemoteHistoryRemoval)
                            }
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                }
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

private func initialHandshakeAccept(postbox: Postbox, network: Network, peerId: PeerId, accessHash: Int64, gA: MemoryBuffer, b: MemoryBuffer, tagLocalIndex: Int32) -> Signal<Void, NoError> {
    return validatedEncryptionConfig(postbox: postbox, network: network)
    |> mapToSignal { config -> Signal<Void, NoError> in
        let p = config.p.makeData()
        
        if !MTCheckIsSafeGAOrB(network.encryptionProvider, gA.makeData(), p) {
            return postbox.transaction { transaction -> Void in
                let removed = transaction.operationLogRemoveEntry(peerId: peerId, tag: OperationLogTags.SecretOutgoing, tagLocalIndex: tagLocalIndex)
                assert(removed)
                if let state = transaction.getPeerChatState(peerId) as? SecretChatState {
                    var updatedState = state
                    updatedState = updatedState.withUpdatedEmbeddedState(.terminated)
                    transaction.setPeerChatState(peerId, state: updatedState)
                    if let peer = transaction.getPeer(peerId) as? TelegramSecretChat {
                        updatePeers(transaction: transaction, peers: [peer.withUpdatedEmbeddedState(updatedState.embeddedState.peerState)], update: { _, updated in
                            return updated
                        })
                    }
                } else {
                    assertionFailure()
                }
            }
        }
        
        var gValue: Int32 = config.g.byteSwapped
        let g = Data(bytes: &gValue, count: 4)
        
        let bData = b.makeData()
        
        let gb = MTExp(network.encryptionProvider, g, bData, p)!
        
        if !MTCheckIsSafeGAOrB(network.encryptionProvider, gb, p) {
            return .complete()
        }
        
        var key = MTExp(network.encryptionProvider, gA.makeData(), bData, p)!
        
        if key.count > 256 {
            key.count = 256
        } else  {
            while key.count < 256 {
                key.insert(0, at: 0)
            }
        }
        
        let keyHash = MTSha1(key)
        
        var keyFingerprint: Int64 = 0
        keyHash.withUnsafeBytes { rawBytes -> Void in
            let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
            memcpy(&keyFingerprint, bytes.advanced(by: keyHash.count - 8), 8)
        }
        
        let result = network.request(Api.functions.messages.acceptEncryption(peer: .inputEncryptedChat(chatId: Int32(peerId.id._internalGetInt64Value()), accessHash: accessHash), gB: Buffer(data: gb), keyFingerprint: keyFingerprint))
        
        let response = result
        |> map { result -> Api.EncryptedChat? in
            return result
        }
        |> `catch` { error -> Signal<Api.EncryptedChat?, NoError> in
            return .single(nil)
        }
        
        return response
        |> mapToSignal { result -> Signal<Void, NoError> in
            return postbox.transaction { transaction -> Void in
                let removed = transaction.operationLogRemoveEntry(peerId: peerId, tag: OperationLogTags.SecretOutgoing, tagLocalIndex: tagLocalIndex)
                assert(removed)
                if let state = transaction.getPeerChatState(peerId) as? SecretChatState {
                    var updatedState = state
                    updatedState = updatedState.withUpdatedKeychain(SecretChatKeychain(keys: [SecretChatKey(fingerprint: keyFingerprint, key: MemoryBuffer(data: key), validity: .indefinite, useCount: 0)]))
                    updatedState = updatedState.withUpdatedEmbeddedState(.sequenceBasedLayer(SecretChatSequenceBasedLayerState(layerNegotiationState: SecretChatLayerNegotiationState(activeLayer: .layer73, locallyRequestedLayer: nil, remotelyRequestedLayer: nil), rekeyState: nil, baseIncomingOperationIndex: transaction.operationLogGetNextEntryLocalIndex(peerId: peerId, tag: OperationLogTags.SecretIncomingDecrypted), baseOutgoingOperationIndex: transaction.operationLogGetNextEntryLocalIndex(peerId: peerId, tag: OperationLogTags.SecretOutgoing), topProcessedCanonicalIncomingOperationIndex: nil)))
                    updatedState = updatedState.withUpdatedKeyFingerprint(SecretChatKeyFingerprint(sha1: SecretChatKeySha1Fingerprint(digest: sha1Digest(key)), sha256: SecretChatKeySha256Fingerprint(digest: sha256Digest(key))))
                    
                    var layer: SecretChatLayer?
                    switch updatedState.embeddedState {
                        case .terminated, .handshake:
                            break
                        case .basicLayer:
                            layer = .layer8
                        case let .sequenceBasedLayer(sequenceState):
                            layer = sequenceState.layerNegotiationState.activeLayer.secretChatLayer
                    }
                    if let layer = layer {
                        updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: peerId, operation: .reportLayerSupport(layer: layer, actionGloballyUniqueId: Int64.random(in: Int64.min ... Int64.max), layerSupport: 46), state: updatedState)
                    }
                    transaction.setPeerChatState(peerId, state: updatedState)
                    if let peer = transaction.getPeer(peerId) as? TelegramSecretChat {
                        updatePeers(transaction: transaction, peers: [peer.withUpdatedEmbeddedState(updatedState.embeddedState.peerState)], update: { _, updated in
                            return updated
                        })
                    }
                } else {
                    assertionFailure()
                }
            }
        }
    }
}

private func pfsRequestKey(postbox: Postbox, network: Network, peerId: PeerId, layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64, a: MemoryBuffer, tagLocalIndex: Int32, wasDelivered: Bool) -> Signal<Void, NoError> {
    return validatedEncryptionConfig(postbox: postbox, network: network)
    |> mapToSignal { config -> Signal<Void, NoError> in
        var gValue: Int32 = config.g.byteSwapped
        let g = Data(bytes: &gValue, count: 4)
        let p = config.p.makeData()
        
        let aData = a.makeData()
        let ga = MTExp(network.encryptionProvider, g, aData, p)!
        
        if !MTCheckIsSafeGAOrB(network.encryptionProvider, ga, p) {
            return .complete()
        }
        
        return postbox.transaction { transaction -> Signal<Void, NoError> in
            if let state = transaction.getPeerChatState(peerId) as? SecretChatState {
                switch state.embeddedState {
                    case let .sequenceBasedLayer(sequenceState):
                        if let rekeyState = sequenceState.rekeyState, case .requesting = rekeyState.data {
                            transaction.setPeerChatState(peerId, state: state.withUpdatedEmbeddedState(.sequenceBasedLayer(sequenceState.withUpdatedRekeyState(SecretChatRekeySessionState(id: rekeyState.id, data: .requested(a: a, config: config))))))
                        }
                    default:
                        break
                }
            }
            return sendServiceActionMessage(postbox: postbox, network: network, peerId: peerId, action: .pfsRequestKey(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, rekeySessionId:rekeySessionId, gA: MemoryBuffer(data: ga)), tagLocalIndex: tagLocalIndex, wasDelivered: wasDelivered)
        }
        |> switchToLatest
    }
}

private func pfsAcceptKey(postbox: Postbox, network: Network, peerId: PeerId, layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64, gA: MemoryBuffer, b: MemoryBuffer, tagLocalIndex: Int32, wasDelivered: Bool) -> Signal<Void, NoError> {
    return validatedEncryptionConfig(postbox: postbox, network: network)
    |> mapToSignal { config -> Signal<Void, NoError> in
        var gValue: Int32 = config.g.byteSwapped
        let g = Data(bytes: &gValue, count: 4)
        let p = config.p.makeData()
        
        if !MTCheckIsSafeGAOrB(network.encryptionProvider, gA.makeData(), p) {
            return .complete()
        }
        
        let bData = b.makeData()
        
        let gb = MTExp(network.encryptionProvider, g, bData, p)!
        
        if !MTCheckIsSafeGAOrB(network.encryptionProvider, gb, p) {
            return .complete()
        }
        
        var key = MTExp(network.encryptionProvider, gA.makeData(), bData, p)!
        
        if key.count > 256 {
            key.count = 256
        } else  {
            while key.count < 256 {
                key.insert(0, at: 0)
            }
        }
        
        let keyHash = MTSha1(key)
        
        var keyFingerprint: Int64 = 0
        keyHash.withUnsafeBytes { rawBytes -> Void in
            let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
            memcpy(&keyFingerprint, bytes.advanced(by: keyHash.count - 8), 8)
        }
        
        return postbox.transaction { transaction -> Signal<Void, NoError> in
            if let state = transaction.getPeerChatState(peerId) as? SecretChatState {
                switch state.embeddedState {
                case let .sequenceBasedLayer(sequenceState):
                    if let rekeyState = sequenceState.rekeyState, case .accepting = rekeyState.data {
                        transaction.setPeerChatState(peerId, state: state.withUpdatedEmbeddedState(.sequenceBasedLayer(sequenceState.withUpdatedRekeyState(SecretChatRekeySessionState(id: rekeyState.id, data: .accepted(key: MemoryBuffer(data: key), keyFingerprint: keyFingerprint))))))
                    }
                default:
                    break
                }
            }
            return sendServiceActionMessage(postbox: postbox, network: network, peerId: peerId, action: .pfsAcceptKey(layer: layer, actionGloballyUniqueId: actionGloballyUniqueId, rekeySessionId:rekeySessionId, gB: MemoryBuffer(data: gb), keyFingerprint: keyFingerprint), tagLocalIndex: tagLocalIndex, wasDelivered: wasDelivered)
        }
        |> switchToLatest
    }
}

private enum BoxedDecryptedMessage {
    case layer8(SecretApi8.DecryptedMessage)
    case layer46(SecretApi46.DecryptedMessage)
    case layer73(SecretApi73.DecryptedMessage)
    case layer101(SecretApi101.DecryptedMessage)
    
    func serialize(_ buffer: Buffer, role: SecretChatRole, sequenceInfo: SecretChatOperationSequenceInfo?) {
        switch self {
            case let .layer8(message):
                let _ = message.serialize(buffer, true)
            case let .layer46(message):
                buffer.appendInt32(0x1be31789)
                let randomBytes = malloc(15)!
                arc4random_buf(randomBytes, 15)
                serializeBytes(Buffer(memory: randomBytes, size: 15, capacity: 15, freeWhenDone: false), buffer: buffer, boxed: false)
                free(randomBytes)
                buffer.appendInt32(46)
                
                if let sequenceInfo = sequenceInfo {
                    let inSeqNo = (sequenceInfo.topReceivedOperationIndex + 1) * 2 + (role == .creator ? 0 : 1)
                    let outSeqNo = sequenceInfo.operationIndex * 2 + (role == .creator ? 1 : 0)
                    buffer.appendInt32(inSeqNo)
                    buffer.appendInt32(outSeqNo)
                } else {
                    buffer.appendInt32(0)
                    buffer.appendInt32(0)
                    assertionFailure()
                }
                
                let _ = message.serialize(buffer, true)
            case let .layer73(message):
                buffer.appendInt32(0x1be31789)
                let randomBytes = malloc(15)!
                arc4random_buf(randomBytes, 15)
                serializeBytes(Buffer(memory: randomBytes, size: 15, capacity: 15, freeWhenDone: false), buffer: buffer, boxed: false)
                free(randomBytes)
                buffer.appendInt32(73)
                
                if let sequenceInfo = sequenceInfo {
                    let inSeqNo = (sequenceInfo.topReceivedOperationIndex + 1) * 2 + (role == .creator ? 0 : 1)
                    let outSeqNo = sequenceInfo.operationIndex * 2 + (role == .creator ? 1 : 0)
                    buffer.appendInt32(inSeqNo)
                    buffer.appendInt32(outSeqNo)
                } else {
                    buffer.appendInt32(0)
                    buffer.appendInt32(0)
                    assertionFailure()
                }
                
                let _ = message.serialize(buffer, true)
            case let .layer101(message):
                buffer.appendInt32(0x1be31789)
                let randomBytes = malloc(15)!
                arc4random_buf(randomBytes, 15)
                serializeBytes(Buffer(memory: randomBytes, size: 15, capacity: 15, freeWhenDone: false), buffer: buffer, boxed: false)
                free(randomBytes)
                buffer.appendInt32(101)
                
                if let sequenceInfo = sequenceInfo {
                    let inSeqNo = (sequenceInfo.topReceivedOperationIndex + 1) * 2 + (role == .creator ? 0 : 1)
                    let outSeqNo = sequenceInfo.operationIndex * 2 + (role == .creator ? 1 : 0)
                    buffer.appendInt32(inSeqNo)
                    buffer.appendInt32(outSeqNo)
                } else {
                    buffer.appendInt32(0)
                    buffer.appendInt32(0)
                    assertionFailure()
                }
                
                let _ = message.serialize(buffer, true)
        }
    }
}

private enum SecretMessageAction {
    case deleteMessages(layer: SecretChatLayer, actionGloballyUniqueId: Int64, globallyUniqueIds: [Int64])
    case screenshotMessages(layer: SecretChatLayer, actionGloballyUniqueId: Int64, globallyUniqueIds: [Int64], messageId: MessageId)
    case clearHistory(layer: SecretChatLayer, actionGloballyUniqueId: Int64)
    case resendOperations(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, fromSeqNo: Int32, toSeqNo: Int32)
    case reportLayerSupport(layer: SecretChatLayer, actionGloballyUniqueId: Int64, layerSupport: Int32)
    case pfsRequestKey(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64, gA: MemoryBuffer)
    case pfsAcceptKey(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64, gB: MemoryBuffer, keyFingerprint: Int64)
    case pfsAbortSession(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64)
    case pfsCommitKey(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64, rekeySessionId: Int64, keyFingerprint: Int64)
    case noop(layer: SecretChatSequenceBasedLayer, actionGloballyUniqueId: Int64)
    case readMessageContents(layer: SecretChatLayer, actionGloballyUniqueId: Int64, globallyUniqueIds: [Int64])
    case setMessageAutoremoveTimeout(layer: SecretChatLayer, actionGloballyUniqueId: Int64, timeout: Int32, messageId: MessageId)
    
    var globallyUniqueId: Int64 {
        switch self {
            case let .deleteMessages(_, actionGloballyUniqueId, _):
                return actionGloballyUniqueId
            case let .screenshotMessages(_, actionGloballyUniqueId, _, _):
                return actionGloballyUniqueId
            case let .clearHistory(_, actionGloballyUniqueId):
                return actionGloballyUniqueId
            case let .resendOperations(_, actionGloballyUniqueId, _, _):
                return actionGloballyUniqueId
            case let .reportLayerSupport(_, actionGloballyUniqueId, _):
                return actionGloballyUniqueId
            case let .pfsRequestKey(_, actionGloballyUniqueId, _, _):
                return actionGloballyUniqueId
            case let .pfsAcceptKey(_, actionGloballyUniqueId, _, _, _):
                return actionGloballyUniqueId
            case let .pfsAbortSession(_, actionGloballyUniqueId, _):
                return actionGloballyUniqueId
            case let .pfsCommitKey(_, actionGloballyUniqueId, _, _):
                return actionGloballyUniqueId
            case let .noop(_, actionGloballyUniqueId):
                return actionGloballyUniqueId
            case let .readMessageContents(_, actionGloballyUniqueId, _):
                return actionGloballyUniqueId
            case let .setMessageAutoremoveTimeout(_, actionGloballyUniqueId, _, _):
                return actionGloballyUniqueId
        }
    }
    
    var messageId: MessageId? {
        switch self {
            case let .setMessageAutoremoveTimeout(_, _, _, messageId):
                return messageId
            case let .screenshotMessages(_, _, _, messageId):
                return messageId
            default:
                return nil
        }
    }
}

private func decryptedAttributes46(_ attributes: [TelegramMediaFileAttribute], transaction: Transaction) -> [SecretApi46.DocumentAttribute] {
    var result: [SecretApi46.DocumentAttribute] = []
    for attribute in attributes {
        switch attribute {
            case let .FileName(fileName):
                result.append(.documentAttributeFilename(fileName: fileName))
            case .Animated:
                result.append(.documentAttributeAnimated)
            case let .Sticker(displayText, packReference, _):
                var stickerSet: SecretApi46.InputStickerSet = .inputStickerSetEmpty
                if let packReference = packReference {
                    switch packReference {
                        case let .name(name):
                            stickerSet = .inputStickerSetShortName(shortName: name)
                        case .id:
                            if let (info, _, _) = cachedStickerPack(transaction: transaction, reference: packReference) {
                                stickerSet = .inputStickerSetShortName(shortName: info.shortName)
                            }
                        default:
                            stickerSet = .inputStickerSetEmpty
                    }
                }
                result.append(.documentAttributeSticker(alt: displayText, stickerset: stickerSet))
            case let .ImageSize(size):
                result.append(.documentAttributeImageSize(w: Int32(size.width), h: Int32(size.height)))
            case let .Video(duration, size, _):
                result.append(.documentAttributeVideo(duration: Int32(duration), w: Int32(size.width), h: Int32(size.height)))
            case let .Audio(isVoice, duration, title, performer, waveform):
                var flags: Int32 = 0
                if isVoice {
                    flags |= (1 << 10)
                }
                if let _ = title {
                    flags |= Int32(1 << 0)
                }
                if let _ = performer {
                    flags |= Int32(1 << 1)
                }
                var waveformBuffer: Buffer?
                if let waveform = waveform {
                    flags |= Int32(1 << 2)
                    waveformBuffer = Buffer(data: waveform)
                }
                result.append(.documentAttributeAudio(flags: flags, duration: Int32(duration), title: title, performer: performer, waveform: waveformBuffer))
            case .HasLinkedStickers:
                break
            case .hintFileIsLarge:
                break
            case .hintIsValidated:
                break
        }
    }
    return result
}

private func decryptedAttributes73(_ attributes: [TelegramMediaFileAttribute], transaction: Transaction) -> [SecretApi73.DocumentAttribute] {
    var result: [SecretApi73.DocumentAttribute] = []
    for attribute in attributes {
        switch attribute {
            case let .FileName(fileName):
                result.append(.documentAttributeFilename(fileName: fileName))
            case .Animated:
                result.append(.documentAttributeAnimated)
            case let .Sticker(displayText, packReference, _):
                var stickerSet: SecretApi73.InputStickerSet = .inputStickerSetEmpty
                if let packReference = packReference {
                    switch packReference {
                        case let .name(name):
                            stickerSet = .inputStickerSetShortName(shortName: name)
                        case .id:
                            if let (info, _, _) = cachedStickerPack(transaction: transaction, reference: packReference) {
                                stickerSet = .inputStickerSetShortName(shortName: info.shortName)
                            }
                        default:
                            stickerSet = .inputStickerSetEmpty
                    }
                }
                result.append(.documentAttributeSticker(alt: displayText, stickerset: stickerSet))
            case let .ImageSize(size):
                result.append(.documentAttributeImageSize(w: Int32(size.width), h: Int32(size.height)))
            case let .Video(duration, size, videoFlags):
                var flags: Int32 = 0
                if videoFlags.contains(.instantRoundVideo) {
                    flags |= 1 << 0
                }
                result.append(.documentAttributeVideo(flags: flags, duration: Int32(duration), w: Int32(size.width), h: Int32(size.height)))
            case let .Audio(isVoice, duration, title, performer, waveform):
                var flags: Int32 = 0
                if isVoice {
                    flags |= (1 << 10)
                }
                if let _ = title {
                    flags |= Int32(1 << 0)
                }
                if let _ = performer {
                    flags |= Int32(1 << 1)
                }
                var waveformBuffer: Buffer?
                if let waveform = waveform {
                    flags |= Int32(1 << 2)
                    waveformBuffer = Buffer(data: waveform)
                }
                result.append(.documentAttributeAudio(flags: flags, duration: Int32(duration), title: title, performer: performer, waveform: waveformBuffer))
            case .HasLinkedStickers:
                break
            case .hintFileIsLarge:
                break
            case .hintIsValidated:
                break
        }
    }
    return result
}

private func decryptedAttributes101(_ attributes: [TelegramMediaFileAttribute], transaction: Transaction) -> [SecretApi101.DocumentAttribute] {
    var result: [SecretApi101.DocumentAttribute] = []
    for attribute in attributes {
        switch attribute {
            case let .FileName(fileName):
                result.append(.documentAttributeFilename(fileName: fileName))
            case .Animated:
                result.append(.documentAttributeAnimated)
            case let .Sticker(displayText, packReference, _):
                var stickerSet: SecretApi101.InputStickerSet = .inputStickerSetEmpty
                if let packReference = packReference {
                    switch packReference {
                        case let .name(name):
                            stickerSet = .inputStickerSetShortName(shortName: name)
                        case .id:
                            if let (info, _, _) = cachedStickerPack(transaction: transaction, reference: packReference) {
                                stickerSet = .inputStickerSetShortName(shortName: info.shortName)
                            }
                        default:
                            stickerSet = .inputStickerSetEmpty
                    }
                }
                result.append(.documentAttributeSticker(alt: displayText, stickerset: stickerSet))
            case let .ImageSize(size):
                result.append(.documentAttributeImageSize(w: Int32(size.width), h: Int32(size.height)))
            case let .Video(duration, size, videoFlags):
                var flags: Int32 = 0
                if videoFlags.contains(.instantRoundVideo) {
                    flags |= 1 << 0
                }
                result.append(.documentAttributeVideo(flags: flags, duration: Int32(duration), w: Int32(size.width), h: Int32(size.height)))
            case let .Audio(isVoice, duration, title, performer, waveform):
                var flags: Int32 = 0
                if isVoice {
                    flags |= (1 << 10)
                }
                if let _ = title {
                    flags |= Int32(1 << 0)
                }
                if let _ = performer {
                    flags |= Int32(1 << 1)
                }
                var waveformBuffer: Buffer?
                if let waveform = waveform {
                    flags |= Int32(1 << 2)
                    waveformBuffer = Buffer(data: waveform)
                }
                result.append(.documentAttributeAudio(flags: flags, duration: Int32(duration), title: title, performer: performer, waveform: waveformBuffer))
            case .HasLinkedStickers:
                break
            case .hintFileIsLarge:
                break
            case .hintIsValidated:
                break
        }
    }
    return result
}

private func decryptedEntities73(_ entities: [MessageTextEntity]?) -> [SecretApi73.MessageEntity]? {
    guard let entities = entities else {
        return nil
    }
    
    var result: [SecretApi73.MessageEntity] = []
    for entity in entities {
        switch entity.type {
            case .Unknown:
                break
            case .Mention:
                result.append(.messageEntityMention(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .Hashtag:
                result.append(.messageEntityHashtag(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .BotCommand:
                result.append(.messageEntityBotCommand(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .Url:
                result.append(.messageEntityUrl(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .Email:
                result.append(.messageEntityEmail(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .Bold:
                result.append(.messageEntityBold(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .Italic:
                result.append(.messageEntityItalic(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .Code:
                result.append(.messageEntityCode(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .Pre:
                result.append(.messageEntityPre(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count), language: ""))
            case let .TextUrl(url):
                result.append(.messageEntityTextUrl(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count), url: url))
            case .TextMention:
                break
            case .PhoneNumber:
                break
            case .Strikethrough:
                break
            case .BlockQuote:
                break
            case .Underline:
                break
            case .BankCard:
                break
            case .Spoiler:
                break
            case .Custom:
                break
        }
    }
    return result
}

private func decryptedEntities101(_ entities: [MessageTextEntity]?) -> [SecretApi101.MessageEntity]? {
    guard let entities = entities else {
        return nil
    }
    
    var result: [SecretApi101.MessageEntity] = []
    for entity in entities {
        switch entity.type {
            case .Unknown:
                break
            case .Mention:
                result.append(.messageEntityMention(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .Hashtag:
                result.append(.messageEntityHashtag(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .BotCommand:
                result.append(.messageEntityBotCommand(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .Url:
                result.append(.messageEntityUrl(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .Email:
                result.append(.messageEntityEmail(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .Bold:
                result.append(.messageEntityBold(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .Italic:
                result.append(.messageEntityItalic(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .Code:
                result.append(.messageEntityCode(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .Pre:
                result.append(.messageEntityPre(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count), language: ""))
            case let .TextUrl(url):
                result.append(.messageEntityTextUrl(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count), url: url))
            case .TextMention:
                break
            case .PhoneNumber:
                break
            case .Strikethrough:
                result.append(.messageEntityStrike(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .BlockQuote:
                result.append(.messageEntityBlockquote(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .Underline:
                result.append(.messageEntityUnderline(offset: Int32(entity.range.lowerBound), length: Int32(entity.range.count)))
            case .BankCard:
                break
            case .Spoiler:
                break
            case .Custom:
                break
        }
    }
    return result
}

private func boxedDecryptedMessage(transaction: Transaction, message: Message, globallyUniqueId: Int64, uploadedFile: SecretChatOutgoingFile?, thumbnailData: [MediaId: (PixelDimensions, Data)], layer: SecretChatLayer) -> BoxedDecryptedMessage {
    let media: Media? = message.media.first
    var messageAutoremoveTimeout: Int32 = 0
    var replyGlobalId: Int64? = nil
    var flags: Int32 = 0
    for attribute in message.attributes {
        if let attribute = attribute as? ReplyMessageAttribute {
            if let message = message.associatedMessages[attribute.messageId] {
                replyGlobalId = message.globallyUniqueId
                flags |= (1 << 3)
                break
            }
        }
    }
    
    var viaBotName: String?
    var entities: [MessageTextEntity]?
    var muted: Bool = false
    
    for attribute in message.attributes {
        if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
            messageAutoremoveTimeout = attribute.timeout
        } else if let attribute = attribute as? InlineBotMessageAttribute {
            if let title = attribute.title {
                viaBotName = title
            } else if let peerId = attribute.peerId, let peer = transaction.getPeer(peerId), let addressName = peer.addressName {
                viaBotName = addressName
            }
        } else if let attribute = attribute as? TextEntitiesMessageAttribute {
            entities = attribute.entities
        } else if let attribute = attribute as? NotificationInfoMessageAttribute {
            if attribute.flags.contains(.muted) {
                muted = true
            }
        }
    }
    
    if let media = media {
        if let image = media as? TelegramMediaImage, let uploadedFile = uploadedFile, let largestRepresentation = largestImageRepresentation(image.representations) {
            let thumbW: Int32
            let thumbH: Int32
            let thumb: Buffer
            if let (thumbnailSize, data) = thumbnailData[image.imageId] {
                thumbW = thumbnailSize.width
                thumbH = thumbnailSize.height
                thumb = Buffer(data: data)
            } else {
                thumbW = 90
                thumbH = 90
                thumb = Buffer()
            }
            
            switch layer {
                case .layer8:
                    let randomBytesData = malloc(15)!
                    arc4random_buf(randomBytesData, 15)
                    let randomBytes = Buffer(memory: randomBytesData, size: 15, capacity: 15, freeWhenDone: true)
                    
                    let decryptedMedia = SecretApi8.DecryptedMessageMedia.decryptedMessageMediaPhoto(thumb: thumb, thumbW: thumbW, thumbH: thumbH, w: Int32(largestRepresentation.dimensions.width), h: Int32(largestRepresentation.dimensions.height), size: uploadedFile.size, key: Buffer(data: uploadedFile.key.aesKey), iv: Buffer(data: uploadedFile.key.aesIv))
                    
                    return .layer8(.decryptedMessage(randomId: globallyUniqueId, randomBytes: randomBytes, message: message.text, media: decryptedMedia))
                case .layer46:
                    if muted {
                        flags |= (1 << 5)
                    }
                    if let _ = viaBotName {
                        flags |= (1 << 11)
                    }
                    let decryptedMedia = SecretApi46.DecryptedMessageMedia.decryptedMessageMediaPhoto(thumb: thumb, thumbW: thumbW, thumbH: thumbH, w: Int32(largestRepresentation.dimensions.width), h: Int32(largestRepresentation.dimensions.height), size: uploadedFile.size, key: Buffer(data: uploadedFile.key.aesKey), iv: Buffer(data: uploadedFile.key.aesIv), caption: "")
                    flags |= (1 << 9)
                    return .layer46(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: decryptedMedia, entities: nil, viaBotName: viaBotName, replyToRandomId: replyGlobalId))
                case .layer73:
                    if muted {
                        flags |= (1 << 5)
                    }
                    if let _ = viaBotName {
                        flags |= (1 << 11)
                    }
                    let decryptedEntites = entities.flatMap(decryptedEntities73)
                    if let _ = decryptedEntites {
                        flags |= (1 << 7)
                    }
                    let decryptedMedia = SecretApi73.DecryptedMessageMedia.decryptedMessageMediaPhoto(thumb: thumb, thumbW: thumbW, thumbH: thumbH, w: Int32(largestRepresentation.dimensions.width), h: Int32(largestRepresentation.dimensions.height), size: uploadedFile.size, key: Buffer(data: uploadedFile.key.aesKey), iv: Buffer(data: uploadedFile.key.aesIv), caption: "")
                    flags |= (1 << 9)
                    if message.groupingKey != nil {
                        flags |= (1 << 17)
                    }
                    return .layer73(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: decryptedMedia, entities: decryptedEntites, viaBotName: viaBotName, replyToRandomId: replyGlobalId, groupedId: message.groupingKey))
                case .layer101:
                    if muted {
                        flags |= (1 << 5)
                    }
                    if let _ = viaBotName {
                        flags |= (1 << 11)
                    }
                    let decryptedEntites = entities.flatMap(decryptedEntities101)
                    if let _ = decryptedEntites {
                        flags |= (1 << 7)
                    }
                    let decryptedMedia = SecretApi101.DecryptedMessageMedia.decryptedMessageMediaPhoto(thumb: thumb, thumbW: thumbW, thumbH: thumbH, w: Int32(largestRepresentation.dimensions.width), h: Int32(largestRepresentation.dimensions.height), size: uploadedFile.size, key: Buffer(data: uploadedFile.key.aesKey), iv: Buffer(data: uploadedFile.key.aesIv), caption: "")
                    flags |= (1 << 9)
                    if message.groupingKey != nil {
                        flags |= (1 << 17)
                    }
                    return .layer101(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: decryptedMedia, entities: decryptedEntites, viaBotName: viaBotName, replyToRandomId: replyGlobalId, groupedId: message.groupingKey))
            }
        } else if let file = media as? TelegramMediaFile {
            let thumbW: Int32
            let thumbH: Int32
            let thumb: Buffer
            if let (thumbnailSize, data) = thumbnailData[file.fileId] {
                thumbW = thumbnailSize.width
                thumbH = thumbnailSize.height
                thumb = Buffer(data: data)
            } else {
                thumbW = 0
                thumbH = 0
                thumb = Buffer()
            }
            
            switch layer {
                case .layer8:
                    if let uploadedFile = uploadedFile {
                        let randomBytesData = malloc(15)!
                        arc4random_buf(randomBytesData, 15)
                        let randomBytes = Buffer(memory: randomBytesData, size: 15, capacity: 15, freeWhenDone: true)
                        
                        let decryptedMedia = SecretApi8.DecryptedMessageMedia.decryptedMessageMediaDocument(thumb: thumb, thumbW: thumbW, thumbH: thumbH, fileName: file.fileName ?? "file", mimeType: file.mimeType, size: uploadedFile.size, key: Buffer(data: uploadedFile.key.aesKey), iv: Buffer(data: uploadedFile.key.aesIv))
                    
                        return .layer8(.decryptedMessage(randomId: globallyUniqueId, randomBytes: randomBytes, message: message.text, media: decryptedMedia))
                    }
                case .layer46:
                    var decryptedMedia: SecretApi46.DecryptedMessageMedia?
                    
                    if let uploadedFile = uploadedFile {
                        var voiceDuration: Int32?
                        for attribute in file.attributes {
                            if case let .Audio(isVoice, duration, _, _, _) = attribute {
                                if isVoice {
                                    voiceDuration = Int32(duration)
                                }
                                break
                            }
                        }
                        
                        if let voiceDuration = voiceDuration {
                            decryptedMedia = SecretApi46.DecryptedMessageMedia.decryptedMessageMediaAudio(duration: voiceDuration, mimeType: file.mimeType, size: uploadedFile.size, key: Buffer(data: uploadedFile.key.aesKey), iv: Buffer(data: uploadedFile.key.aesIv))
                        } else {
                            decryptedMedia = SecretApi46.DecryptedMessageMedia.decryptedMessageMediaDocument(thumb: thumb, thumbW: thumbW, thumbH: thumbH, mimeType: file.mimeType, size: uploadedFile.size, key: Buffer(data: uploadedFile.key.aesKey), iv: Buffer(data: uploadedFile.key.aesIv), attributes: decryptedAttributes46(file.attributes, transaction: transaction), caption: "")
                        }
                    } else {
                        if let resource = file.resource as? CloudDocumentMediaResource, let size = file.size {
                            let thumb: SecretApi46.PhotoSize
                            if let smallestRepresentation = smallestImageRepresentation(file.previewRepresentations), let thumbResource = smallestRepresentation.resource as? CloudFileMediaResource {
                                thumb = .photoSize(type: "s", location: .fileLocation(dcId: Int32(thumbResource.datacenterId), volumeId: thumbResource.volumeId, localId: thumbResource.localId, secret: thumbResource.secret), w: Int32(smallestRepresentation.dimensions.width), h: Int32(smallestRepresentation.dimensions.height), size: thumbResource.size.flatMap(Int32.init) ?? 0)
                            } else {
                                thumb = SecretApi46.PhotoSize.photoSizeEmpty(type: "s")
                            }
                            decryptedMedia = SecretApi46.DecryptedMessageMedia.decryptedMessageMediaExternalDocument(id: resource.fileId, accessHash: resource.accessHash, date: 0, mimeType: file.mimeType, size: Int32(size), thumb: thumb, dcId: Int32(resource.datacenterId), attributes: decryptedAttributes46(file.attributes, transaction: transaction))
                        }
                    }
                    
                    if let decryptedMedia = decryptedMedia {
                        if muted {
                            flags |= (1 << 5)
                        }
                        if let _ = viaBotName {
                            flags |= (1 << 11)
                        }
                        flags |= (1 << 9)
                        return .layer46(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: decryptedMedia, entities: nil, viaBotName: viaBotName, replyToRandomId: replyGlobalId))
                    }
                case .layer73:
                    var decryptedMedia: SecretApi73.DecryptedMessageMedia?
                    
                    if let uploadedFile = uploadedFile {
                        decryptedMedia = SecretApi73.DecryptedMessageMedia.decryptedMessageMediaDocument(thumb: thumb, thumbW: thumbW, thumbH: thumbH, mimeType: file.mimeType, size: uploadedFile.size, key: Buffer(data: uploadedFile.key.aesKey), iv: Buffer(data: uploadedFile.key.aesIv), attributes: decryptedAttributes73(file.attributes, transaction: transaction), caption: "")
                    } else {
                        if let resource = file.resource as? CloudDocumentMediaResource, let size = file.size {
                            let thumb: SecretApi73.PhotoSize
                            if let smallestRepresentation = smallestImageRepresentation(file.previewRepresentations), let thumbResource = smallestRepresentation.resource as? CloudFileMediaResource {
                                thumb = .photoSize(type: "s", location: .fileLocation(dcId: Int32(thumbResource.datacenterId), volumeId: thumbResource.volumeId, localId: thumbResource.localId, secret: thumbResource.secret), w: Int32(smallestRepresentation.dimensions.width), h: Int32(smallestRepresentation.dimensions.height), size: thumbResource.size.flatMap(Int32.init) ?? 0)
                            } else {
                                thumb = SecretApi73.PhotoSize.photoSizeEmpty(type: "s")
                            }
                            decryptedMedia = SecretApi73.DecryptedMessageMedia.decryptedMessageMediaExternalDocument(id: resource.fileId, accessHash: resource.accessHash, date: 0, mimeType: file.mimeType, size: Int32(size), thumb: thumb, dcId: Int32(resource.datacenterId), attributes: decryptedAttributes73(file.attributes, transaction: transaction))
                        }
                    }
                    
                    if let decryptedMedia = decryptedMedia {
                        if muted {
                            flags |= (1 << 5)
                        }
                        if let _ = viaBotName {
                            flags |= (1 << 11)
                        }
                        let decryptedEntites = entities.flatMap(decryptedEntities73)
                        if let _ = decryptedEntites {
                            flags |= (1 << 7)
                        }
                        if message.groupingKey != nil {
                            flags |= (1 << 17)
                        }
                        flags |= (1 << 9)
                        return .layer73(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: decryptedMedia, entities: decryptedEntites, viaBotName: viaBotName, replyToRandomId: replyGlobalId, groupedId: message.groupingKey))
                    }
            case .layer101:
                var decryptedMedia: SecretApi101.DecryptedMessageMedia?
                
                if let uploadedFile = uploadedFile {
                    decryptedMedia = SecretApi101.DecryptedMessageMedia.decryptedMessageMediaDocument(thumb: thumb, thumbW: thumbW, thumbH: thumbH, mimeType: file.mimeType, size: uploadedFile.size, key: Buffer(data: uploadedFile.key.aesKey), iv: Buffer(data: uploadedFile.key.aesIv), attributes: decryptedAttributes101(file.attributes, transaction: transaction), caption: "")
                } else {
                    if let resource = file.resource as? CloudDocumentMediaResource, let size = file.size {
                        let thumb: SecretApi101.PhotoSize
                        if let smallestRepresentation = smallestImageRepresentation(file.previewRepresentations), let thumbResource = smallestRepresentation.resource as? CloudFileMediaResource {
                            thumb = .photoSize(type: "s", location: .fileLocation(dcId: Int32(thumbResource.datacenterId), volumeId: thumbResource.volumeId, localId: thumbResource.localId, secret: thumbResource.secret), w: Int32(smallestRepresentation.dimensions.width), h: Int32(smallestRepresentation.dimensions.height), size: thumbResource.size.flatMap(Int32.init) ?? 0)
                        } else {
                            thumb = SecretApi101.PhotoSize.photoSizeEmpty(type: "s")
                        }
                        decryptedMedia = SecretApi101.DecryptedMessageMedia.decryptedMessageMediaExternalDocument(id: resource.fileId, accessHash: resource.accessHash, date: 0, mimeType: file.mimeType, size: Int32(size), thumb: thumb, dcId: Int32(resource.datacenterId), attributes: decryptedAttributes101(file.attributes, transaction: transaction))
                    }
                }
                
                if let decryptedMedia = decryptedMedia {
                    if muted {
                        flags |= (1 << 5)
                    }
                    if let _ = viaBotName {
                        flags |= (1 << 11)
                    }
                    let decryptedEntites = entities.flatMap(decryptedEntities101)
                    if let _ = decryptedEntites {
                        flags |= (1 << 7)
                    }
                    if message.groupingKey != nil {
                        flags |= (1 << 17)
                    }
                    flags |= (1 << 9)
                    return .layer101(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: decryptedMedia, entities: decryptedEntites, viaBotName: viaBotName, replyToRandomId: replyGlobalId, groupedId: message.groupingKey))
                }
            }
        } else if let webpage = media as? TelegramMediaWebpage {
            var url: String?
            if case let .Loaded(content) = webpage.content {
                url = content.url
            }
            
            if let url = url, !url.isEmpty {
                switch layer {
                    case .layer8:
                        break
                    case .layer46:
                        if muted {
                            flags |= (1 << 5)
                        }
                        if let _ = viaBotName {
                            flags |= (1 << 11)
                        }
                        let decryptedMedia = SecretApi46.DecryptedMessageMedia.decryptedMessageMediaWebPage(url: url)
                        flags |= (1 << 9)
                        return .layer46(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: decryptedMedia, entities: nil, viaBotName: viaBotName, replyToRandomId: replyGlobalId))
                    case .layer73:
                        if muted {
                            flags |= (1 << 5)
                        }
                        if let _ = viaBotName {
                            flags |= (1 << 11)
                        }
                        let decryptedEntites = entities.flatMap(decryptedEntities73)
                        if let _ = decryptedEntites {
                            flags |= (1 << 7)
                        }
                        let decryptedMedia = SecretApi73.DecryptedMessageMedia.decryptedMessageMediaWebPage(url: url)
                        flags |= (1 << 9)
                        return .layer73(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: decryptedMedia, entities: decryptedEntites, viaBotName: viaBotName, replyToRandomId: replyGlobalId, groupedId: message.groupingKey))
                    case .layer101:
                        if muted {
                            flags |= (1 << 5)
                        }
                        if let _ = viaBotName {
                            flags |= (1 << 11)
                        }
                        let decryptedEntites = entities.flatMap(decryptedEntities101)
                        if let _ = decryptedEntites {
                            flags |= (1 << 7)
                        }
                        let decryptedMedia = SecretApi101.DecryptedMessageMedia.decryptedMessageMediaWebPage(url: url)
                        flags |= (1 << 9)
                        return .layer101(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: decryptedMedia, entities: decryptedEntites, viaBotName: viaBotName, replyToRandomId: replyGlobalId, groupedId: message.groupingKey))
                }
            }
        } else if let location = media as? TelegramMediaMap {
            switch layer {
                case .layer8:
                    break
                case .layer46:
                    if muted {
                        flags |= (1 << 5)
                    }
                    if let _ = viaBotName {
                        flags |= (1 << 11)
                    }
                    let decryptedMedia: SecretApi46.DecryptedMessageMedia
                    flags |= (1 << 9)
                    if let venue = location.venue {
                        decryptedMedia = .decryptedMessageMediaVenue(lat: location.latitude, long: location.longitude, title: venue.title, address: venue.address ?? "", provider: venue.provider ?? "", venueId: venue.id ?? "")
                    } else {
                        decryptedMedia = .decryptedMessageMediaGeoPoint(lat: location.latitude, long: location.longitude)
                    }
                    return .layer46(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: decryptedMedia, entities: nil, viaBotName: viaBotName, replyToRandomId: replyGlobalId))
                case .layer73:
                    if muted {
                        flags |= (1 << 5)
                    }
                    if let _ = viaBotName {
                        flags |= (1 << 11)
                    }
                    let decryptedEntites = entities.flatMap(decryptedEntities73)
                    if let _ = decryptedEntites {
                        flags |= (1 << 7)
                    }
                    
                    let decryptedMedia: SecretApi73.DecryptedMessageMedia
                    flags |= (1 << 9)
                    if let venue = location.venue {
                        decryptedMedia = .decryptedMessageMediaVenue(lat: location.latitude, long: location.longitude, title: venue.title, address: venue.address ?? "", provider: venue.provider ?? "", venueId: venue.id ?? "")
                    } else {
                        decryptedMedia = .decryptedMessageMediaGeoPoint(lat: location.latitude, long: location.longitude)
                    }
                    return .layer73(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: decryptedMedia, entities: decryptedEntites, viaBotName: viaBotName, replyToRandomId: replyGlobalId, groupedId: message.groupingKey))
                case .layer101:
                    if muted {
                        flags |= (1 << 5)
                    }
                    if let _ = viaBotName {
                        flags |= (1 << 11)
                    }
                    let decryptedEntites = entities.flatMap(decryptedEntities101)
                    if let _ = decryptedEntites {
                        flags |= (1 << 7)
                    }
                    
                    let decryptedMedia: SecretApi101.DecryptedMessageMedia
                    flags |= (1 << 9)
                    if let venue = location.venue {
                        decryptedMedia = .decryptedMessageMediaVenue(lat: location.latitude, long: location.longitude, title: venue.title, address: venue.address ?? "", provider: venue.provider ?? "", venueId: venue.id ?? "")
                    } else {
                        decryptedMedia = .decryptedMessageMediaGeoPoint(lat: location.latitude, long: location.longitude)
                    }
                    return .layer101(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: decryptedMedia, entities: decryptedEntites, viaBotName: viaBotName, replyToRandomId: replyGlobalId, groupedId: message.groupingKey))
            }
        } else if let contact = media as? TelegramMediaContact {
            switch layer {
                case .layer8:
                    break
                case .layer46:
                    if muted {
                        flags |= (1 << 5)
                    }
                    if let _ = viaBotName {
                        flags |= (1 << 11)
                    }
                    let decryptedMedia: SecretApi46.DecryptedMessageMedia = .decryptedMessageMediaContact(phoneNumber: contact.phoneNumber, firstName: contact.firstName, lastName: contact.lastName, userId: 0)
                    flags |= (1 << 9)
                    return .layer46(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: decryptedMedia, entities: nil, viaBotName: viaBotName, replyToRandomId: replyGlobalId))
                case .layer73:
                    if muted {
                        flags |= (1 << 5)
                    }
                    if let _ = viaBotName {
                        flags |= (1 << 11)
                    }
                    let decryptedEntites = entities.flatMap(decryptedEntities73)
                    if let _ = decryptedEntites {
                        flags |= (1 << 7)
                    }
                    
                    let decryptedMedia: SecretApi73.DecryptedMessageMedia = .decryptedMessageMediaContact(phoneNumber: contact.phoneNumber, firstName: contact.firstName, lastName: contact.lastName, userId: 0)
                    flags |= (1 << 9)
                    return .layer73(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: decryptedMedia, entities: decryptedEntites, viaBotName: viaBotName, replyToRandomId: replyGlobalId, groupedId: message.groupingKey))
                case .layer101:
                    if muted {
                        flags |= (1 << 5)
                    }
                    if let _ = viaBotName {
                        flags |= (1 << 11)
                    }
                    let decryptedEntites = entities.flatMap(decryptedEntities101)
                    if let _ = decryptedEntites {
                        flags |= (1 << 7)
                    }
                    
                    let decryptedMedia: SecretApi101.DecryptedMessageMedia = .decryptedMessageMediaContact(phoneNumber: contact.phoneNumber, firstName: contact.firstName, lastName: contact.lastName, userId: 0)
                    flags |= (1 << 9)
                    return .layer101(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: decryptedMedia, entities: decryptedEntites, viaBotName: viaBotName, replyToRandomId: replyGlobalId, groupedId: message.groupingKey))
            }
        }
    }

    switch layer {
        case .layer8:
            let randomBytesData = malloc(15)!
            arc4random_buf(randomBytesData, 15)
            let randomBytes = Buffer(memory: randomBytesData, size: 15, capacity: 15, freeWhenDone: true)
            
            return .layer8(.decryptedMessage(randomId: globallyUniqueId, randomBytes: randomBytes, message: message.text, media: .decryptedMessageMediaEmpty))
        case .layer46:
            if muted {
                flags |= (1 << 5)
            }
            if let _ = viaBotName {
                flags |= (1 << 11)
            }
            return .layer46(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: .decryptedMessageMediaEmpty, entities: nil, viaBotName: viaBotName, replyToRandomId: replyGlobalId))
        case .layer73:
            if muted {
                flags |= (1 << 5)
            }
            if let _ = viaBotName {
                flags |= (1 << 11)
            }
            let decryptedEntites = entities.flatMap(decryptedEntities73)
            if let _ = decryptedEntites {
                flags |= (1 << 7)
            }
            return .layer73(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: .decryptedMessageMediaEmpty, entities: decryptedEntites, viaBotName: viaBotName, replyToRandomId: replyGlobalId, groupedId: message.groupingKey))
        case .layer101:
            if muted {
                flags |= (1 << 5)
            }
            if let _ = viaBotName {
                flags |= (1 << 11)
            }
            let decryptedEntites = entities.flatMap(decryptedEntities101)
            if let _ = decryptedEntites {
                flags |= (1 << 7)
            }
            return .layer101(.decryptedMessage(flags: flags, randomId: globallyUniqueId, ttl: messageAutoremoveTimeout, message: message.text, media: .decryptedMessageMediaEmpty, entities: decryptedEntites, viaBotName: viaBotName, replyToRandomId: replyGlobalId, groupedId: message.groupingKey))
    }
}

private func boxedDecryptedSecretMessageAction(action: SecretMessageAction) -> BoxedDecryptedMessage {
    switch action {
        case let .deleteMessages(layer, actionGloballyUniqueId, globallyUniqueIds):
            switch layer {
                case .layer8:
                    let randomBytesData = malloc(15)!
                    arc4random_buf(randomBytesData, 15)
                    let randomBytes = Buffer(memory: randomBytesData, size: 15, capacity: 15, freeWhenDone: true)
                    
                    return .layer8(.decryptedMessageService(randomId: actionGloballyUniqueId, randomBytes: randomBytes, action: .decryptedMessageActionDeleteMessages(randomIds: globallyUniqueIds)))
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionDeleteMessages(randomIds: globallyUniqueIds)))
                case .layer73:
                    return .layer73(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionDeleteMessages(randomIds: globallyUniqueIds)))
                case .layer101:
                    return .layer101(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionDeleteMessages(randomIds: globallyUniqueIds)))
            }
        case let .screenshotMessages(layer, actionGloballyUniqueId, globallyUniqueIds, _):
            switch layer {
                case .layer8:
                    let randomBytesData = malloc(15)!
                    arc4random_buf(randomBytesData, 15)
                    let randomBytes = Buffer(memory: randomBytesData, size: 15, capacity: 15, freeWhenDone: true)
                    
                    return .layer8(.decryptedMessageService(randomId: actionGloballyUniqueId, randomBytes: randomBytes, action: .decryptedMessageActionScreenshotMessages(randomIds: globallyUniqueIds)))
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionScreenshotMessages(randomIds: globallyUniqueIds)))
                case .layer73:
                    return .layer73(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionScreenshotMessages(randomIds: globallyUniqueIds)))
                case .layer101:
                    return .layer101(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionScreenshotMessages(randomIds: globallyUniqueIds)))
            }
        case let .clearHistory(layer, actionGloballyUniqueId):
            switch layer {
                case .layer8:
                    let randomBytesData = malloc(15)!
                    arc4random_buf(randomBytesData, 15)
                    let randomBytes = Buffer(memory: randomBytesData, size: 15, capacity: 15, freeWhenDone: true)
                    return .layer8(.decryptedMessageService(randomId: actionGloballyUniqueId, randomBytes: randomBytes, action: .decryptedMessageActionFlushHistory))
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionFlushHistory))
                case .layer73:
                    return .layer73(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionFlushHistory))
                case .layer101:
                    return .layer101(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionFlushHistory))
            }
        case let .resendOperations(layer, actionGloballyUniqueId, fromSeqNo, toSeqNo):
            switch layer {
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionResend(startSeqNo: fromSeqNo, endSeqNo: toSeqNo)))
                case .layer73:
                    return .layer73(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionResend(startSeqNo: fromSeqNo, endSeqNo: toSeqNo)))
                case .layer101:
                    return .layer101(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionResend(startSeqNo: fromSeqNo, endSeqNo: toSeqNo)))
            }
        case let .reportLayerSupport(layer, actionGloballyUniqueId, layerSupport):
            switch layer {
                case .layer8:
                    let randomBytesData = malloc(15)!
                    arc4random_buf(randomBytesData, 15)
                    let randomBytes = Buffer(memory: randomBytesData, size: 15, capacity: 15, freeWhenDone: true)
                    
                    return .layer8(.decryptedMessageService(randomId: actionGloballyUniqueId, randomBytes: randomBytes, action: .decryptedMessageActionNotifyLayer(layer: layerSupport)))
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionNotifyLayer(layer: layerSupport)))
                case .layer73:
                    return .layer73(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionNotifyLayer(layer: layerSupport)))
                case .layer101:
                    return .layer101(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionNotifyLayer(layer: layerSupport)))
            }
        case let .pfsRequestKey(layer, actionGloballyUniqueId, rekeySessionId, gA):
            switch layer {
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionRequestKey(exchangeId: rekeySessionId, gA: Buffer(buffer: gA))))
                case .layer73:
                    return .layer73(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionRequestKey(exchangeId: rekeySessionId, gA: Buffer(buffer: gA))))
                case .layer101:
                    return .layer101(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionRequestKey(exchangeId: rekeySessionId, gA: Buffer(buffer: gA))))
            }
        case let .pfsAcceptKey(layer, actionGloballyUniqueId, rekeySessionId, gB, keyFingerprint):
            switch layer {
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionAcceptKey(exchangeId: rekeySessionId, gB: Buffer(buffer: gB), keyFingerprint: keyFingerprint)))
                case .layer73:
                    return .layer73(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionAcceptKey(exchangeId: rekeySessionId, gB: Buffer(buffer: gB), keyFingerprint: keyFingerprint)))
                case .layer101:
                    return .layer101(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionAcceptKey(exchangeId: rekeySessionId, gB: Buffer(buffer: gB), keyFingerprint: keyFingerprint)))
            }
        case let .pfsAbortSession(layer, actionGloballyUniqueId, rekeySessionId):
            switch layer {
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionAbortKey(exchangeId: rekeySessionId)))
                case .layer73:
                    return .layer73(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionAbortKey(exchangeId: rekeySessionId)))
                case .layer101:
                    return .layer101(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionAbortKey(exchangeId: rekeySessionId)))
            }
        case let .pfsCommitKey(layer, actionGloballyUniqueId, rekeySessionId, keyFingerprint):
            switch layer {
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionCommitKey(exchangeId: rekeySessionId, keyFingerprint: keyFingerprint)))
                case .layer73:
                    return .layer73(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionCommitKey(exchangeId: rekeySessionId, keyFingerprint: keyFingerprint)))
                case .layer101:
                    return .layer101(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionCommitKey(exchangeId: rekeySessionId, keyFingerprint: keyFingerprint)))
            }
        case let .noop(layer, actionGloballyUniqueId):
            switch layer {
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionNoop))
                case .layer73:
                    return .layer73(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionNoop))
                case .layer101:
                    return .layer101(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionNoop))
            }
        case let .readMessageContents(layer, actionGloballyUniqueId, globallyUniqueIds):
            switch layer {
                case .layer8:
                    let randomBytesData = malloc(15)!
                    arc4random_buf(randomBytesData, 15)
                    let randomBytes = Buffer(memory: randomBytesData, size: 15, capacity: 15, freeWhenDone: true)
                    
                    return .layer8(.decryptedMessageService(randomId: actionGloballyUniqueId, randomBytes: randomBytes, action: .decryptedMessageActionReadMessages(randomIds: globallyUniqueIds)))
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionReadMessages(randomIds: globallyUniqueIds)))
                case .layer73:
                    return .layer73(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionReadMessages(randomIds: globallyUniqueIds)))
                case .layer101:
                    return .layer101(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionReadMessages(randomIds: globallyUniqueIds)))
            }
        case let .setMessageAutoremoveTimeout(layer, actionGloballyUniqueId, timeout, _):
            switch layer {
                case .layer8:
                    let randomBytesData = malloc(15)!
                    arc4random_buf(randomBytesData, 15)
                    let randomBytes = Buffer(memory: randomBytesData, size: 15, capacity: 15, freeWhenDone: true)
                    
                    return .layer8(.decryptedMessageService(randomId: actionGloballyUniqueId, randomBytes: randomBytes, action: .decryptedMessageActionSetMessageTTL(ttlSeconds: timeout)))
                case .layer46:
                    return .layer46(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionSetMessageTTL(ttlSeconds: timeout)))
                case .layer73:
                    return .layer73(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionSetMessageTTL(ttlSeconds: timeout)))
                case .layer101:
                    return .layer101(.decryptedMessageService(randomId: actionGloballyUniqueId, action: .decryptedMessageActionSetMessageTTL(ttlSeconds: timeout)))
            }
    }
}

private func markOutgoingOperationAsCompleted(transaction: Transaction, peerId: PeerId, tagLocalIndex: Int32, forceRemove: Bool) {
    var removeFromTagMergedIndexOnly = false
    if let state = transaction.getPeerChatState(peerId) as? SecretChatState {
        switch state.embeddedState {
            case let .sequenceBasedLayer(sequenceState):
                if tagLocalIndex >= sequenceState.baseOutgoingOperationIndex {
                    removeFromTagMergedIndexOnly = true
                }
            default:
                break
        }
    }
    if removeFromTagMergedIndexOnly && !forceRemove {
        transaction.operationLogUpdateEntry(peerId: peerId, tag: OperationLogTags.SecretOutgoing, tagLocalIndex: tagLocalIndex, { entry in
            if let operation = entry?.contents as? SecretChatOutgoingOperation {
                return PeerOperationLogEntryUpdate(mergedIndex: .remove, contents: .update(operation.withUpdatedDelivered(true)))
            } else {
                //assertionFailure()
                return PeerOperationLogEntryUpdate(mergedIndex: .remove, contents: .none)
            }
        })
    } else {
        let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: OperationLogTags.SecretOutgoing, tagLocalIndex: tagLocalIndex)
    }
}

private func replaceOutgoingOperationWithEmptyMessage(transaction: Transaction, peerId: PeerId, tagLocalIndex: Int32, globallyUniqueId: Int64) {
    var layer: SecretChatLayer?
    let state = transaction.getPeerChatState(peerId) as? SecretChatState
    if let state = state {
        switch state.embeddedState {
            case .terminated, .handshake:
                break
            case .basicLayer:
                layer = .layer8
            case let .sequenceBasedLayer(sequenceState):
                layer = sequenceState.layerNegotiationState.activeLayer.secretChatLayer
        }
    }
    if let layer = layer {
        transaction.operationLogUpdateEntry(peerId: peerId, tag: OperationLogTags.SecretOutgoing, tagLocalIndex: tagLocalIndex, { entry in
            if let _ = entry?.contents as? SecretChatOutgoingOperation {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .update(SecretChatOutgoingOperation(contents: SecretChatOutgoingOperationContents.deleteMessages(layer: layer, actionGloballyUniqueId: Int64.random(in: Int64.min ... Int64.max), globallyUniqueIds: [globallyUniqueId]), mutable: true, delivered: false)))
            } else {
                assertionFailure()
                return PeerOperationLogEntryUpdate(mergedIndex: .remove, contents: .none)
            }
        })
    } else {
        assertionFailure()
        let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: OperationLogTags.SecretOutgoing, tagLocalIndex: tagLocalIndex)
    }
}

private func resourceThumbnailData(auxiliaryMethods: AccountAuxiliaryMethods, mediaBox: MediaBox, resource: MediaResource, mediaId: MediaId) -> Signal<(MediaId, PixelDimensions, Data)?, NoError> {
    return mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
    |> take(1)
    |> map { data -> (MediaId, PixelDimensions, Data)? in
        if data.complete, let (mappedSize, mappedData) = auxiliaryMethods.prepareSecretThumbnailData(data) {
            return (mediaId, mappedSize, mappedData)
        } else {
            return nil
        }
    }
}

private func messageWithThumbnailData(auxiliaryMethods: AccountAuxiliaryMethods, mediaBox: MediaBox, message: Message) -> Signal<[MediaId: (PixelDimensions, Data)], NoError> {
    var signals: [Signal<(MediaId, PixelDimensions, Data)?, NoError>] = []
    for media in message.media {
        if let image = media as? TelegramMediaImage {
            if let smallestRepresentation = smallestImageRepresentation(image.representations) {
                signals.append(resourceThumbnailData(auxiliaryMethods: auxiliaryMethods, mediaBox: mediaBox, resource: smallestRepresentation.resource, mediaId: image.imageId))
            }
        } else if let file = media as? TelegramMediaFile {
            if let smallestRepresentation = smallestImageRepresentation(file.previewRepresentations) {
                signals.append(resourceThumbnailData(auxiliaryMethods: auxiliaryMethods, mediaBox: mediaBox, resource: smallestRepresentation.resource, mediaId: file.fileId))
            }
        }
    }
    return combineLatest(signals)
    |> map { values in
        var result: [MediaId: (PixelDimensions, Data)] = [:]
        for value in values {
            if let value = value {
                result[value.0] = (value.1, value.2)
            }
        }
        return result
    }
}

private func sendMessage(auxiliaryMethods: AccountAuxiliaryMethods, postbox: Postbox, network: Network, messageId: MessageId, file: SecretChatOutgoingFile?, tagLocalIndex: Int32, wasDelivered: Bool, layer: SecretChatLayer) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<[MediaId: (PixelDimensions, Data)], NoError> in
        if let message = transaction.getMessage(messageId) {
            return messageWithThumbnailData(auxiliaryMethods: auxiliaryMethods, mediaBox: postbox.mediaBox, message: message)
        } else {
            return .single([:])
        }
    }
    |> switchToLatest
    |> mapToSignal { thumbnailData -> Signal<Void, NoError> in
        return postbox.transaction { transaction -> Signal<Void, NoError> in
            if let state = transaction.getPeerChatState(messageId.peerId) as? SecretChatState, let peer = transaction.getPeer(messageId.peerId) as? TelegramSecretChat {
                if let message = transaction.getMessage(messageId), let globallyUniqueId = message.globallyUniqueId {
                    let decryptedMessage = boxedDecryptedMessage(transaction: transaction, message: message, globallyUniqueId: globallyUniqueId, uploadedFile: file, thumbnailData: thumbnailData, layer: layer)
                    return sendBoxedDecryptedMessage(postbox: postbox, network: network, peer: peer, state: state, operationIndex: tagLocalIndex, decryptedMessage: decryptedMessage, globallyUniqueId: globallyUniqueId, file: file, silent: message.muted, asService: wasDelivered, wasDelivered: wasDelivered)
                    |> mapToSignal { result in
                        return postbox.transaction { transaction -> Void in
                            let forceRemove: Bool
                            switch result {
                                case .message:
                                    forceRemove = false
                                case .error:
                                    forceRemove = true
                            }
                            markOutgoingOperationAsCompleted(transaction: transaction, peerId: messageId.peerId, tagLocalIndex: tagLocalIndex, forceRemove: forceRemove)
                            
                            var timestamp = message.timestamp
                            var encryptedFile: SecretChatFileReference?
                            if case let .message(result) = result {
                                switch result {
                                    case let .sentEncryptedMessage(date):
                                        timestamp = date
                                    case let .sentEncryptedFile(date, file):
                                        timestamp = date
                                        encryptedFile = SecretChatFileReference(file)
                                }
                            }
                            
                            transaction.offsetPendingMessagesTimestamps(lowerBound: message.id, excludeIds: Set([messageId]), timestamp: timestamp)
                            
                            transaction.updateMessage(message.id, update: { currentMessage in
                                var flags = StoreMessageFlags(currentMessage.flags)
                                if case .message = result {
                                    flags.remove(.Unsent)
                                    flags.remove(.Sending)
                                    flags.remove(.Failed)
                                } else {
                                    flags = [.Failed]
                                }
                                var storeForwardInfo: StoreMessageForwardInfo?
                                if let forwardInfo = currentMessage.forwardInfo {
                                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                                }
                                
                                var updatedMedia = currentMessage.media
                                
                                if let fromMedia = currentMessage.media.first, let encryptedFile = encryptedFile, let file = file {
                                    var toMedia: Media?
                                    if let fromMedia = fromMedia as? TelegramMediaFile {
                                        let updatedFile = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudSecretFile, id: encryptedFile.id), partialReference: nil, resource: SecretFileMediaResource(fileId: encryptedFile.id, accessHash: encryptedFile.accessHash, containerSize: encryptedFile.size, decryptedSize: file.size, datacenterId: Int(encryptedFile.datacenterId), key: file.key), previewRepresentations: fromMedia.previewRepresentations, videoThumbnails: fromMedia.videoThumbnails, immediateThumbnailData: fromMedia.immediateThumbnailData, mimeType: fromMedia.mimeType, size: fromMedia.size, attributes: fromMedia.attributes)
                                        toMedia = updatedFile
                                        updatedMedia = [updatedFile]
                                    }
                                    
                                    if let toMedia = toMedia {
                                        applyMediaResourceChanges(from: fromMedia, to: toMedia, postbox: postbox, force: false)
                                    }
                                }
                                
                                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: timestamp, flags: flags, tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: updatedMedia))
                            })
                            
                            maybeReadSecretOutgoingMessage(transaction: transaction, index: MessageIndex(id: message.id, timestamp: timestamp))
                            
                            var sentStickers: [TelegramMediaFile] = []
                            for media in message.media {
                                if let file = media as? TelegramMediaFile {
                                    if file.isSticker {
                                        sentStickers.append(file)
                                    }
                                }
                            }
                            
                            for file in sentStickers {
                                addRecentlyUsedSticker(transaction: transaction, fileReference: .standalone(media: file))
                            }
                            
                            if case .error(.chatCancelled) = result {
                                
                            }
                        }
                    }
                } else {
                    replaceOutgoingOperationWithEmptyMessage(transaction: transaction, peerId: messageId.peerId, tagLocalIndex: tagLocalIndex, globallyUniqueId: Int64.random(in: Int64.min ... Int64.max))
                    _internal_deleteMessages(transaction: transaction, mediaBox: postbox.mediaBox, ids: [messageId])
                    return .complete()
                }
            } else {
                return .complete()
            }
        } |> switchToLatest
    }
}

private func sendServiceActionMessage(postbox: Postbox, network: Network, peerId: PeerId, action: SecretMessageAction, tagLocalIndex: Int32, wasDelivered: Bool) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        if let state = transaction.getPeerChatState(peerId) as? SecretChatState, let peer = transaction.getPeer(peerId) as? TelegramSecretChat {
            let decryptedMessage = boxedDecryptedSecretMessageAction(action: action)
            return sendBoxedDecryptedMessage(postbox: postbox, network: network, peer: peer, state: state, operationIndex: tagLocalIndex, decryptedMessage: decryptedMessage, globallyUniqueId: action.globallyUniqueId, file: nil, silent: false, asService: true, wasDelivered: wasDelivered)
            |> mapToSignal { result in
                return postbox.transaction { transaction -> Void in
                    let forceRemove: Bool
                    switch result {
                        case .message:
                            forceRemove = false
                        case .error:
                            forceRemove = true
                    }
                    markOutgoingOperationAsCompleted(transaction: transaction, peerId: peerId, tagLocalIndex: tagLocalIndex, forceRemove: forceRemove)
                    if let messageId = action.messageId {
                        var resultTimestamp: Int32?
                        transaction.updateMessage(messageId, update: { currentMessage in
                            var flags = StoreMessageFlags(currentMessage.flags)
                            var timestamp = currentMessage.timestamp
                            if case let .message(result) = result {
                                switch result {
                                    case let .sentEncryptedMessage(date):
                                        timestamp = date
                                    case let .sentEncryptedFile(date, _):
                                        timestamp = date
                                }
                                flags.remove(.Unsent)
                                flags.remove(.Sending)
                            } else {
                                flags = [.Failed]
                            }
                            resultTimestamp = timestamp
                            var storeForwardInfo: StoreMessageForwardInfo?
                            if let forwardInfo = currentMessage.forwardInfo {
                                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                            }
                            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: timestamp, flags: flags, tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
                        })
                        
                        if let resultTimestamp = resultTimestamp {
                            maybeReadSecretOutgoingMessage(transaction: transaction, index: MessageIndex(id: messageId, timestamp: resultTimestamp))
                        }
                    }
                }
            }
        } else {
            return .complete()
        }
    }
    |> switchToLatest
}

private enum SendBoxedDecryptedMessageError {
    case chatCancelled
    case generic
}

private enum SendBoxedDecryptedMessageResult {
    case message(Api.messages.SentEncryptedMessage)
    case error(SendBoxedDecryptedMessageError)
}

private func sendBoxedDecryptedMessage(postbox: Postbox, network: Network, peer: TelegramSecretChat, state: SecretChatState, operationIndex: Int32, decryptedMessage: BoxedDecryptedMessage, globallyUniqueId: Int64, file: SecretChatOutgoingFile?, silent: Bool, asService: Bool, wasDelivered: Bool) -> Signal<SendBoxedDecryptedMessageResult, NoError> {
    let payload = Buffer()
    var sequenceInfo: SecretChatOperationSequenceInfo?
    var maybeParameters: SecretChatEncryptionParameters?
    
    let mode: SecretChatEncryptionMode
    switch decryptedMessage {
        case .layer8, .layer46:
            mode = .v1
        default:
            mode = .v2(role: state.role)
    }
    
    switch state.embeddedState {
        case .terminated, .handshake:
            break
        case .basicLayer:
            if let key = state.keychain.indefinitelyValidKey() {
                maybeParameters = SecretChatEncryptionParameters(key: key, mode: mode)
            }
        case let .sequenceBasedLayer(sequenceState):
            let topReceivedOperationIndex: Int32
            if let topProcessedCanonicalIncomingOperationIndex = sequenceState.topProcessedCanonicalIncomingOperationIndex {
                topReceivedOperationIndex = topProcessedCanonicalIncomingOperationIndex
            } else {
                topReceivedOperationIndex = -1
            }
            let canonicalOperationIndex = sequenceState.canonicalOutgoingOperationIndex(operationIndex)
            if let key = state.keychain.latestKey(validForSequenceBasedCanonicalIndex: canonicalOperationIndex) {
                maybeParameters = SecretChatEncryptionParameters(key: key, mode: mode)
            }
            Logger.shared.log("SecretChat", "sending message with index \(canonicalOperationIndex) key \(String(describing: maybeParameters?.key.fingerprint))")
            sequenceInfo = SecretChatOperationSequenceInfo(topReceivedOperationIndex: topReceivedOperationIndex, operationIndex: canonicalOperationIndex)
    }
    
    guard let parameters = maybeParameters else {
        Logger.shared.log("SecretChat", "no valid key found")
        return .single(.error(.chatCancelled))
    }
    
    decryptedMessage.serialize(payload, role: state.role, sequenceInfo: sequenceInfo)
    let encryptedPayload = encryptedMessageContents(parameters: parameters, data: MemoryBuffer(payload))
    let sendMessage: Signal<Api.messages.SentEncryptedMessage, MTRpcError>
    let inputPeer = Api.InputEncryptedChat.inputEncryptedChat(chatId: Int32(peer.id.id._internalGetInt64Value()), accessHash: peer.accessHash)
    
    var flags: Int32 = 0
    if silent {
        flags |= (1 << 0)
    }
    
    if asService {
        let actionRandomId: Int64
        if wasDelivered {
            actionRandomId = Int64.random(in: Int64.min ... Int64.max)
        } else {
            actionRandomId = globallyUniqueId
        }
        sendMessage = network.request(Api.functions.messages.sendEncryptedService(peer: inputPeer, randomId: actionRandomId, data: Buffer(data: encryptedPayload)))
    } else {
        if let file = file {
            sendMessage = network.request(Api.functions.messages.sendEncryptedFile(flags: flags, peer: inputPeer, randomId: globallyUniqueId, data: Buffer(data: encryptedPayload), file: file.reference.apiInputFile))
        } else {
            sendMessage = network.request(Api.functions.messages.sendEncrypted(flags: flags, peer: inputPeer, randomId: globallyUniqueId, data: Buffer(data: encryptedPayload)))
        }
    }
    return sendMessage
    |> map { next -> SendBoxedDecryptedMessageResult in
        return .message(next)
    }
    |> `catch` { error -> Signal<SendBoxedDecryptedMessageResult, NoError> in
        if error.errorDescription == "ENCRYPTION_DECLINED" {
            return .single(.error(.chatCancelled))
        } else {
            return .single(.error(.generic))
        }
    }
}

private func requestTerminateSecretChat(postbox: Postbox, network: Network, peerId: PeerId, tagLocalIndex: Int32, reportSpam: Bool, requestRemoteHistoryRemoval: Bool) -> Signal<Void, NoError> {
    var flags: Int32 = 0
    if requestRemoteHistoryRemoval {
        flags |= 1 << 0
    }
    return network.request(Api.functions.messages.discardEncryption(flags: flags, chatId: Int32(peerId.id._internalGetInt64Value())))
    |> map(Optional.init)
    |> `catch` { _ in
        return .single(nil)
    }
    |> mapToSignal { _ -> Signal<Void, NoError> in
        if reportSpam {
            return postbox.transaction { transaction -> TelegramSecretChat? in
                if let peer = transaction.getPeer(peerId) as? TelegramSecretChat {
                    return peer
                } else {
                    return nil
                }
            }
            |> mapToSignal { peer -> Signal<Void, NoError> in
                if let peer = peer {
                    return network.request(Api.functions.messages.reportEncryptedSpam(peer: Api.InputEncryptedChat.inputEncryptedChat(chatId: Int32(peer.id.id._internalGetInt64Value()), accessHash: peer.accessHash)))
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<Api.Bool?, NoError> in
                        return .single(nil)
                    }
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        return postbox.transaction { transaction -> Void in
                            if result != nil {
                                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                    if let current = current as? CachedSecretChatData {
                                        var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                                        peerStatusSettings.flags = []
                                        return current.withUpdatedPeerStatusSettings(peerStatusSettings)
                                    } else {
                                        return current
                                    }
                                })
                            }
                        }
                    }
                } else {
                    return .single(Void())
                }
            }
        } else {
            return .single(Void())
        }
    }
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return postbox.transaction { transaction -> Void in
            markOutgoingOperationAsCompleted(transaction: transaction, peerId: peerId, tagLocalIndex: tagLocalIndex, forceRemove: true)
        }
    }
}
