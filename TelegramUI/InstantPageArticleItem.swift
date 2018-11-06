import Foundation
import Postbox
import TelegramCore
import AsyncDisplayKit

final class InstantPageArticleItem: InstantPageItem {
    var frame: CGRect
    let wantsNode: Bool = true
    let separatesTiles: Bool = false
    let medias: [InstantPageMedia] = []
    let webPage: TelegramMediaWebpage
    
    let contentItems: [InstantPageItem]
    let contentSize: CGSize
    let cover: TelegramMediaImage?
    let url: String
    let webpageId: MediaId
    let rtl: Bool
    
    init(frame: CGRect, webPage: TelegramMediaWebpage, contentItems: [InstantPageItem], contentSize: CGSize, cover: TelegramMediaImage?, url: String, webpageId: MediaId, rtl: Bool) {
        self.frame = frame
        self.webPage = webPage
        self.contentItems = contentItems
        self.contentSize = contentSize
        self.cover = cover
        self.url = url
        self.webpageId = webpageId
        self.rtl = rtl
    }

    func node(account: Account, strings: PresentationStrings, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> (InstantPageNode & ASDisplayNode)? {
        return InstantPageArticleNode(account: account, item: self, webPage: self.webPage, strings: strings, theme: theme, contentItems: self.contentItems, contentSize: self.contentSize, cover: self.cover, url: self.url, webpageId: self.webpageId, rtl: self.rtl, openUrl: openUrl)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPageArticleNode {
            return self === node.item
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

func layoutArticleItem(theme: InstantPageTheme, webPage: TelegramMediaWebpage, title: NSAttributedString, description: NSAttributedString, cover: TelegramMediaImage?, url: String, webpageId: MediaId, boundingWidth: CGFloat, rtl: Bool) -> InstantPageArticleItem {
    let inset: CGFloat = 17.0
    var sideInset = inset
    let imageSize = CGSize(width: 65.0, height: 65.0)
    if cover != nil {
        sideInset += imageSize.width + 10.0
    }
    
    var contentItems: [InstantPageItem] = []
    let (titleItems, titleSize) = layoutTextItemWithString(title, boundingWidth: boundingWidth - inset - sideInset, offset: CGPoint(x: inset, y: 20.0), maxNumberOfLines: 2)
    contentItems.append(contentsOf: titleItems)
    
    let (descriptionItems, descriptionSize) = layoutTextItemWithString(description, boundingWidth: boundingWidth - inset - sideInset, offset: CGPoint(x: inset, y: 20.0 + titleSize.height + 14.0), maxNumberOfLines: 2)
    contentItems.append(contentsOf: descriptionItems)
    
    var hasRTL = false
    for case let item as InstantPageTextItem in contentItems {
        if item.containsRTL {
            hasRTL = true
            break
        }
    }
    
    let contentSize = CGSize(width: boundingWidth, height: max(93.0, titleSize.height + descriptionSize.height + 20.0 + 14.0 + 20.0))
    return InstantPageArticleItem(frame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: contentSize.height)), webPage: webPage, contentItems: contentItems, contentSize: contentSize, cover: cover, url: url, webpageId: webpageId, rtl: rtl || hasRTL)
}
