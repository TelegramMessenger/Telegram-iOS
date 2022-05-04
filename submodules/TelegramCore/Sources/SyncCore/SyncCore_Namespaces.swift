import Foundation
import Postbox

public struct Namespaces {
    public struct Message {
        public static let Cloud: Int32 = 0
        public static let Local: Int32 = 1
        public static let SecretIncoming: Int32 = 2
        public static let ScheduledCloud: Int32 = 3
        public static let ScheduledLocal: Int32 = 4
        
        public static let allScheduled: Set<Int32> = Set([Namespaces.Message.ScheduledCloud, Namespaces.Message.ScheduledLocal])
    }
    
    public struct Media {
        public static let CloudImage: Int32 = 0
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
        public static let CloudInvoice: Int32 = 12
        public static let LocalWebpage: Int32 = 13
        public static let LocalPoll: Int32 = 14
        public static let CloudPoll: Int32 = 15
    }
    
    public struct Peer {
        public static let CloudUser = PeerId.Namespace._internalFromInt32Value(0)
        public static let CloudGroup = PeerId.Namespace._internalFromInt32Value(1)
        public static let CloudChannel = PeerId.Namespace._internalFromInt32Value(2)
        public static let SecretChat = PeerId.Namespace._internalFromInt32Value(3)
        public static let Empty = PeerId.Namespace.max
    }
    
    public struct ItemCollection {
        public static let CloudStickerPacks: Int32 = 0
        public static let CloudMaskPacks: Int32 = 1
        public static let EmojiKeywords: Int32 = 2
        public static let CloudAnimatedEmoji: Int32 = 3
        public static let CloudDice: Int32 = 4
        public static let CloudAnimatedEmojiAnimations: Int32 = 5
        public static let CloudAnimatedEmojiReactions: Int32 = 6
    }
    
    public struct OrderedItemList {
        public static let CloudRecentStickers: Int32 = 0
        public static let CloudRecentGifs: Int32 = 1
        public static let RecentlySearchedPeerIds: Int32 = 2
        public static let CloudRecentInlineBots: Int32 = 3
        public static let CloudFeaturedStickerPacks: Int32 = 4
        public static let CloudArchivedStickerPacks: Int32 = 5
        public static let CloudWallpapers: Int32 = 6
        public static let CloudSavedStickers: Int32 = 7
        public static let RecentlyUsedHashtags: Int32 = 8
        public static let CloudThemes: Int32 = 9
        public static let CloudGreetingStickers: Int32 = 10
        public static let RecentDownloads: Int32 = 11
    }
    
    public struct CachedItemCollection {
        public static let resolvedByNamePeers: Int8 = 0
        public static let cachedTwoStepToken: Int8 = 1
        public static let cachedStickerPacks: Int8 = 2
        public static let cachedAvailableLocalizations: Int8 = 3
        public static let cachedSentMediaReferences: Int8 = 4
        public static let cachedStickerQueryResults: Int8 = 5
        public static let cachedSecureIdConfiguration: Int8 = 6
        public static let cachedWallpapersConfiguration: Int8 = 7
        public static let cachedThemesConfiguration: Int8 = 8
        public static let cachedPollResults: Int8 = 9
        public static let cachedContextResults: Int8 = 10
        public static let proximityNotificationStoredState: Int8 = 11
        public static let cachedGroupCallDisplayAsPeers: Int8 = 14
        public static let cachedAdMessageStates: Int8 = 15
        public static let cachedPeerInvitationImporters: Int8 = 16
        public static let cachedPeerExportedInvitations: Int8 = 17
        public static let cachedSendAsPeers: Int8 = 18
        public static let availableReactions: Int8 = 19
        public static let resolvedByPhonePeers: Int8 = 20
        public static let notificationSoundList: Int8 = 22
        public static let attachMenuBots: Int8 = 23
    }
    
    public struct UnorderedItemList {
        public static let synchronizedDeviceContacts: UnorderedItemListEntryTag = {
            let key = ValueBoxKey(length: 1)
            key.setUInt8(0, value: 0)
            return UnorderedItemListEntryTag(value: key)
        }()
    }
    
    public struct PeerGroup {
        public static let archive = PeerGroupId(rawValue: 1)
    }
}

public extension MessageTags {
    static let photoOrVideo = MessageTags(rawValue: 1 << 0)
    static let file = MessageTags(rawValue: 1 << 1)
    static let music = MessageTags(rawValue: 1 << 2)
    static let webPage = MessageTags(rawValue: 1 << 3)
    static let voiceOrInstantVideo = MessageTags(rawValue: 1 << 4)
    static let unseenPersonalMessage = MessageTags(rawValue: 1 << 5)
    static let liveLocation = MessageTags(rawValue: 1 << 6)
    static let gif = MessageTags(rawValue: 1 << 7)
    static let photo = MessageTags(rawValue: 1 << 8)
    static let video = MessageTags(rawValue: 1 << 9)
    static let pinned = MessageTags(rawValue: 1 << 10)
    static let unseenReaction = MessageTags(rawValue: 1 << 11)
    
    static let all: MessageTags = [.photoOrVideo, .file, .music, .webPage, .voiceOrInstantVideo, .unseenPersonalMessage, .liveLocation, .gif, .photo, .video, .pinned, .unseenReaction]
}

public extension GlobalMessageTags {
    static let Calls = GlobalMessageTags(rawValue: 1 << 0)
    static let MissedCalls = GlobalMessageTags(rawValue: 1 << 1)
    
    static let all: GlobalMessageTags = [.Calls, .MissedCalls]
}

public extension LocalMessageTags {
    static let OutgoingLiveLocation = LocalMessageTags(rawValue: 1 << 0)
    static let OutgoingDeliveredToServer = LocalMessageTags(rawValue: 1 << 1)
}

public extension PendingMessageActionType {
    static let consumeUnseenPersonalMessage = PendingMessageActionType(rawValue: 0)
    static let updateReaction = PendingMessageActionType(rawValue: 1)
    static let sendScheduledMessageImmediately = PendingMessageActionType(rawValue: 2)
    static let readReaction = PendingMessageActionType(rawValue: 3)
}

public let peerIdNamespacesWithInitialCloudMessageHoles = [Namespaces.Peer.CloudUser, Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel]

public struct OperationLogTags {
    public static let SecretOutgoing = PeerOperationLogTag(value: 0)
    public static let SecretIncomingEncrypted = PeerOperationLogTag(value: 1)
    public static let SecretIncomingDecrypted = PeerOperationLogTag(value: 2)
    public static let CloudChatRemoveMessages = PeerOperationLogTag(value: 3)
    public static let SynchronizePinnedCloudChats = PeerOperationLogTag(value: 4)
    public static let AutoremoveMessages = PeerOperationLogTag(value: 5)
    public static let SynchronizePinnedChats = PeerOperationLogTag(value: 6)
    public static let SynchronizeConsumeMessageContents = PeerOperationLogTag(value: 7)
    public static let SynchronizeInstalledStickerPacks = PeerOperationLogTag(value: 8)
    public static let SynchronizeInstalledMasks = PeerOperationLogTag(value: 9)
    public static let SynchronizeMarkFeaturedStickerPacksAsSeen = PeerOperationLogTag(value: 10)
    public static let SynchronizeChatInputStates = PeerOperationLogTag(value: 11)
    public static let SynchronizeSavedGifs = PeerOperationLogTag(value: 12)
    public static let SynchronizeLocalizationUpdates = PeerOperationLogTag(value: 13)
    public static let SynchronizeSavedStickers = PeerOperationLogTag(value: 14)
    public static let SynchronizeGroupedPeers = PeerOperationLogTag(value: 15)
    public static let SynchronizeMarkAllUnseenPersonalMessages = PeerOperationLogTag(value: 16)
    public static let SynchronizeRecentlyUsedStickers = PeerOperationLogTag(value: 17)
    public static let SynchronizeAppLogEvents = PeerOperationLogTag(value: 18)
    public static let SynchronizeEmojiKeywords = PeerOperationLogTag(value: 19)
    public static let SynchronizeChatListFilters = PeerOperationLogTag(value: 20)
    public static let SynchronizeMarkAllUnseenReactions = PeerOperationLogTag(value: 21)
}

public struct LegacyPeerSummaryCounterTags: OptionSet, Sequence, Hashable {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let regularChatsAndPrivateGroups = LegacyPeerSummaryCounterTags(rawValue: 1 << 0)
    public static let publicGroups = LegacyPeerSummaryCounterTags(rawValue: 1 << 1)
    public static let channels = LegacyPeerSummaryCounterTags(rawValue: 1 << 2)
    
    public func makeIterator() -> AnyIterator<LegacyPeerSummaryCounterTags> {
        var index = 0
        return AnyIterator { () -> LegacyPeerSummaryCounterTags? in
            while index < 31 {
                let currentTags = self.rawValue >> UInt32(index)
                let tag = LegacyPeerSummaryCounterTags(rawValue: 1 << UInt32(index))
                index += 1
                if currentTags == 0 {
                    break
                }
                
                if (currentTags & 1) != 0 {
                    return tag
                }
            }
            return nil
        }
    }
}

public extension PeerSummaryCounterTags {
    static let contact = PeerSummaryCounterTags(rawValue: 1 << 3)
    static let nonContact = PeerSummaryCounterTags(rawValue: 1 << 4)
    static let group = PeerSummaryCounterTags(rawValue: 1 << 5)
    static let bot = PeerSummaryCounterTags(rawValue: 1 << 7)
    static let channel = PeerSummaryCounterTags(rawValue: 1 << 8)
    
    static let all: PeerSummaryCounterTags = [
        .contact,
        .nonContact,
        .group,
        .bot,
        .channel
    ]
}

private enum PreferencesKeyValues: Int32 {
    case globalNotifications = 0
    case suggestedLocalization = 3
    case limitsConfiguration = 4
    case contentPrivacySettings = 8
    case networkSettings = 9
    case remoteStorageConfiguration = 10
    case voipConfiguration = 11
    case appChangelogState = 12
    case localizationListState = 13
    case appConfiguration = 14
    case searchBotsConfiguration = 15
    case contactsSettings = 16
    case walletCollection = 18
    case contentSettings = 19
    case chatListFilters = 20
    case peersNearby = 21
    case chatListFiltersFeaturedState = 22
    case secretChatSettings = 23
    case reactionSettings = 24
}

public func applicationSpecificPreferencesKey(_ value: Int32) -> ValueBoxKey {
    let key = ValueBoxKey(length: 4)
    key.setInt32(0, value: value + 1000)
    return key
}

public func applicationSpecificSharedDataKey(_ value: Int32) -> ValueBoxKey {
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
    
    public static let suggestedLocalization: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.suggestedLocalization.rawValue)
        return key
    }()
    
    public static let limitsConfiguration: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.limitsConfiguration.rawValue)
        return key
    }()
    
    public static let contentPrivacySettings: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.contentPrivacySettings.rawValue)
        return key
    }()
    
    public static let networkSettings: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.networkSettings.rawValue)
        return key
    }()
    
    public static let remoteStorageConfiguration: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.remoteStorageConfiguration.rawValue)
        return key
    }()
    
    public static let voipConfiguration: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.voipConfiguration.rawValue)
        return key
    }()
    
    public static let appChangelogState: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.appChangelogState.rawValue)
        return key
    }()
    
    public static let localizationListState: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.localizationListState.rawValue)
        return key
    }()
    
    public static let appConfiguration: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.appConfiguration.rawValue)
        return key
    }()
    
    public static let searchBotsConfiguration: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.searchBotsConfiguration.rawValue)
        return key
    }()
    
    public static let contactsSettings: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.contactsSettings.rawValue)
        return key
    }()
    
    public static let secretChatSettings: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.secretChatSettings.rawValue)
        return key
    }()
    
    public static let walletCollection: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.walletCollection.rawValue)
        return key
    }()
    
    public static let contentSettings: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.contentSettings.rawValue)
        return key
    }()
    
    public static let chatListFilters: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.chatListFilters.rawValue)
        return key
    }()
    
    public static let peersNearby: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.peersNearby.rawValue)
        return key
    }()
    
    public static let chatListFiltersFeaturedState: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.chatListFiltersFeaturedState.rawValue)
        return key
    }()
    
    public static let reactionSettings: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: PreferencesKeyValues.reactionSettings.rawValue)
        return key
    }()
}

private enum SharedDataKeyValues: Int32 {
    case loggingSettings = 0
    case cacheStorageSettings = 2
    case localizationSettings = 3
    case proxySettings = 4
    case autodownloadSettings = 5
    case themeSettings = 6
    case countriesList = 7
    case wallapersState = 8
    case chatThemes = 10
}

public struct SharedDataKeys {
    public static let loggingSettings: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: SharedDataKeyValues.loggingSettings.rawValue)
        return key
    }()
    
    public static let cacheStorageSettings: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: SharedDataKeyValues.cacheStorageSettings.rawValue)
        return key
    }()
    
    public static let localizationSettings: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: SharedDataKeyValues.localizationSettings.rawValue)
        return key
    }()
    
    public static let proxySettings: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: SharedDataKeyValues.proxySettings.rawValue)
        return key
    }()
    
    public static let autodownloadSettings: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: SharedDataKeyValues.autodownloadSettings.rawValue)
        return key
    }()
    
    public static let themeSettings: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: SharedDataKeyValues.themeSettings.rawValue)
        return key
    }()
    
    public static let countriesList: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: SharedDataKeyValues.countriesList.rawValue)
        return key
    }()

    public static let wallapersState: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: SharedDataKeyValues.wallapersState.rawValue)
        return key
    }()
    
    public static let chatThemes: ValueBoxKey = {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: SharedDataKeyValues.chatThemes.rawValue)
        return key
    }()
}

public func applicationSpecificItemCacheCollectionId(_ value: Int8) -> Int8 {
    return 64 + value
}

public func applicationSpecificOrderedItemListCollectionId(_ value: Int32) -> Int32 {
    return 1000 + value
}
