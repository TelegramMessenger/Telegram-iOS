import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
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

private func attributedServiceMessageString(theme: ChatPresentationThemeData, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, message: Message, accountPeerId: PeerId) -> NSAttributedString? {
    return universalServiceMessageString(presentationData: (theme.theme, theme.wallpaper), strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, message: EngineMessage(message), accountPeerId: accountPeerId, forChatList: false, forForumOverview: false)
}

class ChatMessageGiftBubbleContentNode: ChatMessageBubbleContentNode {
    private let labelNode: TextNode
    private var backgroundNode: WallpaperBubbleBackgroundNode?
    private var backgroundColorNode: ASDisplayNode
    private let backgroundMaskNode: ASImageNode
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private var mediaBackgroundContent: WallpaperBubbleBackgroundNode?
    private let mediaBackgroundNode: NavigationBackgroundNode
    private let titleNode: TextNode
    private let subtitleNode: TextNode
    private let animationNode: AnimatedStickerNode
    
    private let buttonNode: HighlightTrackingButtonNode
    private let buttonStarsNode: PremiumStarsNode
    private let buttonTitleNode: TextNode
    
    private var cachedMaskBackgroundImage: (CGPoint, UIImage, [CGRect])?
    private var absoluteRect: (CGRect, CGSize)?
    
    private var isPlaying: Bool = false
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            let wasVisible = oldValue != .none
            let isVisible = self.visibility != .none
            
            if wasVisible != isVisible {
                self.visibilityStatus = isVisible
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
    
    required init() {
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.displaysAsynchronously = false

        self.backgroundColorNode = ASDisplayNode()
        self.backgroundMaskNode = ASImageNode()
        
        self.mediaBackgroundNode = NavigationBackgroundNode(color: .clear)
        self.mediaBackgroundNode.clipsToBounds = true
        self.mediaBackgroundNode.cornerRadius = 24.0
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.displaysAsynchronously = false
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.clipsToBounds = true
        self.buttonNode.cornerRadius = 17.0
                
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        
        self.buttonStarsNode = PremiumStarsNode()
        
        self.buttonTitleNode = TextNode()
        self.buttonTitleNode.isUserInteractionEnabled = false
        self.buttonTitleNode.displaysAsynchronously = false
        
        super.init()

        self.addSubnode(self.labelNode)
        
        self.addSubnode(self.mediaBackgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.animationNode)
        
        self.addSubnode(self.buttonNode)
        self.buttonNode.addSubnode(self.buttonStarsNode)
        self.addSubnode(self.buttonTitleNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.buttonNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonNode.alpha = 0.4
                    strongSelf.buttonTitleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonTitleNode.alpha = 0.4
                } else {
                    strongSelf.buttonNode.alpha = 1.0
                    strongSelf.buttonNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.buttonTitleNode.alpha = 1.0
                    strongSelf.buttonTitleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func buttonPressed() {
        guard let item = self.item else {
            return
        }
        let _ = item.controllerInteraction.openMessage(item.message, .default)
    }
                
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, unboundSize: CGSize?, maxWidth: CGFloat, layout: (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let makeButtonTitleLayout = TextNode.asyncLayout(self.buttonTitleNode)

        let cachedMaskBackgroundImage = self.cachedMaskBackgroundImage
        
        return { item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 0.0, hidesBackground: .always, forceFullCorners: false, forceAlignment: .center)
                        
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let giftSize = CGSize(width: 220.0, height: 240.0)
                
                let attributedString = attributedServiceMessageString(theme: item.presentationData.theme, strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, dateTimeFormat: item.presentationData.dateTimeFormat, message: item.message, accountPeerId: item.context.account.peerId)
            
                let primaryTextColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                
                var duration: String = ""
                var animationName: String = ""
                for media in item.message.media {
                    if let action = media as? TelegramMediaAction {
                        switch action.action {
                        case let .giftPremium(_, _, months):
                            duration = item.presentationData.strings.Notification_PremiumGift_Subtitle(item.presentationData.strings.Notification_PremiumGift_Months(months)).string
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
                        default:
                            break
                        }
                    }
                }
                
                let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: constrainedSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Notification_PremiumGift_Title, font: Font.semibold(15.0), textColor: primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: giftSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: duration, font: Font.regular(13.0), textColor: primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: giftSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (buttonTitleLayout, buttonTitleApply) = makeButtonTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Notification_PremiumGift_View, font: Font.semibold(15.0), textColor: primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: giftSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
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
                if let (currentOffset, currentImage, currentRects) = cachedMaskBackgroundImage, currentRects == labelRects {
                    backgroundMaskImage = (currentOffset, currentImage)
                } else {
                    backgroundMaskImage = LinkHighlightingNode.generateImage(color: .black, inset: 0.0, innerRadius: 10.0, outerRadius: 10.0, rects: labelRects)
                    backgroundMaskUpdated = true
                }
            
                let backgroundSize = CGSize(width: labelLayout.size.width + 8.0 + 8.0, height: labelLayout.size.height + giftSize.height + 18.0)
                
                return (backgroundSize.width, { boundingWidth in
                    return (backgroundSize, { [weak self] animation, synchronousLoads, _ in
                        if let strongSelf = self {
                            if strongSelf.item == nil {
                                strongSelf.animationNode.autoplay = true
                                strongSelf.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: animationName), width: 384, height: 384, playbackMode: .still(.end), mode: .direct(cachePathPrefix: nil))
                            }
                            strongSelf.item = item

                            strongSelf.updateVisibility()
                            
                            strongSelf.backgroundColorNode.backgroundColor = selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper)
                            
                            let imageFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundSize.width - giftSize.width) / 2.0), y: labelLayout.size.height + 16.0), size: giftSize)
                            let mediaBackgroundFrame = imageFrame.insetBy(dx: -2.0, dy: -2.0)
                            strongSelf.mediaBackgroundNode.frame = mediaBackgroundFrame
                                                        
                            strongSelf.mediaBackgroundNode.updateColor(color: selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), enableBlur: dateFillNeedsBlur(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), transition: .immediate)
                            strongSelf.mediaBackgroundNode.update(size: mediaBackgroundFrame.size, transition: .immediate)
                            strongSelf.buttonNode.backgroundColor = item.presentationData.theme.theme.overallDarkAppearance ? UIColor(rgb: 0xffffff, alpha: 0.12) : UIColor(rgb: 0x000000, alpha: 0.12)
                            
                            let iconSize = CGSize(width: 160.0, height: 160.0)
                            strongSelf.animationNode.frame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - iconSize.width) / 2.0), y: mediaBackgroundFrame.minY - 16.0), size: iconSize)
                            strongSelf.animationNode.updateLayout(size: iconSize)
                            
                            let _ = labelApply()
                            let _ = titleApply()
                            let _ = subtitleApply()
                            let _ = buttonTitleApply()
                            
                            let labelFrame = CGRect(origin: CGPoint(x: 8.0, y: 2.0), size: labelLayout.size)
                            strongSelf.labelNode.frame = labelFrame
                            
                            let titleFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - titleLayout.size.width) / 2.0) , y: mediaBackgroundFrame.minY + 151.0), size: titleLayout.size)
                            strongSelf.titleNode.frame = titleFrame
                            
                            let subtitleFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - subtitleLayout.size.width) / 2.0) , y: titleFrame.maxY - 1.0), size: subtitleLayout.size)
                            strongSelf.subtitleNode.frame = subtitleFrame
                            
                            let buttonTitleFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - buttonTitleLayout.size.width) / 2.0), y: subtitleFrame.maxY + 18.0), size: buttonTitleLayout.size)
                            strongSelf.buttonTitleNode.frame = buttonTitleFrame
                            
                            let buttonSize = CGSize(width: buttonTitleLayout.size.width + 38.0, height: 34.0)
                            strongSelf.buttonNode.frame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - buttonSize.width) / 2.0), y: subtitleFrame.maxY + 10.0), size: buttonSize)
                            strongSelf.buttonStarsNode.frame = CGRect(origin: .zero, size: buttonSize)

                            if item.controllerInteraction.presentationContext.backgroundNode?.hasExtraBubbleBackground() == true {
                                if strongSelf.mediaBackgroundContent == nil, let backgroundContent = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                    strongSelf.mediaBackgroundNode.isHidden = true
                                    backgroundContent.clipsToBounds = true
                                    backgroundContent.allowsGroupOpacity = true
                                    backgroundContent.cornerRadius = 24.0

                                    strongSelf.mediaBackgroundContent = backgroundContent
                                    strongSelf.insertSubnode(backgroundContent, at: 0)
                                }
                                
                                strongSelf.mediaBackgroundContent?.frame = mediaBackgroundFrame
                            } else {
                                strongSelf.mediaBackgroundNode.isHidden = false
                                strongSelf.mediaBackgroundContent?.removeFromSupernode()
                                strongSelf.mediaBackgroundContent = nil
                            }
                            
                            let baseBackgroundFrame = labelFrame.offsetBy(dx: 0.0, dy: -11.0)
                            if let (offset, image) = backgroundMaskImage {
                                if strongSelf.backgroundNode == nil {
                                    if let backgroundNode = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                        strongSelf.backgroundNode = backgroundNode
                                        backgroundNode.addSubnode(strongSelf.backgroundColorNode)
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
                                strongSelf.backgroundColorNode.frame = CGRect(origin: CGPoint(), size: image.size)

                                strongSelf.cachedMaskBackgroundImage = (offset, image, labelRects)
                            }
                            if let (rect, size) = strongSelf.absoluteRect {
                                strongSelf.updateAbsoluteRect(rect, within: size)
                            }
                        }
                    })
                })
            })
        }
    }

    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        
        if let mediaBackgroundContent = self.mediaBackgroundContent {
            var backgroundFrame = mediaBackgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            mediaBackgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }

        if let backgroundNode = self.backgroundNode {
            var backgroundFrame = backgroundNode.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            backgroundNode.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }
    }

    override func applyAbsoluteOffset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        if let backgroundNode = self.backgroundNode {
            backgroundNode.offset(value: value, animationCurve: animationCurve, duration: duration)
        }
    }

    override func applyAbsoluteOffsetSpring(value: CGFloat, duration: Double, damping: CGFloat) {
        if let backgroundNode = self.backgroundNode {
            backgroundNode.offsetSpring(value: value, duration: duration, damping: damping)
        }
    }
    
    override func updateTouchesAtPoint(_ point: CGPoint?) {
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

    override func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        let textNodeFrame = self.labelNode.frame
        if let (index, attributes) = self.labelNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY - 10.0)), gesture == .tap {
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let (attributeText, fullText) = self.labelNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                }
                return .url(url: url, concealed: concealed)
            } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                return .peerMention(peerMention.peerId, peerMention.mention)
            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return .textMention(peerName)
            } else if let botCommand = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                return .botCommand(botCommand)
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return .hashtag(hashtag.peerName, hashtag.hashtag)
            }
        }
        
        if let backgroundNode = self.backgroundNode, backgroundNode.frame.contains(point) {
            return .openMessage
        } else if self.mediaBackgroundNode.frame.contains(point) {
            return .openMessage
        } else {
            return .none
        }
    }
    
    override func unreadMessageRangeUpdated() {
        self.updateVisibility()
    }
    
    private func updateVisibility() {
        guard let item = self.item else {
            return
        }
                
        let isPlaying = self.visibilityStatus == true
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
            self.animationNode.visibility = isPlaying
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
            
            if !item.controllerInteraction.seenOneTimeAnimatedMedia.contains(item.message.id) {
                item.controllerInteraction.seenOneTimeAnimatedMedia.insert(item.message.id)
                self.animationNode.playOnce()
            }
            
            if !alreadySeen && self.animationNode.isPlaying {
                item.controllerInteraction.playNextOutgoingGift = false
                Queue.mainQueue().after(1.0) {
                    item.controllerInteraction.animateDiceSuccess(false, true)
                }
            }
        }
    }
}
