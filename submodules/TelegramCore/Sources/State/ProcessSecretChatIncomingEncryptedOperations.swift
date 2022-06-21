import Foundation
import Postbox
import TelegramApi


private enum MessagePreParsingError: Error {
    case invalidChatState
    case malformedData
    case protocolViolation
}

func processSecretChatIncomingEncryptedOperations(transaction: Transaction, peerId: PeerId) -> Bool {
    if let state = transaction.getPeerChatState(peerId) as? SecretChatState {
        var updatedState = state
        var removeTagLocalIndices: [Int32] = []
        var addedDecryptedOperations = false
        transaction.operationLogEnumerateEntries(peerId: peerId, tag: OperationLogTags.SecretIncomingEncrypted, { entry in
            if let operation = entry.contents as? SecretChatIncomingEncryptedOperation {
                if let key = updatedState.keychain.key(fingerprint: operation.keyFingerprint) {
                    var decryptedContents = withDecryptedMessageContents(parameters: SecretChatEncryptionParameters(key: key, mode: .v2(role: updatedState.role)), data: operation.contents)
                    if decryptedContents == nil {
                        decryptedContents = withDecryptedMessageContents(parameters: SecretChatEncryptionParameters(key: key, mode: .v1), data: operation.contents)
                    }
                    if let decryptedContents = decryptedContents {
                        withExtendedLifetime(decryptedContents, {
                            let buffer = BufferReader(Buffer(bufferNoCopy: decryptedContents))
                            
                            do {
                                guard let topLevelSignature = buffer.readInt32() else {
                                    throw MessagePreParsingError.malformedData
                                }
                                let parsedLayer: Int32
                                let sequenceInfo: SecretChatOperationSequenceInfo?
                                
                                if topLevelSignature == 0x1be31789 {
                                    guard let _ = parseBytes(buffer) else {
                                        throw MessagePreParsingError.malformedData
                                    }
                                    
                                    guard let layerValue = buffer.readInt32() else {
                                        throw MessagePreParsingError.malformedData
                                    }
                                    
                                    guard let seqInValue = buffer.readInt32() else {
                                        throw MessagePreParsingError.malformedData
                                    }
                                    
                                    guard let seqOutValue = buffer.readInt32() else {
                                        throw MessagePreParsingError.malformedData
                                    }
                                    
                                    switch updatedState.role {
                                        case .creator:
                                            if seqOutValue < 0 || (seqInValue >= 0 && (seqInValue & 1) == 0) || (seqOutValue & 1) != 0 {
                                                throw MessagePreParsingError.protocolViolation
                                            }
                                        case .participant:
                                            if seqOutValue < 0 || (seqInValue >= 0 && (seqInValue & 1) != 0) || (seqOutValue & 1) == 0 {
                                                throw MessagePreParsingError.protocolViolation
                                            }
                                    }
                                    
                                    sequenceInfo = SecretChatOperationSequenceInfo(topReceivedOperationIndex: seqInValue / 2, operationIndex: seqOutValue / 2)
                                    
                                    if layerValue == 17 {
                                        parsedLayer = 46
                                    } else {
                                        parsedLayer = layerValue
                                    }
                                } else {
                                    parsedLayer = 8
                                    sequenceInfo = nil
                                    buffer.reset()
                                }
                                
                                guard let messageContents = buffer.readBuffer(decryptedContents.length - Int(buffer.offset)) else {
                                    throw MessagePreParsingError.malformedData
                                }
                                
                                let entryTagLocalIndex: StorePeerOperationLogEntryTagLocalIndex
                                
                                switch updatedState.embeddedState {
                                    case .terminated:
                                        throw MessagePreParsingError.invalidChatState
                                    case .handshake:
                                        throw MessagePreParsingError.invalidChatState
                                    case .basicLayer:
                                        if parsedLayer >= 46 {
                                            guard let sequenceInfo = sequenceInfo else {
                                                throw MessagePreParsingError.protocolViolation
                                            }
                                            
                                            let sequenceBasedLayerState = SecretChatSequenceBasedLayerState(layerNegotiationState: SecretChatLayerNegotiationState(activeLayer: secretChatCommonSupportedLayer(remoteLayer: parsedLayer), locallyRequestedLayer: nil, remotelyRequestedLayer: nil), rekeyState: nil, baseIncomingOperationIndex: entry.tagLocalIndex, baseOutgoingOperationIndex: transaction.operationLogGetNextEntryLocalIndex(peerId: peerId, tag: OperationLogTags.SecretOutgoing), topProcessedCanonicalIncomingOperationIndex: nil)
                                            updatedState = updatedState.withUpdatedEmbeddedState(.sequenceBasedLayer(sequenceBasedLayerState))
                                            transaction.setPeerChatState(peerId, state: updatedState)
                                            entryTagLocalIndex = .manual(sequenceBasedLayerState.baseIncomingOperationIndex + sequenceInfo.operationIndex)
                                        } else {
                                            if parsedLayer != 8 && parsedLayer != 17 {
                                                throw MessagePreParsingError.protocolViolation
                                            }
                                            entryTagLocalIndex = .automatic
                                        }
                                    case let .sequenceBasedLayer(sequenceState):
                                        if parsedLayer < 46 {
                                            throw MessagePreParsingError.protocolViolation
                                        }
                                    
                                        entryTagLocalIndex = .manual(sequenceState.baseIncomingOperationIndex + sequenceInfo!.operationIndex)
                                }
                                
                                transaction.operationLogAddEntry(peerId: peerId, tag: OperationLogTags.SecretIncomingDecrypted, tagLocalIndex: entryTagLocalIndex, tagMergedIndex: .none, contents: SecretChatIncomingDecryptedOperation(timestamp: operation.timestamp, layer: parsedLayer, sequenceInfo: sequenceInfo, contents: MemoryBuffer(messageContents), file: operation.mediaFileReference))
                                addedDecryptedOperations = true
                            } catch let error {
                                if let error = error as? MessagePreParsingError {
                                    switch error {
                                        case .invalidChatState:
                                            break
                                        case .malformedData, .protocolViolation:
                                            break
                                    }
                                }
                                Logger.shared.log("SecretChat", "peerId \(peerId) malformed data after decryption")
                            }
                            
                            removeTagLocalIndices.append(entry.tagLocalIndex)
                        })
                    } else {
                        Logger.shared.log("SecretChat", "peerId \(peerId) couldn't decrypt message content")
                        removeTagLocalIndices.append(entry.tagLocalIndex)
                    }
                } else {
                    Logger.shared.log("SecretChat", "peerId \(peerId) key \(operation.keyFingerprint) doesn't exist")
                }
            } else {
                assertionFailure()
            }
            return true
        })
        for index in removeTagLocalIndices {
            let removed = transaction.operationLogRemoveEntry(peerId: peerId, tag: OperationLogTags.SecretIncomingEncrypted, tagLocalIndex: index)
            assert(removed)
        }
        return addedDecryptedOperations
    } else {
        return false
    }
}
