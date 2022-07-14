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
import ContextUI

private class GifVideoLayer: AVSampleBufferDisplayLayer {
    private let context: AccountContext
    private let file: TelegramMediaFile
    
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
                self.playbackTimer = SwiftSignalKit.Timer(timeout: 1.0 / 30.0, repeat: true, completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.frameManager?.tick(timestamp: strongSelf.playbackTimestamp)
                    strongSelf.playbackTimestamp += 1.0 / 30.0
                }, queue: .mainQueue())
                self.playbackTimer?.start()
            } else {
                self.playbackTimer?.invalidate()
                self.playbackTimer = nil
            }
        }
    }
    
    init(context: AccountContext, file: TelegramMediaFile, synchronousLoad: Bool) {
        self.context = context
        self.file = file
        
        super.init()
        
        self.videoGravity = .resizeAspectFill
        
        if let dimensions = file.dimensions {
            self.thumbnailDisposable = (mediaGridMessageVideo(postbox: context.account.postbox, videoReference: .savedGif(media: self.file), synchronousLoad: synchronousLoad, nilForEmptyResult: true)
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
        let frameManager = SoftwareVideoLayerFrameManager(account: self.context.account, fileReference: .savedGif(media: self.file), layerHolder: nil, layer: self)
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
        public let openGifContextMenu: (TelegramMediaFile, UIView, CGRect, ContextGesture, Bool) -> Void
        
        public init(
            performItemAction: @escaping (Item, UIView, CGRect) -> Void,
            openGifContextMenu: @escaping (TelegramMediaFile, UIView, CGRect, ContextGesture, Bool) -> Void
        ) {
            self.performItemAction = performItemAction
            self.openGifContextMenu = openGifContextMenu
        }
    }
    
    public final class Item: Equatable {
        public let file: TelegramMediaFile
        
        public init(file: TelegramMediaFile) {
            self.file = file
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.file.fileId != rhs.file.fileId {
                return false
            }
            
            return true
        }
    }
    
    public let context: AccountContext
    public let inputInteraction: InputInteraction
    public let subject: Subject
    public let items: [Item]
    
    public init(
        context: AccountContext,
        inputInteraction: InputInteraction,
        subject: Subject,
        items: [Item]
    ) {
        self.context = context
        self.inputInteraction = inputInteraction
        self.subject = subject
        self.items = items
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
        
        return true
    }
    
    public final class View: ContextControllerSourceView, UIScrollViewDelegate {
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
                
                let itemHorizontalSpace = width - self.containerInsets.left - self.containerInsets.right
                self.itemSize = floor((width - self.horizontalSpacing * 2.0) / 3.0)
                
                self.itemsPerRow = Int((itemHorizontalSpace + self.horizontalSpacing) / (self.itemSize + self.horizontalSpacing))
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
                
                if column == self.itemsPerRow - 1 {
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
                let maxVisibleIndex = min(self.itemCount - 1, (maxVisibleRow + 1) * self.itemsPerRow - 1)
                
                if maxVisibleIndex >= minVisibleIndex {
                    return minVisibleIndex ..< (maxVisibleIndex + 1)
                } else {
                    return nil
                }
            }
        }
        
        fileprivate final class ItemLayer: GifVideoLayer {
            let item: Item
            
            private let file: TelegramMediaFile
            private let placeholderColor: UIColor
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
            private var displayPlaceholder: Bool = false
            
            init(
                item: Item,
                context: AccountContext,
                groupId: String,
                attemptSynchronousLoad: Bool,
                file: TelegramMediaFile,
                placeholderColor: UIColor
            ) {
                self.item = item
                self.file = file
                self.placeholderColor = placeholderColor
                
                super.init(context: context, file: file, synchronousLoad: attemptSynchronousLoad)
                
                self.updateDisplayPlaceholder(displayPlaceholder: true)
                
                self.started = { [weak self] in
                    self?.updateDisplayPlaceholder(displayPlaceholder: false)
                }
                
                /*if attemptSynchronousLoad {
                    if !renderer.loadFirstFrameSynchronously(groupId: groupId, target: self, cache: cache, itemId: file.resource.id.stringRepresentation, size: pixelSize) {
                        self.displayPlaceholder = true
                        
                        if let image = generateStickerPlaceholderImage(data: file.immediateThumbnailData, size: self.size, imageSize: file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0), backgroundColor: nil, foregroundColor: placeholderColor) {
                            self.contents = image.cgImage
                        }
                    }
                }
                
                self.disposable = renderer.add(groupId: groupId, target: self, cache: cache, itemId: file.resource.id.stringRepresentation, size: pixelSize, fetch: { size, writer in
                    let source = AnimatedStickerResourceSource(account: context.account, resource: file.resource, fitzModifier: nil, isVideo: false)
                    
                    let dataDisposable = source.directDataPath(attemptSynchronously: false).start(next: { result in
                        guard let result = result else {
                            return
                        }
                                
                        guard let data = try? Data(contentsOf: URL(fileURLWithPath: result)) else {
                            writer.finish()
                            return
                        }
                        cacheLottieAnimation(data: data, width: Int(size.width), height: Int(size.height), writer: writer)
                    })
                    
                    let fetchDisposable = freeMediaFileInteractiveFetched(account: context.account, fileReference: .standalone(media: file)).start()
                    
                    return ActionDisposable {
                        dataDisposable.dispose()
                        fetchDisposable.dispose()
                    }
                })*/
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
            
            func updateDisplayPlaceholder(displayPlaceholder: Bool) {
                if self.displayPlaceholder == displayPlaceholder {
                    return
                }
                
                self.displayPlaceholder = displayPlaceholder
                
                if displayPlaceholder {
                    let placeholderColor = self.placeholderColor
                    self.backgroundColor = placeholderColor.cgColor
                } else {
                    self.backgroundColor = nil
                }
            }
        }
        
        private final class ContentScrollView: UIScrollView, PagerExpandableScrollView {
        }
        
        private let scrollView: ContentScrollView
        
        private var visibleItemLayers: [MediaId: ItemLayer] = [:]
        private var ignoreScrolling: Bool = false
        
        private var component: GifPagerContentComponent?
        private var pagerEnvironment: PagerComponentChildEnvironment?
        private var theme: PresentationTheme?
        private var itemLayout: ItemLayout?
        
        override init(frame: CGRect) {
            self.scrollView = ContentScrollView()
            
            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
            
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
                component.inputInteraction.openGifContextMenu(item.file, strongSelf, rect, gesture, true)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func openGifContextMenu(file: TelegramMediaFile, sourceView: UIView, sourceRect: CGRect, gesture: ContextGesture, isSaved: Bool) {
            guard let component = self.component else {
                return
            }
            component.inputInteraction.openGifContextMenu(file, sourceView, sourceRect, gesture, isSaved)
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                if let component = self.component, let item = self.item(atPoint: recognizer.location(in: self)), let itemView = self.visibleItemLayers[item.file.fileId] {
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
                    return (itemLayer.item, itemLayer)
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
            let isInteracting = scrollView.isDragging || scrollView.isTracking || scrollView.isDecelerating
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
            guard let component = self.component, let theme = self.theme, let itemLayout = self.itemLayout else {
                return
            }
            
            var validIds = Set<MediaId>()
            
            if let itemRange = itemLayout.visibleItems(for: self.scrollView.bounds) {
                for index in itemRange.lowerBound ..< itemRange.upperBound {
                    let item = component.items[index]
                    let itemId = item.file.fileId
                    validIds.insert(itemId)
                    
                    let itemLayer: ItemLayer
                    if let current = self.visibleItemLayers[itemId] {
                        itemLayer = current
                    } else {
                        itemLayer = ItemLayer(
                            item: item,
                            context: component.context,
                            groupId: "savedGif",
                            attemptSynchronousLoad: attemptSynchronousLoads,
                            file: item.file,
                            placeholderColor: theme.chat.inputMediaPanel.stickersBackgroundColor
                        )
                        self.scrollView.layer.addSublayer(itemLayer)
                        self.visibleItemLayers[itemId] = itemLayer
                    }
                    
                    itemLayer.frame = itemLayout.frame(at: index)
                    itemLayer.isVisibleForAnimations = true
                }
            }

            var removedIds: [MediaId] = []
            for (id, itemLayer) in self.visibleItemLayers {
                if !validIds.contains(id) {
                    removedIds.append(id)
                    itemLayer.removeFromSuperlayer()
                }
            }
            for id in removedIds {
                self.visibleItemLayers.removeValue(forKey: id)
            }
        }
        
        func update(component: GifPagerContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.theme = environment[EntityKeyboardChildEnvironment.self].value.theme
            
            let pagerEnvironment = environment[PagerComponentChildEnvironment.self].value
            self.pagerEnvironment = pagerEnvironment
            
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
