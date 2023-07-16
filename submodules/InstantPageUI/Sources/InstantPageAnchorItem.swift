import Foundation
import UIKit
import TelegramCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ContextUI

public final class InstantPageAnchorItem: InstantPageItem {
    public let wantsNode: Bool = false
    public let separatesTiles: Bool = false
    public let medias: [InstantPageMedia] = []

    public let anchor: String
    public var frame: CGRect
    
    init(frame: CGRect, anchor: String) {
        self.frame = frame
        self.anchor = anchor
    }
    
    public func matchesAnchor(_ anchor: String) -> Bool {
        return anchor == self.anchor
    }
    
    public func drawInTile(context: CGContext) {
    }
    
    public func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourceLocation: InstantPageSourceLocation, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> InstantPageNode? {
        return nil
    }
    
    public func matchesNode(_ node: InstantPageNode) -> Bool {
        return false
    }
    
    public func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
    
    public func distanceThresholdGroup() -> Int? {
        return nil
    }
    
    public func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 0.0
    }
}
