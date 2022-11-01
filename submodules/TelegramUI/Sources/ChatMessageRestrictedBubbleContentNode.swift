import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TextFormat

class ChatMessageRestrictedBubbleContentNode: ChatMessageBubbleContentNode {
    private let textNode: TextNode
    private let statusNode: ChatMessageDateAndStatusNode
    
    required init() {
        self.textNode = TextNode()
        self.statusNode = ChatMessageDateAndStatusNode()
        
        super.init()
        
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .topLeft
        self.textNode.contentsScale = UIScreenScale
        self.textNode.displaysAsynchronously = false
        self.addSubnode(self.textNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let textLayout = TextNode.asyncLayout(self.textNode)
        let statusLayout = self.statusNode.asyncLayout()
        
        return { item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let message = item.message
                
                let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                
                let maxTextWidth = CGFloat.greatestFiniteMagnitude
                
                let horizontalInset = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                let textConstrainedSize = CGSize(width: min(maxTextWidth, constrainedSize.width - horizontalInset), height: constrainedSize.height)
                
                var edited = false
                if item.attributes.updatingMedia != nil {
                    edited = true
                }
                var viewCount: Int?
                var rawText = ""
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
                    } else if let attribute = attribute as? RestrictedContentMessageAttribute {
                        rawText = attribute.platformText(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) ?? ""
                    } else if let attribute = attribute as? ReplyThreadMessageAttribute, case .peer = item.chatLocation {
                        if let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .group = channel.info {
                            dateReplies = Int(attribute.count)
                        }
                    }
                }
                
                let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings)
                
                let statusType: ChatMessageDateAndStatusType?
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
                
                let entities = [MessageTextEntity(range: 0..<rawText.count, type: .Italic)]
                
                let messageTheme = incoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
                
                let textFont = item.presentationData.messageFont
                
                let attributedText = stringWithAppliedEntities(rawText, entities: entities, baseColor: messageTheme.primaryTextColor.withAlphaComponent(0.7), linkColor: messageTheme.linkTextColor, baseFont: textFont, linkFont: textFont, boldFont: item.presentationData.messageBoldFont, italicFont: item.presentationData.messageItalicFont, boldItalicFont: item.presentationData.messageBoldItalicFont, fixedFont: item.presentationData.messageFixedFont, blockQuoteFont: item.presentationData.messageBlockQuoteFont, message: nil)
                
                let textInsets = UIEdgeInsets(top: 2.0, left: 0.0, bottom: 5.0, right: 0.0)
                
                let (textLayout, textApply) = textLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: textInsets, lineColor: messageTheme.accentControlColor))
                
                var textFrame = CGRect(origin: CGPoint(x: -textInsets.left, y: -textInsets.top), size: textLayout.size)
                var textFrameWithoutInsets = CGRect(origin: CGPoint(x: textFrame.origin.x + textInsets.left, y: textFrame.origin.y + textInsets.top), size: CGSize(width: textFrame.width - textInsets.left - textInsets.right, height: textFrame.height - textInsets.top - textInsets.bottom))
                
                textFrame = textFrame.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)
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
                        layoutInput: .trailingContent(contentWidth: textLayout.trailingLineWidth, reactionSettings: ChatMessageDateAndStatusNode.TrailingReactionSettings(displayInline: shouldDisplayInlineDateReactions(message: message, isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions), preferAdditionalInset: false)),
                        constrainedSize: textConstrainedSize,
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
                
                var suggestedBoundingWidth: CGFloat = textFrameWithoutInsets.width
                if let statusSuggestedWidthAndContinue = statusSuggestedWidthAndContinue {
                    suggestedBoundingWidth = max(suggestedBoundingWidth, statusSuggestedWidthAndContinue.0)
                }
                let sideInsets = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                suggestedBoundingWidth += sideInsets
                
                return (suggestedBoundingWidth, { boundingWidth in
                    var boundingSize: CGSize
                    
                    let statusSizeAndApply = statusSuggestedWidthAndContinue?.1(boundingWidth)
                    
                    boundingSize = textFrameWithoutInsets.size
                    if let statusSizeAndApply = statusSizeAndApply {
                        boundingSize.height += statusSizeAndApply.0.height
                    }
                    boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                    boundingSize.height += layoutConstants.text.bubbleInsets.top + layoutConstants.text.bubbleInsets.bottom
                    
                    return (boundingSize, { [weak self] animation, _, _ in
                        if let strongSelf = self {
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
                            
                            let _ = textApply()
                            
                            strongSelf.textNode.frame = textFrame
                            
                            if let statusSizeAndApply = statusSizeAndApply {
                                strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: textFrameWithoutInsets.maxX - statusSizeAndApply.0.width, y: textFrameWithoutInsets.maxY), size: statusSizeAndApply.0)
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
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.statusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
}
