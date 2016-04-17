import UIKit
import AsyncDisplayKit
import SwiftSignalKit

private let usePerformanceTracker = false
private let useDynamicTuning = false

public enum ListViewScrollPosition {
    case Top
    case Bottom
    case Center
}

public struct ListViewDeleteAndInsertOptions: OptionSetType {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let AnimateInsertion = ListViewDeleteAndInsertOptions(rawValue: 1)
    public static let AnimateAlpha = ListViewDeleteAndInsertOptions(rawValue: 2)
}

public struct ListViewVisibleRange: Equatable {
    public let firstIndex: Int
    public let lastIndex: Int
}

public func ==(lhs: ListViewVisibleRange, rhs: ListViewVisibleRange) -> Bool {
    return lhs.firstIndex == rhs.firstIndex && lhs.lastIndex == rhs.lastIndex
}

private struct IndexRange {
    let first: Int
    let last: Int
    
    func contains(index: Int) -> Bool {
        return index >= first && index <= last
    }
    
    var empty: Bool {
        return first > last
    }
}

private struct OffsetRanges {
    var offsets: [(IndexRange, CGFloat)] = []
    
    mutating func append(other: OffsetRanges) {
        self.offsets.appendContentsOf(other.offsets)
    }
    
    mutating func offset(indexRange: IndexRange, offset: CGFloat) {
        self.offsets.append((indexRange, offset))
    }
    
    func offsetForIndex(index: Int) -> CGFloat {
        var result: CGFloat = 0.0
        for offset in self.offsets {
            if offset.0.contains(index) {
                result += offset.1
            }
        }
        return result
    }
}

private func binarySearch(inputArr: [Int], searchItem: Int) -> Int? {
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
}

private struct ListViewState {
    let insets: UIEdgeInsets
    let visibleSize: CGSize
    let invisibleInset: CGFloat
    var nodes: [ListViewStateNode]
    
    func nodeInsertionPointAndIndex(itemIndex: Int) -> (CGPoint, Int) {
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
    
    mutating func insertNode(itemIndex: Int, node: ListViewItemNode, layout: ListViewItemNodeLayout, apply: () -> (), offsetDirection: ListViewInsertionOffsetDirection, animated: Bool, inout operations: [ListViewStateOperation]) {
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
        self.nodes.insert(.Node(index: node.index!, frame: nodeFrame, referenceNode: nil), atIndex: insertionIndex)
        
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
    }
    
    mutating func removeNodeAtIndex(index: Int, animated: Bool, inout operations: [ListViewStateOperation]) {
        let node = self.nodes[index]
        if case let .Node(_, _, referenceNode) = node {
            let nodeFrame = node.frame
            self.nodes.removeAtIndex(index)
            operations.append(.Remove(index: index))
            
            if let referenceNode = referenceNode where animated {
                self.nodes.insert(.Placeholder(frame: nodeFrame), atIndex: index)
                operations.append(.InsertPlaceholder(index: index, referenceNode: referenceNode))
            } else {
                for i in index ..< self.nodes.count {
                    var frame = self.nodes[i].frame
                    frame.origin.y -= nodeFrame.size.height
                    self.nodes[i].frame = frame
                }
            }
        } else {
            assertionFailure()
        }
    }
}

private enum ListViewStateOperation {
    case InsertNode(index: Int, offsetDirection: ListViewInsertionOffsetDirection, node: ListViewItemNode, layout: ListViewItemNodeLayout, apply: () -> ())
    case InsertPlaceholder(index: Int, referenceNode: ListViewItemNode)
    case Remove(index: Int)
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
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.target?.touchesBegan(touches, withEvent: event)
    }
    
    override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        self.target?.touchesCancelled(touches, withEvent: event)
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.target?.touchesMoved(touches, withEvent: event)
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.target?.touchesEnded(touches, withEvent: event)
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
                self.enqueueUpdateVisibleItems()
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
    
    public final var visibleItemRangeChanged: ListViewVisibleRange? -> Void = { _ in }
    public final var visibleItemRange: ListViewVisibleRange?
    
    private final var animations: [ListViewAnimation] = []
    private final var actionsForVSync: [() -> ()] = []
    private final var inVSync = false
    
    private let frictionSlider = UISlider()
    private let springSlider = UISlider()
    private let freeResistanceSlider = UISlider()
    private let scrollingResistanceSlider = UISlider()
    
    //let performanceTracker: FBAnimationPerformanceTracker
    
    private var selectionTouchLocation: CGPoint?
    private var selectionTouchDelayTimer: NSTimer?
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
        }, didLoadBlock: nil)
        
        (self.view as! ListViewBackingView).target = self
        
        self.transactionQueue.transactionCompleted = { [weak self] in
            if let strongSelf = self {
                strongSelf.updateVisibleItemRange()
            }
        }
        
        //self.performanceTracker.delegate = self
        
        self.scroller.alwaysBounceVertical = true
        self.scroller.contentSize = CGSize(width: 0.0, height: infiniteScrollSize * 2.0)
        self.scroller.hidden = true
        self.scroller.delegate = self
        self.view.addSubview(self.scroller)
        self.scroller.panGestureRecognizer.cancelsTouchesInView = false
        self.view.addGestureRecognizer(self.scroller.panGestureRecognizer)
        
        self.displayLink = CADisplayLink(target: DisplayLinkProxy(target: self), selector: #selector(DisplayLinkProxy.displayLinkEvent))
        self.displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
        self.displayLink.paused = true
        
        if useDynamicTuning {
            self.frictionSlider.addTarget(self, action: #selector(self.frictionSliderChanged(_:)), forControlEvents: .ValueChanged)
            self.springSlider.addTarget(self, action: #selector(self.springSliderChanged(_:)), forControlEvents: .ValueChanged)
            self.freeResistanceSlider.addTarget(self, action: #selector(self.freeResistanceSliderChanged(_:)), forControlEvents: .ValueChanged)
            self.scrollingResistanceSlider.addTarget(self, action: #selector(self.scrollingResistanceSliderChanged(_:)), forControlEvents: .ValueChanged)
            
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
    }
    
    @objc func frictionSliderChanged(slider: UISlider) {
        testSpringFriction = CGFloat(slider.value)
        print("friction: \(testSpringFriction)")
    }
    
    @objc func springSliderChanged(slider: UISlider) {
        testSpringConstant = CGFloat(slider.value)
        print("spring: \(testSpringConstant)")
    }
    
    @objc func freeResistanceSliderChanged(slider: UISlider) {
        testSpringFreeResistance = CGFloat(slider.value)
        print("free resistance: \(testSpringFreeResistance)")
    }
    
    @objc func scrollingResistanceSliderChanged(slider: UISlider) {
        testSpringScrollingResistance = CGFloat(slider.value)
        print("free resistance: \(testSpringScrollingResistance)")
    }
    
    private func displayLinkEvent() {
        self.updateAnimations()
    }
    
    private func setNeedsAnimations() {
        if !self.needsAnimations {
            self.needsAnimations = true
            self.displayLink.paused = false
        }
    }
    
    private func pauseAnimations() {
        if self.needsAnimations {
            self.needsAnimations = false
            self.displayLink.paused = true
        }
    }
    
    private func dispatchOnVSync(forceNext: Bool = false, action: () -> ()) {
        Queue.mainQueue().dispatch {
            if !forceNext && self.inVSync {
                action()
            } else {
                self.actionsForVSync.append(action)
                self.setNeedsAnimations()
            }
        }
    }
    
    public func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        self.lastContentOffsetTimestamp = 0.0
        
        /*if usePerformanceTracker {
            self.performanceTracker.start()
        }*/
    }
    
    public func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate {
            self.lastContentOffsetTimestamp = CACurrentMediaTime()
        } else {
            self.lastContentOffsetTimestamp = 0.0
            /*if usePerformanceTracker {
                self.performanceTracker.stop()
            }*/
        }
    }
    
    public func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        self.lastContentOffsetTimestamp = 0.0
        /*if usePerformanceTracker {
            self.performanceTracker.stop()
        }*/
    }
    
    public func scrollViewDidScroll(scrollView: UIScrollView) {
        if self.ignoreScrollingEvents || scroller !== self.scroller {
            return
        }
            
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
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
        
        self.updateVisibleNodes()
        
        CATransaction.commit()
    }
    
    private func snapToBounds() {
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
            } else if topItemEdge > self.insets.top - overscroll {
                //offset = topItemEdge - (self.insets.top - overscroll)
            }
        } else if topItemFound {
            if topItemEdge > self.insets.top - overscroll {
                //offset = topItemEdge - (self.insets.top - overscroll)
            }
        } else if bottomItemFound {
            if bottomItemEdge < self.visibleSize.height - self.insets.bottom - overscroll {
                offset = self.visibleSize.height - self.insets.bottom - overscroll - bottomItemEdge
            }
        }
        
        if abs(offset) > CGFloat(FLT_EPSILON) {
            for itemNode in self.itemNodes {
                var position = itemNode.position
                position.y += offset
                itemNode.position = position
            }
        }
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
    
    private func nodeForItem(item: ListViewItem, previousNode: ListViewItemNode?, index: Int, previousItem: ListViewItem?, nextItem: ListViewItem?, width: CGFloat, completion: (ListViewItemNode, ListViewItemNodeLayout, () -> Void) -> Void) {
        if let previousNode = previousNode {
            item.updateNode(previousNode, width: width, previousItem: previousItem, nextItem: nextItem, completion: { (layout, apply) in
                previousNode.index = index
                completion(previousNode, layout, apply)
            })
        } else {
            let startTime = CACurrentMediaTime()
            item.nodeConfiguredForWidth(width, previousItem: previousItem, nextItem: nextItem, completion: { itemNode, apply in
                itemNode.index = index
                if self.debugInfo {
                    print("[ListView] nodeConfiguredForWidth \((CACurrentMediaTime() - startTime) * 1000.0) ms")
                }
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
        return ListViewState(insets: self.insets, visibleSize: self.visibleSize, invisibleInset: self.invisibleInset, nodes: nodes)
    }
    
    public func deleteAndInsertItems(deleteIndices: [Int], insertIndicesAndItems: [(Int, ListViewItem, Int?)], offsetTopInsertedItems: Bool, options: ListViewDeleteAndInsertOptions, completion: Void -> Void = {}) {
        if deleteIndices.count == 0 && insertIndicesAndItems.count == 0 {
            completion()
            return
        }
        
        self.transactionQueue.addTransaction({ [weak self] transactionCompletion in
            if let strongSelf = self {
                strongSelf.transactionOffset = 0.0
                strongSelf.deleteAndInsertItemsTransaction(deleteIndices, insertIndicesAndItems: insertIndicesAndItems, offsetTopInsertedItems: offsetTopInsertedItems, options: options, completion: {
                    completion()
                    
                    transactionCompletion()
                })
            }
        })
    }

    private func deleteAndInsertItemsTransaction(deleteIndices: [Int], insertIndicesAndItems: [(Int, ListViewItem, Int?)], offsetTopInsertedItems: Bool, options: ListViewDeleteAndInsertOptions, completion: Void -> Void) {
        var state = self.currentState()
        
        let sortedDeleteIndices = deleteIndices.sort()
        for index in sortedDeleteIndices.reverse() {
            self.items.removeAtIndex(index)
        }
        
        let sortedIndicesAndItems = insertIndicesAndItems.sort { $0.0 < $1.0 }
        if self.items.count == 0 {
            if sortedIndicesAndItems[0].0 != 0 {
                fatalError("deleteAndInsertItems: invalid insert into empty list")
            }
        }
        
        var previousNodes: [Int: ListViewItemNode] = [:]
        for (index, item, previousIndex) in sortedIndicesAndItems {
            self.items.insert(item, atIndex: index)
            if let previousIndex = previousIndex {
                for itemNode in self.itemNodes {
                    if itemNode.index == previousIndex {
                        previousNodes[index] = itemNode
                    }
                }
            }
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            var operations: [ListViewStateOperation] = []
            
            let deleteIndexSet = Set(deleteIndices)
            var insertedIndexSet = Set<Int>()
            var moveMapping: [Int: Int] = [:]
            for (index, _, previousIndex) in sortedIndicesAndItems {
                insertedIndexSet.insert(index)
                if let previousIndex = previousIndex {
                    moveMapping[previousIndex] = index
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
                        if deleteIndex < index {
                            indexOffset += 1
                        } else {
                            break
                        }
                    }
                    
                    if deleteIndexSet.contains(index) {
                        state.removeNodeAtIndex(i, animated: animated, operations: &operations)
                    } else {
                        let updatedIndex = index - indexOffset
                        remapDeletion[index] = updatedIndex
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
                operations.append(.Remap(remapDeletion))
            }
            
            var remapInsertion: [Int: Int] = [:]
            
            for i in 0 ..< state.nodes.count {
                if let index = state.nodes[i].index {
                    var indexOffset = 0
                    for (insertIndex, _, _) in sortedIndicesAndItems {
                        if insertIndex <= index + indexOffset {
                            indexOffset += 1
                        }
                    }
                    if indexOffset != 0 {
                        let updatedIndex = index + indexOffset
                        remapInsertion[index] = updatedIndex
                        switch state.nodes[i] {
                            case let .Node(_, frame, referenceNode):
                                state.nodes[i] = .Node(index: updatedIndex, frame: frame, referenceNode: referenceNode)
                            case .Placeholder:
                                break
                        }
                    }
                }
            }
            
            for node in state.nodes {
                if let index = node.index {
                    if insertedIndexSet.contains(index - 1) || insertedIndexSet.contains(index + 1) {
                        updateAdjacentItemsIndices.insert(index)
                    }
                }
            }
            
            if !remapInsertion.isEmpty {
                operations.append(.Remap(remapInsertion))
            }
            
            let startTime = CACurrentMediaTime()
            
            self.fillMissingNodes(animated, offsetTopInsertedItems: offsetTopInsertedItems, animatedInsertIndices: animated ? insertedIndexSet : Set<Int>(), state: state, previousNodes: previousNodes, operations: operations, completion: { updatedState, operations in
                
                var fixedUpdateAdjacentItemsIndices = updateAdjacentItemsIndices
                let maxIndex = updatedState.nodes.count - 1
                for nodeIndex in updateAdjacentItemsIndices {
                    if nodeIndex < 0 || nodeIndex > maxIndex {
                        fixedUpdateAdjacentItemsIndices.remove(nodeIndex)
                    }
                }
                
                if self.debugInfo {
                    print("fillMissingNodes completion \((CACurrentMediaTime() - startTime) * 1000.0) ms")
                }
                self.updateAdjacent(animated, state: updatedState, updateAdjacentItemsIndices: fixedUpdateAdjacentItemsIndices, operations: operations, completion: { operations in
                    if self.debugInfo {
                        print("updateAdjacent completion \((CACurrentMediaTime() - startTime) * 1000.0) ms")
                    }
                    
                    let next = {
                        self.replayOperations(animated, operations: operations, completion: completion)
                    }
                    
                    self.dispatchOnVSync {
                        next()
                    }
                })
            })
        })
    }
    
    private func updateAdjacent(animated: Bool, state: ListViewState, updateAdjacentItemsIndices: Set<Int>, operations: [ListViewStateOperation], completion: [ListViewStateOperation] -> Void) {
        if updateAdjacentItemsIndices.isEmpty {
            completion(operations)
        } else {
            var updatedUpdateAdjacentItemsIndices = updateAdjacentItemsIndices
            
            let nodeIndex = updateAdjacentItemsIndices.first!
            updatedUpdateAdjacentItemsIndices.remove(nodeIndex)

            var actualIndex = nodeIndex
            /*for node in state.nodes {
                if case let .Node(index, _, _) = node where index == nodeIndex {
                    break
                }
                actualIndex += 1
            }*/
            
            var continueWithoutNode = true
            
            if actualIndex < state.nodes.count {
                if case let .Node(index, _, referenceNode) = state.nodes[actualIndex] {
                    if let referenceNode = referenceNode {
                        continueWithoutNode = false
                        self.items[index].updateNode(referenceNode, width: state.visibleSize.width, previousItem: index == 0 ? nil : self.items[index - 1], nextItem: index == self.items.count - 1 ? nil : self.items[index + 1], completion: { layout, apply in
                            var updatedState = state
                            var updatedOperations = operations
                            
                            for i in nodeIndex + 1 ..< updatedState.nodes.count {
                                let frame = updatedState.nodes[i].frame
                                updatedState.nodes[i].frame = frame.offsetBy(dx: 0.0, dy: frame.size.height)
                                updatedOperations.append(.UpdateLayout(index: nodeIndex, layout: layout, apply: apply))
                            }
                            
                            self.updateAdjacent(animated, state: updatedState, updateAdjacentItemsIndices: updatedUpdateAdjacentItemsIndices, operations: updatedOperations, completion: completion)
                        })
                    }
                }
            }
            
            if continueWithoutNode {
                updateAdjacent(animated, state: state, updateAdjacentItemsIndices: updatedUpdateAdjacentItemsIndices, operations: operations, completion: completion)
            }
        }
    }
    
    private func fillMissingNodes(animated: Bool, offsetTopInsertedItems: Bool, animatedInsertIndices: Set<Int>, state: ListViewState, previousNodes: [Int: ListViewItemNode], operations: [ListViewStateOperation], completion: (ListViewState, [ListViewStateOperation]) -> Void) {
        if self.items.count == 0 {
            completion(state, operations)
        } else {
            var insertionItemIndexAndDirection: (Int, ListViewInsertionOffsetDirection)?
            
            if state.nodes.count == 0 {
                insertionItemIndexAndDirection = (0, .Down)
            } else {
                var previousIndex: Int?
                for node in state.nodes {
                    if let index = node.index {
                        if let previousIndex = previousIndex {
                            if previousIndex + 1 != index {
                                if state.nodeInsertionPointAndIndex(index - 1).0.y < state.insets.top {
                                    insertionItemIndexAndDirection = (index - 1, .Up)
                                } else {
                                    insertionItemIndexAndDirection = (previousIndex + 1, .Down)
                                }
                                break
                            }
                        } else if index != 0 {
                            let insertionPoint = state.nodeInsertionPointAndIndex(index - 1).0
                            if insertionPoint.y >= -state.invisibleInset {
                                if !offsetTopInsertedItems || insertionPoint.y < state.insets.top {
                                    insertionItemIndexAndDirection = (index - 1, .Up)
                                } else {
                                    insertionItemIndexAndDirection = (0, .Down)
                                }
                                break
                            }
                        }
                        previousIndex = index
                    }
                }
                if let previousIndex = previousIndex where insertionItemIndexAndDirection == nil && previousIndex != self.items.count - 1 {
                    let insertionPoint = state.nodeInsertionPointAndIndex(previousIndex + 1).0
                    if insertionPoint.y < state.visibleSize.height + state.invisibleInset {
                        insertionItemIndexAndDirection = (previousIndex + 1, .Down)
                    }
                }
            }
            
            if let insertionItemIndexAndDirection = insertionItemIndexAndDirection {
                let index = insertionItemIndexAndDirection.0
                self.nodeForItem(self.items[index], previousNode: previousNodes[index], index: index, previousItem: index == 0 ? nil : self.items[index - 1], nextItem: self.items.count == index + 1 ? nil : self.items[index + 1], width: state.visibleSize.width, completion: { (node, layout, apply) in
                    var updatedState = state
                    var updatedOperations = operations
                    updatedState.insertNode(index, node: node, layout: layout, apply: apply, offsetDirection: insertionItemIndexAndDirection.1, animated: animated && animatedInsertIndices.contains(index), operations: &updatedOperations)
                    
                    self.fillMissingNodes(animated, offsetTopInsertedItems: offsetTopInsertedItems, animatedInsertIndices: animatedInsertIndices, state: updatedState, previousNodes: previousNodes, operations: updatedOperations, completion: completion)
                })
            } else {
                completion(state, operations)
            }
        }
    }
    
    private func referencePointForInsertionAtIndex(nodeIndex: Int) -> CGPoint {
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
    
    private func updateVisibleNodes() {
        /*let visibleRect = CGRect(origin: CGPoint(x: 0.0, y: -10.0), size: CGSize(width: self.visibleSize.width, height: self.visibleSize.height + 20))
        for itemNode in self.itemNodes {
            if CGRectIntersectsRect(itemNode.apparentFrame, visibleRect) {
                if useDynamicTuning {
                    self.insertSubnode(itemNode, atIndex: 0)
                } else {
                    self.addSubnode(itemNode)
                }
            } else if itemNode.supernode != nil {
                itemNode.removeFromSupernode()
            }
        }*/
    }
    
    private func insertNodeAtIndex(animated: Bool, previousFrame: CGRect?, nodeIndex: Int, offsetDirection: ListViewInsertionOffsetDirection, node: ListViewItemNode, layout: ListViewItemNodeLayout, apply: () -> (), timestamp: Double) {
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
        
        node.contentSize = layout.contentSize
        node.insets = layout.insets
        node.apparentHeight = animated ? 0.0 : layout.size.height
        node.frame = nodeFrame
        apply()
        self.itemNodes.insert(node, atIndex: nodeIndex)
        
        if useDynamicTuning {
            self.insertSubnode(node, atIndex: 0)
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
                    if let animation = node.animationForKey("apparentHeight") where abs(animation.to as! CGFloat - layout.size.height) < CGFloat(FLT_EPSILON) {
                        node.apparentHeight = previousApparentHeight
                        
                        offsetHeight = 0.0
                        
                        var offsetPosition = nextNode.position
                        offsetPosition.y += nextHeight
                        nextNode.position = offsetPosition
                        nextNode.apparentHeight = 0.0
                        
                        nextNode.removeApparentHeightAnimation()
                        
                        takenAnimation = true
                    }
                }
            }
        }
        
        if node.index == nil {
            node.addApparentHeightAnimation(0.0, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp)
        } else if animated {
            if !takenAnimation {
                node.addApparentHeightAnimation(nodeFrame.size.height, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp)
            
                if let previousFrame = previousFrame {
                    node.transitionOffset += nodeFrame.origin.y - previousFrame.origin.y
                    node.addTransitionOffsetAnimation(0.0, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp)
                    if previousInsets != layout.insets {
                        node.insets = previousInsets
                        node.addInsetsAnimationToValue(layout.insets, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp)
                    }
                } else {
                    node.animateInsertion(timestamp, duration: insertionAnimationDuration * UIView.animationDurationFactor())
                }
            }
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
    
    private func replayOperations(animated: Bool, operations: [ListViewStateOperation], completion: () -> Void) {
        let timestamp = CACurrentMediaTime()
        
        var previousApparentFrames: [(ListViewItemNode, CGRect)] = []
        for itemNode in self.itemNodes {
            previousApparentFrames.append((itemNode, itemNode.apparentFrame))
        }
        var insertedNodes: [ASDisplayNode] = []
        
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
                    self.insertNodeAtIndex(animated, previousFrame: previousFrame, nodeIndex: index, offsetDirection: offsetDirection, node: node, layout: layout, apply: apply, timestamp: timestamp)
                    insertedNodes.append(node)
                case let .InsertPlaceholder(index, referenceNode):
                    var height: CGFloat?
                    
                    for (node, previousFrame) in previousApparentFrames {
                        if node === referenceNode {
                            height = previousFrame.size.height
                            break
                        }
                    }
                    
                    if let height = height {
                        self.insertNodeAtIndex(false, previousFrame: nil, nodeIndex: index, offsetDirection: .Down, node: ListViewItemNode(layerBacked: true), layout: ListViewItemNodeLayout(contentSize: CGSize(width: self.visibleSize.width, height: height), insets: UIEdgeInsets()), apply: { }, timestamp: timestamp)
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
                case let .Remove(index):
                    let height = self.itemNodes[index].apparentHeight
                    if index != self.itemNodes.count - 1 {
                        for i in index + 1 ..< self.itemNodes.count {
                            var frame = self.itemNodes[i].frame
                            frame.origin.y -= height
                            self.itemNodes[i].frame = frame
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
                            node.addApparentHeightAnimation(updatedApparentHeight, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp)
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
                            var position = itemNode.position
                            position.y += offset
                            itemNode.position = position
                        }
                        
                        index += 1
                    }
            }
        }
        
        self.insertNodesInBatches(insertedNodes, completion: {
            self.debugCheckMonotonity()
            self.removeInvisibleNodes()
            self.updateAccessoryNodes(animated, currentTimestamp: timestamp)
            self.snapToBounds()
            self.updateVisibleNodes()
            if animated {
                self.setNeedsAnimations()
            }
            
            completion()
        })
        
        /*let delta = CACurrentMediaTime() - timestamp
        if delta > 1.0 / 60.0 {
            print("replayOperations \(delta * 1000.0) ms \(nodeCreationDurations)")
        }*/
    }
    
    private func insertNodesInBatches(nodes: [ASDisplayNode], completion: () -> Void) {
        if nodes.count == 0 {
            completion()
        } else {
            for node in nodes {
                self.addSubnode(node)
            }
            completion()
            /*self.dispatchOnVSync(true, action: {
                self.addSubnode(nodes[0])
                var updatedNodes = nodes
                updatedNodes.removeAtIndex(0)
                self.insertNodesInBatches(updatedNodes, completion: completion)
            })*/
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
    
    private func removeItemNodeAtIndex(index: Int) {
        let node = self.itemNodes[index]
        self.itemNodes.removeAtIndex(index)
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
                                                
                                                nextAccessoryItemNode.animateTransitionOffset(CGPoint(x: 0.0, y: updatedAccessoryItemNodeOrigin.y - previousAccessoryItemNodeOrigin.y), beginAt: currentTimestamp, duration: insertionAnimationDuration * UIView.animationDurationFactor(), curve: listViewAnimationCurveSystem)
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
                    strongSelf.updateVisibleItemsTransaction({
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
    
    private func updateVisibleItemsTransaction(completion: Void -> Void) {
        var i = 0
        while i < self.itemNodes.count {
            let node = self.itemNodes[i]
            if node.index == nil && node.apparentHeight <= CGFloat(FLT_EPSILON) {
                self.removeItemNodeAtIndex(i)
            } else {
                i += 1
            }
        }
        
        self.fillMissingNodes(false, offsetTopInsertedItems: false, animatedInsertIndices: [], state: self.currentState(), previousNodes: [:], operations: []) { _, operations in
            self.dispatchOnVSync {
                self.replayOperations(false, operations: operations, completion: completion)
            }
        }
    }
    
    private func removeInvisibleNodes() {
        var i = 0
        var visibleItemNodeHeight: CGFloat = 0.0
        while i < self.itemNodes.count {
            visibleItemNodeHeight += self.itemNodes[i].apparentBounds.height
            i += 1
        }
        
        if visibleItemNodeHeight > (self.visibleSize.height + self.invisibleInset + self.invisibleInset) {
            i = self.itemNodes.count - 1
            while i >= 0 {
                let itemNode = self.itemNodes[i]
                let apparentFrame = itemNode.apparentFrame
                if apparentFrame.maxY < -self.invisibleInset || apparentFrame.origin.y > self.visibleSize.height + self.invisibleInset {
                    self.removeItemNodeAtIndex(i)
                }
                i -= 1
            }
        }
    }
    
    private func updateVisibleItemRange(force: Bool = false) {
        let currentRange: ListViewVisibleRange?
        if self.itemNodes.count != 0 {
            var firstIndex: Int?
            var lastIndex: Int?
            var i = 0
            while i < self.itemNodes.count {
                if let index = self.itemNodes[i].index {
                    firstIndex = index
                    break
                }
                i += 1
            }
            i = self.itemNodes.count - 1
            while i >= 0 {
                if let index = self.itemNodes[i].index {
                    lastIndex = index
                    break
                }
                i -= 1
            }
            if let firstIndex = firstIndex, lastIndex = lastIndex {
                currentRange = ListViewVisibleRange(firstIndex: firstIndex, lastIndex: lastIndex)
            } else {
                currentRange = nil
            }
        } else {
            currentRange = nil
        }
        
        if currentRange != self.visibleItemRange || force {
            self.visibleItemRange = currentRange
            self.visibleItemRangeChanged(currentRange)
        }
    }
    
    public func updateSizeAndInsets(size: CGSize, insets: UIEdgeInsets, duration: Double = 0.0, options: UIViewAnimationOptions = UIViewAnimationOptions()) {
        self.transactionQueue.addTransaction({ [weak self] completion in
            if let strongSelf = self {
                strongSelf.transactionOffset = 0.0
                strongSelf.updateSizeAndInsetsTransaction(size, insets: insets, duration: duration, options: options, completion: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.transactionOffset = 0.0
                        strongSelf.updateVisibleItemsTransaction(completion)
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
    
    private func updateSizeAndInsetsTransaction(size: CGSize, insets: UIEdgeInsets, duration: Double, options: UIViewAnimationOptions, completion: Void -> Void) {
        if CGSizeEqualToSize(size, self.visibleSize) && UIEdgeInsetsEqualToEdgeInsets(self.insets, insets) {
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
            self.scroller.contentSize = CGSizeMake(size.width, infiniteScrollSize * 2.0)
            self.lastContentOffset = CGPointMake(0.0, infiniteScrollSize)
            self.scroller.contentOffset = self.lastContentOffset
            
            self.updateScroller()
            self.updateVisibleItemRange()
            
            let completion = { [weak self] (_: Bool) -> Void in
                if let strongSelf = self {
                    strongSelf.updateVisibleItemsTransaction(completion)
                    strongSelf.ignoreScrollingEvents = false
                }
            }
            
            if duration > DBL_EPSILON {
                let animation: CABasicAnimation
                if (options.rawValue & UInt(7 << 16)) != 0 {
                    let springAnimation = CASpringAnimation(keyPath: "sublayerTransform")
                    springAnimation.mass = 3.0
                    springAnimation.stiffness = 1000.0
                    springAnimation.damping = 500.0
                    springAnimation.initialVelocity = 0.0
                    springAnimation.duration = duration * UIView.animationDurationFactor()
                    springAnimation.fromValue = NSValue(CATransform3D: CATransform3DMakeTranslation(0.0, -completeOffset, 0.0))
                    springAnimation.toValue = NSValue(CATransform3D: CATransform3DIdentity)
                    springAnimation.removedOnCompletion = true
                    animation = springAnimation
                } else {
                    let basicAnimation = CABasicAnimation(keyPath: "sublayerTransform")
                    basicAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
                    basicAnimation.duration = duration * UIView.animationDurationFactor()
                    basicAnimation.fromValue = NSValue(CATransform3D: CATransform3DMakeTranslation(0.0, -completeOffset, 0.0))
                    basicAnimation.toValue = NSValue(CATransform3D: CATransform3DIdentity)
                    basicAnimation.removedOnCompletion = true
                    animation = basicAnimation
                }
                
                animation.completion = completion
                self.layer.addAnimation(animation, forKey: "sublayerTransform")
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
                animations.removeAtIndex(i)
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
            self.updateVisibleNodes()
            self.enqueueUpdateVisibleItems()
        }
    }
    
    override public func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.isTracking = true
        self.touchesPosition = (touches.first!).locationInView(self.view)
        self.selectionTouchLocation = self.touchesPosition
        
        self.selectionTouchDelayTimer?.invalidate()
        let timer = NSTimer(timeInterval: 0.08, target: ListViewTimerProxy { [weak self] in
            if let strongSelf = self where strongSelf.selectionTouchLocation != nil {
                strongSelf.clearHighlightAnimated(false)
                let index = strongSelf.itemIndexAtPoint(strongSelf.touchesPosition)
                
                if let index = index {
                    if strongSelf.items[index].selectable {
                        strongSelf.highlightedItemIndex = index
                        for itemNode in strongSelf.itemNodes {
                            if itemNode.index == index {
                                if !itemNode.layerBacked {
                                    strongSelf.view.bringSubviewToFront(itemNode.view)
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
        NSRunLoop.mainRunLoop().addTimer(timer, forMode: NSRunLoopCommonModes)
        
        super.touchesBegan(touches, withEvent: event)
        
        self.updateScroller()
    }
    
    public func clearHighlightAnimated(animated: Bool) {
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
    
    private func itemIndexAtPoint(point: CGPoint) -> Int? {
        for itemNode in self.itemNodes {
            if itemNode.apparentFrame.contains(point) {
                return itemNode.index
            }
        }
        return nil
    }
    
    override public func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.touchesPosition = touches.first!.locationInView(self.view)
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
        
        super.touchesMoved(touches, withEvent: event)
    }
    
    override public func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
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
                            if !itemNode.layerBacked {
                                self.view.bringSubviewToFront(itemNode.view)
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
        
        super.touchesEnded(touches, withEvent: event)
    }
    
    override public func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        self.isTracking = false
        
        self.selectionTouchLocation = nil
        self.selectionTouchDelayTimer?.invalidate()
        self.selectionTouchDelayTimer = nil
        self.clearHighlightAnimated(false)
        
        super.touchesCancelled(touches, withEvent: event)
    }
}
