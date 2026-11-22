import Foundation
import Postbox
internal import TelegramApi

/// What a `channel` constructor's `pinned_msg_id` says about `CachedChannelData.pinnedMessageId`, a cache the chat
/// shows as a pinned skeleton until its own pinned list has loaded. Every full constructor carries the field, so
/// one without it means nothing is pinned. A `min` constructor is partial and says nothing.
enum CachedPinnedMessageIdUpdate: Equatable {
    case set(Int32)
    case clear
}

func cachedPinnedMessageIdUpdate(chat: Api.Chat) -> CachedPinnedMessageIdUpdate? {
    guard case let .channel(channelData) = chat else {
        return nil
    }
    if (channelData.flags & (1 << 12)) != 0 {
        return nil
    }
    if let pinnedMsgId = channelData.pinnedMsgId {
        return .set(pinnedMsgId)
    } else {
        return .clear
    }
}

/// The cached data to store, or nil to write nothing: `updatePeerCachedData` writes and notifies for any non-nil
/// result, the unchanged object included. "Nothing pinned" never creates a row of its own.
func cachedChannelData(applying update: CachedPinnedMessageIdUpdate, peerId: PeerId, to current: CachedPeerData?) -> CachedChannelData? {
    switch update {
    case let .set(id):
        let messageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id)
        if let current = current as? CachedChannelData {
            if current.pinnedMessageId == messageId {
                return nil
            }
            return current.withUpdatedPinnedMessageId(messageId)
        } else if current == nil {
            return CachedChannelData().withUpdatedPinnedMessageId(messageId)
        } else {
            return nil
        }
    case .clear:
        guard let current = current as? CachedChannelData, current.pinnedMessageId != nil else {
            return nil
        }
        return current.withUpdatedPinnedMessageId(nil)
    }
}
