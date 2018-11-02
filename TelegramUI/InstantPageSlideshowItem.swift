import Foundation
import Postbox
import TelegramCore
import AsyncDisplayKit

final class InstantPageSlideshowItem: InstantPageItem {
    var frame: CGRect
    let webPage: TelegramMediaWebpage
    let wantsNode: Bool = true
    let medias: [InstantPageMedia]
    
    init(frame: CGRect, webPage: TelegramMediaWebpage, medias: [InstantPageMedia]) {
        self.frame = frame
        self.webPage = webPage
        self.medias = medias
    }
    
    func node(account: Account, strings: PresentationStrings, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (Int, Int) -> Void, updateDetailsOpened: @escaping (Int, Bool) -> Void) -> (InstantPageNode & ASDisplayNode)? {
        return InstantPageSlideshowNode(account: account, theme: theme, webPage: webPage, medias: self.medias, openMedia: openMedia)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPageSlideshowNode {
            return self.medias == node.medias
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

