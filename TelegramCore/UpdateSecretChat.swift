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

struct SecretChatRequestData {
    let g: Int32
    let p: MemoryBuffer
    let a: MemoryBuffer
}

func updateSecretChat(accountPeerId: PeerId, modifier: Modifier, chat: Api.EncryptedChat, requestData: SecretChatRequestData?) {
    let currentPeer = modifier.getPeer(chat.peerId) as? TelegramSecretChat
    let currentState = modifier.getPeerChatState(chat.peerId) as? SecretChatState
    assert((currentPeer == nil) == (currentState == nil))
    switch chat {
        case let .encryptedChat(_, _, _, adminId, _, gAOrB, remoteKeyFingerprint):
            if let currentPeer = currentPeer, let currentState = currentState, adminId == accountPeerId.id {
                if case let .handshake(handshakeState) = currentState.embeddedState, case let .requested(_, p, a) = handshakeState {
                    let pData = p.makeData()
                    let aData = a.makeData()
                    
                    var key = MTExp(gAOrB.makeData(), aData, pData)!
                    
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
                    
                    var updatedState = currentState.withUpdatedKeychain(SecretChatKeychain(keys: [SecretChatKey(fingerprint: keyFingerprint, key: MemoryBuffer(data: key), validity: .indefinite, useCount: 0)])).withUpdatedEmbeddedState(.basicLayer).withUpdatedKeyFingerprint(SecretChatKeyFingerprint(sha1: SecretChatKeySha1Fingerprint(digest: sha1Digest(key)), sha256: SecretChatKeySha256Fingerprint(digest: sha256Digest(key))))

                    updatedState = secretChatAddReportCurrentLayerSupportOperationAndUpdateRequestedLayer(modifier: modifier, peerId: currentPeer.id, state: updatedState)
                    
                    modifier.setPeerChatState(currentPeer.id, state: updatedState)
                    updatePeers(modifier: modifier, peers: [currentPeer.withUpdatedEmbeddedState(updatedState.embeddedState.peerState)], update: { _, updated in
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
                updatePeers(modifier: modifier, peers: [peer], update: { _, updated in return updated })
                modifier.setPeerChatState(peer.id, state: state)
                modifier.operationLogRemoveAllEntries(peerId: peer.id, tag: OperationLogTags.SecretOutgoing)
            } else {
                Logger.shared.log("State", "got encryptedChatDiscarded, but peer doesn't exist")
            }
        case .encryptedChatEmpty(_):
            break
        case let .encryptedChatRequested(_, accessHash, date, adminId, participantId, gA):
            if currentPeer == nil && participantId == accountPeerId.id {
                let state = SecretChatState(role: .participant, embeddedState: .handshake(.accepting), keychain: SecretChatKeychain(keys: []), keyFingerprint: nil, messageAutoremoveTimeout: nil)
                
                let bBytes = malloc(256)!
                let randomStatus = SecRandomCopyBytes(nil, 256, bBytes.assumingMemoryBound(to: UInt8.self))
                let b = MemoryBuffer(memory: bBytes, capacity: 256, length: 256, freeWhenDone: true)
                if randomStatus == 0 {
                    let updatedState = addSecretChatOutgoingOperation(modifier: modifier, peerId: chat.peerId, operation: .initialHandshakeAccept(gA: MemoryBuffer(gA), accessHash: accessHash, b: b), state: state)
                    modifier.setPeerChatState(chat.peerId, state: updatedState)
                    
                    let peer = TelegramSecretChat(id: chat.peerId, creationDate: date, regularPeerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: adminId), accessHash: accessHash, role: updatedState.role, embeddedState: updatedState.embeddedState.peerState, messageAutoremoveTimeout: nil)
                    updatePeers(modifier: modifier, peers: [peer], update: { _, updated in return updated })
                    modifier.resetIncomingReadStates([peer.id: [
                        Namespaces.Message.SecretIncoming: .indexBased(maxIncomingReadIndex: MessageIndex.lowerBound(peerId: peer.id), maxOutgoingReadIndex: MessageIndex.lowerBound(peerId: peer.id), count: 0),
                        Namespaces.Message.Local: .indexBased(maxIncomingReadIndex: MessageIndex.lowerBound(peerId: peer.id), maxOutgoingReadIndex: MessageIndex.lowerBound(peerId: peer.id), count: 0)
                        ]
                    ])
                } else {
                    assertionFailure()
                }
            } else {
                Logger.shared.log("State", "got encryptedChatRequested, but peer already exists or this account is creator")
            }
        case let .encryptedChatWaiting(_, accessHash, date, adminId, participantId):
            if let requestData = requestData, currentPeer == nil && adminId == accountPeerId.id {
                let state = SecretChatState(role: .creator, embeddedState: .handshake(.requested(g: requestData.g, p: requestData.p, a: requestData.a)), keychain: SecretChatKeychain(keys: []), keyFingerprint: nil, messageAutoremoveTimeout: nil)
                let peer = TelegramSecretChat(id: chat.peerId, creationDate: date, regularPeerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: participantId), accessHash: accessHash, role: state.role, embeddedState: state.embeddedState.peerState, messageAutoremoveTimeout: nil)
                updatePeers(modifier: modifier, peers: [peer], update: { _, updated in return updated })
                modifier.setPeerChatState(peer.id, state: state)
                modifier.resetIncomingReadStates([peer.id: [
                    Namespaces.Message.SecretIncoming: .indexBased(maxIncomingReadIndex: MessageIndex.lowerBound(peerId: peer.id), maxOutgoingReadIndex: MessageIndex.lowerBound(peerId: peer.id), count: 0),
                    Namespaces.Message.Local: .indexBased(maxIncomingReadIndex: MessageIndex.lowerBound(peerId: peer.id), maxOutgoingReadIndex: MessageIndex.lowerBound(peerId: peer.id), count: 0)
                    ]
                ])
            } else {
                Logger.shared.log("State", "got encryptedChatWaiting, but peer already exists or this account is not creator")
            }
    }
}
