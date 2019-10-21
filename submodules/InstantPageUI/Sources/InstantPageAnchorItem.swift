import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

final class InstantPageAnchorItem: InstantPageItem {
    let wantsNode: Bool = false
    let separatesTiles: Bool = false
    let medias: [InstantPageMedia] = []

    let anchor: String
    var frame: CGRect
    
    init(frame: CGRect, anchor: String) {
        self.frame = frame
        self.anchor = anchor
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return anchor == self.anchor
    }
    
    func drawInTile(context: CGContext) {
    }
    
    func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> (InstantPageNode & ASDisplayNode)? {
        return nil
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        return false
    }
    
    func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
    
    func distanceThresholdGroup() -> Int? {
        return nil
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 0.0
    }
}
