import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
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

private func attributedServiceMessageString(theme: ChatPresentationThemeData, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, message: EngineMessage, accountPeerId: EnginePeer.Id) -> NSAttributedString? {
    return universalServiceMessageString(presentationData: (theme.theme, theme.wallpaper), strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, message: message, accountPeerId: accountPeerId, forChatList: false, forForumOverview: false, forAdditionalServiceMessage: true)
}

public class ChatMessageGiftBubbleContentNode: ChatMessageBubbleContentNode {
    private let labelNode: TextNode
    private var backgroundNode: WallpaperBubbleBackgroundNode?
    private let backgroundMaskNode: ASImageNode
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private let mediaBackgroundMaskNode: ASImageNode
    private var mediaBackgroundContent: WallpaperBubbleBackgroundNode?
    private let titleNode: TextNode
    private let subtitleNode: TextNodeWithEntities
    private var spoilerSubtitleNode: TextNodeWithEntities?
    private let textClippingNode: ASDisplayNode
    private var dustNode: InvisibleInkDustNode?
    private let placeholderNode: StickerShimmerEffectNode
    private let animationNode: AnimatedStickerNode
    
    private let ribbonBackgroundNode: ASImageNode
    private let ribbonTextNode: TextNode
    
    private var shimmerEffectNode: ShimmerEffectForegroundNode?
    private let buttonNode: HighlightTrackingButtonNode
    private let buttonStarsNode: PremiumStarsNode
    private let buttonTitleNode: TextNode
    
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
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.clipsToBounds = true
        self.buttonNode.cornerRadius = 17.0
                        
        self.placeholderNode = StickerShimmerEffectNode()
        self.placeholderNode.isUserInteractionEnabled = false
        self.placeholderNode.alpha = 0.75
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()

        self.buttonStarsNode = PremiumStarsNode()
        
        self.buttonTitleNode = TextNode()
        self.buttonTitleNode.isUserInteractionEnabled = false
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
        self.buttonNode.addSubnode(self.buttonTitleNode)
        
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
    
        let cachedMaskBackgroundImage = self.cachedMaskBackgroundImage
        
        let currentIsExpanded = self.isExpanded
        
        return { item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 0.0, hidesBackground: .always, forceFullCorners: false, forceAlignment: .center)
                        
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                var giftSize = CGSize(width: 220.0, height: 240.0)
                
                let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                
                let attributedString = attributedServiceMessageString(theme: item.presentationData.theme, strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, dateTimeFormat: item.presentationData.dateTimeFormat, message: EngineMessage(item.message), accountPeerId: item.context.account.peerId)
            
                let primaryTextColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                
                var months: Int32 = 3
                var animationName: String = ""
                var animationFile: TelegramMediaFile?
                var title = item.presentationData.strings.Notification_PremiumGift_Title
                var text = ""
                var entities: [MessageTextEntity] = []
                var buttonTitle = item.presentationData.strings.Notification_PremiumGift_View
                var ribbonTitle = ""
                var hasServiceMessage = true
                var textSpacing: CGFloat = 0.0
                var isStarGift = false
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
                            text = item.presentationData.strings.Notification_StarsGiveaway_Subtitle(peerName, item.presentationData.strings.Notification_StarsGiveaway_Subtitle_Stars(Int32(count))).string
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
                        case let .starGift(gift, convertStars, giftText, giftEntities, _, savedToProfile, converted):
                            isStarGift = true
                            let authorName = item.message.author.flatMap { EnginePeer($0) }?.compactDisplayTitle ?? ""
                            title = item.presentationData.strings.Notification_StarGift_Title(authorName).string
                            if let giftText, !giftText.isEmpty {
                                text = giftText
                                entities = giftEntities ?? []
                            } else {
                                if incoming {
                                    if converted {
                                        text = item.presentationData.strings.Notification_StarGift_Subtitle_Converted(item.presentationData.strings.Notification_StarGift_Subtitle_Converted_Stars(Int32(convertStars ?? 0))).string
                                    } else if savedToProfile {
                                        if let convertStars {
                                            text =  item.presentationData.strings.Notification_StarGift_Subtitle_Displaying(item.presentationData.strings.Notification_StarGift_Subtitle_Displaying_Stars(Int32(convertStars))).string
                                        } else {
                                            text =  item.presentationData.strings.Notification_StarGift_Bot_Subtitle_Displaying
                                        }
                                    } else {
                                        if let convertStars {
                                            text = item.presentationData.strings.Notification_StarGift_Subtitle(item.presentationData.strings.Notification_StarGift_Subtitle_Stars(Int32(convertStars))).string
                                        } else {
                                            text =  item.presentationData.strings.Notification_StarGift_Bot_Subtitle
                                        }
                                    }
                                } else {
                                    var peerName = ""
                                    if let peer = item.message.peers[item.message.id.peerId] {
                                        peerName = EnginePeer(peer).compactDisplayTitle
                                    }
                                    if peerName.isEmpty {
                                        if let convertStars {
                                            text = item.presentationData.strings.Notification_StarGift_Subtitle(item.presentationData.strings.Notification_StarGift_Subtitle_Stars(Int32(convertStars))).string
                                        } else {
                                            text =  item.presentationData.strings.Notification_StarGift_Bot_Subtitle
                                        }
                                    } else {
                                        text = item.presentationData.strings.Notification_StarGift_Subtitle_Other(peerName, item.presentationData.strings.Notification_StarGift_Subtitle_Other_Stars(Int32(convertStars ?? 0))).string
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
                            if incoming {
                                buttonTitle = item.presentationData.strings.Notification_StarGift_View
                            } else {
                                buttonTitle = ""
                            }
                        default:
                            break
                        }
                    }
                }
                
                switch months {
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
                
                let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: Font.semibold(15.0), textColor: primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: giftSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (moreLayout, moreApply) = makeMoreTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Notification_PremiumGift_More, font: Font.semibold(13.0), textColor: primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: giftSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let attributedText: NSAttributedString
                if !entities.isEmpty {
                    attributedText = stringWithAppliedEntities(text, entities: entities, baseColor: primaryTextColor, linkColor: primaryTextColor, baseFont: Font.regular(13.0), linkFont: Font.regular(13.0), boldFont: Font.semibold(13.0), italicFont: Font.italic(13.0), boldItalicFont: Font.semiboldItalic(13.0), fixedFont: Font.monospace(13.0), blockQuoteFont: Font.regular(13.0), message: nil)
                } else {
                    attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: primaryTextColor),
                        bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: primaryTextColor),
                        link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: primaryTextColor),
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
                 
                let (buttonTitleLayout, buttonTitleApply) = makeButtonTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: buttonTitle, font: Font.semibold(15.0), textColor: primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: giftSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (ribbonTextLayout, ribbonTextApply) = makeRibbonTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: ribbonTitle, font: Font.semibold(11.0), textColor: primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: giftSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))

                giftSize.height = titleLayout.size.height + textSpacing + clippedTextHeight + 164.0
                if !buttonTitle.isEmpty {
                    giftSize.height += 48.0
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
                    labelRects[i] = labelRects[i].insetBy(dx: -6.0, dy: floor((labelRects[i].height - 20.0) / 2.0))
                    labelRects[i].size.height = 20.0
                    labelRects[i].origin.x = floor((labelLayout.size.width - labelRects[i].width) / 2.0)
                }

                let backgroundMaskImage: (CGPoint, UIImage)?
                var backgroundMaskUpdated = false
                if hasServiceMessage {
                    if let (currentOffset, currentImage, currentRects) = cachedMaskBackgroundImage, currentRects == labelRects {
                        backgroundMaskImage = (currentOffset, currentImage)
                    } else {
                        backgroundMaskImage = LinkHighlightingNode.generateImage(color: .black, inset: 0.0, innerRadius: 10.0, outerRadius: 10.0, rects: labelRects, useModernPathCalculation: false)
                        backgroundMaskUpdated = true
                    }
                } else {
                    backgroundMaskImage = nil
                }
            
                var backgroundSize = giftSize
                if hasServiceMessage {
                    backgroundSize.height += labelLayout.size.height + 18.0
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
                            
                            let overlayColor = item.presentationData.theme.theme.overallDarkAppearance ? UIColor(rgb: 0xffffff, alpha: 0.12) : UIColor(rgb: 0x000000, alpha: 0.12)
                            
                            let imageFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundSize.width - giftSize.width) / 2.0), y: hasServiceMessage ? labelLayout.size.height + 16.0 : 0.0), size: giftSize)
                            let mediaBackgroundFrame = imageFrame.insetBy(dx: -2.0, dy: -2.0)
                            
                            var iconSize = CGSize(width: 160.0, height: 160.0)
                            var iconOffset: CGFloat = 0.0
                            if let _ = animationFile {
                                iconSize = CGSize(width: 120.0, height: 120.0)
                                iconOffset = 32.0
                            }
                            let animationFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - iconSize.width) / 2.0), y: mediaBackgroundFrame.minY - 16.0 + iconOffset), size: iconSize)
                            strongSelf.animationNode.frame = animationFrame
                            
                            strongSelf.buttonNode.isHidden = buttonTitle.isEmpty
                            strongSelf.buttonTitleNode.isHidden = buttonTitle.isEmpty
                        
                            if strongSelf.item == nil {
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
                                    strongSelf.animationNode.setup(source: AnimatedStickerResourceSource(account: item.context.account, resource: file.resource), width: 384, height: 384, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
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
                                                        
                            let labelFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundSize.width - labelLayout.size.width) / 2.0), y: 2.0), size: labelLayout.size)
                            strongSelf.labelNode.frame = labelFrame
                            
                            let titleFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - titleLayout.size.width) / 2.0) , y: mediaBackgroundFrame.minY + 151.0), size: titleLayout.size)
                            strongSelf.titleNode.frame = titleFrame
                            
                            let clippingTextFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - subtitleLayout.size.width) / 2.0) , y: titleFrame.maxY + textSpacing), size: CGSize(width: subtitleLayout.size.width, height: clippedTextHeight))
                            
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
                            
                            let buttonSize = CGSize(width: buttonTitleLayout.size.width + 38.0, height: 34.0)
                            strongSelf.buttonTitleNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((buttonSize.width - buttonTitleLayout.size.width) / 2.0), y: 8.0), size: buttonTitleLayout.size)
                            
                            animation.animator.updateFrame(layer: strongSelf.buttonNode.layer, frame: CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - buttonSize.width) / 2.0), y: clippingTextFrame.maxY + 10.0), size: buttonSize), completion: nil)
                            strongSelf.buttonStarsNode.frame = CGRect(origin: .zero, size: buttonSize)
                            
                            if ribbonTextLayout.size.width > 0.0 {
                                if strongSelf.ribbonBackgroundNode.image == nil {
                                    let ribbonImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/GiftRibbon"), color: overlayColor)
                                    strongSelf.ribbonBackgroundNode.image = ribbonImage
                                }
                                if let ribbonImage = strongSelf.ribbonBackgroundNode.image {
                                    let ribbonFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.maxX - ribbonImage.size.width + 2.0, y: mediaBackgroundFrame.minY - 2.0), size: ribbonImage.size)
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
                                if ribbonTextLayout.size.width > 0.0 {
                                    let backgroundMaskFrame = mediaBackgroundFrame.insetBy(dx: -2.0, dy: -2.0)
                                    backgroundContent.frame = backgroundMaskFrame
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
                                    strongSelf.mediaBackgroundMaskNode.frame = CGRect(origin: .zero, size: backgroundMaskFrame.size)
                                } else {
                                    animation.animator.updateFrame(layer: backgroundContent.layer, frame: mediaBackgroundFrame, completion: nil)
                                    backgroundContent.clipsToBounds = true
                                    backgroundContent.cornerRadius = 24.0
                                    backgroundContent.view.mask = nil
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
                                    backgroundNode.frame = CGRect(origin: CGPoint(x: baseBackgroundFrame.minX + offset.x, y: baseBackgroundFrame.minY + offset.y), size: image.size)
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
