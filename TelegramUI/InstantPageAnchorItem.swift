import Foundation
import Postbox
import TelegramCore

final class InstantPageAnchorItem: InstantPageItem {
    let wantsNode: Bool = false
    let medias: [InstantPageMedia] = []

    let anchor: String
    var frame: CGRect
    
    init(frame: CGRect, anchor: String) {
        self.frame = frame
        self.anchor = anchor
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return anchor == self.anchor
    }
    
    func drawInTile(context: CGContext) {
    }
    
    func node(account: Account, strings: PresentationStrings, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void) -> InstantPageNode? {
        return nil
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        return false
    }
    
    func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
    
    func distanceThresholdGroup() -> Int? {
        return nil
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 0.0
    }
}
