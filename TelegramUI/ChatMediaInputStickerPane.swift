import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

final class ChatMediaInputStickerPane: ASDisplayNode {
    let gridNode: GridNode
    
    override init() {
        self.gridNode = GridNode()
        
        super.init()
        
        self.addSubnode(self.gridNode)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: size, insets: UIEdgeInsets(), preloadSize: 300.0, type: .fixed(itemSize: CGSize(width: 75.0, height: 75.0), lineSpacing: 0.0)), transition: .immediate), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        self.gridNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height))
    }
}
