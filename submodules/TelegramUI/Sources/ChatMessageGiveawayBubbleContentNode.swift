import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AvatarNode
import AccountContext
import PhoneNumberFormat
import TelegramStringFormatting
import Markdown
import ShimmerEffect
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import ChatMessageDateAndStatusNode

private let titleFont = Font.medium(15.0)
private let textFont = Font.regular(13.0)
private let boldTextFont = Font.semibold(13.0)

class ChatMessageGiveawayBubbleContentNode: ChatMessageBubbleContentNode {
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    
    private let placeholderNode: StickerShimmerEffectNode
    private let animationNode: AnimatedStickerNode
    
    private let prizeTitleNode: TextNode
    private let prizeTextNode: TextNode
    
    private let participantsTitleNode: TextNode
    private let participantsTextNode: TextNode
    
    private let dateTitleNode: TextNode
    private let dateTextNode: TextNode
    
    private var giveaway: TelegramMediaGiveaway?
    
    private let buttonNode: ChatMessageAttachedContentButtonNode
    
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
    
    private var setupTimestamp: Double?
    
    required init() {
        self.placeholderNode = StickerShimmerEffectNode()
        self.placeholderNode.isUserInteractionEnabled = false
        self.placeholderNode.alpha = 0.75
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        self.prizeTitleNode = TextNode()
        self.prizeTextNode = TextNode()
        
        self.participantsTitleNode = TextNode()
        self.participantsTextNode = TextNode()
        
        self.dateTitleNode = TextNode()
        self.dateTextNode = TextNode()
        
        self.buttonNode = ChatMessageAttachedContentButtonNode()
        
        super.init()
        
        self.addSubnode(self.prizeTitleNode)
        self.addSubnode(self.prizeTextNode)
        self.addSubnode(self.participantsTitleNode)
        self.addSubnode(self.participantsTextNode)
        self.addSubnode(self.dateTitleNode)
        self.addSubnode(self.dateTextNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.animationNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.dateAndStatusNode.reactionSelected = { [weak self] value in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            item.controllerInteraction.updateMessageReaction(item.message, .reaction(value))
        }
        
        self.dateAndStatusNode.openReactionPreview = { [weak self] gesture, sourceView, value in
            guard let strongSelf = self, let item = strongSelf.item else {
                gesture?.cancel()
                return
            }
            
            item.controllerInteraction.openMessageReactionContextMenu(item.topMessage, sourceView, gesture, value)
        }
    }
    
    override func accessibilityActivate() -> Bool {
        self.buttonPressed()
        return true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didLoad() {
        super.didLoad()
        
//        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.contactTap(_:)))
//        self.view.addGestureRecognizer(tapRecognizer)
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
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let statusLayout = self.dateAndStatusNode.asyncLayout()
        let makePrizeTitleLayout = TextNode.asyncLayout(self.prizeTitleNode)
        let makePrizeTextLayout = TextNode.asyncLayout(self.prizeTextNode)
        
        let makeParticipantsTitleLayout = TextNode.asyncLayout(self.participantsTitleNode)
        let makeParticipantsTextLayout = TextNode.asyncLayout(self.participantsTextNode)
        
        let makeDateTitleLayout = TextNode.asyncLayout(self.dateTitleNode)
        let makeDateTextLayout = TextNode.asyncLayout(self.dateTextNode)
        
        let makeButtonLayout = ChatMessageAttachedContentButtonNode.asyncLayout(self.buttonNode)
                
        return { item, layoutConstants, _, _, constrainedSize, _ in
            var giveaway: TelegramMediaGiveaway?
            for media in item.message.media {
                if let media = media as? TelegramMediaGiveaway {
                    giveaway = media;
                }
            }
            
            var incoming = item.message.effectivelyIncoming(item.context.account.peerId)
            if case .forwardedMessages = item.associatedData.subject {
                incoming = false
            }
            
            let textColor = incoming ? item.presentationData.theme.theme.chat.message.incoming.primaryTextColor : item.presentationData.theme.theme.chat.message.outgoing.primaryTextColor
            
            let prizeTitleString = NSAttributedString(string: "Giveaway Prizes", font: titleFont, textColor: textColor)
            var prizeTextString: NSAttributedString?
            if let giveaway {
                prizeTextString = parseMarkdownIntoAttributedString("**\(giveaway.quantity)** Telegram Premium Subscriptions for **\(giveaway.months)** months.", attributes: MarkdownAttributes(
                    body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                    bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                    link: MarkdownAttributeSet(font: textFont, textColor: textColor),
                    linkAttribute: { url in
                        return ("URL", url)
                    }
                ), textAlignment: .center)
            }
            
            let participantsTitleString = NSAttributedString(string: "Participants", font: titleFont, textColor: textColor)
            let participantsTextString = NSAttributedString(string: "All subscribers of this channel:", font: textFont, textColor: textColor)
            
            let dateTitleString = NSAttributedString(string: "Winners Selection Date", font: titleFont, textColor: textColor)
            var dateTextString: NSAttributedString?
            if let giveaway {
                dateTextString = NSAttributedString(string: stringForFullDate(timestamp: giveaway.untilDate, strings: item.presentationData.strings, dateTimeFormat: item.presentationData.dateTimeFormat), font: textFont, textColor: textColor)
            }
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let sideInsets = layoutConstants.text.bubbleInsets.right * 2.0
                
                let maxTextWidth = min(200.0, max(1.0, constrainedSize.width - 7.0 - sideInsets))
                let (prizeTitleLayout, prizeTitleApply) = makePrizeTitleLayout(TextNodeLayoutArguments(attributedString: prizeTitleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                                
                let (prizeTextLayout, prizeTextApply) = makePrizeTextLayout(TextNodeLayoutArguments(attributedString: prizeTextString, backgroundColor: nil, maximumNumberOfLines: 5, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (participantsTitleLayout, participantsTitleApply) = makeParticipantsTitleLayout(TextNodeLayoutArguments(attributedString: participantsTitleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                let (participantsTextLayout, participantsTextApply) = makeParticipantsTextLayout(TextNodeLayoutArguments(attributedString: participantsTextString, backgroundColor: nil, maximumNumberOfLines: 5, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (dateTitleLayout, dateTitleApply) = makeDateTitleLayout(TextNodeLayoutArguments(attributedString: dateTitleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                let (dateTextLayout, dateTextApply) = makeDateTextLayout(TextNodeLayoutArguments(attributedString: dateTextString, backgroundColor: nil, maximumNumberOfLines: 5, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                var edited = false
                if item.attributes.updatingMedia != nil {
                    edited = true
                }
                var viewCount: Int?
                var dateReplies = 0
                var dateReactionsAndPeers = mergedMessageReactionsAndPeers(accountPeer: item.associatedData.accountPeer, message: item.message)
                if item.message.isRestricted(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) {
                    dateReactionsAndPeers = ([], [])
                }
                for attribute in item.message.attributes {
                    if let attribute = attribute as? EditedMessageAttribute {
                        edited = !attribute.isHidden
                    } else if let attribute = attribute as? ViewCountMessageAttribute {
                        viewCount = attribute.count
                    } else if let attribute = attribute as? ReplyThreadMessageAttribute, case .peer = item.chatLocation {
                        if let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .group = channel.info {
                            dateReplies = Int(attribute.count)
                        }
                    }
                }
                
                let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, associatedData: item.associatedData)
                
                let statusType: ChatMessageDateAndStatusType?
                switch position {
                    case .linear(_, .None), .linear(_, .Neighbour(true, _, _)):
                        if incoming {
                            statusType = .BubbleIncoming
                        } else {
                            if item.message.flags.contains(.Failed) {
                                statusType = .BubbleOutgoing(.Failed)
                            } else if (item.message.flags.isSending && !item.message.isSentOrAcknowledged) || item.attributes.updatingMedia != nil {
                                statusType = .BubbleOutgoing(.Sending)
                            } else {
                                statusType = .BubbleOutgoing(.Sent(read: item.read))
                            }
                        }
                    default:
                        statusType = nil
                }
                
                var statusSuggestedWidthAndContinue: (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))?
                if let statusType = statusType {
                    var isReplyThread = false
                    if case .replyThread = item.chatLocation {
                        isReplyThread = true
                    }
                    
                    statusSuggestedWidthAndContinue = statusLayout(ChatMessageDateAndStatusNode.Arguments(
                        context: item.context,
                        presentationData: item.presentationData,
                        edited: edited,
                        impressionCount: viewCount,
                        dateText: dateText,
                        type: statusType,
                        layoutInput: .trailingContent(contentWidth: 1000.0, reactionSettings: shouldDisplayInlineDateReactions(message: item.message, isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions) ? ChatMessageDateAndStatusNode.TrailingReactionSettings(displayInline: true, preferAdditionalInset: false) : nil),
                        constrainedSize: CGSize(width: constrainedSize.width - sideInsets, height: .greatestFiniteMagnitude),
                        availableReactions: item.associatedData.availableReactions,
                        reactions: dateReactionsAndPeers.reactions,
                        reactionPeers: dateReactionsAndPeers.peers,
                        displayAllReactionPeers: item.message.id.peerId.namespace == Namespaces.Peer.CloudUser,
                        replyCount: dateReplies,
                        isPinned: item.message.tags.contains(.pinned) && !item.associatedData.isInPinnedListMode && isReplyThread,
                        hasAutoremove: item.message.isSelfExpiring,
                        canViewReactionList: canViewMessageReactionList(message: item.message),
                        animationCache: item.controllerInteraction.presentationContext.animationCache,
                        animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
                    ))
                }
                
                let buttonImage: UIImage
                let buttonHighlightedImage: UIImage
                let titleColor: UIColor
                let titleHighlightedColor: UIColor
                if incoming {
                    buttonImage = PresentationResourcesChat.chatMessageAttachedContentButtonIncoming(item.presentationData.theme.theme)!
                    buttonHighlightedImage = PresentationResourcesChat.chatMessageAttachedContentHighlightedButtonIncoming(item.presentationData.theme.theme)!
                    titleColor = item.presentationData.theme.theme.chat.message.incoming.accentTextColor
                    
                    let bubbleColors = bubbleColorComponents(theme: item.presentationData.theme.theme, incoming: true, wallpaper: !item.presentationData.theme.wallpaper.isEmpty)
                    titleHighlightedColor = bubbleColors.fill[0]
                } else {
                    buttonImage = PresentationResourcesChat.chatMessageAttachedContentButtonOutgoing(item.presentationData.theme.theme)!
                    buttonHighlightedImage = PresentationResourcesChat.chatMessageAttachedContentHighlightedButtonOutgoing(item.presentationData.theme.theme)!
                    titleColor = item.presentationData.theme.theme.chat.message.outgoing.accentTextColor
                    
                    let bubbleColors = bubbleColorComponents(theme: item.presentationData.theme.theme, incoming: false, wallpaper: !item.presentationData.theme.wallpaper.isEmpty)
                    titleHighlightedColor = bubbleColors.fill[0]
                }
                
                let (buttonWidth, continueLayout) = makeButtonLayout(constrainedSize.width, buttonImage, buttonHighlightedImage, nil, nil, false, "HOW DOES IT WORK?", titleColor, titleHighlightedColor, false)
                
                let months = giveaway?.months ?? 0
                let animationName: String
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
                
                var maxContentWidth: CGFloat = 0.0
                if let statusSuggestedWidthAndContinue = statusSuggestedWidthAndContinue {
                    maxContentWidth = max(maxContentWidth, statusSuggestedWidthAndContinue.0)
                }
                maxContentWidth = max(maxContentWidth, prizeTitleLayout.size.width)
                maxContentWidth = max(maxContentWidth, prizeTextLayout.size.width)
                maxContentWidth = max(maxContentWidth, participantsTitleLayout.size.width)
                maxContentWidth = max(maxContentWidth, participantsTextLayout.size.width)
                maxContentWidth = max(maxContentWidth, dateTitleLayout.size.width)
                maxContentWidth = max(maxContentWidth, dateTextLayout.size.width)
                maxContentWidth = max(maxContentWidth, buttonWidth)
                maxContentWidth += 30.0
                
                let contentWidth = maxContentWidth + layoutConstants.text.bubbleInsets.right * 2.0
                
                return (contentWidth, { boundingWidth in
                    let (buttonSize, buttonApply) = continueLayout(boundingWidth - layoutConstants.text.bubbleInsets.right * 2.0)
                    let buttonSpacing: CGFloat = 4.0
                    
                    let statusSizeAndApply = statusSuggestedWidthAndContinue?.1(boundingWidth - sideInsets)
                    
                    var layoutSize = CGSize(width: contentWidth, height: 49.0 + prizeTitleLayout.size.height + prizeTextLayout.size.height + participantsTitleLayout.size.height + participantsTextLayout.size.height + dateTitleLayout.size.height + dateTextLayout.size.height + buttonSize.height + buttonSpacing + 100.0)
                    if let statusSizeAndApply = statusSizeAndApply {
                        layoutSize.height += statusSizeAndApply.0.height - 4.0
                    }
                    let buttonFrame = CGRect(origin: CGPoint(x: layoutConstants.text.bubbleInsets.right, y: layoutSize.height - 9.0 - buttonSize.height), size: buttonSize)
                    
                    return (layoutSize, { [weak self] animation, synchronousLoads, _ in
                        if let strongSelf = self {
                            if strongSelf.item == nil {
                                strongSelf.animationNode.autoplay = true
                                strongSelf.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: animationName), width: 384, height: 384, playbackMode: .still(.start), mode: .direct(cachePathPrefix: nil))
                            }
                            strongSelf.item = item
                            strongSelf.giveaway = giveaway
                            
                            strongSelf.updateVisibility()
                                                        
                            let _ = prizeTitleApply()
                            let _ = prizeTextApply()
                            
                            let _ = participantsTitleApply()
                            let _ = participantsTextApply()
                            
                            let _ = dateTitleApply()
                            let _ = dateTextApply()
                            
                            let _ = buttonApply()
                            
                            let smallSpacing: CGFloat = 2.0
                            let largeSpacing: CGFloat = 14.0
                            
                            var originY: CGFloat = 0.0
                            
                            let iconSize = CGSize(width: 140.0, height: 140.0)
                            strongSelf.animationNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layoutSize.width - iconSize.width) / 2.0), y: originY - 50.0), size: iconSize)
                            strongSelf.animationNode.updateLayout(size: iconSize)
                            originY += 95.0
                            
                            strongSelf.prizeTitleNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layoutSize.width - prizeTitleLayout.size.width) / 2.0), y: originY), size: prizeTitleLayout.size)
                            originY += prizeTitleLayout.size.height + smallSpacing
                            strongSelf.prizeTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layoutSize.width - prizeTextLayout.size.width) / 2.0), y: originY), size: prizeTextLayout.size)
                            originY += prizeTextLayout.size.height + largeSpacing
                            
                            strongSelf.participantsTitleNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layoutSize.width - participantsTitleLayout.size.width) / 2.0), y: originY), size: participantsTitleLayout.size)
                            originY += participantsTitleLayout.size.height + smallSpacing
                            strongSelf.participantsTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layoutSize.width - participantsTextLayout.size.width) / 2.0), y: originY), size: participantsTextLayout.size)
                            originY += participantsTextLayout.size.height + largeSpacing
                            
                            strongSelf.dateTitleNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layoutSize.width - dateTitleLayout.size.width) / 2.0), y: originY), size: dateTitleLayout.size)
                            originY += dateTitleLayout.size.height + smallSpacing
                            strongSelf.dateTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layoutSize.width - dateTextLayout.size.width) / 2.0), y: originY), size: dateTextLayout.size)
                            originY += dateTextLayout.size.height + largeSpacing
                            
                            strongSelf.buttonNode.frame = buttonFrame
                            
                            if let statusSizeAndApply = statusSizeAndApply {
                                strongSelf.dateAndStatusNode.frame = CGRect(origin: CGPoint(x: layoutConstants.text.bubbleInsets.left, y: strongSelf.dateTextNode.frame.maxY + 2.0), size: statusSizeAndApply.0)
                                if strongSelf.dateAndStatusNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.dateAndStatusNode)
                                    statusSizeAndApply.1(.None)
                                } else {
                                    statusSizeAndApply.1(animation)
                                }
                            } else if strongSelf.dateAndStatusNode.supernode != nil {
                                strongSelf.dateAndStatusNode.removeFromSupernode()
                            }
                                                        
                            if let forwardInfo = item.message.forwardInfo, forwardInfo.flags.contains(.isImported) {
                                strongSelf.dateAndStatusNode.pressed = {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    item.controllerInteraction.displayImportedMessageTooltip(strongSelf.dateAndStatusNode)
                                }
                            } else {
                                strongSelf.dateAndStatusNode.pressed = nil
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
    
    private func updateVisibility() {
//        guard let item = self.item else {
//            return
//        }
//                
//        let isPlaying = self.visibilityStatus == true
//        if self.isPlaying != isPlaying {
//            self.isPlaying = isPlaying
//            self.animationNode.visibility = isPlaying
//        }
//        
//        if isPlaying && self.setupTimestamp == nil {
//            self.setupTimestamp = CACurrentMediaTime()
//        }
//        
//        if isPlaying {
//            var alreadySeen = true
//            
//            if item.message.flags.contains(.Incoming) {
//                if let unreadRange = item.controllerInteraction.unreadMessageRange[UnreadMessageRangeKey(peerId: item.message.id.peerId, namespace: item.message.id.namespace)] {
//                    if unreadRange.contains(item.message.id.id) {
//                        alreadySeen = false
//                    }
//                }
//            } else {
//                if item.controllerInteraction.playNextOutgoingGift && !item.controllerInteraction.seenOneTimeAnimatedMedia.contains(item.message.id) {
//                    alreadySeen = false
//                }
//            }
//            
//            if !item.controllerInteraction.seenOneTimeAnimatedMedia.contains(item.message.id) {
//                item.controllerInteraction.seenOneTimeAnimatedMedia.insert(item.message.id)
//                self.animationNode.playOnce()
//            }
//            
//            if !alreadySeen && self.animationNode.isPlaying {
//                item.controllerInteraction.playNextOutgoingGift = false
//                Queue.mainQueue().after(1.0) {
//                    item.controllerInteraction.animateDiceSuccess(false, true)
//                }
//            }
//        }
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        
        self.placeholderNode.updateAbsoluteRect(CGRect(origin: CGPoint(x: rect.minX + self.placeholderNode.frame.minX, y: rect.minY + self.placeholderNode.frame.minY), size: self.placeholderNode.frame.size), within: containerSize)
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.buttonNode.frame.contains(point) {
            return .openMessage
        }
        if self.dateAndStatusNode.supernode != nil, let _ = self.dateAndStatusNode.hitTest(self.view.convert(point, to: self.dateAndStatusNode.view), with: nil) {
            return .ignore
        }
        return .none
    }
    
    @objc func contactTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let item = self.item {
                let _ = item.controllerInteraction.openMessage(item.message, .default)
            }
        }
    }
    
    @objc private func buttonPressed() {
        if let item = self.item {
            let _ = item.controllerInteraction.openMessage(item.message, .default)
        }
    }
    
    override func reactionTargetView(value: MessageReaction.Reaction) -> UIView? {
        if !self.dateAndStatusNode.isHidden {
            return self.dateAndStatusNode.reactionView(value: value)
        }
        return nil
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.dateAndStatusNode.supernode != nil, let result = self.dateAndStatusNode.hitTest(self.view.convert(point, to: self.dateAndStatusNode.view), with: event) {
            return result
        }
        return super.hitTest(point, with: event)
    }
}
