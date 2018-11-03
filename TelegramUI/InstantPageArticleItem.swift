import Foundation
import Postbox
import TelegramCore
import AsyncDisplayKit

final class InstantPageArticleItem: InstantPageItem {
    var frame: CGRect
    let wantsNode: Bool = true
    let medias: [InstantPageMedia] = []
    let webPage: TelegramMediaWebpage
    
    let title: String
    let description: String
    let cover: TelegramMediaImage?
    let url: String
    let webpageId: MediaId
    
    init(frame: CGRect, webPage: TelegramMediaWebpage, title: String, description: String, cover: TelegramMediaImage?, url: String, webpageId: MediaId) {
        self.frame = frame
        self.webPage = webPage
        self.title = title
        self.description = description
        self.cover = cover
        self.url = url
        self.webpageId = webpageId
    }

    func node(account: Account, strings: PresentationStrings, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void) -> (InstantPageNode & ASDisplayNode)? {
        return InstantPageArticleNode(account: account, webPage: self.webPage, strings: strings, theme: theme, title: self.title, description: self.description, cover: self.cover, url: self.url, webpageId: self.webpageId, openUrl: openUrl)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPageArticleNode {
            return self.webpageId == node.webpageId
        } else {
            return false
        }
    }
    
    func distanceThresholdGroup() -> Int? {
        return 7
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
