import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramCore

class ChatListItem: ListViewItem {
    let account: Account
    let index: ChatListIndex
    let message: Message?
    let peer: RenderedPeer
    let combinedReadState: CombinedPeerReadState?
    let notificationSettings: PeerNotificationSettings?
    let embeddedState: PeerChatListEmbeddedInterfaceState?
    let editing: Bool
    let hasActiveRevealControls: Bool
    let interaction: ChatListNodeInteraction
    
    let selectable: Bool = true
    
    let header: ListViewItemHeader?
    
    init(account: Account, index: ChatListIndex, message: Message?, peer: RenderedPeer, combinedReadState: CombinedPeerReadState?, notificationSettings: PeerNotificationSettings?, embeddedState: PeerChatListEmbeddedInterfaceState?, editing: Bool, hasActiveRevealControls: Bool, header: ListViewItemHeader?, interaction: ChatListNodeInteraction) {
        self.account = account
        self.index = index
        self.message = message
        self.peer = peer
        self.combinedReadState = combinedReadState
        self.notificationSettings = notificationSettings
        self.embeddedState = embeddedState
        self.editing = editing
        self.hasActiveRevealControls = hasActiveRevealControls
        self.header = header
        self.interaction = interaction
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ChatListItemNode()
            node.setupItem(item: self)
            let (first, last, firstWithHeader, nextIsPinned) = ChatListItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
            node.insets = ChatListItemNode.insets(first: first, last: last, firstWithHeader: firstWithHeader)
            
            let (nodeLayout, apply) = node.asyncLayout()(self, width, first, last, firstWithHeader, nextIsPinned)
            
            node.insets = nodeLayout.insets
            node.contentSize = nodeLayout.contentSize
            
            completion(node, {
                return (nil, {
                    apply(false)
                })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        assert(node is ChatListItemNode)
        if let node = node as? ChatListItemNode {
            Queue.mainQueue().async {
                node.setupItem(item: self)
                let layout = node.asyncLayout()
                async {
                    let (first, last, firstWithHeader, nextIsPinned) = ChatListItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
                    var animated = true
                    if case .None = animation {
                        animated = false
                    }
                    
                    let (nodeLayout, apply) = layout(self, width, first, last, firstWithHeader, nextIsPinned)
                    Queue.mainQueue().async {
                        completion(nodeLayout, {
                            apply(animated)
                        })
                    }
                }
            }
        }
    }
    
    func selected(listView: ListView) {
        if let message = self.message {
            self.interaction.messageSelected(message)
        } else if let peer = self.peer.peers[self.peer.peerId] {
            self.interaction.peerSelected(peer)
        }
    }
    
    static func mergeType(item: ChatListItem, previousItem: ListViewItem?, nextItem: ListViewItem?) -> (first: Bool, last: Bool, firstWithHeader: Bool, nextIsPinned: Bool) {
        var first = false
        var last = false
        var firstWithHeader = false
        if let previousItem = previousItem {
            if let header = item.header {
                if let previousItem = previousItem as? ChatListItem {
                    firstWithHeader = header.id != previousItem.header?.id
                } else {
                    firstWithHeader = true
                }
            }
        } else {
            first = true
            firstWithHeader = item.header != nil
        }
        var nextIsPinned = false
        if let nextItem = nextItem as? ChatListItem {
            if nextItem.index.pinningIndex != nil {
                nextIsPinned = true
            }
        } else {
            last = true
        }
        return (first, last, firstWithHeader, nextIsPinned)
    }
}

private let titleFont = Font.medium(17.0)
private let textFont = Font.regular(15.0)
private let dateFont = Font.regular(14.0)
private let badgeFont = Font.regular(14.0)

private let titleSecretColor = UIColor(0x00a629)

private let pinIcon = UIImage(bundleImageName: "Chat List/RevealActionPinIcon")?.precomposed()
private let unpinIcon = UIImage(bundleImageName: "Chat List/RevealActionUnpinIcon")?.precomposed()
private let muteIcon = UIImage(bundleImageName: "Chat List/RevealActionMuteIcon")?.precomposed()
private let unmuteIcon = UIImage(bundleImageName: "Chat List/RevealActionUnmuteIcon")?.precomposed()
private let deleteIcon = UIImage(bundleImageName: "Chat List/RevealActionDeleteIcon")?.precomposed()

private enum RevealOptionKey: Int32 {
    case pin
    case unpin
    case mute
    case unmute
    case delete
}

private let pinOption = ItemListRevealOption(key: RevealOptionKey.pin.rawValue, title: "Pin", icon: pinIcon, color: UIColor(0xbcbcc3))
private let unpinOption = ItemListRevealOption(key: RevealOptionKey.unpin.rawValue, title: "Unpin", icon: unpinIcon, color: UIColor(0xbcbcc3))
private let muteOption = ItemListRevealOption(key: RevealOptionKey.mute.rawValue, title: "Mute", icon: muteIcon, color: UIColor(0xaaaab3))
private let unmuteOption = ItemListRevealOption(key: RevealOptionKey.unmute.rawValue, title: "Unmute", icon: unmuteIcon, color: UIColor(0xaaaab3))
private let deleteOption = ItemListRevealOption(key: RevealOptionKey.delete.rawValue, title: "Delete", icon: deleteIcon, color: UIColor(0xff3824))

private func revealOptions(isPinned: Bool, isMuted: Bool) -> [ItemListRevealOption] {
    var options: [ItemListRevealOption] = []
    if isPinned {
        options.append(unpinOption)
    } else {
        options.append(pinOption)
    }
    if isMuted {
        options.append(unmuteOption)
    } else {
        options.append(muteOption)
    }
    options.append(deleteOption)
    return options
}

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

private let pinnedBackgroundColor = UIColor(0xf7f7f7)

class ChatListItemNode: ItemListRevealOptionsItemNode {
    var item: ChatListItem?
    
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    let avatarNode: AvatarNode
    let titleNode: TextNode
    let textNode: TextNode
    let dateNode: TextNode
    let statusNode: ASImageNode
    let separatorNode: ASDisplayNode
    let badgeBackgroundNode: ASImageNode
    let badgeTextNode: TextNode
    let mutedIconNode: ASImageNode
    
    var editableControlNode: ItemListEditableControlNode?
    
    var layoutParams: (ChatListItem, first: Bool, last: Bool, firstWithHeader: Bool, nextIsPinned: Bool)?
    
    override var canBeSelected: Bool {
        if self.editableControlNode != nil {
            return false
        } else {
            return super.canBeSelected
        }
    }
    
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
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.avatarNode)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.dateNode)
        self.addSubnode(self.statusNode)
        self.addSubnode(self.badgeBackgroundNode)
        self.addSubnode(self.badgeTextNode)
        self.addSubnode(self.mutedIconNode)
    }
    
    func setupItem(item: ChatListItem) {
        self.item = item
        
        if let message = item.message {
            let peer = messageMainPeer(message)
            if let peer = peer {
                self.avatarNode.setPeer(account: item.account, peer: peer)
            }
        } else {
            if let peer = item.peer.chatMainPeer {
                self.avatarNode.setPeer(account: item.account, peer: peer)
            }
        }
    }
    
    override func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let layout = self.asyncLayout()
        let (first, last, firstWithHeader, nextIsPinned) = ChatListItem.mergeType(item: item as! ChatListItem, previousItem: previousItem, nextItem: nextItem)
        let (nodeLayout, apply) = layout(item as! ChatListItem, width, first, last, firstWithHeader, nextIsPinned)
        apply(false)
        self.contentSize = nodeLayout.contentSize
        self.insets = nodeLayout.insets
    }
    
    class func insets(first: Bool, last: Bool, firstWithHeader: Bool) -> UIEdgeInsets {
        return UIEdgeInsets(top: firstWithHeader ? 29.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0)
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        if highlighted {
            /*var nodes: [ASDisplayNode] = [self.titleNode, self.textNode, self.dateNode, self.statusNode]
            for node in nodes {
                node.backgroundColor = .clear
                node.recursivelyEnsureDisplaySynchronously(true)
            }*/
            
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
                                /*if let item = strongSelf.layoutParams?.0, item.index.pinningIndex != nil {
                                    strongSelf.contentNode.backgroundColor = pinnedBackgroundColor
                                } else {
                                    strongSelf.contentNode.backgroundColor = UIColor.white
                                }
                                
                                if !strongSelf.contentNode.isOpaque {
                                    strongSelf.contentNode.isOpaque = true
                                    strongSelf.contentNode.recursivelyEnsureDisplaySynchronously(true)
                                }*/
                            }
                        }
                        })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                    
                    /*if let item = self.layoutParams?.0, item.index.pinningIndex != nil {
                        self.contentNode.backgroundColor = pinnedBackgroundColor
                    } else {
                        self.contentNode.backgroundColor = UIColor.white
                    }
                    self.contentNode.isOpaque = true
                    self.contentNode.displaysAsynchronously = true*/
                }
            }
        }
    }
    
    
    func asyncLayout() -> (_ item: ChatListItem, _ width: CGFloat, _ first: Bool, _ last: Bool, _ firstWithHeader: Bool, _ nextIsPinned: Bool) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let dateLayout = TextNode.asyncLayout(self.dateNode)
        let textLayout = TextNode.asyncLayout(self.textNode)
        let titleLayout = TextNode.asyncLayout(self.titleNode)
        let badgeTextLayout = TextNode.asyncLayout(self.badgeTextNode)
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        
        return { item, width, first, last, firstWithHeader, nextIsPinned in
            let account = item.account
            let message = item.message
            let combinedReadState = item.combinedReadState
            let notificationSettings = item.notificationSettings
            let embeddedState = item.embeddedState
            
            var textAttributedString: NSAttributedString?
            var dateAttributedString: NSAttributedString?
            var titleAttributedString: NSAttributedString?
            var badgeAttributedString: NSAttributedString?
            
            var statusImage: UIImage?
            var currentBadgeBackgroundImage: UIImage?
            var currentMutedIconImage: UIImage?
            
            var editableControlSizeAndApply: (CGSize, () -> ItemListEditableControlNode)?
            
            let editingOffset: CGFloat
            if item.editing {
                let sizeAndApply = editableControlLayout(68.0)
                editableControlSizeAndApply = sizeAndApply
                editingOffset = sizeAndApply.0.width
            } else {
                editingOffset = 0.0
            }
            
            if true {
                let peer: Peer?
                
                var messageText: NSString
                if let message = message {
                    if let messageMain = messageMainPeer(message) {
                        peer = messageMain
                    } else {
                        peer = item.peer.chatMainPeer
                    }
                    
                    messageText = message.text as NSString
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
                } else {
                    peer = item.peer.chatMainPeer
                    messageText = ""
                }
                
                let attributedText: NSAttributedString
                if let embeddedState = embeddedState as? ChatEmbeddedInterfaceState {
                    let mutableAttributedText = NSMutableAttributedString()
                    mutableAttributedText.append(NSAttributedString(string: "Draft: ", font: textFont, textColor: UIColor(0xdd4b39)))
                    mutableAttributedText.append(NSAttributedString(string: embeddedState.text, font: textFont, textColor: UIColor(0x8e8e93)))
                    attributedText = mutableAttributedText;
                } else if let message = message, let author = message.author as? TelegramUser, let peer = peer, !(peer is TelegramUser) {
                    if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                        attributedText = NSAttributedString(string: messageText as String, font: textFont, textColor: UIColor(0x8e8e93))
                    } else {
                        let peerText: NSString = (author.id == account.peerId ? "You: " : author.compactDisplayTitle + ": ") as NSString
                        
                        let mutableAttributedText = NSMutableAttributedString(string: peerText.appending(messageText as String), attributes: [kCTFontAttributeName as String: textFont])
                        mutableAttributedText.addAttribute(kCTForegroundColorAttributeName as String, value: UIColor.black.cgColor, range: NSMakeRange(0, peerText.length))
                        mutableAttributedText.addAttribute(kCTForegroundColorAttributeName as String, value: UIColor(0x8e8e93).cgColor, range: NSMakeRange(peerText.length, messageText.length))
                        attributedText = mutableAttributedText;
                    }
                } else {
                    attributedText = NSAttributedString(string: messageText as String, font: textFont, textColor: UIColor(0x8e8e93))
                }
                
                if let displayTitle = peer?.displayTitle {
                    titleAttributedString = NSAttributedString(string: displayTitle, font: titleFont, textColor: item.index.messageIndex.id.peerId.namespace == Namespaces.Peer.SecretChat ? titleSecretColor : UIColor.black)
                }
                
                textAttributedString = attributedText
                
                var t = Int(item.index.messageIndex.timestamp)
                var timeinfo = tm()
                localtime_r(&t, &timeinfo)
                
                let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                let dateText = stringForRelativeTimestamp(item.index.messageIndex.timestamp, relativeTo: timestamp)
                
                dateAttributedString = NSAttributedString(string: dateText, font: dateFont, textColor: UIColor(0x8e8e93))
                
                if let message = message, message.author?.id == account.peerId {
                    if !message.flags.isSending {
                        if let combinedReadState = combinedReadState, combinedReadState.isOutgoingMessageIndexRead(MessageIndex(message)) {
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
            
            let rawContentRect = CGRect(origin: CGPoint(x: 2.0, y: 12.0), size: CGSize(width: width - 78.0 - 10.0 - 1.0 - editingOffset, height: 68.0 - 12.0 - 9.0))
            
            let (dateLayout, dateApply) = dateLayout(dateAttributedString, nil, 1, .end, CGSize(width: rawContentRect.width, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let (badgeLayout, badgeApply) = badgeTextLayout(badgeAttributedString, nil, 1, .end, CGSize(width: 50.0, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let badgeSize: CGFloat
            if let currentBadgeBackgroundImage = currentBadgeBackgroundImage {
                badgeSize = max(currentBadgeBackgroundImage.size.width, badgeLayout.size.width + 10.0) + 2.0
            } else {
                badgeSize = 0.0
            }
            
            let (textLayout, textApply) = textLayout(textAttributedString, nil, 1, .end, CGSize(width: rawContentRect.width - badgeSize, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let titleRect = CGRect(origin: rawContentRect.origin, size: CGSize(width: rawContentRect.width - dateLayout.size.width - 10.0 - statusWidth - muteWidth, height: rawContentRect.height))
            let (titleLayout, titleApply) = titleLayout(titleAttributedString, nil, 1, .end, CGSize(width: titleRect.width, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let insets = ChatListItemNode.insets(first: first, last: last, firstWithHeader: firstWithHeader)
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: width, height: 68.0), insets: insets)
            
            let peerRevealOptions = revealOptions(isPinned: item.index.pinningIndex != nil, isMuted: currentMutedIconImage != nil)
            
            return (layout, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, first, last, firstWithHeader, nextIsPinned)
                    
                    let revealOffset = strongSelf.revealOffset
                    
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    var crossfadeContent = false
                    if let editableControlSizeAndApply = editableControlSizeAndApply {
                        if strongSelf.editableControlNode == nil {
                            crossfadeContent = true
                            let editableControlNode = editableControlSizeAndApply.1()
                            editableControlNode.tapped = {
                                if let strongSelf = self {
                                    strongSelf.setRevealOptionsOpened(true, animated: true)
                                    strongSelf.revealOptionsInteractivelyOpened()
                                }
                            }
                            strongSelf.editableControlNode = editableControlNode
                            strongSelf.addSubnode(editableControlNode)
                            let editableControlFrame = CGRect(origin: CGPoint(x: revealOffset, y: 0.0), size: editableControlSizeAndApply.0)
                            editableControlNode.frame = editableControlFrame
                            transition.animatePosition(node: editableControlNode, from: CGPoint(x: editableControlFrame.midX - editableControlFrame.size.width, y: editableControlFrame.midY))
                            editableControlNode.alpha = 0.0
                            transition.updateAlpha(node: editableControlNode, alpha: 1.0)
                        }
                    } else if let editableControlNode = strongSelf.editableControlNode {
                        crossfadeContent = true
                        var editableControlFrame = editableControlNode.frame
                        editableControlFrame.origin.x = -editableControlFrame.size.width
                        strongSelf.editableControlNode = nil
                        transition.updateAlpha(node: editableControlNode, alpha: 0.0)
                        transition.updateFrame(node: editableControlNode, frame: editableControlFrame, completion: { [weak editableControlNode] _ in
                            editableControlNode?.removeFromSupernode()
                        })
                    }
                    
                    transition.updateFrame(node: strongSelf.avatarNode, frame: CGRect(origin: CGPoint(x: editingOffset + 10.0 + revealOffset, y: 4.0), size: CGSize(width: 60.0, height: 60.0)))
                    
                    let _ = dateApply()
                    let _ = textApply()
                    let _ = titleApply()
                    let _ = badgeApply()
                    
                    let contentRect = rawContentRect.offsetBy(dx: editingOffset + 78.0 + revealOffset, dy: 0.0)
                    
                    strongSelf.dateNode.frame = CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateLayout.size.width, y: contentRect.origin.y + 2.0), size: dateLayout.size)
                    
                    if let statusImage = statusImage {
                        strongSelf.statusNode.image = statusImage
                        strongSelf.statusNode.isHidden = false
                        let statusSize = statusImage.size
                        strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateLayout.size.width - 2.0 - statusSize.width, y: contentRect.origin.y + 5.0), size: statusSize)
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
                    
                    if let currentMutedIconImage = currentMutedIconImage {
                        strongSelf.mutedIconNode.image = currentMutedIconImage
                        strongSelf.mutedIconNode.isHidden = false
                        transition.updateFrame(node: strongSelf.mutedIconNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + titleLayout.size.width + 3.0, y: contentRect.origin.y + 6.0), size: currentMutedIconImage.size))
                    } else {
                        strongSelf.mutedIconNode.image = nil
                        strongSelf.mutedIconNode.isHidden = true
                    }
                    
                    let contentDeltaX = contentRect.origin.x - strongSelf.titleNode.frame.minX
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: contentRect.origin.x, y: contentRect.origin.y), size: titleLayout.size)
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: contentRect.origin.x, y: contentRect.maxY - textLayout.size.height - 1.0), size: textLayout.size)
                    
                    if !contentDeltaX.isZero {
                        let titlePosition = strongSelf.titleNode.position
                        transition.animatePosition(node: strongSelf.titleNode, from: CGPoint(x: titlePosition.x - contentDeltaX, y: titlePosition.y))
                        
                        let textPosition = strongSelf.textNode.position
                        transition.animatePosition(node: strongSelf.textNode, from: CGPoint(x: textPosition.x - contentDeltaX, y: textPosition.y))
                    }
                    
                    let separatorInset: CGFloat
                    if !nextIsPinned && item.index.pinningIndex != nil {
                        separatorInset = 0.0
                    } else {
                        separatorInset = editingOffset + 78.0 + rawContentRect.origin.x
                    }
                    
                    transition.updateFrame(node: strongSelf.separatorNode, frame: CGRect(origin: CGPoint(x: separatorInset, y: 68.0 - separatorHeight), size: CGSize(width: width - separatorInset, height: separatorHeight)))
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    if item.index.pinningIndex != nil {
                        strongSelf.backgroundNode.backgroundColor = pinnedBackgroundColor
                        /*if strongSelf.contentNode.backgroundColor == nil || !strongSelf.contentNode.backgroundColor!.isEqual(pinnedBackgroundColor) {
                            strongSelf.contentNode.backgroundColor = pinnedBackgroundColor
                            updateContentNode = true
                        }*/
                    } else {
                        strongSelf.backgroundNode.backgroundColor = UIColor.white
                        /*if strongSelf.contentNode.backgroundColor == nil || !strongSelf.contentNode.backgroundColor!.isEqual(UIColor.white) {
                            strongSelf.contentNode.backgroundColor = UIColor.white
                            updateContentNode = true
                        }*/
                    }
                    let topNegativeInset: CGFloat = 0.0
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -separatorHeight - topNegativeInset), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height + separatorHeight + topNegativeInset))
                    
                    /*if crossfadeContent && animated {
                        if let contents = strongSelf.titleNode.contents {
                            let tempNode = ASDisplayNode()
                            tempNode.isLayerBacked = true
                            tempNode.contents = contents
                            tempNode.frame = previousContentNodeFrame
                            strongSelf.insertSubnode(tempNode, aboveSubnode: strongSelf.contentNode)
                            transition.updateFrame(node: tempNode, frame: strongSelf.contentNode.frame)
                            transition.updateAlpha(node: tempNode, alpha: 0.0, completion: { [weak tempNode] _ in
                                tempNode?.removeFromSupernode()
                            })
                        }
                    }*/
                    
                    strongSelf.setRevealOptions(peerRevealOptions)
                    strongSelf.setRevealOptionsOpened(item.hasActiveRevealControls, animated: animated)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
    
    override public func header() -> ListViewItemHeader? {
        if let (item, _, _, _, _) = self.layoutParams {
            return item.header
        } else {
            return nil
        }
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        if let _ = self.item {
            let editingOffset: CGFloat
            if let editableControlNode = self.editableControlNode {
                editingOffset = editableControlNode.bounds.size.width
                var editableControlFrame = editableControlNode.frame
                editableControlFrame.origin.x = offset
                transition.updateFrame(node: editableControlNode, frame: editableControlFrame)
            } else {
                editingOffset = 0.0
            }
            
            let rawContentRect = CGRect(origin: CGPoint(x: 2.0, y: 12.0), size: CGSize(width: self.contentSize.width - 78.0 - 10.0 - 1.0 - editingOffset, height: 68.0 - 12.0 - 9.0))
            
            let contentRect = rawContentRect.offsetBy(dx: editingOffset + 78.0 + offset, dy: 0.0)
            
            var avatarFrame = self.avatarNode.frame
            avatarFrame.origin.x = editingOffset + 10.0 + offset
            transition.updateFrame(node: self.avatarNode, frame: avatarFrame)
            
            let titleFrame = self.titleNode.frame
            transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x, y: titleFrame.origin.y), size: titleFrame.size))
            
            let textFrame = self.textNode.frame
            transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x, y: textFrame.origin.y), size: textFrame.size))
            
            let dateFrame = self.dateNode.frame
            transition.updateFrame(node: self.dateNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateFrame.size.width, y: contentRect.origin.y + 2.0), size: dateFrame.size))
            
            let statusFrame = self.statusNode.frame
            transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateFrame.size.width - 2.0 - statusFrame.size.width, y: contentRect.origin.y + 5.0), size: statusFrame.size))
            
            let mutedIconFrame = self.mutedIconNode.frame
            transition.updateFrame(node: self.mutedIconNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + titleFrame.size.width + 3.0, y: contentRect.origin.y + 6.0), size: mutedIconFrame.size))
            
            
            let badgeBackgroundFrame = self.badgeBackgroundNode.frame
            let updatedBadgeBackgroundFrame = CGRect(origin: CGPoint(x: contentRect.maxX - badgeBackgroundFrame.size.width, y: contentRect.maxY - badgeBackgroundFrame.size.height - 2.0), size: badgeBackgroundFrame.size)
            transition.updateFrame(node: self.badgeBackgroundNode, frame: updatedBadgeBackgroundFrame)
            
            let badgeTextFrame = self.badgeTextNode.frame
            transition.updateFrame(node: self.badgeTextNode, frame: CGRect(origin: CGPoint(x: updatedBadgeBackgroundFrame.midX - badgeTextFrame.size.width / 2.0, y: badgeBackgroundFrame.minY + 1.0), size: badgeTextFrame.size))
        }
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let item = self.item {
            item.interaction.setPeerIdWithRevealedOptions(item.index.messageIndex.id.peerId, nil)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let item = self.item {
            item.interaction.setPeerIdWithRevealedOptions(nil, item.index.messageIndex.id.peerId)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
        if let item = self.item {
            switch option.key {
                case RevealOptionKey.pin.rawValue:
                    item.interaction.setPeerPinned(item.index.messageIndex.id.peerId, true)
                case RevealOptionKey.unpin.rawValue:
                    item.interaction.setPeerPinned(item.index.messageIndex.id.peerId, false)
                case RevealOptionKey.mute.rawValue:
                    item.interaction.setPeerMuted(item.index.messageIndex.id.peerId, true)
                case RevealOptionKey.unmute.rawValue:
                    item.interaction.setPeerMuted(item.index.messageIndex.id.peerId, false)
                case RevealOptionKey.delete.rawValue:
                    item.interaction.deletePeer(item.index.messageIndex.id.peerId)
                default:
                    break
            }
        }
    }
}
