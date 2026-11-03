import Foundation

// Successive drafts must be distinct messages, not one message that changes: node-local
// state in the chat UI (the text-reveal cursor, the rich-data expand state) is keyed by
// MessageId, so a shared sentinel would let a replacement inherit its predecessor's state.
//
// Deterministic in randomId — every update of one draft must land on the same id, or each
// streaming chunk would mint a new item and destroy the reveal. Namespace 1 is the Local
// namespace, which the chat layer relies on to suppress the context menu for drafts. The
// band sits far above any id a pending outgoing local message will reach. A hash collision
// between two successive drafts is harmless: stableId still differs, so the list still
// builds a new node, and node-local state does not carry across nodes.
func typingDraftMessageId(peerId: PeerId, randomId: Int64) -> MessageId {
    let folded = UInt64(bitPattern: randomId)
    let hashed = folded ^ (folded >> 32)
    let offset = Int32(truncatingIfNeeded: hashed % 65536)
    return MessageId(peerId: peerId, namespace: 1, id: Int32.max - 50000 - offset)
}

final class MutableTypingDraftsView: MutablePostboxView {
    fileprivate let peerAndThreadId: PeerAndThreadId
    fileprivate var typingDraft: Message?
    
    init(postbox: PostboxImpl, peerAndThreadId: PeerAndThreadId) {
        self.peerAndThreadId = peerAndThreadId
        
        self.reload(postbox: postbox)
    }
    
    private func reload(postbox: PostboxImpl) {
        if let typingDraft = postbox.currentTypingDrafts[self.peerAndThreadId] {
            self.typingDraft = self.renderTypingDraft(postbox: postbox, typingDraft: typingDraft)
        } else {
            self.typingDraft = nil
        }
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        if let typingDraftUpdate = transaction.updatedTypingDrafts[self.peerAndThreadId] {
            if let typingDraft = typingDraftUpdate.value {
                self.typingDraft = self.renderTypingDraft(postbox: postbox, typingDraft: typingDraft)
            } else {
                self.typingDraft = nil
            }
            updated = true
        }
        
        return updated
    }

    private func renderTypingDraft(postbox: PostboxImpl, typingDraft: PostboxImpl.TypingDraft) -> Message? {
        guard let peer = postbox.peerTable.get(self.peerAndThreadId.peerId), let author = postbox.peerTable.get(typingDraft.authorId) else {
            return nil
        }
        
        var peers = SimpleDictionary<PeerId, Peer>()
        peers[peer.id] = peer
        peers[author.id] = author
        
        var associatedThreadInfo: Message.AssociatedThreadInfo?
        if let threadId = typingDraft.threadId, let data = postbox.messageHistoryThreadIndexTable.get(peerId: self.peerAndThreadId.peerId, threadId: threadId) {
            associatedThreadInfo = postbox.seedConfiguration.decodeMessageThreadInfo(data.data)
        }
        
        return Message(
            stableId: typingDraft.stableId,
            stableVersion: typingDraft.stableVersion,
            id: typingDraftMessageId(peerId: self.peerAndThreadId.peerId, randomId: typingDraft.id),
            globallyUniqueId: nil,
            groupingKey: nil,
            groupInfo: nil,
            threadId: typingDraft.threadId,
            timestamp: typingDraft.timestamp,
            flags: [.Incoming],
            tags: [],
            globalTags: [],
            localTags: [],
            customTags: [],
            forwardInfo: nil,
            author: author,
            text: typingDraft.text,
            attributes: typingDraft.attributes,
            media: [],
            peers: peers,
            associatedMessages: SimpleDictionary(),
            associatedMessageIds: [],
            associatedMedia: [:],
            associatedThreadInfo: associatedThreadInfo,
            associatedStories: [:]
        )
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        self.reload(postbox: postbox)
        
        return true
    }
    
    func immutableView() -> PostboxView {
        return TypingDraftsView(self)
    }
}

public final class TypingDraftsView: PostboxView {
    public let typingDraft: Message?
    
    init(_ view: MutableTypingDraftsView) {
        self.typingDraft = view.typingDraft
    }
}
