import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import Postbox
import TelegramPresentationData
import AppBundle

private let titleFont: UIFont = Font.medium(16.0)
private let labelFont: UIFont = Font.regular(13.0)

private let incomingGreenIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/CallIncomingArrow"), color: UIColor(rgb: 0x36c033))
private let incomingRedIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/CallIncomingArrow"), color: UIColor(rgb: 0xff4747))

private let outgoingGreenIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/CallOutgoingArrow"), color: UIColor(rgb: 0x36c033))
private let outgoingRedIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/CallOutgoingArrow"), color: UIColor(rgb: 0xff4747))

class ChatMessageCallBubbleContentNode: ChatMessageBubbleContentNode {
    private let titleNode: TextNode
    private let labelNode: TextNode
    private let iconNode: ASImageNode
    private let buttonNode: HighlightableButtonNode
    
    required init() {
        self.titleNode = TextNode()
        self.labelNode = TextNode()
        
        self.iconNode = ASImageNode()
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.isLayerBacked = true
        
        self.buttonNode = HighlightableButtonNode()
        
        super.init()
        
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .topLeft
        self.titleNode.contentsScale = UIScreenScale
        self.titleNode.displaysAsynchronously = true
        self.addSubnode(self.titleNode)
        
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.contentMode = .topLeft
        self.labelNode.contentsScale = UIScreenScale
        self.labelNode.displaysAsynchronously = true
        self.addSubnode(self.labelNode)
        
        self.addSubnode(self.iconNode)
        
        self.addSubnode(self.buttonNode)
        self.buttonNode.addTarget(self, action: #selector(self.callButtonPressed), forControlEvents: .touchUpInside)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> Void))) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        
        return { item, layoutConstants, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let message = item.message
                let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                
                let horizontalInset = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                let textConstrainedSize = CGSize(width: constrainedSize.width - horizontalInset, height: constrainedSize.height)
                
                let messageTheme = incoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
                
                var titleString: String?
                var callDuration: Int32?
                var callSuccessful = true
                for media in item.message.media {
                    if let action = media as? TelegramMediaAction, case let .phoneCall(_, discardReason, duration) = action.action {
                        callDuration = duration
                        if let discardReason = discardReason {
                            switch discardReason {
                                case .busy, .disconnect:
                                    callSuccessful = false
                                    titleString = item.presentationData.strings.Notification_CallCanceled
                                case .missed:
                                    callSuccessful = false
                                    titleString = incoming ? item.presentationData.strings.Notification_CallMissed : item.presentationData.strings.Notification_CallCanceled
                                case .hangup:
                                    break
                            }
                        }
                        break
                    }
                }
                
                if titleString == nil {
                    let baseString: String
                    if message.flags.contains(.Incoming) {
                        baseString = item.presentationData.strings.Notification_CallIncoming
                    } else {
                        baseString = item.presentationData.strings.Notification_CallOutgoing
                    }
                    
                    titleString = baseString
                }
                
                let attributedTitle = NSAttributedString(string: titleString ?? "", font: titleFont, textColor: messageTheme.primaryTextColor)
                
                var callIcon: UIImage?
                if callSuccessful {
                    if incoming {
                        callIcon = incomingGreenIcon
                    } else {
                        callIcon = outgoingGreenIcon
                    }
                } else {
                    if incoming {
                        callIcon = incomingRedIcon
                    } else {
                        callIcon = outgoingRedIcon
                    }
                }
                
                var buttonImage: UIImage?
                if incoming {
                    buttonImage = PresentationResourcesChat.chatBubbleIncomingCallButtonImage(item.presentationData.theme.theme)
                } else {
                    buttonImage = PresentationResourcesChat.chatBubbleOutgoingCallButtonImage(item.presentationData.theme.theme)
                }
                
                let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, reactionCount: 0)
                
                let statusText: String
                if let callDuration = callDuration, callDuration > 1 {
                    statusText = item.presentationData.strings.Notification_CallFormat(dateText, callDurationString(strings: item.presentationData.strings, value: callDuration)).0
                } else {
                    statusText = dateText
                }
                
                let attributedLabel = NSAttributedString(string: statusText, font: labelFont, textColor: messageTheme.fileDurationColor)

                let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: attributedTitle, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: attributedLabel, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                let titleSize = titleLayout.size
                let labelSize = labelLayout.size
                
                var titleFrame = CGRect(origin: CGPoint(), size: titleSize)
                var labelFrame = CGRect(origin: CGPoint(x: 14.0, y: 0.0), size: labelSize)
                
                titleFrame = titleFrame.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top + 4.0)
                labelFrame = labelFrame.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top + titleSize.height + 4.0)
                
                var boundingSize: CGSize
                boundingSize = CGSize(width: max(titleFrame.size.width, labelFrame.size.width + 14.0), height: 47.0)
                boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                boundingSize.height += layoutConstants.text.bubbleInsets.top + layoutConstants.text.bubbleInsets.bottom
                
                boundingSize.width += 54.0
                
                return (boundingSize.width, { boundingWidth in
                    return (boundingSize, { [weak self] animation, _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            let _ = titleApply()
                            let _ = labelApply()
                            
                            strongSelf.titleNode.frame = titleFrame
                            strongSelf.labelNode.frame = labelFrame
                            
                            if let callIcon = callIcon {
                                if strongSelf.iconNode.image != callIcon {
                                    strongSelf.iconNode.image = callIcon
                                }
                                strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: titleFrame.minX + 1.0, y: labelFrame.minY + 4.0), size: callIcon.size)
                            }
                            
                            if let buttonImage = buttonImage {
                                strongSelf.buttonNode.setImage(buttonImage, for: [])
                                strongSelf.buttonNode.frame = CGRect(origin: CGPoint(x: boundingWidth - buttonImage.size.width - 8.0, y: 15.0), size: buttonImage.size)
                            }
                        }
                    })
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    @objc func callButtonPressed() {
        if let item = self.item {
            item.controllerInteraction.callPeer(item.message.id.peerId)
        }
    }
    
    override func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture) -> ChatMessageBubbleContentTapAction {
        if self.buttonNode.frame.contains(point) {
            return .ignore
        } else if self.bounds.contains(point), let item = self.item {
            return .call(item.message.id.peerId)
        } else {
            return .none
        }
    }
    
    override func reactionTargetNode(value: String) -> (ASImageNode, Int)? {
        return nil
    }
}
