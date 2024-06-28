import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import TextFormat
import ChatMessageDateAndStatusNode
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import MessageInlineBlockBackgroundView
import TextSelectionNode
import Geocoding
import UrlEscaping

private func generateMaskImage() -> UIImage? {
    return generateImage(CGSize(width: 140, height: 30), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        var locations: [CGFloat] = [0.0, 0.5, 1.0]
        let colors: [CGColor] = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.0).cgColor, UIColor.white.withAlphaComponent(0.0).cgColor]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        context.setBlendMode(.copy)
        context.clip(to: CGRect(origin: CGPoint(x: 10.0, y: 8.0), size: CGSize(width: 130.0, height: 22.0)))
        context.drawLinearGradient(gradient, start: CGPoint(x: 10.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
    })?.resizableImage(withCapInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 22.0, right: 130.0))
}

public class ChatMessageFactCheckBubbleContentNode: ChatMessageBubbleContentNode {
    private var backgroundView: MessageInlineBlockBackgroundView?
    
    private var titleNode: TextNode
    private var titleBadgeLabel: TextNode
    private var titleBadgeButton: HighlightTrackingButtonNode?
    private let textClippingNode: ASDisplayNode
    private let textNode: TextNode
    private let additionalTextNode: TextNode
    private var linkHighlightingNode: LinkHighlightingNode?
    private var textSelectionNode: TextSelectionNode?
    
    private let lineNode: ASDisplayNode
    
    private var maskView: UIImageView?
    private var maskOverlayView: UIView?
    
    private var expandIcon: ASImageNode
    
    private let statusNode: ChatMessageDateAndStatusNode
    
    private var isExpanded: Bool = false
    private var appliedIsExpanded: Bool = false
    
    private var countryName: String?
    
    required public init() {
        self.titleNode = TextNode()
        self.titleBadgeLabel = TextNode()
        self.textClippingNode = ASDisplayNode()
        self.textNode = TextNode()
        self.additionalTextNode = TextNode()
        self.expandIcon = ASImageNode()
        self.statusNode = ChatMessageDateAndStatusNode()
        self.lineNode = ASDisplayNode()

        super.init()
        
        self.textClippingNode.clipsToBounds = true
        self.addSubnode(self.textClippingNode)
        
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .topLeft
        self.titleNode.contentsScale = UIScreenScale
        self.titleNode.displaysAsynchronously = false
        self.addSubnode(self.titleNode)
        
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .topLeft
        self.textNode.contentsScale = UIScreenScale
        self.textNode.displaysAsynchronously = false
        self.textClippingNode.addSubnode(self.textNode)
        
        self.additionalTextNode.isUserInteractionEnabled = false
        self.additionalTextNode.contentMode = .topLeft
        self.additionalTextNode.contentsScale = UIScreenScale
        self.additionalTextNode.displaysAsynchronously = false
        self.textClippingNode.addSubnode(self.additionalTextNode)
        
        self.textClippingNode.addSubnode(self.lineNode)
        
        self.titleBadgeLabel.isUserInteractionEnabled = false
        self.titleBadgeLabel.contentMode = .topLeft
        self.titleBadgeLabel.contentsScale = UIScreenScale
        self.titleBadgeLabel.displaysAsynchronously = false
        self.addSubnode(self.titleBadgeLabel)
        
        self.expandIcon.displaysAsynchronously = false
        self.addSubnode(self.expandIcon)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    public override func didLoad() {
        self.maskView = UIImageView()
        
        let maskOverlayView = UIView()
        maskOverlayView.alpha = 0.0
        maskOverlayView.backgroundColor = .white
        self.maskOverlayView = maskOverlayView
        
        self.maskView?.addSubview(maskOverlayView)
    }
    
    @objc private func badgePressed() {
        guard let item = self.item, let countryName = self.countryName else {
            return
        }
        
        item.controllerInteraction.displayMessageTooltip(item.message.id, item.presentationData.strings.Conversation_FactCheck_Description(countryName).string, true, self.titleBadgeButton, nil)
    }
    
    @objc private func expandPressed() {
        self.isExpanded = !self.isExpanded
        guard let item = self.item else{
            return
        }
        let _ = item.controllerInteraction.requestMessageUpdate(item.message.id, false)
    }
    
    public override func willUpdateIsExtractedToContextPreview(_ value: Bool) {
        if !value {
            if let textSelectionNode = self.textSelectionNode {
                self.textSelectionNode = nil
                textSelectionNode.highlightAreaNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                textSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak textSelectionNode] _ in
                    textSelectionNode?.highlightAreaNode.removeFromSupernode()
                    textSelectionNode?.removeFromSupernode()
                })
            }
        }
    }
    
    public override func updateIsExtractedToContextPreview(_ value: Bool) {
        if value {
            if self.textSelectionNode == nil, let item = self.item, let rootNode = item.controllerInteraction.chatControllerNode() {
                let selectionColor: UIColor = item.presentationData.theme.theme.chat.message.incoming.textSelectionColor
                let knobColor: UIColor = item.presentationData.theme.theme.chat.message.incoming.textSelectionKnobColor
                
                let textSelectionNode = TextSelectionNode(theme: TextSelectionTheme(selection: selectionColor, knob: knobColor, isDark: item.presentationData.theme.theme.overallDarkAppearance), strings: item.presentationData.strings, textNode: self.textNode, updateIsActive: { [weak self] value in
                    self?.updateIsTextSelectionActive?(value)
                }, present: { [weak self] c, a in
                    self?.item?.controllerInteraction.presentGlobalOverlayController(c, a)
                }, rootNode: { [weak rootNode] in
                    return rootNode
                }, performAction: { [weak self] text, action in
                    guard let strongSelf = self, let item = strongSelf.item else {
                        return
                    }
                    item.controllerInteraction.performTextSelectionAction(item.message, true, text, action)
                })
                textSelectionNode.enableQuote = false
                self.textSelectionNode = textSelectionNode
                self.addSubnode(textSelectionNode)
                self.insertSubnode(textSelectionNode.highlightAreaNode, belowSubnode: self.textClippingNode)
                textSelectionNode.frame = self.textClippingNode.view.convert(self.textNode.frame, to: self.view)
                textSelectionNode.highlightAreaNode.frame = textSelectionNode.frame
            }
        } else {
            if let textSelectionNode = self.textSelectionNode {
                self.textSelectionNode = nil
                self.updateIsTextSelectionActive?(false)
                textSelectionNode.highlightAreaNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                textSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak textSelectionNode] _ in
                    textSelectionNode?.highlightAreaNode.removeFromSupernode()
                    textSelectionNode?.removeFromSupernode()
                })
            }
        }
    }
    
    public override func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if let titleBadgeButton = self.titleBadgeButton, titleBadgeButton.frame.contains(point) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        
        if self.statusNode.supernode != nil, let _ = self.statusNode.hitTest(self.view.convert(point, to: self.statusNode.view), with: nil) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        
        let textNodeFrame = self.textClippingNode.frame
        if let (_, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                return ChatMessageBubbleContentTapAction(content: .url(ChatMessageBubbleContentTapAction.Url(url: url, concealed: false)))
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
        if let backgroundView = self.backgroundView, backgroundView.frame.contains(point), case .tap = gesture {
            return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                self?.expandPressed()
            }), hasLongTapAction: false)
        }
        return ChatMessageBubbleContentTapAction(content: .none)
    }
    
    public override func updateTouchesAtPoint(_ point: CGPoint?) {
        guard let item = self.item else {
            return
        }
        var rects: [CGRect]?
        if let point = point {
            let textNodeFrame = self.textClippingNode.frame
            if let (index, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
                let possibleNames: [String] = [
                    TelegramTextAttributes.URL,
                    TelegramTextAttributes.PeerMention,
                    TelegramTextAttributes.PeerTextMention,
                    TelegramTextAttributes.BotCommand,
                    TelegramTextAttributes.Hashtag,
                    TelegramTextAttributes.BankCard
                ]
                for name in possibleNames {
                    if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                        rects = self.textNode.attributeRects(name: name, at: index)
                        break
                    }
                }
            }
        }
        
        if let rects {
            let linkHighlightingNode: LinkHighlightingNode
            if let current = self.linkHighlightingNode {
                linkHighlightingNode = current
            } else {
                linkHighlightingNode = LinkHighlightingNode(color: item.message.effectivelyIncoming(item.context.account.peerId) ? item.presentationData.theme.theme.chat.message.incoming.linkHighlightColor : item.presentationData.theme.theme.chat.message.outgoing.linkHighlightColor)
                self.linkHighlightingNode = linkHighlightingNode
                self.insertSubnode(linkHighlightingNode, belowSubnode: self.textClippingNode)
            }
            linkHighlightingNode.frame = self.textClippingNode.frame
            linkHighlightingNode.updateRects(rects)
        } else if let linkHighlightingNode = self.linkHighlightingNode {
            self.linkHighlightingNode = nil
            linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                linkHighlightingNode?.removeFromSupernode()
            })
        }
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let titleLayout = TextNode.asyncLayout(self.titleNode)
        let titleBadgeLayout = TextNode.asyncLayout(self.titleBadgeLabel)
        let textLayout = TextNode.asyncLayout(self.textNode)
        let additionalTextLayout = TextNode.asyncLayout(self.additionalTextNode)
        let measureTextLayout = TextNode.asyncLayout(nil)
        let statusLayout = self.statusNode.asyncLayout()
        
        let currentIsExpanded = self.isExpanded
        let currentCountryName = self.countryName
        
        return { item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let message = item.message
                
                let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                
                let maxTextWidth = CGFloat.greatestFiniteMagnitude
                
                let horizontalInset = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                let textConstrainedSize = CGSize(width: min(maxTextWidth, constrainedSize.width - (horizontalInset - 2.0) * 2.0), height: constrainedSize.height)
                
                var edited = false
                if item.attributes.updatingMedia != nil {
                    edited = true
                }
                var viewCount: Int?
                var rawText = ""
                var rawEntities: [MessageTextEntity] = []
                var dateReplies = 0
                var dateReactionsAndPeers = mergedMessageReactionsAndPeers(accountPeerId: item.context.account.peerId, accountPeer: item.associatedData.accountPeer, message: item.message)
                if item.message.isRestricted(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) {
                    dateReactionsAndPeers = ([], [])
                }
                for attribute in item.message.attributes {
                    if let attribute = attribute as? EditedMessageAttribute {
                        edited = !attribute.isHidden
                    } else if let attribute = attribute as? ViewCountMessageAttribute {
                        viewCount = attribute.count
                    } else if let attribute = attribute as? FactCheckMessageAttribute, case let .Loaded(text, entities, _) = attribute.content {
                        rawText = text
                        rawEntities = entities
                    } else if let attribute = attribute as? ReplyThreadMessageAttribute, case .peer = item.chatLocation {
                        if let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .group = channel.info {
                            dateReplies = Int(attribute.count)
                        }
                    }
                }
                
                let dateFormat: MessageTimestampStatusFormat
                if item.presentationData.isPreview {
                    dateFormat = .full
                } else if let subject = item.associatedData.subject, case .messageOptions = subject {
                    dateFormat = .minimal
                } else {
                    dateFormat = .regular
                }
                let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, format: dateFormat, associatedData: item.associatedData)
                
                let statusType: ChatMessageDateAndStatusType?
                if case .customChatContents = item.associatedData.subject {
                    statusType = nil
                } else {
                    switch position {
                    case .linear(_, .None), .linear(_, .Neighbour(true, _, _)):
                        if incoming {
                            statusType = .BubbleIncoming
                        } else {
                            if message.flags.contains(.Failed) {
                                statusType = .BubbleOutgoing(.Failed)
                            } else if message.flags.isSending && !message.isSentOrAcknowledged {
                                statusType = .BubbleOutgoing(.Sending)
                            } else {
                                statusType = .BubbleOutgoing(.Sent(read: item.read))
                            }
                        }
                    default:
                        statusType = nil
                    }
                }
                                
                let messageTheme = incoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
                                
                let fontSize = floor(item.presentationData.fontSize.baseDisplaySize * 14.0 / 17.0)
                let textFont = Font.regular(fontSize)
                let textBoldFont = Font.semibold(fontSize)
                let textItalicFont = Font.italic(fontSize)
                let textBoldItalicFont = Font.semiboldItalic(fontSize)
                let textFixedFont = Font.regular(fontSize)
                let textBlockQuoteFont = Font.regular(fontSize)
                let badgeFont = Font.regular(floor(item.presentationData.fontSize.baseDisplaySize * 11.0 / 17.0))
                
                let attributedText = stringWithAppliedEntities(rawText, entities: rawEntities, baseColor: messageTheme.primaryTextColor, linkColor: messageTheme.linkTextColor, baseFont: textFont, linkFont: textFont, boldFont: textBoldFont, italicFont: textItalicFont, boldItalicFont: textBoldItalicFont, fixedFont: textFixedFont, blockQuoteFont: textBlockQuoteFont, message: nil)
                
                let textInsets = UIEdgeInsets(top: 2.0, left: 0.0, bottom: 5.0, right: 0.0)
                
                var backgroundInsets = UIEdgeInsets()
                backgroundInsets.left += layoutConstants.text.bubbleInsets.left
                backgroundInsets.right += layoutConstants.text.bubbleInsets.right
                
                let mainColor = messageTheme.scamColor
                
                let (titleLayout, titleApply) = titleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Message_FactCheck, font: textBoldFont, textColor: mainColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: textInsets, lineColor: mainColor))
                
                let titleBadgePadding: CGFloat = 5.0
                let titleBadgeSpacing: CGFloat = 5.0
                let titleBadgeString = NSAttributedString(string: item.presentationData.strings.Message_FactCheck_WhatIsThis, font: badgeFont, textColor: mainColor)
                let (titleBadgeLayout, titleBadgeApply) = titleBadgeLayout(TextNodeLayoutArguments(attributedString: titleBadgeString, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: textConstrainedSize))
                
                let countryName: String
                if let currentCountryName {
                    countryName = currentCountryName
                } else {
                    if let attribute = item.message.factCheckAttribute, case let .Loaded(_, _, countryIdValue) = attribute.content {
                        let locale = localeWithStrings(item.presentationData.strings)
                        countryName = displayCountryName(countryIdValue, locale: locale)
                    } else {
                        countryName = ""
                    }
                }
                
                let finalAttributedText = stringWithAppliedEntities(rawText, entities: rawEntities, baseColor: messageTheme.primaryTextColor, linkColor: messageTheme.linkTextColor, baseFont: textFont, linkFont: textFont, boldFont: textBoldFont, italicFont: textItalicFont, boldItalicFont: textBoldItalicFont, fixedFont: textFixedFont, blockQuoteFont: textBlockQuoteFont, message: nil) as! NSMutableAttributedString
                finalAttributedText.append(NSAttributedString(string: "__", font: textFont, textColor: .clear))
                
                let (textLayout, textApply) = textLayout(TextNodeLayoutArguments(attributedString: finalAttributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: textInsets, lineColor: messageTheme.accentControlColor))
                
                let additionalAttributedText = NSMutableAttributedString(string: item.presentationData.strings.Conversation_FactCheck_InnerDescription(countryName).string, font: badgeFont, textColor: mainColor)
                additionalAttributedText.append(NSAttributedString(string: "__", font: badgeFont, textColor: .clear))
                
                let (additionalTextLayout, additionalTextApply) = additionalTextLayout(TextNodeLayoutArguments(attributedString: additionalAttributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, lineSpacing: 0.0, cutout: nil, insets: textInsets, lineColor: messageTheme.accentControlColor))
            
                var canExpand = false
                var clippedTextHeight: CGFloat = textLayout.size.height
                if textLayout.numberOfLines > 4 {
                    let (measuredTextLayout, _) = measureTextLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 4, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: textInsets, lineColor: messageTheme.accentControlColor))
                    canExpand = true
                    
                    if !currentIsExpanded {
                        clippedTextHeight = measuredTextLayout.size.height
                    }
                }
                
                var titleFrame = CGRect(origin: CGPoint(x: -textInsets.left, y: -textInsets.top), size: titleLayout.size)
                titleFrame = titleFrame.offsetBy(dx: layoutConstants.text.bubbleInsets.left * 2.0 - 2.0, dy: layoutConstants.text.bubbleInsets.top - 3.0)
                var titleFrameWithoutInsets = CGRect(origin: CGPoint(x: titleFrame.origin.x + textInsets.left, y: titleFrame.origin.y + textInsets.top), size: CGSize(width: titleFrame.width - textInsets.left - textInsets.right, height: titleFrame.height - textInsets.top - textInsets.bottom))
                titleFrameWithoutInsets = titleFrameWithoutInsets.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)
                
                let topInset: CGFloat = 5.0
                let textSpacing: CGFloat = 3.0
                
                let textFrame = CGRect(origin: CGPoint(x: titleFrame.origin.x, y: -textInsets.top + titleFrameWithoutInsets.height + textSpacing), size: textLayout.size)
                var textFrameWithoutInsets = CGRect(origin: CGPoint(x: textFrame.origin.x + textInsets.left, y: textFrame.origin.y + textInsets.top), size: CGSize(width: textFrame.width - textInsets.left - textInsets.right, height: clippedTextHeight - textInsets.top - textInsets.bottom))
                textFrameWithoutInsets = textFrameWithoutInsets.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)
                
                let additionalTextFrame = CGRect(origin: CGPoint(x: titleFrame.origin.x, y: textFrame.maxY), size: additionalTextLayout.size)
                var additionalTextFrameWithoutInsets = CGRect(origin: CGPoint(x: additionalTextFrame.origin.x + textInsets.left, y: additionalTextFrame.origin.y + textInsets.top), size: CGSize(width: additionalTextFrame.width - textInsets.left - textInsets.right, height: additionalTextFrame.height - textInsets.top - textInsets.bottom))
                additionalTextFrameWithoutInsets = additionalTextFrameWithoutInsets.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)
                
                var statusSuggestedWidthAndContinue: (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))?
                if let statusType = statusType {
                    var isReplyThread = false
                    if case .replyThread = item.chatLocation {
                        isReplyThread = true
                    }
                    
                    statusSuggestedWidthAndContinue = statusLayout(ChatMessageDateAndStatusNode.Arguments(
                        context: item.context,
                        presentationData: item.presentationData,
                        edited: edited && !item.presentationData.isPreview,
                        impressionCount: !item.presentationData.isPreview ? viewCount : nil,
                        dateText: dateText,
                        type: statusType,
                        layoutInput: .trailingContent(contentWidth: nil, reactionSettings: item.presentationData.isPreview ? nil : ChatMessageDateAndStatusNode.TrailingReactionSettings(displayInline: shouldDisplayInlineDateReactions(message: message, isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions), preferAdditionalInset: false)),
                        constrainedSize: textConstrainedSize,
                        availableReactions: item.associatedData.availableReactions,
                        savedMessageTags: item.associatedData.savedMessageTags,
                        reactions: dateReactionsAndPeers.reactions,
                        reactionPeers: dateReactionsAndPeers.peers,
                        displayAllReactionPeers: item.message.id.peerId.namespace == Namespaces.Peer.CloudUser,
                        areReactionsTags: item.topMessage.areReactionsTags(accountPeerId: item.context.account.peerId),
                        messageEffect: item.topMessage.messageEffect(availableMessageEffects: item.associatedData.availableMessageEffects),
                        replyCount: dateReplies,
                        isPinned: item.message.tags.contains(.pinned) && !item.associatedData.isInPinnedListMode && isReplyThread,
                        hasAutoremove: item.message.isSelfExpiring,
                        canViewReactionList: canViewMessageReactionList(message: item.topMessage),
                        animationCache: item.controllerInteraction.presentationContext.animationCache,
                        animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
                    ))
                }
                
                var suggestedBoundingWidth: CGFloat = max(textFrameWithoutInsets.width, titleFrameWithoutInsets.width + titleBadgeLayout.size.width + titleBadgeSpacing + titleBadgePadding * 2.0)
                if let statusSuggestedWidthAndContinue = statusSuggestedWidthAndContinue {
                    suggestedBoundingWidth = max(suggestedBoundingWidth, statusSuggestedWidthAndContinue.0)
                }
                suggestedBoundingWidth = max(suggestedBoundingWidth, additionalTextFrameWithoutInsets.width)
                let sideInsets = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                suggestedBoundingWidth += (sideInsets - 2.0) * 2.0
                
                return (suggestedBoundingWidth, { boundingWidth in
                    var boundingSize: CGSize
                    
                    let statusSizeAndApply = statusSuggestedWidthAndContinue?.1(boundingWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right)
                    
                    var contentHeight = titleFrameWithoutInsets.height + textSpacing + textFrameWithoutInsets.size.height
                    if canExpand && !currentIsExpanded {
                    } else {
                        contentHeight += textSpacing * 2.0 + 1.0 + additionalTextFrameWithoutInsets.height
                    }
                    contentHeight += textSpacing
                    boundingSize = CGSize(width: boundingWidth, height: topInset + contentHeight - textSpacing)
                    if let statusSizeAndApply = statusSizeAndApply {
                        boundingSize.height += statusSizeAndApply.0.height
                    }
                    boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                    boundingSize.height += layoutConstants.text.bubbleInsets.top + layoutConstants.text.bubbleInsets.bottom
                    
                    return (boundingSize, { [weak self] animation, _, info in
                        if let strongSelf = self {
                            info?.setInvertOffsetDirection()
                            
                            let isFirstTime = strongSelf.item == nil
                            let themeUpdated = strongSelf.item?.presentationData.theme.theme !== item.presentationData.theme.theme
                            
                            strongSelf.item = item
                            strongSelf.countryName = countryName
     
                            let backgroundView: MessageInlineBlockBackgroundView
                            if let current = strongSelf.backgroundView {
                                backgroundView = current
                            } else {
                                backgroundView = MessageInlineBlockBackgroundView()
                                strongSelf.view.insertSubview(backgroundView, at: 0)
                                strongSelf.backgroundView = backgroundView
                            }
                            
                            if themeUpdated {
                                strongSelf.lineNode.backgroundColor = mainColor.withAlphaComponent(0.15)
                            }
                            
                            var isExpandedUpdated = false
                            if strongSelf.appliedIsExpanded != currentIsExpanded {
                                strongSelf.appliedIsExpanded = currentIsExpanded
                                info?.setInvertOffsetDirection()
                                isExpandedUpdated = true
                                
                                animation.transition.updateTransformRotation(node: strongSelf.expandIcon, angle: currentIsExpanded ? .pi : 0.0)
                                if let maskOverlayView = strongSelf.maskOverlayView {
                                    animation.transition.updateAlpha(layer: maskOverlayView.layer, alpha: currentIsExpanded ? 1.0 : 0.0)
                                }
                            }
                            
                            let cachedLayout = strongSelf.textNode.cachedLayout
                            
                            if case .System = animation, !isExpandedUpdated {
                                if let cachedLayout = cachedLayout {
                                    if !cachedLayout.areLinesEqual(to: textLayout) {
                                        if let textContents = strongSelf.textNode.contents {
                                            let fadeNode = ASDisplayNode()
                                            fadeNode.displaysAsynchronously = false
                                            fadeNode.contents = textContents
                                            fadeNode.frame = strongSelf.textNode.frame
                                            fadeNode.isLayerBacked = true
                                            strongSelf.textClippingNode.addSubnode(fadeNode)
                                            fadeNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak fadeNode] _ in
                                                fadeNode?.removeFromSupernode()
                                            })
                                            strongSelf.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                        }
                                    }
                                }
                            }
                            
                            if themeUpdated {
                                strongSelf.expandIcon.image = generateImage(CGSize(width: 15.0, height: 9.0), rotatedContext: { size, context in
                                    context.clear(CGRect(origin: CGPoint(), size: size))
                                    context.setStrokeColor(mainColor.cgColor)
                                    context.setLineWidth(2.0 - UIScreenPixel)
                                    context.setLineCap(.round)
                                    context.setLineJoin(.round)
                                    context.beginPath()
                                    context.move(to: CGPoint(x: 1.0 + UIScreenPixel, y: 1.0))
                                    context.addLine(to: CGPoint(x: size.width / 2.0, y: size.height - 2.0))
                                    context.addLine(to: CGPoint(x: size.width - 1.0 - UIScreenPixel, y: 1.0))
                                    context.strokePath()
                                })
                            }
                            
                            let _ = titleApply()
                            strongSelf.titleNode.frame = titleFrame.offsetBy(dx: 0.0, dy: topInset)
                            let _ = titleBadgeApply()

                            let _ = textApply()
                            strongSelf.textNode.frame = CGRect(origin: .zero, size: textFrame.size)
                            
                            let _ = additionalTextApply()
                            strongSelf.additionalTextNode.frame = CGRect(origin: CGPoint(x: 0.0, y: textFrame.height - textInsets.bottom + textSpacing + 1.0), size: additionalTextFrame.size)
                            
                            let clippingTextFrame = CGRect(origin: textFrame.origin.offsetBy(dx: 0.0, dy: topInset), size: CGSize(width: boundingWidth, height: contentHeight - titleFrame.height + textSpacing))
                             
                            var titleLineWidth: CGFloat = 0.0
                            if let firstLine = titleLayout.linesRects().first {
                                titleLineWidth = firstLine.width
                            } else {
                                titleLineWidth = titleFrame.width
                            }
                            
                            let titleBadgeFrame = CGRect(origin: CGPoint(x: titleFrame.minX + titleLineWidth + titleBadgeSpacing + titleBadgePadding, y: topInset + floorToScreenPixels(titleFrame.midY - titleBadgeLayout.size.height / 2.0) - 1.0), size: titleBadgeLayout.size)
                            let badgeBackgroundFrame = titleBadgeFrame.insetBy(dx: -titleBadgePadding, dy: -1.0 + UIScreenPixel)
                            
                            strongSelf.titleBadgeLabel.frame = titleBadgeFrame
                            
                            let titleBadgeButton: HighlightTrackingButtonNode
                            if let current = strongSelf.titleBadgeButton {
                                titleBadgeButton = current
                                titleBadgeButton.bounds = CGRect(origin: .zero, size: badgeBackgroundFrame.size)
                                animation.animator.updatePosition(layer: titleBadgeButton.layer, position: badgeBackgroundFrame.center, completion: nil)
                            } else {
                                titleBadgeButton = HighlightTrackingButtonNode()
                                titleBadgeButton.addTarget(self, action: #selector(strongSelf.badgePressed), forControlEvents: .touchUpInside)
                                titleBadgeButton.frame = badgeBackgroundFrame
                                titleBadgeButton.highligthedChanged = { [weak self, weak titleBadgeButton] highlighted in
                                    if let strongSelf = self, let titleBadgeButton {
                                        if highlighted {
                                            titleBadgeButton.layer.removeAnimation(forKey: "opacity")
                                            titleBadgeButton.alpha = 0.4
                                            strongSelf.titleBadgeLabel.layer.removeAnimation(forKey: "opacity")
                                            strongSelf.titleBadgeLabel.alpha = 0.4
                                        } else {
                                            titleBadgeButton.alpha = 1.0
                                            titleBadgeButton.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                                            strongSelf.titleBadgeLabel.alpha = 1.0
                                            strongSelf.titleBadgeLabel.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                                        }
                                    }
                                }
                                strongSelf.titleBadgeButton = titleBadgeButton
                                strongSelf.addSubnode(titleBadgeButton)
                            }
                            
                            titleBadgeButton.isHidden = item.presentationData.isPreview
                            strongSelf.titleBadgeLabel.isHidden = item.presentationData.isPreview
                            
                            if themeUpdated || titleBadgeButton.backgroundImage(for: .normal) == nil {
                                titleBadgeButton.setBackgroundImage(generateFilledCircleImage(diameter: badgeBackgroundFrame.height, color: mainColor.withMultipliedAlpha(0.1))?.stretchableImage(withLeftCapWidth: Int(badgeBackgroundFrame.height / 2), topCapHeight: Int(badgeBackgroundFrame.height / 2)), for: .normal)
                            }
                            
                            let backgroundFrame = CGRect(origin: CGPoint(x: backgroundInsets.left, y: backgroundInsets.top + topInset), size: CGSize(width: boundingWidth - backgroundInsets.left - backgroundInsets.right, height: contentHeight))
                            
                            if isFirstTime {
                                strongSelf.textClippingNode.frame = clippingTextFrame
                            } else {
                                animation.animator.updateFrame(layer: strongSelf.textClippingNode.layer, frame: clippingTextFrame, completion: nil)
                            }
                            if let maskView = strongSelf.maskView, let maskOverlayView = strongSelf.maskOverlayView {
                                animation.animator.updateFrame(layer: maskView.layer, frame: CGRect(origin: .zero, size: CGSize(width: boundingWidth, height: clippingTextFrame.size.height)), completion: nil)
                                animation.animator.updateFrame(layer: maskOverlayView.layer, frame: CGRect(origin: .zero, size: CGSize(width: boundingWidth, height: clippingTextFrame.size.height)), completion: nil)
                            }
                            
                            if isFirstTime {
                                backgroundView.frame = backgroundFrame
                            } else {
                                animation.animator.updateFrame(layer: backgroundView.layer, frame: backgroundFrame, completion: nil)
                            }
                            backgroundView.update(size: backgroundFrame.size, isTransparent: false, primaryColor: mainColor, secondaryColor: nil, thirdColor: nil, backgroundColor: nil, pattern: nil, patternTopRightPosition: nil, animation: isFirstTime ? .None : animation)
                            
                            animation.animator.updateFrame(layer: strongSelf.lineNode.layer, frame: CGRect(origin: CGPoint(x: 0.0, y: textFrame.height - textSpacing + 1.0), size: CGSize(width: backgroundFrame.width - 9.0 - 6.0, height: 1.0 - UIScreenPixel)), completion: nil)
                            
                            if canExpand {
                                let wasHidden = strongSelf.expandIcon.isHidden
                                strongSelf.expandIcon.isHidden = false
                                if strongSelf.maskView?.image == nil {
                                    strongSelf.maskView?.image = generateMaskImage()
                                }
                                strongSelf.textClippingNode.view.mask = strongSelf.maskView
                                
                                var expandIconFrame: CGRect = .zero
                                if let icon = strongSelf.expandIcon.image {
                                    expandIconFrame = CGRect(origin: CGPoint(x: boundingWidth - icon.size.width - 19.0, y: backgroundFrame.maxY - icon.size.height - 6.0), size: icon.size)
                                    if wasHidden || isFirstTime {
                                        strongSelf.expandIcon.position = expandIconFrame.center
                                    } else {
                                        animation.animator.updatePosition(layer: strongSelf.expandIcon.layer, position: expandIconFrame.center, completion: nil)
                                    }
                                    strongSelf.expandIcon.bounds = CGRect(origin: .zero, size: expandIconFrame.size)
                                }
                            } else {
                                strongSelf.expandIcon.isHidden = true
                                strongSelf.textClippingNode.view.mask = nil
                            }
                            
                            if let textSelectionNode = strongSelf.textSelectionNode {
                                let shouldUpdateLayout = textSelectionNode.frame.size != textFrame.size
                                textSelectionNode.frame = strongSelf.textClippingNode.view.convert(strongSelf.textNode.frame, to: strongSelf.view)
                                textSelectionNode.highlightAreaNode.frame = textSelectionNode.frame
                                
                                if shouldUpdateLayout {
                                    textSelectionNode.updateLayout()
                                }
                            }
                            
                            if let statusSizeAndApply = statusSizeAndApply {
                                strongSelf.statusNode.reactionSelected = { [weak strongSelf] _, value, sourceView in
                                    guard let strongSelf, let item = strongSelf.item else {
                                        return
                                    }
                                    item.controllerInteraction.updateMessageReaction(item.topMessage, .reaction(value), false, sourceView)
                                }
                                strongSelf.statusNode.openReactionPreview = { [weak strongSelf] gesture, sourceNode, value in
                                    guard let strongSelf, let item = strongSelf.item else {
                                        gesture?.cancel()
                                        return
                                    }
                                    
                                    item.controllerInteraction.openMessageReactionContextMenu(item.topMessage, sourceNode, gesture, value)
                                }
                                
                                let statusFrame = CGRect(origin: CGPoint(x: boundingWidth - layoutConstants.text.bubbleInsets.right - statusSizeAndApply.0.width, y: backgroundFrame.maxY + 4.0), size: statusSizeAndApply.0)
                                if isFirstTime {
                                    strongSelf.statusNode.frame = statusFrame
                                } else {
                                    animation.animator.updateFrame(layer: strongSelf.statusNode.layer, frame: statusFrame, completion: nil)
                                }
                                
                                if strongSelf.statusNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.statusNode)
                                    statusSizeAndApply.1(.None)
                                } else {
                                    statusSizeAndApply.1(animation)
                                }
                            } else if strongSelf.statusNode.supernode != nil {
                                strongSelf.statusNode.removeFromSupernode()
                            }
                        }
                    })
                })
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.statusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
}
