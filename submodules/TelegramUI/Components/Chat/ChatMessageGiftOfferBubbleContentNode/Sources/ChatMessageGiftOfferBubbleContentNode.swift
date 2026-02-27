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
import GiftItemComponent

private func attributedServiceMessageString(theme: ChatPresentationThemeData, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, message: EngineMessage, accountPeerId: EnginePeer.Id) -> NSAttributedString? {
    return universalServiceMessageString(presentationData: (theme.theme, theme.wallpaper), strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, message: message, accountPeerId: accountPeerId, forChatList: false, forForumOverview: false, forAdditionalServiceMessage: true)
}

public class ChatMessageGiftOfferBubbleContentNode: ChatMessageBubbleContentNode {
    private var mediaBackgroundContent: WallpaperBubbleBackgroundNode?
    private let titleNode: TextNode
    private let subtitleNode: TextNodeWithEntities
    private let giftIcon = ComponentView<Empty>()
        
    private var absoluteRect: (CGRect, CGSize)?
    
    private var isPlaying: Bool = false
    
    override public var disablesClipping: Bool {
        return true
    }
    
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
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.subtitleNode = TextNodeWithEntities()
        self.subtitleNode.textNode.isUserInteractionEnabled = false
        self.subtitleNode.textNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode.textNode)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.fetchDisposable?.dispose()
    }
        
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, unboundSize: CGSize?, maxWidth: CGFloat, layout: (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNodeWithEntities.asyncLayout(self.subtitleNode)
                            
        return { item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 0.0, hidesBackground: .always, forceFullCorners: false, forceAlignment: .center)
                        
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                var giftSize = CGSize(width: 260.0, height: 240.0)
                var uniqueGift: StarGift.UniqueGift?
                
                let incoming: Bool
                if item.message.id.peerId == item.context.account.peerId && item.message.forwardInfo == nil {
                    incoming = true
                } else {
                    incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                }
                
                let textColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                
                let text: String
                let additionalText: String
                
                var hasActionButtons = false
                if let action = item.message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction, case let .starGiftPurchaseOffer(gift, amount, expireDate, isAccepted, isDeclined) = action.action {
                    let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                    
                    let priceString: String
                    switch amount.currency {
                    case .stars:
                        priceString = item.presentationData.strings.Notification_StarGiftOffer_Offer_Stars(Int32(clamping: amount.amount.value))
                    case .ton:
                        priceString = formatTonAmountText(amount.amount.value, dateTimeFormat: item.presentationData.dateTimeFormat) + " TON"
                    }
                    
                    let peerName = item.message.peers[item.message.id.peerId].flatMap { EnginePeer($0) }?.compactDisplayTitle ?? ""
                    let giftTitle: String
                    if case let .unique(gift) = gift {
                        giftTitle = "\(gift.title) #\(formatCollectibleNumber(gift.number, dateTimeFormat: item.presentationData.dateTimeFormat))"
                        uniqueGift = gift
                    } else {
                        giftTitle = ""
                    }
                    
                    if incoming {
                        text = item.presentationData.strings.Notification_StarGiftOffer_Offer(peerName, priceString, giftTitle).string
                    } else {
                        text = item.presentationData.strings.Notification_StarGiftOffer_OfferYou(peerName, priceString, giftTitle).string
                    }
                    
                    if isAccepted {
                        additionalText = item.presentationData.strings.Notification_StarGiftOffer_Status_Accepted
                    } else if isDeclined {
                        additionalText = item.presentationData.strings.Notification_StarGiftOffer_Status_Rejected
                    } else if expireDate > currentTimestamp {
                        func textForTimeout(_ value: Int32) -> String {
                            if value < 3600 {
                                let minutes = value / 60
                                return item.presentationData.strings.Notification_StarGiftOffer_Expiration_Minutes(minutes)
                            } else {
                                let hours = value / 3600
                                let minutes = (value % 3600) / 60
                                return item.presentationData.strings.Notification_StarGiftOffer_Expiration_Hours(hours) + item.presentationData.strings.Notification_StarGiftOffer_Expiration_Delimiter + item.presentationData.strings.Notification_StarGiftOffer_Expiration_Minutes(minutes)
                            }
                        }
                        let delta = expireDate - currentTimestamp
                        additionalText = item.presentationData.strings.Notification_StarGiftOffer_Status_Expires(textForTimeout(delta)).string

                        if incoming {
                            hasActionButtons = true
                        }
                    } else {
                        additionalText = item.presentationData.strings.Notification_StarGiftOffer_Status_Expired
                    }
                } else {
                    text = ""
                    additionalText = ""
                }
                
                let titleAttributedString = NSMutableAttributedString(attributedString: NSAttributedString(string: additionalText, font: Font.regular(13.0), textColor: textColor, paragraphAlignment: .center))
              
                let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: giftSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(
                    body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: textColor),
                    bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: textColor),
                    link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: textColor),
                    linkAttribute: { url in
                        return ("URL", url)
                    }
                ), textAlignment: .center)
                
                let textConstrainedSize = CGSize(width: giftSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude)
                let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
           
                giftSize.height = titleLayout.size.height + subtitleLayout.size.height + 162.0
                
                let backgroundSize = CGSize(width: giftSize.width, height: giftSize.height + 4.0)
                
                return (backgroundSize.width, { boundingWidth in
                    return (backgroundSize, { [weak self] animation, synchronousLoads, info in
                        if let strongSelf = self {
                            strongSelf.item = item
                                                              
                            let imageFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((boundingWidth - giftSize.width) / 2.0), y: 0.0), size: giftSize)
                            let mediaBackgroundFrame = imageFrame.insetBy(dx: -2.0, dy: -2.0)
                                                    
                            strongSelf.updateVisibility()
                            
                            let _ = titleApply()
                            let _ = subtitleApply(TextNodeWithEntities.Arguments(
                                context: item.context,
                                cache: item.controllerInteraction.presentationContext.animationCache,
                                renderer: item.controllerInteraction.presentationContext.animationRenderer,
                                placeholderColor: item.presentationData.theme.theme.chat.message.freeform.withWallpaper.reactionInactiveBackground,
                                attemptSynchronous: synchronousLoads
                            ))
                            
                                                        
                            let textFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - subtitleLayout.size.width) / 2.0), y: mediaBackgroundFrame.minY + 126.0), size: subtitleLayout.size)
                            strongSelf.subtitleNode.textNode.frame = textFrame
                            
                            let titleFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - titleLayout.size.width) / 2.0) , y: textFrame.maxY + 23.0), size: titleLayout.size)
                            strongSelf.titleNode.frame = titleFrame
                            
                            if strongSelf.mediaBackgroundContent == nil, let backgroundContent = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                backgroundContent.clipsToBounds = true
                                backgroundContent.cornerRadius = 24.0
                                
                                strongSelf.mediaBackgroundContent = backgroundContent
                                strongSelf.insertSubnode(backgroundContent, at: 0)
                            }
                            
                            if let backgroundContent = strongSelf.mediaBackgroundContent {
                                animation.animator.updateFrame(layer: backgroundContent.layer, frame: mediaBackgroundFrame, completion: nil)
                                backgroundContent.clipsToBounds = true
                                
                                if hasActionButtons {
                                    backgroundContent.cornerRadius = 0.0
                                    if backgroundContent.view.mask == nil {
                                        backgroundContent.view.mask = UIImageView(image: generateImage(mediaBackgroundFrame.size, rotatedContext: { size, context in
                                            context.clear(CGRect(origin: .zero, size: size))
                                            context.setFillColor(UIColor.white.cgColor)
                                            
                                            context.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.5), cornerWidth: 24.0, cornerHeight: 24.0, transform: nil))
                                            context.addPath(CGPath(roundedRect: CGRect(x: 0, y: size.height * 0.5 - 30.0, width: size.width, height: size.height * 0.5 + 30.0), cornerWidth: 8.0, cornerHeight: 8.0, transform: nil))
                                            context.fillPath()
                                        }))
                                    }
                                } else {
                                    backgroundContent.view.mask = nil
                                    backgroundContent.cornerRadius = 24.0
                                }
                            }
                            
                            if let uniqueGift {
                                let iconSize = CGSize(width: 94.0, height: 94.0)
                                let _ = strongSelf.giftIcon.update(
                                    transition: .immediate,
                                    component: AnyComponent(GiftItemComponent(
                                        context: item.context,
                                        theme: item.presentationData.theme.theme,
                                        strings: item.presentationData.strings,
                                        peer: nil,
                                        subject: .uniqueGift(gift: uniqueGift, price: nil),
                                        mode: .thumbnail
                                    )),
                                    environment: {},
                                    containerSize: iconSize
                                )
                                if let giftIconView = strongSelf.giftIcon.view {
                                    if giftIconView.superview == nil {
                                        strongSelf.view.addSubview(giftIconView)
                                    }
                                    giftIconView.frame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - iconSize.width) / 2.0), y: mediaBackgroundFrame.minY + 17.0), size: iconSize)
                                }
                            }
                            
                            if let (rect, size) = strongSelf.absoluteRect {
                                strongSelf.updateAbsoluteRect(rect, within: size)
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
    }

    override public func applyAbsoluteOffset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {

    }

    override public func applyAbsoluteOffsetSpring(value: CGFloat, duration: Double, damping: CGFloat) {

    }
    
    override public func unreadMessageRangeUpdated() {
        self.updateVisibility()
    }
    
    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.mediaBackgroundContent?.frame.contains(point) == true {
            return ChatMessageBubbleContentTapAction(content: .openMessage)
        } else {
            return ChatMessageBubbleContentTapAction(content: .none)
        }
    }
    
    private func updateVisibility() {
    }
}
