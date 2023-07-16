import Foundation
import UIKit
import TelegramCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ContextUI

public final class InstantPagePlayableVideoItem: InstantPageItem {
    public var frame: CGRect
    let webPage: TelegramMediaWebpage
    
    let media: InstantPageMedia
    public var medias: [InstantPageMedia] {
        return [self.media]
    }
    
    let interactive: Bool
    
    public let wantsNode: Bool = true
    public let separatesTiles: Bool = false
    
    init(frame: CGRect, webPage: TelegramMediaWebpage, media: InstantPageMedia, interactive: Bool) {
        self.frame = frame
        self.webPage = webPage
        self.media = media
        self.interactive = interactive
    }
    
    public func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourceLocation: InstantPageSourceLocation, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> InstantPageNode? {
        return InstantPagePlayableVideoNode(context: context, userLocation: sourceLocation.userLocation, webPage: self.webPage, theme: theme, media: self.media, interactive: self.interactive, openMedia: openMedia)
    }
    
    public func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    public func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPagePlayableVideoNode {
            return node.media == self.media
        } else {
            return false
        }
    }
    
    public func distanceThresholdGroup() -> Int? {
        return 2
    }
    
    public func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        if count > 3 {
            return 200.0
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

