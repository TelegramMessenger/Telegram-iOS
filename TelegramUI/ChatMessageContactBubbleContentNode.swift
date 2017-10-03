import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private let avatarFont: UIFont = UIFont(name: "ArialRoundedMTBold", size: 15.0)!

private let titleFont = Font.medium(14.0)
private let textFont = Font.regular(14.0)

class ChatMessageContactBubbleContentNode: ChatMessageBubbleContentNode {
    private let avatarNode: AvatarNode
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    private let titleNode: TextNode
    private let textNode: TextNode
    
    private var item: ChatMessageItem?
    private var contact: TelegramMediaContact?
    private var contactPhone: String?
    
    required init() {
        self.avatarNode = AvatarNode(font: avatarFont)
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        self.titleNode = TextNode()
        self.textNode = TextNode()
        
        super.init()
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.contactTap(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ position: ChatMessageBubbleContentPosition, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))) {
        let statusLayout = self.dateAndStatusNode.asyncLayout()
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        let previousContact = self.contact
        let previousContactPhone = self.contactPhone
        
        return { item, layoutConstants, position, constrainedSize in
            var selectedContact: TelegramMediaContact?
            for media in item.message.media {
                if let media = media as? TelegramMediaContact {
                    selectedContact = media
                }
            }
            
            var titleString: NSAttributedString?
            var textString: NSAttributedString?
            var updatedPhone: String?
            
            if let selectedContact = selectedContact {
                let displayName: String
                if !selectedContact.firstName.isEmpty && !selectedContact.lastName.isEmpty {
                    displayName = "\(selectedContact.firstName) \(selectedContact.lastName)"
                } else if !selectedContact.firstName.isEmpty {
                    displayName = selectedContact.firstName
                } else {
                    displayName = selectedContact.lastName
                }
                titleString = NSAttributedString(string: displayName, font: titleFont, textColor: item.message.effectivelyIncoming ? item.theme.chat.bubble.incomingAccentColor : item.theme.chat.bubble.outgoingAccentColor)
                
                let phone: String
                if let previousContact = previousContact, previousContact.isEqual(selectedContact), let contactPhone = previousContactPhone {
                    phone = contactPhone
                } else {
                    phone = formatPhoneNumber(selectedContact.phoneNumber)
                }
                updatedPhone = phone
                textString = NSAttributedString(string: phone, font: textFont, textColor: item.message.effectivelyIncoming ? item.theme.chat.bubble.incomingPrimaryTextColor : item.theme.chat.bubble.outgoingPrimaryTextColor)
            } else {
                updatedPhone = nil
            }
            
            return (CGFloat.greatestFiniteMagnitude, { constrainedSize in
                let avatarSize = CGSize(width: 40.0, height: 40.0)
                
                let maxTextWidth = max(1.0, constrainedSize.width - avatarSize.width - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right)
                let (titleLayout, titleApply) = makeTitleLayout(titleString, nil, 1, .end, CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
                let (textLayout, textApply) = makeTextLayout(textString, nil, 2, .end, CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
                
                var t = Int(item.message.timestamp)
                var timeinfo = tm()
                localtime_r(&t, &timeinfo)
                
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
                
                var dateText = String(format: "%02d:%02d", arguments: [Int(timeinfo.tm_hour), Int(timeinfo.tm_min)])
                
                if let author = item.message.author as? TelegramUser {
                    if author.botInfo != nil {
                        sentViaBot = true
                    }
                    if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                        dateText = "\(author.displayTitle), \(dateText)"
                    }
                }
                
                let statusType: ChatMessageDateAndStatusType?
                if case .None = position.bottom {
                    if item.message.effectivelyIncoming {
                        statusType = .BubbleIncoming
                    } else {
                        if item.message.flags.contains(.Failed) {
                            statusType = .BubbleOutgoing(.Failed)
                        } else if item.message.flags.isSending {
                            statusType = .BubbleOutgoing(.Sending)
                        } else {
                            statusType = .BubbleOutgoing(.Sent(read: item.read))
                        }
                    }
                } else {
                    statusType = nil
                }
                
                var statusSize = CGSize()
                var statusApply: ((Bool) -> Void)?
                
                if let statusType = statusType {
                    let (size, apply) = statusLayout(item.theme, edited && !sentViaBot, viewCount, dateText, statusType, CGSize(width: constrainedSize.width, height: CGFloat.greatestFiniteMagnitude))
                    statusSize = size
                    statusApply = apply
                }
                
                let contentWidth = avatarSize.width + max(statusSize.width, max(titleLayout.size.width, textLayout.size.width)) +  layoutConstants.text.bubbleInsets.right + 8.0
                
                return (contentWidth, { boundingWidth in
                    let layoutSize: CGSize
                    let statusFrame: CGRect
                    
                    let baseAvatarFrame = CGRect(origin: CGPoint(), size: avatarSize)
                    
                    layoutSize = CGSize(width: contentWidth, height: 63.0)
                    statusFrame = CGRect(origin: CGPoint(x: boundingWidth - statusSize.width - layoutConstants.text.bubbleInsets.right, y: layoutSize.height - statusSize.height - 5.0), size: statusSize)
                    let avatarFrame = baseAvatarFrame.offsetBy(dx: 5.0, dy: 5.0)
                    
                    var customLetters: [String] = []
                    if let selectedContact = selectedContact, selectedContact.peerId == nil {
                        let firstName = selectedContact.firstName
                        let lastName = selectedContact.lastName
                        if !firstName.isEmpty && !lastName.isEmpty {
                            customLetters = [firstName.substring(to: firstName.index(after: firstName.startIndex)).uppercased(), lastName.substring(to: lastName.index(after: lastName.startIndex)).uppercased()]
                        } else if !firstName.isEmpty {
                            customLetters = [firstName.substring(to: firstName.index(after: firstName.startIndex)).uppercased()]
                        } else if !lastName.isEmpty {
                            customLetters = [lastName.substring(to: lastName.index(after: lastName.startIndex)).uppercased()]
                        }
                    }
                    
                    return (layoutSize, { [weak self] animation in
                        if let strongSelf = self {
                            strongSelf.item = item
                            strongSelf.contact = selectedContact
                            strongSelf.contactPhone = updatedPhone
                            
                            strongSelf.avatarNode.frame = avatarFrame
                            
                            let _ = titleApply()
                            let _ = textApply()
                            
                            strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: avatarFrame.maxX + 7.0, y: avatarFrame.minY + 1.0), size: titleLayout.size)
                            strongSelf.textNode.frame = CGRect(origin: CGPoint(x: avatarFrame.maxX + 7.0, y: avatarFrame.minY + 20.0), size: textLayout.size)
                            
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
                            
                            if let _ = titleString {
                                if strongSelf.titleNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.titleNode)
                                }
                                if strongSelf.textNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.textNode)
                                }
                            } else {
                                if strongSelf.titleNode.supernode != nil {
                                    strongSelf.titleNode.removeFromSupernode()
                                }
                                if strongSelf.textNode.supernode != nil {
                                    strongSelf.textNode.removeFromSupernode()
                                }
                            }
                            
                            if let peerId = selectedContact?.peerId, let peer = item.message.peers[peerId] {
                                strongSelf.avatarNode.setPeer(account: item.account, peer: peer)
                            } else {
                                strongSelf.avatarNode.setCustomLetters(customLetters)
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
    
    override func tapActionAtPoint(_ point: CGPoint) -> ChatMessageBubbleContentTapAction {
        return .none
    }
    
    @objc func contactTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let item = self.item {
                self.controllerInteraction?.openMessage(item.message.id)
            }
        }
    }
}
