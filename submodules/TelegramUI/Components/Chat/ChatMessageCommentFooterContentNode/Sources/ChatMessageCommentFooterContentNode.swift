import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import RadialStatusNode
import AnimatedCountLabelNode
import AnimatedAvatarSetNode
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import StaticGlassBackground

public final class ChatMessageCommentFooterContentNode: ChatMessageBubbleContentNode {
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
    
    // Bubble mode off: the row is a capsule captured from glass, like a bot's button, its content in the text colour:
    // plain UIKit views in the capsule's content view.
    private var glassView: StaticGlassBackgroundView?
    private var glassControl: UIControl?
    private var glassAvatarsView: AnimatedAvatarSetView?
    private var glassIconView: UIImageView?
    private var glassTextLabel: UILabel?
    private var glassUnreadView: UIImageView?
    private var glassArrowView: UIImageView?
    
    required public init() {
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
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func glassControlPressed() {
        self.buttonPressed()
    }
    
    // The capsule dims under the finger as the row does with bubbles.
    @objc private func glassControlHighlighted() {
        guard let glassView = self.glassView else {
            return
        }
        glassView.layer.removeAnimation(forKey: "opacity")
        glassView.alpha = 0.4
    }
    
    @objc private func glassControlUnhighlighted() {
        guard let glassView = self.glassView, glassView.alpha < 1.0 else {
            return
        }
        glassView.alpha = 1.0
        glassView.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
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
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeCountLayout = self.countNode.asyncLayout()
        let makeAlternativeCountLayout = self.alternativeCountNode.asyncLayout()
        
        return { [weak self] item, layoutConstants, preparePosition, _, constrainedSize, _ in
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
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { [weak self] constrainedSize, position in
                let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                
                let maxTextWidth = CGFloat.greatestFiniteMagnitude
                
                let horizontalInset = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                
                var dateReplies = 0
                var replyPeers: [EnginePeer] = []
                var hasUnseenReplies = false
                for attribute in item.message.attributes {
                    if let attribute = attribute as? ReplyThreadMessageAttribute {
                        dateReplies = Int(attribute.count)
                        replyPeers = attribute.latestUsers.compactMap { peerId -> EnginePeer? in
                            return item.message.peers[peerId].flatMap(EnginePeer.init)
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
                let textRightInset: CGFloat = 24.0
                
                let textConstrainedSize = CGSize(width: min(maxTextWidth, constrainedSize.width - horizontalInset - textLeftInset - textRightInset), height: constrainedSize.height)
                
                let textInsets = UIEdgeInsets()//(top: 2.0, left: 2.0, bottom: 5.0, right: 2.0)
                
                let (countLayout, countApply) = makeCountLayout(textConstrainedSize, .zero, rawSegments)
                let (alternativeCountLayout, alternativeCountApply) = makeAlternativeCountLayout(textConstrainedSize, .zero, rawAlternativeSegments)
                
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
                
                // Bubble mode off: a glass capsule 6pt under the content, as wide as the content, its text in the text
                // colour (the short form when the long one does not fit).
                let isGlass = item.bubbleStyle.isBubbleless
                var glassLayout: ChatMessageBubblelessCommentsCapsuleLayout?
                var glassAttributedText: NSAttributedString?
                var glassTextSize = CGSize()
                var glassIconImage: UIImage?
                var glassArrowImage: UIImage?
                if isGlass {
                    // The glyphs take the content colour as templates, with no tinted copies drawn for every post.
                    glassIconImage = iconImage?.withRenderingMode(.alwaysTemplate)
                    glassArrowImage = arrowImage?.withRenderingMode(.alwaysTemplate)
                    let unreadWidth: CGFloat = hasUnseenReplies ? 4.0 + (unreadIconImage?.size.width ?? 0.0) : 0.0
                    let layout = chatMessageBubblelessCommentsCapsuleLayout(avatarCount: replyPeers.count, iconWidth: glassIconImage?.size.width ?? 0.0, arrowWidth: glassArrowImage?.size.width ?? 0.0, unreadWidth: unreadWidth, constrainedWidth: constrainedSize.width)
                    var text = NSAttributedString(string: accessibilityLabel, font: textFont, textColor: messageTheme.primaryTextColor)
                    var textSize = text.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil).size
                    if textSize.width > layout.textMaxWidth, rawAlternativeSegments.count == 1, case let .text(_, shortText) = rawAlternativeSegments[0] {
                        text = NSAttributedString(string: shortText.string, font: textFont, textColor: messageTheme.primaryTextColor)
                        textSize = text.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil).size
                    }
                    glassTextSize = CGSize(width: min(layout.textMaxWidth, ceil(textSize.width)), height: ceil(textSize.height))
                    glassAttributedText = text
                    glassLayout = layout
                    suggestedBoundingWidth = layout.leading + glassTextSize.width + unreadWidth + layout.trailing
                }
                
                return (suggestedBoundingWidth, { [weak self] boundingWidth in
                    var boundingSize: CGSize
                    
                    boundingSize = textFrameWithoutInsets.size
                    boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                    boundingSize.height = 40.0 + topOffset
                    if isGlass {
                        boundingSize = CGSize(width: boundingWidth, height: chatMessageBubblelessGlassCapsuleSpacing + chatMessageBubblelessGlassCapsuleHeight)
                    }
                    
                    return (boundingSize, { [weak self] animation, synchronousLoad, _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            if isGlass, let glassLayout, let glassAttributedText {
                                let capsuleFrame = CGRect(x: 0.0, y: chatMessageBubblelessGlassCapsuleSpacing, width: boundingWidth, height: chatMessageBubblelessGlassCapsuleHeight)
                                strongSelf.applyGlass(item: item, capsuleFrame: capsuleFrame, contentColor: messageTheme.primaryTextColor, attributedText: glassAttributedText, textSize: glassTextSize, leading: glassLayout.leading, iconImage: glassIconImage, arrowImage: glassArrowImage, unreadIconImage: unreadIconImage, hasUnseenReplies: hasUnseenReplies, replyPeers: replyPeers, accessibilityLabel: accessibilityLabel, animation: animation, synchronousLoad: synchronousLoad)
                                return
                            }
                            if strongSelf.glassView != nil {
                                strongSelf.removeGlass()
                            }
                            
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
                            
                            let avatarContent = strongSelf.avatarsContext.update(peers: replyPeers, animated: animation.isAnimated)
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
    
    /// Bubble mode off: the row as a capsule captured from glass, like a bot's button, its content in the text colour;
    /// the button node that draws it with bubbles stays hidden.
    private func applyGlass(item: ChatMessageBubbleContentItem, capsuleFrame: CGRect, contentColor: UIColor, attributedText: NSAttributedString, textSize: CGSize, leading: CGFloat, iconImage: UIImage?, arrowImage: UIImage?, unreadIconImage: UIImage?, hasUnseenReplies: Bool, replyPeers: [EnginePeer], accessibilityLabel: String, animation: ListViewItemUpdateAnimation, synchronousLoad: Bool) {
        let height = capsuleFrame.height
        let isEnabled = item.message.id.namespace == Namespaces.Message.Cloud
        let contentAlpha: CGFloat = isEnabled ? 1.0 : 0.5
        self.buttonNode.isHidden = true
        
        let glassView: StaticGlassBackgroundView
        let glassControl: UIControl
        // A capsule made in this pass appears in place rather than growing from nothing.
        var glassAnimation = animation
        if let currentGlassView = self.glassView, let currentControl = self.glassControl {
            glassView = currentGlassView
            glassControl = currentControl
            animation.animator.updateFrame(layer: glassView.layer, frame: capsuleFrame, completion: nil)
        } else {
            glassAnimation = .None
            glassView = StaticGlassBackgroundView()
            glassView.frame = capsuleFrame
            self.glassView = glassView
            self.view.insertSubview(glassView, at: 0)
            
            glassControl = UIControl()
            glassControl.addTarget(self, action: #selector(self.glassControlPressed), for: .touchUpInside)
            glassControl.addTarget(self, action: #selector(self.glassControlHighlighted), for: [.touchDown, .touchDragEnter])
            glassControl.addTarget(self, action: #selector(self.glassControlUnhighlighted), for: [.touchUpInside, .touchUpOutside, .touchDragExit, .touchCancel])
            // VoiceOver keeps the row's button ("Leave a comment", "N comments").
            glassControl.isAccessibilityElement = true
            glassControl.accessibilityTraits = .button
            self.glassControl = glassControl
            glassView.contentView.addSubview(glassControl)
        }
        glassView.update(size: capsuleFrame.size, cornerRadius: height * 0.5, isDark: item.presentationData.theme.theme.overallDarkAppearance, tint: .panel, updateFrame: { view, frame in
            glassAnimation.animator.updateFrame(layer: view.layer, frame: frame, completion: nil)
        })
        glassControl.isEnabled = isEnabled
        glassControl.frame = CGRect(origin: CGPoint(), size: capsuleFrame.size)
        glassControl.accessibilityLabel = accessibilityLabel
        
        func makeImageView() -> UIImageView {
            let imageView = UIImageView()
            imageView.isUserInteractionEnabled = false
            glassView.contentView.insertSubview(imageView, belowSubview: glassControl)
            return imageView
        }
        
        if !replyPeers.isEmpty {
            let avatarsView: AnimatedAvatarSetView
            if let current = self.glassAvatarsView {
                avatarsView = current
            } else {
                avatarsView = AnimatedAvatarSetView()
                avatarsView.isUserInteractionEnabled = false
                self.glassAvatarsView = avatarsView
                glassView.contentView.insertSubview(avatarsView, belowSubview: glassControl)
            }
            let avatarContent = self.avatarsContext.update(peers: replyPeers, animated: animation.isAnimated)
            let avatarsSize = avatarsView.update(context: item.context, content: avatarContent, itemSize: CGSize(width: 30.0, height: 30.0), animation: animation, synchronousLoad: synchronousLoad)
            avatarsView.frame = CGRect(origin: CGPoint(x: 6.0, y: floorToScreenPixels((height - avatarsSize.height) * 0.5)), size: avatarsSize)
            avatarsView.alpha = contentAlpha
        } else if let avatarsView = self.glassAvatarsView {
            self.glassAvatarsView = nil
            avatarsView.removeFromSuperview()
        }
        
        if replyPeers.isEmpty, let iconImage {
            let iconView = self.glassIconView ?? makeImageView()
            self.glassIconView = iconView
            iconView.image = iconImage
            iconView.tintColor = contentColor
            iconView.frame = CGRect(origin: CGPoint(x: 12.0, y: floorToScreenPixels((height - iconImage.size.height) * 0.5)), size: iconImage.size)
            iconView.alpha = contentAlpha
        } else if let iconView = self.glassIconView {
            self.glassIconView = nil
            iconView.removeFromSuperview()
        }
        
        let textLabel: UILabel
        if let current = self.glassTextLabel {
            textLabel = current
        } else {
            textLabel = UILabel()
            textLabel.isUserInteractionEnabled = false
            textLabel.lineBreakMode = .byTruncatingTail
            // The control is the VoiceOver element, with the same words.
            textLabel.isAccessibilityElement = false
            self.glassTextLabel = textLabel
            glassView.contentView.insertSubview(textLabel, belowSubview: glassControl)
        }
        // The label draws on the main thread: only when its text changes.
        if textLabel.attributedText != attributedText {
            textLabel.attributedText = attributedText
        }
        let textFrame = CGRect(origin: CGPoint(x: leading, y: floorToScreenPixels((height - textSize.height) * 0.5)), size: textSize)
        textLabel.frame = textFrame
        textLabel.alpha = contentAlpha
        
        if hasUnseenReplies, let unreadIconImage {
            let unreadView = self.glassUnreadView ?? makeImageView()
            self.glassUnreadView = unreadView
            unreadView.image = unreadIconImage
            unreadView.frame = CGRect(origin: CGPoint(x: textFrame.maxX + 4.0, y: floorToScreenPixels(textFrame.midY - unreadIconImage.size.height * 0.5)), size: unreadIconImage.size)
            unreadView.alpha = contentAlpha
        } else if let unreadView = self.glassUnreadView {
            self.glassUnreadView = nil
            unreadView.removeFromSuperview()
        }
        
        let hasActivity = item.controllerInteraction.currentMessageWithLoadingReplyThread == item.message.id
        var arrowFrame = CGRect()
        if let arrowImage {
            let arrowView = self.glassArrowView ?? makeImageView()
            self.glassArrowView = arrowView
            arrowView.image = arrowImage
            arrowView.tintColor = contentColor
            arrowFrame = CGRect(origin: CGPoint(x: capsuleFrame.width - 14.0 - arrowImage.size.width, y: floorToScreenPixels((height - arrowImage.size.height) * 0.5)), size: arrowImage.size)
            arrowView.frame = arrowFrame
            arrowView.alpha = hasActivity ? 0.0 : contentAlpha
        }
        
        // The spinner of a thread being opened takes the chevron's place.
        if hasActivity {
            let statusNode: RadialStatusNode
            if let current = self.statusNode {
                statusNode = current
            } else {
                statusNode = RadialStatusNode(backgroundNodeColor: .clear)
                self.statusNode = statusNode
            }
            if statusNode.supernode !== self {
                self.addSubnode(statusNode)
            }
            statusNode.frame = CGRect(origin: CGPoint(x: capsuleFrame.minX + arrowFrame.midX - 10.0, y: capsuleFrame.minY + floorToScreenPixels((height - 20.0) * 0.5)), size: CGSize(width: 20.0, height: 20.0))
            statusNode.transitionToState(.progress(color: contentColor, lineWidth: 1.5, value: nil, cancelEnabled: false, animateRotation: true), animated: false, synchronous: false, completion: {})
        } else if let statusNode = self.statusNode {
            self.statusNode = nil
            statusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: 0.3, removeOnCompletion: false, completion: { [weak statusNode] _ in
                statusNode?.removeFromSupernode()
            })
            self.glassArrowView?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: 0.3)
        }
    }
    
    private func removeGlass() {
        guard let glassView = self.glassView else {
            return
        }
        self.glassView = nil
        self.glassControl = nil
        self.glassAvatarsView = nil
        self.glassIconView = nil
        self.glassTextLabel = nil
        self.glassUnreadView = nil
        self.glassArrowView = nil
        glassView.removeFromSuperview()
        self.buttonNode.isHidden = false
        if let statusNode = self.statusNode, statusNode.supernode !== self.buttonNode {
            self.buttonNode.addSubnode(statusNode)
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
    }
    
    override public func animateInsertionIntoBubble(_ duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if let glassView = self.glassView {
            if glassView.frame.contains(point) {
                return ChatMessageBubbleContentTapAction(content: .ignore)
            }
            return ChatMessageBubbleContentTapAction(content: .none)
        }
        if self.buttonNode.frame.contains(point) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        return ChatMessageBubbleContentTapAction(content: .none)
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let glassView = self.glassView, let glassControl = self.glassControl {
            if glassControl.isEnabled && glassView.frame.contains(point) {
                return glassControl
            }
            return nil
        }
        if self.buttonNode.isUserInteractionEnabled && self.buttonNode.frame.contains(point) {
            return self.buttonNode.view
        }
        return nil
    }
}
