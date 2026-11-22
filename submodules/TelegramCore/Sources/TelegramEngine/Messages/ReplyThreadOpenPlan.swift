import Foundation
import Postbox

/// Where a thread's comments can be requested before `messages.getDiscussionMessage` answers.
enum ReplyThreadFillTarget: Equatable {
    /// A channel post: `messages.getReplies(peer: channel, msg_id: post)` answers with the
    /// discussion group's comments (`.threadFromChannel`).
    case channelPost(MessageId)
    /// A thread in a non-forum supergroup: `messages.getReplies(peer: group, msg_id: threadId)` (`.direct`).
    case groupThread(peerId: PeerId, threadId: Int64)
}

/// The chat a thread is opened from, as far as what can be requested early goes.
enum ReplyThreadSubjectChat {
    case broadcastChannel
    /// A supergroup without topics.
    case nonForumGroup
    /// Forums, monoforums, users, basic groups: their opens stay sequential.
    case other
}

/// What can be requested before `getDiscussionMessage` answers: a channel post's comments by the post itself, a
/// group thread by its root (`subjectThreadId` when the subject is a reply in a thread, else the subject itself).
func replyThreadFillTarget(chat: ReplyThreadSubjectChat, messageId: MessageId, subjectThreadId: Int64?) -> ReplyThreadFillTarget? {
    switch chat {
    case .broadcastChannel:
        return .channelPost(messageId)
    case .nonForumGroup:
        return .groupThread(peerId: messageId.peerId, threadId: subjectThreadId ?? Int64(messageId.id))
    case .other:
        return nil
    }
}

/// Whether a fill made at time zero is a fill of the thread `getDiscussionMessage` named, so its holes may be
/// closed on that thread. A post's comments are resolved by the server, so any answer is about the server's
/// thread unless its comments say otherwise (an empty answer says nothing). A group thread was chosen by the
/// client, and the fill closes holes of that thread whatever it returns, so it matches only when it is the
/// server's thread.
func replyThreadFillMatchesServerThread(target: ReplyThreadFillTarget, actualPeerId: PeerId?, actualThreadId: Int64?, serverPeerId: PeerId, serverThreadId: Int64) -> Bool {
    switch target {
    case .channelPost:
        return (actualPeerId == nil || actualPeerId == serverPeerId) && (actualThreadId == nil || actualThreadId == serverThreadId)
    case let .groupThread(peerId, threadId):
        return peerId == serverPeerId && threadId == serverThreadId
    }
}

/// Where a thread opens, and so what its first fill is around. Ids are in the discussion group's id space.
enum ReplyThreadFillAnchor: Equatable {
    case around(MessageId.Id)
    case oldest
}

/// What the thread head's stored `ReplyThreadMessageAttribute` says (`messageReplies.max_id`, `read_max_id`).
struct ReplyThreadStoredReplies: Equatable {
    var maxMessageId: MessageId.Id?
    var maxReadMessageId: MessageId.Id?
}

enum ReplyThreadOpenPlan: Equatable {
    /// `getDiscussionMessage`, then the fill it decides: the path every open took before.
    case sequential
    /// `getDiscussionMessage` alone; the reconcile decides whether a fill follows.
    case discussionOnly
    /// `getDiscussionMessage` and the fill in the same turn.
    case parallel(ReplyThreadFillTarget, ReplyThreadFillAnchor)
}

/// What to send at the moment a thread is opened.
///
/// The fill needs only ids the client already has: the post (or the group thread), and an anchor.
/// The anchor follows the order the server's answer is read in later: the link's comment, else the
/// stored read position, else the oldest comments. With nothing stored and no link there is no anchor
/// worth guessing, so the open stays sequential; with no comments stored and no link there is nothing
/// to fill; and a window the cache already holds is not fetched again (`cachedWindowIsComplete` is nil
/// when the thread is not known locally).
func replyThreadOpenPlan(target: ReplyThreadFillTarget?, storedReplies: ReplyThreadStoredReplies?, linkedCommentId: MessageId.Id?, cachedWindowIsComplete: Bool?) -> ReplyThreadOpenPlan {
    guard let target else {
        return .sequential
    }
    if storedReplies == nil && linkedCommentId == nil {
        return .sequential
    }
    if linkedCommentId == nil && storedReplies?.maxMessageId == nil {
        return .discussionOnly
    }
    if cachedWindowIsComplete == true {
        return .discussionOnly
    }
    return .parallel(target, replyThreadServerAnchor(linkedCommentId: linkedCommentId, readInboxMaxId: storedReplies?.maxReadMessageId))
}

/// Where the thread opens: the link's comment, else the read position, else the oldest comments.
func replyThreadServerAnchor(linkedCommentId: MessageId.Id?, readInboxMaxId: MessageId.Id?) -> ReplyThreadFillAnchor {
    if let linkedCommentId {
        return .around(linkedCommentId)
    } else if let readInboxMaxId {
        return .around(readInboxMaxId)
    } else {
        return .oldest
    }
}

enum ReplyThreadFillOutcome: Equatable {
    case notSent
    case failed
    /// `matchesServerThread` is false when the fill's comments belong to another thread than the
    /// one `getDiscussionMessage` named (for example, the channel changed its discussion group).
    case succeeded(usedAnchor: ReplyThreadFillAnchor, matchesServerThread: Bool)
}

enum ReplyThreadReconcileDecision: Equatable {
    /// The server has no comments: every index is filled and the thread opens empty.
    case empty
    /// The fill serves the server's anchor as it is.
    case accept
    /// Run the sequential fill around this anchor. It reads the cache first, so a window the cache
    /// (with the fill just applied) already holds costs no request.
    case refill(ReplyThreadFillAnchor)
}

/// What to do once `getDiscussionMessage` has answered. The server's anchor always decides where the
/// thread opens; a fill made around another anchor, a failed fill, a fill of another thread and a
/// skipped fill all fall back to the sequential fill around it.
func replyThreadReconcile(serverHasComments: Bool, serverAnchor: ReplyThreadFillAnchor, fill: ReplyThreadFillOutcome) -> ReplyThreadReconcileDecision {
    if !serverHasComments {
        return .empty
    }
    if case let .succeeded(usedAnchor, matchesServerThread) = fill, matchesServerThread, usedAnchor == serverAnchor {
        return .accept
    }
    return .refill(serverAnchor)
}
