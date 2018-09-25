import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox

private final class CachedChatMessageText {
    let text: String
    let inputEntities: [MessageTextEntity]?
    let entities: [MessageTextEntity]?
    
    init(text: String, inputEntities: [MessageTextEntity]?, entities: [MessageTextEntity]?) {
        self.text = text
        self.inputEntities = inputEntities
        self.entities = entities
    }
    
    func matches(text: String, inputEntities: [MessageTextEntity]?) -> Bool {
        if self.text != text {
            return false
        }
        if let current = self.inputEntities, let inputEntities = inputEntities {
            if current != inputEntities {
                return false
            }
        } else if (self.inputEntities != nil) != (inputEntities != nil) {
            return false
        }
        return true
    }
}

class ChatMessageTextBubbleContentNode: ChatMessageBubbleContentNode {
    private let textNode: TextNode
    private let statusNode: ChatMessageDateAndStatusNode
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private var cachedChatMessageText: CachedChatMessageText?
    
    required init() {
        self.textNode = TextNode()
        self.statusNode = ChatMessageDateAndStatusNode()
        
        super.init()
        
        self.textNode.isLayerBacked = true
        self.textNode.contentMode = .topLeft
        self.textNode.contentsScale = UIScreenScale
        self.textNode.displaysAsynchronously = true
        self.addSubnode(self.textNode)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))) {
        let textLayout = TextNode.asyncLayout(self.textNode)
        let statusLayout = self.statusNode.asyncLayout()
        
        let currentCachedChatMessageText = self.cachedChatMessageText
        
        return { item, layoutConstants, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let message = item.message
                
                let incoming = item.message.effectivelyIncoming(item.account.peerId)
                
                let horizontalInset = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                let textConstrainedSize = CGSize(width: constrainedSize.width - horizontalInset, height: constrainedSize.height)
                
                var edited = false
                var sentViaBot = false
                var viewCount: Int?
                for attribute in item.message.attributes {
                    if let _ = attribute as? EditedMessageAttribute {
                        edited = true
                    } else if let attribute = attribute as? ViewCountMessageAttribute {
                        viewCount = attribute.count
                    } else if let _ = attribute as? InlineBotMessageAttribute {
                        sentViaBot = true
                    }
                }
                if let author = item.message.author as? TelegramUser, author.botInfo != nil {
                    sentViaBot = true
                }
                
                let dateText = stringForMessageTimestampStatus(message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, strings: item.presentationData.strings)
                
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
                    let (size, apply) = statusLayout(item.presentationData.theme, item.presentationData.strings, edited && !sentViaBot, viewCount, dateText, statusType, textConstrainedSize)
                    statusSize = size
                    statusApply = apply
                }
                
                let attributedText: NSAttributedString
                var messageEntities: [MessageTextEntity]?
                for attribute in item.message.attributes {
                    if let attribute = attribute as? TextEntitiesMessageAttribute {
                        messageEntities = attribute.entities
                        break
                    }
                }
                
                var entities: [MessageTextEntity]?
                
                var updatedCachedChatMessageText: CachedChatMessageText?
                if let cached = currentCachedChatMessageText, cached.matches(text: message.text, inputEntities: messageEntities) {
                    entities = cached.entities
                } else {
                    entities = messageEntities
                    if let entitiesValue = entities {
                        if let result = addLocallyGeneratedEntities(message.text, enabledTypes: .all, entities: entitiesValue) {
                            entities = result
                        }
                    } else {
                        var generateEntities = false
                        for media in message.media {
                            if media is TelegramMediaImage || media is TelegramMediaFile {
                                generateEntities = true
                                break
                            }
                        }
                        if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                           generateEntities = true
                        }
                        if generateEntities {
                            let parsedEntities = generateTextEntities(message.text, enabledTypes: .all)
                            if !parsedEntities.isEmpty {
                                entities = parsedEntities
                            }
                        }
                    }
                    updatedCachedChatMessageText = CachedChatMessageText(text: message.text, inputEntities: messageEntities, entities: entities)
                }
                
                
                let bubbleTheme = item.presentationData.theme.theme.chat.bubble
                
                if let entities = entities {
                    attributedText = stringWithAppliedEntities(message.text, entities: entities, baseColor: incoming ? bubbleTheme.incomingPrimaryTextColor : bubbleTheme.outgoingPrimaryTextColor, linkColor: incoming ? bubbleTheme.incomingLinkTextColor : bubbleTheme.outgoingLinkTextColor, baseFont: item.presentationData.messageFont, linkFont: item.presentationData.messageFont, boldFont: item.presentationData.messageBoldFont, italicFont: item.presentationData.messageItalicFont, fixedFont: item.presentationData.messageFixedFont)
                } else {
                    attributedText = NSAttributedString(string: message.text, font: item.presentationData.messageFont, textColor: incoming ? bubbleTheme.incomingPrimaryTextColor : bubbleTheme.outgoingPrimaryTextColor)
                }
                
                let (textLayout, textApply) = textLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                var textFrame = CGRect(origin: CGPoint(), size: textLayout.size)
                let textSize = textLayout.size
                
                var statusFrame: CGRect?
                if let statusSize = statusSize {
                    var frame = CGRect(origin: CGPoint(), size: statusSize)
                    
                    let trailingLineWidth = textLayout.trailingLineWidth
                    if textSize.width - trailingLineWidth >= statusSize.width {
                        frame.origin = CGPoint(x: textFrame.maxX - statusSize.width, y: textFrame.maxY - statusSize.height)
                    } else if trailingLineWidth + statusSize.width < textConstrainedSize.width {
                        frame.origin = CGPoint(x: textFrame.minX + trailingLineWidth, y: textFrame.maxY - statusSize.height)
                    } else {
                        frame.origin = CGPoint(x: textFrame.maxX - statusSize.width, y: textFrame.maxY)
                    }
                    statusFrame = frame
                }
                
                textFrame = textFrame.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)
                statusFrame = statusFrame?.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top)

                var boundingSize: CGSize
                if let statusFrame = statusFrame {
                    boundingSize = textFrame.union(statusFrame).size
                } else {
                    boundingSize = textFrame.size
                }
                boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                boundingSize.height += layoutConstants.text.bubbleInsets.top + layoutConstants.text.bubbleInsets.bottom
                
                return (boundingSize.width, { boundingWidth in
                    var adjustedStatusFrame: CGRect?
                    if let statusFrame = statusFrame {
                        adjustedStatusFrame = CGRect(origin: CGPoint(x: boundingWidth - statusFrame.size.width - layoutConstants.text.bubbleInsets.right, y: statusFrame.origin.y), size: statusFrame.size)
                    }
                    
                    return (boundingSize, { [weak self] animation in
                        if let strongSelf = self {
                            strongSelf.item = item
                            if let updatedCachedChatMessageText = updatedCachedChatMessageText {
                                strongSelf.cachedChatMessageText = updatedCachedChatMessageText
                            }
                            
                            let cachedLayout = strongSelf.textNode.cachedLayout
                            
                            if case .System = animation {
                                if let cachedLayout = cachedLayout {
                                    if cachedLayout != textLayout {
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
                            
                            strongSelf.textNode.frame = textFrame
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
    
    override func tapActionAtPoint(_ point: CGPoint) -> ChatMessageBubbleContentTapAction {
        let textNodeFrame = self.textNode.frame
            if let (index, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
            if let url = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let attributeText = self.textNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText)
                }
                return .url(url: url, concealed: concealed)
            } else if let peerMention = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                return .peerMention(peerMention.peerId, peerMention.mention)
            } else if let peerName = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return .textMention(peerName)
            } else if let botCommand = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                return .botCommand(botCommand)
            } else if let hashtag = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return .hashtag(hashtag.peerName, hashtag.hashtag)
            } else {
                return .none
            }
        } else {
            return .none
        }
    }
    
    override func updateTouchesAtPoint(_ point: CGPoint?) {
        if let item = self.item {
            var rects: [CGRect]?
            if let point = point {
                let textNodeFrame = self.textNode.frame
                if let (index, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
                    let possibleNames: [String] = [
                        TelegramTextAttributes.URL,
                        TelegramTextAttributes.PeerMention,
                        TelegramTextAttributes.PeerTextMention,
                        TelegramTextAttributes.BotCommand,
                        TelegramTextAttributes.Hashtag
                    ]
                    for name in possibleNames {
                        if let _ = attributes[NSAttributedStringKey(rawValue: name)] {
                            rects = self.textNode.attributeRects(name: name, at: index)
                            break
                        }
                    }
                }
            }
            
            if let rects = rects {
                let linkHighlightingNode: LinkHighlightingNode
                if let current = self.linkHighlightingNode {
                    linkHighlightingNode = current
                } else {
                    linkHighlightingNode = LinkHighlightingNode(color: item.message.effectivelyIncoming(item.account.peerId) ? item.presentationData.theme.theme.chat.bubble.incomingLinkHighlightColor : item.presentationData.theme.theme.chat.bubble.outgoingLinkHighlightColor)
                    self.linkHighlightingNode = linkHighlightingNode
                    self.insertSubnode(linkHighlightingNode, belowSubnode: self.textNode)
                }
                linkHighlightingNode.frame = self.textNode.frame
                linkHighlightingNode.updateRects(rects)
            } else if let linkHighlightingNode = self.linkHighlightingNode {
                self.linkHighlightingNode = nil
                linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                    linkHighlightingNode?.removeFromSupernode()
                })
            }
        }
    }
    
    override func peekPreviewContent(at point: CGPoint) -> (Message, ChatMessagePeekPreviewContent)? {
        if let item = self.item {
            let textNodeFrame = self.textNode.frame
            if let (index, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
                if let value = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)] as? String {
                    if let rects = self.textNode.attributeRects(name: TelegramTextAttributes.URL, at: index), !rects.isEmpty {
                        var rect = rects[0]
                        for i in 1 ..< rects.count {
                            rect = rect.union(rects[i])
                        }
                        return (item.message, .url(self, rect, value))
                    }
                }
            }
        }
        return nil
    }
}
