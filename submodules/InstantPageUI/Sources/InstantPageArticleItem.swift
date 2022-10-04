import Foundation
import UIKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ContextUI

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
    let hasRTL: Bool
    
    init(frame: CGRect, webPage: TelegramMediaWebpage, contentItems: [InstantPageItem], contentSize: CGSize, cover: TelegramMediaImage?, url: String, webpageId: MediaId, rtl: Bool, hasRTL: Bool) {
        self.frame = frame
        self.webPage = webPage
        self.contentItems = contentItems
        self.contentSize = contentSize
        self.cover = cover
        self.url = url
        self.webpageId = webpageId
        self.rtl = rtl
        self.hasRTL = hasRTL
    }

    func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourcePeerType: MediaAutoDownloadPeerType, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> InstantPageNode? {
        return InstantPageArticleNode(context: context, item: self, webPage: self.webPage, strings: strings, theme: theme, contentItems: self.contentItems, contentSize: self.contentSize, cover: self.cover, url: self.url, webpageId: self.webpageId, openUrl: openUrl)
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
    let imageSpacing: CGFloat = 10.0
    var sideInset = inset
    let imageSize = CGSize(width: 44.0, height: 44.0)
    if cover != nil {
        sideInset += imageSize.width + imageSpacing
    }
    
    var availableLines: Int = 3
    var contentHeight: CGFloat = 15.0 * 2.0
    
    var hasRTL = false
    var contentItems: [InstantPageItem] = []
    let (titleTextItem, titleItems, titleSize) = layoutTextItemWithString(title, boundingWidth: boundingWidth - inset - sideInset, offset: CGPoint(x: inset, y: 15.0), maxNumberOfLines: availableLines)
    contentItems.append(contentsOf: titleItems)
    contentHeight += titleSize.height
    
    if let textItem = titleTextItem {
        availableLines -= textItem.lines.count
        if textItem.containsRTL {
            hasRTL = true
        }
    }
    var descriptionInset = inset
    if hasRTL && cover != nil {
        descriptionInset += imageSize.width + imageSpacing
        for var item in titleItems {
            item.frame = item.frame.offsetBy(dx: imageSize.width + imageSpacing, dy: 0.0)
        }
    }
    
    if availableLines > 0 {
        let (descriptionTextItem, descriptionItems, descriptionSize) = layoutTextItemWithString(description, boundingWidth: boundingWidth - inset - sideInset, alignment: hasRTL ? .right : .natural, offset: CGPoint(x: descriptionInset, y: 15.0 + titleSize.height + 14.0), maxNumberOfLines: availableLines)
        contentItems.append(contentsOf: descriptionItems)
        
        if let textItem = descriptionTextItem {
            if textItem.containsRTL || hasRTL {
                hasRTL = true
            }
        }
        contentHeight += descriptionSize.height + 14.0
    }
    
    let contentSize = CGSize(width: boundingWidth, height: contentHeight)
    return InstantPageArticleItem(frame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: contentSize.height)), webPage: webPage, contentItems: contentItems, contentSize: contentSize, cover: cover, url: url, webpageId: webpageId, rtl: rtl || hasRTL, hasRTL: hasRTL)
}
