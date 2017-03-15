import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public struct Namespaces {
    public struct Message {
        public static let Cloud: Int32 = 0
        public static let Local: Int32 = 1
        public static let SecretIncoming: Int32 = 2
    }
    
    public struct Media {
        public static let CloudImage: Int32 = 0
        public static let CloudVideo: Int32 = 1
        public static let CloudAudio: Int32 = 2
        public static let CloudContact: Int32 = 3
        public static let CloudMap: Int32 = 4
        public static let CloudFile: Int32 = 5
        public static let CloudWebpage: Int32 = 6
        public static let LocalImage: Int32 = 7
        public static let LocalFile: Int32 = 8
        public static let CloudSecretImage: Int32 = 9
        public static let CloudSecretFile: Int32 = 10
        public static let CloudGame: Int32 = 11
    }
    
    public struct Peer {
        public static let CloudUser: Int32 = 0
        public static let CloudGroup: Int32 = 1
        public static let CloudChannel: Int32 = 2
        public static let SecretChat: Int32 = 3
        public static let Empty: Int32 = Int32.max
    }
    
    public struct ItemCollection {
        public static let CloudStickerPacks: Int32 = 0
        public static let CloudMaskPacks: Int32 = 1
        public static let CloudRecentStickers: Int32 = 2
    }
    
    public struct OrderedItemList {
        public static let CloudRecentStickers: Int32 = 0
        public static let CloudRecentGifs: Int32 = 1
        public static let RecentlySearchedPeerIds: Int32 = 2
        public static let CloudRecentInlineBots: Int32 = 3
    }
    
    struct CachedItemCollection {
        public static let resolvedByNamePeers: Int8 = 0
    }
}

public extension MessageTags {
    static let PhotoOrVideo = MessageTags(rawValue: 1 << 0)
    static let File = MessageTags(rawValue: 1 << 1)
    static let Music = MessageTags(rawValue: 1 << 2)
    static let WebPage = MessageTags(rawValue: 1 << 3)
    static let Voice = MessageTags(rawValue: 1 << 4)
}

let allMessageTags: MessageTags = [.PhotoOrVideo, .File, .Music, .WebPage, .Voice]
let peerIdNamespacesWithInitialCloudMessageHoles = [Namespaces.Peer.CloudUser, Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel]

struct OperationLogTags {
    static let SecretOutgoing = PeerOperationLogTag(value: 0)
    static let SecretIncomingEncrypted = PeerOperationLogTag(value: 1)
    static let SecretIncomingDecrypted = PeerOperationLogTag(value: 2)
    static let CloudChatRemoveMessages = PeerOperationLogTag(value: 3)
    static let SynchronizePinnedCloudChats = PeerOperationLogTag(value: 4)
    static let AutoremoveMessages = PeerOperationLogTag(value: 5)
    static let SynchronizePinnedChats = PeerOperationLogTag(value: 6)
    static let SynchronizeConsumeMessageContents = PeerOperationLogTag(value: 7)
    static let SynchronizeInstalledStickerPacks = PeerOperationLogTag(value: 8)
    static let SynchronizeInstalledMasks = PeerOperationLogTag(value: 9)
}

private enum PreferencesKeyValues: Int32 {
    case globalNotifications = 0
}

public func applicationSpecificPreferencesKey(_ value: Int32) -> ValueBoxKey {
    let key = ValueBoxKey(length: 4)
    key.setInt32(0, value: value + 1000)
    return key
}

public struct PreferencesKeys {
    public static let globalNotifications: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.globalNotifications.rawValue)
        return key
    }()
}
