import Foundation
import Postbox
internal import TelegramApi

// A channel the account is not a member of has no read state on the server: no unread count and no read
// position. That covers channels seen in For You and channels added only to News (a light join, which stays
// `.left`). The client keeps none either, wherever read state is made or sent:
// - opening the chat installs `nonMemberChannelReadState` (`AccountViewTracker.wrappedMessageHistorySignal`);
// - an interactive read does nothing (`_internal_applyMaxReadIndexInteractively`);
// - the server's read-state operations are skipped in replay (`readStateOperationTargetsNonMember`);
// - the synchronizer confirms a queued operation without sending it (`synchronizePeerReadState`);
// - dialogs fetched for chat folders store no read state for one (`dialogReadStateIsKept`);
// - the replay's read marks for topic counting leave its operations out (`cloudReadInboxMarks`).
// Joining installs the server's state: a stored channel that becomes a member asks for it
// (`channelJoinNeedsServerReadState`, read-state validation fetches the dialog). The join's own dialog
// fetch (`resolveMissingPeerChatInfos`) cannot be relied on: it is skipped for a channel whose
// notification settings are stored, which opening the chat does.

/// False only for a stored channel the account is not a member of. A peer that is not stored keeps today's
/// behaviour.
func peerKeepsReadState(_ peer: Peer?) -> Bool {
    if let channel = peer as? TelegramChannel {
        // A monoforum is a user's direct messages with a channel: its replies and read receipts matter
        // whatever the participation status says.
        if channel.flags.contains(.isMonoforum) {
            return true
        }
        return channel.participationStatus == .member
    }
    return true
}

/// Nothing unread (`count` 0: no unread count, no separator) and nothing ever counted (`maxKnownId`).
/// The incoming read mark is 0, never above a server mark: the replay of `.ResetReadState` and validation
/// keep a local mark that is ahead of the server's while the server reports unread messages
/// (`localReadMarkIsAheadOfServer`), so a higher mark would block the state a join brings in, and validation
/// would retry it without end (a join can report nothing read: mark 0). `Int32.max - 1` is the codebase's
/// "everything"; `Int32.max` itself overflows paths that add 1.
let nonMemberChannelReadState: PeerReadState = .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 1, maxKnownId: Int32.max - 1, count: 0, markedUnread: false)

/// The incoming read state a chat opened on a channel outside the chat list starts from. Members outside
/// the chat list keep the reset they always had.
func channelReadStateOnOpenOutsideChatList(peer: Peer?) -> PeerReadState {
    if peerKeepsReadState(peer) {
        return .idBased(maxIncomingReadId: 1, maxOutgoingReadId: 1, maxKnownId: 1, count: 0, markedUnread: false)
    } else {
        return nonMemberChannelReadState
    }
}

/// Whether `operation` writes the main chat's incoming read state of a channel the account is not a member
/// of, judged by the peer stored when the operation is replayed. Operations replay in order, so a membership
/// change earlier in the same replay (a join's channel merge) is already stored.
func readStateOperationTargetsNonMember(_ operation: AccountStateMutationOperation, getPeer: (PeerId) -> Peer?) -> Bool {
    let peerId: PeerId
    switch operation {
    case let .ReadInbox(messageId):
        peerId = messageId.peerId
    case let .ResetReadState(peerIdValue, _, _, _, _, _, _):
        peerId = peerIdValue
    case let .ResetIncomingReadState(_, peerIdValue, _, _, _, _):
        peerId = peerIdValue
    case let .UpdatePeerChatUnreadMark(peerIdValue, threadId, _, _):
        if threadId != nil {
            return false
        }
        peerId = peerIdValue
    default:
        return false
    }
    return !peerKeepsReadState(getPeer(peerId))
}

/// Whether a stored channel the account has just become a member of must ask the server for its read
/// state. It still holds the state it had as a non-member, and the join does not always fetch the dialog:
/// `initialStateWithPeerIds` judges the stored (non-member) channel and builds its chat info from the
/// stored notification settings, which opening the chat has fetched, so `resolveMissingPeerChatInfos`
/// asks for nothing.
func channelJoinNeedsServerReadState(previous: Peer?, updated: Peer) -> Bool {
    guard let previous = previous as? TelegramChannel, let updated = updated as? TelegramChannel else {
        return false
    }
    return previous.participationStatus != .member && updated.participationStatus == .member
}

/// Whether the read state in a dialog the server sent is stored for `peerId`. The chat object in the same
/// response decides, being newer than the stored peer (a channel joined since keeps the server's state);
/// the stored peer decides when the response has none.
func dialogReadStateIsKept(peerId: PeerId, responseChats: [Api.Chat], storedPeer: Peer?) -> Bool {
    for chat in responseChats where chat.peerId == peerId {
        if let peer = parseTelegramGroupOrChannel(chat: chat) {
            return peerKeepsReadState(peer)
        }
    }
    return peerKeepsReadState(storedPeer)
}
