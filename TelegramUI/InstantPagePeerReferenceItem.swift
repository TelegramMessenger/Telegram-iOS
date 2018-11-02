import Foundation
import Postbox
import TelegramCore
import AsyncDisplayKit

final class InstantPagePeerReferenceItem: InstantPageItem {
    var frame: CGRect
    let wantsNode: Bool = true
    let medias: [InstantPageMedia] = []
    
    let initialPeer: Peer
    let rtl: Bool
    
    init(frame: CGRect, initialPeer: Peer, rtl: Bool) {
        self.frame = frame
        self.initialPeer = initialPeer
        self.rtl = rtl
    }
    
    func node(account: Account, strings: PresentationStrings, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (Int, Int) -> Void) -> (InstantPageNode & ASDisplayNode)? {
        return InstantPagePeerReferenceNode(account: account, strings: strings, theme: theme, initialPeer: self.initialPeer, rtl: self.rtl, openPeer: openPeer)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPagePeerReferenceNode {
            return self.initialPeer.id == node.initialPeer.id
        } else {
            return false
        }
    }
    
    func distanceThresholdGroup() -> Int? {
        return 5
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        if count > 3 {
            return 1000.0
        } else {
            return CGFloat.greatestFiniteMagnitude
        }
    }
    
    func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
    
    func drawInTile(context: CGContext) {
    }
}
