import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import MergeLists

typealias ItemListSectionId = Int32

protocol ItemListNodeAnyEntry {
    var anyId: AnyHashable { get }
    var tag: ItemListItemTag? { get }
    func isLessThan(_ rhs: ItemListNodeAnyEntry) -> Bool
    func isEqual(_ rhs: ItemListNodeAnyEntry) -> Bool
    func item(_ arguments: Any) -> ListViewItem
}

protocol ItemListNodeEntry: Comparable, Identifiable, ItemListNodeAnyEntry {
    var section: ItemListSectionId { get }
}

extension ItemListNodeEntry {
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

extension ItemListNodeEntry {
    var tag: ItemListItemTag? { return nil }
}

private struct ItemListNodeEntryTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedItemListNodeEntryTransition(from fromEntries: [ItemListNodeAnyEntry], to toEntries: [ItemListNodeAnyEntry], arguments: Any) -> ItemListNodeEntryTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, isLess: { lhs, rhs in
        return lhs.isLessThan(rhs)
    }, isEqual: { lhs, rhs in
        return lhs.isEqual(rhs)
    }, getId: { value in
        return value.anyId
    })
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(arguments), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(arguments), directionHint: nil) }
    
    return ItemListNodeEntryTransition(deletions: deletions, insertions: insertions, updates: updates)
}

enum ItemListStyle {
    case plain
    case blocks
}

private struct ItemListNodeTransition {
    let theme: WalletTheme
    let entries: ItemListNodeEntryTransition
    let updateStyle: ItemListStyle?
    let emptyStateItem: ItemListControllerEmptyStateItem?
    let searchItem: ItemListControllerSearch?
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

final class ItemListNodeState {
    let entries: [ItemListNodeAnyEntry]
    let style: ItemListStyle
    let emptyStateItem: ItemListControllerEmptyStateItem?
    let searchItem: ItemListControllerSearch?
    let animateChanges: Bool
    let crossfadeState: Bool
    let scrollEnabled: Bool
    let focusItemTag: ItemListItemTag?
    let ensureVisibleItemTag: ItemListItemTag?
    let initialScrollToItem: ListViewScrollToItem?
    
    init<T: ItemListNodeEntry>(entries: [T], style: ItemListStyle, focusItemTag: ItemListItemTag? = nil, ensureVisibleItemTag: ItemListItemTag? = nil, emptyStateItem: ItemListControllerEmptyStateItem? = nil, searchItem: ItemListControllerSearch? = nil, initialScrollToItem: ListViewScrollToItem? = nil, crossfadeState: Bool = false, animateChanges: Bool = true, scrollEnabled: Bool = true) {
        self.entries = entries.map { $0 }
        self.style = style
        self.emptyStateItem = emptyStateItem
        self.searchItem = searchItem
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

final class ItemListNodeVisibleEntries: Sequence {
    let iterate: () -> ItemListNodeAnyEntry?
    
    init(iterate: @escaping () -> ItemListNodeAnyEntry?) {
        self.iterate = iterate
    }
    
    func makeIterator() -> AnyIterator<ItemListNodeAnyEntry> {
        return AnyIterator { () -> ItemListNodeAnyEntry? in
            return self.iterate()
        }
    }
}

final class ItemListControllerNodeView: UITracingLayerView, PreviewingHostView {
    var onLayout: (() -> Void)?
    
    init(controller: ItemListController?) {
        self.controller = controller
        
        super.init(frame: CGRect())
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.onLayout?()
    }
    
    private var inHitTest = false
    var hitTestImpl: ((CGPoint, UIEvent?) -> UIView?)?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.inHitTest {
            return super.hitTest(point, with: event)
        } else {
            self.inHitTest = true
            let result = self.hitTestImpl?(point, event)
            self.inHitTest = false
            return result
        }
    }
    
    var previewingDelegate: PreviewingHostViewDelegate? {
        return PreviewingHostViewDelegate(controllerForLocation: { [weak self] sourceView, point in
            return self?.controller?.previewingController(from: sourceView, for: point)
        }, commitController: { [weak self] controller in
            self?.controller?.previewingCommit(controller)
        })
    }
    
    weak var controller: ItemListController?
}

class ItemListControllerNode: ASDisplayNode, UIScrollViewDelegate {
    private var _ready = ValuePromise<Bool>()
    var ready: Signal<Bool, NoError> {
        return self._ready.get()
    }
    private var didSetReady = false
    
    private let navigationBar: NavigationBar
    
    let listNode: ListView
    private let leftOverlayNode: ASDisplayNode
    private let rightOverlayNode: ASDisplayNode
    private var emptyStateItem: ItemListControllerEmptyStateItem?
    private var emptyStateNode: ItemListControllerEmptyStateItemNode?
    
    private var searchItem: ItemListControllerSearch?
    private var searchNode: ItemListControllerSearchNode?
    
    private let transitionDisposable = MetaDisposable()
    
    private var enqueuedTransitions: [ItemListNodeTransition] = []
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private var theme: WalletTheme?
    private var listStyle: ItemListStyle?
    
    private var appliedFocusItemTag: ItemListItemTag?
    private var appliedEnsureVisibleItemTag: ItemListItemTag?
    
    private var afterLayoutActions: [() -> Void] = []
    
    let updateNavigationOffset: (CGFloat) -> Void
    var dismiss: (() -> Void)?
    
    var visibleEntriesUpdated: ((ItemListNodeVisibleEntries) -> Void)?
    var visibleBottomContentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)?
    var contentOffsetChanged: ((ListViewVisibleContentOffset, Bool) -> Void)?
    var contentScrollingEnded: ((ListView) -> Bool)?
    var searchActivated: ((Bool) -> Void)?
    var reorderEntry: ((Int, Int, [ItemListNodeAnyEntry]) -> Void)?
    var requestLayout: ((ContainedViewLayoutTransition) -> Void)?
    
    var enableInteractiveDismiss = false {
        didSet {
        }
    }

    var alwaysSynchronous = false
    
    init(controller: ItemListController?, navigationBar: NavigationBar, updateNavigationOffset: @escaping (CGFloat) -> Void, state: Signal<(WalletTheme, (ItemListNodeState, Any)), NoError>) {
        self.navigationBar = navigationBar
        self.updateNavigationOffset = updateNavigationOffset
        
        self.listNode = ListView()
        self.leftOverlayNode = ASDisplayNode()
        self.rightOverlayNode = ASDisplayNode()
        
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
                    reorderEntry(fromIndex, toIndex, mergedEntries)
                }
            }
            return .single(false)
        }
        
        self.listNode.visibleBottomContentOffsetChanged = { [weak self] offset in
            self?.visibleBottomContentOffsetChanged?(offset)
        }
        
        self.listNode.visibleContentOffsetChanged = { [weak self] offset in
            var inVoiceOver = false
            if let validLayout = self?.validLayout {
                inVoiceOver = validLayout.0.inVoiceOver
            }
            self?.contentOffsetChanged?(offset, inVoiceOver)
        }
        
        self.listNode.didEndScrolling = { [weak self] in
            if let strongSelf = self {
                let _ = strongSelf.contentScrollingEnded?(strongSelf.listNode)
            }
        }
        
        let previousState = Atomic<ItemListNodeState?>(value: nil)
        self.transitionDisposable.set(((state |> map { theme, stateAndArguments -> ItemListNodeTransition in
            let (state, arguments) = stateAndArguments
            if state.entries.count > 1 {
                for i in 1 ..< state.entries.count {
                    assert(state.entries[i - 1].isLessThan(state.entries[i]))
                }
            }
            let previous = previousState.swap(state)
            let transition = preparedItemListNodeEntryTransition(from: previous?.entries ?? [], to: state.entries, arguments: arguments)
            var updatedStyle: ItemListStyle?
            if previous?.style != state.style {
                updatedStyle = state.style
            }
            
            var scrollToItem: ListViewScrollToItem?
            if previous == nil {
                scrollToItem = state.initialScrollToItem
            }
            
            return ItemListNodeTransition(theme: theme, entries: transition, updateStyle: updatedStyle, emptyStateItem: state.emptyStateItem, searchItem: state.searchItem, focusItemTag: state.focusItemTag, ensureVisibleItemTag: state.ensureVisibleItemTag, scrollToItem: scrollToItem, firstTime: previous == nil, animated: previous != nil && state.animateChanges, animateAlpha: previous != nil && state.animateChanges, crossfade: state.crossfadeState, mergedEntries: state.entries, scrollEnabled: state.scrollEnabled)
        }) |> deliverOnMainQueue).start(next: { [weak self] transition in
            if let strongSelf = self {
                strongSelf.enqueueTransition(transition)
            }
        }))
    }
    
    deinit {
        self.transitionDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
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
    
    func animateIn(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
            completion?()
        })
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.dismiss?()
            }
            completion?()
        })
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        var addedInsets: UIEdgeInsets?
        if layout.size.width > 480.0 {
            let inset = max(20.0, floor((layout.size.width - 674.0) / 2.0))
            insets.left += inset
            insets.right += inset
            addedInsets = UIEdgeInsets(top: 0.0, left: inset, bottom: 0.0, right: inset)
            
            if self.leftOverlayNode.supernode == nil {
                self.insertSubnode(self.leftOverlayNode, aboveSubnode: self.listNode)
            }
            if self.rightOverlayNode.supernode == nil {
                self.insertSubnode(self.rightOverlayNode, aboveSubnode: self.listNode)
            }
        } else {
            insets.left += layout.safeInsets.left
            insets.right += layout.safeInsets.right
            
            if self.leftOverlayNode.supernode != nil {
                self.leftOverlayNode.removeFromSupernode()
            }
            if self.rightOverlayNode.supernode != nil {
                self.rightOverlayNode.removeFromSupernode()
            }
        }
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        self.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.leftOverlayNode.frame = CGRect(x: 0.0, y: 0.0, width: insets.left, height: layout.size.height)
        self.rightOverlayNode.frame = CGRect(x: layout.size.width - insets.right, y: 0.0, width: insets.right, height: layout.size.height)
        
        if let emptyStateNode = self.emptyStateNode {
            var layout = layout
            if let addedInsets = addedInsets {
                layout = layout.addedInsets(insets: addedInsets)
            }
            emptyStateNode.updateLayout(layout: layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
        
        if let searchNode = self.searchNode {
            searchNode.updateLayout(layout: layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
        
        let dequeue = self.validLayout == nil
        self.validLayout = (layout, navigationBarHeight)
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
                        case .blocks:
                            self.backgroundColor = transition.theme.list.blocksBackgroundColor
                            self.listNode.backgroundColor = transition.theme.list.blocksBackgroundColor
                            self.leftOverlayNode.backgroundColor = transition.theme.list.blocksBackgroundColor
                            self.rightOverlayNode.backgroundColor = transition.theme.list.blocksBackgroundColor
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
                options.insert(.AnimateCrossfade)
            } else {
                options.insert(.Synchronous)
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
                        self.insertSubnode(updatedNode, belowSubnode: self.navigationBar)
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
                    self.listNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.emptyStateNode = nil
                }
            }
            self.listNode.scrollEnabled = transition.scrollEnabled
            
            if updateSearchItem {
                self.requestLayout?(.animated(duration: 0.3, curve: .spring))
            }
        }
    }
    
    func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        self.searchNode?.scrollToTop()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let distanceFromEquilibrium = scrollView.contentOffset.y - scrollView.contentSize.height / 3.0
        self.updateNavigationOffset(-distanceFromEquilibrium)
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        targetContentOffset.pointee = scrollView.contentOffset
        
        let scrollVelocity = scrollView.panGestureRecognizer.velocity(in: scrollView)
        if abs(scrollVelocity.y) > 200.0 {
           self.animateOut()
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let searchNode = self.searchNode {
            if let result = searchNode.hitTest(point, with: event) {
                return result
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    func afterLayout(_ f: @escaping () -> Void) {
        self.afterLayoutActions.append(f)
        self.view.setNeedsLayout()
    }
}
