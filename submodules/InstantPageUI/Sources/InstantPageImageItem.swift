import Foundation
import UIKit
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

public final class InstantPageImageItem: InstantPageItem {
    public var frame: CGRect
    
    let webPage: TelegramMediaWebpage
    
    let media: InstantPageMedia
    let attributes: [InstantPageImageAttribute]
    
    public var medias: [InstantPageMedia] {
        return [self.media]
    }
    
    let interactive: Bool
    let roundCorners: Bool
    let fit: Bool
    
    public let wantsNode: Bool = true
    public let separatesTiles: Bool = false
    
    init(frame: CGRect, webPage: TelegramMediaWebpage, media: InstantPageMedia, attributes: [InstantPageImageAttribute] = [], interactive: Bool, roundCorners: Bool, fit: Bool) {
        self.frame = frame
        self.webPage = webPage
        self.media = media
        self.attributes = attributes
        self.interactive = interactive
        self.roundCorners = roundCorners
        self.fit = fit
    }
    
    public func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourceLocation: InstantPageSourceLocation, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> InstantPageNode? {
        return InstantPageImageNode(context: context, sourceLocation: sourceLocation, theme: theme, webPage: self.webPage, media: self.media, attributes: self.attributes, interactive: self.interactive, roundCorners: self.roundCorners, fit: self.fit, openMedia: openMedia, longPressMedia: longPressMedia, activatePinchPreview: activatePinchPreview, pinchPreviewFinished: pinchPreviewFinished)
    }
    
    public func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    public func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPageImageNode {
            return node.media == self.media
        } else {
            return false
        }
    }
    
    public func distanceThresholdGroup() -> Int? {
        return 1
    }
    
    public func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        if count > 3 {
            return 400.0
        } else {
            return CGFloat.greatestFiniteMagnitude
        }
    }
    
    public func drawInTile(context: CGContext) {
    }
    
    public func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
}
