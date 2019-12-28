import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import SyncCore
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
        self.textNode.displaysAsynchronously = true
        self.addSubnode(self.textNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> Void))) {
        let textLayout = TextNode.asyncLayout(self.textNode)
        let statusLayout = self.statusNode.asyncLayout()
        
        return { item, layoutConstants, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let message = item.message
                
                let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                
                let maxTextWidth = CGFloat.greatestFiniteMagnitude
                
                let horizontalInset = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                let textConstrainedSize = CGSize(width: min(maxTextWidth, constrainedSize.width - horizontalInset), height: constrainedSize.height)
                
                var edited = false
                var viewCount: Int?
                var rawText = ""
                for attribute in item.message.attributes {
                    if let attribute = attribute as? EditedMessageAttribute {
                        edited = !attribute.isHidden
                    } else if let attribute = attribute as? ViewCountMessageAttribute {
                        viewCount = attribute.count
                    } else if let attribute = attribute as? RestrictedContentMessageAttribute {
                        rawText = attribute.platformText(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) ?? ""
                    }
                }
                
                var dateReactions: [MessageReaction] = []
                var dateReactionCount = 0
                if let reactionsAttribute = mergedMessageReactions(attributes: item.message.attributes), !reactionsAttribute.reactions.isEmpty {
                    for reaction in reactionsAttribute.reactions {
                        if reaction.isSelected {
                            dateReactions.insert(reaction, at: 0)
                        } else {
                            dateReactions.append(reaction)
                        }
                        dateReactionCount += Int(reaction.count)
                    }
                }
                
                let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, reactionCount: dateReactionCount)
                
                let statusType: ChatMessageDateAndStatusType?
                switch position {
                case .linear(_, .None):
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
                
                var statusSize: CGSize?
                var statusApply: ((Bool) -> Void)?
                
                if let statusType = statusType {
                    let (size, apply) = statusLayout(item.context, item.presentationData, edited, viewCount, dateText, statusType, textConstrainedSize, dateReactions)
                    statusSize = size
                    statusApply = apply
                }
                
                let entities = [MessageTextEntity(range: 0..<rawText.count, type: .Italic)]
                
                let messageTheme = incoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
                
                let textFont = item.presentationData.messageFont
                let forceStatusNewline = false
                
                let attributedText = stringWithAppliedEntities(rawText, entities: entities, baseColor: messageTheme.primaryTextColor.withAlphaComponent(0.7), linkColor: messageTheme.linkTextColor, baseFont: textFont, linkFont: textFont, boldFont: item.presentationData.messageBoldFont, italicFont: item.presentationData.messageItalicFont, boldItalicFont: item.presentationData.messageBoldItalicFont, fixedFont: item.presentationData.messageFixedFont, blockQuoteFont: item.presentationData.messageBlockQuoteFont)
                
                var cutout: TextNodeCutout?
                if let statusSize = statusSize, !forceStatusNewline {
                    cutout = TextNodeCutout(bottomRight: statusSize)
                }
                
                let textInsets = UIEdgeInsets(top: 2.0, left: 0.0, bottom: 5.0, right: 0.0)
                
                let (textLayout, textApply) = textLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: cutout, insets: textInsets, lineColor: messageTheme.accentControlColor))
                
                var textFrame = CGRect(origin: CGPoint(x: -textInsets.left, y: -textInsets.top), size: textLayout.size)
                var textFrameWithoutInsets = CGRect(origin: CGPoint(x: textFrame.origin.x + textInsets.left, y: textFrame.origin.y + textInsets.top), size: CGSize(width: textFrame.width - textInsets.left - textInsets.right, height: textFrame.height - textInsets.top - textInsets.bottom))
                
                var statusFrame: CGRect?
                if let statusSize = statusSize {
                    if forceStatusNewline {
                        statusFrame = CGRect(origin: CGPoint(x: textFrameWithoutInsets.maxX - statusSize.width, y: textFrameWithoutInsets.maxY), size: statusSize)
                    } else {
                        statusFrame = CGRect(origin: CGPoint(x: textFrameWithoutInsets.maxX - statusSize.width, y: textFrameWithoutInsets.maxY - statusSize.height), size: statusSize)
                    }
                }
                
                textFrame = textFrame.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)
                textFrameWithoutInsets = textFrameWithoutInsets.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)
                statusFrame = statusFrame?.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)
                
                var suggestedBoundingWidth: CGFloat
                if let statusFrame = statusFrame {
                    suggestedBoundingWidth = textFrameWithoutInsets.union(statusFrame).width
                } else {
                    suggestedBoundingWidth = textFrameWithoutInsets.width
                }
                suggestedBoundingWidth += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                
                return (suggestedBoundingWidth, { boundingWidth in
                    var boundingSize: CGSize
                    var adjustedStatusFrame: CGRect?
                    
                    if let statusFrame = statusFrame {
                        let centeredTextFrame = CGRect(origin: CGPoint(x: floor((boundingWidth - textFrame.size.width) / 2.0), y: 0.0), size: textFrame.size)
                        let statusOverlapsCenteredText = CGRect(origin: CGPoint(), size: statusFrame.size).intersects(centeredTextFrame)
                        
                        if !forceStatusNewline || statusOverlapsCenteredText {
                            boundingSize = textFrameWithoutInsets.union(statusFrame).size
                            boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                            boundingSize.height += layoutConstants.text.bubbleInsets.top + layoutConstants.text.bubbleInsets.bottom
                            adjustedStatusFrame = CGRect(origin: CGPoint(x: boundingWidth - statusFrame.size.width - layoutConstants.text.bubbleInsets.right, y: statusFrame.origin.y), size: statusFrame.size)
                        } else {
                            boundingSize = textFrameWithoutInsets.size
                            boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                            boundingSize.height += layoutConstants.text.bubbleInsets.top + layoutConstants.text.bubbleInsets.bottom
                            adjustedStatusFrame = CGRect(origin: CGPoint(x: boundingWidth - statusFrame.size.width - layoutConstants.text.bubbleInsets.right, y: boundingSize.height - statusFrame.height - layoutConstants.text.bubbleInsets.bottom), size: statusFrame.size)
                        }
                    } else {
                        boundingSize = textFrameWithoutInsets.size
                        boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                        boundingSize.height += layoutConstants.text.bubbleInsets.top + layoutConstants.text.bubbleInsets.bottom
                    }
                    
                    return (boundingSize, { [weak self] animation, _ in
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
                            
                            if let statusApply = statusApply, let adjustedStatusFrame = adjustedStatusFrame {
                                let previousStatusFrame = strongSelf.statusNode.frame
                                strongSelf.statusNode.frame = adjustedStatusFrame
                                var hasAnimation = true
                                if case .None = animation {
                                    hasAnimation = false
                                }
                                statusApply(hasAnimation)
                                if strongSelf.statusNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.statusNode)
                                } else {
                                    if case let .System(duration) = animation {
                                        let delta = CGPoint(x: previousStatusFrame.maxX - adjustedStatusFrame.maxX, y: previousStatusFrame.minY - adjustedStatusFrame.minY)
                                        let statusPosition = strongSelf.statusNode.layer.position
                                        let previousPosition = CGPoint(x: statusPosition.x + delta.x, y: statusPosition.y + delta.y)
                                        strongSelf.statusNode.layer.animatePosition(from: previousPosition, to: statusPosition, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                                    }
                                }
                            } else if strongSelf.statusNode.supernode != nil {
                                strongSelf.statusNode.removeFromSupernode()
                            }
                            
                            var adjustedTextFrame = textFrame
                            if forceStatusNewline {
                                adjustedTextFrame.origin.x = floor((boundingWidth - adjustedTextFrame.width) / 2.0)
                            }
                            strongSelf.textNode.frame = adjustedTextFrame
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
    
    override func reactionTargetNode(value: String) -> (ASDisplayNode, Int)? {
        if !self.statusNode.isHidden {
            return self.statusNode.reactionNode(value: value)
        }
        return nil
    }
}
