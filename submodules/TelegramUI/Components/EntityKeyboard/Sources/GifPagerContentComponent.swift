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
//import ContextUI
import ShimmerEffect

private class GifVideoLayer: AVSampleBufferDisplayLayer {
    private let context: AccountContext
    private let file: TelegramMediaFile?
    
    private var frameManager: SoftwareVideoLayerFrameManager?
    
    private var thumbnailDisposable: Disposable?
    
    private var playbackTimestamp: Double = 0.0
    private var playbackTimer: SwiftSignalKit.Timer?
    
    var started: (() -> Void)?
    
    var shouldBeAnimating: Bool = false {
        didSet {
            if self.shouldBeAnimating == oldValue {
                return
            }
            
            if self.shouldBeAnimating {
                self.playbackTimer?.invalidate()
                let startTimestamp = self.playbackTimestamp + CFAbsoluteTimeGetCurrent()
                self.playbackTimer = SwiftSignalKit.Timer(timeout: 1.0 / 30.0, repeat: true, completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    let timestamp = CFAbsoluteTimeGetCurrent() - startTimestamp
                    strongSelf.frameManager?.tick(timestamp: timestamp)
                    strongSelf.playbackTimestamp = timestamp
                }, queue: .mainQueue())
                self.playbackTimer?.start()
            } else {
                self.playbackTimer?.invalidate()
                self.playbackTimer = nil
            }
        }
    }
    
    init(context: AccountContext, file: TelegramMediaFile?, synchronousLoad: Bool) {
        self.context = context
        self.file = file
        
        super.init()
        
        self.videoGravity = .resizeAspectFill
        
        if let file = self.file {
            if let dimensions = file.dimensions {
                self.thumbnailDisposable = (mediaGridMessageVideo(postbox: context.account.postbox, videoReference: .savedGif(media: file), synchronousLoad: synchronousLoad, nilForEmptyResult: true)
                |> deliverOnMainQueue).start(next: { [weak self] transform in
                    guard let strongSelf = self else {
                        return
                    }
                    let boundingSize = CGSize(width: 93.0, height: 93.0)
                    let imageSize = dimensions.cgSize.aspectFilled(boundingSize)
                    
                    if let image = transform(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets(), resizeMode: .fill(.clear)))?.generateImage() {
                        Queue.mainQueue().async {
                            if let strongSelf = self {
                                strongSelf.contents = image.cgImage
                                strongSelf.setupVideo()
                                strongSelf.started?()
                            }
                        }
                    } else {
                        strongSelf.setupVideo()
                    }
                })
            } else {
                self.setupVideo()
            }
        }
    }
    
    override init(layer: Any) {
        preconditionFailure()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.thumbnailDisposable?.dispose()
    }
    
    private func setupVideo() {
        guard let file = self.file else {
            return
        }
        let frameManager = SoftwareVideoLayerFrameManager(account: self.context.account, fileReference: .savedGif(media: file), layerHolder: nil, layer: self)
        self.frameManager = frameManager
        frameManager.started = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let _ = strongSelf
        }
        frameManager.start()
    }
}

public final class GifPagerContentComponent: Component {
    public typealias EnvironmentType = (EntityKeyboardChildEnvironment, PagerComponentChildEnvironment)
    
    public enum Subject: Equatable {
        case recent
        case trending
        case emojiSearch(String)
    }
    
    public final class InputInteraction {
        public let performItemAction: (Item, UIView, CGRect) -> Void
        public let openGifContextMenu: (Item, UIView, CGRect, ContextGesture, Bool) -> Void
        public let loadMore: (String) -> Void
        
        public init(
            performItemAction: @escaping (Item, UIView, CGRect) -> Void,
            openGifContextMenu: @escaping (Item, UIView, CGRect, ContextGesture, Bool) -> Void,
            loadMore: @escaping (String) -> Void
        ) {
            self.performItemAction = performItemAction
            self.openGifContextMenu = openGifContextMenu
            self.loadMore = loadMore
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
    
    public init(
        context: AccountContext,
        inputInteraction: InputInteraction,
        subject: Subject,
        items: [Item],
        isLoading: Bool,
        loadMoreToken: String?
    ) {
        self.context = context
        self.inputInteraction = inputInteraction
        self.subject = subject
        self.items = items
        self.isLoading = isLoading
        self.loadMoreToken = loadMoreToken
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
            
            init(width: CGFloat, containerInsets: UIEdgeInsets, itemCount: Int) {
                self.width = width
                self.containerInsets = containerInsets
                self.itemCount = itemCount
                self.horizontalSpacing = 1.0
                self.verticalSpacing = 1.0
                
                let defaultItemSize: CGFloat = 120.0
                
                let itemHorizontalSpace = width - self.containerInsets.left - self.containerInsets.right
                var itemsPerRow = Int(floor((itemHorizontalSpace) / (defaultItemSize)))
                itemsPerRow = max(3, itemsPerRow)
                
                self.itemsPerRow = itemsPerRow
                
                self.itemSize = floor((itemHorizontalSpace - self.horizontalSpacing * CGFloat(itemsPerRow - 1)) / CGFloat(itemsPerRow))
                
                let numRowsInGroup = (itemCount + (self.itemsPerRow - 1)) / self.itemsPerRow
                self.contentSize = CGSize(width: width, height: self.containerInsets.top + self.containerInsets.bottom + CGFloat(numRowsInGroup) * self.itemSize + CGFloat(max(0, numRowsInGroup - 1)) * self.verticalSpacing)
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
                var minVisibleRow = Int(floor((offsetRect.minY - self.verticalSpacing) / (self.itemSize + self.verticalSpacing)))
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
                groupId: String,
                attemptSynchronousLoad: Bool,
                onUpdateDisplayPlaceholder: @escaping (Bool, Double) -> Void
            ) {
                self.item = item
                self.onUpdateDisplayPlaceholder = onUpdateDisplayPlaceholder
                
                super.init(context: context, file: item?.file.media, synchronousLoad: attemptSynchronousLoad)
                
                if item == nil {
                    self.updateDisplayPlaceholder(displayPlaceholder: true, duration: 0.0)
                }
                
                self.started = { [weak self] in
                    let _ = self
                    //self?.updateDisplayPlaceholder(displayPlaceholder: false, duration: 0.2)
                }
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
        
        private final class ContentScrollView: UIScrollView, PagerExpandableScrollView {
        }
        
        private let backgroundView: BlurredBackgroundView
        
        private let shimmerHostView: PortalSourceView
        private let standaloneShimmerEffect: StandaloneShimmerEffect
        
        private let scrollView: ContentScrollView
        
        private let placeholdersContainerView: UIView
        private var visibleItemPlaceholderViews: [ItemKey: ItemPlaceholderView] = [:]
        private var visibleItemLayers: [ItemKey: ItemLayer] = [:]
        private var ignoreScrolling: Bool = false
        
        private var component: GifPagerContentComponent?
        private var pagerEnvironment: PagerComponentChildEnvironment?
        private var theme: PresentationTheme?
        private var itemLayout: ItemLayout?
        
        private var currentLoadMoreToken: String?
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: nil)
            
            self.shimmerHostView = PortalSourceView()
            self.standaloneShimmerEffect = StandaloneShimmerEffect()
            
            self.placeholdersContainerView = UIView()
            
            self.scrollView = ContentScrollView()
            
            super.init(frame: frame)
            
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
            self.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.placeholdersContainerView)
            
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
            
            self.updateVisibleItems(attemptSynchronousLoads: false)
            
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
        
        private func updateScrollingOffset(transition: Transition) {
            let isInteracting = scrollView.isDragging || scrollView.isDecelerating
            if let previousScrollingOffsetValue = self.previousScrollingOffset {
                let currentBounds = scrollView.bounds
                let offsetToTopEdge = max(0.0, currentBounds.minY - 0.0)
                let offsetToBottomEdge = max(0.0, scrollView.contentSize.height - currentBounds.maxY)
                
                let relativeOffset = scrollView.contentOffset.y - previousScrollingOffsetValue
                self.pagerEnvironment?.onChildScrollingUpdate(PagerComponentChildEnvironment.ContentScrollingUpdate(
                    relativeOffset: relativeOffset,
                    absoluteOffsetToTopEdge: offsetToTopEdge,
                    absoluteOffsetToBottomEdge: offsetToBottomEdge,
                    isReset: false,
                    isInteracting: isInteracting,
                    transition: transition
                ))
                self.previousScrollingOffset = scrollView.contentOffset.y
            }
            self.previousScrollingOffset = scrollView.contentOffset.y
        }
        
        private func snappedContentOffset(proposedOffset: CGFloat) -> CGFloat {
            guard let pagerEnvironment = self.pagerEnvironment else {
                return proposedOffset
            }
            
            var proposedOffset = proposedOffset
            let bounds = self.bounds
            if proposedOffset + bounds.height > self.scrollView.contentSize.height - pagerEnvironment.containerInsets.bottom {
                proposedOffset = self.scrollView.contentSize.height - bounds.height
            }
            if proposedOffset < pagerEnvironment.containerInsets.top {
                proposedOffset = 0.0
            }
            
            return proposedOffset
        }
        
        private func snapScrollingOffsetToInsets() {
            let transition = Transition(animation: .curve(duration: 0.4, curve: .spring))
            
            var currentBounds = self.scrollView.bounds
            currentBounds.origin.y = self.snappedContentOffset(proposedOffset: currentBounds.minY)
            transition.setBounds(view: self.scrollView, bounds: currentBounds)
            
            self.updateScrollingOffset(transition: transition)
        }
        
        private func updateVisibleItems(attemptSynchronousLoads: Bool) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            var validIds = Set<ItemKey>()
            
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
                    
                    let itemFrame = itemLayout.frame(at: index)
                    
                    let itemTransition: Transition = .immediate
                    var updateItemLayerPlaceholder = false
                    
                    let itemLayer: ItemLayer
                    if let current = self.visibleItemLayers[itemId] {
                        itemLayer = current
                    } else {
                        updateItemLayerPlaceholder = true
                        
                        itemLayer = ItemLayer(
                            item: item,
                            context: component.context,
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
                    
                    itemTransition.setFrame(layer: itemLayer, frame: itemFrame)
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
        }
        
        private func updateShimmerIfNeeded() {
            if self.placeholdersContainerView.subviews.isEmpty {
                self.standaloneShimmerEffect.layer = nil
            } else {
                self.standaloneShimmerEffect.layer = self.shimmerHostView.layer
            }
        }
        
        public func pagerUpdateBackground(backgroundFrame: CGRect, transition: Transition) {
            guard let theme = self.theme else {
                return
            }
            self.backgroundView.updateColor(color: theme.chat.inputMediaPanel.backgroundColor, enableBlur: true, forceKeepBlur: false, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            self.backgroundView.update(size: backgroundFrame.size, transition: transition.containedViewLayoutTransition)
        }
        
        func update(component: GifPagerContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
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
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: availableSize))
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
            
            self.updateVisibleItems(attemptSynchronousLoads: true)
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
