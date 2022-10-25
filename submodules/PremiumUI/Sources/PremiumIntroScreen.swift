import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import ViewControllerComponent
import AccountContext
import SolidRoundedButtonComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import BundleIconComponent
import SolidRoundedButtonComponent
import Markdown
import InAppPurchaseManager
import ConfettiEffect
import TextFormat
import InstantPageCache
import UniversalMediaPlayer
import CheckNode
import AnimationCache
import MultiAnimationRenderer

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
        case let .gift(from, to, duration):
            if case .gift(from, to, duration) = rhs {
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
    case profile(PeerId)
    case emojiStatus(PeerId, Int64, TelegramMediaFile?, LoadedStickerPack?)
    case gift(from: PeerId, to: PeerId, duration: Int32)
    case giftTerms
    case voiceToText
    
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
            case .gift, .giftTerms:
                return nil
            case let .deeplink(reference):
                if let reference = reference {
                    return "deeplink_\(reference)"
                } else {
                    return "deeplink"
                }
        }
    }
}

enum PremiumPerk: CaseIterable {
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
    
    static var allCases: [PremiumPerk] {
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
            .emojiStatus
        ]
    }
    
    init?(identifier: String) {
        for perk in PremiumPerk.allCases {
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
        }
    }
}

struct PremiumIntroConfiguration {
    static var defaultValue: PremiumIntroConfiguration {
        return PremiumIntroConfiguration(perks: [
            .doubleLimits,
            .moreUpload,
            .fasterDownload,
            .voiceToText,
            .noAds,
            .emojiStatus,
            .uniqueReactions,
            .premiumStickers,
            .animatedEmoji,
            .advancedChatManagement,
            .profileBadge,
            .animatedUserpics,
            .appIcons
        ])
    }
    
    let perks: [PremiumPerk]
    
    fileprivate init(perks: [PremiumPerk]) {
        self.perks = perks
    }
    
    public static func with(appConfiguration: AppConfiguration) -> PremiumIntroConfiguration {
        if let data = appConfiguration.data, let values = data["premium_promo_order"] as? [String] {
            var perks: [PremiumPerk] = []
            for value in values {
                if let perk = PremiumPerk(identifier: value) {
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
            return PremiumIntroConfiguration(perks: perks)
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
}

final class PremiumOptionComponent: CombinedComponent {
    let title: String
    let subtitle: String
    let labelPrice: String
    let discount: String
    let selected: Bool
    let primaryTextColor: UIColor
    let secondaryTextColor: UIColor
    let accentColor: UIColor
    let checkForegroundColor: UIColor
    let checkBorderColor: UIColor
    
    init(
        title: String,
        subtitle: String,
        labelPrice: String,
        discount: String,
        selected: Bool,
        primaryTextColor: UIColor,
        secondaryTextColor: UIColor,
        accentColor: UIColor,
        checkForegroundColor: UIColor,
        checkBorderColor: UIColor
    ) {
        self.title = title
        self.subtitle = subtitle
        self.labelPrice = labelPrice
        self.discount = discount
        self.selected = selected
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.accentColor = accentColor
        self.checkForegroundColor = checkForegroundColor
        self.checkBorderColor = checkBorderColor
    }
    
    static func ==(lhs: PremiumOptionComponent, rhs: PremiumOptionComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        if lhs.labelPrice != rhs.labelPrice {
            return false
        }
        if lhs.discount != rhs.discount {
            return false
        }
        if lhs.selected != rhs.selected {
            return false
        }
        if lhs.primaryTextColor != rhs.primaryTextColor {
            return false
        }
        if lhs.secondaryTextColor != rhs.secondaryTextColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.checkForegroundColor != rhs.checkForegroundColor {
            return false
        }
        if lhs.checkBorderColor != rhs.checkBorderColor {
            return false
        }
        return true
    }
    
    static var body: Body {
        let check = Child(CheckComponent.self)
        let title = Child(MultilineTextComponent.self)
        let subtitle = Child(MultilineTextComponent.self)
        let discountBackground = Child(RoundedRectangle.self)
        let discount = Child(MultilineTextComponent.self)
        let label = Child(MultilineTextComponent.self)
        
        return { context in
            let component = context.component
            
            var insets = UIEdgeInsets(top: 11.0, left: 46.0, bottom: 13.0, right: 16.0)
                        
            let label = label.update(
                component: MultilineTextComponent(
                    text: .plain(
                        NSAttributedString(
                            string: component.labelPrice,
                            font: Font.regular(17),
                            textColor: component.secondaryTextColor
                        )
                    ),
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(
                        NSAttributedString(
                            string: component.title,
                            font: Font.regular(17),
                            textColor: component.primaryTextColor
                        )
                    ),
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - insets.left - insets.right - label.size.width, height: context.availableSize.height),
                transition: context.transition
            )
                        
            var spacing: CGFloat = 0.0
            var subtitleSize = CGSize()
            if !component.subtitle.isEmpty {
                spacing = 2.0
                
                let subtitleFont = Font.regular(13)
                let subtitleColor = component.secondaryTextColor
                
                let subtitleString = parseMarkdownIntoAttributedString(
                    component.subtitle,
                    attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(font: subtitleFont, textColor: subtitleColor),
                        bold: MarkdownAttributeSet(font: subtitleFont, textColor: subtitleColor, additionalAttributes: [NSAttributedString.Key.strikethroughStyle.rawValue: NSUnderlineStyle.single.rawValue as NSNumber]),
                        link: MarkdownAttributeSet(font: subtitleFont, textColor: subtitleColor),
                        linkAttribute: { _ in return nil }
                    )
                )
                
                let subtitle = subtitle.update(
                    component: MultilineTextComponent(
                        text: .plain(subtitleString),
                        maximumNumberOfLines: 1
                    ),
                    availableSize: CGSize(width: context.availableSize.width - insets.left - insets.right - label.size.width, height: context.availableSize.height),
                    transition: context.transition
                )
                context.add(subtitle
                    .position(CGPoint(x: insets.left + subtitle.size.width / 2.0, y: insets.top + title.size.height + spacing + subtitle.size.height / 2.0))
                )
                subtitleSize = subtitle.size
                
                insets.top -= 2.0
                insets.bottom -= 2.0
            }
            
            let discountSize: CGSize
            if !component.discount.isEmpty {
                let discount = discount.update(
                    component: MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: component.discount,
                                font: Font.with(size: 14.0, design: .round, weight: .semibold, traits: []),
                                textColor: .white
                            )
                        ),
                        maximumNumberOfLines: 1
                    ),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                
                discountSize = CGSize(width: discount.size.width + 6.0, height: 18.0)
            
                let discountBackground = discountBackground.update(
                    component: RoundedRectangle(
                        color: component.accentColor,
                        cornerRadius: 5.0
                    ),
                    availableSize: discountSize,
                    transition: context.transition
                )
                
                context.add(discountBackground
                    .position(CGPoint(x: insets.left + title.size.width + 6.0 + discountSize.width / 2.0, y: insets.top + title.size.height / 2.0))
                )
                
                context.add(discount
                    .position(CGPoint(x: insets.left + title.size.width + 6.0 + discountSize.width / 2.0, y: insets.top + title.size.height / 2.0))
                )
            } else {
                discountSize = CGSize(width: 0.0, height: 18.0)
            }
                        
            let check = check.update(
                component: CheckComponent(
                    theme: CheckComponent.Theme(
                        backgroundColor: component.accentColor,
                        strokeColor: component.checkForegroundColor,
                        borderColor: component.checkBorderColor,
                        overlayBorder: false,
                        hasInset: false,
                        hasShadow: false
                    ),
                    selected: component.selected
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
                
            context.add(title
                .position(CGPoint(x: insets.left + title.size.width / 2.0, y: insets.top + title.size.height / 2.0))
            )
               
            let size = CGSize(width: context.availableSize.width, height: insets.top + title.size.height + spacing + subtitleSize.height + insets.bottom)
            
            let distance = context.availableSize.width - insets.left - insets.right - label.size.width - subtitleSize.width
            
            let labelY: CGFloat
            if distance > 8.0 {
                labelY = size.height / 2.0
            } else {
                labelY = insets.top + title.size.height / 2.0
            }
            
            context.add(label
                .position(CGPoint(x: context.availableSize.width - insets.right - label.size.width / 2.0, y: labelY))
            )
            
            context.add(check
                .position(CGPoint(x: 4.0 + check.size.width / 2.0, y: size.height / 2.0))
            )
            
            return size
        }
    }
}

private final class CheckComponent: Component {
    struct Theme: Equatable {
        public let backgroundColor: UIColor
        public let strokeColor: UIColor
        public let borderColor: UIColor
        public let overlayBorder: Bool
        public let hasInset: Bool
        public let hasShadow: Bool
        public let filledBorder: Bool
        public let borderWidth: CGFloat?
        
        public init(backgroundColor: UIColor, strokeColor: UIColor, borderColor: UIColor, overlayBorder: Bool, hasInset: Bool, hasShadow: Bool, filledBorder: Bool = false, borderWidth: CGFloat? = nil) {
            self.backgroundColor = backgroundColor
            self.strokeColor = strokeColor
            self.borderColor = borderColor
            self.overlayBorder = overlayBorder
            self.hasInset = hasInset
            self.hasShadow = hasShadow
            self.filledBorder = filledBorder
            self.borderWidth = borderWidth
        }
        
        var checkNodeTheme: CheckNodeTheme {
            return CheckNodeTheme(
                backgroundColor: self.backgroundColor,
                strokeColor: self.strokeColor,
                borderColor: self.borderColor,
                overlayBorder: self.overlayBorder,
                hasInset: self.hasInset,
                hasShadow: self.hasShadow,
                filledBorder: self.filledBorder,
                borderWidth: self.borderWidth
            )
        }
    }
    
    let theme: Theme
    let selected: Bool
    
    init(
        theme: Theme,
        selected: Bool
    ) {
        self.theme = theme
        self.selected = selected
    }
    
    static func ==(lhs: CheckComponent, rhs: CheckComponent) -> Bool {
        if lhs.theme != rhs.theme {
            return false
        }
        if lhs.selected != rhs.selected {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var currentValue: CGFloat?
        private var animator: DisplayLinkAnimator?

        private var checkLayer: CheckLayer {
            return self.layer as! CheckLayer
        }
        
        override class var layerClass: AnyClass {
            return CheckLayer.self
        }
        
        init() {
            super.init(frame: CGRect())
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

    
        func update(component: CheckComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.checkLayer.setSelected(component.selected, animated: true)
            self.checkLayer.theme = component.theme.checkNodeTheme
            
            return CGSize(width: 22.0, height: 22.0)
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

final class SectionGroupComponent: Component {
    public final class Item: Equatable {
        public let content: AnyComponentWithIdentity<Empty>
        public let action: () -> Void
        
        public init(_ content: AnyComponentWithIdentity<Empty>, action: @escaping () -> Void) {
            self.content = content
            self.action = action
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.content != rhs.content {
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
        
        func update(component: SectionGroupComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
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
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
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
    
    init(
        iconName: String,
        iconBackgroundColors: [UIColor],
        title: String,
        titleColor: UIColor,
        subtitle: String,
        subtitleColor: UIColor,
        arrowColor: UIColor
    ) {
        self.iconName = iconName
        self.iconBackgroundColors = iconBackgroundColors
        self.title = title
        self.titleColor = titleColor
        self.subtitle = subtitle
        self.subtitleColor = subtitleColor
        self.arrowColor = arrowColor
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
        return true
    }
    
    static var body: Body {
        let iconBackground = Child(RoundedRectangle.self)
        let icon = Child(BundleIconComponent.self)
        let title = Child(MultilineTextComponent.self)
        let subtitle = Child(MultilineTextComponent.self)
        let arrow = Child(BundleIconComponent.self)

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
                availableSize: iconSize, transition: context.transition
            )
            
            let icon = icon.update(
                component: BundleIconComponent(
                    name: component.iconName,
                    tintColor: .white
                ),
                availableSize: iconSize,
                transition: context.transition
            )
            
            let arrow = arrow.update(
                component: BundleIconComponent(
                    name: "Item List/DisclosureArrow",
                    tintColor: component.arrowColor
                ),
                availableSize: context.availableSize,
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
            
            context.add(subtitle
                .position(CGPoint(x: iconBackground.size.width + sideInset + subtitle.size.width / 2.0, y: textTopInset + title.size.height + spacing + subtitle.size.height / 2.0))
            )
            
            let size = CGSize(width: context.availableSize.width, height: textTopInset + title.size.height + spacing + subtitle.size.height + textBottomInset)
            context.add(arrow
                .position(CGPoint(x: context.availableSize.width - 7.0 - arrow.size.width / 2.0, y: size.height / 2.0))
            )
        
            return size
        }
    }
}


private final class PremiumIntroScreenContentComponent: CombinedComponent {
    typealias EnvironmentType = (ViewControllerComponentContainer.Environment, ScrollChildEnvironment)
    
    let context: AccountContext
    let source: PremiumSource
    let isPremium: Bool?
    let otherPeerName: String?
    let products: [PremiumProduct]?
    let selectedProductId: String?
    let promoConfiguration: PremiumPromoConfiguration?
    let present: (ViewController) -> Void
    let selectProduct: (String) -> Void
    let buy: () -> Void
    let updateIsFocused: (Bool) -> Void
    
    init(context: AccountContext, source: PremiumSource, isPremium: Bool?, otherPeerName: String?, products: [PremiumProduct]?, selectedProductId: String?, promoConfiguration: PremiumPromoConfiguration?, present: @escaping (ViewController) -> Void, selectProduct: @escaping (String) -> Void, buy: @escaping () -> Void, updateIsFocused: @escaping (Bool) -> Void) {
        self.context = context
        self.source = source
        self.isPremium = isPremium
        self.otherPeerName = otherPeerName
        self.products = products
        self.selectedProductId = selectedProductId
        self.promoConfiguration = promoConfiguration
        self.present = present
        self.selectProduct = selectProduct
        self.buy = buy
        self.updateIsFocused = updateIsFocused
    }
    
    static func ==(lhs: PremiumIntroScreenContentComponent, rhs: PremiumIntroScreenContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.source != rhs.source {
            return false
        }
        if lhs.isPremium != rhs.isPremium {
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
        if lhs.promoConfiguration != rhs.promoConfiguration {
            return false
        }
    
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
    
        var products: [PremiumProduct]?
        var selectedProductId: String?
        
        var isPremium: Bool?
        
        private var disposable: Disposable?
        private(set) var configuration = PremiumIntroConfiguration.defaultValue
    
        private var stickersDisposable: Disposable?
        private var preloadDisposableSet =  DisposableSet()
        
        var price: String? {
            return self.products?.first(where: { $0.id == self.selectedProductId })?.price
        }
        
        var isAnnual: Bool {
            return self.products?.first(where: { $0.id == self.selectedProductId })?.id.hasSuffix(".annual") ?? false
        }
        
        init(context: AccountContext, source: PremiumSource) {
            self.context = context
            
            super.init()
            
            self.disposable = (context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Configuration.App()
            )
            |> deliverOnMainQueue).start(next: { [weak self] appConfiguration in
                if let strongSelf = self {
                    strongSelf.configuration = PremiumIntroConfiguration.with(appConfiguration: appConfiguration)
                    strongSelf.updated(transition: .immediate)
                    
                    if let identifier = source.identifier {
                        var jsonString: String = "{"
                        jsonString += "\"source\": \"\(identifier)\","
                        
                        jsonString += "\"data\": {\"premium_promo_order\":["
                        var isFirst = true
                        for perk in strongSelf.configuration.perks {
                            if !isFirst {
                                jsonString += ","
                            }
                            isFirst = false
                            jsonString += "\"\(perk.identifier)\""
                        }
                        jsonString += "]}}"
                        
                        if let data = jsonString.data(using: .utf8), let json = JSON(data: data) {
                            addAppLogEvent(postbox: strongSelf.context.account.postbox, type: "premium.promo_screen_show", data: json)
                        }
                    }
                }
            })
            
            let _ = updatePremiumPromoConfigurationOnce(account: context.account).start()
            
            let stickersKey: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.CloudPremiumStickers)
            self.stickersDisposable = (self.context.account.postbox.combinedView(keys: [stickersKey])
            |> deliverOnMainQueue).start(next: { [weak self] views in
                guard let strongSelf = self else {
                    return
                }
                if let view = views.views[stickersKey] as? OrderedItemListView {
                    for item in view.items {
                        if let mediaItem = item.contents.get(RecentMediaItem.self) {
                            let file = mediaItem.media
                            strongSelf.preloadDisposableSet.add(freeMediaFileResourceInteractiveFetched(account: context.account, fileReference: .standalone(media: file), resource: file.resource).start())
                            if let effect = file.videoThumbnails.first {
                                strongSelf.preloadDisposableSet.add(freeMediaFileResourceInteractiveFetched(account: context.account, fileReference: .standalone(media: file), resource: effect.resource).start())
                            }
                        }
                    }
                }
            })
        }
        
        deinit {
            self.disposable?.dispose()
            self.preloadDisposableSet.dispose()
            self.stickersDisposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, source: self.source)
    }
    
    static var body: Body {
        let overscroll = Child(Rectangle.self)
        let fade = Child(RoundedRectangle.self)
        let text = Child(MultilineTextComponent.self)
        let optionsSection = Child(SectionGroupComponent.self)
        let perksSection = Child(SectionGroupComponent.self)
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
            state.isPremium = context.component.isPremium
            
            let theme = environment.theme
            let strings = environment.strings
            
            let availableWidth = context.availableSize.width
            let sideInsets = sideInset * 2.0 + environment.safeInsets.left + environment.safeInsets.right
            var size = CGSize(width: context.availableSize.width, height: 0.0)
            
            let overscroll = overscroll.update(
                component: Rectangle(color: theme.list.plainBackgroundColor),
                availableSize: CGSize(width: context.availableSize.width, height: 1000),
                transition: context.transition
            )
            context.add(overscroll
                .position(CGPoint(x: overscroll.size.width / 2.0, y: -overscroll.size.height / 2.0))
            )
            
            let fade = fade.update(
                component: RoundedRectangle(
                    colors: [
                        theme.list.plainBackgroundColor,
                        theme.list.blocksBackgroundColor
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
            let titleColor = theme.list.itemPrimaryTextColor
            let subtitleColor = theme.list.itemSecondaryTextColor
            let arrowColor = theme.list.disclosureArrowColor
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            
            let textString: String
            if case .emojiStatus = context.component.source {
                textString = strings.Premium_EmojiStatusText.replacingOccurrences(of: "#", with: "# ")
            } else if case .giftTerms = context.component.source {
                textString = strings.Premium_PersonalDescription
            } else if let _ = context.component.otherPeerName {
                if case let .gift(fromId, _, _) = context.component.source {
                    if fromId == context.component.context.account.peerId {
                        textString = strings.Premium_GiftedDescriptionYou
                    } else {
                        textString = strings.Premium_GiftedDescription
                    }
                } else {
                    textString = strings.Premium_PersonalDescription
                }
            } else if context.component.isPremium == true {
                textString = strings.Premium_SubscribedDescription
            } else {
                textString = strings.Premium_Description
            }
            
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: accentColor), linkAttribute: { _ in
                return nil
            })
            
            let text = text.update(
                component: MultilineTextComponent(
                    text: .markdown(
                        text: textString,
                        attributes: markdownAttributes
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                environment: {},
                availableSize: CGSize(width: availableWidth - sideInsets, height: 240.0),
                transition: context.transition
            )
            context.add(text
                .position(CGPoint(x: size.width / 2.0, y: size.height + text.size.height / 2.0))
            )
            size.height += text.size.height
            size.height += 21.0
            
            let gradientColors: [UIColor] = [
                UIColor(rgb: 0xF27C30),
                UIColor(rgb: 0xE36850),
                UIColor(rgb: 0xda5d63),
                UIColor(rgb: 0xD15078),
                UIColor(rgb: 0xC14998),
                UIColor(rgb: 0xB24CB5),
                UIColor(rgb: 0xA34ED0),
                UIColor(rgb: 0x9054E9),
                UIColor(rgb: 0x7561EB),
                UIColor(rgb: 0x5A6EEE),
                UIColor(rgb: 0x548DFF),
                UIColor(rgb: 0x54A3FF),
                UIColor(rgb: 0x54bdff)
            ]
                        
            let accountContext = context.component.context
            let present = context.component.present
            let selectProduct = context.component.selectProduct
            let buy = context.component.buy
            let updateIsFocused = context.component.updateIsFocused
            
            let layoutOptions = {
                if state.isPremium == true {
                    
                } else if let products = state.products, products.count > 1 {
                    var optionsItems: [SectionGroupComponent.Item] = []
                    let gradientColors: [UIColor] = [
                        UIColor(rgb: 0x8e77ff),
                        UIColor(rgb: 0x9a6fff),
                        UIColor(rgb: 0xb36eee)
                    ]
                    
                    let shortestOptionPrice: (Int64, NSDecimalNumber)
                    if let product = products.first(where: { $0.id.hasSuffix(".monthly") }) {
                        shortestOptionPrice = (Int64(Float(product.storeProduct.priceCurrencyAndAmount.amount)), product.storeProduct.priceValue)
                    } else {
                        shortestOptionPrice = (1, NSDecimalNumber(decimal: 1))
                    }
                    
                    var i = 0
                    for product in products {
                        let giftTitle: String
                        let months = product.months
                        
                        if product.id.hasSuffix(".monthly") {
                            giftTitle = strings.Premium_Monthly
                        } else if product.id.hasSuffix(".semiannual") {
                            giftTitle = strings.Premium_Semiannual
                        } else {
                            giftTitle = strings.Premium_Annual
                        }
                                            
                        let discountValue = Int((1.0 - Float(product.storeProduct.priceCurrencyAndAmount.amount) / Float(months) / Float(shortestOptionPrice.0)) * 100.0)
                        let discount: String
                        if discountValue > 0 {
                            discount = "-\(discountValue)%"
                        } else {
                            discount = ""
                        }
                        
                        let defaultPrice = product.storeProduct.defaultPrice(shortestOptionPrice.1, monthsCount: Int(months))
                        
                        var subtitle = ""
                        var pricePerMonth = product.price
                        if months > 1 {
                            pricePerMonth = product.storeProduct.pricePerMonth(Int(months))
                            
                            if discountValue > 0 {
                                subtitle = "**\(defaultPrice)** \(product.price)"
                                if months == 12 {
                                    subtitle = environment.strings.Premium_PricePerYear(subtitle).string
                                }
                            } else {
                                subtitle = product.price
                            }
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
                                            selected: product.id == state.selectedProductId,
                                            primaryTextColor: textColor,
                                            secondaryTextColor: subtitleColor,
                                            accentColor: gradientColors[i],
                                            checkForegroundColor: environment.theme.list.itemCheckColors.foregroundColor,
                                            checkBorderColor: environment.theme.list.itemCheckColors.strokeColor
                                        )
                                    )
                                ),
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
                        
            let layoutPerks = {
                var i = 0
                var perksItems: [SectionGroupComponent.Item] = []
                for perk in state.configuration.perks {
                    let iconBackgroundColors = gradientColors[i]
                    perksItems.append(SectionGroupComponent.Item(
                        AnyComponentWithIdentity(
                            id: perk.identifier,
                            component: AnyComponent(
                                PerkComponent(
                                    iconName: perk.iconName,
                                    iconBackgroundColors: [
                                        iconBackgroundColors
                                    ],
                                    title: perk.title(strings: strings),
                                    titleColor: titleColor,
                                    subtitle: perk.subtitle(strings: strings),
                                    subtitleColor: subtitleColor,
                                    arrowColor: arrowColor
                                )
                            )
                        ),
                        action: { [weak state] in
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
                            }
                            
                            let isPremium = state?.isPremium == true
                            
                            var dismissImpl: (() -> Void)?
                            let controller = PremiumLimitsListScreen(context: accountContext, subject: demoSubject, source: .intro(state?.price), order: state?.configuration.perks, buttonText: isPremium ? strings.Common_OK : (state?.isAnnual == true ? strings.Premium_SubscribeForAnnual(state?.price ?? "–").string :  strings.Premium_SubscribeFor(state?.price ?? "–").string), isPremium: isPremium)
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
                            
//                            let controller = PremiumDemoScreen(
//                                context: accountContext,
//                                subject: demoSubject,
//                                source: .intro(state?.price),
//                                order: state?.configuration.perks,
//                                action: {
//                                    if state?.isPremium == false {
//                                        buy()
//                                    }
//                                }
//                            )
//                            controller.disposed = {
//                                updateIsFocused(false)
//                            }
//                            present(controller)
//                            updateIsFocused(true)
                            
                            addAppLogEvent(postbox: accountContext.account.postbox, type: "premium.promo_screen_tap", data: ["item": perk.identifier])
                        }
                    ))
                    i += 1
                }
                
                let perksSection = perksSection.update(
                    component: SectionGroupComponent(
                        items: perksItems,
                        backgroundColor: environment.theme.list.itemBlocksBackgroundColor,
                        selectionColor: environment.theme.list.itemHighlightedBackgroundColor,
                        separatorColor: environment.theme.list.itemBlocksSeparatorColor
                    ),
                    environment: {},
                    availableSize: CGSize(width: availableWidth - sideInsets, height: .greatestFiniteMagnitude),
                    transition: context.transition
                )
                context.add(perksSection
                    .position(CGPoint(x: availableWidth / 2.0, y: size.height + perksSection.size.height / 2.0))
                    .clipsToBounds(true)
                    .cornerRadius(10.0)
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
            
            if case .emojiStatus = context.component.source {
                layoutPerks()
                layoutOptions()
            } else {
                layoutOptions()
                layoutPerks()
                
                let textSideInset: CGFloat = 16.0
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
                
                let termsFont = Font.regular(13.0)
                let boldTermsFont = Font.semibold(13.0)
                let italicTermsFont = Font.italic(13.0)
                let boldItalicTermsFont = Font.semiboldItalic(13.0)
                let monospaceTermsFont = Font.monospace(13.0)
                let termsTextColor = environment.theme.list.freeTextColor
                let termsMarkdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: termsFont, textColor: termsTextColor), bold: MarkdownAttributeSet(font: termsFont, textColor: termsTextColor), link: MarkdownAttributeSet(font: termsFont, textColor: environment.theme.list.itemAccentColor), linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                })
                           
                var isGiftView = false
                if case let .gift(fromId, _, _) = context.component.source {
                    if fromId == context.component.context.account.peerId {
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
                
                let termsText = termsText.update(
                    component: MultilineTextComponent(
                        text: termsString,
                        horizontalAlignment: .natural,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.0,
                        highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.3),
                        highlightAction: { attributes in
                            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                            } else {
                                return nil
                            }
                        },
                        tapAction: { [weak environment] attributes, _ in
                            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String,
                                let controller = environment?.controller() as? PremiumIntroScreen, let navigationController = controller.navigationController as? NavigationController {
                                if url.hasPrefix("https://apps.apple.com/account/subscriptions") {
                                    controller.context.sharedContext.applicationBindings.openSubscriptions()
                                } else if url.hasPrefix("https://") || url.hasPrefix("tg://") {
                                    controller.context.sharedContext.openExternalUrl(context: controller.context, urlContext: .generic, url: url, forceExternal: !url.hasPrefix("tg://"), presentationData: controller.context.sharedContext.currentPresentationData.with({$0}), navigationController: nil, dismissInput: {})
                                } else {
                                    let context = controller.context
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
                                            context.sharedContext.openResolvedUrl(resolvedUrl, context: context, urlContext: .generic, navigationController: navigationController, forceExternal: false, openPeer: { peer, navigation in
                                            }, sendFile: nil, sendSticker: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { [weak controller] c, arguments in
                                                controller?.push(c)
                                            }, dismissInput: {}, contentContext: nil)
                                        })
                                    }
                                }
                            }
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
            
            size.height += scrollEnvironment.insets.bottom
            
            if context.component.source != .settings {
                size.height += 44.0
            }
            
            return size
        }
    }
}

class BlurredRectangle: Component {
    let color: UIColor
    let radius: CGFloat

    init(color: UIColor, radius: CGFloat = 0.0) {
        self.color = color
        self.radius = radius
    }

    static func ==(lhs: BlurredRectangle, rhs: BlurredRectangle) -> Bool {
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        if lhs.radius != rhs.radius {
            return false
        }
        return true
    }

    final class View: UIView {
        private let background: NavigationBackgroundNode

        init() {
            self.background = NavigationBackgroundNode(color: .clear)

            super.init(frame: CGRect())

            self.addSubview(self.background.view)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: BlurredRectangle, availableSize: CGSize, transition: Transition) -> CGSize {
            transition.setFrame(view: self.background.view, frame: CGRect(origin: CGPoint(), size: availableSize))
            self.background.updateColor(color: component.color, transition: .immediate)
            self.background.update(size: availableSize, cornerRadius: component.radius, transition: .immediate)

            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class PremiumIntroScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let source: PremiumSource
    let updateInProgress: (Bool) -> Void
    let present: (ViewController) -> Void
    let push: (ViewController) -> Void
    let completion: () -> Void
    
    init(context: AccountContext, source: PremiumSource, updateInProgress: @escaping (Bool) -> Void, present: @escaping (ViewController) -> Void, push: @escaping (ViewController) -> Void, completion: @escaping () -> Void) {
        self.context = context
        self.source = source
        self.updateInProgress = updateInProgress
        self.present = present
        self.push = push
        self.completion = completion
    }
        
    static func ==(lhs: PremiumIntroScreenComponent, rhs: PremiumIntroScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.source != rhs.source {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
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
        
        var isPremium: Bool?
        var otherPeerName: String?
        
        let animationCache: AnimationCache
        let animationRenderer: MultiAnimationRenderer
        
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
        
        init(context: AccountContext, source: PremiumSource, updateInProgress: @escaping (Bool) -> Void, present: @escaping (ViewController) -> Void, completion: @escaping () -> Void) {
            self.context = context
            self.updateInProgress = updateInProgress
            self.present = present
            self.completion = completion
            
            self.animationCache = context.animationCache
            self.animationRenderer = context.animationRenderer
            
            super.init()
            
            let availableProducts: Signal<[InAppPurchaseManager.Product], NoError>
            if let inAppPurchaseManager = context.inAppPurchaseManager {
                availableProducts = inAppPurchaseManager.availableProducts
            } else {
                availableProducts = .single([])
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let otherPeerName: Signal<String?, NoError>
            if case let .gift(fromPeerId, toPeerId, _) = source {
                let otherPeerId = fromPeerId != context.account.peerId ? fromPeerId : toPeerId
                otherPeerName = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: otherPeerId))
                |> map { peer -> String? in
                    return peer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                }
            } else if case let .profile(peerId) = source {
                otherPeerName = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                |> map { peer -> String? in
                    return peer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                }
            } else if case let .emojiStatus(peerId, _, _, _) = source {
                otherPeerName = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                |> map { peer -> String? in
                    return peer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                }
            } else {
                otherPeerName = .single(nil)
            }
            
            self.disposable = combineLatest(
                queue: Queue.mainQueue(),
                availableProducts,
                context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.PremiumPromo()),
                context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                |> map { peer -> Bool in
                    return peer?.isPremium ?? false
                },
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
                    strongSelf.isPremium = isPremium
                    strongSelf.otherPeerName = otherPeerName
                    
                    if !hadProducts {
                        strongSelf.selectedProductId = strongSelf.products?.last?.id
                        
                        for (_, video) in promoConfiguration.videos {
                            strongSelf.preloadDisposableSet.add(preloadVideoResource(postbox: context.account.postbox, resourceReference: .standalone(resource: video.resource), duration: 3.0).start())
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
                    self.emojiFileDisposable = (context.engine.stickers.resolveInlineStickers(fileIds: [emojiFileId])
                    |> deliverOnMainQueue).start(next: { [weak self] result in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.emojiFile = result[emojiFileId]
                        strongSelf.updated(transition: .immediate)
                    })
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
            guard let inAppPurchaseManager = self.context.inAppPurchaseManager,
                  let premiumProduct = self.products?.first(where: { $0.id == self.selectedProductId }), !self.inProgress else {
                return
            }
                        
            addAppLogEvent(postbox: self.context.account.postbox, type: "premium.promo_screen_accept")

            self.inProgress = true
            self.updateInProgress(true)
            self.updated(transition: .immediate)

            let _ = (self.context.engine.payments.canPurchasePremium(purpose: .subscription)
            |> deliverOnMainQueue).start(next: { [weak self] available in
                if let strongSelf = self {
                    if available {
                        strongSelf.paymentDisposable.set((inAppPurchaseManager.buyProduct(premiumProduct.storeProduct)
                        |> deliverOnMainQueue).start(next: { [weak self] status in
                            if let strongSelf = self, case .purchased = status {
                                strongSelf.activationDisposable.set((strongSelf.context.account.postbox.peerView(id: strongSelf.context.account.peerId)
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
                                |> deliverOnMainQueue).start(error: { [weak self] _ in
                                    if let strongSelf = self {
                                        strongSelf.inProgress = false
                                        strongSelf.updateInProgress(false)
                                        
                                        strongSelf.updated(transition: .immediate)
                                        
                                        addAppLogEvent(postbox: strongSelf.context.account.postbox, type: "premium.promo_screen_fail")
                                        
                                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                        let errorText = presentationData.strings.Premium_Purchase_ErrorUnknown
                                        let alertController = textAlertController(context: strongSelf.context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                                        strongSelf.present(alertController)
                                    }
                                }, completed: { [weak self] in
                                    if let strongSelf = self {
                                        let _ = updatePremiumPromoConfigurationOnce(account: strongSelf.context.account).start()
                                        strongSelf.inProgress = false
                                        strongSelf.updateInProgress(false)
                                        
                                        strongSelf.isPremium = true
                                        strongSelf.updated(transition: .easeInOut(duration: 0.25))
                                        strongSelf.completion()
                                    }
                                }))
                            }
                        }, error: { [weak self] error in
                            if let strongSelf = self {
                                strongSelf.inProgress = false
                                strongSelf.updateInProgress(false)
                                strongSelf.updated(transition: .immediate)

                                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
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
                                    case .cancelled:
                                        break
                                }
                                
                                if let errorText = errorText {
                                    addAppLogEvent(postbox: strongSelf.context.account.postbox, type: "premium.promo_screen_fail")
                                    
                                    let alertController = textAlertController(context: strongSelf.context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                                    strongSelf.present(alertController)
                                }
                            }
                        }))
                    } else {
                        strongSelf.inProgress = false
                        strongSelf.updateInProgress(false)
                        strongSelf.updated(transition: .immediate)
                    }
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
        return State(context: self.context, source: self.source, updateInProgress: self.updateInProgress, present: self.present, completion: self.completion)
    }
    
    static var body: Body {
        let background = Child(Rectangle.self)
        let scrollContent = Child(ScrollComponent<EnvironmentType>.self)
        let star = Child(PremiumStarComponent.self)
        let emoji = Child(EmojiHeaderComponent.self)
        let topPanel = Child(BlurredRectangle.self)
        let topSeparator = Child(Rectangle.self)
        let title = Child(MultilineTextComponent.self)
        let secondaryTitle = Child(MultilineTextWithEntitiesComponent.self)
        let bottomPanel = Child(BlurredRectangle.self)
        let bottomSeparator = Child(Rectangle.self)
        let button = Child(SolidRoundedButtonComponent.self)
        
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
            if case let .emojiStatus(_, fileId, _, _) = context.component.source {
                header = emoji.update(
                    component: EmojiHeaderComponent(
                        context: context.component.context,
                        animationCache: state.animationCache,
                        animationRenderer: state.animationRenderer,
                        placeholderColor: environment.theme.list.mediaPlaceholderColor,
                        accentColor: environment.theme.list.itemAccentColor,
                        fileId: fileId,
                        isVisible: starIsVisible,
                        hasIdleAnimations: state.hasIdleAnimations
                    ),
                    availableSize: CGSize(width: min(390.0, context.availableSize.width), height: 220.0),
                    transition: context.transition
                )
            } else {
                header = star.update(
                    component: PremiumStarComponent(
                        isIntro: isIntro,
                        isVisible: starIsVisible,
                        hasIdleAnimations: state.hasIdleAnimations
                    ),
                    availableSize: CGSize(width: min(390.0, context.availableSize.width), height: 220.0),
                    transition: context.transition
                )
            }
            
            let topPanel = topPanel.update(
                component: BlurredRectangle(
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
            if case .emojiStatus = context.component.source {
                titleString = environment.strings.Premium_Title
            } else if case .giftTerms = context.component.source {
                titleString = environment.strings.Premium_Title
            } else if case .gift = context.component.source {
                titleString = environment.strings.Premium_GiftedTitle
            } else if state.isPremium == true {
                titleString = environment.strings.Premium_SubscribedTitle
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
            
            let textColor = environment.theme.list.itemPrimaryTextColor
            let accentColor: UIColor
            if case .emojiStatus = context.component.source {
                accentColor = environment.theme.list.itemAccentColor
            } else {
                accentColor = UIColor(rgb: 0x597cf5)
            }
            
            let textFont = Font.bold(18.0)
            let boldTextFont = Font.bold(18.0)
            
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: accentColor), linkAttribute: { _ in
                return nil
            })
            
            var loadedEmojiPack: LoadedStickerPack?
            var highlightableLinks = false
            let secondaryTitleText: String
            if let otherPeerName = state.otherPeerName {
                if case let .emojiStatus(_, _, file, maybeEmojiPack) = context.component.source, let emojiPack = maybeEmojiPack, case let .result(info, _, _) = emojiPack {
                    loadedEmojiPack = maybeEmojiPack
                    highlightableLinks = true
                    
                    var packReference: StickerPackReference?
                    if let file = file {
                        for attribute in file.attributes {
                            if case let .CustomEmoji(_, _, reference) = attribute {
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
                } else if case let .gift(fromPeerId, _, duration) = context.component.source {
                    if fromPeerId == context.component.context.account.peerId {
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
            
            let secondaryAttributedText = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(secondaryTitleText, attributes: markdownAttributes))
            if let emojiFile = state.emojiFile {
                let range = (secondaryAttributedText.string as NSString).range(of: "#")
                if range.location != NSNotFound {
                    secondaryAttributedText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: emojiFile.fileId.id, file: emojiFile), range: range)
                }
            }
            let accountContext = context.component.context
            let presentController = context.component.present
            
            let secondaryTitle = secondaryTitle.update(
                component: MultilineTextWithEntitiesComponent(
                    context: context.component.context,
                    animationCache: context.state.animationCache,
                    animationRenderer: context.state.animationRenderer,
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
                        if let emojiFile = state?.emojiFile, let controller = environment?.controller() as? PremiumIntroScreen, let navigationController = controller.navigationController as? NavigationController {
                            for attribute in emojiFile.attributes {
                                if case let .CustomEmoji(_, _, packReference) = attribute, let packReference = packReference {
                                    let controller = accountContext.sharedContext.makeStickerPackScreen(context: accountContext, updatedPresentationData: nil, mainStickerPack: packReference, stickerPacks: [packReference], loadedStickerPacks: loadedEmojiPack.flatMap { [$0] } ?? [], parentNavigationController: navigationController, sendSticker: { _, _, _ in
                                        return false
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
            let bottomPanelHeight: CGFloat = state.isPremium == true ? bottomInset : bottomPanelPadding + 50.0 + bottomInset
                       
            let scrollContent = scrollContent.update(
                component: ScrollComponent<EnvironmentType>(
                    content: AnyComponent(PremiumIntroScreenContentComponent(
                        context: context.component.context,
                        source: context.component.source,
                        isPremium: state.isPremium,
                        otherPeerName: state.otherPeerName,
                        products: state.products,
                        selectedProductId: state.selectedProductId,
                        promoConfiguration: state.promoConfiguration,
                        present: context.component.present,
                        selectProduct: { [weak state] productId in
                            state?.selectProduct(productId)
                        },
                        buy: { [weak state] in
                            state?.buy()
                        },
                        updateIsFocused: { [weak state] isFocused in
                            state?.updateIsFocused(isFocused)
                        }
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
            
            var isGiftView = false
            if case let .gift(fromId, _, _) = context.component.source {
                if fromId == context.component.context.account.peerId {
                    isGiftView = true
                }
            }
                        
            if state.isPremium == true || isGiftView {
                
            } else {
                
                let sideInset: CGFloat = 16.0
                let button = button.update(
                    component: SolidRoundedButtonComponent(
                        title: state.isAnnual ? environment.strings.Premium_SubscribeForAnnual(state.price ?? "—").string : environment.strings.Premium_SubscribeFor(state.price ?? "—").string,
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
                            state.buy()
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - environment.safeInsets.left - environment.safeInsets.right, height: 50.0),
                    transition: context.transition)
                               
                let bottomPanel = bottomPanel.update(
                    component: BlurredRectangle(
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
                    .disappear(Transition.Disappear { view, transition, completion in
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
                    .disappear(Transition.Disappear { view, transition, completion in
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
                    .disappear(Transition.Disappear { view, transition, completion in
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
    fileprivate let context: AccountContext
    
    private var didSetReady = false
    private let _ready = Promise<Bool>()
    public override var ready: Promise<Bool> {
        return self._ready
    }
    
    public weak var sourceView: UIView?
    public weak var containerView: UIView?
    public var animationColor: UIColor?
    
    public init(context: AccountContext, modal: Bool = true, source: PremiumSource) {
        self.context = context
            
        var updateInProgressImpl: ((Bool) -> Void)?
        var pushImpl: ((ViewController) -> Void)?
        var presentImpl: ((ViewController) -> Void)?
        var completionImpl: (() -> Void)?
        super.init(context: context, component: PremiumIntroScreenComponent(
            context: context,
            source: source,
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
            }
        ), navigationBarAppearance: .transparent)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        if modal {
            let cancelItem = UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
            self.navigationItem.setLeftBarButton(cancelItem, animated: false)
            self.navigationPresentation = .modal
        } else {
            self.navigationPresentation = .modalInLargeLayout
        }
        
        updateInProgressImpl = { [weak self] inProgress in
            if let strongSelf = self {
                strongSelf.navigationItem.leftBarButtonItem?.isEnabled = !inProgress
                strongSelf.view.disablesInteractiveTransitionGestureRecognizer = inProgress
                strongSelf.view.disablesInteractiveModalDismiss = inProgress
            }
        }
        
        presentImpl = { [weak self] c in
            self?.present(c, in: .window(.root))
        }
        
        pushImpl = { [weak self] c in
            self?.push(c)
        }
        
        completionImpl = { [weak self] in
            if let strongSelf = self {
                strongSelf.view.addSubview(ConfettiView(frame: strongSelf.view.bounds))
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if !self.didSetReady {
            if let view = self.node.hostView.findTaggedView(tag: PremiumStarComponent.View.Tag()) as? PremiumStarComponent.View {
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
