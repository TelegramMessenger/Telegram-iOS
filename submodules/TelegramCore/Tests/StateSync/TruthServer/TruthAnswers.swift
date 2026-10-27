import Foundation
import TelegramApi
@testable import TelegramCore

/// How much one answer carries.
struct TruthLimits {
    /// Log entries per `getDifference` answer; more makes it a `differenceSlice`.
    var differenceSlice = 20
    /// A channel this many pts behind gets `channelDifferenceTooLong`.
    var channelDifferenceTooLong = 60
    /// Messages a `channelDifferenceTooLong` carries, newest first.
    var channelTooLongMessages = 20
}

// MARK: - Api values for the world

enum TruthApi {
    static func user(_ id: Int64) -> Api.User {
        return StateSyncApi.user(id: id, accessHash: 1, firstName: "U\(id)", isSelf: id == TruthWorld.accountId)
    }

    static func users(_ world: TruthWorld) -> [Api.User] {
        return ([TruthWorld.accountId] + world.users).map { self.user($0) }
    }

    /// `chat#41cbf256` for a basic group the account is in.
    static func basicGroup(_ id: Int64, world: TruthWorld) -> Api.Chat {
        return .chat(.init(flags: 0, id: id, title: "G\(id)", photo: .chatPhotoEmpty, participantsCount: Int32(world.shape.groupMembers.count + 1), date: 1, version: 1, migratedTo: nil, adminRights: nil, defaultBannedRights: nil))
    }

    /// `channel#…` for a megagroup the account is in: `megagroup` flags.8, `access_hash` flags.13.
    static func megagroup(_ id: Int64) -> Api.Chat {
        let flags: Int32 = (1 << 8) | (1 << 13)
        return .channel(.init(flags: flags, flags2: 0, id: id, accessHash: 1, title: "M\(id)", username: nil, photo: .chatPhotoEmpty, date: 1, restrictionReason: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, participantsCount: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, emojiStatus: nil, level: nil, subscriptionUntilDate: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedMonoforumId: nil, linkedCommunityId: nil, pinnedMsgId: nil))
    }

    static func chats(_ world: TruthWorld) -> [Api.Chat] {
        return world.basicGroups.map { self.basicGroup($0, world: world) } + world.broadcastChannels.map { StateSyncApi.broadcastChannel(id: $0, accessHash: 1, title: "C\($0)") } + world.megagroups.map { self.megagroup($0) }
    }

    static func peer(_ chat: TruthPeer) -> Api.Peer {
        switch chat {
        case let .user(id):
            return .peerUser(.init(userId: id))
        case let .chat(id):
            return .peerChat(.init(chatId: id))
        case let .channel(id):
            return .peerChannel(.init(channelId: id))
        case .selfUser:
            return .peerUser(.init(userId: TruthWorld.accountId))
        }
    }

    /// `message#7600b9d3`: `out` flags.1; `from_id` flags.8 on a private chat's incoming message and on every group
    /// and megagroup message; `post` flags.14, and no `from_id`, on a broadcast post; `edit_date` flags.15 on an
    /// edited message.
    static func message(_ message: TruthMessage) -> Api.Message {
        var flags: Int32 = 0
        if message.outgoing {
            flags |= 1 << 1
        }
        var fromId: Api.Peer?
        switch message.chat {
        case .user:
            fromId = message.outgoing ? nil : message.fromUserId.map { .peerUser(.init(userId: $0)) }
        case .chat, .channel:
            fromId = message.fromUserId.map { .peerUser(.init(userId: $0)) }
        case .selfUser:
            fromId = nil
        }
        // A broadcast post is the one channel message without an author (`TruthWorld.receive`).
        if message.chat.isChannel && message.fromUserId == nil {
            flags |= 1 << 14
            fromId = nil
        }
        if fromId != nil {
            flags |= 1 << 8
        }
        if message.editDate != nil {
            flags |= 1 << 15
        }
        return .message(.init(flags: flags, flags2: 0, id: message.id, fromId: fromId, fromBoostsApplied: nil, fromRank: nil, peerId: self.peer(message.chat), savedPeerId: nil, fwdFrom: nil, viaBotId: nil, viaBusinessBotId: nil, guestchatViaFrom: nil, replyTo: nil, date: message.date, message: message.text, media: nil, replyMarkup: nil, entities: nil, views: nil, forwards: nil, replies: nil, editDate: message.editDate, postAuthor: nil, groupedId: nil, reactions: nil, restrictionReason: nil, ttlPeriod: nil, quickReplyShortcutId: nil, effect: nil, factcheck: nil, reportDeliveryUntilDate: nil, paidMessageStars: nil, suggestedPost: nil, scheduleRepeatPeriod: nil, summaryFromLanguage: nil, richMessage: nil))
    }

    /// `messageService#7a800e0a` with `messageActionHistoryClear`: a cleared chat's top in the chat list.
    static func historyClear(_ chat: TruthPeer, id: Int32, date: Int32) -> Api.Message {
        return .messageService(.init(flags: 0, id: id, fromId: nil, peerId: self.peer(chat), savedPeerId: nil, replyTo: nil, date: date, action: .messageActionHistoryClear, reactions: nil, ttlPeriod: nil))
    }

    static func messageEmpty(_ id: Int32) -> Api.Message {
        return .messageEmpty(.init(flags: 0, id: id, peerId: nil))
    }

    static func state(_ world: TruthWorld, pts: Int32? = nil) -> Api.updates.State {
        return StateSyncApi.state(pts: pts ?? world.pts, qts: world.qts, date: world.date, seq: world.seq)
    }
}

// MARK: - The chat list

/// A chat's top in the chat list: its newest message, or a cleared chat's service message; nil when it has neither.
private func truthDialogTop(_ chat: TruthPeer, world: TruthWorld) -> (id: Int32, date: Int32, message: Api.Message)? {
    if let newest = world.existing(chat).last {
        return (newest.id, newest.date, TruthApi.message(newest))
    }
    if let cleared = world.clearedTop[chat] {
        return (cleared.id, cleared.date, TruthApi.historyClear(chat, id: cleared.id, date: cleared.date))
    }
    return nil
}

/// The chat's dialog, everything read; a channel's carries its pts, which marks it delivered.
private func truthDialog(_ chat: TruthPeer, top: Int32, world: TruthWorld) -> Api.Dialog {
    var pts: Int32?
    if case let .channel(channelId) = chat {
        pts = world.channelPts[channelId]
        world.deliveredChannelPts[channelId] = pts
    }
    return StateSyncApi.dialog(peer: TruthApi.peer(chat), topMessage: top, readInboxMaxId: top, readOutboxMaxId: top, unreadCount: 0, pts: pts)
}

private func truthDialogs(_ chats: [TruthPeer], world: TruthWorld) -> (dialogs: [Api.Dialog], messages: [Api.Message]) {
    var dialogs: [Api.Dialog] = []
    var messages: [Api.Message] = []
    for chat in chats {
        if let top = truthDialogTop(chat, world: world) {
            dialogs.append(truthDialog(chat, top: top.id, world: world))
            messages.append(top.message)
        }
    }
    return (dialogs, messages)
}

// MARK: - Answers

/// The world's answer to `request`, of exactly the function's result type, or nil when the truth server does not
/// answer it. Answering reads the world and marks the channel pts it hands out as delivered.
func truthAnswer(_ request: TruthRequest, world: TruthWorld, limits: TruthLimits) -> Any? {
    switch request {
    case .getState:
        return TruthApi.state(world)
    case let .getDifference(pts, _, ptsTotalLimit, _, _):
        return truthDifference(after: pts, ptsTotalLimit: ptsTotalLimit, world: world, limits: limits)
    case let .getChannelDifference(channelId, pts, limit):
        return truthChannelDifference(channelId, after: pts, limit: limit, world: world, limits: limits)
    case let .getHistory(peer, offsetId, addOffset, limit, maxId, minId):
        return truthHistory(peer, offsetId: offsetId, addOffset: addOffset, limit: limit, maxId: maxId, minId: minId, world: world)
    case let .getMessages(ids):
        let messages = ids.map { id -> Api.Message in
            return world.accountMessage(id).map(TruthApi.message) ?? TruthApi.messageEmpty(id)
        }
        return StateSyncApi.messages(messages, chats: TruthApi.chats(world), users: TruthApi.users(world))
    case let .channelsGetMessages(channelId, ids):
        let messages = ids.map { id -> Api.Message in
            return world.message(.channel(channelId), id).map(TruthApi.message) ?? TruthApi.messageEmpty(id)
        }
        return Api.messages.Messages.channelMessages(.init(flags: 0, pts: world.channelPts[channelId] ?? 0, count: Int32(messages.count), offsetIdOffset: nil, messages: messages, topics: [], chats: TruthApi.chats(world), users: TruthApi.users(world)))
    case let .getDialogs(folderId, offsetDate, offsetId, offsetPeer, limit):
        if let folderId, folderId != 0 {
            return StateSyncApi.dialogs()
        }
        var ordered = world.chats().compactMap { chat -> (TruthPeer, Int32, Int32)? in
            return truthDialogTop(chat, world: world).map { (chat, $0.date, $0.id) }
        }
        // Newest top first; a tie of date and id (a private chat and a channel share no id space) is broken by the
        // peer, which `offset_peer` names, so the next page starts after the page's last dialog itself.
        let key: (TruthPeer, Int32, Int32) -> (Int32, Int32, Int64) = { peer, date, id in
            return (date, id, peer.peerId.toInt64())
        }
        ordered.sort(by: { lhs, rhs in
            return key(lhs.0, lhs.1, lhs.2) > key(rhs.0, rhs.1, rhs.2)
        })
        var start = 0
        if offsetDate != 0 || offsetId != 0 || offsetPeer != nil {
            let offsetKey = (offsetDate, offsetId, offsetPeer?.peerId.toInt64() ?? Int64.min)
            start = ordered.firstIndex(where: { key($0.0, $0.1, $0.2) < offsetKey }) ?? ordered.count
        }
        let page = Array(ordered[start ..< min(ordered.count, start + Int(limit))])
        let (dialogs, messages) = truthDialogs(page.map { $0.0 }, world: world)
        if start == 0 && page.count == ordered.count {
            return StateSyncApi.dialogs(dialogs: dialogs, messages: messages, chats: TruthApi.chats(world), users: TruthApi.users(world))
        }
        return StateSyncApi.dialogsSlice(count: Int32(ordered.count), dialogs: dialogs, messages: messages, chats: TruthApi.chats(world), users: TruthApi.users(world))
    case .getPinnedDialogs:
        return StateSyncApi.peerDialogs(chats: TruthApi.chats(world), users: TruthApi.users(world), state: TruthApi.state(world))
    case let .getPeerDialogs(peers):
        let (dialogs, messages) = truthDialogs(peers, world: world)
        return StateSyncApi.peerDialogs(dialogs: dialogs, messages: messages, chats: TruthApi.chats(world), users: TruthApi.users(world), state: TruthApi.state(world))
    case .other:
        return nil
    }
}

/// `getHistory`: the chat's messages inside `minId < id < maxId` (a 0 bound is no bound), newest first; the window
/// starts at the first one older than `offsetId` (0: the newest), moved by `addOffset`, `limit` long. The whole
/// chat answers `.messages`, a part `.messagesSlice` with the total and `offsetIdOffset` (1 + how many are newer
/// than `offsetId`); a channel answers `.channelMessages` with its pts.
private func truthHistory(_ peer: TruthPeer, offsetId: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32, world: TruthWorld) -> Api.messages.Messages {
    let all = world.existing(peer)
    let filtered = all.reversed().filter { message in
        return (maxId == 0 || message.id < maxId) && (minId == 0 || message.id > minId)
    }
    let index = offsetId == 0 ? 0 : (filtered.firstIndex(where: { $0.id < offsetId }) ?? filtered.count)
    let lower = max(0, min(filtered.count, index + Int(addOffset)))
    let upper = max(lower, min(filtered.count, index + Int(addOffset) + Int(limit)))
    let window = Array(filtered[lower ..< upper]).map(TruthApi.message)
    let offsetIdOffset = Int32(1 + filtered.filter({ $0.id > offsetId }).count)
    if case let .channel(channelId) = peer {
        return .channelMessages(.init(flags: 1 << 2, pts: world.channelPts[channelId] ?? 0, count: Int32(all.count), offsetIdOffset: offsetIdOffset, messages: window, topics: [], chats: TruthApi.chats(world), users: TruthApi.users(world)))
    }
    if window.count == all.count {
        return StateSyncApi.messages(window, chats: TruthApi.chats(world), users: TruthApi.users(world))
    }
    return .messagesSlice(.init(flags: 1 << 2, count: Int32(all.count), nextRate: nil, offsetIdOffset: offsetIdOffset, searchFlood: nil, messages: window, topics: [], chats: TruthApi.chats(world), users: TruthApi.users(world)))
}

/// `getDifference`: empty at the world's pts; `differenceTooLong` past `ptsTotalLimit`; else the log after `pts`, at
/// most `limits.differenceSlice` entries. New messages that still exist go in `new_messages` as they are now; each
/// deletion is an `updateDeleteMessages`, each edit of a message older than `pts` an `updateEditMessage`; every
/// channel with entries the app has not been sent gets an `updateChannelTooLong`.
private func truthDifference(after pts: Int32, ptsTotalLimit: Int32?, world: TruthWorld, limits: TruthLimits) -> Api.updates.Difference {
    if pts >= world.pts {
        return StateSyncApi.differenceEmpty(date: world.date, seq: world.seq)
    }
    if let ptsTotalLimit, world.pts - pts > ptsTotalLimit {
        return StateSyncApi.differenceTooLong(pts: world.pts)
    }
    let entries = world.accountLog(after: pts)
    let taken = Array(entries.prefix(limits.differenceSlice))
    let isSlice = taken.count < entries.count
    var newMessages: [Api.Message] = []
    var otherUpdates: [Api.Update] = []
    var createdInRange = Set<Int32>()
    for entry in taken {
        switch entry.event {
        case let .newMessage(message):
            createdInRange.insert(message.id)
            if let current = world.accountMessage(message.id) {
                newMessages.append(TruthApi.message(current))
            }
        case let .edit(message):
            if !createdInRange.contains(message.id), let current = world.accountMessage(message.id) {
                otherUpdates.append(.updateEditMessage(.init(message: TruthApi.message(current), pts: entry.pts, ptsCount: entry.ptsCount)))
            }
        case let .delete(_, ids):
            otherUpdates.append(.updateDeleteMessages(.init(messages: ids, pts: entry.pts, ptsCount: entry.ptsCount)))
        }
    }
    for channelId in world.channels {
        if let channelPts = world.channelPts[channelId], channelPts > (world.deliveredChannelPts[channelId] ?? 0) {
            otherUpdates.append(StateSyncApi.updateChannelTooLong(channelId: channelId, pts: channelPts))
        }
    }
    if isSlice {
        return StateSyncApi.differenceSlice(newMessages: newMessages, otherUpdates: otherUpdates, chats: TruthApi.chats(world), users: TruthApi.users(world), intermediateState: TruthApi.state(world, pts: taken.last!.pts))
    }
    return StateSyncApi.difference(newMessages: newMessages, otherUpdates: otherUpdates, chats: TruthApi.chats(world), users: TruthApi.users(world), state: TruthApi.state(world))
}

/// `getChannelDifference`: empty at the channel's pts; `channelDifferenceTooLong` more than
/// `limits.channelDifferenceTooLong` behind (the dialog at the pts now and the newest messages); else the log after
/// `pts`, at most `limit` entries, `final` when that is all of it.
private func truthChannelDifference(_ channelId: Int64, after pts: Int32, limit: Int32, world: TruthWorld, limits: TruthLimits) -> Api.updates.ChannelDifference {
    let chat = TruthPeer.channel(channelId)
    let channelPts = world.channelPts[channelId] ?? 0
    if pts >= channelPts {
        world.deliveredChannelPts[channelId] = channelPts
        return StateSyncApi.channelDifferenceEmpty(pts: channelPts)
    }
    if channelPts - pts > Int32(limits.channelDifferenceTooLong) {
        let newest = world.existing(chat).suffix(limits.channelTooLongMessages).reversed().map(TruthApi.message)
        let top = world.existing(chat).last?.id ?? 0
        let dialog = truthDialog(chat, top: top, world: world)
        return StateSyncApi.channelDifferenceTooLong(dialog: dialog, messages: newest, chats: TruthApi.chats(world), users: TruthApi.users(world))
    }
    let entries = world.channelLog(channelId, after: pts)
    let taken = Array(entries.prefix(Int(max(1, limit))))
    var newMessages: [Api.Message] = []
    var otherUpdates: [Api.Update] = []
    var createdInRange = Set<Int32>()
    for entry in taken {
        switch entry.event {
        case let .newMessage(message):
            createdInRange.insert(message.id)
            if let current = world.message(chat, message.id) {
                newMessages.append(TruthApi.message(current))
            }
        case let .edit(message):
            if !createdInRange.contains(message.id), let current = world.message(chat, message.id) {
                otherUpdates.append(.updateEditChannelMessage(.init(message: TruthApi.message(current), pts: entry.pts, ptsCount: entry.ptsCount)))
            }
        case let .delete(_, ids):
            otherUpdates.append(StateSyncApi.updateDeleteChannelMessages(channelId: channelId, messages: ids, pts: entry.pts, ptsCount: entry.ptsCount))
        }
    }
    let newPts = taken.last!.pts
    world.deliveredChannelPts[channelId] = max(world.deliveredChannelPts[channelId] ?? 0, newPts)
    return StateSyncApi.channelDifference(pts: newPts, isFinal: taken.count == entries.count, newMessages: newMessages, otherUpdates: otherUpdates, chats: TruthApi.chats(world), users: TruthApi.users(world))
}
