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
import PhotoResources
import TelegramStringFormatting
import UniversalMediaPlayer
import TelegramUniversalVideoContent
import GalleryUI
import WallpaperBackgroundNode
import InvisibleInkDustNode
import TextNodeWithEntities
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import Markdown
import ComponentFlow
import ReactionSelectionNode
import MultilineTextComponent

private func attributedServiceMessageString(theme: ChatPresentationThemeData, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, message: Message, messageCount: Int? = nil, accountPeerId: PeerId, forForumOverview: Bool) -> NSAttributedString? {
    return universalServiceMessageString(presentationData: (theme.theme, theme.wallpaper), strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, message: EngineMessage(message), messageCount: messageCount, accountPeerId: accountPeerId, forChatList: false, forForumOverview: forForumOverview)
}

public class ChatMessageActionBubbleContentNode: ChatMessageBubbleContentNode {
    public var expandHighlightingNode: LinkHighlightingNode?
    
    public var titleNode: TextNode?
    public let labelNode: TextNodeWithEntities
    private var dustNode: InvisibleInkDustNode?
    public var backgroundNode: WallpaperBubbleBackgroundNode?
    public var backgroundColorNode: ASDisplayNode
    public let backgroundMaskNode: ASImageNode
    public var linkHighlightingNode: LinkHighlightingNode?
    
    private var buyStarsTitle: TextNode?
    private var buyStarsButton: HighlightTrackingButton?
    private var buttonStarsNode: PremiumStarsNode?
    
    private let mediaBackgroundNode: ASImageNode
    fileprivate var imageNode: TransformImageNode?
    fileprivate var videoNode: UniversalVideoNode?
    private var videoContent: NativeVideoContent?
    private var videoStartTimestamp: Double?
    private let fetchDisposable = MetaDisposable()
    
    private var leadingIconView: UIImageView?

    private var cachedMaskBackgroundImage: (CGPoint, UIImage, [CGRect])?
    private var absoluteRect: (CGRect, CGSize)?
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            if oldValue != self.visibility {
                switch self.visibility {
                case .none:
                    self.labelNode.visibilityRect = nil
                    //self.spoilerTextNode?.visibilityRect = nil
                case let .visible(_, subRect):
                    var subRect = subRect
                    subRect.origin.x = 0.0
                    subRect.size.width = 10000.0
                    self.labelNode.visibilityRect = subRect
                    //self.spoilerTextNode?.visibilityRect = subRect
                }
            }
        }
    }
    
    required public init() {
        self.labelNode = TextNodeWithEntities()
        self.labelNode.textNode.isUserInteractionEnabled = false
        self.labelNode.textNode.displaysAsynchronously = false

        self.backgroundColorNode = ASDisplayNode()
        self.backgroundMaskNode = ASImageNode()
        
        self.mediaBackgroundNode = ASImageNode()
        self.mediaBackgroundNode.displaysAsynchronously = false
        self.mediaBackgroundNode.displayWithoutProcessing = true
        
        super.init()

        self.addSubnode(self.labelNode.textNode)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.fetchDisposable.dispose()
    }
    
    override public func didLoad() {
        super.didLoad()
    }
    
    override public func transitionNode(messageId: MessageId, media: Media, adjustRect: Bool) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if let imageNode = self.imageNode, self.item?.message.id == messageId {
            return (imageNode, imageNode.bounds, { [weak self] in
                guard let strongSelf = self, let imageNode = strongSelf.imageNode else {
                    return (nil, nil)
                }
                
                let resultView = imageNode.view.snapshotContentTree(unhide: true)
                if let resultView = resultView, strongSelf.mediaBackgroundNode.supernode != nil, let backgroundView = strongSelf.mediaBackgroundNode.view.snapshotContentTree(unhide: true) {
                    let backgroundContainer = UIView()
                    
                    backgroundContainer.addSubview(backgroundView)
                    backgroundContainer.frame = CGRect(origin: CGPoint(x: -2.0, y: -2.0), size: CGSize(width: resultView.frame.width + 4.0, height: resultView.frame.height + 4.0))
                    backgroundView.frame = backgroundContainer.bounds
                    let viewWithBackground = UIView()
                    viewWithBackground.addSubview(backgroundContainer)
                    viewWithBackground.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: resultView.frame.size)
                    resultView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: resultView.frame.size)
                    viewWithBackground.addSubview(resultView)
                    return (viewWithBackground, backgroundContainer)
                }
                
                return (resultView, nil)
            })
        } else {
            return nil
        }
    }
    
    override public func updateHiddenMedia(_ media: [Media]?) -> Bool {
        var mediaHidden = false
        var currentMedia: Media?
        if let item = item {
            mediaLoop: for media in item.message.media {
                if let media = media as? TelegramMediaAction {
                    switch media.action {
                    case let .photoUpdated(image):
                        currentMedia = image
                        break mediaLoop
                    default:
                        break
                    }
                }
            }
        }
        if let currentMedia = currentMedia, let media = media {
            for item in media {
                if item.isSemanticallyEqual(to: currentMedia) {
                    mediaHidden = true
                    break
                }
            }
        }
        
        self.imageNode?.isHidden = mediaHidden
        self.mediaBackgroundNode.isHidden = mediaHidden
        return mediaHidden
    }
    
    @objc private func buyStarsPressed() {
        if let item = self.item {
            item.controllerInteraction.openStarsPurchase(nil)
        }
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, unboundSize: CGSize?, maxWidth: CGFloat, layout: (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNodeWithEntities.asyncLayout(self.labelNode)
        let makeBuyStarsTitleLayout = TextNode.asyncLayout(self.buyStarsTitle)

        let cachedMaskBackgroundImage = self.cachedMaskBackgroundImage
        
        return { item, layoutConstants, _, _, _, _ in
            var isDetached = false
            if let _ = item.message.paidStarsAttribute {
                isDetached = true
            }
            
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 0.0, hidesBackground: .always, forceFullCorners: false, forceAlignment: .center, isDetached: isDetached)
            
            let backgroundImage = PresentationResourcesChat.chatActionPhotoBackgroundImage(item.presentationData.theme.theme, wallpaper: !item.presentationData.theme.wallpaper.isEmpty)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                var forForumOverview = false
                if item.chatLocation.threadId == nil {
                    forForumOverview = true
                }
                
                var messageCount: Int = 1
                if case let .group(messages) = item.content {
                    messageCount = messages.count
                }
                
                let attributedString = attributedServiceMessageString(theme: item.presentationData.theme, strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, dateTimeFormat: item.presentationData.dateTimeFormat, message: item.message, messageCount: messageCount, accountPeerId: item.context.account.peerId, forForumOverview: forForumOverview)
            
                var image: TelegramMediaImage?
                var suggestedPost: TelegramMediaActionType.SuggestedPostApprovalStatus?
                
                var leadingIcon: UIImage?
                var isStory = false
                for media in item.message.media {
                    if let action = media as? TelegramMediaAction {
                        switch action.action {
                        case let .photoUpdated(img):
                            image = img
                        case let .suggestedPostApprovalStatus(status):
                            suggestedPost = status
                        case let .todoCompletions(completed, _):
                            if !completed.isEmpty {
                                leadingIcon = PresentationResourcesChat.chatServiceMessageTodoCompletedIcon(item.presentationData.theme.theme)
                            } else {
                                leadingIcon = PresentationResourcesChat.chatServiceMessageTodoIncompletedIcon(item.presentationData.theme.theme)
                            }
                        case .todoAppendTasks:
                            leadingIcon = PresentationResourcesChat.chatServiceMessageTodoAppendedIcon(item.presentationData.theme.theme)
                        default:
                            break
                        }
                    } else if media is TelegramMediaStory {
                        leadingIcon = PresentationResourcesChat.chatExpiredStoryIndicatorIcon(item.presentationData.theme.theme, type: .free)
                        isStory = true
                    }
                }
                
                var isUser = true
                if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel, peer.isMonoForum, let linkedMonoforumId = peer.linkedMonoforumId, let mainChannel = item.message.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.manageDirect) {
                    isUser = false
                }
                
                let imageSize = CGSize(width: 212.0, height: 212.0)
                
                var updatedAttributedString = attributedString
                if leadingIcon != nil, let attributedString {
                    let mutableString = NSMutableAttributedString(attributedString: attributedString)
                    mutableString.insert(NSAttributedString(string: isStory ? "    " : "      ", font: Font.regular(13.0), textColor: .clear), at: 0)
                    updatedAttributedString = mutableString
                }
                
                var textAlignment: NSTextAlignment = .center
                
                let primaryTextColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                
                if let suggestedPost {
                    textAlignment = .left
                    
                    let channelName: String
                    if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel, peer.isMonoForum, let linkedMonoforumId = peer.linkedMonoforumId, let mainChannel = item.message.peers[linkedMonoforumId] as? TelegramChannel {
                        channelName = EnginePeer(mainChannel).compactDisplayTitle
                    } else {
                        channelName = " "
                    }
                    
                    switch suggestedPost {
                    case let .approved(timestamp, amount):
                        let timeString = humanReadableStringForTimestamp(strings: item.presentationData.strings, dateTimeFormat: item.presentationData.dateTimeFormat, timestamp: timestamp ?? 0, alwaysShowTime: true, allowYesterday: false, format: HumanReadableStringFormat(
                            dateFormatString: { value in
                                return PresentationStrings.FormattedString(string: item.presentationData.strings.SuggestPost_SetTimeFormat_Date(value).string.lowercased(), ranges: [])
                            },
                            tomorrowFormatString: { value in
                                return PresentationStrings.FormattedString(string: item.presentationData.strings.SuggestPost_SetTimeFormat_TomorrowAt(value).string.lowercased(), ranges: [])
                            },
                            todayFormatString: { value in
                                return PresentationStrings.FormattedString(string: item.presentationData.strings.SuggestPost_SetTimeFormat_TodayAt(value).string.lowercased(), ranges: [])
                            },
                            yesterdayFormatString: { value in
                                return PresentationStrings.FormattedString(string: item.presentationData.strings.SuggestPost_SetTimeFormat_TodayAt(value).string.lowercased(), ranges: [])
                            }
                        )).string
                        
                        var pricePart = ""
                        if let amount, amount.amount != .zero {
                            let amountString: String
                            switch amount.currency {
                            case .stars:
                                amountString = item.presentationData.strings.Chat_PostApproval_DetailStatus_StarsAmount(Int32((amount.amount.value == 1 && amount.amount.nanos == 0) ? 1 : 100)).replacingOccurrences(of: "#", with: "\(amount.amount)")
                            case .ton:
                                amountString = item.presentationData.strings.Chat_PostApproval_DetailStatus_TonAmount(Int32((amount.amount.value == 1 * 1_000_000_000) ? 1 : 100)).replacingOccurrences(of: "#", with: "\(formatTonAmountText(amount.amount.value, dateTimeFormat: item.presentationData.dateTimeFormat, maxDecimalPositions: 3))")
                            }
                            
                            switch amount.currency {
                            case .stars:
                                if isUser {
                                    pricePart = "\n\n" + item.presentationData.strings.Chat_PostApproval_Message_UserAgreementPriceStars(amountString, channelName).string
                                } else {
                                    pricePart = "\n\n" + item.presentationData.strings.Chat_PostApproval_Message_AdminAgreementPriceStars(amountString, channelName).string
                                }
                            case .ton:
                                if isUser {
                                    pricePart = "\n\n" + item.presentationData.strings.Chat_PostApproval_Message_UserAgreementPriceTon(amountString, channelName).string
                                } else {
                                    pricePart = "\n\n" + item.presentationData.strings.Chat_PostApproval_Message_AdminAgreementPriceTon(amountString, channelName).string
                                }
                            }
                        }
                        
                        let rawString: String
                        if let timestamp {
                            if Int32(Date().timeIntervalSince1970) >= timestamp {
                                if isUser {
                                    rawString = item.presentationData.strings.Chat_PostApproval_Message_UserAgreementPast(channelName, timeString).string + pricePart
                                } else {
                                    rawString = item.presentationData.strings.Chat_PostApproval_Message_AdminAgreementPast(channelName, timeString).string + pricePart
                                }
                            } else {
                                if isUser {
                                    rawString = item.presentationData.strings.Chat_PostApproval_Message_UserAgreementFuture(channelName, timeString).string + pricePart
                                } else {
                                    rawString = item.presentationData.strings.Chat_PostApproval_Message_AdminAgreementFuture(channelName, timeString).string + pricePart
                                }
                            }
                        } else {
                            if isUser {
                                rawString = item.presentationData.strings.Chat_PostApproval_Message_UserAgreementNoTime(channelName).string + pricePart
                            } else {
                                rawString = item.presentationData.strings.Chat_PostApproval_Message_AdminAgreementNoTime(channelName).string + pricePart
                            }
                        }
                        updatedAttributedString = parseMarkdownIntoAttributedString(rawString, attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: primaryTextColor),
                            bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: primaryTextColor),
                            link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: primaryTextColor),
                            linkAttribute: { url in
                                return ("URL", url)
                            }
                        ))
                    case let .rejected(reason, comment):
                        let rawString: String
                        if !item.message.effectivelyIncoming(item.context.account.peerId) {
                            switch reason {
                            case .generic:
                                if let comment {
                                    rawString = item.presentationData.strings.Chat_PostApproval_Message_AdminDeclinedComment(comment).string
                                } else {
                                    rawString = item.presentationData.strings.Chat_PostApproval_Message_AdminDeclined
                                }
                            case .lowBalance:
                                rawString = ""
                            }
                        } else {
                            switch reason {
                            case .generic:
                                if let comment {
                                    rawString = "\"\(comment)\""
                                } else {
                                    rawString = ""
                                }
                            case .lowBalance:
                                rawString = ""
                            }
                        }
                        textAlignment = .center
                        updatedAttributedString = parseMarkdownIntoAttributedString(rawString, attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: primaryTextColor),
                            bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: primaryTextColor),
                            link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: primaryTextColor),
                            linkAttribute: { url in
                                return ("URL", url)
                            }
                        ))
                    }
                }
                
                var titleLayoutAndApply: (TextNodeLayout, () -> TextNode)?
                if let suggestedPost {
                    let channelName: String
                    if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel, peer.isMonoForum, let linkedMonoforumId = peer.linkedMonoforumId, let mainChannel = item.message.peers[linkedMonoforumId] as? TelegramChannel {
                        channelName = EnginePeer(mainChannel).compactDisplayTitle
                    } else {
                        channelName = " "
                    }
                    
                    let rawString: String
                    var smallFont = false
                    switch suggestedPost {
                    case .approved:
                        rawString = item.presentationData.strings.Chat_PostApproval_Message_TitleApproved
                    case let .rejected(reason, comment):
                        if !item.message.effectivelyIncoming(item.context.account.peerId) {
                            switch reason {
                            case .generic:
                                if comment != nil {
                                    rawString = item.presentationData.strings.Chat_PostApproval_Message_AdminTitleRejectedComment
                                } else {
                                    rawString = item.presentationData.strings.Chat_PostApproval_Message_AdminTitleRejected
                                    smallFont = true
                                }
                            case .lowBalance:
                                rawString = item.presentationData.strings.Chat_PostApproval_Message_AdminTitleFailedFunds
                                smallFont = true
                            }
                        } else {
                            switch reason {
                            case .generic:
                                if comment != nil {
                                    rawString = item.presentationData.strings.Chat_PostApproval_Message_UserTitleRejectedComment(channelName).string
                                } else {
                                    rawString = item.presentationData.strings.Chat_PostApproval_Message_UserTitleRejected(channelName).string
                                    smallFont = true
                                }
                            case .lowBalance:
                                rawString = item.presentationData.strings.Chat_PostApproval_Message_UserTitleFailedFunds
                                smallFont = true
                            }
                        }
                    }
                    let baseFontSize: CGFloat = smallFont ? 13.0 : 15.0
                    let titleString = parseMarkdownIntoAttributedString(rawString, attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(font: Font.regular(baseFontSize), textColor: primaryTextColor),
                        bold: MarkdownAttributeSet(font: Font.bold(baseFontSize), textColor: primaryTextColor),
                        link: MarkdownAttributeSet(font: Font.semibold(baseFontSize), textColor: primaryTextColor),
                        linkAttribute: { url in
                            return ("URL", url)
                        }
                    ))
                    
                    titleLayoutAndApply = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: constrainedSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                }
                
                let (labelLayout, apply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: updatedAttributedString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: constrainedSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: textAlignment, cutout: nil, insets: UIEdgeInsets()))
            
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
                if suggestedPost != nil {
                    backgroundMaskImage = nil
                    if cachedMaskBackgroundImage != nil {
                        backgroundMaskUpdated = true
                    }
                } else {
                    if let (currentOffset, currentImage, currentRects) = cachedMaskBackgroundImage, currentRects == labelRects {
                        backgroundMaskImage = (currentOffset, currentImage)
                    } else {
                        backgroundMaskImage = LinkHighlightingNode.generateImage(color: .white, inset: 0.0, innerRadius: 11.0, outerRadius: 11.0, rects: labelRects, useModernPathCalculation: false)
                        backgroundMaskUpdated = true
                    }
                }
            
                var backgroundSize = CGSize(width: labelLayout.size.width, height: labelLayout.size.height)
                if let _ = image {
                    backgroundSize.width = imageSize.width + 2.0
                    backgroundSize.height += imageSize.height + 10.0
                }
                
                let titleSpacing: CGFloat = 14.0
                
                var contentInsets = UIEdgeInsets()
                var contentOuterInsets = UIEdgeInsets()
                
                if let titleLayoutAndApply {
                    backgroundSize.width = max(backgroundSize.width, titleLayoutAndApply.0.size.width)
                    if labelLayout.size.width != 0.0 {
                        backgroundSize.height += titleSpacing
                    }
                    backgroundSize.height += titleLayoutAndApply.0.size.height
                    
                    contentInsets = UIEdgeInsets(top: 12.0, left: 16.0, bottom: 12.0, right: 16.0)
                    contentOuterInsets = UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0)
                    
                    backgroundSize.width += contentInsets.left + contentInsets.right
                    backgroundSize.height += contentInsets.top + contentInsets.bottom
                } else {
                    backgroundSize.width += 8.0 + 8.0
                    backgroundSize.height += 4.0
                }
                
                var hasBuyStarsButton = false
                if item.message.effectivelyIncoming(item.context.account.peerId), let suggestedPost, case let .rejected(reason, _) = suggestedPost, case .lowBalance = reason {
                    hasBuyStarsButton = true
                }
                
                var buyStarsTitleLayoutAndApply: (TextNodeLayout, () -> TextNode)?
                var buyStarsButtonSize: CGSize?
                if hasBuyStarsButton {
                    let serviceColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper)
                    let buyStarsTitleLayoutAndApplyValue = makeBuyStarsTitleLayout(TextNodeLayoutArguments(attributedString:  NSAttributedString(string: item.presentationData.strings.Chat_PostApproval_Message_BuyStars, font: Font.semibold(15.0), textColor: serviceColor.primaryText), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: constrainedSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: textAlignment, cutout: nil, insets: UIEdgeInsets()))
                    buyStarsTitleLayoutAndApply = buyStarsTitleLayoutAndApplyValue
                    
                    let buyStarsButtonSizeValue = CGSize(width: buyStarsTitleLayoutAndApplyValue.0.size.width + 20.0 * 2.0, height: buyStarsTitleLayoutAndApplyValue.0.size.height + 8.0 * 2.0)
                    buyStarsButtonSize = buyStarsButtonSizeValue
                    
                    backgroundSize.width = max(backgroundSize.width, buyStarsButtonSizeValue.width + 8.0 * 2.0)
                    backgroundSize.height += 15.0 + buyStarsButtonSizeValue.height
                }
                
                return (backgroundSize.width, { boundingWidth in
                    return (CGSize(width: boundingWidth, height: backgroundSize.height + contentOuterInsets.top + contentOuterInsets.bottom), { [weak self] animation, synchronousLoads, _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            let maskPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: imageSize), cornerRadius: 15.5)
                            
                            let imageFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((boundingWidth - imageSize.width) / 2.0), y: labelLayout.size.height + 12.0), size: imageSize)
                            if let image = image {
                                let imageNode: TransformImageNode
                                if let current = strongSelf.imageNode {
                                    imageNode = current
                                } else {
                                    imageNode = TransformImageNode()
                                    let shape = CAShapeLayer()
                                    shape.path = maskPath.cgPath
                                    imageNode.layer.mask = shape
                                    strongSelf.imageNode = imageNode
                                    strongSelf.insertSubnode(imageNode, at: 0)
                                    strongSelf.insertSubnode(strongSelf.mediaBackgroundNode, at: 0)
                                }
                                strongSelf.fetchDisposable.set(chatMessagePhotoInteractiveFetched(context: item.context, userLocation: .peer(item.message.id.peerId), photoReference: .message(message: MessageReference(item.message), media: image), displayAtSize: nil, storeToDownloadsPeerId: nil).startStrict())
                                let updateImageSignal = chatMessagePhoto(postbox: item.context.account.postbox, userLocation: .peer(item.message.id.peerId), photoReference: .message(message: MessageReference(item.message), media: image), synchronousLoad: synchronousLoads)

                                imageNode.setSignal(updateImageSignal, attemptSynchronously: synchronousLoads)
                                
                                let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets())
                                let apply = imageNode.asyncLayout()(arguments)
                                apply()
                                
                                imageNode.frame = imageFrame
                                strongSelf.mediaBackgroundNode.frame = imageFrame.insetBy(dx: -2.0, dy: -2.0)
                            } else if let imageNode = strongSelf.imageNode {
                                strongSelf.mediaBackgroundNode.removeFromSupernode()
                                imageNode.removeFromSupernode()
                                strongSelf.imageNode = nil
                            }
                            strongSelf.mediaBackgroundNode.image = backgroundImage
                            
                            if let image = image, let video = image.videoRepresentations.last, let id = image.id?.id {
                                let videoFileReference = FileMediaReference.message(message: MessageReference(item.message), media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: video.resource, previewRepresentations: image.representations, videoThumbnails: [], immediateThumbnailData: image.immediateThumbnailData, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: video.dimensions, flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil)], alternativeRepresentations: []))
                                let videoContent = NativeVideoContent(id: .profileVideo(id, "action"), userLocation: .peer(item.message.id.peerId), fileReference: videoFileReference, streamVideo: isMediaStreamable(resource: video.resource) ? .conservative : .none, loopVideo: true, enableSound: false, fetchAutomatically: true, onlyFullSizeThumbnail: false, useLargeThumbnail: true, autoFetchFullSizeThumbnail: true, continuePlayingWithoutSoundOnLostAudioSession: false, placeholderColor: .clear, storeAfterDownload: nil)
                                if videoContent.id != strongSelf.videoContent?.id {
                                    let mediaManager = item.context.sharedContext.mediaManager
                                    let videoNode = UniversalVideoNode(context: item.context, postbox: item.context.account.postbox, audioSession: mediaManager.audioSession, manager: mediaManager.universalVideoManager, decoration: GalleryVideoDecoration(), content: videoContent, priority: .secondaryOverlay)
                                    videoNode.isUserInteractionEnabled = false
                                    videoNode.ownsContentNodeUpdated = { [weak self] owns in
                                        if let strongSelf = self {
                                            strongSelf.videoNode?.isHidden = !owns
                                        }
                                    }
                                    strongSelf.videoContent = videoContent
                                    strongSelf.videoNode = videoNode
                                    
                                    videoNode.updateLayout(size: imageSize, transition: .immediate)
                                    videoNode.frame = imageFrame
                                    
                                    let shape = CAShapeLayer()
                                    shape.path = maskPath.cgPath
                                    videoNode.layer.mask = shape
                                    
                                    strongSelf.addSubnode(videoNode)
                                    
                                    videoNode.canAttachContent = true
                                    if let videoStartTimestamp = video.startTimestamp {
                                        videoNode.seek(videoStartTimestamp)
                                    } else {
                                        videoNode.seek(0.0)
                                    }
                                    videoNode.play()
                                    
                                }
                            } else if let videoNode = strongSelf.videoNode {
                                strongSelf.videoContent = nil
                                strongSelf.videoNode = nil
                                
                                videoNode.removeFromSupernode()
                            }
                                                        
                            let _ = apply(TextNodeWithEntities.Arguments(
                                context: item.context,
                                cache: item.controllerInteraction.presentationContext.animationCache,
                                renderer: item.controllerInteraction.presentationContext.animationRenderer,
                                placeholderColor: item.presentationData.theme.theme.chat.message.freeform.withWallpaper.reactionInactiveBackground,
                                attemptSynchronous: synchronousLoads
                            ))
                            
                            var labelFrame: CGRect
                            let contentFrame: CGRect
                            
                            if let (titleLayout, titleApply) = titleLayoutAndApply {
                                contentFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((boundingWidth - backgroundSize.width) * 0.5), y: contentOuterInsets.top), size: backgroundSize)
                                
                                let titleFrame = CGRect(origin: CGPoint(x: contentFrame.minX + floor((contentFrame.width - titleLayout.size.width) * 0.5), y: contentFrame.minY + contentInsets.top), size: titleLayout.size)
                                labelFrame = CGRect(origin: CGPoint(x: contentFrame.minX + contentInsets.left, y: titleFrame.maxY + titleSpacing), size: labelLayout.size)
                                if textAlignment == .center {
                                    labelFrame.origin.x = contentFrame.minX + floor((contentFrame.width - labelFrame.width) * 0.5)
                                }
                            
                                let titleNode = titleApply()
                                if strongSelf.titleNode !== titleNode {
                                    strongSelf.titleNode?.removeFromSupernode()
                                    strongSelf.titleNode = titleNode
                                    strongSelf.addSubnode(titleNode)
                                    titleNode.anchorPoint = CGPoint()
                                    
                                    titleNode.frame = titleFrame
                                } else {
                                    animation.animator.updatePosition(layer: titleNode.layer, position: titleFrame.origin, completion: nil)
                                    titleNode.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                                }
                            } else {
                                labelFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((boundingWidth - labelLayout.size.width) / 2.0) - 1.0, y: image != nil ? 2.0 : floorToScreenPixels((backgroundSize.height - labelLayout.size.height) / 2.0) - 1.0), size: labelLayout.size)
                                contentFrame = labelFrame
                            }
                            
                            if hasBuyStarsButton, let (buyStarsTitleLayout, buyStarsTitleApply) = buyStarsTitleLayoutAndApply, let buyStarsButtonSize {
                                let buyStarsButton: HighlightTrackingButton
                                if let current = strongSelf.buyStarsButton {
                                    buyStarsButton = current
                                } else {
                                    buyStarsButton = HighlightTrackingButton()
                                    buyStarsButton.clipsToBounds = true
                                    strongSelf.buyStarsButton = buyStarsButton
                                    strongSelf.view.addSubview(buyStarsButton)
                                    buyStarsButton.highligthedChanged = { [weak buyStarsButton] highlighted in
                                        guard let buyStarsButton else {
                                            return
                                        }
                                        if highlighted {
                                            buyStarsButton.layer.removeAnimation(forKey: "opacity")
                                            buyStarsButton.alpha = 0.6
                                        } else {
                                            buyStarsButton.alpha = 1.0
                                            buyStarsButton.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                                        }
                                    }
                                    buyStarsButton.addTarget(strongSelf, action: #selector(strongSelf.buyStarsPressed), for: .touchUpInside)
                                }
                                
                                let buttonStarsNode: PremiumStarsNode
                                if let current = strongSelf.buttonStarsNode {
                                    buttonStarsNode = current
                                } else {
                                    buttonStarsNode = PremiumStarsNode()
                                    buttonStarsNode.isUserInteractionEnabled = false
                                    strongSelf.buttonStarsNode = buttonStarsNode
                                    buyStarsButton.addSubview(buttonStarsNode.view)
                                }
                                
                                let buyStarsTitle = buyStarsTitleApply()
                                if buyStarsTitle !== strongSelf.buyStarsTitle {
                                    buyStarsTitle.isUserInteractionEnabled = false
                                    strongSelf.buyStarsTitle?.view.removeFromSuperview()
                                }
                                strongSelf.buyStarsTitle = buyStarsTitle
                                buyStarsButton.addSubview(buyStarsTitle.view)
                                
                                let buttonTitleSize = buyStarsTitleLayout.size
                                
                                let buttonFrame = CGRect(origin: CGPoint(x: contentFrame.minX + floor((contentFrame.width - buyStarsButtonSize.width) * 0.5), y: labelFrame.minY - 2.0), size: buyStarsButtonSize)
                                buyStarsButton.frame = buttonFrame
                                buyStarsButton.layer.cornerRadius = buttonFrame.height * 0.5
                                buyStarsTitle.frame = CGRect(origin: CGPoint(x: floor((buyStarsButtonSize.width - buttonTitleSize.width) * 0.5), y: floor((buyStarsButtonSize.height - buttonTitleSize.height) * 0.5)), size: buttonTitleSize)
                                
                                buyStarsButton.backgroundColor = item.presentationData.theme.theme.overallDarkAppearance ? UIColor(rgb: 0xffffff, alpha: 0.12) : UIColor(rgb: 0x000000, alpha: 0.12)
                                buttonStarsNode.frame = CGRect(origin: CGPoint(), size: buyStarsButtonSize)
                            } else {
                                if let buyStarsTitle = strongSelf.buyStarsTitle {
                                    strongSelf.buyStarsTitle = nil
                                    buyStarsTitle.view.removeFromSuperview()
                                }
                                if let buyStarsButton = strongSelf.buyStarsButton {
                                    strongSelf.buyStarsButton = nil
                                    buyStarsButton.removeFromSuperview()
                                }
                                if let buttonStarsNode = strongSelf.buttonStarsNode {
                                    strongSelf.buttonStarsNode = nil
                                    buttonStarsNode.view.removeFromSuperview()
                                }
                            }
                            
                            if let leadingIcon {
                                let leadingIconView: UIImageView
                                if let current = strongSelf.leadingIconView {
                                    leadingIconView = current
                                } else {
                                    leadingIconView = UIImageView()
                                    strongSelf.leadingIconView = leadingIconView
                                    strongSelf.view.addSubview(leadingIconView)
                                }
                                
                                leadingIconView.image = leadingIcon
                                
                                if let lineRect = labelLayout.linesRects().first, let iconImage = leadingIconView.image {
                                    let iconSize = iconImage.size
                                    var iconFrame = CGRect(origin: CGPoint(x: lineRect.minX + labelFrame.minX - 1.0, y: labelFrame.minY), size: iconSize)
                                    if !isStory {
                                        iconFrame.origin.x += 3.0
                                    }
                                    leadingIconView.frame = iconFrame
                                }
                            } else if let leadingIconView = strongSelf.leadingIconView {
                                strongSelf.leadingIconView = nil
                                leadingIconView.removeFromSuperview()
                            }
                            
                            animation.animator.updateFrame(layer: strongSelf.labelNode.textNode.layer, frame: labelFrame, completion: nil)
                            strongSelf.backgroundColorNode.backgroundColor = selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper)

                            if !labelLayout.spoilers.isEmpty {
                                let dustColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                                
                                let dustNode: InvisibleInkDustNode
                                if let current = strongSelf.dustNode {
                                    dustNode = current
                                } else {
                                    dustNode = InvisibleInkDustNode(textNode: nil, enableAnimations: item.context.sharedContext.energyUsageSettings.fullTranslucency)
                                    dustNode.isUserInteractionEnabled = false
                                    strongSelf.dustNode = dustNode
                                    strongSelf.insertSubnode(dustNode, aboveSubnode: strongSelf.labelNode.textNode)
                                }
                                dustNode.frame = labelFrame.insetBy(dx: -3.0, dy: -3.0).offsetBy(dx: 0.0, dy: 1.0)
                                dustNode.update(size: dustNode.frame.size, color: dustColor, textColor: dustColor, rects: labelLayout.spoilers.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) }, wordRects: labelLayout.spoilerWords.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) })
                            } else if let dustNode = strongSelf.dustNode {
                                dustNode.removeFromSupernode()
                                strongSelf.dustNode = nil
                            }
                            
                            let baseBackgroundFrame = labelFrame.offsetBy(dx: 0.0, dy: -11.0)

                            if var rect = strongSelf.labelNode.textNode.cachedLayout?.allAttributeRects(name: TelegramTextAttributes.Button).first?.1 {
                                rect = rect.insetBy(dx: -2.0, dy: 2.0).offsetBy(dx: 0.0, dy: 1.0 - UIScreenPixel)
                                let highlightNode: LinkHighlightingNode
                                if let current = strongSelf.expandHighlightingNode {
                                    highlightNode = current
                                } else {
                                    highlightNode = LinkHighlightingNode(color: UIColor(rgb: 0x000000, alpha: 0.1))
                                    highlightNode.outerRadius = 7.5
                                    strongSelf.insertSubnode(highlightNode, belowSubnode: strongSelf.labelNode.textNode)
                                    strongSelf.expandHighlightingNode = highlightNode
                                }
                                highlightNode.frame = strongSelf.labelNode.textNode.frame
                                highlightNode.updateRects([rect])
                            } else {
                                strongSelf.expandHighlightingNode?.removeFromSupernode()
                                strongSelf.expandHighlightingNode = nil
                            }
                            
                            if suggestedPost != nil {
                                let backgroundFrame = contentFrame
                                
                                if item.context.sharedContext.energyUsageSettings.fullTranslucency {
                                    if strongSelf.backgroundNode == nil {
                                        if let backgroundNode = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                            strongSelf.backgroundNode = backgroundNode
                                            backgroundNode.addSubnode(strongSelf.backgroundColorNode)
                                            strongSelf.insertSubnode(backgroundNode, at: 0)
                                        }
                                    }
                                    strongSelf.backgroundColorNode.isHidden = true
                                } else {
                                    if strongSelf.backgroundMaskNode.supernode == nil {
                                        strongSelf.insertSubnode(strongSelf.backgroundMaskNode, at: 0)
                                    }
                                }
                                
                                if let backgroundNode = strongSelf.backgroundNode {
                                    backgroundNode.clipsToBounds = true
                                    backgroundNode.cornerRadius = min(backgroundFrame.height * 0.5, 22.0)
                                    backgroundNode.view.mask = nil
                                    
                                    animation.animator.updateFrame(layer: backgroundNode.layer, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX, y: backgroundFrame.minY), size: backgroundFrame.size), completion: nil)
                                    
                                    if let (rect, size) = strongSelf.absoluteRect {
                                        strongSelf.updateAbsoluteRect(rect, within: size)
                                    }
                                    strongSelf.backgroundMaskNode.frame = CGRect(origin: CGPoint(), size: backgroundFrame.size)
                                    strongSelf.backgroundMaskNode.layer.layerTintColor = nil
                                } else {
                                    animation.animator.updateFrame(layer: strongSelf.backgroundMaskNode.layer, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX, y: backgroundFrame.minY), size: backgroundFrame.size), completion: nil)
                                    strongSelf.backgroundMaskNode.layer.layerTintColor = selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).cgColor
                                }
                                
                                strongSelf.backgroundMaskNode.image = nil

                                animation.animator.updateFrame(layer: strongSelf.backgroundColorNode.layer, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size), completion: nil)

                                strongSelf.cachedMaskBackgroundImage = nil
                                
                                switch strongSelf.visibility {
                                case .none:
                                    strongSelf.labelNode.visibilityRect = nil
                                    //strongSelf.spoilerTextNode?.visibilityRect = nil
                                case let .visible(_, subRect):
                                    var subRect = subRect
                                    subRect.origin.x = 0.0
                                    subRect.size.width = 10000.0
                                    strongSelf.labelNode.visibilityRect = subRect
                                    //strongSelf.spoilerTextNode?.visibilityRect = subRect
                                }
                            } else if let (offset, image) = backgroundMaskImage {
                                if item.context.sharedContext.energyUsageSettings.fullTranslucency {
                                    if strongSelf.backgroundNode == nil {
                                        if let backgroundNode = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                            strongSelf.backgroundNode = backgroundNode
                                            backgroundNode.addSubnode(strongSelf.backgroundColorNode)
                                            strongSelf.insertSubnode(backgroundNode, at: 0)
                                        }
                                    }
                                    strongSelf.backgroundColorNode.isHidden = true
                                } else {
                                    if strongSelf.backgroundMaskNode.supernode == nil {
                                        strongSelf.insertSubnode(strongSelf.backgroundMaskNode, at: 0)
                                    }
                                }

                                if backgroundMaskUpdated {
                                    if let backgroundNode = strongSelf.backgroundNode {
                                        if labelRects.count == 1 {
                                            backgroundNode.clipsToBounds = true
                                            backgroundNode.cornerRadius = min(32.0, labelRects[0].height / 2.0)
                                            backgroundNode.view.mask = nil
                                        } else {
                                            backgroundNode.clipsToBounds = false
                                            backgroundNode.cornerRadius = 0.0
                                            backgroundNode.view.mask = strongSelf.backgroundMaskNode.view
                                        }
                                    }
                                }

                                if let backgroundNode = strongSelf.backgroundNode {
                                    animation.animator.updateFrame(layer: backgroundNode.layer, frame: CGRect(origin: CGPoint(x: baseBackgroundFrame.minX + offset.x, y: baseBackgroundFrame.minY + offset.y), size: image.size), completion: nil)
                                    
                                    if let (rect, size) = strongSelf.absoluteRect {
                                        strongSelf.updateAbsoluteRect(rect, within: size)
                                    }
                                    strongSelf.backgroundMaskNode.frame = CGRect(origin: CGPoint(), size: image.size)
                                    strongSelf.backgroundMaskNode.layer.layerTintColor = nil
                                } else {
                                    animation.animator.updateFrame(layer: strongSelf.backgroundMaskNode.layer, frame: CGRect(origin: CGPoint(x: baseBackgroundFrame.minX + offset.x, y: baseBackgroundFrame.minY + offset.y), size: image.size), completion: nil)
                                    strongSelf.backgroundMaskNode.layer.layerTintColor = selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).cgColor
                                }
                                
                                strongSelf.backgroundMaskNode.image = image

                                animation.animator.updateFrame(layer: strongSelf.backgroundColorNode.layer, frame: CGRect(origin: CGPoint(), size: image.size), completion: nil)

                                strongSelf.cachedMaskBackgroundImage = (offset, image, labelRects)
                                
                                switch strongSelf.visibility {
                                case .none:
                                    strongSelf.labelNode.visibilityRect = nil
                                    //strongSelf.spoilerTextNode?.visibilityRect = nil
                                case let .visible(_, subRect):
                                    var subRect = subRect
                                    subRect.origin.x = 0.0
                                    subRect.size.width = 10000.0
                                    strongSelf.labelNode.visibilityRect = subRect
                                    //strongSelf.spoilerTextNode?.visibilityRect = subRect
                                }
                            }
                        }
                    })
                })
            })
        }
    }

    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)

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
            let textNodeFrame = self.labelNode.textNode.frame
            if let point = point {
                if let (index, attributes) = self.labelNode.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY - 10.0)) {
                    let possibleNames: [String] = [
                        TelegramTextAttributes.URL,
                        TelegramTextAttributes.PeerMention,
                        TelegramTextAttributes.PeerTextMention,
                        TelegramTextAttributes.BotCommand,
                        TelegramTextAttributes.Hashtag
                    ]
                    for name in possibleNames {
                        if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                            rects = self.labelNode.textNode.lineAndAttributeRects(name: name, at: index)
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
                    linkHighlightingNode.useModernPathCalculation = false
                    linkHighlightingNode.inset = 2.5
                    self.linkHighlightingNode = linkHighlightingNode
                    self.insertSubnode(linkHighlightingNode, belowSubnode: self.labelNode.textNode)
                }
                linkHighlightingNode.frame = self.labelNode.textNode.frame.offsetBy(dx: 0.0, dy: 1.5)
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
        guard let item = self.item else {
            return ChatMessageBubbleContentTapAction(content: .none)
        }
        
        let textNodeFrame = self.labelNode.textNode.frame
        if let (index, attributes) = self.labelNode.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY - 10.0)), gesture == .tap {
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let (attributeText, fullText) = self.labelNode.textNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                }
                return ChatMessageBubbleContentTapAction(content: .url(ChatMessageBubbleContentTapAction.Url(url: url, concealed: concealed)))
            } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                if peerMention.peerId == item.context.account.peerId, let action = item.message.media.first as? TelegramMediaAction, case .customText = action.action {
                    return ChatMessageBubbleContentTapAction(content: .peerMention(peerId: peerMention.peerId, mention: peerMention.mention, openProfile: false))
                } else {
                    return ChatMessageBubbleContentTapAction(content: .peerMention(peerId: peerMention.peerId, mention: peerMention.mention, openProfile: true))
                }
            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return ChatMessageBubbleContentTapAction(content: .textMention(peerName))
            } else if let botCommand = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                return ChatMessageBubbleContentTapAction(content: .botCommand(botCommand))
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return ChatMessageBubbleContentTapAction(content: .hashtag(hashtag.peerName, hashtag.hashtag))
            }
        }
        if let imageNode = self.imageNode, imageNode.frame.contains(point) {
            return ChatMessageBubbleContentTapAction(content: .openMessage)
        }
        if let buyStarsButton = self.buyStarsButton, buyStarsButton.frame.contains(point) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        
        if let backgroundNode = self.backgroundNode, backgroundNode.frame.contains(point) {
            if let item = self.item, item.message.media.contains(where: { $0 is TelegramMediaStory }) {
                return ChatMessageBubbleContentTapAction(content: .none)
            } else {
                return ChatMessageBubbleContentTapAction(content: .openMessage)
            }
        } else {
            return ChatMessageBubbleContentTapAction(content: .none)
        }
    }
}
