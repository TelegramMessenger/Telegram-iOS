import UIKit
import AsyncDisplayKit
import SwiftSignalKit

private let usePerformanceTracker = false
private let useDynamicTuning = false

private let infiniteScrollSize: CGFloat = 10000.0
private let insertionAnimationDuration: Double = 0.4

private final class ListViewBackingLayer: CALayer {
    override func setNeedsLayout() {
    }
    
    override func layoutSublayers() {
    }
}

final class ListViewBackingView: UIView {
    weak var target: ListView?
    
    override class var layerClass: AnyClass {
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
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let target = target, target.limitHitTestToNodes {
            if !target.internalHitTest(point, with: event) {
                return nil
            }
        }
        return super.hitTest(point, with: event)
    }
}

private final class ListViewTimerProxy: NSObject {
    private let action: () -> ()
    
    init(_ action: @escaping () -> ()) {
        self.action = action
        super.init()
    }
    
    @objc func timerEvent() {
        self.action()
    }
}

public enum ListViewVisibleContentOffset {
    case known(CGFloat)
    case unknown
    case none
}

open class ListView: ASDisplayNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
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
    
    public final var stackFromBottom: Bool = false
    public final var stackFromBottomInsetItemFactor: CGFloat = 0.0
    public final var limitHitTestToNodes: Bool = false
    public final var keepBottomItemOverscrollBackground: Bool = false
    
    private var bottomItemOverscrollBackground: ASDisplayNode?
    
    private var touchesPosition = CGPoint()
    private var isTracking = false
    private var isDeceleratingAfterTracking = false
    
    private final var transactionQueue: ListViewTransactionQueue
    private final var transactionOffset: CGFloat = 0.0
    
    private final var enqueuedUpdateVisibleItems = false
    
    private final var createdItemNodes = 0
    
    public final var synchronousNodes = false
    public final var debugInfo = false
    
    private final var items: [ListViewItem] = []
    private final var itemNodes: [ListViewItemNode] = []
    private final var itemHeaderNodes: [Int64: ListViewItemHeaderNode] = [:]
    
    public final var displayedItemRangeChanged: (ListViewDisplayedItemRange, Any?) -> Void = { _, _ in }
    public private(set) final var displayedItemRange: ListViewDisplayedItemRange = ListViewDisplayedItemRange(loadedRange: nil, visibleRange: nil)
    
    private final var opaqueTransactionState: Any?
    
    public final var visibleContentOffsetChanged: (ListViewVisibleContentOffset) -> Void = { _ in }
    
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
    private var flashNodesDelayTimer: Foundation.Timer?
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
        
        self.clipsToBounds = true
        
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
        self.scroller.panGestureRecognizer.cancelsTouchesInView = true
        self.view.addGestureRecognizer(self.scroller.panGestureRecognizer)
        
        let trackingRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.trackingGesture(_:)))
        trackingRecognizer.delegate = self
        self.view.addGestureRecognizer(trackingRecognizer)
        
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
    
    private func dispatchOnVSync(forceNext: Bool = false, action: @escaping () -> ()) {
        Queue.mainQueue().async {
            if !forceNext && self.inVSync {
                action()
            } else {
                action()
                //self.actionsForVSync.append(action)
                //self.setNeedsAnimations()
            }
        }
    }
    
    private func resetHeaderItemsFlashTimer(start: Bool) {
        if let flashNodesDelayTimer = self.flashNodesDelayTimer {
            flashNodesDelayTimer.invalidate()
            self.flashNodesDelayTimer = nil
        }
        
        if start {
            let timer = Timer(timeInterval: 0.3, target: ListViewTimerProxy { [weak self] in
                if let strongSelf = self {
                    if let flashNodesDelayTimer = strongSelf.flashNodesDelayTimer {
                        flashNodesDelayTimer.invalidate()
                        strongSelf.flashNodesDelayTimer = nil
                        strongSelf.updateHeaderItemsFlashing(animated: true)
                    }
                }
            }, selector: #selector(ListViewTimerProxy.timerEvent), userInfo: nil, repeats: false)
            self.flashNodesDelayTimer = timer
            RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
            self.updateHeaderItemsFlashing(animated: true)
        }
    }
    
    private func headerItemsAreFlashing() -> Bool {
        //print("\(self.scroller.isDragging) || (\(self.scroller.isDecelerating) && \(self.isDeceleratingAfterTracking)) || \(self.flashNodesDelayTimer != nil)")
        return self.scroller.isDragging || (self.isDeceleratingAfterTracking) || self.flashNodesDelayTimer != nil
    }
    
    private func updateHeaderItemsFlashing(animated: Bool) {
        let flashing = self.headerItemsAreFlashing()
        for (_, headerNode) in self.itemHeaderNodes {
            headerNode.updateFlashingOnScrolling(flashing, animated: animated)
        }
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.lastContentOffsetTimestamp = 0.0
        self.resetHeaderItemsFlashTimer(start: false)
        self.updateHeaderItemsFlashing(animated: true)
        
        /*if usePerformanceTracker {
            self.performanceTracker.start()
        }*/
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate {
            self.lastContentOffsetTimestamp = CACurrentMediaTime()
            self.isDeceleratingAfterTracking = true
            self.updateHeaderItemsFlashing(animated: true)
        } else {
            self.isDeceleratingAfterTracking = false
            self.resetHeaderItemsFlashTimer(start: true)
            self.updateHeaderItemsFlashing(animated: true)
            
            self.lastContentOffsetTimestamp = 0.0
            /*if usePerformanceTracker {
                self.performanceTracker.stop()
            }*/
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.lastContentOffsetTimestamp = 0.0
        self.isDeceleratingAfterTracking = false
        self.resetHeaderItemsFlashTimer(start: true)
        self.updateHeaderItemsFlashing(animated: true)
        
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
        
        self.transactionOffset += -deltaY
        
        self.enqueueUpdateVisibleItems()
        
        var useScrollDynamics = false
        
        let anchor: CGFloat
        if self.isTracking {
            anchor = self.touchesPosition.y
        } else if deltaY < 0.0 {
            anchor = self.visibleSize.height
        } else {
            anchor = 0.0
        }
        
        for itemNode in self.itemNodes {
            let position = itemNode.position
            itemNode.position = CGPoint(x: position.x, y: position.y - deltaY)
            
            if itemNode.wantsScrollDynamics {
                useScrollDynamics = true
                
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
        
        if !self.snapToBounds(snapTopItem: false, stackFromBottom: self.stackFromBottom).offset.isZero {
            self.updateVisibleContentOffset()
        }
        self.updateScroller()
        
        self.updateItemHeaders()
        
        for (headerId, headerNode) in self.itemHeaderNodes {
            //let position = headerNode.position
            //headerNode.position = CGPoint(x: position.x, y: position.y - deltaY)
            
            if headerNode.wantsScrollDynamics {
                useScrollDynamics = true
                
                var distance: CGFloat
                let itemFrame = headerNode.frame
                if anchor < itemFrame.origin.y {
                    distance = abs(itemFrame.origin.y - anchor)
                } else if anchor > itemFrame.origin.y + itemFrame.size.height {
                    distance = abs(anchor - (itemFrame.origin.y + itemFrame.size.height))
                } else {
                    distance = 0.0
                }
                
                let factor: CGFloat = max(0.08, abs(distance) / self.visibleSize.height)
                
                let resistance: CGFloat = testSpringFreeResistance
                
                headerNode.addScrollingOffset(deltaY * factor * resistance)
            }
        }
        
        if useScrollDynamics {
            self.setNeedsAnimations()
        }
        
        self.updateVisibleContentOffset()
        self.updateVisibleItemRange()
        
        //CATransaction.commit()
    }
    
    private func calculateAdditionalTopInverseInset() -> CGFloat {
        var additionalInverseTopInset: CGFloat = 0.0
        if !self.stackFromBottomInsetItemFactor.isZero {
            var remainingFactor = self.stackFromBottomInsetItemFactor
            for itemNode in self.itemNodes {
                if remainingFactor.isLessThanOrEqualTo(0.0) {
                    break
                }
                
                let itemFactor: CGFloat
                if CGFloat(1.0).isLessThanOrEqualTo(remainingFactor) {
                    itemFactor = 1.0
                } else {
                    itemFactor = remainingFactor
                }
                
                additionalInverseTopInset += floor(itemNode.apparentBounds.height * itemFactor)
                
                remainingFactor -= 1.0
            }
        }
        return additionalInverseTopInset
    }
    
    private func snapToBounds(snapTopItem: Bool, stackFromBottom: Bool) -> (snappedTopInset: CGFloat, offset: CGFloat) {
        if self.itemNodes.count == 0 {
            return (0.0, 0.0)
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
        
        for i in 0 ..< self.itemNodes.count {
            if let index = itemNodes[i].index {
                if index == 0 {
                    topItemFound = true
                }
                break
            }
        }
        
        var effectiveInsets = self.insets
        if topItemFound && !self.stackFromBottomInsetItemFactor.isZero {
            let additionalInverseTopInset = self.calculateAdditionalTopInverseInset()
            effectiveInsets.top = max(effectiveInsets.top, self.visibleSize.height - additionalInverseTopInset)
        }
        
        if topItemFound {
            topItemEdge = itemNodes[0].apparentFrame.origin.y
        }
        
        for i in (0 ..< self.itemNodes.count).reversed() {
            if let index = itemNodes[i].index {
                if index == self.items.count - 1 {
                    bottomItemFound = true
                }
                break
            }
        }
        
        if bottomItemFound {
            bottomItemEdge = itemNodes[itemNodes.count - 1].apparentFrame.maxY
        }
        
        if topItemFound && bottomItemFound {
            for itemNode in self.itemNodes {
                completeHeight += itemNode.apparentBounds.height
            }
        }
        
        var offset: CGFloat = 0.0
        if topItemFound && bottomItemFound {
            let visibleAreaHeight = self.visibleSize.height - effectiveInsets.bottom - effectiveInsets.top
            if self.stackFromBottom {
                if visibleAreaHeight > completeHeight {
                    let areaHeight = completeHeight
                    if topItemEdge < self.visibleSize.height - effectiveInsets.bottom - areaHeight - overscroll {
                        offset = self.visibleSize.height - effectiveInsets.bottom - areaHeight - overscroll - topItemEdge
                    } else if bottomItemEdge > self.visibleSize.height - effectiveInsets.bottom - overscroll {
                        offset = self.visibleSize.height - effectiveInsets.bottom - overscroll - bottomItemEdge
                    }
                } else {
                    let areaHeight = min(completeHeight, visibleAreaHeight)
                    if bottomItemEdge < effectiveInsets.top + areaHeight - overscroll {
                        offset = effectiveInsets.top + areaHeight - overscroll - bottomItemEdge
                    } else if topItemEdge > effectiveInsets.top - overscroll {
                        offset = (effectiveInsets.top - overscroll) - topItemEdge
                    }
                }
            } else {
                let areaHeight = min(completeHeight, visibleAreaHeight)
                if bottomItemEdge < effectiveInsets.top + areaHeight - overscroll {
                    offset = effectiveInsets.top + areaHeight - overscroll - bottomItemEdge
                } else if topItemEdge > effectiveInsets.top - overscroll && /*snapTopItem*/ true {
                    offset = (effectiveInsets.top - overscroll) - topItemEdge
                }
            }
        } else if topItemFound {
            if topItemEdge > effectiveInsets.top - overscroll && /*snapTopItem*/ true {
                offset = (effectiveInsets.top - overscroll) - topItemEdge
            }
        } else if bottomItemFound {
            if bottomItemEdge < self.visibleSize.height - effectiveInsets.bottom - overscroll {
                offset = self.visibleSize.height - effectiveInsets.bottom - overscroll - bottomItemEdge
            }
        }
        
        if abs(offset) > CGFloat(FLT_EPSILON) {
            for itemNode in self.itemNodes {
                var frame = itemNode.frame
                frame.origin.y += offset
                itemNode.frame = frame
            }
        }
        
        var snappedTopInset: CGFloat = 0.0
        if !self.stackFromBottomInsetItemFactor.isZero && topItemFound {
            snappedTopInset = max(0.0, (effectiveInsets.top - self.insets.top) - (topItemEdge + offset))
        }
        
        return (snappedTopInset, offset)
    }
    
    private func updateVisibleContentOffset() {
        var offset: ListViewVisibleContentOffset = .unknown
        var topItemIndexAndFrame: (Int, CGRect) = (-1, CGRect())
        for itemNode in self.itemNodes {
            if let index = itemNode.index {
                topItemIndexAndFrame = (index, itemNode.apparentFrame)
                break
            }
        }
        if topItemIndexAndFrame.0 == 0 {
            offset = .known(-(topItemIndexAndFrame.1.minY - self.insets.top))
        } else if topItemIndexAndFrame.0 == -1 {
            offset = .none
        }
        
        self.visibleContentOffsetChanged(offset)
    }
    
    private func stopScrolling() {
        let wasIgnoringScrollingEvents = self.ignoreScrollingEvents
        self.ignoreScrollingEvents = true
        self.scroller.setContentOffset(self.scroller.contentOffset, animated: false)
        self.ignoreScrollingEvents = wasIgnoringScrollingEvents
    }
    
    private func updateBottomItemOverscrollBackground() {
        if self.keepBottomItemOverscrollBackground {
            var bottomItemFound = false
            if self.itemNodes[itemNodes.count - 1].index == self.items.count - 1 {
                bottomItemFound = true
            }
            
            let bottomItemOverscrollBackground: ASDisplayNode
            if let currentBottomItemOverscrollBackground = self.bottomItemOverscrollBackground {
                bottomItemOverscrollBackground = currentBottomItemOverscrollBackground
            } else {
                bottomItemOverscrollBackground = ASDisplayNode()
                bottomItemOverscrollBackground.backgroundColor = .white
                bottomItemOverscrollBackground.isLayerBacked = true
                self.insertSubnode(bottomItemOverscrollBackground, at: 0)
                self.bottomItemOverscrollBackground = bottomItemOverscrollBackground
            }
            
            if bottomItemFound {
                let realBottomItemEdge = itemNodes.last!.apparentFrame.origin.y
                let realBottomItemEdgeOffset = max(0.0, self.visibleSize.height - realBottomItemEdge)
                let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: self.visibleSize.height - realBottomItemEdgeOffset), size: CGSize(width: self.visibleSize.width, height: self.visibleSize.height))
                if !backgroundFrame.equalTo(bottomItemOverscrollBackground.frame) {
                    bottomItemOverscrollBackground.frame = backgroundFrame
                }
            } else {
                let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: self.visibleSize.height), size: CGSize(width: self.visibleSize.width, height: self.visibleSize.height))
                if !backgroundFrame.equalTo(bottomItemOverscrollBackground.frame) {
                    bottomItemOverscrollBackground.frame = backgroundFrame
                }
            }
        }
    }
    
    private func updateScroller() {
        if itemNodes.count == 0 {
            return
        }
        
        var topItemFound = false
        var bottomItemFound = false
        var topItemEdge: CGFloat = 0.0
        var bottomItemEdge: CGFloat = 0.0
        
        for i in 0 ..< self.itemNodes.count {
            if let index = itemNodes[i].index {
                if index == 0 {
                    topItemFound = true
                    topItemEdge = itemNodes[0].apparentFrame.origin.y
                    break
                }
            }
        }
        
        var effectiveInsets = self.insets
        if topItemFound && !self.stackFromBottomInsetItemFactor.isZero {
            let additionalInverseTopInset = self.calculateAdditionalTopInverseInset()
            effectiveInsets.top = max(effectiveInsets.top, self.visibleSize.height - additionalInverseTopInset)
        }
        
        var completeHeight = effectiveInsets.top + effectiveInsets.bottom
        
        if itemNodes[itemNodes.count - 1].index == self.items.count - 1 {
            bottomItemFound = true
            bottomItemEdge = itemNodes[itemNodes.count - 1].apparentFrame.maxY
        }
        
        topItemEdge -= effectiveInsets.top
        bottomItemEdge += effectiveInsets.bottom
        
        if topItemFound && bottomItemFound {
            for itemNode in self.itemNodes {
                completeHeight += itemNode.apparentBounds.height
            }
            
            if self.stackFromBottom {
                let updatedCompleteHeight = max(completeHeight, self.visibleSize.height)
                let deltaCompleteHeight = updatedCompleteHeight - completeHeight
                topItemEdge -= deltaCompleteHeight
                bottomItemEdge -= deltaCompleteHeight
                completeHeight = updatedCompleteHeight
            }
        }
        
        self.updateBottomItemOverscrollBackground()
        
        let wasIgnoringScrollingEvents = self.ignoreScrollingEvents
        self.ignoreScrollingEvents = true
        if topItemFound && bottomItemFound {
            if self.stackFromBottom {
                self.lastContentOffset = CGPoint(x: 0.0, y: -topItemEdge)
            } else {
                self.lastContentOffset = CGPoint(x: 0.0, y: -topItemEdge)
            }
            self.scroller.contentSize = CGSize(width: self.visibleSize.width, height: completeHeight)
            self.scroller.contentOffset = self.lastContentOffset
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
        self.ignoreScrollingEvents = wasIgnoringScrollingEvents
    }
    
    private func async(_ f: @escaping () -> Void) {
        DispatchQueue.global().async(execute: f)
    }
    
    private func nodeForItem(synchronous: Bool, item: ListViewItem, previousNode: ListViewItemNode?, index: Int, previousItem: ListViewItem?, nextItem: ListViewItem?, width: CGFloat, updateAnimation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNode, ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
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
        return ListViewState(insets: self.insets, visibleSize: self.visibleSize, invisibleInset: self.invisibleInset, nodes: nodes, scrollPosition: nil, stationaryOffset: nil, stackFromBottom: self.stackFromBottom)
    }
    
    public func transaction(deleteIndices: [ListViewDeleteItem], insertIndicesAndItems: [ListViewInsertItem], updateIndicesAndItems: [ListViewUpdateItem], options: ListViewDeleteAndInsertOptions, scrollToItem: ListViewScrollToItem? = nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets? = nil, stationaryItemRange: (Int, Int)? = nil, updateOpaqueState: Any?, completion: @escaping (ListViewDisplayedItemRange) -> Void = { _ in }) {
        if deleteIndices.isEmpty && insertIndicesAndItems.isEmpty && updateIndicesAndItems.isEmpty && scrollToItem == nil && updateSizeAndInsets == nil {
            completion(self.immediateDisplayedItemRange())
            return
        }
        
        self.transactionQueue.addTransaction({ [weak self] transactionCompletion in
            if let strongSelf = self {
                strongSelf.transactionOffset = 0.0
                strongSelf.deleteAndInsertItemsTransaction(deleteIndices: deleteIndices, insertIndicesAndItems: insertIndicesAndItems, updateIndicesAndItems: updateIndicesAndItems, options: options, scrollToItem: scrollToItem, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: stationaryItemRange, updateOpaqueState: updateOpaqueState, completion: { [weak strongSelf] in
                    completion(strongSelf?.immediateDisplayedItemRange() ?? ListViewDisplayedItemRange(loadedRange: nil, visibleRange: nil))
                    
                    transactionCompletion()
                })
            }
        })
    }

    private func deleteAndInsertItemsTransaction(deleteIndices: [ListViewDeleteItem], insertIndicesAndItems: [ListViewInsertItem], updateIndicesAndItems: [ListViewUpdateItem], options: ListViewDeleteAndInsertOptions, scrollToItem: ListViewScrollToItem?, updateSizeAndInsets: ListViewUpdateSizeAndInsets?, stationaryItemRange: (Int, Int)?, updateOpaqueState: Any?, completion: @escaping (Void) -> Void) {
        if deleteIndices.isEmpty && insertIndicesAndItems.isEmpty && updateIndicesAndItems.isEmpty && scrollToItem == nil {
            if let updateSizeAndInsets = updateSizeAndInsets , (self.items.count == 0 || (updateSizeAndInsets.size == self.visibleSize && updateSizeAndInsets.insets == self.insets)) {
                self.visibleSize = updateSizeAndInsets.size
                self.insets = updateSizeAndInsets.insets
                
                if useDynamicTuning {
                    let size = updateSizeAndInsets.size
                    self.frictionSlider.frame = CGRect(x: 10.0, y: size.height - insets.bottom - 10.0 - self.frictionSlider.bounds.height, width: size.width - 20.0, height: self.frictionSlider.bounds.height)
                    self.springSlider.frame = CGRect(x: 10.0, y: self.frictionSlider.frame.minY - self.springSlider.bounds.height, width: size.width - 20.0, height: self.springSlider.bounds.height)
                    self.freeResistanceSlider.frame = CGRect(x: 10.0, y: self.springSlider.frame.minY - self.freeResistanceSlider.bounds.height, width: size.width - 20.0, height: self.freeResistanceSlider.bounds.height)
                    self.scrollingResistanceSlider.frame = CGRect(x: 10.0, y: self.freeResistanceSlider.frame.minY - self.scrollingResistanceSlider.bounds.height, width: size.width - 20.0, height: self.scrollingResistanceSlider.bounds.height)
                }
                
                let wasIgnoringScrollingEvents = self.ignoreScrollingEvents
                self.ignoreScrollingEvents = true
                self.scroller.frame = CGRect(origin: CGPoint(), size: updateSizeAndInsets.size)
                self.scroller.contentSize = CGSize(width: updateSizeAndInsets.size.width, height: infiniteScrollSize * 2.0)
                self.lastContentOffset = CGPoint(x: 0.0, y: infiniteScrollSize)
                self.scroller.contentOffset = self.lastContentOffset
                self.ignoreScrollingEvents = wasIgnoringScrollingEvents
                
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
        
        let sortedDeleteIndices = deleteIndices.sorted(by: {$0.index < $1.index})
        for deleteItem in sortedDeleteIndices.reversed() {
            self.items.remove(at: deleteItem.index)
        }
        
        let sortedIndicesAndItems = insertIndicesAndItems.sorted(by: { $0.index < $1.index })
        if self.items.count == 0 && !sortedIndicesAndItems.isEmpty {
            if sortedIndicesAndItems[0].index != 0 {
                fatalError("deleteAndInsertItems: invalid insert into empty list")
            }
        }
        
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
                if itemNode.index == updatedItem.previousIndex {
                    previousNodes[updatedItem.index] = itemNode
                    break
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
                            self.replayOperations(animated: animated, animateAlpha: options.contains(.AnimateAlpha), animateTopItemVerticalOrigin: options.contains(.AnimateTopItemPosition), operations: updatedOperations, requestItemInsertionAnimationsIndices: options.contains(.RequestItemInsertionAnimations) ? insertedIndexSet : Set(), scrollToItem: scrollToItem, updateSizeAndInsets: updateSizeAndInsets, stationaryItemIndex: stationaryItemIndex, updateOpaqueState: updateOpaqueState, completion: completion)
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
    
    private func updateAdjacent(synchronous: Bool, animated: Bool, state: ListViewState, updateAdjacentItemsIndices: Set<Int>, operations: [ListViewStateOperation], completion: @escaping (ListViewState, [ListViewStateOperation]) -> Void) {
        if updateAdjacentItemsIndices.isEmpty {
            completion(state, operations)
        } else {
            var updatedUpdateAdjacentItemsIndices = updateAdjacentItemsIndices
            
            let nodeIndex = updateAdjacentItemsIndices.first!
            updatedUpdateAdjacentItemsIndices.remove(nodeIndex)
            
            var continueWithoutNode = true
            
            var i = 0
            for node in state.nodes {
                if case let .Node(index, _, referenceNode) = node , index == nodeIndex {
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
                            
                            let heightDelta = layout.size.height - updatedState.nodes[i].frame.size.height
                            
                            updatedOperations.append(.UpdateLayout(index: i, layout: layout, apply: apply))
                            
                            if !animated {
                                let previousFrame = updatedState.nodes[i].frame
                                updatedState.nodes[i].frame = CGRect(origin: previousFrame.origin, size: layout.size)
                                if previousFrame.minY < updatedState.insets.top {
                                    for j in 0 ... i {
                                        updatedState.nodes[j].frame = updatedState.nodes[j].frame.offsetBy(dx: 0.0, dy: -heightDelta)
                                    }
                                } else {
                                    if i != updatedState.nodes.count {
                                        for j in i + 1 ..< updatedState.nodes.count {
                                            updatedState.nodes[j].frame = updatedState.nodes[j].frame.offsetBy(dx: 0.0, dy: heightDelta)
                                        }
                                    }
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
    
    private func fillMissingNodes(synchronous: Bool, animated: Bool, inputAnimatedInsertIndices: Set<Int>, insertDirectionHints: [Int: ListViewItemOperationDirectionHint], inputState: ListViewState, inputPreviousNodes: [Int: ListViewItemNode], inputOperations: [ListViewStateOperation], inputCompletion: @escaping (ListViewState, [ListViewStateOperation]) -> Void) {
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
    
    private func updateNodes(synchronous: Bool, animated: Bool, updateIndicesAndItems: [ListViewUpdateItem], inputState: ListViewState, previousNodes: [Int: ListViewItemNode], inputOperations: [ListViewStateOperation], completion: @escaping (ListViewState, [ListViewStateOperation]) -> Void) {
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
    
    private func insertNodeAtIndex(animated: Bool, animateAlpha: Bool, forceAnimateInsertion: Bool, previousFrame: CGRect?, nodeIndex: Int, offsetDirection: ListViewInsertionOffsetDirection, node: ListViewItemNode, layout: ListViewItemNodeLayout, apply: () -> (), timestamp: Double) {
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
        self.itemNodes.insert(node, at: nodeIndex)
        
        if useDynamicTuning {
            self.insertSubnode(node, at: 0)
        } else {
            //self.addSubnode(node)
        }
        
        var offsetHeight = node.apparentHeight
        var takenAnimation = false
        
        if let _ = previousFrame , animated && node.index != nil && nodeIndex != self.itemNodes.count - 1 {
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
            node.animateRemoved(timestamp, duration: insertionAnimationDuration * UIView.animationDurationFactor())
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
                    
                    let transitionOffsetDelta = nodeFrame.origin.y - previousFrame.origin.y - previousApparentHeight + layout.size.height
                    if node.rotated {
                        node.transitionOffset -= transitionOffsetDelta
                    } else {
                        node.transitionOffset += transitionOffsetDelta
                    }
                    node.addTransitionOffsetAnimation(0.0, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp)
                    if previousInsets != layout.insets {
                        node.insets = previousInsets
                        node.addInsetsAnimationToValue(layout.insets, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp)
                    }
                } else {
                    if self.debugInfo {
                        assert(true)
                    }
                    node.animateInsertion(timestamp, duration: insertionAnimationDuration * UIView.animationDurationFactor(), short: false)
                }
            }
        } else if animateAlpha && previousFrame == nil {
            if forceAnimateInsertion {
                node.animateInsertion(timestamp, duration: insertionAnimationDuration * UIView.animationDurationFactor(), short: true)
            } else {
                node.animateAdded(timestamp, duration: insertionAnimationDuration * UIView.animationDurationFactor())
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
    
    private func lowestHeaderNode() -> ASDisplayNode? {
        var lowestHeaderNode: ASDisplayNode?
        var lowestHeaderNodeIndex: Int?
        for (_, headerNode) in self.itemHeaderNodes {
            if let index = self.subnodes.index(of: headerNode) {
                if lowestHeaderNodeIndex == nil || index < lowestHeaderNodeIndex! {
                    lowestHeaderNodeIndex = index
                    lowestHeaderNode = headerNode
                }
            }
        }
        return lowestHeaderNode
    }
    
    private func topItemVerticalOrigin() -> CGFloat? {
        var topItemFound = false
        
        for i in 0 ..< self.itemNodes.count {
            if let index = itemNodes[i].index {
                if index == 0 {
                    topItemFound = true
                }
                break
            }
        }
        
        if topItemFound {
            return itemNodes[0].apparentFrame.origin.y
        } else {
            return nil
        }
    }
    
    private func bottomItemMaxY() -> CGFloat? {
        var bottomItemFound = false
        
        for i in (0 ..< self.itemNodes.count).reversed() {
            if let index = itemNodes[i].index {
                if index == self.items.count - 1 {
                    bottomItemFound = true
                    break
                }
            }
        }
        
        if bottomItemFound {
            return itemNodes.last!.apparentFrame.maxY
        } else {
            return nil
        }
    }
    
    private func replayOperations(animated: Bool, animateAlpha: Bool, animateTopItemVerticalOrigin: Bool, operations: [ListViewStateOperation], requestItemInsertionAnimationsIndices: Set<Int>, scrollToItem: ListViewScrollToItem?, updateSizeAndInsets: ListViewUpdateSizeAndInsets?, stationaryItemIndex: Int?, updateOpaqueState: Any?, completion: () -> Void) {
        let timestamp = CACurrentMediaTime()
        
        if let updateOpaqueState = updateOpaqueState {
            self.opaqueTransactionState = updateOpaqueState
        }
        
        var previousTopItemVerticalOrigin: CGFloat?
        var previousBottomItemMaxY: CGFloat?
        var snapshotView: UIView?
        if animateTopItemVerticalOrigin {
            previousTopItemVerticalOrigin = self.topItemVerticalOrigin()
            previousBottomItemMaxY = self.bottomItemMaxY()
            snapshotView = self.view.snapshotView(afterScreenUpdates: false)
        }
        
        var previousApparentFrames: [(ListViewItemNode, CGRect)] = []
        for itemNode in self.itemNodes {
            previousApparentFrames.append((itemNode, itemNode.apparentFrame))
        }
        
        var takenPreviousNodes = Set<ListViewItemNode>()
        for operation in operations {
            if case let .InsertNode(_, _, node, _, _) = operation {
                takenPreviousNodes.insert(node)
            }
        }
        
        let lowestHeaderNode = self.lowestHeaderNode()
        
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
                    var forceAnimateInsertion = false
                    if let index = node.index, requestItemInsertionAnimationsIndices.contains(index) {
                        forceAnimateInsertion = true
                    }
                    var updatedPreviousFrame = previousFrame
                    if let previousFrame = previousFrame, previousFrame.minY >= self.visibleSize.height || previousFrame.maxY < 0.0 {
                        updatedPreviousFrame = nil
                    }
                    
                    self.insertNodeAtIndex(animated: animated, animateAlpha: animateAlpha, forceAnimateInsertion: forceAnimateInsertion, previousFrame: updatedPreviousFrame, nodeIndex: index, offsetDirection: offsetDirection, node: node, layout: layout, apply: apply, timestamp: timestamp)
                    if let updatedPreviousFrame = updatedPreviousFrame {
                        if let lowestHeaderNode = lowestHeaderNode {
                            self.insertSubnode(node, belowSubnode: lowestHeaderNode)
                        } else {
                            self.addSubnode(node)
                        }
                    } else {
                        if animated {
                            self.insertSubnode(node, at: 0)
                        } else {
                            if let lowestHeaderNode = lowestHeaderNode {
                                self.insertSubnode(node, belowSubnode: lowestHeaderNode)
                            } else {
                                self.addSubnode(node)
                            }
                        }
                    }
                case let .InsertDisappearingPlaceholder(index, referenceNode, offsetDirection):
                    var height: CGFloat?
                    var previousLayout: ListViewItemNodeLayout?
                    
                    for (node, previousFrame) in previousApparentFrames {
                        if node === referenceNode {
                            height = previousFrame.size.height
                            previousLayout = ListViewItemNodeLayout(contentSize: node.contentSize, insets: node.insets)
                            break
                        }
                    }
                    
                    if let height = height, let previousLayout = previousLayout {
                        if takenPreviousNodes.contains(referenceNode) {
                            self.insertNodeAtIndex(animated: false, animateAlpha: false, forceAnimateInsertion: false, previousFrame: nil, nodeIndex: index, offsetDirection: offsetDirection, node: ListViewItemNode(layerBacked: true), layout: ListViewItemNodeLayout(contentSize: CGSize(width: self.visibleSize.width, height: height), insets: UIEdgeInsets()), apply: { }, timestamp: timestamp)
                        } else {
                            referenceNode.index = nil
                            self.insertNodeAtIndex(animated: false, animateAlpha: false, forceAnimateInsertion: false, previousFrame: nil, nodeIndex: index, offsetDirection: offsetDirection, node: referenceNode, layout: previousLayout, apply: { }, timestamp: timestamp)
                            self.addSubnode(referenceNode)
                        }
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
                            
                            let insetPart: CGFloat = previousInsets.top - layout.insets.top
                            node.transitionOffset += previousApparentHeight - layout.size.height - insetPart
                            node.addTransitionOffsetAnimation(0.0, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp)
                        } else {
                            if node.shouldAnimateHorizontalFrameTransition() {
                                node.addApparentHeightAnimation(updatedApparentHeight, duration: insertionAnimationDuration * UIView.animationDurationFactor(), beginAt: timestamp, update: { [weak node] progress in
                                    if let node = node {
                                        node.animateFrameTransition(progress)
                                    }
                                })
                            }
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
                if let index = itemNode.index, index == scrollToItem.index {
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
        } else if let stationaryItemIndex = stationaryItemIndex {
            for itemNode in self.itemNodes {
                if let index = itemNode.index , index == stationaryItemIndex {
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
            
            var headerNodesTransition: (ContainedViewLayoutTransition, Bool, CGFloat) = (.immediate, false, 0.0)
            
            if let updateSizeAndInsets = updateSizeAndInsets {
                if self.insets != updateSizeAndInsets.insets || !self.visibleSize.height.isEqual(to: updateSizeAndInsets.size.height) {
                    let previousVisibleSize = self.visibleSize
                    self.visibleSize = updateSizeAndInsets.size
                    
                    var offsetFix = updateSizeAndInsets.insets.top - self.insets.top
                    
                    self.insets = updateSizeAndInsets.insets
                    self.visibleSize = updateSizeAndInsets.size
                    
                    for itemNode in self.itemNodes {
                        let position = itemNode.position
                        itemNode.position = CGPoint(x: position.x, y: position.y + offsetFix)
                    }
                    
                    let (snappedTopInset, snapToBoundsOffset) = self.snapToBounds(snapTopItem: scrollToItem != nil, stackFromBottom: self.stackFromBottom)
                    
                    if !snappedTopInset.isZero && (previousVisibleSize.height.isZero || previousApparentFrames.isEmpty) {
                        offsetFix += snappedTopInset
                        
                        for itemNode in self.itemNodes {
                            let position = itemNode.position
                            itemNode.position = CGPoint(x: position.x, y: position.y + snappedTopInset)
                        }
                    }
                    
                    var completeOffset = offsetFix
                    
                    if !snapToBoundsOffset.isZero {
                        self.updateVisibleContentOffset()
                    }
                    
                    sizeAndInsetsOffset = offsetFix
                    completeOffset += snapToBoundsOffset
                    
                    if updateSizeAndInsets.duration > DBL_EPSILON {
                        let animation: CABasicAnimation
                        switch updateSizeAndInsets.curve {
                            case let .Spring(duration):
                                headerNodesTransition = (.animated(duration: duration, curve: .spring), false, -completeOffset)
                                let springAnimation = makeSpringAnimation("sublayerTransform")
                                springAnimation.fromValue = NSValue(caTransform3D: CATransform3DMakeTranslation(0.0, -completeOffset, 0.0))
                                springAnimation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
                                springAnimation.isRemovedOnCompletion = true
                                
                                let k = Float(UIView.animationDurationFactor())
                                var speed: Float = 1.0
                                if k != 0 && k != 1 {
                                    speed = Float(1.0) / k
                                }
                                springAnimation.speed = speed * Float(springAnimation.duration / duration)
                                
                                springAnimation.isAdditive = true
                                animation = springAnimation
                            case .Default:
                                headerNodesTransition = (.animated(duration: updateSizeAndInsets.duration, curve: .easeInOut), false, -completeOffset)
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
                } else {
                    self.visibleSize = updateSizeAndInsets.size
                    
                    if !self.snapToBounds(snapTopItem: scrollToItem != nil, stackFromBottom: self.stackFromBottom).offset.isZero {
                        self.updateVisibleContentOffset()
                    }
                }
                
                if let updatedTopItemVerticalOrigin = self.topItemVerticalOrigin(), let previousTopItemVerticalOrigin = previousTopItemVerticalOrigin, animateTopItemVerticalOrigin, !updatedTopItemVerticalOrigin.isEqual(to: previousTopItemVerticalOrigin) {
                    self.stopScrolling()
                    
                    let completeOffset = updatedTopItemVerticalOrigin - previousTopItemVerticalOrigin
                    let duration: Double = 0.4
                    
                    if let snapshotView = snapshotView {
                        snapshotView.frame = CGRect(origin: CGPoint(x: 0.0, y: completeOffset), size: snapshotView.frame.size)
                        self.view.addSubview(snapshotView)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                    
                    let springAnimation = makeSpringAnimation("sublayerTransform")
                    springAnimation.fromValue = NSValue(caTransform3D: CATransform3DMakeTranslation(0.0, -completeOffset, 0.0))
                    springAnimation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
                    springAnimation.isRemovedOnCompletion = true
                    
                    let k = Float(UIView.animationDurationFactor())
                    var speed: Float = 1.0
                    if k != 0 && k != 1 {
                        speed = Float(1.0) / k
                    }
                    springAnimation.speed = speed * Float(springAnimation.duration / duration)
                    
                    springAnimation.isAdditive = true
                    self.layer.add(springAnimation, forKey: nil)
                } else {
                    if let snapshotView = snapshotView {
                        snapshotView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: snapshotView.frame.size)
                        self.view.addSubview(snapshotView)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                }
                
                let wasIgnoringScrollingEvents = self.ignoreScrollingEvents
                self.ignoreScrollingEvents = true
                self.scroller.frame = CGRect(origin: CGPoint(), size: self.visibleSize)
                self.scroller.contentSize = CGSize(width: self.visibleSize.width, height: infiniteScrollSize * 2.0)
                self.lastContentOffset = CGPoint(x: 0.0, y: infiniteScrollSize)
                self.scroller.contentOffset = self.lastContentOffset
                self.ignoreScrollingEvents = wasIgnoringScrollingEvents
            } else {
                let (snappedTopInset, snapToBoundsOffset) = self.snapToBounds(snapTopItem: scrollToItem != nil, stackFromBottom: self.stackFromBottom)
                
                if !snappedTopInset.isZero && previousApparentFrames.isEmpty {
                    let offsetFix = snappedTopInset
                    
                    for itemNode in self.itemNodes {
                        let position = itemNode.position
                        itemNode.position = CGPoint(x: position.x, y: position.y + snappedTopInset)
                    }
                }
                
                if !snapToBoundsOffset.isZero {
                    self.updateVisibleContentOffset()
                }
            }
            
            self.updateAccessoryNodes(animated: animated, currentTimestamp: timestamp)
            self.updateFloatingAccessoryNodes(animated: animated, currentTimestamp: timestamp)
            
            if let scrollToItem = scrollToItem , scrollToItem.animated {
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
                    
                    var previousItemHeaderNodes: [ListViewItemHeaderNode] = []
                    let offsetOrZero: CGFloat = offset ?? 0.0
                    switch scrollToItem.curve {
                        case let .Spring(duration):
                            headerNodesTransition = (.animated(duration: duration, curve: .spring), headerNodesTransition.1, headerNodesTransition.2 - offsetOrZero)
                        case .Default:
                            headerNodesTransition = (.animated(duration: 0.5, curve: .easeInOut), true, headerNodesTransition.2 - offsetOrZero)
                    }
                    for (_, headerNode) in self.itemHeaderNodes {
                        previousItemHeaderNodes.append(headerNode)
                    }
                    
                    self.updateItemHeaders(headerNodesTransition, animateInsertion: animated || !requestItemInsertionAnimationsIndices.isEmpty)
                    
                    if let offset = offset , abs(offset) > CGFloat(FLT_EPSILON) {
                        let lowestHeaderNode = self.lowestHeaderNode()
                        for itemNode in temporaryPreviousNodes {
                            itemNode.frame = itemNode.frame.offsetBy(dx: 0.0, dy: offset)
                            temporaryPreviousNodes.append(itemNode)
                            if let lowestHeaderNode = lowestHeaderNode {
                                self.insertSubnode(itemNode, belowSubnode: lowestHeaderNode)
                            } else {
                                self.addSubnode(itemNode)
                            }
                        }
                        
                        var temporaryHeaderNodes: [ListViewItemHeaderNode] = []
                        for headerNode in previousItemHeaderNodes {
                            if headerNode.supernode == nil {
                                headerNode.frame = headerNode.frame.offsetBy(dx: 0.0, dy: offset)
                                temporaryHeaderNodes.append(headerNode)
                                self.addSubnode(headerNode)
                            }
                        }
                        
                        let animation: CABasicAnimation
                        switch scrollToItem.curve {
                            case let .Spring(duration):
                                let springAnimation = makeSpringAnimation("sublayerTransform")
                                springAnimation.fromValue = NSValue(caTransform3D: CATransform3DMakeTranslation(0.0, -offset, 0.0))
                                springAnimation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
                                springAnimation.isRemovedOnCompletion = true
                                springAnimation.isAdditive = true
                                springAnimation.fillMode = kCAFillModeForwards
                                
                                let k = Float(UIView.animationDurationFactor())
                                var speed: Float = 1.0
                                if k != 0 && k != 1 {
                                    speed = Float(1.0) / k
                                }
                                springAnimation.speed = speed * Float(springAnimation.duration / duration)
                                
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
                            for headerNode in temporaryHeaderNodes {
                                headerNode.removeFromSupernode()
                            }
                        }
                        self.layer.add(animation, forKey: nil)
                    }
                }
                
                self.updateScroller()
                self.setNeedsAnimations()
                
                self.updateVisibleContentOffset()
                
                if self.debugInfo {
                    let delta = CACurrentMediaTime() - timestamp
                    //print("replayOperations \(delta * 1000.0) ms")
                }
                
                completion()
            } else {
                self.updateItemHeaders(headerNodesTransition, animateInsertion: animated || !requestItemInsertionAnimationsIndices.isEmpty)
                
                if animated {
                    self.setNeedsAnimations()
                }
                
                self.updateScroller()
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
                if let previousMaxY = previousMaxY , abs(previousMaxY - node.apparentFrame.minY) > CGFloat(FLT_EPSILON) {
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
        node.headerAccessoryItemNode?.removeFromSupernode()
        node.headerAccessoryItemNode = nil
    }
    
    private func updateItemHeaders(_ transition: (ContainedViewLayoutTransition, Bool, CGFloat) = (.immediate, false, 0.0), animateInsertion: Bool = false) {
        let upperDisplayBound = self.insets.top
        let lowerDisplayBound = self.visibleSize.height - self.insets.bottom
        var visibleHeaderNodes = Set<Int64>()
        
        let flashing = self.headerItemsAreFlashing()
        
        let addHeader: (_ id: Int64, _ upperBound: CGFloat, _ lowerBound: CGFloat, _ item: ListViewItemHeader, _ hasValidNodes: Bool) -> Void = { id, upperBound, lowerBound, item, hasValidNodes in
            let itemHeaderHeight: CGFloat = item.height
            
            let headerFrame: CGRect
            let stickLocationDistanceFactor: CGFloat
            let stickLocationDistance: CGFloat
            switch item.stickDirection {
                case .top:
                    headerFrame = CGRect(origin: CGPoint(x: 0.0, y: min(max(upperDisplayBound, upperBound), lowerBound - itemHeaderHeight)), size: CGSize(width: self.visibleSize.width, height: itemHeaderHeight))
                    stickLocationDistance = 0.0
                    stickLocationDistanceFactor = 0.0
                case .bottom:
                    headerFrame = CGRect(origin: CGPoint(x: 0.0, y: max(upperBound, min(lowerBound, lowerDisplayBound) - itemHeaderHeight)), size: CGSize(width: self.visibleSize.width, height: itemHeaderHeight))
                    stickLocationDistance = lowerBound - headerFrame.maxY
                    stickLocationDistanceFactor = max(0.0, min(1.0, stickLocationDistance / itemHeaderHeight))
            }
            visibleHeaderNodes.insert(id)
            if let headerNode = self.itemHeaderNodes[id] {
                switch transition.0 {
                    case .immediate:
                        headerNode.frame = headerFrame
                    case let .animated(duration, curve):
                        let previousFrame = headerNode.frame
                        headerNode.frame = headerFrame
                        let offset = -(headerFrame.minY - previousFrame.minY + transition.2)
                        switch curve {
                            case .spring:
                                transition.0.animateOffsetAdditive(node: headerNode, offset: offset)
                            case .easeInOut:
                                if transition.1 {
                                    headerNode.layer.animateBoundsOriginYAdditive(from: offset, to: 0.0, duration: duration, mediaTimingFunction: CAMediaTimingFunction(controlPoints: 0.33, 0.52, 0.25, 0.99))
                                } else {
                                    headerNode.layer.animateBoundsOriginYAdditive(from: offset, to: 0.0, duration: duration, mediaTimingFunction: CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut))
                                }
                        }
                }
                headerNode.updateInternalStickLocationDistanceFactor(stickLocationDistanceFactor, animated: true)
                headerNode.internalStickLocationDistance = stickLocationDistance
                if !hasValidNodes && !headerNode.alpha.isZero {
                    headerNode.alpha = 0.0
                    if animateInsertion {
                        headerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                        headerNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.2)
                    }
                } else if hasValidNodes && headerNode.alpha.isZero {
                    headerNode.alpha = 1.0
                    if animateInsertion {
                        headerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        headerNode.layer.animateScale(from: 0.2, to: 1.0, duration: 0.2)
                    }
                }
                headerNode.updateStickDistanceFactor(stickLocationDistanceFactor, transition: transition.0)
            } else {
                let headerNode = item.node()
                headerNode.updateFlashingOnScrolling(flashing, animated: false)
                headerNode.frame = headerFrame
                headerNode.updateInternalStickLocationDistanceFactor(stickLocationDistanceFactor, animated: false)
                self.itemHeaderNodes[id] = headerNode
                self.addSubnode(headerNode)
                if animateInsertion {
                    headerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    headerNode.layer.animateScale(from: 0.2, to: 1.0, duration: 0.3)
                }
                headerNode.updateStickDistanceFactor(stickLocationDistanceFactor, transition: .immediate)
            }
        }
        
        var previousHeader: (Int64, CGFloat, CGFloat, ListViewItemHeader, Bool)?
        for itemNode in self.itemNodes {
            let itemFrame = itemNode.apparentFrame
            if let itemHeader = itemNode.header() {
                if let (previousHeaderId, previousUpperBound, previousLowerBound, previousHeaderItem, hasValidNodes) = previousHeader {
                    if previousHeaderId == itemHeader.id {
                        previousHeader = (previousHeaderId, previousUpperBound, itemFrame.maxY, previousHeaderItem, hasValidNodes || itemNode.index != nil)
                    } else {
                        addHeader(previousHeaderId, previousUpperBound, previousLowerBound, previousHeaderItem, hasValidNodes)
                        
                        previousHeader = (itemHeader.id, itemFrame.minY, itemFrame.maxY, itemHeader, itemNode.index != nil)
                    }
                } else {
                    previousHeader = (itemHeader.id, itemFrame.minY, itemFrame.maxY, itemHeader, itemNode.index != nil)
                }
            } else {
                if let (previousHeaderId, previousUpperBound, previousLowerBound, previousHeaderItem, hasValidNodes) = previousHeader {
                    addHeader(previousHeaderId, previousUpperBound, previousLowerBound, previousHeaderItem, hasValidNodes)
                }
                previousHeader = nil
            }
        }
        
        if let (previousHeaderId, previousUpperBound, previousLowerBound, previousHeaderItem, hasValidNodes) = previousHeader {
            addHeader(previousHeaderId, previousUpperBound, previousLowerBound, previousHeaderItem, hasValidNodes)
        }
        
        var currentIds = Set(self.itemHeaderNodes.keys)
        for id in currentIds.subtracting(visibleHeaderNodes) {
            if let headerNode = self.itemHeaderNodes.removeValue(forKey: id) {
                headerNode.removeFromSupernode()
            }
        }
    }
    
    private func updateAccessoryNodes(animated: Bool, currentTimestamp: Double) {
        var index = -1
        let count = self.itemNodes.count
        for itemNode in self.itemNodes {
            index += 1
            
            guard let itemNodeIndex = itemNode.index else {
                continue
            }
            
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
                                    if let nextAccessoryItem = nextItem.accessoryItem , nextAccessoryItem.isEqualToItem(accessoryItem) {
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
            
            if let headerAccessoryItem = self.items[itemNodeIndex].headerAccessoryItem {
                let previousItem: ListViewItem? = itemNodeIndex == 0 ? nil : self.items[itemNodeIndex - 1]
                let previousHeaderAccessoryItem = previousItem?.headerAccessoryItem
                
                if (previousHeaderAccessoryItem == nil || !previousHeaderAccessoryItem!.isEqualToItem(headerAccessoryItem)) {
                    if itemNode.headerAccessoryItemNode == nil {
                        var didStealHeaderAccessoryNode = false
                        if index != count - 1 {
                            for i in index + 1 ..< count {
                                let nextItemNode = self.itemNodes[i]
                                if let nextItemNodeIndex = nextItemNode.index {
                                    let nextItem = self.items[nextItemNodeIndex]
                                    if let nextHeaderAccessoryItem = nextItem.headerAccessoryItem , nextHeaderAccessoryItem.isEqualToItem(headerAccessoryItem) {
                                        if let nextHeaderAccessoryItemNode = nextItemNode.headerAccessoryItemNode {
                                            didStealHeaderAccessoryNode = true
                                            
                                            var previousHeaderAccessoryItemNodeOrigin = nextHeaderAccessoryItemNode.frame.origin
                                            let previousParentOrigin = nextItemNode.frame.origin
                                            previousHeaderAccessoryItemNodeOrigin.x += previousParentOrigin.x
                                            previousHeaderAccessoryItemNodeOrigin.y += previousParentOrigin.y
                                            previousHeaderAccessoryItemNodeOrigin.y -= nextItemNode.bounds.origin.y
                                            previousHeaderAccessoryItemNodeOrigin.y -= nextHeaderAccessoryItemNode.transitionOffset.y
                                            nextHeaderAccessoryItemNode.transitionOffset = CGPoint()
                                            
                                            nextHeaderAccessoryItemNode.removeFromSupernode()
                                            itemNode.addSubnode(nextHeaderAccessoryItemNode)
                                            itemNode.headerAccessoryItemNode = nextHeaderAccessoryItemNode
                                            self.itemNodes[i].headerAccessoryItemNode = nil
                                            
                                            var updatedHeaderAccessoryItemNodeOrigin = nextHeaderAccessoryItemNode.frame.origin
                                            let updatedParentOrigin = itemNode.frame.origin
                                            updatedHeaderAccessoryItemNodeOrigin.x += updatedParentOrigin.x
                                            updatedHeaderAccessoryItemNodeOrigin.y += updatedParentOrigin.y
                                            updatedHeaderAccessoryItemNodeOrigin.y -= itemNode.bounds.origin.y
                                            
                                            let deltaHeight = itemNode.frame.size.height - nextItemNode.frame.size.height
                                            
                                            nextHeaderAccessoryItemNode.animateTransitionOffset(CGPoint(x: 0.0, y: updatedHeaderAccessoryItemNodeOrigin.y - previousHeaderAccessoryItemNodeOrigin.y - deltaHeight), beginAt: currentTimestamp, duration: insertionAnimationDuration * UIView.animationDurationFactor(), curve: listViewAnimationCurveSystem)
                                        }
                                    } else {
                                        break
                                    }
                                }
                            }
                        }
                        
                        if !didStealHeaderAccessoryNode {
                            let headerAccessoryNode = headerAccessoryItem.node()
                            itemNode.addSubnode(headerAccessoryNode)
                            itemNode.headerAccessoryItemNode = headerAccessoryNode
                        }
                    }
                } else {
                    itemNode.headerAccessoryItemNode?.removeFromSupernode()
                    itemNode.headerAccessoryItemNode = nil
                }
            }
        }
    }
    
    private func updateFloatingAccessoryNodes(animated: Bool, currentTimestamp: Double) {
        var previousFloatingAccessoryItem: ListViewAccessoryItem?
        for itemNode in self.itemNodes {
            if let index = itemNode.index, let floatingAccessoryItem = self.items[index].floatingAccessoryItem {
                if itemNode.floatingAccessoryItemNode == nil {
                    let floatingAccessoryItemNode = floatingAccessoryItem.node()
                    itemNode.floatingAccessoryItemNode = floatingAccessoryItemNode
                    itemNode.addSubnode(floatingAccessoryItemNode)
                }
            } else {
                itemNode.floatingAccessoryItemNode?.removeFromSupernode()
                itemNode.floatingAccessoryItemNode = nil
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
                        
                        completion()
                    
                        if repeatUpdate {
                            strongSelf.enqueueUpdateVisibleItems()
                        }
                    })
                }
            })
        }
    }
    
    private func updateVisibleItemsTransaction(completion: @escaping (Void) -> Void) {
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
        
        let state = self.currentState()
        self.async {
            self.fillMissingNodes(synchronous: false, animated: false, inputAnimatedInsertIndices: [], insertDirectionHints: [:], inputState: state, inputPreviousNodes: [:], inputOperations: []) { state, operations in
                var updatedState = state
                var updatedOperations = operations
                updatedState.removeInvisibleNodes(&updatedOperations)
                self.dispatchOnVSync {
                    self.replayOperations(animated: false, animateAlpha: false, animateTopItemVerticalOrigin: false, operations: updatedOperations, requestItemInsertionAnimationsIndices: Set(), scrollToItem: nil, updateSizeAndInsets: nil, stationaryItemIndex: nil, updateOpaqueState: nil, completion: completion)
                }
            }
        }
    }
    
    private func updateVisibleItemRange(force: Bool = false) {
        let currentRange = self.immediateDisplayedItemRange()
        
        if currentRange != self.displayedItemRange || force {
            self.displayedItemRange = currentRange
            self.displayedItemRangeChanged(currentRange, self.opaqueTransactionState)
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
            if let firstIndex = firstIndex, let lastIndex = lastIndex {
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
        
        for (_, headerNode) in self.itemHeaderNodes {
            if headerNode.animate(timestamp) {
                continueAnimations = true
            }
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
            
            if !self.snapToBounds(snapTopItem: false, stackFromBottom: self.stackFromBottom).offset.isZero {
                self.updateVisibleContentOffset()
            }
        }
        
        self.debugCheckMonotonity()
        
        if !continueAnimations {
            self.pauseAnimations()
        }
        
        if requestUpdateVisibleItems {
            self.enqueueUpdateVisibleItems()
        }
    }
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touchesPosition = touches.first!.location(in: self.view)
        self.selectionTouchLocation = touches.first!.location(in: self.view)
        
        self.selectionTouchDelayTimer?.invalidate()
        let timer = Timer(timeInterval: 0.08, target: ListViewTimerProxy { [weak self] in
            if let strongSelf = self , strongSelf.selectionTouchLocation != nil {
                strongSelf.clearHighlightAnimated(false)
                
                if let index = strongSelf.itemIndexAtPoint(strongSelf.touchesPosition) {
                    if strongSelf.items[index].selectable {
                        strongSelf.highlightedItemIndex = index
                        for itemNode in strongSelf.itemNodes {
                            if itemNode.index == index {
                                if true { //!(itemNode.hitTest(CGPoint(x: strongSelf.touchesPosition.x - itemNode.frame.minX, y: strongSelf.touchesPosition.y - itemNode.frame.minY), with: event) is UIControl) {
                                    if !itemNode.isLayerBacked {
                                        strongSelf.view.bringSubview(toFront: itemNode.view)
                                    }
                                    itemNode.setHighlighted(true, animated: false)
                                }
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
    
    public func forEachItemNode(_ f: @noescape(ASDisplayNode) -> Void) {
        for itemNode in self.itemNodes {
            if itemNode.index != nil {
                f(itemNode)
            }
        }
    }
    
    public func ensureItemNodeVisible(_ node: ListViewItemNode) {
        if let index = node.index {
            if node.frame.minY < self.insets.top {
                self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: ListViewDeleteAndInsertOptions(), scrollToItem: ListViewScrollToItem(index: index, position: ListViewScrollPosition.Top, animated: true, curve: ListViewAnimationCurve.Default, directionHint: ListViewScrollToItemDirectionHint.Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            } else if node.frame.maxY > self.visibleSize.height - self.insets.bottom {
                self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: ListViewDeleteAndInsertOptions(), scrollToItem: ListViewScrollToItem(index: index, position: ListViewScrollPosition.Bottom, animated: true, curve: ListViewAnimationCurve.Default, directionHint: ListViewScrollToItemDirectionHint.Down), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            }
        }
    }
    
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let selectionTouchLocation = self.selectionTouchLocation {
            let location = touches.first!.location(in: self.view)
            let distance = CGPoint(x: selectionTouchLocation.x - location.x, y: selectionTouchLocation.y - location.y)
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
    
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
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
            self.items[highlightedItemIndex].selected(listView: self)
        }
        self.selectionTouchLocation = nil
        
        super.touchesEnded(touches, with: event)
    }
    
    override open func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        self.selectionTouchLocation = nil
        self.selectionTouchDelayTimer?.invalidate()
        self.selectionTouchDelayTimer = nil
        self.clearHighlightAnimated(false)
        
        super.touchesCancelled(touches, with: event)
    }
    
    @objc func trackingGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case .began:
                self.isTracking = true
                break
            case .changed:
                self.touchesPosition = recognizer.location(in: self.view)
            case .ended, .cancelled:
                self.isTracking = false
            default:
                break
        }
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    public func withTransaction(_ f: @escaping () -> Void) {
        self.transactionQueue.addTransaction { completion in
            f()
            completion()
        }
    }
    
    fileprivate func internalHitTest(_ point: CGPoint, with event: UIEvent?) -> Bool {
        if self.limitHitTestToNodes {
            var foundHit = false
            for itemNode in self.itemNodes {
                if itemNode.frame.contains(point) {
                    foundHit = true
                    break
                }
            }
            if !foundHit {
                return false
            }
        }
        return true
    }
}
