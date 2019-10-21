import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

protocol InstantPageImageAttribute {
}

struct InstantPageMapAttribute: InstantPageImageAttribute {
    let zoom: Int32
    let dimensions: CGSize
}

final class InstantPageImageItem: InstantPageItem {
    var frame: CGRect
    
    let webPage: TelegramMediaWebpage
    
    let media: InstantPageMedia
    let attributes: [InstantPageImageAttribute]
    
    var medias: [InstantPageMedia] {
        return [self.media]
    }
    
    let interactive: Bool
    let roundCorners: Bool
    let fit: Bool
    
    let wantsNode: Bool = true
    let separatesTiles: Bool = false
    
    init(frame: CGRect, webPage: TelegramMediaWebpage, media: InstantPageMedia, attributes: [InstantPageImageAttribute] = [], interactive: Bool, roundCorners: Bool, fit: Bool) {
        self.frame = frame
        self.webPage = webPage
        self.media = media
        self.attributes = attributes
        self.interactive = interactive
        self.roundCorners = roundCorners
        self.fit = fit
    }
    
    func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> (InstantPageNode & ASDisplayNode)? {
        return InstantPageImageNode(context: context, theme: theme, webPage: self.webPage, media: self.media, attributes: self.attributes, interactive: self.interactive, roundCorners: self.roundCorners, fit: self.fit, openMedia: openMedia, longPressMedia: longPressMedia)
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
