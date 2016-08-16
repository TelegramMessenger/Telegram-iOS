import Foundation
import Display
import SwiftSignalKit
import AsyncDisplayKit
import Postbox

class SettingsAccountInfoItem: ListControllerGroupableItem {
    let account: Account
    let peer: Peer?
    let connectionStatus: ConnectionStatus
    
    init(account: Account, peer: Peer?, connectionStatus: ConnectionStatus) {
        self.account = account
        self.peer = peer
        self.connectionStatus = connectionStatus
    }
    
    func setupNode(async: (() -> Void) -> Void, completion: (ListControllerGroupableItemNode) -> Void) {
        async {
            let node = SettingsAccountInfoItemNode()
            completion(node)
        }
    }
}

private let nameFont = Font.medium(19.0)
private let statusFont = Font.regular(15.0)

class SettingsAccountInfoItemNode: ListControllerGroupableItemNode {
    let avatarNode: ChatListAvatarNode
    
    let nameNode: TextNode
    let statusNode: TextNode
    
    override init() {
        self.avatarNode = ChatListAvatarNode(font: Font.regular(20.0))
        
        self.nameNode = TextNode()
        self.nameNode.isLayerBacked = true
        self.nameNode.contentMode = .left
        self.nameNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = TextNode()
        self.statusNode.isLayerBacked = true
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        super.init()
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.nameNode)
        self.addSubnode(self.statusNode)
    }
    
    deinit {
    }
    
    override func asyncLayoutContent() -> (item: ListControllerGroupableItem, width: CGFloat) -> (CGSize, () -> Void) {
        let layoutNameNode = TextNode.asyncLayout(self.nameNode)
        let layoutStatusNode = TextNode.asyncLayout(self.statusNode)
        
        return { item, width in
            if let item = item as? SettingsAccountInfoItem {
                let (nameNodeLayout, nameNodeApply) = layoutNameNode(attributedString: NSAttributedString(string: item.peer?.displayTitle ?? "", font: nameFont, textColor: UIColor.black), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), cutout: nil)
                
                let statusText: String
                let statusColor: UIColor
                switch item.connectionStatus {
                    case .WaitingForNetwork:
                        statusText = "waiting for network"
                        statusColor = UIColor(0xb3b3b3)
                    case .Connecting:
                        statusText = "waiting for network"
                        statusColor = UIColor(0xb3b3b3)
                    case .Updating:
                        statusText = "updating"
                        statusColor = UIColor(0xb3b3b3)
                    case .Online:
                        statusText = "online"
                        statusColor = UIColor.blue
                }
                
                let (statusNodeLayout, statusNodeApply) = layoutStatusNode(attributedString: NSAttributedString(string: statusText, font: statusFont, textColor: statusColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), cutout: nil)
                
                return (CGSize(width: width, height: 97.0), { [weak self] in
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
            } else {
                return (CGSize(width: width, height: 0.0), {
                })
            }
        }
    }
    
    func setupWithAccount1(account: Account, peer: Peer?) {
        /*self.peerDisposable.set((account.postbox.peerWithId(account.peerId)
            |> deliverOnMainQueue).start(next: {[weak self] peer in
                if let strongSelf = self {
                    strongSelf.avatarNode.setPeer(account, peer: peer)
                    let width = strongSelf.bounds.size.width
                    if width > CGFloat(FLT_EPSILON) {
                        strongSelf.layoutContentForWidth(width)
                        strongSelf.nameNode.setNeedsDisplay()
                    }
                }
            }))
        self.connectingStatusDisposable.set((account.network.connectionStatus
            |> deliverOnMainQueue).start(next: { [weak self] status in
                if let strongSelf = self {
        
                    //strongSelf.statusNode.attributedString = NSAttributedString(string: statusText, font: statusFont, textColor: statusColor)
                    let width = strongSelf.bounds.size.width
                    if width > CGFloat(FLT_EPSILON) {
                        strongSelf.layoutContentForWidth(width)
                        strongSelf.statusNode.setNeedsDisplay()
                    }
                }
            }))*/
    }
}
