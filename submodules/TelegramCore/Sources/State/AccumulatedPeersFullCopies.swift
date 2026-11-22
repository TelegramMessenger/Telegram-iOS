import Foundation
import Postbox
internal import TelegramApi

extension AccumulatedPeers {
    /// `union(with:)` for two answers carrying the same peers, `other` the newer one (owner decision D3,
    /// 2026-10-15): `other`'s copy of a peer wins, except that a min copy never replaces a full copy of the
    /// same peer. A min copy (`user` flags.20; `channel` or `community` flags.12) is what the server sends where
    /// the account may not see the full peer. Written over a full copy it loses data: a min user is merged with
    /// the STORED user (`TelegramUser.merge` keeps the stored name and access hash, which can be older than the
    /// full copy), and a min chat, parsed on its own, replaces the full chat outright (`updatePeers` writes
    /// `peers` without a merge).
    ///
    /// D3 names users. Channels and communities have min copies too and get the same rule here: a decision
    /// (2026-10-16) beyond D3's letter, made because they are merged at the same site and lose more (a min chat
    /// replaces the full chat outright). Deleting the one `keepFullChats` line below restricts the rule to
    /// users. Anything else that is newer wins, as D3 says: a full copy over a min one, a forbidden chat over a
    /// full one, and an empty user (`userEmpty`), which is not a min copy.
    func unionKeepingFullCopies(with other: AccumulatedPeers) -> AccumulatedPeers {
        var result = self.union(with: other)
        result.keepFullUsers(of: self, over: other)
        // Channels and communities: a decision beyond D3's letter (see above). Deleting this one line restricts
        // the rule to users, as D3 is worded.
        result.keepFullChats(of: self, over: other)
        return result
    }

    /// Puts back `older`'s full copy of every user that `newer` carries only as a min copy.
    private mutating func keepFullUsers(of older: AccumulatedPeers, over newer: AccumulatedPeers) {
        for (id, user) in newer.users {
            if accumulatedUserIsMin(user), let current = older.users[id], accumulatedUserIsFull(current) {
                self.users[id] = current
            }
        }
    }

    /// Puts back `older`'s full copy of every channel or community that `newer` carries only as a min copy, in
    /// `chats` and in the parsed `peers`.
    private mutating func keepFullChats(of older: AccumulatedPeers, over newer: AccumulatedPeers) {
        for (id, chat) in newer.chats {
            if accumulatedChatIsMin(chat), let current = older.chats[id], accumulatedChatIsFull(current) {
                self.chats[id] = current
                if let currentPeer = older.peers[id] {
                    self.peers[id] = currentPeer
                }
            }
        }
    }
}

/// A min copy of a user: `user` with `min` (flags.20).
private func accumulatedUserIsMin(_ user: Api.User) -> Bool {
    if case let .user(userData) = user {
        return (userData.flags & (1 << 20)) != 0
    }
    return false
}

/// A full copy of a user: `user` without `min`.
private func accumulatedUserIsFull(_ user: Api.User) -> Bool {
    if case let .user(userData) = user {
        return (userData.flags & (1 << 20)) == 0
    }
    return false
}

/// A min copy of a chat: `channel` or `community` with `min` (flags.12).
private func accumulatedChatIsMin(_ chat: Api.Chat) -> Bool {
    if case let .channel(channelData) = chat {
        return (channelData.flags & (1 << 12)) != 0
    }
    if case let .community(communityData) = chat {
        return (communityData.flags & (1 << 12)) != 0
    }
    return false
}

/// A full copy of a chat: a basic group (`chat`, which has no min copies), or a `channel` or `community`
/// without `min`.
private func accumulatedChatIsFull(_ chat: Api.Chat) -> Bool {
    if case .chat = chat {
        return true
    }
    if case let .channel(channelData) = chat {
        return (channelData.flags & (1 << 12)) == 0
    }
    if case let .community(communityData) = chat {
        return (communityData.flags & (1 << 12)) == 0
    }
    return false
}
