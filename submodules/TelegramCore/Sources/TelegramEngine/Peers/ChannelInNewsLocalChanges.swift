import Foundation
import Postbox

/// The client's own Add to News / Remove from News, for `window` seconds after each: a channel object from the server
/// keeps the `in_news` it set. Responses to requests sent before the change (the chat's full-channel fetch, the
/// unjoined-channel poll) otherwise land after it and store the channel as it was: measured on K1, a full-channel
/// fetch sent when the chat opened landed after Add to News, and the channel read as not in News for minutes, until
/// something fetched it again. Keyed by account, so another account's copy of the channel is unaffected.
final class ChannelInNewsLocalChanges {
    static let shared = ChannelInNewsLocalChanges()

    static let window: Double = 10.0

    private struct Key: Hashable {
        let accountPeerId: PeerId
        let channelId: PeerId
    }

    private let lock = NSLock()
    private var changes: [Key: (isInNews: Bool, time: Double)] = [:]

    func record(accountPeerId: PeerId, channelId: PeerId, isInNews: Bool, at time: Double) {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        self.changes[Key(accountPeerId: accountPeerId, channelId: channelId)] = (isInNews, time)
    }

    /// The `in_news` the client set itself within the window, or nil.
    func localInNews(accountPeerId: PeerId, channelId: PeerId, at time: Double) -> Bool? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        let key = Key(accountPeerId: accountPeerId, channelId: channelId)
        guard let change = self.changes[key] else {
            return nil
        }
        if time - change.time >= ChannelInNewsLocalChanges.window {
            self.changes.removeValue(forKey: key)
            return nil
        }
        return change.isInNews
    }
}

/// `channel` with `localInNews`, when the client set it within the window; unchanged otherwise.
func channelApplyingLocalInNews(_ channel: TelegramChannel, localInNews: Bool?) -> TelegramChannel {
    guard let localInNews, channel.flags.contains(.isInNews) != localInNews else {
        return channel
    }
    var flags = channel.flags
    if localInNews {
        flags.insert(.isInNews)
    } else {
        flags.remove(.isInNews)
    }
    return channel.withUpdatedFlags(flags)
}

/// Records the client's own change and stores it on the channel now, rather than when the server's updates land (a
/// for-News join's answer arrives before them; a leave's may not carry the channel at all).
func _internal_storeLocalInNews(transaction: Transaction, accountPeerId: PeerId, channelId: PeerId, isInNews: Bool) {
    ChannelInNewsLocalChanges.shared.record(accountPeerId: accountPeerId, channelId: channelId, isInNews: isInNews, at: CFAbsoluteTimeGetCurrent())
    if let channel = transaction.getPeer(channelId) as? TelegramChannel {
        let updated = channelApplyingLocalInNews(channel, localInNews: isInNews)
        if updated !== channel {
            updatePeersCustom(transaction: transaction, peers: [updated], update: { _, updated in updated })
        }
    }
}
