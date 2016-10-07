import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramCore

private let titleFont = Font.regular(20.0)
private let statusFont = Font.regular(14.0)

class ContactsVCardItem: ListViewItem {
    let account: Account
    let peer: Peer
    let action: (Peer) -> Void
    let selectable: Bool = true
    
    init(account: Account, peer: Peer, action: @escaping (Peer) -> Void) {
        self.account = account
        self.peer = peer
        self.action = action
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> Void) -> Void) {
        async {
            let node = ContactsVCardItemNode()
            let makeLayout = node.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(self.account, self.peer, width, previousItem != nil, nextItem != nil)
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            completion(node, {
                nodeApply()
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? ContactsVCardItemNode {
            Queue.mainQueue().async {
                let layout = node.asyncLayout()
                async {
                    let first = previousItem == nil
                    let last = nextItem == nil
                    
                    let (nodeLayout, apply) = layout(self.account, self.peer, width, first, last)
                    Queue.mainQueue().async {
                        completion(nodeLayout, {
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    func selected(listView: ListView) {
        self.action(self.peer)
    }
}

private let separatorHeight = 1.0 / UIScreen.main.scale

class ContactsVCardItemNode: ListViewItemNode {
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let avatarNode: AvatarNode
    private let titleNode: TextNode
    private let statusNode: TextNode
    
    private var account: Account?
    private var peer: Peer?
    private var avatarState: (Account, Peer)?
    
    required init() {
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
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.statusNode)
    }
    
    override func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let makeLayout = self.asyncLayout()
        let (nodeLayout, nodeApply) = makeLayout(self.account, self.peer, width, previousItem != nil, nextItem != nil)
        self.contentSize = nodeLayout.contentSize
        self.insets = nodeLayout.insets
        nodeApply()
    }
    
    private func updateBackgroundAndSeparatorsLayout(layout: ListViewItemNodeLayout) {
        self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -layout.insets.top - separatorHeight), size: CGSize(width: layout.size.width, height: layout.size.height + separatorHeight))
        self.separatorNode.frame = CGRect(origin: CGPoint(x: 65.0, y: layout.size.height - separatorHeight), size: CGSize(width: max(0.0, layout.size.width - 65.0), height: separatorHeight))
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        if highlighted {
            /*self.contentNode.displaysAsynchronously = false
             self.contentNode.backgroundColor = UIColor.clear
             self.contentNode.isOpaque = false*/
            
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
                                /*strongSelf.contentNode.backgroundColor = UIColor.white
                                 strongSelf.contentNode.isOpaque = true
                                 strongSelf.contentNode.displaysAsynchronously = true*/
                            }
                        }
                        })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                    /*self.contentNode.backgroundColor = UIColor.white
                     self.contentNode.isOpaque = true
                     self.contentNode.displaysAsynchronously = true*/
                }
            }
        }
    }
    
    func asyncLayout() -> (_ account: Account?, _ peer: Peer?, _ width: CGFloat, _ first: Bool, _ last: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        
        return { [weak self] account, peer, width, first, last in
            let leftInset: CGFloat = 91.0
            let rightInset: CGFloat = 10.0
            
            var titleAttributedString: NSAttributedString?
            var statusAttributedString: NSAttributedString?
            
            if let peer = peer {
                if let user = peer as? TelegramUser {
                    titleAttributedString = NSAttributedString(string: user.displayTitle, font: titleFont, textColor: UIColor.black)
                    
                    if let phone = user.phone {
                        statusAttributedString = NSAttributedString(string: formatPhoneNumber(phone), font: statusFont, textColor: UIColor(0xa6a6a6))
                    }
                } else if let group = peer as? TelegramGroup {
                    titleAttributedString = NSAttributedString(string: group.title, font: titleFont, textColor: UIColor.black)
                    statusAttributedString = NSAttributedString(string: "group", font: statusFont, textColor: UIColor(0xa6a6a6))
                } else if let channel = peer as? TelegramChannel {
                    titleAttributedString = NSAttributedString(string: channel.title, font: titleFont, textColor: UIColor.black)
                    statusAttributedString = NSAttributedString(string: "channel", font: statusFont, textColor: UIColor(0xa6a6a6))
                }
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(titleAttributedString, nil, 1, .end, CGSize(width: max(0.0, width - leftInset - rightInset), height: CGFloat.infinity), nil)
            
            let (statusLayout, statusApply) = makeStatusLayout(statusAttributedString, nil, 1, .end, CGSize(width: max(0.0, width - leftInset - rightInset), height: CGFloat.infinity), nil)
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: width, height: 78.0), insets: UIEdgeInsets())
            
            return (nodeLayout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.peer = peer
                    strongSelf.account = account
                    
                    if let peer = peer, let account = account, strongSelf.avatarState == nil || strongSelf.avatarState!.0 !== account || !strongSelf.avatarState!.1.isEqual(peer) {
                        strongSelf.avatarNode.setPeer(account: account, peer: peer)
                    }
                    
                    strongSelf.avatarNode.frame = CGRect(origin: CGPoint(x: 14.0, y: 6.0), size: CGSize(width: 60.0, height: 60.0))
                    
                    let _ = titleApply()
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 15.0), size: titleLayout.size)
                    
                    let _ = statusApply()
                    strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 40.0), size: statusLayout.size)
                    
                    strongSelf.updateBackgroundAndSeparatorsLayout(layout: nodeLayout)
                    strongSelf.separatorNode.isHidden = true
                }
            })
        }
    }
}
