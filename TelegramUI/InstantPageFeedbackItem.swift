import Foundation
import Postbox
import TelegramCore
import AsyncDisplayKit

final class InstantPageFeedbackItem: InstantPageItem {
    var frame: CGRect
    let wantsNode: Bool = true
    let medias: [InstantPageMedia] = []
    
    let webPage: TelegramMediaWebpage
    
    init(frame: CGRect, webPage: TelegramMediaWebpage) {
        self.frame = frame
        self.webPage = webPage
    }
    
    func node(account: Account, strings: PresentationStrings, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (Int, Int) -> Void, updateDetailsOpened: @escaping (Int, Bool) -> Void) -> (InstantPageNode & ASDisplayNode)? {
        return InstantPageFeedbackNode(account: account, strings: strings, theme: theme, webPage: self.webPage, openUrl: openUrl)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        if node is InstantPageFeedbackNode {
            return true
        }
        return false
    }
    
    func distanceThresholdGroup() -> Int? {
        return nil
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 0.0
    }
    
    func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
    
    func drawInTile(context: CGContext) {
    }
}
