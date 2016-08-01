import UIKit
import AsyncDisplayKit
import SwiftSignalKit

private let usePerformanceTracker = false
private let useDynamicTuning = false

public enum ListViewCenterScrollPositionOverflow {
    case Top
    case Bottom
}

public enum ListViewScrollPosition: Equatable {
    case Top
    case Bottom
    case Center(ListViewCenterScrollPositionOverflow)
}

public func ==(lhs: ListViewScrollPosition, rhs: ListViewScrollPosition) -> Bool {
    switch lhs {
        case .Top:
            switch rhs {
                case .Top:
                    return true
                default:
                    return false
            }
        case .Bottom:
            switch rhs {
                case .Bottom:
                    return true
                default:
                    return false
            }
        case let .Center(lhsOverflow):
            switch rhs {
                case let .Center(rhsOverflow) where lhsOverflow == rhsOverflow:
                    return true
                default:
                    return false
            }
    }
}

public enum ListViewScrollToItemDirectionHint {
    case Up
    case Down
}

public enum ListViewAnimationCurve {
    case Spring(speed: CGFloat)
    case Default
}

public struct ListViewScrollToItem {
    public let index: Int
    public let position: ListViewScrollPosition
    public let animated: Bool
    public let curve: ListViewAnimationCurve
    public let directionHint: ListViewScrollToItemDirectionHint
    
    public init(index: Int, position: ListViewScrollPosition, animated: Bool, curve: ListViewAnimationCurve, directionHint: ListViewScrollToItemDirectionHint) {
        self.index = index
        self.position = position
        self.animated = animated
        self.curve = curve
        self.directionHint = directionHint
    }
}

public enum ListViewItemOperationDirectionHint {
    case Up
    case Down
}

public struct ListViewDeleteItem {
    public let index: Int
    public let directionHint: ListViewItemOperationDirectionHint?
    
    public init(index: Int, directionHint: ListViewItemOperationDirectionHint?) {
        self.index = index
        self.directionHint = directionHint
    }
}

public struct ListViewInsertItem {
    public let index: Int
    public let previousIndex: Int?
    public let item: ListViewItem
    public let directionHint: ListViewItemOperationDirectionHint?
    
    public init(index: Int, previousIndex: Int?, item: ListViewItem, directionHint: ListViewItemOperationDirectionHint?) {
        self.index = index
        self.previousIndex = previousIndex
        self.item = item
        self.directionHint = directionHint
    }
}

public struct ListViewUpdateItem {
    public let index: Int
    public let item: ListViewItem
    public let directionHint: ListViewItemOperationDirectionHint?
    
    public init(index: Int, item: ListViewItem, directionHint: ListViewItemOperationDirectionHint?) {
        self.index = index
        self.item = item
        self.directionHint = directionHint
    }
}

public struct ListViewDeleteAndInsertOptions: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let AnimateInsertion = ListViewDeleteAndInsertOptions(rawValue: 1)
    public static let AnimateAlpha = ListViewDeleteAndInsertOptions(rawValue: 2)
    public static let LowLatency = ListViewDeleteAndInsertOptions(rawValue: 4)
    public static let Synchronous = ListViewDeleteAndInsertOptions(rawValue: 8)
}

public struct ListViewUpdateSizeAndInsets {
    public let size: CGSize
    public let insets: UIEdgeInsets
    public let duration: Double
    public let curve: ListViewAnimationCurve
    
    public init(size: CGSize, insets: UIEdgeInsets, duration: Double, curve: ListViewAnimationCurve) {
        self.size = size
        self.insets = insets
        self.duration = duration
        self.curve = curve
    }
}

public struct ListViewItemRange: Equatable {
    public let firstIndex: Int
    public let lastIndex: Int
}

public func ==(lhs: ListViewItemRange, rhs: ListViewItemRange) -> Bool {
    return lhs.firstIndex == rhs.firstIndex && lhs.lastIndex == rhs.lastIndex
}

public struct ListViewDisplayedItemRange: Equatable {
    public let loadedRange: ListViewItemRange?
    public let visibleRange: ListViewItemRange?
}

public func ==(lhs: ListViewDisplayedItemRange, rhs: ListViewDisplayedItemRange) -> Bool {
    return lhs.loadedRange == rhs.loadedRange && lhs.visibleRange == rhs.visibleRange
}

private struct IndexRange {
    let first: Int
    let last: Int
    
    func contains(_ index: Int) -> Bool {
        return index >= first && index <= last
    }
    
    var empty: Bool {
        return first > last
    }
}

private struct OffsetRanges {
    var offsets: [(IndexRange, CGFloat)] = []
    
    mutating func append(_ other: OffsetRanges) {
        self.offsets.append(contentsOf: other.offsets)
    }
    
    mutating func offset(_ indexRange: IndexRange, offset: CGFloat) {
        self.offsets.append((indexRange, offset))
    }
    
    func offsetForIndex(_ index: Int) -> CGFloat {
        var result: CGFloat = 0.0
        for offset in self.offsets {
            if offset.0.contains(index) {
                result += offset.1
            }
        }
        return result
    }
}

private func binarySearch(_ inputArr: [Int], searchItem: Int) -> Int? {
    var lowerIndex = 0;
    var upperIndex = inputArr.count - 1
    
    if lowerIndex > upperIndex {
        return nil
    }
    
    while (true) {
        let currentIndex = (lowerIndex + upperIndex) / 2
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
}

private struct TransactionState {
    let visibleSize: CGSize
    let items: [ListViewItem]
}

private struct PendingNode {
    let index: Int
    let node: ListViewItemNode
    let apply: () -> ()
    let frame: CGRect
    let apparentHeight: CGFloat
}

private enum ListViewStateNode {
    case Node(index: Int, frame: CGRect, referenceNode: ListViewItemNode?)
    case Placeholder(frame: CGRect)
    
    var index: Int? {
        switch self {
            case .Node(let index, _, _):
                return index
            case .Placeholder(_):
                return nil
        }
    }
    
    var frame: CGRect {
        get {
            switch self {
                case .Node(_, let frame, _):
                    return frame
                case .Placeholder(let frame):
                    return frame
            }
        } set(value) {
            switch self {
                case let .Node(index, _, referenceNode):
                    self = .Node(index: index, frame: value, referenceNode: referenceNode)
                case .Placeholder(_):
                    self = .Placeholder(frame: value)
            }
        }
    }
}

private enum ListViewInsertionOffsetDirection {
    case Up
    case Down
    
    init(_ hint: ListViewItemOperationDirectionHint) {
        switch hint {
            case .Up:
                self = .Up
            case .Down:
                self = .Down
        }
    }
    
    func inverted() -> ListViewInsertionOffsetDirection {
        switch self {
            case .Up:
                return .Down
            case .Down:
                return .Up
        }
    }
}

private struct ListViewInsertionPoint {
    let index: Int
    let point: CGPoint
    let direction: ListViewInsertionOffsetDirection
}

private struct ListViewState {
    var insets: UIEdgeInsets
    var visibleSize: CGSize
    let invisibleInset: CGFloat
    var nodes: [ListViewStateNode]
    var scrollPosition: (Int, ListViewScrollPosition)?
    var stationaryOffset: (Int, CGFloat)?
    
    mutating func fixScrollPostition(_ itemCount: Int) {
        if let (fixedIndex, fixedPosition) = self.scrollPosition {
            for node in self.nodes {
                if let index = node.index where index == fixedIndex {
                    let offset: CGFloat
                    switch fixedPosition {
                        case .Bottom:
                            offset = (self.visibleSize.height - self.insets.bottom) - node.frame.maxY
                        case .Top:
                            offset = self.insets.top - node.frame.minY
                        case let .Center(overflow):
                            let contentAreaHeight = self.visibleSize.height - self.insets.bottom - self.insets.top
                            if node.frame.size.height <= contentAreaHeight + CGFloat(FLT_EPSILON) {
                                offset = self.insets.top + floor((contentAreaHeight - node.frame.size.height) / 2.0) - node.frame.minY
                            } else {
                                switch overflow {
                                    case .Top:
                                        offset = self.insets.top - node.frame.minY
                                    case .Bottom:
                                        offset = (self.visibleSize.height - self.insets.bottom) - node.frame.maxY
                                }
                            }
                    }
                    
                    var minY: CGFloat = CGFloat.greatestFiniteMagnitude
                    var maxY: CGFloat = 0.0
                    for i in 0 ..< self.nodes.count {
                        var frame = self.nodes[i].frame
                        frame.offsetInPlace(dx: 0.0, dy: offset)
                        self.nodes[i].frame = frame
                        
                        minY = min(minY, frame.minY)
                        maxY = max(maxY, frame.maxY)
                    }
                    
                    var additionalOffset: CGFloat = 0.0
                    if minY > self.insets.top {
                        additionalOffset = self.insets.top - minY
                    }
                    
                    if abs(additionalOffset) > CGFloat(FLT_EPSILON) {
                        for i in 0 ..< self.nodes.count {
                            var frame = self.nodes[i].frame
                            frame.offsetInPlace(dx: 0.0, dy: additionalOffset)
                            self.nodes[i].frame = frame
                        }
                    }
                    
                    self.snapToBounds(itemCount, snapTopItem: true)
                    
                    break
                }
            }
        } else if let (stationaryIndex, stationaryOffset) = self.stationaryOffset {
            for node in self.nodes {
                if node.index == stationaryIndex {
                    let offset = stationaryOffset - node.frame.minY
                    
                    if abs(offset) > CGFloat(FLT_EPSILON) {
                        for i in 0 ..< self.nodes.count {
                            var frame = self.nodes[i].frame
                            frame.offsetInPlace(dx: 0.0, dy: offset)
                            self.nodes[i].frame = frame
                        }
                    }
                    
                    break
                }
            }
            
            //self.snapToBounds(itemCount, snapTopItem: true)
        }
    }
    
    mutating func setupStationaryOffset(_ index: Int, boundary: Int, frames: [Int: CGRect]) {
        if index < boundary {
            for node in self.nodes {
                if let nodeIndex = node.index where nodeIndex >= index {
                    if let frame = frames[nodeIndex] {
                        self.stationaryOffset = (nodeIndex, frame.minY)
                        break
                    }
                }
            }
        } else {
            for node in self.nodes.reversed() {
                if let nodeIndex = node.index where nodeIndex <= index {
                    if let frame = frames[nodeIndex] {
                        self.stationaryOffset = (nodeIndex, frame.minY)
                        break
                    }
                }
            }
        }
    }
    
    mutating func snapToBounds(_ itemCount: Int, snapTopItem: Bool) {
        var completeHeight: CGFloat = 0.0
        var topItemFound = false
        var bottomItemFound = false
        var topItemEdge: CGFloat = 0.0
        var bottomItemEdge: CGFloat = 0.0
        
        for node in self.nodes {
            if let index = node.index {
                if index == 0 {
                    topItemFound = true
                    topItemEdge = node.frame.minY
                }
                break
            }
        }
        
        for node in self.nodes.reversed() {
            if let index = node.index {
                if index == itemCount - 1 {
                    bottomItemFound = true
                    bottomItemEdge = node.frame.maxY
                }
                break
            }
        }
        
        if topItemFound && bottomItemFound {
            for node in self.nodes {
                completeHeight += node.frame.size.height
            }
        }
        
        let overscroll: CGFloat = 0.0
        
        var offset: CGFloat = 0.0
        if topItemFound && bottomItemFound {
            let areaHeight = min(completeHeight, self.visibleSize.height - self.insets.bottom - self.insets.top)
            if bottomItemEdge < self.insets.top + areaHeight - overscroll {
                offset = self.insets.top + areaHeight - overscroll - bottomItemEdge
            } else if topItemEdge > self.insets.top - overscroll && snapTopItem {
                offset = (self.insets.top - overscroll) - topItemEdge
            }
        } else if topItemFound {
            if topItemEdge > self.insets.top - overscroll && snapTopItem {
                offset = (self.insets.top - overscroll) - topItemEdge
            }
        } else if bottomItemFound {
            if bottomItemEdge < self.visibleSize.height - self.insets.bottom - overscroll {
                offset = self.visibleSize.height - self.insets.bottom - overscroll - bottomItemEdge
            }
        }
        
        if abs(offset) > CGFloat(FLT_EPSILON) {
            for i in  0 ..< self.nodes.count {
                var frame = self.nodes[i].frame
                frame.origin.y += offset
                self.nodes[i].frame = frame
            }
        }
    }
    
    func insertionPoint(_ insertDirectionHints: [Int: ListViewItemOperationDirectionHint], itemCount: Int) -> ListViewInsertionPoint? {
        var fixedNode: (nodeIndex: Int, index: Int, frame: CGRect)?
        
        if let (fixedIndex, _) = self.scrollPosition {
            for i in 0 ..< self.nodes.count {
                let node = self.nodes[i]
                if let index = node.index where index == fixedIndex {
                    fixedNode = (i, index, node.frame)
                    break
                }
            }
            
            if fixedNode == nil {
                return ListViewInsertionPoint(index: fixedIndex, point: CGPoint(), direction: .Down)
            }
        }
        
        if fixedNode == nil {
            if let (fixedIndex, _) = self.stationaryOffset {
                for i in 0 ..< self.nodes.count {
                    let node = self.nodes[i]
                    if let index = node.index where index == fixedIndex {
                        fixedNode = (i, index, node.frame)
                        break
                    }
                }
            }
        }
        
        if fixedNode == nil {
            for i in 0 ..< self.nodes.count {
                let node = self.nodes[i]
                if let index = node.index where node.frame.maxY >= self.insets.top {
                    fixedNode = (i, index, node.frame)
                    break
                }
            }
        }
        
        if fixedNode == nil && self.nodes.count != 0 {
            for i in (0 ..< self.nodes.count).reversed() {
                let node = self.nodes[i]
                if let index = node.index {
                    fixedNode = (i, index, node.frame)
                    break
                }
            }
        }
        
        if let fixedNode = fixedNode {
            var currentUpperNode = fixedNode
            for i in (0 ..< fixedNode.nodeIndex).reversed() {
                let node = self.nodes[i]
                if let index = node.index {
                    if index != currentUpperNode.index - 1 {
                        if currentUpperNode.frame.minY > -self.invisibleInset - CGFloat(FLT_EPSILON) {
                            var directionHint: ListViewInsertionOffsetDirection?
                            if let hint = insertDirectionHints[currentUpperNode.index - 1] where currentUpperNode.frame.minY > self.insets.top - CGFloat(FLT_EPSILON) {
                                directionHint = ListViewInsertionOffsetDirection(hint)
                            }
                            return ListViewInsertionPoint(index: currentUpperNode.index - 1, point: CGPoint(x: 0.0, y: currentUpperNode.frame.minY), direction: directionHint ?? .Up)
                        } else {
                            break
                        }
                    }
                    currentUpperNode = (i, index, node.frame)
                }
            }
            
            if currentUpperNode.index != 0 && currentUpperNode.frame.minY > -self.invisibleInset - CGFloat(FLT_EPSILON) {
                var directionHint: ListViewInsertionOffsetDirection?
                if let hint = insertDirectionHints[currentUpperNode.index - 1] where currentUpperNode.frame.minY > self.insets.top - CGFloat(FLT_EPSILON) {
                    directionHint = ListViewInsertionOffsetDirection(hint)
                }
                
                return ListViewInsertionPoint(index: currentUpperNode.index - 1, point: CGPoint(x: 0.0, y: currentUpperNode.frame.minY), direction: directionHint ?? .Up)
            }
            
            var currentLowerNode = fixedNode
            if fixedNode.nodeIndex + 1 < self.nodes.count {
                for i in (fixedNode.nodeIndex + 1) ..< self.nodes.count {
                    let node = self.nodes[i]
                    if let index = node.index {
                        if index != currentLowerNode.index + 1 {
                            if currentLowerNode.frame.maxY < self.visibleSize.height + self.invisibleInset - CGFloat(FLT_EPSILON) {
                                var directionHint: ListViewInsertionOffsetDirection?
                                if let hint = insertDirectionHints[currentLowerNode.index + 1] where currentLowerNode.frame.maxY < self.visibleSize.height - self.insets.bottom + CGFloat(FLT_EPSILON) {
                                    directionHint = ListViewInsertionOffsetDirection(hint)
                                }
                                return ListViewInsertionPoint(index: currentLowerNode.index + 1, point: CGPoint(x: 0.0, y: currentLowerNode.frame.maxY), direction: directionHint ?? .Down)
                            } else {
                                break
                            }
                        }
                        currentLowerNode = (i, index, node.frame)
                    }
                }
            }
            
            if currentLowerNode.index != itemCount - 1 && currentLowerNode.frame.maxY < self.visibleSize.height + self.invisibleInset - CGFloat(FLT_EPSILON) {
                var directionHint: ListViewInsertionOffsetDirection?
                if let hint = insertDirectionHints[currentLowerNode.index + 1] where currentLowerNode.frame.maxY < self.visibleSize.height - self.insets.bottom + CGFloat(FLT_EPSILON) {
                    directionHint = ListViewInsertionOffsetDirection(hint)
                }
                return ListViewInsertionPoint(index: currentLowerNode.index + 1, point: CGPoint(x: 0.0, y: currentLowerNode.frame.maxY), direction: directionHint ?? .Down)
            }
        } else if itemCount != 0 {
            return ListViewInsertionPoint(index: 0, point: CGPoint(x: 0.0, y: self.insets.top), direction: .Down)
        }
        
        return nil
    }
    
    mutating func removeInvisibleNodes(_ operations: inout [ListViewStateOperation]) {
        var i = 0
        var visibleItemNodeHeight: CGFloat = 0.0
        while i < self.nodes.count {
            visibleItemNodeHeight += self.nodes[i].frame.height
            i += 1
        }
        
        if visibleItemNodeHeight > (self.visibleSize.height + self.invisibleInset + self.invisibleInset) {
            i = self.nodes.count - 1
            while i >= 0 {
                let itemNode = self.nodes[i]
                let frame = itemNode.frame
                if frame.maxY < -self.invisibleInset || frame.origin.y > self.visibleSize.height + self.invisibleInset {
                    //print("remove \(i)")
                    operations.append(.Remove(index: i, offsetDirection: frame.maxY < -self.invisibleInset ? .Down : .Up))
                    self.nodes.remove(at: i)
                }
                
                i -= 1
            }
        }
        
        let upperBound = -self.invisibleInset + CGFloat(FLT_EPSILON)
        for i in 0 ..< self.nodes.count {
            let node = self.nodes[i]
            if let index = node.index where node.frame.maxY > upperBound {
                if i != 0 {
                    var previousIndex = index
                    for j in (0 ..< i).reversed() {
                        if self.nodes[j].frame.maxY < upperBound {
                            if let index = self.nodes[j].index {
                                if index != previousIndex - 1 {
                                    print("remove monotonity \(j) (\(index))")
                                    operations.append(.Remove(index: j, offsetDirection: .Down))
                                    self.nodes.remove(at: j)
                                } else {
                                    previousIndex = index
                                }
                            }
                        }
                    }
                }
                break
            }
        }
        
        let lowerBound = self.visibleSize.height + self.invisibleInset - CGFloat(FLT_EPSILON)
        for i in (0 ..< self.nodes.count).reversed() {
            let node = self.nodes[i]
            if let index = node.index where node.frame.minY < lowerBound {
                if i != self.nodes.count - 1 {
                    var previousIndex = index
                    var removeIndices: [Int] = []
                    for j in (i + 1) ..< self.nodes.count {
                        if self.nodes[j].frame.minY > lowerBound {
                            if let index = self.nodes[j].index {
                                if index != previousIndex + 1 {
                                    removeIndices.append(j)
                                } else {
                                    previousIndex = index
                                }
                            }
                        }
                    }
                    if !removeIndices.isEmpty {
                        for i in removeIndices.reversed() {
                            print("remove monotonity \(i) (\(self.nodes[i].index!))")
                            operations.append(.Remove(index: i, offsetDirection: .Up))
                            self.nodes.remove(at: i)
                        }
                    }
                }
                break
            }
        }
    }
    
    func nodeInsertionPointAndIndex(_ itemIndex: Int) -> (CGPoint, Int) {
        if self.nodes.count == 0 {
            return (CGPoint(x: 0.0, y: self.insets.top), 0)
        } else {
            var index = 0
            var lastNodeWithIndex = -1
            for node in self.nodes {
                if let nodeItemIndex = node.index {
                    if nodeItemIndex > itemIndex {
                        break
                    }
                    lastNodeWithIndex = index
                }
                index += 1
            }
            lastNodeWithIndex += 1
            return (CGPoint(x: 0.0, y: lastNodeWithIndex == 0 ? self.nodes[0].frame.minY : self.nodes[lastNodeWithIndex - 1].frame.maxY), lastNodeWithIndex)
        }
    }
    
    func continuousHeightRelativeToNodeIndex(_ fixedNodeIndex: Int) -> CGFloat {
        let fixedIndex = self.nodes[fixedNodeIndex].index!
        
        var height: CGFloat = 0.0
        
        if fixedNodeIndex != 0 {
            var upperIndex = fixedIndex
            for i in (0 ..< fixedNodeIndex).reversed() {
                if let index = self.nodes[i].index {
                    if index == upperIndex - 1 {
                        height += self.nodes[i].frame.size.height
                        upperIndex = index
                    } else {
                        break
                    }
                }
            }
        }
        
        if fixedNodeIndex != self.nodes.count - 1 {
            var lowerIndex = fixedIndex
            for i in (fixedNodeIndex + 1) ..< self.nodes.count {
                if let index = self.nodes[i].index {
                    if index == lowerIndex + 1 {
                        height += self.nodes[i].frame.size.height
                        lowerIndex = index
                    } else {
                        break
                    }
                }
            }
        }
        
        return height
    }
    
    mutating func insertNode(_ itemIndex: Int, node: ListViewItemNode, layout: ListViewItemNodeLayout, apply: () -> (), offsetDirection: ListViewInsertionOffsetDirection, animated: Bool, operations: inout [ListViewStateOperation], itemCount: Int) {
        let (insertionOrigin, insertionIndex) = self.nodeInsertionPointAndIndex(itemIndex)
        
        let nodeOrigin: CGPoint
        switch offsetDirection {
            case .Up:
                nodeOrigin = CGPoint(x: insertionOrigin.x, y: insertionOrigin.y - (animated ? 0.0 : layout.size.height))
            case .Down:
                nodeOrigin = insertionOrigin
        }
        
        let nodeFrame = CGRect(origin: nodeOrigin, size: CGSize(width: layout.size.width, height: animated ? 0.0 : layout.size.height))
        
        operations.append(.InsertNode(index: insertionIndex, offsetDirection: offsetDirection, node: node, layout: layout, apply: apply))
        self.nodes.insert(.Node(index: itemIndex, frame: nodeFrame, referenceNode: nil), at: insertionIndex)
        
        if !animated {
            switch offsetDirection {
                case .Up:
                    var i = insertionIndex - 1
                    while i >= 0 {
                        var frame = self.nodes[i].frame
                        frame.origin.y -= nodeFrame.size.height
                        self.nodes[i].frame = frame
                        i -= 1
                    }
                case .Down:
                    var i = insertionIndex + 1
                    while i < self.nodes.count {
                        var frame = self.nodes[i].frame
                        frame.origin.y += nodeFrame.size.height
                        self.nodes[i].frame = frame
                        i += 1
                }
            }
        }
        
        var previousIndex: Int?
        for node in self.nodes {
            if let index = node.index {
                if let currentPreviousIndex = previousIndex {
                    if index <= currentPreviousIndex {
                        print("index <= previousIndex + 1")
                        break
                    }
                    previousIndex = index
                } else {
                    previousIndex = index
                }
            }
        }
        
        if let _ = self.scrollPosition {
            self.fixScrollPostition(itemCount)
        }
    }
    
    mutating func removeNodeAtIndex(_ index: Int, direction: ListViewItemOperationDirectionHint?, animated: Bool, operations: inout [ListViewStateOperation]) {
        let node = self.nodes[index]
        if case let .Node(_, _, referenceNode) = node {
            let nodeFrame = node.frame
            self.nodes.remove(at: index)
            let offsetDirection: ListViewInsertionOffsetDirection
            if let direction = direction {
                offsetDirection = ListViewInsertionOffsetDirection(direction)
            } else {
                if nodeFrame.maxY < self.insets.top + CGFloat(FLT_EPSILON) {
                    offsetDirection = .Down
                } else {
                    offsetDirection = .Up
                }
            }
            operations.append(.Remove(index: index, offsetDirection: offsetDirection))
            
            if let referenceNode = referenceNode where animated {
                self.nodes.insert(.Placeholder(frame: nodeFrame), at: index)
                operations.append(.InsertPlaceholder(index: index, referenceNode: referenceNode, offsetDirection: offsetDirection.inverted()))
            } else {
                if nodeFrame.maxY > self.insets.top - CGFloat(FLT_EPSILON) {
                    if let direction = direction where direction == .Down && node.frame.minY < self.visibleSize.height - self.insets.bottom + CGFloat(FLT_EPSILON) {
                        for i in (0 ..< index).reversed() {
                            var frame = self.nodes[i].frame
                            frame.origin.y += nodeFrame.size.height
                            self.nodes[i].frame = frame
                        }
                    } else {
                        for i in index ..< self.nodes.count {
                            var frame = self.nodes[i].frame
                            frame.origin.y -= nodeFrame.size.height
                            self.nodes[i].frame = frame
                        }
                    }
                } else if index != 0 {
                    for i in (0 ..< index).reversed() {
                        var frame = self.nodes[i].frame
                        frame.origin.y += nodeFrame.size.height
                        self.nodes[i].frame = frame
                    }
                }
            }
        } else {
            assertionFailure()
        }
    }
    
    mutating func updateNodeAtItemIndex(_ itemIndex: Int, layout: ListViewItemNodeLayout, direction: ListViewItemOperationDirectionHint?, animation: ListViewItemUpdateAnimation, apply: () -> Void, operations: inout [ListViewStateOperation]) {
        var i = -1
        for node in self.nodes {
            i += 1
            if node.index == itemIndex {
                switch animation {
                    case .None:
                        let offsetDirection: ListViewInsertionOffsetDirection
                        if let direction = direction {
                            offsetDirection = ListViewInsertionOffsetDirection(direction)
                        } else {
                            if node.frame.maxY < self.insets.top + CGFloat(FLT_EPSILON) {
                                offsetDirection = .Down
                            } else {
                                offsetDirection = .Up
                            }
                        }
                        
                        switch offsetDirection {
                            case .Up:
                                let offsetDelta = -(layout.size.height - node.frame.size.height)
                                var updatedFrame = node.frame
                                updatedFrame.origin.y += offsetDelta
                                updatedFrame.size.height = layout.size.height
                                self.nodes[i].frame = updatedFrame
                            
                                for j in 0 ..< i {
                                    var frame = self.nodes[j].frame
                                    frame.origin.y += offsetDelta
                                    self.nodes[j].frame = frame
                                }
                            case .Down:
                                let offsetDelta = layout.size.height - node.frame.size.height
                                var updatedFrame = node.frame
                                updatedFrame.size.height = layout.size.height
                                self.nodes[i].frame = updatedFrame
                            
                                for j in i + 1 ..< self.nodes.count {
                                    var frame = self.nodes[j].frame
                                    frame.origin.y += offsetDelta
                                    self.nodes[j].frame = frame
                                }
                        }
                        
                        operations.append(.UpdateLayout(index: itemIndex, layout: layout, apply: apply))
                    case .System:
                        operations.append(.UpdateLayout(index: itemIndex, layout: layout, apply: apply))
                }
                
                break
            }
        }
    }
}

private enum ListViewStateOperation {
    case InsertNode(index: Int, offsetDirection: ListViewInsertionOffsetDirection, node: ListViewItemNode, layout: ListViewItemNodeLayout, apply: () -> ())
    case InsertPlaceholder(index: Int, referenceNode: ListViewItemNode, offsetDirection: ListViewInsertionOffsetDirection)
    case Remove(index: Int, offsetDirection: ListViewInsertionOffsetDirection)
    case Remap([Int: Int])
    case UpdateLayout(index: Int, layout: ListViewItemNodeLayout, apply: () -> ())
}

private let infiniteScrollSize: CGFloat = 10000.0
private let insertionAnimationDuration: Double = 0.4

private final class ListViewBackingLayer: CALayer {
    override func setNeedsLayout() {
    }
    
    override func layoutSublayers() {
    }
}

private final class ListViewBackingView: UIView {
    weak var target: ASDisplayNode?
    
    override class func layerClass() -> AnyClass {
        return ListViewBackingLayer.self
    }
    
    override func setNeedsLayout() {
    }
    
    override func layoutSubviews() {
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.target?.touchesBegan(touches, with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        self.target?.touchesCancelled(touches, with: event)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.target?.touchesMoved(touches, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.target?.touchesEnded(touches, with: event)
    }
}

private final class ListViewTimerProxy: NSObject {
    private let action: () -> ()
    
    init(_ action: () -> ()) {
        self.action = action
        super.init()
    }
    
    @objc func timerEvent() {
        self.action()
    }
}

public final class ListView: ASDisplayNode, UIScrollViewDelegate {
    private final let scroller: ListViewScroller
    private final var visibleSize: CGSize = CGSize()
    private final var insets = UIEdgeInsets()
    private final var lastContentOffset: CGPoint = CGPoint()
    private final var lastContentOffsetTimestamp: CFAbsoluteTime = 0.0
    private final var ignoreScrollingEvents: Bool = false
    
    private final var displayLink: CADisplayLink!
    private final var needsAnimations = false
    
    private final var invisibleInset: CGFloat = 500.0
    public var preloadPages: Bool = true {
        didSet {
            if self.preloadPages != oldValue {
                self.invisibleInset = self.preloadPages ? 500.0 : 20.0
                //self.invisibleInset = self.preloadPages ? 20.0 : 20.0
                if self.preloadPages {
                    self.enqueueUpdateVisibleItems()
                }
            }
        }
    }
    
    private var touchesPosition = CGPoint()
    private var isTracking = false
    
    private final var transactionQueue: ListViewTransactionQueue
    private final var transactionOffset: CGFloat = 0.0
    
    private final var enqueuedUpdateVisibleItems = false
    
    private final var createdItemNodes = 0
    
    public final var synchronousNodes = false
    public final var debugInfo = false
    
    private final var items: [ListViewItem] = []
    private final var itemNodes: [ListViewItemNode] = []
    
    public final var displayedItemRangeChanged: (ListViewDisplayedItemRange) -> Void = { _ in }
    public private(set) final var displayedItemRange: ListViewDisplayedItemRange = ListViewDisplayedItemRange(loadedRange: nil, visibleRange: nil)
    
    public final var visibleContentOffsetChanged: (CGFloat?) -> Void = { _ in }
    
    private final var animations: [ListViewAnimation] = []
    private final var actionsForVSync: [() -> ()] = []
    private final var inVSync = false
    
    private let frictionSlider = UISlider()
    private let springSlider = UISlider()
    private let freeResistanceSlider = UISlider()
    private let scrollingResistanceSlider = UISlider()
    
    //let performanceTracker: FBAnimationPerformanceTracker
    
    private var selectionTouchLocation: CGPoint?
    private var selectionTouchDelayTimer: Foundation.Timer?
    private var highlightedItemIndex: Int?
    
    public func reportDurationInMS(duration: Int, smallDropEvent: Double, largeDropEvent: Double) {
        print("reportDurationInMS duration: \(duration), smallDropEvent: \(smallDropEvent), largeDropEvent: \(largeDropEvent)")
    }
    
    public func reportStackTrace(stack: String!, withSlide slide: String!) {
        NSLog("reportStackTrace stack: \(stack)\n\nslide: \(slide)")
    }
    
    override public init() {
        class DisplayLinkProxy: NSObject {
            weak var target: ListView?
            init(target: ListView) {
                self.target = target
            }
            
            @objc func displayLinkEvent() {
                self.target?.displayLinkEvent()
            }
        }
        
        self.transactionQueue = ListViewTransactionQueue()
        
        self.scroller = ListViewScroller()
        
        /*var performanceTrackerConfig = FBAnimationPerformanceTracker.standardConfig()
        performanceTrackerConfig.reportStackTraces = true
        self.performanceTracker = FBAnimationPerformanceTracker(config: performanceTrackerConfig)*/
        
        super.init(viewBlock: { Void -> UIView in
            return ListViewBackingView()
        }, didLoad: nil)
        
        (self.view as! ListViewBackingView).target = self
        
        self.transactionQueue.transactionCompleted = { [weak self] in
            if let strongSelf = self {
                strongSelf.updateVisibleItemRange()
            }
        }
        
        //self.performanceTracker.delegate = self
        
        self.scroller.alwaysBounceVertical = true
        self.scroller.contentSize = CGSize(width: 0.0, height: infiniteScrollSize * 2.0)
        self.scroller.isHidden = true
        self.scroller.delegate = self
        self.view.addSubview(self.scroller)
        self.scroller.panGestureRecognizer.cancelsTouchesInView = false
        self.view.addGestureRecognizer(self.scroller.panGestureRecognizer)
        
        self.displayLink = CADisplayLink(target: DisplayLinkProxy(target: self), selector: #selector(DisplayLinkProxy.displayLinkEvent))
        self.displayLink.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
        if #available(iOS 10.0, *) {
            self.displayLink.preferredFramesPerSecond = 60
        }
        self.displayLink.isPaused = true
        
        if useDynamicTuning {
            self.frictionSlider.addTarget(self, action: #selector(self.frictionSliderChanged(_:)), for: .valueChanged)
            self.springSlider.addTarget(self, action: #selector(self.springSliderChanged(_:)), for: .valueChanged)
            self.freeResistanceSlider.addTarget(self, action: #selector(self.freeResistanceSliderChanged(_:)), for: .valueChanged)
            self.scrollingResistanceSlider.addTarget(self, action: #selector(self.scrollingResistanceSliderChanged(_:)), for: .valueChanged)
            
            self.frictionSlider.minimumValue = Float(testSpringFrictionLimits.0)
            self.frictionSlider.maximumValue = Float(testSpringFrictionLimits.1)
            self.frictionSlider.value = Float(testSpringFriction)
            
            self.springSlider.minimumValue = Float(testSpringConstantLimits.0)
            self.springSlider.maximumValue = Float(testSpringConstantLimits.1)
            self.springSlider.value = Float(testSpringConstant)
            
            self.freeResistanceSlider.minimumValue = Float(testSpringResistanceFreeLimits.0)
            self.freeResistanceSlider.maximumValue = Float(testSpringResistanceFreeLimits.1)
            self.freeResistanceSlider.value = Float(testSpringFreeResistance)
            
            self.scrollingResistanceSlider.minimumValue = Float(testSpringResistanceScrollingLimits.0)
            self.scrollingResistanceSlider.maximumValue = Float(testSpringResistanceScrollingLimits.1)
            self.scrollingResistanceSlider.value = Float(testSpringScrollingResistance)
        
            self.view.addSubview(self.frictionSlider)
            self.view.addSubview(self.springSlider)
            self.view.addSubview(self.freeResistanceSlider)
            self.view.addSubview(self.scrollingResistanceSlider)
        }
    }
    
    deinit {
        self.pauseAnimations()
        self.displayLink.invalidate()
    }
    
    @objc func frictionSliderChanged(_ slider: UISlider) {
        testSpringFriction = CGFloat(slider.value)
        print("friction: \(testSpringFriction)")
    }
    
    @objc func springSliderChanged(_ slider: UISlider) {
        testSpringConstant = CGFloat(slider.value)
        print("spring: \(testSpringConstant)")
    }
    
    @objc func freeResistanceSliderChanged(_ slider: UISlider) {
        testSpringFreeResistance = CGFloat(slider.value)
        print("free resistance: \(testSpringFreeResistance)")
    }
    
    @objc func scrollingResistanceSliderChanged(_ slider: UISlider) {
        testSpringScrollingResistance = CGFloat(slider.value)
        print("free resistance: \(testSpringScrollingResistance)")
    }
    
    private func displayLinkEvent() {
        self.updateAnimations()
    }
    
    private func setNeedsAnimations() {
        if !self.needsAnimations {
            self.needsAnimations = true
            self.displayLink.isPaused = false
        }
    }
    
    private func pauseAnimations() {
        if self.needsAnimations {
            self.needsAnimations = false
            self.displayLink.isPaused = true
        }
    }
    
    private func dispatchOnVSync(forceNext: Bool = false, action: () -> ()) {
        Queue.mainQueue().async {
            if !forceNext && self.inVSync {
                action()
            } else {
                self.actionsForVSync.append(action)
                self.setNeedsAnimations()
            }
        }
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.lastContentOffsetTimestamp = 0.0
        
        /*if usePerformanceTracker {
            self.performanceTracker.start()
        }*/
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate {
            self.lastContentOffsetTimestamp = CACurrentMediaTime()
        } else {
            self.lastContentOffsetTimestamp = 0.0
            /*if usePerformanceTracker {
                self.performanceTracker.stop()
            }*/
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.lastContentOffsetTimestamp = 0.0
        /*if usePerformanceTracker {
            self.performanceTracker.stop()
        }*/
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.ignoreScrollingEvents || scroller !== self.scroller {
            return
        }
            
        //CATransaction.begin()
        //CATransaction.setDisableActions(true)
        
        let deltaY = scrollView.contentOffset.y - self.lastContentOffset.y
        
        self.lastContentOffset = scrollView.contentOffset
        if self.lastContentOffsetTimestamp > DBL_EPSILON {
            self.lastContentOffsetTimestamp = CACurrentMediaTime()
        }
        
        for itemNode in self.itemNodes {
            let position = itemNode.position
            itemNode.position = CGPoint(x: position.x, y: position.y - deltaY)
        }
        
        self.transactionOffset += -deltaY
        
        self.enqueueUpdateVisibleItems()
        self.updateScroller()
        
        var useScrollDynamics = false
        
        for itemNode in self.itemNodes {
            if itemNode.wantsScrollDynamics {
                useScrollDynamics = true
                let anchor: CGFloat
                if self.isTracking {
                    anchor = self.touchesPosition.y
                } else if deltaY < 0.0 {
                    anchor = self.visibleSize.height
                } else {
                    anchor = 0.0
                }
                
                var distance: CGFloat
                let itemFrame = itemNode.apparentFrame
                if anchor < itemFrame.origin.y {
                    distance = abs(itemFrame.origin.y - anchor)
                } else if anchor > itemFrame.origin.y + itemFrame.size.height {
                    distance = abs(anchor - (itemFrame.origin.y + itemFrame.size.height))
                } else {
                    distance = 0.0
                }
                
                let factor: CGFloat = max(0.08, abs(distance) / self.visibleSize.height)
                
                let resistance: CGFloat = testSpringFreeResistance

                itemNode.addScrollingOffset(deltaY * factor * resistance)
            }
        }
        
        if useScrollDynamics {
            self.setNeedsAnimations()
        }
        
        self.updateVisibleContentOffset()
        self.updateVisibleItemRange()
        
        //CATransaction.commit()
    }
    
    private func snapToBounds(_ snapTopItem: Bool = false) {
        if self.itemNodes.count == 0 {
            return
        }
        
        var overscroll: CGFloat = 0.0
        if self.scroller.contentOffset.y < 0.0 {
            overscroll = self.scroller.contentOffset.y
        } else if self.scroller.contentOffset.y > max(0.0, self.scroller.contentSize.height - self.scroller.bounds.size.height) {
            overscroll = self.scroller.contentOffset.y - max(0.0, (self.scroller.contentSize.height - self.scroller.bounds.size.height))
        }
        
        var completeHeight: CGFloat = 0.0
        var topItemFound = false
        var bottomItemFound = false
        var topItemEdge: CGFloat = 0.0
        var bottomItemEdge: CGFloat = 0.0
        
        if itemNodes[0].index == 0 {
            topItemFound = true
            topItemEdge = itemNodes[0].apparentFrame.origin.y
        }
        
        if itemNodes[itemNodes.count - 1].index == self.items.count - 1 {
            bottomItemFound = true
            bottomItemEdge = itemNodes[itemNodes.count - 1].apparentFrame.maxY
        }
        
        if topItemFound && bottomItemFound {
            for itemNode in self.itemNodes {
                completeHeight += itemNode.apparentBounds.height
            }
        }
        
        var offset: CGFloat = 0.0
        if topItemFound && bottomItemFound {
            let areaHeight = min(completeHeight, self.visibleSize.height - self.insets.bottom - self.insets.top)
            if bottomItemEdge < self.insets.top + areaHeight - overscroll {
                offset = self.insets.top + areaHeight - overscroll - bottomItemEdge
            } else if topItemEdge > self.insets.top - overscroll && snapTopItem {
                offset = (self.insets.top - overscroll) - topItemEdge
            }
        } else if topItemFound {
            if topItemEdge > self.insets.top - overscroll && snapTopItem {
                offset = (self.insets.top - overscroll) - topItemEdge
            }
        } else if bottomItemFound {
            if bottomItemEdge < self.visibleSize.height - self.insets.bottom - overscroll {
                offset = self.visibleSize.height - self.insets.bottom - overscroll - bottomItemEdge
            }
        }
        
        if abs(offset) > CGFloat(FLT_EPSILON) {
            for itemNode in self.itemNodes {
                var frame = itemNode.frame
                frame.origin.y += offset
                itemNode.frame = frame
            }
            
            self.updateVisibleContentOffset()
        }
    }
    
    private func updateVisibleContentOffset() {
        var offset: CGFloat?
        if let itemNode = self.itemNodes.first, index = itemNode.index where index == 0 {
            offset = -(itemNode.apparentFrame.minY - self.insets.top)
        }
        
        self.visibleContentOffsetChanged(offset)
    }
    
    private func stopScrolling() {
        let wasIgnoringScrollingEvents = self.ignoreScrollingEvents
        self.ignoreScrollingEvents = true
        self.scroller.setContentOffset(self.scroller.contentOffset, animated: false)
        self.ignoreScrollingEvents = wasIgnoringScrollingEvents
    }
    
    private func updateScroller() {
        if itemNodes.count == 0 {
            return
        }
        
        var completeHeight = self.insets.top + self.insets.bottom
        var topItemFound = false
        var bottomItemFound = false
        var topItemEdge: CGFloat = 0.0
        var bottomItemEdge: CGFloat = 0.0
        
        if itemNodes[0].index == 0 {
            topItemFound = true
            topItemEdge = itemNodes[0].apparentFrame.origin.y
        }
        
        if itemNodes[itemNodes.count - 1].index == self.items.count - 1 {
            bottomItemFound = true
            bottomItemEdge = itemNodes[itemNodes.count - 1].apparentFrame.maxY
        }
        
        if topItemFound && bottomItemFound {
            for itemNode in self.itemNodes {
                completeHeight += itemNode.apparentBounds.height
            }
        }
        
        topItemEdge -= self.insets.top
        bottomItemEdge += self.insets.bottom
        
        self.ignoreScrollingEvents = true
        if topItemFound && bottomItemFound {
            self.scroller.contentSize = CGSize(width: self.visibleSize.width, height: completeHeight)
            self.lastContentOffset = CGPoint(x: 0.0, y: -topItemEdge)
            self.scroller.contentOffset = self.lastContentOffset;
        } else if topItemFound {
            self.scroller.contentSize = CGSize(width: self.visibleSize.width, height: infiniteScrollSize * 2.0)
            self.lastContentOffset = CGPoint(x: 0.0, y: -topItemEdge)
            self.scroller.contentOffset = self.lastContentOffset
        } else if bottomItemFound {
            self.scroller.contentSize = CGSize(width: self.visibleSize.width, height: infiniteScrollSize * 2.0)
            self.lastContentOffset = CGPoint(x: 0.0, y: infiniteScrollSize * 2.0 - bottomItemEdge)
            self.scroller.contentOffset = self.lastContentOffset
        }
        else
        {
            self.scroller.contentSize = CGSize(width: self.visibleSize.width, height: infiniteScrollSize * 2.0)
            self.lastContentOffset = CGPoint(x: 0.0, y: infiniteScrollSize)
            self.scroller.contentOffset = self.lastContentOffset
        }
        
        self.ignoreScrollingEvents = false
    }
    
    private func async(_ f: () -> Void) {
        DispatchQueue.global().async(execute: f)
    }
    
    private func nodeForItem(synchronous: Bool, item: ListViewItem, previousNode: ListViewItemNode?, index: Int, previousItem: ListViewItem?, nextItem: ListViewItem?, width: CGFloat, updateAnimation: ListViewItemUpdateAnimation, completion: (ListViewItemNode, ListViewItemNodeLayout, () -> Void) -> Void) {
        if let previousNode = previousNode {
            item.updateNode(async: { f in
                if synchronous {
                    f()
                } else {
                    self.async(f)
                }
            }, node: previousNode, width: width, previousItem: previousItem, nextItem: nextItem, animation: updateAnimation, completion: { (layout, apply) in
                if Thread.isMainThread {
                    if synchronous {
                        completion(previousNode, layout, {
                            previousNode.index = index
                            apply()
                        })
                    } else {
                        self.async {
                            completion(previousNode, layout, {
                                previousNode.index = index
                                apply()
                            })
                        }
                    }
                } else {
                    completion(previousNode, layout, {
                        previousNode.index = index
                        apply()
                    })
                }
            })
        } else {
            item.nodeConfiguredForWidth(async: { f in
                if synchronous {
                    f()
                } else {
                    self.async(f)
                }
            }, width: width, previousItem: previousItem, nextItem: nextItem, completion: { itemNode, apply in
                itemNode.index = index
                completion(itemNode, ListViewItemNodeLayout(contentSize: itemNode.contentSize, insets: itemNode.insets), apply)
            })
        }
    }
    
    private func currentState() -> ListViewState {
        var nodes: [ListViewStateNode] = []
        nodes.reserveCapacity(self.itemNodes.count)
        for node in self.itemNodes {
            if let index = node.index {
                nodes.append(.Node(index: index, frame: node.apparentFrame, referenceNode: node))
            } else {
                nodes.append(.Placeholder(frame: node.apparentFrame))
            }
        }
        return ListViewState(insets: self.insets, visibleSize: self.visibleSize, invisibleInset: self.invisibleInset, nodes: nodes, scrollPosition: nil, stationaryOffset: nil)
    }
    
    public func deleteAndInsertItems(deleteIndices: [ListViewDeleteItem], insertIndicesAndItems: [ListViewInsertItem], updateIndicesAndItems: [ListViewUpdateItem], options: ListViewDeleteAndInsertOptions, scrollToItem: ListViewScrollToItem? = nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets? = nil, stationaryItemRange: (Int, Int)? = nil, completion: (ListViewDisplayedItemRange) -> Void = { _ in }) {
        if deleteIndices.isEmpty && insertIndicesAndItems.isEmpty && updateIndicesAndItems.isEmpty && scrollToItem == nil && updateSizeAndInsets == nil {
            completion(self.immediateDisplayedItemRange())
            return
        }
        
        self.transactionQueue.addTransaction({ [weak self] transactionCompletion in
            if let strongSelf = self {
                strongSelf.transactionOffset = 0.0
                strongSelf.deleteAndInsertItemsTransaction(deleteIndices: deleteIndices, insertIndicesAndItems: insertIndicesAndItems, updateIndicesAndItems: updateIndicesAndItems, options: options, scrollToItem: scrollToItem, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: stationaryItemRange, completion: { [weak strongSelf] in
                    completion(strongSelf?.immediateDisplayedItemRange() ?? ListViewDisplayedItemRange(loadedRange: nil, visibleRange: nil))
                    
                    transactionCompletion()
                })
            }
        })
    }

    private func deleteAndInsertItemsTransaction(deleteIndices: [ListViewDeleteItem], insertIndicesAndItems: [ListViewInsertItem], updateIndicesAndItems: [ListViewUpdateItem], options: ListViewDeleteAndInsertOptions, scrollToItem: ListViewScrollToItem?, updateSizeAndInsets: ListViewUpdateSizeAndInsets?, stationaryItemRange: (Int, Int)?, completion: (Void) -> Void) {
        if deleteIndices.isEmpty && insertIndicesAndItems.isEmpty && scrollToItem == nil {
            if let updateSizeAndInsets = updateSizeAndInsets where self.items.count == 0 || (updateSizeAndInsets.size == self.visibleSize && updateSizeAndInsets.insets == self.insets) {
                self.visibleSize = updateSizeAndInsets.size
                self.insets = updateSizeAndInsets.insets
                
                self.ignoreScrollingEvents = true
                self.scroller.frame = CGRect(origin: CGPoint(), size: updateSizeAndInsets.size)
                self.scroller.contentSize = CGSize(width: updateSizeAndInsets.size.width, height: infiniteScrollSize * 2.0)
                self.lastContentOffset = CGPoint(x: 0.0, y: infiniteScrollSize)
                self.scroller.contentOffset = self.lastContentOffset
                
                self.updateScroller()
                
                completion()
                return
            }
        }
        
        let startTime = CACurrentMediaTime()
        var state = self.currentState()
        
        let widthUpdated: Bool
        if let updateSizeAndInsets = updateSizeAndInsets {
            widthUpdated = abs(state.visibleSize.width - updateSizeAndInsets.size.width) > CGFloat(FLT_EPSILON)
            
            state.visibleSize = updateSizeAndInsets.size
            state.insets = updateSizeAndInsets.insets
        } else {
            widthUpdated = false
        }
        
        if let scrollToItem = scrollToItem {
            state.scrollPosition = (scrollToItem.index, scrollToItem.position)
        }
        state.fixScrollPostition(self.items.count)
        
        let sortedDeleteIndices = deleteIndices.sorted(isOrderedBefore: {$0.index < $1.index})
        for deleteItem in sortedDeleteIndices.reversed() {
            self.items.remove(at: deleteItem.index)
        }
        
        let sortedIndicesAndItems = insertIndicesAndItems.sorted(isOrderedBefore: { $0.index < $1.index })
        if self.items.count == 0 {
            if sortedIndicesAndItems[0].index != 0 {
                fatalError("deleteAndInsertItems: invalid insert into empty list")
            }
        }
        
        if self.debugInfo {
            //print("deleteAndInsertItemsTransaction deleteIndices: \(deleteIndices.map({$0.index})) insertIndicesAndItems: \(insertIndicesAndItems.map({"\($0.index) <- \($0.previousIndex)"}))")
        }
        
        /*if scrollToItem != nil {
            print("Current indices:")
            for itemNode in self.itemNodes {
                print("    \(itemNode.index)")
            }
        }*/
        
        var previousNodes: [Int: ListViewItemNode] = [:]
        for insertedItem in sortedIndicesAndItems {
            self.items.insert(insertedItem.item, at: insertedItem.index)
            if let previousIndex = insertedItem.previousIndex {
                for itemNode in self.itemNodes {
                    if itemNode.index == previousIndex {
                        previousNodes[insertedItem.index] = itemNode
                    }
                }
            }
        }
        
        for updatedItem in updateIndicesAndItems {
            self.items[updatedItem.index] = updatedItem.item
            for itemNode in self.itemNodes {
                if itemNode.index == updatedItem.index {
                    previousNodes[updatedItem.index] = itemNode
                }
            }
        }
        
        let actions = {
            var previousFrames: [Int: CGRect] = [:]
            for i in 0 ..< state.nodes.count {
                if let index = state.nodes[i].index {
                    previousFrames[index] = state.nodes[i].frame
                }
            }
            
            var operations: [ListViewStateOperation] = []
            
            var deleteDirectionHints: [Int: ListViewItemOperationDirectionHint] = [:]
            var insertDirectionHints: [Int: ListViewItemOperationDirectionHint] = [:]
            
            var deleteIndexSet = Set<Int>()
            for deleteItem in deleteIndices {
                deleteIndexSet.insert(deleteItem.index)
                if let directionHint = deleteItem.directionHint {
                    deleteDirectionHints[deleteItem.index] = directionHint
                }
            }
            
            var insertedIndexSet = Set<Int>()
            for insertedItem in sortedIndicesAndItems {
                insertedIndexSet.insert(insertedItem.index)
                if let directionHint = insertedItem.directionHint {
                    insertDirectionHints[insertedItem.index] = directionHint
                }
            }
            
            let animated = options.contains(.AnimateInsertion)
            
            var remapDeletion: [Int: Int] = [:]
            var updateAdjacentItemsIndices = Set<Int>()
            
            var i = 0
            while i < state.nodes.count {
                if let index = state.nodes[i].index {
                    var indexOffset = 0
                    for deleteIndex in sortedDeleteIndices {
                        if deleteIndex.index < index {
                            indexOffset += 1
                        } else {
                            break
                        }
                    }
                    
                    if deleteIndexSet.contains(index) {
                        previousFrames.removeValue(forKey: index)
                        state.removeNodeAtIndex(i, direction: deleteDirectionHints[index], animated: animated, operations: &operations)
                    } else {
                        let updatedIndex = index - indexOffset
                        if index != updatedIndex {
                            remapDeletion[index] = updatedIndex
                        }
                        if let previousFrame = previousFrames[index] {
                            previousFrames.removeValue(forKey: index)
                            previousFrames[updatedIndex] = previousFrame
                        }
                        if deleteIndexSet.contains(index - 1) || deleteIndexSet.contains(index + 1) {
                            updateAdjacentItemsIndices.insert(updatedIndex)
                        }
                        
                        switch state.nodes[i] {
                            case let .Node(_, frame, referenceNode):
                                state.nodes[i] = .Node(index: updatedIndex, frame: frame, referenceNode: referenceNode)
                            case .Placeholder:
                                break
                        }
                        i += 1
                    }
                } else {
                    i += 1
                }
            }
            
            if !remapDeletion.isEmpty {
                if self.debugInfo {
                    //print("remapDeletion \(remapDeletion)")
                }
                operations.append(.Remap(remapDeletion))
            }
            
            var remapInsertion: [Int: Int] = [:]
            
            for i in 0 ..< state.nodes.count {
                if let index = state.nodes[i].index {
                    var indexOffset = 0
                    for insertedItem in sortedIndicesAndItems {
                        if insertedItem.index <= index + indexOffset {
                            indexOffset += 1
                        }
                    }
                    if indexOffset != 0 {
                        let updatedIndex = index + indexOffset
                        remapInsertion[index] = updatedIndex
                        
                        if let previousFrame = previousFrames[index] {
                            previousFrames.removeValue(forKey: index)
                            previousFrames[updatedIndex] = previousFrame
                        }
                        
                        switch state.nodes[i] {
                            case let .Node(_, frame, referenceNode):
                                state.nodes[i] = .Node(index: updatedIndex, frame: frame, referenceNode: referenceNode)
                            case .Placeholder:
                                break
                        }
                    }
                }
            }
            
            if !remapInsertion.isEmpty {
                if self.debugInfo {
                    print("remapInsertion \(remapInsertion)")
                }
                operations.append(.Remap(remapInsertion))
                
                var remappedUpdateAdjacentItemsIndices = Set<Int>()
                for index in updateAdjacentItemsIndices {
                    if let remappedIndex = remapInsertion[index] {
                        remappedUpdateAdjacentItemsIndices.insert(remappedIndex)
                    } else {
                        remappedUpdateAdjacentItemsIndices.insert(index)
                    }
                }
                updateAdjacentItemsIndices = remappedUpdateAdjacentItemsIndices
            }
            
            if self.debugInfo {
                //print("state \(state.nodes.map({$0.index ?? -1}))")
            }
            
            for node in state.nodes {
                if let index = node.index {
                    if insertedIndexSet.contains(index - 1) || insertedIndexSet.contains(index + 1) {
                        updateAdjacentItemsIndices.insert(index)
                    }
                }
            }
            
            if let (index, boundary) = stationaryItemRange {
                state.setupStationaryOffset(index, boundary: boundary, frames: previousFrames)
            }
            
            if self.debugInfo {
                print("deleteAndInsertItemsTransaction prepare \((CACurrentMediaTime() - startTime) * 1000.0) ms")
            }
            
            self.fillMissingNodes(synchronous: options.contains(.Synchronous), animated: animated, inputAnimatedInsertIndices: animated ? insertedIndexSet : Set<Int>(), insertDirectionHints: insertDirectionHints, inputState: state, inputPreviousNodes: previousNodes, inputOperations: operations, inputCompletion: { updatedState, operations in
                
                if self.debugInfo {
                    print("fillMissingNodes completion \((CACurrentMediaTime() - startTime) * 1000.0) ms")
                }
                
                var updateIndices = updateAdjacentItemsIndices
                if widthUpdated {
                    for case let .Node(index, _, _) in updatedState.nodes {
                        updateIndices.insert(index)
                    }
                }
                
                self.updateNodes(synchronous: options.contains(.Synchronous), animated: animated, updateIndicesAndItems: updateIndicesAndItems, inputState: updatedState, previousNodes: previousNodes, inputOperations: operations, completion: { updatedState, operations in
                    self.updateAdjacent(synchronous: options.contains(.Synchronous), animated: animated, state: updatedState, updateAdjacentItemsIndices: updateIndices, operations: operations, completion: { state, operations in
                        var updatedState = state
                        var updatedOperations = operations
                        updatedState.removeInvisibleNodes(&updatedOperations)
                        
                        if self.debugInfo {
                            print("updateAdjacent completion \((CACurrentMediaTime() - startTime) * 1000.0) ms")
                        }
                        
                        let stationaryItemIndex = updatedState.stationaryOffset?.0
                        
                        let next = {
                            self.replayOperations(animated: animated, animateAlpha: options.contains(.AnimateAlpha), operations: updatedOperations, scrollToItem: scrollToItem, updateSizeAndInsets: updateSizeAndInsets, stationaryItemIndex: stationaryItemIndex, completion: completion)
                        }
                        
                        if options.contains(.LowLatency) || options.contains(.Synchronous) {
                            Queue.mainQueue().async {
                                if self.debugInfo {
                                    print("updateAdjacent LowLatency enqueue \((CACurrentMediaTime() - startTime) * 1000.0) ms")
                                }
                                next()
                            }
                        } else {
                            self.dispatchOnVSync {
                                next()
                            }
                        }
                    })
                })
            })
        }
        
        if options.contains(.Synchronous) {
            actions()
        } else {
            self.async(actions)
        }
    }
    
    private func updateAdjacent(synchronous: Bool, animated: Bool, state: ListViewState, updateAdjacentItemsIndices: Set<Int>, operations: [ListViewStateOperation], completion: (ListViewState, [ListViewStateOperation]) -> Void) {
        if updateAdjacentItemsIndices.isEmpty {
            completion(state, operations)
        } else {
            var updatedUpdateAdjacentItemsIndices = updateAdjacentItemsIndices
            
            let nodeIndex = updateAdjacentItemsIndices.first!
            updatedUpdateAdjacentItemsIndices.remove(nodeIndex)
            
            var continueWithoutNode = true
            
            var i = 0
            for node in state.nodes {
                if case let .Node(index, _, referenceNode) = node where index == nodeIndex {
                    if let referenceNode = referenceNode {
                        continueWithoutNode = false
                        self.items[index].updateNode(async: { f in
                            if synchronous {
                                f()
                            } else {
                                self.async(f)
                            }
                        }, node: referenceNode, width: state.visibleSize.width, previousItem: index == 0 ? nil : self.items[index - 1], nextItem: index == self.items.count - 1 ? nil : self.items[index + 1], animation: .None, completion: { layout, apply in
                            var updatedState = state
                            var updatedOperations = operations
                            
                            updatedOperations.append(.UpdateLayout(index: i, layout: layout, apply: apply))
                            
                            if nodeIndex + 1 < updatedState.nodes.count {
                                for i in nodeIndex + 1 ..< updatedState.nodes.count {
                                    let frame = updatedState.nodes[i].frame
                                    updatedState.nodes[i].frame = frame.offsetBy(dx: 0.0, dy: frame.size.height)
                                }
                            }
                            
                            self.updateAdjacent(synchronous: synchronous, animated: animated, state: updatedState, updateAdjacentItemsIndices: updatedUpdateAdjacentItemsIndices, operations: updatedOperations, completion: completion)
                        })
                    }
                    break
                }
                i += 1
            }
            
            if continueWithoutNode {
                updateAdjacent(synchronous: synchronous, animated: animated, state: state, updateAdjacentItemsIndices: updatedUpdateAdjacentItemsIndices, operations: operations, completion: completion)
            }
        }
    }
    
    private func fillMissingNodes(synchronous: Bool, animated: Bool, inputAnimatedInsertIndices: Set<Int>, insertDirectionHints: [Int: ListViewItemOperationDirectionHint], inputState: ListViewState, inputPreviousNodes: [Int: ListViewItemNode], inputOperations: [ListViewStateOperation], inputCompletion: (ListViewState, [ListViewStateOperation]) -> Void) {
        let animatedInsertIndices = inputAnimatedInsertIndices
        var state = inputState
        var previousNodes = inputPreviousNodes
        var operations = inputOperations
        let completion = inputCompletion
        let updateAnimation: ListViewItemUpdateAnimation = animated ? .System(duration: insertionAnimationDuration) : .None
        
        if state.nodes.count > 1000 {
            print("state.nodes.count > 1000")
        }
        
        while true {
            if self.items.count == 0 {
                completion(state, operations)
                break
            } else {
                var insertionItemIndexAndDirection: (Int, ListViewInsertionOffsetDirection)?
                
                if self.debugInfo {
                    assert(true)
                }
                
                if let insertionPoint = state.insertionPoint(insertDirectionHints, itemCount: self.items.count) {
                    insertionItemIndexAndDirection = (insertionPoint.index, insertionPoint.direction)
                }
                
                if self.debugInfo {
                    print("insertionItemIndexAndDirection \(insertionItemIndexAndDirection)")
                }
                
                if let insertionItemIndexAndDirection = insertionItemIndexAndDirection {
                    let index = insertionItemIndexAndDirection.0
                    let threadId = pthread_self()
                    var tailRecurse = false
                    self.nodeForItem(synchronous: synchronous, item: self.items[index], previousNode: previousNodes[index], index: index, previousItem: index == 0 ? nil : self.items[index - 1], nextItem: self.items.count == index + 1 ? nil : self.items[index + 1], width: state.visibleSize.width, updateAnimation: updateAnimation, completion: { (node, layout, apply) in
                        
                        if pthread_equal(pthread_self(), threadId) != 0 && !tailRecurse {
                            tailRecurse = true
                            state.insertNode(index, node: node, layout: layout, apply: apply, offsetDirection: insertionItemIndexAndDirection.1, animated: animated && animatedInsertIndices.contains(index), operations: &operations, itemCount: self.items.count)
                        } else {
                            var updatedState = state
                            var updatedOperations = operations
                            updatedState.insertNode(index, node: node, layout: layout, apply: apply, offsetDirection: insertionItemIndexAndDirection.1, animated: animated && animatedInsertIndices.contains(index), operations: &updatedOperations, itemCount: self.items.count)
                            self.fillMissingNodes(synchronous: synchronous, animated: animated, inputAnimatedInsertIndices: animatedInsertIndices, insertDirectionHints: insertDirectionHints, inputState: updatedState, inputPreviousNodes: previousNodes, inputOperations: updatedOperations, inputCompletion: completion)
                        }
                    })
                    if !tailRecurse {
                        tailRecurse = true
                        break
                    }
                } else {
                    completion(state, operations)
                    break
                }
            }
        }
    }
    
    private func updateNodes(synchronous: Bool, animated: Bool, updateIndicesAndItems: [ListViewUpdateItem], inputState: ListViewState, previousNodes: [Int: ListViewItemNode], inputOperations: [ListViewStateOperation], completion: (ListViewState, [ListViewStateOperation]) -> Void) {
        var state = inputState
        var operations = inputOperations
        var updateIndicesAndItems = updateIndicesAndItems
        
        if updateIndicesAndItems.isEmpty {
            completion(state, operations)
        } else {
            var updateItem = updateIndicesAndItems[0]
            if let previousNode = previousNodes[updateItem.index] {
                self.nodeForItem(synchronous: synchronous, item: updateItem.item, previousNode: previousNode, index: updateItem.index, previousItem: updateItem.index == 0 ? nil : self.items[updateItem.index - 1], nextItem: updateItem.index == (self.items.count - 1) ? nil : self.items[updateItem.index + 1], width: state.visibleSize.width, updateAnimation: animated ? .System(duration: insertionAnimationDuration) : .None, completion: { _, layout, apply in
                    state.updateNodeAtItemIndex(updateItem.index, layout: layout, direction: updateItem.directionHint, animation: animated ? .System(duration: insertionAnimationDuration) : .None, apply: apply, operations: &operations)
                    
                    updateIndicesAndItems.remove(at: 0)
                    self.updateNodes(synchronous: synchronous, animated: animated, updateIndicesAndItems: updateIndicesAndItems, inputState: state, previousNodes: previousNodes, inputOperations: operations, completion: completion)
                })
            } else {
                updateIndicesAndItems.remove(at: 0)
                self.updateNodes(synchronous: synchronous, animated: animated, updateIndicesAndItems: updateIndicesAndItems, inputState: state, previousNodes: previousNodes, inputOperations: operations, completion: completion)
            }
        }
    }
    
    private func referencePointForInsertionAtIndex(_ nodeIndex: Int) -> CGPoint {
        var index = 0
        for itemNode in self.itemNodes {
            if index == nodeIndex {
                return itemNode.apparentFrame.origin
            }
            index += 1
        }
        if self.itemNodes.count == 0 {
            return CGPoint(x: 0.0, y: self.insets.top)
        } else {
            return CGPoint(x: 0.0, y: self.itemNodes[self.itemNodes.count - 1].apparentFrame.maxY)
        }
    }
    
    private func insertNodeAtIndex(animated: Bool, animateAlpha: Bool, previousFrame: CGRect?, nodeIndex: Int, offsetDirection: ListViewInsertionOffsetDirection, node: ListViewItemNode, layout: ListViewItemNodeLayout, apply: () -> (), timestamp: Double) {
        let insertionOrigin = self.referencePointForInsertionAtIndex(nodeIndex)
        
        let nodeOrigin: CGPoint
        switch offsetDirection {
            case .Up:
                nodeOrigin = CGPoint(x: insertionOrigin.x, y: insertionOrigin.y - (animated ? 0.0 : layout.size.height))
            case .Down:
                nodeOrigin = insertionOrigin
        }
        
        let nodeFrame = CGRect(origin: nodeOrigin, size: CGSize(width: layout.size.width, height: layout.size.height))
        
        let previousApparentHeight = node.apparentHeight
        let previousInsets = node.insets
        
        if node.wantsScrollDynamics && previousFrame != nil {
            assert(true)
        }
        
        node.contentSize = layout.contentSize
        node.insets = layout.insets
        node.apparentHeight = animated ? 0.0 : layout.size.height
        node.frame = nodeFrame
        apply()
        self.itemNodes.insert(node, at: nodeIndex)
        
        if useDynamicTuning {
            self.insertSubnode(node, at: 0)
        } else {
            //self.addSubnode(node)
        }
        
        if previousFrame == nil {
            node.setupGestures()
        }
        
        var offsetHeight = node.apparentHeight
        var takenAnimation = false
        
        if let _ = previousFrame where animated && node.index != nil && nodeIndex != self.itemNodes.count - 1 {
            let nextNode = self.itemNodes[nodeIndex + 1]
            if nextNode.index == nil {
                let nextHeight = nextNode.apparentHeight
                if abs(nextHeight - previousApparentHeight) < CGFloat(FLT_EPSILON) {
                    if let animation = nextNode.animationForKey("apparentHeight") {
                        node.apparentHeight = previousApparentHeight
                        
                        offsetHeight = 0.0
                        
                        var offsetPosition = nextNode.position
                        offsetPosition.y += nextHeight
                        nextNode.position = offsetPosition
                        nextNode.apparentHeight = 0.0
                        
                        nextNode.removeApparentHeightAnimation()
                        
                        takenAnimation = true
                        
                        if abs(layout.size.height - previousApparentHeight) > CGFloat(FLT_EPSILON) {
                            node.addApparentHeightAnimation(layout.size.height, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp, update: { [weak node] progress in
                                if let node = node {
                                    node.animateFrameTransition(progress)
                                }
                            })
                            node.transitionOffset += previousApparentHeight - layout.size.height
                            node.addTransitionOffsetAnimation(0.0, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp)
                        }
                    }
                }
            }
        }
        
        if node.index == nil {
            node.addApparentHeightAnimation(0.0, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp)
        } else if animated {
            if !takenAnimation {
                node.addApparentHeightAnimation(nodeFrame.size.height, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp, update: { [weak node] progress in
                    if let node = node {
                        node.animateFrameTransition(progress)
                    }
                })
            
                if let previousFrame = previousFrame {
                    if self.debugInfo {
                        assert(true)
                    }
                    
                    node.transitionOffset += nodeFrame.origin.y - previousFrame.origin.y - previousApparentHeight + layout.size.height
                    node.addTransitionOffsetAnimation(0.0, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp)
                    if previousInsets != layout.insets {
                        node.insets = previousInsets
                        node.addInsetsAnimationToValue(layout.insets, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp)
                    }
                } else {
                    node.animateInsertion(timestamp, duration: insertionAnimationDuration * UIView.animationDurationFactor())
                }
            }
        } else if animateAlpha && previousFrame == nil {
            node.animateAdded(timestamp, duration: insertionAnimationDuration * UIView.animationDurationFactor())
        }
        
        if node.apparentHeight > CGFloat(FLT_EPSILON) {
            switch offsetDirection {
            case .Up:
                var i = nodeIndex - 1
                while i >= 0 {
                    var frame = self.itemNodes[i].frame
                    frame.origin.y -= offsetHeight
                    self.itemNodes[i].frame = frame
                    i -= 1
                }
            case .Down:
                var i = nodeIndex + 1
                while i < self.itemNodes.count {
                    var frame = self.itemNodes[i].frame
                    frame.origin.y += offsetHeight
                    self.itemNodes[i].frame = frame
                    i += 1
                }
            }
        }
    }
    
    private func replayOperations(animated: Bool, animateAlpha: Bool, operations: [ListViewStateOperation], scrollToItem: ListViewScrollToItem?, updateSizeAndInsets: ListViewUpdateSizeAndInsets?, stationaryItemIndex: Int?, completion: () -> Void) {
        let timestamp = CACurrentMediaTime()
        
        var previousApparentFrames: [(ListViewItemNode, CGRect)] = []
        for itemNode in self.itemNodes {
            previousApparentFrames.append((itemNode, itemNode.apparentFrame))
        }
        
        if self.debugInfo {
            //print("replay before \(self.itemNodes.map({"\($0.index) \(unsafeAddressOf($0))"}))")
        }
        
        for operation in operations {
            switch operation {
                case let .InsertNode(index, offsetDirection, node, layout, apply):
                    var previousFrame: CGRect?
                    for (previousNode, frame) in previousApparentFrames {
                        if previousNode === node {
                            previousFrame = frame
                            break
                        }
                    }
                    self.insertNodeAtIndex(animated: animated, animateAlpha: animateAlpha, previousFrame: previousFrame, nodeIndex: index, offsetDirection: offsetDirection, node: node, layout: layout, apply: apply, timestamp: timestamp)
                    self.addSubnode(node)
                case let .InsertPlaceholder(index, referenceNode, offsetDirection):
                    var height: CGFloat?
                    
                    for (node, previousFrame) in previousApparentFrames {
                        if node === referenceNode {
                            height = previousFrame.size.height
                            break
                        }
                    }
                    
                    if let height = height {
                        self.insertNodeAtIndex(animated: false, animateAlpha: false, previousFrame: nil, nodeIndex: index, offsetDirection: offsetDirection, node: ListViewItemNode(layerBacked: true), layout: ListViewItemNodeLayout(contentSize: CGSize(width: self.visibleSize.width, height: height), insets: UIEdgeInsets()), apply: { }, timestamp: timestamp)
                    } else {
                        assertionFailure()
                    }
                case let .Remap(mapping):
                    for node in self.itemNodes {
                        if let index = node.index {
                            if let mapped = mapping[index] {
                                node.index = mapped
                            }
                        }
                    }
                case let .Remove(index, offsetDirection):
                    let apparentFrame = self.itemNodes[index].apparentFrame
                    let height = apparentFrame.size.height
                    switch offsetDirection {
                        case .Up:
                            if index != self.itemNodes.count - 1 {
                                for i in index + 1 ..< self.itemNodes.count {
                                    var frame = self.itemNodes[i].frame
                                    frame.origin.y -= height
                                    self.itemNodes[i].frame = frame
                                }
                            }
                        case .Down:
                            if index != 0 {
                                for i in (0 ..< index).reversed() {
                                    var frame = self.itemNodes[i].frame
                                    frame.origin.y += height
                                    self.itemNodes[i].frame = frame
                                }
                            }
                    }
                    
                    self.removeItemNodeAtIndex(index)
                case let .UpdateLayout(index, layout, apply):
                    let node = self.itemNodes[index]
                    
                    let previousApparentHeight = node.apparentHeight
                    let previousInsets = node.insets
                    
                    node.contentSize = layout.contentSize
                    node.insets = layout.insets
                    apply()
                    
                    let updatedApparentHeight = node.bounds.size.height
                    let updatedInsets = node.insets
                    
                    var offsetRanges = OffsetRanges()
                    
                    if animated {
                        if updatedInsets != previousInsets {
                            node.insets = previousInsets
                            node.addInsetsAnimationToValue(updatedInsets, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp)
                        }
                        
                        if abs(updatedApparentHeight - previousApparentHeight) > CGFloat(FLT_EPSILON) {
                            node.apparentHeight = previousApparentHeight
                            node.addApparentHeightAnimation(updatedApparentHeight, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp, update: { [weak node] progress in
                                if let node = node {
                                    node.animateFrameTransition(progress)
                                }
                            })
                            node.transitionOffset += previousApparentHeight - layout.size.height
                            node.addTransitionOffsetAnimation(0.0, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp)
                        }
                    } else {
                        node.apparentHeight = updatedApparentHeight
                        
                        let apparentHeightDelta = updatedApparentHeight - previousApparentHeight
                        if apparentHeightDelta != 0.0 {
                            var apparentFrame = node.apparentFrame
                            apparentFrame.origin.y += offsetRanges.offsetForIndex(index)
                            if apparentFrame.maxY < self.insets.top {
                                offsetRanges.offset(IndexRange(first: 0, last: index), offset: -apparentHeightDelta)
                            } else {
                                offsetRanges.offset(IndexRange(first: index + 1, last: Int.max), offset: apparentHeightDelta)
                            }
                        }
                    }
                    
                    var index = 0
                    for itemNode in self.itemNodes {
                        let offset = offsetRanges.offsetForIndex(index)
                        if offset != 0.0 {
                            var frame = itemNode.frame
                            frame.origin.y += offset
                            itemNode.frame = frame
                        }
                        
                        index += 1
                    }
            }
            
            if self.debugInfo {
                //print("operation \(self.itemNodes.map({"\($0.index) \(unsafeAddressOf($0))"}))")
            }
        }
        
        if self.debugInfo {
            //print("replay after \(self.itemNodes.map({"\($0.index) \(unsafeAddressOf($0))"}))")
        }
        
        if let scrollToItem = scrollToItem {
            self.stopScrolling()
            
            for itemNode in self.itemNodes {
                if let index = itemNode.index where index == scrollToItem.index {
                    let offset: CGFloat
                    switch scrollToItem.position {
                        case .Bottom:
                            offset = (self.visibleSize.height - self.insets.bottom) - itemNode.apparentFrame.maxY + itemNode.scrollPositioningInsets.bottom
                        case .Top:
                            offset = self.insets.top - itemNode.apparentFrame.minY - itemNode.scrollPositioningInsets.top
                        case let .Center(overflow):
                            let contentAreaHeight = self.visibleSize.height - self.insets.bottom - self.insets.top
                            if itemNode.apparentFrame.size.height <= contentAreaHeight + CGFloat(FLT_EPSILON) {
                                offset = self.insets.top + floor(((self.visibleSize.height - self.insets.bottom - self.insets.top) - itemNode.frame.size.height) / 2.0) - itemNode.apparentFrame.minY
                            } else {
                                switch overflow {
                                    case .Top:
                                        offset = self.insets.top - itemNode.apparentFrame.minY
                                    case .Bottom:
                                        offset = (self.visibleSize.height - self.insets.bottom) - itemNode.apparentFrame.maxY
                                }
                            }
                    }
                    
                    for itemNode in self.itemNodes {
                        var frame = itemNode.frame
                        frame.origin.y += offset
                        itemNode.frame = frame
                    }
                    
                    break
                }
            }
            
            /*for itemNode in self.itemNodes {
                print("item \(itemNode.index) frame \(itemNode.frame)")
            }*/
        } else if let stationaryItemIndex = stationaryItemIndex {
            for itemNode in self.itemNodes {
                if let index = itemNode.index where index == stationaryItemIndex {
                    for (previousNode, previousFrame) in previousApparentFrames {
                        if previousNode === itemNode {
                            let offset = previousFrame.minY - itemNode.frame.minY
                            
                            if abs(offset) > CGFloat(FLT_EPSILON) {
                                for itemNode in self.itemNodes {
                                    var frame = itemNode.frame
                                    frame.origin.y += offset
                                    itemNode.frame = frame
                                }
                            }
                            
                            break
                        }
                    }
                    break
                }
            }
        }
        
        self.insertNodesInBatches(nodes: [], completion: {
            self.debugCheckMonotonity()
            
            var sizeAndInsetsOffset: CGFloat = 0.0
            
            if let updateSizeAndInsets = updateSizeAndInsets {
                self.visibleSize = updateSizeAndInsets.size
                
                if self.insets != updateSizeAndInsets.insets {
                    var offsetFix = updateSizeAndInsets.insets.top - self.insets.top
                    
                    self.insets = updateSizeAndInsets.insets
                    
                    var completeOffset = offsetFix
                    sizeAndInsetsOffset = offsetFix
                    
                    for itemNode in self.itemNodes {
                        let position = itemNode.position
                        itemNode.position = CGPoint(x: position.x, y: position.y + offsetFix)
                    }
                    
                    if updateSizeAndInsets.duration > DBL_EPSILON {
                        let animation: CABasicAnimation
                        switch updateSizeAndInsets.curve {
                            case let .Spring(speed):
                                let springAnimation = makeSpringAnimation("sublayerTransform")
                                springAnimation.speed = Float(speed) * Float(1.0 / UIView.animationDurationFactor())
                                springAnimation.fromValue = NSValue(caTransform3D: CATransform3DMakeTranslation(0.0, -completeOffset, 0.0))
                                springAnimation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
                                springAnimation.isRemovedOnCompletion = true
                                springAnimation.isAdditive = true
                                animation = springAnimation
                            case .Default:
                                let basicAnimation = CABasicAnimation(keyPath: "sublayerTransform")
                                basicAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
                                basicAnimation.duration = updateSizeAndInsets.duration * UIView.animationDurationFactor()
                                basicAnimation.fromValue = NSValue(caTransform3D: CATransform3DMakeTranslation(0.0, -completeOffset, 0.0))
                                basicAnimation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
                                basicAnimation.isRemovedOnCompletion = true
                                basicAnimation.isAdditive = true
                                animation = basicAnimation
                        }
                        
                        self.layer.add(animation, forKey: nil)
                    }
                }
                
                self.ignoreScrollingEvents = true
                self.scroller.frame = CGRect(origin: CGPoint(), size: self.visibleSize)
                self.scroller.contentSize = CGSize(width: self.visibleSize.width, height: infiniteScrollSize * 2.0)
                self.lastContentOffset = CGPoint(x: 0.0, y: infiniteScrollSize)
                self.scroller.contentOffset = self.lastContentOffset
            }
            
            self.snapToBounds(scrollToItem != nil)
            
            if let scrollToItem = scrollToItem where scrollToItem.animated {
                /*for itemNode in self.itemNodes {
                    print("item \(itemNode.index) frame \(itemNode.frame)")
                }*/
                
                self.updateAccessoryNodes(animated: animated, currentTimestamp: timestamp)
                
                if self.itemNodes.count != 0 {
                    var offset: CGFloat?
                    
                    var temporaryPreviousNodes: [ListViewItemNode] = []
                    var previousUpperBound: CGFloat?
                    var previousLowerBound: CGFloat?
                    for (previousNode, previousFrame) in previousApparentFrames {
                        if previousNode.supernode == nil {
                            temporaryPreviousNodes.append(previousNode)
                            previousNode.frame = previousFrame
                            if previousUpperBound == nil || previousUpperBound! > previousFrame.minY {
                                previousUpperBound = previousFrame.minY
                            }
                            if previousLowerBound == nil || previousLowerBound! < previousFrame.maxY {
                                previousLowerBound = previousFrame.maxY
                            }
                        } else {
                            offset = previousNode.apparentFrame.minY - previousFrame.minY
                        }
                    }
                    
                    if offset == nil {
                        let updatedUpperBound = self.itemNodes[0].apparentFrame.minY
                        let updatedLowerBound = self.itemNodes[self.itemNodes.count - 1].apparentFrame.maxY
                        
                        switch scrollToItem.directionHint {
                            case .Up:
                                offset = updatedLowerBound - (previousUpperBound ?? 0.0)
                            case .Down:
                                offset = updatedUpperBound - (previousLowerBound ?? self.visibleSize.height)
                        }
                    }
                    
                    if let offsetValue = offset {
                        offset = offsetValue - sizeAndInsetsOffset
                    }
                    
                    if let offset = offset where abs(offset) > CGFloat(FLT_EPSILON) {
                        for itemNode in temporaryPreviousNodes {
                            itemNode.frame = itemNode.frame.offsetBy(dx: 0.0, dy: offset)
                            temporaryPreviousNodes.append(itemNode)
                            self.addSubnode(itemNode)
                        }
                        
                        let animation: CABasicAnimation
                        switch scrollToItem.curve {
                            case let .Spring(speed):
                                let springAnimation = makeSpringAnimation("sublayerTransform")
                                springAnimation.fromValue = NSValue(caTransform3D: CATransform3DMakeTranslation(0.0, -offset, 0.0))
                                springAnimation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
                                springAnimation.isRemovedOnCompletion = true
                                springAnimation.isAdditive = true
                                springAnimation.fillMode = kCAFillModeForwards
                                springAnimation.speed = Float(speed) * Float(1.0 / UIView.animationDurationFactor())
                                animation = springAnimation
                            case .Default:
                                let basicAnimation = CABasicAnimation(keyPath: "sublayerTransform")
                                basicAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.33, 0.52, 0.25, 0.99)
                                //basicAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
                                basicAnimation.duration = 0.5 * UIView.animationDurationFactor()
                                basicAnimation.fromValue = NSValue(caTransform3D: CATransform3DMakeTranslation(0.0, -offset, 0.0))
                                basicAnimation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
                                basicAnimation.isRemovedOnCompletion = true
                                basicAnimation.isAdditive = true
                                animation = basicAnimation
                        }
                        animation.completion = { _ in
                            for itemNode in temporaryPreviousNodes {
                                itemNode.removeFromSupernode()
                            }
                        }
                        self.layer.add(animation, forKey: nil)
                    }
                }
                
                self.setNeedsAnimations()
                
                self.updateVisibleContentOffset()
                
                if self.debugInfo {
                    let delta = CACurrentMediaTime() - timestamp
                    //print("replayOperations \(delta * 1000.0) ms")
                }
                
                completion()
            } else {
                self.updateAccessoryNodes(animated: animated, currentTimestamp: timestamp)
                if animated {
                    self.setNeedsAnimations()
                }
                
                self.updateVisibleContentOffset()
                
                if self.debugInfo {
                    let delta = CACurrentMediaTime() - timestamp
                    //print("replayOperations \(delta * 1000.0) ms")
                }
                
                completion()
            }
        })
    }
    
    private func insertNodesInBatches(nodes: [ASDisplayNode], completion: () -> Void) {
        if nodes.count == 0 {
            completion()
        } else {
            for node in nodes {
                self.addSubnode(node)
            }
            completion()
        }
    }
    
    private func debugCheckMonotonity() {
        if self.debugInfo {
            var previousMaxY: CGFloat?
            for node in self.itemNodes {
                if let previousMaxY = previousMaxY where abs(previousMaxY - node.apparentFrame.minY) > CGFloat(FLT_EPSILON) {
                    print("monotonity violated")
                    break
                }
                previousMaxY = node.apparentFrame.maxY
            }
        }
    }
    
    private func removeItemNodeAtIndex(_ index: Int) {
        let node = self.itemNodes[index]
        self.itemNodes.remove(at: index)
        node.removeFromSupernode()
        
        node.accessoryItemNode?.removeFromSupernode()
        node.accessoryItemNode = nil
        node.accessoryHeaderItemNode?.removeFromSupernode()
        node.accessoryHeaderItemNode = nil
    }
    
    private func updateAccessoryNodes(animated: Bool, currentTimestamp: Double) {
        var index = -1
        let count = self.itemNodes.count
        for itemNode in self.itemNodes {
            index += 1
            
            if let itemNodeIndex = itemNode.index {
                if let accessoryItem = self.items[itemNodeIndex].accessoryItem {
                    let previousItem: ListViewItem? = itemNodeIndex == 0 ? nil : self.items[itemNodeIndex - 1]
                    let previousAccessoryItem = previousItem?.accessoryItem
                    
                    if (previousAccessoryItem == nil || !previousAccessoryItem!.isEqualToItem(accessoryItem)) {
                        if itemNode.accessoryItemNode == nil {
                            var didStealAccessoryNode = false
                            if index != count - 1 {
                                for i in index + 1 ..< count {
                                    let nextItemNode = self.itemNodes[i]
                                    if let nextItemNodeIndex = nextItemNode.index {
                                        let nextItem = self.items[nextItemNodeIndex]
                                        if let nextAccessoryItem = nextItem.accessoryItem where nextAccessoryItem.isEqualToItem(accessoryItem) {
                                            if let nextAccessoryItemNode = nextItemNode.accessoryItemNode {
                                                didStealAccessoryNode = true
                                                
                                                var previousAccessoryItemNodeOrigin = nextAccessoryItemNode.frame.origin
                                                let previousParentOrigin = nextItemNode.frame.origin
                                                previousAccessoryItemNodeOrigin.x += previousParentOrigin.x
                                                previousAccessoryItemNodeOrigin.y += previousParentOrigin.y
                                                previousAccessoryItemNodeOrigin.y -= nextItemNode.bounds.origin.y
                                                previousAccessoryItemNodeOrigin.y -= nextAccessoryItemNode.transitionOffset.y
                                                nextAccessoryItemNode.transitionOffset = CGPoint()
                                                
                                                nextAccessoryItemNode.removeFromSupernode()
                                                itemNode.addSubnode(nextAccessoryItemNode)
                                                itemNode.accessoryItemNode = nextAccessoryItemNode
                                                self.itemNodes[i].accessoryItemNode = nil
                                                
                                                var updatedAccessoryItemNodeOrigin = nextAccessoryItemNode.frame.origin
                                                let updatedParentOrigin = itemNode.frame.origin
                                                updatedAccessoryItemNodeOrigin.x += updatedParentOrigin.x
                                                updatedAccessoryItemNodeOrigin.y += updatedParentOrigin.y
                                                updatedAccessoryItemNodeOrigin.y -= itemNode.bounds.origin.y
                                                
                                                let deltaHeight = itemNode.frame.size.height - nextItemNode.frame.size.height
                                                
                                                nextAccessoryItemNode.animateTransitionOffset(CGPoint(x: 0.0, y: updatedAccessoryItemNodeOrigin.y - previousAccessoryItemNodeOrigin.y - deltaHeight), beginAt: currentTimestamp, duration: insertionAnimationDuration * UIView.animationDurationFactor(), curve: listViewAnimationCurveSystem)
                                            }
                                        } else {
                                            break
                                        }
                                    }
                                }
                            }
                            
                            if !didStealAccessoryNode {
                                let accessoryNode = accessoryItem.node()
                                itemNode.addSubnode(accessoryNode)
                                itemNode.accessoryItemNode = accessoryNode
                            }
                        }
                    } else {
                        itemNode.accessoryItemNode?.removeFromSupernode()
                        itemNode.accessoryItemNode = nil
                    }
                }
            }
        }
    }
    
    private func enqueueUpdateVisibleItems() {
        if !self.enqueuedUpdateVisibleItems {
            self.enqueuedUpdateVisibleItems = true
            
            self.transactionQueue.addTransaction({ [weak self] completion in
                if let strongSelf = self {
                    strongSelf.transactionOffset = 0.0
                    strongSelf.updateVisibleItemsTransaction(completion: {
                        var repeatUpdate = false
                        if let strongSelf = self {
                            repeatUpdate = abs(strongSelf.transactionOffset) > 0.00001
                            strongSelf.transactionOffset = 0.0
                            strongSelf.enqueuedUpdateVisibleItems = false
                        }
                        
                        //dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2.0 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), {
                                completion()
                        
                            if repeatUpdate {
                                strongSelf.enqueueUpdateVisibleItems()
                            }
                        //})
                    })
                }
            })
        }
    }
    
    private func updateVisibleItemsTransaction(completion: (Void) -> Void) {
        if self.items.count == 0 && self.itemNodes.count == 0 {
            completion()
            return
        }
        var i = 0
        while i < self.itemNodes.count {
            let node = self.itemNodes[i]
            if node.index == nil && node.apparentHeight <= CGFloat(FLT_EPSILON) {
                self.removeItemNodeAtIndex(i)
            } else {
                i += 1
            }
        }
        
        self.fillMissingNodes(synchronous: false, animated: false, inputAnimatedInsertIndices: [], insertDirectionHints: [:], inputState: self.currentState(), inputPreviousNodes: [:], inputOperations: []) { state, operations in
            
            var updatedState = state
            var updatedOperations = operations
            updatedState.removeInvisibleNodes(&updatedOperations)
            self.dispatchOnVSync {
                self.replayOperations(animated: false, animateAlpha: false, operations: updatedOperations, scrollToItem: nil, updateSizeAndInsets: nil, stationaryItemIndex: nil, completion: completion)
            }
        }
    }
    
    private func updateVisibleItemRange(force: Bool = false) {
        let currentRange = self.immediateDisplayedItemRange()
        
        if currentRange != self.displayedItemRange || force {
            self.displayedItemRange = currentRange
            self.displayedItemRangeChanged(currentRange)
        }
    }
    
    private func immediateDisplayedItemRange() -> ListViewDisplayedItemRange {
        var loadedRange: ListViewItemRange?
        var visibleRange: ListViewItemRange?
        if self.itemNodes.count != 0 {
            var firstIndex: (nodeIndex: Int, index: Int)?
            var lastIndex: (nodeIndex: Int, index: Int)?
            
            var i = 0
            while i < self.itemNodes.count {
                if let index = self.itemNodes[i].index {
                    firstIndex = (i, index)
                    break
                }
                i += 1
            }
            i = self.itemNodes.count - 1
            while i >= 0 {
                if let index = self.itemNodes[i].index {
                    lastIndex = (i, index)
                    break
                }
                i -= 1
            }
            if let firstIndex = firstIndex, lastIndex = lastIndex {
                var firstVisibleIndex: Int?
                for i in firstIndex.nodeIndex ... lastIndex.nodeIndex {
                    if let index = self.itemNodes[i].index {
                        let frame = self.itemNodes[i].apparentFrame
                        if frame.maxY >= self.insets.top && frame.minY < self.visibleSize.height + self.insets.bottom {
                            firstVisibleIndex = index
                            break
                        }
                    }
                }
                
                if let firstVisibleIndex = firstVisibleIndex {
                    var lastVisibleIndex: Int?
                    for i in (firstIndex.nodeIndex ... lastIndex.nodeIndex).reversed() {
                        if let index = self.itemNodes[i].index {
                            let frame = self.itemNodes[i].apparentFrame
                            if frame.maxY >= self.insets.top && frame.minY < self.visibleSize.height - self.insets.bottom {
                                lastVisibleIndex = index
                                break
                            }
                        }
                    }
                    
                    if let lastVisibleIndex = lastVisibleIndex {
                        visibleRange = ListViewItemRange(firstIndex: firstVisibleIndex, lastIndex: lastVisibleIndex)
                    }
                }
                
                loadedRange = ListViewItemRange(firstIndex: firstIndex.index, lastIndex: lastIndex.index)
            }
        }
        
        return ListViewDisplayedItemRange(loadedRange: loadedRange, visibleRange: visibleRange)
    }
    
    public func updateSizeAndInsets(size: CGSize, insets: UIEdgeInsets, duration: Double = 0.0, options: UIViewAnimationOptions = UIViewAnimationOptions()) {
        self.transactionQueue.addTransaction({ [weak self] completion in
            if let strongSelf = self {
                strongSelf.transactionOffset = 0.0
                strongSelf.updateSizeAndInsetsTransaction(size: size, insets: insets, duration: duration, options: options, completion: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.transactionOffset = 0.0
                        strongSelf.updateVisibleItemsTransaction(completion: completion)
                    }
                })
            }
        })
        
        if useDynamicTuning {
            self.frictionSlider.frame = CGRect(x: 10.0, y: size.height - insets.bottom - 10.0 - self.frictionSlider.bounds.height, width: size.width - 20.0, height: self.frictionSlider.bounds.height)
            self.springSlider.frame = CGRect(x: 10.0, y: self.frictionSlider.frame.minY - self.springSlider.bounds.height, width: size.width - 20.0, height: self.springSlider.bounds.height)
            self.freeResistanceSlider.frame = CGRect(x: 10.0, y: self.springSlider.frame.minY - self.freeResistanceSlider.bounds.height, width: size.width - 20.0, height: self.freeResistanceSlider.bounds.height)
            self.scrollingResistanceSlider.frame = CGRect(x: 10.0, y: self.freeResistanceSlider.frame.minY - self.scrollingResistanceSlider.bounds.height, width: size.width - 20.0, height: self.scrollingResistanceSlider.bounds.height)
        }
    }
    
    private func updateSizeAndInsetsTransaction(size: CGSize, insets: UIEdgeInsets, duration: Double, options: UIViewAnimationOptions, completion: (Void) -> Void) {
        if size.equalTo(self.visibleSize) && UIEdgeInsetsEqualToEdgeInsets(self.insets, insets) {
            completion()
        } else {
            if abs(size.width - self.visibleSize.width) > CGFloat(FLT_EPSILON) {
                let itemNodes = self.itemNodes
                for itemNode in itemNodes {
                    itemNode.removeAllAnimations()
                    itemNode.transitionOffset = 0.0
                    if let index = itemNode.index {
                        itemNode.layoutForWidth(size.width, item: self.items[index], previousItem: index == 0 ? nil : self.items[index - 1], nextItem: index == self.items.count - 1 ? nil : self.items[index + 1])
                    }
                    itemNode.apparentHeight = itemNode.bounds.height
                }
                
                if itemNodes.count != 0 {
                    for i in 0 ..< itemNodes.count - 1 {
                        var nextFrame = itemNodes[i + 1].frame
                        nextFrame.origin.y = itemNodes[i].apparentFrame.maxY
                        itemNodes[i + 1].frame = nextFrame
                    }
                }
            }
            
            var offsetFix = insets.top - self.insets.top
            
            self.visibleSize = size
            self.insets = insets
            
            var completeOffset = offsetFix
            
            for itemNode in self.itemNodes {
                let position = itemNode.position
                itemNode.position = CGPoint(x: position.x, y: position.y + offsetFix)
            }
            
            let completeDeltaHeight = offsetFix
            offsetFix = 0.0
            
            if Double(completeDeltaHeight) < DBL_EPSILON && self.itemNodes.count != 0 {
                let firstItemNode = self.itemNodes[0]
                let lastItemNode = self.itemNodes[self.itemNodes.count - 1]
                
                if lastItemNode.index == self.items.count - 1 {
                    if firstItemNode.index == 0 {
                        let topGap = firstItemNode.apparentFrame.origin.y - self.insets.top
                        let bottomGap = self.visibleSize.height - lastItemNode.apparentFrame.maxY - self.insets.bottom
                        if Double(bottomGap) > DBL_EPSILON {
                            offsetFix = -bottomGap
                            if topGap + bottomGap > 0.0 {
                                offsetFix = topGap
                            }
                            
                            let absOffsetFix = abs(offsetFix)
                            let absCompleteDeltaHeight = abs(completeDeltaHeight)
                            offsetFix = min(absOffsetFix, absCompleteDeltaHeight) * (offsetFix < 0 ? -1.0 : 1.0)
                        }
                    } else {
                        offsetFix = completeDeltaHeight
                    }
                }
            }
            
            if Double(abs(offsetFix)) > DBL_EPSILON {
                completeOffset -= offsetFix
                for itemNode in self.itemNodes {
                    let position = itemNode.position
                    itemNode.position = CGPoint(x: position.x, y: position.y - offsetFix)
                }
            }
            
            self.snapToBounds()
            
            self.ignoreScrollingEvents = true
            self.scroller.frame = CGRect(origin: CGPoint(), size: size)
            self.scroller.contentSize = CGSize(width: size.width, height: infiniteScrollSize * 2.0)
            self.lastContentOffset = CGPoint(x: 0.0, y: infiniteScrollSize)
            self.scroller.contentOffset = self.lastContentOffset
            
            self.updateScroller()
            self.updateVisibleItemRange()
            
            let completion = { [weak self] (_: Bool) -> Void in
                if let strongSelf = self {
                    strongSelf.updateVisibleItemsTransaction(completion: completion)
                    strongSelf.ignoreScrollingEvents = false
                }
            }
            
            if duration > DBL_EPSILON {
                let animation: CABasicAnimation
                if (options.rawValue & UInt(7 << 16)) != 0 {
                    let springAnimation = makeSpringAnimation("sublayerTransform")
                    springAnimation.duration = duration * UIView.animationDurationFactor()
                    springAnimation.fromValue = NSValue(caTransform3D: CATransform3DMakeTranslation(0.0, -completeOffset, 0.0))
                    springAnimation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
                    springAnimation.isRemovedOnCompletion = true
                    animation = springAnimation
                } else {
                    let basicAnimation = CABasicAnimation(keyPath: "sublayerTransform")
                    basicAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
                    basicAnimation.duration = duration * UIView.animationDurationFactor()
                    basicAnimation.fromValue = NSValue(caTransform3D: CATransform3DMakeTranslation(0.0, -completeOffset, 0.0))
                    basicAnimation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
                    basicAnimation.isRemovedOnCompletion = true
                    animation = basicAnimation
                }
                
                animation.completion = completion
                self.layer.add(animation, forKey: "sublayerTransform")
            } else {
                completion(true)
            }
        }
    }
    
    private func updateAnimations() {
        self.inVSync = true
        let actionsForVSync = self.actionsForVSync
        self.actionsForVSync.removeAll()
        for action in actionsForVSync {
            action()
        }
        self.inVSync = false
        
        let timestamp: Double = CACurrentMediaTime()
        
        var continueAnimations = false
        
        if !self.actionsForVSync.isEmpty {
            continueAnimations = true
        }
        
        var i = 0
        var animationCount = self.animations.count
        while i < animationCount {
            let animation = self.animations[i]
            animation.applyAt(timestamp)
            
            if animation.completeAt(timestamp) {
                animations.remove(at: i)
                animationCount -= 1
                i -= 1
            } else {
                continueAnimations = true
            }
            
            i += 1
        }
        
        var offsetRanges = OffsetRanges()
        
        var requestUpdateVisibleItems = false
        var index = 0
        while index < self.itemNodes.count {
            let itemNode = self.itemNodes[index]
            
            let previousApparentHeight = itemNode.apparentHeight
            if itemNode.animate(timestamp) {
                continueAnimations = true
            }
            let updatedApparentHeight = itemNode.apparentHeight
            let apparentHeightDelta = updatedApparentHeight - previousApparentHeight
            if abs(apparentHeightDelta) > CGFloat(FLT_EPSILON) {
                if itemNode.apparentFrame.maxY < self.insets.top + CGFloat(FLT_EPSILON) {
                    offsetRanges.offset(IndexRange(first: 0, last: index), offset: -apparentHeightDelta)
                } else {
                    offsetRanges.offset(IndexRange(first: index + 1, last: Int.max), offset: apparentHeightDelta)
                }
            }
            
            if itemNode.index == nil && updatedApparentHeight <= CGFloat(FLT_EPSILON) {
                requestUpdateVisibleItems = true
            }
            
            index += 1
        }
        
        if !offsetRanges.offsets.isEmpty {
            requestUpdateVisibleItems = true
            var index = 0
            for itemNode in self.itemNodes {
                let offset = offsetRanges.offsetForIndex(index)
                if offset != 0.0 {
                    var position = itemNode.position
                    position.y += offset
                    itemNode.position = position
                }
                
                index += 1
            }
            
            self.snapToBounds()
        }
        
        self.debugCheckMonotonity()
        
        if !continueAnimations {
            self.pauseAnimations()
        }
        
        if requestUpdateVisibleItems {
            self.enqueueUpdateVisibleItems()
        }
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.isTracking = true
        self.touchesPosition = (touches.first!).location(in: self.view)
        self.selectionTouchLocation = self.touchesPosition
        
        self.selectionTouchDelayTimer?.invalidate()
        let timer = Timer(timeInterval: 0.08, target: ListViewTimerProxy { [weak self] in
            if let strongSelf = self where strongSelf.selectionTouchLocation != nil {
                strongSelf.clearHighlightAnimated(false)
                let index = strongSelf.itemIndexAtPoint(strongSelf.touchesPosition)
                
                if let index = index {
                    if strongSelf.items[index].selectable {
                        strongSelf.highlightedItemIndex = index
                        for itemNode in strongSelf.itemNodes {
                            if itemNode.index == index {
                                if !itemNode.isLayerBacked {
                                    strongSelf.view.bringSubview(toFront: itemNode.view)
                                }
                                itemNode.setHighlighted(true, animated: false)
                                break
                            }
                        }
                    }
                }
            }
        }, selector: #selector(ListViewTimerProxy.timerEvent), userInfo: nil, repeats: false)
        self.selectionTouchDelayTimer = timer
        RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
        
        super.touchesBegan(touches, with: event)
        
        self.updateScroller()
    }
    
    public func clearHighlightAnimated(_ animated: Bool) {
        if let highlightedItemIndex = self.highlightedItemIndex {
            for itemNode in self.itemNodes {
                if itemNode.index == highlightedItemIndex {
                    itemNode.setHighlighted(false, animated: animated)
                    break
                }
            }
        }
        self.highlightedItemIndex = nil
    }
    
    private func itemIndexAtPoint(_ point: CGPoint) -> Int? {
        for itemNode in self.itemNodes {
            if itemNode.apparentFrame.contains(point) {
                return itemNode.index
            }
        }
        return nil
    }
    
    public func forEachItemNode(_ f: (ListViewItemNode) -> Void) {
        for itemNode in self.itemNodes {
            if itemNode.index != nil {
                f(itemNode)
            }
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touchesPosition = touches.first!.location(in: self.view)
        if let selectionTouchLocation = self.selectionTouchLocation {
            let distance = CGPoint(x: selectionTouchLocation.x - self.touchesPosition.x, y: selectionTouchLocation.y - self.touchesPosition.y)
            let maxMovementDistance: CGFloat = 4.0
            if distance.x * distance.x + distance.y * distance.y > maxMovementDistance * maxMovementDistance {
                self.selectionTouchLocation = nil
                self.selectionTouchDelayTimer?.invalidate()
                self.selectionTouchDelayTimer = nil
                self.clearHighlightAnimated(false)
            }
        }
        
        super.touchesMoved(touches, with: event)
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.isTracking = false
        
        if let selectionTouchLocation = self.selectionTouchLocation {
            let index = self.itemIndexAtPoint(selectionTouchLocation)
            if index != self.highlightedItemIndex {
                self.clearHighlightAnimated(false)
            }
            
            if let index = index {
                if self.items[index].selectable {
                    self.highlightedItemIndex = index
                    for itemNode in self.itemNodes {
                        if itemNode.index == index {
                            if !itemNode.isLayerBacked {
                                self.view.bringSubview(toFront: itemNode.view)
                            }
                            itemNode.setHighlighted(true, animated: false)
                            break
                        }
                    }
                }
            }
        }
        
        if let highlightedItemIndex = self.highlightedItemIndex {
            self.items[highlightedItemIndex].selected()
        }
        self.selectionTouchLocation = nil
        
        super.touchesEnded(touches, with: event)
    }
    
    override public func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        self.isTracking = false
        
        self.selectionTouchLocation = nil
        self.selectionTouchDelayTimer?.invalidate()
        self.selectionTouchDelayTimer = nil
        self.clearHighlightAnimated(false)
        
        super.touchesCancelled(touches, with: event)
    }
}
