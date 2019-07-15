import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData

private let avatarFont = UIFont(name: ".SFCompactRounded-Semibold", size: 16.0)!

private let titleFont = Font.medium(14.0)
private let textFont = Font.regular(14.0)

class ChatMessagePhoneNumberRequestContentNode: ChatMessageBubbleContentNode {
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    private let textNode: TextNode
    
    private let buttonNode: ChatMessageAttachedContentButtonNode
    
    required init() {
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        self.textNode = TextNode()
        self.buttonNode = ChatMessageAttachedContentButtonNode()
        
        super.init()
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> Void))) {
        let statusLayout = self.dateAndStatusNode.asyncLayout()
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeButtonLayout = ChatMessageAttachedContentButtonNode.asyncLayout(self.buttonNode)
        
        return { item, layoutConstants, _, _, constrainedSize in
            let text: String
            if item.message.effectivelyIncoming(item.context.account.peerId) {
                text = "\(item.message.author?.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder) ?? "") requests your phone number"
            } else {
                text = "You have requested phone number"
            }
            
            let textString = NSAttributedString(string: text, font: textFont, textColor: item.message.effectivelyIncoming(item.context.account.peerId) ? item.presentationData.theme.theme.chat.message.incoming.primaryTextColor : item.presentationData.theme.theme.chat.message.outgoing.primaryTextColor)
            
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let maxTextWidth = max(1.0, constrainedSize.width - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right)
                let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: textString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
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
                if let author = item.message.author as? TelegramUser, author.botInfo != nil || author.flags.contains(.isSupport) {
                    sentViaBot = true
                }
                
                let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings)
                
                let statusType: ChatMessageDateAndStatusType?
                switch position {
                    case .linear(_, .None):
                        if item.message.effectivelyIncoming(item.context.account.peerId) {
                            statusType = .BubbleIncoming
                        } else {
                            if item.message.flags.contains(.Failed) {
                                statusType = .BubbleOutgoing(.Failed)
                            } else if item.message.flags.isSending && !item.message.isSentOrAcknowledged {
                                statusType = .BubbleOutgoing(.Sending)
                            } else {
                                statusType = .BubbleOutgoing(.Sent(read: item.read))
                            }
                        }
                    default:
                        statusType = nil
                }
                
                var statusSize = CGSize()
                var statusApply: ((Bool) -> Void)?
                
                if let statusType = statusType {
                    let (size, apply) = statusLayout(item.presentationData, edited && !sentViaBot, viewCount, dateText, statusType, CGSize(width: constrainedSize.width, height: CGFloat.greatestFiniteMagnitude))
                    statusSize = size
                    statusApply = apply
                }
                
                let buttonImage: UIImage
                let buttonHighlightedImage: UIImage
                let titleColor: UIColor
                let titleHighlightedColor: UIColor
                if item.message.effectivelyIncoming(item.context.account.peerId) {
                    buttonImage = PresentationResourcesChat.chatMessageAttachedContentButtonIncoming(item.presentationData.theme.theme)!
                    buttonHighlightedImage = PresentationResourcesChat.chatMessageAttachedContentHighlightedButtonIncoming(item.presentationData.theme.theme)!
                    titleColor = item.presentationData.theme.theme.chat.message.incoming.accentTextColor
                    
                    let bubbleColors = bubbleColorComponents(theme: item.presentationData.theme.theme, incoming: true, wallpaper: !item.presentationData.theme.wallpaper.isEmpty)
                    titleHighlightedColor = bubbleColors.fill
                } else {
                    buttonImage = PresentationResourcesChat.chatMessageAttachedContentButtonOutgoing(item.presentationData.theme.theme)!
                    buttonHighlightedImage = PresentationResourcesChat.chatMessageAttachedContentHighlightedButtonOutgoing(item.presentationData.theme.theme)!
                    titleColor = item.presentationData.theme.theme.chat.message.outgoing.accentTextColor
                    
                    let bubbleColors = bubbleColorComponents(theme: item.presentationData.theme.theme, incoming: false, wallpaper: !item.presentationData.theme.wallpaper.isEmpty)
                    titleHighlightedColor = bubbleColors.fill
                }
                
                let (buttonWidth, continueLayout) = makeButtonLayout(constrainedSize.width, buttonImage, buttonHighlightedImage, nil, nil, "SHARE MY PHONE NUMBER", titleColor, titleHighlightedColor)
                
                var maxContentWidth: CGFloat = 0.0
                maxContentWidth = max(maxContentWidth, statusSize.width)
                maxContentWidth = max(maxContentWidth, textLayout.size.width)
                maxContentWidth = max(maxContentWidth, buttonWidth)
                
                let contentWidth = maxContentWidth +  layoutConstants.text.bubbleInsets.right + 8.0
                
                return (contentWidth, { boundingWidth in
                    let layoutSize: CGSize
                    let statusFrame: CGRect
                    
                    let (buttonSize, buttonApply) = continueLayout(boundingWidth - layoutConstants.text.bubbleInsets.right * 2.0)
                    let buttonSpacing: CGFloat = 4.0
                    
                    layoutSize = CGSize(width: contentWidth, height: layoutConstants.text.bubbleInsets.top + textLayout.size.height + 9.0 + statusSize.height + buttonSize.height + buttonSpacing)
                    statusFrame = CGRect(origin: CGPoint(x: boundingWidth - statusSize.width - layoutConstants.text.bubbleInsets.right, y: layoutSize.height - statusSize.height - 9.0 - buttonSpacing - buttonSize.height), size: statusSize)
                    let buttonFrame = CGRect(origin: CGPoint(x: layoutConstants.text.bubbleInsets.right, y: layoutSize.height - 9.0 - buttonSize.height), size: buttonSize)
                    
                    return (layoutSize, { [weak self] animation, _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            let _ = textApply()
                            let _ = buttonApply()
                            
                            strongSelf.textNode.frame = CGRect(origin: CGPoint(x: layoutConstants.text.bubbleInsets.left, y: layoutConstants.text.bubbleInsets.top), size: textLayout.size)
                            strongSelf.buttonNode.frame = buttonFrame
                            
                            if let statusApply = statusApply {
                                if strongSelf.dateAndStatusNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.dateAndStatusNode)
                                }
                                var hasAnimation = true
                                if case .None = animation {
                                    hasAnimation = false
                                }
                                statusApply(hasAnimation)
                                strongSelf.dateAndStatusNode.frame = statusFrame
                            } else if strongSelf.dateAndStatusNode.supernode != nil {
                                strongSelf.dateAndStatusNode.removeFromSupernode()
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
    
    override func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture) -> ChatMessageBubbleContentTapAction {
        if self.buttonNode.frame.contains(point) {
            //return .openMessage
        }
        return .none
    }
    
    @objc private func buttonPressed() {
        if let item = self.item {
            item.controllerInteraction.shareAccountContact()
        }
    }
}
