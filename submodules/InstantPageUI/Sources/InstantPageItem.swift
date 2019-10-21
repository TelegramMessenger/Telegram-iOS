import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

protocol InstantPageItem {
    var frame: CGRect { get set }
    var wantsNode: Bool { get }
    var medias: [InstantPageMedia] { get }
    var separatesTiles: Bool { get }
    
    func matchesAnchor(_ anchor: String) -> Bool
    func drawInTile(context: CGContext)
    func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> (InstantPageNode & ASDisplayNode)?
    func matchesNode(_ node: InstantPageNode) -> Bool
    func linkSelectionRects(at point: CGPoint) -> [CGRect]
    
    func distanceThresholdGroup() -> Int?
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat
}
