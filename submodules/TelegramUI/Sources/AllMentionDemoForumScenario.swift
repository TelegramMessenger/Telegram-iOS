import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences

/// Explicit offline QA fixtures. Save the original metadata once, then restore
/// it without replacing messages, queued sends, quota or read state.
enum AllMentionDemoForumScenario {
    private struct Topic: Codable {
        let id: Int64
        let data: MessageHistoryThreadData
    }
    private struct Snapshot: Codable {
        let channel: Data
        let topics: [Topic]
    }
    private static var key: ValueBoxKey { applicationSpecificPreferencesKey(0x414c4e) }

    static func apply(transaction: Transaction, scenario: String) {
        let peerId = AllMentionDemoConfiguration.forumPeerId
        guard let channel = transaction.getPeer(peerId) as? TelegramChannel else { return }
        if scenario == "restore" {
            guard let snapshot = transaction.getPreferencesEntry(key: key)?.get(Snapshot.self) else { return }
            let original = TelegramChannel(decoder: PostboxDecoder(buffer: MemoryBuffer(data: snapshot.channel)))
            updatePeersCustom(transaction: transaction, peers: [original], update: { _, updated in updated })
            for topic in snapshot.topics {
                var data = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: topic.id)?.data.get(MessageHistoryThreadData.self) ?? topic.data
                data.isClosed = topic.data.isClosed
                data.isOwnedByMe = topic.data.isOwnedByMe
                data.author = topic.data.author
                transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: topic.id, info: AllMentionDemoForumState.stored(data))
            }
            transaction.updatePreferencesEntry(key: key, { _ in nil })
            return
        }
        let parts = scenario.split(separator: ":")
        guard scenario == "readonly" || (parts.count == 2 && ["close", "delete"].contains(String(parts[0])) && Int64(parts[1]) != nil) else { return }
        if transaction.getPreferencesEntry(key: key) == nil {
            let encoder = PostboxEncoder()
            channel.encode(encoder)
            let topics = transaction.getMessageHistoryThreadIndex(peerId: peerId, limit: Int(Int32.max)).compactMap { entry -> Topic? in
                entry.info.data.get(MessageHistoryThreadData.self).map { Topic(id: entry.threadId, data: $0) }
            }
            transaction.updatePreferencesEntry(key: key, { _ in PreferencesEntry(Snapshot(channel: encoder.makeData(), topics: topics)) })
        }
        if scenario == "readonly" {
            // The fixture account starts as creator, so remove that exemption.
            let member = channel.withUpdatedFlags(channel.flags.subtracting(.isCreator)).withUpdatedDefaultBannedRights(TelegramChatBannedRights(flags: [.banSendText], untilDate: Int32.max))
            updatePeersCustom(transaction: transaction, peers: [member], update: { _, updated in updated })
        } else if let id = Int64(parts[1]), var data = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: id)?.data.get(MessageHistoryThreadData.self) {
            if parts[0] == "delete" {
                transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: id, info: nil)
            } else {
                let member = channel.withUpdatedFlags(channel.flags.subtracting(.isCreator))
                updatePeersCustom(transaction: transaction, peers: [member], update: { _, updated in updated })
                data.isClosed = true
                data.isOwnedByMe = false
                transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: id, info: AllMentionDemoForumState.stored(data))
            }
        }
    }
}
