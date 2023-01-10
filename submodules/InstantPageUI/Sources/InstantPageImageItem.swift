import Foundation
import UIKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ContextUI

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
    
    func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourcePeerType: MediaAutoDownloadPeerType, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> InstantPageNode? {
        return InstantPageImageNode(context: context, sourcePeerType: sourcePeerType, theme: theme, webPage: self.webPage, media: self.media, attributes: self.attributes, interactive: self.interactive, roundCorners: self.roundCorners, fit: self.fit, openMedia: openMedia, longPressMedia: longPressMedia, activatePinchPreview: activatePinchPreview, pinchPreviewFinished: pinchPreviewFinished)
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
