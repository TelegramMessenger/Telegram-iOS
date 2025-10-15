import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import MergeLists
import ComponentDisplayAdapters

public final class AsyncListComponent: Component {
    public protocol ItemView: UIView {
        func isReorderable(at point: CGPoint) -> Bool
    }
    
    public final class OverlayContainerView: UIView {
        public override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.layer.anchorPoint = CGPoint()
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func updatePosition(position: CGPoint, transition: ComponentTransition) {
            let previousPosition: CGPoint
            var forceUpdate = false
            if self.layer.animation(forKey: "positionUpdate") != nil, let presentation = self.layer.presentation() {
                forceUpdate = true
                previousPosition = presentation.position
                
                if !transition.animation.isImmediate {
                    self.layer.removeAnimation(forKey: "positionUpdate")
                }
            } else {
                previousPosition = self.layer.position
            }
            
            if previousPosition != position || forceUpdate {
                self.center = position
                if case let .curve(duration, curve) = transition.animation {
                    self.layer.animate(
                        from: NSValue(cgPoint: CGPoint(x: previousPosition.x - position.x, y: previousPosition.y - position.y)),
                        to: NSValue(cgPoint: CGPoint()),
                        keyPath: "position",
                        duration: duration,
                        delay: 0.0,
                        curve: curve,
                        removeOnCompletion: true,
                        additive: true,
                        completion: nil,
                        key: "positionUpdate"
                    )
                }
            }
        }
    }
    
    final class ResetScrollingRequest: Equatable {
        let requestId: Int
        let id: AnyHashable
        
        init(requestId: Int, id: AnyHashable) {
            self.requestId = requestId
            self.id = id
        }
        
        static func ==(lhs: ResetScrollingRequest, rhs: ResetScrollingRequest) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.requestId != rhs.requestId {
                return false
            }
            if lhs.id != rhs.id {
                return false
            }
            return true
        }
    }
    
    public final class ExternalState {
        public struct Value: Equatable {
            var resetScrollingRequest: ResetScrollingRequest?
            
            public static func ==(lhs: Value, rhs: Value) -> Bool {
                if lhs.resetScrollingRequest != rhs.resetScrollingRequest {
                    return false
                }
                return true
            }
        }
        
        public private(set) var value: Value = Value()
        private var nextId: Int = 0
        
        public init() {
            
        }
        
        public func resetScrolling(id: AnyHashable) {
            let requestId = self.nextId
            self.nextId += 1
            self.value.resetScrollingRequest = ResetScrollingRequest(requestId: requestId, id: id)
        }
    }
    
    public enum Direction {
        case vertical
        case horizontal
    }
    
    public final class VisibleItem {
        public let item: AnyComponentWithIdentity<Empty>
        public let frame: CGRect
        
        init(item: AnyComponentWithIdentity<Empty>, frame: CGRect) {
            self.item = item
            self.frame = frame
        }
    }
    
    public final class VisibleItems: Sequence, IteratorProtocol {
        private let view: AsyncListComponent.View
        private var index: Int = 0
        private let indices: [(Int, CGRect)]
        
        init(view: AsyncListComponent.View, direction: Direction) {
            self.view = view
            var indices: [(Int, CGRect)] = []
            view.listNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ListItemNodeImpl, let index = itemNode.index {
                    var itemFrame = itemNode.frame
                    itemFrame.origin.y -= itemNode.transitionOffset
                    if let animation = itemNode.animationForKey("height") {
                        if let height = animation.to as? CGFloat {
                            itemFrame.size.height = height
                        }
                    }
                    
                    if case .horizontal = direction {
                        itemFrame = CGRect(origin: CGPoint(x: itemFrame.minY, y: itemFrame.minX), size: CGSize(width: itemFrame.height, height: itemFrame.width))
                    }
                    
                    indices.append((index, itemFrame))
                }
            }
            indices.sort(by: { $0.0 < $1.0 })
            self.indices = indices
        }
        
        public func next() -> VisibleItem? {
            if self.index >= self.indices.count {
                return nil
            }
            let index = self.index
            self.index += 1
            
            if let component = self.view.component {
                let (itemIndex, itemFrame) = self.indices[index]
                return VisibleItem(item: component.items[itemIndex], frame: itemFrame)
            }
            
            return nil
        }
    }

    public let externalState: ExternalState
    public let externalStateValue: ExternalState.Value
    public let items: [AnyComponentWithIdentity<Empty>]
    public let itemSetId: AnyHashable // Changing itemSetId supresses update animations
    public let direction: Direction
    public let insets: UIEdgeInsets
    public let reorderItems: ((Int, Int) -> Bool)?
    public let onVisibleItemsUpdated: ((VisibleItems, ComponentTransition) -> Void)?

    public init(
        externalState: ExternalState,
        items: [AnyComponentWithIdentity<Empty>],
        itemSetId: AnyHashable,
        direction: Direction,
        insets: UIEdgeInsets,
        reorderItems: ((Int, Int) -> Bool)? = nil,
        onVisibleItemsUpdated: ((VisibleItems, ComponentTransition) -> Void)? = nil
    ) {
        self.externalState = externalState
        self.externalStateValue = externalState.value
        self.items = items
        self.itemSetId = itemSetId
        self.direction = direction
        self.insets = insets
        self.reorderItems = reorderItems
        self.onVisibleItemsUpdated = onVisibleItemsUpdated
    }
    
    public static func ==(lhs: AsyncListComponent, rhs: AsyncListComponent) -> Bool {
        if lhs.externalState !== rhs.externalState {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.itemSetId != rhs.itemSetId {
            return false
        }
        if lhs.direction != rhs.direction {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if (lhs.reorderItems == nil) != (rhs.reorderItems == nil) {
            return false
        }
        return true
    }
    
    private struct ItemEntry: Comparable, Identifiable {
        let contents: AnyComponentWithIdentity<Empty>
        let index: Int
        
        var id: AnyHashable {
            return self.contents.id
        }
        
        var stableId: AnyHashable {
            return self.id
        }
        
        static func ==(lhs: ItemEntry, rhs: ItemEntry) -> Bool {
            if lhs.contents != rhs.contents {
                return false
            }
            if lhs.index != rhs.index {
                return false
            }
            return true
        }
        
        static func <(lhs: ItemEntry, rhs: ItemEntry) -> Bool {
            return lhs.index < rhs.index
        }
        
        func item(parentView: AsyncListComponent.View?, direction: Direction) -> ListViewItem {
            return ListItemImpl(parentView: parentView, contents: self.contents, direction: direction)
        }
    }
    
    private final class ListItemImpl: ListViewItem {
        weak var parentView: AsyncListComponent.View?
        let contents: AnyComponentWithIdentity<Empty>
        let direction: Direction
        
        let selectable: Bool = false
        
        init(parentView: AsyncListComponent.View?, contents: AnyComponentWithIdentity<Empty>, direction: Direction) {
            self.parentView = parentView
            self.contents = contents
            self.direction = direction
        }
        
        func nodeConfiguredForParams(
            async: @escaping (@escaping () -> Void) -> Void,
            params: ListViewItemLayoutParams,
            synchronousLoads: Bool,
            previousItem: ListViewItem?,
            nextItem: ListViewItem?,
            completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void
        ) {
            async {
                let impl: () -> Void = {
                    let node = ListItemNodeImpl()
                    let (nodeLayout, apply) = node.asyncLayout()(self, params)
                    node.insets = nodeLayout.insets
                    node.contentSize = nodeLayout.contentSize
                    
                    Queue.mainQueue().async {
                        completion(node, {
                            return (nil, { _ in
                                apply(false)
                            })
                        })
                    }
                }
                
                if Thread.isMainThread {
                    impl()
                } else {
                    assert(false)
                    Queue.mainQueue().async {
                        impl()
                    }
                }
            }
        }
        
        public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
            Queue.mainQueue().async {
                assert(node() is ListItemNodeImpl)
                if let nodeValue = node() as? ListItemNodeImpl {
                    let layout = nodeValue.asyncLayout()
                    async {
                        let impl: () -> Void = {
                            let (nodeLayout, apply) = layout(self, params)
                            Queue.mainQueue().async {
                                completion(nodeLayout, { _ in
                                    apply(animation.isAnimated)
                                })
                            }
                        }
                        
                        if Thread.isMainThread {
                            impl()
                        } else {
                            assert(false)
                            Queue.mainQueue().async {
                                impl()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private final class ListItemNodeImpl: ListViewItemNode {
        private let contentContainer: UIView
        private let contentsView = ComponentView<Empty>()
        private(set) var item: ListItemImpl?
        
        init() {
            self.contentContainer = UIView()
            
            super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
            
            self.view.addSubview(self.contentContainer)
            
            self.scrollPositioningInsets = UIEdgeInsets(top: -24.0, left: 0.0, bottom: -24.0, right: 0.0)
        }
        
        deinit {
        }
        
        override func isReorderable(at point: CGPoint) -> Bool {
            if let itemView = self.contentsView.view as? ItemView {
                return itemView.isReorderable(at: self.view.convert(point, to: itemView))
            }
            return false
        }
        
        override func snapshotForReordering() -> UIView? {
            return self.view.snapshotView(afterScreenUpdates: false)
        }
        
        func asyncLayout() -> (ListItemImpl, ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (Bool) -> Void) {
            return { item, params in
                let containerSize: CGSize
                switch item.direction {
                case .vertical:
                    containerSize = CGSize(width: params.width, height: 100000.0)
                case .horizontal:
                    containerSize = CGSize(width: 100000.0, height: params.width)
                }
                
                let contentsSize = self.contentsView.update(
                    transition: .immediate,
                    component: item.contents.component,
                    environment: {},
                    containerSize: containerSize
                )
                
                let mappedContentsSize: CGSize
                switch item.direction {
                case .vertical:
                    mappedContentsSize = CGSize(width: params.width, height: contentsSize.height)
                case .horizontal:
                    mappedContentsSize = CGSize(width: params.width, height: contentsSize.width)
                }
                
                let itemLayout = ListViewItemNodeLayout(contentSize: mappedContentsSize, insets: UIEdgeInsets())
                return (itemLayout, { animated in
                    self.item = item
                    
                    switch item.direction {
                    case .vertical:
                        self.contentContainer.layer.sublayerTransform = CATransform3DIdentity
                    case .horizontal:
                        self.contentContainer.layer.sublayerTransform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                    }
                    self.contentContainer.frame = CGRect(origin: CGPoint(), size: mappedContentsSize)
                    
                    let contentsFrame = CGRect(origin: CGPoint(), size: contentsSize)
                    
                    if let contentsComponentView = self.contentsView.view {
                        if contentsComponentView.superview == nil {
                            self.contentContainer.addSubview(contentsComponentView)
                        }
                        contentsComponentView.center = CGPoint(x: mappedContentsSize.width * 0.5, y: mappedContentsSize.height * 0.5)
                        contentsComponentView.bounds = CGRect(origin: CGPoint(), size: contentsFrame.size)
                    }
                })
            }
        }
            
        override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
            super.animateInsertion(currentTimestamp, duration: duration, options: options)
            
            self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
        
        override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
            super.animateRemoved(currentTimestamp, duration: duration)
            
            self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
        
        override func animateAdded(_ currentTimestamp: Double, duration: Double) {
            super.animateAdded(currentTimestamp, duration: duration)
            
            self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
    }
    
    public final class View: UIView {
        let listNode: ListView
        
        private var externalStateValue: ExternalState.Value?
        private var isUpdating: Bool = false
        private(set) var component: AsyncListComponent?
        
        private var currentEntries: [ItemEntry] = []
        
        private var ignoreUpdateVisibleItems: Bool = false
        
        public override init(frame: CGRect) {
            self.listNode = ListView()
            self.listNode.useMainQueueTransactions = true
            self.listNode.scroller.delaysContentTouches = false
            self.listNode.reorderedItemHasShadow = false
            
            super.init(frame: frame)
            
            self.addSubview(self.listNode.view)
            
            self.listNode.onContentsUpdated = { [weak self] transition in
                guard let self else {
                    return
                }
                self.updateVisibleItems(transition: ComponentTransition(transition))
            }
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        public func stopScrolling() {
            self.listNode.stopScrolling()
        }
        
        private func updateVisibleItems(transition: ComponentTransition) {
            if self.ignoreUpdateVisibleItems {
                return
            }
            guard let component = self.component else {
                return
            }
            if let onVisibleItemsUpdated = component.onVisibleItemsUpdated {
                onVisibleItemsUpdated(VisibleItems(view: self, direction: component.direction), transition)
            }
        }
        
        func update(component: AsyncListComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            
            let listSize: CGSize
            let listInsets: UIEdgeInsets
            switch component.direction {
            case .vertical:
                self.listNode.transform = CATransform3DIdentity
                listSize = CGSize(width: availableSize.width, height: availableSize.height)
                listInsets = component.insets
            case .horizontal:
                self.listNode.transform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                listSize = CGSize(width: availableSize.height, height: availableSize.width)
                listInsets = UIEdgeInsets(top: component.insets.left, left: component.insets.top, bottom: component.insets.right, right: component.insets.bottom)
            }
            
            var updateSizeAndInsets = ListViewUpdateSizeAndInsets(
                size: listSize,
                insets: listInsets,
                duration: 0.0,
                curve: .Default(duration: nil)
            )
            
            var animateTransition = false
            var transactionOptions: ListViewDeleteAndInsertOptions = []
            
            if !transition.animation.isImmediate, let previousComponent {
                if previousComponent.itemSetId == component.itemSetId {
                    transactionOptions.insert(.AnimateInsertion)
                }
                animateTransition = true
                
                switch transition.animation {
                case .none:
                    break
                case let .curve(duration, curve):
                    updateSizeAndInsets.duration = duration
                    switch curve {
                    case .linear, .easeInOut:
                        updateSizeAndInsets.curve = .Default(duration: duration)
                    case .spring:
                        updateSizeAndInsets.curve = .Spring(duration: duration)
                    case let .custom(a, b, c, d):
                        updateSizeAndInsets.curve = .Custom(duration: duration, a, b, c, d)
                    }
                }
            }
            
            var entries: [ItemEntry] = []
            for item in component.items {
                entries.append(ItemEntry(
                    contents: item,
                    index: entries.count
                ))
            }
            
            var scrollToItem: ListViewScrollToItem?
            if let resetScrollingRequest = component.externalStateValue.resetScrollingRequest, previousComponent?.externalStateValue.resetScrollingRequest != component.externalStateValue.resetScrollingRequest {
                if let index = entries.firstIndex(where: { $0.id == resetScrollingRequest.id }) {
                    var directionHint: ListViewScrollToItemDirectionHint = .Down
                    var didSelectDirection = false
                    self.listNode.forEachItemNode { itemNode in
                        if didSelectDirection {
                            return
                        }
                        if let itemNode = itemNode as? ListItemNodeImpl, let itemIndex = itemNode.index {
                            if itemIndex <= index {
                                directionHint = .Up
                            } else {
                                directionHint = .Down
                            }
                            didSelectDirection = true
                        }
                    }
                    
                    scrollToItem = ListViewScrollToItem(
                        index: index,
                        position: .visible,
                        animated: animateTransition,
                        curve: updateSizeAndInsets.curve,
                        directionHint: directionHint
                    )
                }
            }
            
            self.ignoreUpdateVisibleItems = true
            
            let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.currentEntries, rightList: entries)
            self.currentEntries = entries
            let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
            let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(parentView: self, direction: component.direction), directionHint: .Down) }
            let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(parentView: self, direction: component.direction), directionHint: nil) }
            
            transactionOptions.insert(.Synchronous)
            
            self.listNode.transaction(
                deleteIndices: [],
                insertIndicesAndItems: [],
                updateIndicesAndItems: [],
                options: transactionOptions,
                scrollToItem: nil,
                updateSizeAndInsets: updateSizeAndInsets,
                stationaryItemRange: nil,
                updateOpaqueState: nil,
                completion: { _ in }
            )
            
            self.listNode.transaction(
                deleteIndices: deletions,
                insertIndicesAndItems: insertions,
                updateIndicesAndItems: updates,
                options: transactionOptions,
                scrollToItem: scrollToItem,
                updateSizeAndInsets: nil,
                stationaryItemRange: nil,
                updateOpaqueState: nil,
                completion: { _ in }
            )
            
            let mappedListFrame: CGRect
            switch component.direction {
            case .vertical:
                mappedListFrame = CGRect(origin: CGPoint(x: availableSize.width * 0.5, y: availableSize.height * 0.5), size: listSize)
            case .horizontal:
                mappedListFrame = CGRect(origin: CGPoint(x: availableSize.width * 0.5, y: availableSize.height * 0.5), size: listSize)
            }
            self.listNode.position = mappedListFrame.origin
            self.listNode.bounds = CGRect(origin: CGPoint(), size: mappedListFrame.size)
            
            self.listNode.reorderItem = { [weak self] fromIndex, toIndex, _ in
                guard let self, let component = self.component else {
                    return .single(false)
                }
                guard let reorderItems = component.reorderItems else {
                    return .single(false)
                }
                
                if reorderItems(fromIndex, toIndex) {
                    return .single(true)
                } else {
                    return .single(false)
                }
            }
            
            self.ignoreUpdateVisibleItems = false
            
            self.updateVisibleItems(transition: transition)
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
