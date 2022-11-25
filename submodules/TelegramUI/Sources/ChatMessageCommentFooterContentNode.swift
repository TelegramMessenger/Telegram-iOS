import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import RadialStatusNode
import AnimatedCountLabelNode
import AnimatedAvatarSetNode

final class ChatMessageCommentFooterContentNode: ChatMessageBubbleContentNode {
    private let separatorNode: ASDisplayNode
    private let countNode: AnimatedCountLabelNode
    private let alternativeCountNode: AnimatedCountLabelNode
    private let iconNode: ASImageNode
    private let arrowNode: ASImageNode
    private let buttonNode: HighlightTrackingButtonNode
    private let avatarsContext: AnimatedAvatarSetContext
    private let avatarsNode: AnimatedAvatarSetNode
    private let unreadIconNode: ASImageNode
    private var statusNode: RadialStatusNode?
    
    required init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isUserInteractionEnabled = false
        
        self.countNode = AnimatedCountLabelNode()
        self.alternativeCountNode = AnimatedCountLabelNode()
        
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
        
        self.avatarsContext = AnimatedAvatarSetContext()
        self.avatarsNode = AnimatedAvatarSetNode()
        self.avatarsNode.isUserInteractionEnabled = false
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        super.init()
        
        self.buttonNode.addSubnode(self.separatorNode)
        self.buttonNode.addSubnode(self.countNode)
        self.buttonNode.addSubnode(self.alternativeCountNode)
        self.buttonNode.addSubnode(self.iconNode)
        self.buttonNode.addSubnode(self.unreadIconNode)
        self.buttonNode.addSubnode(self.arrowNode)
        self.buttonNode.addSubnode(self.avatarsNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                let nodes: [ASDisplayNode] = [
                    strongSelf.buttonNode
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
            item.controllerInteraction.openMessageReplies(item.message.id, true, false)
        }
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeCountLayout = self.countNode.asyncLayout()
        let makeAlternativeCountLayout = self.alternativeCountNode.asyncLayout()
        
        return { item, layoutConstants, preparePosition, _, constrainedSize, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            let displaySeparator: Bool
            let topOffset: CGFloat
            let topSeparatorOffset: CGFloat
            if case let .linear(top, _) = preparePosition, case .Neighbour(_, .media, _) = top {
                displaySeparator = false
                topOffset = 2.0
                topSeparatorOffset = 0.0
            } else {
                displaySeparator = true
                topOffset = 2.0
                topSeparatorOffset = 2.0
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
                
                let messageTheme = incoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
                
                let textFont = Font.regular(17.0)
                
                let rawSegments: [AnimatedCountLabelNode.Segment]
                let rawAlternativeSegments: [AnimatedCountLabelNode.Segment]
                
                var accessibilityLabel = ""
                if item.message.id.peerId.isReplies {
                    rawSegments = [.text(100, NSAttributedString(string: item.presentationData.strings.Conversation_ViewReply, font: textFont, textColor: messageTheme.accentTextColor))]
                    rawAlternativeSegments = rawSegments
                    accessibilityLabel = item.presentationData.strings.Conversation_ViewReply
                } else if dateReplies > 0 {
                    var commentsPart = item.presentationData.strings.Conversation_MessageViewComments(Int32(dateReplies))
                    if commentsPart.contains("[") && commentsPart.contains("]") {
                        if let startIndex = commentsPart.firstIndex(of: "["), let endIndex = commentsPart.firstIndex(of: "]") {
                            commentsPart.removeSubrange(startIndex ... endIndex)
                        }
                    } else {
                        commentsPart = commentsPart.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789-,. "))
                    }
                    
                    var segments: [AnimatedCountLabelNode.Segment] = []
                    
                    let textAndRanges = item.presentationData.strings.Conversation_MessageViewCommentsFormat("\(dateReplies)", commentsPart)
                    let rawText = textAndRanges.string
                    var textIndex = 0
                    var latestIndex = 0
                    for indexAndRange in textAndRanges.ranges {
                        var lowerSegmentIndex = indexAndRange.range.lowerBound
                        if indexAndRange.index != 0 {
                            lowerSegmentIndex = min(lowerSegmentIndex, latestIndex)
                        } else {
                            if latestIndex < indexAndRange.range.lowerBound {
                                let part = String(rawText[rawText.index(rawText.startIndex, offsetBy: latestIndex) ..< rawText.index(rawText.startIndex, offsetBy: indexAndRange.range.lowerBound)])
                                segments.append(.text(textIndex, NSAttributedString(string: part, font: textFont, textColor: messageTheme.accentTextColor)))
                                textIndex += 1
                            }
                        }
                        latestIndex = indexAndRange.range.upperBound
                        
                        let part = String(rawText[rawText.index(rawText.startIndex, offsetBy: lowerSegmentIndex) ..< rawText.index(rawText.startIndex, offsetBy: min(rawText.count, indexAndRange.range.upperBound))])
                        if indexAndRange.index == 0 {
                            segments.append(.number(dateReplies, NSAttributedString(string: part, font: textFont, textColor: messageTheme.accentTextColor)))
                        } else {
                            segments.append(.text(textIndex, NSAttributedString(string: part, font: textFont, textColor: messageTheme.accentTextColor)))
                            textIndex += 1
                        }
                    }
                    if latestIndex < rawText.count {
                        let part = String(rawText[rawText.index(rawText.startIndex, offsetBy: latestIndex)...])
                        segments.append(.text(textIndex, NSAttributedString(string: part, font: textFont, textColor: messageTheme.accentTextColor)))
                        textIndex += 1
                    }
                    
                    rawSegments = segments
                    rawAlternativeSegments = rawSegments
                    accessibilityLabel = rawText
                } else {
                    rawSegments = [.text(100, NSAttributedString(string: item.presentationData.strings.Conversation_MessageLeaveComment, font: textFont, textColor: messageTheme.accentTextColor))]
                    rawAlternativeSegments = [.text(100, NSAttributedString(string: item.presentationData.strings.Conversation_MessageLeaveCommentShort, font: textFont, textColor: messageTheme.accentTextColor))]
                    accessibilityLabel = item.presentationData.strings.Conversation_MessageLeaveComment
                }
                
                let imageSize: CGFloat = 30.0
                let imageSpacing: CGFloat = 20.0
                
                var textLeftInset: CGFloat = 0.0
                if replyPeers.isEmpty {
                    textLeftInset = 41.0
                } else {
                    textLeftInset = 15.0 + imageSize * min(1.0, CGFloat(replyPeers.count)) + (imageSpacing) * max(0.0, min(2.0, CGFloat(replyPeers.count - 1)))
                }
                let textRightInset: CGFloat = 36.0
                
                let textConstrainedSize = CGSize(width: min(maxTextWidth, constrainedSize.width - horizontalInset - textLeftInset - textRightInset), height: constrainedSize.height)
                
                let textInsets = UIEdgeInsets()//(top: 2.0, left: 2.0, bottom: 5.0, right: 2.0)
                
                let (countLayout, countApply) = makeCountLayout(textConstrainedSize, rawSegments)
                let (alternativeCountLayout, alternativeCountApply) = makeAlternativeCountLayout(textConstrainedSize, rawAlternativeSegments)
                
                var textFrame = CGRect(origin: CGPoint(x: -textInsets.left + textLeftInset - 2.0, y: -textInsets.top + 5.0 + topOffset), size: countLayout.size)
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
                    
                    return (boundingSize, { [weak self] animation, synchronousLoad, _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            let transition: ContainedViewLayoutTransition
                            if animation.isAnimated {
                                transition = .animated(duration: 0.2, curve: .easeInOut)
                            } else {
                                transition = .immediate
                            }
                            
                            strongSelf.countNode.isHidden = countLayout.isTruncated
                            strongSelf.alternativeCountNode.isHidden = !strongSelf.countNode.isHidden
                            
                            strongSelf.buttonNode.accessibilityLabel = accessibilityLabel
                            
                            let _ = countApply(animation.isAnimated)
                            let _ = alternativeCountApply(animation.isAnimated)
                            
                            let adjustedTextFrame = textFrame
                            
                            if strongSelf.countNode.frame.isEmpty {
                                strongSelf.countNode.frame = adjustedTextFrame
                            } else {
                                transition.updateFrameAdditive(node: strongSelf.countNode, frame: adjustedTextFrame)
                            }
                            
                            if strongSelf.alternativeCountNode.frame.isEmpty {
                                strongSelf.alternativeCountNode.frame = CGRect(origin: adjustedTextFrame.origin, size: alternativeCountLayout.size)
                            } else {
                                transition.updateFrameAdditive(node: strongSelf.alternativeCountNode, frame: CGRect(origin: adjustedTextFrame.origin, size: alternativeCountLayout.size))
                            }
                            
                            let effectiveTextFrame: CGRect
                            if !strongSelf.alternativeCountNode.isHidden {
                                effectiveTextFrame = strongSelf.alternativeCountNode.frame
                            } else {
                                effectiveTextFrame = strongSelf.countNode.frame
                            }
                            
                            if let iconImage = iconImage {
                                strongSelf.iconNode.image = iconImage
                                strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: 15.0 + iconOffset.x, y: 6.0 + iconOffset.y + topOffset), size: iconImage.size)
                            }

                            if let arrowImage = arrowImage {
                                strongSelf.arrowNode.image = arrowImage
                                let arrowFrame = CGRect(origin: CGPoint(x: boundingWidth - 33.0, y: 6.0 + topOffset), size: arrowImage.size)
                                if strongSelf.arrowNode.frame.isEmpty {
                                    strongSelf.arrowNode.frame = arrowFrame
                                } else {
                                    transition.updateFrameAdditive(node: strongSelf.arrowNode, frame: arrowFrame)
                                }
                                
                                if let unreadIconImage = unreadIconImage {
                                    strongSelf.unreadIconNode.image = unreadIconImage
                                    
                                    let unreadIconFrame = CGRect(origin: CGPoint(x: effectiveTextFrame.maxX + 4.0, y: effectiveTextFrame.minY + floor((effectiveTextFrame.height - unreadIconImage.size.height) / 2.0) + 1.0), size: unreadIconImage.size)
                                    
                                    if strongSelf.unreadIconNode.frame.isEmpty {
                                        strongSelf.unreadIconNode.frame = unreadIconFrame
                                    } else {
                                        transition.updateFrameAdditive(node: strongSelf.unreadIconNode, frame: unreadIconFrame)
                                    }
                                }
                            }
                            
                            if strongSelf.unreadIconNode.alpha.isZero != !hasUnseenReplies {
                                transition.updateAlpha(node: strongSelf.unreadIconNode, alpha: hasUnseenReplies ? 1.0 : 0.0)
                                if hasUnseenReplies {
                                    strongSelf.unreadIconNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5, initialVelocity: 0.0)
                                }
                            }
                            
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
                                let statusFrame = CGRect(origin: CGPoint(x: boundingWidth - statusSize.width - 11.0, y: 8.0 + topOffset), size: statusSize)
                                
                                if statusNode.frame.isEmpty {
                                    statusNode.frame = statusFrame
                                } else {
                                    transition.updateFrameAdditive(node: statusNode, frame: statusFrame)
                                }
                                
                                statusNode.transitionToState(.progress(color: messageTheme.accentTextColor, lineWidth: 1.5, value: nil, cancelEnabled: false, animateRotation: true), animated: false, synchronous: false, completion: {})
                            } else {
                                strongSelf.arrowNode.isHidden = false
                                if let statusNode = strongSelf.statusNode {
                                    strongSelf.statusNode = nil
                                    statusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: 0.3, removeOnCompletion: false, completion: { [weak statusNode] _ in
                                        statusNode?.removeFromSupernode()
                                    })
                                    strongSelf.arrowNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: 0.3)
                                }
                            }
                            
                            let avatarContent = strongSelf.avatarsContext.update(peers: replyPeers.map(EnginePeer.init), animated: animation.isAnimated)
                            let avatarsSize = strongSelf.avatarsNode.update(context: item.context, content: avatarContent, animated: animation.isAnimated, synchronousLoad: synchronousLoad)
                            
                            let iconAlpha: CGFloat = avatarsSize.width.isZero ? 1.0 : 0.0
                            if iconAlpha.isZero != strongSelf.iconNode.alpha.isZero {
                                transition.updateAlpha(node: strongSelf.iconNode, alpha: iconAlpha)
                                if animation.isAnimated {
                                    if iconAlpha.isZero {
                                    } else {
                                        strongSelf.iconNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                                    }
                                }
                            }
                            
                            let avatarsFrame = CGRect(origin: CGPoint(x: 13.0, y: 3.0 + topOffset), size: avatarsSize)
                            strongSelf.avatarsNode.frame = avatarsFrame
                            //strongSelf.avatarsNode.updateLayout(size: avatarsFrame.size)
                            //strongSelf.avatarsNode.update(context: item.context, peers: replyPeers, synchronousLoad: synchronousLoad, imageSize: imageSize, imageSpacing: imageSpacing, borderWidth: 2.0 - UIScreenPixel)
                            
                            strongSelf.separatorNode.backgroundColor = messageTheme.polls.separator
                            strongSelf.separatorNode.isHidden = !displaySeparator
                            strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: layoutConstants.bubble.strokeInsets.left, y: -3.0 + topSeparatorOffset), size: CGSize(width: boundingWidth - layoutConstants.bubble.strokeInsets.left - layoutConstants.bubble.strokeInsets.right, height: UIScreenPixel))
                            
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
