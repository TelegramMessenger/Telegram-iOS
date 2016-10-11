import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

class PeerInfoAvatarAndNameItem: ListViewItem, PeerInfoItem {
    let account: Account
    let peer: Peer?
    let cachedData: CachedPeerData?
    let sectionId: PeerInfoItemSectionId
    let style: PeerInfoListStyle
    
    init(account: Account, peer: Peer?, cachedData: CachedPeerData?, sectionId: PeerInfoItemSectionId, style: PeerInfoListStyle) {
        self.account = account
        self.peer = peer
        self.cachedData = cachedData
        self.sectionId = sectionId
        self.style = style
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> Void) -> Void) {
        async {
            let node = PeerInfoAvatarAndNameItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, peerInfoItemNeighbors(item: self, topItem: previousItem as? PeerInfoItem, bottomItem: nextItem as? PeerInfoItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                apply()
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? PeerInfoAvatarAndNameItemNode {
            Queue.mainQueue().async {
                let makeLayout = node.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, width, peerInfoItemNeighbors(item: self, topItem: previousItem as? PeerInfoItem, bottomItem: nextItem as? PeerInfoItem))
                    Queue.mainQueue().async {
                        completion(layout, {
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool = true
    
    func selected(listView: ListView){
        
    }
}

private let nameFont = Font.medium(19.0)
private let statusFont = Font.regular(15.0)

class PeerInfoAvatarAndNameItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    private let avatarNode: AvatarNode
    private let nameNode: TextNode
    private let statusNode: TextNode
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.backgroundColor = UIColor(0xc8c7cc)
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.backgroundColor = UIColor(0xc8c7cc)
        self.bottomStripeNode.isLayerBacked = true
        
        self.avatarNode = AvatarNode(font: Font.regular(20.0))
        
        self.nameNode = TextNode()
        self.nameNode.isLayerBacked = true
        self.nameNode.contentMode = .left
        self.nameNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = TextNode()
        self.statusNode.isLayerBacked = true
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.nameNode)
        self.addSubnode(self.statusNode)
    }
    
    func asyncLayout() -> (_ item: PeerInfoAvatarAndNameItem, _ width: CGFloat, _ neighbors: PeerInfoItemNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let layoutNameNode = TextNode.asyncLayout(self.nameNode)
        let layoutStatusNode = TextNode.asyncLayout(self.statusNode)
        
        return { item, width, neighbors in
            let (nameNodeLayout, nameNodeApply) = layoutNameNode(NSAttributedString(string: item.peer?.displayTitle ?? "", font: nameFont, textColor: UIColor.black), nil, 1, .end, CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let statusText: String
            let statusColor: UIColor
            if let user = item.peer as? TelegramUser {
                statusText = "online"
                statusColor = UIColor(0x007ee5)
            } else if let channel = item.peer as? TelegramChannel {
                if let cachedChannelData = item.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount {
                    statusText = "\(memberCount) members"
                    statusColor = UIColor(0xb3b3b3)
                } else {
                    switch channel.info {
                        case .broadcast:
                            statusText = "channel"
                            statusColor = UIColor(0xb3b3b3)
                        case .group:
                            statusText = "group"
                            statusColor = UIColor(0xb3b3b3)
                    }
                }
            } else if let group = item.peer as? TelegramGroup {
                statusText = "\(group.participantCount) members"
                statusColor = UIColor(0xb3b3b3)
            } else {
                statusText = ""
                statusColor = UIColor.black
            }
            
            let (statusNodeLayout, statusNodeApply) = layoutStatusNode(NSAttributedString(string: statusText, font: statusFont, textColor: statusColor), nil, 1, .end, CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let separatorHeight = UIScreenPixel
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            switch item.style {
                case .plain:
                    contentSize = CGSize(width: width, height: 96.0)
                    insets = peerInfoItemNeighborsPlainInsets(neighbors)
                case .blocks:
                    contentSize = CGSize(width: width, height: 92.0)
                    let topInset: CGFloat
                    switch neighbors.top {
                        case .sameSection, .none:
                            topInset = 0.0
                        case .otherSection:
                            topInset = separatorHeight + 35.0
                    }
                    insets = UIEdgeInsets(top: topInset, left: 0.0, bottom: separatorHeight, right: 0.0)
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    let avatarOriginY: CGFloat
                    switch item.style {
                        case .plain:
                            avatarOriginY = 15.0
                            
                            if strongSelf.backgroundNode.supernode != nil {
                               strongSelf.backgroundNode.removeFromSupernode()
                            }
                            if strongSelf.topStripeNode.supernode != nil {
                                strongSelf.topStripeNode.removeFromSupernode()
                            }
                            if strongSelf.bottomStripeNode.supernode != nil {
                                strongSelf.bottomStripeNode.removeFromSupernode()
                            }
                        case .blocks:
                            avatarOriginY = 13.0
                            
                            if strongSelf.backgroundNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                            }
                            if strongSelf.topStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                            }
                            if strongSelf.bottomStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                            }
                            switch neighbors.top {
                                case .sameSection:
                                    strongSelf.topStripeNode.isHidden = true
                                case .none, .otherSection:
                                    strongSelf.topStripeNode.isHidden = false
                            }
                            
                            let bottomStripeInset: CGFloat
                            switch neighbors.bottom {
                                case .sameSection:
                                    bottomStripeInset = 16.0
                                case .none, .otherSection:
                                    bottomStripeInset = 0.0
                            }
                        
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -insets.top), size: CGSize(width: width, height: layoutSize.height))
                            strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -insets.top), size: CGSize(width: layoutSize.width, height: separatorHeight))
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: layoutSize.height - insets.top - separatorHeight), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    let _ = nameNodeApply()
                    let _ = statusNodeApply()
                    
                    if let peer = item.peer {
                        strongSelf.avatarNode.setPeer(account: item.account, peer: peer)
                    }
                    
                    strongSelf.avatarNode.frame = CGRect(origin: CGPoint(x: 15.0, y: avatarOriginY), size: CGSize(width: 66.0, height: 66.0))
                    strongSelf.nameNode.frame = CGRect(origin: CGPoint(x: 94.0, y: 25.0), size: nameNodeLayout.size)
                    
                    strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: 94.0, y: 25.0 + nameNodeLayout.size.height + 4.0), size: statusNodeLayout.size)
                }
            })
        }
    }
}
