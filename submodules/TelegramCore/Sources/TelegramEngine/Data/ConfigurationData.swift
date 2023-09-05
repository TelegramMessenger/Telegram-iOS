import SwiftSignalKit
import Postbox

public enum EngineConfiguration {
    public struct Limits: Equatable {
        public static let timeIntervalForever: Int32 = 0x7fffffff
        
        public var maxGroupMemberCount: Int32
        public var maxSupergroupMemberCount: Int32
        public var maxMessageForwardBatchSize: Int32
        public var maxRecentStickerCount: Int32
        public var maxMessageEditingInterval: Int32
        public var canRemoveIncomingMessagesInPrivateChats: Bool
        public var maxMessageRevokeInterval: Int32
        public var maxMessageRevokeIntervalInPrivateChats: Int32

        public init(
            maxGroupMemberCount: Int32,
            maxSupergroupMemberCount: Int32,
            maxMessageForwardBatchSize: Int32,
            maxRecentStickerCount: Int32,
            maxMessageEditingInterval: Int32,
            canRemoveIncomingMessagesInPrivateChats: Bool,
            maxMessageRevokeInterval: Int32,
            maxMessageRevokeIntervalInPrivateChats: Int32
        ) {
            self.maxGroupMemberCount = maxGroupMemberCount
            self.maxSupergroupMemberCount = maxSupergroupMemberCount
            self.maxMessageForwardBatchSize = maxMessageForwardBatchSize
            self.maxRecentStickerCount = maxRecentStickerCount
            self.maxMessageEditingInterval = maxMessageEditingInterval
            self.canRemoveIncomingMessagesInPrivateChats = canRemoveIncomingMessagesInPrivateChats
            self.maxMessageRevokeInterval = maxMessageRevokeInterval
            self.maxMessageRevokeIntervalInPrivateChats = maxMessageRevokeIntervalInPrivateChats
        }
    }
    
    public struct UserLimits: Equatable {
        public let maxPinnedChatCount: Int32
        public let maxArchivedPinnedChatCount: Int32
        public let maxChannelsCount: Int32
        public let maxPublicLinksCount: Int32
        public let maxSavedGifCount: Int32
        public let maxFavedStickerCount: Int32
        public let maxFoldersCount: Int32
        public let maxFolderChatsCount: Int32
        public let maxCaptionLength: Int32
        public let maxUploadFileParts: Int32
        public let maxAboutLength: Int32
        public let maxAnimatedEmojisInText: Int32
        public let maxReactionsPerMessage: Int32
        public let maxSharedFolderInviteLinks: Int32
        public let maxSharedFolderJoin: Int32
        public let maxStoryCaptionLength: Int32
        public let maxExpiringStoriesCount: Int32
        public let maxStoriesWeeklyCount: Int32
        public let maxStoriesMonthlyCount: Int32
        public let maxStoriesSuggestedReactions: Int32
        
        public static var defaultValue: UserLimits {
            return UserLimits(UserLimitsConfiguration.defaultValue)
        }

        public init(
            maxPinnedChatCount: Int32,
            maxArchivedPinnedChatCount: Int32,
            maxChannelsCount: Int32,
            maxPublicLinksCount: Int32,
            maxSavedGifCount: Int32,
            maxFavedStickerCount: Int32,
            maxFoldersCount: Int32,
            maxFolderChatsCount: Int32,
            maxCaptionLength: Int32,
            maxUploadFileParts: Int32,
            maxAboutLength: Int32,
            maxAnimatedEmojisInText: Int32,
            maxReactionsPerMessage: Int32,
            maxSharedFolderInviteLinks: Int32,
            maxSharedFolderJoin: Int32,
            maxStoryCaptionLength: Int32,
            maxExpiringStoriesCount: Int32,
            maxStoriesWeeklyCount: Int32,
            maxStoriesMonthlyCount: Int32,
            maxStoriesSuggestedReactions: Int32
        ) {
            self.maxPinnedChatCount = maxPinnedChatCount
            self.maxArchivedPinnedChatCount = maxArchivedPinnedChatCount
            self.maxChannelsCount = maxChannelsCount
            self.maxPublicLinksCount = maxPublicLinksCount
            self.maxSavedGifCount = maxSavedGifCount
            self.maxFavedStickerCount = maxFavedStickerCount
            self.maxFoldersCount = maxFoldersCount
            self.maxFolderChatsCount = maxFolderChatsCount
            self.maxCaptionLength = maxCaptionLength
            self.maxUploadFileParts = maxUploadFileParts
            self.maxAboutLength = maxAboutLength
            self.maxAnimatedEmojisInText = maxAnimatedEmojisInText
            self.maxReactionsPerMessage = maxReactionsPerMessage
            self.maxSharedFolderInviteLinks = maxSharedFolderInviteLinks
            self.maxSharedFolderJoin = maxSharedFolderJoin
            self.maxStoryCaptionLength = maxStoryCaptionLength
            self.maxExpiringStoriesCount = maxExpiringStoriesCount
            self.maxStoriesWeeklyCount = maxStoriesWeeklyCount
            self.maxStoriesMonthlyCount = maxStoriesMonthlyCount
            self.maxStoriesSuggestedReactions = maxStoriesSuggestedReactions
        }
    }
}

public typealias EngineContentSettings = ContentSettings

public extension EngineConfiguration.Limits {
    init(_ limitsConfiguration: LimitsConfiguration) {
        self.init(
            maxGroupMemberCount: limitsConfiguration.maxGroupMemberCount,
            maxSupergroupMemberCount: limitsConfiguration.maxSupergroupMemberCount,
            maxMessageForwardBatchSize: limitsConfiguration.maxMessageForwardBatchSize,
            maxRecentStickerCount: limitsConfiguration.maxRecentStickerCount,
            maxMessageEditingInterval: limitsConfiguration.maxMessageEditingInterval,
            canRemoveIncomingMessagesInPrivateChats: limitsConfiguration.canRemoveIncomingMessagesInPrivateChats,
            maxMessageRevokeInterval: limitsConfiguration.maxMessageRevokeInterval,
            maxMessageRevokeIntervalInPrivateChats: limitsConfiguration.maxMessageRevokeIntervalInPrivateChats
        )
    }
    
    func _asLimits() -> LimitsConfiguration {
        return LimitsConfiguration(
            maxGroupMemberCount: self.maxGroupMemberCount,
            maxSupergroupMemberCount: self.maxSupergroupMemberCount,
            maxMessageForwardBatchSize: self.maxMessageForwardBatchSize,
            maxRecentStickerCount: self.maxRecentStickerCount,
            maxMessageEditingInterval: self.maxMessageEditingInterval,
            canRemoveIncomingMessagesInPrivateChats: self.canRemoveIncomingMessagesInPrivateChats,
            maxMessageRevokeInterval: self.maxMessageRevokeInterval,
            maxMessageRevokeIntervalInPrivateChats: self.maxMessageRevokeIntervalInPrivateChats
        )
    }
}

public extension EngineConfiguration.UserLimits {
    init(_ userLimitsConfiguration: UserLimitsConfiguration) {
        self.init(
            maxPinnedChatCount: userLimitsConfiguration.maxPinnedChatCount,
            maxArchivedPinnedChatCount: userLimitsConfiguration.maxArchivedPinnedChatCount,
            maxChannelsCount: userLimitsConfiguration.maxChannelsCount,
            maxPublicLinksCount: userLimitsConfiguration.maxPublicLinksCount,
            maxSavedGifCount: userLimitsConfiguration.maxSavedGifCount,
            maxFavedStickerCount: userLimitsConfiguration.maxFavedStickerCount,
            maxFoldersCount: userLimitsConfiguration.maxFoldersCount,
            maxFolderChatsCount: userLimitsConfiguration.maxFolderChatsCount,
            maxCaptionLength: userLimitsConfiguration.maxCaptionLength,
            maxUploadFileParts: userLimitsConfiguration.maxUploadFileParts,
            maxAboutLength: userLimitsConfiguration.maxAboutLength,
            maxAnimatedEmojisInText: userLimitsConfiguration.maxAnimatedEmojisInText,
            maxReactionsPerMessage: userLimitsConfiguration.maxReactionsPerMessage,
            maxSharedFolderInviteLinks: userLimitsConfiguration.maxSharedFolderInviteLinks,
            maxSharedFolderJoin: userLimitsConfiguration.maxSharedFolderJoin,
            maxStoryCaptionLength: userLimitsConfiguration.maxStoryCaptionLength,
            maxExpiringStoriesCount: userLimitsConfiguration.maxExpiringStoriesCount,
            maxStoriesWeeklyCount: userLimitsConfiguration.maxStoriesWeeklyCount,
            maxStoriesMonthlyCount: userLimitsConfiguration.maxStoriesMonthlyCount,
            maxStoriesSuggestedReactions: userLimitsConfiguration.maxStoriesSuggestedReactions
        )
    }
}

public extension EngineConfiguration {
    struct SearchBots {
        public var imageBotUsername: String?
        public var gifBotUsername: String?
        public var venueBotUsername: String?
        
        public init(
            imageBotUsername: String?,
            gifBotUsername: String?,
            venueBotUsername: String?
        ) {
            self.imageBotUsername = imageBotUsername
            self.gifBotUsername = gifBotUsername
            self.venueBotUsername = venueBotUsername
        }
    }
}

public extension EngineConfiguration.SearchBots {
    init(_ configuration: SearchBotsConfiguration) {
        self.init(
            imageBotUsername: configuration.imageBotUsername,
            gifBotUsername: configuration.gifBotUsername,
            venueBotUsername: configuration.venueBotUsername
        )
    }
}

public extension EngineConfiguration {
    struct Links {
        public var autologinToken: String?

        public init(
            autologinToken: String?
        ) {
            self.autologinToken = autologinToken
        }
    }
}

public extension EngineConfiguration.Links {
    init(_ configuration: LinksConfiguration) {
        self.init(
            autologinToken: configuration.autologinToken
        )
    }
}

public extension TelegramEngine.EngineData.Item {
    enum Configuration {
        public struct App: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = AppConfiguration

            public init() {
            }

            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.appConfiguration]))
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                guard let appConfiguration = view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) else {
                    return AppConfiguration.defaultValue
                }
                return appConfiguration
            }
        }
        
        public struct Limits: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = EngineConfiguration.Limits

            public init() {
            }

            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.limitsConfiguration]))
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                guard let limitsConfiguration = view.values[PreferencesKeys.limitsConfiguration]?.get(LimitsConfiguration.self) else {
                    return EngineConfiguration.Limits(LimitsConfiguration.defaultValue)
                }
                return EngineConfiguration.Limits(limitsConfiguration)
            }
        }
        
        public struct UserLimits: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = EngineConfiguration.UserLimits
            
            fileprivate let isPremium: Bool
            public init(isPremium: Bool) {
                self.isPremium = isPremium
            }
            
            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.appConfiguration]))
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                guard let appConfiguration = view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) else {
                    return EngineConfiguration.UserLimits(UserLimitsConfiguration.defaultValue)
                }
                return EngineConfiguration.UserLimits(UserLimitsConfiguration(appConfiguration: appConfiguration, isPremium: self.isPremium))
            }
        }
        
        public struct SuggestedLocalization: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = SuggestedLocalizationEntry?
            
            public init() {
            }
            
            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.suggestedLocalization]))
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                guard let suggestedLocalization = view.values[PreferencesKeys.suggestedLocalization]?.get(SuggestedLocalizationEntry.self) else {
                    return nil
                }
                return suggestedLocalization
            }
        }

        public struct SearchBots: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = EngineConfiguration.SearchBots
            
            public init() {
            }
            
            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.searchBotsConfiguration]))
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                guard let value = view.values[PreferencesKeys.searchBotsConfiguration]?.get(SearchBotsConfiguration.self) else {
                    return EngineConfiguration.SearchBots(SearchBotsConfiguration.defaultValue)
                }
                return EngineConfiguration.SearchBots(value)
            }
        }
        
        public struct ApplicationSpecificPreference: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = PreferencesEntry?
            
            private let itemKey: ValueBoxKey
            public init(key: ValueBoxKey) {
                self.itemKey = key
            }
            
            var key: PostboxViewKey {
                return .preferences(keys: Set([self.itemKey]))
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                guard let value = view.values[self.itemKey] else {
                    return nil
                }
                return value
            }
        }
        
        public struct ContentSettings: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = EngineContentSettings
            
            public init() {
            }
            
            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.appConfiguration]))
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                guard let appConfiguration = view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) else {
                    return EngineContentSettings(appConfiguration: AppConfiguration.defaultValue)
                }
                return EngineContentSettings(appConfiguration: appConfiguration)
            }
        }
        
        public struct LocalizationList: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = LocalizationListState
            
            public init() {
            }
            
            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.localizationListState]))
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                guard let localizationListState = view.values[PreferencesKeys.localizationListState]?.get(LocalizationListState.self) else {
                    return LocalizationListState.defaultSettings
                }
                return localizationListState
            }
        }
        
        public struct PremiumPromo: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = PremiumPromoConfiguration
            
            public init() {
            }
            
            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.premiumPromo]))
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                guard let premiumPromoConfiguration = view.values[PreferencesKeys.premiumPromo]?.get(PremiumPromoConfiguration.self) else {
                    return PremiumPromoConfiguration.defaultValue
                }
                return premiumPromoConfiguration
            }
        }
        
        public struct GlobalAutoremoveTimeout: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = Int32?
            
            public init() {
            }
            
            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.globalMessageAutoremoveTimeoutSettings]))
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                guard let settings = view.values[PreferencesKeys.globalMessageAutoremoveTimeoutSettings]?.get(GlobalMessageAutoremoveTimeoutSettings.self) else {
                    return GlobalMessageAutoremoveTimeoutSettings.default.messageAutoremoveTimeout
                }
                return settings.messageAutoremoveTimeout
            }
        }
        
        public struct Links: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = EngineConfiguration.Links
            
            public init() {
            }
            
            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.linksConfiguration]))
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                guard let value = view.values[PreferencesKeys.linksConfiguration]?.get(LinksConfiguration.self) else {
                    return EngineConfiguration.Links(LinksConfiguration.defaultValue)
                }
                return EngineConfiguration.Links(value)
            }
        }
        
        public struct GlobalPrivacy: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = GlobalPrivacySettings
            
            public init() {
            }
            
            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.globalPrivacySettings]))
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                guard let value = view.values[PreferencesKeys.globalPrivacySettings]?.get(GlobalPrivacySettings.self) else {
                    return GlobalPrivacySettings.default
                }
                return value
            }
        }
        
        public struct StoryConfigurationState: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = Stories.ConfigurationState
            
            public init() {
            }
            
            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.storiesConfiguration]))
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                guard let value = view.values[PreferencesKeys.storiesConfiguration]?.get(Stories.ConfigurationState.self) else {
                    return Stories.ConfigurationState.default
                }
                return value
            }
        }
    }
}
