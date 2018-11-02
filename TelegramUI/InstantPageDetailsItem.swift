import Foundation
import Postbox
import TelegramCore
import AsyncDisplayKit

final class InstantPageDetailsItem: InstantPageItem {
    var frame: CGRect
    let wantsNode: Bool = true
    let medias: [InstantPageMedia] = []

    let title: NSAttributedString
    let items: [InstantPageItem]
    let rtl: Bool
    
    init(frame: CGRect, title: NSAttributedString, items: [InstantPageItem], rtl: Bool) {
        self.frame = frame
        self.title = title
        self.items = items
        self.rtl = rtl
    }
    
    func node(account: Account, strings: PresentationStrings, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (Int, Int) -> Void) -> (InstantPageNode & ASDisplayNode)? {
        return InstantPageDetailsNode(account: account, strings: strings, theme: theme, item: self)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPageDetailsNode {
            return self === node.item
        } else {
            return false
        }
    }
    
    func distanceThresholdGroup() -> Int? {
        return 8
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        if count > 3 {
            return 1000.0
        } else {
            return CGFloat.greatestFiniteMagnitude
        }
    }
    
    func drawInTile(context: CGContext) {
    }
    
    func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
}

func layoutDetailsItem(theme: InstantPageTheme, title: NSAttributedString, boundingWidth: CGFloat, items: [InstantPageItem], contentSize: CGSize, open: Bool, rtl: Bool) -> InstantPageDetailsItem {
    for var item in items {
        item.frame = item.frame.offsetBy(dx: 0.0, dy: 44.0)
    }
    return InstantPageDetailsItem(frame: CGRect(x: 0.0, y: 0.0, width: boundingWidth, height: 44.0), title: title, items: items, rtl: rtl)
}
