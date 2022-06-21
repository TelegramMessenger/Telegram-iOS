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
import VideoAnimationCache
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SwiftSignalKit
import ShimmerEffect
import PagerComponent
import StickerResources

public final class EmojiPagerContentComponent: Component {
    public typealias EnvironmentType = (EntityKeyboardChildEnvironment, PagerComponentChildEnvironment)
    
    public final class InputInteraction {
        public let performItemAction: (Item, UIView, CGRect, CALayer) -> Void
        public let deleteBackwards: () -> Void
        public let openStickerSettings: () -> Void
        
        public init(
            performItemAction: @escaping (Item, UIView, CGRect, CALayer) -> Void,
            deleteBackwards: @escaping () -> Void,
            openStickerSettings: @escaping () -> Void
        ) {
            self.performItemAction = performItemAction
            self.deleteBackwards = deleteBackwards
            self.openStickerSettings = openStickerSettings
        }
    }
    
    public final class Item: Equatable {
        public let emoji: String
        public let file: TelegramMediaFile
        
        public init(emoji: String, file: TelegramMediaFile) {
            self.emoji = emoji
            self.file = file
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.emoji != rhs.emoji {
                return false
            }
            if lhs.file.fileId != rhs.file.fileId {
                return false
            }
            
            return true
        }
    }
    
    public final class ItemGroup: Equatable {
        public let id: AnyHashable
        public let title: String?
        public let items: [Item]
        
        public init(
            id: AnyHashable,
            title: String?,
            items: [Item]
        ) {
            self.id = id
            self.title = title
            self.items = items
        }
        
        public static func ==(lhs: ItemGroup, rhs: ItemGroup) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.items != rhs.items {
                return false
            }
            return true
        }
    }
    
    public enum ItemLayoutType {
        case compact
        case detailed
    }
    
    public let context: AccountContext
    public let animationCache: AnimationCache
    public let animationRenderer: MultiAnimationRenderer
    public let inputInteraction: InputInteraction
    public let itemGroups: [ItemGroup]
    public let itemLayoutType: ItemLayoutType
    
    public init(
        context: AccountContext,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        inputInteraction: InputInteraction,
        itemGroups: [ItemGroup],
        itemLayoutType: ItemLayoutType
    ) {
        self.context = context
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.inputInteraction = inputInteraction
        self.itemGroups = itemGroups
        self.itemLayoutType = itemLayoutType
    }
    
    public static func ==(lhs: EmojiPagerContentComponent, rhs: EmojiPagerContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.animationCache !== rhs.animationCache {
            return false
        }
        if lhs.animationRenderer !== rhs.animationRenderer {
            return false
        }
        if lhs.inputInteraction !== rhs.inputInteraction {
            return false
        }
        if lhs.itemGroups != rhs.itemGroups {
            return false
        }
        if lhs.itemLayoutType != rhs.itemLayoutType {
            return false
        }
        
        return true
    }
    
    public final class View: UIView, UIScrollViewDelegate {
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
            var width: CGFloat
            var containerInsets: UIEdgeInsets
            var itemGroupLayouts: [ItemGroupLayout]
            var itemSize: CGFloat
            var horizontalSpacing: CGFloat
            var verticalSpacing: CGFloat
            var verticalGroupSpacing: CGFloat
            var itemsPerRow: Int
            var contentSize: CGSize
            
            init(width: CGFloat, containerInsets: UIEdgeInsets, itemGroups: [ItemGroupDescription], itemLayoutType: ItemLayoutType) {
                self.width = width
                self.containerInsets = containerInsets
                
                let minSpacing: CGFloat
                switch itemLayoutType {
                case .compact:
                    self.itemSize = 36.0
                    self.verticalSpacing = 9.0
                    minSpacing = 9.0
                case .detailed:
                    self.itemSize = 60.0
                    self.verticalSpacing = 9.0
                    minSpacing = 9.0
                }
                
                self.verticalGroupSpacing = 18.0
                
                let itemHorizontalSpace = width - self.containerInsets.left - self.containerInsets.right
                
                self.itemsPerRow = Int((itemHorizontalSpace + minSpacing) / (self.itemSize + minSpacing))
                self.horizontalSpacing = floor((itemHorizontalSpace - self.itemSize * CGFloat(self.itemsPerRow)) / CGFloat(self.itemsPerRow - 1))
                
                var verticalGroupOrigin: CGFloat = self.containerInsets.top
                self.itemGroupLayouts = []
                for itemGroup in itemGroups {
                    var itemTopOffset: CGFloat = 0.0
                    if itemGroup.hasTitle {
                        itemTopOffset += 24.0
                    }
                    
                    let numRowsInGroup = (itemGroup.itemCount + (self.itemsPerRow - 1)) / self.itemsPerRow
                    let groupContentSize = CGSize(width: width, height: itemTopOffset + CGFloat(numRowsInGroup) * self.itemSize + CGFloat(max(0, numRowsInGroup - 1)) * self.verticalSpacing)
                    self.itemGroupLayouts.append(ItemGroupLayout(
                        frame: CGRect(origin: CGPoint(x: 0.0, y: verticalGroupOrigin), size: groupContentSize),
                        itemTopOffset: itemTopOffset,
                        itemCount: itemGroup.itemCount
                    ))
                    verticalGroupOrigin += groupContentSize.height + self.verticalGroupSpacing
                }
                verticalGroupOrigin += self.containerInsets.bottom
                self.contentSize = CGSize(width: width, height: verticalGroupOrigin)
            }
            
            func frame(groupIndex: Int, itemIndex: Int) -> CGRect {
                let groupLayout = self.itemGroupLayouts[groupIndex]
                
                let row = itemIndex / self.itemsPerRow
                let column = itemIndex % self.itemsPerRow
                
                return CGRect(
                    origin: CGPoint(
                        x: self.containerInsets.left + CGFloat(column) * (self.itemSize + self.horizontalSpacing),
                        y: groupLayout.frame.minY + groupLayout.itemTopOffset + CGFloat(row) * (self.itemSize + self.verticalSpacing)
                    ),
                    size: CGSize(
                        width: self.itemSize,
                        height: self.itemSize
                    )
                )
            }
            
            func visibleItems(for rect: CGRect) -> [(groupIndex: Int, groupItems: Range<Int>)] {
                var result: [(groupIndex: Int, groupItems: Range<Int>)] = []
                
                for groupIndex in 0 ..< self.itemGroupLayouts.count {
                    let group = self.itemGroupLayouts[groupIndex]
                    
                    if !rect.intersects(group.frame) {
                        continue
                    }
                    let offsetRect = rect.offsetBy(dx: -self.containerInsets.left, dy: -group.frame.minY - group.itemTopOffset)
                    var minVisibleRow = Int(floor((offsetRect.minY - self.verticalSpacing) / (self.itemSize + self.verticalSpacing)))
                    minVisibleRow = max(0, minVisibleRow)
                    let maxVisibleRow = Int(ceil((offsetRect.maxY - self.verticalSpacing) / (self.itemSize + self.verticalSpacing)))

                    let minVisibleIndex = minVisibleRow * self.itemsPerRow
                    let maxVisibleIndex = min(group.itemCount - 1, (maxVisibleRow + 1) * self.itemsPerRow - 1)
                    
                    if maxVisibleIndex >= minVisibleIndex {
                        result.append((
                            groupIndex: groupIndex,
                            groupItems: minVisibleIndex ..< (maxVisibleIndex + 1)
                        ))
                    }
                }
                
                return result
            }
        }
        
        final class ItemLayer: MultiAnimationRenderTarget {
            struct Key: Hashable {
                var groupId: AnyHashable
                var fileId: MediaId
            }
            
            let item: Item
            
            private let file: TelegramMediaFile
            private let placeholderColor: UIColor
            private let size: CGSize
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
                cache: AnimationCache,
                renderer: MultiAnimationRenderer,
                placeholderColor: UIColor,
                pointSize: CGSize
            ) {
                self.item = item
                self.file = file
                self.placeholderColor = placeholderColor
                
                let scale = min(2.0, UIScreenScale)
                let pixelSize = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
                self.size = CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
                
                super.init()
                
                if file.isAnimatedSticker || file.isVideoSticker {
                    if attemptSynchronousLoad {
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
                            
                            if file.isVideoSticker {
                                cacheVideoAnimation(path: result, width: Int(size.width), height: Int(size.height), writer: writer)
                            } else {
                                guard let data = try? Data(contentsOf: URL(fileURLWithPath: result)) else {
                                    writer.finish()
                                    return
                                }
                                cacheLottieAnimation(data: data, width: Int(size.width), height: Int(size.height), writer: writer)
                            }
                        })
                        
                        let fetchDisposable = freeMediaFileResourceInteractiveFetched(account: context.account, fileReference: stickerPackFileReference(file), resource: file.resource).start()
                        
                        return ActionDisposable {
                            dataDisposable.dispose()
                            fetchDisposable.dispose()
                        }
                    })
                } else if let dimensions = file.dimensions {
                    let isSmall: Bool = false
                    self.disposable = (chatMessageSticker(account: context.account, file: file, small: isSmall, synchronousLoad: attemptSynchronousLoad)).start(next: { [weak self] resultTransform in
                        let boundingSize = CGSize(width: 93.0, height: 93.0)
                        let imageSize = dimensions.cgSize.aspectFilled(boundingSize)
                        
                        if let image = resultTransform(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets(), resizeMode: .fill(.clear)))?.generateImage() {
                            Queue.mainQueue().async {
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                strongSelf.contents = image.cgImage
                            }
                        }
                    })
                }
            }
            
            override public init(layer: Any) {
                preconditionFailure()
            }
            
            required public init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            deinit {
                self.disposable?.dispose()
                self.fetchDisposable?.dispose()
            }
            
            override public func action(forKey event: String) -> CAAction? {
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
            
            override func updateDisplayPlaceholder(displayPlaceholder: Bool) {
                if self.displayPlaceholder == displayPlaceholder {
                    return
                }
                
                self.displayPlaceholder = displayPlaceholder
                let file = self.file
                let size = self.size
                let placeholderColor = self.placeholderColor
                
                Queue.concurrentDefaultQueue().async { [weak self] in
                    if let image = generateStickerPlaceholderImage(data: file.immediateThumbnailData, size: size, imageSize: file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0), backgroundColor: nil, foregroundColor: placeholderColor) {
                        Queue.mainQueue().async {
                            guard let strongSelf = self else {
                                return
                            }
                            
                            if strongSelf.displayPlaceholder {
                                strongSelf.contents = image.cgImage
                            }
                        }
                    }
                }
            }
        }
        
        private let scrollView: UIScrollView
        
        private var visibleItemLayers: [ItemLayer.Key: ItemLayer] = [:]
        private var visibleGroupHeaders: [AnyHashable: ComponentHostView<Empty>] = [:]
        private var ignoreScrolling: Bool = false
        
        private var component: EmojiPagerContentComponent?
        private var pagerEnvironment: PagerComponentChildEnvironment?
        private var theme: PresentationTheme?
        private var itemLayout: ItemLayout?
        
        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            
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
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                if let component = self.component, let (item, itemKey) = self.item(atPoint: recognizer.location(in: self)), let itemLayer = self.visibleItemLayers[itemKey] {
                    component.inputInteraction.performItemAction(item, self, self.scrollView.convert(itemLayer.frame, to: self), itemLayer)
                }
            }
        }
        
        private func item(atPoint point: CGPoint) -> (Item, ItemLayer.Key)? {
            let localPoint = self.convert(point, to: self.scrollView)
            
            for (key, itemLayer) in self.visibleItemLayers {
                if itemLayer.frame.contains(localPoint) {
                    return (itemLayer.item, key)
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
            if let previousScrollingOffsetValue = self.previousScrollingOffset {
                let currentBounds = scrollView.bounds
                let offsetToTopEdge = max(0.0, currentBounds.minY - 0.0)
                let offsetToBottomEdge = max(0.0, scrollView.contentSize.height - currentBounds.maxY)
                let offsetToClosestEdge = min(offsetToTopEdge, offsetToBottomEdge)
                
                let relativeOffset = scrollView.contentOffset.y - previousScrollingOffsetValue
                self.pagerEnvironment?.onChildScrollingUpdate(PagerComponentChildEnvironment.ContentScrollingUpdate(
                    relativeOffset: relativeOffset,
                    absoluteOffsetToClosestEdge: offsetToClosestEdge,
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
            
            var validIds = Set<ItemLayer.Key>()
            var validGroupHeaderIds = Set<AnyHashable>()
            
            for groupItems in itemLayout.visibleItems(for: self.scrollView.bounds) {
                let itemGroup = component.itemGroups[groupItems.groupIndex]
                let itemGroupLayout = itemLayout.itemGroupLayouts[groupItems.groupIndex]
                
                if let title = itemGroup.title {
                    validGroupHeaderIds.insert(itemGroup.id)
                    let groupHeaderView: ComponentHostView<Empty>
                    if let current = self.visibleGroupHeaders[itemGroup.id] {
                        groupHeaderView = current
                    } else {
                        groupHeaderView = ComponentHostView<Empty>()
                        self.visibleGroupHeaders[itemGroup.id] = groupHeaderView
                        self.scrollView.addSubview(groupHeaderView)
                    }
                    let groupHeaderSize = groupHeaderView.update(
                        transition: .immediate,
                        component: AnyComponent(Text(
                            text: title, font: Font.medium(12.0), color: theme.chat.inputMediaPanel.stickersSectionTextColor
                        )),
                        environment: {},
                        containerSize: CGSize(width: itemLayout.contentSize.width - itemLayout.containerInsets.left - itemLayout.containerInsets.right, height: 100.0)
                    )
                    groupHeaderView.frame = CGRect(origin: CGPoint(x: itemLayout.containerInsets.left, y: itemGroupLayout.frame.minY + 1.0), size: groupHeaderSize)
                }
                
                for index in groupItems.groupItems.lowerBound ..< groupItems.groupItems.upperBound {
                    let item = itemGroup.items[index]
                    let itemId = ItemLayer.Key(groupId: itemGroup.id, fileId: item.file.fileId)
                    validIds.insert(itemId)
                    
                    let itemLayer: ItemLayer
                    if let current = self.visibleItemLayers[itemId] {
                        itemLayer = current
                    } else {
                        itemLayer = ItemLayer(item: item, context: component.context, groupId: "keyboard", attemptSynchronousLoad: attemptSynchronousLoads, file: item.file, cache: component.animationCache, renderer: component.animationRenderer, placeholderColor: theme.chat.inputMediaPanel.stickersBackgroundColor, pointSize: CGSize(width: itemLayout.itemSize, height: itemLayout.itemSize))
                        self.scrollView.layer.addSublayer(itemLayer)
                        self.visibleItemLayers[itemId] = itemLayer
                    }
                    
                    itemLayer.frame = itemLayout.frame(groupIndex: groupItems.groupIndex, itemIndex: index)
                    itemLayer.isVisibleForAnimations = true
                }
            }

            var removedIds: [ItemLayer.Key] = []
            for (id, itemLayer) in self.visibleItemLayers {
                if !validIds.contains(id) {
                    removedIds.append(id)
                    itemLayer.removeFromSuperlayer()
                }
            }
            for id in removedIds {
                self.visibleItemLayers.removeValue(forKey: id)
            }
            
            var removedGroupHeaderIds: [AnyHashable] = []
            for (id, groupHeaderView) in self.visibleGroupHeaders {
                if !validGroupHeaderIds.contains(id) {
                    removedGroupHeaderIds.append(id)
                    groupHeaderView.removeFromSuperview()
                }
            }
            for id in removedGroupHeaderIds {
                self.visibleGroupHeaders.removeValue(forKey: id)
            }
        }
        
        func update(component: EmojiPagerContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.theme = environment[EntityKeyboardChildEnvironment.self].value.theme
            
            let pagerEnvironment = environment[PagerComponentChildEnvironment.self].value
            self.pagerEnvironment = pagerEnvironment
            
            var itemGroups: [ItemGroupDescription] = []
            for itemGroup in component.itemGroups {
                itemGroups.append(ItemGroupDescription(
                    hasTitle: itemGroup.title != nil,
                    itemCount: itemGroup.items.count
                ))
            }
            
            let itemLayout = ItemLayout(width: availableSize.width, containerInsets: UIEdgeInsets(top: pagerEnvironment.containerInsets.top + 9.0, left: pagerEnvironment.containerInsets.left + 12.0, bottom: 9.0 + pagerEnvironment.containerInsets.bottom, right: pagerEnvironment.containerInsets.right + 12.0), itemGroups: itemGroups, itemLayoutType: component.itemLayoutType)
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
