import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import TelegramPresentationData

protocol PeerInfoScreenItem: AnyObject {
    var id: AnyHashable { get }
    func node() -> PeerInfoScreenItemNode
}

class PeerInfoScreenItemNode: ASDisplayNode, AccessibilityFocusableNode {
    var bringToFrontForHighlight: (() -> Void)?
    
    func update(context: AccountContext, width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        preconditionFailure()
    }
    
    override open func accessibilityElementDidBecomeFocused() {
//        (self.supernode as? ListView)?.ensureItemNodeVisible(self, animated: false, overflow: 22.0)
    }
}
