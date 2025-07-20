import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import PresentationDataUtils
import ViewControllerComponent
import AccountContext
import SolidRoundedButtonComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import BundleIconComponent
import BlurredBackgroundComponent
import Markdown
import InAppPurchaseManager
import ConfettiEffect
import TextFormat
import InstantPageCache
import UniversalMediaPlayer
import CheckNode
import AnimationCache
import MultiAnimationRenderer
import TelegramNotices
import UndoUI
import TelegramStringFormatting
import ListSectionComponent
import ListActionItemComponent
import EmojiStatusSelectionComponent
import EmojiStatusComponent
import EntityKeyboard
import EmojiActionIconComponent
import ScrollComponent
import PremiumStarComponent
import PremiumCoinComponent

public enum PremiumSource: Equatable {
    public static func == (lhs: PremiumSource, rhs: PremiumSource) -> Bool {
        switch lhs {
        case .settings:
            if case .settings = rhs {
                return true
            } else {
                return false
            }
        case .stickers:
            if case .stickers = rhs {
                return true
            } else {
                return false
            }
        case .reactions:
            if case .reactions = rhs {
                return true
            } else {
                return false
            }
        case .ads:
            if case .ads = rhs {
                return true
            } else {
                return false
            }
        case .upload:
            if case .upload = rhs {
                return true
            } else {
                return false
            }
        case .groupsAndChannels:
            if case .groupsAndChannels = rhs {
                return true
            } else {
                return false
            }
        case .pinnedChats:
            if case .pinnedChats = rhs {
                return true
            } else {
                return false
            }
        case .publicLinks:
            if case .publicLinks = rhs {
                return true
            } else {
                return false
            }
        case .savedGifs:
            if case .savedGifs = rhs {
                return true
            } else {
                return false
            }
        case .savedStickers:
            if case .savedStickers = rhs {
                return true
            } else {
                return false
            }
        case .folders:
            if case .folders = rhs {
                return true
            } else {
                return false
            }
        case .chatsPerFolder:
            if case .chatsPerFolder = rhs {
                return true
            } else {
                return false
            }
        case .accounts:
            if case .accounts = rhs {
                return true
            } else {
                return false
            }
        case .about:
            if case .about = rhs {
                return true
            } else {
                return false
            }
        case .appIcons:
            if case .appIcons = rhs {
                return true
            } else {
                return false
            }
        case .animatedEmoji:
            if case .animatedEmoji = rhs {
                return true
            } else {
                return false
            }
        case let .deeplink(link):
            if case .deeplink(link) = rhs {
                return true
            } else {
                return false
            }
        case let .profile(peerId):
            if case .profile(peerId) = rhs {
                return true
            } else {
                return false
            }
        case let .emojiStatus(lhsPeerId, lhsFileId, lhsFile, _):
            if case let .emojiStatus(rhsPeerId, rhsFileId, rhsFile, _) = rhs {
                return lhsPeerId == rhsPeerId && lhsFileId == rhsFileId && lhsFile == rhsFile
            } else {
                return false
            }
        case let .gift(from, to, duration, slug):
            if case .gift(from, to, duration, slug) = rhs {
                return true
            } else {
                return false
            }
        case .giftTerms:
            if case .giftTerms = rhs {
                return true
            } else {
                return false
            }
        case .voiceToText:
            if case .voiceToText = rhs {
                return true
            } else {
                return false
            }
        case .fasterDownload:
            if case .fasterDownload = rhs {
                return true
            } else {
                return false
            }
        case .translation:
            if case .translation = rhs {
                return true
            } else {
                return false
            }
        case .linksPerSharedFolder:
            if case .linksPerSharedFolder = rhs {
                return true
            } else {
                return false
            }
        case .membershipInSharedFolders:
            if case .membershipInSharedFolders = rhs {
                return true
            } else {
                return false
            }
        case .stories:
            if case .stories = rhs {
                return true
            } else {
                return false
            }
        case .storiesDownload:
            if case .storiesDownload = rhs {
                return true
            } else {
                return false
            }
        case .storiesStealthMode:
            if case .storiesStealthMode = rhs {
                return true
            } else {
                return false
            }
        case .storiesPermanentViews:
            if case .storiesPermanentViews = rhs {
                return true
            } else {
                return false
            }
        case .storiesFormatting:
            if case .storiesFormatting = rhs {
                return true
            } else {
                return false
            }
        case .storiesExpirationDurations:
            if case .storiesExpirationDurations = rhs {
                return true
            } else {
                return false
            }
        case .storiesSuggestedReactions:
            if case .storiesSuggestedReactions = rhs {
                return true
            } else {
                return false
            }
        case .storiesHigherQuality:
            if case .storiesHigherQuality = rhs {
                return true
            } else {
                return false
            }
        case .storiesLinks:
            if case .storiesLinks = rhs {
                return true
            } else {
                return false
            }
        case let .channelBoost(peerId):
            if case .channelBoost(peerId) = rhs {
                return true
            } else {
                return false
            }
        case .nameColor:
            if case .nameColor = rhs {
                return true
            } else {
                return false
            }
        case .similarChannels:
            if case .similarChannels = rhs {
                return true
            } else {
                return false
            }
        case .wallpapers:
            if case .wallpapers = rhs {
                return true
            } else {
                return false
            }
        case .presence:
            if case .presence = rhs {
                return true
            } else {
                return false
            }
        case .readTime:
            if case .readTime = rhs {
                return true
            } else {
                return false
            }
        case .messageTags:
            if case .messageTags = rhs {
                return true
            } else {
                return false
            }
        case .folderTags:
            if case .folderTags = rhs {
                return true
            } else {
                return false
            }
        case .messageEffects:
            if case .messageEffects = rhs {
                return true
            } else {
                return false
            }
        case .todo:
            if case .todo = rhs {
                return true
            } else {
                return false
            }
        case let .auth(lhsPrice):
            if case let .auth(rhsPrice) = rhs, lhsPrice == rhsPrice {
                return true
            } else {
                return false
            }
        }
    }
    
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
    case about
    case appIcons
    case animatedEmoji
    case deeplink(String?)
    case profile(EnginePeer.Id)
    case emojiStatus(EnginePeer.Id, Int64, TelegramMediaFile?, LoadedStickerPack?)
    case gift(from: EnginePeer.Id, to: EnginePeer.Id, duration: Int32, giftCode: PremiumGiftCodeInfo?)
    case giftTerms
    case voiceToText
    case fasterDownload
    case translation
    case linksPerSharedFolder
    case membershipInSharedFolders
    case stories
    case storiesDownload
    case storiesStealthMode
    case storiesPermanentViews
    case storiesFormatting
    case storiesExpirationDurations
    case storiesSuggestedReactions
    case storiesLinks
    case storiesHigherQuality
    case channelBoost(EnginePeer.Id)
    case nameColor
    case similarChannels
    case wallpapers
    case presence
    case readTime
    case messageTags
    case folderTags
    case messageEffects
    case todo
    case auth(String)
    
    var identifier: String? {
        switch self {
        case .settings:
            return "settings"
        case .stickers:
            return "premium_stickers"
        case .reactions:
            return "infinite_reactions"
        case .ads:
            return "no_ads"
        case .upload:
            return "more_upload"
        case .appIcons:
            return "app_icons"
        case .groupsAndChannels:
            return "double_limits__channels"
        case .pinnedChats:
            return "double_limits__dialog_pinned"
        case .publicLinks:
            return "double_limits__channels_public"
        case .savedGifs:
            return "double_limits__saved_gifs"
        case .savedStickers:
            return "double_limits__stickers_faved"
        case .folders:
            return "double_limits__dialog_filters"
        case .chatsPerFolder:
            return "double_limits__dialog_filters_chats"
        case .accounts:
            return "double_limits__accounts"
        case .about:
            return "double_limits__about"
        case .animatedEmoji:
            return "animated_emoji"
        case let .profile(id):
            return "profile__\(id.id._internalGetInt64Value())"
        case .emojiStatus:
            return "emoji_status"
        case .voiceToText:
            return "voice_to_text"
        case .fasterDownload:
            return "faster_download"
        case .gift, .giftTerms:
            return nil
        case let .deeplink(reference):
            if let reference = reference {
                return "deeplink_\(reference)"
            } else {
                return "deeplink"
            }
        case .translation:
            return "translations"
        case .linksPerSharedFolder:
            return "double_limits__community_invites"
        case .membershipInSharedFolders:
            return "double_limits__communities_joined"
        case .stories:
            return "stories"
        case .storiesDownload:
            return "stories__save_stories_to_gallery"
        case .storiesStealthMode:
            return "stories__stealth_mode"
        case .storiesPermanentViews:
            return "stories__permanent_views_history"
        case .storiesFormatting:
            return "stories__links_and_formatting"
        case .storiesExpirationDurations:
            return "stories__expiration_durations"
        case .storiesSuggestedReactions:
            return "stories__suggested_reactions"
        case .storiesLinks:
            return "stories__links"
        case .storiesHigherQuality:
            return "stories__quality"
        case let .channelBoost(peerId):
            return "channel_boost__\(peerId.id._internalGetInt64Value())"
        case .nameColor:
            return "name_color"
        case .similarChannels:
            return "similar_channels"
        case .wallpapers:
            return "wallpapers"
        case .presence:
            return "presence"
        case .readTime:
            return "read_time"
        case .messageTags:
            return "saved_tags"
        case .folderTags:
            return "folder_tags"
        case .messageEffects:
            return "effects"
        case .todo:
            return "todo"
        case .auth:
            return "auth"
        }
    }
}

public enum PremiumPerk: CaseIterable {
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
    case messageTags
    case lastSeen
    case messagePrivacy
    case business
    case folderTags
    case messageEffects
    case todo
    
    case businessLocation
    case businessHours
    case businessGreetingMessage
    case businessQuickReplies
    case businessAwayMessage
    case businessChatBots
    case businessIntro
    case businessLinks
    
    public static var allCases: [PremiumPerk] {
        return [
            .doubleLimits,
            .moreUpload,
            .fasterDownload,
            .voiceToText,
            .noAds,
            .uniqueReactions,
            .premiumStickers,
            .advancedChatManagement,
            .profileBadge,
            .animatedUserpics,
            .appIcons,
            .animatedEmoji,
            .emojiStatus,
            .translation,
            .stories,
            .colors,
            .wallpapers,
            .messageTags,
            .lastSeen,
            .messagePrivacy,
            .folderTags,
            .business,
            .messageEffects,
            .todo
        ]
    }
    
    public static var allBusinessCases: [PremiumPerk] {
        return [
            .businessLocation,
            .businessHours,
            .businessQuickReplies,
            .businessGreetingMessage,
            .businessLinks,
            .businessAwayMessage,
            .businessIntro,
            .businessChatBots
        ]
    }
    
    
    init?(identifier: String, business: Bool) {
        for perk in business ? PremiumPerk.allBusinessCases : PremiumPerk.allCases {
            if perk.identifier == identifier {
                self = perk
                return
            }
        }
        return nil
    }
    
    var identifier: String {
        switch self {
        case .doubleLimits:
            return "double_limits"
        case .moreUpload:
            return "more_upload"
        case .fasterDownload:
            return "faster_download"
        case .voiceToText:
            return "voice_to_text"
        case .noAds:
            return "no_ads"
        case .uniqueReactions:
            return "infinite_reactions"
        case .premiumStickers:
            return "premium_stickers"
        case .advancedChatManagement:
            return "advanced_chat_management"
        case .profileBadge:
            return "profile_badge"
        case .animatedUserpics:
            return "animated_userpics"
        case .appIcons:
            return "app_icons"
        case .animatedEmoji:
            return "animated_emoji"
        case .emojiStatus:
            return "emoji_status"
        case .translation:
            return "translations"
        case .stories:
            return "stories"
        case .colors:
            return "peer_colors"
        case .wallpapers:
            return "wallpapers"
        case .messageTags:
            return "saved_tags"
        case .lastSeen:
            return "last_seen"
        case .messagePrivacy:
            return "message_privacy"
        case .folderTags:
            return "folder_tags"
        case .messageEffects:
            return "effects"
        case .todo:
            return "todo"
        case .business:
            return "business"
        case .businessLocation:
            return "business_location"
        case .businessHours:
            return "business_hours"
        case .businessQuickReplies:
            return "quick_replies"
        case .businessGreetingMessage:
            return "greeting_message"
        case .businessAwayMessage:
            return "away_message"
        case .businessChatBots:
            return "business_bots"
        case .businessIntro:
            return "business_intro"
        case .businessLinks:
            return "business_links"
        }
    }
    
    func title(strings: PresentationStrings) -> String {
        switch self {
        case .doubleLimits:
            return strings.Premium_DoubledLimits
        case .moreUpload:
            return strings.Premium_UploadSize
        case .fasterDownload:
            return strings.Premium_FasterSpeed
        case .voiceToText:
            return strings.Premium_VoiceToText
        case .noAds:
            return strings.Premium_NoAds
        case .uniqueReactions:
            return strings.Premium_InfiniteReactions
        case .premiumStickers:
            return strings.Premium_Stickers
        case .advancedChatManagement:
            return strings.Premium_ChatManagement
        case .profileBadge:
            return strings.Premium_Badge
        case .animatedUserpics:
            return strings.Premium_Avatar
        case .appIcons:
            return strings.Premium_AppIcon
        case .animatedEmoji:
            return strings.Premium_AnimatedEmoji
        case .emojiStatus:
            return strings.Premium_EmojiStatus
        case .translation:
            return strings.Premium_Translation
        case .stories:
            return strings.Premium_Stories
        case .colors:
            return strings.Premium_Colors
        case .wallpapers:
            return strings.Premium_Wallpapers
        case .messageTags:
            return strings.Premium_MessageTags
        case .lastSeen:
            return strings.Premium_LastSeen
        case .messagePrivacy:
            return strings.Premium_MessagePrivacy
        case .folderTags:
            return strings.Premium_FolderTags
        case .business:
            return strings.Premium_Business
        case .messageEffects:
            return strings.Premium_MessageEffects
        case .todo:
            return strings.Premium_Todo
        case .businessLocation:
            return strings.Business_Location
        case .businessHours:
            return strings.Business_OpeningHours
        case .businessQuickReplies:
            return strings.Business_QuickReplies
        case .businessGreetingMessage:
            return strings.Business_GreetingMessages
        case .businessAwayMessage:
            return strings.Business_AwayMessages
        case .businessChatBots:
            return strings.Business_ChatbotsItem
        case .businessIntro:
            return strings.Business_Intro
        case .businessLinks:
            return strings.Business_Links
        }
    }
    
    func subtitle(strings: PresentationStrings) -> String {
        switch self {
        case .doubleLimits:
            return strings.Premium_DoubledLimitsInfo
        case .moreUpload:
            return strings.Premium_UploadSizeInfo
        case .fasterDownload:
            return strings.Premium_FasterSpeedInfo
        case .voiceToText:
            return strings.Premium_VoiceToTextInfo
        case .noAds:
            return strings.Premium_NoAdsInfo
        case .uniqueReactions:
            return strings.Premium_InfiniteReactionsInfo
        case .premiumStickers:
            return strings.Premium_StickersInfo
        case .advancedChatManagement:
            return strings.Premium_ChatManagementInfo
        case .profileBadge:
            return strings.Premium_BadgeInfo
        case .animatedUserpics:
            return strings.Premium_AvatarInfo
        case .appIcons:
            return strings.Premium_AppIconInfo
        case .animatedEmoji:
            return strings.Premium_AnimatedEmojiInfo
        case .emojiStatus:
            return strings.Premium_EmojiStatusInfo
        case .translation:
            return strings.Premium_TranslationInfo
        case .stories:
            return strings.Premium_StoriesInfo
        case .colors:
            return strings.Premium_ColorsInfo
        case .wallpapers:
            return strings.Premium_WallpapersInfo
        case .messageTags:
            return strings.Premium_MessageTagsInfo
        case .lastSeen:
            return strings.Premium_LastSeenInfo
        case .messagePrivacy:
            return strings.Premium_MessagePrivacyInfo
        case .folderTags:
            return strings.Premium_FolderTagsInfo
        case .business:
            return strings.Premium_BusinessInfo
        case .messageEffects:
            return strings.Premium_MessageEffectsInfo
        case .todo:
            return strings.Premium_TodoInfo
        case .businessLocation:
            return strings.Business_LocationInfo
        case .businessHours:
            return strings.Business_OpeningHoursInfo
        case .businessQuickReplies:
            return strings.Business_QuickRepliesInfo
        case .businessGreetingMessage:
            return strings.Business_GreetingMessagesInfo
        case .businessAwayMessage:
            return strings.Business_AwayMessagesInfo
        case .businessChatBots:
            return strings.Business_ChatbotsInfo
        case .businessIntro:
            return strings.Business_IntroInfo
        case .businessLinks:
            return strings.Business_LinksInfo
        }
    }
    
    var iconName: String {
        switch self {
        case .doubleLimits:
            return "Premium/Perk/Limits"
        case .moreUpload:
            return "Premium/Perk/Upload"
        case .fasterDownload:
            return "Premium/Perk/Speed"
        case .voiceToText:
            return "Premium/Perk/Voice"
        case .noAds:
            return "Premium/Perk/NoAds"
        case .uniqueReactions:
            return "Premium/Perk/Reactions"
        case .premiumStickers:
            return "Premium/Perk/Stickers"
        case .advancedChatManagement:
            return "Premium/Perk/Chat"
        case .profileBadge:
            return "Premium/Perk/Badge"
        case .animatedUserpics:
            return "Premium/Perk/Avatar"
        case .appIcons:
            return "Premium/Perk/AppIcon"
        case .animatedEmoji:
            return "Premium/Perk/Emoji"
        case .emojiStatus:
            return "Premium/Perk/Status"
        case .translation:
            return "Premium/Perk/Translation"
        case .stories:
            return "Premium/Perk/Stories"
        case .colors:
            return "Premium/Perk/Colors"
        case .wallpapers:
            return "Premium/Perk/Wallpapers"
        case .messageTags:
            return "Premium/Perk/MessageTags"
        case .lastSeen:
            return "Premium/Perk/LastSeen"
        case .messagePrivacy:
            return "Premium/Perk/MessagePrivacy"
        case .folderTags:
            return "Premium/Perk/MessageTags"
        case .business:
            return "Premium/Perk/Business"
        case .messageEffects:
            return "Premium/Perk/MessageEffects"
        case .todo:
            return "Premium/Perk/Todo"
        case .businessLocation:
            return "Premium/BusinessPerk/Location"
        case .businessHours:
            return "Premium/BusinessPerk/Hours"
        case .businessQuickReplies:
            return "Premium/BusinessPerk/Replies"
        case .businessGreetingMessage:
            return "Premium/BusinessPerk/Greetings"
        case .businessAwayMessage:
            return "Premium/BusinessPerk/Away"
        case .businessChatBots:
            return "Premium/BusinessPerk/Chatbots"
        case .businessIntro:
            return "Premium/BusinessPerk/Intro"
        case .businessLinks:
            return "Premium/BusinessPerk/Links"
        }
    }
}

struct PremiumIntroConfiguration {
    static var defaultValue: PremiumIntroConfiguration {
        return PremiumIntroConfiguration(perks: [
            .stories,
            .moreUpload,
            .doubleLimits,
            .lastSeen,
            .voiceToText,
            .fasterDownload,
            .translation,
            .todo,
            .animatedEmoji,
            .emojiStatus,
            .messageEffects,
            .messageTags,
            .colors,
            .wallpapers,
            .profileBadge,
            .messagePrivacy,
            .advancedChatManagement,
            .noAds,
            .appIcons,
            .uniqueReactions,
            .animatedUserpics,
            .premiumStickers,
            .business
        ], businessPerks: [
            .businessLocation,
            .businessHours,
            .businessQuickReplies,
            .businessGreetingMessage,
            .businessAwayMessage,
            .businessLinks,
            .businessIntro,
            .businessChatBots
        ])
    }
    
    let perks: [PremiumPerk]
    let businessPerks: [PremiumPerk]
    
    fileprivate init(perks: [PremiumPerk], businessPerks: [PremiumPerk]) {
        self.perks = perks
        self.businessPerks = businessPerks
    }
    
    public static func with(appConfiguration: AppConfiguration) -> PremiumIntroConfiguration {
        if let data = appConfiguration.data, let values = data["premium_promo_order"] as? [String] {
            var perks: [PremiumPerk] = []
            for value in values {
                if let perk = PremiumPerk(identifier: value, business: false) {
                    if !perks.contains(perk) {
                        perks.append(perk)
                    } else {
                        perks = []
                        break
                    }
                } else {
                    perks = []
                    break
                }
            }
            if perks.count < 4 {
                perks = PremiumIntroConfiguration.defaultValue.perks
            }
                        
            var businessPerks: [PremiumPerk] = []
            if let values = data["business_promo_order"] as? [String] {
                for value in values {
                    if let perk = PremiumPerk(identifier: value, business: true) {
                        if !businessPerks.contains(perk) {
                            businessPerks.append(perk)
                        } else {
                            businessPerks = []
                            break
                        }
                    }
                }
            }
            if businessPerks.count < 4 {
                businessPerks = PremiumIntroConfiguration.defaultValue.businessPerks
            }
            
            return PremiumIntroConfiguration(perks: perks, businessPerks: businessPerks)
        } else {
            return .defaultValue
        }
    }
}

private struct PremiumProduct: Equatable {
    let option: PremiumPromoConfiguration.PremiumProductOption
    let storeProduct: InAppPurchaseManager.Product
    
    var id: String {
        return self.storeProduct.id
    }
    
    var months: Int32 {
        return self.option.months
    }
    
    var price: String {
        return self.storeProduct.price
    }
    
    var pricePerMonth: String {
        return self.storeProduct.pricePerMonth(Int(self.months))
    }
    
    var isCurrent: Bool {
        return self.option.isCurrent
    }
    
    var transactionId: String? {
        return self.option.transactionId
    }
}

final class PerkIconComponent: CombinedComponent {
    let backgroundColor: UIColor
    let foregroundColor: UIColor
    let iconName: String
    
    init(
        backgroundColor: UIColor,
        foregroundColor: UIColor,
        iconName: String
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.iconName = iconName
    }
    
    static func ==(lhs: PerkIconComponent, rhs: PerkIconComponent) -> Bool {
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.foregroundColor != rhs.foregroundColor {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        return true
    }
    
    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let icon = Child(BundleIconComponent.self)

        return { context in
            let component = context.component
        
            let iconSize = CGSize(width: 30.0, height: 30.0)
            
            let background = background.update(
                component: RoundedRectangle(
                    color: component.backgroundColor,
                    cornerRadius: 7.0
                ),
                availableSize: iconSize,
                transition: context.transition
            )
            
            let icon = icon.update(
                component: BundleIconComponent(
                    name: component.iconName,
                    tintColor: .white
                ),
                availableSize: iconSize,
                transition: context.transition
            )
            
            let iconPosition = CGPoint(x: background.size.width / 2.0, y: background.size.height / 2.0)
            context.add(background
                .position(iconPosition)
            )
            context.add(icon
                .position(iconPosition)
            )
            return iconSize
        }
    }
}

final class SectionGroupComponent: Component {
    public final class Item: Equatable {
        public let content: AnyComponentWithIdentity<Empty>
        public let accessibilityLabel: String
        public let isEnabled: Bool
        public let action: () -> Void
        
        public init(_ content: AnyComponentWithIdentity<Empty>, accessibilityLabel: String, isEnabled: Bool = true, action: @escaping () -> Void) {
            self.content = content
            self.accessibilityLabel = accessibilityLabel
            self.isEnabled = isEnabled
            self.action = action
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.content != rhs.content {
                return false
            }
            if lhs.accessibilityLabel != rhs.accessibilityLabel {
                return false
            }
            if lhs.isEnabled != rhs.isEnabled {
                return false
            }
            return true
        }
    }
    
    public let items: [Item]
    public let backgroundColor: UIColor
    public let selectionColor: UIColor
    public let separatorColor: UIColor
    
    public init(
        items: [Item],
        backgroundColor: UIColor,
        selectionColor: UIColor,
        separatorColor: UIColor
    ) {
        self.items = items
        self.backgroundColor = backgroundColor
        self.selectionColor = selectionColor
        self.separatorColor = separatorColor
    }
    
    public static func ==(lhs: SectionGroupComponent, rhs: SectionGroupComponent) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.selectionColor != rhs.selectionColor {
            return false
        }
        if lhs.separatorColor != rhs.separatorColor {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var buttonViews: [AnyHashable: HighlightTrackingButton] = [:]
        private var itemViews: [AnyHashable: ComponentHostView<Empty>] = [:]
        private var separatorViews: [UIView] = []
        
        private var component: SectionGroupComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func buttonPressed(_ sender: HighlightTrackingButton) {
            guard let component = self.component else {
                return
            }
            
            if let (id, _) = self.buttonViews.first(where: { $0.value === sender }), let item = component.items.first(where: { $0.content.id == id }) {
                item.action()
            }
        }
        
        func update(component: SectionGroupComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let sideInset: CGFloat = 16.0
            
            self.backgroundColor = component.backgroundColor
            
            var size = CGSize(width: availableSize.width, height: 0.0)
            
            var validIds: [AnyHashable] = []
            
            var i = 0
            for item in component.items {
                validIds.append(item.content.id)
                
                let buttonView: HighlightTrackingButton
                let itemView: ComponentHostView<Empty>
                var itemTransition = transition
                
                if let current = self.buttonViews[item.content.id] {
                    buttonView = current
                } else {
                    buttonView = HighlightTrackingButton()
                    buttonView.isMultipleTouchEnabled = false
                    buttonView.isExclusiveTouch = true
                    buttonView.addTarget(self, action: #selector(self.buttonPressed(_:)), for: .touchUpInside)
                    self.buttonViews[item.content.id] = buttonView
                    self.addSubview(buttonView)
                }
                buttonView.accessibilityLabel = item.accessibilityLabel
                
                if let current = self.itemViews[item.content.id] {
                    itemView = current
                } else {
                    itemTransition = transition.withAnimation(.none)
                    itemView = ComponentHostView<Empty>()
                    self.itemViews[item.content.id] = itemView
                    self.addSubview(itemView)
                }
                let itemSize = itemView.update(
                    transition: itemTransition,
                    component: item.content.component,
                    environment: {},
                    containerSize: CGSize(width: size.width - sideInset, height: .greatestFiniteMagnitude)
                )
                buttonView.isEnabled = item.isEnabled
                itemView.alpha = item.isEnabled ? 1.0 : 0.3
                
                let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height), size: itemSize)
                buttonView.frame = CGRect(origin: itemFrame.origin, size: CGSize(width: availableSize.width, height: itemSize.height + UIScreenPixel))
                itemView.frame = CGRect(origin: CGPoint(x: itemFrame.minX + sideInset, y: itemFrame.minY + floor((itemFrame.height - itemSize.height) / 2.0)), size: itemSize)
                itemView.isUserInteractionEnabled = false
                
                buttonView.highligthedChanged = { [weak buttonView] highlighted in
                    if highlighted {
                        buttonView?.backgroundColor = component.selectionColor
                    } else {
                        UIView.animate(withDuration: 0.3, animations: {
                            buttonView?.backgroundColor = nil
                        })
                    }
                }
                
                size.height += itemSize.height
                
                if i != component.items.count - 1 {
                    let separatorView: UIView
                    if self.separatorViews.count > i {
                        separatorView = self.separatorViews[i]
                    } else {
                        separatorView = UIView()
                        self.separatorViews.append(separatorView)
                        self.addSubview(separatorView)
                    }
                    separatorView.backgroundColor = component.separatorColor
                    
                    separatorView.frame = CGRect(origin: CGPoint(x: itemFrame.minX + sideInset * 2.0 + 30.0, y: itemFrame.maxY), size: CGSize(width: size.width - sideInset * 2.0 - 30.0, height: UIScreenPixel))
                }
                i += 1
            }
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    itemView.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.itemViews.removeValue(forKey: id)
            }
            
            if !self.separatorViews.isEmpty, self.separatorViews.count > component.items.count - 1 {
                for i in (component.items.count - 1) ..< self.separatorViews.count {
                    self.separatorViews[i].removeFromSuperview()
                }
                self.separatorViews.removeSubrange((component.items.count - 1) ..< self.separatorViews.count)
            }
            
            self.component = component
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class PerkComponent: CombinedComponent {
    let iconName: String
    let iconBackgroundColors: [UIColor]
    let title: String
    let titleColor: UIColor
    let subtitle: String
    let subtitleColor: UIColor
    let arrowColor: UIColor
    let accentColor: UIColor
    let displayArrow: Bool
    let badge: String?
    
    init(
        iconName: String,
        iconBackgroundColors: [UIColor],
        title: String,
        titleColor: UIColor,
        subtitle: String,
        subtitleColor: UIColor,
        arrowColor: UIColor,
        accentColor: UIColor,
        displayArrow: Bool = true,
        badge: String? = nil
    ) {
        self.iconName = iconName
        self.iconBackgroundColors = iconBackgroundColors
        self.title = title
        self.titleColor = titleColor
        self.subtitle = subtitle
        self.subtitleColor = subtitleColor
        self.arrowColor = arrowColor
        self.accentColor = accentColor
        self.displayArrow = displayArrow
        self.badge = badge
    }
    
    static func ==(lhs: PerkComponent, rhs: PerkComponent) -> Bool {
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.iconBackgroundColors != rhs.iconBackgroundColors {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.titleColor != rhs.titleColor {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        if lhs.subtitleColor != rhs.subtitleColor {
            return false
        }
        if lhs.arrowColor != rhs.arrowColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.displayArrow != rhs.displayArrow {
            return false
        }
        if lhs.badge != rhs.badge {
            return false
        }
        return true
    }
    
    static var body: Body {
        let iconBackground = Child(RoundedRectangle.self)
        let icon = Child(BundleIconComponent.self)
        let title = Child(MultilineTextComponent.self)
        let subtitle = Child(MultilineTextComponent.self)
        let arrow = Child(BundleIconComponent.self)
        let badgeBackground = Child(RoundedRectangle.self)
        let badgeText = Child(MultilineTextComponent.self)

        return { context in
            let component = context.component
            
            let sideInset: CGFloat = 16.0
            let iconTopInset: CGFloat = 15.0
            let textTopInset: CGFloat = 9.0
            let textBottomInset: CGFloat = 9.0
            let spacing: CGFloat = 2.0
            let iconSize = CGSize(width: 30.0, height: 30.0)
            
            let iconBackground = iconBackground.update(
                component: RoundedRectangle(
                    colors: component.iconBackgroundColors,
                    cornerRadius: 7.0,
                    gradientDirection: .vertical),
                availableSize: iconSize,
                transition: context.transition
            )
            
            let icon = icon.update(
                component: BundleIconComponent(
                    name: component.iconName,
                    tintColor: .white
                ),
                availableSize: iconSize,
                transition: context.transition
            )
                        
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(
                        NSAttributedString(
                            string: component.title,
                            font: Font.regular(17),
                            textColor: component.titleColor
                        )
                    ),
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: context.availableSize.width - iconBackground.size.width - sideInset * 2.83, height: context.availableSize.height),
                transition: context.transition
            )
            
            let subtitle = subtitle.update(
                component: MultilineTextComponent(
                    text: .plain(
                        NSAttributedString(
                            string: component.subtitle,
                            font: Font.regular(13),
                            textColor: component.subtitleColor
                        )
                    ),
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: context.availableSize.width - iconBackground.size.width - sideInset * 2.83, height: context.availableSize.height),
                transition: context.transition
            )
            
            let iconPosition = CGPoint(x: iconBackground.size.width / 2.0, y: iconTopInset + iconBackground.size.height / 2.0)
            context.add(iconBackground
                .position(iconPosition)
            )
            
            context.add(icon
                .position(iconPosition)
            )
            
            context.add(title
                .position(CGPoint(x: iconBackground.size.width + sideInset + title.size.width / 2.0, y: textTopInset + title.size.height / 2.0))
            )
            
            if let badge = component.badge {
                let badgeText = badgeText.update(
                    component: MultilineTextComponent(text: .plain(NSAttributedString(string: badge, font: Font.semibold(11.0), textColor: .white))),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                
                let badgeWidth = badgeText.size.width + 7.0
                let badgeBackground = badgeBackground.update(
                    component: RoundedRectangle(
                        colors: component.iconBackgroundColors,
                        cornerRadius: 5.0,
                        gradientDirection: .vertical),
                    availableSize: CGSize(width: badgeWidth, height: 16.0),
                    transition: context.transition
                )
                
                context.add(badgeBackground
                    .position(CGPoint(x: iconBackground.size.width + sideInset + title.size.width + badgeWidth / 2.0 + 8.0, y: textTopInset + title.size.height / 2.0 - 1.0))
                )
                
                context.add(badgeText
                    .position(CGPoint(x: iconBackground.size.width + sideInset + title.size.width + badgeWidth / 2.0 + 8.0, y: textTopInset + title.size.height / 2.0 - 1.0))
                )
            }
            
            context.add(subtitle
                .position(CGPoint(x: iconBackground.size.width + sideInset + subtitle.size.width / 2.0, y: textTopInset + title.size.height + spacing + subtitle.size.height / 2.0))
            )
            
            let size = CGSize(width: context.availableSize.width, height: textTopInset + title.size.height + spacing + subtitle.size.height + textBottomInset)
            
            if component.displayArrow {
                let arrow = arrow.update(
                    component: BundleIconComponent(
                        name: "Item List/DisclosureArrow",
                        tintColor: component.arrowColor
                    ),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                context.add(arrow
                    .position(CGPoint(x: context.availableSize.width - 7.0 - arrow.size.width / 2.0, y: size.height / 2.0))
                )
            }
            
            return size
        }
    }
}


private final class PremiumIntroScreenContentComponent: CombinedComponent {
    typealias EnvironmentType = (ViewControllerComponentContainer.Environment, ScrollChildEnvironment)
    
    let screenContext: PremiumIntroScreen.ScreenContext
    let mode: PremiumIntroScreen.Mode
    let source: PremiumSource
    let forceDark: Bool
    let isPremium: Bool?
    let justBought: Bool
    let otherPeerName: String?
    let products: [PremiumProduct]?
    let selectedProductId: String?
    let validPurchases: [InAppPurchaseManager.ReceiptPurchase]
    let promoConfiguration: PremiumPromoConfiguration?
    let present: (ViewController) -> Void
    let push: (ViewController) -> Void
    let selectProduct: (String) -> Void
    let buy: () -> Void
    let updateIsFocused: (Bool) -> Void
    let copyLink: (String) -> Void
    let shareLink: (String) -> Void
    
    init(
        screenContext: PremiumIntroScreen.ScreenContext,
        mode: PremiumIntroScreen.Mode,
        source: PremiumSource,
        forceDark: Bool,
        isPremium: Bool?,
        justBought: Bool,
        otherPeerName: String?,
        products: [PremiumProduct]?,
        selectedProductId: String?,
        validPurchases: [InAppPurchaseManager.ReceiptPurchase],
        promoConfiguration: PremiumPromoConfiguration?,
        present: @escaping (ViewController) -> Void,
        push: @escaping (ViewController) -> Void,
        selectProduct: @escaping (String) -> Void,
        buy: @escaping () -> Void,
        updateIsFocused: @escaping (Bool) -> Void,
        copyLink: @escaping (String) -> Void,
        shareLink: @escaping (String) -> Void
    ) {
        self.screenContext = screenContext
        self.mode = mode
        self.source = source
        self.forceDark = forceDark
        self.isPremium = isPremium
        self.justBought = justBought
        self.otherPeerName = otherPeerName
        self.products = products
        self.selectedProductId = selectedProductId
        self.validPurchases = validPurchases
        self.promoConfiguration = promoConfiguration
        self.present = present
        self.push = push
        self.selectProduct = selectProduct
        self.buy = buy
        self.updateIsFocused = updateIsFocused
        self.copyLink = copyLink
        self.shareLink = shareLink
    }
    
    static func ==(lhs: PremiumIntroScreenContentComponent, rhs: PremiumIntroScreenContentComponent) -> Bool {
        if lhs.source != rhs.source {
            return false
        }
        if lhs.isPremium != rhs.isPremium {
            return false
        }
        if lhs.forceDark != rhs.forceDark {
            return false
        }
        if lhs.justBought != rhs.justBought {
            return false
        }
        if lhs.otherPeerName != rhs.otherPeerName {
            return false
        }
        if lhs.products != rhs.products {
            return false
        }
        if lhs.selectedProductId != rhs.selectedProductId {
            return false
        }
        if lhs.validPurchases != rhs.validPurchases {
            return false
        }
        if lhs.promoConfiguration != rhs.promoConfiguration {
            return false
        }
    
        return true
    }
    
    final class State: ComponentState {
        private let screenContext: PremiumIntroScreen.ScreenContext
        private let present: (ViewController) -> Void
    
        var products: [PremiumProduct]?
        var selectedProductId: String?
        var validPurchases: [InAppPurchaseManager.ReceiptPurchase] = []
        
        var newPerks: [String] = []
        
        var isPremium: Bool?
        var peer: EnginePeer?
        var adsEnabled = false
        
        private var disposable: Disposable?
        private(set) var configuration = PremiumIntroConfiguration.defaultValue
    
        private var stickersDisposable: Disposable?
        private var newPerksDisposable: Disposable?
        private var preloadDisposableSet =  DisposableSet()
        private var adsEnabledDisposable: Disposable?
        
        var price: String? {
            return self.products?.first(where: { $0.id == self.selectedProductId })?.price
        }
        
        var isAnnual: Bool {
            return self.products?.first(where: { $0.id == self.selectedProductId })?.id.hasSuffix(".annual") ?? false
        }
        
        var canUpgrade: Bool {
            if let products = self.products, let current = products.first(where: { $0.isCurrent }), let transactionId = current.transactionId {
                if self.validPurchases.contains(where: { $0.transactionId == transactionId }) {
                    return products.first(where: { $0.months > current.months }) != nil
                } else {
                    return false
                }
            } else {
                return false
            }
        }
        
        var cachedChevronImage: (UIImage, PresentationTheme)?
        
        init(
            screenContext: PremiumIntroScreen.ScreenContext,
            source: PremiumSource,
            present: @escaping (ViewController) -> Void
        ) {
            self.screenContext = screenContext
            self.present = present
            
            super.init()
            
            let premiumIntroConfiguration: Signal<PremiumIntroConfiguration, NoError>
            let accountPeer: Signal<EnginePeer?, NoError>
            switch screenContext {
            case let .accountContext(context):
                premiumIntroConfiguration = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.App())
                |> map { appConfiguration in
                    return PremiumIntroConfiguration.with(appConfiguration: appConfiguration)
                }
                accountPeer = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            case .sharedContext:
                premiumIntroConfiguration = .single(PremiumIntroConfiguration.defaultValue)
                accountPeer = .single(nil)
            }
            
            self.disposable = combineLatest(
                queue: Queue.mainQueue(),
                premiumIntroConfiguration,
                accountPeer
            ).start(next: { [weak self] premiumIntroConfiguration, accountPeer in
                guard let self else {
                    return
                }
                let isFirstTime = self.peer == nil
                
                self.configuration = premiumIntroConfiguration
                self.peer = accountPeer
                self.updated(transition: .immediate)
                
                if let identifier = source.identifier, isFirstTime {
                    var jsonString: String = "{"
                    jsonString += "\"source\": \"\(identifier)\","
                    
                    jsonString += "\"data\": {\"premium_promo_order\":["
                    var isFirst = true
                    for perk in premiumIntroConfiguration.perks {
                        if !isFirst {
                            jsonString += ","
                        }
                        isFirst = false
                        jsonString += "\"\(perk.identifier)\""
                    }
                    jsonString += "]}}"
                    
                    if let context = screenContext.context, let data = jsonString.data(using: .utf8), let json = JSON(data: data) {
                        addAppLogEvent(postbox: context.account.postbox, type: "premium.promo_screen_show", data: json)
                    }
                }
            })
            
            if let context = screenContext.context {
                let _ = updatePremiumPromoConfigurationOnce(account: context.account).start()
                
                let stickersKey: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.CloudPremiumStickers)
                self.stickersDisposable = (context.account.postbox.combinedView(keys: [stickersKey])
                |> deliverOnMainQueue).start(next: { [weak self] views in
                    guard let self else {
                        return
                    }
                    if let view = views.views[stickersKey] as? OrderedItemListView {
                        for item in view.items {
                            if let mediaItem = item.contents.get(RecentMediaItem.self) {
                                let file = mediaItem.media._parse()
                                self.preloadDisposableSet.add(freeMediaFileResourceInteractiveFetched(account: context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                                if let effect = file.videoThumbnails.first {
                                    self.preloadDisposableSet.add(freeMediaFileResourceInteractiveFetched(account: context.account, userLocation: .other, fileReference: .standalone(media: file), resource: effect.resource).start())
                                }
                            }
                        }
                    }
                })
                
                self.newPerksDisposable = combineLatest(
                    queue: Queue.mainQueue(),
                    ApplicationSpecificNotice.dismissedBusinessBadge(accountManager: context.sharedContext.accountManager),
                    ApplicationSpecificNotice.dismissedBusinessLinksBadge(accountManager: context.sharedContext.accountManager),
                    ApplicationSpecificNotice.dismissedBusinessIntroBadge(accountManager: context.sharedContext.accountManager),
                    ApplicationSpecificNotice.dismissedBusinessChatbotsBadge(accountManager: context.sharedContext.accountManager)
                ).startStrict(next: { [weak self] dismissedBusinessBadge, dismissedBusinessLinksBadge, dismissedBusinessIntroBadge, dismissedBusinessChatbotsBadge in
                    guard let self else {
                        return
                    }
                    var newPerks: [String] = []
                    if !dismissedBusinessBadge {
                        newPerks.append(PremiumPerk.business.identifier)
                    }
                    if !dismissedBusinessLinksBadge {
                        newPerks.append(PremiumPerk.businessLinks.identifier)
                    }
                    if !dismissedBusinessIntroBadge {
                        newPerks.append(PremiumPerk.businessIntro.identifier)
                    }
                    if !dismissedBusinessChatbotsBadge {
                        newPerks.append(PremiumPerk.businessChatBots.identifier)
                    }
                    self.newPerks = newPerks
                    self.updated()
                })
                
                self.adsEnabledDisposable = (context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.AdsEnabled(id: context.account.peerId))
                |> deliverOnMainQueue).start(next: { [weak self] adsEnabled in
                    guard let self else {
                        return
                    }
                    self.adsEnabled = adsEnabled
                    self.updated()
                })
            }
        }
        
        deinit {
            self.disposable?.dispose()
            self.preloadDisposableSet.dispose()
            self.stickersDisposable?.dispose()
            self.newPerksDisposable?.dispose()
            self.adsEnabledDisposable?.dispose()
        }
        
        private var updatedPeerStatus: PeerEmojiStatus?
        
        private weak var emojiStatusSelectionController: ViewController?
        private var previousEmojiSetupTimestamp: Double?
        func openEmojiSetup(sourceView: UIView, currentFileId: Int64?, color: UIColor?) {
            guard let context = self.screenContext.context else {
                return
            }
            let currentTimestamp = CACurrentMediaTime()
            if let previousTimestamp = self.previousEmojiSetupTimestamp, currentTimestamp < previousTimestamp + 1.0 {
                return
            }
            self.previousEmojiSetupTimestamp = currentTimestamp
            
            self.emojiStatusSelectionController?.dismiss()
            var selectedItems = Set<MediaId>()
            if let currentFileId {
                selectedItems.insert(MediaId(namespace: Namespaces.Media.CloudFile, id: currentFileId))
            }
                                    
            let controller = EmojiStatusSelectionController(
                context: context,
                mode: .statusSelection,
                sourceView: sourceView,
                emojiContent: EmojiPagerContentComponent.emojiInputData(
                    context: context,
                    animationCache: context.animationCache,
                    animationRenderer: context.animationRenderer,
                    isStandalone: false,
                    subject: .status,
                    hasTrending: false,
                    topReactionItems: [],
                    areUnicodeEmojiEnabled: false,
                    areCustomEmojiEnabled: true,
                    chatPeerId: context.account.peerId,
                    selectedItems: selectedItems,
                    topStatusTitle: nil,
                    backgroundIconColor: color
                ),
                currentSelection: currentFileId,
                color: color,
                destinationItemView: { [weak sourceView] in
                    guard let sourceView else {
                        return nil
                    }
                    return sourceView
                }
            )
            self.emojiStatusSelectionController = controller
            self.present(controller)
        }
    }
    
    func makeState() -> State {
        return State(screenContext: self.screenContext, source: self.source, present: self.present)
    }
    
    static var body: Body {
        let overscroll = Child(Rectangle.self)
        let fade = Child(RoundedRectangle.self)
        let text = Child(MultilineTextComponent.self)
        let completedText = Child(MultilineTextComponent.self)
        let linkButton = Child(Button.self)
        let optionsSection = Child(SectionGroupComponent.self)
        let businessSection = Child(ListSectionComponent.self)
        let moreBusinessSection = Child(ListSectionComponent.self)
        let adsSettingsSection = Child(ListSectionComponent.self)
        let perksSection = Child(ListSectionComponent.self)
        let infoBackground = Child(RoundedRectangle.self)
        let infoTitle = Child(MultilineTextComponent.self)
        let infoText = Child(MultilineTextComponent.self)
        let termsText = Child(MultilineTextComponent.self)
        
        return { context in
            let sideInset: CGFloat = 16.0
            
            let scrollEnvironment = context.environment[ScrollChildEnvironment.self].value
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let state = context.state
            state.products = context.component.products
            state.selectedProductId = context.component.selectedProductId
            state.validPurchases = context.component.validPurchases
            state.isPremium = context.component.isPremium
            
            let theme = environment.theme
            let strings = environment.strings
            let presentationData = context.component.screenContext.presentationData
            
            let availableWidth = context.availableSize.width
            let sideInsets = sideInset * 2.0 + environment.safeInsets.left + environment.safeInsets.right
            var size = CGSize(width: context.availableSize.width, height: 0.0)
            
            var topBackgroundColor = theme.list.plainBackgroundColor
            let bottomBackgroundColor = theme.list.blocksBackgroundColor
            if theme.overallDarkAppearance {
                topBackgroundColor = bottomBackgroundColor
            }
        
            let overscroll = overscroll.update(
                component: Rectangle(color: topBackgroundColor),
                availableSize: CGSize(width: context.availableSize.width, height: 1000),
                transition: context.transition
            )
            context.add(overscroll
                .position(CGPoint(x: overscroll.size.width / 2.0, y: -overscroll.size.height / 2.0))
            )
            
            let fade = fade.update(
                component: RoundedRectangle(
                    colors: [
                        topBackgroundColor,
                        bottomBackgroundColor
                    ],
                    cornerRadius: 0.0,
                    gradientDirection: .vertical
                ),
                availableSize: CGSize(width: availableWidth, height: 300),
                transition: context.transition
            )
            context.add(fade
                .position(CGPoint(x: fade.size.width / 2.0, y: fade.size.height / 2.0))
            )
            
            size.height += 183.0 + 10.0 + environment.navigationHeight - 56.0
            
            let textColor = theme.list.itemPrimaryTextColor
            let accentColor = theme.list.itemAccentColor
            let subtitleColor = theme.list.itemSecondaryTextColor
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            
            var link = ""
            let textString: String
            if case .emojiStatus = context.component.source {
                textString = strings.Premium_EmojiStatusText.replacingOccurrences(of: "#", with: "# ")
            } else if case .giftTerms = context.component.source {
                textString = strings.Premium_PersonalDescription
            } else if let _ = context.component.otherPeerName {
                if case let .gift(fromId, _, _, giftCode) = context.component.source, let accountContext = context.component.screenContext.context {
                    if fromId == accountContext.account.peerId {
                        textString = strings.Premium_GiftedDescriptionYou
                    } else {
                        if let giftCode {
                            if let _ = giftCode.usedDate {
                                textString = strings.Premium_Gift_UsedLink_Text
                            } else {
                                link = "https://t.me/giftcode/\(giftCode.slug)"
                                textString = strings.Premium_Gift_Link_Text
                            }
                        } else {
                            textString = strings.Premium_GiftedDescription
                        }
                    }
                } else {
                    textString = strings.Premium_PersonalDescription
                }
            } else if context.component.isPremium == true {
                if case .business = context.component.mode {
                    textString = strings.Business_SubscribedDescription
                } else {
                    if !context.component.justBought, let products = state.products, let current = products.first(where: { $0.isCurrent }), current.months == 1 {
                        textString = strings.Premium_UpgradeDescription
                    } else {
                        textString = strings.Premium_SubscribedDescription
                    }
                }
            } else {
                if case .business = context.component.mode {
                    textString = strings.Business_Description
                } else {
                    textString = strings.Premium_Description
                }
            }
            
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: accentColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            let shareLink = context.component.shareLink
            let textComponent: _ConcreteChildComponent<MultilineTextComponent>
            if context.component.justBought {
                textComponent = completedText
            } else {
                textComponent = text
            }
            let text = textComponent.update(
                component: MultilineTextComponent(
                    text: .markdown(
                        text: textString,
                        attributes: markdownAttributes
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.2),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { _, _ in
                        if !link.isEmpty {
                            shareLink(link)
                        }
                    }
                ),
                environment: {},
                availableSize: CGSize(width: availableWidth - sideInsets - 8.0, height: 240.0),
                transition: .immediate
            )
            context.add(text
                .position(CGPoint(x: size.width / 2.0, y: size.height + text.size.height / 2.0))
                .appear(.default(alpha: true))
                .disappear(.default(alpha: true))
            )
            size.height += text.size.height
            size.height += 21.0
            
            let gradientColors: [UIColor] = [
                UIColor(rgb: 0xef6922),
                UIColor(rgb: 0xe95a2c),
                UIColor(rgb: 0xe74e33),
                UIColor(rgb: 0xe74e33),
                UIColor(rgb: 0xe54937),
                UIColor(rgb: 0xe3433c),
                UIColor(rgb: 0xdb374b),
                UIColor(rgb: 0xcb3e6d),
                UIColor(rgb: 0xbc4395),
                UIColor(rgb: 0xbc4395),
                UIColor(rgb: 0xab4ac4),
                UIColor(rgb: 0xab4ac4),
                UIColor(rgb: 0xa34cd7),
                UIColor(rgb: 0x9b4fed),
                UIColor(rgb: 0x8958ff),
                UIColor(rgb: 0x676bff),
                UIColor(rgb: 0x676bff),
                UIColor(rgb: 0x6172ff),
                UIColor(rgb: 0x5b79ff),
                UIColor(rgb: 0x4492ff),
                UIColor(rgb: 0x429bd5),
                UIColor(rgb: 0x41a6a5),
                UIColor(rgb: 0x3eb26d),
                UIColor(rgb: 0x3dbd4a)
            ]
                        
            let accountContext = context.component.screenContext.context
            let present = context.component.present
            let push = context.component.push
            let selectProduct = context.component.selectProduct
            let buy = context.component.buy
            let updateIsFocused = context.component.updateIsFocused
            
            let layoutOptions = {
                if let products = state.products, products.count > 1, state.isPremium == false || (!context.component.justBought && state.canUpgrade) {
                    var optionsItems: [SectionGroupComponent.Item] = []
                    
                    let shortestOptionPrice: (Int64, NSDecimalNumber)
                    if let product = products.first(where: { $0.id.hasSuffix(".monthly") }) {
                        shortestOptionPrice = (Int64(Float(product.storeProduct.priceCurrencyAndAmount.amount)), product.storeProduct.priceValue)
                    } else {
                        shortestOptionPrice = (1, NSDecimalNumber(decimal: 1))
                    }
                    
                    let currentProductMonths = state.products?.first(where: { $0.isCurrent })?.months ?? 0
                    
                    var i = 0
                    for product in products {
                        let giftTitle: String
                        if product.id.hasSuffix(".monthly") {
                            giftTitle = strings.Premium_Monthly
                        } else if product.id.hasSuffix(".semiannual") {
                            giftTitle = strings.Premium_Semiannual
                        } else {
                            giftTitle = strings.Premium_Annual
                        }
                        
                        let fraction = Float(product.storeProduct.priceCurrencyAndAmount.amount) / Float(product.months) / Float(shortestOptionPrice.0)
                        let discountValue = Int(round((1.0 - fraction) * 20.0) * 5.0)
                        let discount: String
                        if discountValue > 0 {
                            discount = "-\(discountValue)%"
                        } else {
                            discount = ""
                        }
                        
                        let defaultPrice = product.storeProduct.defaultPrice(shortestOptionPrice.1, monthsCount: Int(product.months))
                        
                        var subtitle = ""
                        var accessibilitySubtitle = ""
                        var pricePerMonth = product.price
                        if product.months > 1 {
                            pricePerMonth = product.storeProduct.pricePerMonth(Int(product.months))
                            
                            if discountValue > 0 {
                                subtitle = "**\(defaultPrice)** \(product.price)"
                                accessibilitySubtitle = product.price
                                if product.months == 12 {
                                    subtitle = environment.strings.Premium_PricePerYear(subtitle).string
                                    accessibilitySubtitle = environment.strings.Premium_PricePerYear(accessibilitySubtitle).string
                                }
                            } else {
                                subtitle = product.price
                            }
                        }
                        if product.isCurrent {
                            subtitle = environment.strings.Premium_CurrentPlan
                            accessibilitySubtitle = subtitle
                        }
                        pricePerMonth = environment.strings.Premium_PricePerMonth(pricePerMonth).string
                                                
                        optionsItems.append(
                            SectionGroupComponent.Item(
                                AnyComponentWithIdentity(
                                    id: product.id,
                                    component: AnyComponent(
                                        PremiumOptionComponent(
                                            title: giftTitle,
                                            subtitle: subtitle,
                                            labelPrice: pricePerMonth,
                                            discount: discount,
                                            selected: !product.isCurrent && product.id == state.selectedProductId,
                                            primaryTextColor: textColor,
                                            secondaryTextColor: subtitleColor,
                                            accentColor: environment.theme.list.itemAccentColor,
                                            checkForegroundColor: environment.theme.list.itemCheckColors.foregroundColor,
                                            checkBorderColor: environment.theme.list.itemCheckColors.strokeColor
                                        )
                                    )
                                ),
                                accessibilityLabel: "\(giftTitle). \(accessibilitySubtitle). \(pricePerMonth)",
                                isEnabled: product.months > currentProductMonths,
                                action: {
                                    selectProduct(product.id)
                                }
                            )
                        )
                        i += 1
                    }
                    
                    let optionsSection = optionsSection.update(
                        component: SectionGroupComponent(
                            items: optionsItems,
                            backgroundColor: environment.theme.list.itemBlocksBackgroundColor,
                            selectionColor: environment.theme.list.itemHighlightedBackgroundColor,
                            separatorColor: environment.theme.list.itemBlocksSeparatorColor
                        ),
                        environment: {},
                        availableSize: CGSize(width: availableWidth - sideInsets, height: .greatestFiniteMagnitude),
                        transition: context.transition
                    )
                    context.add(optionsSection
                        .position(CGPoint(x: availableWidth / 2.0, y: size.height + optionsSection.size.height / 2.0))
                        .clipsToBounds(true)
                        .cornerRadius(10.0)
                    )
                    size.height += optionsSection.size.height
                    
                    if case .emojiStatus = context.component.source {
                        size.height -= 18.0
                    } else {
                        size.height += 26.0
                    }
                }
            }
             
            let textSideInset: CGFloat = 16.0
            
            let forceDark = context.component.forceDark
            let layoutPerks = {
                size.height += 8.0
                                
                var i = 0
                var perksItems: [AnyComponentWithIdentity<Empty>] = []
                for perk in state.configuration.perks  {
                    if case .business = context.component.mode, case .business = perk {
                        continue
                    }
                    
                    let isNew = state.newPerks.contains(perk.identifier)
                    let titleComponent = AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: perk.title(strings: strings),
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 0
                    ))
                    
                    let titleCombinedComponent: AnyComponent<Empty>
                    if isNew {
                        titleCombinedComponent = AnyComponent(HStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: titleComponent),
                            AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(BadgeComponent(color: gradientColors[i], text: strings.Premium_New)))
                        ], spacing: 5.0))
                    } else {
                        titleCombinedComponent = AnyComponent(HStack([AnyComponentWithIdentity(id: AnyHashable(0), component: titleComponent)], spacing: 0.0))
                    }
                    
                    perksItems.append(AnyComponentWithIdentity(id: perksItems.count, component: AnyComponent(ListActionItemComponent(
                        theme: environment.theme,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: titleCombinedComponent),
                            AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: perk.subtitle(strings: strings),
                                    font: Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0)),
                                    textColor: environment.theme.list.itemSecondaryTextColor
                                )),
                                maximumNumberOfLines: 0,
                                lineSpacing: 0.18
                            )))
                        ], alignment: .left, spacing: 2.0)),
                        leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(PerkIconComponent(
                            backgroundColor: gradientColors[i],
                            foregroundColor: .white,
                            iconName: perk.iconName
                        ))), false),
                        accessory: accountContext != nil ? .arrow : nil,
                        action: { [weak state] _ in
                            guard let accountContext else {
                                return
                            }
                            var demoSubject: PremiumDemoScreen.Subject
                            switch perk {
                            case .doubleLimits:
                                demoSubject = .doubleLimits
                            case .moreUpload:
                                demoSubject = .moreUpload
                            case .fasterDownload:
                                demoSubject = .fasterDownload
                            case .voiceToText:
                                demoSubject = .voiceToText
                            case .noAds:
                                demoSubject = .noAds
                            case .uniqueReactions:
                                demoSubject = .uniqueReactions
                            case .premiumStickers:
                                demoSubject = .premiumStickers
                            case .advancedChatManagement:
                                demoSubject = .advancedChatManagement
                            case .profileBadge:
                                demoSubject = .profileBadge
                            case .animatedUserpics:
                                demoSubject = .animatedUserpics
                            case .appIcons:
                                demoSubject = .appIcons
                            case .animatedEmoji:
                                demoSubject = .animatedEmoji
                            case .emojiStatus:
                                demoSubject = .emojiStatus
                            case .translation:
                                demoSubject = .translation
                            case .stories:
                                demoSubject = .stories
                            case .colors:
                                demoSubject = .colors
                            case .wallpapers:
                                demoSubject = .wallpapers
                            case .messageTags:
                                demoSubject = .messageTags
                            case .lastSeen:
                                demoSubject = .lastSeen
                            case .messagePrivacy:
                                demoSubject = .messagePrivacy
                            case .messageEffects:
                                demoSubject = .messageEffects
                            case .todo:
                                demoSubject = .todo
                            case .business:
                                demoSubject = .business
                                let _ = ApplicationSpecificNotice.setDismissedBusinessBadge(accountManager: accountContext.sharedContext.accountManager).startStandalone()
                            default:
                                demoSubject = .doubleLimits
                            }

                            let isPremium = state?.isPremium == true
                            var dismissImpl: (() -> Void)?
                            let controller = PremiumLimitsListScreen(context: accountContext, subject: demoSubject, source: .intro(state?.price), order: state?.configuration.perks, buttonText: isPremium ? strings.Common_OK : (state?.isAnnual == true ? strings.Premium_SubscribeForAnnual(state?.price ?? "—").string :  strings.Premium_SubscribeFor(state?.price ?? "–").string), isPremium: isPremium, forceDark: forceDark)
                            controller.action = { [weak state] in
                                dismissImpl?()
                                if state?.isPremium == false {
                                    buy()
                                }
                            }
                            controller.disposed = {
                                updateIsFocused(false)
                            }
                            present(controller)
                            dismissImpl = { [weak controller] in
                                controller?.dismiss(animated: true, completion: nil)
                            }
                            updateIsFocused(true)

                            addAppLogEvent(postbox: accountContext.account.postbox, type: "premium.promo_screen_tap", data: ["item": perk.identifier])
                        },
                        highlighting: accountContext != nil ? .default : .disabled
                    ))))
                    i += 1
                }
                
                let perksSection = perksSection.update(
                    component: ListSectionComponent(
                        theme: environment.theme,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.Premium_WhatsIncluded.uppercased(),
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: nil,
                        items: perksItems
                    ),
                    environment: {},
                    availableSize: CGSize(width: availableWidth - sideInsets, height: .greatestFiniteMagnitude),
                    transition: context.transition
                )
                context.add(perksSection
                    .position(CGPoint(x: availableWidth / 2.0, y: size.height + perksSection.size.height / 2.0))
                    .clipsToBounds(true)
                    .cornerRadius(10.0)
                    .disappear(.default(alpha: true))
                )
                size.height += perksSection.size.height
                
                if case .emojiStatus = context.component.source {
                    if state.isPremium == true {
                        size.height -= 23.0
                    } else {
                        size.height += 23.0
                    }
                } else {
                    size.height += 23.0
                }
            }
            
            let layoutBusinessPerks = {
                size.height += 8.0
                
                let gradientColors: [UIColor] = [
                    UIColor(rgb: 0xef6922),
                    UIColor(rgb: 0xe54937),
                    UIColor(rgb: 0xdb374b),
                    UIColor(rgb: 0xbc4395),
                    UIColor(rgb: 0x9b4fed),
                    UIColor(rgb: 0x8958ff),
                    UIColor(rgb: 0x676bff),
                    UIColor(rgb: 0x007aff)
                ]
                
                var i = 0
                var perksItems: [AnyComponentWithIdentity<Empty>] = []
                for perk in state.configuration.businessPerks  {
                    let isNew = state.newPerks.contains(perk.identifier)
                    let titleComponent = AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: perk.title(strings: strings),
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 0
                    ))
                    
                    let titleCombinedComponent: AnyComponent<Empty>
                    if isNew {
                        titleCombinedComponent = AnyComponent(HStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: titleComponent),
                            AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(BadgeComponent(color: gradientColors[i], text: strings.Premium_New)))
                        ], spacing: 5.0))
                    } else {
                        titleCombinedComponent = AnyComponent(HStack([AnyComponentWithIdentity(id: AnyHashable(0), component: titleComponent)], spacing: 0.0))
                    }
                    
                    perksItems.append(AnyComponentWithIdentity(id: perksItems.count, component: AnyComponent(ListActionItemComponent(
                        theme: environment.theme,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: titleCombinedComponent),
                            AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: perk.subtitle(strings: strings),
                                    font: Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0)),
                                    textColor: environment.theme.list.itemSecondaryTextColor
                                )),
                                maximumNumberOfLines: 0,
                                lineSpacing: 0.18
                            )))
                        ], alignment: .left, spacing: 2.0)),
                        leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(PerkIconComponent(
                            backgroundColor: gradientColors[min(i, gradientColors.count - 1)],
                            foregroundColor: .white,
                            iconName: perk.iconName
                        ))), false),
                        action: { [weak state] _ in
                            guard let accountContext else {
                                return
                            }
                            
                            let isPremium = state?.isPremium == true
                            if isPremium {
                                switch perk {
                                case .businessLocation:
                                    let _ = (accountContext.engine.data.get(
                                        TelegramEngine.EngineData.Item.Peer.BusinessLocation(id: accountContext.account.peerId)
                                    )
                                    |> deliverOnMainQueue).start(next: { [weak accountContext] businessLocation in
                                        guard let accountContext else {
                                            return
                                        }
                                        push(accountContext.sharedContext.makeBusinessLocationSetupScreen(context: accountContext, initialValue: businessLocation, completion: { _ in }))
                                    })
                                case .businessHours:
                                    let _ = (accountContext.engine.data.get(
                                        TelegramEngine.EngineData.Item.Peer.BusinessHours(id: accountContext.account.peerId)
                                    )
                                    |> deliverOnMainQueue).start(next: { [weak accountContext] businessHours in
                                        guard let accountContext else {
                                            return
                                        }
                                        push(accountContext.sharedContext.makeBusinessHoursSetupScreen(context: accountContext, initialValue: businessHours, completion: { _ in }))
                                    })
                                case .businessQuickReplies:
                                    let _ = (accountContext.sharedContext.makeQuickReplySetupScreenInitialData(context: accountContext)
                                    |> take(1)
                                    |> deliverOnMainQueue).start(next: { [weak accountContext] initialData in
                                        guard let accountContext else {
                                            return
                                        }
                                        push(accountContext.sharedContext.makeQuickReplySetupScreen(context: accountContext, initialData: initialData))
                                    })
                                case .businessGreetingMessage:
                                    let _ = (accountContext.sharedContext.makeAutomaticBusinessMessageSetupScreenInitialData(context: accountContext)
                                    |> take(1)
                                    |> deliverOnMainQueue).start(next: { [weak accountContext] initialData in
                                        guard let accountContext else {
                                            return
                                        }
                                        push(accountContext.sharedContext.makeAutomaticBusinessMessageSetupScreen(context: accountContext, initialData: initialData, isAwayMode: false))
                                    })
                                case .businessAwayMessage:
                                    let _ = (accountContext.sharedContext.makeAutomaticBusinessMessageSetupScreenInitialData(context: accountContext)
                                    |> take(1)
                                    |> deliverOnMainQueue).start(next: { [weak accountContext] initialData in
                                        guard let accountContext else {
                                            return
                                        }
                                        push(accountContext.sharedContext.makeAutomaticBusinessMessageSetupScreen(context: accountContext, initialData: initialData, isAwayMode: true))
                                    })
                                case .businessChatBots:
                                    let _ = (accountContext.sharedContext.makeChatbotSetupScreenInitialData(context: accountContext)
                                    |> take(1)
                                    |> deliverOnMainQueue).start(next: { [weak accountContext] initialData in
                                        guard let accountContext else {
                                            return
                                        }
                                        push(accountContext.sharedContext.makeChatbotSetupScreen(context: accountContext, initialData: initialData))
                                    })
                                    let _ = ApplicationSpecificNotice.setDismissedBusinessChatbotsBadge(accountManager: accountContext.sharedContext.accountManager).startStandalone()
                                case .businessIntro:
                                    let _ = (accountContext.sharedContext.makeBusinessIntroSetupScreenInitialData(context: accountContext)
                                    |> take(1)
                                    |> deliverOnMainQueue).start(next: { [weak accountContext] initialData in
                                        guard let accountContext else {
                                            return
                                        }
                                        push(accountContext.sharedContext.makeBusinessIntroSetupScreen(context: accountContext, initialData: initialData))
                                    })
                                    let _ = ApplicationSpecificNotice.setDismissedBusinessIntroBadge(accountManager: accountContext.sharedContext.accountManager).startStandalone()
                                case .businessLinks:
                                    let _ = (accountContext.sharedContext.makeBusinessLinksSetupScreenInitialData(context: accountContext)
                                    |> take(1)
                                    |> deliverOnMainQueue).start(next: { [weak accountContext] initialData in
                                        guard let accountContext else {
                                            return
                                        }
                                        push(accountContext.sharedContext.makeBusinessLinksSetupScreen(context: accountContext, initialData: initialData))
                                    })
                                    let _ = ApplicationSpecificNotice.setDismissedBusinessLinksBadge(accountManager: accountContext.sharedContext.accountManager).startStandalone()
                                default:
                                    fatalError()
                                }
                            } else {
                                var demoSubject: PremiumDemoScreen.Subject
                                switch perk {
                                case .businessLocation:
                                    demoSubject = .businessLocation
                                case .businessHours:
                                    demoSubject = .businessHours
                                case .businessQuickReplies:
                                    demoSubject = .businessQuickReplies
                                case .businessGreetingMessage:
                                    demoSubject = .businessGreetingMessage
                                case .businessAwayMessage:
                                    demoSubject = .businessAwayMessage
                                case .businessChatBots:
                                    demoSubject = .businessChatBots
                                    let _ = ApplicationSpecificNotice.setDismissedBusinessChatbotsBadge(accountManager: accountContext.sharedContext.accountManager).startStandalone()
                                case .businessIntro:
                                    demoSubject = .businessIntro
                                    let _ = ApplicationSpecificNotice.setDismissedBusinessIntroBadge(accountManager: accountContext.sharedContext.accountManager).startStandalone()
                                case .businessLinks:
                                    demoSubject = .businessLinks
                                    let _ = ApplicationSpecificNotice.setDismissedBusinessLinksBadge(accountManager: accountContext.sharedContext.accountManager).startStandalone()
                                default:
                                    fatalError()
                                }
                                var dismissImpl: (() -> Void)?
                                let controller = PremiumLimitsListScreen(context: accountContext, subject: demoSubject, source: .intro(state?.price), order: state?.configuration.businessPerks, buttonText: isPremium ? strings.Common_OK : (state?.isAnnual == true ? strings.Premium_SubscribeForAnnual(state?.price ?? "—").string :  strings.Premium_SubscribeFor(state?.price ?? "–").string), isPremium: isPremium, forceDark: forceDark)
                                controller.action = { [weak state] in
                                    dismissImpl?()
                                    if state?.isPremium == false {
                                        buy()
                                    }
                                }
                                controller.disposed = {
                                    updateIsFocused(false)
                                }
                                present(controller)
                                dismissImpl = { [weak controller] in
                                    controller?.dismiss(animated: true, completion: nil)
                                }
                                updateIsFocused(true)
                            }
                        }
                    ))))
                    i += 1
                }
                
                let businessSection = businessSection.update(
                    component: ListSectionComponent(
                        theme: environment.theme,
                        header: nil,
                        footer: nil,
                        items: perksItems
                    ),
                    environment: {},
                    availableSize: CGSize(width: availableWidth - sideInsets, height: .greatestFiniteMagnitude),
                    transition: context.transition
                )
                context.add(businessSection
                    .position(CGPoint(x: availableWidth / 2.0, y: size.height + businessSection.size.height / 2.0))
                    .clipsToBounds(true)
                    .cornerRadius(10.0)
                )
                size.height += businessSection.size.height
                size.height += 23.0
            }
            
            let layoutMoreBusinessPerks = {
                size.height += 8.0
    
                let status = state.peer?.emojiStatus
                
                let accentColor = environment.theme.list.itemAccentColor
                var perksItems: [AnyComponentWithIdentity<Empty>] = []
                if let accountContext = context.component.screenContext.context {
                    perksItems.append(AnyComponentWithIdentity(id: perksItems.count, component: AnyComponent(ListActionItemComponent(
                        theme: environment.theme,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: strings.Business_SetEmojiStatus,
                                    font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                    textColor: environment.theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 0
                            ))),
                            AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: strings.Business_SetEmojiStatusInfo,
                                    font: Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0)),
                                    textColor: environment.theme.list.itemSecondaryTextColor
                                )),
                                maximumNumberOfLines: 0,
                                lineSpacing: 0.18
                            )))
                        ], alignment: .left, spacing: 2.0)),
                        leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(PerkIconComponent(
                            backgroundColor: UIColor(rgb: 0x676bff),
                            foregroundColor: .white,
                            iconName: "Premium/BusinessPerk/Status"
                        ))), false),
                        icon: ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(EmojiActionIconComponent(
                            context: accountContext,
                            color: accentColor,
                            fileId: status?.fileId,
                            file: nil
                        )))),
                        accessory: nil,
                        action: { [weak state] view in
                            guard let view = view as? ListActionItemComponent.View, let iconView = view.iconView else {
                                return
                            }
                            state?.openEmojiSetup(sourceView: iconView, currentFileId: nil, color: accentColor)
                        }
                    ))))
                }
                
                perksItems.append(AnyComponentWithIdentity(id: perksItems.count, component: AnyComponent(ListActionItemComponent(
                    theme: environment.theme,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.Business_TagYourChats,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 0
                        ))),
                        AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.Business_TagYourChatsInfo,
                                font: Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0)),
                                textColor: environment.theme.list.itemSecondaryTextColor
                            )),
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.18
                        )))
                    ], alignment: .left, spacing: 2.0)),
                    leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(PerkIconComponent(
                        backgroundColor: UIColor(rgb: 0x4492ff),
                        foregroundColor: .white,
                        iconName: "Premium/BusinessPerk/Tag"
                    ))), false),
                    action: { _ in
                        guard let accountContext else {
                            return
                        }
                        push(accountContext.sharedContext.makeFilterSettingsController(context: accountContext, modal: false, scrollToTags: true, dismissed: nil))
                    }
                ))))
                
                perksItems.append(AnyComponentWithIdentity(id: perksItems.count, component: AnyComponent(ListActionItemComponent(
                    theme: environment.theme,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.Business_AddPost,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 0
                        ))),
                        AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.Business_AddPostInfo,
                                font: Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0)),
                                textColor: environment.theme.list.itemSecondaryTextColor
                            )),
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.18
                        )))
                    ], alignment: .left, spacing: 2.0)),
                    leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(PerkIconComponent(
                        backgroundColor: UIColor(rgb: 0x41a6a5),
                        foregroundColor: .white,
                        iconName: "Premium/Perk/Stories"
                    ))), false),
                    action: {  _ in
                        guard let accountContext else {
                            return
                        }
                        push(accountContext.sharedContext.makeMyStoriesController(context: accountContext, isArchive: false))
                    }
                ))))
                
                let moreBusinessSection = moreBusinessSection.update(
                    component: ListSectionComponent(
                        theme: environment.theme,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.Business_MoreFeaturesTitle.uppercased(),
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.Business_MoreFeaturesInfo,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: perksItems
                    ),
                    environment: {},
                    availableSize: CGSize(width: availableWidth - sideInsets, height: .greatestFiniteMagnitude),
                    transition: context.transition
                )
                context.add(moreBusinessSection
                    .position(CGPoint(x: availableWidth / 2.0, y: size.height + moreBusinessSection.size.height / 2.0))
                    .clipsToBounds(true)
                    .cornerRadius(10.0)
                )
                size.height += moreBusinessSection.size.height
                size.height += 23.0
            }
            
            let termsFont = Font.regular(13.0)
            let boldTermsFont = Font.semibold(13.0)
            let italicTermsFont = Font.italic(13.0)
            let boldItalicTermsFont = Font.semiboldItalic(13.0)
            let monospaceTermsFont = Font.monospace(13.0)
            let termsTextColor = environment.theme.list.freeTextColor
            let termsMarkdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: termsFont, textColor: termsTextColor), bold: MarkdownAttributeSet(font: termsFont, textColor: termsTextColor), link: MarkdownAttributeSet(font: termsFont, textColor: environment.theme.list.itemAccentColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            let layoutAdsSettings = {
                size.height += 8.0
                
                var adsSettingsItems: [AnyComponentWithIdentity<Empty>] = []
                adsSettingsItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                    theme: environment.theme,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.Business_DontHideAds,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))),
                    ], alignment: .left, spacing: 2.0)),
                    accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: state.adsEnabled, action: { [weak state] value in
                        guard let accountContext else {
                            return
                        }
                        let _ = accountContext.engine.accountData.updateAdMessagesEnabled(enabled: value).startStandalone()
                        state?.updated(transition: .immediate)
                    })),
                    action: nil
                ))))
                
                let adsInfoString = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(environment.strings.Business_AdsInfo, attributes: termsMarkdownAttributes, textAlignment: .natural
                ))
                if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== theme {
                    state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Contact List/SubtitleArrow"), color: environment.theme.list.itemAccentColor)!, theme)
                }
                if let range = adsInfoString.string.range(of: ">"), let chevronImage = state.cachedChevronImage?.0 {
                    adsInfoString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: adsInfoString.string))
                }
                let controller = environment.controller
                let adsInfoTapActionImpl: ([NSAttributedString.Key: Any]) -> Void = { _ in
                    if let controller = controller() as? PremiumIntroScreen, let context = controller.context {
                        context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: environment.strings.Business_AdsInfo_URL, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
                    }
                }
                let adsSettingsSection = adsSettingsSection.update(
                    component: ListSectionComponent(
                        theme: environment.theme,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.Business_AdsTitle.uppercased(),
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(adsInfoString),
                            maximumNumberOfLines: 0,
                            highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.1),
                            highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                            highlightAction: { attributes in
                                if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                    return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                                } else {
                                    return nil
                                }
                            },
                            tapAction: { attributes, _ in
                                adsInfoTapActionImpl(attributes)
                            }
                        )),
                        items: adsSettingsItems
                    ),
                    environment: {},
                    availableSize: CGSize(width: availableWidth - sideInsets, height: .greatestFiniteMagnitude),
                    transition: context.transition
                )
                context.add(adsSettingsSection
                    .position(CGPoint(x: availableWidth / 2.0, y: size.height + adsSettingsSection.size.height / 2.0))
                    .clipsToBounds(true)
                    .cornerRadius(10.0)
                )
                size.height += adsSettingsSection.size.height
                size.height += 23.0
            }
            
            let copyLink = context.component.copyLink
            if case .emojiStatus = context.component.source {
                layoutPerks()
                layoutOptions()
            } else if case let .gift(fromPeerId, _, _, giftCode) = context.component.source {
                if let giftCode, let accountContext = context.component.screenContext.context,  fromPeerId != accountContext.account.peerId, !context.component.justBought {
                    let link = "https://t.me/giftcode/\(giftCode.slug)"
                    let linkButton = linkButton.update(
                        component: Button(
                            content: AnyComponent(
                                GiftLinkButtonContentComponent(theme: environment.theme, text: link, isSeparateSection: true)
                            ),
                            action: {
                                copyLink(link)
                            }
                        ),
                        availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                        transition: .immediate
                    )
                    context.add(linkButton
                        .position(CGPoint(x: availableWidth / 2.0, y: size.height + linkButton.size.height / 2.0))
                        .disappear(.default(alpha: true))
                    )
                    size.height += linkButton.size.height
                    size.height += 17.0
                }
                
                layoutPerks()
            } else {
                layoutOptions()
                
                if case .business = context.component.mode {
                    layoutBusinessPerks()
                    if context.component.isPremium == true {
                        layoutMoreBusinessPerks()
                        layoutAdsSettings()
                    }
                } else {
                    layoutPerks()
                
                    let textPadding: CGFloat = 13.0
                    
                    let infoTitle = infoTitle.update(
                        component: MultilineTextComponent(
                            text: .plain(
                                NSAttributedString(string: strings.Premium_AboutTitle.uppercased(), font: Font.regular(14.0), textColor: environment.theme.list.freeTextColor)
                            ),
                            horizontalAlignment: .natural,
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.2
                        ),
                        environment: {},
                        availableSize: CGSize(width: availableWidth - sideInsets, height: .greatestFiniteMagnitude),
                        transition: context.transition
                    )
                    context.add(infoTitle
                        .position(CGPoint(x: sideInset + environment.safeInsets.left + textSideInset + infoTitle.size.width / 2.0, y: size.height + infoTitle.size.height / 2.0))
                    )
                    size.height += infoTitle.size.height
                    size.height += 3.0
                                
                    let infoText = infoText.update(
                        component: MultilineTextComponent(
                            text: .markdown(
                                text: strings.Premium_AboutText,
                                attributes: markdownAttributes
                            ),
                            horizontalAlignment: .natural,
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.2
                        ),
                        environment: {},
                        availableSize: CGSize(width: availableWidth - sideInsets - textSideInset * 2.0, height: .greatestFiniteMagnitude),
                        transition: context.transition
                    )
                    
                    let infoBackground = infoBackground.update(
                        component: RoundedRectangle(
                            color: environment.theme.list.itemBlocksBackgroundColor,
                            cornerRadius: 10.0
                        ),
                        environment: {},
                        availableSize: CGSize(width: availableWidth - sideInsets, height: infoText.size.height + textPadding * 2.0),
                        transition: context.transition
                    )
                    context.add(infoBackground
                        .position(CGPoint(x: size.width / 2.0, y: size.height + infoBackground.size.height / 2.0))
                    )
                    context.add(infoText
                        .position(CGPoint(x: sideInset + environment.safeInsets.left + textSideInset + infoText.size.width / 2.0, y: size.height + textPadding + infoText.size.height / 2.0))
                    )
                    size.height += infoBackground.size.height
                    size.height += 6.0
                                                   
                    var isGiftView = false
                    if case let .gift(fromId, _, _, _) = context.component.source {
                        if let accountContext = context.component.screenContext.context, fromId == accountContext.account.peerId {
                            isGiftView = true
                        }
                    }
                    
                    let termsString: MultilineTextComponent.TextContent
                    if isGiftView {
                        termsString = .plain(NSAttributedString())
                    } else if let promoConfiguration = context.component.promoConfiguration {
                        let attributedString = stringWithAppliedEntities(promoConfiguration.status, entities: promoConfiguration.statusEntities, baseColor: termsTextColor, linkColor: environment.theme.list.itemAccentColor, baseFont: termsFont, linkFont: termsFont, boldFont: boldTermsFont, italicFont: italicTermsFont, boldItalicFont: boldItalicTermsFont, fixedFont: monospaceTermsFont, blockQuoteFont: termsFont, message: nil)
                        termsString = .plain(attributedString)
                    } else {
                        termsString = .markdown(
                            text: strings.Premium_Terms,
                            attributes: termsMarkdownAttributes
                        )
                    }
                    
                    let controller = environment.controller
                    let termsTapActionImpl: ([NSAttributedString.Key: Any]) -> Void = { attributes in
                        if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String, let controller = controller() as? PremiumIntroScreen, let context = controller.context, let navigationController = controller.navigationController as? NavigationController {
                            if url.hasPrefix("https://apps.apple.com/account/subscriptions") {
                                context.sharedContext.applicationBindings.openSubscriptions()
                            } else if url.hasPrefix("https://") || url.hasPrefix("tg://") {
                                context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
                            } else {
                                let signal: Signal<ResolvedUrl, NoError>?
                                switch url {
                                    case "terms":
                                        signal = cachedTermsPage(context: context)
                                    case "privacy":
                                        signal = cachedPrivacyPage(context: context)
                                    default:
                                        signal = nil
                                }
                                if let signal = signal {
                                    let _ = (signal
                                    |> deliverOnMainQueue).start(next: { resolvedUrl in
                                        context.sharedContext.openResolvedUrl(resolvedUrl, context: context, urlContext: .generic, navigationController: navigationController, forceExternal: false, forceUpdate: false, openPeer: { peer, navigation in
                                        }, sendFile: nil, sendSticker: nil, sendEmoji: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { [weak controller] c, arguments in
                                            controller?.push(c)
                                        }, dismissInput: {}, contentContext: nil, progress: nil, completion: nil)
                                    })
                                }
                            }
                        }
                    }
                    
                    let termsText = termsText.update(
                        component: MultilineTextComponent(
                            text: termsString,
                            horizontalAlignment: .natural,
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.0,
                            highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.2),
                            highlightAction: { attributes in
                                if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                    return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                                } else {
                                    return nil
                                }
                            },
                            tapAction: { attributes, _ in
                                termsTapActionImpl(attributes)
                            }
                        ),
                        environment: {},
                        availableSize: CGSize(width: availableWidth - sideInsets - textSideInset * 2.0, height: .greatestFiniteMagnitude),
                        transition: context.transition
                    )
                    context.add(termsText
                        .position(CGPoint(x: sideInset + environment.safeInsets.left + textSideInset + termsText.size.width / 2.0, y: size.height + termsText.size.height / 2.0))
                    )
                    size.height += termsText.size.height
                    size.height += 10.0
                }
            }
            
            size.height += scrollEnvironment.insets.bottom
            if case .business = context.component.mode, state.isPremium == false {
                size.height += 123.0
            }
            
            if context.component.source != .settings {
                size.height += 44.0
            }
            
            return size
        }
    }
}

private final class PremiumIntroScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let screenContext: PremiumIntroScreen.ScreenContext
    let mode: PremiumIntroScreen.Mode
    let source: PremiumSource
    let forceDark: Bool
    let forceHasPremium: Bool
    let updateInProgress: (Bool) -> Void
    let present: (ViewController) -> Void
    let push: (ViewController) -> Void
    let completion: () -> Void
    let copyLink: (String) -> Void
    let shareLink: (String) -> Void
    
    init(screenContext: PremiumIntroScreen.ScreenContext, mode: PremiumIntroScreen.Mode, source: PremiumSource, forceDark: Bool, forceHasPremium: Bool, updateInProgress: @escaping (Bool) -> Void, present: @escaping (ViewController) -> Void, push: @escaping (ViewController) -> Void, completion: @escaping () -> Void, copyLink: @escaping (String) -> Void, shareLink: @escaping (String) -> Void) {
        self.screenContext = screenContext
        self.mode = mode
        self.source = source
        self.forceDark = forceDark
        self.forceHasPremium = forceHasPremium
        self.updateInProgress = updateInProgress
        self.present = present
        self.push = push
        self.completion = completion
        self.copyLink = copyLink
        self.shareLink = shareLink
    }
        
    static func ==(lhs: PremiumIntroScreenComponent, rhs: PremiumIntroScreenComponent) -> Bool {
        if lhs.mode != rhs.mode {
            return false
        }
        if lhs.source != rhs.source {
            return false
        }
        if lhs.forceDark != rhs.forceDark {
            return false
        }
        if lhs.forceHasPremium != rhs.forceHasPremium {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let screenContext: PremiumIntroScreen.ScreenContext
        private let source: PremiumSource
        private let updateInProgress: (Bool) -> Void
        private let present: (ViewController) -> Void
        private let completion: () -> Void
        
        var topContentOffset: CGFloat?
        var bottomContentOffset: CGFloat?
        
        var hasIdleAnimations = true
        
        var inProgress = false
        
        private(set) var promoConfiguration: PremiumPromoConfiguration?
        
        private(set) var products: [PremiumProduct]?
        private(set) var selectedProductId: String?
        fileprivate var validPurchases: [InAppPurchaseManager.ReceiptPurchase] = []
        
        var isPremium: Bool?
        var otherPeerName: String?
        var justBought = false
                
        var emojiFile: TelegramMediaFile?
        var emojiPackTitle: String?
        private var emojiFileDisposable: Disposable?
        
        
        private var disposable: Disposable?
        private var paymentDisposable = MetaDisposable()
        private var activationDisposable = MetaDisposable()
        private var preloadDisposableSet = DisposableSet()
        
        var price: String? {
            return self.products?.first(where: { $0.id == self.selectedProductId })?.price
        }
        
        var isAnnual: Bool {
            return self.products?.first(where: { $0.id == self.selectedProductId })?.id.hasSuffix(".annual") ?? false
        }
        
        var canUpgrade: Bool {
            if let products = self.products, let current = products.first(where: { $0.isCurrent }), let transactionId = current.transactionId {
                if self.validPurchases.contains(where: { $0.transactionId == transactionId }) {
                    return products.first(where: { $0.months > current.months }) != nil
                } else {
                    return false
                }
            } else {
                return false
            }
        }
        
        init(screenContext: PremiumIntroScreen.ScreenContext, source: PremiumSource, forceHasPremium: Bool, updateInProgress: @escaping (Bool) -> Void, present: @escaping (ViewController) -> Void, completion: @escaping () -> Void) {
            self.screenContext = screenContext
            self.source = source
            self.updateInProgress = updateInProgress
            self.present = present
            self.completion = completion
                        
            super.init()
            
            self.validPurchases = screenContext.inAppPurchaseManager?.getReceiptPurchases() ?? []
            
            let availableProducts: Signal<[InAppPurchaseManager.Product], NoError>
            if let inAppPurchaseManager = screenContext.inAppPurchaseManager {
                availableProducts = inAppPurchaseManager.availableProducts
            } else {
                availableProducts = .single([])
            }
            
            let otherPeerName: Signal<String?, NoError>
            if let context = screenContext.context {
                if case let .gift(fromPeerId, toPeerId, _, _) = source {
                    let otherPeerId = fromPeerId != context.account.peerId ? fromPeerId : toPeerId
                    otherPeerName = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: otherPeerId))
                    |> map { peer -> String? in
                        return peer?.compactDisplayTitle
                    }
                } else if case let .profile(peerId) = source {
                    otherPeerName = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                    |> map { peer -> String? in
                        return peer?.compactDisplayTitle
                    }
                } else if case let .emojiStatus(peerId, _, _, _) = source {
                    otherPeerName = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                    |> map { peer -> String? in
                        return peer?.compactDisplayTitle
                    }
                } else {
                    otherPeerName = .single(nil)
                }
            } else {
                otherPeerName = .single(nil)
            }
            
            if forceHasPremium {
                self.isPremium = true
            }
            
            let isPremium: Signal<Bool, NoError>
            let promoConfiguration: Signal<PremiumPromoConfiguration, NoError>
            switch screenContext {
            case let .accountContext(context):
                isPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                |> map { peer -> Bool in
                    return peer?.isPremium ?? false
                }
                promoConfiguration = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.PremiumPromo())
            case .sharedContext:
                isPremium = .single(false)
                promoConfiguration = .single(PremiumPromoConfiguration.defaultValue)
            }
            
            self.disposable = combineLatest(
                queue: Queue.mainQueue(),
                availableProducts,
                promoConfiguration,
                isPremium,
                otherPeerName
            ).start(next: { [weak self] availableProducts, promoConfiguration, isPremium, otherPeerName in
                if let strongSelf = self {
                    strongSelf.promoConfiguration = promoConfiguration
                    
                    let hadProducts = strongSelf.products != nil
                    var products: [PremiumProduct] = []
                    for option in promoConfiguration.premiumProductOptions {
                        if let product = availableProducts.first(where: { $0.id == option.storeProductId }), product.isSubscription {
                            products.append(PremiumProduct(option: option, storeProduct: product))
                        }
                    }
                    
                    strongSelf.products = products
                    strongSelf.isPremium = forceHasPremium || isPremium
                    strongSelf.otherPeerName = otherPeerName
                    
                    if !hadProducts {
                        strongSelf.selectedProductId = strongSelf.products?.first?.id
                        
                        if let context = screenContext.context {
                            for (_, video) in promoConfiguration.videos {
                                strongSelf.preloadDisposableSet.add(preloadVideoResource(postbox: context.account.postbox, userLocation: .other, userContentType: .video, resourceReference: .standalone(resource: video.resource), duration: 3.0).start())
                            }
                        }
                    }
                    
                    strongSelf.updated(transition: .immediate)
                }
            })
            
            if case let .emojiStatus(_, emojiFileId, emojiFile, maybeEmojiPack) = source, let emojiPack = maybeEmojiPack, case let .result(info, _, _) = emojiPack {
                if let emojiFile = emojiFile {
                    self.emojiFile = emojiFile
                    self.emojiPackTitle = info.title
                    self.updated(transition: .immediate)
                } else {
                    if let context = screenContext.context {
                        self.emojiFileDisposable = (context.engine.stickers.resolveInlineStickers(fileIds: [emojiFileId])
                        |> deliverOnMainQueue).start(next: { [weak self] result in
                            guard let self else {
                                return
                            }
                            self.emojiFile = result[emojiFileId]
                            self.updated(transition: .immediate)
                        })
                    }
                }
            }
        }
        
        deinit {
            self.disposable?.dispose()
            self.paymentDisposable.dispose()
            self.activationDisposable.dispose()
            self.emojiFileDisposable?.dispose()
            self.preloadDisposableSet.dispose()
        }
        
        func buy() {
            guard !self.inProgress else {
                return
            }
            
            let presentationData = self.screenContext.presentationData
            
            if case let .gift(_, _, _, giftCode) = self.source, let giftCode, giftCode.usedDate == nil {
                guard let context = self.screenContext.context else {
                    return
                }
                self.inProgress = true
                self.updateInProgress(true)
                self.updated(transition: .immediate)
                
                self.paymentDisposable.set((context.engine.payments.applyPremiumGiftCode(slug: giftCode.slug)
                |> deliverOnMainQueue).start(error: { [weak self] error in
                    guard let self else {
                        return
                    }
                    
                    self.inProgress = false
                    self.updateInProgress(false)
                    self.updated(transition: .immediate)
                    
                    if case let .waitForExpiration(date) = error {
                        let dateText = stringForMediumDate(timestamp: date, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
                        self.present(UndoOverlayController(presentationData: presentationData, content: .info(title: presentationData.strings.Premium_Gift_ApplyLink_AlreadyHasPremium_Title, text: presentationData.strings.Premium_Gift_ApplyLink_AlreadyHasPremium_Text(dateText).string, timeout: nil, customUndoText: nil), elevatedLayout: true, position: .bottom, action: { _ in return true }))
                    }
                }, completed: { [weak self] in
                    guard let self else {
                        return
                    }
                    
                    self.inProgress = false
                    self.justBought = true
                    self.updateInProgress(false)
                    self.updated(transition: .easeInOut(duration: 0.25))
                    self.completion()
                }))
                return
            }
            
            guard let inAppPurchaseManager = self.screenContext.inAppPurchaseManager,
                  let premiumProduct = self.products?.first(where: { $0.id == self.selectedProductId }) else {
                return
            }
            
            let isUpgrade = self.products?.first(where: { $0.isCurrent }) != nil
            
            var hasActiveSubsciption = false
            if let context = self.screenContext.context, let data = context.currentAppConfiguration.with({ $0 }).data, let _ = data["ios_killswitch_disable_receipt_check"] {
                
            } else if !self.validPurchases.isEmpty && !isUpgrade {
                let now = Date()
                for purchase in self.validPurchases.reversed() {
                    if (purchase.productId.hasSuffix(".monthly") || purchase.productId.hasSuffix(".annual")) && purchase.expirationDate > now {
                        hasActiveSubsciption = true
                    }
                }
            }
            
            if hasActiveSubsciption {
                let errorText = presentationData.strings.Premium_Purchase_OnlyOneSubscriptionAllowed
                let alertController = textAlertController(sharedContext: self.screenContext.sharedContext, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                self.present(alertController)
                return
            }
                        
            if let context = self.screenContext.context {
                addAppLogEvent(postbox: context.account.postbox, type: "premium.promo_screen_accept")
            }
            
            self.inProgress = true
            self.updateInProgress(true)
            self.updated(transition: .immediate)
            
            let purpose: AppStoreTransactionPurpose = isUpgrade ? .upgrade : .subscription
            
            let canPurchasePremium: Signal<Bool, NoError>
            switch self.screenContext {
            case let .accountContext(context):
                canPurchasePremium = context.engine.payments.canPurchasePremium(purpose: purpose)
            case let .sharedContext(_, engine, _):
                canPurchasePremium = engine.payments.canPurchasePremium(purpose: purpose)
            }
            let _ = (canPurchasePremium
            |> deliverOnMainQueue).start(next: { [weak self] available in
                guard let self else {
                    return
                }
                if available {
                    self.paymentDisposable.set((inAppPurchaseManager.buyProduct(premiumProduct.storeProduct, purpose: purpose)
                    |> deliverOnMainQueue).start(next: { [weak self] status in
                        if let self, case .purchased = status {
                            let activation: Signal<Never, AssignAppStoreTransactionError>
                            if let context = self.screenContext.context {
                                activation = context.account.postbox.peerView(id: context.account.peerId)
                                |> castError(AssignAppStoreTransactionError.self)
                                |> take(until: { view in
                                    if let peer = view.peers[view.peerId], peer.isPremium {
                                        return SignalTakeAction(passthrough: false, complete: true)
                                    } else {
                                        return SignalTakeAction(passthrough: false, complete: false)
                                    }
                                })
                                |> mapToSignal { _ -> Signal<Never, AssignAppStoreTransactionError> in
                                    return .never()
                                }
                                |> timeout(15.0, queue: Queue.mainQueue(), alternate: .fail(.timeout))
                            } else {
                                activation = .complete()
                            }
                            
                            self.activationDisposable.set((activation
                            |> deliverOnMainQueue).start(error: { [weak self] _ in
                                if let self {
                                    self.inProgress = false
                                    self.updateInProgress(false)
                                    
                                    self.updated(transition: .immediate)
                                    
                                    if let context = self.screenContext.context {
                                        addAppLogEvent(postbox: context.account.postbox, type: "premium.promo_screen_fail")
                                    }
                                    
                                    let errorText = presentationData.strings.Premium_Purchase_ErrorUnknown
                                    let alertController = textAlertController(sharedContext: self.screenContext.sharedContext, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                                    self.present(alertController)
                                }
                            }, completed: { [weak self] in
                                guard let self else {
                                    return
                                }
                                if let context = self.screenContext.context {
                                    let _ = updatePremiumPromoConfigurationOnce(account: context.account).start()
                                }
                                self.inProgress = false
                                self.updateInProgress(false)
                                
                                self.isPremium = true
                                self.justBought = true
                                                                        
                                self.updated(transition: .easeInOut(duration: 0.25))
                                self.completion()
                            }))
                        }
                    }, error: { [weak self] error in
                        guard let self else {
                            return
                        }
                        self.inProgress = false
                        self.updateInProgress(false)
                        self.updated(transition: .immediate)
                        
                        var errorText: String?
                        switch error {
                        case .generic:
                            errorText = presentationData.strings.Premium_Purchase_ErrorUnknown
                        case .network:
                            errorText = presentationData.strings.Premium_Purchase_ErrorNetwork
                        case .notAllowed:
                            errorText = presentationData.strings.Premium_Purchase_ErrorNotAllowed
                        case .cantMakePayments:
                            errorText = presentationData.strings.Premium_Purchase_ErrorCantMakePayments
                        case .assignFailed:
                            errorText = presentationData.strings.Premium_Purchase_ErrorUnknown
                        case .tryLater:
                            errorText = presentationData.strings.Premium_Purchase_ErrorUnknown
                        case .cancelled:
                            break
                        }
                        
                        if let errorText = errorText {
                            if let context = self.screenContext.context {
                                addAppLogEvent(postbox: context.account.postbox, type: "premium.promo_screen_fail")
                            }
                            
                            let alertController = textAlertController(sharedContext: self.screenContext.sharedContext, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                            self.present(alertController)
                        }
                    }))
                } else {
                    self.inProgress = false
                    self.updateInProgress(false)
                    self.updated(transition: .immediate)
                }
            })
        }
        
        func updateIsFocused(_ isFocused: Bool) {
            self.hasIdleAnimations = !isFocused
            self.updated(transition: .immediate)
        }
        
        func selectProduct(_ productId: String) {
            self.selectedProductId = productId
            self.updated(transition: .immediate)
        }
    }
    
    func makeState() -> State {
        return State(screenContext: self.screenContext, source: self.source, forceHasPremium: self.forceHasPremium, updateInProgress: self.updateInProgress, present: self.present, completion: self.completion)
    }
    
    static var body: Body {
        let background = Child(Rectangle.self)
        let scrollContent = Child(ScrollComponent<EnvironmentType>.self)
        let star = Child(PremiumStarComponent.self)
        let emoji = Child(EmojiHeaderComponent.self)
        let coin = Child(PremiumCoinComponent.self)
        let topPanel = Child(BlurredBackgroundComponent.self)
        let topSeparator = Child(Rectangle.self)
        let title = Child(MultilineTextComponent.self)
        let secondaryTitle = Child(MultilineTextWithEntitiesComponent.self)
        let bottomPanel = Child(BlurredBackgroundComponent.self)
        let bottomSeparator = Child(Rectangle.self)
        let button = Child(SolidRoundedButtonComponent.self)
        
        var updatedInstalled: Bool?
        
        return { context in
            let environment = context.environment[EnvironmentType.self].value
            let state = context.state
                        
            let background = background.update(component: Rectangle(color: environment.theme.list.blocksBackgroundColor), environment: {}, availableSize: context.availableSize, transition: context.transition)
            
            var starIsVisible = true
            if let topContentOffset = state.topContentOffset, topContentOffset >= 123.0 {
                starIsVisible = false
            }

            var isIntro = true
            if case .profile = context.component.source {
                isIntro = false
            }
            
            let header: _UpdatedChildComponent
            if case .business = context.component.mode {
                header = coin.update(
                    component: PremiumCoinComponent(
                        mode: .business,
                        isIntro: isIntro,
                        isVisible: starIsVisible,
                        hasIdleAnimations: state.hasIdleAnimations
                    ),
                    availableSize: CGSize(width: min(414.0, context.availableSize.width), height: 220.0),
                    transition: context.transition
                )
            } else if case let .emojiStatus(_, fileId, _, _) = context.component.source, case let .accountContext(accountContext) = context.component.screenContext {
                header = emoji.update(
                    component: EmojiHeaderComponent(
                        context: accountContext,
                        animationCache: accountContext.animationCache,
                        animationRenderer: accountContext.animationRenderer,
                        placeholderColor: environment.theme.list.mediaPlaceholderColor,
                        accentColor: environment.theme.list.itemAccentColor,
                        fileId: fileId,
                        isVisible: starIsVisible,
                        hasIdleAnimations: state.hasIdleAnimations
                    ),
                    availableSize: CGSize(width: min(414.0, context.availableSize.width), height: 220.0),
                    transition: context.transition
                )
            } else {
                header = star.update(
                    component: PremiumStarComponent(
                        theme: environment.theme,
                        isIntro: isIntro,
                        isVisible: starIsVisible,
                        hasIdleAnimations: state.hasIdleAnimations,
                        colors: [
                            UIColor(rgb: 0x6a94ff),
                            UIColor(rgb: 0x9472fd),
                            UIColor(rgb: 0xe26bd3)
                        ]
                    ),
                    availableSize: CGSize(width: min(414.0, context.availableSize.width), height: 220.0),
                    transition: context.transition
                )
            }
            
            let topPanel = topPanel.update(
                component: BlurredBackgroundComponent(
                    color: environment.theme.rootController.navigationBar.blurredBackgroundColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: environment.navigationHeight),
                transition: context.transition
            )
            
            let topSeparator = topSeparator.update(
                component: Rectangle(
                    color: environment.theme.rootController.navigationBar.separatorColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: UIScreenPixel),
                transition: context.transition
            )
            
            let titleString: String
            if case .business = context.component.mode {
                titleString = environment.strings.Business_Title
            } else if case .emojiStatus = context.component.source {
                titleString = environment.strings.Premium_Title
            } else if case .giftTerms = context.component.source {
                titleString = environment.strings.Premium_Title
            } else if case .gift = context.component.source {
                titleString = environment.strings.Premium_GiftedTitle
            } else if state.isPremium == true {
                if !state.justBought && state.canUpgrade {
                    titleString = environment.strings.Premium_Title
                } else {
                    titleString = environment.strings.Premium_SubscribedTitle
                }
            } else {
                titleString = environment.strings.Premium_Title
            }
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleString, font: Font.bold(28.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center,
                    truncationType: .end,
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )

            var loadedEmojiPack: LoadedStickerPack?
            var highlightableLinks = false
            let secondaryTitleText: String
            var isAnonymous = false
            if var otherPeerName = state.otherPeerName {
                if case let .emojiStatus(peerId, _, file, maybeEmojiPack) = context.component.source, let emojiPack = maybeEmojiPack, case let .result(info, _, _) = emojiPack {
                    loadedEmojiPack = maybeEmojiPack
                    highlightableLinks = true
                    
                    if peerId.isGroupOrChannel, otherPeerName.count > 20 {
                        otherPeerName = otherPeerName.prefix(20).trimmingCharacters(in: .whitespacesAndNewlines) + "\u{2026}"
                    }
                    
                    var packReference: StickerPackReference?
                    if let file = file {
                        for attribute in file.attributes {
                            if case let .CustomEmoji(_, _, _, reference) = attribute {
                                packReference = reference
                            }
                        }
                    }
                    if let packReference = packReference, case let .id(id, _) = packReference, id == 773947703670341676 {
                        secondaryTitleText = environment.strings.Premium_EmojiStatusShortTitle(otherPeerName).string
                    } else {
                        secondaryTitleText = environment.strings.Premium_EmojiStatusTitle(otherPeerName, info.title).string.replacingOccurrences(of: "#", with: " #  ")
                    }
                } else if case .profile = context.component.source {
                    secondaryTitleText = environment.strings.Premium_PersonalTitle(otherPeerName).string
                } else if case let .gift(fromPeerId, _, duration, _) = context.component.source {
                    if case let .accountContext(accountContext) = context.component.screenContext, fromPeerId == accountContext.account.peerId {
                        if duration == 12 {
                            secondaryTitleText = environment.strings.Premium_GiftedTitleYou_12Month(otherPeerName).string
                        } else if duration == 6  {
                            secondaryTitleText = environment.strings.Premium_GiftedTitleYou_6Month(otherPeerName).string
                        } else if duration == 3 {
                            secondaryTitleText = environment.strings.Premium_GiftedTitleYou_3Month(otherPeerName).string
                        } else {
                            secondaryTitleText = ""
                        }
                    } else {
                        if fromPeerId.namespace == Namespaces.Peer.CloudUser && fromPeerId.id._internalGetInt64Value() == 777000 {
                            isAnonymous = true
                            otherPeerName = environment.strings.Premium_GiftedTitle_Someone
                        }
                        if duration == 12 {
                            secondaryTitleText = environment.strings.Premium_GiftedTitle_12Month(otherPeerName).string
                        } else if duration == 6 {
                            secondaryTitleText = environment.strings.Premium_GiftedTitle_6Month(otherPeerName).string
                        } else if duration == 3 {
                            secondaryTitleText = environment.strings.Premium_GiftedTitle_3Month(otherPeerName).string
                        } else {
                            secondaryTitleText = ""
                        }
                    }
                } else {
                    secondaryTitleText = ""
                }
            } else {
                secondaryTitleText = ""
            }
            
            let textColor = environment.theme.list.itemPrimaryTextColor
            let accentColor: UIColor
            if case .emojiStatus = context.component.source {
                accentColor = environment.theme.list.itemAccentColor
            } else {
                accentColor = UIColor(rgb: 0x597cf5)
            }
            
            let textFont = Font.bold(18.0)
            let boldTextFont = Font.bold(18.0)
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: isAnonymous ? textColor : accentColor), linkAttribute: { _ in
                return nil
            })
            
            let secondaryAttributedText = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(secondaryTitleText, attributes: markdownAttributes))
            if let emojiFile = state.emojiFile {
                let range = (secondaryAttributedText.string as NSString).range(of: "#")
                if range.location != NSNotFound {
                    secondaryAttributedText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: emojiFile.fileId.id, file: emojiFile), range: range)
                }
            }

            let presentController = context.component.present
            let secondaryTitle = secondaryTitle.update(
                component: MultilineTextWithEntitiesComponent(
                    context: context.component.screenContext.context,
                    animationCache: context.component.screenContext.context?.animationCache,
                    animationRenderer: context.component.screenContext.context?.animationRenderer,
                    placeholderColor: environment.theme.list.mediaPlaceholderColor,
                    text: .plain(secondaryAttributedText),
                    horizontalAlignment: .center,
                    truncationType: .end,
                    maximumNumberOfLines: 2,
                    lineSpacing: 0.0,
                    highlightAction: highlightableLinks ? { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    } : nil,
                    tapAction: { [weak state, weak environment] _, _ in
                        if let emojiFile = state?.emojiFile, let controller = environment?.controller() as? PremiumIntroScreen, let context = controller.context, let navigationController = controller.navigationController as? NavigationController {
                            for attribute in emojiFile.attributes {
                                if case let .CustomEmoji(_, _, _, packReference) = attribute, let packReference = packReference {
                                    var loadedPack: LoadedStickerPack?
                                    if let loadedEmojiPack, case let .result(info, items, installed) = loadedEmojiPack {
                                        loadedPack = .result(info: info, items: items, installed: updatedInstalled ?? installed)
                                    }
                                    
                                    let controller = context.sharedContext.makeStickerPackScreen(context: context, updatedPresentationData: nil, mainStickerPack: packReference, stickerPacks: [packReference], loadedStickerPacks: loadedPack.flatMap { [$0] } ?? [], actionTitle: nil, isEditing: false, expandIfNeeded: false, parentNavigationController: navigationController, sendSticker: { _, _, _ in
                                        return false
                                    }, actionPerformed: { added in
                                        updatedInstalled = added
                                    })
                                    presentController(controller)
                                    break
                                }
                            }
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - 32.0, height: context.availableSize.width),
                transition: context.transition
            )
            
            let bottomPanelPadding: CGFloat = 12.0
            let bottomInset: CGFloat = environment.safeInsets.bottom > 0.0 ? environment.safeInsets.bottom + 5.0 : bottomPanelPadding
            let bottomPanelHeight: CGFloat = state.isPremium == true && !state.canUpgrade ? bottomInset : bottomPanelPadding + 50.0 + bottomInset
                       
            let scrollContent = scrollContent.update(
                component: ScrollComponent<EnvironmentType>(
                    content: AnyComponent(PremiumIntroScreenContentComponent(
                        screenContext: context.component.screenContext,
                        mode: context.component.mode,
                        source: context.component.source,
                        forceDark: context.component.forceDark,
                        isPremium: state.isPremium,
                        justBought: state.justBought,
                        otherPeerName: state.otherPeerName,
                        products: state.products,
                        selectedProductId: state.selectedProductId,
                        validPurchases: state.validPurchases,
                        promoConfiguration: state.promoConfiguration,
                        present: context.component.present,
                        push: context.component.push,
                        selectProduct: { [weak state] productId in
                            state?.selectProduct(productId)
                        },
                        buy: { [weak state] in
                            state?.buy()
                        },
                        updateIsFocused: { [weak state] isFocused in
                            state?.updateIsFocused(isFocused)
                        },
                        copyLink: context.component.copyLink,
                        shareLink: context.component.shareLink
                    )),
                    contentInsets: UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: bottomPanelHeight, right: 0.0),
                    contentOffsetUpdated: { [weak state] topContentOffset, bottomContentOffset in
                        state?.topContentOffset = topContentOffset
                        state?.bottomContentOffset = bottomContentOffset
                        Queue.mainQueue().justDispatch {
                            state?.updated(transition: .immediate)
                        }
                    },
                    contentOffsetWillCommit: { targetContentOffset in
                        if targetContentOffset.pointee.y < 100.0 {
                            targetContentOffset.pointee = CGPoint(x: 0.0, y: 0.0)
                        } else if targetContentOffset.pointee.y < 123.0 {
                            targetContentOffset.pointee = CGPoint(x: 0.0, y: 123.0)
                        }
                    }
                ),
                environment: { environment },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            let topInset: CGFloat = environment.navigationHeight - 56.0
            
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            context.add(scrollContent
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
                        
            let topPanelAlpha: CGFloat
            let titleOffset: CGFloat
            let titleScale: CGFloat
            let titleOffsetDelta = (topInset + 160.0) - (environment.statusBarHeight + (environment.navigationHeight - environment.statusBarHeight) / 2.0)
            let titleAlpha: CGFloat
            
            if let topContentOffset = state.topContentOffset {
                topPanelAlpha = min(20.0, max(0.0, topContentOffset - 95.0)) / 20.0
                let topContentOffset = topContentOffset + max(0.0, min(1.0, topContentOffset / titleOffsetDelta)) * 10.0
                titleOffset = topContentOffset
                let fraction = max(0.0, min(1.0, titleOffset / titleOffsetDelta))
                titleScale = 1.0 - fraction * 0.36
                
                if state.otherPeerName != nil {
                    titleAlpha = min(1.0, fraction * 1.1)
                } else {
                    titleAlpha = 1.0
                }
            } else {
                topPanelAlpha = 0.0
                titleScale = 1.0
                titleOffset = 0.0
                titleAlpha = state.otherPeerName != nil ? 0.0 : 1.0
            }
            
            context.add(header
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topInset + header.size.height / 2.0 - 30.0 - titleOffset * titleScale))
                .scale(titleScale)
            )
            
            context.add(topPanel
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topPanel.size.height / 2.0))
                .opacity(topPanelAlpha)
            )
            context.add(topSeparator
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topPanel.size.height))
                .opacity(topPanelAlpha)
            )
            
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: max(topInset + 160.0 - titleOffset, environment.statusBarHeight + (environment.navigationHeight - environment.statusBarHeight) / 2.0)))
                .scale(titleScale)
                .opacity(titleAlpha)
            )
            
            context.add(secondaryTitle
                .position(CGPoint(x: context.availableSize.width / 2.0, y: max(topInset + 160.0 - titleOffset, environment.statusBarHeight + (environment.navigationHeight - environment.statusBarHeight) / 2.0)))
                .scale(titleScale)
                .opacity(max(0.0, 1.0 - titleAlpha * 1.8))
            )
            
            var isUnusedGift = false
            if case let .gift(fromId, _, _, giftCode) = context.component.source, let accountContext = context.component.screenContext.context {
                if let giftCode, giftCode.usedDate == nil, fromId != accountContext.account.peerId {
                    isUnusedGift = true
                }
            }
            
            var buttonIsHidden = true
            if !state.justBought {
                if isUnusedGift {
                    buttonIsHidden = false
                } else if state.canUpgrade {
                    buttonIsHidden = false
                } else if !(state.isPremium ?? false) {
                    buttonIsHidden = false
                }
            }
            
            if !buttonIsHidden {
                let buttonTitle: String
                var buttonSubtitle: String?
                if case let .auth(price) = context.component.source {
                    buttonTitle = environment.strings.Premium_Week_SignUp(price).string
                    buttonSubtitle = environment.strings.Premium_Week_SignUpInfo
                } else if isUnusedGift {
                    buttonTitle = environment.strings.Premium_Gift_ApplyLink
                } else if state.isPremium == true && state.canUpgrade {
                    buttonTitle = state.isAnnual ? environment.strings.Premium_UpgradeForAnnual(state.price ?? "—").string : environment.strings.Premium_UpgradeFor(state.price ?? "—").string
                } else {
                    buttonTitle = state.isAnnual ? environment.strings.Premium_SubscribeForAnnual(state.price ?? "—").string : environment.strings.Premium_SubscribeFor(state.price ?? "—").string
                }
                
                let controller = environment.controller
                let sideInset: CGFloat = 16.0
                let button = button.update(
                    component: SolidRoundedButtonComponent(
                        title: buttonTitle,
                        subtitle: buttonSubtitle,
                        theme: SolidRoundedButtonComponent.Theme(
                            backgroundColor: UIColor(rgb: 0x8878ff),
                            backgroundColors: [
                                UIColor(rgb: 0x0077ff),
                                UIColor(rgb: 0x6b93ff),
                                UIColor(rgb: 0x8878ff),
                                UIColor(rgb: 0xe46ace)
                            ],
                            foregroundColor: .white
                        ),
                        height: 50.0,
                        cornerRadius: 11.0,
                        gloss: true,
                        isLoading: state.inProgress,
                        action: {
                            if let controller = controller() as? PremiumIntroScreen, let customProceed = controller.customProceed {
                                controller.dismiss()
                                customProceed()
                            } else {
                                state.buy()
                            }
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - environment.safeInsets.left - environment.safeInsets.right, height: 50.0),
                    transition: context.transition)
                               
                let bottomPanel = bottomPanel.update(
                    component: BlurredBackgroundComponent(
                        color: environment.theme.rootController.tabBar.backgroundColor
                    ),
                    availableSize: CGSize(width: context.availableSize.width, height: bottomPanelPadding + button.size.height + bottomInset),
                    transition: context.transition
                )
                
                let bottomSeparator = bottomSeparator.update(
                    component: Rectangle(
                        color: environment.theme.rootController.tabBar.separatorColor
                    ),
                    availableSize: CGSize(width: context.availableSize.width, height: UIScreenPixel),
                    transition: context.transition
                )
                
                let bottomPanelAlpha: CGFloat
                if let bottomContentOffset = state.bottomContentOffset {
                    bottomPanelAlpha = min(16.0, bottomContentOffset) / 16.0
                } else {
                    bottomPanelAlpha = 1.0
                }
                
                context.add(bottomPanel
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - bottomPanel.size.height / 2.0))
                    .opacity(bottomPanelAlpha)
                    .disappear(ComponentTransition.Disappear { view, transition, completion in
                        if case .none = transition.animation {
                            completion()
                            return
                        }
                        view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: bottomPanel.size.height), duration: 0.2, removeOnCompletion: false, additive: true, completion: { _ in
                            completion()
                        })
                    })
                )
                context.add(bottomSeparator
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - bottomPanel.size.height))
                    .opacity(bottomPanelAlpha)
                    .disappear(ComponentTransition.Disappear { view, transition, completion in
                        if case .none = transition.animation {
                            completion()
                            return
                        }
                        view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: bottomPanel.size.height), duration: 0.2, removeOnCompletion: false, additive: true, completion: { _ in
                            completion()
                        })
                    })
                )
                context.add(button
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - bottomPanel.size.height + bottomPanelPadding + button.size.height / 2.0))
                    .disappear(ComponentTransition.Disappear { view, transition, completion in
                        if case .none = transition.animation {
                            completion()
                            return
                        }
                        view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: bottomPanel.size.height), duration: 0.2, removeOnCompletion: false, additive: true, completion: { _ in
                            completion()
                        })
                    })
                )
            }
            
            return context.availableSize
        }
    }
}

public final class PremiumIntroScreen: ViewControllerComponentContainer {
    public enum ScreenContext {
        case accountContext(AccountContext)
        case sharedContext(SharedAccountContext, TelegramEngineUnauthorized, InAppPurchaseManager)
        
        var context: AccountContext? {
            switch self {
            case let .accountContext(context):
                return context
            case .sharedContext:
                return nil
            }
        }
        
        var sharedContext: SharedAccountContext {
            switch self {
            case let .accountContext(context):
                return context.sharedContext
            case let .sharedContext(sharedContext, _, _):
                return sharedContext
            }
        }
        
        var inAppPurchaseManager: InAppPurchaseManager? {
            switch self {
            case let .accountContext(context):
                return context.inAppPurchaseManager
            case let .sharedContext(_, _, inAppPurchaseManager):
                return inAppPurchaseManager
            }
        }
        
        var presentationData: PresentationData {
            switch self {
            case let .accountContext(context):
                return context.sharedContext.currentPresentationData.with { $0 }
            case let .sharedContext(sharedContext, _, _):
                return sharedContext.currentPresentationData.with { $0 }
            }
        }
        
        var updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) {
            switch self {
            case let .accountContext(context):
                return (initial: context.sharedContext.currentPresentationData.with { $0 }, signal: context.sharedContext.presentationData)
            case let .sharedContext(sharedContext, _, _):
                return (initial: sharedContext.currentPresentationData.with { $0 }, signal: sharedContext.presentationData)
            }
        }
    }
    
    public enum Mode {
        case premium
        case business
    }
    
    fileprivate var context: AccountContext? {
        switch self.screenContext {
        case let .accountContext(context):
            return context
        case .sharedContext:
            return nil
        }
    }
    private let screenContext: ScreenContext
    fileprivate let mode: Mode
    
    private var didSetReady = false
    private let _ready = Promise<Bool>()
    public override var ready: Promise<Bool> {
        return self._ready
    }
    
    public weak var sourceView: UIView?
    public var sourceRect: CGRect?
    public weak var containerView: UIView?
    public var animationColor: UIColor?
    
    public convenience init(context: AccountContext, mode: Mode = .premium, source: PremiumSource, modal: Bool = true, forceDark: Bool = false, forceHasPremium: Bool = false) {
        self.init(screenContext: .accountContext(context), mode: mode, source: source, modal: modal, forceDark: forceDark, forceHasPremium: forceHasPremium)
    }
    
    public init(screenContext: ScreenContext, mode: Mode = .premium, source: PremiumSource, modal: Bool = true, forceDark: Bool = false, forceHasPremium: Bool = false) {
        self.screenContext = screenContext
        self.mode = mode
        
        let presentationData = screenContext.presentationData
        
        var updateInProgressImpl: ((Bool) -> Void)?
        var pushImpl: ((ViewController) -> Void)?
        var presentImpl: ((ViewController) -> Void)?
        var completionImpl: (() -> Void)?
        var copyLinkImpl: ((String) -> Void)?
        var shareLinkImpl: ((String) -> Void)?
        super.init(component: PremiumIntroScreenComponent(
            screenContext: screenContext,
            mode: mode,
            source: source,
            forceDark: forceDark,
            forceHasPremium: forceHasPremium,
            updateInProgress: { inProgress in
                updateInProgressImpl?(inProgress)
            },
            present: { c in
                presentImpl?(c)
            },
            push: { c in
                pushImpl?(c)
            },
            completion: {
                completionImpl?()
            },
            copyLink: { link in
                copyLinkImpl?(link)
            },
            shareLink: { link in
                shareLinkImpl?(link)
            }
        ), navigationBarAppearance: .transparent, presentationMode: modal ? .modal : .default, theme: forceDark ? .dark : .default, updatedPresentationData: screenContext.updatedPresentationData)
                
        if modal {
            let cancelItem = UIBarButtonItem(title: presentationData.strings.Common_Close, style: .plain, target: self, action: #selector(self.cancelPressed))
            self.navigationItem.setLeftBarButton(cancelItem, animated: false)
            self.navigationPresentation = .modal
        } else {
            self.navigationPresentation = .modalInLargeLayout
        }
        
        updateInProgressImpl = { [weak self] inProgress in
            guard let self else {
                return
            }
            self.navigationItem.leftBarButtonItem?.isEnabled = !inProgress
            self.view.disablesInteractiveTransitionGestureRecognizer = inProgress
            self.view.disablesInteractiveModalDismiss = inProgress
        }
        
        presentImpl = { [weak self] c in
            if c is UndoOverlayController {
                self?.present(c, in: .current)
            } else {
                self?.present(c, in: .window(.root))
            }
        }
        
        pushImpl = { [weak self] c in
            self?.push(c)
        }
        
        completionImpl = { [weak self] in
            if let self {
                self.animateSuccess()
            }
        }
        
        copyLinkImpl = { [weak self] link in
            UIPasteboard.general.string = link
            
            guard let self else {
                return
            }
            self.dismissAllTooltips()
            
            self.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, position: .top, action: { _ in return true }), in: .current)
        }
        
        shareLinkImpl = { [weak self] link in
            guard let self, case let .accountContext(context) = screenContext, let navigationController = self.navigationController as? NavigationController else {
                return
            }
            
            let messages: [EnqueueMessage] = [.message(text: link, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]
            
            let peerSelectionController = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled], multipleSelection: false, selectForumThreads: true))
            peerSelectionController.peerSelected = { [weak peerSelectionController, weak navigationController] peer, threadId in
                if let _ = peerSelectionController {
                    Queue.mainQueue().after(0.88) {
                        HapticFeedback().success()
                    }
                    
                    (navigationController?.topViewController as? ViewController)?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: true, text: peer.id == context.account.peerId ? presentationData.strings.GiftLink_LinkSharedToSavedMessages : presentationData.strings.GiftLink_LinkSharedToChat(peer.compactDisplayTitle).string), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .window(.root))
                    
                    let _ = (enqueueMessages(account: context.account, peerId: peer.id, messages: messages)
                    |> deliverOnMainQueue).startStandalone()
                    if let peerSelectionController = peerSelectionController {
                        peerSelectionController.dismiss()
                    }
                }
            }
            navigationController.pushViewController(peerSelectionController)
        }
        
        if case .business = mode, case let .accountContext(context) = screenContext {
            context.account.viewTracker.keepQuickRepliesApproximatelyUpdated()
            context.account.viewTracker.keepBusinessLinksApproximatelyUpdated()
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.dismissAllTooltips()
    }
    
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
            return true
        })
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
        self.wasDismissed?()
    }
    
    public func animateSuccess() {
        self.view.addSubview(ConfettiView(frame: self.view.bounds))
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if !self.didSetReady {
            if let view = self.node.hostView.findTaggedView(tag: PremiumCoinComponent.View.Tag()) as? PremiumCoinComponent.View {
                self.didSetReady = true
                self._ready.set(view.ready)
            } else if let view = self.node.hostView.findTaggedView(tag: PremiumStarComponent.View.Tag()) as? PremiumStarComponent.View {
                self.didSetReady = true
                self._ready.set(view.ready)
                
                if let sourceView = self.sourceView {
                    view.animateFrom = sourceView
                    view.containerView = self.containerView
                    view.animationColor = self.animationColor
                    
                    self.sourceView = nil
                    self.containerView = nil
                    self.animationColor = nil
                }
            } else if let view = self.node.hostView.findTaggedView(tag: EmojiHeaderComponent.View.Tag()) as? EmojiHeaderComponent.View {
                self.didSetReady = true
                self._ready.set(view.ready)
                
                if let sourceView = self.sourceView {
                    view.animateFrom = sourceView
                    view.sourceRect = self.sourceRect
                    view.containerView = self.containerView
                    
                    view.animateIn()
                    
                    self.sourceView = nil
                    self.containerView = nil
                    self.animationColor = nil
                }
            }
        }
    }
}

private final class BadgeComponent: CombinedComponent {
    let color: UIColor
    let text: String
    
    init(
        color: UIColor,
        text: String
    ) {
        self.color = color
        self.text = text
    }
    
    static func ==(lhs: BadgeComponent, rhs: BadgeComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        return true
    }
    
    static var body: Body {
        let badgeBackground = Child(RoundedRectangle.self)
        let badgeText = Child(MultilineTextComponent.self)

        return { context in
            let component = context.component
            
            let badgeText = badgeText.update(
                component: MultilineTextComponent(text: .plain(NSAttributedString(string: component.text, font: Font.semibold(11.0), textColor: .white))),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            let badgeSize = CGSize(width: badgeText.size.width + 7.0, height: 16.0)
            let badgeBackground = badgeBackground.update(
                component: RoundedRectangle(
                    color: component.color,
                    cornerRadius: 5.0
                ),
                availableSize: badgeSize,
                transition: context.transition
            )
            
            context.add(badgeBackground
                .position(CGPoint(x: badgeSize.width / 2.0, y: badgeSize.height / 2.0))
            )
            
            context.add(badgeText
                .position(CGPoint(x: badgeSize.width / 2.0, y: badgeSize.height / 2.0))
            )
                    
            return badgeSize
        }
    }
}
