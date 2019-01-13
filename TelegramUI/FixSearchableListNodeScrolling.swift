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

func fixNavigationSearchableListNodeScrolling(_ listNode: ListView, searchNode: NavigationBarSearchContentNode) -> Bool {
    if searchNode.expansionProgress > 0.0 && searchNode.expansionProgress < 1.0 {
        let scrollToItem: ListViewScrollToItem
        let targetProgress: CGFloat
        if searchNode.expansionProgress < 0.6 {
            scrollToItem = ListViewScrollToItem(index: 0, position: .top(-navigationBarSearchContentHeight), animated: true, curve: .Default(duration: 0.3), directionHint: .Up)
            targetProgress = 0.0
        } else {
            scrollToItem = ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: 0.3), directionHint: .Up)
            targetProgress = 1.0
        }
        searchNode.updateExpansionProgress(targetProgress, animated: true)
        
        listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: ListViewDeleteAndInsertOptions(), scrollToItem: scrollToItem, updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        return true
    }
    return false
}
