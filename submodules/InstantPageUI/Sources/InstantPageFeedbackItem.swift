import Foundation
import UIKit
import TelegramCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ContextUI

public final class InstantPageFeedbackItem: InstantPageItem {
    public var frame: CGRect
    public let wantsNode: Bool = true
    public let separatesTiles: Bool = false
    public let medias: [InstantPageMedia] = []
    
    let webPage: TelegramMediaWebpage
    
    init(frame: CGRect, webPage: TelegramMediaWebpage) {
        self.frame = frame
        self.webPage = webPage
    }
    
    public func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourceLocation: InstantPageSourceLocation, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> InstantPageNode? {
        return InstantPageFeedbackNode(context: context, strings: strings, theme: theme, webPage: self.webPage, openUrl: openUrl)
    }
    
    public func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    public func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPageFeedbackNode, case let .Loaded(content) = node.webPage.content, case let .Loaded(updatedContent) = self.webPage.content, content.instantPage?.views == updatedContent.instantPage?.views {
            return true
        }
        return false
    }
    
    public func distanceThresholdGroup() -> Int? {
        return 8
    }
    
    public func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return CGFloat.greatestFiniteMagnitude
    }
    
    public func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
    
    public func drawInTile(context: CGContext) {
    }
}
