import Foundation
import TelegramCore

public enum PremiumIntroSource {
    case settings
    case stickers
    case reactions
    case ads
    case upload
    case groupsAndChannels
    case pinnedChats
    case publicLinks
    case savedGifs
    case savedStickers
    case folders
    case chatsPerFolder
    case accounts
    case appIcons
    case about
    case deeplink(String?)
    case profile(EnginePeer.Id)
    case emojiStatus(EnginePeer.Id, Int64, TelegramMediaFile?, LoadedStickerPack?)
    case voiceToText
    case fasterDownload
    case translation
    case stories
    case storiesDownload
    case storiesStealthMode
    case storiesPermanentViews
    case storiesFormatting
    case storiesExpirationDurations
    case storiesSuggestedReactions
    case channelBoost(EnginePeer.Id)
    case nameColor
    case similarChannels
    case wallpapers
    case presence
    case readTime
}

public enum PremiumGiftSource: Equatable {
    case profile
    case attachMenu
    case settings
    case chatList
    case channelBoost
    case deeplink(String?)
}

public enum PremiumDemoSubject {
    case doubleLimits
    case moreUpload
    case fasterDownload
    case voiceToText
    case noAds
    case uniqueReactions
    case premiumStickers
    case advancedChatManagement
    case profileBadge
    case animatedUserpics
    case appIcons
    case animatedEmoji
    case emojiStatus
    case translation
    case stories
    case colors
    case wallpapers
}

public enum PremiumLimitSubject {
    case folders
    case chatsPerFolder
    case pins
    case files
    case accounts
    case linksPerSharedFolder
    case membershipInSharedFolders
    case channels
    case expiringStories
    case storiesWeekly
    case storiesMonthly
    case storiesChannelBoost(peer: EnginePeer, isCurrent: Bool, level: Int32, currentLevelBoosts: Int32, nextLevelBoosts: Int32?, link: String?, myBoostCount: Int32, canBoostAgain: Bool)
}

public enum PremiumPrivacySubject {
    case presence
    case readTime
}

public struct PremiumConfiguration {
    public static var defaultValue: PremiumConfiguration {
        return PremiumConfiguration(
            isPremiumDisabled: false,
            showPremiumGiftInAttachMenu: false,
            showPremiumGiftInTextField: false,
            giveawayGiftsPurchaseAvailable: false,
            boostsPerGiftCount: 3,
            audioTransciptionTrialMaxDuration: 300,
            audioTransciptionTrialCount: 2,
            minChannelNameColorLevel: 1,
            minChannelNameIconLevel: 4,
            minChannelProfileColorLevel: 5,
            minChannelProfileIconLevel: 7,
            minChannelEmojiStatusLevel: 8,
            minChannelWallpaperLevel: 9,
            minChannelCustomWallpaperLevel: 10
        )
    }
    
    public let isPremiumDisabled: Bool
    public let showPremiumGiftInAttachMenu: Bool
    public let showPremiumGiftInTextField: Bool
    public let giveawayGiftsPurchaseAvailable: Bool
    public let boostsPerGiftCount: Int32
    public let audioTransciptionTrialMaxDuration: Int32
    public let audioTransciptionTrialCount: Int32
    public let minChannelNameColorLevel: Int32
    public let minChannelNameIconLevel: Int32
    public let minChannelProfileColorLevel: Int32
    public let minChannelProfileIconLevel: Int32
    public let minChannelEmojiStatusLevel: Int32
    public let minChannelWallpaperLevel: Int32
    public let minChannelCustomWallpaperLevel: Int32
    
    fileprivate init(
        isPremiumDisabled: Bool,
        showPremiumGiftInAttachMenu: Bool,
        showPremiumGiftInTextField: Bool,
        giveawayGiftsPurchaseAvailable: Bool,
        boostsPerGiftCount: Int32,
        audioTransciptionTrialMaxDuration: Int32,
        audioTransciptionTrialCount: Int32,
        minChannelNameColorLevel: Int32,
        minChannelNameIconLevel: Int32,
        minChannelProfileColorLevel: Int32,
        minChannelProfileIconLevel: Int32,
        minChannelEmojiStatusLevel: Int32,
        minChannelWallpaperLevel: Int32,
        minChannelCustomWallpaperLevel: Int32
    
    ) {
        self.isPremiumDisabled = isPremiumDisabled
        self.showPremiumGiftInAttachMenu = showPremiumGiftInAttachMenu
        self.showPremiumGiftInTextField = showPremiumGiftInTextField
        self.giveawayGiftsPurchaseAvailable = giveawayGiftsPurchaseAvailable
        self.boostsPerGiftCount = boostsPerGiftCount
        self.audioTransciptionTrialMaxDuration = audioTransciptionTrialMaxDuration
        self.audioTransciptionTrialCount = audioTransciptionTrialCount
        self.minChannelNameColorLevel = minChannelNameColorLevel
        self.minChannelNameIconLevel = minChannelNameIconLevel
        self.minChannelProfileColorLevel = minChannelProfileColorLevel
        self.minChannelProfileIconLevel = minChannelProfileIconLevel
        self.minChannelEmojiStatusLevel = minChannelEmojiStatusLevel
        self.minChannelWallpaperLevel = minChannelWallpaperLevel
        self.minChannelCustomWallpaperLevel = minChannelCustomWallpaperLevel
    }
    
    public static func with(appConfiguration: AppConfiguration) -> PremiumConfiguration {
        let defaultValue = self.defaultValue
        if let data = appConfiguration.data {
            func get(_ value: Any?) -> Int32? {
                return (value as? Double).flatMap(Int32.init)
            }
            return PremiumConfiguration(
                isPremiumDisabled: data["premium_purchase_blocked"] as? Bool ?? defaultValue.isPremiumDisabled,
                showPremiumGiftInAttachMenu: data["premium_gift_attach_menu_icon"] as? Bool ?? defaultValue.showPremiumGiftInAttachMenu,
                showPremiumGiftInTextField: data["premium_gift_text_field_icon"] as? Bool ?? defaultValue.showPremiumGiftInTextField,
                giveawayGiftsPurchaseAvailable: data["giveaway_gifts_purchase_available"] as? Bool ?? defaultValue.giveawayGiftsPurchaseAvailable,
                boostsPerGiftCount: get(data["boosts_per_sent_gift"]) ?? defaultValue.boostsPerGiftCount,
                audioTransciptionTrialMaxDuration: get(data["transcribe_audio_trial_duration_max"]) ?? defaultValue.audioTransciptionTrialMaxDuration,
                audioTransciptionTrialCount: get(data["transcribe_audio_trial_weekly_number"]) ?? defaultValue.audioTransciptionTrialCount,
                minChannelNameColorLevel: get(data["channel_color_level_min"]) ?? defaultValue.minChannelNameColorLevel,
                minChannelNameIconLevel: get(data["channel_bg_icon_level_min"]) ?? defaultValue.minChannelNameIconLevel,
                minChannelProfileColorLevel: get(data["channel_profile_color_level_min"]) ?? defaultValue.minChannelProfileColorLevel,
                minChannelProfileIconLevel: get(data["channel_profile_bg_icon_level_min"]) ?? defaultValue.minChannelProfileIconLevel,
                minChannelEmojiStatusLevel: get(data["channel_emoji_status_level_min"]) ?? defaultValue.minChannelEmojiStatusLevel,
                minChannelWallpaperLevel: get(data["channel_wallpaper_level_min"]) ?? defaultValue.minChannelWallpaperLevel,
                minChannelCustomWallpaperLevel: get(data["channel_custom_wallpaper_level_min"]) ?? defaultValue.minChannelCustomWallpaperLevel
            )
        } else {
            return defaultValue
        }
    }
}
