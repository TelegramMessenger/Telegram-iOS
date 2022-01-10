import Foundation

public enum AdditionalMessageHistoryViewData {
    case cachedPeerData(PeerId)
    case cachedPeerDataMessages(PeerId)
    case peerChatState(PeerId)
    case totalUnreadState
    case peerNotificationSettings(PeerId)
    case cacheEntry(ItemCacheEntryId)
    case preferencesEntry(ValueBoxKey)
    case peer(PeerId)
    case peerIsContact(PeerId)
    case message(MessageId)
}

public enum AdditionalMessageHistoryViewDataEntry {
    case cachedPeerData(PeerId, CachedPeerData?)
    case cachedPeerDataMessages(PeerId, [MessageId: Message]?)
    case peerChatState(PeerId, PeerChatState?)
    case totalUnreadState(ChatListTotalUnreadState)
    case peerNotificationSettings(PeerNotificationSettings?)
    case cacheEntry(ItemCacheEntryId, CodableEntry?)
    case preferencesEntry(ValueBoxKey, PreferencesEntry?)
    case peerIsContact(PeerId, Bool)
    case peer(PeerId, Peer?)
    case message(MessageId, [Message])
}
