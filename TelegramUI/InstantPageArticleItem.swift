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
    let imageSize = CGSize(width: 44.0, height: 44.0)
    if cover != nil {
        sideInset += imageSize.width + 10.0
    }
    
    var availableLines: Int = 3
    
    var hasRTL = false
    var contentItems: [InstantPageItem] = []
    let (titleTextItem, titleItems, titleSize) = layoutTextItemWithString(title, boundingWidth: boundingWidth - inset - sideInset, offset: CGPoint(x: inset, y: 15.0), maxNumberOfLines: availableLines)
    contentItems.append(contentsOf: titleItems)
    
    if let textItem = titleTextItem {
        availableLines -= textItem.lines.count
        if textItem.containsRTL {
            textItem.alignment = .right
            hasRTL = true
        }
    }
    
    let (descriptionTextItem, descriptionItems, descriptionSize) = layoutTextItemWithString(description, boundingWidth: boundingWidth - inset - sideInset, offset: CGPoint(x: inset, y: 15.0 + titleSize.height + 14.0), maxNumberOfLines: 2)
    contentItems.append(contentsOf: descriptionItems)
    
    if let textItem = descriptionTextItem {
        if textItem.containsRTL || hasRTL {
            textItem.alignment = .right
            hasRTL = true
        }
    }
    
    let contentSize = CGSize(width: boundingWidth, height: titleSize.height + descriptionSize.height + 15.0 + 14.0 + 15.0)
    return InstantPageArticleItem(frame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: contentSize.height)), webPage: webPage, contentItems: contentItems, contentSize: contentSize, cover: cover, url: url, webpageId: webpageId, rtl: rtl || hasRTL)
}
