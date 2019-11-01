import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

struct SecretChatRequestData {
    let g: Int32
    let p: MemoryBuffer
    let a: MemoryBuffer
}

func updateSecretChat(encryptionProvider: EncryptionProvider, accountPeerId: PeerId, transaction: Transaction, chat: Api.EncryptedChat, requestData: SecretChatRequestData?) {
    let currentPeer = transaction.getPeer(chat.peerId) as? TelegramSecretChat
    let currentState = transaction.getPeerChatState(chat.peerId) as? SecretChatState
    let settings = transaction.getPreferencesEntry(key: PreferencesKeys.secretChatSettings) as? SecretChatSettings ?? SecretChatSettings.defaultSettings
    assert((currentPeer == nil) == (currentState == nil))
    switch chat {
        case let .encryptedChat(_, _, _, adminId, _, gAOrB, remoteKeyFingerprint):
            if let currentPeer = currentPeer, let currentState = currentState, adminId == accountPeerId.id {
                if case let .handshake(handshakeState) = currentState.embeddedState, case let .requested(_, p, a) = handshakeState {
                    let pData = p.makeData()
                    let aData = a.makeData()
                    
                    if !MTCheckIsSafeGAOrB(encryptionProvider, gAOrB.makeData(), pData) {
                        var updatedState = currentState
                        updatedState = updatedState.withUpdatedEmbeddedState(.terminated)
                        transaction.setPeerChatState(chat.peerId, state: updatedState)
                        return
                    }
                    
                    var key = MTExp(encryptionProvider, gAOrB.makeData(), aData, pData)!
                    
                    if key.count > 256 {
                        key.count = 256
                    } else  {
                        while key.count < 256 {
                            key.insert(0, at: 0)
                        }
                    }
                    
                    let keyHash = MTSha1(key)!
                    
                    var keyFingerprint: Int64 = 0
                    keyHash.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                        memcpy(&keyFingerprint, bytes.advanced(by: keyHash.count - 8), 8)
                    }
                    
                    var updatedState = currentState
                    updatedState = updatedState.withUpdatedKeychain(SecretChatKeychain(keys: [SecretChatKey(fingerprint: keyFingerprint, key: MemoryBuffer(data: key), validity: .indefinite, useCount: 0)]))
                    updatedState = updatedState.withUpdatedEmbeddedState(.sequenceBasedLayer(SecretChatSequenceBasedLayerState(layerNegotiationState: SecretChatLayerNegotiationState(activeLayer: .layer46, locallyRequestedLayer: nil, remotelyRequestedLayer: nil), rekeyState: nil, baseIncomingOperationIndex: transaction.operationLogGetNextEntryLocalIndex(peerId: currentPeer.id, tag: OperationLogTags.SecretIncomingDecrypted), baseOutgoingOperationIndex: transaction.operationLogGetNextEntryLocalIndex(peerId: currentPeer.id, tag: OperationLogTags.SecretOutgoing), topProcessedCanonicalIncomingOperationIndex: nil)))
                    
                    updatedState = updatedState.withUpdatedKeyFingerprint(SecretChatKeyFingerprint(sha1: SecretChatKeySha1Fingerprint(digest: sha1Digest(key)), sha256: SecretChatKeySha256Fingerprint(digest: sha256Digest(key))))
                    
                    updatedState = secretChatAddReportCurrentLayerSupportOperationAndUpdateRequestedLayer(transaction: transaction, peerId: currentPeer.id, state: updatedState)
                    
                    transaction.setPeerChatState(currentPeer.id, state: updatedState)
                    updatePeers(transaction: transaction, peers: [currentPeer.withUpdatedEmbeddedState(updatedState.embeddedState.peerState)], update: { _, updated in
                        return updated
                    })
                } else {
                    Logger.shared.log("State", "got encryptedChat, but chat is not in handshake state")
                }
            } else {
                Logger.shared.log("State", "got encryptedChat, but peer or state don't exist or account is not creator")
            }
        case .encryptedChatDiscarded(_):
            if let currentPeer = currentPeer, let currentState = currentState {
                let state = currentState.withUpdatedEmbeddedState(.terminated)
                let peer = currentPeer.withUpdatedEmbeddedState(state.embeddedState.peerState)
                updatePeers(transaction: transaction, peers: [peer], update: { _, updated in return updated })
                transaction.setPeerChatState(peer.id, state: state)
                transaction.operationLogRemoveAllEntries(peerId: peer.id, tag: OperationLogTags.SecretOutgoing)
            } else {
                Logger.shared.log("State", "got encryptedChatDiscarded, but peer doesn't exist")
            }
        case .encryptedChatEmpty(_):
            break
        case let .encryptedChatRequested(_, accessHash, date, adminId, participantId, gA):
            if currentPeer == nil && participantId == accountPeerId.id {
                if settings.acceptOnThisDevice {
                    let state = SecretChatState(role: .participant, embeddedState: .handshake(.accepting), keychain: SecretChatKeychain(keys: []), keyFingerprint: nil, messageAutoremoveTimeout: nil)
                    
                    let bBytes = malloc(256)!
                    let randomStatus = SecRandomCopyBytes(nil, 256, bBytes.assumingMemoryBound(to: UInt8.self))
                    let b = MemoryBuffer(memory: bBytes, capacity: 256, length: 256, freeWhenDone: true)
                    if randomStatus == 0 {
                        let updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: chat.peerId, operation: .initialHandshakeAccept(gA: MemoryBuffer(gA), accessHash: accessHash, b: b), state: state)
                        transaction.setPeerChatState(chat.peerId, state: updatedState)
                        
                        let peer = TelegramSecretChat(id: chat.peerId, creationDate: date, regularPeerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: adminId), accessHash: accessHash, role: updatedState.role, embeddedState: updatedState.embeddedState.peerState, messageAutoremoveTimeout: nil)
                        updatePeers(transaction: transaction, peers: [peer], update: { _, updated in return updated })
                        transaction.resetIncomingReadStates([peer.id: [
                            Namespaces.Message.SecretIncoming: .indexBased(maxIncomingReadIndex: MessageIndex.lowerBound(peerId: peer.id), maxOutgoingReadIndex: MessageIndex.lowerBound(peerId: peer.id), count: 0, markedUnread: false),
                            Namespaces.Message.Local: .indexBased(maxIncomingReadIndex: MessageIndex.lowerBound(peerId: peer.id), maxOutgoingReadIndex: MessageIndex.lowerBound(peerId: peer.id), count: 0, markedUnread: false)
                            ]
                            ])
                    } else {
                        assertionFailure()
                    }
                } else {
                    Logger.shared.log("State", "accepting secret chats disabled on this device")
                }
                
                
            } else {
                Logger.shared.log("State", "got encryptedChatRequested, but peer already exists or this account is creator")
            }
        case let .encryptedChatWaiting(_, accessHash, date, adminId, participantId):
            if let requestData = requestData, currentPeer == nil && adminId == accountPeerId.id {
                let state = SecretChatState(role: .creator, embeddedState: .handshake(.requested(g: requestData.g, p: requestData.p, a: requestData.a)), keychain: SecretChatKeychain(keys: []), keyFingerprint: nil, messageAutoremoveTimeout: nil)
                let peer = TelegramSecretChat(id: chat.peerId, creationDate: date, regularPeerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: participantId), accessHash: accessHash, role: state.role, embeddedState: state.embeddedState.peerState, messageAutoremoveTimeout: nil)
                updatePeers(transaction: transaction, peers: [peer], update: { _, updated in return updated })
                transaction.setPeerChatState(peer.id, state: state)
                transaction.resetIncomingReadStates([peer.id: [
                    Namespaces.Message.SecretIncoming: .indexBased(maxIncomingReadIndex: MessageIndex.lowerBound(peerId: peer.id), maxOutgoingReadIndex: MessageIndex.lowerBound(peerId: peer.id), count: 0, markedUnread: false),
                    Namespaces.Message.Local: .indexBased(maxIncomingReadIndex: MessageIndex.lowerBound(peerId: peer.id), maxOutgoingReadIndex: MessageIndex.lowerBound(peerId: peer.id), count: 0, markedUnread: false)
                    ]
                ])
            } else {
                Logger.shared.log("State", "got encryptedChatWaiting, but peer already exists or this account is not creator")
            }
    }
}
