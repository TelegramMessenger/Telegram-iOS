import Foundation
import Postbox
import TelegramCore

final class InstantPageWebEmbedItem: InstantPageItem {
    var frame: CGRect
    let wantsNode: Bool = true
    let medias: [InstantPageMedia] = []
    
    let url: String?
    let html: String?
    let enableScrolling: Bool
    
    init(frame: CGRect, url: String?, html: String?, enableScrolling: Bool) {
        self.frame = frame
        self.url = url
        self.html = html
        self.enableScrolling = enableScrolling
    }
    
    func node(account: Account, strings: PresentationStrings, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void) -> InstantPageNode? {
        return instantPageWebEmbedNode(frame: self.frame, url: self.url, html: self.html, enableScrolling: self.enableScrolling)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? instantPageWebEmbedNode {
            return self.url == node.url && self.html == node.html
        } else {
            return false
        }
    }
    
    func distanceThresholdGroup() -> Int? {
        return 3
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
