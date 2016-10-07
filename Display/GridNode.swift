import Foundation
import AsyncDisplayKit

public struct GridNodeInsertItem {
    public let index: Int
    public let item: GridItem
    public let previousIndex: Int?
    
    public init(index: Int, item: GridItem, previousIndex: Int?) {
        self.index = index
        self.item = item
        self.previousIndex = previousIndex
    }
}

public struct GridNodeUpdateItem {
    public let index: Int
    public let item: GridItem
    
    public init(index: Int, item: GridItem) {
        self.index = index
        self.item = item
    }
}

public enum GridNodeScrollToItemPosition {
    case top
    case bottom
    case center
}

public struct GridNodeScrollToItem {
    public let index: Int
    public let position: GridNodeScrollToItemPosition
    
    public init(index: Int, position: GridNodeScrollToItemPosition) {
        self.index = index
        self.position = position
    }
}

public struct GridNodeLayout: Equatable {
    public let size: CGSize
    public let insets: UIEdgeInsets
    public let preloadSize: CGFloat
    public let itemSize: CGSize
    public let indexOffset: Int
    
    public init(size: CGSize, insets: UIEdgeInsets, preloadSize: CGFloat, itemSize: CGSize, indexOffset: Int) {
        self.size = size
        self.insets = insets
        self.preloadSize = preloadSize
        self.itemSize = itemSize
        self.indexOffset = indexOffset
    }
    
    public static func ==(lhs: GridNodeLayout, rhs: GridNodeLayout) -> Bool {
        return lhs.size.equalTo(rhs.size) && lhs.insets == rhs.insets && lhs.preloadSize.isEqual(to: rhs.preloadSize) && lhs.itemSize.equalTo(rhs.itemSize) && lhs.indexOffset == rhs.indexOffset
    }
}

public struct GridNodeUpdateLayout {
    public let layout: GridNodeLayout
    public let transition: ContainedViewLayoutTransition
    
    public init(layout: GridNodeLayout, transition: ContainedViewLayoutTransition) {
        self.layout = layout
        self.transition = transition
    }
}

/*private func binarySearch(_ inputArr: [GridNodePresentationItem], searchItem: CGFloat) -> Int? {
    if inputArr.isEmpty {
        return nil
    }
    
    var lowerPosition = inputArr[0].frame.origin.y + inputArr[0].frame.size.height
    var upperPosition = inputArr[inputArr.count - 1].frame.origin.y
    
    if lowerPosition > upperPosition {
        return nil
    }
    
    while (true) {
        let currentPosition = (lowerIndex + upperIndex) / 2
        if (inputArr[currentIndex] == searchItem) {
            return currentIndex
        } else if (lowerIndex > upperIndex) {
            return nil
        } else {
            if (inputArr[currentIndex] > searchItem) {
                upperIndex = currentIndex - 1
            } else {
                lowerIndex = currentIndex + 1
            }
        }
    }
}*/

public struct GridNodeTransaction {
    public let deleteItems: [Int]
    public let insertItems: [GridNodeInsertItem]
    public let updateItems: [GridNodeUpdateItem]
    public let scrollToItem: GridNodeScrollToItem?
    public let updateLayout: GridNodeUpdateLayout?
    public let stationaryItemRange: (Int, Int)?
    
    public init(deleteItems: [Int], insertItems: [GridNodeInsertItem], updateItems: [GridNodeUpdateItem], scrollToItem: GridNodeScrollToItem?, updateLayout: GridNodeUpdateLayout?, stationaryItemRange: (Int, Int)?) {
        self.deleteItems = deleteItems
        self.insertItems = insertItems
        self.updateItems = updateItems
        self.scrollToItem = scrollToItem
        self.updateLayout = updateLayout
        self.stationaryItemRange = stationaryItemRange
    }
}

private struct GridNodePresentationItem {
    let index: Int
    let frame: CGRect
}

private struct GridNodePresentationLayout {
    let layout: GridNodeLayout
    let contentOffset: CGPoint
    let contentSize: CGSize
    let items: [GridNodePresentationItem]
}

private final class GridNodeItemLayout {
    let contentSize: CGSize
    let items: [GridNodePresentationItem]
    
    init(contentSize: CGSize, items: [GridNodePresentationItem]) {
        self.contentSize = contentSize
        self.items = items
    }
}

public struct GridNodeDisplayedItemRange: Equatable {
    public let loadedRange: Range<Int>?
    public let visibleRange: Range<Int>?
    
    public static func ==(lhs: GridNodeDisplayedItemRange, rhs: GridNodeDisplayedItemRange) -> Bool {
        return lhs.loadedRange == rhs.loadedRange && lhs.visibleRange == rhs.visibleRange
    }
}

open class GridNode: GridNodeScroller, UIScrollViewDelegate {
    private var gridLayout = GridNodeLayout(size: CGSize(), insets: UIEdgeInsets(), preloadSize: 0.0, itemSize: CGSize(), indexOffset: 0)
    private var items: [GridItem] = []
    private var itemNodes: [Int: GridItemNode] = [:]
    private var itemLayout = GridNodeItemLayout(contentSize: CGSize(), items: [])
    
    private var applyingContentOffset = false
    
    public override init() {
        super.init()
        
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.scrollsToTop = false
        self.scrollView.delegate = self
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func transaction(_ transaction: GridNodeTransaction, completion: (GridNodeDisplayedItemRange) -> Void) {
        if transaction.deleteItems.isEmpty && transaction.insertItems.isEmpty && transaction.scrollToItem == nil && transaction.updateItems.isEmpty && (transaction.updateLayout == nil || transaction.updateLayout!.layout == self.gridLayout) {
            completion(self.displayedItemRange())
            return
        }
        
        if let updateLayout = transaction.updateLayout {
            self.gridLayout = updateLayout.layout
        }
        
        for updatedItem in transaction.updateItems {
            self.items[updatedItem.index] = updatedItem.item
            if let itemNode = self.itemNodes[updatedItem.index] {
                //update node
            }
        }
        
        if !transaction.deleteItems.isEmpty || !transaction.insertItems.isEmpty {
            let deleteItems = transaction.deleteItems.sorted()
                
            for deleteItemIndex in deleteItems.reversed() {
                self.items.remove(at: deleteItemIndex)
                self.removeItemNodeWithIndex(deleteItemIndex)
            }
            
            var remappedDeletionItemNodes: [Int: GridItemNode] = [:]
            
            for (index, itemNode) in self.itemNodes {
                var indexOffset = 0
                for deleteIndex in deleteItems {
                    if deleteIndex < index {
                        indexOffset += 1
                    } else {
                        break
                    }
                }
                
                remappedDeletionItemNodes[index - indexOffset] = itemNode
            }
            
            let insertItems = transaction.insertItems.sorted(by: { $0.index < $1.index })
            if self.items.count == 0 && !insertItems.isEmpty {
                if insertItems[0].index != 0 {
                    fatalError("transaction: invalid insert into empty list")
                }
            }
            
            for insertedItem in insertItems {
                self.items.insert(insertedItem.item, at: insertedItem.index)
            }
            
            var remappedInsertionItemNodes: [Int: GridItemNode] = [:]
            for (index, itemNode) in remappedDeletionItemNodes {
                var indexOffset = 0
                for insertedItem in transaction.insertItems {
                    if insertedItem.index <= index + indexOffset {
                        indexOffset += 1
                    }
                }
                
                remappedInsertionItemNodes[index + indexOffset] = itemNode
            }
            
            self.itemNodes = remappedInsertionItemNodes
        }
        
        self.itemLayout = self.generateItemLayout()
        
        self.applyPresentaionLayout(self.generatePresentationLayout(scrollToItemIndex: 0))
        
        completion(self.displayedItemRange())
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.applyingContentOffset {
            self.applyPresentaionLayout(self.generatePresentationLayout())
        }
    }
    
    private func displayedItemRange() -> GridNodeDisplayedItemRange {
        var minIndex: Int?
        var maxIndex: Int?
        for index in self.itemNodes.keys {
            if minIndex == nil || minIndex! > index {
                minIndex = index
            }
            if maxIndex == nil || maxIndex! < index {
                maxIndex = index
            }
        }
        
        if let minIndex = minIndex, let maxIndex = maxIndex {
            return GridNodeDisplayedItemRange(loadedRange: minIndex ..< maxIndex, visibleRange: minIndex ..< maxIndex)
        } else {
            return GridNodeDisplayedItemRange(loadedRange: nil, visibleRange: nil)
        }
    }
    
    private func generateItemLayout() -> GridNodeItemLayout {
        if CGFloat(0.0).isLess(than: gridLayout.size.width) && CGFloat(0.0).isLess(than: gridLayout.size.height) && !self.items.isEmpty {
            var contentSize = CGSize(width: gridLayout.size.width, height: 0.0)
            var items: [GridNodePresentationItem] = []
            
            var incrementedCurrentRow = false
            var nextItemOrigin = CGPoint(x: 0.0, y: 0.0)
            var index = 0
            for item in self.items {
                if !incrementedCurrentRow {
                    incrementedCurrentRow = true
                    contentSize.height += gridLayout.itemSize.height
                }
                
                items.append(GridNodePresentationItem(index: index, frame: CGRect(origin: nextItemOrigin, size: gridLayout.itemSize)))
                index += 1
                
                nextItemOrigin.x += gridLayout.itemSize.width
                if nextItemOrigin.x + gridLayout.itemSize.width > gridLayout.size.width {
                    nextItemOrigin.x = 0.0
                    nextItemOrigin.y += gridLayout.itemSize.height
                    incrementedCurrentRow = false
                }
            }
            
            return GridNodeItemLayout(contentSize: contentSize, items: items)
        } else {
            return GridNodeItemLayout(contentSize: CGSize(), items: [])
        }
    }
    
    private func generatePresentationLayout(scrollToItemIndex: Int? = nil) -> GridNodePresentationLayout {
        if CGFloat(0.0).isLess(than: gridLayout.size.width) && CGFloat(0.0).isLess(than: gridLayout.size.height) && !self.itemLayout.items.isEmpty {
            let contentOffset: CGPoint
            if let scrollToItemIndex = scrollToItemIndex {
                let itemFrame = self.itemLayout.items[scrollToItemIndex]
                
                let displayHeight = max(0.0, self.gridLayout.size.height - self.gridLayout.insets.top - self.gridLayout.insets.bottom)
                var verticalOffset = floor(itemFrame.frame.minY + itemFrame.frame.size.height / 2.0 - displayHeight / 2.0 - self.gridLayout.insets.top)
                
                if verticalOffset > self.itemLayout.contentSize.height + self.gridLayout.insets.bottom - self.gridLayout.size.height {
                    verticalOffset = self.itemLayout.contentSize.height + self.gridLayout.insets.bottom - self.gridLayout.size.height
                }
                if verticalOffset < -self.gridLayout.insets.top {
                    verticalOffset = -self.gridLayout.insets.top
                }
                
                contentOffset = CGPoint(x: 0.0, y: verticalOffset)
            } else {
                contentOffset = self.scrollView.contentOffset
            }
            
            let lowerDisplayBound = contentOffset.y - self.gridLayout.preloadSize
            let upperDisplayBound = contentOffset.y + self.gridLayout.size.height + self.gridLayout.preloadSize
            
            var presentationItems: [GridNodePresentationItem] = []
            for item in self.itemLayout.items {
                if item.frame.origin.y < lowerDisplayBound {
                    continue
                }
                if item.frame.origin.y + item.frame.size.height > upperDisplayBound {
                    break
                }
                presentationItems.append(item)
            }
            
            return GridNodePresentationLayout(layout: self.gridLayout, contentOffset: contentOffset, contentSize: self.itemLayout.contentSize, items: presentationItems)
        } else {
            return GridNodePresentationLayout(layout: self.gridLayout, contentOffset: CGPoint(), contentSize: self.itemLayout.contentSize, items: [])
        }
    }
    
    private func applyPresentaionLayout(_ presentationLayout: GridNodePresentationLayout) {
        applyingContentOffset = true
        self.scrollView.contentSize = presentationLayout.contentSize
        self.scrollView.contentInset = presentationLayout.layout.insets
        if !self.scrollView.contentOffset.equalTo(presentationLayout.contentOffset) {
            self.scrollView.setContentOffset(presentationLayout.contentOffset, animated: false)
        }
        applyingContentOffset = false
        
        var existingItemIndices = Set<Int>()
        for item in presentationLayout.items {
            existingItemIndices.insert(item.index)
            
            if let itemNode = self.itemNodes[item.index] {
                itemNode.frame = item.frame
            } else {
                let itemNode = self.items[item.index].node(layout: presentationLayout.layout)
                itemNode.frame = item.frame
                self.addItemNode(index: item.index, itemNode: itemNode)
            }
        }
        
        for index in self.itemNodes.keys {
            if !existingItemIndices.contains(index) {
                self.removeItemNodeWithIndex(index)
            }
        }
    }
    
    private func addItemNode(index: Int, itemNode: GridItemNode) {
        assert(self.itemNodes[index] == nil)
        self.itemNodes[index] = itemNode
        if itemNode.supernode == nil {
            self.addSubnode(itemNode)
        }
    }
    
    private func removeItemNodeWithIndex(_ index: Int) {
        if let itemNode = self.itemNodes.removeValue(forKey: index) {
            itemNode.removeFromSupernode()
        }
    }
    
    public func forEachItemNode(_ f: @noescape(ASDisplayNode) -> Void) {
        for (_, node) in self.itemNodes {
            f(node)
        }
    }
}
