import Foundation
import UIKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ContextUI

public final class InstantPageWebEmbedItem: InstantPageItem {
    public var frame: CGRect
    public let wantsNode: Bool = true
    public let separatesTiles: Bool = false
    public let medias: [InstantPageMedia] = []
    
    let url: String?
    let html: String?
    let enableScrolling: Bool
    
    init(frame: CGRect, url: String?, html: String?, enableScrolling: Bool) {
        self.frame = frame
        self.url = url
        self.html = html
        self.enableScrolling = enableScrolling
    }
    
    public func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourceLocation: InstantPageSourceLocation, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> InstantPageNode? {
        return InstantPageWebEmbedNode(frame: self.frame, url: self.url, html: self.html, enableScrolling: self.enableScrolling, updateWebEmbedHeight: updateWebEmbedHeight)
    }
    
    public func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    public func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPageWebEmbedNode {
            return self.url == node.url && self.html == node.html
        } else {
            return false
        }
    }
    
    public func distanceThresholdGroup() -> Int? {
        return 6
    }
    
    public func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        if count > 3 {
            return 1000.0
        } else {
            return CGFloat.greatestFiniteMagnitude
        }
    }
    
    public func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
    
    public func drawInTile(context: CGContext) {
    }
}
