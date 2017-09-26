import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramCore

private let titleFont = Font.regular(17.0)
private let titleBoldFont = Font.medium(17.0)
private let statusFont = Font.regular(13.0)

private let selectedImage = UIImage(bundleImageName: "Contact List/SelectionChecked")?.precomposed()
private let selectableImage = UIImage(bundleImageName: "Contact List/SelectionUnchecked")?.precomposed()

enum ContactsPeerItemStatus {
    case none
    case presence(PeerPresence)
    case addressName
}

enum ContactsPeerItemSelection: Equatable {
    case none
    case selectable(selected: Bool)
    
    static func ==(lhs: ContactsPeerItemSelection, rhs: ContactsPeerItemSelection) -> Bool {
        switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case let .selectable(selected):
                if case .selectable(selected) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

class ContactsPeerItem: ListViewItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let account: Account
    let peer: Peer?
    let chatPeer: Peer?
    let status: ContactsPeerItemStatus
    let selection: ContactsPeerItemSelection
    let hasActiveRevealControls: Bool
    let action: (Peer) -> Void
    let setPeerIdWithRevealedOptions: ((PeerId?, PeerId?) -> Void)?
    let deletePeer: ((PeerId) -> Void)?
    
    let selectable: Bool = true
    
    let headerAccessoryItem: ListViewAccessoryItem?
    
    let header: ListViewItemHeader?
    
    init(theme: PresentationTheme, strings: PresentationStrings, account: Account, peer: Peer?, chatPeer: Peer?, status: ContactsPeerItemStatus, selection: ContactsPeerItemSelection, hasActiveRevealControls: Bool, index: PeerNameIndex?, header: ListViewItemHeader?, action: @escaping (Peer) -> Void, setPeerIdWithRevealedOptions: ((PeerId?, PeerId?) -> Void)? = nil, deletePeer: ((PeerId) -> Void)? = nil) {
        self.theme = theme
        self.strings = strings
        self.account = account
        self.peer = peer
        self.chatPeer = chatPeer
        self.status = status
        self.selection = selection
        self.hasActiveRevealControls = hasActiveRevealControls
        self.action = action
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.deletePeer = deletePeer
        self.header = header
        
        if let index = index {
            var letter: String = "#"
            if let user = peer as? TelegramUser {
                switch index {
                    case .firstNameFirst:
                        if let firstName = user.firstName, !firstName.isEmpty {
                            letter = firstName.substring(to: firstName.index(after: firstName.startIndex)).uppercased()
                        } else if let lastName = user.lastName, !lastName.isEmpty {
                            letter = lastName.substring(to: lastName.index(after: lastName.startIndex)).uppercased()
                        }
                    case .lastNameFirst:
                        if let lastName = user.lastName, !lastName.isEmpty {
                            letter = lastName.substring(to: lastName.index(after: lastName.startIndex)).uppercased()
                        } else if let firstName = user.firstName, !firstName.isEmpty {
                            letter = firstName.substring(to: firstName.index(after: firstName.startIndex)).uppercased()
                        }
                }
            } else if let group = peer as? TelegramGroup {
                if !group.title.isEmpty {
                    letter = group.title.substring(to: group.title.index(after: group.title.startIndex)).uppercased()
                }
            } else if let channel = peer as? TelegramChannel {
                if !channel.title.isEmpty {
                    letter = channel.title.substring(to: channel.title.index(after: channel.title.startIndex)).uppercased()
                }
            }
            self.headerAccessoryItem = ContactsSectionHeaderAccessoryItem(sectionHeader: .letter(letter), theme: theme)
        } else {
            self.headerAccessoryItem = nil
        }
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ContactsPeerItemNode()
            let makeLayout = node.asyncLayout()
            let (first, last, firstWithHeader) = ContactsPeerItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
            let (nodeLayout, nodeApply) = makeLayout(self, width, first, last, firstWithHeader)
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            completion(node, {
                let (signal, apply) = nodeApply()
                return (signal, {
                    apply(false)
                })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? ContactsPeerItemNode {
            Queue.mainQueue().async {
                let layout = node.asyncLayout()
                async {
                    let (first, last, firstWithHeader) = ContactsPeerItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
                    let (nodeLayout, apply) = layout(self, width, first, last, firstWithHeader)
                    Queue.mainQueue().async {
                        completion(nodeLayout, {
                            apply().1(animation.isAnimated)
                        })
                    }
                }
            }
        }
    }
    
    func selected(listView: ListView) {
        if let peer = self.peer {
            self.action(peer)
        }
    }
    
    static func mergeType(item: ContactsPeerItem, previousItem: ListViewItem?, nextItem: ListViewItem?) -> (first: Bool, last: Bool, firstWithHeader: Bool) {
        var first = false
        var last = false
        var firstWithHeader = false
        if let previousItem = previousItem {
            if let header = item.header {
                if let previousItem = previousItem as? ContactsPeerItem {
                    firstWithHeader = header.id != previousItem.header?.id
                } else {
                    firstWithHeader = true
                }
            }
        } else {
            first = true
            firstWithHeader = item.header != nil
        }
        if let nextItem = nextItem {
            if let header = item.header {
                if let nextItem = nextItem as? ContactsPeerItem {
                    last = header.id != nextItem.header?.id
                } else {
                    last = true
                }
            }
        } else {
            last = true
        }
        return (first, last, firstWithHeader)
    }
}

private let separatorHeight = 1.0 / UIScreen.main.scale

class ContactsPeerItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let avatarNode: AvatarNode
    private let titleNode: TextNode
    private var verificationIconNode: ASImageNode?
    private let statusNode: TextNode
    private var selectionNode: ASImageNode?
    
    private var avatarState: (Account, Peer?)?
    
    private var peerPresenceManager: PeerPresenceStatusManager?
    private var layoutParams: (ContactsPeerItem, CGFloat, Bool, Bool, Bool)?
    var peer: Peer? {
        return self.layoutParams?.0.peer
    }
    private var item: ContactsPeerItem? {
        return self.layoutParams?.0
    }
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.avatarNode = AvatarNode(font: Font.regular(15.0))
        self.avatarNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.statusNode = TextNode()
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.statusNode)
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let layoutParams = strongSelf.layoutParams {
                let (_, apply) = strongSelf.asyncLayout()(layoutParams.0, layoutParams.1, layoutParams.2, layoutParams.3, layoutParams.4)
                let _ = apply()
            }
        })
    }
    
    override func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let (item, _, _, _, _) = self.layoutParams {
            let (first, last, firstWithHeader) = ContactsPeerItem.mergeType(item: item, previousItem: previousItem, nextItem: nextItem)
            self.layoutParams = (item, width, first, last, firstWithHeader)
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, width, first, last, firstWithHeader)
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply()
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        if highlighted && self.selectionNode == nil {
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
                            }
                        }
                    })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                }
            }
        }
    }
    
    func asyncLayout() -> (_ item: ContactsPeerItem, _ width: CGFloat, _ first: Bool, _ last: Bool, _ firstWithHeader: Bool) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (Bool) -> Void)) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        let currentSelectionNode = self.selectionNode
        
        let currentItem = self.layoutParams?.0
        
        return { [weak self] item, width, first, last, firstWithHeader in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            var leftInset: CGFloat = 65.0
            let rightInset: CGFloat = 10.0
            
            let updatedSelectionNode: ASImageNode?
            var updatedSelectionImage: UIImage?
            switch item.selection {
                case .none:
                    updatedSelectionNode = nil
                case let .selectable(selected):
                    leftInset += 28.0
                    
                    let selectionNode: ASImageNode
                    if let current = currentSelectionNode {
                        selectionNode = current
                        updatedSelectionNode = selectionNode
                    } else {
                        selectionNode = ASImageNode()
                        updatedSelectionNode = selectionNode
                    }
                    updatedSelectionImage = selected ? selectedImage : selectableImage
            }
            
            var isVerified = false
            if let peer = item.peer as? TelegramUser {
                isVerified = peer.flags.contains(.isVerified)
            } else if let peer = item.peer as? TelegramChannel {
                isVerified = peer.flags.contains(.isVerified)
            }
            var verificationIconImage: UIImage?
            if isVerified {
                verificationIconImage = PresentationResourcesChatList.verifiedIcon(item.theme)
            }
            
            var titleAttributedString: NSAttributedString?
            var statusAttributedString: NSAttributedString?
            var userPresence: TelegramUserPresence?
            
            if let peer = item.peer {
                let textColor: UIColor
                if let _ = item.chatPeer as? TelegramSecretChat {
                    textColor = item.theme.chatList.secretTitleColor
                } else {
                    textColor = item.theme.list.itemPrimaryTextColor
                }
                if let user = peer as? TelegramUser {
                    if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                        let string = NSMutableAttributedString()
                        string.append(NSAttributedString(string: firstName, font: titleFont, textColor: textColor))
                        string.append(NSAttributedString(string: " ", font: titleFont, textColor: textColor))
                        string.append(NSAttributedString(string: lastName, font: titleBoldFont, textColor: textColor))
                        titleAttributedString = string
                    } else if let firstName = user.firstName, !firstName.isEmpty {
                        titleAttributedString = NSAttributedString(string: firstName, font: titleBoldFont, textColor: textColor)
                    } else if let lastName = user.lastName, !lastName.isEmpty {
                        titleAttributedString = NSAttributedString(string: lastName, font: titleBoldFont, textColor: textColor)
                    } else {
                        titleAttributedString = NSAttributedString(string: item.strings.User_DeletedAccount, font: titleBoldFont, textColor: textColor)
                    }
                } else if let group = peer as? TelegramGroup {
                    titleAttributedString = NSAttributedString(string: group.title, font: titleBoldFont, textColor: item.theme.list.itemPrimaryTextColor)
                } else if let channel = peer as? TelegramChannel {
                    titleAttributedString = NSAttributedString(string: channel.title, font: titleBoldFont, textColor: item.theme.list.itemPrimaryTextColor)
                }
                
                switch item.status {
                    case .none:
                        break
                    case let .presence(presence):
                        if let presence = presence as? TelegramUserPresence {
                            userPresence = presence
                            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                            let (string, activity) = stringAndActivityForUserPresence(strings: item.strings, presence: presence, relativeTo: Int32(timestamp))
                            statusAttributedString = NSAttributedString(string: string, font: statusFont, textColor: activity ? item.theme.list.itemAccentColor : item.theme.list.itemSecondaryTextColor)
                        }
                    case .addressName:
                        if let addressName = peer.addressName {
                            statusAttributedString = NSAttributedString(string: "@" + addressName, font: statusFont, textColor: item.theme.list.itemSecondaryTextColor)
                        }
                }
            }
            
            var additionalTitleInset: CGFloat = 0.0
            if let verificationIconImage = verificationIconImage {
                additionalTitleInset += 3.0 + verificationIconImage.size.width
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(titleAttributedString, nil, 1, .end, CGSize(width: max(0.0, width - leftInset - rightInset - additionalTitleInset), height: CGFloat.infinity), .natural, nil, UIEdgeInsets())
            
            let (statusLayout, statusApply) = makeStatusLayout(statusAttributedString, nil, 1, .end, CGSize(width: max(0.0, width - leftInset - rightInset), height: CGFloat.infinity), .natural, nil, UIEdgeInsets())
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: width, height: 48.0), insets: UIEdgeInsets(top: firstWithHeader ? 29.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0))
            
            let titleFrame: CGRect
            if statusAttributedString != nil {
                titleFrame = CGRect(origin: CGPoint(x: leftInset, y: 4.0), size: titleLayout.size)
            } else {
                titleFrame = CGRect(origin: CGPoint(x: leftInset, y: 13.0), size: titleLayout.size)
            }
            
            return (nodeLayout, { [weak self] in
                if let strongSelf = self {
                    if let peer = item.peer {
                        strongSelf.avatarNode.setPeer(account: item.account, peer: peer)
                    }
                    
                    return (strongSelf.avatarNode.ready, { [weak strongSelf] animated in
                        if let strongSelf = strongSelf {
                            strongSelf.layoutParams = (item, width, first, last, firstWithHeader)
                            
                            let transition: ContainedViewLayoutTransition
                            if animated {
                                transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                            } else {
                                transition = .immediate
                            }
                            
                            let revealOffset = strongSelf.revealOffset
                            
                            if let _ = updatedTheme {
                                strongSelf.separatorNode.backgroundColor = item.theme.list.itemSeparatorColor
                                strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBackgroundColor
                                strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                            }
                            
                            transition.updateFrame(node: strongSelf.avatarNode, frame: CGRect(origin: CGPoint(x: revealOffset + leftInset - 51.0, y: 4.0), size: CGSize(width: 40.0, height: 40.0)))
                            
                            let _ = titleApply()
                            transition.updateFrame(node: strongSelf.titleNode, frame: titleFrame.offsetBy(dx: revealOffset, dy: 0.0))
                            
                            let _ = statusApply()
                            transition.updateFrame(node: strongSelf.statusNode, frame: CGRect(origin: CGPoint(x: revealOffset + leftInset, y: 25.0), size: statusLayout.size))
                            
                            if let verificationIconImage = verificationIconImage {
                                if strongSelf.verificationIconNode == nil {
                                    let verificationIconNode = ASImageNode()
                                    verificationIconNode.isLayerBacked = true
                                    verificationIconNode.displayWithoutProcessing = true
                                    verificationIconNode.displaysAsynchronously = false
                                    strongSelf.verificationIconNode = verificationIconNode
                                    strongSelf.addSubnode(verificationIconNode)
                                }
                                if let verificationIconNode = strongSelf.verificationIconNode {
                                    verificationIconNode.image = verificationIconImage
                                    
                                    transition.updateFrame(node: verificationIconNode, frame: CGRect(origin: CGPoint(x: revealOffset + titleFrame.maxX + 3.0, y: titleFrame.minY + 3.0 + UIScreenPixel), size: verificationIconImage.size))
                                }
                            } else if let verificationIconNode = strongSelf.verificationIconNode {
                                strongSelf.verificationIconNode = nil
                                verificationIconNode.removeFromSupernode()
                            }
                            
                            if let updatedSelectionNode = updatedSelectionNode {
                                if strongSelf.selectionNode !== updatedSelectionNode {
                                    strongSelf.selectionNode?.removeFromSupernode()
                                    strongSelf.selectionNode = updatedSelectionNode
                                    strongSelf.addSubnode(updatedSelectionNode)
                                }
                                if updatedSelectionImage !== updatedSelectionNode.image {
                                    updatedSelectionNode.image = updatedSelectionImage
                                }
                                if let updatedSelectionImage = updatedSelectionImage {
                                    updatedSelectionNode.frame = CGRect(origin: CGPoint(x: 10.0, y: floor((nodeLayout.contentSize.height - updatedSelectionImage.size.height) / 2.0)), size: updatedSelectionImage.size)
                                }
                            } else if let selectionNode = strongSelf.selectionNode {
                                selectionNode.removeFromSupernode()
                                strongSelf.selectionNode = nil
                            }
                            
                            let topHighlightInset: CGFloat = (first || !nodeLayout.insets.top.isZero) ? 0.0 : separatorHeight
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: nodeLayout.contentSize.width, height: nodeLayout.contentSize.height))
                            strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - topHighlightInset), size: CGSize(width: nodeLayout.size.width, height: nodeLayout.size.height + topHighlightInset))
                            strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - separatorHeight), size: CGSize(width: max(0.0, nodeLayout.size.width - 65.0), height: separatorHeight))
                            strongSelf.separatorNode.isHidden = last
                            
                            if let userPresence = userPresence {
                                strongSelf.peerPresenceManager?.reset(presence: userPresence)
                            }
                            
                            strongSelf.setRevealOptions([ItemListRevealOption(key: 0, title: item.strings.Common_Delete, icon: nil, color: UIColor(rgb: 0xff3824))])
                            strongSelf.setRevealOptionsOpened(item.hasActiveRevealControls, animated: animated)
                        }
                    })
                } else {
                    return (nil, { _ in
                    })
                }
            })
        }
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        if let item = self.item {
            var leftInset: CGFloat = 65.0
            
            switch item.selection {
                case .none:
                    break
                case .selectable:
                    leftInset += 28.0
            }
            
            var avatarFrame = self.avatarNode.frame
            avatarFrame.origin.x = offset + leftInset - 51.0
            transition.updateFrame(node: self.avatarNode, frame: avatarFrame)
            
            var titleFrame = self.titleNode.frame
            titleFrame.origin.x = leftInset + offset
            transition.updateFrame(node: self.titleNode, frame: titleFrame)
            
            var statusFrame = self.statusNode.frame
            statusFrame.origin.x = leftInset + offset
            transition.updateFrame(node: self.statusNode, frame: statusFrame)
            
            if let verificationIconNode = self.verificationIconNode {
                var iconFrame = verificationIconNode.frame
                iconFrame.origin.x = offset + titleFrame.maxX + 3.0
                transition.updateFrame(node: verificationIconNode, frame: iconFrame)
            }
        }
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let item = self.item, let peer = item.peer {
            item.setPeerIdWithRevealedOptions?(peer.id, nil)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let item = self.item, let peer = item.peer {
            item.setPeerIdWithRevealedOptions?(nil, peer.id)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption) {
        if let item = self.item, let peer = item.peer {
            item.deletePeer?(peer.id)
        }
        
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
    }
    
    override func layoutHeaderAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode) {
        let bounds = self.bounds
        accessoryItemNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -29.0), size: CGSize(width: bounds.size.width, height: 29.0))
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
}
