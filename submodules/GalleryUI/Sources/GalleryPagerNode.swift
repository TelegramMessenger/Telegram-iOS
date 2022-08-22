import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox

private func edgeWidth(width: CGFloat) -> CGFloat {
    return min(44.0, floor(width / 6.0))
}

let fadeWidth: CGFloat = 70.0
private let leftFadeImage = generateImage(CGSize(width: fadeWidth, height: 32.0), opaque: false, rotatedContext: { size, context in
    let bounds = CGRect(origin: CGPoint(), size: size)
    context.clear(bounds)
    
    let gradientColors = [UIColor.black.withAlphaComponent(0.35).cgColor, UIColor.black.withAlphaComponent(0.0).cgColor] as CFArray
    
    var locations: [CGFloat] = [0.0, 1.0]
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!

    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
})

private let rightFadeImage = generateImage(CGSize(width: fadeWidth, height: 32.0), opaque: false, rotatedContext: { size, context in
    let bounds = CGRect(origin: CGPoint(), size: size)
    context.clear(bounds)
    
    let gradientColors = [UIColor.black.withAlphaComponent(0.0).cgColor, UIColor.black.withAlphaComponent(0.35).cgColor] as CFArray
    
    var locations: [CGFloat] = [0.0, 1.0]
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!

    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
})

public struct GalleryPagerInsertItem {
    public let index: Int
    public let item: GalleryItem
    public let previousIndex: Int?
    
    public init(index: Int, item: GalleryItem, previousIndex: Int?) {
        self.index = index
        self.item = item
        self.previousIndex = previousIndex
    }
}

public struct GalleryPagerUpdateItem {
    public let index: Int
    public let previousIndex: Int
    public let item: GalleryItem
    
    public init(index: Int, previousIndex: Int, item: GalleryItem) {
        self.index = index
        self.previousIndex = previousIndex
        self.item = item
    }
}

public struct GalleryPagerTransaction {
    public let deleteItems: [Int]
    public let insertItems: [GalleryPagerInsertItem]
    public let updateItems: [GalleryPagerUpdateItem]
    public let focusOnItem: Int?
    public let synchronous: Bool
    
    public init(deleteItems: [Int], insertItems: [GalleryPagerInsertItem], updateItems: [GalleryPagerUpdateItem], focusOnItem: Int?, synchronous: Bool) {
        self.deleteItems = deleteItems
        self.insertItems = insertItems
        self.updateItems = updateItems
        self.focusOnItem = focusOnItem
        self.synchronous = synchronous
    }
}

public final class GalleryPagerNode: ASDisplayNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    private let pageGap: CGFloat
    private let disableTapNavigation: Bool
    
    private let scrollView: UIScrollView
    
    private let leftFadeNode: ASDisplayNode
    private let rightFadeNode: ASDisplayNode
    private var highlightedSide: Bool?
    
    private var tapRecognizer: TapLongTapOrDoubleTapGestureRecognizer?
    
    public private(set) var items: [GalleryItem] = []
    private var itemNodes: [GalleryItemNode] = []
    private var ignoreDidScroll = false
    private var ignoreCentralItemIndexUpdate = false
    private var centralItemIndex: Int? {
        didSet {
            if oldValue != self.centralItemIndex && !self.ignoreCentralItemIndexUpdate {
                self.centralItemIndexUpdated(self.centralItemIndex)
            }
        }
    }
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    public var centralItemIndexUpdated: (Int?) -> Void = { _ in }
    private var invalidatedItems = false
    public var centralItemIndexOffsetUpdated: (([GalleryItem]?, Int, CGFloat)?) -> Void = { _ in }
    public var toggleControlsVisibility: () -> Void = { }
    public var updateControlsVisibility: (Bool) -> Void = { _ in }
    public var updateOrientation: (UIInterfaceOrientation) -> Void = { _ in }
    public var dismiss: () -> Void = { }
    public var beginCustomDismiss: (Bool) -> Void = { _ in }
    public var completeCustomDismiss: () -> Void = { }
    public var baseNavigationController: () -> NavigationController? = { return nil }
    public var galleryController: () -> ViewController? = { return nil }
    
    private var pagingEnabled = true
    public var pagingEnabledPromise = Promise<Bool>(true)
    private var pagingEnabledDisposable: Disposable?
    
    public init(pageGap: CGFloat, disableTapNavigation: Bool) {
        self.pageGap = pageGap
        self.disableTapNavigation = disableTapNavigation

        self.scrollView = UIScrollView()
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        self.leftFadeNode = ASDisplayNode()
        self.leftFadeNode.alpha = 0.0
        self.leftFadeNode.backgroundColor = leftFadeImage.flatMap { UIColor(patternImage: $0) }
        
        self.rightFadeNode = ASDisplayNode()
        self.rightFadeNode.alpha = 0.0
        self.rightFadeNode.backgroundColor = rightFadeImage.flatMap { UIColor(patternImage: $0) }
        
        super.init()
        
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.alwaysBounceHorizontal = !pageGap.isZero
        self.scrollView.bounces = !pageGap.isZero
        self.scrollView.isPagingEnabled = true
        self.scrollView.delegate = self
        self.scrollView.clipsToBounds = false
        self.scrollView.scrollsToTop = false
        self.scrollView.delaysContentTouches = false
        self.view.addSubview(self.scrollView)
        
        self.addSubnode(self.leftFadeNode)
        self.addSubnode(self.rightFadeNode)
        
        self.pagingEnabledDisposable = (self.pagingEnabledPromise.get()
        |> deliverOnMainQueue).start(next: { [weak self] pagingEnabled  in
            if let strongSelf = self {
                strongSelf.pagingEnabled = pagingEnabled
            }
        })
    }
    
    deinit {
        self.pagingEnabledDisposable?.dispose()
    }
    
    public override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.delegate = self
        self.tapRecognizer = recognizer
        recognizer.tapActionAtPoint = { [weak self] point in
            guard let strongSelf = self, strongSelf.pagingEnabled else {
                return .fail
            }
            
            let size = strongSelf.bounds
            
            var highlightedSide: Bool?
            if point.x < edgeWidth(width: size.width) && strongSelf.canGoToPreviousItem() {
                if strongSelf.items.count > 1 {
                    highlightedSide = false
                }
            } else if point.x > size.width - edgeWidth(width: size.width) && strongSelf.canGoToNextItem() {
                if strongSelf.items.count > 1 {
                    if point.y < 80.0 {
                        highlightedSide = nil
                    } else {
                        highlightedSide = true
                    }
                }
            }
            
            if highlightedSide == nil {
                return .fail
            }
            
            if let result = strongSelf.hitTest(point, with: nil), let _ = result.asyncdisplaykit_node as? ASButtonNode {
                return .fail
            }
            return .keepWithSingleTap
        }
        recognizer.highlight = { [weak self] point in
            guard let strongSelf = self, strongSelf.pagingEnabled else {
                return
            }
            let size = strongSelf.bounds
            
            var highlightedSide: Bool?
            if let point = point {
                if point.x < edgeWidth(width: size.width) && strongSelf.canGoToPreviousItem() {
                    if strongSelf.items.count > 1 {
                        highlightedSide = false
                    }
                } else if point.x > size.width - edgeWidth(width: size.width) && strongSelf.canGoToNextItem() {
                    if strongSelf.items.count > 1 {
                        highlightedSide = true
                    }
                }
            }
            if strongSelf.highlightedSide != highlightedSide {
                strongSelf.highlightedSide = highlightedSide
                
                let leftAlpha: CGFloat
                let rightAlpha: CGFloat
                if let highlightedSide = highlightedSide {
                    leftAlpha = highlightedSide ? 0.0 : 1.0
                    rightAlpha = highlightedSide ? 1.0 : 0.0
                } else {
                    leftAlpha = 0.0
                    rightAlpha = 0.0
                }
                if strongSelf.leftFadeNode.alpha != leftAlpha {
                    strongSelf.leftFadeNode.alpha = leftAlpha
                    if leftAlpha.isZero {
                        strongSelf.leftFadeNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, timingFunction: kCAMediaTimingFunctionSpring)
                    } else {
                        strongSelf.leftFadeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.08)
                    }
                }
                if strongSelf.rightFadeNode.alpha != rightAlpha {
                    strongSelf.rightFadeNode.alpha = rightAlpha
                    if rightAlpha.isZero {
                        strongSelf.rightFadeNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, timingFunction: kCAMediaTimingFunctionSpring)
                    } else {
                        strongSelf.rightFadeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.08)
                    }
                }
            }
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                if case .tap = gesture {
                    let size = self.bounds.size
                    if location.x < edgeWidth(width: size.width) && self.canGoToPreviousItem() {
                        self.goToPreviousItem()
                    } else if location.x > size.width - edgeWidth(width: size.width) && self.canGoToNextItem() {
                        self.goToNextItem()
                    }
                }
            }
        default:
            break
        }
    }
    
    public var isScrollEnabled: Bool {
        get {
            return self.scrollView.isScrollEnabled
        }
        set {
            self.scrollView.isScrollEnabled = newValue
        }
    }
    
    public func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var centralPoint: CGPoint?
        if transition.isAnimated, let centralItemIndex = self.centralItemIndex, let centralItemNode = self.visibleItemNode(at: centralItemIndex) {
            centralPoint = self.view.convert(CGPoint(x: centralItemNode.frame.size.width / 2.0, y: centralItemNode.frame.size.height / 2.0), from: centralItemNode.view)
        }
        
        var previousCentralNodeHorizontalOffset: CGFloat?
        if let centralItemIndex = self.centralItemIndex, let centralNode = self.visibleItemNode(at: centralItemIndex) {
            previousCentralNodeHorizontalOffset = self.scrollView.contentOffset.x - centralNode.frame.minX
        }
        
        self.ignoreDidScroll = true
        self.scrollView.frame = CGRect(origin: CGPoint(x: -self.pageGap, y: 0.0), size: CGSize(width: layout.size.width + self.pageGap * 2.0, height: layout.size.height))
        self.ignoreDidScroll = false
        
        for i in 0 ..< self.itemNodes.count {
            transition.updateFrame(node: self.itemNodes[i], frame: CGRect(origin: CGPoint(x: CGFloat(i) * self.scrollView.bounds.size.width + self.pageGap, y: 0.0), size: CGSize(width: self.scrollView.bounds.size.width - self.pageGap * 2.0, height: self.scrollView.bounds.size.height)))
            self.itemNodes[i].containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
        
        if let previousCentralNodeHorizontalOffset = previousCentralNodeHorizontalOffset, let centralItemIndex = self.centralItemIndex, let centralNode = self.visibleItemNode(at: centralItemIndex) {
            self.scrollView.contentOffset = CGPoint(x: centralNode.frame.minX + previousCentralNodeHorizontalOffset, y: 0.0)
        }
        
        self.updateItemNodes(transition: transition)
        
        if let centralPoint = centralPoint, let centralItemIndex = self.centralItemIndex, let centralItemNode = self.visibleItemNode(at: centralItemIndex) {
            let updatedCentralPoint = self.view.convert(CGPoint(x: centralItemNode.frame.size.width / 2.0, y: centralItemNode.frame.size.height / 2.0), from: centralItemNode.view)
            
            transition.animatePosition(node: centralItemNode, from: centralItemNode.position.offsetBy(dx: -updatedCentralPoint.x + centralPoint.x, dy: -updatedCentralPoint.y + centralPoint.y))
        }
        
        self.leftFadeNode.frame = CGRect(x: 0.0, y: 0.0, width: fadeWidth, height: layout.size.height)
        self.rightFadeNode.frame = CGRect(x: layout.size.width - fadeWidth, y: 0.0, width: fadeWidth, height: layout.size.height)
    }
    
    public func ready() -> Signal<Void, NoError> {
        if let itemNode = self.centralItemNode() {
            return itemNode.ready()
        }
        return .single(Void())
    }
    
    public func centralItemNode() -> GalleryItemNode? {
        if let centralItemIndex = self.centralItemIndex, let centralItemNode = self.visibleItemNode(at: centralItemIndex) {
            return centralItemNode
        } else {
            return nil
        }
    }
    
    public var updateOnReplacement = false
    public func replaceItems(_ items: [GalleryItem], centralItemIndex: Int?, synchronous: Bool = false) {
        var updateItems: [GalleryPagerUpdateItem] = []
        var deleteItems: [Int] = []
        var insertItems: [GalleryPagerInsertItem] = []
        var previousIndexById: [AnyHashable: Int] = [:]
        let validIds = Set(items.map { $0.id })
        
        for i in 0 ..< self.items.count {
            previousIndexById[self.items[i].id] = i
            if !validIds.contains(self.items[i].id) {
                deleteItems.append(i)
            }
        }
        
        if self.updateOnReplacement {
            for i in 0 ..< items.count {
                if (previousIndexById[items[i].id] == nil)  {
                    insertItems.append(GalleryPagerInsertItem(index: i, item: items[i], previousIndex: previousIndexById[items[i].id]))
                } else {
                    updateItems.append(GalleryPagerUpdateItem(index: i, previousIndex: i, item: items[i]))
                }
            }
        } else {
            for i in 0 ..< items.count {
                insertItems.append(GalleryPagerInsertItem(index: i, item: items[i], previousIndex: previousIndexById[items[i].id]))
            }
        }
        
        self.transaction(GalleryPagerTransaction(deleteItems: deleteItems, insertItems: insertItems, updateItems: updateItems, focusOnItem: centralItemIndex, synchronous: synchronous))
        
        if self.updateOnReplacement {
            self.items = items
            
            for i in 0 ..< self.items.count {
                if let itemNode = self.visibleItemNode(at: i) {
                    self.items[i].updateNode(node: itemNode, synchronous: synchronous)
                }
            }
            for i in (0 ..< self.itemNodes.count).reversed() {
                let node = self.itemNodes[i]
                if node.index > self.items.count - 1 {
                    node.removeFromSupernode()
                    self.itemNodes.remove(at: i)
                }
            }
            
            self.updateCentralIndexOffset(transition: .immediate)
        }
    }
    
    public func transaction(_ transaction: GalleryPagerTransaction) {
        for updatedItem in transaction.updateItems {
            self.items[updatedItem.previousIndex] = updatedItem.item
            if let itemNode = self.visibleItemNode(at: updatedItem.previousIndex) {
                //print("update visible node at \(updatedItem.previousIndex)")
                updatedItem.item.updateNode(node: itemNode, synchronous: transaction.synchronous)
            }
        }
                
        if !transaction.deleteItems.isEmpty || !transaction.insertItems.isEmpty {
            let deleteItems = transaction.deleteItems.sorted()
            
            for deleteItemIndex in deleteItems.reversed() {
                self.items.remove(at: deleteItemIndex)
                for i in 0 ..< self.itemNodes.count {
                    if self.itemNodes[i].index == deleteItemIndex {
                        //print("delete visible node at \(deleteItemIndex)")
                        self.removeVisibleItemNode(internalIndex: i)
                        break
                    }
                }
            }
            
            let insertItems = transaction.insertItems.sorted(by: { $0.index < $1.index })
            
            if transaction.updateItems.isEmpty && !insertItems.isEmpty {
                self.items.removeAll()
            }
            
            for insertedItem in insertItems {
                self.items.append(insertedItem.item)
                //self.items.insert(insertedItem.item, at: insertedItem.index)
            }
            
            let visibleIndices: [Int] = self.itemNodes.map { $0.index }
            
            var remapIndices: [Int: Int] = [:]
            for i in 0 ..< insertItems.count {
                if let previousIndex = insertItems[i].previousIndex, visibleIndices.contains(previousIndex) {
                    remapIndices[previousIndex] = i
                }
            }
            
            for itemNode in self.itemNodes {
                if let remappedIndex = remapIndices[itemNode.index] {
                    //print("remap visible node \(itemNode.index) -> \(remappedIndex)")
                    itemNode.index = remappedIndex
                }
            }
            
            self.itemNodes.sort(by: { $0.index < $1.index })
            
            //print("visible indices before update \(self.itemNodes.map { $0.index })")
            
            self.invalidatedItems = true
            if let focusOnItem = transaction.focusOnItem {
                self.centralItemIndex = focusOnItem
            }
            
            self.updateItemNodes(transition: .immediate, notify: transaction.focusOnItem != nil, synchronous: transaction.synchronous)
            
            //print("visible indices after update \(self.itemNodes.map { $0.index })")
        }
        else if let focusOnItem = transaction.focusOnItem {
            self.ignoreCentralItemIndexUpdate = true
            self.centralItemIndex = focusOnItem
            self.ignoreCentralItemIndexUpdate = false
            self.updateItemNodes(transition: .immediate, forceOffsetReset: true, synchronous: transaction.synchronous)
        }
    }
    
    func canGoToPreviousItem() -> Bool {
        if self.disableTapNavigation {
            return false
        }
        if let index = self.centralItemIndex, index > 0 {
            return true
        } else {
            return false
        }
    }
    
    func canGoToNextItem() -> Bool {
        if self.disableTapNavigation {
            return false
        }
        if let index = self.centralItemIndex, index < self.items.count - 1 {
            return true
        } else {
            return false
        }
    }
    
    func goToPreviousItem() {
        if let index = self.centralItemIndex, index > 0 {
            self.transaction(GalleryPagerTransaction(deleteItems: [], insertItems: [], updateItems: [], focusOnItem: index - 1, synchronous: false))
        }
    }
    
    func goToNextItem() {
        if let index = self.centralItemIndex, index < self.items.count - 1 {
            self.transaction(GalleryPagerTransaction(deleteItems: [], insertItems: [], updateItems: [], focusOnItem: index + 1, synchronous: false))
        }
    }
    
    private func makeNodeForItem(at index: Int, synchronous: Bool) -> GalleryItemNode {
        let node = self.items[index].node(synchronous: synchronous)
        node.toggleControlsVisibility = self.toggleControlsVisibility
        node.updateControlsVisibility = self.updateControlsVisibility
        node.updateOrientation = self.updateOrientation
        node.dismiss = self.dismiss
        node.beginCustomDismiss = self.beginCustomDismiss
        node.completeCustomDismiss = self.completeCustomDismiss
        node.baseNavigationController = self.baseNavigationController
        node.galleryController = self.galleryController
        node.index = index
        return node
    }
    
    private func visibleItemNode(at index: Int) -> GalleryItemNode? {
        for itemNode in self.itemNodes {
            if itemNode.index == index {
                return itemNode
            }
        }
        return nil
    }
    
    private func addVisibleItemNode(_ node: GalleryItemNode) {
        var added = false
        for i in 0 ..< self.itemNodes.count {
            if node.index < self.itemNodes[i].index {
                self.itemNodes.insert(node, at: i)
                added = true
                break
            }
        }
        if !added {
            self.itemNodes.append(node)
        }
        self.scrollView.addSubview(node.view)
    }
    
    private func removeVisibleItemNode(internalIndex: Int) {
        self.itemNodes[internalIndex].view.removeFromSuperview()
        self.itemNodes.remove(at: internalIndex)
    }
    
    private func updateItemNodes(transition: ContainedViewLayoutTransition, forceOffsetReset: Bool = false, notify: Bool = false, forceLoad: Bool = false, synchronous: Bool = false) {
        if self.items.isEmpty || self.containerLayout == nil {
            return
        }
        
        var resetOffsetToCentralItem = forceOffsetReset
        if let centralItemIndex = self.centralItemIndex, self.visibleItemNode(at: centralItemIndex) == nil, !self.itemNodes.isEmpty {
            repeat {
                self.removeVisibleItemNode(internalIndex: self.itemNodes.count - 1)
            } while self.itemNodes.count > 0
        }
        if self.itemNodes.isEmpty {
            let node = self.makeNodeForItem(at: self.centralItemIndex ?? 0, synchronous: synchronous)
            node.frame = CGRect(origin: CGPoint(), size: self.scrollView.bounds.size)
            if let containerLayout = self.containerLayout {
                node.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
            }
            self.addVisibleItemNode(node)
            self.centralItemIndex = node.index
            resetOffsetToCentralItem = true
        }
        
        var notifyCentralItemUpdated = forceOffsetReset || notify
        
        if let centralItemIndex = self.centralItemIndex, let centralItemNode = self.visibleItemNode(at: centralItemIndex) {
            if centralItemIndex != 0 {
                if self.shouldLoadItems(force: forceLoad) && self.visibleItemNode(at: centralItemIndex - 1) == nil {
                    let node = self.makeNodeForItem(at: centralItemIndex - 1, synchronous: synchronous)
                    node.frame = centralItemNode.frame.offsetBy(dx: -centralItemNode.frame.size.width - self.pageGap, dy: 0.0)
                    if let containerLayout = self.containerLayout {
                        node.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
                    }
                    self.addVisibleItemNode(node)
                }
            }
            
            if centralItemIndex != self.items.count - 1 {
                if self.shouldLoadItems(force: forceLoad) && self.visibleItemNode(at: centralItemIndex + 1) == nil {
                    let node = self.makeNodeForItem(at: centralItemIndex + 1, synchronous: synchronous)
                    node.frame = centralItemNode.frame.offsetBy(dx: centralItemNode.frame.size.width + self.pageGap, dy: 0.0)
                    if let containerLayout = self.containerLayout {
                        node.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
                    }
                    self.addVisibleItemNode(node)
                }
            }
            
            for i in 0 ..< self.itemNodes.count {
                let node = self.itemNodes[i]
                transition.updateFrame(node: node, frame: CGRect(origin: CGPoint(x: CGFloat(i) * self.scrollView.bounds.size.width + self.pageGap, y: 0.0), size: CGSize(width: self.scrollView.bounds.size.width - self.pageGap * 2.0, height: self.scrollView.bounds.size.height)))
                
                let screenFrame = node.convert(node.bounds, to: self.supernode)
                node.screenFrameUpdated(screenFrame)
            }
            
            if resetOffsetToCentralItem {
                self.scrollView.contentOffset = CGPoint(x: centralItemNode.frame.minX - self.pageGap, y: 0.0)
            }
            
            if self.shouldLoadItems(force: forceLoad), let centralItemCandidateNode = self.centralItemCandidate(), centralItemCandidateNode.index != centralItemIndex {
                for i in (0 ..< self.itemNodes.count).reversed() {
                    let node = self.itemNodes[i]
                    if node.index < centralItemCandidateNode.index - 1 || node.index > centralItemCandidateNode.index + 1 {
                        self.removeVisibleItemNode(internalIndex: i)
                    }
                }
                
                self.ignoreCentralItemIndexUpdate = true
                self.centralItemIndex = centralItemCandidateNode.index
                self.ignoreCentralItemIndexUpdate = false
                notifyCentralItemUpdated = true
                
                if centralItemCandidateNode.index != 0 {
                    if self.shouldLoadItems(force: forceLoad) && self.visibleItemNode(at: centralItemCandidateNode.index - 1) == nil {
                        let node = self.makeNodeForItem(at: centralItemCandidateNode.index - 1, synchronous: synchronous)
                        node.frame = centralItemCandidateNode.frame.offsetBy(dx: -centralItemCandidateNode.frame.size.width - self.pageGap, dy: 0.0)
                        if let containerLayout = self.containerLayout {
                            node.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
                        }
                        self.addVisibleItemNode(node)
                    }
                }
                
                if centralItemCandidateNode.index != items.count - 1 {
                    if self.shouldLoadItems(force: forceLoad) && self.visibleItemNode(at: centralItemCandidateNode.index + 1) == nil {
                        let node = self.makeNodeForItem(at: centralItemCandidateNode.index + 1, synchronous: synchronous)
                        node.frame = centralItemCandidateNode.frame.offsetBy(dx: centralItemCandidateNode.frame.size.width + self.pageGap, dy: 0.0)
                        if let containerLayout = self.containerLayout {
                            node.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
                        }
                        self.addVisibleItemNode(node)
                    }
                }
                
                let previousCentralCandidateHorizontalOffset = self.scrollView.contentOffset.x - centralItemCandidateNode.frame.minX
                
                for i in 0 ..< self.itemNodes.count {
                    let node = self.itemNodes[i]
                    transition.updateFrame(node: node, frame: CGRect(origin: CGPoint(x: CGFloat(i) * self.scrollView.bounds.size.width + self.pageGap, y: 0.0), size: CGSize(width: self.scrollView.bounds.size.width - self.pageGap * 2.0, height: self.scrollView.bounds.size.height)))
                    
                    let screenFrame = node.convert(node.bounds, to: self.supernode)
                    node.screenFrameUpdated(screenFrame)
                }
                
                self.scrollView.contentOffset = CGPoint(x: centralItemCandidateNode.frame.minX + previousCentralCandidateHorizontalOffset, y: 0.0)
            }
            
            self.scrollView.contentSize = CGSize(width: CGFloat(self.itemNodes.count) * self.scrollView.bounds.size.width, height: self.scrollView.bounds.size.height)
        } else {
            assertionFailure()
        }
        
        for itemNode in self.itemNodes {
            let isVisible = self.scrollView.bounds.intersects(itemNode.frame)
            itemNode.centralityUpdated(isCentral: itemNode.index == self.centralItemIndex)
            itemNode.visibilityUpdated(isVisible: isVisible)
            itemNode.isHidden = !isVisible
        }
        
        if notifyCentralItemUpdated {
            self.centralItemIndexUpdated(self.centralItemIndex)
        }
        
        self.updateCentralIndexOffset(transition: .immediate)
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.ignoreDidScroll {
            self.updateItemNodes(transition: .immediate)
        }
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.ensureItemsLoaded(force: false)
        }
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.ensureItemsLoaded(force: true)
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.ensureItemsLoaded(force: true)
    }
    
    private func shouldLoadItems(force: Bool) -> Bool {
        return force || (!self.scrollView.isDecelerating && !self.scrollView.isDragging)
    }
    
    private func ensureItemsLoaded(force: Bool) {
        self.updateItemNodes(transition: .immediate, forceLoad: force)
    }
    
    private func centralItemCandidate() -> GalleryItemNode? {
        let hotizontlOffset = self.scrollView.contentOffset.x + self.pageGap
        var closestNodeAndDistance: (Int, CGFloat)?
        for i in 0 ..< self.itemNodes.count {
            let node = self.itemNodes[i]
            let distance = abs(node.frame.minX - hotizontlOffset)
            if let currentClosestNodeAndDistance = closestNodeAndDistance {
                if distance < currentClosestNodeAndDistance.1 {
                    closestNodeAndDistance = (node.index, distance)
                }
            } else {
                closestNodeAndDistance = (node.index, distance)
            }
        }
        if let closestNodeAndDistance = closestNodeAndDistance {
            return self.visibleItemNode(at: closestNodeAndDistance.0)
        } else {
            return nil
        }
    }
    
    private func updateCentralIndexOffset(transition: ContainedViewLayoutTransition) {
        if let centralIndex = self.centralItemIndex, let itemNode = self.visibleItemNode(at: centralIndex) {
            let offset: CGFloat = self.scrollView.contentOffset.x + self.pageGap - itemNode.frame.minX
            var progress = offset / self.scrollView.bounds.size.width
            progress = min(1.0, progress)
            progress = max(-1.0, progress)
            self.centralItemIndexOffsetUpdated((self.invalidatedItems ? self.items : nil, centralIndex, progress))
        } else {
            self.invalidatedItems = false
            self.centralItemIndexOffsetUpdated(nil)
        }
    }

    public func forEachItemNode(_ f: (GalleryItemNode) -> Void) {
        for itemNode in self.itemNodes {
            f(itemNode)
        }
    }
}
