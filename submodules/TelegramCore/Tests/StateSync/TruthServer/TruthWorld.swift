import Foundation

/// One message as the server has it now.
struct TruthMessage: Equatable {
    let id: Int32
    let chat: TruthPeer
    /// The author: nil for a broadcast channel's post; `TruthWorld.accountId` for the account's own messages.
    let fromUserId: Int64?
    let outgoing: Bool
    let date: Int32
    var text: String
    /// When it was last edited, nil if never: the server's `edit_date`.
    var editDate: Int32? = nil
}

/// What one log entry did.
enum TruthEvent {
    case newMessage(TruthMessage)
    case edit(TruthMessage)
    case delete(chat: TruthPeer, ids: [Int32])
}

/// One entry of the account's log (private chats and basic groups) or of one channel's. `pts` is the pts after the
/// entry, so an entry covers `pts - ptsCount + 1 ... pts`.
struct TruthLogEntry {
    let pts: Int32
    let ptsCount: Int32
    let event: TruthEvent
}

/// The server's truth for one account: three private chats, a basic group, a broadcast channel and a megagroup, every
/// message they hold now, and the logs that say how they got there. Ids follow Telegram: private chats and basic
/// groups take theirs from one account-wide counter and share the account's pts; each channel has its own counter and
/// pts. A new message, an edit and a deletion are one log entry each; a deletion's `ptsCount` is its id count.
/// The chats a world has and how much history each starts with.
struct TruthShape {
    var users: [Int64]
    var basicGroups: [Int64]
    var broadcastChannels: [Int64]
    var megagroups: [Int64]
    /// Who writes in the groups and megagroups besides the account.
    var groupMembers: [Int64]
    /// Chats that start with `quietMessages` messages each, stored before every other chat's, so they are the oldest
    /// in the chat list.
    var quietChats: [TruthPeer]
    var quietMessages: ClosedRange<Int>
    /// Chats that start with this many messages instead of the world's `initialMessagesPerChat`.
    var longChats: [TruthPeer: ClosedRange<Int>]

    /// The six chats of `makeTruthSession`: three private chats, a basic group, a broadcast channel and a megagroup.
    static let small = TruthShape(users: [201, 202, 203], basicGroups: [801], broadcastChannels: [301], megagroups: [302], groupMembers: [201, 202, 203], quietChats: [], quietMessages: 1 ... 3, longChats: [:])

    /// An account of a realistic size: the six chats of `small`, 120 quiet private chats (users 204…323), a quiet basic
    /// group (802), broadcast channel (303) and megagroup (304), so 129 chats, more than a dialogs page of 100; and a
    /// long private chat (201) and channel (301) of 300…400 messages, more than a history page of 100.
    static let large: TruthShape = {
        let quietUsers = Array(Int64(204) ... 323)
        return TruthShape(users: [201, 202, 203] + quietUsers, basicGroups: [801, 802], broadcastChannels: [301, 303], megagroups: [302, 304], groupMembers: [201, 202, 203], quietChats: quietUsers.map { TruthPeer.user($0) } + [.chat(802), .channel(303), .channel(304)], quietMessages: 1 ... 3, longChats: [.user(201): 300 ... 400, .channel(301): 300 ... 400])
    }()
}

final class TruthWorld {
    static let accountId: Int64 = 1000
    let shape: TruthShape
    var users: [Int64] {
        return self.shape.users
    }
    var basicGroups: [Int64] {
        return self.shape.basicGroups
    }
    var broadcastChannels: [Int64] {
        return self.shape.broadcastChannels
    }
    var megagroups: [Int64] {
        return self.shape.megagroups
    }
    var channels: [Int64] {
        return self.shape.broadcastChannels + self.shape.megagroups
    }

    /// Who writes in each chat besides the account (a broadcast channel's posts have no author).
    func members(of chat: TruthPeer) -> [Int64] {
        switch chat {
        case let .user(id):
            return [id]
        case .chat, .channel:
            return self.shape.groupMembers
        case .selfUser:
            return []
        }
    }

    func isBroadcast(_ chat: TruthPeer) -> Bool {
        if case let .channel(id) = chat {
            return self.shape.broadcastChannels.contains(id)
        }
        return false
    }

    private(set) var pts: Int32 = 1
    let qts: Int32 = 0
    let seq: Int32 = 1
    private(set) var date: Int32
    /// Every message and edit advances `date` by one, so no two tops share a date; a test that needs a tie (two
    /// messages in one second, as on the real server) holds it.
    var holdsClock = false
    private(set) var channelPts: [Int64: Int32] = [:]
    /// The channel pts the app has been sent so far: by pushes, channel differences and dialogs. A `getDifference`
    /// carries `updateChannelTooLong` for every channel past it. Written by the driver and the answers.
    var deliveredChannelPts: [Int64: Int32] = [:]

    private var nextAccountMessageId: Int32 = 1
    private var nextChannelMessageId: [Int64: Int32] = [:]
    private var messagesByChat: [TruthPeer: [Int32: TruthMessage]] = [:]
    private(set) var accountLog: [TruthLogEntry] = []
    private(set) var channelLogs: [Int64: [TruthLogEntry]] = [:]
    /// A cleared private chat or basic group keeps its old top message in the chat list as a
    /// `messageActionHistoryClear` service message with the old id and date (K1, 2026-10-24); it is no message of the
    /// history. Dropped when the chat gets a new message.
    private(set) var clearedTop: [TruthPeer: (id: Int32, date: Int32)] = [:]
    /// Every id that was a cleared chat's top, current or not. The app may keep the service message the chat list
    /// gave it (a reset stores a dialog's top above its hole, where no fill confirms it); whether the server still
    /// has it is not known, so the oracle judges none of these.
    private(set) var historyClearIds: [TruthPeer: Set<Int32>] = [:]

    /// `seed` interleaves the initial messages across the chats, so private-chat ids are not contiguous per chat. A
    /// shape's quiet chats get theirs first, one chat after another; with none (`small`) the draws are the ones every
    /// seed has made since the first run.
    init(seed: UInt64, initialMessagesPerChat: ClosedRange<Int>, baseDate: Int32, shape: TruthShape = .small) {
        self.shape = shape
        self.date = baseDate
        for channelId in self.channels {
            self.channelPts[channelId] = 1
            self.nextChannelMessageId[channelId] = 1
            self.channelLogs[channelId] = []
        }
        self.allChats = shape.users.map { TruthPeer.user($0) } + shape.basicGroups.map { TruthPeer.chat($0) } + (shape.broadcastChannels + shape.megagroups).map { TruthPeer.channel($0) }
        for chat in self.chats() {
            self.messagesByChat[chat] = [:]
        }
        var random = TruthRandom(seed: seed ^ 0x5eed)
        for chat in shape.quietChats {
            let count = shape.quietMessages.lowerBound + Int(random.next() % UInt64(shape.quietMessages.count))
            for _ in 0 ..< count {
                self.receive(in: chat, from: nil, text: "initial")
            }
        }
        let quiet = Set(shape.quietChats)
        var remaining: [TruthPeer: Int] = [:]
        for chat in self.chats() where !quiet.contains(chat) {
            let range = shape.longChats[chat] ?? initialMessagesPerChat
            remaining[chat] = range.lowerBound + Int(random.next() % UInt64(range.count))
        }
        while let chat = self.chats().filter({ (remaining[$0] ?? 0) > 0 }).randomElement(using: &random) {
            remaining[chat]! -= 1
            if random.next() % 3 == 0 && !self.isBroadcast(chat) {
                self.sendFromOtherDevice(in: chat, text: "initial")
            } else {
                self.receive(in: chat, from: nil, text: "initial")
            }
        }
        for channelId in self.channels {
            self.deliveredChannelPts[channelId] = self.channelPts[channelId]
        }
    }

    private var allChats: [TruthPeer] = []

    func chats() -> [TruthPeer] {
        return self.allChats
    }

    /// The chat's messages, ascending ids.
    func existing(_ chat: TruthPeer) -> [TruthMessage] {
        return (self.messagesByChat[chat] ?? [:]).values.sorted(by: { $0.id < $1.id })
    }

    func message(_ chat: TruthPeer, _ id: Int32) -> TruthMessage? {
        return self.messagesByChat[chat]?[id]
    }

    /// The private-chat or basic-group message with account-wide id `id`, if it exists.
    func accountMessage(_ id: Int32) -> TruthMessage? {
        for chat in self.chats() where !chat.isChannel {
            if let message = self.messagesByChat[chat]?[id] {
                return message
            }
        }
        return nil
    }

    /// A message from `userId` (a member, or a random one when nil); a post in a broadcast channel.
    @discardableResult
    func receive(in chat: TruthPeer, from userId: Int64?, text: String) -> TruthLogEntry {
        let author: Int64?
        if self.isBroadcast(chat) {
            author = nil
        } else {
            author = userId ?? self.members(of: chat)[Int(self.date) % self.members(of: chat).count]
        }
        return self.addMessage(in: chat, fromUserId: author, outgoing: false, text: text)
    }

    /// The account's own message, sent from another device. A broadcast channel takes a post instead.
    @discardableResult
    func sendFromOtherDevice(in chat: TruthPeer, text: String) -> TruthLogEntry {
        if self.isBroadcast(chat) {
            return self.receive(in: chat, from: nil, text: text)
        }
        return self.addMessage(in: chat, fromUserId: TruthWorld.accountId, outgoing: true, text: text)
    }

    @discardableResult
    func edit(_ chat: TruthPeer, _ id: Int32, text: String) -> TruthLogEntry {
        guard var message = self.messagesByChat[chat]?[id] else {
            preconditionFailure("truth world: edit of \(chat) \(id), which does not exist")
        }
        self.date += 1
        message.text = text
        message.editDate = self.date
        self.messagesByChat[chat]![id] = message
        return self.append(TruthEvent.edit(message), chat: chat, ptsCount: 1)
    }

    @discardableResult
    func delete(_ chat: TruthPeer, _ ids: [Int32]) -> TruthLogEntry {
        precondition(!ids.isEmpty)
        for id in ids {
            precondition(self.messagesByChat[chat]?[id] != nil, "truth world: delete of \(chat) \(id), which does not exist")
            self.messagesByChat[chat]![id] = nil
        }
        return self.append(TruthEvent.delete(chat: chat, ids: ids), chat: chat, ptsCount: Int32(ids.count))
    }

    /// Deletes every message of a private chat or basic group; the chat list keeps the old top as a history-cleared
    /// service message (`clearedTop`). Nil when the chat holds nothing.
    @discardableResult
    func clearHistory(_ chat: TruthPeer) -> TruthLogEntry? {
        precondition(!chat.isChannel, "truth world: channels are not cleared")
        let all = self.existing(chat)
        guard let top = all.last else {
            return nil
        }
        let entry = self.delete(chat, all.map { $0.id })
        self.clearedTop[chat] = (top.id, top.date)
        self.historyClearIds[chat, default: []].insert(top.id)
        return entry
    }

    /// The entries of the account's log after `pts`, oldest first.
    func accountLog(after pts: Int32) -> [TruthLogEntry] {
        return self.accountLog.filter { $0.pts > pts }
    }

    func channelLog(_ channelId: Int64, after pts: Int32) -> [TruthLogEntry] {
        return (self.channelLogs[channelId] ?? []).filter { $0.pts > pts }
    }

    private func addMessage(in chat: TruthPeer, fromUserId: Int64?, outgoing: Bool, text: String) -> TruthLogEntry {
        if !self.holdsClock {
            self.date += 1
        }
        let id: Int32
        if case let .channel(channelId) = chat {
            id = self.nextChannelMessageId[channelId]!
            self.nextChannelMessageId[channelId] = id + 1
        } else {
            id = self.nextAccountMessageId
            self.nextAccountMessageId += 1
        }
        let message = TruthMessage(id: id, chat: chat, fromUserId: fromUserId, outgoing: outgoing, date: self.date, text: "\(text) \(chat) \(id)")
        self.messagesByChat[chat]![id] = message
        self.clearedTop[chat] = nil
        return self.append(TruthEvent.newMessage(message), chat: chat, ptsCount: 1)
    }

    private func append(_ event: TruthEvent, chat: TruthPeer, ptsCount: Int32) -> TruthLogEntry {
        if case let .channel(channelId) = chat {
            let pts = self.channelPts[channelId]! + ptsCount
            self.channelPts[channelId] = pts
            let entry = TruthLogEntry(pts: pts, ptsCount: ptsCount, event: event)
            self.channelLogs[channelId]!.append(entry)
            return entry
        } else {
            self.pts += ptsCount
            let entry = TruthLogEntry(pts: self.pts, ptsCount: ptsCount, event: event)
            self.accountLog.append(entry)
            return entry
        }
    }
}

extension TruthPeer {
    var isChannel: Bool {
        if case .channel = self {
            return true
        }
        return false
    }
}

/// SplitMix64: the sessions' only source of randomness, so a seed replays a session exactly.
struct TruthRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        self.state &+= 0x9e3779b97f4a7c15
        var z = self.state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
