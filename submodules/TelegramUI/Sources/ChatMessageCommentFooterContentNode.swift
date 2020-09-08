import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import TelegramPresentationData

final class ChatMessageCommentFooterContentNode: ChatMessageBubbleContentNode {
    private let separatorNode: ASDisplayNode
    private let textNode: TextNode
    private let iconNode: ASImageNode
    private let arrowNode: ASImageNode
    private let buttonNode: HighlightTrackingButtonNode
    private let avatarsNode: MergedAvatarsNode
    
    required init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isUserInteractionEnabled = false
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .topLeft
        self.textNode.contentsScale = UIScreenScale
        self.textNode.displaysAsynchronously = true
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.isUserInteractionEnabled = false
        
        self.arrowNode = ASImageNode()
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.isUserInteractionEnabled = false
        
        self.avatarsNode = MergedAvatarsNode()
        self.avatarsNode.isUserInteractionEnabled = false
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.avatarsNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                let nodes: [ASDisplayNode] = [
                    strongSelf.textNode,
                    strongSelf.iconNode,
                    strongSelf.avatarsNode,
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
        item.controllerInteraction.openMessageReplies(item.message.id)
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> Void))) {
        let textLayout = TextNode.asyncLayout(self.textNode)
        
        return { item, layoutConstants, preparePosition, _, constrainedSize in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            let displaySeparator: Bool
            if case let .linear(top, _) = preparePosition, case .Neighbour(true, _) = top {
                displaySeparator = false
            } else {
                displaySeparator = true
            }
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                
                var maxTextWidth = CGFloat.greatestFiniteMagnitude
                for media in item.message.media {
                    if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content, content.type == "telegram_background" || content.type == "telegram_theme" {
                        maxTextWidth = layoutConstants.wallpapers.maxTextWidth
                        break
                    }
                }
                
                let horizontalInset = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                
                var dateReplies = 0
                var replyPeers: [Peer] = []
                for attribute in item.message.attributes {
                    if let attribute = attribute as? ReplyThreadMessageAttribute {
                        dateReplies = Int(attribute.count)
                        replyPeers = attribute.latestUsers.compactMap { peerId -> Peer? in
                            return item.message.peers[peerId]
                        }
                    }
                }
                
                //TODO:localize
                let rawText: String
                
                if dateReplies > 0 {
                    if dateReplies == 1 {
                        rawText = "1 Comment"
                    } else {
                        rawText = "\(dateReplies) Comments"
                    }
                } else {
                    rawText = "Leave a Comment"
                }
                
                let imageSize: CGFloat = 30.0
                let imageSpacing: CGFloat = 20.0
                
                var textLeftInset: CGFloat = 0.0
                if replyPeers.isEmpty {
                    textLeftInset = 41.0
                } else {
                    textLeftInset = 15.0 + imageSize * min(1.0, CGFloat(replyPeers.count)) + (imageSpacing) * max(0.0, min(2.0, CGFloat(replyPeers.count - 1)))
                }
                
                let textConstrainedSize = CGSize(width: min(maxTextWidth, constrainedSize.width - horizontalInset - textLeftInset - 20.0), height: constrainedSize.height)
                
                let attributedText: NSAttributedString
                
                let messageTheme = incoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
                
                let textFont = item.presentationData.messageFont
                
                attributedText = NSAttributedString(string: rawText, font: textFont, textColor: messageTheme.accentTextColor)
                
                let textInsets = UIEdgeInsets(top: 2.0, left: 2.0, bottom: 5.0, right: 2.0)
                
                let (textLayout, textApply) = textLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: textInsets, lineColor: messageTheme.accentControlColor))
                
                var textFrame = CGRect(origin: CGPoint(x: -textInsets.left + textLeftInset, y: -textInsets.top + 5.0), size: textLayout.size)
                var textFrameWithoutInsets = CGRect(origin: CGPoint(x: textFrame.origin.x + textInsets.left, y: textFrame.origin.y + textInsets.top), size: CGSize(width: textFrame.width - textInsets.left - textInsets.right, height: textFrame.height - textInsets.top - textInsets.bottom))
                
                textFrame = textFrame.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top - 5.0 + UIScreenPixel)
                textFrameWithoutInsets = textFrameWithoutInsets.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)

                var suggestedBoundingWidth: CGFloat
                suggestedBoundingWidth = textFrameWithoutInsets.width
                suggestedBoundingWidth += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right + textLeftInset + 20.0
                
                let iconImage = PresentationResourcesChat.chatMessageCommentsIcon(item.presentationData.theme.theme, incoming: incoming)
                let arrowImage = PresentationResourcesChat.chatMessageCommentsArrowIcon(item.presentationData.theme.theme, incoming: incoming)
                
                return (suggestedBoundingWidth, { boundingWidth in
                    var boundingSize: CGSize
                    
                    boundingSize = textFrameWithoutInsets.size
                    boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                    boundingSize.height = 40.0
                    
                    return (boundingSize, { [weak self] animation, synchronousLoad in
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
                            
                            strongSelf.textNode.displaysAsynchronously = !item.presentationData.isPreview
                            let _ = textApply()
                            
                            let adjustedTextFrame = textFrame
                            
                            strongSelf.textNode.frame = adjustedTextFrame
                            
                            if let iconImage = iconImage {
                                strongSelf.iconNode.image = iconImage
                                strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: 15.0, y: 6.0), size: iconImage.size)
                            }

                            if let arrowImage = arrowImage {
                                strongSelf.arrowNode.image = arrowImage
                                strongSelf.arrowNode.frame = CGRect(origin: CGPoint(x: boundingWidth - 27.0, y: 6.0), size: arrowImage.size)
                            }

                            strongSelf.iconNode.isHidden = !replyPeers.isEmpty
                            
                            let avatarsFrame = CGRect(origin: CGPoint(x: 13.0, y: 3.0), size: CGSize(width: imageSize * 3.0, height: imageSize))
                            strongSelf.avatarsNode.frame = avatarsFrame
                            strongSelf.avatarsNode.updateLayout(size: avatarsFrame.size)
                            strongSelf.avatarsNode.update(context: item.context, peers: replyPeers, synchronousLoad: synchronousLoad, imageSize: imageSize, imageSpacing: imageSpacing, borderWidth: 2.0 - UIScreenPixel)
                            
                            strongSelf.separatorNode.backgroundColor = messageTheme.polls.separator
                            strongSelf.separatorNode.isHidden = !displaySeparator
                            strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: layoutConstants.bubble.strokeInsets.left, y: -3.0), size: CGSize(width: boundingWidth - layoutConstants.bubble.strokeInsets.left - layoutConstants.bubble.strokeInsets.right, height: UIScreenPixel))
                            
                            strongSelf.buttonNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: boundingWidth, height: boundingSize.height))
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
        if self.buttonNode.frame.contains(point) {
            return self.buttonNode.view
        }
        return nil
    }
}




