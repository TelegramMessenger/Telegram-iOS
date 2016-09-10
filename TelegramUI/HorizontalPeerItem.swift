import Foundation
import Display
import Postbox
import AsyncDisplayKit
import TelegramCore

final class HorizontalPeerItem: ListViewItem {
    let account: Account
    let peer: Peer
    let action: (PeerId) -> Void
    
    init(account: Account, peer: Peer, action: @escaping (PeerId) -> Void) {
        self.account = account
        self.peer = peer
        self.action = action
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> Void) -> Void) {
        async {
            let node = HorizontalPeerItemNode()
            node.contentSize = CGSize(width: 92.0, height: 80.0)
            node.insets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            node.update(account: self.account, peer: self.peer)
            node.action = self.action
            completion(node, {
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        completion(ListViewItemNodeLayout(contentSize: node.contentSize, insets: node.insets), {
        })
    }
}

private final class HorizontalPeerItemNode: ListViewItemNode {
    private let avatarNode: AvatarNode
    private let titleNode: ASTextNode
    private var peer: Peer?
    fileprivate var action: ((PeerId) -> Void)?
    
    init() {
        self.avatarNode = AvatarNode(font: Font.regular(14.0))
        //self.avatarNode.transform = CATransform3DMakeRotation(CGFloat(M_PI / 2.0), 0.0, 0.0, 1.0)
        self.avatarNode.frame = CGRect(origin: CGPoint(x: floor((92.0 - 60.0) / 2.0), y: 4.0), size: CGSize(width: 60.0, height: 60.0))
        
        self.titleNode = ASTextNode()
        //self.titleNode.transform = CATransform3DMakeRotation(CGFloat(M_PI / 2.0), 0.0, 0.0, 1.0)
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.layer.sublayerTransform = CATransform3DMakeRotation(CGFloat(M_PI / 2.0), 0.0, 0.0, 1.0)
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func update(account: Account, peer: Peer) {
        self.peer = peer
        self.avatarNode.setPeer(account: account, peer: peer)
        self.titleNode.attributedText = NSAttributedString(string: peer.compactDisplayTitle, font: Font.regular(11.0), textColor: UIColor.black)
        let titleSize = self.titleNode.measure(CGSize(width: 84.0, height: CGFloat.infinity))
        self.titleNode.frame = CGRect(origin: CGPoint(x: floor((92.0 - titleSize.width) / 2.0), y: 4.0 + 60.0 + 6.0), size: titleSize)
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let peer = self.peer, let action = self.action {
                action(peer.id)
            }
        }
    }
}

