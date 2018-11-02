import Foundation
import Postbox
import TelegramCore
import AsyncDisplayKit

protocol InstantPageImageAttribute {
}

struct InstantPageMapAttribute: InstantPageImageAttribute {
    let zoom: Int32
    let dimensions: CGSize
}

final class InstantPageImageItem: InstantPageItem {
    var frame: CGRect
    
    let webPage: TelegramMediaWebpage
    let url: InstantPageUrlItem?
    
    let media: InstantPageMedia
    let attributes: [InstantPageImageAttribute]
    
    var medias: [InstantPageMedia] {
        return [self.media]
    }
    
    let interactive: Bool
    let roundCorners: Bool
    let fit: Bool
    
    let wantsNode: Bool = true
    
    init(frame: CGRect, webPage: TelegramMediaWebpage, media: InstantPageMedia, attributes: [InstantPageImageAttribute] = [], url: InstantPageUrlItem? = nil, interactive: Bool, roundCorners: Bool, fit: Bool) {
        self.frame = frame
        self.webPage = webPage
        self.media = media
        self.attributes = attributes
        self.url = url
        self.interactive = interactive
        self.roundCorners = roundCorners
        self.fit = fit
    }
    
    func node(account: Account, strings: PresentationStrings, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (Int, Int) -> Void) -> (InstantPageNode & ASDisplayNode)? {
        return InstantPageImageNode(account: account, webPage: self.webPage, media: self.media, attributes: self.attributes, url: self.url, interactive: self.interactive, roundCorners: self.roundCorners, fit: self.fit, openMedia: openMedia, openUrl: openUrl)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPageImageNode {
            return node.media == self.media
        } else {
            return false
        }
    }
    
    func distanceThresholdGroup() -> Int? {
        return 1
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        if count > 3 {
            return 400.0
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
