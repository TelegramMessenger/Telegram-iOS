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
    
    init(account: Account, peer: Peer?, cachedData: CachedPeerData?, sectionId: PeerInfoItemSectionId) {
        self.account = account
        self.peer = peer
        self.cachedData = cachedData
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> Void) -> Void) {
        async {
            let node = PeerInfoAvatarAndNameItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, peerInfoItemInsets(item: self, topItem: previousItem as? PeerInfoItem, bottomItem: nextItem as? PeerInfoItem))
            
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
                    let (layout, apply) = makeLayout(self, width, peerInfoItemInsets(item: self, topItem: previousItem as? PeerInfoItem, bottomItem: nextItem as? PeerInfoItem))
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
    let avatarNode: AvatarNode
    
    let nameNode: TextNode
    let statusNode: TextNode
    
    init() {
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
    
    func asyncLayout() -> (_ item: PeerInfoAvatarAndNameItem, _ width: CGFloat, _ insets: UIEdgeInsets) -> (ListViewItemNodeLayout, () -> Void) {
        let layoutNameNode = TextNode.asyncLayout(self.nameNode)
        let layoutStatusNode = TextNode.asyncLayout(self.statusNode)
        
        return { item, width, insets in
            let (nameNodeLayout, nameNodeApply) = layoutNameNode(NSAttributedString(string: item.peer?.displayTitle ?? "", font: nameFont, textColor: UIColor.black), nil, 1, .end, CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let statusText: String
            let statusColor: UIColor
            if let user = item.peer as? TelegramUser {
                statusText = "online"
                statusColor = UIColor(0x1195f2)
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
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: width, height: 96.0), insets: insets), { [weak self] in
                if let strongSelf = self {
                    let _ = nameNodeApply()
                    let _ = statusNodeApply()
                    
                    if let peer = item.peer {
                        strongSelf.avatarNode.setPeer(account: item.account, peer: peer)
                    }
                    
                    strongSelf.avatarNode.frame = CGRect(origin: CGPoint(x: 15.0, y: 15.0), size: CGSize(width: 66.0, height: 66.0))
                    strongSelf.nameNode.frame = CGRect(origin: CGPoint(x: 94.0, y: 25.0), size: nameNodeLayout.size)
                    
                    
                    strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: 94.0, y: 25.0 + nameNodeLayout.size.height + 4.0), size: statusNodeLayout.size)
                }
            })
        }
    }
}
