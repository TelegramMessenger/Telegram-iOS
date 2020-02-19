import Foundation
import UIKit
import Display
import AsyncDisplayKit

final class ItemListMaskAccessoryItem: ListViewAccessoryItem {
    private let sectionId: Int32
    
    init(sectionId: Int32) {
        self.sectionId = sectionId
    }
    
    func isEqualToItem(_ other: ListViewAccessoryItem) -> Bool {
        if case let other as ItemListMaskAccessoryItem = other {
            return self.sectionId == other.sectionId
        }
        
        return false
    }
    
    func node(synchronous: Bool) -> ListViewAccessoryItemNode {
        let node = ItemListMaskAccessoryItemItemNode()
        node.frame = CGRect(origin: CGPoint(), size: CGSize(width: 38.0, height: 38.0))
        return node
    }
}

final class ItemListMaskAccessoryItemItemNode: ListViewAccessoryItemNode {
    let node: ASDisplayNode
    
    override init() {
        self.node = ASDisplayNode()
        self.node.backgroundColor = .red
        
        super.init()
        
        self.addSubnode(self.node)
    }
}
