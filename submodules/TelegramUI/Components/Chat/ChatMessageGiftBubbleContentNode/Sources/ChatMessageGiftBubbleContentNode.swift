import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import ComponentFlow
import TelegramCore
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import LocalizedPeerData
import UrlEscaping
import TelegramStringFormatting
import WallpaperBackgroundNode
import ReactionSelectionNode
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import ChatControllerInteraction
import ShimmerEffect
import Markdown
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import TextNodeWithEntities
import InvisibleInkDustNode
import PeerInfoCoverComponent

private func attributedServiceMessageString(theme: ChatPresentationThemeData, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, message: EngineMessage, accountPeerId: EnginePeer.Id) -> NSAttributedString? {
    return universalServiceMessageString(presentationData: (theme.theme, theme.wallpaper), strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, message: message, accountPeerId: accountPeerId, forChatList: false, forForumOverview: false, forAdditionalServiceMessage: true)
}

public class ChatMessageGiftBubbleContentNode: ChatMessageBubbleContentNode {
    private let labelNode: TextNode
    private var backgroundNode: WallpaperBubbleBackgroundNode?
    private let backgroundMaskNode: ASImageNode
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private let patternView = ComponentView<Empty>()
    private let mediaBackgroundMaskNode: ASImageNode
    private var mediaBackgroundContent: WallpaperBubbleBackgroundNode?
    private let titleNode: TextNode
    private let subtitleNode: TextNodeWithEntities
    private var spoilerSubtitleNode: TextNodeWithEntities?
    private let textClippingNode: ASDisplayNode
    private var dustNode: InvisibleInkDustNode?
    private let placeholderNode: StickerShimmerEffectNode
    private let animationNode: AnimatedStickerNode
    
    private let modelTitleTextNode: TextNode
    private let modelValueTextNode: TextNode
    private let backdropTitleTextNode: TextNode
    private let backdropValueTextNode: TextNode
    private let symbolTitleTextNode: TextNode
    private let symbolValueTextNode: TextNode
    
    private let ribbonBackgroundNode: ASImageNode
    private let ribbonTextNode: TextNode
    
    private var shimmerEffectNode: ShimmerEffectForegroundNode?
    private let buttonNode: HighlightTrackingButtonNode
    private let buttonStarsNode: PremiumStarsNode
    private let buttonContentNode: ASDisplayNode
    private let buttonTitleNode: TextNode
    private var buttonIconNode: DefaultAnimatedStickerNodeImpl?
    
    private let moreTextNode: TextNode
    
    private var maskView: UIImageView?
    private var maskOverlayView: UIView?
    
    private var cachedMaskBackgroundImage: (CGPoint, UIImage, [CGRect])?
    private var absoluteRect: (CGRect, CGSize)?
    
    private var isPlaying: Bool = false
    
    private var isExpanded: Bool = false
    private var appliedIsExpanded: Bool = false
    
    private var isStarGift = false
    
    private var currentProgressDisposable: Disposable?
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            let wasVisible = oldValue != .none
            let isVisible = self.visibility != .none
            
            if wasVisible != isVisible {
                self.visibilityStatus = isVisible
                
                switch self.visibility {
                case .none:
                    self.subtitleNode.visibilityRect = nil
                case let .visible(_, subRect):
                    var subRect = subRect
                    subRect.origin.x = 0.0
                    subRect.size.width = 10000.0
                    self.subtitleNode.visibilityRect = subRect
                }
            }
        }
    }
    
    private var visibilityStatus: Bool? {
        didSet {
            if self.visibilityStatus != oldValue {
                self.updateVisibility()
            }
        }
    }
    
    private var fetchDisposable: Disposable?
    private var setupTimestamp: Double?
    
    private var cachedTonImage: (UIImage, UIColor)?
    
    required public init() {
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.displaysAsynchronously = false

        self.backgroundMaskNode = ASImageNode()
        
        self.mediaBackgroundMaskNode = ASImageNode()
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.subtitleNode = TextNodeWithEntities()
        self.subtitleNode.textNode.isUserInteractionEnabled = false
        self.subtitleNode.textNode.displaysAsynchronously = false
        
        self.textClippingNode = ASDisplayNode()
        self.textClippingNode.clipsToBounds = true
        
        self.modelTitleTextNode = TextNode()
        self.modelTitleTextNode.isUserInteractionEnabled = false
        self.modelTitleTextNode.displaysAsynchronously = false
        self.modelValueTextNode = TextNode()
        self.modelValueTextNode.isUserInteractionEnabled = false
        self.modelValueTextNode.displaysAsynchronously = false
        self.backdropTitleTextNode = TextNode()
        self.backdropTitleTextNode.isUserInteractionEnabled = false
        self.backdropTitleTextNode.displaysAsynchronously = false
        self.backdropValueTextNode = TextNode()
        self.backdropValueTextNode.isUserInteractionEnabled = false
        self.backdropValueTextNode.displaysAsynchronously = false
        self.symbolTitleTextNode = TextNode()
        self.symbolTitleTextNode.isUserInteractionEnabled = false
        self.symbolTitleTextNode.displaysAsynchronously = false
        self.symbolValueTextNode = TextNode()
        self.symbolValueTextNode.isUserInteractionEnabled = false
        self.symbolValueTextNode.displaysAsynchronously = false
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.clipsToBounds = true
        self.buttonNode.cornerRadius = 17.0
                        
        self.placeholderNode = StickerShimmerEffectNode()
        self.placeholderNode.isUserInteractionEnabled = false
        self.placeholderNode.alpha = 0.75
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()

        self.buttonStarsNode = PremiumStarsNode()
        
        self.buttonContentNode = ASDisplayNode()
        self.buttonContentNode.isUserInteractionEnabled = false
        
        self.buttonTitleNode = TextNode()
        self.buttonTitleNode.displaysAsynchronously = false
                
        self.ribbonBackgroundNode = ASImageNode()
        self.ribbonBackgroundNode.displaysAsynchronously = false
        
        self.ribbonTextNode = TextNode()
        self.ribbonTextNode.isUserInteractionEnabled = false
        self.ribbonTextNode.displaysAsynchronously = false
        
        self.moreTextNode = TextNode()
        self.moreTextNode.isUserInteractionEnabled = false
        self.moreTextNode.displaysAsynchronously = false
        
        super.init()

        self.addSubnode(self.labelNode)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textClippingNode)
        self.textClippingNode.addSubnode(self.subtitleNode.textNode)
        self.addSubnode(self.placeholderNode)
        self.addSubnode(self.animationNode)
        self.addSubnode(self.moreTextNode)
        
        self.addSubnode(self.buttonNode)
        self.buttonNode.addSubnode(self.buttonStarsNode)
        self.buttonNode.addSubnode(self.buttonContentNode)
        
        self.buttonContentNode.addSubnode(self.buttonTitleNode)
        
        self.addSubnode(self.ribbonBackgroundNode)
        self.addSubnode(self.ribbonTextNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.buttonNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonNode.alpha = 0.4
                } else {
                    strongSelf.buttonNode.alpha = 1.0
                    strongSelf.buttonNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.fetchDisposable?.dispose()
        self.currentProgressDisposable?.dispose()
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.maskView = UIImageView()
        
        let maskOverlayView = UIView()
        maskOverlayView.alpha = 0.0
        maskOverlayView.backgroundColor = .white
        self.maskOverlayView = maskOverlayView
        
        self.maskView?.addSubview(maskOverlayView)
    }
    
    @objc private func buttonPressed() {
        guard let item = self.item else {
            return
        }
        let _ = item.controllerInteraction.openMessage(item.message, OpenMessageParams(mode: .default, progress: self.makeProgress()))
    }
    
    private func expandPressed() {
        self.isExpanded = !self.isExpanded
        guard let item = self.item else{
            return
        }
        let _ = item.controllerInteraction.requestMessageUpdate(item.message.id, false)
    }
    
    private func makeProgress() -> Promise<Bool> {
        let progress = Promise<Bool>()
        self.currentProgressDisposable?.dispose()
        self.currentProgressDisposable = (progress.get()
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] hasProgress in
            guard let self else {
                return
            }
            self.displayProgress = hasProgress
        })
        return progress
    }
    
    private var displayProgress = false {
        didSet {
            if self.displayProgress != oldValue {
                if self.displayProgress {
                    self.startShimmering()
                } else {
                    self.stopShimmering()
                }
            }
        }
    }
    
    private func startShimmering() {        
        let shimmerEffectNode: ShimmerEffectForegroundNode
        if let current = self.shimmerEffectNode {
            shimmerEffectNode = current
        } else {
            shimmerEffectNode = ShimmerEffectForegroundNode()
            shimmerEffectNode.cornerRadius = 17.0
            self.buttonNode.insertSubnode(shimmerEffectNode, at: 0)
            self.shimmerEffectNode = shimmerEffectNode
        }
        
        shimmerEffectNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        let backgroundFrame = self.buttonNode.frame
        shimmerEffectNode.frame = CGRect(origin: .zero, size: backgroundFrame.size)
        shimmerEffectNode.updateAbsoluteRect(CGRect(origin: .zero, size: backgroundFrame.size), within: backgroundFrame.size)
        shimmerEffectNode.update(backgroundColor: .clear, foregroundColor: UIColor.white.withAlphaComponent(0.15), horizontal: true, effectSize: nil, globalTimeOffset: false, duration: nil)
    }
    
    private func stopShimmering() {
        guard let shimmerEffectNode = self.shimmerEffectNode else {
            return
        }
        self.shimmerEffectNode = nil
        shimmerEffectNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak shimmerEffectNode] _ in
            shimmerEffectNode?.removeFromSupernode()
        })
    }
    
    private func removePlaceholder(animated: Bool) {
        self.placeholderNode.alpha = 0.0
        if !animated {
            self.placeholderNode.removeFromSupernode()
        } else {
            self.placeholderNode.layer.animateAlpha(from: self.placeholderNode.alpha, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                self?.placeholderNode.removeFromSupernode()
            })
        }
    }
        
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, unboundSize: CGSize?, maxWidth: CGFloat, layout: (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNodeWithEntities.asyncLayout(self.subtitleNode)
        let makeSpoilerSubtitleLayout = TextNodeWithEntities.asyncLayout(self.spoilerSubtitleNode)
        let makeButtonTitleLayout = TextNode.asyncLayout(self.buttonTitleNode)
        let makeRibbonTextLayout = TextNode.asyncLayout(self.ribbonTextNode)
        let makeMeasureTextLayout = TextNode.asyncLayout(nil)
        let makeMoreTextLayout = TextNode.asyncLayout(self.moreTextNode)
        
        let makeModelTitleLayout = TextNode.asyncLayout(self.modelTitleTextNode)
        let makeModelValueLayout = TextNode.asyncLayout(self.modelValueTextNode)
        let makeBackdropTitleLayout = TextNode.asyncLayout(self.backdropTitleTextNode)
        let makeBackdropValueLayout = TextNode.asyncLayout(self.backdropValueTextNode)
        let makeSymbolTitleLayout = TextNode.asyncLayout(self.symbolTitleTextNode)
        let makeSymbolValueLayout = TextNode.asyncLayout(self.symbolValueTextNode)
    
        let cachedMaskBackgroundImage = self.cachedMaskBackgroundImage
        
        let currentIsExpanded = self.isExpanded
        
        let cachedTonImage = self.cachedTonImage
        
        return { item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 0.0, hidesBackground: .always, forceFullCorners: false, forceAlignment: .center)
                        
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                var giftSize = CGSize(width: 220.0, height: 240.0)
                
                let incoming: Bool
                if item.message.id.peerId == item.context.account.peerId && item.message.forwardInfo == nil {
                    incoming = true
                } else {
                    incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                }
                
                let attributedString = attributedServiceMessageString(theme: item.presentationData.theme, strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, dateTimeFormat: item.presentationData.dateTimeFormat, message: EngineMessage(item.message), accountPeerId: item.context.account.peerId)
            
                var primaryTextColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                                
                var months: Int32 = 3
                var animationName: String = ""
                var animationFile: TelegramMediaFile?
                var title = item.presentationData.strings.Notification_PremiumGift_Title
                var text = ""
                var subtitleColor = primaryTextColor
                var entities: [MessageTextEntity] = []
                var buttonTitle = item.presentationData.strings.Notification_PremiumGift_View
                var buttonIcon: String?
                var ribbonTitle = ""
                var textSpacing: CGFloat = 0.0
                var isStarGift = false
                
                var modelTitle: String?
                var modelValue: String?
                var backdropTitle: String?
                var backdropValue: String?
                var symbolTitle: String?
                var symbolValue: String?
                var uniqueBackgroundColor: UIColor?
                var uniqueSecondBackgroundColor: UIColor?
                var uniquePatternColor: UIColor?
                var uniquePatternFile: TelegramMediaFile?
                
                let isStoryEntity = item.message.id.id == -1
                var hasServiceMessage = !isStoryEntity
                
                for media in item.message.media {
                    if let action = media as? TelegramMediaAction {
                        switch action.action {
                        case let .giftPremium(_, _, monthsValue, _, _, giftText, giftEntities):
                            months = monthsValue
                            if months == 12 {
                                title = item.presentationData.strings.Notification_PremiumGift_YearsTitle(1)
                            } else {
                                title = item.presentationData.strings.Notification_PremiumGift_MonthsTitle(months)
                            }
                            if let giftText, !giftText.isEmpty {
                                text = giftText
                                entities = giftEntities ?? []
                            } else {
                                text = item.presentationData.strings.Notification_PremiumGift_SubscriptionDescription
                            }
                        case let .giftStars(_, _, count, _, _, _):
                            if count <= 1000 {
                                months = 3
                            } else if count < 2500 {
                                months = 6
                            } else {
                                months = 12
                            }
                            var peerName = ""
                            if let peer = item.message.peers[item.message.id.peerId] {
                                peerName = EnginePeer(peer).compactDisplayTitle
                            }
                            title = item.presentationData.strings.Notification_StarsGift_Title(Int32(count))
                            text = incoming ? item.presentationData.strings.Notification_StarsGift_Subtitle : item.presentationData.strings.Notification_StarsGift_SubtitleYou(peerName).string
                        case let .giftTon(_, amount, _, cryptoAmount, _):
                            if amount < 10000000000 {
                                months = 1000
                            } else if amount < 50000000000 {
                                months = 2000
                            } else {
                                months = 3000
                            }
                            
                            var peerName = ""
                            if let peer = item.message.peers[item.message.id.peerId] {
                                peerName = EnginePeer(peer).compactDisplayTitle
                            }
                            let cryptoAmount = cryptoAmount ?? 0
                            
                            title = "$ \(formatTonAmountText(cryptoAmount, dateTimeFormat: item.presentationData.dateTimeFormat, maxDecimalPositions: 3))"
                            text = incoming ? item.presentationData.strings.Notification_Ton_Subtitle : item.presentationData.strings.Notification_Ton_SubtitleYou(peerName).string
                            buttonTitle = ""
                        case let .prizeStars(count, _, channelId, _, _):
                            if count <= 1000 {
                                months = 3
                            } else if count < 2500 {
                                months = 6
                            } else {
                                months = 12
                            }
                            var peerName = ""
                            if let channelId, let channel = item.message.peers[channelId] {
                                peerName = EnginePeer(channel).compactDisplayTitle
                            }
                            title = item.presentationData.strings.Notification_StarsGiveaway_Title
                            let starsString = item.presentationData.strings.Notification_StarsGiveaway_Subtitle_Stars(Int32(count)).replacingOccurrences(of: " ", with: "\u{00A0}")
                            text = item.presentationData.strings.Notification_StarsGiveaway_Subtitle(peerName, starsString).string
                        case let .giftCode(_, fromGiveaway, unclaimed, channelId, monthsValue, _, _, _, _, giftText, giftEntities):
                            if channelId == nil {
                                months = monthsValue
                                if months == 12 {
                                    title = item.presentationData.strings.Notification_PremiumGift_YearsTitle(1)
                                } else {
                                    title = item.presentationData.strings.Notification_PremiumGift_MonthsTitle(months)
                                }
                                if let giftText, !giftText.isEmpty {
                                    text = giftText
                                    entities = giftEntities ?? []
                                } else {
                                    text = item.presentationData.strings.Notification_PremiumGift_SubscriptionDescription
                                }
                                if item.message.author?.id != item.context.account.peerId {
                                    buttonTitle = item.presentationData.strings.Notification_PremiumGift_UseGift
                                }
                            } else {
                                giftSize.width += 34.0
                                textSpacing += 13.0
                                
                                if unclaimed {
                                    title = item.presentationData.strings.Notification_PremiumPrize_Unclaimed
                                } else {
                                    title = item.presentationData.strings.Notification_PremiumPrize_Title
                                }
                                var peerName = ""
                                if let channelId, let channel = item.message.peers[channelId] {
                                    peerName = EnginePeer(channel).compactDisplayTitle
                                }
                                if unclaimed {
                                    text = item.presentationData.strings.Notification_PremiumPrize_UnclaimedText(peerName, item.presentationData.strings.Notification_PremiumPrize_Months(monthsValue)).string
                                } else if fromGiveaway {
                                    text = item.presentationData.strings.Notification_PremiumPrize_GiveawayText(peerName, item.presentationData.strings.Notification_PremiumPrize_Months(monthsValue)).string
                                } else {
                                    text = item.presentationData.strings.Notification_PremiumPrize_GiftText(peerName, item.presentationData.strings.Notification_PremiumPrize_Months(monthsValue)).string
                                }
                                
                                months = monthsValue
                                buttonTitle = item.presentationData.strings.Notification_PremiumPrize_View
                                hasServiceMessage = false
                            }
                        case let .starGift(gift, convertStars, giftText, giftEntities, _, savedToProfile, converted, upgraded, canUpgrade, upgradeStars, isRefunded, _, channelPeerId, senderPeerId, _):
                            if case let .generic(gift) = gift {
                                isStarGift = true
                                var authorName = item.message.author.flatMap { EnginePeer($0) }?.compactDisplayTitle ?? ""
                                
                                let isSelfGift = item.message.id.peerId == item.context.account.peerId
                                let isChannelGift = item.message.id.peerId.namespace == Namespaces.Peer.CloudChannel || channelPeerId != nil
                                if isSelfGift {
                                    title = item.presentationData.strings.Notification_StarGift_Self_Title
                                } else {
                                    if let senderPeerId, let name = item.message.peers[senderPeerId].flatMap(EnginePeer.init)?.compactDisplayTitle {
                                        authorName = name
                                    }
                                    title = item.presentationData.strings.Notification_StarGift_Title(authorName).string
                                }
                                if let giftText, !giftText.isEmpty {
                                    text = giftText
                                    entities = giftEntities ?? []
                                } else {
                                    if isRefunded {
                                        text = item.presentationData.strings.Notification_StarGift_Subtitle_Refunded
                                    } else if upgraded {
                                        text = item.presentationData.strings.Notification_StarGift_Subtitle_Upgraded
                                    } else if incoming {
                                        if converted {
                                            text = item.presentationData.strings.Notification_StarGift_Subtitle_Converted(item.presentationData.strings.Notification_StarGift_Subtitle_Converted_Stars(Int32(convertStars ?? 0))).string
                                        } else if upgradeStars != nil {
                                            text = item.presentationData.strings.Notification_StarGift_Subtitle_Upgrade
                                        } else if isSelfGift && canUpgrade {
                                            text = item.presentationData.strings.Notification_StarsGift_Subtitle_Self
                                        } else if savedToProfile {
                                            if let convertStars {
                                                text =  item.presentationData.strings.Notification_StarGift_Subtitle_Displaying(item.presentationData.strings.Notification_StarGift_Subtitle_Displaying_Stars(Int32(convertStars))).string
                                            } else {
                                                text = item.presentationData.strings.Notification_StarGift_Bot_Subtitle_Displaying
                                            }
                                        } else {
                                            if let convertStars, convertStars > 0 {
                                                if isChannelGift {
                                                    text = item.presentationData.strings.Notification_StarGift_Subtitle_Channel(item.presentationData.strings.Notification_StarGift_Subtitle_Stars(Int32(convertStars))).string
                                                } else {
                                                    text = item.presentationData.strings.Notification_StarGift_Subtitle(item.presentationData.strings.Notification_StarGift_Subtitle_Stars(Int32(convertStars))).string
                                                }
                                            } else {
                                                text = item.presentationData.strings.Notification_StarGift_Bot_Subtitle
                                            }
                                        }
                                    } else {
                                        var peerName = ""
                                        if let peer = item.message.peers[item.message.id.peerId] {
                                            peerName = EnginePeer(peer).compactDisplayTitle
                                        }
                                        if peerName.isEmpty {
                                            if let convertStars, convertStars > 0 {
                                                let starsString = item.presentationData.strings.Notification_StarGift_Subtitle_Stars(Int32(convertStars)).replacingOccurrences(of: " ", with: "\u{00A0}")
                                                text = item.presentationData.strings.Notification_StarGift_Subtitle(starsString).string
                                            } else {
                                                text =  item.presentationData.strings.Notification_StarGift_Bot_Subtitle
                                            }
                                        } else {
                                            if upgradeStars != nil {
                                                text =  item.presentationData.strings.Notification_StarGift_Subtitle_Upgrade_Other(peerName).string
                                            } else if let convertStars, convertStars > 0 {
                                                let starsString = item.presentationData.strings.Notification_StarGift_Subtitle_Other_Stars(Int32(convertStars)).replacingOccurrences(of: " ", with: "\u{00A0}")
                                                let formattedString = item.presentationData.strings.Notification_StarGift_Subtitle_Other(peerName, starsString)
                                                text = formattedString.string
                                                if let starsRange = formattedString.ranges.last {
                                                    entities.append(MessageTextEntity(range: starsRange.range.lowerBound ..< starsRange.range.upperBound, type: .Bold))
                                                }
                                            }
                                        }
                                    }
                                }
                                animationFile = gift.file
                                if let availability = gift.availability {
                                    let availabilityString: String
                                    if availability.total > 9999 {
                                        availabilityString = compactNumericCountString(Int(availability.total))
                                    } else {
                                        availabilityString = "\(availability.total)"
                                    }
                                    ribbonTitle = item.presentationData.strings.Notification_StarGift_OneOf(availabilityString).string
                                }
                                if incoming || item.presentationData.isPreview, let upgradeStars, upgradeStars > 0, !upgraded {
                                    buttonTitle = item.presentationData.strings.Notification_StarGift_Unpack
                                    buttonIcon = "GiftUnpack"
                                } else {
                                    buttonTitle = item.presentationData.strings.Notification_StarGift_View
                                }
                            }
                        case let .starGiftUnique(gift, isUpgrade, _, _, _, _, isRefunded, _, _, _, _, _, _):
                            if case let .unique(uniqueGift) = gift {
                                isStarGift = true
                                
                                let isSelfGift = item.message.id.peerId == item.context.account.peerId
                                let authorName: String
                                if isUpgrade {
                                    if item.message.author?.id == item.context.account.peerId {
                                        authorName = item.message.peers[item.message.id.peerId].flatMap { EnginePeer($0) }?.compactDisplayTitle ?? ""
                                    } else {
                                        authorName = item.associatedData.accountPeer?.compactDisplayTitle ?? ""
                                    }
                                } else {
                                    authorName = item.message.author.flatMap { EnginePeer($0) }?.compactDisplayTitle ?? ""
                                }
                                if isSelfGift {
                                    title = item.presentationData.strings.Notification_StarGift_Self_Title
                                } else if item.message.id.peerId.isTelegramNotifications {
                                    title = item.presentationData.strings.Notification_StarGift_TitleShort
                                } else {
                                    title = isStoryEntity ? uniqueGift.title : item.presentationData.strings.Notification_StarGift_Title(authorName).string
                                }
                                text = isStoryEntity ? "**\(item.presentationData.strings.Notification_StarGift_Collectible) #\(presentationStringsFormattedNumber(uniqueGift.number, item.presentationData.dateTimeFormat.groupingSeparator))**" : "**\(uniqueGift.title) #\(presentationStringsFormattedNumber(uniqueGift.number, item.presentationData.dateTimeFormat.groupingSeparator))**"
                                ribbonTitle = isStoryEntity ? "" : item.presentationData.strings.Notification_StarGift_Gift
                                buttonTitle = isStoryEntity ? "" : item.presentationData.strings.Notification_StarGift_View
                                modelTitle = item.presentationData.strings.Notification_StarGift_Model
                                backdropTitle = item.presentationData.strings.Notification_StarGift_Backdrop
                                symbolTitle = item.presentationData.strings.Notification_StarGift_Symbol
                                
                                for attribute in uniqueGift.attributes {
                                    switch attribute {
                                    case let .model(name, file, _):
                                        modelValue = name
                                        animationFile = file
                                    case let .backdrop(name, _, innerColor, outerColor, patternColor, _, _):
                                        uniqueBackgroundColor = UIColor(rgb: UInt32(bitPattern: outerColor))
                                        uniqueSecondBackgroundColor = UIColor(rgb: UInt32(bitPattern: innerColor))
                                        uniquePatternColor = UIColor(rgb: UInt32(bitPattern: patternColor))
                                        backdropValue = name
                                        primaryTextColor = UIColor(rgb: 0xffffff)
                                        subtitleColor = UIColor(rgb: UInt32(bitPattern: innerColor)).withMultiplied(hue: 1.0, saturation: 1.02, brightness: 1.25).mixedWith(UIColor.white, alpha: 0.3)
                                    case let .pattern(name, file, _):
                                        symbolValue = name
                                        uniquePatternFile = file
                                    default:
                                        break
                                    }
                                }
                            } else if isRefunded, case let .generic(gift) = gift {
                                isStarGift = true
                                let authorName = item.message.author.flatMap { EnginePeer($0) }?.compactDisplayTitle ?? ""
                                title = item.presentationData.strings.Notification_StarGift_Title(authorName).string
                                text = item.presentationData.strings.Notification_StarGift_Subtitle_Refunded
                                animationFile = gift.file
                            }
                        default:
                            break
                        }
                    }
                }
                
                switch months {
                case 1000:
                    animationName = "GiftDiamond1"
                case 2000:
                    animationName = "GiftDiamond2"
                case 3000:
                    animationName = "GiftDiamond3"
                case 12:
                    animationName = "Gift12"
                case 6:
                    animationName = "Gift6"
                case 3:
                    animationName = "Gift3"
                default:
                    animationName = "Gift3"
                }
                
                let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: constrainedSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let titleAttributedString = NSMutableAttributedString(attributedString: NSAttributedString(string: title, font: Font.semibold(15.0), textColor: primaryTextColor, paragraphAlignment: .center))
                var updatedCachedTonImage: (UIImage, UIColor)? = cachedTonImage
                if let range = titleAttributedString.string.range(of: "$") {
                    if updatedCachedTonImage == nil || updatedCachedTonImage?.1 != primaryTextColor {
                        if let image = generateTintedImage(image: UIImage(bundleImageName: "Ads/TonAbout"), color: primaryTextColor) {
                            let imageScale: CGFloat = 0.8
                            let imageSize = CGSize(width: floor(image.size.width * imageScale), height: floor(image.size.height * imageScale))
                            updatedCachedTonImage = (generateImage(CGSize(width: imageSize.width + 2.0, height: imageSize.height), opaque: false, scale: nil, rotatedContext: { size, context in
                                context.clear(CGRect(origin: CGPoint(), size: size))
                                UIGraphicsPushContext(context)
                                defer {
                                    UIGraphicsPopContext()
                                }
                                image.draw(in: CGRect(origin: CGPoint(x: 2.0, y: 0.0), size: imageSize))
                            })!, primaryTextColor)
                        }
                    }
                    if let tonImage = updatedCachedTonImage?.0 {
                        titleAttributedString.addAttribute(.attachment, value: tonImage, range: NSRange(range, in: titleAttributedString.string))
                        titleAttributedString.addAttribute(.foregroundColor, value: primaryTextColor, range: NSRange(range, in: titleAttributedString.string))
                        titleAttributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: titleAttributedString.string))
                        titleAttributedString.addAttribute(.kern, value: 2.0, range: NSRange(range, in: titleAttributedString.string))
                    }
                }
                
                let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: giftSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (moreLayout, moreApply) = makeMoreTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Notification_PremiumGift_More, font: Font.semibold(13.0), textColor: primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: giftSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let attributedText: NSAttributedString
                if !entities.isEmpty {
                    attributedText = stringWithAppliedEntities(text, entities: entities, baseColor: primaryTextColor, linkColor: primaryTextColor, baseFont: Font.regular(13.0), linkFont: Font.regular(13.0), boldFont: Font.semibold(13.0), italicFont: Font.italic(13.0), boldItalicFont: Font.semiboldItalic(13.0), fixedFont: Font.monospace(13.0), blockQuoteFont: Font.regular(13.0), message: nil)
                } else {
                    attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: subtitleColor),
                        bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: subtitleColor),
                        link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: subtitleColor),
                        linkAttribute: { url in
                            return ("URL", url)
                        }
                    ), textAlignment: .center)
                }
                
                let textConstrainedSize = CGSize(width: giftSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude)
                let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (_, spoilerSubtitleApply) = makeSpoilerSubtitleLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets(), displaySpoilers: true))
                
                var canExpand = false
                var clippedTextHeight: CGFloat = subtitleLayout.size.height
                if subtitleLayout.numberOfLines > 4 {
                    let (measuredTextLayout, _) = makeMeasureTextLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 4, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                    canExpand = true
                    if !currentIsExpanded {
                        clippedTextHeight = measuredTextLayout.size.height
                    }
                }
                
                let infoConstrainedSize = CGSize(width: (giftSize.width - 32.0) * 0.7, height: CGFloat.greatestFiniteMagnitude)
                let modelTitleLayoutAndApply: (TextNodeLayout, () -> TextNode)?
                if let modelTitle {
                    modelTitleLayoutAndApply = makeModelTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: modelTitle, font: Font.regular(13.0), textColor: subtitleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                } else {
                    modelTitleLayoutAndApply = nil
                }
                let modelValueLayoutAndApply: (TextNodeLayout, () -> TextNode)?
                if let modelValue {
                    modelValueLayoutAndApply = makeModelValueLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: modelValue, font: Font.semibold(13.0), textColor: primaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                } else {
                    modelValueLayoutAndApply = nil
                }
                
                let backdropTitleLayoutAndApply: (TextNodeLayout, () -> TextNode)?
                if let backdropTitle {
                    backdropTitleLayoutAndApply = makeBackdropTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: backdropTitle, font: Font.regular(13.0), textColor: subtitleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                } else {
                    backdropTitleLayoutAndApply = nil
                }
                let backdropValueLayoutAndApply: (TextNodeLayout, () -> TextNode)?
                if let backdropValue {
                    backdropValueLayoutAndApply = makeBackdropValueLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: backdropValue, font: Font.semibold(13.0), textColor: primaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                } else {
                    backdropValueLayoutAndApply = nil
                }
                
                let symbolTitleLayoutAndApply: (TextNodeLayout, () -> TextNode)?
                if let symbolTitle {
                    symbolTitleLayoutAndApply = makeSymbolTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: symbolTitle, font: Font.regular(13.0), textColor: subtitleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                } else {
                    symbolTitleLayoutAndApply = nil
                }
                let symbolValueLayoutAndApply: (TextNodeLayout, () -> TextNode)?
                if let symbolValue {
                    symbolValueLayoutAndApply = makeSymbolValueLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: symbolValue, font: Font.semibold(13.0), textColor: primaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                } else {
                    symbolValueLayoutAndApply = nil
                }
                
                let (buttonTitleLayout, buttonTitleApply) = makeButtonTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: buttonTitle, font: Font.semibold(15.0), textColor: primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: giftSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (ribbonTextLayout, ribbonTextApply) = makeRibbonTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: ribbonTitle, font: Font.semibold(11.0), textColor: primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: giftSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))

                giftSize.height = titleLayout.size.height + textSpacing + clippedTextHeight + 164.0
                
                if let _ = modelTitle {
                    giftSize.height += 70.0
                }
                
                if !buttonTitle.isEmpty {
                    giftSize.height += 48.0
                } else if isStoryEntity {
                    giftSize.height += 12.0
                }
                
                var labelRects = labelLayout.linesRects()
                if labelRects.count > 1 {
                    let sortedIndices = (0 ..< labelRects.count).sorted(by: { labelRects[$0].width > labelRects[$1].width })
                    for i in 0 ..< sortedIndices.count {
                        let index = sortedIndices[i]
                        for j in -1 ... 1 {
                            if j != 0 && index + j >= 0 && index + j < sortedIndices.count {
                                if abs(labelRects[index + j].width - labelRects[index].width) < 40.0 {
                                    labelRects[index + j].size.width = max(labelRects[index + j].width, labelRects[index].width)
                                    labelRects[index].size.width = labelRects[index + j].size.width
                                }
                            }
                        }
                    }
                }
                for i in 0 ..< labelRects.count {
                    labelRects[i] = labelRects[i].insetBy(dx: -7.0, dy: floor((labelRects[i].height - 22.0) / 2.0))
                    labelRects[i].size.height = 22.0
                    labelRects[i].origin.x = floor((labelLayout.size.width - labelRects[i].width) / 2.0)
                }

                let backgroundMaskImage: (CGPoint, UIImage)?
                var backgroundMaskUpdated = false
                if hasServiceMessage {
                    if let (currentOffset, currentImage, currentRects) = cachedMaskBackgroundImage, currentRects == labelRects {
                        backgroundMaskImage = (currentOffset, currentImage)
                    } else {
                        backgroundMaskImage = LinkHighlightingNode.generateImage(color: .black, inset: 0.0, innerRadius: 11.0, outerRadius: 11.0, rects: labelRects, useModernPathCalculation: false)
                        backgroundMaskUpdated = true
                    }
                } else {
                    backgroundMaskImage = nil
                }
            
                var backgroundSize = giftSize
                if hasServiceMessage {
                    backgroundSize.height += labelLayout.size.height + 20.0
                } else {
                    backgroundSize.height += 4.0
                }
                
                return (backgroundSize.width, { boundingWidth in
                    return (backgroundSize, { [weak self] animation, synchronousLoads, info in
                        if let strongSelf = self {
                            let isFirstTime = strongSelf.item == nil
                            
                            if strongSelf.appliedIsExpanded != currentIsExpanded {
                                strongSelf.appliedIsExpanded = currentIsExpanded
                                info?.setInvertOffsetDirection()
                                
                                if let maskOverlayView = strongSelf.maskOverlayView {
                                    animation.transition.updateAlpha(layer: maskOverlayView.layer, alpha: currentIsExpanded ? 1.0 : 0.0)
                                }
                            }
                            
                            let overlayColor = item.presentationData.theme.theme.overallDarkAppearance && uniquePatternFile == nil ? UIColor(rgb: 0xffffff, alpha: 0.12) : UIColor(rgb: 0x000000, alpha: 0.12)
                            
                            let imageFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((boundingWidth - giftSize.width) / 2.0), y: hasServiceMessage ? labelLayout.size.height + 13.0 : 0.0), size: giftSize)
                            let mediaBackgroundFrame = imageFrame.insetBy(dx: -2.0, dy: -2.0)
                            
                            var iconSize = CGSize(width: 160.0, height: 160.0)
                            var iconOffset: CGFloat = 0.0
                            if let _ = animationFile {
                                iconSize = CGSize(width: 120.0, height: 120.0)
                                iconOffset = 32.0
                            }
                            let animationFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - iconSize.width) / 2.0), y: mediaBackgroundFrame.minY - 16.0 + iconOffset), size: iconSize)
                            strongSelf.animationNode.frame = animationFrame
                            strongSelf.animationNode.isHidden = isStoryEntity
                            
                            strongSelf.buttonNode.isHidden = buttonTitle.isEmpty
                            strongSelf.buttonTitleNode.isHidden = buttonTitle.isEmpty
                        
                            if strongSelf.item == nil && !isStoryEntity {
                                strongSelf.animationNode.started = { [weak self] in
                                    if let strongSelf = self {
                                        let current = CACurrentMediaTime()
                                        if let setupTimestamp = strongSelf.setupTimestamp, current - setupTimestamp > 0.3 {
                                            if !strongSelf.placeholderNode.alpha.isZero {
                                                strongSelf.animationNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                                strongSelf.removePlaceholder(animated: true)
                                            }
                                        } else {
                                            strongSelf.removePlaceholder(animated: false)
                                        }
                                    }
                                }
                                
                                strongSelf.animationNode.autoplay = true
                                
                                if let file = animationFile {
                                    strongSelf.animationNode.setup(source: AnimatedStickerResourceSource(account: item.context.account, resource: file.resource, isVideo: file.mimeType == "video/webm"), width: 384, height: 384, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
                                    if strongSelf.fetchDisposable == nil {
                                        strongSelf.fetchDisposable = freeMediaFileResourceInteractiveFetched(postbox: item.context.account.postbox, userLocation: .other, fileReference: .message(message: MessageReference(item.message), media: file), resource: file.resource).start()
                                    }
                                    
                                    if let immediateThumbnailData = file.immediateThumbnailData {
                                        let shimmeringColor = bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.stickerPlaceholderShimmerColor, wallpaper: item.presentationData.theme.wallpaper)
                                        strongSelf.placeholderNode.update(backgroundColor: nil, foregroundColor: overlayColor, shimmeringColor: shimmeringColor, data: immediateThumbnailData, size: animationFrame.size, enableEffect: item.context.sharedContext.energyUsageSettings.fullTranslucency)
                                    }
                                } else if animationName.hasPrefix("Gift") {
                                    strongSelf.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: animationName), width: 384, height: 384, playbackMode: .still(.end), mode: .direct(cachePathPrefix: nil))
                                }
                            }
                            strongSelf.item = item
                            strongSelf.isStarGift = isStarGift
                            
                            strongSelf.updateVisibility()
                            
                            strongSelf.labelNode.isHidden = !hasServiceMessage
                            
                            strongSelf.buttonNode.backgroundColor = overlayColor
                            
                            strongSelf.animationNode.updateLayout(size: iconSize)
                            strongSelf.placeholderNode.frame = animationFrame
                            
                            strongSelf.cachedTonImage = updatedCachedTonImage
                            
                            let _ = labelApply()
                            let _ = titleApply()
                            let _ = subtitleApply(TextNodeWithEntities.Arguments(
                                context: item.context,
                                cache: item.controllerInteraction.presentationContext.animationCache,
                                renderer: item.controllerInteraction.presentationContext.animationRenderer,
                                placeholderColor: item.presentationData.theme.theme.chat.message.freeform.withWallpaper.reactionInactiveBackground,
                                attemptSynchronous: synchronousLoads
                            ))
                            let _ = buttonTitleApply()
                            let _ = ribbonTextApply()
                            let _ = moreApply()
                                                        
                            let labelFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((boundingWidth - labelLayout.size.width) / 2.0), y: 2.0), size: labelLayout.size)
                            strongSelf.labelNode.frame = labelFrame
                            
                            let titleFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - titleLayout.size.width) / 2.0) , y: mediaBackgroundFrame.minY + 151.0), size: titleLayout.size)
                            strongSelf.titleNode.frame = titleFrame
                            
                            let clippingTextFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - subtitleLayout.size.width) / 2.0), y: titleFrame.maxY + textSpacing), size: CGSize(width: subtitleLayout.size.width, height: clippedTextHeight))
                            
                            let subtitleFrame = CGRect(origin: .zero, size: subtitleLayout.size)
                            strongSelf.subtitleNode.textNode.frame = subtitleFrame
                            
                            if isFirstTime {
                                strongSelf.textClippingNode.frame = clippingTextFrame
                            } else {
                                animation.animator.updateFrame(layer: strongSelf.textClippingNode.layer, frame: clippingTextFrame, completion: nil)
                            }
                            if let maskView = strongSelf.maskView, let maskOverlayView = strongSelf.maskOverlayView {
                                animation.animator.updateFrame(layer: maskView.layer, frame: CGRect(origin: .zero, size: CGSize(width: clippingTextFrame.width, height: clippingTextFrame.height)), completion: nil)
                                animation.animator.updateFrame(layer: maskOverlayView.layer, frame: CGRect(origin: .zero, size: CGSize(width: clippingTextFrame.width, height: clippingTextFrame.height)), completion: nil)
                            }
                            animation.animator.updateFrame(layer: strongSelf.moreTextNode.layer, frame: CGRect(origin: CGPoint(x: clippingTextFrame.maxX - moreLayout.size.width, y: clippingTextFrame.maxY - moreLayout.size.height), size: moreLayout.size), completion: nil)
                            
                            if !subtitleLayout.spoilers.isEmpty {
                                let spoilerSubtitleNode = spoilerSubtitleApply(TextNodeWithEntities.Arguments(
                                    context: item.context,
                                    cache: item.controllerInteraction.presentationContext.animationCache,
                                    renderer: item.controllerInteraction.presentationContext.animationRenderer,
                                    placeholderColor: item.presentationData.theme.theme.chat.message.freeform.withWallpaper.reactionInactiveBackground,
                                    attemptSynchronous: synchronousLoads
                                ))
                                if strongSelf.spoilerSubtitleNode == nil {
                                    spoilerSubtitleNode.textNode.alpha = 0.0
                                    spoilerSubtitleNode.textNode.isUserInteractionEnabled = false
                                    strongSelf.spoilerSubtitleNode = spoilerSubtitleNode
                                    
                                    strongSelf.textClippingNode.addSubnode(spoilerSubtitleNode.textNode)
                                }
                                spoilerSubtitleNode.textNode.frame = subtitleFrame
                                
                                let dustColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                                
                                let dustNode: InvisibleInkDustNode
                                if let current = strongSelf.dustNode {
                                    dustNode = current
                                } else {
                                    dustNode = InvisibleInkDustNode(textNode: spoilerSubtitleNode.textNode, enableAnimations: item.context.sharedContext.energyUsageSettings.fullTranslucency)
                                    strongSelf.dustNode = dustNode
                                    strongSelf.textClippingNode.insertSubnode(dustNode, aboveSubnode: strongSelf.subtitleNode.textNode)
                                }
                                dustNode.frame = subtitleFrame.insetBy(dx: -3.0, dy: -3.0).offsetBy(dx: 0.0, dy: 1.0)
                                dustNode.update(size: dustNode.frame.size, color: dustColor, textColor: dustColor, rects: subtitleLayout.spoilers.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) }, wordRects: subtitleLayout.spoilerWords.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) })
                            } else if let dustNode = strongSelf.dustNode {
                                dustNode.removeFromSupernode()
                                strongSelf.dustNode = nil
                            }
                            
                            let attributeSpacing: CGFloat = 6.0
                            let attributeVerticalSpacing: CGFloat = 22.0
                            var attributeMidpoints: [CGFloat] = []
                            
                            func appendAttributeMidpoint(titleLayout: TextNodeLayout?, valueLayout: TextNodeLayout?) {
                                if let titleLayout, let valueLayout {
                                    let totalWidth = titleLayout.size.width + attributeSpacing + valueLayout.size.width
                                    let titleOffset = titleLayout.size.width + attributeSpacing / 2.0
                                    let midpoint = (mediaBackgroundFrame.width - totalWidth) / 2.0 + titleOffset
                                    attributeMidpoints.append(midpoint)
                                }
                            }
                            appendAttributeMidpoint(titleLayout: modelTitleLayoutAndApply?.0, valueLayout: modelValueLayoutAndApply?.0)
                            appendAttributeMidpoint(titleLayout: backdropTitleLayoutAndApply?.0, valueLayout: backdropValueLayoutAndApply?.0)
                            appendAttributeMidpoint(titleLayout: symbolTitleLayoutAndApply?.0, valueLayout: symbolValueLayoutAndApply?.0)
                            
                            let middleX = attributeMidpoints.isEmpty ? mediaBackgroundFrame.width / 2.0 : attributeMidpoints.reduce(0, +) / CGFloat(attributeMidpoints.count)
                            
                            let titleMaxX: CGFloat = mediaBackgroundFrame.minX + middleX - attributeSpacing / 2.0
                            let valueMinX: CGFloat = mediaBackgroundFrame.minX + middleX + attributeSpacing / 2.0
                          
                            func positionAttributeNodes(
                                titleTextNode: TextNode,
                                valueTextNode: TextNode,
                                titleLayoutAndApply: (TextNodeLayout, () -> TextNode)?,
                                valueLayoutAndApply: (TextNodeLayout, () -> TextNode)?,
                                yOffset: CGFloat
                            ) {
                                if let (titleLayout, titleApply) = titleLayoutAndApply {
                                    if titleTextNode.supernode == nil {
                                        strongSelf.addSubnode(titleTextNode)
                                    }
                                    let _ = titleApply()
                                    titleTextNode.frame = CGRect(
                                        origin: CGPoint(x: titleMaxX - titleLayout.size.width, y: clippingTextFrame.maxY + yOffset),
                                        size: titleLayout.size
                                    )
                                }
                                if let (valueLayout, valueApply) = valueLayoutAndApply {
                                    if valueTextNode.supernode == nil {
                                        strongSelf.addSubnode(valueTextNode)
                                    }
                                    let _ = valueApply()
                                    valueTextNode.frame = CGRect(
                                        origin: CGPoint(x: valueMinX, y: clippingTextFrame.maxY + yOffset),
                                        size: valueLayout.size
                                    )
                                }
                            }
                            
                            positionAttributeNodes(
                                titleTextNode: strongSelf.modelTitleTextNode,
                                valueTextNode: strongSelf.modelValueTextNode,
                                titleLayoutAndApply: modelTitleLayoutAndApply,
                                valueLayoutAndApply: modelValueLayoutAndApply,
                                yOffset: 10.0
                            )
                            positionAttributeNodes(
                                titleTextNode: strongSelf.backdropTitleTextNode,
                                valueTextNode: strongSelf.backdropValueTextNode,
                                titleLayoutAndApply: backdropTitleLayoutAndApply,
                                valueLayoutAndApply: backdropValueLayoutAndApply,
                                yOffset: 10.0 + attributeVerticalSpacing
                            )
                            positionAttributeNodes(
                                titleTextNode: strongSelf.symbolTitleTextNode,
                                valueTextNode: strongSelf.symbolValueTextNode,
                                titleLayoutAndApply: symbolTitleLayoutAndApply,
                                valueLayoutAndApply: symbolValueLayoutAndApply,
                                yOffset: 10.0 + attributeVerticalSpacing * 2
                            )
 
                            var buttonSize = CGSize(width: buttonTitleLayout.size.width + 38.0, height: 34.0)
                            var buttonOriginY = clippingTextFrame.maxY + 10.0
                            if modelTitleLayoutAndApply != nil {
                                buttonOriginY = clippingTextFrame.maxY + 80.0
                            }
                            strongSelf.buttonTitleNode.frame = CGRect(origin: CGPoint(x: 19.0, y: 8.0), size: buttonTitleLayout.size)
                            
                            if let buttonIcon {
                                buttonSize.width += 15.0
                                
                                let buttonIconNode: DefaultAnimatedStickerNodeImpl
                                if let current = strongSelf.buttonIconNode {
                                    buttonIconNode = current
                                } else {
                                    if animation.isAnimated {
                                        if let snapshotView = strongSelf.buttonContentNode.view.snapshotView(afterScreenUpdates: false) {
                                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                                                snapshotView.removeFromSuperview()
                                            })
                                            snapshotView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
                                            strongSelf.buttonNode.view.addSubview(snapshotView)
                                        }
                                        strongSelf.buttonContentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                        strongSelf.buttonContentNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                                    }
                                    
                                    buttonIconNode = DefaultAnimatedStickerNodeImpl()
                                    buttonIconNode.setup(source: AnimatedStickerNodeLocalFileSource(name: buttonIcon), width: 60, height: 60, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
                                    strongSelf.buttonContentNode.addSubnode(buttonIconNode)
                                    strongSelf.buttonIconNode = buttonIconNode
                                    buttonIconNode.playLoop()
                                }
                                let iconSize = CGSize(width: 20.0, height: 20.0)
                                buttonIconNode.frame = CGRect(origin: CGPoint(x: buttonSize.width - iconSize.width - 13.0, y: 7.0), size: iconSize)
                                buttonIconNode.updateLayout(size: iconSize)
                                buttonIconNode.visibility = strongSelf.visibilityStatus == true
                                buttonIconNode.dynamicColor = primaryTextColor
                            } else if let buttonIconNode = strongSelf.buttonIconNode {
                                if animation.isAnimated {
                                    if let snapshotView = strongSelf.buttonContentNode.view.snapshotView(afterScreenUpdates: false) {
                                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                                            snapshotView.removeFromSuperview()
                                        })
                                        snapshotView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
                                        strongSelf.buttonNode.view.addSubview(snapshotView)
                                    }
                                    strongSelf.buttonContentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                    strongSelf.buttonContentNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                                }
                                
                                strongSelf.buttonIconNode = nil
                                buttonIconNode.removeFromSupernode()
                            }
                                                        
                            animation.animator.updateFrame(layer: strongSelf.buttonNode.layer, frame: CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - buttonSize.width) / 2.0), y: buttonOriginY), size: buttonSize), completion: nil)
                            strongSelf.buttonStarsNode.frame = CGRect(origin: .zero, size: buttonSize)
                            strongSelf.buttonContentNode.frame = CGRect(origin: .zero, size: buttonSize)
                            
                            if ribbonTextLayout.size.width > 0.0 {
                                if strongSelf.ribbonBackgroundNode.image == nil {
                                    if let uniqueBackgroundColor {
                                        let colors = [
                                            uniqueBackgroundColor.withMultiplied(hue: 0.97, saturation: 1.45, brightness: 0.89),
                                            uniqueBackgroundColor.withMultiplied(hue: 1.01, saturation: 1.22, brightness: 1.04)
                                        ]
                                        strongSelf.ribbonBackgroundNode.image = generateGradientTintedImage(image: UIImage(bundleImageName: "Premium/GiftRibbon"), colors: colors, direction: .mirroredDiagonal)
                                    } else {
                                        strongSelf.ribbonBackgroundNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/GiftRibbon"), color: overlayColor)
                                    }
                                }
                                if let ribbonImage = strongSelf.ribbonBackgroundNode.image {
                                    var ribbonFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.maxX - ribbonImage.size.width + 2.0, y: mediaBackgroundFrame.minY - 2.0), size: ribbonImage.size)
                                    if let _ = uniqueBackgroundColor {
                                        ribbonFrame = ribbonFrame.offsetBy(dx: -4.0, dy: 4.0)
                                    }
                                    strongSelf.ribbonBackgroundNode.frame = ribbonFrame
                                    
                                    strongSelf.ribbonTextNode.transform = CATransform3DMakeRotation(.pi / 4.0, 0.0, 0.0, 1.0)
                                    strongSelf.ribbonTextNode.bounds = CGRect(origin: .zero, size: ribbonTextLayout.size)
                                    strongSelf.ribbonTextNode.position = ribbonFrame.center.offsetBy(dx: 7.0, dy: -6.0)
                                }
                            }
                            
                            if strongSelf.mediaBackgroundContent == nil, let backgroundContent = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                backgroundContent.clipsToBounds = true
                                backgroundContent.cornerRadius = 24.0
                                
                                strongSelf.mediaBackgroundContent = backgroundContent
                                strongSelf.insertSubnode(backgroundContent, at: 0)
                            }
                            
                            if let backgroundContent = strongSelf.mediaBackgroundContent {
                                if ribbonTextLayout.size.width > 0.0, uniqueBackgroundColor == nil {
                                    let backgroundMaskFrame = mediaBackgroundFrame.insetBy(dx: -2.0, dy: -2.0)
                                    animation.animator.updateFrame(layer: backgroundContent.layer, frame: backgroundMaskFrame, completion: nil)
                                    backgroundContent.cornerRadius = 0.0
                                    
                                    if strongSelf.mediaBackgroundMaskNode.image?.size != mediaBackgroundFrame.size {
                                        strongSelf.mediaBackgroundMaskNode.image = generateImage(backgroundMaskFrame.size, contextGenerator: { size, context in
                                            let bounds = CGRect(origin: .zero, size: size)
                                            context.clear(bounds)
                                            
                                            context.setFillColor(UIColor.black.cgColor)
                                            context.addPath(UIBezierPath(roundedRect: bounds.insetBy(dx: 2.0, dy: 2.0), cornerRadius: 24.0).cgPath)
                                            context.fillPath()
                                            
                                            if let ribbonImage = UIImage(bundleImageName: "Chat/Message/GiftRibbon"), let cgImage = ribbonImage.cgImage {
                                                context.draw(cgImage, in: CGRect(origin: CGPoint(x: bounds.width - ribbonImage.size.width, y: bounds.height - ribbonImage.size.height), size: ribbonImage.size), byTiling: false)
                                            }
                                        })
                                    }
                                    backgroundContent.view.mask = strongSelf.mediaBackgroundMaskNode.view
                                    animation.animator.updateFrame(layer: strongSelf.mediaBackgroundMaskNode.layer, frame: CGRect(origin: .zero, size: backgroundMaskFrame.size), completion: nil)
                                } else {
                                    animation.animator.updateFrame(layer: backgroundContent.layer, frame: mediaBackgroundFrame, completion: nil)
                                    backgroundContent.clipsToBounds = true
                                    backgroundContent.cornerRadius = 24.0
                                    backgroundContent.view.mask = nil
                                }
                            }
                            
                            if let uniqueBackgroundColor, let uniqueSecondBackgroundColor, let uniquePatternColor, let uniquePatternFile {
                                let patternInset: CGFloat = 4.0
                                let patternSize = CGSize(width: mediaBackgroundFrame.width - patternInset * 2.0, height: mediaBackgroundFrame.height - patternInset * 2.0)
                                let files: [Int64: TelegramMediaFile] = [uniquePatternFile.fileId.id: uniquePatternFile]
                                let _ = strongSelf.patternView.update(
                                    transition: .immediate,
                                    component: AnyComponent(PeerInfoCoverComponent(
                                        context: item.context,
                                        subject: .custom(uniqueBackgroundColor, uniqueSecondBackgroundColor, uniquePatternColor, uniquePatternFile.fileId.id),
                                        files: files,
                                        isDark: false,
                                        avatarCenter: CGPoint(x: patternSize.width / 2.0, y: 104.0),
                                        avatarScale: 1.0,
                                        defaultHeight: patternSize.height,
                                        avatarTransitionFraction: 0.0,
                                        patternTransitionFraction: 0.0
                                    )),
                                    environment: {},
                                    containerSize: patternSize
                                )
                                if let backgroundView = strongSelf.patternView.view {
                                    if backgroundView.superview == nil {
                                        backgroundView.layer.cornerRadius = 20.0
                                        backgroundView.clipsToBounds = true
                                        strongSelf.view.insertSubview(backgroundView, belowSubview: strongSelf.titleNode.view)
                                    }
                                    backgroundView.frame = CGRect(origin: .zero, size: patternSize).offsetBy(dx: mediaBackgroundFrame.minX + patternInset, dy: mediaBackgroundFrame.minY + patternInset)
                                }
                            }
                            
                            let baseBackgroundFrame = labelFrame.offsetBy(dx: 0.0, dy: -11.0)
                            if let (offset, image) = backgroundMaskImage {
                                if strongSelf.backgroundNode == nil {
                                    if let backgroundNode = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                        strongSelf.backgroundNode = backgroundNode
                                        strongSelf.insertSubnode(backgroundNode, at: 0)
                                    }
                                }

                                if backgroundMaskUpdated, let backgroundNode = strongSelf.backgroundNode {
                                    if labelRects.count == 1 {
                                        backgroundNode.clipsToBounds = true
                                        backgroundNode.cornerRadius = labelRects[0].height / 2.0
                                        backgroundNode.view.mask = nil
                                    } else {
                                        backgroundNode.clipsToBounds = false
                                        backgroundNode.cornerRadius = 0.0
                                        backgroundNode.view.mask = strongSelf.backgroundMaskNode.view
                                    }
                                }

                                if let backgroundNode = strongSelf.backgroundNode {
                                    animation.animator.updateFrame(layer: backgroundNode.layer, frame: CGRect(origin: CGPoint(x: baseBackgroundFrame.minX + offset.x, y: baseBackgroundFrame.minY + offset.y), size: image.size), completion: nil)
                                }
                                strongSelf.backgroundMaskNode.image = image
                                strongSelf.backgroundMaskNode.frame = CGRect(origin: CGPoint(), size: image.size)

                                strongSelf.cachedMaskBackgroundImage = (offset, image, labelRects)
                            }
                            if let (rect, size) = strongSelf.absoluteRect {
                                strongSelf.updateAbsoluteRect(rect, within: size)
                            }
                            
                            if canExpand, let maskView = strongSelf.maskView {
                                if maskView.image == nil {
                                    maskView.image = generateMaskImage()
                                }
                                strongSelf.textClippingNode.view.mask = strongSelf.maskView
                                
                                animation.animator.updateAlpha(layer: strongSelf.moreTextNode.layer, alpha: strongSelf.isExpanded ? 0.0 : 1.0, completion: nil)
                            } else {
                                strongSelf.textClippingNode.view.mask = nil
                                strongSelf.moreTextNode.alpha = 0.0
                            }
                            
                            switch strongSelf.visibility {
                            case .none:
                                strongSelf.subtitleNode.visibilityRect = nil
                            case let .visible(_, subRect):
                                var subRect = subRect
                                subRect.origin.x = 0.0
                                subRect.size.width = 10000.0
                                strongSelf.subtitleNode.visibilityRect = subRect
                            }
                        }
                    })
                })
            })
        }
    }

    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        
        if let mediaBackgroundContent = self.mediaBackgroundContent {
            var backgroundFrame = mediaBackgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            mediaBackgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }
        
        self.placeholderNode.updateAbsoluteRect(CGRect(origin: CGPoint(x: rect.minX + self.placeholderNode.frame.minX, y: rect.minY + self.placeholderNode.frame.minY), size: self.placeholderNode.frame.size), within: containerSize)

        if let backgroundNode = self.backgroundNode {
            var backgroundFrame = backgroundNode.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            backgroundNode.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }
    }

    override public func applyAbsoluteOffset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        if let backgroundNode = self.backgroundNode {
            backgroundNode.offset(value: value, animationCurve: animationCurve, duration: duration)
        }
    }

    override public func applyAbsoluteOffsetSpring(value: CGFloat, duration: Double, damping: CGFloat) {
        if let backgroundNode = self.backgroundNode {
            backgroundNode.offsetSpring(value: value, duration: duration, damping: damping)
        }
    }
    
    override public func updateTouchesAtPoint(_ point: CGPoint?) {
        if let item = self.item {
            var rects: [(CGRect, CGRect)]?
            let textNodeFrame = self.labelNode.frame
            if let point = point {
                if let (index, attributes) = self.labelNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY - 10.0)) {
                    let possibleNames: [String] = [
                        TelegramTextAttributes.URL,
                        TelegramTextAttributes.PeerMention,
                        TelegramTextAttributes.PeerTextMention,
                        TelegramTextAttributes.BotCommand,
                        TelegramTextAttributes.Hashtag
                    ]
                    for name in possibleNames {
                        if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                            rects = self.labelNode.lineAndAttributeRects(name: name, at: index)
                            break
                        }
                    }
                }
            }
        
            if let rects = rects {
                var mappedRects: [CGRect] = []
                for i in 0 ..< rects.count {
                    let lineRect = rects[i].0
                    var itemRect = rects[i].1
                    itemRect.origin.x = floor((textNodeFrame.size.width - lineRect.width) / 2.0) + itemRect.origin.x
                    mappedRects.append(itemRect)
                }
                
                let linkHighlightingNode: LinkHighlightingNode
                if let current = self.linkHighlightingNode {
                    linkHighlightingNode = current
                } else {
                    let serviceColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper)
                    linkHighlightingNode = LinkHighlightingNode(color: serviceColor.linkHighlight)
                    linkHighlightingNode.inset = 2.5
                    self.linkHighlightingNode = linkHighlightingNode
                    self.insertSubnode(linkHighlightingNode, belowSubnode: self.labelNode)
                }
                linkHighlightingNode.frame = self.labelNode.frame.offsetBy(dx: 0.0, dy: 1.5)
                linkHighlightingNode.updateRects(mappedRects)
            } else if let linkHighlightingNode = self.linkHighlightingNode {
                self.linkHighlightingNode = nil
                linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                    linkHighlightingNode?.removeFromSupernode()
                })
            }
        }
    }

    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if let (index, attributes) = self.labelNode.attributesAtPoint(CGPoint(x: point.x - self.labelNode.frame.minX, y: point.y - self.labelNode.frame.minY - 10.0)), gesture == .tap {
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let (attributeText, fullText) = self.labelNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                }
                return ChatMessageBubbleContentTapAction(content: .url(ChatMessageBubbleContentTapAction.Url(url: url, concealed: concealed)))
            } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                return ChatMessageBubbleContentTapAction(content: .peerMention(peerId: peerMention.peerId, mention: peerMention.mention, openProfile: false))
            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return ChatMessageBubbleContentTapAction(content: .textMention(peerName))
            } else if let botCommand = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                return ChatMessageBubbleContentTapAction(content: .botCommand(botCommand))
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return ChatMessageBubbleContentTapAction(content: .hashtag(hashtag.peerName, hashtag.hashtag))
            }
        }
        
        if let (_, attributes) = self.subtitleNode.textNode.attributesAtPoint(CGPoint(x: point.x - self.textClippingNode.frame.minX, y: point.y - self.textClippingNode.frame.minY)), gesture == .tap {
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler)], let dustNode = self.dustNode, !dustNode.isRevealed {
                return ChatMessageBubbleContentTapAction(content: .none)
            }
        }
        
        if self.buttonNode.frame.contains(point) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        } else if self.textClippingNode.frame.contains(point) && !self.isExpanded && !self.moreTextNode.alpha.isZero {
            return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                self?.expandPressed()
            }))
        } else if let backgroundNode = self.backgroundNode, backgroundNode.frame.contains(point) {
            return ChatMessageBubbleContentTapAction(content: .openMessage)
        } else if self.mediaBackgroundContent?.frame.contains(point) == true {
            return ChatMessageBubbleContentTapAction(content: .openMessage)
        } else {
            return ChatMessageBubbleContentTapAction(content: .none)
        }
    }
    
    override public func unreadMessageRangeUpdated() {
        self.updateVisibility()
    }
    
    private var internalPlayedOnce = false
    private func updateVisibility() {
        guard let item = self.item else {
            return
        }
                
        let isPlaying = self.visibilityStatus == true
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
            self.animationNode.visibility = isPlaying
        }
        self.buttonIconNode?.visibility = isPlaying
        
        if isPlaying && self.setupTimestamp == nil {
            self.setupTimestamp = CACurrentMediaTime()
        }
        
        if isPlaying {
            var alreadySeen = true
            
            if item.message.flags.contains(.Incoming) {
                if let unreadRange = item.controllerInteraction.unreadMessageRange[UnreadMessageRangeKey(peerId: item.message.id.peerId, namespace: item.message.id.namespace)] {
                    if unreadRange.contains(item.message.id.id) {
                        alreadySeen = false
                    }
                }
            } else {
                if item.controllerInteraction.playNextOutgoingGift && !item.controllerInteraction.seenOneTimeAnimatedMedia.contains(item.message.id) {
                    alreadySeen = false
                }
            }
            
            if !item.controllerInteraction.seenOneTimeAnimatedMedia.contains(item.message.id) && !self.internalPlayedOnce {
                item.controllerInteraction.seenOneTimeAnimatedMedia.insert(item.message.id)
                self.animationNode.playOnce()
                self.internalPlayedOnce = true
                
                Queue.mainQueue().after(0.05) {
                    if let itemNode = self.itemNode, let supernode = itemNode.supernode {
                        supernode.addSubnode(itemNode)
                    }
                }
            }
            
            if !alreadySeen && self.animationNode.isPlaying {
                item.controllerInteraction.playNextOutgoingGift = false
                
                Queue.mainQueue().after(self.isStarGift ? 0.1 : 1.0) {
                    item.controllerInteraction.animateDiceSuccess(false, true)
                }
            }
        }
    }
}

private func generateMaskImage() -> UIImage? {
    return generateImage(CGSize(width: 100.0, height: 30.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        var locations: [CGFloat] = [0.0, 0.5, 1.0]
        let colors: [CGColor] = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.0).cgColor, UIColor.white.withAlphaComponent(0.0).cgColor]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        context.setBlendMode(.copy)
        context.clip(to: CGRect(origin: CGPoint(x: 10.0, y: 12.0), size: CGSize(width: 130.0, height: 18.0)))
        context.drawLinearGradient(gradient, start: CGPoint(x: 30.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
    })?.resizableImage(withCapInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 18.0, right: 70.0))
}
