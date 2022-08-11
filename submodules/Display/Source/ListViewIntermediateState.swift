import Foundation
import UIKit
import SwiftSignalKit

public enum ListViewCenterScrollPositionOverflow {
    case top
    case bottom
}

public enum ListViewScrollPosition: Equatable {
    case top(CGFloat)
    case bottom(CGFloat)
    case center(ListViewCenterScrollPositionOverflow)
    case visible
}

public enum ListViewScrollToItemDirectionHint {
    case Up
    case Down
}

public enum ListViewAnimationCurve {
    case Spring(duration: Double)
    case Default(duration: Double?)
    case Custom(duration: Double, Float, Float, Float, Float)
}

public struct ListViewScrollToItem {
    public let index: Int
    public let position: ListViewScrollPosition
    public let animated: Bool
    public let curve: ListViewAnimationCurve
    public let directionHint: ListViewScrollToItemDirectionHint
    public let displayLink: Bool
    
    public init(index: Int, position: ListViewScrollPosition, animated: Bool, curve: ListViewAnimationCurve, directionHint: ListViewScrollToItemDirectionHint, displayLink: Bool = false) {
        self.index = index
        self.position = position
        self.animated = animated
        self.curve = curve
        self.directionHint = directionHint
        self.displayLink = displayLink
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
    public let forceAnimateInsertion: Bool
    
    public init(index: Int, previousIndex: Int?, item: ListViewItem, directionHint: ListViewItemOperationDirectionHint?, forceAnimateInsertion: Bool = false) {
        self.index = index
        self.previousIndex = previousIndex
        self.item = item
        self.directionHint = directionHint
        self.forceAnimateInsertion = forceAnimateInsertion
    }
}

public struct ListViewUpdateItem {
    public let index: Int
    public let previousIndex: Int
    public let item: ListViewItem
    public let directionHint: ListViewItemOperationDirectionHint?
    
    public init(index: Int, previousIndex: Int, item: ListViewItem, directionHint: ListViewItemOperationDirectionHint?) {
        self.index = index
        self.previousIndex = previousIndex
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
    public static let RequestItemInsertionAnimations = ListViewDeleteAndInsertOptions(rawValue: 16)
    public static let AnimateTopItemPosition = ListViewDeleteAndInsertOptions(rawValue: 32)
    public static let PreferSynchronousDrawing = ListViewDeleteAndInsertOptions(rawValue: 64)
    public static let PreferSynchronousResourceLoading = ListViewDeleteAndInsertOptions(rawValue: 128)
    public static let AnimateCrossfade = ListViewDeleteAndInsertOptions(rawValue: 256)
}

public struct ListViewUpdateSizeAndInsets {
    public let size: CGSize
    public let insets: UIEdgeInsets
    public let headerInsets: UIEdgeInsets?
    public let scrollIndicatorInsets: UIEdgeInsets?
    public let duration: Double
    public let curve: ListViewAnimationCurve
    public let ensureTopInsetForOverlayHighlightedItems: CGFloat?
    
    public init(size: CGSize, insets: UIEdgeInsets, headerInsets: UIEdgeInsets? = nil, scrollIndicatorInsets: UIEdgeInsets? = nil, duration: Double, curve: ListViewAnimationCurve, ensureTopInsetForOverlayHighlightedItems: CGFloat? = nil) {
        self.size = size
        self.insets = insets
        self.headerInsets = headerInsets
        self.scrollIndicatorInsets = scrollIndicatorInsets
        self.duration = duration
        self.curve = curve
        self.ensureTopInsetForOverlayHighlightedItems = ensureTopInsetForOverlayHighlightedItems
    }
}

public struct ListViewItemRange: Equatable {
    public let firstIndex: Int
    public let lastIndex: Int
}

public struct ListViewVisibleItemRange: Equatable {
    public let firstIndex: Int
    public let firstIndexFullyVisible: Bool
    public let lastIndex: Int
}

public struct ListViewDisplayedItemRange: Equatable {
    public let loadedRange: ListViewItemRange?
    public let visibleRange: ListViewVisibleItemRange?
}

struct IndexRange {
    let first: Int
    let last: Int
    
    func contains(_ index: Int) -> Bool {
        return index >= first && index <= last
    }
    
    var empty: Bool {
        return first > last
    }
}

struct OffsetRanges {
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

func binarySearch(_ inputArr: [Int], searchItem: Int) -> Int? {
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

struct TransactionState {
    let visibleSize: CGSize
    let items: [ListViewItem]
}

struct PendingNode {
    let index: Int
    let node: QueueLocalObject<ListViewItemNode>
    let apply: () -> (Signal<Void, NoError>?, () -> Void)
    let frame: CGRect
    let apparentHeight: CGFloat
}

enum ListViewStateNode {
    case Node(index: Int, frame: CGRect, referenceNode: QueueLocalObject<ListViewItemNode>?)
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

enum ListViewInsertionOffsetDirection {
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

struct ListViewInsertionPoint {
    let index: Int
    let point: CGPoint
    let direction: ListViewInsertionOffsetDirection
}

struct ListViewState {
    var insets: UIEdgeInsets
    var visibleSize: CGSize
    let invisibleInset: CGFloat
    var nodes: [ListViewStateNode]
    var scrollPosition: (Int, ListViewScrollPosition)?
    var stationaryOffset: (Int, CGFloat)?
    let stackFromBottom: Bool
    
    mutating func fixScrollPosition(_ itemCount: Int) {
        if let (fixedIndex, fixedPosition) = self.scrollPosition {
            for node in self.nodes {
                if let index = node.index, index == fixedIndex {
                    let offset: CGFloat
                    switch fixedPosition {
                        case let .bottom(additionalOffset):
                            offset = (self.visibleSize.height - self.insets.bottom) - node.frame.maxY + additionalOffset
                        case let .top(additionalOffset):
                            offset = self.insets.top - node.frame.minY + additionalOffset
                        case let .center(overflow):
                            let contentAreaHeight = self.visibleSize.height - self.insets.bottom - self.insets.top
                            if node.frame.size.height <= contentAreaHeight + CGFloat.ulpOfOne {
                                offset = self.insets.top + floor((contentAreaHeight - node.frame.size.height) / 2.0) - node.frame.minY
                            } else {
                                switch overflow {
                                    case .top:
                                        offset = self.insets.top - node.frame.minY
                                    case .bottom:
                                        offset = (self.visibleSize.height - self.insets.bottom) - node.frame.maxY
                                }
                            }
                        case .visible:
                            if node.frame.maxY > self.visibleSize.height - self.insets.bottom {
                                offset = (self.visibleSize.height - self.insets.bottom) - node.frame.maxY
                            } else if node.frame.minY < self.insets.top {
                                offset = self.insets.top - node.frame.minY
                            } else {
                                offset = 0.0
                            }
                    }
                    
                    var minY: CGFloat = CGFloat.greatestFiniteMagnitude
                    var maxY: CGFloat = 0.0
                    for i in 0 ..< self.nodes.count {
                        var frame = self.nodes[i].frame
                        frame = frame.offsetBy(dx: 0.0, dy: offset)
                        self.nodes[i].frame = frame
                        
                        minY = min(minY, frame.minY)
                        maxY = max(maxY, frame.maxY)
                    }
                    
                    var additionalOffset: CGFloat = 0.0
                    if minY > self.insets.top {
                        additionalOffset = self.insets.top - minY
                    }
                    
                    if abs(additionalOffset) > CGFloat.ulpOfOne {
                        for i in 0 ..< self.nodes.count {
                            var frame = self.nodes[i].frame
                            frame = frame.offsetBy(dx: 0.0, dy: additionalOffset)
                            self.nodes[i].frame = frame
                        }
                    }
                    
                    self.snapToBounds(itemCount, snapTopItem: true, stackFromBottom: self.stackFromBottom)
                    
                    break
                }
            }
        } else if let (stationaryIndex, stationaryOffset) = self.stationaryOffset {
            for node in self.nodes {
                if node.index == stationaryIndex {
                    let offset = stationaryOffset - node.frame.minY
                    
                    if abs(offset) > CGFloat.ulpOfOne {
                        for i in 0 ..< self.nodes.count {
                            var frame = self.nodes[i].frame
                            frame = frame.offsetBy(dx: 0.0, dy: offset)
                            self.nodes[i].frame = frame
                        }
                    }
                    
                    break
                }
            }
        }
    }
    
    mutating func setupStationaryOffset(_ index: Int, boundary: Int, frames: [Int: CGRect]) {
        if index < boundary {
            for node in self.nodes {
                if let nodeIndex = node.index , nodeIndex >= index {
                    if let frame = frames[nodeIndex] {
                        self.stationaryOffset = (nodeIndex, frame.minY)
                        break
                    }
                }
            }
        } else {
            for node in self.nodes.reversed() {
                if let nodeIndex = node.index , nodeIndex <= index {
                    if let frame = frames[nodeIndex] {
                        self.stationaryOffset = (nodeIndex, frame.minY)
                        break
                    }
                }
            }
        }
    }
    
    mutating func snapToBounds(_ itemCount: Int, snapTopItem: Bool, stackFromBottom: Bool) {
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
        
        if abs(offset) > CGFloat.ulpOfOne {
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
                if let index = node.index , index == fixedIndex {
                    fixedNode = (i, index, node.frame)
                    break
                }
            }
            
            if fixedNode == nil {
                return ListViewInsertionPoint(index: fixedIndex, point: CGPoint(), direction: .Down)
            }
        }
        
        var fixedNodeIsStationary = false
        if fixedNode == nil {
            if let (fixedIndex, _) = self.stationaryOffset {
                for i in 0 ..< self.nodes.count {
                    let node = self.nodes[i]
                    if let index = node.index , index == fixedIndex {
                        fixedNode = (i, index, node.frame)
                        fixedNodeIsStationary = true
                        break
                    }
                }
            }
        }
        
        if fixedNode == nil {
            for i in 0 ..< self.nodes.count {
                let node = self.nodes[i]
                if let index = node.index , node.frame.maxY >= self.insets.top {
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
                        if currentUpperNode.frame.minY > -self.invisibleInset - CGFloat.ulpOfOne {
                            var directionHint: ListViewInsertionOffsetDirection?
                            if let hint = insertDirectionHints[currentUpperNode.index - 1] , currentUpperNode.frame.minY > self.insets.top - CGFloat.ulpOfOne {
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
            
            if currentUpperNode.index != 0 && currentUpperNode.frame.minY > -self.invisibleInset - CGFloat.ulpOfOne {
                var directionHint: ListViewInsertionOffsetDirection?
                if let hint = insertDirectionHints[currentUpperNode.index - 1] {
                    if currentUpperNode.frame.minY >= self.insets.top - CGFloat.ulpOfOne {
                        directionHint = ListViewInsertionOffsetDirection(hint)
                    }
                } else if currentUpperNode.frame.minY >= self.insets.top - CGFloat.ulpOfOne && !fixedNodeIsStationary {
                    directionHint = .Down
                }
                
                return ListViewInsertionPoint(index: currentUpperNode.index - 1, point: CGPoint(x: 0.0, y: currentUpperNode.frame.minY), direction: directionHint ?? .Up)
            }
            
            var currentLowerNode = fixedNode
            if fixedNode.nodeIndex + 1 < self.nodes.count {
                for i in (fixedNode.nodeIndex + 1) ..< self.nodes.count {
                    let node = self.nodes[i]
                    if let index = node.index {
                        if index != currentLowerNode.index + 1 {
                            if currentLowerNode.frame.maxY < self.visibleSize.height + self.invisibleInset - CGFloat.ulpOfOne {
                                var directionHint: ListViewInsertionOffsetDirection?
                                if let hint = insertDirectionHints[currentLowerNode.index + 1] , currentLowerNode.frame.maxY < self.visibleSize.height - self.insets.bottom + CGFloat.ulpOfOne {
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
            
            if currentLowerNode.index != itemCount - 1 && currentLowerNode.frame.maxY < self.visibleSize.height + self.invisibleInset - CGFloat.ulpOfOne {
                var directionHint: ListViewInsertionOffsetDirection?
                if let hint = insertDirectionHints[currentLowerNode.index + 1] , currentLowerNode.frame.maxY < self.visibleSize.height - self.insets.bottom + CGFloat.ulpOfOne {
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
                //print("node \(i) frame \(frame)")
                if frame.maxY < -self.invisibleInset || frame.origin.y > self.visibleSize.height + self.invisibleInset {
                    //print("remove invisible 1 \(i) frame \(frame)")
                    operations.append(.Remove(index: i, offsetDirection: frame.maxY < -self.invisibleInset ? .Down : .Up))
                    self.nodes.remove(at: i)
                }
                
                i -= 1
            }
        }
        
        let upperBound = -self.invisibleInset + CGFloat.ulpOfOne
        for i in 0 ..< self.nodes.count {
            let node = self.nodes[i]
            if let index = node.index , node.frame.maxY > upperBound {
                if i != 0 {
                    var previousIndex = index
                    for j in (0 ..< i).reversed() {
                        if self.nodes[j].frame.maxY < upperBound {
                            if let index = self.nodes[j].index {
                                if index != previousIndex - 1 {
                                    //print("remove monotonity \(j) (\(index))")
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
        
        let lowerBound = self.visibleSize.height + self.invisibleInset - CGFloat.ulpOfOne
        for i in (0 ..< self.nodes.count).reversed() {
            let node = self.nodes[i]
            if let index = node.index , node.frame.minY < lowerBound {
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
                            //print("remove monotonity \(i) (\(self.nodes[i].index!))")
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
    
    mutating func insertNode(_ itemIndex: Int, node: QueueLocalObject<ListViewItemNode>, layout: ListViewItemNodeLayout, apply: @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void), offsetDirection: ListViewInsertionOffsetDirection, animated: Bool, operations: inout [ListViewStateOperation], itemCount: Int) {
        let (insertionOrigin, insertionIndex) = self.nodeInsertionPointAndIndex(itemIndex)
        
        let nodeOrigin: CGPoint
        switch offsetDirection {
        case .Up:
            nodeOrigin = CGPoint(x: insertionOrigin.x, y: insertionOrigin.y - (animated ? 0.0 : layout.size.height))
        case .Down:
            nodeOrigin = insertionOrigin
        }
        
        let nodeFrame = CGRect(origin: nodeOrigin, size: CGSize(width: layout.size.width, height: animated ? 0.0 : layout.size.height))
        
        operations.append(.InsertNode(index: insertionIndex, offsetDirection: offsetDirection, animated: animated, node: node, layout: layout, apply: apply))
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
            self.fixScrollPosition(itemCount)
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
                if nodeFrame.maxY < self.insets.top + CGFloat.ulpOfOne {
                    offsetDirection = .Down
                } else {
                    offsetDirection = .Up
                }
            }
            operations.append(.Remove(index: index, offsetDirection: offsetDirection))
            
            if let referenceNode = referenceNode , animated {
                self.nodes.insert(.Placeholder(frame: nodeFrame), at: index)
                operations.append(.InsertDisappearingPlaceholder(index: index, referenceNode: referenceNode, offsetDirection: offsetDirection.inverted()))
            } else {
                if nodeFrame.maxY > self.insets.top - CGFloat.ulpOfOne {
                    if let direction = direction , direction == .Down && node.frame.minY < self.visibleSize.height - self.insets.bottom + CGFloat.ulpOfOne {
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
    
    mutating func updateNodeAtItemIndex(_ itemIndex: Int, layout: ListViewItemNodeLayout, direction: ListViewItemOperationDirectionHint?, isAnimated: Bool, apply: @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void), operations: inout [ListViewStateOperation]) {
        var i = -1
        for node in self.nodes {
            i += 1
            if node.index == itemIndex {
                if !isAnimated {
                    let offsetDirection: ListViewInsertionOffsetDirection
                    if let direction = direction {
                        offsetDirection = ListViewInsertionOffsetDirection(direction)
                    } else {
                        if node.frame.maxY < self.insets.top + CGFloat.ulpOfOne {
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
                    
                    operations.append(.UpdateLayout(index: i, layout: layout, apply: apply))
                } else {
                    operations.append(.UpdateLayout(index: i, layout: layout, apply: apply))
                }
                
                break
            }
        }
    }
}

enum ListViewStateOperation {
    case InsertNode(index: Int, offsetDirection: ListViewInsertionOffsetDirection, animated: Bool, node: QueueLocalObject<ListViewItemNode>, layout: ListViewItemNodeLayout, apply: () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void))
    case InsertDisappearingPlaceholder(index: Int, referenceNode: QueueLocalObject<ListViewItemNode>, offsetDirection: ListViewInsertionOffsetDirection)
    case Remove(index: Int, offsetDirection: ListViewInsertionOffsetDirection)
    case Remap([Int: Int])
    case UpdateLayout(index: Int, layout: ListViewItemNodeLayout, apply: () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void))
}
