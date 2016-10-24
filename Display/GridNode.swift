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
    
    public init(size: CGSize, insets: UIEdgeInsets, preloadSize: CGFloat, itemSize: CGSize) {
        self.size = size
        self.insets = insets
        self.preloadSize = preloadSize
        self.itemSize = itemSize
    }
    
    public static func ==(lhs: GridNodeLayout, rhs: GridNodeLayout) -> Bool {
        return lhs.size.equalTo(rhs.size) && lhs.insets == rhs.insets && lhs.preloadSize.isEqual(to: rhs.preloadSize) && lhs.itemSize.equalTo(rhs.itemSize)
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

public enum GridNodeStationaryItems {
    case none
    case all
    case indices(Set<Int>)
}

public struct GridNodeTransaction {
    public let deleteItems: [Int]
    public let insertItems: [GridNodeInsertItem]
    public let updateItems: [GridNodeUpdateItem]
    public let scrollToItem: GridNodeScrollToItem?
    public let updateLayout: GridNodeUpdateLayout?
    public let stationaryItems: GridNodeStationaryItems
    public let updateFirstIndexInSectionOffset: Int?
    
    public init(deleteItems: [Int], insertItems: [GridNodeInsertItem], updateItems: [GridNodeUpdateItem], scrollToItem: GridNodeScrollToItem?, updateLayout: GridNodeUpdateLayout?, stationaryItems: GridNodeStationaryItems, updateFirstIndexInSectionOffset: Int?) {
        self.deleteItems = deleteItems
        self.insertItems = insertItems
        self.updateItems = updateItems
        self.scrollToItem = scrollToItem
        self.updateLayout = updateLayout
        self.stationaryItems = stationaryItems
        self.updateFirstIndexInSectionOffset = updateFirstIndexInSectionOffset
    }
}

private struct GridNodePresentationItem {
    let index: Int
    let frame: CGRect
}

private struct GridNodePresentationSection {
    let section: GridSection
    let frame: CGRect
}

private struct GridNodePresentationLayout {
    let layout: GridNodeLayout
    let contentOffset: CGPoint
    let contentSize: CGSize
    let items: [GridNodePresentationItem]
    let sections: [GridNodePresentationSection]
}

private final class GridNodeItemLayout {
    let contentSize: CGSize
    let items: [GridNodePresentationItem]
    let sections: [GridNodePresentationSection]
    
    init(contentSize: CGSize, items: [GridNodePresentationItem], sections: [GridNodePresentationSection]) {
        self.contentSize = contentSize
        self.items = items
        self.sections = sections
    }
}

public struct GridNodeDisplayedItemRange: Equatable {
    public let loadedRange: Range<Int>?
    public let visibleRange: Range<Int>?
    
    public static func ==(lhs: GridNodeDisplayedItemRange, rhs: GridNodeDisplayedItemRange) -> Bool {
        return lhs.loadedRange == rhs.loadedRange && lhs.visibleRange == rhs.visibleRange
    }
}

private struct WrappedGridSection: Hashable {
    let section: GridSection
    
    init(_ section: GridSection) {
        self.section = section
    }
    
    var hashValue: Int {
        return self.section.hashValue
    }
    
    static func ==(lhs: WrappedGridSection, rhs: WrappedGridSection) -> Bool {
        return lhs.section.isEqual(to: rhs.section)
    }
}

public struct GridNodeVisibleItems {
    public let top: (Int, GridItem)?
    public let bottom: (Int, GridItem)?
    public let topVisible: (Int, GridItem)?
    public let bottomVisible: (Int, GridItem)?
    public let count: Int
}

open class GridNode: GridNodeScroller, UIScrollViewDelegate {
    private var gridLayout = GridNodeLayout(size: CGSize(), insets: UIEdgeInsets(), preloadSize: 0.0, itemSize: CGSize())
    private var firstIndexInSectionOffset: Int = 0
    private var items: [GridItem] = []
    private var itemNodes: [Int: GridItemNode] = [:]
    private var sectionNodes: [WrappedGridSection: ASDisplayNode] = [:]
    private var itemLayout = GridNodeItemLayout(contentSize: CGSize(), items: [], sections: [])
    
    private var applyingContentOffset = false
    
    public var visibleItemsUpdated: ((GridNodeVisibleItems) -> Void)?
    
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
        if transaction.deleteItems.isEmpty && transaction.insertItems.isEmpty && transaction.scrollToItem == nil && transaction.updateItems.isEmpty && (transaction.updateLayout == nil || transaction.updateLayout!.layout == self.gridLayout && (transaction.updateFirstIndexInSectionOffset == nil || transaction.updateFirstIndexInSectionOffset == self.firstIndexInSectionOffset)) {
            completion(self.displayedItemRange())
            return
        }
        
        if let updateFirstIndexInSectionOffset = transaction.updateFirstIndexInSectionOffset {
            self.firstIndexInSectionOffset = updateFirstIndexInSectionOffset
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
        
        var previousLayoutWasEmpty = self.itemLayout.items.isEmpty
        
        self.itemLayout = self.generateItemLayout()
        
        
        self.applyPresentaionLayout(self.generatePresentationLayout(stationaryItems: transaction.stationaryItems, scrollToItemIndex: previousLayoutWasEmpty ? 0 : nil))
        
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
            var sections: [GridNodePresentationSection] = []
            
            var incrementedCurrentRow = false
            var nextItemOrigin = CGPoint(x: 0.0, y: 0.0)
            var index = 0
            var previousSection: GridSection?
            for item in self.items {
                let section = item.section
                var keepSection = true
                if let previousSection = previousSection, let section = section {
                    keepSection = previousSection.isEqual(to: section)
                } else if (previousSection != nil) != (section != nil) {
                    keepSection = false
                }
                
                if !keepSection {
                    if incrementedCurrentRow {
                        nextItemOrigin.x = 0.0
                        nextItemOrigin.y += gridLayout.itemSize.height
                        incrementedCurrentRow = false
                    }
                    
                    if let section = section {
                        sections.append(GridNodePresentationSection(section: section, frame: CGRect(origin: CGPoint(x: 0.0, y: nextItemOrigin.y), size: CGSize(width: gridLayout.size.width, height: section.height))))
                        nextItemOrigin.y += section.height
                        contentSize.height += section.height
                    }
                }
                previousSection = section
                
                if !incrementedCurrentRow {
                    incrementedCurrentRow = true
                    contentSize.height += gridLayout.itemSize.height
                }
                
                if index == 0 {
                    let itemsInRow = Int(gridLayout.size.width) / Int(gridLayout.itemSize.width)
                    let normalizedIndexOffset = self.firstIndexInSectionOffset % itemsInRow
                    nextItemOrigin.x += gridLayout.itemSize.width * CGFloat(normalizedIndexOffset)
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
            
            return GridNodeItemLayout(contentSize: contentSize, items: items, sections: sections)
        } else {
            return GridNodeItemLayout(contentSize: CGSize(), items: [], sections: [])
        }
    }
    
    private func generatePresentationLayout(stationaryItems: GridNodeStationaryItems = .none, scrollToItemIndex: Int? = nil) -> GridNodePresentationLayout {
        if CGFloat(0.0).isLess(than: gridLayout.size.width) && CGFloat(0.0).isLess(than: gridLayout.size.height) && !self.itemLayout.items.isEmpty {
            let contentOffset: CGPoint
            switch stationaryItems {
                case .none:
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
                case let .indices(stationaryItemIndices):
                    var selectedContentOffset: CGPoint?
                    for (index, itemNode) in self.itemNodes {
                        if stationaryItemIndices.contains(index) {
                            let currentScreenOffset = itemNode.frame.origin.y - self.scrollView.contentOffset.y
                            selectedContentOffset = CGPoint(x: 0.0, y: self.itemLayout.items[index].frame.origin.y - itemNode.frame.origin.y + self.scrollView.contentOffset.y)
                            break
                        }
                    }
                    
                    if let selectedContentOffset = selectedContentOffset {
                        contentOffset = selectedContentOffset
                    } else {
                        contentOffset = self.scrollView.contentOffset
                    }
                case .all:
                    var selectedContentOffset: CGPoint?
                    for (index, itemNode) in self.itemNodes {
                        let currentScreenOffset = itemNode.frame.origin.y - self.scrollView.contentOffset.y
                        selectedContentOffset = CGPoint(x: 0.0, y: self.itemLayout.items[index].frame.origin.y - itemNode.frame.origin.y + self.scrollView.contentOffset.y)
                        break
                    }
                    
                    if let selectedContentOffset = selectedContentOffset {
                        contentOffset = selectedContentOffset
                    } else {
                        contentOffset = self.scrollView.contentOffset
                    }
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
            
            var presentationSections: [GridNodePresentationSection] = []
            for section in self.itemLayout.sections {
                if section.frame.origin.y < lowerDisplayBound {
                    continue
                }
                if section.frame.origin.y + section.frame.size.height > upperDisplayBound {
                    break
                }
                presentationSections.append(section)
            }
            
            return GridNodePresentationLayout(layout: self.gridLayout, contentOffset: contentOffset, contentSize: self.itemLayout.contentSize, items: presentationItems, sections: presentationSections)
        } else {
            return GridNodePresentationLayout(layout: self.gridLayout, contentOffset: CGPoint(), contentSize: self.itemLayout.contentSize, items: [], sections: [])
        }
    }
    
    private func applyPresentaionLayout(_ presentationLayout: GridNodePresentationLayout) {
        applyingContentOffset = true
        self.scrollView.contentSize = presentationLayout.contentSize
        self.scrollView.contentInset = presentationLayout.layout.insets
        if !self.scrollView.contentOffset.equalTo(presentationLayout.contentOffset) {
            //self.scrollView.setContentOffset(presentationLayout.contentOffset, animated: false)
            self.scrollView.contentOffset = presentationLayout.contentOffset
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
        
        var existingSections = Set<WrappedGridSection>()
        for section in presentationLayout.sections {
            let wrappedSection = WrappedGridSection(section.section)
            existingSections.insert(wrappedSection)
            
            if let sectionNode = self.sectionNodes[wrappedSection] {
                sectionNode.frame = section.frame
            } else {
                let sectionNode = section.section.node()
                sectionNode.frame = section.frame
                self.addSectionNode(section: wrappedSection, sectionNode: sectionNode)
            }
        }
        
        for wrappedSection in self.sectionNodes.keys {
            if !existingSections.contains(wrappedSection) {
                self.removeSectionNodeWithSection(wrappedSection)
            }
        }
        
        if let visibleItemsUpdated = self.visibleItemsUpdated {
            if presentationLayout.items.count != 0 {
                let topIndex = presentationLayout.items.first!.index
                let bottomIndex = presentationLayout.items.last!.index
                
                var topVisible: (Int, GridItem) = (topIndex, self.items[topIndex])
                var bottomVisible: (Int, GridItem) = (bottomIndex, self.items[bottomIndex])
                
                let lowerDisplayBound = presentationLayout.contentOffset.y
                let upperDisplayBound = presentationLayout.contentOffset.y + self.gridLayout.size.height
                
                for item in presentationLayout.items {
                    if item.frame.maxY >= lowerDisplayBound {
                        topVisible = (item.index, self.items[item.index])
                        break
                    }
                }
                
                visibleItemsUpdated(GridNodeVisibleItems(top: (topIndex, self.items[topIndex]), bottom: (bottomIndex, self.items[bottomIndex]), topVisible: topVisible, bottomVisible: bottomVisible, count: self.items.count))
            } else {
                visibleItemsUpdated(GridNodeVisibleItems(top: nil, bottom: nil, topVisible: nil, bottomVisible: nil, count: self.items.count))
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
    
    private func addSectionNode(section: WrappedGridSection, sectionNode: ASDisplayNode) {
        assert(self.sectionNodes[section] == nil)
        self.sectionNodes[section] = sectionNode
        if sectionNode.supernode == nil {
            self.addSubnode(sectionNode)
        }
    }
    
    private func removeItemNodeWithIndex(_ index: Int) {
        if let itemNode = self.itemNodes.removeValue(forKey: index) {
            itemNode.removeFromSupernode()
        }
    }
    
    private func removeSectionNodeWithSection(_ section: WrappedGridSection) {
        if let sectionNode = self.sectionNodes.removeValue(forKey: section) {
            sectionNode.removeFromSupernode()
        }
    }
    
    public func forEachItemNode(_ f: @noescape(ASDisplayNode) -> Void) {
        for (_, node) in self.itemNodes {
            f(node)
        }
    }
}
