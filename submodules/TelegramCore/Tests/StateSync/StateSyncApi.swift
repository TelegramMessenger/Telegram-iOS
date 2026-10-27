import Foundation
import MtProtoKit
import TelegramApi
@testable import TelegramCore

/// Wire names the state-sync flows expect in the request log (`FunctionDescription.name`).
enum StateSyncRequestName {
    static let getDifference = "updates.getDifference"
    static let getState = "updates.getState"
    static let getChannelDifference = "updates.getChannelDifference"
    static let getPeerDialogs = "messages.getPeerDialogs"
    static let getDialogs = "messages.getDialogs"
    static let getPinnedDialogs = "messages.getPinnedDialogs"
    static let channelsGetMessages = "channels.getMessages"
    static let messagesGetMessages = "messages.getMessages"
    static let receivedQueue = "messages.receivedQueue"
    static let helpTest = "help.test"
}

/// Api values for the state-sync harness. Every constructor shape is the generated one in
/// `submodules/TelegramApi/Sources/SwiftPMGenerated` (identical to what Bazel generates from
/// `swift_scheme.tl`).
///
/// Flags rule: accessors read presence (scalars) or nil-ness (references), never `flags`, so
/// TelegramCore sees a value whether or not its bit is set. Serialization is different: a set bit
/// with a nil value aborts the process (`TLAbortMissingField`, TLEngine.m), and a value whose bit
/// is clear is silently dropped from the wire. So every factory sets exactly the bits of the
/// optionals it fills, plus the `true`-flags the scenario means. TelegramCore reads `out` (message)
/// and `left` (channel); `post`, `final` and user `self` are set for wire fidelity only.
enum StateSyncApi {
    // MARK: - Peers

    static func peerUser(_ userId: Int64) -> Api.Peer {
        return .peerUser(.init(userId: userId))
    }

    static func peerChannel(_ channelId: Int64) -> Api.Peer {
        return .peerChannel(.init(channelId: channelId))
    }

    /// `user#b1b8cc83`: `access_hash` flags.0, `first_name` flags.1, `self` flags.10 (wire-only:
    /// `TelegramUser(user:)` does not read it). `min` (flags.20) stays clear, so the access hash is
    /// stored as `.personal`.
    static func user(id: Int64, accessHash: Int64 = 1, firstName: String = "User", isSelf: Bool = false) -> Api.User {
        var flags: Int32 = (1 << 0) | (1 << 1)
        if isSelf {
            flags |= 1 << 10
        }
        return .user(.init(flags: flags, flags2: 0, id: id, accessHash: accessHash, firstName: firstName, lastName: nil, username: nil, phone: nil, photo: nil, status: nil, botInfoVersion: nil, restrictionReason: nil, botInlinePlaceholder: nil, langCode: nil, emojiStatus: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, botActiveUsers: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedCommunityId: nil))
    }

    /// `channel#d49f34c6`: `broadcast` flags.5, `access_hash` flags.13; `left` flags.2 only when asked.
    /// `megagroup` (8), `min` (12), `forum` (30) and `flags2.monoforum` (17) stay clear: the result
    /// parses as `TelegramChannel(info: .broadcast, participationStatus: .member)`, not a forum.
    static func broadcastChannel(id: Int64, accessHash: Int64 = 1, title: String = "Channel", date: Int32 = 1, left: Bool = false) -> Api.Chat {
        var flags: Int32 = (1 << 5) | (1 << 13)
        if left {
            flags |= 1 << 2
        }
        return .channel(.init(flags: flags, flags2: 0, id: id, accessHash: accessHash, title: title, username: nil, photo: .chatPhotoEmpty, date: date, restrictionReason: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, participantsCount: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, emojiStatus: nil, level: nil, subscriptionUntilDate: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedMonoforumId: nil, linkedCommunityId: nil, pinnedMsgId: nil))
    }

    // MARK: - Messages

    /// `messageReplyHeader#1b97dd66`: `reply_to_msg_id` flags.4. No `reply_to_peer_id`, so the
    /// target is in the same chat as the replying message.
    static func replyHeader(toMessageId: Int32) -> Api.MessageReplyHeader {
        return .messageReplyHeader(.init(flags: 1 << 4, replyToMsgId: toMessageId, replyToPeerId: nil, replyFrom: nil, replyMedia: nil, replyToTopId: nil, quoteText: nil, quoteEntities: nil, quoteOffset: nil, todoItemId: nil, pollOption: nil, quoteRich: nil))
    }

    /// `message#7600b9d3` in a private chat with `peerUserId`. Incoming unless `outgoing`
    /// (`out` flags.1). `from_id` flags.8 when `fromUserId` is set; `reply_to` flags.3.
    static func privateMessage(id: Int32, peerUserId: Int64, fromUserId: Int64? = nil, date: Int32, text: String = "text", outgoing: Bool = false, replyToMessageId: Int32? = nil, media: Api.MessageMedia? = nil) -> Api.Message {
        var flags: Int32 = 0
        if media != nil {
            flags |= 1 << 9
        }
        if outgoing {
            flags |= 1 << 1
        }
        if fromUserId != nil {
            flags |= 1 << 8
        }
        if replyToMessageId != nil {
            flags |= 1 << 3
        }
        return .message(.init(flags: flags, flags2: 0, id: id, fromId: fromUserId.flatMap { self.peerUser($0) }, fromBoostsApplied: nil, fromRank: nil, peerId: self.peerUser(peerUserId), savedPeerId: nil, fwdFrom: nil, viaBotId: nil, viaBusinessBotId: nil, guestchatViaFrom: nil, replyTo: replyToMessageId.flatMap { self.replyHeader(toMessageId: $0) }, date: date, message: text, media: media, replyMarkup: nil, entities: nil, views: nil, forwards: nil, replies: nil, editDate: nil, postAuthor: nil, groupedId: nil, reactions: nil, restrictionReason: nil, ttlPeriod: nil, quickReplyShortcutId: nil, effect: nil, factcheck: nil, reportDeliveryUntilDate: nil, paidMessageStars: nil, suggestedPost: nil, scheduleRepeatPeriod: nil, summaryFromLanguage: nil, richMessage: nil))
    }

    /// widget-sandbox v0.2: a message widget with the bot's state (`messageMediaWidget`: the shared state flags.3, the
    /// chat state flags.4, the widget id flags.5). A nil state is absent; "" is present and empty.
    static func widgetMedia(chatData: String?, publicData: String?, publicDataHash: Int64? = nil, widgetId: Int64? = nil) -> Api.MessageMedia {
        var flags: Int32 = 0
        if publicData != nil {
            flags |= 1 << 3
        }
        if chatData != nil {
            flags |= 1 << 4
        }
        if widgetId != nil {
            flags |= 1 << 5
        }
        return .messageMediaWidget(.init(flags: flags, width: 0, height: 0, payload: Buffer(data: Data("<p>w</p>".utf8)), publicData: publicData, publicDataHash: publicData == nil ? nil : (publicDataHash ?? 0), chatData: chatData, widgetId: widgetId))
    }

    /// widget-sandbox v0.2: the bot's edit of a message widget's state in a private chat (`updateMessageWidgetData`,
    /// the account's pts sequence). A nil field is absent (unchanged); "" clears it.
    static func updateMessageWidgetData(userId: Int64, msgId: Int32, chatData: String?, publicData: String?, publicDataHash: Int64? = nil, pts: Int32) -> Api.Update {
        var flags: Int32 = 0
        if publicData != nil {
            flags |= 1 << 0
        }
        if chatData != nil {
            flags |= 1 << 1
        }
        return .updateMessageWidgetData(.init(flags: flags, peer: self.peerUser(userId), msgId: msgId, publicData: publicData, publicDataHash: publicData == nil ? nil : (publicDataHash ?? 0), chatData: chatData, pts: pts, ptsCount: 1))
    }

    /// A broadcast channel post: `post` flags.14, no `from_id`, `reply_to` flags.3.
    static func channelPost(id: Int32, channelId: Int64, date: Int32, text: String = "post", replyToMessageId: Int32? = nil) -> Api.Message {
        var flags: Int32 = 1 << 14
        if replyToMessageId != nil {
            flags |= 1 << 3
        }
        return .message(.init(flags: flags, flags2: 0, id: id, fromId: nil, fromBoostsApplied: nil, fromRank: nil, peerId: self.peerChannel(channelId), savedPeerId: nil, fwdFrom: nil, viaBotId: nil, viaBusinessBotId: nil, guestchatViaFrom: nil, replyTo: replyToMessageId.flatMap { self.replyHeader(toMessageId: $0) }, date: date, message: text, media: nil, replyMarkup: nil, entities: nil, views: nil, forwards: nil, replies: nil, editDate: nil, postAuthor: nil, groupedId: nil, reactions: nil, restrictionReason: nil, ttlPeriod: nil, quickReplyShortcutId: nil, effect: nil, factcheck: nil, reportDeliveryUntilDate: nil, paidMessageStars: nil, suggestedPost: nil, scheduleRepeatPeriod: nil, summaryFromLanguage: nil, richMessage: nil))
    }

    /// `encryptedMessageService#23734b06`. `bytes` must be non-empty (MemoryBuffer(Buffer) mallocs
    /// its size and force-unwraps) and at least 8 bytes (`keyFingerprintFromBytes` copies 8 once size >= 4).
    static func encryptedServiceMessage(chatId: Int32, randomId: Int64, date: Int32) -> Api.EncryptedMessage {
        return .encryptedMessageService(.init(randomId: randomId, chatId: chatId, date: date, bytes: Buffer(data: Data(count: 16))))
    }

    // MARK: - Update

    static func updateNewMessage(_ message: Api.Message, pts: Int32, ptsCount: Int32 = 1) -> Api.Update {
        return .updateNewMessage(.init(message: message, pts: pts, ptsCount: ptsCount))
    }

    static func updateNewChannelMessage(_ message: Api.Message, pts: Int32, ptsCount: Int32 = 1) -> Api.Update {
        return .updateNewChannelMessage(.init(message: message, pts: pts, ptsCount: ptsCount))
    }

    static func updateDeleteChannelMessages(channelId: Int64, messages: [Int32], pts: Int32, ptsCount: Int32) -> Api.Update {
        return .updateDeleteChannelMessages(.init(channelId: channelId, messages: messages, pts: pts, ptsCount: ptsCount))
    }

    /// `updateChannelTooLong#108d941f`: `pts` flags.0.
    static func updateChannelTooLong(channelId: Int64, pts: Int32?) -> Api.Update {
        return .updateChannelTooLong(.init(flags: pts != nil ? (1 << 0) : 0, channelId: channelId, pts: pts))
    }

    /// `updatePinnedForumTopics#def143d0`: without `order` (flags.0) the update only says the pinned topics changed;
    /// with it, it carries the new order of the pinned topics' ids.
    static func updatePinnedForumTopics(peer: Api.Peer, order: [Int32]? = nil) -> Api.Update {
        return .updatePinnedForumTopics(.init(flags: order != nil ? (1 << 0) : 0, peer: peer, order: order))
    }

    /// `updateReadHistoryInbox#9e84bc99`: no `folder_id` (flags.0), no `top_msg_id` (flags.1).
    static func updateReadHistoryInbox(peer: Api.Peer, maxId: Int32, stillUnreadCount: Int32, pts: Int32, ptsCount: Int32 = 1) -> Api.Update {
        return .updateReadHistoryInbox(.init(flags: 0, folderId: nil, peer: peer, topMsgId: nil, maxId: maxId, stillUnreadCount: stillUnreadCount, pts: pts, ptsCount: ptsCount))
    }

    /// A non-sequenced update: no pts, no qts, so `groupUpdates` puts it in the date (or seq) group.
    /// It is applied only when the group's date is within 60 s of `network.currentGlobalTime`.
    static func updateUserTyping(userId: Int64) -> Api.Update {
        return .updateUserTyping(.init(flags: 0, userId: userId, topMsgId: nil, action: .sendMessageTypingAction))
    }

    /// The only qts-carrying update (`apiUpdateQtsRange` in UpdateGroup.swift).
    static func updateNewEncryptedMessage(chatId: Int32 = 1, randomId: Int64 = 1, date: Int32, qts: Int32) -> Api.Update {
        return .updateNewEncryptedMessage(.init(message: self.encryptedServiceMessage(chatId: chatId, randomId: randomId, date: date), qts: qts))
    }

    /// `dialogPeer#e56dbf05` for the chat with user `userId`.
    static func dialogPeerUser(_ userId: Int64) -> Api.DialogPeer {
        return .dialogPeer(.init(peer: self.peerUser(userId)))
    }

    /// `dialogPeerFolder#514519e2`: a chat folder (folder 1 is the archive). It names no peer:
    /// `Api.DialogPeer.peerId` is nil (issue G4).
    static func dialogPeerFolder(folderId: Int32 = 1) -> Api.DialogPeer {
        return .dialogPeerFolder(.init(folderId: folderId))
    }

    /// `updateDialogPinned#6e6fe51c`: `pinned` flags.0 when asked; no `folder_id` (flags.1), so the
    /// root chat list.
    static func updateDialogPinned(_ peer: Api.DialogPeer, pinned: Bool) -> Api.Update {
        return .updateDialogPinned(.init(flags: pinned ? (1 << 0) : 0, folderId: nil, peer: peer))
    }

    /// `updatePinnedDialogs#fa0f3ca2`: `order` flags.0; no `folder_id` (flags.1), so the root chat list.
    static func updatePinnedDialogs(order: [Api.DialogPeer]) -> Api.Update {
        return .updatePinnedDialogs(.init(flags: 1 << 0, folderId: nil, order: order))
    }

    // MARK: - Updates (pushes)

    /// `seq == 0` makes `groupUpdates` emit a date group; any other value a seq group of size 1.
    static func updates(_ updates: [Api.Update], users: [Api.User] = [], chats: [Api.Chat] = [], date: Int32, seq: Int32) -> Api.Updates {
        return .updates(.init(updates: updates, users: users, chats: chats, date: date, seq: seq))
    }

    /// Always a date group (`seqRange: nil`).
    static func updateShort(_ update: Api.Update, date: Int32) -> Api.Updates {
        return .updateShort(.init(update: update, date: date))
    }

    static func updatesTooLong() -> Api.Updates {
        return .updatesTooLong
    }

    /// `updateShortMessage#313bc7f8`, incoming (no `out` flag): `UpdateMessageService` turns it into an
    /// `updateNewMessage` from `userId` in the private chat with `userId`, in a pts group plus an empty
    /// date group.
    static func updateShortMessage(id: Int32, userId: Int64, pts: Int32, ptsCount: Int32 = 1, date: Int32, text: String = "text") -> Api.Updates {
        return .updateShortMessage(.init(flags: 0, id: id, userId: userId, message: text, pts: pts, ptsCount: ptsCount, date: date, fwdFrom: nil, viaBotId: nil, replyTo: nil, entities: nil, ttlPeriod: nil))
    }

    /// `updatesCombined`: `UpdateMessageService` encodes its seq range as `(seq, seq - seqStart + 1)`, the
    /// container covering `seqStart...seq`.
    static func updatesCombined(_ updates: [Api.Update], users: [Api.User] = [], chats: [Api.Chat] = [], date: Int32, seqStart: Int32, seq: Int32) -> Api.Updates {
        return .updatesCombined(.init(updates: updates, users: users, chats: chats, date: date, seqStart: seqStart, seq: seq))
    }

    // MARK: - Request payloads

    /// The exact bytes `Network` hands the engine for `updates.getDifference` with these arguments
    /// (compare with `ScriptedRequest.payload`). The main app and the extension send `pts_total_limit`
    /// (flags.0) on every request: 10000 when the app configuration has no `pts_total_limit` (audit Q14).
    /// nil is a request without it (flags 0). `pts_limit` and `qts_limit` are never sent.
    static func getDifferencePayload(pts: Int32, date: Int32, qts: Int32, ptsTotalLimit: Int32? = 10000) -> Data {
        let flags: Int32 = ptsTotalLimit != nil ? (1 << 0) : 0
        return Api.functions.updates.getDifference(flags: flags, pts: pts, ptsLimit: nil, ptsTotalLimit: ptsTotalLimit, date: date, qts: qts, qtsLimit: nil).1.makeData()
    }

    /// `updateShortSentMessage#9015e101`: `out` flags.1. Becomes `[.updatePts(pts:ptsCount:)]`.
    static func updateShortSentMessage(id: Int32, pts: Int32, ptsCount: Int32 = 1, date: Int32) -> Api.Updates {
        return .updateShortSentMessage(.init(flags: 1 << 1, id: id, pts: pts, ptsCount: ptsCount, date: date, media: nil, entities: nil, ttlPeriod: nil))
    }

    // MARK: - updates.State / updates.Difference

    static func state(pts: Int32, qts: Int32 = 0, date: Int32, seq: Int32, unreadCount: Int32 = 0) -> Api.updates.State {
        return .state(.init(pts: pts, qts: qts, date: date, seq: seq, unreadCount: unreadCount))
    }

    static func differenceEmpty(date: Int32, seq: Int32) -> Api.updates.Difference {
        return .differenceEmpty(.init(date: date, seq: seq))
    }

    static func difference(newMessages: [Api.Message] = [], newEncryptedMessages: [Api.EncryptedMessage] = [], otherUpdates: [Api.Update] = [], chats: [Api.Chat] = [], users: [Api.User] = [], state: Api.updates.State) -> Api.updates.Difference {
        return .difference(.init(newMessages: newMessages, newEncryptedMessages: newEncryptedMessages, otherUpdates: otherUpdates, chats: chats, users: users, state: state))
    }

    static func differenceSlice(newMessages: [Api.Message] = [], newEncryptedMessages: [Api.EncryptedMessage] = [], otherUpdates: [Api.Update] = [], chats: [Api.Chat] = [], users: [Api.User] = [], intermediateState: Api.updates.State) -> Api.updates.Difference {
        return .differenceSlice(.init(newMessages: newMessages, newEncryptedMessages: newEncryptedMessages, otherUpdates: otherUpdates, chats: chats, users: users, intermediateState: intermediateState))
    }

    static func differenceTooLong(pts: Int32) -> Api.updates.Difference {
        return .differenceTooLong(.init(pts: pts))
    }

    // MARK: - updates.ChannelDifference (`final` flags.0, `timeout` flags.1)

    private static func channelDifferenceFlags(isFinal: Bool, timeout: Int32?) -> Int32 {
        var flags: Int32 = 0
        if isFinal {
            flags |= 1 << 0
        }
        if timeout != nil {
            flags |= 1 << 1
        }
        return flags
    }

    static func channelDifferenceEmpty(pts: Int32, timeout: Int32? = nil, isFinal: Bool = true) -> Api.updates.ChannelDifference {
        return .channelDifferenceEmpty(.init(flags: self.channelDifferenceFlags(isFinal: isFinal, timeout: timeout), pts: pts, timeout: timeout))
    }

    static func channelDifference(pts: Int32, timeout: Int32? = nil, isFinal: Bool = true, newMessages: [Api.Message] = [], otherUpdates: [Api.Update] = [], chats: [Api.Chat] = [], users: [Api.User] = []) -> Api.updates.ChannelDifference {
        return .channelDifference(.init(flags: self.channelDifferenceFlags(isFinal: isFinal, timeout: timeout), pts: pts, timeout: timeout, newMessages: newMessages, otherUpdates: otherUpdates, chats: chats, users: users))
    }

    /// The new channel pts travels in `dialog`'s `pts`: `pollChannel` asserts when it is nil.
    static func channelDifferenceTooLong(dialog: Api.Dialog, messages: [Api.Message] = [], chats: [Api.Chat] = [], users: [Api.User] = [], timeout: Int32? = nil, isFinal: Bool = true) -> Api.updates.ChannelDifference {
        return .channelDifferenceTooLong(.init(flags: self.channelDifferenceFlags(isFinal: isFinal, timeout: timeout), timeout: timeout, dialog: dialog, messages: messages, chats: chats, users: users))
    }

    // MARK: - Dialogs

    static func emptyNotifySettings() -> Api.PeerNotifySettings {
        return .peerNotifySettings(.init(flags: 0, showPreviews: nil, silent: nil, muteUntil: nil, iosSound: nil, androidSound: nil, otherSound: nil, storiesMuted: nil, storiesHideSender: nil, storiesIosSound: nil, storiesAndroidSound: nil, storiesOtherSound: nil))
    }

    /// `dialog#fc89f7f3`: `pts` flags.0 (channels only), `pinned` flags.2 when asked.
    static func dialog(peer: Api.Peer, topMessage: Int32, readInboxMaxId: Int32 = 0, readOutboxMaxId: Int32 = 0, unreadCount: Int32 = 0, pts: Int32? = nil, pinned: Bool = false) -> Api.Dialog {
        var flags: Int32 = 0
        if pts != nil {
            flags |= 1 << 0
        }
        if pinned {
            flags |= 1 << 2
        }
        return .dialog(.init(flags: flags, peer: peer, topMessage: topMessage, readInboxMaxId: readInboxMaxId, readOutboxMaxId: readOutboxMaxId, unreadCount: unreadCount, unreadMentionsCount: 0, unreadReactionsCount: 0, unreadPollVotesCount: 0, notifySettings: self.emptyNotifySettings(), pts: pts, draft: nil, folderId: nil, ttlPeriod: nil))
    }

    /// Answer to `messages.getPeerDialogs` and `messages.getPinnedDialogs`.
    static func peerDialogs(dialogs: [Api.Dialog] = [], messages: [Api.Message] = [], chats: [Api.Chat] = [], users: [Api.User] = [], state: Api.updates.State) -> Api.messages.PeerDialogs {
        return .peerDialogs(.init(dialogs: dialogs, messages: messages, chats: chats, users: users, state: state))
    }

    /// Answer to `messages.getDialogs`: the complete list (`apiIsAtLowestBoundary == true`).
    static func dialogs(dialogs: [Api.Dialog] = [], messages: [Api.Message] = [], chats: [Api.Chat] = [], users: [Api.User] = []) -> Api.messages.Dialogs {
        return .dialogs(.init(dialogs: dialogs, messages: messages, chats: chats, users: users))
    }

    /// Answer to `messages.getDialogs`: a page of a longer list (`apiIsAtLowestBoundary == false`).
    static func dialogsSlice(count: Int32, dialogs: [Api.Dialog] = [], messages: [Api.Message] = [], chats: [Api.Chat] = [], users: [Api.User] = []) -> Api.messages.Dialogs {
        return .dialogsSlice(.init(count: count, dialogs: dialogs, messages: messages, chats: chats, users: users))
    }

    /// Answer to `messages.getDialogs` when the list did not change since the request's `hash`
    /// (`messages.dialogsNotModified#f0e3e596`); `fetchChatList` turns it into nil.
    static func dialogsNotModified(count: Int32 = 0) -> Api.messages.Dialogs {
        return .dialogsNotModified(.init(count: count))
    }

    // MARK: - messages.Messages (reply targets)

    /// Answer to `messages.getMessages` (users, basic groups).
    static func messages(_ messages: [Api.Message], chats: [Api.Chat] = [], users: [Api.User] = []) -> Api.messages.Messages {
        return .messages(.init(messages: messages, topics: [], chats: chats, users: users))
    }

    /// Answer to `channels.getMessages`. `offset_id_offset` (flags.2) and `inexact` (flags.1) unset.
    static func channelMessages(pts: Int32, _ messages: [Api.Message], chats: [Api.Chat] = [], users: [Api.User] = []) -> Api.messages.Messages {
        return .channelMessages(.init(flags: 0, pts: pts, count: Int32(messages.count), offsetIdOffset: nil, messages: messages, topics: [], chats: chats, users: users))
    }

    /// Answer to `messages.getForumTopics` / `messages.getForumTopicsByID`, if a test ever needs one.
    static func forumTopics(pts: Int32) -> Api.messages.ForumTopics {
        return .forumTopics(.init(flags: 0, count: 0, topics: [], messages: [], chats: [], users: [], pts: pts))
    }

    /// Answer to `help.test`.
    static func boolTrue() -> Api.Bool {
        return .boolTrue
    }
}
