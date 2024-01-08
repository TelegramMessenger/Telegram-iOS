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

func requiredBoostSubjectLevel(subject: BoostSubject, context: AccountContext, configuration: PremiumConfiguration) -> Int32 {
    switch subject {
    case .stories:
        return 1
    case let .channelReactions(reactionCount):
        return reactionCount
    case let .nameColors(colors):
        if let value = context.peerNameColors.nameColorsChannelMinRequiredBoostLevel[colors.rawValue] {
            return value
        } else {
            return 1
        }
    case .nameIcon:
        return configuration.minChannelNameIconLevel
    case .profileColors:
        return configuration.minChannelProfileColorLevel
    case .profileIcon:
        return configuration.minChannelProfileIconLevel
    case .emojiStatus:
        return configuration.minChannelEmojiStatusLevel
    case .wallpaper:
        return configuration.minChannelWallpaperLevel
    case .customWallpaper:
        return configuration.minChannelCustomWallpaperLevel
    }
}

public enum BoostSubject: Equatable {
    case stories
    case channelReactions(reactionCount: Int32)
    case nameColors(colors: PeerNameColor)
    case nameIcon
    case profileColors
    case profileIcon
    case emojiStatus
    case wallpaper
    case customWallpaper
    
    public func requiredLevel(context: AccountContext, configuration: PremiumConfiguration) -> Int32 {
        return requiredBoostSubjectLevel(subject: self, context: context, configuration: configuration)
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
        
        func title(strings: PresentationStrings) -> String {
            switch self {
            case let .story(value):
                return strings.ChannelBoost_Table_StoriesPerDay(value)
            case let .reaction(value):
                return strings.ChannelBoost_Table_CustomReactions(value)
            case let .nameColor(value):
                return strings.ChannelBoost_Table_NameColor(value)
            case let .profileColor(value):
                return strings.ChannelBoost_Table_ProfileColor(value)
            case .profileIcon:
                return strings.ChannelBoost_Table_ProfileLogo
            case let .linkColor(value):
                return strings.ChannelBoost_Table_StyleForHeaders(value)
            case .linkIcon:
                return strings.ChannelBoost_Table_HeadersLogo
            case .emojiStatus:
                return strings.ChannelBoost_Table_EmojiStatus
            case let .wallpaper(value):
                return strings.ChannelBoost_Table_Wallpaper(value)
            case .customWallpaper:
                return strings.ChannelBoost_Table_CustomWallpaper
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
            }
        }
    }
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    let level: Int32
    let isFirst: Bool
    let perks: [Perk]
  
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        level: Int32,
        isFirst: Bool,
        perks: [Perk]
    ) {
        self.theme = theme
        self.strings = strings
        self.level = level
        self.isFirst = isFirst
        self.perks = perks
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
                            text: value.title(strings: component.strings)
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
            
            let height = header.size.height + list.size.height
            return CGSize(width: context.availableSize.width, height: height)
        }
    }
}

private final class LimitSheetContent: CombinedComponent {
    typealias EnvironmentType = (Empty, ScrollChildEnvironment)
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let insets: UIEdgeInsets
        
    let peer: EnginePeer
    let subject: BoostSubject
    let status: ChannelBoostStatus

    let copyLink: (String) -> Void
    let dismiss: () -> Void
    let openStats: (() -> Void)?
    let openGift: (() -> Void)?
    
    init(context: AccountContext,
         theme: PresentationTheme,
         strings: PresentationStrings,
         insets: UIEdgeInsets,
         peer: EnginePeer,
         subject: BoostSubject,
         status: ChannelBoostStatus,
         copyLink: @escaping (String) -> Void,
         dismiss: @escaping () -> Void,
         openStats: (() -> Void)?,
         openGift: (() -> Void)?
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.insets = insets
        self.peer = peer
        self.subject = subject
        self.status = status
        self.copyLink = copyLink
        self.dismiss = dismiss
        self.openStats = openStats
        self.openGift = openGift
    }
    
    static func ==(lhs: LimitSheetContent, rhs: LimitSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.status != rhs.status {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedChevronImage: (UIImage, PresentationTheme)?
    }
    
    func makeState() -> State {
        return State()
    }
    
    static var body: Body {
        let text = Child(BalancedTextComponent.self)
        let limit = Child(PremiumLimitDisplayComponent.self)
        let linkButton = Child(SolidRoundedButtonComponent.self)
        let button = Child(SolidRoundedButtonComponent.self)
        
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
            let badgeText = "\(component.status.boosts)"
            
            var remaining: Int?
            if let nextLevelBoosts = component.status.nextLevelBoosts {
                remaining = nextLevelBoosts - component.status.boosts
            }
            
            var textString = ""
            let actionButtonText = strings.ChannelBoost_CopyLink
            let buttonIconName = "Premium/CopyLink"
            
            if let remaining {
                var needsSecondParagraph = true
                let storiesString = strings.ChannelBoost_StoriesPerDay(Int32(component.status.level) + 1)
                let valueString = strings.ChannelBoost_MoreBoosts(Int32(remaining))
                switch component.subject {
                case .stories:
                    if component.status.level == 0 {
                        textString = strings.ChannelBoost_EnableStoriesText(valueString).string
                    } else {
                        textString = strings.ChannelBoost_IncreaseLimitText(valueString, storiesString).string
                    }
                    needsSecondParagraph = false
                case let .channelReactions(reactionCount):
                    textString = strings.ChannelBoost_CustomReactionsText("\(reactionCount)", "\(reactionCount)").string
                    needsSecondParagraph = false
                case .nameColors:
                    let colorLevel = component.subject.requiredLevel(context: context.component.context, configuration: premiumConfiguration)
                    
                    textString = strings.ChannelBoost_EnableNameColorLevelText("\(colorLevel)").string
                case .nameIcon:
                    textString = strings.ChannelBoost_EnableNameIconLevelText("\(premiumConfiguration.minChannelNameIconLevel)").string
                case .profileColors:
                    textString = strings.ChannelBoost_EnableProfileColorLevelText("\(premiumConfiguration.minChannelProfileColorLevel)").string
                case .profileIcon:
                    textString = strings.ChannelBoost_EnableProfileIconLevelText("\(premiumConfiguration.minChannelProfileIconLevel)").string
                case .emojiStatus:
                    textString = strings.ChannelBoost_EnableEmojiStatusLevelText("\(premiumConfiguration.minChannelEmojiStatusLevel)").string
                case .wallpaper:
                    textString = strings.ChannelBoost_EnableWallpaperLevelText("\(premiumConfiguration.minChannelWallpaperLevel)").string
                case .customWallpaper:
                    textString = strings.ChannelBoost_EnableCustomWallpaperLevelText("\(premiumConfiguration.minChannelCustomWallpaperLevel)").string
                }
                
                if needsSecondParagraph {
                    textString += "\n\n\(strings.ChannelBoost_AskToBoost)"
                }
            } else {
                let storiesString = strings.ChannelBoost_StoriesPerDay(Int32(component.status.level))
                textString = strings.ChannelBoost_MaxLevelReachedTextAuthor("\(component.status.level)", storiesString).string
            }
            
            let defaultTitle = strings.ChannelBoost_Level("\(component.status.level)").string
            let defaultValue = ""
            let premiumValue = strings.ChannelBoost_Level("\(component.status.level + 1)").string
            let premiumTitle = ""
            
            let progress: CGFloat
            if let nextLevelBoosts = component.status.nextLevelBoosts {
                progress = CGFloat(component.status.boosts - component.status.currentLevelBoosts) / CGFloat(nextLevelBoosts - component.status.currentLevelBoosts)
            } else {
                progress = 1.0
            }

            let contentSize: CGSize
    
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = theme.actionSheet.primaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            let textChild = text.update(
                component: BalancedTextComponent(
                    text: .markdown(text: textString, attributes: markdownAttributes),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            
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
        
            let limitTransition: Transition = .immediate

            let button = button.update(
                component: SolidRoundedButtonComponent(
                    title: actionButtonText,
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
                    iconName: buttonIconName,
                    animationName: nil,
                    iconPosition: .left,
                    action: {
                        component.copyLink(component.status.url)
                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: context.transition
            )
            
            var buttonOffset: CGFloat = 0.0
            var textOffset: CGFloat = 184.0
            
            let linkButton = linkButton.update(
                component: SolidRoundedButtonComponent(
                    title: component.status.url.replacingOccurrences(of: "https://", with: ""),
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
                        component.copyLink(component.status.url)
                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: context.transition
            )
            buttonOffset += 66.0
            
            let linkFrame = CGRect(origin: CGPoint(x: sideInset, y: textOffset + textChild.size.height + 24.0), size: linkButton.size)
            context.add(linkButton
                .position(CGPoint(x: linkFrame.midX, y: linkFrame.midY))
            )
            
            let textSize = textChild.size
            textOffset += textSize.height / 2.0
            
            context.add(textChild
                .position(CGPoint(x: context.availableSize.width / 2.0, y: textOffset))
            )
            
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
                    badgeText: badgeText,
                    badgePosition: progress,
                    badgeGraphPosition: progress,
                    invertProgress: true,
                    isPremiumDisabled: false
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                transition: limitTransition
            )
            context.add(limit
                .position(CGPoint(x: context.availableSize.width / 2.0, y: limit.size.height / 2.0 + 44.0))
            )
            
            let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: textOffset + ceil(textSize.height / 2.0) + buttonOffset + 24.0), size: button.size)
            context.add(button
                .position(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
            )
            
            var additionalContentHeight: CGFloat = 0.0
          
            if premiumConfiguration.giveawayGiftsPurchaseAvailable {
                let orText = orText.update(
                    component: MultilineTextComponent(text: .plain(NSAttributedString(string: strings.ChannelBoost_Or, font: Font.regular(15.0), textColor: textColor.withAlphaComponent(0.8), paragraphAlignment: .center))),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                    transition: .immediate
                )
                context.add(orText
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: buttonFrame.maxY + 27.0))
                )
                
                let orLeftLine = orLeftLine.update(
                    component: Rectangle(color: theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.3)),
                    availableSize: CGSize(width: 90.0, height: 1.0 - UIScreenPixel),
                    transition: .immediate
                )
                context.add(orLeftLine
                    .position(CGPoint(x: context.availableSize.width / 2.0 - orText.size.width / 2.0 - 11.0 - 45.0, y: buttonFrame.maxY + 27.0))
                )
                
                let orRightLine = orRightLine.update(
                    component: Rectangle(color: theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.3)),
                    availableSize: CGSize(width: 90.0, height: 1.0 - UIScreenPixel),
                    transition: .immediate
                )
                context.add(orRightLine
                    .position(CGPoint(x: context.availableSize.width / 2.0 + orText.size.width / 2.0 + 11.0 + 45.0, y: buttonFrame.maxY + 27.0))
                )
                
                if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== theme {
                    state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: linkColor)!, theme)
                }
                
                
                let giftString = strings.Premium_BoostByGiftDescription2
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
                        highlightColor: linkColor.withAlphaComponent(0.2),
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
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: buttonFrame.maxY + 50.0 + giftText.size.height / 2.0))
                )
                
                additionalContentHeight += giftText.size.height + 50.0
            }
        
            
            var nextLevels: ClosedRange<Int32>?
            if component.status.level < 10 {
                nextLevels = Int32(component.status.level) + 1 ... 10
            }
            
            var levelsHeight: CGFloat = 0.0
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
                        
            if let nextLevels {
                for level in nextLevels {
                    var perks: [LevelSectionComponent.Perk] = []
                    perks.append(.story(level))
                    perks.append(.reaction(level))
                                 
                    var nameColorsCount: Int32 = 0
                    for (colorLevel, count) in nameColorsAtLevel {
                        if level >= colorLevel && colorLevel == 1 {
                            nameColorsCount = count
                        }
                    }
                    if nameColorsCount > 0 {
                        perks.append(.nameColor(nameColorsCount))
                    }
                    
                    if level >= premiumConfiguration.minChannelProfileColorLevel {
                        let delta = min(level - premiumConfiguration.minChannelProfileColorLevel + 1, 2)
                        perks.append(.profileColor(8 * delta))
                    }
                    if level >= premiumConfiguration.minChannelProfileIconLevel {
                        perks.append(.profileIcon)
                    }
                    
                    var linkColorsCount: Int32 = 0
                    for (colorLevel, count) in nameColorsAtLevel {
                        if level >= colorLevel {
                            linkColorsCount += count
                        }
                    }
                    if linkColorsCount > 0 {
                        perks.append(.linkColor(linkColorsCount))
                    }
                                        
                    if level >= premiumConfiguration.minChannelNameIconLevel {
                        perks.append(.linkIcon)
                    }
                    if level >= premiumConfiguration.minChannelEmojiStatusLevel {
                        perks.append(.emojiStatus)
                    }
                    if level >= premiumConfiguration.minChannelWallpaperLevel {
                        perks.append(.wallpaper(8))
                    }
                    if level >= premiumConfiguration.minChannelCustomWallpaperLevel {
                        perks.append(.customWallpaper)
                    }
                    
                    levelItems.append(
                        AnyComponentWithIdentity(
                            id: level, component: AnyComponent(
                                LevelSectionComponent(
                                    theme: component.theme,
                                    strings: component.strings,
                                    level: level,
                                    isFirst: levelItems.isEmpty,
                                    perks: perks
                                )
                            )
                        )
                    )
                }
            }
            
            if !levelItems.isEmpty {
                let levels = levels.update(
                    component: List(levelItems),
                    availableSize: CGSize(width: context.availableSize.width, height: 100000.0),
                    transition: context.transition
                )
                context.add(levels
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: buttonFrame.maxY + 23.0 + additionalContentHeight + levels.size.height / 2.0 ))
                )
                levelsHeight = levels.size.height + 40.0
            }
            
            let bottomInset: CGFloat = 0.0
            contentSize = CGSize(width: context.availableSize.width, height: buttonFrame.maxY + additionalContentHeight + 5.0 + bottomInset + levelsHeight)
            
            return contentSize
        }
    }
}

private final class BoostLevelsContainerComponent: CombinedComponent {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    
    let peer: EnginePeer
    let subject: BoostSubject
    let status: ChannelBoostStatus
    let copyLink: (String) -> Void
    let dismiss: () -> Void
    let openStats: () -> Void
    let openGift: () -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peer: EnginePeer,
        subject: BoostSubject,
        status: ChannelBoostStatus,
        copyLink: @escaping (String) -> Void,
        dismiss: @escaping () -> Void,
        openStats: @escaping () -> Void,
        openGift: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
        self.subject = subject
        self.status = status
        self.copyLink = copyLink
        self.dismiss = dismiss
        self.openStats = openStats
        self.openGift = openGift
    }
    
    static func ==(lhs: BoostLevelsContainerComponent, rhs: BoostLevelsContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.status != rhs.status {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var topContentOffset: CGFloat = 0.0
        var cachedStatsImage: (UIImage, PresentationTheme)?
        var cachedCloseImage: (UIImage, PresentationTheme)?
    }
    
    func makeState() -> State {
        return State()
    }
        
    static var body: Body {
        let background = Child(Rectangle.self)
        let scroll = Child(ScrollComponent<Empty>.self)
        let topPanel = Child(BlurredBackgroundComponent.self)
        let topSeparator = Child(Rectangle.self)
        let title = Child(MultilineTextComponent.self)
        let statsButton = Child(Button.self)
        let closeButton = Child(Button.self)
        
        return { context in
            let state = context.state
            
            let theme = context.component.theme
            let strings = context.component.context.sharedContext.currentPresentationData.with { $0 }.strings
            
            let topInset: CGFloat = 56.0
            
            let component = context.component
            
            let scroll = scroll.update(
                component: ScrollComponent<Empty>(
                    content: AnyComponent(
                        LimitSheetContent(
                            context: component.context,
                            theme: component.theme,
                            strings: component.strings,
                            insets: .zero,
                            peer: component.peer,
                            subject: component.subject,
                            status: component.status,
                            copyLink: component.copyLink,
                            dismiss: component.dismiss,
                            openStats: component.openStats,
                            openGift: component.openGift
                        )
                    ),
                    contentInsets: UIEdgeInsets(top: topInset, left: 0.0, bottom: 34.0, right: 0.0),
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
            if let _ = component.status.nextLevelBoosts {
                switch component.subject {
                case .stories:
                    if component.status.level == 0 {
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
                }
            } else {
                titleString = strings.ChannelBoost_MaxLevelReached
            }
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleString, font: Font.semibold(17.0), textColor: theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center,
                    truncationType: .end,
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
                  
            let topPanelAlpha: CGFloat = min(30.0, state.topContentOffset) / 30.0
            context.add(topPanel
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topPanel.size.height / 2.0))
                .opacity(topPanelAlpha)
            )
            context.add(topSeparator
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topPanel.size.height))
                .opacity(topPanelAlpha)
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topPanel.size.height / 2.0))
            )
            
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
                            component.openStats()
                        }
                    }
                ).minSize(CGSize(width: 44.0, height: 44.0)),
                availableSize: context.availableSize,
                transition: .immediate
            )
            context.add(statsButton
                .position(CGPoint(x: 31.0, y: 28.0))
            )
            
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
            
            return scroll.size
        }
    }
}

public class PremiumBoostLevelsScreen: ViewController {
    final class Node: ViewControllerTracingNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        private var presentationData: PresentationData
        private weak var controller: PremiumBoostLevelsScreen?
                
        let dim: ASDisplayNode
        let wrappingView: UIView
        let containerView: UIView
        
        let contentView: ComponentHostView<Empty>
                
        private(set) var isExpanded = false
        private var panGestureRecognizer: UIPanGestureRecognizer?
        private var panGestureArguments: (topInset: CGFloat, offset: CGFloat, scrollView: UIScrollView?, listNode: ListView?)?
        
        private var currentIsVisible: Bool = false
        private var currentLayout: ContainerViewLayout?
                
        var isPremium: Bool?
        var disposable: Disposable?
                
        init(context: AccountContext, controller: PremiumBoostLevelsScreen) {
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
            if controller.forceDark {
                self.presentationData = self.presentationData.withUpdated(theme: defaultDarkPresentationTheme)
            }
            self.presentationData = self.presentationData.withUpdated(theme: self.presentationData.theme.withModalBlocksBackground())
            
            self.controller = controller
            
            self.dim = ASDisplayNode()
            self.dim.alpha = 0.0
            self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
            
            self.wrappingView = UIView()
            self.containerView = UIView()
            self.contentView = ComponentHostView()
            
            super.init()
                        
            self.containerView.clipsToBounds = true
            self.containerView.backgroundColor = self.presentationData.theme.overallDarkAppearance ? self.presentationData.theme.list.blocksBackgroundColor : self.presentationData.theme.list.plainBackgroundColor
            
            self.addSubnode(self.dim)
            
            self.view.addSubview(self.wrappingView)
            self.wrappingView.addSubview(self.containerView)
            self.containerView.addSubview(self.contentView)
        }
        
        deinit {
            self.disposable?.dispose()
        }
        
        override func didLoad() {
            super.didLoad()
            
            let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            panRecognizer.delegate = self
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
                
        private var dismissOffset: CGFloat?
        func containerLayoutUpdated(layout: ContainerViewLayout, transition: Transition) {
            self.currentLayout = layout
            
            self.dim.frame = CGRect(origin: CGPoint(x: 0.0, y: -layout.size.height), size: CGSize(width: layout.size.width, height: layout.size.height * 3.0))
                        
            var effectiveExpanded = self.isExpanded
            if case .regular = layout.metrics.widthClass {
                effectiveExpanded = true
            }
            
            let isLandscape = layout.orientation == .landscape
            let edgeTopInset = isLandscape ? 0.0 : self.defaultTopInset
            let topInset: CGFloat
            if let (panInitialTopInset, panOffset, _, _) = self.panGestureArguments {
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
                    var containerTopInset: CGFloat = 10.0
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
            
            self.updated(transition: transition)
        }
        
        func updated(transition: Transition) {
            guard let controller = self.controller else {
                return
            }
            let containerSize = self.containerView.bounds.size
            

            let contentSize = self.contentView.update(
                transition: .immediate,
                component: AnyComponent(
                    BoostLevelsContainerComponent(
                        context: controller.context,
                        theme: self.presentationData.theme,
                        strings: self.presentationData.strings,
                        peer: controller.peer,
                        subject: controller.subject,
                        status: controller.status,
                        copyLink: { [weak self, weak controller] link in
                            guard let self else {
                                return
                            }
                            UIPasteboard.general.string = link
                            
                            if let previousController = controller?.navigationController?.viewControllers.reversed().first(where: { $0 !== controller }) as? ViewController {
                                previousController.present(UndoOverlayController(presentationData: self.presentationData, content: .linkCopied(text: self.presentationData.strings.ChannelBoost_BoostLinkCopied), elevatedLayout: true, position: .top, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                            }
                        },
                        dismiss: { [weak controller] in
                            controller?.dismiss(animated: true)
                        },
                        openStats: controller.openStats,
                        openGift: controller.openGift
                    )
                ),
                environment: {},
                containerSize: CGSize(width: containerSize.width, height: containerSize.height)
            )
            self.contentView.frame = CGRect(origin: .zero, size: contentSize)
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
        
        private var defaultTopInset: CGFloat {
            guard let layout = self.currentLayout else {
                return 210.0
            }
            if case .compact = layout.metrics.widthClass {
                let bottomPanelPadding: CGFloat = 12.0
                let bottomInset: CGFloat = layout.intrinsicInsets.bottom > 0.0 ? layout.intrinsicInsets.bottom + 5.0 : bottomPanelPadding
                let panelHeight: CGFloat = bottomPanelPadding + 50.0 + bottomInset + 28.0
                
                let additionalInset: CGFloat = 0.0
                return layout.size.height - layout.size.width - 181.0 - panelHeight + additionalInset
            } else {
                return 210.0
            }
        }
        
        private func findVerticalScrollView(view: UIView?) -> (UIScrollView, ListView?)? {
            if let view = view {
                if let view = view as? UIScrollView, view.contentSize.height > view.contentSize.width {
                    return (view, nil)
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
                    
                    var scrollViewAndListNode = self.findVerticalScrollView(view: currentHitView)
                    if scrollViewAndListNode?.0.frame.height == self.frame.width {
                        scrollViewAndListNode = nil
                    }
                    let scrollView = scrollViewAndListNode?.0
                    let listNode = scrollViewAndListNode?.1
                                
                    let topInset: CGFloat
                    if self.isExpanded {
                        topInset = 0.0
                    } else {
                        topInset = edgeTopInset
                    }
                
                    self.panGestureArguments = (topInset, 0.0, scrollView, listNode)
                case .changed:
                    guard let (topInset, panOffset, scrollView, listNode) = self.panGestureArguments else {
                        return
                    }
                    let visibleContentOffset = listNode?.visibleContentOffset()
                    let contentOffset = scrollView?.contentOffset.y ?? 0.0
                
                    var translation = recognizer.translation(in: self.view).y

                    var currentOffset = topInset + translation
                
                    let epsilon = 1.0
                    if case let .known(value) = visibleContentOffset, value <= epsilon {
                        if let scrollView = scrollView {
                            scrollView.bounces = false
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: false)
                        }
                    } else if let scrollView = scrollView, contentOffset <= -scrollView.contentInset.top + epsilon {
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
                    
                    self.panGestureArguments = (topInset, translation, scrollView, listNode)
                    
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
                    guard let (currentTopInset, panOffset, scrollView, listNode) = self.panGestureArguments else {
                        return
                    }
                    self.panGestureArguments = nil
                
                    let visibleContentOffset = listNode?.visibleContentOffset()
                    let contentOffset = scrollView?.contentOffset.y ?? 0.0
                
                    let translation = recognizer.translation(in: self.view).y
                    var velocity = recognizer.velocity(in: self.view)
                    
                    if self.isExpanded {
                        if case let .known(value) = visibleContentOffset, value > 0.1 {
                            velocity = CGPoint()
                        } else if case .unknown = visibleContentOffset {
                            velocity = CGPoint()
                        } else if contentOffset > 0.1 {
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
                            if let listNode = listNode {
                                listNode.scroller.setContentOffset(CGPoint(), animated: false)
                            } else if let scrollView = scrollView {
                                scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                            }
                            
                            let distance = topInset - offset
                            let initialVelocity: CGFloat = distance.isZero ? 0.0 : abs(velocity.y / distance)
                            let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))

                            self.containerLayoutUpdated(layout: layout, transition: Transition(transition))
                        } else {
                            self.isExpanded = true
                            
                            self.containerLayoutUpdated(layout: layout, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
                        }
                    } else if scrollView != nil, (velocity.y < -300.0 || offset < topInset / 2.0) {
                        if velocity.y > -2200.0 && velocity.y < -300.0, let listNode = listNode {
                            DispatchQueue.main.async {
                                listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                            }
                        }
                                                    
                        let initialVelocity: CGFloat = offset.isZero ? 0.0 : abs(velocity.y / offset)
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))
                        self.isExpanded = true
                       
                        self.containerLayoutUpdated(layout: layout, transition: Transition(transition))
                    } else {
                        if let listNode = listNode {
                            listNode.scroller.setContentOffset(CGPoint(), animated: false)
                        } else if let scrollView = scrollView {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                        
                        self.containerLayoutUpdated(layout: layout, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
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
                    
                    self.containerLayoutUpdated(layout: layout, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
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
            self.containerLayoutUpdated(layout: layout, transition: Transition(transition))
        }
    }
    
    var node: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    private let peer: EnginePeer
    private let subject: BoostSubject
    private let status: ChannelBoostStatus
    private let openStats: () -> Void
    private let openGift: () -> Void
    private let forceDark: Bool
    
    private var currentLayout: ContainerViewLayout?
        
    public var disposed: () -> Void = {}
    
    public init(
        context: AccountContext,
        peer: EnginePeer,
        subject: BoostSubject,
        status: ChannelBoostStatus,
        openStats: @escaping () -> Void,
        openGift: @escaping () -> Void,
        forceDark: Bool = false
    ) {
        self.context = context
        self.peer = peer
        self.subject = subject
        self.status = status
        self.openStats = openStats
        self.openGift = openGift
        self.forceDark = forceDark
        
        super.init(navigationBarPresentationData: nil)
        
        self.navigationPresentation = .flatModal
        self.statusBar.statusBarStyle = .Ignore
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        
//        UIPasteboard.general.string = link
//        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
//        self.environment?.controller()?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.ChannelBoost_BoostLinkCopied), elevatedLayout: false, position: .bottom, animateInAsReplacement: false, action: { _ in return false }), in: .current)
    }
        
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposed()
    }
    
    @objc private func cancelPressed() {
        self.dismiss(animated: true, completion: nil)
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
                
        self.node.containerLayoutUpdated(layout: layout, transition: Transition(transition))
    }
}
