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

enum ContactsPeerItemStatus {
    case none
    case presence(PeerPresence)
    case addressName
}

class ContactsPeerItem: ListViewItem {
    let account: Account
    let peer: Peer?
    let status: ContactsPeerItemStatus
    let action: (Peer) -> Void
    let selectable: Bool = true
    
    let headerAccessoryItem: ListViewAccessoryItem?
    
    let header: ListViewItemHeader?
    
    init(account: Account, peer: Peer?, status: ContactsPeerItemStatus, index: PeerNameIndex?, header: ListViewItemHeader?, action: @escaping (Peer) -> Void) {
        self.account = account
        self.peer = peer
        self.status = status
        self.action = action
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
            self.headerAccessoryItem = ContactsSectionHeaderAccessoryItem(sectionHeader: .letter(letter))
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
            
            completion(node, nodeApply)
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
                            apply().1()
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

class ContactsPeerItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let avatarNode: AvatarNode
    private let titleNode: TextNode
    private let statusNode: TextNode
    
    private var avatarState: (Account, Peer?)?
    
    private var peerPresenceManager: PeerPresenceStatusManager?
    private var layoutParams: (ContactsPeerItem, CGFloat, Bool, Bool, Bool)?
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = .white
        self.backgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = UIColor(0xc8c7cc)
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = UIColor(0xd9d9d9)
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.avatarNode = AvatarNode(font: Font.regular(15.0))
        self.avatarNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.statusNode = TextNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.statusNode)
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let layoutParams = strongSelf.layoutParams {
                let (_, apply) = strongSelf.asyncLayout()(layoutParams.0, layoutParams.1, layoutParams.2, layoutParams.3, layoutParams.4)
                apply()
            }
        })
    }
    
    override func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let (item, _, _, _, _) = self.layoutParams {
            let (first, last, firstWithHeader) = ContactsPeerItem.mergeType(item: item as! ContactsPeerItem, previousItem: previousItem, nextItem: nextItem)
            self.layoutParams = (item, width, first, last, firstWithHeader)
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, width, first, last, firstWithHeader)
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            nodeApply()
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        if highlighted {
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
    
    func asyncLayout() -> (_ item: ContactsPeerItem, _ width: CGFloat, _ first: Bool, _ last: Bool, _ firstWithHeader: Bool) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, () -> Void)) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        
        return { [weak self] item, width, first, last, firstWithHeader in
            let leftInset: CGFloat = 65.0
            let rightInset: CGFloat = 10.0
            
            var titleAttributedString: NSAttributedString?
            var statusAttributedString: NSAttributedString?
            var userPresence: TelegramUserPresence?
            
            if let peer = item.peer {
                if let user = peer as? TelegramUser {
                    if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                        let string = NSMutableAttributedString()
                        string.append(NSAttributedString(string: firstName, font: titleFont, textColor: .black))
                        string.append(NSAttributedString(string: " ", font: titleFont, textColor: .black))
                        string.append(NSAttributedString(string: lastName, font: titleBoldFont, textColor: .black))
                        titleAttributedString = string
                    } else if let firstName = user.firstName, !firstName.isEmpty {
                        titleAttributedString = NSAttributedString(string: firstName, font: titleBoldFont, textColor: UIColor.black)
                    } else if let lastName = user.lastName, !lastName.isEmpty {
                        titleAttributedString = NSAttributedString(string: lastName, font: titleBoldFont, textColor: UIColor.black)
                    } else {
                        titleAttributedString = NSAttributedString(string: "Deleted User", font: titleBoldFont, textColor: UIColor(0xa6a6a6))
                    }
                } else if let group = peer as? TelegramGroup {
                    titleAttributedString = NSAttributedString(string: group.title, font: titleBoldFont, textColor: UIColor.black)
                } else if let channel = peer as? TelegramChannel {
                    titleAttributedString = NSAttributedString(string: channel.title, font: titleBoldFont, textColor: UIColor.black)
                }
                
                switch item.status {
                    case .none:
                        break
                    case let .presence(presence):
                        if let presence = presence as? TelegramUserPresence {
                            userPresence = presence
                            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                            let (string, activity) = stringAndActivityForUserPresence(presence, relativeTo: Int32(timestamp))
                            statusAttributedString = NSAttributedString(string: string, font: statusFont, textColor: activity ? UIColor(0x007ee5) : UIColor(0xa6a6a6))
                        }
                    case .addressName:
                        if let addressName = peer.addressName {
                            statusAttributedString = NSAttributedString(string: "@" + addressName, font: statusFont, textColor: UIColor(0xa6a6a6))
                        }
                }
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(titleAttributedString, nil, 1, .end, CGSize(width: max(0.0, width - leftInset - rightInset), height: CGFloat.infinity), nil)
            
            let (statusLayout, statusApply) = makeStatusLayout(statusAttributedString, nil, 1, .end, CGSize(width: max(0.0, width - leftInset - rightInset), height: CGFloat.infinity), nil)
            
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
                    
                    return (strongSelf.avatarNode.ready, { [weak strongSelf] in
                        if let strongSelf = strongSelf {
                            strongSelf.layoutParams = (item, width, first, last, firstWithHeader)
                            
                            strongSelf.avatarNode.frame = CGRect(origin: CGPoint(x: 14.0, y: 4.0), size: CGSize(width: 40.0, height: 40.0))
                            
                            let _ = titleApply()
                            strongSelf.titleNode.frame = titleFrame
                            
                            let _ = statusApply()
                            strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 25.0), size: statusLayout.size)
                            
                            let topHighlightInset: CGFloat = first ? 0.0 : separatorHeight
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: nodeLayout.contentSize.width, height: nodeLayout.contentSize.height))
                            strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - topHighlightInset), size: CGSize(width: nodeLayout.size.width, height: nodeLayout.size.height + topHighlightInset))
                            strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: 65.0, y: nodeLayout.contentSize.height - separatorHeight), size: CGSize(width: max(0.0, nodeLayout.size.width - 65.0), height: separatorHeight))
                            strongSelf.separatorNode.isHidden = last
                            
                            if let userPresence = userPresence {
                                strongSelf.peerPresenceManager?.reset(presence: userPresence)
                            }
                        }
                    })
                } else {
                    return (nil, {})
                }
            })
        }
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
