import Foundation
import TelegramCore

/// A post's identity in a list: an album keeps its identity when a later page adds a message to it.
public func newsPostIdentity(_ entry: EngineFeedEntry) -> AnyHashable {
    if let groupingKey = entry.groupingKey {
        return AnyHashable("album-\(entry.peerId.toInt64())-\(groupingKey)")
    }
    return AnyHashable("post-\(entry.peerId.toInt64())-\(entry.messageIds[0].namespace)-\(entry.messageIds[0].id)")
}
