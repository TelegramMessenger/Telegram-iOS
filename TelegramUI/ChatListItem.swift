import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramCore

class ChatListItem: ListViewItem {
    let account: Account
    let message: Message
    let combinedReadState: CombinedPeerReadState?
    let notificationSettings: PeerNotificationSettings?
    let action: (Message) -> Void
    
    let selectable: Bool = true
    
    init(account: Account, message: Message, combinedReadState: CombinedPeerReadState?, notificationSettings: PeerNotificationSettings?, action: @escaping (Message) -> Void) {
        self.account = account
        self.message = message
        self.combinedReadState = combinedReadState
        self.notificationSettings = notificationSettings
        self.action = action
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> Void) -> Void) {
        async {
            let node = ChatListItemNode()
            node.setupItem(account: self.account, message: self.message, combinedReadState: self.combinedReadState, notificationSettings: self.notificationSettings)
            node.relativePosition = (first: previousItem == nil, last: nextItem == nil)
            node.insets = ChatListItemNode.insets(first: node.relativePosition.first, last: node.relativePosition.last)
            node.layoutForWidth(width, item: self, previousItem: previousItem, nextItem: nextItem)
            completion(node, {})
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        assert(node is ChatListItemNode)
        if let node = node as? ChatListItemNode {
            Queue.mainQueue().async {
                node.setupItem(account: self.account, message: self.message, combinedReadState: self.combinedReadState, notificationSettings: self.notificationSettings)
                let layout = node.asyncLayout()
                async {
                    let first = previousItem == nil
                    let last = nextItem == nil
                    
                    let (nodeLayout, apply) = layout(self.account, width, first, last)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { [weak node] in
                            apply()
                            node?.updateBackgroundAndSeparatorsLayout()
                        })
                    }
                }
            }
        }
    }
    
    func selected(listView: ListView) {
        self.action(self.message)
    }
}

private let titleFont = Font.medium(17.0)
private let textFont = Font.regular(15.0)
private let dateFont = Font.regular(floorToScreenPixels(14.0))
private let badgeFont = Font.regular(14.0)

private func generateStatusCheckImage(single: Bool) -> UIImage? {
    return generateImage(CGSize(width: single ? 13.0 : 18.0, height: 13.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0 + 1.0, y: -size.height / 2.0 + 1.0)
        
        //CGContextSetFillColorWithColor(context, UIColor.lightGrayColor().CGColor)
        //CGContextFillRect(context, CGRect(origin: CGPoint(), size: size))
        
        context.scaleBy(x: 0.5, y: 0.5)
        context.setStrokeColor(UIColor(0x19C700).cgColor)
        context.setLineWidth(2.8)
        if single {
            let _ = try? drawSvgPath(context, path: "M0,12 L6.75230742,19.080349 L22.4821014,0.277229071 ")
        } else {
            let _ = try? drawSvgPath(context, path: "M0,12 L6.75230742,19.080349 L22.4821014,0.277229071 ")
            let _ = try? drawSvgPath(context, path: "M13.4492402,16.500967 L15.7523074,18.8031199 L31.4821014,0 ")
        }
        context.strokePath()
    })
}

private func generateBadgeBackgroundImage(active: Bool) -> UIImage? {
    return generateImage(CGSize(width: 20.0, height: 20.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        if active {
            context.setFillColor(UIColor(0x007ee5).cgColor)
        } else {
            context.setFillColor(UIColor(0xbbbbbb).cgColor)
        }
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    })?.stretchableImage(withLeftCapWidth: 10, topCapHeight: 10)
}

private let statusSingleCheckImage = generateStatusCheckImage(single: true)
private let statusDoubleCheckImage = generateStatusCheckImage(single: false)
private let activeBadgeBackgroundImage = generateBadgeBackgroundImage(active: true)
private let inactiveBadgeBackgroundImage = generateBadgeBackgroundImage(active: false)
private let peerMutedIcon = UIImage(bundleImageName: "Chat List/PeerMutedIcon")?.precomposed()

private let separatorHeight = 1.0 / UIScreen.main.scale

class ChatListItemNode: ListViewItemNode {
    var account: Account?
    var message: Message?
    var combinedReadState: CombinedPeerReadState?
    var notificationSettings: PeerNotificationSettings?
    
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    let avatarNode: AvatarNode
    let contentNode: ASDisplayNode
    let titleNode: TextNode
    let textNode: TextNode
    let dateNode: TextNode
    let statusNode: ASImageNode
    let separatorNode: ASDisplayNode
    let badgeBackgroundNode: ASImageNode
    let badgeTextNode: TextNode
    let mutedIconNode: ASImageNode
    
    var relativePosition: (first: Bool, last: Bool) = (false, false)
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.backgroundColor = .white
        
        self.avatarNode = AvatarNode(font: Font.regular(24.0))
        self.avatarNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = UIColor(0xd9d9d9)
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.contentNode = ASDisplayNode()
        self.contentNode.isLayerBacked = true
        self.contentNode.displaysAsynchronously = true
        self.contentNode.shouldRasterizeDescendants = true
        self.contentNode.isOpaque = true
        self.contentNode.backgroundColor = UIColor.white
        self.contentNode.contentMode = .left
        self.contentNode.contentsScale = UIScreenScale
        
        self.titleNode = TextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.displaysAsynchronously = true
        
        self.textNode = TextNode()
        self.textNode.isLayerBacked = true
        self.textNode.displaysAsynchronously = true
        
        self.dateNode = TextNode()
        self.dateNode.isLayerBacked = true
        self.dateNode.displaysAsynchronously = true
        
        self.statusNode = ASImageNode()
        self.statusNode.isLayerBacked = true
        self.statusNode.displaysAsynchronously = false
        self.statusNode.displayWithoutProcessing = true
        
        self.badgeBackgroundNode = ASImageNode()
        self.badgeBackgroundNode.isLayerBacked = true
        self.badgeBackgroundNode.displaysAsynchronously = false
        self.badgeBackgroundNode.displayWithoutProcessing = true
        
        self.badgeTextNode = TextNode()
        self.badgeTextNode.isLayerBacked = true
        self.badgeTextNode.displaysAsynchronously = true
        
        self.mutedIconNode = ASImageNode()
        self.mutedIconNode.isLayerBacked = true
        self.mutedIconNode.displaysAsynchronously = false
        self.mutedIconNode.displayWithoutProcessing = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = UIColor(0xc8c7cc)
        self.separatorNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.contentNode)
        
        self.contentNode.addSubnode(self.titleNode)
        self.contentNode.addSubnode(self.textNode)
        self.contentNode.addSubnode(self.dateNode)
        self.contentNode.addSubnode(self.statusNode)
        self.contentNode.addSubnode(self.badgeBackgroundNode)
        self.contentNode.addSubnode(self.badgeTextNode)
        self.contentNode.addSubnode(self.mutedIconNode)
    }
    
    func setupItem(account: Account, message: Message, combinedReadState: CombinedPeerReadState?, notificationSettings: PeerNotificationSettings?) {
        self.account = account
        self.message = message
        self.combinedReadState = combinedReadState
        self.notificationSettings = notificationSettings
        
        let peer = message.peers[message.id.peerId]
        if let peer = peer {
            self.avatarNode.setPeer(account: account, peer: peer)
        }
    }
    
    override func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let layout = self.asyncLayout()
        let (_, apply) = layout(self.account, width, self.relativePosition.first, self.relativePosition.last)
        apply()
    }
    
    func updateBackgroundAndSeparatorsLayout() {
        let size = self.bounds.size
        let insets = self.insets
        
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -insets.top - separatorHeight), size: CGSize(width: size.width, height: size.height + separatorHeight))
    }
    
    class func insets(first: Bool, last: Bool) -> UIEdgeInsets {
        return UIEdgeInsets(top: first ? 4.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0)
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        if highlighted {
            self.contentNode.displaysAsynchronously = false
            self.contentNode.backgroundColor = UIColor.clear
            self.contentNode.isOpaque = false
            
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.separatorNode)
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if animated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightedBackgroundNode.removeFromSupernode()
                                strongSelf.contentNode.backgroundColor = UIColor.white
                                strongSelf.contentNode.isOpaque = true
                                strongSelf.contentNode.displaysAsynchronously = true
                            }
                        }
                        })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                    self.contentNode.backgroundColor = UIColor.white
                    self.contentNode.isOpaque = true
                    self.contentNode.displaysAsynchronously = true
                }
            }
        }
    }
    
    func asyncLayout() -> (_ account: Account?, _ width: CGFloat, _ first: Bool, _ last: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let dateLayout = TextNode.asyncLayout(self.dateNode)
        let textLayout = TextNode.asyncLayout(self.textNode)
        let titleLayout = TextNode.asyncLayout(self.titleNode)
        let badgeTextLayout = TextNode.asyncLayout(self.badgeTextNode)
        
        let message = self.message
        let combinedReadState = self.combinedReadState
        let notificationSettings = self.notificationSettings
        
        return { account, width, first, last in
            var textAttributedString: NSAttributedString?
            var dateAttributedString: NSAttributedString?
            var titleAttributedString: NSAttributedString?
            var badgeAttributedString: NSAttributedString?
            
            var statusImage: UIImage?
            var currentBadgeBackgroundImage: UIImage?
            var currentMutedIconImage: UIImage?
            
            if let message = message {
                let peer = message.peers[message.id.peerId]
                
                var messageText: NSString = message.text as NSString
                if message.text.isEmpty {
                    for media in message.media {
                        switch media {
                            case _ as TelegramMediaImage:
                                messageText = "Photo"
                            case let fileMedia as TelegramMediaFile:
                                if fileMedia.isSticker {
                                    messageText = "Sticker"
                                } else {
                                    messageText = "File"
                                }
                            case _ as TelegramMediaMap:
                                messageText = "Map"
                            case _ as TelegramMediaContact:
                                messageText = "Contact"
                            default:
                                break
                        }
                    }
                }
                
                let attributedText: NSAttributedString
                if let author = message.author as? TelegramUser, let peer = peer, peer as? TelegramUser == nil {
                    let peerText: NSString = (author.id == account?.peerId ? "You: " : author.compactDisplayTitle + ": ") as NSString
                    
                    let mutableAttributedText = NSMutableAttributedString(string: peerText.appending(messageText as String), attributes: [kCTFontAttributeName as String: textFont])
                    mutableAttributedText.addAttribute(kCTForegroundColorAttributeName as String, value: UIColor.black.cgColor, range: NSMakeRange(0, peerText.length))
                    mutableAttributedText.addAttribute(kCTForegroundColorAttributeName as String, value: UIColor(0x8e8e93).cgColor, range: NSMakeRange(peerText.length, messageText.length))
                    attributedText = mutableAttributedText;
                } else {
                    attributedText = NSAttributedString(string: messageText as String, font: textFont, textColor: UIColor(0x8e8e93))
                }
                
                if let displayTitle = peer?.displayTitle {
                    titleAttributedString = NSAttributedString(string: displayTitle, font: titleFont, textColor: UIColor.black)
                }
                
                textAttributedString = attributedText
                
                var t = Int(message.timestamp)
                var timeinfo = tm()
                localtime_r(&t, &timeinfo)
                
                let dateText = String(format: "%02d:%02d", arguments: [Int(timeinfo.tm_hour), Int(timeinfo.tm_min)])
                
                dateAttributedString = NSAttributedString(string: dateText, font: dateFont, textColor: UIColor(0x8e8e93))
                
                if message.author?.id == account?.peerId {
                    if !message.flags.contains(.Unsent) && !message.flags.contains(.Failed) {
                        if let combinedReadState = combinedReadState, combinedReadState.isOutgoingMessageIdRead(message.id) {
                            statusImage = statusDoubleCheckImage
                        } else {
                            statusImage = statusSingleCheckImage
                        }
                    }
                }
                
                if let combinedReadState = combinedReadState {
                    let unreadCount = combinedReadState.count
                    if unreadCount != 0 {
                        if let notificationSettings = notificationSettings as? TelegramPeerNotificationSettings {
                            if case .unmuted = notificationSettings.muteState {
                                currentBadgeBackgroundImage = activeBadgeBackgroundImage
                            } else {
                                currentBadgeBackgroundImage = inactiveBadgeBackgroundImage
                            }
                        } else {
                            currentBadgeBackgroundImage = activeBadgeBackgroundImage
                        }
                        badgeAttributedString = NSAttributedString(string: "\(unreadCount)", font: badgeFont, textColor: UIColor.white)
                    }
                }
                
                if let notificationSettings = notificationSettings as? TelegramPeerNotificationSettings {
                    if case .muted = notificationSettings.muteState {
                        currentMutedIconImage = peerMutedIcon
                    }
                }
            }
            
            let statusWidth = statusImage?.size.width ?? 0.0
            
            var muteWidth: CGFloat = 0.0
            if let currentMutedIconImage = currentMutedIconImage {
                muteWidth = currentMutedIconImage.size.width + 4.0
            }
            
            let contentRect = CGRect(origin: CGPoint(x: 2.0, y: 12.0), size: CGSize(width: width - 78.0 - 10.0 - 1.0, height: 68.0 - 12.0 - 9.0))
            
            let (dateLayout, dateApply) = dateLayout(dateAttributedString, nil, 1, .end, CGSize(width: contentRect.width, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let (badgeLayout, badgeApply) = badgeTextLayout(badgeAttributedString, nil, 1, .end, CGSize(width: 50.0, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let badgeSize: CGFloat
            if let currentBadgeBackgroundImage = currentBadgeBackgroundImage {
                badgeSize = max(currentBadgeBackgroundImage.size.width, badgeLayout.size.width + 10.0) + 2.0
            } else {
                badgeSize = 0.0
            }
            
            let (textLayout, textApply) = textLayout(textAttributedString, nil, 1, .end, CGSize(width: contentRect.width - badgeSize, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let titleRect = CGRect(origin: contentRect.origin, size: CGSize(width: contentRect.width - dateLayout.size.width - 10.0 - statusWidth - muteWidth, height: contentRect.height))
            let (titleLayout, titleApply) = titleLayout(titleAttributedString, nil, 1, .end, CGSize(width: titleRect.width, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let insets = ChatListItemNode.insets(first: first, last: last)
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: width, height: 68.0), insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.relativePosition = (first, last)
                    
                    strongSelf.avatarNode.frame = CGRect(origin: CGPoint(x: 10.0, y: 4.0), size: CGSize(width: 60.0, height: 60.0))
                    strongSelf.contentNode.frame = CGRect(origin: CGPoint(x: 78.0, y: 0.0), size: CGSize(width: width - 78.0, height: 60.0))
                    
                    let _ = dateApply()
                    let _ = textApply()
                    let _ = titleApply()
                    let _ = badgeApply()
                    
                    strongSelf.dateNode.frame = CGRect(origin: CGPoint(x: contentRect.size.width - dateLayout.size.width, y: contentRect.origin.y + 2.0), size: dateLayout.size)
                    
                    if let statusImage = statusImage {
                        strongSelf.statusNode.image = statusImage
                        strongSelf.statusNode.isHidden = false
                        let statusSize = statusImage.size
                        strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: contentRect.size.width - dateLayout.size.width - 2.0 - statusSize.width, y: contentRect.origin.y + 5.0), size: statusSize)
                    } else {
                        strongSelf.statusNode.image = nil
                        strongSelf.statusNode.isHidden = true
                    }
                    
                    if let currentBadgeBackgroundImage = currentBadgeBackgroundImage {
                        strongSelf.badgeBackgroundNode.image = currentBadgeBackgroundImage
                        strongSelf.badgeBackgroundNode.isHidden = false
                        
                        let badgeBackgroundWidth = max(badgeLayout.size.width + 10.0, currentBadgeBackgroundImage.size.width)
                        let badgeBackgroundFrame = CGRect(x: contentRect.maxX - badgeBackgroundWidth, y: contentRect.maxY - currentBadgeBackgroundImage.size.height - 2.0, width: badgeBackgroundWidth, height: currentBadgeBackgroundImage.size.height)
                        let badgeTextFrame = CGRect(origin: CGPoint(x: badgeBackgroundFrame.midX - badgeLayout.size.width / 2.0, y: badgeBackgroundFrame.minY + 1.0), size: badgeLayout.size)
                        
                        strongSelf.badgeTextNode.frame = badgeTextFrame
                        strongSelf.badgeBackgroundNode.frame = badgeBackgroundFrame
                    } else {
                        strongSelf.badgeBackgroundNode.image = nil
                        strongSelf.badgeBackgroundNode.isHidden = true
                    }
                    
                    var updateContentNode = false
                    if let currentMutedIconImage = currentMutedIconImage {
                        strongSelf.mutedIconNode.image = currentMutedIconImage
                        if strongSelf.mutedIconNode.isHidden {
                            updateContentNode = true
                        }
                        strongSelf.mutedIconNode.isHidden = false
                        strongSelf.mutedIconNode.frame = CGRect(origin: CGPoint(x: contentRect.origin.x + titleLayout.size.width + 3.0, y: contentRect.origin.y + 6.0), size: currentMutedIconImage.size)
                    } else {
                        if !strongSelf.mutedIconNode.isHidden {
                            updateContentNode = true
                        }
                        strongSelf.mutedIconNode.image = nil
                        strongSelf.mutedIconNode.isHidden = true
                    }
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: contentRect.origin.x, y: contentRect.origin.y), size: titleLayout.size)
                    
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: contentRect.origin.x, y: contentRect.maxY - textLayout.size.height - 1.0), size: textLayout.size)
                    
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: 78.0 + contentRect.origin.x, y: 68.0 - separatorHeight), size: CGSize(width: width - 78.0, height: separatorHeight))
                    
                    strongSelf.contentSize = layout.contentSize
                    strongSelf.insets = layout.insets
                    strongSelf.updateBackgroundAndSeparatorsLayout()
                    
                    if updateContentNode {
                        strongSelf.contentNode.setNeedsDisplay()
                    }
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
}
