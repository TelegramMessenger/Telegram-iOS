import Foundation
import UIKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ContextUI

final class InstantPageFeedbackItem: InstantPageItem {
    var frame: CGRect
    let wantsNode: Bool = true
    let separatesTiles: Bool = false
    let medias: [InstantPageMedia] = []
    
    let webPage: TelegramMediaWebpage
    
    init(frame: CGRect, webPage: TelegramMediaWebpage) {
        self.frame = frame
        self.webPage = webPage
    }
    
    func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourcePeerType: MediaAutoDownloadPeerType, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> InstantPageNode? {
        return InstantPageFeedbackNode(context: context, strings: strings, theme: theme, webPage: self.webPage, openUrl: openUrl)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPageFeedbackNode, case let .Loaded(content) = node.webPage.content, case let .Loaded(updatedContent) = self.webPage.content, content.instantPage?.views == updatedContent.instantPage?.views {
            return true
        }
        return false
    }
    
    func distanceThresholdGroup() -> Int? {
        return 8
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return CGFloat.greatestFiniteMagnitude
    }
    
    func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
    
    func drawInTile(context: CGContext) {
    }
}
