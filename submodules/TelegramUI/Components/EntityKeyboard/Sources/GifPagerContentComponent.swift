import Foundation
import UIKit
import Display
import ComponentFlow
import PagerComponent
import TelegramPresentationData
import TelegramCore
import Postbox
import MultiAnimationRenderer
import AnimationCache
import AccountContext
import LottieAnimationCache
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SwiftSignalKit
import ShimmerEffect
import PagerComponent
import SoftwareVideo
import AVFoundation
import PhotoResources
import ShimmerEffect
import BatchVideoRendering
import GifVideoLayer

public final class GifPagerContentComponent: Component {
    public typealias EnvironmentType = (EntityKeyboardChildEnvironment, PagerComponentChildEnvironment)
    
    public enum Subject: Equatable {
        case recent
        case trending
        case emojiSearch([String])
    }
    
    public final class InputInteraction {
        public let performItemAction: (Item, UIView, CGRect) -> Void
        public let openGifContextMenu: (Item, UIView, CGRect, ContextGesture, Bool) -> Void
        public let loadMore: (String) -> Void
        public let openSearch: () -> Void
        public let updateSearchQuery: ([String]?) -> Void
        public let hideBackground: Bool
        public let hasSearch: Bool
        
        public init(
            performItemAction: @escaping (Item, UIView, CGRect) -> Void,
            openGifContextMenu: @escaping (Item, UIView, CGRect, ContextGesture, Bool) -> Void,
            loadMore: @escaping (String) -> Void,
            openSearch: @escaping () -> Void,
            updateSearchQuery: @escaping ([String]?) -> Void,
            hideBackground: Bool,
            hasSearch: Bool
        ) {
            self.performItemAction = performItemAction
            self.openGifContextMenu = openGifContextMenu
            self.loadMore = loadMore
            self.openSearch = openSearch
            self.updateSearchQuery = updateSearchQuery
            self.hideBackground = hideBackground
            self.hasSearch = hasSearch
        }
    }
    
    public final class Item: Equatable {
        public let file: FileMediaReference
        public let contextResult: (ChatContextResultCollection, ChatContextResult)?
        
        public init(file: FileMediaReference, contextResult: (ChatContextResultCollection, ChatContextResult)?) {
            self.file = file
            self.contextResult = contextResult
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.file.media.fileId != rhs.file.media.fileId {
                return false
            }
            if (lhs.contextResult == nil) != (rhs.contextResult != nil) {
                return false
            }
            
            return true
        }
    }
    
    public let context: AccountContext
    public let inputInteraction: InputInteraction
    public let subject: Subject
    public let items: [Item]
    public let isLoading: Bool
    public let loadMoreToken: String?
    public let displaySearchWithPlaceholder: String?
    public let searchCategories: EmojiSearchCategories?
    public let searchInitiallyHidden: Bool
    public let searchState: EmojiPagerContentComponent.SearchState
    public let hideBackground: Bool
    
    public init(
        context: AccountContext,
        inputInteraction: InputInteraction,
        subject: Subject,
        items: [Item],
        isLoading: Bool,
        loadMoreToken: String?,
        displaySearchWithPlaceholder: String?,
        searchCategories: EmojiSearchCategories?,
        searchInitiallyHidden: Bool,
        searchState: EmojiPagerContentComponent.SearchState,
        hideBackground: Bool
    ) {
        self.context = context
        self.inputInteraction = inputInteraction
        self.subject = subject
        self.items = items
        self.isLoading = isLoading
        self.loadMoreToken = loadMoreToken
        self.displaySearchWithPlaceholder = displaySearchWithPlaceholder
        self.searchCategories = searchCategories
        self.searchInitiallyHidden = searchInitiallyHidden
        self.searchState = searchState
        self.hideBackground = hideBackground
    }
    
    public static func ==(lhs: GifPagerContentComponent, rhs: GifPagerContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.inputInteraction !== rhs.inputInteraction {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.isLoading != rhs.isLoading {
            return false
        }
        if lhs.loadMoreToken != rhs.loadMoreToken {
            return false
        }
        if lhs.displaySearchWithPlaceholder != rhs.displaySearchWithPlaceholder {
            return false
        }
        if lhs.searchCategories != rhs.searchCategories {
            return false
        }
        if lhs.searchInitiallyHidden != rhs.searchInitiallyHidden {
            return false
        }
        if lhs.searchState != rhs.searchState {
            return false
        }
        if lhs.hideBackground != rhs.hideBackground {
            return false
        }
        return true
    }
    
    
    public final class View: ContextControllerSourceView, PagerContentViewWithBackground, UIScrollViewDelegate {
        private struct ItemGroupDescription: Equatable {
            let hasTitle: Bool
            let itemCount: Int
        }
        
        private struct ItemGroupLayout: Equatable {
            let frame: CGRect
            let itemTopOffset: CGFloat
            let itemCount: Int
        }
        
        private struct ItemLayout: Equatable {
            let width: CGFloat
            let containerInsets: UIEdgeInsets
            let itemCount: Int
            let itemSize: CGFloat
            let horizontalSpacing: CGFloat
            let verticalSpacing: CGFloat
            let itemsPerRow: Int
            let contentSize: CGSize
            
            var searchInsets: UIEdgeInsets
            var searchHeight: CGFloat
            
            init(width: CGFloat, containerInsets: UIEdgeInsets, itemCount: Int) {
                self.width = width
                self.containerInsets = containerInsets
                self.itemCount = itemCount
                self.horizontalSpacing = 1.0
                self.verticalSpacing = 1.0
                
                self.searchHeight = 54.0
                self.searchInsets = UIEdgeInsets(top: max(0.0, containerInsets.top + 1.0), left: containerInsets.left, bottom: 0.0, right: containerInsets.right)
                
                let defaultItemSize: CGFloat = 120.0
                
                let itemHorizontalSpace = width - self.containerInsets.left - self.containerInsets.right
                var itemsPerRow = Int(floor((itemHorizontalSpace) / (defaultItemSize)))
                itemsPerRow = max(3, itemsPerRow)
                
                self.itemsPerRow = itemsPerRow
                
                self.itemSize = floor((itemHorizontalSpace - self.horizontalSpacing * CGFloat(itemsPerRow - 1)) / CGFloat(itemsPerRow))
                
                let numRowsInGroup = (itemCount + (self.itemsPerRow - 1)) / self.itemsPerRow
                self.contentSize = CGSize(width: width, height: self.searchInsets.top + self.searchHeight + self.containerInsets.top + self.containerInsets.bottom + CGFloat(numRowsInGroup) * self.itemSize + CGFloat(max(0, numRowsInGroup - 1)) * self.verticalSpacing)
            }
            
            func frame(at index: Int) -> CGRect {
                let row = index / self.itemsPerRow
                let column = index % self.itemsPerRow
                
                var rect = CGRect(
                    origin: CGPoint(
                        x: self.containerInsets.left + CGFloat(column) * (self.itemSize + self.horizontalSpacing),
                        y: self.containerInsets.top + CGFloat(row) * (self.itemSize + self.verticalSpacing)
                    ),
                    size: CGSize(
                        width: self.itemSize,
                        height: self.itemSize
                    )
                )
                
                if column == self.itemsPerRow - 1 && index < self.itemCount - 1 {
                    rect.size.width = self.width - self.containerInsets.right - rect.minX
                }
                
                return rect
            }
            
            func visibleItems(for rect: CGRect) -> Range<Int>? {
                let offsetRect = rect.offsetBy(dx: -self.containerInsets.left, dy: -containerInsets.top)
                var minVisibleRow = Int(floor((offsetRect.minY - self.searchHeight - self.verticalSpacing) / (self.itemSize + self.verticalSpacing)))
                minVisibleRow = max(0, minVisibleRow)
                let maxVisibleRow = Int(ceil((offsetRect.maxY - self.verticalSpacing) / (self.itemSize + self.verticalSpacing)))
                
                let minVisibleIndex = minVisibleRow * self.itemsPerRow
                let maxVisibleIndex = (maxVisibleRow + 1) * self.itemsPerRow - 1
                
                if maxVisibleIndex >= minVisibleIndex {
                    return minVisibleIndex ..< (maxVisibleIndex + 1)
                } else {
                    return nil
                }
            }
        }
        
        fileprivate enum ItemKey: Hashable {
            case media(MediaId)
            case placeholder(Int)
        }
        
        fileprivate final class ItemLayer: GifVideoLayer {
            let item: Item?
            
            private var disposable: Disposable?
            private var fetchDisposable: Disposable?
            
            private var isInHierarchyValue: Bool = false
            public var isVisibleForAnimations: Bool = false {
                didSet {
                    if self.isVisibleForAnimations != oldValue {
                        self.updatePlayback()
                    }
                }
            }
            private(set) var displayPlaceholder: Bool = false
            let onUpdateDisplayPlaceholder: (Bool, Double) -> Void
            
            init(
                item: Item?,
                context: AccountContext,
                batchVideoContext: BatchVideoRenderingContext,
                groupId: String,
                attemptSynchronousLoad: Bool,
                onUpdateDisplayPlaceholder: @escaping (Bool, Double) -> Void
            ) {
                self.item = item
                self.onUpdateDisplayPlaceholder = onUpdateDisplayPlaceholder
                
                super.init(context: context, batchVideoContext: batchVideoContext, userLocation: .other, file: item?.file, synchronousLoad: attemptSynchronousLoad)
                
                if item == nil {
                    self.updateDisplayPlaceholder(displayPlaceholder: true, duration: 0.0)
                }
                
                self.started = { [weak self] in
                    let _ = self
                    //self?.updateDisplayPlaceholder(displayPlaceholder: false, duration: 0.2)
                }
            }
            
            override init(layer: Any) {
                self.item = nil
                self.onUpdateDisplayPlaceholder = { _, _ in }
                
                super.init(layer: layer)
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            deinit {
                self.disposable?.dispose()
                self.fetchDisposable?.dispose()
            }
            
            override func action(forKey event: String) -> CAAction? {
                if event == kCAOnOrderIn {
                    self.isInHierarchyValue = true
                } else if event == kCAOnOrderOut {
                    self.isInHierarchyValue = false
                }
                self.updatePlayback()
                return nullAction
            }
            
            private func updatePlayback() {
                let shouldBePlaying = self.isInHierarchyValue && self.isVisibleForAnimations
                
                self.shouldBeAnimating = shouldBePlaying
            }
            
            func updateDisplayPlaceholder(displayPlaceholder: Bool, duration: Double) {
                if self.displayPlaceholder == displayPlaceholder {
                    return
                }
                self.displayPlaceholder = displayPlaceholder
                self.onUpdateDisplayPlaceholder(displayPlaceholder, duration)
            }
        }
        
        final class ItemPlaceholderView: UIView {
            private let shimmerView: PortalSourceView?
            private var placeholderView: PortalView?
            
            init(shimmerView: PortalSourceView?) {
                self.shimmerView = shimmerView
                self.placeholderView = PortalView()
                
                super.init(frame: CGRect())
                
                self.clipsToBounds = true
                
                if let placeholderView = self.placeholderView, let shimmerView = self.shimmerView {
                    placeholderView.view.clipsToBounds = true
                    self.addSubview(placeholderView.view)
                    shimmerView.addPortal(view: placeholderView)
                }
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            func update(size: CGSize) {
                if let placeholderView = self.placeholderView {
                    placeholderView.view.frame = CGRect(origin: CGPoint(), size: size)
                }
            }
        }
        
        private final class SearchHeaderContainer: UIView {
            override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
                var result: UIView?
                for subview in self.subviews.reversed() {
                    if let value = subview.hitTest(self.convert(point, to: subview), with: event) {
                        result = value
                        break
                    }
                }
                return result
            }
        }
        
        public final class ContentScrollLayer: CALayer {
            public var mirrorLayer: CALayer?
            
            override public init() {
                super.init()
            }
            
            override public init(layer: Any) {
                super.init(layer: layer)
            }
            
            required public init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            override public var position: CGPoint {
                get {
                    return super.position
                } set(value) {
                    if let mirrorLayer = self.mirrorLayer {
                        mirrorLayer.position = value
                    }
                    super.position = value
                }
            }
            
            override public var bounds: CGRect {
                get {
                    return super.bounds
                } set(value) {
                    if let mirrorLayer = self.mirrorLayer {
                        mirrorLayer.bounds = value
                    }
                    super.bounds = value
                }
            }
            
            override public func add(_ animation: CAAnimation, forKey key: String?) {
                if let mirrorLayer = self.mirrorLayer {
                    mirrorLayer.add(animation, forKey: key)
                }
                
                super.add(animation, forKey: key)
            }
            
            override public func removeAllAnimations() {
                if let mirrorLayer = self.mirrorLayer {
                    mirrorLayer.removeAllAnimations()
                }
                
                super.removeAllAnimations()
            }
            
            override public func removeAnimation(forKey: String) {
                if let mirrorLayer = self.mirrorLayer {
                    mirrorLayer.removeAnimation(forKey: forKey)
                }
                
                super.removeAnimation(forKey: forKey)
            }
        }
        
        private final class ContentScrollView: UIScrollView, PagerExpandableScrollView {
            override static var layerClass: AnyClass {
                return ContentScrollLayer.self
            }
            
            private let mirrorView: UIView
            
            init(mirrorView: UIView) {
                self.mirrorView = mirrorView
                
                super.init(frame: CGRect())
                
                (self.layer as? ContentScrollLayer)?.mirrorLayer = mirrorView.layer
                self.canCancelContentTouches = true
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            override func touchesShouldCancel(in view: UIView) -> Bool {
                return true
            }
        }
        
        private let shimmerHostView: PortalSourceView
        private let standaloneShimmerEffect: StandaloneShimmerEffect
        
        private let backgroundView: BlurredBackgroundView
        private let backgroundTintView: UIView
        private var vibrancyEffectView: UIView?
        private let mirrorContentScrollView: UIView
        private let scrollView: ContentScrollView
        private let scrollClippingView: UIView
        
        private let placeholdersContainerView: UIView
        private var visibleSearchHeader: EmojiSearchHeaderView?
        private let searchHeaderContainer: SearchHeaderContainer
        private let mirrorSearchHeaderContainer: UIView
        private var visibleItemPlaceholderViews: [ItemKey: ItemPlaceholderView] = [:]
        private var visibleItemLayers: [ItemKey: ItemLayer] = [:]
        private var ignoreScrolling: Bool = false
        
        private var component: GifPagerContentComponent?
        private var pagerEnvironment: PagerComponentChildEnvironment?
        private var theme: PresentationTheme?
        private var itemLayout: ItemLayout?
        private var batchVideoContext: BatchVideoRenderingContext?
        
        private var currentLoadMoreToken: String?
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: nil)
            self.backgroundTintView = UIView()
            
            self.shimmerHostView = PortalSourceView()
            self.standaloneShimmerEffect = StandaloneShimmerEffect()
            
            self.placeholdersContainerView = UIView()
            
            self.mirrorContentScrollView = UIView()
            self.mirrorContentScrollView.layer.anchorPoint = CGPoint()
            self.mirrorContentScrollView.clipsToBounds = true
            self.scrollView = ContentScrollView(mirrorView: self.mirrorContentScrollView)
            self.scrollView.layer.anchorPoint = CGPoint()
            
            self.searchHeaderContainer = SearchHeaderContainer()
            self.searchHeaderContainer.layer.anchorPoint = CGPoint()
            self.mirrorSearchHeaderContainer = UIView()
            self.mirrorSearchHeaderContainer.layer.anchorPoint = CGPoint()
            
            self.scrollClippingView = UIView()
            self.scrollClippingView.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.backgroundView.addSubview(self.backgroundTintView)
            self.addSubview(self.backgroundView)
            
            self.shimmerHostView.alpha = 0.0
            self.addSubview(self.shimmerHostView)
            
            self.scrollView.delaysContentTouches = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            
            self.scrollClippingView.addSubview(self.scrollView)
            self.addSubview(self.scrollClippingView)
            
            self.scrollView.addSubview(self.placeholdersContainerView)
            self.addSubview(self.searchHeaderContainer)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
            
            self.isMultipleTouchEnabled = false
            
            self.useSublayerTransformForActivation = false
            self.shouldBegin = { [weak self] point in
                guard let strongSelf = self else {
                    return false
                }
                strongSelf.targetLayerForActivationProgress = nil
                if let (_, itemLayer) = strongSelf.itemLayer(atPoint: point) {
                    strongSelf.targetLayerForActivationProgress = itemLayer
                    return true
                }
                return false
            }
            self.activated = { [weak self] gesture, location in
                guard let strongSelf = self, let component = strongSelf.component else {
                    gesture.cancel()
                    return
                }
                guard let (item, itemLayer) = strongSelf.itemLayer(atPoint: location) else {
                    gesture.cancel()
                    return
                }
                let rect = strongSelf.scrollView.convert(itemLayer.frame, to: strongSelf)
                component.inputInteraction.openGifContextMenu(item, strongSelf, rect, gesture, component.subject == .recent)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func openGifContextMenu(item: Item, sourceView: UIView, sourceRect: CGRect, gesture: ContextGesture, isSaved: Bool) {
            guard let component = self.component else {
                return
            }
            component.inputInteraction.openGifContextMenu(item, sourceView, sourceRect, gesture, isSaved)
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                if let component = self.component, let item = self.item(atPoint: recognizer.location(in: self)), let itemView = self.visibleItemLayers[.media(item.file.media.fileId)] {
                    component.inputInteraction.performItemAction(item, self, self.scrollView.convert(itemView.frame, to: self))
                }
            }
        }
        
        private func item(atPoint point: CGPoint) -> Item? {
            let localPoint = self.convert(point, to: self.scrollView)
            
            for (_, itemLayer) in self.visibleItemLayers {
                if itemLayer.frame.contains(localPoint) {
                    return itemLayer.item
                }
            }
            
            return nil
        }
        
        private func itemLayer(atPoint point: CGPoint) -> (Item, ItemLayer)? {
            let localPoint = self.convert(point, to: self.scrollView)
            
            for (_, itemLayer) in self.visibleItemLayers {
                if itemLayer.frame.contains(localPoint) {
                    if let item = itemLayer.item {
                        return (item, itemLayer)
                    } else {
                        return nil
                    }
                }
            }
            
            return nil
        }
        
        private var previousScrollingOffset: CGFloat?
        
        public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            if let presentation = scrollView.layer.presentation() {
                scrollView.bounds = presentation.bounds
                scrollView.layer.removeAllAnimations()
            }
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if self.ignoreScrolling {
                return
            }
            
            self.updateVisibleItems(attemptSynchronousLoads: false, transition: .immediate, fromScrolling: true)
            
            self.updateScrollingOffset(transition: .immediate)
            
            if scrollView.contentOffset.y >= scrollView.contentSize.height - scrollView.bounds.height - 100.0 {
                if let component = self.component, let loadMoreToken = component.loadMoreToken, self.currentLoadMoreToken != loadMoreToken {
                    self.currentLoadMoreToken = loadMoreToken
                    component.inputInteraction.loadMore(loadMoreToken)
                }
            }
        }
        
        public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            if velocity.y != 0.0 {
                targetContentOffset.pointee.y = self.snappedContentOffset(proposedOffset: targetContentOffset.pointee.y)
            }
        }
        
        public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                self.snapScrollingOffsetToInsets()
            }
        }
        
        public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            self.snapScrollingOffsetToInsets()
        }
        
        private func updateScrollingOffset(transition: ComponentTransition) {
            let isInteracting = self.scrollView.isDragging || self.scrollView.isDecelerating
            if let previousScrollingOffsetValue = self.previousScrollingOffset {
                let currentBounds = self.scrollView.bounds
                var offsetToTopEdge = max(0.0, currentBounds.minY - 0.0)
                var offsetToBottomEdge = max(0.0, self.scrollView.contentSize.height - currentBounds.maxY)
                
                if self.scrollView.contentSize.height < self.scrollView.bounds.height * 2.0 {
                    offsetToTopEdge = 0.0
                    offsetToBottomEdge = self.scrollView.contentSize.height
                }
                
                let relativeOffset = self.scrollView.contentOffset.y - previousScrollingOffsetValue
                self.pagerEnvironment?.onChildScrollingUpdate(PagerComponentChildEnvironment.ContentScrollingUpdate(
                    relativeOffset: relativeOffset,
                    absoluteOffsetToTopEdge: offsetToTopEdge,
                    absoluteOffsetToBottomEdge: offsetToBottomEdge,
                    isReset: false,
                    isInteracting: isInteracting,
                    transition: transition
                ))
                self.previousScrollingOffset = self.scrollView.contentOffset.y
            }
            self.previousScrollingOffset = self.scrollView.contentOffset.y
        }
        
        private func snappedContentOffset(proposedOffset: CGFloat) -> CGFloat {
            guard let pagerEnvironment = self.pagerEnvironment, let itemLayout = self.itemLayout else {
                return proposedOffset
            }
            
            var proposedOffset = proposedOffset
            let bounds = self.bounds
            if proposedOffset <= itemLayout.searchInsets.top + itemLayout.searchHeight * 0.5 {
                proposedOffset = 0.0
            } else if proposedOffset + bounds.height > self.scrollView.contentSize.height - pagerEnvironment.containerInsets.bottom {
                proposedOffset = self.scrollView.contentSize.height - bounds.height
            }
            if proposedOffset < pagerEnvironment.containerInsets.top {
                proposedOffset = 0.0
            }
            
            return proposedOffset
        }
        
        private func snapScrollingOffsetToInsets() {
            let transition = ComponentTransition(animation: .curve(duration: 0.4, curve: .spring))
            
            var currentBounds = self.scrollView.bounds
            currentBounds.origin.y = self.snappedContentOffset(proposedOffset: currentBounds.minY)
            transition.setBounds(view: self.scrollView, bounds: currentBounds)
            
            self.updateScrollingOffset(transition: transition)
            self.updateVisibleItems(attemptSynchronousLoads: false, transition: transition, fromScrolling: true)
        }
        
        private func updateVisibleItems(attemptSynchronousLoads: Bool, transition: ComponentTransition, fromScrolling: Bool) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            var validIds = Set<ItemKey>()
            
            var searchInset: CGFloat = 0.0
            if let _ = component.displaySearchWithPlaceholder {
                searchInset += itemLayout.searchHeight
            }
            
            let batchVideoContext: BatchVideoRenderingContext
            if let current = self.batchVideoContext {
                batchVideoContext = current
            } else {
                batchVideoContext = BatchVideoRenderingContext(context: component.context)
                self.batchVideoContext = batchVideoContext
            }
            
            if let itemRange = itemLayout.visibleItems(for: self.scrollView.bounds) {
                for index in itemRange.lowerBound ..< itemRange.upperBound {
                    var item: Item?
                    let itemId: ItemKey
                    if index < component.items.count {
                        item = component.items[index]
                        itemId = .media(component.items[index].file.media.fileId)
                    } else if component.isLoading || component.loadMoreToken != nil {
                        itemId = .placeholder(index)
                    } else {
                        continue
                    }
                    
                    if !component.isLoading {
                        if let placeholderView = self.visibleItemPlaceholderViews.removeValue(forKey: .placeholder(index)) {
                            self.visibleItemPlaceholderViews[itemId] = placeholderView
                        }
                    }
                        
                    validIds.insert(itemId)
                    
                    let itemFrame = itemLayout.frame(at: index).offsetBy(dx: 0.0, dy: searchInset)
                    
                    var itemTransition: ComponentTransition = transition
                    var updateItemLayerPlaceholder = false
                    
                    let itemLayer: ItemLayer
                    if let current = self.visibleItemLayers[itemId] {
                        itemLayer = current
                    } else {
                        updateItemLayerPlaceholder = true
                        itemTransition = .immediate
                        
                        itemLayer = ItemLayer(
                            item: item,
                            context: component.context,
                            batchVideoContext: batchVideoContext,
                            groupId: "savedGif",
                            attemptSynchronousLoad: attemptSynchronousLoads,
                            onUpdateDisplayPlaceholder: { [weak self] displayPlaceholder, duration in
                                guard let strongSelf = self else {
                                    return
                                }
                                if displayPlaceholder {
                                    if let itemLayer = strongSelf.visibleItemLayers[itemId] {
                                        let placeholderView: ItemPlaceholderView
                                        if let current = strongSelf.visibleItemPlaceholderViews[itemId] {
                                            placeholderView = current
                                        } else {
                                            placeholderView = ItemPlaceholderView(shimmerView: strongSelf.shimmerHostView)
                                            strongSelf.visibleItemPlaceholderViews[itemId] = placeholderView
                                            strongSelf.placeholdersContainerView.addSubview(placeholderView)
                                        }
                                        placeholderView.frame = itemLayer.frame
                                        placeholderView.update(size: placeholderView.bounds.size)
                                        
                                        strongSelf.updateShimmerIfNeeded()
                                    }
                                } else {
                                    if let placeholderView = strongSelf.visibleItemPlaceholderViews[itemId] {
                                        strongSelf.visibleItemPlaceholderViews.removeValue(forKey: itemId)
                                        if duration > 0.0 {
                                            if let itemLayer = strongSelf.visibleItemLayers[itemId] {
                                                itemLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
                                            }
                                            
                                            placeholderView.alpha = 0.0
                                            placeholderView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, completion: { [weak self, weak placeholderView] _ in
                                                placeholderView?.removeFromSuperview()
                                                self?.updateShimmerIfNeeded()
                                            })
                                        } else {
                                            placeholderView.removeFromSuperview()
                                            strongSelf.updateShimmerIfNeeded()
                                        }
                                    }
                                }
                            }
                        )
                        self.scrollView.layer.addSublayer(itemLayer)
                        self.visibleItemLayers[itemId] = itemLayer
                    }
                    
                    let itemPosition = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
                    let itemBounds = CGRect(origin: CGPoint(), size: itemFrame.size)
                    
                    //itemTransition.setFrame(layer: itemLayer, frame: itemFrame)
                    itemLayer.bounds = CGRect(origin: CGPoint(), size: itemFrame.size)
                    itemTransition.setPosition(layer: itemLayer, position: itemFrame.center)
                    
                    itemLayer.isVisibleForAnimations = true
                    
                    if let placeholderView = self.visibleItemPlaceholderViews[itemId] {
                        if placeholderView.layer.position != itemPosition || placeholderView.layer.bounds != itemBounds {
                            itemTransition.setFrame(view: placeholderView, frame: itemFrame)
                            placeholderView.update(size: itemFrame.size)
                        }
                    }
                    
                    if updateItemLayerPlaceholder {
                        if itemLayer.displayPlaceholder {
                            itemLayer.onUpdateDisplayPlaceholder(true, 0.0)
                        } else {
                            itemLayer.onUpdateDisplayPlaceholder(false, 0.2)
                        }
                    }
                }
            }

            var removedIds: [ItemKey] = []
            for (id, itemLayer) in self.visibleItemLayers {
                if !validIds.contains(id) {
                    removedIds.append(id)
                    itemLayer.removeFromSuperlayer()
                    
                    if let view = self.visibleItemPlaceholderViews.removeValue(forKey: id) {
                        view.removeFromSuperview()
                    }
                }
            }
            for id in removedIds {
                self.visibleItemLayers.removeValue(forKey: id)
            }
            
            transition.setPosition(view: self.searchHeaderContainer, position: self.scrollView.center)
            var searchContainerBounds = self.scrollView.bounds
            if case .emojiSearch = component.subject {
                searchContainerBounds.origin.y = 0.0
            }
            transition.setBounds(view: self.searchHeaderContainer, bounds: searchContainerBounds)
            
            transition.setPosition(view: self.mirrorSearchHeaderContainer, position: self.scrollView.center)
            transition.setBounds(view: self.mirrorSearchHeaderContainer, bounds: searchContainerBounds)
        }
        
        private func updateShimmerIfNeeded() {
            if self.placeholdersContainerView.subviews.isEmpty {
                self.standaloneShimmerEffect.layer = nil
            } else {
                self.standaloneShimmerEffect.layer = self.shimmerHostView.layer
            }
        }
        
        public func pagerUpdateBackground(backgroundFrame: CGRect, topPanelHeight: CGFloat, transition: ComponentTransition) {
            guard let theme = self.theme else {
                return
            }
            if theme.overallDarkAppearance {
                if let vibrancyEffectView = self.vibrancyEffectView {
                    self.vibrancyEffectView = nil
                    vibrancyEffectView.removeFromSuperview()
                }
            } else {
                if self.vibrancyEffectView == nil {
                    let vibrancyEffectView = UIView()
                    vibrancyEffectView.backgroundColor = .white
                    if let filter = CALayer.luminanceToAlpha() {
                        vibrancyEffectView.layer.filters = [filter]
                    }
                    self.vibrancyEffectView = vibrancyEffectView
                    self.backgroundTintView.mask = vibrancyEffectView
                    vibrancyEffectView.addSubview(self.mirrorContentScrollView)
                    vibrancyEffectView.addSubview(self.mirrorSearchHeaderContainer)
                }
            }
            
            let hideBackground = self.component?.hideBackground ?? false
            var backgroundColor = theme.chat.inputMediaPanel.backgroundColor
            if hideBackground {
                backgroundColor = backgroundColor.withAlphaComponent(0.01)
            }
            
            self.backgroundTintView.backgroundColor = backgroundColor
            transition.setFrame(view: self.backgroundTintView, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
            
            self.backgroundView.updateColor(color: .clear, enableBlur: true, forceKeepBlur: true, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            self.backgroundView.update(size: backgroundFrame.size, transition: transition.containedViewLayoutTransition)
            
            if let vibrancyEffectView = self.vibrancyEffectView {
                transition.setFrame(view: vibrancyEffectView, frame: CGRect(origin: CGPoint(x: 0.0, y: -backgroundFrame.minY), size: CGSize(width: backgroundFrame.width, height: backgroundFrame.height + backgroundFrame.minY)))
            }
        }
        
        func update(component: GifPagerContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            var contentReset = false
            if let previousComponent = self.component, previousComponent.subject != component.subject {
                contentReset = true
                self.currentLoadMoreToken = nil
            }
            
            let keyboardChildEnvironment = environment[EntityKeyboardChildEnvironment.self].value
            
            self.component = component
            self.theme = keyboardChildEnvironment.theme
            
            let pagerEnvironment = environment[PagerComponentChildEnvironment.self].value
            self.pagerEnvironment = pagerEnvironment
            
            transition.setFrame(view: self.shimmerHostView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            let shimmerBackgroundColor = keyboardChildEnvironment.theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.08)
            let shimmerForegroundColor = keyboardChildEnvironment.theme.list.itemBlocksBackgroundColor.withMultipliedAlpha(0.15)
            self.standaloneShimmerEffect.update(background: shimmerBackgroundColor, foreground: shimmerForegroundColor)
            
            let itemLayout = ItemLayout(
                width: availableSize.width,
                containerInsets: UIEdgeInsets(top: pagerEnvironment.containerInsets.top, left: pagerEnvironment.containerInsets.left, bottom: pagerEnvironment.containerInsets.bottom, right: pagerEnvironment.containerInsets.right),
                itemCount: component.items.count
            )
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            let scrollOriginY: CGFloat = 0.0
            let scrollSize = CGSize(width: availableSize.width, height: availableSize.height)
            
            transition.setPosition(view: self.scrollView, position: CGPoint(x: 0.0, y: scrollOriginY))
            self.scrollView.bounds = CGRect(origin: self.scrollView.bounds.origin, size: scrollSize)
            
            if self.scrollView.contentSize != itemLayout.contentSize {
                self.scrollView.contentSize = itemLayout.contentSize
            }
            if self.scrollView.scrollIndicatorInsets != pagerEnvironment.containerInsets {
                self.scrollView.scrollIndicatorInsets = pagerEnvironment.containerInsets
            }
            
            if contentReset {
                self.scrollView.setContentOffset(CGPoint(), animated: false)
            }
            
            self.previousScrollingOffset = self.scrollView.contentOffset.y
            self.ignoreScrolling = false
            
            if let displaySearchWithPlaceholder = component.displaySearchWithPlaceholder {
                let visibleSearchHeader: EmojiSearchHeaderView
                if let current = self.visibleSearchHeader {
                    visibleSearchHeader = current
                } else {
                    visibleSearchHeader = EmojiSearchHeaderView(activated: { [weak self] isTextInput in
                        guard let strongSelf = self else {
                            return
                        }
                        if isTextInput {
                            strongSelf.component?.inputInteraction.openSearch()
                        }
                    }, deactivated: { _ in
                    }, updateQuery: { [weak self] query in
                        guard let self, let component = self.component else {
                            return
                        }
                        switch query {
                        case .none:
                            component.inputInteraction.updateSearchQuery(nil)
                        case .text:
                            break
                        case let .category(value):
                            component.inputInteraction.updateSearchQuery(value.identifiers)
                        }
                    })
                    self.visibleSearchHeader = visibleSearchHeader
                    self.searchHeaderContainer.addSubview(visibleSearchHeader)
                    self.mirrorSearchHeaderContainer.addSubview(visibleSearchHeader.tintContainerView)
                }
                
                let searchHeaderFrame = CGRect(origin: CGPoint(x: itemLayout.searchInsets.left, y: itemLayout.searchInsets.top), size: CGSize(width: itemLayout.width - itemLayout.searchInsets.left - itemLayout.searchInsets.right, height: itemLayout.searchHeight))
                visibleSearchHeader.update(context: component.context, theme: keyboardChildEnvironment.theme, forceNeedsVibrancy: false, strings: keyboardChildEnvironment.strings, text: displaySearchWithPlaceholder, useOpaqueTheme: false, isActive: false, size: searchHeaderFrame.size, canFocus: false, searchCategories: component.searchCategories, searchState: component.searchState, transition: transition)
                transition.setFrame(view: visibleSearchHeader, frame: searchHeaderFrame, completion: { [weak self] completed in
                    let _ = self
                    let _ = completed
                    /*guard let strongSelf = self, completed, let visibleSearchHeader = strongSelf.visibleSearchHeader else {
                        return
                    }
                    
                    if visibleSearchHeader.superview != strongSelf.scrollView {
                        strongSelf.scrollView.addSubview(visibleSearchHeader)
                        strongSelf.mirrorSearchHeaderContainer.addSubview(visibleSearchHeader.tintContainerView)
                    }*/
                })
            } else {
                if let visibleSearchHeader = self.visibleSearchHeader {
                    self.visibleSearchHeader = nil
                    visibleSearchHeader.removeFromSuperview()
                    visibleSearchHeader.tintContainerView.removeFromSuperview()
                }
            }
            
            self.updateVisibleItems(attemptSynchronousLoads: true, transition: transition, fromScrolling: false)
            
            var clippingInset: CGFloat = 0.0
            if case .emojiSearch = component.subject {
                clippingInset = itemLayout.searchInsets.top + itemLayout.searchHeight - 1.0
            }
            let clippingFrame = CGRect(origin: CGPoint(x: 0.0, y: clippingInset), size: CGSize(width: availableSize.width, height: availableSize.height - clippingInset))
            transition.setPosition(view: self.scrollClippingView, position: clippingFrame.center)
            transition.setBounds(view: self.scrollClippingView, bounds: clippingFrame)
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
