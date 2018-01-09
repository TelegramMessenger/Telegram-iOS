import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox

final class ChatMultipleAvatarsNavigationNode: ASDisplayNode {
    private let multipleAvatarsNode: MultipleAvatarsNode
    
    private weak var account: Account?
    private var peers: [Peer] = []
    
    override init() {
        self.multipleAvatarsNode = MultipleAvatarsNode()
        
        super.init()
        
        self.addSubnode(self.multipleAvatarsNode)
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        if constrainedSize.height.isLessThanOrEqualTo(32.0) {
            return CGSize(width: 26.0, height: 26.0)
        } else {
            return CGSize(width: 37.0, height: 37.0)
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        if let account = self.account, !bounds.width.isZero {
            let avatarsLayout = MultipleAvatarsNode.asyncLayout(self.multipleAvatarsNode)
            let apply = avatarsLayout(account, self.peers, bounds.size)
            let _ = apply(false)
        }
        if self.bounds.size.height.isLessThanOrEqualTo(26.0) {
            self.multipleAvatarsNode.frame = bounds.offsetBy(dx: 8.0, dy: 0.0)
        } else {
            self.multipleAvatarsNode.frame = bounds.offsetBy(dx: 10.0, dy: 1.0)
        }
    }
    
    func setPeers(account: Account, peers: [Peer], animated: Bool) {
        self.account = account
        self.peers = peers
        
        let bounds = self.bounds
        if !bounds.width.isZero {
            let avatarsLayout = MultipleAvatarsNode.asyncLayout(self.multipleAvatarsNode)
            let apply = avatarsLayout(account, peers, bounds.size)
            let _ = apply(animated)
        }
    }
}

