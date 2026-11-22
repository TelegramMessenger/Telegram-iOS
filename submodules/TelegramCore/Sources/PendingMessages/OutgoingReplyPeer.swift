import Foundation
import Postbox

/// Whether an outgoing reply must carry an explicit `reply_to_peer_id`.
///
/// It obviously must when the replied message lives in another peer. It must *also* when the
/// destination is a forum and the replied message sits in a different topic of that same forum:
/// the server routes a forum reply into the replied message's topic unless the reply is marked
/// external (`reply_to_peer_id` present), regardless of `top_msg_id`. Telegram Desktop marks the
/// reply external in exactly this case; without it, "Reply in Another Chat" into a sibling topic
/// lands the message back in the source topic (bugs.telegram.org/c/37773).
///
/// The topic comparison is gated on the destination being a forum on purpose. Outside forums the
/// stored `threadId` conflates comment-thread roots with the `1` default that every channel message
/// without a reply header receives, so an un-gated comparison flags an ordinary reply to a comment
/// thread's root message as external. That is what the 2026-04 attempt did before it was rolled back.
///
/// `replyThreadId` should be the replied message's *live* stored `threadId` where a transaction is at
/// hand, falling back to the enqueue-time snapshot on `ReplyMessageAttribute.threadMessageId` — the
/// snapshot is nil when the replied message was not in the store at enqueue time, and a nil here
/// disables the topic comparison. Known gap: bot forums (a `TelegramUser` with `hasForum`) store no
/// default thread id for messages outside a topic (`StoreMessage_Telegram` only defaults channels to
/// `1`), so such a reply is not marked external; that feature is still gated `TODO:release`.
func outgoingReplyRequiresExplicitPeer(destinationPeer: Peer, destinationThreadId: Int64?, replyMessageId: MessageId, replyThreadId: Int64?) -> Bool {
    if replyMessageId.peerId != destinationPeer.id {
        return true
    }
    guard destinationPeer.isForum, let destinationThreadId, let replyThreadId else {
        return false
    }
    return destinationThreadId != replyThreadId
}
