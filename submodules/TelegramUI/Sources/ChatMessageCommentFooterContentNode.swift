import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import TelegramPresentationData
import RadialStatusNode

final class ChatMessageCommentFooterContentNode: ChatMessageBubbleContentNode {
    private let separatorNode: ASDisplayNode
    private let textNode: TextNode
    private let alternativeTextNode: TextNode
    private let iconNode: ASImageNode
    private let arrowNode: ASImageNode
    private let buttonNode: HighlightTrackingButtonNode
    private let avatarsNode: MergedAvatarsNode
    private let unreadIconNode: ASImageNode
    private var statusNode: RadialStatusNode?
    
    required init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isUserInteractionEnabled = false
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .topLeft
        self.textNode.contentsScale = UIScreenScale
        self.textNode.displaysAsynchronously = true
        
        self.alternativeTextNode = TextNode()
        self.alternativeTextNode.isUserInteractionEnabled = false
        self.alternativeTextNode.contentMode = .topLeft
        self.alternativeTextNode.contentsScale = UIScreenScale
        self.alternativeTextNode.displaysAsynchronously = true
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.isUserInteractionEnabled = false
        
        self.unreadIconNode = ASImageNode()
        self.unreadIconNode.displaysAsynchronously = false
        self.unreadIconNode.displayWithoutProcessing = true
        self.unreadIconNode.isUserInteractionEnabled = false
        
        self.arrowNode = ASImageNode()
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.isUserInteractionEnabled = false
        
        self.avatarsNode = MergedAvatarsNode()
        self.avatarsNode.isUserInteractionEnabled = false
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        super.init()
        
        self.buttonNode.addSubnode(self.separatorNode)
        self.buttonNode.addSubnode(self.textNode)
        self.buttonNode.addSubnode(self.alternativeTextNode)
        self.buttonNode.addSubnode(self.iconNode)
        self.buttonNode.addSubnode(self.unreadIconNode)
        self.buttonNode.addSubnode(self.arrowNode)
        self.buttonNode.addSubnode(self.avatarsNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                let nodes: [ASDisplayNode] = [
                    strongSelf.textNode,
                    strongSelf.alternativeTextNode,
                    strongSelf.iconNode,
                    strongSelf.avatarsNode,
                    strongSelf.unreadIconNode,
                    strongSelf.arrowNode,
                ]
                for node in nodes {
                    if highlighted {
                        node.layer.removeAnimation(forKey: "opacity")
                        node.alpha = 0.4
                    } else {
                        node.alpha = 1.0
                        node.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    }
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
        if item.message.id.peerId.isReplies {
            item.controllerInteraction.openReplyThreadOriginalMessage(item.message)
        } else {
            item.controllerInteraction.openMessageReplies(item.message.id, true)
        }
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> Void))) {
        let textLayout = TextNode.asyncLayout(self.textNode)
        let alternativeTextLayout = TextNode.asyncLayout(self.alternativeTextNode)
        
        return { item, layoutConstants, preparePosition, _, constrainedSize in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            let displaySeparator: Bool
            let topOffset: CGFloat
            if case let .linear(top, _) = preparePosition, case .Neighbour(_, .media) = top {
                displaySeparator = false
                topOffset = 2.0
            } else {
                displaySeparator = true
                topOffset = 0.0
            }
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                
                let maxTextWidth = CGFloat.greatestFiniteMagnitude
                
                let horizontalInset = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                
                var dateReplies = 0
                var replyPeers: [Peer] = []
                var hasUnseenReplies = false
                for attribute in item.message.attributes {
                    if let attribute = attribute as? ReplyThreadMessageAttribute {
                        dateReplies = Int(attribute.count)
                        replyPeers = attribute.latestUsers.compactMap { peerId -> Peer? in
                            return item.message.peers[peerId]
                        }
                        if let maxMessageId = attribute.maxMessageId, let maxReadMessageId = attribute.maxReadMessageId {
                            hasUnseenReplies = maxMessageId > maxReadMessageId
                        }
                    }
                }
                
                let rawText: String
                let rawAlternativeText: String
                
                if item.message.id.peerId.isReplies {
                    rawText = item.presentationData.strings.Conversation_ViewReply
                    rawAlternativeText = rawText
                } else if dateReplies > 0 {
                    rawText = item.presentationData.strings.Conversation_MessageViewComments(Int32(dateReplies))
                    rawAlternativeText = rawText
                } else {
                    rawText = item.presentationData.strings.Conversation_MessageLeaveComment
                    rawAlternativeText = item.presentationData.strings.Conversation_MessageLeaveCommentShort
                }
                
                let imageSize: CGFloat = 30.0
                let imageSpacing: CGFloat = 20.0
                
                var textLeftInset: CGFloat = 0.0
                if replyPeers.isEmpty {
                    textLeftInset = 41.0
                } else {
                    textLeftInset = 15.0 + imageSize * min(1.0, CGFloat(replyPeers.count)) + (imageSpacing) * max(0.0, min(2.0, CGFloat(replyPeers.count - 1)))
                }
                let textRightInset: CGFloat = 33.0
                
                let textConstrainedSize = CGSize(width: min(maxTextWidth, constrainedSize.width - horizontalInset - textLeftInset - textRightInset), height: constrainedSize.height)
                
                let messageTheme = incoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
                
                let textFont = item.presentationData.messageFont
                
                let attributedText = NSAttributedString(string: rawText, font: textFont, textColor: messageTheme.accentTextColor)
                let alternativeAttributedText = NSAttributedString(string: rawAlternativeText, font: textFont, textColor: messageTheme.accentTextColor)
                
                let textInsets = UIEdgeInsets(top: 2.0, left: 2.0, bottom: 5.0, right: 2.0)
                
                let (textLayout, textApply) = textLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: textInsets, lineColor: messageTheme.accentControlColor))
                let (alternativeTextLayout, alternativeTextApply) = alternativeTextLayout(TextNodeLayoutArguments(attributedString: alternativeAttributedText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: textInsets, lineColor: messageTheme.accentControlColor))
                
                var textFrame = CGRect(origin: CGPoint(x: -textInsets.left + textLeftInset, y: -textInsets.top + 5.0 + topOffset), size: textLayout.size)
                var textFrameWithoutInsets = CGRect(origin: CGPoint(x: textFrame.origin.x + textInsets.left, y: textFrame.origin.y + textInsets.top), size: CGSize(width: textFrame.width - textInsets.left - textInsets.right, height: textFrame.height - textInsets.top - textInsets.bottom))
                
                textFrame = textFrame.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top - 5.0 + UIScreenPixel)
                textFrameWithoutInsets = textFrameWithoutInsets.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)

                var suggestedBoundingWidth: CGFloat
                suggestedBoundingWidth = textFrameWithoutInsets.width
                suggestedBoundingWidth += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right + textLeftInset + textRightInset
                
                let iconImage: UIImage?
                let iconOffset: CGPoint
                if item.message.id.peerId.isReplies {
                    iconImage = PresentationResourcesChat.chatMessageRepliesIcon(item.presentationData.theme.theme, incoming: incoming)
                    iconOffset = CGPoint(x: -4.0, y: -4.0)
                } else {
                    iconImage = PresentationResourcesChat.chatMessageCommentsIcon(item.presentationData.theme.theme, incoming: incoming)
                    iconOffset = CGPoint(x: 0.0, y: -1.0)
                }
                let arrowImage = PresentationResourcesChat.chatMessageCommentsArrowIcon(item.presentationData.theme.theme, incoming: incoming)
                let unreadIconImage = PresentationResourcesChat.chatMessageCommentsUnreadDotIcon(item.presentationData.theme.theme, incoming: incoming)
                
                return (suggestedBoundingWidth, { boundingWidth in
                    var boundingSize: CGSize
                    
                    boundingSize = textFrameWithoutInsets.size
                    boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                    boundingSize.height = 40.0 + topOffset
                    
                    return (boundingSize, { [weak self] animation, synchronousLoad in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            strongSelf.textNode.displaysAsynchronously = !item.presentationData.isPreview
                            strongSelf.alternativeTextNode.displaysAsynchronously = !item.presentationData.isPreview
                            
                            strongSelf.textNode.isHidden = textLayout.truncated
                            strongSelf.alternativeTextNode.isHidden = !strongSelf.textNode.isHidden
                            
                            let _ = textApply()
                            let _ = alternativeTextApply()
                            
                            let adjustedTextFrame = textFrame
                            
                            strongSelf.textNode.frame = adjustedTextFrame
                            strongSelf.alternativeTextNode.frame = CGRect(origin: adjustedTextFrame.origin, size: alternativeTextLayout.size)
                            
                            let effectiveTextFrame: CGRect
                            if !strongSelf.alternativeTextNode.isHidden {
                                effectiveTextFrame = strongSelf.alternativeTextNode.frame
                            } else {
                                effectiveTextFrame = strongSelf.textNode.frame
                            }
                            
                            if let iconImage = iconImage {
                                strongSelf.iconNode.image = iconImage
                                strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: 15.0 + iconOffset.x, y: 6.0 + iconOffset.y + topOffset), size: iconImage.size)
                            }

                            if let arrowImage = arrowImage {
                                strongSelf.arrowNode.image = arrowImage
                                let arrowFrame = CGRect(origin: CGPoint(x: boundingWidth - 33.0, y: 6.0 + topOffset), size: arrowImage.size)
                                strongSelf.arrowNode.frame = arrowFrame
                                
                                if let unreadIconImage = unreadIconImage {
                                    strongSelf.unreadIconNode.image = unreadIconImage
                                    strongSelf.unreadIconNode.frame = CGRect(origin: CGPoint(x: effectiveTextFrame.maxX + 4.0, y: effectiveTextFrame.minY + floor((effectiveTextFrame.height - unreadIconImage.size.height) / 2.0) - 1.0), size: unreadIconImage.size)
                                }
                            }
                            
                            strongSelf.unreadIconNode.isHidden = !hasUnseenReplies

                            strongSelf.iconNode.isHidden = !replyPeers.isEmpty
                            
                            let hasActivity = item.controllerInteraction.currentMessageWithLoadingReplyThread == item.message.id
                            
                            if hasActivity {
                                strongSelf.arrowNode.isHidden = true
                                let statusNode: RadialStatusNode
                                if let current = strongSelf.statusNode {
                                    statusNode = current
                                } else {
                                    statusNode = RadialStatusNode(backgroundNodeColor: .clear)
                                    strongSelf.statusNode = statusNode
                                    strongSelf.buttonNode.addSubnode(statusNode)
                                }
                                let statusSize = CGSize(width: 20.0, height: 20.0)
                                statusNode.frame = CGRect(origin: CGPoint(x: boundingWidth - statusSize.width - 11.0, y: 8.0 + topOffset), size: statusSize)
                                statusNode.transitionToState(.progress(color: messageTheme.accentTextColor, lineWidth: 1.5, value: nil, cancelEnabled: false), animated: false, synchronous: false, completion: {})
                            } else {
                                strongSelf.arrowNode.isHidden = false
                                if let statusNode = strongSelf.statusNode {
                                    strongSelf.statusNode = nil
                                    statusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak statusNode] _ in
                                        statusNode?.removeFromSupernode()
                                    })
                                    strongSelf.arrowNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                }
                            }
                            
                            let avatarsFrame = CGRect(origin: CGPoint(x: 13.0, y: 3.0 + topOffset), size: CGSize(width: imageSize * 3.0, height: imageSize))
                            strongSelf.avatarsNode.frame = avatarsFrame
                            strongSelf.avatarsNode.updateLayout(size: avatarsFrame.size)
                            strongSelf.avatarsNode.update(context: item.context, peers: replyPeers, synchronousLoad: synchronousLoad, imageSize: imageSize, imageSpacing: imageSpacing, borderWidth: 2.0 - UIScreenPixel)
                            
                            strongSelf.separatorNode.backgroundColor = messageTheme.polls.separator
                            strongSelf.separatorNode.isHidden = !displaySeparator
                            strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: layoutConstants.bubble.strokeInsets.left, y: -3.0), size: CGSize(width: boundingWidth - layoutConstants.bubble.strokeInsets.left - layoutConstants.bubble.strokeInsets.right, height: UIScreenPixel))
                            
                            strongSelf.buttonNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: boundingWidth, height: boundingSize.height))
                            
                            strongSelf.buttonNode.isUserInteractionEnabled = item.message.id.namespace == Namespaces.Message.Cloud
                            strongSelf.buttonNode.alpha = item.message.id.namespace == Namespaces.Message.Cloud ? 1.0 : 0.5
                        }
                    })
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
    }
    
    override func animateInsertionIntoBubble(_ duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.buttonNode.frame.contains(point) {
            return .ignore
        }
        return .none
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.buttonNode.isUserInteractionEnabled && self.buttonNode.frame.contains(point) {
            return self.buttonNode.view
        }
        return nil
    }
}




