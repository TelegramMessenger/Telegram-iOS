import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Typing activity and live typing drafts.
extension ReplayContext {
    func applyAddPeerInputActivity(_ chatPeerId: PeerActivitySpace, _ peerId: PeerId?, _ activity: PeerInputActivity?) {
        if let peerId = peerId {
            if updatedTypingActivities[chatPeerId] == nil {
                updatedTypingActivities[chatPeerId] = [peerId: activity]
            } else {
                updatedTypingActivities[chatPeerId]![peerId] = activity
            }
        } else if chatPeerId.peerId.namespace == Namespaces.Peer.SecretChat {
            updatedSecretChatTypingActivities.insert(chatPeerId.peerId)
        }
    }
    
    func applyAddPeerLiveTypingDraftUpdate(_ peerAndThreadId: PeerAndThreadId, _ id: Int64, _ timestamp: Int32, _ authorId: PeerId, _ canStop: Bool, _ keepOnStop: Bool, _ content: PeerLiveTypingDraftUpdateContent) {
        if liveTypingDraftUpdates[peerAndThreadId] == nil {
            liveTypingDraftUpdates[peerAndThreadId] = []
        }
        liveTypingDraftUpdates[peerAndThreadId]?.append(.update(LiveTypingDraftUpdate.Update(
            id: id,
            threadId: peerAndThreadId.threadId,
            authorId: authorId,
            timestamp: timestamp,
            canStop: canStop,
            keepOnStop: keepOnStop,
            content: content
        )))
        if peerAndThreadId.threadId != nil {
            let allKey = PeerAndThreadId(peerId: peerAndThreadId.peerId, threadId: nil)
            if liveTypingDraftUpdates[allKey] == nil {
                liveTypingDraftUpdates[allKey] = []
            }
            liveTypingDraftUpdates[allKey]?.append(.update(LiveTypingDraftUpdate.Update(
                id: id,
                threadId: peerAndThreadId.threadId,
                authorId: authorId,
                timestamp: timestamp,
                canStop: canStop,
                keepOnStop: keepOnStop,
                content: content
            )))
        }
    }
    
    func applyAddPeerLiveTypingDraftStop(_ peerAndThreadId: PeerAndThreadId, _ randomId: Int64, _ timestamp: Int32) {
        if liveTypingDraftUpdates[peerAndThreadId] == nil {
            liveTypingDraftUpdates[peerAndThreadId] = []
        }
        liveTypingDraftUpdates[peerAndThreadId]?.append(.stop(randomId: randomId, timestamp: timestamp))
        if peerAndThreadId.threadId != nil {
            let allKey = PeerAndThreadId(peerId: peerAndThreadId.peerId, threadId: nil)
            if liveTypingDraftUpdates[allKey] == nil {
                liveTypingDraftUpdates[allKey] = []
            }
            liveTypingDraftUpdates[allKey]?.append(.stop(randomId: randomId, timestamp: timestamp))
        }
    }
}
