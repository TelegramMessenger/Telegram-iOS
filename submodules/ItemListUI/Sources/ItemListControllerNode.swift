import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import MergeLists

public protocol ItemListHeaderItemNode: AnyObject {
    func updateTheme(theme: PresentationTheme)
}

public typealias ItemListSectionId = Int32

public protocol ItemListNodeAnyEntry {
    var anyId: AnyHashable { get }
    var tag: ItemListItemTag? { get }
    func isLessThan(_ rhs: ItemListNodeAnyEntry) -> Bool
    func isEqual(_ rhs: ItemListNodeAnyEntry) -> Bool
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem
}

public protocol ItemListNodeEntry: Comparable, Identifiable, ItemListNodeAnyEntry {
    var section: ItemListSectionId { get }
}

public extension ItemListNodeEntry {
    var anyId: AnyHashable {
        return self.stableId
    }
    
    func isLessThan(_ rhs: ItemListNodeAnyEntry) -> Bool {
        return self < (rhs as! Self)
    }
    
    func isEqual(_ rhs: ItemListNodeAnyEntry) -> Bool {
        return self == (rhs as! Self)
    }
}

public extension ItemListNodeEntry {
    var tag: ItemListItemTag? { return nil }
}

private struct ItemListNodeEntryTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedItemListNodeEntryTransition(from fromEntries: [ItemListNodeAnyEntry], to toEntries: [ItemListNodeAnyEntry], presentationData: ItemListPresentationData, arguments: Any, presentationDataUpdated: Bool) -> ItemListNodeEntryTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, isLess: { lhs, rhs in
        return lhs.isLessThan(rhs)
    }, isEqual: { lhs, rhs in
        return lhs.isEqual(rhs)
    }, getId: { value in
        return value.anyId
    }, allUpdated: presentationDataUpdated)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, arguments: arguments), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, arguments: arguments), directionHint: nil) }
    
    return ItemListNodeEntryTransition(deletions: deletions, insertions: insertions, updates: updates)
}

public enum ItemListStyle {
    case plain
    case blocks
}

open class ItemListToolbarItem {
    public struct Action {
        public let title: String
        public let isEnabled: Bool
        public let action: () -> Void
        
        public init(title: String, isEnabled: Bool, action: @escaping () -> Void) {
            self.title = title
            self.isEnabled = isEnabled
            self.action = action
        }
    }
    
    let actions: [Action]
    
    public init(actions: [Action]) {
        self.actions = actions
    }
    
    open func isEqual(to: ItemListToolbarItem) -> Bool {
        return false
    }
    
    var toolbar: Toolbar {
        var leftAction: ToolbarAction?
        var middleAction: ToolbarAction?
        var rightAction: ToolbarAction?
        
        if self.actions.count == 1 {
            if let action = self.actions.first {
                middleAction = ToolbarAction(title: action.title, isEnabled: action.isEnabled)
            }
        } else if self.actions.count == 2 {
            if let action = self.actions.first {
                leftAction = ToolbarAction(title: action.title, isEnabled: action.isEnabled)
            }
            if let action = self.actions.last {
                rightAction = ToolbarAction(title: action.title, isEnabled: action.isEnabled)
            }
        } else if self.actions.count == 3 {
            leftAction = ToolbarAction(title: self.actions[0].title, isEnabled: self.actions[0].isEnabled)
            middleAction = ToolbarAction(title: self.actions[1].title, isEnabled: self.actions[1].isEnabled)
            rightAction = ToolbarAction(title: self.actions[2].title, isEnabled: self.actions[2].isEnabled)
        }
        return Toolbar(leftAction: leftAction, rightAction: rightAction, middleAction: middleAction)
    }
    
}

private struct ItemListNodeTransition {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let entries: ItemListNodeEntryTransition
    let updateStyle: ItemListStyle?
    let emptyStateItem: ItemListControllerEmptyStateItem?
    let searchItem: ItemListControllerSearch?
    let toolbarItem: ItemListToolbarItem?
    let footerItem: ItemListControllerFooterItem?
    let focusItemTag: ItemListItemTag?
    let ensureVisibleItemTag: ItemListItemTag?
    let scrollToItem: ListViewScrollToItem?
    let firstTime: Bool
    let animated: Bool
    let animateAlpha: Bool
    let crossfade: Bool
    let mergedEntries: [ItemListNodeAnyEntry]
    let scrollEnabled: Bool
}

public final class ItemListNodeState {
    let presentationData: ItemListPresentationData
    let entries: [ItemListNodeAnyEntry]
    let style: ItemListStyle
    let emptyStateItem: ItemListControllerEmptyStateItem?
    let searchItem: ItemListControllerSearch?
    let toolbarItem: ItemListToolbarItem?
    let footerItem: ItemListControllerFooterItem?
    let animateChanges: Bool
    let crossfadeState: Bool
    let scrollEnabled: Bool
    let focusItemTag: ItemListItemTag?
    let ensureVisibleItemTag: ItemListItemTag?
    let initialScrollToItem: ListViewScrollToItem?
    
    public init<T: ItemListNodeEntry>(presentationData: ItemListPresentationData, entries: [T], style: ItemListStyle, focusItemTag: ItemListItemTag? = nil, ensureVisibleItemTag: ItemListItemTag? = nil, emptyStateItem: ItemListControllerEmptyStateItem? = nil, searchItem: ItemListControllerSearch? = nil, toolbarItem: ItemListToolbarItem? = nil, footerItem: ItemListControllerFooterItem? = nil, initialScrollToItem: ListViewScrollToItem? = nil, crossfadeState: Bool = false, animateChanges: Bool = true, scrollEnabled: Bool = true) {
        self.presentationData = presentationData
        self.entries = entries.map { $0 }
        self.style = style
        self.emptyStateItem = emptyStateItem
        self.searchItem = searchItem
        self.toolbarItem = toolbarItem
        self.footerItem = footerItem
        self.crossfadeState = crossfadeState
        self.animateChanges = animateChanges
        self.focusItemTag = focusItemTag
        self.ensureVisibleItemTag = ensureVisibleItemTag
        self.initialScrollToItem = initialScrollToItem
        self.scrollEnabled = scrollEnabled
    }
}

private final class ItemListNodeOpaqueState {
    let mergedEntries: [ItemListNodeAnyEntry]
    
    init(mergedEntries: [ItemListNodeAnyEntry]) {
        self.mergedEntries = mergedEntries
    }
}

public final class ItemListNodeVisibleEntries: Sequence {
    let iterate: () -> ItemListNodeAnyEntry?
    
    init(iterate: @escaping () -> ItemListNodeAnyEntry?) {
        self.iterate = iterate
    }
    
    public func makeIterator() -> AnyIterator<ItemListNodeAnyEntry> {
        return AnyIterator { () -> ItemListNodeAnyEntry? in
            return self.iterate()
        }
    }
}

public final class ItemListControllerNodeView: UITracingLayerView {
    var onLayout: (() -> Void)?
    
    init(controller: ItemListController?) {
        self.controller = controller
        
        super.init(frame: CGRect())
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        self.onLayout?()
    }
    
    private var inHitTest = false
    var hitTestImpl: ((CGPoint, UIEvent?) -> UIView?)?
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.inHitTest {
            return super.hitTest(point, with: event)
        } else {
            self.inHitTest = true
            let result = self.hitTestImpl?(point, event)
            self.inHitTest = false
            return result
        }
    }
    
    weak var controller: ItemListController?
}

open class ItemListControllerNode: ASDisplayNode {
    private var _ready = ValuePromise<Bool>()
    open var ready: Signal<Bool, NoError> {
        return self._ready.get()
    }
    private var didSetReady = false
    
    private let navigationBar: NavigationBar
    
    public let listNode: ListView
    private let leftOverlayNode: ASDisplayNode
    private let rightOverlayNode: ASDisplayNode
    private var emptyStateItem: ItemListControllerEmptyStateItem?
    private var emptyStateNode: ItemListControllerEmptyStateItemNode?
    
    private var toolbarNode: ToolbarNode?
    
    private var searchItem: ItemListControllerSearch?
    private var searchNode: ItemListControllerSearchNode?
    
    private var toolbarItem: ItemListToolbarItem?
    
    private var footerItem: ItemListControllerFooterItem?
    private var footerItemNode: ItemListControllerFooterItemNode?
    
    private let transitionDisposable = MetaDisposable()
    
    private var enqueuedTransitions: [ItemListNodeTransition] = []
    private var validLayout: (ContainerViewLayout, CGFloat, UIEdgeInsets)?
    
    private var theme: PresentationTheme?
    private var listStyle: ItemListStyle?
    
    private var appliedFocusItemTag: ItemListItemTag?
    private var appliedEnsureVisibleItemTag: ItemListItemTag?
    
    private var afterLayoutActions: [() -> Void] = []

    public var dismiss: (() -> Void)?
    
    public var visibleEntriesUpdated: ((ItemListNodeVisibleEntries) -> Void)?
    public var visibleBottomContentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)?
    public var beganInteractiveDragging: (() -> Void)?
    public var contentOffsetChanged: ((ListViewVisibleContentOffset, Bool) -> Void)?
    public var contentScrollingEnded: ((ListView) -> Bool)?
    public var searchActivated: ((Bool) -> Void)?
    public var reorderEntry: ((Int, Int, [ItemListNodeAnyEntry]) -> Signal<Bool, NoError>)?
    public var reorderCompleted: (([ItemListNodeAnyEntry]) -> Void)?
    public var requestLayout: ((ContainedViewLayoutTransition) -> Void)?
    
    public var enableInteractiveDismiss = false {
        didSet {
        }
    }

    var alwaysSynchronous = false
    
    private var previousContentOffset: ListViewVisibleContentOffset?
    
    public init(controller: ItemListController?, navigationBar: NavigationBar, state: Signal<(ItemListPresentationData, (ItemListNodeState, Any)), NoError>) {
        self.navigationBar = navigationBar
        
        self.listNode = ListView()
        self.leftOverlayNode = ASDisplayNode()
        self.leftOverlayNode.isUserInteractionEnabled = false
        self.rightOverlayNode = ASDisplayNode()
        self.rightOverlayNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.setViewBlock({ [weak controller] in
            return ItemListControllerNodeView(controller: controller)
        })
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.addSubnode(self.listNode)
        
        self.listNode.displayedItemRangeChanged = { [weak self] displayedRange, opaqueTransactionState in
            if let strongSelf = self, let visibleEntriesUpdated = strongSelf.visibleEntriesUpdated, let mergedEntries = (opaqueTransactionState as? ItemListNodeOpaqueState)?.mergedEntries {
                if let visible = displayedRange.visibleRange {
                    let indexRange = (visible.firstIndex, visible.lastIndex)
                    
                    var index = indexRange.0
                    let iterator = ItemListNodeVisibleEntries(iterate: {
                        var item: ItemListNodeAnyEntry?
                        if index <= indexRange.1 {
                            item = mergedEntries[index]
                        }
                        index += 1
                        return item
                    })
                    visibleEntriesUpdated(iterator)
                }
            }
        }
        
        self.listNode.reorderItem = { [weak self] fromIndex, toIndex, opaqueTransactionState in
            if let strongSelf = self, let reorderEntry = strongSelf.reorderEntry, let mergedEntries = (opaqueTransactionState as? ItemListNodeOpaqueState)?.mergedEntries {
                if fromIndex >= 0 && fromIndex < mergedEntries.count && toIndex >= 0 && toIndex < mergedEntries.count {
                    return reorderEntry(fromIndex, toIndex, mergedEntries)
                }
            }
            return .single(false)
        }
        
        self.listNode.reorderCompleted = { [weak self] opaqueTransactionState in
            if let strongSelf = self, let reorderCompleted = strongSelf.reorderCompleted, let mergedEntries = (opaqueTransactionState as? ItemListNodeOpaqueState)?.mergedEntries {
                reorderCompleted(mergedEntries)
            }
        }
        
        self.listNode.visibleBottomContentOffsetChanged = { [weak self] offset in
            self?.visibleBottomContentOffsetChanged?(offset)
            
            if let strongSelf = self {
                strongSelf.updateFooterBackgroundAlpha()
            }
        }
        
        self.listNode.visibleContentOffsetChanged = { [weak self] offset in
            var inVoiceOver = false
            if let validLayout = self?.validLayout {
                inVoiceOver = validLayout.0.inVoiceOver
            }
            
            self?.contentOffsetChanged?(offset, inVoiceOver)
            
            if let strongSelf = self {
                var previousContentOffsetValue: CGFloat?
                if let previousContentOffset = strongSelf.previousContentOffset {
                    if case let .known(value) = previousContentOffset {
                        previousContentOffsetValue = value
                    } else {
                        previousContentOffsetValue = 30.0
                    }
                }
                switch offset {
                    case let .known(value):
                        let transition: ContainedViewLayoutTransition
                        if let previousContentOffsetValue = previousContentOffsetValue, value <= 0.0, previousContentOffsetValue >= 30.0 {
                            transition = .animated(duration: 0.2, curve: .easeInOut)
                        } else {
                            transition = .immediate
                        }
                        strongSelf.navigationBar.updateBackgroundAlpha(min(30.0, value) / 30.0, transition: transition)
                    case .unknown, .none:
                        strongSelf.navigationBar.updateBackgroundAlpha(1.0, transition: .immediate)
                }
                
                strongSelf.previousContentOffset = offset
            }
        }
        
        self.listNode.beganInteractiveDragging = { [weak self] _ in
            if let strongSelf = self {
                strongSelf.beganInteractiveDragging?()
            }
        }
        
        self.listNode.didEndScrolling = { [weak self] _ in
            if let strongSelf = self {
                let _ = strongSelf.contentScrollingEnded?(strongSelf.listNode)
            }
        }
        
        self.listNode.itemNodeHitTest = { [weak self] point in
            if let strongSelf = self {
                return point.x > strongSelf.leftOverlayNode.frame.maxX && point.x < strongSelf.rightOverlayNode.frame.minX
            } else {
                return true
            }
        }
    
        let previousState = Atomic<ItemListNodeState?>(value: nil)
        self.transitionDisposable.set(((state
        |> map { presentationData, stateAndArguments -> ItemListNodeTransition in
            let (state, arguments) = stateAndArguments
            if state.entries.count > 1 {
                for i in 1 ..< state.entries.count {
                    assert(state.entries[i - 1].isLessThan(state.entries[i]))
                }
            }
            let previous = previousState.swap(state)
            let transition = preparedItemListNodeEntryTransition(from: previous?.entries ?? [], to: state.entries, presentationData: presentationData, arguments: arguments, presentationDataUpdated: previous?.presentationData != presentationData)
            var updatedStyle: ItemListStyle?
            if previous?.style != state.style {
                updatedStyle = state.style
            }
            
            var scrollToItem: ListViewScrollToItem?
            if previous == nil {
                scrollToItem = state.initialScrollToItem
            }
            
            return ItemListNodeTransition(theme: presentationData.theme, strings: presentationData.strings, entries: transition, updateStyle: updatedStyle, emptyStateItem: state.emptyStateItem, searchItem: state.searchItem, toolbarItem: state.toolbarItem, footerItem: state.footerItem, focusItemTag: state.focusItemTag, ensureVisibleItemTag: state.ensureVisibleItemTag, scrollToItem: scrollToItem, firstTime: previous == nil, animated: previous != nil && state.animateChanges, animateAlpha: previous != nil && state.animateChanges, crossfade: state.crossfadeState, mergedEntries: state.entries, scrollEnabled: state.scrollEnabled)
        })
        |> deliverOnMainQueue).start(next: { [weak self] transition in
            if let strongSelf = self {
                strongSelf.enqueueTransition(transition)
            }
        }))
    }
    
    deinit {
        self.transitionDisposable.dispose()
    }
    
    override open func didLoad() {
        super.didLoad()
        
        self.navigationBar.updateBackgroundAlpha(0.0, transition: .immediate)
        
        (self.view as? ItemListControllerNodeView)?.onLayout = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.afterLayoutActions.isEmpty {
                let afterLayoutActions = strongSelf.afterLayoutActions
                strongSelf.afterLayoutActions = []
                for f in afterLayoutActions {
                    f()
                }
            }
        }
        
        (self.view as? ItemListControllerNodeView)?.hitTestImpl = { [weak self] point, event in
            return self?.hitTest(point, with: event)
        }
    }
    
    open func animateIn(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
            completion?()
        })
    }
    
    open func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.dismiss?()
            }
            completion?()
        })
    }
    
    func updateFooterBackgroundAlpha() {
        guard let footerItemNode = self.footerItemNode else {
            return
        }

        switch self.listNode.visibleBottomContentOffset() {
            case let .known(value):
                let backgroundAlpha: CGFloat = min(30.0, value) / 30.0
                footerItemNode.updateBackgroundAlpha(backgroundAlpha, transition: .immediate)
            case .unknown, .none:
                footerItemNode.updateBackgroundAlpha(1.0, transition: .immediate)
        }
    }
    
    open func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition, additionalInsets: UIEdgeInsets) {
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        insets.bottom = max(insets.bottom, additionalInsets.bottom)
        
        let inset = max(16.0, floor((layout.size.width - 674.0) / 2.0))
        if layout.size.width >= 375.0 {
            insets.left += inset
            insets.right += inset
        }
        
        if self.rightOverlayNode.supernode == nil {
            self.insertSubnode(self.rightOverlayNode, aboveSubnode: self.listNode)
        }
        if self.leftOverlayNode.supernode == nil {
            self.insertSubnode(self.leftOverlayNode, aboveSubnode: self.listNode)
        }

        if let toolbarItem = self.toolbarItem {
            var tabBarHeight: CGFloat
            let bottomInset: CGFloat = insets.bottom
            if !layout.safeInsets.left.isZero {
                tabBarHeight = 34.0 + bottomInset
                insets.bottom += 34.0
            } else {
                tabBarHeight = 49.0 + bottomInset
                insets.bottom += 49.0
            }
            
            let toolbarFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - tabBarHeight), size: CGSize(width: layout.size.width, height: tabBarHeight))
            
            if let toolbarNode = self.toolbarNode {
                transition.updateFrame(node: toolbarNode, frame: toolbarFrame)
                toolbarNode.updateLayout(size: toolbarFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, additionalSideInsets: layout.additionalInsets, bottomInset: layout.intrinsicInsets.bottom, toolbar: toolbarItem.toolbar, transition: transition)
            } else if let theme = self.theme {
                let toolbarNode = ToolbarNode(theme: ToolbarTheme(rootControllerTheme: theme), displaySeparator: true)
                toolbarNode.frame = toolbarFrame
                toolbarNode.updateLayout(size: toolbarFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, additionalSideInsets: layout.additionalInsets, bottomInset: layout.intrinsicInsets.bottom, toolbar: toolbarItem.toolbar, transition: .immediate)
                self.addSubnode(toolbarNode)
                self.toolbarNode = toolbarNode
                if case let .animated(duration, curve) = transition {
                    toolbarNode.layer.animatePosition(from: CGPoint(x: 0.0, y: toolbarFrame.height), to: CGPoint(), duration: duration, mediaTimingFunction: curve.mediaTimingFunction, additive: true)
                }
            }
                
            self.toolbarNode?.left = {
                toolbarItem.actions[0].action()
            }
            self.toolbarNode?.right = {
                if toolbarItem.actions.count == 2 {
                    toolbarItem.actions[1].action()
                } else if toolbarItem.actions.count == 3 {
                    toolbarItem.actions[2].action()
                }
            }
            self.toolbarNode?.middle = {
                if toolbarItem.actions.count == 1 {
                    toolbarItem.actions[0].action()
                } else if toolbarItem.actions.count == 3 {
                    toolbarItem.actions[1].action()
                }
            }
        } else if let toolbarNode = self.toolbarNode {
            self.toolbarNode = nil
            if case let .animated(duration, curve) = transition {
                toolbarNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: toolbarNode.frame.size.height), duration: duration, mediaTimingFunction: curve.mediaTimingFunction, removeOnCompletion: false, additive: true, completion: { [weak toolbarNode] _ in
                    toolbarNode?.removeFromSupernode()
                })
            } else {
                toolbarNode.removeFromSupernode()
            }
        }
    
        if let footerItemNode = self.footerItemNode {
            let footerHeight = footerItemNode.updateLayout(layout: layout, transition: transition)
            insets.bottom += footerHeight
        }
        
        self.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.leftOverlayNode.frame = CGRect(x: 0.0, y: 0.0, width: insets.left, height: layout.size.height)
        self.rightOverlayNode.frame = CGRect(x: layout.size.width - insets.right, y: 0.0, width: insets.right, height: layout.size.height)
        
        if let emptyStateNode = self.emptyStateNode {
            emptyStateNode.updateLayout(layout: layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
        
        if let searchNode = self.searchNode {
            var layout = layout
            layout = layout.addedInsets(insets: additionalInsets)
            
            searchNode.updateLayout(layout: layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
                
        let dequeue = self.validLayout == nil
        self.validLayout = (layout, navigationBarHeight, additionalInsets)
        if dequeue {
            self.dequeueTransitions()
        }
        
        if !self.afterLayoutActions.isEmpty {
            let afterLayoutActions = self.afterLayoutActions
            self.afterLayoutActions = []
            for f in afterLayoutActions {
                f()
            }
        }
    }
    
    private func enqueueTransition(_ transition: ItemListNodeTransition) {
        self.enqueuedTransitions.append(transition)
        if self.validLayout != nil {
            self.dequeueTransitions()
        }
    }
    
    private func dequeueTransitions() {
        while !self.enqueuedTransitions.isEmpty {
            let transition = self.enqueuedTransitions.removeFirst()
            
            if transition.theme !== self.theme {
                self.theme = transition.theme
                
                if let listStyle = self.listStyle {
                    switch listStyle {
                        case .plain:
                            self.backgroundColor = transition.theme.list.plainBackgroundColor
                            self.listNode.backgroundColor = transition.theme.list.plainBackgroundColor
                            self.leftOverlayNode.backgroundColor = transition.theme.list.plainBackgroundColor
                            self.rightOverlayNode.backgroundColor = transition.theme.list.plainBackgroundColor
                        case .blocks:
                            self.backgroundColor = transition.theme.list.blocksBackgroundColor
                            self.listNode.backgroundColor = transition.theme.list.blocksBackgroundColor
                            self.leftOverlayNode.backgroundColor = transition.theme.list.blocksBackgroundColor
                            self.rightOverlayNode.backgroundColor = transition.theme.list.blocksBackgroundColor
                    }
                }
                
                self.listNode.forEachItemHeaderNode({ itemHeaderNode in
                    if let itemHeaderNode = itemHeaderNode as? ItemListHeaderItemNode {
                        itemHeaderNode.updateTheme(theme: transition.theme)
                    }
                })
            }
            
            if let updateStyle = transition.updateStyle {
                self.listStyle = updateStyle
                
                if let _ = self.theme {
                    switch updateStyle {
                        case .plain:
                            self.backgroundColor = transition.theme.list.plainBackgroundColor
                            self.listNode.backgroundColor = transition.theme.list.plainBackgroundColor
                            self.leftOverlayNode.backgroundColor = transition.theme.list.plainBackgroundColor
                            self.rightOverlayNode.backgroundColor = transition.theme.list.plainBackgroundColor
                        
                            self.leftOverlayNode.isHidden = true
                            self.rightOverlayNode.isHidden = true
                        case .blocks:
                            self.backgroundColor = transition.theme.list.blocksBackgroundColor
                            self.listNode.backgroundColor = transition.theme.list.blocksBackgroundColor
                            self.leftOverlayNode.backgroundColor = transition.theme.list.blocksBackgroundColor
                            self.rightOverlayNode.backgroundColor = transition.theme.list.blocksBackgroundColor
                        
                            self.leftOverlayNode.isHidden = false
                            self.rightOverlayNode.isHidden = false
                    }
                }
            }
            
            var options = ListViewDeleteAndInsertOptions()
            if transition.firstTime {
                options.insert(.Synchronous)
                options.insert(.LowLatency)
                options.insert(.PreferSynchronousResourceLoading)
                options.insert(.PreferSynchronousDrawing)
            } else if transition.animated {
                options.insert(.AnimateInsertion)
            } else if transition.animateAlpha {
                options.insert(.PreferSynchronousResourceLoading)
                options.insert(.PreferSynchronousDrawing)
                options.insert(.AnimateAlpha)
            } else if transition.crossfade {
                options.insert(.PreferSynchronousResourceLoading)
                options.insert(.PreferSynchronousDrawing)
                options.insert(.AnimateCrossfade)
            } else {
                options.insert(.Synchronous)
                options.insert(.PreferSynchronousResourceLoading)
                options.insert(.PreferSynchronousDrawing)
            }
            if self.alwaysSynchronous {
                options.insert(.Synchronous)
                options.insert(.LowLatency)
            }
            let focusItemTag = transition.focusItemTag
            let ensureVisibleItemTag = transition.ensureVisibleItemTag
            var scrollToItem: ListViewScrollToItem?
            if let item = transition.scrollToItem {
                scrollToItem = item
            } else if self.listNode.experimentalSnapScrollToItem, let ensureVisibleItemTag = ensureVisibleItemTag {
                for i in 0 ..< transition.mergedEntries.count {
                    if let tag = transition.mergedEntries[i].tag, tag.isEqual(to: ensureVisibleItemTag) {
                        scrollToItem = ListViewScrollToItem(index: i, position: ListViewScrollPosition.visible, animated: true, curve: .Default(duration: nil), directionHint: .Down)
                    }
                }
            }
            
            var updateSearchItem = false
            if let searchItem = self.searchItem, let updatedSearchItem = transition.searchItem {
                updateSearchItem = !searchItem.isEqual(to: updatedSearchItem)
            } else if (self.searchItem != nil) != (transition.searchItem != nil) {
                updateSearchItem = true
            }
            if updateSearchItem {
                self.searchItem = transition.searchItem
                if let searchItem = transition.searchItem {
                    let updatedTitleContentNode = searchItem.titleContentNode(current: self.navigationBar.contentNode as? (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode))
                    if updatedTitleContentNode !== self.navigationBar.contentNode {
                        if let titleContentNode = self.navigationBar.contentNode as? ItemListControllerSearchNavigationContentNode {
                            titleContentNode.deactivate()
                        }
                        updatedTitleContentNode.setQueryUpdated { [weak self] query in
                            if let strongSelf = self {
                                strongSelf.searchNode?.queryUpdated(query)
                            }
                        }
                        self.navigationBar.setContentNode(updatedTitleContentNode, animated: true)
                        updatedTitleContentNode.activate()
                    }
                    
                    let updatedNode = searchItem.node(current: self.searchNode, titleContentNode: updatedTitleContentNode)
                    if let searchNode = self.searchNode, updatedNode !== searchNode {
                        searchNode.removeFromSupernode()
                    }
                    if self.searchNode !== updatedNode {
                        self.searchNode = updatedNode
                        if let validLayout = self.validLayout {
                            updatedNode.updateLayout(layout: validLayout.0, navigationBarHeight: validLayout.1, transition: .immediate)
                        }
                        if self.rightOverlayNode.supernode != nil {
                            self.insertSubnode(updatedNode, aboveSubnode: self.rightOverlayNode)
                        } else {
                            self.insertSubnode(updatedNode, aboveSubnode: self.listNode)
                        }
                        updatedNode.activate()
                    }
                } else {
                    if let searchNode = self.searchNode {
                        self.searchNode = nil
                        searchNode.deactivate()
                    }
                    
                    if let titleContentNode = self.navigationBar.contentNode {
                        if let titleContentNode = titleContentNode as? ItemListControllerSearchNavigationContentNode {
                            titleContentNode.deactivate()
                        }
                        self.navigationBar.setContentNode(nil, animated: true)
                    }
                }
            }
            
            self.listNode.accessibilityPageScrolledString = { row, count in
                return transition.strings.VoiceOver_ScrollStatus(row, count).string
            }
            
            var updateToolbarItem = false
            if let toolbarItem = self.toolbarItem, let updatedToolbarItem = transition.toolbarItem {
                updateToolbarItem = !toolbarItem.isEqual(to: updatedToolbarItem)
            } else if (self.toolbarItem != nil) != (transition.toolbarItem != nil) {
                updateToolbarItem = true
            }
            if updateToolbarItem {
                self.toolbarItem = transition.toolbarItem
            }
            
            self.listNode.transaction(deleteIndices: transition.entries.deletions, insertIndicesAndItems: transition.entries.insertions, updateIndicesAndItems: transition.entries.updates, options: options, scrollToItem: scrollToItem, updateOpaqueState: ItemListNodeOpaqueState(mergedEntries: transition.mergedEntries), completion: { [weak self] _ in
                if let strongSelf = self {
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(true)
                    }
                    
                    var updatedFocusItemTag = false
                    if let appliedFocusItemTag = strongSelf.appliedFocusItemTag, let focusItemTag = focusItemTag {
                        updatedFocusItemTag = !appliedFocusItemTag.isEqual(to: focusItemTag)
                    } else if (strongSelf.appliedFocusItemTag != nil) != (focusItemTag != nil) {
                        updatedFocusItemTag = true
                    }
                    if updatedFocusItemTag {
                        if let focusItemTag = focusItemTag {
                            strongSelf.listNode.forEachItemNode { itemNode in
                                if let itemNode = itemNode as? ItemListItemNode {
                                    if let itemTag = itemNode.tag {
                                        if itemTag.isEqual(to: focusItemTag) {
                                            if let focusableNode = itemNode as? ItemListItemFocusableNode {
                                                focusableNode.focus()
                                            }
                                        }
                                    }
                                }
                            }
                            strongSelf.appliedFocusItemTag = focusItemTag
                        }
                    }
                    
                    var updatedEnsureVisibleItemTag = false
                    if let appliedEnsureVisibleTag = strongSelf.appliedEnsureVisibleItemTag, let ensureVisibleItemTag = ensureVisibleItemTag {
                        updatedEnsureVisibleItemTag = !appliedEnsureVisibleTag.isEqual(to: ensureVisibleItemTag)
                    } else if (strongSelf.appliedEnsureVisibleItemTag != nil) != (ensureVisibleItemTag != nil) {
                        updatedEnsureVisibleItemTag = true
                    }
                    if updatedEnsureVisibleItemTag {
                        if let ensureVisibleItemTag = ensureVisibleItemTag {
                            var applied = false
                            strongSelf.listNode.forEachItemNode { itemNode in
                                if let itemNode = itemNode as? ItemListItemNode {
                                    if let itemTag = itemNode.tag {
                                        if itemTag.isEqual(to: ensureVisibleItemTag) {
                                            if let itemNode = itemNode as? ListViewItemNode {
                                                strongSelf.listNode.ensureItemNodeVisible(itemNode)
                                                applied = true
                                            }
                                        }
                                    }
                                }
                            }
                            if applied {
                                strongSelf.appliedEnsureVisibleItemTag = ensureVisibleItemTag
                            }
                        }
                    }
                }
            })
            var updateEmptyStateItem = false
            if let emptyStateItem = self.emptyStateItem, let updatedEmptyStateItem = transition.emptyStateItem {
                updateEmptyStateItem = !emptyStateItem.isEqual(to: updatedEmptyStateItem)
            } else if (self.emptyStateItem != nil) != (transition.emptyStateItem != nil) {
                updateEmptyStateItem = true
            }
            if updateEmptyStateItem {
                self.emptyStateItem = transition.emptyStateItem
                if let emptyStateItem = transition.emptyStateItem {
                    let updatedNode = emptyStateItem.node(current: self.emptyStateNode)
                    if let emptyStateNode = self.emptyStateNode, updatedNode !== emptyStateNode {
                        emptyStateNode.removeFromSupernode()
                    }
                    if self.emptyStateNode !== updatedNode {
                        self.emptyStateNode = updatedNode
                        if let validLayout = self.validLayout {
                            updatedNode.updateLayout(layout: validLayout.0, navigationBarHeight: validLayout.1, transition: .immediate)
                        }
                        self.addSubnode(updatedNode)
                    }
                } else if let emptyStateNode = self.emptyStateNode {
                    emptyStateNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak emptyStateNode] _ in
                        emptyStateNode?.removeFromSupernode()
                    })
                    self.emptyStateNode = nil
                }
            }
            var updateFooterItem = false
            if let footerItem = self.footerItem, let updatedFooterItem = transition.footerItem {
                updateFooterItem = !footerItem.isEqual(to: updatedFooterItem)
            } else if (self.footerItem != nil) != (transition.footerItem != nil) {
                updateFooterItem = true
            }
            if updateFooterItem {
                self.footerItem = transition.footerItem
                if let footerItem = transition.footerItem {
                    let updatedNode = footerItem.node(current: self.footerItemNode)
                    if let footerItemNode = self.footerItemNode, updatedNode !== footerItemNode {
                        footerItemNode.removeFromSupernode()
                    }
                    if self.footerItemNode !== updatedNode {
                        self.footerItemNode = updatedNode
                        if let validLayout = self.validLayout {
                            let _ = updatedNode.updateLayout(layout: validLayout.0, transition: .immediate)
                        }
                        self.addSubnode(updatedNode)
                    }
                } else if let footerItemNode = self.footerItemNode {
                    footerItemNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak footerItemNode] _ in
                        footerItemNode?.removeFromSupernode()
                    })
                    self.footerItemNode = nil
                }
            }
            self.listNode.scrollEnabled = transition.scrollEnabled
            
            if updateSearchItem {
                self.requestLayout?(.animated(duration: 0.3, curve: .spring))
            } else if updateToolbarItem || updateFooterItem, let (layout, navigationBarHeight, additionalInsets) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.3, curve: .spring), additionalInsets: additionalInsets)
            }
        }
    }
    
    open func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        self.searchNode?.scrollToTop()
    }
    
    open func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        targetContentOffset.pointee = scrollView.contentOffset
        
        let scrollVelocity = scrollView.panGestureRecognizer.velocity(in: scrollView)
        if abs(scrollVelocity.y) > 200.0 {
           self.animateOut()
        }
    }
    
    override open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let searchNode = self.searchNode {
            if !self.navigationBar.isHidden && self.navigationBar.supernode != nil {
                if let result = self.navigationBar.hitTest(self.view.convert(point, to: self.navigationBar.view), with: event) {
                    return result
                }
            }
            if let result = searchNode.hitTest(point, with: event) {
                return result
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    open func afterLayout(_ f: @escaping () -> Void) {
        self.afterLayoutActions.append(f)
        self.view.setNeedsLayout()
    }
}
