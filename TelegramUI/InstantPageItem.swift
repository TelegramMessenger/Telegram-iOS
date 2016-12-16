import Foundation
import TelegramCore

protocol InstantPageItem {
    var frame: CGRect { get set }
    var hasLinks: Bool { get }
    var wantsNode: Bool { get }
    var medias: [InstantPageMedia] { get }
    
    func matchesAnchor(_ anchor: String) -> Bool
    func drawInTile(context: CGContext)
    func node(account: Account) -> InstantPageNode?
    func matchesNode(_ node: InstantPageNode) -> Bool
    func linkSelectionViews() -> [InstantPageLinkSelectionView]
    
    func distanceThresholdGroup() -> Int?
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat
}
