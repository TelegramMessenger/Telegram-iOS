import Foundation
import AsyncDisplayKit
import Display

func fixSearchableListNodeScrolling(_ listNode: ListView) {
    var searchItemNode: ListViewItemNode?
    var nextItemNode: ListViewItemNode?
    
    listNode.forEachItemNode({ itemNode in
        if let itemNode = itemNode as? ChatListSearchItemNode {
            searchItemNode = itemNode
        } else if searchItemNode != nil && nextItemNode == nil {
            nextItemNode = itemNode as? ListViewItemNode
        }
    })
    
    if let searchItemNode = searchItemNode {
        let itemFrame = searchItemNode.apparentFrame
        if itemFrame.contains(CGPoint(x: 0.0, y: listNode.insets.top)) {
            if itemFrame.minY + itemFrame.height * 0.6 < listNode.insets.top {
                if let nextItemNode = nextItemNode {
                    listNode.ensureItemNodeVisibleAtTopInset(nextItemNode)
                }
            } else {
                listNode.ensureItemNodeVisibleAtTopInset(searchItemNode)
            }
        }
    }
}
