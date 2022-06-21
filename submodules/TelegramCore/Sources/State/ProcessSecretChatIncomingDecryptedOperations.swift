import Foundation
import Postbox
import TelegramApi

import EncryptionProvider

private enum MessageParsingError: Error {
    case contentParsingError
    case unsupportedLayer
    case invalidChatState
    case alreadyProcessedMessageInSequenceBasedLayer
    case holesInSequenceBasedLayer
    case secretChatCorruption
}

enum SecretChatRekeyServiceAction {
    case pfsRequestKey(rekeySessionId: Int64, gA: MemoryBuffer)
    case pfsAcceptKey(rekeySessionId: Int64, gB: MemoryBuffer, keyFingerprint: Int64)
    case pfsAbortSession(rekeySessionId: Int64)
    case pfsCommitKey(rekeySessionId: Int64, keyFingerprint: Int64)
}

private enum SecretChatServiceAction {
    case deleteMessages(globallyUniqueIds: [Int64])
    case clearHistory
    case reportLayerSupport(Int32)
    case markMessagesContentAsConsumed(globallyUniqueIds: [Int64])
    case setMessageAutoremoveTimeout(Int32)
    case resendOperations(fromSeq: Int32, toSeq: Int32)
    case rekeyAction(SecretChatRekeyServiceAction)
}

private func parsedServiceAction(_ operation: SecretChatIncomingDecryptedOperation) -> SecretChatServiceAction? {
    guard let parsedLayer = SecretChatLayer(rawValue: operation.layer) else {
        return nil
    }
    
    switch parsedLayer {
        case .layer8:
            if let parsedObject = SecretApi8.parse(Buffer(bufferNoCopy: operation.contents)), let apiMessage = parsedObject as? SecretApi8.DecryptedMessage {
                return SecretChatServiceAction(apiMessage)
            }
        case .layer46:
            if let parsedObject = SecretApi46.parse(Buffer(bufferNoCopy: operation.contents)), let apiMessage = parsedObject as? SecretApi46.DecryptedMessage {
                return SecretChatServiceAction(apiMessage)
            }
        case .layer73:
            if let parsedObject = SecretApi73.parse(Buffer(bufferNoCopy: operation.contents)), let apiMessage = parsedObject as? SecretApi73.DecryptedMessage {
                return SecretChatServiceAction(apiMessage)
            }
        case .layer101:
            if let parsedObject = SecretApi101.parse(Buffer(bufferNoCopy: operation.contents)), let apiMessage = parsedObject as? SecretApi101.DecryptedMessage {
                return SecretChatServiceAction(apiMessage)
            }
    }
    return nil
}

struct SecretChatOperationProcessResult {
    let addedMessages: [StoreMessage]
}

func processSecretChatIncomingDecryptedOperations(encryptionProvider: EncryptionProvider, mediaBox: MediaBox, transaction: Transaction, peerId: PeerId) -> SecretChatOperationProcessResult {
    if let state = transaction.getPeerChatState(peerId) as? SecretChatState, let peer = transaction.getPeer(peerId) as? TelegramSecretChat {
        var removeTagLocalIndices: [Int32] = []
        var updatedState = state
        var couldNotResendRequestedMessages = false
        var maxAcknowledgedCanonicalOperationIndex: Int32?
        var updatedPeer = peer
        var addedMessages: [StoreMessage] = []
        
        transaction.operationLogEnumerateEntries(peerId: peerId, tag: OperationLogTags.SecretIncomingDecrypted, { entry in
            if let operation = entry.contents as? SecretChatIncomingDecryptedOperation, let serviceAction = parsedServiceAction(operation), case let .resendOperations(fromSeq, toSeq) = serviceAction {
                switch updatedState.role {
                    case .creator:
                        if fromSeq < 0 || toSeq < 0 || (fromSeq & 1) == 0 || (toSeq & 1) == 0 {
                            return true
                        }
                    case .participant:
                        if fromSeq < 0 || toSeq < 0 || (fromSeq & 1) != 0 || (toSeq & 1) != 0 {
                            return true
                        }
                }
                switch updatedState.embeddedState {
                    case let .sequenceBasedLayer(sequenceState):
                        let fromOperationIndex = sequenceState.outgoingOperationIndexFromCanonicalOperationIndex(fromSeq / 2)
                        let toOperationIndex = sequenceState.outgoingOperationIndexFromCanonicalOperationIndex(toSeq / 2)
                        if fromOperationIndex <= toOperationIndex {
                            for index in fromOperationIndex ... toOperationIndex {
                                var notFound = false
                                transaction.operationLogUpdateEntry(peerId: peerId, tag: OperationLogTags.SecretOutgoing, tagLocalIndex: index, { entry in
                                    if let _ = entry {                                                        return PeerOperationLogEntryUpdate(mergedIndex: .newAutomatic, contents: .none)
                                    } else {
                                        notFound = true
                                        return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
                                    }
                                })
                                if notFound {
                                    couldNotResendRequestedMessages = true
                                    return false
                                }
                            }
                        }
                    default:
                        break
                }
            }
            return true
        })
        
        if !couldNotResendRequestedMessages {
            transaction.operationLogEnumerateEntries(peerId: peerId, tag: OperationLogTags.SecretIncomingDecrypted, { entry in
                if let operation = entry.contents as? SecretChatIncomingDecryptedOperation {
                    do {
                        var message: StoreMessage?
                        var contentParsingError = false
                        var resources: [(MediaResource, Data)] = []
                        var serviceAction: SecretChatServiceAction?
                        
                        guard let parsedLayer = SecretChatLayer(rawValue: operation.layer) else {
                            throw MessageParsingError.unsupportedLayer
                        }
                        
                        switch parsedLayer {
                            case .layer8:
                                if let parsedObject = SecretApi8.parse(Buffer(bufferNoCopy: operation.contents)), let apiMessage = parsedObject as? SecretApi8.DecryptedMessage {
                                    message = StoreMessage(peerId: peerId, authorId: updatedPeer.regularPeerId, tagLocalIndex: entry.tagLocalIndex, timestamp: operation.timestamp, apiMessage: apiMessage, file: operation.file)
                                    serviceAction = SecretChatServiceAction(apiMessage)
                                } else {
                                    throw MessageParsingError.contentParsingError
                                }
                            case .layer46:
                                if let parsedObject = SecretApi46.parse(Buffer(bufferNoCopy: operation.contents)), let apiMessage = parsedObject as? SecretApi46.DecryptedMessage {
                                    if let (parsedMessage, parsedResources) = parseMessage(peerId: peerId, authorId: updatedPeer.regularPeerId, tagLocalIndex: entry.tagLocalIndex, timestamp: operation.timestamp, apiMessage: apiMessage, file: operation.file, messageIdForGloballyUniqueMessageId: { id in
                                        return transaction.messageIdForGloballyUniqueMessageId(peerId: peerId, id: id)
                                    }) {
                                        message = parsedMessage
                                        resources = parsedResources
                                    }
                                    serviceAction = SecretChatServiceAction(apiMessage)
                                } else {
                                    throw MessageParsingError.contentParsingError
                                }
                            case .layer73:
                                if let parsedObject = SecretApi73.parse(Buffer(bufferNoCopy: operation.contents)), let apiMessage = parsedObject as? SecretApi73.DecryptedMessage {
                                    if let (parsedMessage, parsedResources) = parseMessage(peerId: peerId, authorId: updatedPeer.regularPeerId, tagLocalIndex: entry.tagLocalIndex, timestamp: operation.timestamp, apiMessage: apiMessage, file: operation.file, messageIdForGloballyUniqueMessageId: { id in
                                        return transaction.messageIdForGloballyUniqueMessageId(peerId: peerId, id: id)
                                    }) {
                                        message = parsedMessage
                                        resources = parsedResources
                                    }
                                    serviceAction = SecretChatServiceAction(apiMessage)
                                } else {
                                    contentParsingError = true
                                }
                            case .layer101:
                                if let parsedObject = SecretApi101.parse(Buffer(bufferNoCopy: operation.contents)), let apiMessage = parsedObject as? SecretApi101.DecryptedMessage {
                                    if let (parsedMessage, parsedResources) = parseMessage(peerId: peerId, authorId: updatedPeer.regularPeerId, tagLocalIndex: entry.tagLocalIndex, timestamp: operation.timestamp, apiMessage: apiMessage, file: operation.file, messageIdForGloballyUniqueMessageId: { id in
                                        return transaction.messageIdForGloballyUniqueMessageId(peerId: peerId, id: id)
                                    }) {
                                        message = parsedMessage
                                        resources = parsedResources
                                    }
                                    serviceAction = SecretChatServiceAction(apiMessage)
                                } else {
                                    contentParsingError = true
                                }
                        }
                        
                        switch updatedState.embeddedState {
                            case .terminated:
                                throw MessageParsingError.invalidChatState
                            case .handshake:
                                throw MessageParsingError.invalidChatState
                            case .basicLayer:
                                if parsedLayer != .layer8 {
                                    throw MessageParsingError.contentParsingError
                                }
                            case let .sequenceBasedLayer(sequenceState):
                                if let sequenceInfo = operation.sequenceInfo {
                                    let canonicalIncomingIndex = sequenceState.canonicalIncomingOperationIndex(entry.tagLocalIndex)
                                    assert(canonicalIncomingIndex == sequenceInfo.operationIndex)
                                    if let topProcessedCanonicalIncomingOperationIndex = sequenceState.topProcessedCanonicalIncomingOperationIndex {
                                        if canonicalIncomingIndex != topProcessedCanonicalIncomingOperationIndex + 1 {
                                            if canonicalIncomingIndex <= topProcessedCanonicalIncomingOperationIndex {
                                                throw MessageParsingError.alreadyProcessedMessageInSequenceBasedLayer
                                            } else {
                                                if let layer = SecretChatSequenceBasedLayer(rawValue: parsedLayer.rawValue) {
                                                    let role = updatedState.role
                                                    let fromSeqNo: Int32 = (topProcessedCanonicalIncomingOperationIndex + 1) * 2 + (role == .creator ? 0 : 1)
                                                    let toSeqNo: Int32 = (canonicalIncomingIndex - 1) * 2 + (role == .creator ? 0 : 1)
                                                    updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: peerId, operation: SecretChatOutgoingOperationContents.resendOperations(layer: layer, actionGloballyUniqueId: Int64.random(in: Int64.min ... Int64.max), fromSeqNo: fromSeqNo, toSeqNo: toSeqNo), state: updatedState)
                                                } else {
                                                    assertionFailure()
                                                }
                                                throw MessageParsingError.holesInSequenceBasedLayer
                                            }
                                        }
                                    } else {
                                        
                                        if canonicalIncomingIndex != 0 && canonicalIncomingIndex != 1 {
                                            if let layer = SecretChatSequenceBasedLayer(rawValue: parsedLayer.rawValue) {
                                                let role = updatedState.role
                                                let fromSeqNo: Int32 = Int32(0 * 2) + (role == .creator ? Int32(0) : Int32(1))
                                                let toSeqNo: Int32 = (canonicalIncomingIndex - 1) * 2 + (role == .creator ? 0 : 1)
                                                updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: peerId, operation: SecretChatOutgoingOperationContents.resendOperations(layer: layer, actionGloballyUniqueId: Int64.random(in: Int64.min ... Int64.max), fromSeqNo: fromSeqNo, toSeqNo: toSeqNo), state: updatedState)
                                            } else {
                                                assertionFailure()
                                            }
                                            throw MessageParsingError.holesInSequenceBasedLayer
                                        }
                                    }
                                    
                                    updatedState = updatedState.withUpdatedEmbeddedState(.sequenceBasedLayer(sequenceState.withUpdatedTopProcessedCanonicalIncomingOperationIndex(canonicalIncomingIndex)))
                                } else {
                                    throw MessageParsingError.contentParsingError
                                }
                        }
                        
                        if let serviceAction = serviceAction {
                            switch serviceAction {
                                case let .reportLayerSupport(layerSupport):
                                    switch updatedState.embeddedState {
                                        case .terminated:
                                            throw MessageParsingError.invalidChatState
                                        case .handshake:
                                            throw MessageParsingError.invalidChatState
                                        case .basicLayer:
                                            if layerSupport >= 101 {
                                                let sequenceBasedLayerState = SecretChatSequenceBasedLayerState(layerNegotiationState: SecretChatLayerNegotiationState(activeLayer: .layer101, locallyRequestedLayer: 101, remotelyRequestedLayer: layerSupport), rekeyState: nil, baseIncomingOperationIndex: entry.tagLocalIndex, baseOutgoingOperationIndex: transaction.operationLogGetNextEntryLocalIndex(peerId: peerId, tag: OperationLogTags.SecretOutgoing), topProcessedCanonicalIncomingOperationIndex: nil)
                                                updatedState = updatedState.withUpdatedEmbeddedState(.sequenceBasedLayer(sequenceBasedLayerState))
                                                updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: peerId, operation: .reportLayerSupport(layer: .layer101, actionGloballyUniqueId: Int64.random(in: Int64.min ... Int64.max), layerSupport: 101), state: updatedState)
                                            } else if layerSupport >= 73 {
                                                let sequenceBasedLayerState = SecretChatSequenceBasedLayerState(layerNegotiationState: SecretChatLayerNegotiationState(activeLayer: .layer73, locallyRequestedLayer: 73, remotelyRequestedLayer: layerSupport), rekeyState: nil, baseIncomingOperationIndex: entry.tagLocalIndex, baseOutgoingOperationIndex: transaction.operationLogGetNextEntryLocalIndex(peerId: peerId, tag: OperationLogTags.SecretOutgoing), topProcessedCanonicalIncomingOperationIndex: nil)
                                                updatedState = updatedState.withUpdatedEmbeddedState(.sequenceBasedLayer(sequenceBasedLayerState))
                                                updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: peerId, operation: .reportLayerSupport(layer: .layer73, actionGloballyUniqueId: Int64.random(in: Int64.min ... Int64.max), layerSupport: 101), state: updatedState)
                                            } else if layerSupport >= 46 {
                                                let sequenceBasedLayerState = SecretChatSequenceBasedLayerState(layerNegotiationState: SecretChatLayerNegotiationState(activeLayer: .layer73, locallyRequestedLayer: 46, remotelyRequestedLayer: layerSupport), rekeyState: nil, baseIncomingOperationIndex: entry.tagLocalIndex, baseOutgoingOperationIndex: transaction.operationLogGetNextEntryLocalIndex(peerId: peerId, tag: OperationLogTags.SecretOutgoing), topProcessedCanonicalIncomingOperationIndex: nil)
                                                updatedState = updatedState.withUpdatedEmbeddedState(.sequenceBasedLayer(sequenceBasedLayerState))
                                                updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: peerId, operation: .reportLayerSupport(layer: .layer73, actionGloballyUniqueId: Int64.random(in: Int64.min ... Int64.max), layerSupport: 101), state: updatedState)
                                            } else {
                                                throw MessageParsingError.contentParsingError
                                            }
                                        case let .sequenceBasedLayer(sequenceState):
                                            if sequenceState.layerNegotiationState.remotelyRequestedLayer != layerSupport {
                                                let updatedNegotiationState = sequenceState.layerNegotiationState.withUpdatedRemotelyRequestedLayer(layerSupport)
                                                updatedState = updatedState.withUpdatedEmbeddedState(.sequenceBasedLayer(sequenceState.withUpdatedLayerNegotiationState(updatedNegotiationState)))
                                                
                                                updatedState = secretChatCheckLayerNegotiationIfNeeded(transaction: transaction, peerId: peerId, state: updatedState)
                                            }
                                    }
                                case let .setMessageAutoremoveTimeout(timeout):
                                    updatedPeer = updatedPeer.withUpdatedMessageAutoremoveTimeout(timeout == 0 ? nil : timeout)
                                    updatedState = updatedState.withUpdatedMessageAutoremoveTimeout(timeout == 0 ? nil : timeout)
                                case let .rekeyAction(action):
                                    updatedState = secretChatAdvanceRekeySessionIfNeeded(encryptionProvider: encryptionProvider, transaction: transaction, peerId: peerId, state: updatedState, action: action)
                                case let .deleteMessages(globallyUniqueIds):
                                    var messageIds: [MessageId] = []
                                    for id in globallyUniqueIds {
                                        if let messageId = transaction.messageIdForGloballyUniqueMessageId(peerId: peerId, id: id) {
                                            messageIds.append(messageId)
                                        }
                                    }
                                    if !messageIds.isEmpty {
                                        var filteredMessageIds = messageIds
                                        outer: for i in (0 ..< filteredMessageIds.count).reversed() {
                                            if let message = transaction.getMessage(filteredMessageIds[i]) {
                                                for media in message.media {
                                                    if let media = media as? TelegramMediaAction {
                                                        if case .historyScreenshot = media.action {
                                                            filteredMessageIds.remove(at: i)
                                                            continue outer
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: filteredMessageIds)
                                    }
                                case .clearHistory:
                                    _internal_clearHistory(transaction: transaction, mediaBox: mediaBox, peerId: peerId, namespaces: .all)
                                case let .markMessagesContentAsConsumed(globallyUniqueIds):
                                    var messageIds: [MessageId] = []
                                    for id in globallyUniqueIds {
                                        if let messageId = transaction.messageIdForGloballyUniqueMessageId(peerId: peerId, id: id) {
                                            messageIds.append(messageId)
                                        }
                                    }
                                    for messageId in messageIds {
                                        markMessageContentAsConsumedRemotely(transaction: transaction, messageId: messageId)
                                    }
                                default:
                                    break
                            }
                        }
                        
                        removeTagLocalIndices.append(entry.tagLocalIndex)
                        
                        if let sequenceInfo = operation.sequenceInfo {
                            if maxAcknowledgedCanonicalOperationIndex == nil || maxAcknowledgedCanonicalOperationIndex! < sequenceInfo.topReceivedOperationIndex {
                                maxAcknowledgedCanonicalOperationIndex = sequenceInfo.topReceivedOperationIndex
                            }
                        }
                        
                        if let message = message {
                            for (resource, data) in resources {
                                mediaBox.storeResourceData(resource.id, data: data)
                            }
                            let _ = transaction.addMessages([message], location: .Random)
                            addedMessages.append(message)
                        } else if contentParsingError {
                            Logger.shared.log("SecretChat", "Couldn't parse secret message content")
                        }
                    } catch let error {
                        if let error = error as? MessageParsingError {
                            switch error {
                                case .contentParsingError:
                                    Logger.shared.log("SecretChat", "Couldn't parse secret message payload")
                                    removeTagLocalIndices.append(entry.tagLocalIndex)
                                    return true
                                case .unsupportedLayer:
                                    return false
                                case .invalidChatState:
                                    removeTagLocalIndices.append(entry.tagLocalIndex)
                                    return false
                                case .alreadyProcessedMessageInSequenceBasedLayer:
                                    removeTagLocalIndices.append(entry.tagLocalIndex)
                                    return true
                                case .holesInSequenceBasedLayer:
                                    Logger.shared.log("SecretChat", "Found holes in incoming operation sequence")
                                    return false
                                case .secretChatCorruption:
                                    Logger.shared.log("SecretChat", "Secret chat corrupted")
                                    return false
                            }
                        } else {
                            assertionFailure()
                        }
                    }
                } else {
                    assertionFailure()
                }
                return true
            })
        }
        for index in removeTagLocalIndices {
            let removed = transaction.operationLogRemoveEntry(peerId: peerId, tag: OperationLogTags.SecretIncomingDecrypted, tagLocalIndex: index)
            assert(removed)
        }
        if let maxAcknowledgedCanonicalOperationIndex = maxAcknowledgedCanonicalOperationIndex {
            switch updatedState.embeddedState {
                case let .sequenceBasedLayer(sequenceState):
                    let tagLocalIndex = max(-1, sequenceState.outgoingOperationIndexFromCanonicalOperationIndex(maxAcknowledgedCanonicalOperationIndex) - 1)
                    if tagLocalIndex >= 0 {
                        Logger.shared.log("SecretChat", "peer \(peerId) dropping acknowledged operations <= \(tagLocalIndex)")
                        transaction.operationLogRemoveEntries(peerId: peerId, tag: OperationLogTags.SecretOutgoing, withTagLocalIndicesEqualToOrLowerThan: tagLocalIndex)
                    }
                default:
                    break
            }
        }
        if updatedState != state {
            transaction.setPeerChatState(peerId, state: updatedState)
            updatedPeer = updatedPeer.withUpdatedEmbeddedState(updatedState.embeddedState.peerState)
        }
        if !peer.isEqual(updatedPeer) {
            updatePeers(transaction: transaction, peers: [updatedPeer], update: { _, updated in
                return updated
            })
        }
        return SecretChatOperationProcessResult(addedMessages: addedMessages)
    } else {
        assertionFailure()
        return SecretChatOperationProcessResult(addedMessages: [])
    }
}

extension SecretChatServiceAction {
    init?(_ apiMessage: SecretApi8.DecryptedMessage) {
        switch apiMessage {
            case .decryptedMessage:
                return nil
            case let .decryptedMessageService(_, _, action):
                switch action {
                    case let .decryptedMessageActionDeleteMessages(randomIds):
                        self = .deleteMessages(globallyUniqueIds: randomIds)
                    case .decryptedMessageActionFlushHistory:
                        self = .clearHistory
                    case let .decryptedMessageActionNotifyLayer(layer):
                        self = .reportLayerSupport(layer)
                    case let .decryptedMessageActionReadMessages(randomIds):
                        self = .markMessagesContentAsConsumed(globallyUniqueIds: randomIds)
                    case .decryptedMessageActionScreenshotMessages:
                        return nil
                    case let .decryptedMessageActionSetMessageTTL(ttlSeconds):
                        self = .setMessageAutoremoveTimeout(ttlSeconds)
                }
        }
    }
}

extension SecretChatServiceAction {
    init?(_ apiMessage: SecretApi46.DecryptedMessage) {
        switch apiMessage {
            case .decryptedMessage:
                return nil
            case let .decryptedMessageService(_, action):
                switch action {
                    case let .decryptedMessageActionDeleteMessages(randomIds):
                        self = .deleteMessages(globallyUniqueIds: randomIds)
                    case .decryptedMessageActionFlushHistory:
                        self = .clearHistory
                    case let .decryptedMessageActionNotifyLayer(layer):
                        self = .reportLayerSupport(layer)
                    case let .decryptedMessageActionReadMessages(randomIds):
                        self = .markMessagesContentAsConsumed(globallyUniqueIds: randomIds)
                    case .decryptedMessageActionScreenshotMessages:
                        return nil
                    case let .decryptedMessageActionSetMessageTTL(ttlSeconds):
                        self = .setMessageAutoremoveTimeout(ttlSeconds)
                    case let .decryptedMessageActionResend(startSeqNo, endSeqNo):
                        self = .resendOperations(fromSeq: startSeqNo, toSeq: endSeqNo)
                    case let .decryptedMessageActionRequestKey(exchangeId, gA):
                        self = .rekeyAction(.pfsRequestKey(rekeySessionId: exchangeId, gA: MemoryBuffer(gA)))
                    case let .decryptedMessageActionAcceptKey(exchangeId, gB, keyFingerprint):
                        self = .rekeyAction(.pfsAcceptKey(rekeySessionId: exchangeId, gB: MemoryBuffer(gB), keyFingerprint: keyFingerprint))
                    case let .decryptedMessageActionCommitKey(exchangeId, keyFingerprint):
                        self = .rekeyAction(.pfsCommitKey(rekeySessionId: exchangeId, keyFingerprint: keyFingerprint))
                    case let .decryptedMessageActionAbortKey(exchangeId):
                        self = .rekeyAction(.pfsAbortSession(rekeySessionId: exchangeId))
                    case .decryptedMessageActionNoop:
                        return nil
                }
        }
    }
}

extension SecretChatServiceAction {
    init?(_ apiMessage: SecretApi73.DecryptedMessage) {
        switch apiMessage {
            case .decryptedMessage:
                return nil
            case let .decryptedMessageService(_, action):
                switch action {
                case let .decryptedMessageActionDeleteMessages(randomIds):
                    self = .deleteMessages(globallyUniqueIds: randomIds)
                case .decryptedMessageActionFlushHistory:
                    self = .clearHistory
                case let .decryptedMessageActionNotifyLayer(layer):
                    self = .reportLayerSupport(layer)
                case let .decryptedMessageActionReadMessages(randomIds):
                    self = .markMessagesContentAsConsumed(globallyUniqueIds: randomIds)
                case .decryptedMessageActionScreenshotMessages:
                    return nil
                case let .decryptedMessageActionSetMessageTTL(ttlSeconds):
                    self = .setMessageAutoremoveTimeout(ttlSeconds)
                case let .decryptedMessageActionResend(startSeqNo, endSeqNo):
                    self = .resendOperations(fromSeq: startSeqNo, toSeq: endSeqNo)
                case let .decryptedMessageActionRequestKey(exchangeId, gA):
                    self = .rekeyAction(.pfsRequestKey(rekeySessionId: exchangeId, gA: MemoryBuffer(gA)))
                case let .decryptedMessageActionAcceptKey(exchangeId, gB, keyFingerprint):
                    self = .rekeyAction(.pfsAcceptKey(rekeySessionId: exchangeId, gB: MemoryBuffer(gB), keyFingerprint: keyFingerprint))
                case let .decryptedMessageActionCommitKey(exchangeId, keyFingerprint):
                    self = .rekeyAction(.pfsCommitKey(rekeySessionId: exchangeId, keyFingerprint: keyFingerprint))
                case let .decryptedMessageActionAbortKey(exchangeId):
                    self = .rekeyAction(.pfsAbortSession(rekeySessionId: exchangeId))
                case .decryptedMessageActionNoop:
                    return nil
            }
        }
    }
}

extension SecretChatServiceAction {
    init?(_ apiMessage: SecretApi101.DecryptedMessage) {
        switch apiMessage {
            case .decryptedMessage:
                return nil
            case let .decryptedMessageService(_, action):
                switch action {
                case let .decryptedMessageActionDeleteMessages(randomIds):
                    self = .deleteMessages(globallyUniqueIds: randomIds)
                case .decryptedMessageActionFlushHistory:
                    self = .clearHistory
                case let .decryptedMessageActionNotifyLayer(layer):
                    self = .reportLayerSupport(layer)
                case let .decryptedMessageActionReadMessages(randomIds):
                    self = .markMessagesContentAsConsumed(globallyUniqueIds: randomIds)
                case .decryptedMessageActionScreenshotMessages:
                    return nil
                case let .decryptedMessageActionSetMessageTTL(ttlSeconds):
                    self = .setMessageAutoremoveTimeout(ttlSeconds)
                case let .decryptedMessageActionResend(startSeqNo, endSeqNo):
                    self = .resendOperations(fromSeq: startSeqNo, toSeq: endSeqNo)
                case let .decryptedMessageActionRequestKey(exchangeId, gA):
                    self = .rekeyAction(.pfsRequestKey(rekeySessionId: exchangeId, gA: MemoryBuffer(gA)))
                case let .decryptedMessageActionAcceptKey(exchangeId, gB, keyFingerprint):
                    self = .rekeyAction(.pfsAcceptKey(rekeySessionId: exchangeId, gB: MemoryBuffer(gB), keyFingerprint: keyFingerprint))
                case let .decryptedMessageActionCommitKey(exchangeId, keyFingerprint):
                    self = .rekeyAction(.pfsCommitKey(rekeySessionId: exchangeId, keyFingerprint: keyFingerprint))
                case let .decryptedMessageActionAbortKey(exchangeId):
                    self = .rekeyAction(.pfsAbortSession(rekeySessionId: exchangeId))
                case .decryptedMessageActionNoop:
                    return nil
            }
        }
    }
}

extension StoreMessage {
    convenience init?(peerId: PeerId, authorId: PeerId, tagLocalIndex: Int32, timestamp: Int32, apiMessage: SecretApi8.DecryptedMessage, file: SecretChatFileReference?) {
        switch apiMessage {
            case let .decryptedMessage(randomId, _, message, _):
                self.init(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: authorId, text: message, attributes: [], media: [])
            case let .decryptedMessageService(randomId, _, action):
                switch action {
                    case .decryptedMessageActionDeleteMessages:
                        return nil
                    case .decryptedMessageActionFlushHistory:
                        return nil
                    case .decryptedMessageActionNotifyLayer:
                        return nil
                    case .decryptedMessageActionReadMessages:
                        return nil
                    case .decryptedMessageActionScreenshotMessages:
                        self.init(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: authorId, text: "", attributes: [], media: [TelegramMediaAction(action: .historyScreenshot)])
                    case let .decryptedMessageActionSetMessageTTL(ttlSeconds):
                        self.init(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: authorId, text: "", attributes: [], media: [TelegramMediaAction(action: .messageAutoremoveTimeoutUpdated(ttlSeconds))])
                }
        }
    }
}

extension TelegramMediaFileAttribute {
    init?(_ apiAttribute: SecretApi46.DocumentAttribute) {
        switch apiAttribute {
            case .documentAttributeAnimated:
                self = .Animated
            case let .documentAttributeAudio(flags, duration, title, performer, waveform):
                let isVoice = (flags & (1 << 10)) != 0
                let waveformBuffer: Data? = waveform?.makeData()
                self = .Audio(isVoice: isVoice, duration: Int(duration), title: title, performer: performer, waveform: waveformBuffer)
            case let .documentAttributeFilename(fileName):
                self = .FileName(fileName: fileName)
            case let .documentAttributeImageSize(w, h):
                self = .ImageSize(size: PixelDimensions(width: w, height: h))
            case let .documentAttributeSticker(alt, stickerset):
                let packReference: StickerPackReference?
                switch stickerset {
                    case .inputStickerSetEmpty:
                        packReference = nil
                    case let .inputStickerSetShortName(shortName):
                        packReference = .name(shortName)
                }
                self = .Sticker(displayText: alt, packReference: packReference, maskData: nil)
            case let .documentAttributeVideo(duration, w, h):
                self = .Video(duration: Int(duration), size: PixelDimensions(width: w, height: h), flags: [])
        }
    }
}

extension TelegramMediaFileAttribute {
    init?(_ apiAttribute: SecretApi73.DocumentAttribute) {
        switch apiAttribute {
            case .documentAttributeAnimated:
                self = .Animated
            case let .documentAttributeAudio(flags, duration, title, performer, waveform):
                let isVoice = (flags & (1 << 10)) != 0
                let waveformBuffer: Data? = waveform?.makeData()
                self = .Audio(isVoice: isVoice, duration: Int(duration), title: title, performer: performer, waveform: waveformBuffer)
            case let .documentAttributeFilename(fileName):
                self = .FileName(fileName: fileName)
            case let .documentAttributeImageSize(w, h):
                self = .ImageSize(size: PixelDimensions(width: w, height: h))
            case let .documentAttributeSticker(alt, stickerset):
                let packReference: StickerPackReference?
                switch stickerset {
                case .inputStickerSetEmpty:
                    packReference = nil
                case let .inputStickerSetShortName(shortName):
                    packReference = .name(shortName)
                }
                self = .Sticker(displayText: alt, packReference: packReference, maskData: nil)
            case let .documentAttributeVideo(flags, duration, w, h):
                var videoFlags: TelegramMediaVideoFlags = []
                if (flags & (1 << 0)) != 0 {
                    videoFlags.insert(.instantRoundVideo)
                }
                self = .Video(duration: Int(duration), size: PixelDimensions(width: w, height: h), flags: videoFlags)
        }
    }
}

extension TelegramMediaFileAttribute {
    init?(_ apiAttribute: SecretApi101.DocumentAttribute) {
        switch apiAttribute {
            case .documentAttributeAnimated:
                self = .Animated
            case let .documentAttributeAudio(flags, duration, title, performer, waveform):
                let isVoice = (flags & (1 << 10)) != 0
                let waveformBuffer: Data? = waveform?.makeData()
                self = .Audio(isVoice: isVoice, duration: Int(duration), title: title, performer: performer, waveform: waveformBuffer)
            case let .documentAttributeFilename(fileName):
                self = .FileName(fileName: fileName)
            case let .documentAttributeImageSize(w, h):
                self = .ImageSize(size: PixelDimensions(width: w, height: h))
            case let .documentAttributeSticker(alt, stickerset):
                let packReference: StickerPackReference?
                switch stickerset {
                case .inputStickerSetEmpty:
                    packReference = nil
                case let .inputStickerSetShortName(shortName):
                    packReference = .name(shortName)
                }
                self = .Sticker(displayText: alt, packReference: packReference, maskData: nil)
            case let .documentAttributeVideo(flags, duration, w, h):
                var videoFlags: TelegramMediaVideoFlags = []
                if (flags & (1 << 0)) != 0 {
                    videoFlags.insert(.instantRoundVideo)
                }
                self = .Video(duration: Int(duration), size: PixelDimensions(width: w, height: h), flags: videoFlags)
        }
    }
}

private func parseEntities(_ entities: [SecretApi46.MessageEntity]?) -> TextEntitiesMessageAttribute {
    var result: [MessageTextEntity] = []
    if let entities = entities {
        for entity in entities {
            switch entity {
                case let .messageEntityMention(offset, length):
                    result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Mention))
                case let .messageEntityHashtag(offset, length):
                    result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Hashtag))
                case let .messageEntityBotCommand(offset, length):
                    result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .BotCommand))
                case let .messageEntityUrl(offset, length):
                    result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Url))
                case let .messageEntityEmail(offset, length):
                    result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Email))
                case let .messageEntityBold(offset, length):
                    result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Bold))
                case let .messageEntityItalic(offset, length):
                    result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Italic))
                case let .messageEntityCode(offset, length):
                    result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Code))
                case let .messageEntityPre(offset, length, _):
                    result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Pre))
                case let .messageEntityTextUrl(offset, length, url):
                    result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .TextUrl(url: url)))
                case .messageEntityUnknown:
                    break
            }
        }
    }
    return TextEntitiesMessageAttribute(entities: result)
}

private func maximumMediaAutoremoveTimeout(_ media: [Media]) -> Int32 {
    var maxDuration: Int32 = 0
    for media in media {
        if let file = media as? TelegramMediaFile {
            if let duration = file.duration {
                maxDuration = max(maxDuration, duration)
            }
        }
    }
    return maxDuration
}

private func parseMessage(peerId: PeerId, authorId: PeerId, tagLocalIndex: Int32, timestamp: Int32, apiMessage: SecretApi46.DecryptedMessage, file: SecretChatFileReference?, messageIdForGloballyUniqueMessageId: (Int64) -> MessageId?) -> (StoreMessage, [(MediaResource, Data)])? {
    switch apiMessage {
        case let .decryptedMessage(flags, randomId, ttl, message, media, entities, viaBotName, replyToRandomId):
            var text = message
            var parsedMedia: [Media] = []
            var attributes: [MessageAttribute] = []
            var resources: [(MediaResource, Data)] = []
            
            attributes.append(parseEntities(entities))
            
            if let viaBotName = viaBotName, !viaBotName.isEmpty {
                attributes.append(InlineBotMessageAttribute(peerId: nil, title: viaBotName))
            }
            
            if (flags & 1 << 5) != 0 {
                attributes.append(NotificationInfoMessageAttribute(flags: .muted))
            }
            
            if let media = media {
                switch media {
                    case let .decryptedMessageMediaPhoto(thumb, thumbW, thumbH, w, h, size, key, iv, caption):
                        if !caption.isEmpty {
                            text = caption
                        }
                        if let file = file {
                            var representations: [TelegramMediaImageRepresentation] = []
                            if thumb.size != 0 {
                                let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: thumbW, height: thumbH), resource: resource, progressiveSizes: [], immediateThumbnailData: nil))
                                resources.append((resource, thumb.makeData()))
                            }
                            representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: file.resource(key: SecretFileEncryptionKey(aesKey: key.makeData(), aesIv: iv.makeData()), decryptedSize: size), progressiveSizes: [], immediateThumbnailData: nil))
                            let image = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudSecretImage, id: file.id), representations: representations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                            parsedMedia.append(image)
                        }
                    case let .decryptedMessageMediaAudio(duration, mimeType, size, key, iv):
                        if let file = file {
                            let fileMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudSecretFile, id: file.id), partialReference: nil, resource: file.resource(key: SecretFileEncryptionKey(aesKey: key.makeData(), aesIv: iv.makeData()), decryptedSize: size), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int(size), attributes: [TelegramMediaFileAttribute.Audio(isVoice: true, duration: Int(duration), title: nil, performer: nil, waveform: nil)])
                            parsedMedia.append(fileMedia)
                        }
                    case let .decryptedMessageMediaDocument(thumb, thumbW, thumbH, mimeType, size, key, iv, attributes, caption):
                        if !caption.isEmpty {
                            text = caption
                        }
                        if let file = file {
                            var parsedAttributes: [TelegramMediaFileAttribute] = []
                            for attribute in attributes {
                                if let parsedAttribute = TelegramMediaFileAttribute(attribute) {
                                    parsedAttributes.append(parsedAttribute)
                                }
                            }
                            var previewRepresentations: [TelegramMediaImageRepresentation] = []
                            if thumb.size != 0 {
                                let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: thumbW, height: thumbH), resource: resource, progressiveSizes: [], immediateThumbnailData: nil))
                                resources.append((resource, thumb.makeData()))
                            }
                            let fileMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudSecretFile, id: file.id), partialReference: nil, resource: file.resource(key: SecretFileEncryptionKey(aesKey: key.makeData(), aesIv: iv.makeData()), decryptedSize: size), previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int(size), attributes: parsedAttributes)
                            parsedMedia.append(fileMedia)
                        }
                    case let .decryptedMessageMediaVideo(thumb, thumbW, thumbH, duration, mimeType, w, h, size, key, iv, caption):
                        if !caption.isEmpty {
                            text = caption
                        }
                        if let file = file {
                            let parsedAttributes: [TelegramMediaFileAttribute] = [.Video(duration: Int(duration), size: PixelDimensions(width: w, height: h), flags: []), .FileName(fileName: "video.mov")]
                            var previewRepresentations: [TelegramMediaImageRepresentation] = []
                            if thumb.size != 0 {
                                let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: thumbW, height: thumbH), resource: resource, progressiveSizes: [], immediateThumbnailData: nil))
                                resources.append((resource, thumb.makeData()))
                            }
                            let fileMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudSecretFile, id: file.id), partialReference: nil, resource: file.resource(key: SecretFileEncryptionKey(aesKey: key.makeData(), aesIv: iv.makeData()), decryptedSize: size), previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int(size), attributes: parsedAttributes)
                            parsedMedia.append(fileMedia)
                        }
                    case let .decryptedMessageMediaExternalDocument(id, accessHash, _, mimeType, size, thumb, dcId, attributes):
                        var parsedAttributes: [TelegramMediaFileAttribute] = []
                        for attribute in attributes {
                            if let parsedAttribute = TelegramMediaFileAttribute(attribute) {
                                parsedAttributes.append(parsedAttribute)
                            }
                        }
                        var previewRepresentations: [TelegramMediaImageRepresentation] = []
                        switch thumb {
                            case let .photoSize(_, location, w, h, size):
                                switch location {
                                    case let .fileLocation(dcId, volumeId, localId, secret):
                                        previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: CloudFileMediaResource(datacenterId: Int(dcId), volumeId: volumeId, localId: localId, secret: secret, size: size == 0 ? nil : Int(size), fileReference: nil), progressiveSizes: [], immediateThumbnailData: nil))
                                    case .fileLocationUnavailable:
                                        break
                                }
                            case let .photoCachedSize(_, location, w, h, bytes):
                                if bytes.size > 0 {
                                    switch location {
                                        case let .fileLocation(dcId, volumeId, localId, secret):
                                           let resource = CloudFileMediaResource(datacenterId: Int(dcId), volumeId: volumeId, localId: localId, secret: secret, size: bytes.size, fileReference: nil)
                                           resources.append((resource, bytes.makeData()))
                                           previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: resource, progressiveSizes: [], immediateThumbnailData: nil))
                                        case .fileLocationUnavailable:
                                            break
                                    }
                                }
                            default:
                                break
                        }
                        let fileMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: id), partialReference: nil, resource: CloudDocumentMediaResource(datacenterId: Int(dcId), fileId: id, accessHash: accessHash, size: Int(size), fileReference: nil, fileName: nil), previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int(size), attributes: parsedAttributes)
                        parsedMedia.append(fileMedia)
                    case let .decryptedMessageMediaWebPage(url):
                        parsedMedia.append(TelegramMediaWebpage(webpageId: MediaId(namespace: Namespaces.Media.LocalWebpage, id: Int64.random(in: Int64.min ... Int64.max)), content: .Pending(0, url)))
                    case let .decryptedMessageMediaGeoPoint(lat, long):
                        parsedMedia.append(TelegramMediaMap(latitude: lat, longitude: long, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: nil, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil))
                    case let .decryptedMessageMediaContact(phoneNumber, firstName, lastName, userId):
                        parsedMedia.append(TelegramMediaContact(firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, peerId: userId == 0 ? nil : PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(Int64(userId))), vCardData: nil))
                    case let .decryptedMessageMediaVenue(lat, long, title, address, provider, venueId):
                        parsedMedia.append(TelegramMediaMap(latitude: lat, longitude: long, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: MapVenue(title: title, address: address, provider: provider, id: venueId, type: nil), liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil))
                    case .decryptedMessageMediaEmpty:
                        break
                }
            }
            
            if ttl > 0 {
                attributes.append(AutoremoveTimeoutMessageAttribute(timeout: ttl, countdownBeginTime: nil))
            }
            
            if let replyToRandomId = replyToRandomId, let replyMessageId = messageIdForGloballyUniqueMessageId(replyToRandomId) {
                attributes.append(ReplyMessageAttribute(messageId: replyMessageId, threadMessageId: nil))
            }

            var entitiesAttribute: TextEntitiesMessageAttribute?
            for attribute in attributes {
                if let attribute = attribute as? TextEntitiesMessageAttribute {
                    entitiesAttribute = attribute
                    break
                }
            }
            
            let (tags, globalTags) = tagsForStoreMessage(incoming: true, attributes: attributes, media: parsedMedia, textEntities: entitiesAttribute?.entities, isPinned: false)

            return (StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: tags, globalTags: globalTags, localTags: [], forwardInfo: nil, authorId: authorId, text: text, attributes: attributes, media: parsedMedia), resources)
        case let .decryptedMessageService(randomId, action):
            switch action {
                case .decryptedMessageActionDeleteMessages:
                    return nil
                case .decryptedMessageActionFlushHistory:
                    return nil
                case .decryptedMessageActionNotifyLayer:
                    return nil
                case .decryptedMessageActionReadMessages:
                    return nil
                case .decryptedMessageActionScreenshotMessages:
                    return (StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: authorId, text: "", attributes: [], media: [TelegramMediaAction(action: .historyScreenshot)]), [])
                case let .decryptedMessageActionSetMessageTTL(ttlSeconds):
                    return (StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: authorId, text: "", attributes: [], media: [TelegramMediaAction(action: .messageAutoremoveTimeoutUpdated(ttlSeconds))]), [])
                case .decryptedMessageActionResend:
                    return nil
                case .decryptedMessageActionRequestKey:
                    return nil
                case .decryptedMessageActionAcceptKey:
                    return nil
                case .decryptedMessageActionCommitKey:
                    return nil
                case .decryptedMessageActionAbortKey:
                    return nil
                case .decryptedMessageActionNoop:
                    return nil
            }
    }
}

private func parseEntities(_ entities: [SecretApi73.MessageEntity]) -> TextEntitiesMessageAttribute {
    var result: [MessageTextEntity] = []
    for entity in entities {
        switch entity {
            case let .messageEntityMention(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Mention))
            case let .messageEntityHashtag(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Hashtag))
            case let .messageEntityBotCommand(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .BotCommand))
            case let .messageEntityUrl(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Url))
            case let .messageEntityEmail(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Email))
            case let .messageEntityBold(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Bold))
            case let .messageEntityItalic(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Italic))
            case let .messageEntityCode(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Code))
            case let .messageEntityPre(offset, length, _):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Pre))
            case let .messageEntityTextUrl(offset, length, url):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .TextUrl(url: url)))
            case .messageEntityUnknown:
                break
        }
    }
    return TextEntitiesMessageAttribute(entities: result)
}

private func parseMessage(peerId: PeerId, authorId: PeerId, tagLocalIndex: Int32, timestamp: Int32, apiMessage: SecretApi73.DecryptedMessage, file: SecretChatFileReference?, messageIdForGloballyUniqueMessageId: (Int64) -> MessageId?) -> (StoreMessage, [(MediaResource, Data)])? {
    switch apiMessage {
        case let .decryptedMessage(flags, randomId, ttl, message, media, entities, viaBotName, replyToRandomId, groupedId):
            var text = message
            var parsedMedia: [Media] = []
            var attributes: [MessageAttribute] = []
            var resources: [(MediaResource, Data)] = []
            
            if let entitiesAttribute = entities.flatMap(parseEntities) {
                attributes.append(entitiesAttribute)
            }
            
            if let viaBotName = viaBotName, !viaBotName.isEmpty {
                attributes.append(InlineBotMessageAttribute(peerId: nil, title: viaBotName))
            }
            
            if (flags & 1 << 5) != 0 {
                attributes.append(NotificationInfoMessageAttribute(flags: .muted))
            }
            
            if let media = media {
                switch media {
                    case let .decryptedMessageMediaPhoto(thumb, thumbW, thumbH, w, h, size, key, iv, caption):
                        if !caption.isEmpty {
                            text = caption
                        }
                        if let file = file {
                            var representations: [TelegramMediaImageRepresentation] = []
                            if thumb.size != 0 {
                                let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: thumbW, height: thumbH), resource: resource, progressiveSizes: [], immediateThumbnailData: nil))
                                resources.append((resource, thumb.makeData()))
                            }
                            representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: file.resource(key: SecretFileEncryptionKey(aesKey: key.makeData(), aesIv: iv.makeData()), decryptedSize: size), progressiveSizes: [], immediateThumbnailData: nil))
                            let image = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudSecretImage, id: file.id), representations: representations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                            parsedMedia.append(image)
                        }
                    case let .decryptedMessageMediaAudio(duration, mimeType, size, key, iv):
                        if let file = file {
                            let fileMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudSecretFile, id: file.id), partialReference: nil, resource: file.resource(key: SecretFileEncryptionKey(aesKey: key.makeData(), aesIv: iv.makeData()), decryptedSize: size), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int(size), attributes: [TelegramMediaFileAttribute.Audio(isVoice: true, duration: Int(duration), title: nil, performer: nil, waveform: nil)])
                            parsedMedia.append(fileMedia)
                            attributes.append(ConsumableContentMessageAttribute(consumed: false))
                        }
                    case let .decryptedMessageMediaDocument(thumb, thumbW, thumbH, mimeType, size, key, iv, decryptedAttributes, caption):
                        if !caption.isEmpty {
                            text = caption
                        }
                        if let file = file {
                            var parsedAttributes: [TelegramMediaFileAttribute] = []
                            for attribute in decryptedAttributes {
                                if let parsedAttribute = TelegramMediaFileAttribute(attribute) {
                                    parsedAttributes.append(parsedAttribute)
                                }
                            }
                            var previewRepresentations: [TelegramMediaImageRepresentation] = []
                            if thumb.size != 0 {
                                let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: thumbW, height: thumbH), resource: resource, progressiveSizes: [], immediateThumbnailData: nil))
                                resources.append((resource, thumb.makeData()))
                            }
                            let fileMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudSecretFile, id: file.id), partialReference: nil, resource: file.resource(key: SecretFileEncryptionKey(aesKey: key.makeData(), aesIv: iv.makeData()), decryptedSize: size), previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int(size), attributes: parsedAttributes)
                            parsedMedia.append(fileMedia)
                            
                            loop: for attr in parsedAttributes {
                                switch attr {
                                case let .Video(_, _, flags):
                                    if flags.contains(.instantRoundVideo) {
                                        attributes.append(ConsumableContentMessageAttribute(consumed: false))
                                    }
                                    break loop
                                case let .Audio(isVoice, _, _, _, _):
                                    if isVoice {
                                        attributes.append(ConsumableContentMessageAttribute(consumed: false))
                                    }
                                default:
                                    break
                                }
                            }
                        }
                    case let .decryptedMessageMediaVideo(thumb, thumbW, thumbH, duration, mimeType, w, h, size, key, iv, caption):
                        if !caption.isEmpty {
                            text = caption
                        }
                        if let file = file {
                            let parsedAttributes: [TelegramMediaFileAttribute] = [.Video(duration: Int(duration), size: PixelDimensions(width: w, height: h), flags: []), .FileName(fileName: "video.mov")]
                            var previewRepresentations: [TelegramMediaImageRepresentation] = []
                            if thumb.size != 0 {
                                let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: thumbW, height: thumbH), resource: resource, progressiveSizes: [], immediateThumbnailData: nil))
                                resources.append((resource, thumb.makeData()))
                            }
                            let fileMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudSecretFile, id: file.id), partialReference: nil, resource: file.resource(key: SecretFileEncryptionKey(aesKey: key.makeData(), aesIv: iv.makeData()), decryptedSize: size), previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int(size), attributes: parsedAttributes)
                            parsedMedia.append(fileMedia)
                        }
                    case let .decryptedMessageMediaExternalDocument(id, accessHash, _, mimeType, size, thumb, dcId, attributes):
                        var parsedAttributes: [TelegramMediaFileAttribute] = []
                        for attribute in attributes {
                            if let parsedAttribute = TelegramMediaFileAttribute(attribute) {
                                parsedAttributes.append(parsedAttribute)
                            }
                        }
                        var previewRepresentations: [TelegramMediaImageRepresentation] = []
                        switch thumb {
                            case let .photoSize(_, location, w, h, size):
                                switch location {
                                    case let .fileLocation(dcId, volumeId, localId, secret):
                                        previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: CloudFileMediaResource(datacenterId: Int(dcId), volumeId: volumeId, localId: localId, secret: secret, size: size == 0 ? nil : Int(size), fileReference: nil), progressiveSizes: [], immediateThumbnailData: nil))
                                    case .fileLocationUnavailable:
                                        break
                                }
                            case let .photoCachedSize(_, location, w, h, bytes):
                                if bytes.size > 0 {
                                    switch location {
                                        case let .fileLocation(dcId, volumeId, localId, secret):
                                            let resource = CloudFileMediaResource(datacenterId: Int(dcId), volumeId: volumeId, localId: localId, secret: secret, size: bytes.size, fileReference: nil)
                                            resources.append((resource, bytes.makeData()))
                                            previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: resource, progressiveSizes: [], immediateThumbnailData: nil))
                                        case .fileLocationUnavailable:
                                            break
                                    }
                                }
                            default:
                                break
                        }
                        let fileMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: id), partialReference: nil, resource: CloudDocumentMediaResource(datacenterId: Int(dcId), fileId: id, accessHash: accessHash, size: Int(size), fileReference: nil, fileName: nil), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int(size), attributes: parsedAttributes)
                        parsedMedia.append(fileMedia)
                    case let .decryptedMessageMediaWebPage(url):
                        parsedMedia.append(TelegramMediaWebpage(webpageId: MediaId(namespace: Namespaces.Media.LocalWebpage, id: Int64.random(in: Int64.min ... Int64.max)), content: .Pending(0, url)))
                    case let .decryptedMessageMediaGeoPoint(lat, long):
                        parsedMedia.append(TelegramMediaMap(latitude: lat, longitude: long, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: nil, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil))
                    case let .decryptedMessageMediaContact(phoneNumber, firstName, lastName, userId):
                        parsedMedia.append(TelegramMediaContact(firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, peerId: userId == 0 ? nil : PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(Int64(userId))), vCardData: nil))
                    case let .decryptedMessageMediaVenue(lat, long, title, address, provider, venueId):
                        parsedMedia.append(TelegramMediaMap(latitude: lat, longitude: long, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: MapVenue(title: title, address: address, provider: provider, id: venueId, type: nil), liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil))
                    case .decryptedMessageMediaEmpty:
                        break
                }
            }
            
            if ttl > 0 {
                attributes.append(AutoremoveTimeoutMessageAttribute(timeout: ttl, countdownBeginTime: nil))
            }
            
            var groupingKey: Int64?
            if let groupedId = groupedId {
                inner: for media in parsedMedia {
                    if let _ = media as? TelegramMediaImage {
                        groupingKey = groupedId
                        break inner
                    } else if let _ = media as? TelegramMediaFile {
                        groupingKey = groupedId
                        break inner
                    }
                }
            }
            
            if let replyToRandomId = replyToRandomId, let replyMessageId = messageIdForGloballyUniqueMessageId(replyToRandomId) {
                attributes.append(ReplyMessageAttribute(messageId: replyMessageId, threadMessageId: nil))
            }
            
            var entitiesAttribute: TextEntitiesMessageAttribute?
            for attribute in attributes {
                if let attribute = attribute as? TextEntitiesMessageAttribute {
                    entitiesAttribute = attribute
                    break
                }
            }
            
            let (tags, globalTags) = tagsForStoreMessage(incoming: true, attributes: attributes, media: parsedMedia, textEntities: entitiesAttribute?.entities, isPinned: false)
            
            return (StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, groupingKey: groupingKey, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: tags, globalTags: globalTags, localTags: [], forwardInfo: nil, authorId: authorId, text: text, attributes: attributes, media: parsedMedia), resources)
        case let .decryptedMessageService(randomId, action):
            switch action {
                case .decryptedMessageActionDeleteMessages:
                    return nil
                case .decryptedMessageActionFlushHistory:
                    return nil
                case .decryptedMessageActionNotifyLayer:
                    return nil
                case .decryptedMessageActionReadMessages:
                    return nil
                case .decryptedMessageActionScreenshotMessages:
                    return (StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: authorId, text: "", attributes: [], media: [TelegramMediaAction(action: .historyScreenshot)]), [])
                case let .decryptedMessageActionSetMessageTTL(ttlSeconds):
                    return (StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: authorId, text: "", attributes: [], media: [TelegramMediaAction(action: .messageAutoremoveTimeoutUpdated(ttlSeconds))]), [])
                case .decryptedMessageActionResend:
                    return nil
                case .decryptedMessageActionRequestKey:
                    return nil
                case .decryptedMessageActionAcceptKey:
                    return nil
                case .decryptedMessageActionCommitKey:
                    return nil
                case .decryptedMessageActionAbortKey:
                    return nil
                case .decryptedMessageActionNoop:
                    return nil
            }
    }
}

private func parseEntities(_ entities: [SecretApi101.MessageEntity]) -> TextEntitiesMessageAttribute {
    var result: [MessageTextEntity] = []
    for entity in entities {
        switch entity {
        case let .messageEntityMention(offset, length):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Mention))
        case let .messageEntityHashtag(offset, length):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Hashtag))
        case let .messageEntityBotCommand(offset, length):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .BotCommand))
        case let .messageEntityUrl(offset, length):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Url))
        case let .messageEntityEmail(offset, length):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Email))
        case let .messageEntityBold(offset, length):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Bold))
        case let .messageEntityItalic(offset, length):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Italic))
        case let .messageEntityCode(offset, length):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Code))
        case let .messageEntityPre(offset, length, _):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Pre))
        case let .messageEntityTextUrl(offset, length, url):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .TextUrl(url: url)))
        case let .messageEntityStrike(offset, length):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Strikethrough))
        case let .messageEntityUnderline(offset, length):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Underline))
        case let .messageEntityBlockquote(offset, length):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .BlockQuote))
        case .messageEntityUnknown:
            break
        }
    }
    return TextEntitiesMessageAttribute(entities: result)
}

private func parseMessage(peerId: PeerId, authorId: PeerId, tagLocalIndex: Int32, timestamp: Int32, apiMessage: SecretApi101.DecryptedMessage, file: SecretChatFileReference?, messageIdForGloballyUniqueMessageId: (Int64) -> MessageId?) -> (StoreMessage, [(MediaResource, Data)])? {
    switch apiMessage {
        case let .decryptedMessage(flags, randomId, ttl, message, media, entities, viaBotName, replyToRandomId, groupedId):
            var text = message
            var parsedMedia: [Media] = []
            var attributes: [MessageAttribute] = []
            var resources: [(MediaResource, Data)] = []
            
            if let entitiesAttribute = entities.flatMap(parseEntities) {
                attributes.append(entitiesAttribute)
            }
            
            if let viaBotName = viaBotName, !viaBotName.isEmpty {
                attributes.append(InlineBotMessageAttribute(peerId: nil, title: viaBotName))
            }
            
            if (flags & 1 << 5) != 0 {
                attributes.append(NotificationInfoMessageAttribute(flags: .muted))
            }
            
            if let media = media {
                switch media {
                    case let .decryptedMessageMediaPhoto(thumb, thumbW, thumbH, w, h, size, key, iv, caption):
                        if !caption.isEmpty {
                            text = caption
                        }
                        if let file = file {
                            var representations: [TelegramMediaImageRepresentation] = []
                            if thumb.size != 0 {
                                let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: thumbW, height: thumbH), resource: resource, progressiveSizes: [], immediateThumbnailData: nil))
                                resources.append((resource, thumb.makeData()))
                            }
                            representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: file.resource(key: SecretFileEncryptionKey(aesKey: key.makeData(), aesIv: iv.makeData()), decryptedSize: size), progressiveSizes: [], immediateThumbnailData: nil))
                            let image = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudSecretImage, id: file.id), representations: representations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                            parsedMedia.append(image)
                        }
                    case let .decryptedMessageMediaAudio(duration, mimeType, size, key, iv):
                        if let file = file {
                            let fileMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudSecretFile, id: file.id), partialReference: nil, resource: file.resource(key: SecretFileEncryptionKey(aesKey: key.makeData(), aesIv: iv.makeData()), decryptedSize: size), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int(size), attributes: [TelegramMediaFileAttribute.Audio(isVoice: true, duration: Int(duration), title: nil, performer: nil, waveform: nil)])
                            parsedMedia.append(fileMedia)
                            attributes.append(ConsumableContentMessageAttribute(consumed: false))
                        }
                    case let .decryptedMessageMediaDocument(thumb, thumbW, thumbH, mimeType, size, key, iv, decryptedAttributes, caption):
                        if !caption.isEmpty {
                            text = caption
                        }
                        if let file = file {
                            var parsedAttributes: [TelegramMediaFileAttribute] = []
                            for attribute in decryptedAttributes {
                                if let parsedAttribute = TelegramMediaFileAttribute(attribute) {
                                    parsedAttributes.append(parsedAttribute)
                                }
                            }
                            var previewRepresentations: [TelegramMediaImageRepresentation] = []
                            if thumb.size != 0 {
                                let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: thumbW, height: thumbH), resource: resource, progressiveSizes: [], immediateThumbnailData: nil))
                                resources.append((resource, thumb.makeData()))
                            }
                            let fileMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudSecretFile, id: file.id), partialReference: nil, resource: file.resource(key: SecretFileEncryptionKey(aesKey: key.makeData(), aesIv: iv.makeData()), decryptedSize: size), previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int(size), attributes: parsedAttributes)
                            parsedMedia.append(fileMedia)
                            
                            loop: for attr in parsedAttributes {
                                switch attr {
                                case let .Video(_, _, flags):
                                    if flags.contains(.instantRoundVideo) {
                                        attributes.append(ConsumableContentMessageAttribute(consumed: false))
                                    }
                                    break loop
                                case let .Audio(isVoice, _, _, _, _):
                                    if isVoice {
                                        attributes.append(ConsumableContentMessageAttribute(consumed: false))
                                    }
                                default:
                                    break
                                }
                            }
                        }
                    case let .decryptedMessageMediaVideo(thumb, thumbW, thumbH, duration, mimeType, w, h, size, key, iv, caption):
                        if !caption.isEmpty {
                            text = caption
                        }
                        if let file = file {
                            let parsedAttributes: [TelegramMediaFileAttribute] = [.Video(duration: Int(duration), size: PixelDimensions(width: w, height: h), flags: []), .FileName(fileName: "video.mov")]
                            var previewRepresentations: [TelegramMediaImageRepresentation] = []
                            if thumb.size != 0 {
                                let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: thumbW, height: thumbH), resource: resource, progressiveSizes: [], immediateThumbnailData: nil))
                                resources.append((resource, thumb.makeData()))
                            }
                            let fileMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudSecretFile, id: file.id), partialReference: nil, resource: file.resource(key: SecretFileEncryptionKey(aesKey: key.makeData(), aesIv: iv.makeData()), decryptedSize: size), previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int(size), attributes: parsedAttributes)
                            parsedMedia.append(fileMedia)
                        }
                    case let .decryptedMessageMediaExternalDocument(id, accessHash, _, mimeType, size, thumb, dcId, attributes):
                        var parsedAttributes: [TelegramMediaFileAttribute] = []
                        for attribute in attributes {
                            if let parsedAttribute = TelegramMediaFileAttribute(attribute) {
                                parsedAttributes.append(parsedAttribute)
                            }
                        }
                        var previewRepresentations: [TelegramMediaImageRepresentation] = []
                        switch thumb {
                        case let .photoSize(_, location, w, h, size):
                            switch location {
                            case let .fileLocation(dcId, volumeId, localId, secret):
                                previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: CloudFileMediaResource(datacenterId: Int(dcId), volumeId: volumeId, localId: localId, secret: secret, size: size == 0 ? nil : Int(size), fileReference: nil), progressiveSizes: [], immediateThumbnailData: nil))
                            case .fileLocationUnavailable:
                                break
                            }
                        case let .photoCachedSize(_, location, w, h, bytes):
                            if bytes.size > 0 {
                                switch location {
                                case let .fileLocation(dcId, volumeId, localId, secret):
                                    let resource = CloudFileMediaResource(datacenterId: Int(dcId), volumeId: volumeId, localId: localId, secret: secret, size: bytes.size, fileReference: nil)
                                    resources.append((resource, bytes.makeData()))
                                    previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: resource, progressiveSizes: [], immediateThumbnailData: nil))
                                case .fileLocationUnavailable:
                                    break
                                }
                            }
                        default:
                            break
                    }
                    let fileMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: id), partialReference: nil, resource: CloudDocumentMediaResource(datacenterId: Int(dcId), fileId: id, accessHash: accessHash, size: Int(size), fileReference: nil, fileName: nil), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int(size), attributes: parsedAttributes)
                    parsedMedia.append(fileMedia)
                case let .decryptedMessageMediaWebPage(url):
                    parsedMedia.append(TelegramMediaWebpage(webpageId: MediaId(namespace: Namespaces.Media.LocalWebpage, id: Int64.random(in: Int64.min ... Int64.max)), content: .Pending(0, url)))
                case let .decryptedMessageMediaGeoPoint(lat, long):
                    parsedMedia.append(TelegramMediaMap(latitude: lat, longitude: long, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: nil, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil))
                case let .decryptedMessageMediaContact(phoneNumber, firstName, lastName, userId):
                    parsedMedia.append(TelegramMediaContact(firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, peerId: userId == 0 ? nil : PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(Int64(userId))), vCardData: nil))
                case let .decryptedMessageMediaVenue(lat, long, title, address, provider, venueId):
                    parsedMedia.append(TelegramMediaMap(latitude: lat, longitude: long, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: MapVenue(title: title, address: address, provider: provider, id: venueId, type: nil), liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil))
                case .decryptedMessageMediaEmpty:
                    break
                }
            }
            
            if ttl > 0 {
                attributes.append(AutoremoveTimeoutMessageAttribute(timeout: ttl, countdownBeginTime: nil))
            }
            
            var groupingKey: Int64?
            if let groupedId = groupedId {
                inner: for media in parsedMedia {
                    if let _ = media as? TelegramMediaImage {
                        groupingKey = groupedId
                        break inner
                    } else if let _ = media as? TelegramMediaFile {
                        groupingKey = groupedId
                        break inner
                    }
                }
            }
            
            if let replyToRandomId = replyToRandomId, let replyMessageId = messageIdForGloballyUniqueMessageId(replyToRandomId) {
                attributes.append(ReplyMessageAttribute(messageId: replyMessageId, threadMessageId: nil))
            }
            
            var entitiesAttribute: TextEntitiesMessageAttribute?
            for attribute in attributes {
                if let attribute = attribute as? TextEntitiesMessageAttribute {
                    entitiesAttribute = attribute
                    break
                }
            }
            
            let (tags, globalTags) = tagsForStoreMessage(incoming: true, attributes: attributes, media: parsedMedia, textEntities: entitiesAttribute?.entities, isPinned: false)
            
            return (StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, groupingKey: groupingKey, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: tags, globalTags: globalTags, localTags: [], forwardInfo: nil, authorId: authorId, text: text, attributes: attributes, media: parsedMedia), resources)
        case let .decryptedMessageService(randomId, action):
            switch action {
                case .decryptedMessageActionDeleteMessages:
                    return nil
                case .decryptedMessageActionFlushHistory:
                    return nil
                case .decryptedMessageActionNotifyLayer:
                    return nil
                case .decryptedMessageActionReadMessages:
                    return nil
                case .decryptedMessageActionScreenshotMessages:
                    return (StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: authorId, text: "", attributes: [], media: [TelegramMediaAction(action: .historyScreenshot)]), [])
                case let .decryptedMessageActionSetMessageTTL(ttlSeconds):
                    return (StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: tagLocalIndex), globallyUniqueId: randomId, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: authorId, text: "", attributes: [], media: [TelegramMediaAction(action: .messageAutoremoveTimeoutUpdated(ttlSeconds))]), [])
                case .decryptedMessageActionResend:
                    return nil
                case .decryptedMessageActionRequestKey:
                    return nil
                case .decryptedMessageActionAcceptKey:
                    return nil
                case .decryptedMessageActionCommitKey:
                    return nil
                case .decryptedMessageActionAbortKey:
                    return nil
                case .decryptedMessageActionNoop:
                    return nil
        }
    }
}
