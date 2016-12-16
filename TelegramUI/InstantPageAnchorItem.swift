import Foundation
import TelegramCore

final class InstantPageAnchorItem: InstantPageItem {
    let hasLinks: Bool = false
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
    
    func node(account: Account) -> InstantPageNode? {
        return nil
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        return false
    }
    
    func linkSelectionViews() -> [InstantPageLinkSelectionView] {
        return []
    }
    
    func distanceThresholdGroup() -> Int? {
        return nil
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 0.0
    }
}
