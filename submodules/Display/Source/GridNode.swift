import Foundation
import UIKit
import AsyncDisplayKit

public enum GridNodeVisibleContentOffset {
    case known(CGFloat)
    case unknown
    case none
}

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
    public let previousIndex: Int
    public let item: GridItem
    
    public init(index: Int, previousIndex: Int, item: GridItem) {
        self.index = index
        self.previousIndex = previousIndex
        self.item = item
    }
}

public enum GridNodeScrollToItemPosition {
    case top(CGFloat)
    case bottom(CGFloat)
    case center(CGFloat)
    case visible
}

public struct GridNodeScrollToItem {
    public let index: Int
    public let position: GridNodeScrollToItemPosition
    public let transition: ContainedViewLayoutTransition
    public let directionHint: GridNodePreviousItemsTransitionDirectionHint
    public let adjustForSection: Bool
    public let adjustForTopInset: Bool
    
    public init(index: Int, position: GridNodeScrollToItemPosition, transition: ContainedViewLayoutTransition, directionHint: GridNodePreviousItemsTransitionDirectionHint, adjustForSection: Bool, adjustForTopInset: Bool = false) {
        self.index = index
        self.position = position
        self.transition = transition
        self.directionHint = directionHint
        self.adjustForSection = adjustForSection
        self.adjustForTopInset = adjustForTopInset
    }
}

public enum GridNodeLayoutType: Equatable {
    case fixed(itemSize: CGSize, fillWidth: Bool?, lineSpacing: CGFloat, itemSpacing: CGFloat?)
    case balanced(idealHeight: CGFloat)
}

public struct GridNodeLayout: Equatable {
    public let size: CGSize
    public let insets: UIEdgeInsets
    public let scrollIndicatorInsets: UIEdgeInsets?
    public let preloadSize: CGFloat
    public let type: GridNodeLayoutType
    public let cutout: CGRect?
    
    public init(size: CGSize, insets: UIEdgeInsets, scrollIndicatorInsets: UIEdgeInsets? = nil, preloadSize: CGFloat, type: GridNodeLayoutType, cutout: CGRect? = nil) {
        self.size = size
        self.insets = insets
        self.scrollIndicatorInsets = scrollIndicatorInsets
        self.preloadSize = preloadSize
        self.type = type
        self.cutout = cutout
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
    public let itemTransition: ContainedViewLayoutTransition
    public let stationaryItems: GridNodeStationaryItems
    public let updateFirstIndexInSectionOffset: Int?
    public let updateOpaqueState: Any?
    public let synchronousLoads: Bool
    
    public init(deleteItems: [Int], insertItems: [GridNodeInsertItem], updateItems: [GridNodeUpdateItem], scrollToItem: GridNodeScrollToItem?, updateLayout: GridNodeUpdateLayout?, itemTransition: ContainedViewLayoutTransition, stationaryItems: GridNodeStationaryItems, updateFirstIndexInSectionOffset: Int?, updateOpaqueState: Any? = nil, synchronousLoads: Bool = false) {
        self.deleteItems = deleteItems
        self.insertItems = insertItems
        self.updateItems = updateItems
        self.scrollToItem = scrollToItem
        self.updateLayout = updateLayout
        self.itemTransition = itemTransition
        self.stationaryItems = stationaryItems
        self.updateFirstIndexInSectionOffset = updateFirstIndexInSectionOffset
        self.updateOpaqueState = updateOpaqueState
        self.synchronousLoads = synchronousLoads
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

public enum GridNodePreviousItemsTransitionDirectionHint {
    case up
    case down
}

private struct GridNodePresentationLayoutTransition {
    let layout: GridNodePresentationLayout
    let directionHint: GridNodePreviousItemsTransitionDirectionHint
    let transition: ContainedViewLayoutTransition
}

public struct GridNodeCurrentPresentationLayout {
    public let layout: GridNodeLayout
    public let contentOffset: CGPoint
    public let contentSize: CGSize
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
}

private struct WrappedGridSection: Equatable, Hashable {
    let section: GridSection
    
    init(_ section: GridSection) {
        self.section = section
    }
    
    static func ==(lhs: WrappedGridSection, rhs: WrappedGridSection) -> Bool {
        return lhs.section.isEqual(to: rhs.section)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.section.hashValue)
    }
}

public struct GridNodeVisibleItems {
    public let top: (Int, GridItem)?
    public let bottom: (Int, GridItem)?
    public let topVisible: (Int, GridItem)?
    public let bottomVisible: (Int, GridItem)?
    public let topSectionVisible: GridSection?
    public let count: Int
}

private struct WrappedGridItemNode: Hashable {
    let node: ASDisplayNode
    
    static func ==(lhs: WrappedGridItemNode, rhs: WrappedGridItemNode) -> Bool {
        return lhs.node === rhs.node
    }
}

open class GridNode: GridNodeScroller, UIScrollViewDelegate {
    public private(set) var gridLayout = GridNodeLayout(size: CGSize(), insets: UIEdgeInsets(), preloadSize: 0.0, type: .fixed(itemSize: CGSize(), fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil))
    private var firstIndexInSectionOffset: Int = 0
    public private(set) var items: [GridItem] = []
    private var itemNodes: [Int: GridItemNode] = [:]
    private var sectionNodes: [WrappedGridSection: ASDisplayNode] = [:]
    private var itemLayout = GridNodeItemLayout(contentSize: CGSize(), items: [], sections: [])
    
    public var setupNode: ((GridItemNode) -> Void)?
    
    private var applyingContentOffset = false
    
    public var visibleItemsUpdated: ((GridNodeVisibleItems) -> Void)?
    public var presentationLayoutUpdated: ((GridNodeCurrentPresentationLayout, ContainedViewLayoutTransition) -> Void)?
    public var scrollingInitiated: (() -> Void)?
    public var scrollingCompleted: (() -> Void)?
    public var interactiveScrollingEnded: (() -> Void)?
    public var interactiveScrollingWillBeEnded: ((CGPoint, CGPoint, CGPoint) -> CGPoint)?
    public var visibleContentOffsetChanged: (GridNodeVisibleContentOffset) -> Void = { _ in }
    
    private var autoscrollingAnimator: DisplayLinkAnimator?
    
    public final var floatingSections = false
    
    public final var initialOffset: CGFloat = 0.0
    
    public var showVerticalScrollIndicator: Bool = false {
        didSet {
            self.scrollView.showsVerticalScrollIndicator = self.showVerticalScrollIndicator
        }
    }
    
    public var indicatorStyle: UIScrollView.IndicatorStyle = .default {
        didSet {
            self.scrollView.indicatorStyle = self.indicatorStyle
        }
    }
        
    public private(set) var opaqueState: Any?
    
    public override init() {
        super.init()
        
        if #available(iOS 11.0, *) {
            self.scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.scrollsToTop = false
        self.scrollView.delegate = self
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.autoscrollingAnimator?.invalidate()
    }
    
    public func transaction(_ transaction: GridNodeTransaction, completion: (GridNodeDisplayedItemRange) -> Void) {
        if let updateOpaqueState = transaction.updateOpaqueState {
            self.opaqueState = updateOpaqueState
        }
        
        if transaction.deleteItems.isEmpty && transaction.insertItems.isEmpty && transaction.scrollToItem == nil && transaction.updateItems.isEmpty && (transaction.updateLayout == nil || transaction.updateLayout!.layout == self.gridLayout && (transaction.updateFirstIndexInSectionOffset == nil || transaction.updateFirstIndexInSectionOffset == self.firstIndexInSectionOffset)) {
            if let presentationLayoutUpdated = self.presentationLayoutUpdated {
                presentationLayoutUpdated(GridNodeCurrentPresentationLayout(layout: self.gridLayout, contentOffset: self.scrollView.contentOffset, contentSize: self.itemLayout.contentSize), transaction.updateLayout?.transition ?? .immediate)
            }
            completion(self.displayedItemRange())
            return
        }
        
        if let updateFirstIndexInSectionOffset = transaction.updateFirstIndexInSectionOffset {
            self.firstIndexInSectionOffset = updateFirstIndexInSectionOffset
        }
        
        var layoutTransactionOffset: CGFloat = 0.0
        if let updateLayout = transaction.updateLayout {
            layoutTransactionOffset += updateLayout.layout.insets.top - self.gridLayout.insets.top
            self.gridLayout = updateLayout.layout
        }
        
        for updatedItem in transaction.updateItems {
            self.items[updatedItem.previousIndex] = updatedItem.item
            if let itemNode = self.itemNodes[updatedItem.previousIndex] {
                updatedItem.item.update(node: itemNode)
            }
        }
        
        var removedNodes: [GridItemNode] = []
        
        if !transaction.deleteItems.isEmpty || !transaction.insertItems.isEmpty {
            let deleteItems = transaction.deleteItems.sorted()
                
            for deleteItemIndex in deleteItems.reversed() {
                self.items.remove(at: deleteItemIndex)
                if let itemNode = self.itemNodes[deleteItemIndex] {
                    removedNodes.append(itemNode)
                    self.removeItemNodeWithIndex(deleteItemIndex, removeNode: false)
                } else {
                    self.removeItemNodeWithIndex(deleteItemIndex, removeNode: true)
                }
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
            
            let sortedInsertItems = transaction.insertItems.sorted(by: { $0.index < $1.index })
            
            var remappedInsertionItemNodes: [Int: GridItemNode] = [:]
            for (index, itemNode) in remappedDeletionItemNodes {
                var indexOffset = 0
                for insertedItem in sortedInsertItems {
                    if insertedItem.index <= index + indexOffset {
                        indexOffset += 1
                    }
                }
                
                remappedInsertionItemNodes[index + indexOffset] = itemNode
            }
            
            self.itemNodes = remappedInsertionItemNodes
        }
        
        let previousLayoutWasEmpty = self.itemLayout.items.isEmpty
        
        self.itemLayout = self.generateItemLayout()
        
        var updateLayoutTransition = transaction.updateLayout?.transition
        
        let generatedScrollToItem: GridNodeScrollToItem?
        if let scrollToItem = transaction.scrollToItem {
            generatedScrollToItem = scrollToItem
            if updateLayoutTransition == nil {
                updateLayoutTransition = scrollToItem.transition
            }
        } else if previousLayoutWasEmpty {
            generatedScrollToItem = GridNodeScrollToItem(index: 0, position: .top(0.0), transition: .immediate, directionHint: .up, adjustForSection: true, adjustForTopInset: true)
        } else {
            generatedScrollToItem = nil
        }
        
        self.applyPresentationLayoutTransition(self.generatePresentationLayoutTransition(stationaryItems: transaction.stationaryItems, layoutTransactionOffset: layoutTransactionOffset, scrollToItem: generatedScrollToItem), removedNodes: removedNodes, updateLayoutTransition: updateLayoutTransition, customScrollToItem: transaction.scrollToItem != nil, itemTransition: transaction.itemTransition, synchronousLoads: transaction.synchronousLoads, updatingLayout: transaction.updateLayout != nil, completion: completion)
    }
    
    public func autoscroll(toOffset: CGPoint, duration: Double) {
        if let autoscrollingAnimator = self.autoscrollingAnimator {
            self.autoscrollingAnimator = nil
            autoscrollingAnimator.invalidate()
        }
        
        let fromOffset: CGPoint = self.scrollView.contentOffset
        let fromBounds = CGRect(origin: fromOffset, size: self.scrollView.bounds.size)
        self.applyingContentOffset = true
        self.scrollView.setContentOffset(toOffset, animated: false)
        self.applyingContentOffset = false
        let toBounds = self.scrollView.bounds
        let animation = self.scrollView.layer.makeAnimation(from: NSValue(cgRect: fromBounds), to: NSValue(cgRect: toBounds), keyPath: "bounds", timingFunction: kCAMediaTimingFunctionSpring, duration: duration)
        self.scrollView.layer.add(animation, forKey: "autoscroll")
        
        let transition: ContainedViewLayoutTransition = .animated(duration: duration, curve: .spring)
        
        self.applyPresentationLayoutTransition(self.generatePresentationLayoutTransition(layoutTransactionOffset: 0.0, customTransition: transition), removedNodes: [], updateLayoutTransition: nil, customScrollToItem: false, itemTransition: .immediate, synchronousLoads: false, updatingLayout: false, completion: { _ in })
        self.updateVisibleContentOffset()
        
        /*let fromOffset: CGPoint = self.scrollView.contentOffset
        
        self.autoscrollingAnimator = DisplayLinkAnimator(duration: duration, from: 0.0, to: 1.0, update: { [weak self] t in
            guard let strongSelf = self else {
                return
            }
            let mappedT = bezierPoint(0.23, 1.0, 0.32, 1.0, t)
            let offset = CGPoint(x: 0.0, y: (1.0 - mappedT) * fromOffset.y + mappedT * toOffset.y)
            strongSelf.scrollView.setContentOffset(offset, animated: false)
        }, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.autoscrollingAnimator?.invalidate()
            strongSelf.autoscrollingAnimator = nil
        })*/
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if let autoscrollingAnimator = self.autoscrollingAnimator {
            self.autoscrollingAnimator = nil
            autoscrollingAnimator.invalidate()
        }
        
        if let _ = self.scrollView.layer.animation(forKey: "autoscroll") {
            if let presentationLayer = self.scrollView.layer.presentation() {
                self.scrollView.bounds = presentationLayer.bounds
            }
            self.scrollView.layer.removeAnimation(forKey: "autoscroll")
        }
        
        self.updateItemNodeVisibilititesAndScrolling()
        self.updateVisibleContentOffset()
        self.scrollingInitiated?()
    }
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if let interactiveScrollingWillBeEnded = self.interactiveScrollingWillBeEnded {
            targetContentOffset.pointee = interactiveScrollingWillBeEnded(scrollView.contentOffset, velocity, targetContentOffset.pointee)
        }
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.interactiveScrollingEnded?()
        if !decelerate {
            self.updateItemNodeVisibilititesAndScrolling()
            self.updateVisibleContentOffset()
            self.scrollingCompleted?()
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.updateItemNodeVisibilititesAndScrolling()
        self.updateVisibleContentOffset()
        self.scrollingCompleted?()
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.applyingContentOffset {
            self.applyPresentationLayoutTransition(self.generatePresentationLayoutTransition(layoutTransactionOffset: 0.0), removedNodes: [], updateLayoutTransition: nil, customScrollToItem: false, itemTransition: .immediate, synchronousLoads: false, updatingLayout: false, completion: { _ in })
            self.updateVisibleContentOffset()
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
        if CGFloat(0.0).isLess(than: gridLayout.size.width) && CGFloat(0.0).isLess(than: gridLayout.size.height) {
            var contentSize = CGSize(width: gridLayout.size.width, height: 0.0)
            var items: [GridNodePresentationItem] = []
            var sections: [GridNodePresentationSection] = []
            
            switch gridLayout.type {
                case let .fixed(defaultItemSize, fillWidth, lineSpacing, defaultItemSpacing):
                    let itemInsets = gridLayout.insets
                    
                    let effectiveWidth = gridLayout.size.width - itemInsets.left - itemInsets.right
                    
                    let itemsInRow = Int(effectiveWidth / defaultItemSize.width)
                    let itemsInRowWidth = CGFloat(itemsInRow) * defaultItemSize.width
                    let remainingWidth = max(0.0, effectiveWidth - itemsInRowWidth)
                    
                    let itemSpacing = defaultItemSpacing ?? floorToScreenPixels(remainingWidth / CGFloat(itemsInRow + 1))
                    let initialSpacing: CGFloat = (fillWidth ?? false) ? 0.0 : itemSpacing
                    
                    var incrementedCurrentRow = false
                    var nextItemOrigin = CGPoint(x: initialSpacing + itemInsets.left, y: 0.0)
                    var index = 0
                    var previousSection: GridSection?
                    
                    var previousFillsRow = false
                    
                    for item in self.items {
                        var itemSize = defaultItemSize
                        
                        let section = item.section
                        var keepSection = true
                        if let previousSection = previousSection, let section = section {
                            keepSection = previousSection.isEqual(to: section)
                        } else if (previousSection != nil) != (section != nil) {
                            keepSection = false
                        }
                        
                        if !previousFillsRow && item.fillsRowWithDynamicHeight != nil {
                            keepSection = false
                        }
                        previousFillsRow = item.fillsRowWithDynamicHeight != nil
                        
                        if !keepSection {
                            if incrementedCurrentRow {
                                nextItemOrigin.x = initialSpacing + itemInsets.left
                                nextItemOrigin.y += itemSize.height + lineSpacing
                                incrementedCurrentRow = false
                            }
                            
                            if let section = section {
                                sections.append(GridNodePresentationSection(section: section, frame: CGRect(origin: CGPoint(x: 0.0, y: nextItemOrigin.y), size: CGSize(width: gridLayout.size.width, height: section.height))))
                                nextItemOrigin.y += section.height
                                contentSize.height += section.height
                            }
                        }
                        previousSection = section
                        
                        if let (height, fillWidth) = item.fillsRowWithHeight {
                            if fillWidth {
                                nextItemOrigin.x = 0.0
                                itemSize.width = gridLayout.size.width
                            }
                            itemSize.height = height
                        } else if let fillsRowWithDynamicHeight = item.fillsRowWithDynamicHeight {
                            let height = fillsRowWithDynamicHeight(gridLayout.size.width)
                            nextItemOrigin.x = 0.0
                            itemSize.width = gridLayout.size.width
                            itemSize.height = height
                        } else if index == 0 {
                            let itemsInRow = max(1, Int(effectiveWidth) / Int(itemSize.width))
                            let normalizedIndexOffset = self.firstIndexInSectionOffset % itemsInRow
                            nextItemOrigin.x += (itemSize.width + itemSpacing) * CGFloat(normalizedIndexOffset)
                        } else if let fillWidth = fillWidth, fillWidth {
                            let nextItemOriginX = nextItemOrigin.x + itemSize.width + itemSpacing
                            let remainingWidth = remainingWidth - CGFloat(itemsInRow - 1) * itemSpacing
                            if nextItemOriginX + itemSize.width > self.gridLayout.size.width - itemInsets.right && remainingWidth > 0.0 {
                                itemSize.width += remainingWidth
                            }
                        }
                        
                        if let cutout = self.gridLayout.cutout, cutout.intersects(CGRect(origin: nextItemOrigin, size: itemSize)) {
                            nextItemOrigin.x += cutout.width + itemSpacing
                        }
                        
                        if !incrementedCurrentRow {
                            incrementedCurrentRow = true
                            contentSize.height += itemSize.height + lineSpacing
                        }
                        
                        items.append(GridNodePresentationItem(index: index, frame: CGRect(origin: nextItemOrigin, size: itemSize)))
                        index += 1
                        
                        nextItemOrigin.x += itemSize.width + itemSpacing
                        if nextItemOrigin.x + itemSize.width > gridLayout.size.width - itemInsets.right {
                            nextItemOrigin.x = initialSpacing + itemInsets.left
                            nextItemOrigin.y += itemSize.height + lineSpacing
                            incrementedCurrentRow = false
                        }
                    }
                case let .balanced(idealHeight):
                    var weights: [Int] = []
                    for item in self.items {
                        weights.append(Int(item.aspectRatio * 100))
                    }
                    
                    var totalItemSize: CGFloat = 0.0
                    for i in 0 ..< self.items.count {
                        totalItemSize += self.items[i].aspectRatio * idealHeight
                    }
                    let numberOfRows = max(Int(round(totalItemSize / gridLayout.size.width)), 1)
                    
                    let partition = linearPartitionForWeights(weights, numberOfPartitions:numberOfRows)
                    
                    var i = 0
                    var offset = CGPoint(x: 0.0, y: 0.0)
                    var previousItemSize: CGFloat = 0.0
                    var contentMaxValueInScrollDirection: CGFloat = 0.0
                    let maxWidth = gridLayout.size.width
                    
                    let minimumInteritemSpacing: CGFloat = 1.0
                    let minimumLineSpacing: CGFloat = 1.0
                    
                    let viewportWidth: CGFloat = gridLayout.size.width
                    
                    let preferredRowSize = idealHeight
                    
                    var rowIndex = -1
                    for row in partition {
                        rowIndex += 1
                        
                        var summedRatios: CGFloat = 0.0
                        
                        var j = i
                        var n = i + row.count
                        
                        while j < n {
                            summedRatios += self.items[j].aspectRatio
                                
                            j += 1
                        }
                        
                        var rowSize = gridLayout.size.width - (CGFloat(row.count - 1) * minimumInteritemSpacing)
                        
                        if rowIndex == partition.count - 1 {
                            if row.count < 2 {
                                rowSize = floor(viewportWidth / 3.0) - (CGFloat(row.count - 1) * minimumInteritemSpacing)
                            } else if row.count < 3 {
                                rowSize = floor(viewportWidth * 2.0 / 3.0) - (CGFloat(row.count - 1) * minimumInteritemSpacing)
                            }
                        }
                        
                        j = i
                        n = i + row.count
                        
                        while j < n {
                            let preferredAspectRatio = self.items[j].aspectRatio
                            
                            let actualSize = CGSize(width: round(rowSize / summedRatios * (preferredAspectRatio)), height: preferredRowSize)
                            
                            var frame = CGRect(x: offset.x, y: offset.y, width: actualSize.width, height: actualSize.height)
                            if frame.origin.x + frame.size.width >= maxWidth - 2.0 {
                                frame.size.width = max(1.0, maxWidth - frame.origin.x)
                            }
                            
                            items.append(GridNodePresentationItem(index: j, frame: frame))
                            
                            offset.x += actualSize.width + minimumInteritemSpacing
                            previousItemSize = actualSize.height
                            contentMaxValueInScrollDirection = frame.maxY
                            
                            j += 1
                        }
                        
                        if row.count > 0 {
                            offset = CGPoint(x: 0.0, y: offset.y + previousItemSize + minimumLineSpacing)
                        }
                        
                        i += row.count
                    }
                    contentSize = CGSize(width: gridLayout.size.width, height: contentMaxValueInScrollDirection)
            }
            
            return GridNodeItemLayout(contentSize: contentSize, items: items, sections: sections)
        } else {
            return GridNodeItemLayout(contentSize: CGSize(), items: [], sections: [])
        }
    }
    
    private func generatePresentationLayoutTransition(stationaryItems: GridNodeStationaryItems = .none, layoutTransactionOffset: CGFloat, scrollToItem: GridNodeScrollToItem? = nil, customTransition: ContainedViewLayoutTransition? = nil) -> GridNodePresentationLayoutTransition {
        if CGFloat(0.0).isLess(than: self.gridLayout.size.width) && CGFloat(0.0).isLess(than: self.gridLayout.size.height) {
            var transitionDirectionHint: GridNodePreviousItemsTransitionDirectionHint = .up
            var transition: ContainedViewLayoutTransition = customTransition ?? .immediate
            let contentOffset: CGPoint
            var updatedStationaryItems = stationaryItems
            if let scrollToItem = scrollToItem {
                updatedStationaryItems = .none
                if case .immediate = transition {
                    transition = scrollToItem.transition
                }
            }
            switch updatedStationaryItems {
                case .none:
                    if let scrollToItem = scrollToItem {
                        if self.itemLayout.items.isEmpty {
                            transitionDirectionHint = scrollToItem.directionHint
                            transition = scrollToItem.transition
                            contentOffset = CGPoint(x: 0.0, y: -self.gridLayout.insets.top + self.initialOffset)
                        } else {
                            let itemFrame = self.itemLayout.items[scrollToItem.index]
                            
                            var additionalOffset: CGFloat = 0.0
                            if scrollToItem.adjustForSection {
                                var adjustForSection: GridSection?
                                if scrollToItem.index == 0 {
                                    if let itemSection = self.items[scrollToItem.index].section {
                                        adjustForSection = itemSection
                                    }
                                } else {
                                    let itemSection = self.items[scrollToItem.index].section
                                    let previousSection = self.items[scrollToItem.index - 1].section
                                    if let itemSection = itemSection, let previousSection = previousSection {
                                        if !itemSection.isEqual(to: previousSection) {
                                            adjustForSection = itemSection
                                        }
                                    } else if let itemSection = itemSection {
                                        adjustForSection = itemSection
                                    }
                                }
                                
                                if let adjustForSection = adjustForSection {
                                    additionalOffset = -adjustForSection.height
                                }
                                
                                if scrollToItem.adjustForTopInset {
                                    additionalOffset += -gridLayout.insets.top// + self.initialOffset
                                }
                            } else if scrollToItem.adjustForTopInset {
                                additionalOffset = -gridLayout.insets.top
                            }
                            
                            let displayHeight = max(0.0, self.gridLayout.size.height - self.gridLayout.insets.top - self.gridLayout.insets.bottom)
                            var verticalOffset: CGFloat = self.scrollView.contentOffset.y
                            
                            switch scrollToItem.position {
                                case let .top(offset):
                                    verticalOffset = itemFrame.frame.minY + additionalOffset + offset
                                case let .center(offset):
                                    verticalOffset = floor(itemFrame.frame.minY + itemFrame.frame.size.height / 2.0 - displayHeight / 2.0 - self.gridLayout.insets.top) + additionalOffset + offset
                                case let .bottom(offset):
                                    verticalOffset = itemFrame.frame.maxY - displayHeight + additionalOffset + offset
                                case .visible:
                                    if verticalOffset + self.gridLayout.insets.top > itemFrame.frame.minY {
                                        //verticalOffset = -self.gridLayout.insets.top + itemFrame.frame.minY
                                    } else if verticalOffset + self.gridLayout.insets.top + displayHeight < itemFrame.frame.maxY {
                                        verticalOffset = -self.gridLayout.insets.top - displayHeight + itemFrame.frame.maxY
                                    }
                            }
                            
                            if verticalOffset > self.itemLayout.contentSize.height + self.gridLayout.insets.bottom - self.gridLayout.size.height {
                                verticalOffset = self.itemLayout.contentSize.height + self.gridLayout.insets.bottom - self.gridLayout.size.height
                            }
                            if verticalOffset < -self.gridLayout.insets.top {
                                verticalOffset = -self.gridLayout.insets.top
                            }
                            
                            transitionDirectionHint = scrollToItem.directionHint
                            transition = scrollToItem.transition
                            
                            contentOffset = CGPoint(x: 0.0, y: verticalOffset)
                        }
                    } else {
                        if !layoutTransactionOffset.isZero {
                            var verticalOffset = self.scrollView.contentOffset.y - layoutTransactionOffset
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
                    }
                case let .indices(stationaryItemIndices):
                    var selectedContentOffset: CGPoint?
                    for (index, itemNode) in self.itemNodes {
                        if stationaryItemIndices.contains(index) {
                            //let currentScreenOffset = itemNode.frame.origin.y - self.scrollView.contentOffset.y
                            selectedContentOffset = CGPoint(x: 0.0, y: self.itemLayout.items[index].frame.origin.y - itemNode.frame.origin.y + self.scrollView.contentOffset.y)
                            break
                        }
                    }
                    
                    if  let _ = selectedContentOffset, self.itemNodes.count > 0, let itemNode = self.itemNodes[0], self.scrollView.contentInset.top + self.scrollView.contentOffset.y <= itemNode.frame.maxY {
                        selectedContentOffset = self.scrollView.contentOffset
                    }
                    
                    if let selectedContentOffset = selectedContentOffset {
                        contentOffset = selectedContentOffset
                    } else {
                        contentOffset = self.scrollView.contentOffset
                    }
                
                
                case .all:
                    var selectedContentOffset: CGPoint?
                    for (index, itemNode) in self.itemNodes {
                        //let currentScreenOffset = itemNode.frame.origin.y - self.scrollView.contentOffset.y
                        selectedContentOffset = CGPoint(x: 0.0, y: self.itemLayout.items[index].frame.origin.y - itemNode.frame.origin.y + self.scrollView.contentOffset.y)
                        break
                    }
                    
                    if let selectedContentOffset = selectedContentOffset {
                        contentOffset = selectedContentOffset
                    } else {
                        contentOffset = self.scrollView.contentOffset
                    }
            }
            
            let lowerDisplayBound = contentOffset.y - self.gridLayout.insets.top - self.gridLayout.preloadSize
            let upperDisplayBound = contentOffset.y + self.gridLayout.insets.bottom + self.gridLayout.size.height + self.gridLayout.preloadSize
            
            var presentationItems: [GridNodePresentationItem] = []
            
            var validSections = Set<WrappedGridSection>()
            for item in self.itemLayout.items {
                if item.frame.maxY < lowerDisplayBound {
                    continue
                }
                if item.frame.minY > upperDisplayBound {
                    break
                }
                presentationItems.append(item)
                if self.floatingSections {
                    if let section = self.items[item.index].section {
                        validSections.insert(WrappedGridSection(section))
                    }
                }
            }
            
            var presentationSections: [GridNodePresentationSection] = []
            for section in self.itemLayout.sections {
                if section.frame.origin.y < lowerDisplayBound {
                    if !validSections.contains(WrappedGridSection(section.section)) {
                        continue
                    }
                }
                if section.frame.origin.y + section.frame.size.height > upperDisplayBound {
                    break
                }
                presentationSections.append(section)
            }
            
            return GridNodePresentationLayoutTransition(layout: GridNodePresentationLayout(layout: self.gridLayout, contentOffset: contentOffset, contentSize: self.itemLayout.contentSize, items: presentationItems, sections: presentationSections), directionHint: transitionDirectionHint, transition: transition)
        } else {
            return GridNodePresentationLayoutTransition(layout: GridNodePresentationLayout(layout: self.gridLayout, contentOffset: CGPoint(), contentSize: self.itemLayout.contentSize, items: [], sections: []), directionHint: .up, transition: .immediate)
        }
    }
    
    public func lowestSectionNode() -> ASDisplayNode? {
        var lowestHeaderNode: ASDisplayNode?
        var lowestHeaderNodeIndex: Int?
        for (_, headerNode) in self.sectionNodes {
            if let index = self.subnodes?.firstIndex(of: headerNode) {
                if lowestHeaderNodeIndex == nil || index < lowestHeaderNodeIndex! {
                    lowestHeaderNodeIndex = index
                    lowestHeaderNode = headerNode
                }
            }
        }
        return lowestHeaderNode
    }
    
    private func applyPresentationLayoutTransition(_ presentationLayoutTransition: GridNodePresentationLayoutTransition, removedNodes: [GridItemNode], updateLayoutTransition: ContainedViewLayoutTransition?, customScrollToItem: Bool, itemTransition: ContainedViewLayoutTransition, synchronousLoads: Bool, updatingLayout: Bool, completion: (GridNodeDisplayedItemRange) -> Void) {
        let boundsTransition: ContainedViewLayoutTransition = updateLayoutTransition ?? .immediate
        
        var addedNodes = false
        let verticalIndicator = self.scrollView.subviews.last as? UIImageView
        
        var previousItemFrames: [WrappedGridItemNode: CGRect]?
        var saveItemFrames = false
        switch presentationLayoutTransition.transition {
            case .animated:
                saveItemFrames = true
            case .immediate:
                break
        }
        if case .animated = itemTransition {
            saveItemFrames = true
        }
        
        if saveItemFrames {
            var itemFrames: [WrappedGridItemNode: CGRect] = [:]
            let contentOffset = self.scrollView.contentOffset
            for (_, itemNode) in self.itemNodes {
                itemFrames[WrappedGridItemNode(node: itemNode)] = itemNode.frame.offsetBy(dx: 0.0, dy: -contentOffset.y)
            }
            for (_, sectionNode) in self.sectionNodes {
                itemFrames[WrappedGridItemNode(node: sectionNode)] = sectionNode.frame.offsetBy(dx: 0.0, dy: -contentOffset.y)
            }
            for itemNode in removedNodes {
                itemFrames[WrappedGridItemNode(node: itemNode)] = itemNode.frame.offsetBy(dx: 0.0, dy: -contentOffset.y)
            }
            previousItemFrames = itemFrames
        }
        
        self.applyingContentOffset = true
        
        let previousBounds = self.bounds
        self.scrollView.contentSize = presentationLayoutTransition.layout.contentSize
        let layoutInsets = presentationLayoutTransition.layout.layout.insets
        self.scrollView.contentInset = UIEdgeInsets(top: layoutInsets.top, left: 0.0, bottom: layoutInsets.bottom, right: 0.0)
        if let scrollIndicatorInsets = presentationLayoutTransition.layout.layout.scrollIndicatorInsets {
            self.scrollView.scrollIndicatorInsets = scrollIndicatorInsets
        } else {
            self.scrollView.scrollIndicatorInsets = presentationLayoutTransition.layout.layout.insets
        }
        var boundsOffset: CGFloat = 0.0
        var shouldAnimateBounds = false
        if !self.scrollView.contentOffset.equalTo(presentationLayoutTransition.layout.contentOffset) || self.bounds.size != presentationLayoutTransition.layout.layout.size {
            let updatedBounds = CGRect(origin: presentationLayoutTransition.layout.contentOffset, size: presentationLayoutTransition.layout.layout.size)
            boundsOffset = updatedBounds.origin.y - previousBounds.origin.y
            self.bounds = updatedBounds
            shouldAnimateBounds = true
        }
        self.applyingContentOffset = false
        
        let lowestSectionNode: ASDisplayNode? = self.lowestSectionNode()
        
        let bounds = self.bounds
        var existingItemIndices = Set<Int>()
        for item in presentationLayoutTransition.layout.items {
            existingItemIndices.insert(item.index)
            
            let itemInBounds = bounds.intersects(item.frame)
            
            var absoluteRect = item.frame
            if let itemNode = self.itemNodes[item.index] {
                if itemNode.frame != item.frame {
                    itemNode.frame = item.frame
                }
                itemNode.updateLayout(item: self.items[item.index], size: item.frame.size, isVisible: bounds.intersects(item.frame), synchronousLoads: synchronousLoads && itemInBounds)
                
                if let supernode = self.supernode {
                    absoluteRect = supernode.convert(itemNode.bounds, from: itemNode)
                }
                itemNode.updateAbsoluteRect(absoluteRect, within: bounds.size)
            } else {
                let itemNode = self.items[item.index].node(layout: presentationLayoutTransition.layout.layout, synchronousLoad: synchronousLoads && itemInBounds)
                itemNode.frame = item.frame
                self.addItemNode(index: item.index, itemNode: itemNode, lowestSectionNode: lowestSectionNode)
                addedNodes = true
                itemNode.updateLayout(item: self.items[item.index], size: item.frame.size, isVisible: bounds.intersects(item.frame), synchronousLoads: synchronousLoads)
                self.setupNode?(itemNode)
                
                if let supernode = self.supernode {
                    absoluteRect = supernode.convert(itemNode.bounds, from: itemNode)
                }
                itemNode.updateAbsoluteRect(absoluteRect, within: bounds.size)
            }
        }
        
        var existingSections = Set<WrappedGridSection>()
        for i in 0 ..< presentationLayoutTransition.layout.sections.count {
            let section = presentationLayoutTransition.layout.sections[i]
            
            let wrappedSection = WrappedGridSection(section.section)
            existingSections.insert(wrappedSection)
            
            var sectionFrame = section.frame
            if self.floatingSections {
                var maxY = CGFloat.greatestFiniteMagnitude
                if i != presentationLayoutTransition.layout.sections.count - 1 {
                    maxY = presentationLayoutTransition.layout.sections[i + 1].frame.minY - sectionFrame.height
                }
                sectionFrame.origin.y = max(sectionFrame.minY, min(maxY, presentationLayoutTransition.layout.contentOffset.y + presentationLayoutTransition.layout.layout.insets.top))
            }
            
            if let sectionNode = self.sectionNodes[wrappedSection] {
                sectionNode.frame = sectionFrame
            } else {
                let sectionNode = section.section.node()
                sectionNode.frame = sectionFrame
                self.addSectionNode(section: wrappedSection, sectionNode: sectionNode)
                addedNodes = true
            }
        }
        
        if let previousItemFrames = previousItemFrames, case let .animated(duration, curve) = presentationLayoutTransition.transition {
            let contentOffset = presentationLayoutTransition.layout.contentOffset
            
            if !updatingLayout {
                boundsOffset = 0.0
                shouldAnimateBounds = false
            }
            
            var offset: CGFloat?
            for (index, itemNode) in self.itemNodes {
                if let previousFrame = previousItemFrames[WrappedGridItemNode(node: itemNode)], existingItemIndices.contains(index) {
                    let currentFrame = itemNode.frame.offsetBy(dx: 0.0, dy: -presentationLayoutTransition.layout.contentOffset.y)
                    offset = previousFrame.origin.y - currentFrame.origin.y - boundsOffset
                    break
                }
            }
            
            if offset == nil {
                var previousUpperBound: CGFloat?
                var previousLowerBound: CGFloat?
                for (_, frame) in previousItemFrames {
                    if previousUpperBound == nil || previousUpperBound! > frame.minY {
                        previousUpperBound = frame.minY
                    }
                    if previousLowerBound == nil || previousLowerBound! < frame.maxY {
                        previousLowerBound = frame.maxY
                    }
                }
                
                var updatedUpperBound: CGFloat?
                var updatedLowerBound: CGFloat?
                for item in presentationLayoutTransition.layout.items {
                    let frame = item.frame.offsetBy(dx: 0.0, dy: -contentOffset.y)
                    if updatedUpperBound == nil || updatedUpperBound! > frame.minY {
                        updatedUpperBound = frame.minY
                    }
                    if updatedLowerBound == nil || updatedLowerBound! < frame.maxY {
                        updatedLowerBound = frame.maxY
                    }
                }
                for section in presentationLayoutTransition.layout.sections {
                    let frame = section.frame.offsetBy(dx: 0.0, dy: -contentOffset.y)
                    if updatedUpperBound == nil || updatedUpperBound! > frame.minY {
                        updatedUpperBound = frame.minY
                    }
                    if updatedLowerBound == nil || updatedLowerBound! < frame.maxY {
                        updatedLowerBound = frame.maxY
                    }
                }
                
                if let updatedUpperBound = updatedUpperBound, let updatedLowerBound = updatedLowerBound {
                    switch presentationLayoutTransition.directionHint {
                        case .up:
                            offset = -(updatedLowerBound - (previousUpperBound ?? 0.0))
                        case .down:
                            offset = -(updatedUpperBound - (previousLowerBound ?? presentationLayoutTransition.layout.layout.size.height))
                    }
                }
            }
            
            if let offset = offset {
                let timingFunction = curve.timingFunction
                let mediaTimingFunction = curve.mediaTimingFunction
                
                for (index, itemNode) in self.itemNodes where existingItemIndices.contains(index) {
                    itemNode.layer.animatePosition(from: CGPoint(x: 0.0, y: offset), to: CGPoint(), duration: duration, timingFunction: timingFunction, mediaTimingFunction: mediaTimingFunction, additive: true)
                }
                for (wrappedSection, sectionNode) in self.sectionNodes where existingSections.contains(wrappedSection) {
                    sectionNode.layer.animatePosition(from: CGPoint(x: 0.0, y: offset), to: CGPoint(), duration: duration, timingFunction: timingFunction, mediaTimingFunction: mediaTimingFunction, additive: true)
                }
                
                for index in self.itemNodes.keys {
                    if !existingItemIndices.contains(index) {
                        let itemNode = self.itemNodes[index]!
                        if let previousFrame = previousItemFrames[WrappedGridItemNode(node: itemNode)] {
                            self.removeItemNodeWithIndex(index, removeNode: false)
                            let position = CGPoint(x: previousFrame.midX, y: previousFrame.midY)
                            itemNode.layer.animatePosition(from: CGPoint(x: position.x, y: position.y + contentOffset.y - boundsOffset), to: CGPoint(x: position.x, y: position.y + contentOffset.y - boundsOffset - offset), duration: duration, timingFunction: timingFunction, mediaTimingFunction: mediaTimingFunction, removeOnCompletion: false, force: true, completion: { [weak itemNode] _ in
                                itemNode?.removeFromSupernode()
                            })
                        } else {
                            self.removeItemNodeWithIndex(index, removeNode: true)
                        }
                    }
                }
                
                for itemNode in removedNodes {
                    if let previousFrame = previousItemFrames[WrappedGridItemNode(node: itemNode)] {
                        let position = CGPoint(x: previousFrame.midX, y: previousFrame.midY)
                        itemNode.layer.animatePosition(from: CGPoint(x: position.x, y: position.y + contentOffset.y), to: CGPoint(x: position.x, y: position.y + contentOffset.y - offset), duration: duration, timingFunction: timingFunction, mediaTimingFunction: mediaTimingFunction, removeOnCompletion: false, force: true, completion: { [weak itemNode] _ in
                            itemNode?.removeFromSupernode()
                        })
                    } else {
                        itemNode.removeFromSupernode()
                    }
                }
                
                for wrappedSection in self.sectionNodes.keys {
                    if !existingSections.contains(wrappedSection) {
                        let sectionNode = self.sectionNodes[wrappedSection]!
                        if let previousFrame = previousItemFrames[WrappedGridItemNode(node: sectionNode)] {
                            self.removeSectionNodeWithSection(wrappedSection, removeNode: false)
                            let position = CGPoint(x: previousFrame.midX, y: previousFrame.midY)
                            sectionNode.layer.animatePosition(from: CGPoint(x: position.x, y: position.y + contentOffset.y), to: CGPoint(x: position.x, y: position.y + contentOffset.y - offset), duration: duration, timingFunction: timingFunction, mediaTimingFunction: mediaTimingFunction, removeOnCompletion: false, force: true, completion: { [weak sectionNode] _ in
                                sectionNode?.removeFromSupernode()
                            })
                        } else {
                            self.removeSectionNodeWithSection(wrappedSection, removeNode: true)
                        }
                    }
                }
            } else {
                for index in self.itemNodes.keys {
                    if !existingItemIndices.contains(index) {
                        self.removeItemNodeWithIndex(index)
                    }
                }
                
                for wrappedSection in self.sectionNodes.keys {
                    if !existingSections.contains(wrappedSection) {
                        self.removeSectionNodeWithSection(wrappedSection)
                    }
                }
                
                for itemNode in removedNodes {
                    itemNode.removeFromSupernode()
                }
            }
        } else if let previousItemFrames = previousItemFrames, case let .animated(duration, curve) = itemTransition {
            let timingFunction = curve.timingFunction
            let mediaTimingFunction = curve.mediaTimingFunction
            let contentOffset = self.scrollView.contentOffset
            
            for index in self.itemNodes.keys {
                let itemNode = self.itemNodes[index]!
                if !existingItemIndices.contains(index) {
                    if let _ = previousItemFrames[WrappedGridItemNode(node: itemNode)] {
                        self.removeItemNodeWithIndex(index, removeNode: false)
                        itemNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, removeOnCompletion: false)
                        itemNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, removeOnCompletion: false, completion: { [weak itemNode] _ in
                            itemNode?.removeFromSupernode()
                        })
                    } else {
                        self.removeItemNodeWithIndex(index, removeNode: true)
                    }
                } else if let previousFrame = previousItemFrames[WrappedGridItemNode(node: itemNode)] {
                    itemNode.layer.animatePosition(from: CGPoint(x: previousFrame.midX, y: previousFrame.midY + contentOffset.y), to: itemNode.layer.position, duration: duration, timingFunction: timingFunction, mediaTimingFunction: mediaTimingFunction)
                } else {
                    itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                    itemNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
                }
            }
            
            for itemNode in removedNodes {
                if let _ = previousItemFrames[WrappedGridItemNode(node: itemNode)] {
                    itemNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, removeOnCompletion: false)
                    itemNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.18, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, removeOnCompletion: false, completion: { [weak itemNode] _ in
                        itemNode?.removeFromSupernode()
                    })
                } else {
                    itemNode.removeFromSupernode()
                }
            }
            
            for wrappedSection in self.sectionNodes.keys {
                let sectionNode = self.sectionNodes[wrappedSection]!
                if !existingSections.contains(wrappedSection) {
                    if let _ = previousItemFrames[WrappedGridItemNode(node: sectionNode)] {
                        self.removeSectionNodeWithSection(wrappedSection, removeNode: false)
                        sectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak sectionNode] _ in
                            sectionNode?.removeFromSupernode()
                        })
                    } else {
                        self.removeSectionNodeWithSection(wrappedSection, removeNode: true)
                    }
                } else if let previousFrame = previousItemFrames[WrappedGridItemNode(node: sectionNode)] {
                    sectionNode.layer.animatePosition(from: CGPoint(x: previousFrame.midX, y: previousFrame.midY + contentOffset.y), to: sectionNode.layer.position, duration: duration, timingFunction: timingFunction, mediaTimingFunction: mediaTimingFunction)
                } else {
                    sectionNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                }
            }
        } else {
            for index in self.itemNodes.keys {
                if !existingItemIndices.contains(index) {
                    self.removeItemNodeWithIndex(index)
                }
            }
            
            for wrappedSection in self.sectionNodes.keys {
                if !existingSections.contains(wrappedSection) {
                    self.removeSectionNodeWithSection(wrappedSection)
                }
            }
            
            for itemNode in removedNodes {
                itemNode.removeFromSupernode()
            }
        }
        
        if shouldAnimateBounds {
            boundsTransition.animateBounds(layer: self.layer, from: previousBounds)
        }
        
        completion(self.displayedItemRange())
        
        self.updateItemNodeVisibilititesAndScrolling()
        self.updateVisibleContentOffset()
        
        if let visibleItemsUpdated = self.visibleItemsUpdated {
            if presentationLayoutTransition.layout.items.count != 0 {
                let topIndex = presentationLayoutTransition.layout.items.first!.index
                let bottomIndex = presentationLayoutTransition.layout.items.last!.index
                
                var topVisible: (Int, GridItem) = (topIndex, self.items[topIndex])
                let bottomVisible: (Int, GridItem) = (bottomIndex, self.items[bottomIndex])
                
                let lowerDisplayBound = presentationLayoutTransition.layout.contentOffset.y + presentationLayoutTransition.layout.layout.insets.top
                //let upperDisplayBound = presentationLayoutTransition.layout.contentOffset.y + self.gridLayout.size.height
                
                for item in presentationLayoutTransition.layout.items {
                    if lowerDisplayBound.isLess(than: item.frame.maxY) {
                        topVisible = (item.index, self.items[item.index])
                        break
                    }
                }
                
                var topSectionVisible: GridSection?
                for section in presentationLayoutTransition.layout.sections {
                    if lowerDisplayBound.isLess(than: section.frame.maxY) {
                        if self.itemLayout.items[topVisible.0].frame.minY > section.frame.minY {
                            topSectionVisible = section.section
                        }
                        break
                    }
                }
                
                visibleItemsUpdated(GridNodeVisibleItems(top: (topIndex, self.items[topIndex]), bottom: (bottomIndex, self.items[bottomIndex]), topVisible: topVisible, bottomVisible: bottomVisible, topSectionVisible: topSectionVisible, count: self.items.count))
            } else {
                visibleItemsUpdated(GridNodeVisibleItems(top: nil, bottom: nil, topVisible: nil, bottomVisible: nil, topSectionVisible: nil, count: self.items.count))
            }
        }
        
        if addedNodes {
            if let verticalIndicator = verticalIndicator, self.scrollView.subviews.last !== verticalIndicator {
                verticalIndicator.superview?.bringSubviewToFront(verticalIndicator)
            }
        }
        
        if let presentationLayoutUpdated = self.presentationLayoutUpdated {
            presentationLayoutUpdated(GridNodeCurrentPresentationLayout(layout: presentationLayoutTransition.layout.layout, contentOffset: presentationLayoutTransition.layout.contentOffset, contentSize: presentationLayoutTransition.layout.contentSize), updateLayoutTransition ?? presentationLayoutTransition.transition)
        }
    }
    
    private func addItemNode(index: Int, itemNode: GridItemNode, lowestSectionNode: ASDisplayNode?) {
        assert(self.itemNodes[index] == nil)
        self.itemNodes[index] = itemNode
        if itemNode.supernode == nil {
            if let lowestSectionNode = lowestSectionNode {
                self.insertSubnode(itemNode, belowSubnode: lowestSectionNode)
            } else {
                self.addSubnode(itemNode)
            }
        }
    }
    
    private func addSectionNode(section: WrappedGridSection, sectionNode: ASDisplayNode) {
        assert(self.sectionNodes[section] == nil)
        self.sectionNodes[section] = sectionNode
        if sectionNode.supernode == nil {
            self.addSubnode(sectionNode)
        }
    }
    
    private func removeItemNodeWithIndex(_ index: Int, removeNode: Bool = true) {
        if let itemNode = self.itemNodes.removeValue(forKey: index) {
            if removeNode {
                itemNode.removeFromSupernode()
            }
        }
    }
    
    private func removeSectionNodeWithSection(_ section: WrappedGridSection, removeNode: Bool = true) {
        if let sectionNode = self.sectionNodes.removeValue(forKey: section) {
            if removeNode {
                sectionNode.removeFromSupernode()
            }
        }
    }
    
    public var forceHidden = false {
        didSet {
            self.updateItemNodeVisibilititesAndScrolling()
        }
    }
    private func updateItemNodeVisibilititesAndScrolling() {
        let visibleRect = self.scrollView.bounds
        let isScrolling = self.scrollView.isDragging || self.scrollView.isDecelerating
        for (_, itemNode) in self.itemNodes {
            let visible = itemNode.frame.intersects(visibleRect) && !self.forceHidden
            if itemNode.isVisibleInGrid != visible {
                itemNode.isVisibleInGrid = visible
            }
            if itemNode.isGridScrolling != isScrolling {
                itemNode.isGridScrolling = isScrolling
            }
        }
    }
    
    public func visibleContentOffset() -> GridNodeVisibleContentOffset {
        var offset: GridNodeVisibleContentOffset = .unknown
        
        if let supernode = self.supernode {
            var topItemIndexAndFrame: (Int, CGRect) = (-1, CGRect())
            for index in self.itemNodes.keys.sorted() {
                let itemNode = self.itemNodes[index]!
                topItemIndexAndFrame = (index, supernode.convert(itemNode.bounds, from: itemNode))
                break
            }
            if topItemIndexAndFrame.0 == 0 {
                offset = .known(self.scrollView.contentOffset.y + self.scrollView.contentInset.top)
            } else if topItemIndexAndFrame.0 == -1 {
                offset = .none
            }
        }
        return offset
    }
    
    private func updateVisibleContentOffset() {
        self.visibleContentOffsetChanged(self.visibleContentOffset())
    }
    
    public func forEachItemNode(_ f: (ASDisplayNode) -> Void) {
        for (_, node) in self.itemNodes {
            f(node)
        }
    }
    
    public func forEachRow(_ f: ([ASDisplayNode]) -> Void) {
        var row: [ASDisplayNode] = []
        var previousMinY: CGFloat?
        for index in self.itemNodes.keys.sorted() {
            let itemNode = self.itemNodes[index]!
            if let previousMinY = previousMinY, !previousMinY.isEqual(to: itemNode.frame.minY) {
                if !row.isEmpty {
                    f(row)
                    row.removeAll()
                }
            }
            previousMinY = itemNode.frame.minY
            row.append(itemNode)
        }
        if !row.isEmpty {
            f(row)
        }
    }
    
    public func itemNodeAtPoint(_ point: CGPoint) -> ASDisplayNode? {
        for (_, node) in self.itemNodes {
            if node.frame.contains(point) {
                return node
            }
        }
        return nil
    }
}

private func NH_LP_TABLE_LOOKUP(_ table: inout [Int], _ i: Int, _ j: Int, _ rowsize: Int) -> Int {
    return table[i * rowsize + j]
}

private func NH_LP_TABLE_LOOKUP_SET(_ table: inout [Int], _ i: Int, _ j: Int, _ rowsize: Int, _ value: Int) {
    table[i * rowsize + j] = value
}

private func linearPartitionTable(_ weights: [Int], numberOfPartitions: Int) -> [Int] {
    let n = weights.count
    let k = numberOfPartitions
    
    let tableSize = n * k;
    var tmpTable = Array<Int>(repeatElement(0, count: tableSize))
    
    let solutionSize = (n - 1) * (k - 1)
    var solution = Array<Int>(repeatElement(0, count: solutionSize))
    
    for i in 0 ..< n {
        let offset = i != 0 ? NH_LP_TABLE_LOOKUP(&tmpTable, i - 1, 0, k) : 0
        NH_LP_TABLE_LOOKUP_SET(&tmpTable, i, 0, k, Int(weights[i]) + offset)
    }
    
    for j in 0 ..< k {
        NH_LP_TABLE_LOOKUP_SET(&tmpTable, 0, j, k, Int(weights[0]))
    }
    
    for i in 1 ..< n {
        for j in 1 ..< k {
            var currentMin = 0
            var minX = Int.max
            
            for x in 0 ..< i {
                let c1 = NH_LP_TABLE_LOOKUP(&tmpTable, x, j - 1, k)
                let c2 = NH_LP_TABLE_LOOKUP(&tmpTable, i, 0, k) - NH_LP_TABLE_LOOKUP(&tmpTable, x, 0, k)
                let cost = max(c1, c2)
                
                if x == 0 || cost < currentMin {
                    currentMin = cost;
                    minX = x
                }
            }
            
            NH_LP_TABLE_LOOKUP_SET(&tmpTable, i, j, k, currentMin)
            NH_LP_TABLE_LOOKUP_SET(&solution, i - 1, j - 1, k - 1, minX)
        }
    }
    
    return solution
}

private func linearPartitionForWeights(_ weights: [Int], numberOfPartitions: Int) -> [[Int]] {
    var n = weights.count
    var k = numberOfPartitions
    
    if k <= 0 {
        return []
    }
    
    if k >= n {
        var partition: [[Int]] = []
        for weight in weights {
            partition.append([weight])
        }
        return partition
    }
    
    if n == 1 {
        return [weights]
    }
    
    var solution = linearPartitionTable(weights, numberOfPartitions: numberOfPartitions)
    let solutionRowSize = numberOfPartitions - 1
    
    k = k - 2;
    n = n - 1;
    
    var answer: [[Int]] = []
    
    while k >= 0 {
        if n < 1 {
            answer.insert([], at: 0)
        } else {
            var currentAnswer: [Int] = []
            
            var i = NH_LP_TABLE_LOOKUP(&solution, n - 1, k, solutionRowSize) + 1
            let range = n + 1
            while i < range {
                currentAnswer.append(weights[i])
                i += 1
            }
            
            answer.insert(currentAnswer, at: 0)
            
            n = NH_LP_TABLE_LOOKUP(&solution, n - 1, k, solutionRowSize)
        }
        
        k = k - 1
    }
    
    var currentAnswer: [Int] = []
    var i = 0
    let range = n + 1
    while i < range {
        currentAnswer.append(weights[i])
        i += 1
    }
    
    answer.insert(currentAnswer, at: 0)
    
    return answer
}

