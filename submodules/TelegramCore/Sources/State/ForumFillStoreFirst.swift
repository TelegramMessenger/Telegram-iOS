import Foundation
import Postbox

/// Whether a forum (or monoforum) history fill may store its messages before resolving what they reference. Topic
/// headers read a message's thread info while drawing, so a fill holding a message of a topic whose info is not stored
/// resolves first; otherwise it stores first, like any other chat, and what the messages reference follows. Topics the
/// answer itself carries count as known: they are stored in the same transaction as the messages (a topic's info does
/// not survive a commit without one of its messages).
func forumFillStoresFirst(fetchedThreadIds: Set<Int64>, storedThreadIds: Set<Int64>, answerThreadIds: Set<Int64>) -> Bool {
    return fetchedThreadIds.isSubset(of: storedThreadIds.union(answerThreadIds))
}

/// The reply targets of a message that a fill should wait for. A forum message replies to its own topic's root, which
/// is usually not stored and never drawn as a reply header, so that one is not waited for.
func pendingReplyTargets(replyTargets: [MessageId], messageThreadId: Int64?, peerIsForum: Bool) -> [MessageId] {
    return replyTargets.filter { target in
        if peerIsForum, let messageThreadId, Int64(target.id) == messageThreadId {
            return false
        }
        return true
    }
}
