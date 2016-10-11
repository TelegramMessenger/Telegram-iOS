import Foundation
import AsyncDisplayKit
import Display
import TelegramCore

private let messageFont: UIFont = UIFont.systemFont(ofSize: 17.0)
private let messageBoldFont: UIFont = UIFont.boldSystemFont(ofSize: 17.0)
private let messageFixedFont: UIFont = UIFont(name: "Menlo-Regular", size: 16.0) ?? UIFont.systemFont(ofSize: 17.0)

class ChatMessageTextBubbleContentNode: ChatMessageBubbleContentNode {
    private let textNode: TextNode
    private let statusNode: ChatMessageDateAndStatusNode
    
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
    
    override func asyncLayoutContent() -> (_ item: ChatMessageItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ position: ChatMessageBubbleContentPosition, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))) {
        let textLayout = TextNode.asyncLayout(self.textNode)
        let statusLayout = self.statusNode.asyncLayout()
        
        return { item, layoutConstants, position, _ in
            return (CGFloat.greatestFiniteMagnitude, { constrainedSize in
                let message = item.message
                
                let incoming = item.message.effectivelyIncoming
                
                let horizontalInset = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                let textConstrainedSize = CGSize(width: constrainedSize.width - horizontalInset, height: constrainedSize.height)
                
                var t = Int(item.message.timestamp)
                var timeinfo = tm()
                localtime_r(&t, &timeinfo)
                
                let dateText = String(format: "%02d:%02d", arguments: [Int(timeinfo.tm_hour), Int(timeinfo.tm_min)])
                //let dateText = "\(message.id.id)"
                
                let statusType: ChatMessageDateAndStatusType?
                if case .None = position.bottom {
                    if incoming {
                        statusType = .BubbleIncoming
                    } else {
                        if message.flags.contains(.Failed) {
                            statusType = .BubbleOutgoing(.Failed)
                        } else if message.flags.contains(.Unsent) {
                            statusType = .BubbleOutgoing(.Sending)
                        } else {
                            statusType = .BubbleOutgoing(.Sent(read: item.read))
                        }
                    }
                } else {
                    statusType = nil
                }
                
                var statusSize: CGSize?
                var statusApply: ((Bool) -> Void)?
                
                if let statusType = statusType {
                    let (size, apply) = statusLayout(dateText, statusType, textConstrainedSize)
                    statusSize = size
                    statusApply = apply
                }
                
                let attributedText: NSAttributedString
                var entities: TextEntitiesMessageAttribute?
                for attribute in item.message.attributes {
                    if let attribute = attribute as? TextEntitiesMessageAttribute {
                        entities = attribute
                        break
                    }
                }
                if let entities = entities {
                    let string = NSMutableAttributedString(string: message.text, attributes: [NSFontAttributeName: messageFont, NSForegroundColorAttributeName: UIColor.black])
                    for entity in entities.entities {
                        switch entity.type {
                            case .Url:
                                string.addAttribute(NSForegroundColorAttributeName, value: UIColor(0x004bad), range: NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
                            case .Email:
                                string.addAttribute(NSForegroundColorAttributeName, value: UIColor(0x004bad), range: NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
                            case .TextUrl:
                                string.addAttribute(NSForegroundColorAttributeName, value: UIColor(0x004bad), range: NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
                            case .Bold:
                                string.addAttribute(NSFontAttributeName, value: messageBoldFont, range: NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
                            case .Mention:
                                string.addAttribute(NSForegroundColorAttributeName, value: UIColor(0x004bad), range: NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
                            case .Code, .Pre:
                                string.addAttribute(NSFontAttributeName, value: messageFixedFont, range: NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
                            default:
                                break
                        }
                    }
                    attributedText = string
                } else {
                    attributedText = NSAttributedString(string: message.text, font: messageFont, textColor: UIColor.black)
                }
                
                let (textLayout, textApply) = textLayout(attributedText, nil, 0, .end, textConstrainedSize, nil)
                
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
                            let _ = textApply()
                            
                            if let statusApply = statusApply, let adjustedStatusFrame = adjustedStatusFrame {
                                strongSelf.statusNode.frame = adjustedStatusFrame
                                var hasAnimation = true
                                if case .None = animation {
                                    hasAnimation = false
                                }
                                statusApply(hasAnimation)
                                if strongSelf.statusNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.statusNode)
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
}
