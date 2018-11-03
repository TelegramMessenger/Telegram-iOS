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
    let safeInset: CGFloat
    let rtl: Bool
    var initiallyExpanded: Bool
    let index: Int
    
    init(frame: CGRect, title: NSAttributedString, items: [InstantPageItem], safeInset: CGFloat, rtl: Bool, initiallyExpanded: Bool, index: Int) {
        self.frame = frame
        self.title = title
        self.items = items
        self.safeInset = safeInset
        self.rtl = rtl
        self.initiallyExpanded = initiallyExpanded
        self.index = index
    }
    
    func node(account: Account, strings: PresentationStrings, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void) -> (InstantPageNode & ASDisplayNode)? {
        return InstantPageDetailsNode(account: account, strings: strings, theme: theme, item: self, updateDetailsExpanded: updateDetailsExpanded)
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

func layoutDetailsItem(theme: InstantPageTheme, title: NSAttributedString, boundingWidth: CGFloat, items: [InstantPageItem], contentSize: CGSize, safeInset: CGFloat, rtl: Bool, initiallyExpanded: Bool, index: Int) -> InstantPageDetailsItem {
    return InstantPageDetailsItem(frame: CGRect(x: 0.0, y: 0.0, width: boundingWidth, height: contentSize.height + 44.0), title: title, items: items, safeInset: safeInset, rtl: rtl, initiallyExpanded: initiallyExpanded, index: index)
}
