import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BalancedTextComponent
import BundleIconComponent
import Markdown
import TextFormat
import SolidRoundedButtonComponent
import BlurredBackgroundComponent
import UndoUI
import ConfettiEffect
import PremiumPeerShortcutComponent
import ScrollComponent

func requiredBoostSubjectLevel(subject: BoostSubject, group: Bool, context: AccountContext, configuration: PremiumConfiguration) -> Int32 {
    switch subject {
    case .stories:
        return 1
    case let .channelReactions(reactionCount):
        return reactionCount
    case let .nameColors(colors):
        if let value = context.peerNameColors.nameColorsChannelMinRequiredBoostLevel[colors.rawValue] {
            return value
        }
        return 1
    case .nameIcon:
        return configuration.minChannelNameIconLevel
    case let .profileColors(colors):
        if group {
            if let value = context.peerNameColors.profileColorsGroupMinRequiredBoostLevel[colors.rawValue] {
                return value
            }
        } else {
            return configuration.minChannelProfileColorLevel
        }
        return 1
    case .profileIcon:
        return group ? configuration.minGroupProfileIconLevel : configuration.minChannelProfileIconLevel
    case .emojiStatus:
        return group ? configuration.minGroupEmojiStatusLevel : configuration.minChannelEmojiStatusLevel
    case .wallpaper:
        return group ? configuration.minGroupWallpaperLevel : configuration.minChannelWallpaperLevel
    case .customWallpaper:
        return group ? configuration.minGroupCustomWallpaperLevel : configuration.minChannelCustomWallpaperLevel
    case .audioTranscription:
        return configuration.minGroupAudioTranscriptionLevel
    case .emojiPack:
        return configuration.minGroupEmojiPackLevel
    case .noAds:
        return configuration.minChannelRestrictAdsLevel
    case .wearGift:
        return configuration.minChannelWearGiftLevel
    }
}

extension BoostSubject {
    public func requiredLevel(group: Bool, context: AccountContext, configuration: PremiumConfiguration) -> Int32 {
        return requiredBoostSubjectLevel(subject: self, group: group, context: context, configuration: configuration)
    }
}

private final class LevelHeaderComponent: CombinedComponent {
    let theme: PresentationTheme
    let text: String
  
    init(
        theme: PresentationTheme,
        text: String
    ) {
        self.theme = theme
        self.text = text
    }
    
    static func ==(lhs: LevelHeaderComponent, rhs: LevelHeaderComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        return true
    }
    
    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let text = Child(MultilineTextComponent.self)
        let leftLine = Child(Rectangle.self)
        let rightLine = Child(Rectangle.self)

        return { context in
            let component = context.component
            
            let outerInset: CGFloat = 28.0
            let innerInset: CGFloat = 9.0
            
            let height: CGFloat = 50.0
            let backgroundHeight: CGFloat = 34.0
            let text = text.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.text, font: Font.semibold(15.0), textColor: .white)),
                    horizontalAlignment: .center
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            let backgroundWidth: CGFloat = floor(text.size.width + 21.0)

            let background = background.update(
                component: RoundedRectangle(colors: [UIColor(rgb: 0x9076ff), UIColor(rgb: 0xbc6de8)], cornerRadius: backgroundHeight / 2.0, gradientDirection: .horizontal),
                availableSize: CGSize(width: backgroundWidth, height: backgroundHeight),
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: height / 2.0))
            )
            context.add(text
                .position(CGPoint(x: context.availableSize.width / 2.0, y: height / 2.0))
            )

            let remainingWidth = (context.availableSize.width - background.size.width) / 2.0
            let lineSize = remainingWidth - outerInset - innerInset
            let lineWidth = 1.0 - UIScreenPixel
            
            let leftLine = leftLine.update(
                component: Rectangle(
                    color: component.theme.actionSheet.secondaryTextColor.withMultipliedAlpha(0.5)
                ),
                availableSize: CGSize(width: lineSize, height: lineWidth),
                transition: .immediate
            )
            context.add(leftLine
                .position(CGPoint(x: outerInset + lineSize / 2.0, y: height / 2.0))
            )
            
            let rightLine = rightLine.update(
                component: Rectangle(
                    color: component.theme.actionSheet.secondaryTextColor.withMultipliedAlpha(0.5)
                ),
                availableSize: CGSize(width: lineSize, height: lineWidth),
                transition: .immediate
            )
            context.add(rightLine
                .position(CGPoint(x: context.availableSize.width - outerInset - lineSize / 2.0, y: height / 2.0))
            )
            
            return CGSize(width: context.availableSize.width, height: height)
        }
    }
}

private final class LevelPerkComponent: CombinedComponent {
    let theme: PresentationTheme
    let iconName: String
    let text: String
  
    init(
        theme: PresentationTheme,
        iconName: String,
        text: String
    ) {
        self.theme = theme
        self.iconName = iconName
        self.text = text
    }
    
    static func ==(lhs: LevelPerkComponent, rhs: LevelPerkComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        return true
    }
    
    static var body: Body {
        let icon = Child(BundleIconComponent.self)
        let text = Child(MultilineTextComponent.self)

        return { context in
            let component = context.component
            
            let outerInset: CGFloat = 28.0
            let height: CGFloat = 44.0
            
            let icon = icon.update(
                component: BundleIconComponent(
                    name: component.iconName,
                    tintColor: component.theme.actionSheet.controlAccentColor
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            context.add(icon
                .position(CGPoint(x: outerInset + icon.size.width / 2.0, y: height / 2.0))
            )

            let text = text.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.text, font: Font.semibold(15.0), textColor: component.theme.actionSheet.primaryTextColor)),
                    horizontalAlignment: .center
                ),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(text
                .position(CGPoint(x: outerInset * 2.0 + 18.0 + text.size.width / 2.0, y: height / 2.0))
            )
          
            return CGSize(width: context.availableSize.width, height: height)
        }
    }
}

private final class LevelSectionComponent: CombinedComponent {
    enum Perk: Equatable {
        case story(Int32)
        case reaction(Int32)
        case nameColor(Int32)
        case profileColor(Int32)
        case profileIcon
        case linkColor(Int32)
        case linkIcon
        case emojiStatus
        case wallpaper(Int32)
        case customWallpaper
        case audioTranscription
        case emojiPack
        case noAds
        case wearGift
        
        func title(strings: PresentationStrings, isGroup: Bool) -> String {
            switch self {
            case let .story(value):
                return strings.ChannelBoost_Table_StoriesPerDay(value)
            case let .reaction(value):
                return strings.ChannelBoost_Table_CustomReactions(value)
            case let .nameColor(value):
                return strings.ChannelBoost_Table_NameColor(value)
            case let .profileColor(value):
                return isGroup ? strings.ChannelBoost_Table_Group_ProfileColor(value) : strings.ChannelBoost_Table_ProfileColor(value)
            case .profileIcon:
                return isGroup ? strings.ChannelBoost_Table_Group_ProfileLogo : strings.ChannelBoost_Table_ProfileLogo
            case let .linkColor(value):
                return strings.ChannelBoost_Table_StyleForHeaders(value)
            case .linkIcon:
                return strings.ChannelBoost_Table_HeadersLogo
            case .emojiStatus:
                return strings.ChannelBoost_Table_EmojiStatus
            case let .wallpaper(value):
                return isGroup ? strings.ChannelBoost_Table_Group_Wallpaper(value) : strings.ChannelBoost_Table_Wallpaper(value)
            case .customWallpaper:
                return isGroup ? strings.ChannelBoost_Table_Group_CustomWallpaper : strings.ChannelBoost_Table_CustomWallpaper
            case .audioTranscription:
                return strings.GroupBoost_Table_Group_VoiceToText
            case .emojiPack:
                return strings.GroupBoost_Table_Group_EmojiPack
            case .noAds:
                return strings.ChannelBoost_Table_NoAds
            case .wearGift:
                return strings.ChannelBoost_Table_WearGift
            }
        }
        
        var iconName: String {
            switch self {
            case .story:
                return "Premium/BoostPerk/Story"
            case .reaction:
                return "Premium/BoostPerk/Reaction"
            case .nameColor:
                return "Premium/BoostPerk/NameColor"
            case .profileColor:
                return "Premium/BoostPerk/CoverColor"
            case .profileIcon:
                return "Premium/BoostPerk/CoverLogo"
            case .linkColor:
                return "Premium/BoostPerk/LinkColor"
            case .linkIcon:
                return "Premium/BoostPerk/LinkLogo"
            case .emojiStatus:
                return "Premium/BoostPerk/EmojiStatus"
            case .wallpaper:
                return "Premium/BoostPerk/Wallpaper"
            case .customWallpaper:
                return "Premium/BoostPerk/CustomWallpaper"
            case .audioTranscription:
                return "Premium/BoostPerk/AudioTranscription"
            case .emojiPack:
                return "Premium/BoostPerk/EmojiPack"
            case .noAds:
                return "Premium/BoostPerk/NoAds"
            case .wearGift:
                return "Premium/BoostPerk/NoAds"
            }
        }
    }
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    let level: Int32
    let isFirst: Bool
    let perks: [Perk]
    let isGroup: Bool
  
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        level: Int32,
        isFirst: Bool,
        perks: [Perk],
        isGroup: Bool
    ) {
        self.theme = theme
        self.strings = strings
        self.level = level
        self.isFirst = isFirst
        self.perks = perks
        self.isGroup = isGroup
    }
    
    static func ==(lhs: LevelSectionComponent, rhs: LevelSectionComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.level != rhs.level {
            return false
        }
        if lhs.isFirst != rhs.isFirst {
            return false
        }
        if lhs.perks != rhs.perks {
            return false
        }
        if lhs.isGroup != rhs.isGroup {
            return false
        }
        return true
    }
    
    static var body: Body {
        let header = Child(LevelHeaderComponent.self)
        let list = Child(List<Empty>.self)

        return { context in
            let component = context.component
            
            let header = header.update(
                component: LevelHeaderComponent(theme: component.theme, text: component.isFirst ? component.strings.ChannelBoost_Table_LevelUnlocks(component.level) : component.strings.ChannelBoost_Table_Level(component.level)),
                availableSize: context.availableSize,
                transition: .immediate
            )
            context.add(header
                .position(CGPoint(x: context.availableSize.width / 2.0, y: header.size.height / 2.0)))
            
            let items: [AnyComponentWithIdentity<Empty>] = component.perks.enumerated().map { index, value in
                AnyComponentWithIdentity(
                    id: index, component: AnyComponent(
                        LevelPerkComponent(
                            theme: component.theme,
                            iconName: value.iconName,
                            text: value.title(strings: component.strings, isGroup: component.isGroup)
                        )
                    )
                )
            }
                                
            let list = list.update(
                component: List(items),
                availableSize: CGSize(width: context.availableSize.width, height: 10000.0),
                transition: context.transition
            )
            context.add(list
                .position(CGPoint(x: context.availableSize.width / 2.0, y: header.size.height + list.size.height / 2.0)))
            
            return CGSize(width: context.availableSize.width, height: header.size.height + list.size.height)
        }
    }
}

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = (Empty, ScrollChildEnvironment)
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let insets: UIEdgeInsets
        
    let peerId: EnginePeer.Id
    let isGroup: Bool
    let mode: PremiumBoostLevelsScreen.Mode
    let status: ChannelBoostStatus?
    let boostState: InternalBoostState.DisplayData?
    let initialized: Bool
    
    let boost: () -> Void
    let copyLink: (String) -> Void
    let dismiss: () -> Void
    let openStats: (() -> Void)?
    let openGift: (() -> Void)?
    let openPeer: ((EnginePeer) -> Void)?
    let updated: () -> Void
    
    init(context: AccountContext,
         theme: PresentationTheme,
         strings: PresentationStrings,
         insets: UIEdgeInsets,
         peerId: EnginePeer.Id,
         isGroup: Bool,
         mode: PremiumBoostLevelsScreen.Mode,
         status: ChannelBoostStatus?,
         boostState: InternalBoostState.DisplayData?,
         initialized: Bool,
         boost: @escaping () -> Void,
         copyLink: @escaping (String) -> Void,
         dismiss: @escaping () -> Void,
         openStats: (() -> Void)?,
         openGift: (() -> Void)?,
         openPeer: ((EnginePeer) -> Void)?,
         updated: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.insets = insets
        self.peerId = peerId
        self.isGroup = isGroup
        self.mode = mode
        self.status = status
        self.boostState = boostState
        self.initialized = initialized
        self.boost = boost
        self.copyLink = copyLink
        self.dismiss = dismiss
        self.openStats = openStats
        self.openGift = openGift
        self.openPeer = openPeer
        self.updated = updated
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.isGroup != rhs.isGroup {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        if lhs.status != rhs.status {
            return false
        }
        if lhs.boostState != rhs.boostState {
            return false
        }
        if lhs.initialized != rhs.initialized {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedChevronImage: (UIImage, PresentationTheme)?
        var cachedIconImage: UIImage?
        
        private(set) var peer: EnginePeer?
        private(set) var memberPeer: EnginePeer?
        
        private var disposable: Disposable?
        
        init(context: AccountContext, peerId: EnginePeer.Id, userId: EnginePeer.Id?, updated: @escaping () -> Void) {
            super.init()
            
            var peerIds: [EnginePeer.Id] = [peerId]
            if let userId {
                peerIds.append(userId)
            }
            
            self.disposable = (context.engine.data.get(
                EngineDataMap(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
            ) |> deliverOnMainQueue).startStrict(next: { [weak self] peers in
                guard let self else {
                    return
                }
                if let maybePeer = peers[peerId] {
                    self.peer = maybePeer
                }
                if let userId, let maybePeer = peers[userId] {
                    self.memberPeer = maybePeer
                }
                updated()
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    func makeState() -> State {
        var userId: EnginePeer.Id?
        if case let .user(mode) = mode, case let .groupPeer(peerId, _) = mode {
            userId = peerId
        }
        return State(context: self.context, peerId: self.peerId, userId: userId, updated: self.updated)
    }
    
    static var body: Body {
        let iconBackground = Child(Image.self)
        let icon = Child(BundleIconComponent.self)
        //let icon = Child(LottieComponent.self)
        
        let peerShortcut = Child(Button.self)
        let text = Child(BalancedTextComponent.self)
        let alternateText = Child(List<Empty>.self)
        let limit = Child(PremiumLimitDisplayComponent.self)
        let linkButton = Child(SolidRoundedButtonComponent.self)
        let boostButton = Child(SolidRoundedButtonComponent.self)
        let copyButton = Child(SolidRoundedButtonComponent.self)
        
        let orLeftLine = Child(Rectangle.self)
        let orRightLine = Child(Rectangle.self)
        let orText = Child(MultilineTextComponent.self)
        let giftText = Child(BalancedTextComponent.self)
        
        let levels = Child(List<Empty>.self)
        
        return { context in
            let component = context.component
            let theme = component.theme
            let strings = component.strings
            
            let state = context.state
            
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            let sideInset: CGFloat = 16.0 // + environment.safeInsets.left
            let textSideInset: CGFloat = 32.0 // + environment.safeInsets.left
            
            let iconName = "Premium/Boost"
            let peerName = state.peer?.compactDisplayTitle ?? ""
            
            let isGroup = component.isGroup
            
            let level: Int
            let boosts: Int
            let remaining: Int?
            let progress: CGFloat
            let myBoostCount: Int
            if let boostState = component.boostState {
                level = Int(boostState.level)
                boosts = Int(boostState.boosts)
                if let nextLevelBoosts = boostState.nextLevelBoosts {
                    remaining = max(0, Int(nextLevelBoosts - boostState.boosts))
                    progress = max(0.0, min(1.0, CGFloat(boostState.boosts - boostState.currentLevelBoosts) / CGFloat(nextLevelBoosts - boostState.currentLevelBoosts)))
                } else {
                    remaining = nil
                    progress = 1.0
                }
                myBoostCount = Int(boostState.myBoostCount)
            } else if let status = component.status {
                level = status.level
                boosts = status.boosts
                if let nextLevelBoosts = status.nextLevelBoosts {
                    remaining = max(0, nextLevelBoosts - status.boosts)
                    progress = max(0.0, min(1.0, CGFloat(status.boosts - status.currentLevelBoosts) / CGFloat(nextLevelBoosts - status.currentLevelBoosts)))
                } else {
                    remaining = nil
                    progress = 1.0
                }
                myBoostCount = 0
            } else {
                level = 0
                boosts = 0
                remaining = nil
                progress = 0.0
                myBoostCount = 0
            }
                            
            var textString = ""

            var isCurrent = false
            switch component.mode {
            case let .owner(subject):
                if let remaining {
                    var needsSecondParagraph = true
                    
                    if let subject {
                        let requiredLevel = subject.requiredLevel(group: isGroup, context: context.component.context, configuration: premiumConfiguration)
                        
                        let storiesString = strings.ChannelBoost_StoriesPerDay(Int32(level) + 1)
                        let valueString = strings.ChannelBoost_MoreBoosts(Int32(remaining))
                        switch subject {
                        case .stories:
                            if level == 0 {
                                textString = isGroup ? strings.GroupBoost_EnableStoriesText(valueString).string : strings.ChannelBoost_EnableStoriesText(valueString).string
                            } else {
                                textString = isGroup ? strings.GroupBoost_IncreaseLimitText(valueString, storiesString).string : strings.ChannelBoost_IncreaseLimitText(valueString, storiesString).string
                            }
                            needsSecondParagraph = isGroup
                        case let .channelReactions(reactionCount):
                            textString = strings.ChannelBoost_CustomReactionsText("\(reactionCount)", "\(reactionCount)").string
                            needsSecondParagraph = false
                        case .nameColors:
                            textString = strings.ChannelBoost_EnableNameColorLevelText("\(requiredLevel)").string
                        case .nameIcon:
                            textString = strings.ChannelBoost_EnableNameIconLevelText("\(requiredLevel)").string
                        case .profileColors:
                            textString = isGroup ? strings.GroupBoost_EnableProfileColorLevelText("\(requiredLevel)").string : strings.ChannelBoost_EnableProfileColorLevelText("\(requiredLevel)").string
                        case .profileIcon:
                            textString = isGroup ? strings.GroupBoost_EnableProfileIconLevelText("\(requiredLevel)").string : strings.ChannelBoost_EnableProfileIconLevelText("\(premiumConfiguration.minChannelProfileIconLevel)").string
                        case .emojiStatus:
                            textString = isGroup ? strings.GroupBoost_EnableEmojiStatusLevelText("\(requiredLevel)").string : strings.ChannelBoost_EnableEmojiStatusLevelText("\(requiredLevel)").string
                        case .wallpaper:
                            textString = isGroup ? strings.GroupBoost_EnableWallpaperLevelText("\(requiredLevel)").string : strings.ChannelBoost_EnableWallpaperLevelText("\(requiredLevel)").string
                        case .customWallpaper:
                            textString = isGroup ? strings.GroupBoost_EnableCustomWallpaperLevelText("\(requiredLevel)").string : strings.ChannelBoost_EnableCustomWallpaperLevelText("\(requiredLevel)").string
                        case .audioTranscription:
                            textString = ""
                        case .emojiPack:
                            textString = strings.GroupBoost_EnableEmojiPackLevelText("\(requiredLevel)").string
                        case .noAds:
                            textString = strings.ChannelBoost_EnableNoAdsLevelText("\(requiredLevel)").string
                        case .wearGift:
                            textString = strings.ChannelBoost_WearGiftLevelText("\(requiredLevel)").string
                        }
                    } else {
                        let boostsString = strings.ChannelBoost_MoreBoostsNeeded_Boosts(Int32(remaining))
                        if myBoostCount > 0 {
                            if remaining == 0 {
                                textString = isGroup ? strings.GroupBoost_MoreBoostsNeeded_Boosted_Level_Text("\(level + 1)").string : strings.ChannelBoost_MoreBoostsNeeded_Boosted_Level_Text("\(level + 1)").string
                            } else {
                                textString = strings.ChannelBoost_MoreBoostsNeeded_Boosted_Text(boostsString).string
                            }
                        } else {
                            textString = strings.ChannelBoost_MoreBoostsNeeded_Text(peerName, boostsString).string
                        }
                    }
                    
                    if needsSecondParagraph {
                        textString += " \(isGroup ? strings.GroupBoost_PremiumUsersCanBoost : strings.ChannelBoost_PremiumUsersCanBoost)"
                    }
                } else {
                    textString = strings.ChannelBoost_MaxLevelReached_Text(peerName, "\(level)").string
                }
            case let .user(mode):
                switch mode {
                case let .groupPeer(_, peerBoostCount):
                    let memberName = state.memberPeer?.compactDisplayTitle ?? ""
                    let timesString = strings.GroupBoost_MemberBoosted_Times(Int32(peerBoostCount))
                    let memberString = strings.GroupBoost_MemberBoosted(memberName, timesString).string
                    if myBoostCount > 0 {
                        if let remaining, remaining != 0 {
                            let boostsString = strings.ChannelBoost_MoreBoostsNeeded_Boosts(Int32(remaining))
                            textString = "\(memberString) \(strings.ChannelBoost_MoreBoostsNeeded_Boosted_Text(boostsString).string)"
                        } else {
                            textString = memberString
                        }
                    } else {
                        textString = "\(memberString) \(strings.GroupBoost_MemberBoosted_BoostForBadge(peerName).string)"
                    }
                    isCurrent = true
                case let .unrestrict(unrestrictCount):
                    let timesString = strings.GroupBoost_BoostToUnrestrict_Times(Int32(unrestrictCount))
                    textString = strings.GroupBoost_BoostToUnrestrict(timesString, peerName).string
                    isCurrent = true
                default:
                    if let remaining {
                        let boostsString = strings.ChannelBoost_MoreBoostsNeeded_Boosts(Int32(remaining))
                        if myBoostCount > 0 {
                            if remaining == 0 {
                                textString = isGroup ? strings.GroupBoost_MoreBoostsNeeded_Boosted_Level_Text("\(level + 1)").string : strings.ChannelBoost_MoreBoostsNeeded_Boosted_Level_Text("\(level + 1)").string
                            } else {
                                textString = strings.ChannelBoost_MoreBoostsNeeded_Boosted_Text(boostsString).string
                            }
                        } else {
                            textString = strings.ChannelBoost_MoreBoostsNeeded_Text(peerName, boostsString).string
                        }
                    } else {
                        textString = strings.ChannelBoost_MaxLevelReached_Text(peerName, "\(level)").string
                    }
                    isCurrent = mode == .current
                }
            case .features:
                textString = isGroup ? strings.GroupBoost_AdditionalFeaturesText : strings.ChannelBoost_AdditionalFeaturesText
            }
            
            let defaultTitle = strings.ChannelBoost_Level("\(level)").string
            let defaultValue = ""
            let premiumValue = strings.ChannelBoost_Level("\(level + 1)").string
            let premiumTitle = ""
            
            var contentSize: CGSize = CGSize(width: context.availableSize.width, height: 44.0)
    
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = theme.actionSheet.primaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            let gradientColors = [
                UIColor(rgb: 0x0077ff),
                UIColor(rgb: 0x6b93ff),
                UIColor(rgb: 0x8878ff),
                UIColor(rgb: 0xe46ace)
            ]
            let buttonGradientColors = [
                UIColor(rgb: 0x007afe),
                UIColor(rgb: 0x5494ff)
            ]
            
            if case let .user(mode) = component.mode, case .external = mode, let peer = state.peer {
                contentSize.height += 10.0
                
                let peerShortcut = peerShortcut.update(
                    component: Button(
                        content: AnyComponent(
                            PremiumPeerShortcutComponent(
                                context: component.context,
                                theme: component.theme,
                                peer: peer
                            )
                        ),
                        action: {
                            component.dismiss()
                            Queue.mainQueue().after(0.35) {
                                component.openPeer?(peer)
                            }
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width - 32.0, height: context.availableSize.height),
                    transition: .immediate
                )
                context.add(peerShortcut
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + peerShortcut.size.height / 2.0))
                )
                contentSize.height += peerShortcut.size.height + 2.0
            }
            
            if case .features = component.mode {
                contentSize.height -= 14.0
                
                let iconSize = CGSize(width: 90.0, height: 90.0)
                let gradientImage: UIImage
                if let current = state.cachedIconImage {
                    gradientImage = current
                } else {
                    gradientImage = generateFilledCircleImage(diameter: iconSize.width, color: theme.actionSheet.controlAccentColor)!
                    context.state.cachedIconImage = gradientImage
                }
                
                let iconBackground = iconBackground.update(
                    component: Image(image: gradientImage),
                    availableSize: iconSize,
                    transition: .immediate
                )
                context.add(iconBackground
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + iconBackground.size.height / 2.0))
                )
                
                let icon = icon.update(
                    component: BundleIconComponent(
                        name: "Premium/BoostLarge",
                        tintColor: .white
                    ),
                    availableSize: CGSize(width: 90.0, height: 90.0),
                    transition: .immediate
                )
                context.add(icon
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + iconBackground.size.height / 2.0))
                )
                contentSize.height += iconSize.height
                contentSize.height += 52.0
            } else {
                let limit = limit.update(
                    component: PremiumLimitDisplayComponent(
                        inactiveColor: theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.3),
                        activeColors: gradientColors,
                        inactiveTitle: defaultTitle,
                        inactiveValue: defaultValue,
                        inactiveTitleColor: theme.list.itemPrimaryTextColor,
                        activeTitle: premiumTitle,
                        activeValue: premiumValue,
                        activeTitleColor: .white,
                        badgeIconName: iconName,
                        badgeText: "\(boosts)",
                        badgePosition: progress,
                        badgeGraphPosition: progress,
                        invertProgress: true,
                        isPremiumDisabled: false
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                    transition: context.transition
                )
                context.add(limit
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + limit.size.height / 2.0))
                )
                
                contentSize.height += limit.size.height + 23.0
            }
            
            if myBoostCount > 0 {
                let alternateTitle = isCurrent ? strings.ChannelBoost_YouBoostedChannelText(peerName).string : strings.ChannelBoost_YouBoostedOtherChannelText
                
                var alternateBadge: String?
                if myBoostCount > 1 {
                    alternateBadge = "X\(myBoostCount)"
                }
                
                let alternateText = alternateText.update(
                    component: List(
                        [
                            AnyComponentWithIdentity(
                                id: "title",
                                component: AnyComponent(
                                    BoostedTitleContent(text: NSAttributedString(string: alternateTitle, font: Font.semibold(15.0), textColor: textColor), badge: alternateBadge)
                                )
                            ),
                            AnyComponentWithIdentity(
                                id: "text",
                                component: AnyComponent(
                                    BalancedTextComponent(
                                        text: .markdown(text: textString, attributes: markdownAttributes),
                                        horizontalAlignment: .center,
                                        maximumNumberOfLines: 0,
                                        lineSpacing: 0.1
                                    )
                                )
                            )
                        ],
                        centerAlignment: true
                    ),
                    availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                    transition: .immediate
                )
                context.add(alternateText
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + alternateText.size.height / 2.0))
                    .appear(ComponentTransition.Appear({ _, view, transition in
                        transition.animatePosition(view: view, from: CGPoint(x: 0.0, y: 64.0), to: .zero, additive: true)
                        transition.animateAlpha(view: view, from: 0.0, to: 1.0)
                    }))
                        .disappear(ComponentTransition.Disappear({ view, transition, completion in
                            view.superview?.sendSubviewToBack(view)
                            transition.animatePosition(view: view, from: .zero, to: CGPoint(x: 0.0, y: -64.0), additive: true)
                            transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                                completion()
                            })
                        }))
                )
                contentSize.height += alternateText.size.height + 20.0
            } else {
                let text = text.update(
                    component: BalancedTextComponent(
                        text: .markdown(text: textString, attributes: markdownAttributes),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    ),
                    availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                    transition: .immediate
                )
                context.add(text
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + text.size.height / 2.0))
                    .appear(ComponentTransition.Appear({ _, view, transition in
                        transition.animatePosition(view: view, from: CGPoint(x: 0.0, y: 64.0), to: .zero, additive: true)
                        transition.animateAlpha(view: view, from: 0.0, to: 1.0)
                    }))
                        .disappear(ComponentTransition.Disappear({ view, transition, completion in
                            view.superview?.sendSubviewToBack(view)
                            transition.animatePosition(view: view, from: .zero, to: CGPoint(x: 0.0, y: -64.0), additive: true)
                            transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                                completion()
                            })
                        }))
                )
                contentSize.height += text.size.height + 20.0
            }
                        
            if case .owner = component.mode, let status = component.status {
                contentSize.height += 7.0
                
                let linkButton = linkButton.update(
                    component: SolidRoundedButtonComponent(
                        title: status.url.replacingOccurrences(of: "https://", with: ""),
                        theme: SolidRoundedButtonComponent.Theme(
                            backgroundColor: theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.3),
                            backgroundColors: [],
                            foregroundColor: theme.list.itemPrimaryTextColor
                        ),
                        font: .regular,
                        fontSize: 17.0,
                        height: 50.0,
                        cornerRadius: 10.0,
                        action: {
                            component.copyLink(status.url)
                            component.dismiss()
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                    transition: context.transition
                )
                context.add(linkButton
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + linkButton.size.height / 2.0))
                )
                contentSize.height += linkButton.size.height + 16.0
                
                let boostButton = boostButton.update(
                    component: SolidRoundedButtonComponent(
                        title: strings.ChannelBoost_Boost,
                        theme: SolidRoundedButtonComponent.Theme(
                            backgroundColor: .black,
                            backgroundColors: buttonGradientColors,
                            foregroundColor: .white
                        ),
                        font: .bold,
                        fontSize: 17.0,
                        height: 50.0,
                        cornerRadius: 10.0,
                        gloss: false,
                        iconName: nil,
                        animationName: nil,
                        iconPosition: .left,
                        action: {
                            component.boost()
                        }
                    ),
                    availableSize: CGSize(width: (context.availableSize.width - 8.0 - sideInset * 2.0) / 2.0, height: 50.0),
                    transition: context.transition
                )
                
                let copyButton = copyButton.update(
                    component: SolidRoundedButtonComponent(
                        title: strings.ChannelBoost_Copy,
                        theme: SolidRoundedButtonComponent.Theme(
                            backgroundColor: .black,
                            backgroundColors: buttonGradientColors,
                            foregroundColor: .white
                        ),
                        font: .bold,
                        fontSize: 17.0,
                        height: 50.0,
                        cornerRadius: 10.0,
                        gloss: false,
                        iconName: nil,
                        animationName: nil,
                        iconPosition: .left,
                        action: {
                            component.copyLink(status.url)
                            component.dismiss()
                        }
                    ),
                    availableSize: CGSize(width: (context.availableSize.width - 8.0 - sideInset * 2.0) / 2.0, height: 50.0),
                    transition: context.transition
                )
                
                let boostButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: contentSize.height), size: boostButton.size)
                context.add(boostButton
                    .position(boostButtonFrame.center)
                )
                let copyButtonFrame = CGRect(origin: CGPoint(x: context.availableSize.width - sideInset - copyButton.size.width, y: contentSize.height), size: copyButton.size)
                context.add(copyButton
                    .position(copyButtonFrame.center)
                )
                contentSize.height += boostButton.size.height
                
                if premiumConfiguration.giveawayGiftsPurchaseAvailable {
                    let orText = orText.update(
                        component: MultilineTextComponent(text: .plain(NSAttributedString(string: strings.ChannelBoost_Or, font: Font.regular(15.0), textColor: textColor.withAlphaComponent(0.8), paragraphAlignment: .center))),
                        availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                        transition: .immediate
                    )
                    context.add(orText
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + 27.0))
                    )
                    
                    let orLeftLine = orLeftLine.update(
                        component: Rectangle(color: theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.3)),
                        availableSize: CGSize(width: 90.0, height: 1.0 - UIScreenPixel),
                        transition: .immediate
                    )
                    context.add(orLeftLine
                        .position(CGPoint(x: context.availableSize.width / 2.0 - orText.size.width / 2.0 - 11.0 - 45.0, y: contentSize.height + 27.0))
                    )
                    
                    let orRightLine = orRightLine.update(
                        component: Rectangle(color: theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.3)),
                        availableSize: CGSize(width: 90.0, height: 1.0 - UIScreenPixel),
                        transition: .immediate
                    )
                    context.add(orRightLine
                        .position(CGPoint(x: context.availableSize.width / 2.0 + orText.size.width / 2.0 + 11.0 + 45.0, y: contentSize.height + 27.0))
                    )
                    
                    if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== theme {
                        state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: linkColor)!, theme)
                    }
                    
                    
                    let giftString = isGroup ? strings.Premium_Group_BoostByGiveawayDescription : strings.Premium_BoostByGiveawayDescription
                    let giftAttributedString = parseMarkdownIntoAttributedString(giftString, attributes: markdownAttributes).mutableCopy() as! NSMutableAttributedString
                    
                    if let range = giftAttributedString.string.range(of: ">"), let chevronImage = state.cachedChevronImage?.0 {
                        giftAttributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: giftAttributedString.string))
                    }
                    let giftText = giftText.update(
                        component: BalancedTextComponent(
                            text: .plain(giftAttributedString),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.1,
                            highlightColor: linkColor.withAlphaComponent(0.1),
                            highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                            highlightAction: { _ in
                                return nil
                            },
                            tapAction: { _, _ in
                                component.openGift?()
                            }
                        ),
                        availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                        transition: .immediate
                    )
                    context.add(giftText
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + 50.0 + giftText.size.height / 2.0))
                    )
                    contentSize.height += giftText.size.height + 50.0 + 23.0
                }
            }
            
            var nextLevels: ClosedRange<Int32>?
            if level < 10 {
                nextLevels = Int32(level) + 1 ... 10
            }
                        
            var levelItems: [AnyComponentWithIdentity<Empty>] = []
            
            var nameColorsAtLevel: [(Int32, Int32)] = []
            var nameColorsCountMap: [Int32: Int32] = [:]
            for color in context.component.context.peerNameColors.displayOrder {
                if let level = context.component.context.peerNameColors.nameColorsChannelMinRequiredBoostLevel[color] {
                    if let current = nameColorsCountMap[level] {
                        nameColorsCountMap[level] = current + 1
                    } else {
                        nameColorsCountMap[level] = 1
                    }
                }
            }
            for (key, value) in nameColorsCountMap {
                nameColorsAtLevel.append((key, value))
            }
            
            var profileColorsAtLevel: [(Int32, Int32)] = []
            var profileColorsCountMap: [Int32: Int32] = [:]
            for color in context.component.context.peerNameColors.profileDisplayOrder {
                if let level = isGroup ? context.component.context.peerNameColors.profileColorsGroupMinRequiredBoostLevel[color] : context.component.context.peerNameColors.profileColorsChannelMinRequiredBoostLevel[color]  {
                    if let current = profileColorsCountMap[level] {
                        profileColorsCountMap[level] = current + 1
                    } else {
                        profileColorsCountMap[level] = 1
                    }
                }
            }
            for (key, value) in profileColorsCountMap {
                profileColorsAtLevel.append((key, value))
            }
            
            var isFeatures = false
            if case .features = component.mode {
                isFeatures = true
            }
                        
            
            func layoutLevel(_ level: Int32) {
                var perks: [LevelSectionComponent.Perk] = []
                
                perks.append(.story(level))
                
                if !isGroup {
                    perks.append(.reaction(level))
                }
                
                var nameColorsCount: Int32 = 0
                for (colorLevel, count) in nameColorsAtLevel {
                    if level >= colorLevel && colorLevel == 1 {
                        nameColorsCount = count
                    }
                }
                if !isGroup && nameColorsCount > 0 {
                    perks.append(.nameColor(nameColorsCount))
                }
                
                var profileColorsCount: Int32 = 0
                for (colorLevel, count) in profileColorsAtLevel {
                    if level >= colorLevel {
                        profileColorsCount += count
                    }
                }
                if profileColorsCount > 0 {
                    perks.append(.profileColor(profileColorsCount))
                }
            
                if isGroup && level >= requiredBoostSubjectLevel(subject: .emojiPack, group: isGroup, context: component.context, configuration: premiumConfiguration) {
                    perks.append(.emojiPack)
                }
            
                if level >= requiredBoostSubjectLevel(subject: .profileIcon, group: isGroup, context: component.context, configuration: premiumConfiguration) {
                    perks.append(.profileIcon)
                }
                
                if isGroup && level >= requiredBoostSubjectLevel(subject: .audioTranscription, group: isGroup, context: component.context, configuration: premiumConfiguration) {
                    perks.append(.audioTranscription)
                }
                
                var linkColorsCount: Int32 = 0
                for (colorLevel, count) in nameColorsAtLevel {
                    if level >= colorLevel {
                        linkColorsCount += count
                    }
                }
                if !isGroup && linkColorsCount > 0 {
                    perks.append(.linkColor(linkColorsCount))
                }
                                    
                if !isGroup && level >= requiredBoostSubjectLevel(subject: .nameIcon, group: isGroup, context: component.context, configuration: premiumConfiguration) {
                    perks.append(.linkIcon)
                }
                if level >= requiredBoostSubjectLevel(subject: .emojiStatus, group: isGroup, context: component.context, configuration: premiumConfiguration) {
                    perks.append(.emojiStatus)
                }
                if level >= requiredBoostSubjectLevel(subject: .wallpaper, group: isGroup, context: component.context, configuration: premiumConfiguration) {
                    perks.append(.wallpaper(8))
                }
                if level >= requiredBoostSubjectLevel(subject: .customWallpaper, group: isGroup, context: component.context, configuration: premiumConfiguration) {
                    perks.append(.customWallpaper)
                }
                if !isGroup && level >= requiredBoostSubjectLevel(subject: .noAds, group: isGroup, context: component.context, configuration: premiumConfiguration) {
                    perks.append(.noAds)
                }
//                if !isGroup && level >= requiredBoostSubjectLevel(subject: .wearGift, group: isGroup, context: component.context, configuration: premiumConfiguration) {
//                    perks.append(.wearGift)
//                }
                
                levelItems.append(
                    AnyComponentWithIdentity(
                        id: level, component: AnyComponent(
                            LevelSectionComponent(
                                theme: component.theme,
                                strings: component.strings,
                                level: level,
                                isFirst: !isFeatures && levelItems.isEmpty,
                                perks: perks.reversed(),
                                isGroup: isGroup
                            )
                        )
                    )
                )
            }
            
            if let nextLevels {
                for level in nextLevels {
                    layoutLevel(level)
                }
            }
           
            if !isGroup {
                let noAdsLevel = requiredBoostSubjectLevel(subject: .noAds, group: false, context: component.context, configuration: premiumConfiguration)
                if let nextLevels, noAdsLevel <= nextLevels.upperBound {
                } else if level < noAdsLevel {
                    layoutLevel(noAdsLevel)
                }
            }
            
            if !levelItems.isEmpty {
                let levels = levels.update(
                    component: List(levelItems),
                    availableSize: CGSize(width: context.availableSize.width, height: 100000.0),
                    transition: context.transition
                )
                context.add(levels
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + levels.size.height / 2.0 ))
                )
                contentSize.height += levels.size.height + 80.0
                contentSize.height += 60.0
            }
                        
            return contentSize
        }
    }
}

private final class BoostLevelsContainerComponent: CombinedComponent {
    class ExternalState {
        var isGroup: Bool = false
        var contentHeight: CGFloat = 0.0
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let externalState: ExternalState
    let peerId: EnginePeer.Id
    let mode: PremiumBoostLevelsScreen.Mode
    let status: ChannelBoostStatus?
    let boostState: InternalBoostState.DisplayData?
    let boost: () -> Void
    let copyLink: (String) -> Void
    let dismiss: () -> Void
    let openStats: (() -> Void)?
    let openGift: (() -> Void)?
    let openPeer: ((EnginePeer) -> Void)?
    let updated: () -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        externalState: ExternalState,
        peerId: EnginePeer.Id,
        mode: PremiumBoostLevelsScreen.Mode,
        status: ChannelBoostStatus?,
        boostState: InternalBoostState.DisplayData?,
        boost: @escaping () -> Void,
        copyLink: @escaping (String) -> Void,
        dismiss: @escaping () -> Void,
        openStats: (() -> Void)?,
        openGift: (() -> Void)?,
        openPeer: ((EnginePeer) -> Void)?,
        updated: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.externalState = externalState
        self.peerId = peerId
        self.mode = mode
        self.status = status
        self.boostState = boostState
        self.boost = boost
        self.copyLink = copyLink
        self.dismiss = dismiss
        self.openStats = openStats
        self.openGift = openGift
        self.openPeer = openPeer
        self.updated = updated
    }
    
    static func ==(lhs: BoostLevelsContainerComponent, rhs: BoostLevelsContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        if lhs.status != rhs.status {
            return false
        }
        if lhs.boostState != rhs.boostState {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var topContentOffset: CGFloat = 0.0
        var cachedStatsImage: (UIImage, PresentationTheme)?
        var cachedCloseImage: (UIImage, PresentationTheme)?
        
        var initialized = false
        
        private var disposable: Disposable?
        private(set) var peer: EnginePeer?
        
        init(context: AccountContext, peerId: EnginePeer.Id, updated: @escaping () -> Void) {
            super.init()
            
            self.disposable = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
                guard let self else {
                    return
                }
                self.peer = peer
                updated()
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, peerId: self.peerId, updated: self.updated)
    }
        
    static var body: Body {
        let background = Child(Rectangle.self)
        let scroll = Child(ScrollComponent<Empty>.self)
        let topPanel = Child(BlurredBackgroundComponent.self)
        let topSeparator = Child(Rectangle.self)
        let title = Child(MultilineTextComponent.self)
        let statsButton = Child(Button.self)
        let closeButton = Child(Button.self)
        
        let externalScrollState = ScrollComponent<Empty>.ExternalState()
        
        return { context in
            let state = context.state
            
            let theme = context.component.theme
            let strings = context.component.context.sharedContext.currentPresentationData.with { $0 }.strings
            
            let topInset: CGFloat = 56.0
            
            let component = context.component
            
            var isGroup: Bool?
            if let peer = state.peer {
                if case let .channel(channel) = peer, case .group = channel.info {
                    isGroup = true
                } else {
                    isGroup = false
                }
            }
            
            if let isGroup {
                component.externalState.isGroup = isGroup
                let updated = component.updated
                let scroll = scroll.update(
                    component: ScrollComponent<Empty>(
                        content: AnyComponent(
                            SheetContent(
                                context: component.context,
                                theme: component.theme,
                                strings: component.strings,
                                insets: .zero,
                                peerId: component.peerId,
                                isGroup: isGroup,
                                mode: component.mode,
                                status: component.status,
                                boostState: component.boostState,
                                initialized: state.initialized,
                                boost: component.boost,
                                copyLink: component.copyLink,
                                dismiss: component.dismiss,
                                openStats: component.openStats,
                                openGift: component.openGift,
                                openPeer: component.openPeer,
                                updated: { [weak state] in
                                    state?.initialized = true
                                    updated()
                                }
                            )
                        ),
                        externalState: externalScrollState,
                        contentInsets: UIEdgeInsets(top: topInset, left: 0.0, bottom: 0.0, right: 0.0),
                        contentOffsetUpdated: { [weak state] topContentOffset, _ in
                            state?.topContentOffset = topContentOffset
                            Queue.mainQueue().justDispatch {
                                state?.updated(transition: .immediate)
                            }
                        },
                        contentOffsetWillCommit: { _ in }
                    ),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                component.externalState.contentHeight = externalScrollState.contentHeight
                
                let background = background.update(
                    component: Rectangle(color: theme.overallDarkAppearance ? theme.list.blocksBackgroundColor : theme.list.plainBackgroundColor),
                    availableSize: scroll.size,
                    transition: context.transition
                )
                context.add(background
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: background.size.height / 2.0))
                )
                
                context.add(scroll
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: scroll.size.height / 2.0))
                )
            }
            
            let topPanel = topPanel.update(
                component: BlurredBackgroundComponent(
                    color: theme.rootController.navigationBar.blurredBackgroundColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: topInset),
                transition: context.transition
            )
            
            let topSeparator = topSeparator.update(
                component: Rectangle(
                    color: theme.rootController.navigationBar.separatorColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: UIScreenPixel),
                transition: context.transition
            )
            
            let titleString: String
            var titleFont = Font.semibold(17.0)
            
            switch component.mode {
            case let .owner(subject):
                if let status = component.status, let _ = status.nextLevelBoosts {
                    if let subject {
                        switch subject {
                        case .stories:
                            if status.level == 0 {
                                titleString = strings.ChannelBoost_EnableStories
                            } else {
                                titleString = strings.ChannelBoost_IncreaseLimit
                            }
                        case .nameColors:
                            titleString = strings.ChannelBoost_NameColor
                        case .nameIcon:
                            titleString = strings.ChannelBoost_NameIcon
                        case .profileColors:
                            titleString = strings.ChannelBoost_ProfileColor
                        case .profileIcon:
                            titleString = strings.ChannelBoost_ProfileIcon
                        case .channelReactions:
                            titleString = strings.ChannelBoost_CustomReactions
                        case .emojiStatus:
                            titleString = strings.ChannelBoost_EmojiStatus
                        case .wallpaper:
                            titleString = strings.ChannelBoost_Wallpaper
                        case .customWallpaper:
                            titleString = strings.ChannelBoost_CustomWallpaper
                        case .audioTranscription:
                            titleString = strings.GroupBoost_AudioTranscription
                        case .emojiPack:
                            titleString = strings.GroupBoost_EmojiPack
                        case .noAds:
                            titleString = strings.ChannelBoost_NoAds
                        case .wearGift:
                            titleString = strings.ChannelBoost_WearGift
                        }
                    } else {
                        titleString = isGroup == true ? strings.GroupBoost_Title_Current : strings.ChannelBoost_Title_Current
                    }
                } else {
                    titleString = strings.ChannelBoost_MaxLevelReached
                }
            case let .user(mode):
                var remaining: Int?
                if let status = component.status, let nextLevelBoosts = status.nextLevelBoosts {
                    remaining = nextLevelBoosts - status.boosts
                }
                
                if let _ = remaining {
                    if case .current = mode {
                        titleString = isGroup == true ? strings.GroupBoost_Title_Current : strings.ChannelBoost_Title_Current
                    } else {
                        titleString = isGroup == true ? strings.GroupBoost_Title_Other : strings.ChannelBoost_Title_Other
                    }
                } else {
                    titleString = strings.ChannelBoost_MaxLevelReached
                }
            case .features:
                titleString = strings.GroupBoost_AdditionalFeatures
                titleFont = Font.semibold(20.0)
            }

            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleString, font: titleFont, textColor: theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center,
                    truncationType: .end,
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
                  
            let topPanelAlpha: CGFloat
            let titleOriginY: CGFloat
            let titleScale: CGFloat
            if case .features = component.mode {
                if state.topContentOffset > 78.0 {
                    topPanelAlpha = min(30.0, state.topContentOffset - 78.0) / 30.0
                } else {
                    topPanelAlpha = 0.0
                }
                
                let titleTopOriginY = topPanel.size.height / 2.0
                let titleBottomOriginY: CGFloat = 146.0
                let titleOriginDelta = titleTopOriginY - titleBottomOriginY
                
                let fraction = min(1.0, state.topContentOffset / abs(titleOriginDelta))
                titleOriginY = titleBottomOriginY + fraction * titleOriginDelta
                titleScale = 1.0 - max(0.0, fraction * 0.2)
            } else {
                topPanelAlpha = min(30.0, state.topContentOffset) / 30.0
                titleOriginY = topPanel.size.height / 2.0
                titleScale = 1.0
            }
            
            context.add(topPanel
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topPanel.size.height / 2.0))
                .opacity(topPanelAlpha)
            )
            context.add(topSeparator
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topPanel.size.height))
                .opacity(topPanelAlpha)
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: titleOriginY))
                .scale(titleScale)
            )
            
            if let openStats = component.openStats {
                let statsButton = statsButton.update(
                    component: Button(
                        content: AnyComponent(
                            BundleIconComponent(
                                name: "Premium/Stats",
                                tintColor: component.theme.list.itemAccentColor
                            )
                        ),
                        action: {
                            component.dismiss()
                            Queue.mainQueue().after(0.35) {
                                openStats()
                            }
                        }
                    ).minSize(CGSize(width: 44.0, height: 44.0)),
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                context.add(statsButton
                    .position(CGPoint(x: 31.0, y: 28.0))
                )
            }
            
            let closeImage: UIImage
            if let (image, theme) = state.cachedCloseImage, theme === component.theme {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0x808084, alpha: 0.1), foregroundColor: theme.actionSheet.inputClearButtonColor)!
                state.cachedCloseImage = (closeImage, theme)
            }
            let closeButton = closeButton.update(
                component: Button(
                    content: AnyComponent(Image(image: closeImage)),
                    action: {
                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: context.availableSize.width - closeButton.size.width, y: 28.0))
            )
            
            return context.availableSize
        }
    }
}

public class PremiumBoostLevelsScreen: ViewController {
    public enum Mode: Equatable {
        public enum UserMode: Equatable {
            case external
            case current
            case groupPeer(EnginePeer.Id, Int)
            case unrestrict(Int)
        }
        case user(mode: UserMode)
        case owner(subject: BoostSubject?)
        case features
    }
    
    final class Node: ViewControllerTracingNode, ASScrollViewDelegate, ASGestureRecognizerDelegate {
        private var presentationData: PresentationData
        private weak var controller: PremiumBoostLevelsScreen?
                
        let dim: ASDisplayNode
        let wrappingView: UIView
        let containerView: UIView
        
        let contentView: ComponentHostView<Empty>
        let footerContainerView: UIView
        let footerView: ComponentHostView<Empty>
                
        private let containerExternalState = BoostLevelsContainerComponent.ExternalState()
        
        private(set) var isExpanded = false
        private var panGestureRecognizer: UIPanGestureRecognizer?
        private var panGestureArguments: (topInset: CGFloat, offset: CGFloat, scrollView: UIScrollView?)?
        
        private let hapticFeedback = HapticFeedback()
        
        private var currentIsVisible: Bool = false
        private var currentLayout: ContainerViewLayout?
                        
        init(context: AccountContext, controller: PremiumBoostLevelsScreen) {
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
            if controller.forceDark {
                self.presentationData = self.presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
            }
            self.presentationData = self.presentationData.withUpdated(theme: self.presentationData.theme.withModalBlocksBackground())
            
            self.controller = controller
            
            self.dim = ASDisplayNode()
            self.dim.alpha = 0.0
            self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
            
            self.wrappingView = UIView()
            self.containerView = UIView()
            self.contentView = ComponentHostView()
            
            self.footerContainerView = UIView()
            self.footerView = ComponentHostView()
            
            super.init()
                        
            self.containerView.clipsToBounds = true
            self.containerView.backgroundColor = self.presentationData.theme.overallDarkAppearance ? self.presentationData.theme.list.blocksBackgroundColor : self.presentationData.theme.list.plainBackgroundColor
            
            self.addSubnode(self.dim)
            
            self.view.addSubview(self.wrappingView)
            self.wrappingView.addSubview(self.containerView)
            self.containerView.addSubview(self.contentView)
            
            if case .user = controller.mode {
                self.containerView.addSubview(self.footerContainerView)
                self.footerContainerView.addSubview(self.footerView)
            }
            
            if let status = controller.status, let myBoostStatus = controller.myBoostStatus {
                var myBoostCount: Int32 = 0
                var currentMyBoostCount: Int32 = 0
                var availableBoosts: [MyBoostStatus.Boost] = []
                var occupiedBoosts: [MyBoostStatus.Boost] = []
                
                for boost in myBoostStatus.boosts {
                    if let boostPeer = boost.peer {
                        if boostPeer.id == controller.peerId {
                            myBoostCount += 1
                        } else {
                            occupiedBoosts.append(boost)
                        }
                    } else {
                        availableBoosts.append(boost)
                    }
                }
                
                let boosts = max(Int32(status.boosts), myBoostCount)
                let initialState = InternalBoostState(level: Int32(status.level), currentLevelBoosts: Int32(status.currentLevelBoosts), nextLevelBoosts: status.nextLevelBoosts.flatMap(Int32.init), boosts: boosts)
                self.boostState = initialState.displayData(myBoostCount: myBoostCount, currentMyBoostCount: 0, replacedBoosts: controller.replacedBoosts?.0)
                
                self.updatedState.set(.single(InternalBoostState(level: Int32(status.level), currentLevelBoosts: Int32(status.currentLevelBoosts), nextLevelBoosts: status.nextLevelBoosts.flatMap(Int32.init), boosts: boosts + 1)))
                
                if let (replacedBoosts, sourcePeers) = controller.replacedBoosts {
                    currentMyBoostCount += 1
                    
                    self.boostState = initialState.displayData(myBoostCount: myBoostCount, currentMyBoostCount: 1)
                    Queue.mainQueue().justDispatch {
                        self.updated(transition: .easeInOut(duration: 0.2))
                    }
                                        
                    Queue.mainQueue().after(0.3) {
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        
                        var groupCount: Int32 = 0
                        var channelCount: Int32 = 0
                        for peer in sourcePeers {
                            if case let .channel(channel) = peer {
                                switch channel.info {
                                case .broadcast:
                                    channelCount += 1
                                case .group:
                                    groupCount += 1
                                }
                            }
                        }
                        let otherText: String
                        if channelCount > 0 && groupCount == 0 {
                            otherText = presentationData.strings.ReassignBoost_OtherChannels(channelCount)
                        } else if groupCount > 0 && channelCount == 0 {
                            otherText = presentationData.strings.ReassignBoost_OtherGroups(groupCount)
                        } else {
                            otherText = presentationData.strings.ReassignBoost_OtherGroupsAndChannels(Int32(sourcePeers.count))
                        }
                        let text = presentationData.strings.ReassignBoost_Success(presentationData.strings.ReassignBoost_Boosts(replacedBoosts), otherText).string
                        let undoController = UndoOverlayController(presentationData: presentationData, content:  .universal(animation: "BoostReplace", scale: 0.066, colors: [:], title: nil, text: text, customUndoText: nil, timeout: 4.0), elevatedLayout: false, position: .top, action: { _ in return true })
                        controller.present(undoController, in: .current)
                    }
                }
                
                self.availableBoosts = availableBoosts
                self.occupiedBoosts = occupiedBoosts
                self.myBoostCount = myBoostCount
                self.currentMyBoostCount = currentMyBoostCount
            }
        }
        
        override func didLoad() {
            super.didLoad()
            
            let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            panRecognizer.delegate = self.wrappedGestureRecognizerDelegate
            panRecognizer.delaysTouchesBegan = false
            panRecognizer.cancelsTouchesInView = true
            self.panGestureRecognizer = panRecognizer
            self.wrappingView.addGestureRecognizer(panRecognizer)
            
            self.dim.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            self.controller?.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.controller?.dismiss(animated: true)
            }
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let layout = self.currentLayout {
                if case .regular = layout.metrics.widthClass {
                    return false
                }
            }
            return true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
                if let scrollView = otherGestureRecognizer.view as? UIScrollView {
                    if scrollView.contentSize.width > scrollView.contentSize.height {
                        return false
                    }
                }
                return true
            }
            return false
        }
        
        private var isDismissing = false
        func animateIn() {
            ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear).updateAlpha(node: self.dim, alpha: 1.0)
            
            let targetPosition = self.containerView.center
            let startPosition = targetPosition.offsetBy(dx: 0.0, dy: self.bounds.height)
            
            self.containerView.center = startPosition
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            transition.animateView(allowUserInteraction: true, {
                self.containerView.center = targetPosition
            }, completion: { _ in
            })
        }
        
        func animateOut(completion: @escaping () -> Void = {}) {
            self.isDismissing = true
            
            let positionTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            positionTransition.updatePosition(layer: self.containerView.layer, position: CGPoint(x: self.containerView.center.x, y: self.bounds.height + self.containerView.bounds.height / 2.0), completion: { [weak self] _ in
                self?.controller?.dismiss(animated: false, completion: completion)
            })
            let alphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            alphaTransition.updateAlpha(node: self.dim, alpha: 0.0)
            
            self.controller?.updateModalStyleOverlayTransitionFactor(0.0, transition: positionTransition)
        }
        
        func requestLayout(transition: ComponentTransition) {
            guard let layout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, forceUpdate: true, transition: transition)
        }
                
        private var dismissOffset: CGFloat?
        func containerLayoutUpdated(layout: ContainerViewLayout, forceUpdate: Bool = false, transition: ComponentTransition) {
            guard !self.isDismissing else {
                return
            }
            self.currentLayout = layout
            
            self.dim.frame = CGRect(origin: CGPoint(x: 0.0, y: -layout.size.height), size: CGSize(width: layout.size.width, height: layout.size.height * 3.0))
                                  
            let isLandscape = layout.orientation == .landscape
            
            var containerTopInset: CGFloat = 0.0
            let clipFrame: CGRect
            if layout.metrics.widthClass == .compact {
                self.dim.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.25)
                if isLandscape {
                    self.containerView.layer.cornerRadius = 0.0
                } else {
                    self.containerView.layer.cornerRadius = 10.0
                }
                
                if #available(iOS 11.0, *) {
                    if layout.safeInsets.bottom.isZero {
                        self.containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                    } else {
                        self.containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                    }
                }
                
                if isLandscape {
                    clipFrame = CGRect(origin: CGPoint(), size: layout.size)
                } else {
                    let coveredByModalTransition: CGFloat = 0.0
                    containerTopInset = 10.0
                    if let statusBarHeight = layout.statusBarHeight {
                        containerTopInset += statusBarHeight
                    }
                                        
                    let unscaledFrame = CGRect(origin: CGPoint(x: 0.0, y: containerTopInset - coveredByModalTransition * 10.0), size: CGSize(width: layout.size.width, height: layout.size.height - containerTopInset))
                    let maxScale: CGFloat = (layout.size.width - 16.0 * 2.0) / layout.size.width
                    let containerScale = 1.0 * (1.0 - coveredByModalTransition) + maxScale * coveredByModalTransition
                    let maxScaledTopInset: CGFloat = containerTopInset - 10.0
                    let scaledTopInset: CGFloat = containerTopInset * (1.0 - coveredByModalTransition) + maxScaledTopInset * coveredByModalTransition
                    let containerFrame = unscaledFrame.offsetBy(dx: 0.0, dy: scaledTopInset - (unscaledFrame.midY - containerScale * unscaledFrame.height / 2.0))
                    
                    clipFrame = CGRect(x: containerFrame.minX, y: containerFrame.minY, width: containerFrame.width, height: containerFrame.height)
                }
            } else {
                self.dim.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.4)
                self.containerView.layer.cornerRadius = 10.0
  
                let verticalInset: CGFloat = 44.0
                
                let maxSide = max(layout.size.width, layout.size.height)
                let minSide = min(layout.size.width, layout.size.height)
                let containerSize = CGSize(width: min(layout.size.width - 20.0, floor(maxSide / 2.0)), height: min(layout.size.height, minSide) - verticalInset * 2.0)
                clipFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - containerSize.width) / 2.0), y: floor((layout.size.height - containerSize.height) / 2.0)), size: containerSize)
            }
            
            transition.setFrame(view: self.containerView, frame: clipFrame)
            
            var effectiveExpanded = self.isExpanded
            if case .regular = layout.metrics.widthClass {
                effectiveExpanded = true
            }
        
            self.updated(transition: transition, forceUpdate: forceUpdate)
                        
            let contentHeight = self.containerExternalState.contentHeight
            if contentHeight > 0.0 && contentHeight < 400.0, let view = self.footerView.componentView as? FooterComponent.View {
                view.backgroundView.alpha = 0.0
                view.separator.opacity = 0.0
            }
            let edgeTopInset = isLandscape ? 0.0 : self.defaultTopInset

            let topInset: CGFloat
            if let (panInitialTopInset, panOffset, _) = self.panGestureArguments {
                if effectiveExpanded {
                    topInset = min(edgeTopInset, panInitialTopInset + max(0.0, panOffset))
                } else {
                    topInset = max(0.0, panInitialTopInset + min(0.0, panOffset))
                }
            } else if let dismissOffset = self.dismissOffset, !dismissOffset.isZero {
                topInset = edgeTopInset * dismissOffset
            } else {
                topInset = effectiveExpanded ? 0.0 : edgeTopInset
            }
            transition.setFrame(view: self.wrappingView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: layout.size), completion: nil)
            
            let modalProgress = isLandscape ? 0.0 : (1.0 - topInset / self.defaultTopInset)
            self.controller?.updateModalStyleOverlayTransitionFactor(modalProgress, transition: transition.containedViewLayoutTransition)
            
            let footerHeight = self.footerHeight
            let convertedFooterFrame = self.view.convert(CGRect(origin: CGPoint(x: clipFrame.minX, y: clipFrame.maxY - footerHeight), size: CGSize(width: clipFrame.width, height: footerHeight)), to: self.containerView)
            transition.setFrame(view: self.footerContainerView, frame: convertedFooterFrame)
        }
        
        private var boostState: InternalBoostState.DisplayData?
        func updated(transition: ComponentTransition, forceUpdate: Bool = false) {
            guard let controller = self.controller else {
                return
            }
            let contentSize = self.contentView.update(
                transition: transition,
                component: AnyComponent(
                    BoostLevelsContainerComponent(
                        context: controller.context,
                        theme: self.presentationData.theme,
                        strings: self.presentationData.strings,
                        externalState: self.containerExternalState,
                        peerId: controller.peerId,
                        mode: controller.mode,
                        status: controller.status,
                        boostState: self.boostState,
                        boost: { [weak controller] in
                            guard let controller else {
                                return
                            }
                            controller.node.updateBoostState()
                        },
                        copyLink: { [weak self, weak controller] link in
                            guard let self else {
                                return
                            }
                            UIPasteboard.general.string = link
                            
                            if let previousController = controller?.navigationController?.viewControllers.reversed().first(where: { $0 !== controller }) as? ViewController {
                                previousController.present(UndoOverlayController(presentationData: self.presentationData, content: .linkCopied(title: nil, text: self.presentationData.strings.ChannelBoost_BoostLinkCopied), elevatedLayout: true, position: .top, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                            }
                        },
                        dismiss: { [weak controller] in
                            controller?.dismiss(animated: true)
                        },
                        openStats: controller.openStats,
                        openGift: controller.openGift,
                        openPeer: controller.openPeer,
                        updated: { [weak self] in
                            self?.requestLayout(transition: .immediate)
                        }
                    )
                ),
                environment: {},
                forceUpdate: forceUpdate,
                containerSize: self.containerView.bounds.size
            )
            self.contentView.frame = CGRect(origin: .zero, size: contentSize)
            
            let footerHeight = self.footerHeight
            
            let actionTitle: String
            if self.currentMyBoostCount > 0 {
                actionTitle = self.presentationData.strings.ChannelBoost_BoostAgain
            } else {
                actionTitle = self.containerExternalState.isGroup ? self.presentationData.strings.GroupBoost_BoostGroup : self.presentationData.strings.ChannelBoost_BoostChannel
            }
            
            let footerSize = self.footerView.update(
                transition: .immediate,
                component: AnyComponent(
                    FooterComponent(
                        context: controller.context,
                        theme: self.presentationData.theme,
                        title: actionTitle,
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.buttonPressed()
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: self.containerView.bounds.width, height: footerHeight)
            )
            self.footerView.frame = CGRect(origin: .zero, size: footerSize)
        }
        
        private var didPlayAppearAnimation = false
        func updateIsVisible(isVisible: Bool) {
            if self.currentIsVisible == isVisible {
                return
            }
            self.currentIsVisible = isVisible
            
            guard let layout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, transition: .immediate)
            
            if !self.didPlayAppearAnimation {
                self.didPlayAppearAnimation = true
                self.animateIn()
            }
        }
        
        private var footerHeight: CGFloat {
            if let mode = self.controller?.mode, case .owner = mode {
                return 0.0
            }
            
            guard let layout = self.currentLayout else {
                return 58.0
            }
                        
            var footerHeight: CGFloat = 8.0 + 50.0
            footerHeight += layout.intrinsicInsets.bottom > 0.0 ? layout.intrinsicInsets.bottom + 5.0 : 8.0
            return footerHeight
        }
        
        private var defaultTopInset: CGFloat {
            guard let layout = self.currentLayout else {
                return 210.0
            }
            if case .compact = layout.metrics.widthClass {
                let bottomPanelPadding: CGFloat = 12.0
                let bottomInset: CGFloat = layout.intrinsicInsets.bottom > 0.0 ? layout.intrinsicInsets.bottom + 5.0 : bottomPanelPadding
                let panelHeight: CGFloat = bottomPanelPadding + 50.0 + bottomInset + 28.0
                
                var defaultTopInset = layout.size.height - layout.size.width - 128.0 - panelHeight
                
                let containerTopInset = 10.0 + (layout.statusBarHeight ?? 0.0)
                let contentHeight = self.containerExternalState.contentHeight
                let footerHeight = self.footerHeight
                if contentHeight > 0.0 {
                    let delta = (layout.size.height - defaultTopInset - containerTopInset) - contentHeight - footerHeight - 16.0
                    if delta > 0.0 {
                        defaultTopInset += delta
                    }
                }
                return defaultTopInset
            } else {
                return 210.0
            }
        }
        
        private func findVerticalScrollView(view: UIView?) -> UIScrollView? {
            if let view = view {
                if let view = view as? UIScrollView, view.contentSize.height > view.contentSize.width {
                    return view
                }
                return findVerticalScrollView(view: view.superview)
            } else {
                return nil
            }
        }
        
        @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
            guard let layout = self.currentLayout else {
                return
            }
            
            let isLandscape = layout.orientation == .landscape
            let edgeTopInset = isLandscape ? 0.0 : defaultTopInset
        
            switch recognizer.state {
                case .began:
                    let point = recognizer.location(in: self.view)
                    let currentHitView = self.hitTest(point, with: nil)
                    
                    var scrollView = self.findVerticalScrollView(view: currentHitView)
                    if scrollView?.frame.height == self.frame.width {
                        scrollView = nil
                    }
                    if scrollView?.isDescendant(of: self.view) == false {
                        scrollView = nil
                    }
                                
                    let topInset: CGFloat
                    if self.isExpanded {
                        topInset = 0.0
                    } else {
                        topInset = edgeTopInset
                    }
                
                    self.panGestureArguments = (topInset, 0.0, scrollView)
                case .changed:
                    guard let (topInset, panOffset, scrollView) = self.panGestureArguments else {
                        return
                    }
                    let contentOffset = scrollView?.contentOffset.y ?? 0.0
                    
                    var translation = recognizer.translation(in: self.view).y

                    var currentOffset = topInset + translation
                
                    let epsilon = 1.0
                    if let scrollView = scrollView, contentOffset <= -scrollView.contentInset.top + epsilon {
                        scrollView.bounces = false
                        scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                    } else if let scrollView = scrollView {
                        translation = panOffset
                        currentOffset = topInset + translation
                        if self.isExpanded {
                            recognizer.setTranslation(CGPoint(), in: self.view)
                        } else if currentOffset > 0.0 {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                    }
                
                    if scrollView == nil {
                        translation = max(0.0, translation)
                    }
                    
                    self.panGestureArguments = (topInset, translation, scrollView)
                    
                    if !self.isExpanded {
                        if currentOffset > 0.0, let scrollView = scrollView {
                            scrollView.panGestureRecognizer.setTranslation(CGPoint(), in: scrollView)
                        }
                    }
                
                    var bounds = self.bounds
                    if self.isExpanded {
                        bounds.origin.y = -max(0.0, translation - edgeTopInset)
                    } else {
                        bounds.origin.y = -translation
                    }
                    bounds.origin.y = min(0.0, bounds.origin.y)
                    self.bounds = bounds
                
                    self.containerLayoutUpdated(layout: layout, transition: .immediate)
                case .ended:
                    guard let (currentTopInset, panOffset, scrollView) = self.panGestureArguments else {
                        return
                    }
                    self.panGestureArguments = nil
                
                    let contentOffset = scrollView?.contentOffset.y ?? 0.0
                
                    let translation = recognizer.translation(in: self.view).y
                    var velocity = recognizer.velocity(in: self.view)
                    
                    if self.isExpanded {
                        if contentOffset > 0.1 {
                            velocity = CGPoint()
                        }
                    }
                
                    var bounds = self.bounds
                    if self.isExpanded {
                        bounds.origin.y = -max(0.0, translation - edgeTopInset)
                    } else {
                        bounds.origin.y = -translation
                    }
                    bounds.origin.y = min(0.0, bounds.origin.y)
                
                    scrollView?.bounces = true
                
                    let offset = currentTopInset + panOffset
                    let topInset: CGFloat = edgeTopInset

                    var dismissing = false
                    if bounds.minY < -60 || (bounds.minY < 0.0 && velocity.y > 300.0) || (self.isExpanded && bounds.minY.isZero && velocity.y > 1800.0) {
                        self.controller?.dismiss(animated: true, completion: nil)
                        dismissing = true
                    } else if self.isExpanded {
                        if velocity.y > 300.0 || offset > topInset / 2.0 {
                            self.isExpanded = false
                            if let scrollView = scrollView {
                                scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                            }
                            
                            let distance = topInset - offset
                            let initialVelocity: CGFloat = distance.isZero ? 0.0 : abs(velocity.y / distance)
                            let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))

                            self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(transition))
                        } else {
                            self.isExpanded = true
                            
                            self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(.animated(duration: 0.3, curve: .easeInOut)))
                        }
                    } else if scrollView != nil, (velocity.y < -300.0 || offset < topInset / 2.0) {
                        let initialVelocity: CGFloat = offset.isZero ? 0.0 : abs(velocity.y / offset)
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))
                        self.isExpanded = true
                       
                        self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(transition))
                    } else {
                        if let scrollView = scrollView {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                        
                        self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(.animated(duration: 0.3, curve: .easeInOut)))
                    }
                    
                    if !dismissing {
                        var bounds = self.bounds
                        let previousBounds = bounds
                        bounds.origin.y = 0.0
                        self.bounds = bounds
                        self.layer.animateBounds(from: previousBounds, to: self.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    }
                case .cancelled:
                    self.panGestureArguments = nil
                    
                    self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(.animated(duration: 0.3, curve: .easeInOut)))
                default:
                    break
            }
        }
        
        func updateDismissOffset(_ offset: CGFloat) {
            guard self.isExpanded, let layout = self.currentLayout else {
                return
            }
            
            self.dismissOffset = offset
            self.containerLayoutUpdated(layout: layout, transition: .immediate)
        }
        
        func update(isExpanded: Bool, transition: ContainedViewLayoutTransition) {
            guard isExpanded != self.isExpanded else {
                return
            }
            self.dismissOffset = nil
            self.isExpanded = isExpanded
            
            guard let layout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(transition))
        }
        
        private var currentMyBoostCount: Int32 = 0
        private var myBoostCount: Int32 = 0
        private var availableBoosts: [MyBoostStatus.Boost] = []
        private var occupiedBoosts: [MyBoostStatus.Boost] = []
        private let updatedState = Promise<InternalBoostState?>()
        
        private func updateBoostState() {
            guard let controller = self.controller else {
                return
            }
            let context = controller.context
            let peerId = controller.peerId
            let mode = controller.mode
            let status = controller.status
            let isPremium = controller.context.isPremium
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with({ $0 }))
            let canBoostAgain = premiumConfiguration.boostsPerGiftCount > 0
            let presentationData = self.presentationData
            let forceDark = controller.forceDark
            let boostStatusUpdated = controller.boostStatusUpdated
            
            if let _ = status?.nextLevelBoosts {
                if let availableBoost = self.availableBoosts.first {
                    self.currentMyBoostCount += 1
                    self.myBoostCount += 1
                    
                    let _ = (context.engine.peers.applyChannelBoost(peerId: peerId, slots: [availableBoost.slot])
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] myBoostStatus in
                        self?.updatedState.set(context.engine.peers.getChannelBoostStatus(peerId: peerId)
                        |> beforeNext { [weak self] boostStatus in
                            if let self, let boostStatus, let myBoostStatus {
                                Queue.mainQueue().async {
                                    self.controller?.boostStatusUpdated(boostStatus, myBoostStatus)
                                }
                            }
                        }
                        |> map { status in
                            if let status {
                                return InternalBoostState(level: Int32(status.level), currentLevelBoosts: Int32(status.currentLevelBoosts), nextLevelBoosts: status.nextLevelBoosts.flatMap(Int32.init), boosts: Int32(status.boosts + 1))
                            } else {
                                return nil
                            }
                        })
                    })
                   
                    let _ = (self.updatedState.get()
                    |> take(1)
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] state in
                        guard let self, let state else {
                            return
                        }
                        self.boostState = state.displayData(myBoostCount: self.myBoostCount, currentMyBoostCount: self.currentMyBoostCount)
                        self.updated(transition: .easeInOut(duration: 0.2))
                        
                        self.animateSuccess()
                    })
                    
                    self.availableBoosts.removeFirst()
                } else if !self.occupiedBoosts.isEmpty, let myBoostStatus = controller.myBoostStatus {
                    if canBoostAgain {
                        let navigationController = controller.navigationController
                        let openPeer = controller.openPeer
                        
                        var dismissReplaceImpl: (() -> Void)?
                        let replaceController = ReplaceBoostScreen(context: context, peerId: peerId, myBoostStatus: myBoostStatus, replaceBoosts: { slots in
                            var sourcePeerIds = Set<EnginePeer.Id>()
                            var sourcePeers: [EnginePeer] = []
                            for boost in myBoostStatus.boosts {
                                if slots.contains(boost.slot) {
                                    if let peer = boost.peer {
                                        if !sourcePeerIds.contains(peer.id) {
                                            sourcePeerIds.insert(peer.id)
                                            sourcePeers.append(peer)
                                        }
                                    }
                                }
                            }
                            
                            let _ = context.engine.peers.applyChannelBoost(peerId: peerId, slots: slots).startStandalone(completed: {
                                let _ = combineLatest(
                                    queue: Queue.mainQueue(),
                                    context.engine.peers.getChannelBoostStatus(peerId: peerId),
                                    context.engine.peers.getMyBoostStatus()
                                ).startStandalone(next: { boostStatus, myBoostStatus in
                                    dismissReplaceImpl?()
                                    
                                    if let boostStatus, let myBoostStatus {
                                        boostStatusUpdated(boostStatus, myBoostStatus)
                                    }
                                    
                                    let levelsController = PremiumBoostLevelsScreen(
                                        context: context,
                                        peerId: peerId,
                                        mode: mode,
                                        status: boostStatus,
                                        myBoostStatus: myBoostStatus,
                                        replacedBoosts: (Int32(slots.count), sourcePeers),
                                        openStats: nil, 
                                        openGift: nil,
                                        openPeer: openPeer,
                                        forceDark: forceDark
                                    )
                                    levelsController.boostStatusUpdated = boostStatusUpdated
                                    if let navigationController {
                                        navigationController.pushViewController(levelsController, animated: true)
                                    }
                                })
                            })
                        })
                        
                        if let navigationController = controller.navigationController {
                            controller.dismiss(animated: true)
                            navigationController.pushViewController(replaceController, animated: true)
                        }
                        
                        dismissReplaceImpl = { [weak replaceController] in
                            replaceController?.dismiss(animated: true)
                        }
                    } else if let boost = self.occupiedBoosts.first, let occupiedPeer = boost.peer {
                        if let cooldown = boost.cooldownUntil {
                            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                            let timeout = cooldown - currentTime
                            let valueText = timeIntervalString(strings: presentationData.strings, value: timeout, usage: .afterTime, preferLowerValue: false)
                            let alertController = textAlertController(
                                sharedContext: context.sharedContext,
                                updatedPresentationData: nil,
                                title: presentationData.strings.ChannelBoost_Error_BoostTooOftenTitle,
                                text: self.containerExternalState.isGroup ? presentationData.strings.GroupBoost_Error_BoostTooOftenText(valueText).string : presentationData.strings.ChannelBoost_Error_BoostTooOftenText(valueText).string,
                                actions: [
                                    TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                                ],
                                parseMarkdown: true
                            )
                            controller.present(alertController, in: .window(.root))
                        } else {
                            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                            |> deliverOnMainQueue).start(next: { [weak controller] peer in
                                guard let peer, let controller else {
                                    return
                                }
                                let replaceController = replaceBoostConfirmationController(context: context, fromPeers: [occupiedPeer], toPeer: peer, commit: { [weak self] in
                                    self?.currentMyBoostCount += 1
                                    self?.myBoostCount += 1
                                    let _ = (context.engine.peers.applyChannelBoost(peerId: peerId, slots: [boost.slot])
                                    |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                                        guard let self else {
                                            return
                                        }
                                        let _ = (self.updatedState.get()
                                        |> take(1)
                                        |> deliverOnMainQueue).startStandalone(next: { [weak self] state in
                                            guard let self, let state else {
                                                return
                                            }
                                            self.boostState = state.displayData(myBoostCount: self.myBoostCount, currentMyBoostCount: self.currentMyBoostCount)
                                            self.updated(transition: .easeInOut(duration: 0.2))
                                            
                                            self.animateSuccess()
                                        })
                                    })
                                })
                                controller.present(replaceController, in: .window(.root))
                            })
                        }
                    } else {
                        controller.dismiss(animated: true, completion: nil)
                    }
                } else {
                    if isPremium {
                        if !canBoostAgain {
                            controller.dismiss(animated: true, completion: nil)
                        } else {
                            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                            |> deliverOnMainQueue).start(next: { [weak controller] peer in
                                guard let peer, let controller else {
                                    return
                                }
                                let alertController = textAlertController(
                                    sharedContext: context.sharedContext,
                                    updatedPresentationData: nil,
                                    title: presentationData.strings.ChannelBoost_MoreBoosts_Title,
                                    text: presentationData.strings.ChannelBoost_MoreBoosts_Text(peer.compactDisplayTitle, "\(premiumConfiguration.boostsPerGiftCount)").string,
                                    actions: [
                                        TextAlertAction(type: .defaultAction, title: presentationData.strings.ChannelBoost_MoreBoosts_Gift, action: { [weak controller] in
                                            if let navigationController = controller?.navigationController {
                                                controller?.dismiss(animated: true, completion: nil)
                                                
                                                Queue.mainQueue().after(0.4) {
                                                    let giftController = context.sharedContext.makePremiumGiftController(context: context, source: .channelBoost, completion: nil)
                                                    navigationController.pushViewController(giftController, animated: true)
                                                }
                                            }
                                        }),
                                        TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Close, action: {})
                                    ],
                                    actionLayout: .vertical,
                                    parseMarkdown: true
                                )
                                controller.present(alertController, in: .window(.root))
                            })
                        }
                    } else {
                        let alertController = textAlertController(
                            sharedContext: context.sharedContext,
                            updatedPresentationData: nil,
                            title: presentationData.strings.ChannelBoost_Error_PremiumNeededTitle,
                            text: self.containerExternalState.isGroup ? presentationData.strings.GroupBoost_Error_PremiumNeededText :  presentationData.strings.ChannelBoost_Error_PremiumNeededText,
                            actions: [
                                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                                TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Yes, action: { [weak controller] in
                                    if let navigationController = controller?.navigationController {
                                        controller?.dismiss(animated: true)
                                        
                                        let premiumController = context.sharedContext.makePremiumIntroController(context: context, source: .channelBoost(peerId), forceDark: forceDark, dismissed: nil)
                                        navigationController.pushViewController(premiumController, animated: true)
                                    }
                                })
                            ],
                            parseMarkdown: true
                        )
                        controller.present(alertController, in: .window(.root))
                    }
                }
            } else {
                controller.dismiss(animated: true)
            }
        }
        
        func buttonPressed() {
            self.updateBoostState()
        }
        
        private func animateSuccess() {
            self.hapticFeedback.impact()
            self.view.addSubview(ConfettiView(frame: self.view.bounds))
            
            if self.isExpanded {
                self.update(isExpanded: false, transition: .animated(duration: 0.4, curve: .spring))
            }
        }
    }
    
    var node: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private let mode: Mode
    private let status: ChannelBoostStatus?
    private let myBoostStatus: MyBoostStatus?
    private let replacedBoosts: (Int32, [EnginePeer])?
    private let openStats: (() -> Void)?
    private let openGift: (() -> Void)?
    private let openPeer: ((EnginePeer) -> Void)?
    private let forceDark: Bool
    
    private var currentLayout: ContainerViewLayout?
        
    public var boostStatusUpdated: (ChannelBoostStatus, MyBoostStatus) -> Void = { _, _ in }
    public var disposed: () -> Void = {}
    
    public init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        mode: Mode,
        status: ChannelBoostStatus?,
        myBoostStatus: MyBoostStatus? = nil,
        replacedBoosts: (Int32, [EnginePeer])? = nil,
        openStats: (() -> Void)? = nil,
        openGift: (() -> Void)? = nil,
        openPeer: ((EnginePeer) -> Void)? = nil,
        forceDark: Bool = false
    ) {
        self.context = context
        self.peerId = peerId
        self.mode = mode
        self.status = status
        self.myBoostStatus = myBoostStatus
        self.replacedBoosts = replacedBoosts
        self.openStats = openStats
        self.openGift = openGift
        self.openPeer = openPeer
        self.forceDark = forceDark
        
        super.init(navigationBarPresentationData: nil)
        
        self.navigationPresentation = .flatModal
        self.statusBar.statusBarStyle = .Ignore
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }
        
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposed()
    }

    override open func loadDisplayNode() {
        self.displayNode = Node(context: self.context, controller: self)
        self.displayNodeDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        self.view.endEditing(true)
        if flag {
            self.node.animateOut(completion: {
                super.dismiss(animated: false, completion: {})
                completion?()
            })
        } else {
            super.dismiss(animated: false, completion: {})
            completion?()
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.node.updateIsVisible(isVisible: true)
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
                
        self.node.updateIsVisible(isVisible: false)
    }
        
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.currentLayout = layout
        super.containerLayoutUpdated(layout, transition: transition)
                
        self.node.containerLayoutUpdated(layout: layout, transition: ComponentTransition(transition))
    }
}

private final class FooterComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let title: String
    let action: () -> Void

    init(context: AccountContext, theme: PresentationTheme, title: String, action: @escaping () -> Void) {
        self.context = context
        self.theme = theme
        self.title = title
        self.action = action
    }

    static func ==(lhs: FooterComponent, rhs: FooterComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        return true
    }

    final class View: UIView {
        let backgroundView: BlurredBackgroundView
        let separator = SimpleLayer()
        
        private let button = ComponentView<Empty>()
        
        private var component: FooterComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: nil)
            
            super.init(frame: frame)
            
            self.backgroundView.clipsToBounds = true
            
            self.addSubview(self.backgroundView)
            self.layer.addSublayer(self.separator)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: FooterComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let bounds = CGRect(origin: .zero, size: availableSize)
            
            self.backgroundView.updateColor(color: component.theme.rootController.tabBar.backgroundColor, transition: transition.containedViewLayoutTransition)
            self.backgroundView.update(size: bounds.size, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.backgroundView, frame: bounds)
            
            self.separator.backgroundColor = component.theme.rootController.tabBar.separatorColor.cgColor
            transition.setFrame(layer: self.separator, frame: CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
            let gradientColors = [
                UIColor(rgb: 0x0077ff),
                UIColor(rgb: 0x6b93ff),
                UIColor(rgb: 0x8878ff),
                UIColor(rgb: 0xe46ace)
            ]
            
            let buttonSize = self.button.update(
                transition: .immediate,
                component: AnyComponent(
                    SolidRoundedButtonComponent(
                        title: component.title,
                        theme: SolidRoundedButtonComponent.Theme(
                            backgroundColor: .black,
                            backgroundColors: gradientColors,
                            foregroundColor: .white
                        ),
                        font: .bold,
                        fontSize: 17.0,
                        height: 50.0,
                        cornerRadius: 10.0,
                        gloss: true,
                        iconName: "Premium/BoostChannel",
                        animationName: nil,
                        iconPosition: .left,
                        action: {
                            component.action()
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: availableSize.height)
            )
            
            if let view = self.button.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                let buttonFrame = CGRect(origin: CGPoint(x: 16.0, y: 8.0), size: buttonSize)
                view.frame = buttonFrame
            }
                        
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private struct InternalBoostState: Equatable {
    let level: Int32
    let currentLevelBoosts: Int32
    let nextLevelBoosts: Int32?
    let boosts: Int32
    
    struct DisplayData: Equatable {
        let level: Int32
        let boosts: Int32
        let currentLevelBoosts: Int32
        let nextLevelBoosts: Int32?
        let myBoostCount: Int32
    }
    
    func displayData(myBoostCount: Int32, currentMyBoostCount: Int32, replacedBoosts: Int32? = nil) -> DisplayData {
        var currentLevel = self.level
        var nextLevelBoosts = self.nextLevelBoosts
        var currentLevelBoosts = self.currentLevelBoosts
        var boosts = self.boosts
        if let replacedBoosts {
            boosts = max(currentLevelBoosts, boosts - replacedBoosts)
        }
        
        if currentMyBoostCount > 0 && self.boosts == currentLevelBoosts {
            currentLevel = max(0, currentLevel - 1)
            nextLevelBoosts = currentLevelBoosts
            currentLevelBoosts = max(0, currentLevelBoosts - 1)
        }
        
        return DisplayData(
            level: currentLevel,
            boosts: boosts,
            currentLevelBoosts: currentLevelBoosts,
            nextLevelBoosts: nextLevelBoosts,
            myBoostCount: myBoostCount
        )
    }
}
