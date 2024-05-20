import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TextFormat
import ChatMessageDateAndStatusNode
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import MessageInlineBlockBackgroundView

public class ChatMessageFactCheckBubbleContentNode: ChatMessageBubbleContentNode {
    private let backgroundView: MessageInlineBlockBackgroundView
    
    private var titleNode: TextNode
    private var titleBadgeLabel: TextNode
    private var titleBadgeButton: HighlightTrackingButtonNode?
    private let textNode: TextNode
    
    private let statusNode: ChatMessageDateAndStatusNode
    
    required public init() {
        self.backgroundView = MessageInlineBlockBackgroundView()
        
        self.titleNode = TextNode()
        self.titleBadgeLabel = TextNode()
        self.textNode = TextNode()
        self.statusNode = ChatMessageDateAndStatusNode()
        
        super.init()
        
        self.view.addSubview(self.backgroundView)
        
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .topLeft
        self.titleNode.contentsScale = UIScreenScale
        self.titleNode.displaysAsynchronously = false
        self.addSubnode(self.titleNode)
        
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .topLeft
        self.textNode.contentsScale = UIScreenScale
        self.textNode.displaysAsynchronously = false
        self.addSubnode(self.textNode)
        
        self.titleBadgeLabel.isUserInteractionEnabled = false
        self.titleBadgeLabel.contentMode = .topLeft
        self.titleBadgeLabel.contentsScale = UIScreenScale
        self.titleBadgeLabel.displaysAsynchronously = false
        self.addSubnode(self.titleBadgeLabel)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func badgePressed() {
        
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let titleLayout = TextNode.asyncLayout(self.titleNode)
        let titleBadgeLayout = TextNode.asyncLayout(self.titleBadgeLabel)
        let textLayout = TextNode.asyncLayout(self.textNode)
        let statusLayout = self.statusNode.asyncLayout()
        
        return { item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let message = item.message
                
                let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                
                let maxTextWidth = CGFloat.greatestFiniteMagnitude
                
                let horizontalInset = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                let textConstrainedSize = CGSize(width: min(maxTextWidth, constrainedSize.width - horizontalInset * 2.0), height: constrainedSize.height)
                
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
                
                let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, associatedData: item.associatedData)
                
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
                
                let titleBadgeString = NSAttributedString(string: item.presentationData.strings.Message_FactCheck_WhatIsThis, font: badgeFont, textColor: mainColor)
                let (titleBadgeLayout, titleBadgeApply) = titleBadgeLayout(TextNodeLayoutArguments(attributedString: titleBadgeString, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: textConstrainedSize))
                
                let (textLayout, textApply) = textLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: textInsets, lineColor: messageTheme.accentControlColor))
                
                var titleFrame = CGRect(origin: CGPoint(x: -textInsets.left, y: -textInsets.top), size: titleLayout.size)
                titleFrame = titleFrame.offsetBy(dx: layoutConstants.text.bubbleInsets.left * 2.0 - 2.0, dy: layoutConstants.text.bubbleInsets.top - 3.0)
                var titleFrameWithoutInsets = CGRect(origin: CGPoint(x: titleFrame.origin.x + textInsets.left, y: titleFrame.origin.y + textInsets.top), size: CGSize(width: titleFrame.width - textInsets.left - textInsets.right, height: titleFrame.height - textInsets.top - textInsets.bottom))
                titleFrameWithoutInsets = titleFrameWithoutInsets.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)
                
                let textSpacing: CGFloat = 3.0
                
                let textFrame = CGRect(origin: CGPoint(x: titleFrame.origin.x, y: -textInsets.top + titleFrameWithoutInsets.height + textSpacing), size: textLayout.size)
                var textFrameWithoutInsets = CGRect(origin: CGPoint(x: textFrame.origin.x + textInsets.left, y: textFrame.origin.y + textInsets.top), size: CGSize(width: textFrame.width - textInsets.left - textInsets.right, height: textFrame.height - textInsets.top - textInsets.bottom))
                textFrameWithoutInsets = textFrameWithoutInsets.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)
                                
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
                        layoutInput: .trailingContent(contentWidth: nil, reactionSettings: ChatMessageDateAndStatusNode.TrailingReactionSettings(displayInline: shouldDisplayInlineDateReactions(message: message, isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions), preferAdditionalInset: false)),
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
                        canViewReactionList: canViewMessageReactionList(message: item.topMessage, isInline: item.associatedData.isInline),
                        animationCache: item.controllerInteraction.presentationContext.animationCache,
                        animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
                    ))
                }
                
                var suggestedBoundingWidth: CGFloat = textFrameWithoutInsets.width
                if let statusSuggestedWidthAndContinue = statusSuggestedWidthAndContinue {
                    suggestedBoundingWidth = max(suggestedBoundingWidth, statusSuggestedWidthAndContinue.0)
                }
                let sideInsets = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                suggestedBoundingWidth += sideInsets
                
                return (suggestedBoundingWidth, { boundingWidth in
                    var boundingSize: CGSize
                    
                    let statusSizeAndApply = statusSuggestedWidthAndContinue?.1(boundingWidth)
                    
                    boundingSize = CGSize(width: textFrameWithoutInsets.size.width, height: titleFrameWithoutInsets.height + textFrameWithoutInsets.size.height + textSpacing)
                    if let statusSizeAndApply = statusSizeAndApply {
                        boundingSize.height += statusSizeAndApply.0.height
                    }
                    boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                    boundingSize.height += layoutConstants.text.bubbleInsets.top + layoutConstants.text.bubbleInsets.bottom
                    
                    return (boundingSize, { [weak self] animation, _, _ in
                        if let strongSelf = self {
                            let themeUpdated = strongSelf.item?.presentationData.theme.theme !== item.presentationData.theme.theme
                            
                            strongSelf.item = item
                            
                            let cachedLayout = strongSelf.textNode.cachedLayout
                            
                            if case .System = animation {
                                if let cachedLayout = cachedLayout {
                                    if !cachedLayout.areLinesEqual(to: textLayout) {
                                        if let textContents = strongSelf.textNode.contents {
                                            let fadeNode = ASDisplayNode()
                                            fadeNode.displaysAsynchronously = false
                                            fadeNode.contents = textContents
                                            fadeNode.frame = strongSelf.textNode.frame
                                            fadeNode.isLayerBacked = true
                                            strongSelf.addSubnode(fadeNode)
                                            fadeNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak fadeNode] _ in
                                                fadeNode?.removeFromSupernode()
                                            })
                                            strongSelf.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                        }
                                    }
                                }
                            }
                            
                            let _ = titleApply()
                            let _ = textApply()
                            let _ = titleBadgeApply()
                            
                            strongSelf.titleNode.frame = titleFrame
                            strongSelf.textNode.frame = textFrame
                            
                            var titleLineWidth: CGFloat = 0.0
                            if let firstLine = titleLayout.linesRects().first {
                                titleLineWidth = firstLine.width
                            } else {
                                titleLineWidth = titleFrame.width
                            }
                            
                            let titleBadgePadding: CGFloat = 5.0
                            let titleBadgeSpacing: CGFloat = 5.0
                            let titleBadgeFrame = CGRect(origin: CGPoint(x: titleFrame.minX + titleLineWidth + titleBadgeSpacing + titleBadgePadding, y: floorToScreenPixels(titleFrame.midY - titleBadgeLayout.size.height / 2.0) - 1.0), size: titleBadgeLayout.size)
                            let badgeBackgroundFrame = titleBadgeFrame.insetBy(dx: -titleBadgePadding, dy: -1.0 + UIScreenPixel)
                            
                            strongSelf.titleBadgeLabel.frame = titleBadgeFrame
                            
                            let button: HighlightTrackingButtonNode
                            if let current = strongSelf.titleBadgeButton {
                                button = current
                                button.bounds = CGRect(origin: .zero, size: badgeBackgroundFrame.size)
                                animation.animator.updatePosition(layer: button.layer, position: badgeBackgroundFrame.center, completion: nil)
                            } else {
                                button = HighlightTrackingButtonNode()
                                button.addTarget(self, action: #selector(strongSelf.badgePressed), forControlEvents: .touchUpInside)
                                button.frame = badgeBackgroundFrame
                                button.highligthedChanged = { [weak self, weak button] highlighted in
                                    if let strongSelf = self, let button {
                                        if highlighted {
                                            button.layer.removeAnimation(forKey: "opacity")
                                            button.alpha = 0.4
                                            strongSelf.titleBadgeLabel.layer.removeAnimation(forKey: "opacity")
                                            strongSelf.titleBadgeLabel.alpha = 0.4
                                        } else {
                                            button.alpha = 1.0
                                            button.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                                            strongSelf.titleBadgeLabel.alpha = 1.0
                                            strongSelf.titleBadgeLabel.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                                        }
                                    }
                                }
                                strongSelf.titleBadgeButton = button
                                strongSelf.addSubnode(button)
                            }
                            
                            if themeUpdated || button.backgroundImage(for: .normal) == nil {
                                button.setBackgroundImage(generateFilledCircleImage(diameter: badgeBackgroundFrame.height, color: mainColor.withMultipliedAlpha(0.1))?.stretchableImage(withLeftCapWidth: Int(badgeBackgroundFrame.height / 2), topCapHeight: Int(badgeBackgroundFrame.height / 2)), for: .normal)
                            }
                            
                            let backgroundFrame = CGRect(origin: CGPoint(x: backgroundInsets.left, y: backgroundInsets.top), size: CGSize(width: boundingWidth - backgroundInsets.left - backgroundInsets.right, height: titleFrameWithoutInsets.height + textSpacing + textFrameWithoutInsets.height + textSpacing))
                            
                            strongSelf.backgroundView.frame = backgroundFrame
                            strongSelf.backgroundView.update(size: backgroundFrame.size, isTransparent: false, primaryColor: mainColor, secondaryColor: nil, thirdColor: nil, backgroundColor: nil, pattern: nil, patternTopRightPosition: nil, animation: .None)
                            
                            if let statusSizeAndApply = statusSizeAndApply {
                                strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: boundingWidth - layoutConstants.text.bubbleInsets.right - statusSizeAndApply.0.width, y: textFrameWithoutInsets.maxY), size: statusSizeAndApply.0)
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
