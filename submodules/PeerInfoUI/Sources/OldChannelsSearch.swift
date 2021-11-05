import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import MergeLists
import ItemListUI
import PresentationDataUtils
import AccountContext
import SearchBarNode
import SearchUI
import ChatListSearchItemHeader
import ContactsPeerItem

extension NavigationBarSearchContentNode: ItemListControllerSearchNavigationContentNode {
    public func activate() {
    }
    
    public func deactivate() {
    }
    
    public func setQueryUpdated(_ f: @escaping (String) -> Void) {
    }
}

final class OldChannelsSearchItem: ItemListControllerSearch {
    let context: AccountContext
    let theme: PresentationTheme
    let placeholder: String
    let activated: Bool
    let updateActivated: (Bool) -> Void
    let peers: Signal<[InactiveChannel], NoError>
    let selectedPeerIds: Signal<Set<PeerId>, NoError>
    let togglePeer: (PeerId) -> Void
    
    private var updateActivity: ((Bool) -> Void)?
    private var activity: ValuePromise<Bool> = ValuePromise(ignoreRepeated: false)
    private let activityDisposable = MetaDisposable()
    
    init(context: AccountContext, theme: PresentationTheme, placeholder: String, activated: Bool, updateActivated: @escaping (Bool) -> Void, peers: Signal<[InactiveChannel], NoError>, selectedPeerIds: Signal<Set<PeerId>, NoError>, togglePeer: @escaping (PeerId) -> Void) {
        self.context = context
        self.theme = theme
        self.placeholder = placeholder
        self.activated = activated
        self.updateActivated = updateActivated
        self.peers = peers
        self.selectedPeerIds = selectedPeerIds
        self.togglePeer = togglePeer
    }
    
    deinit {
        self.activityDisposable.dispose()
    }
    
    func isEqual(to: ItemListControllerSearch) -> Bool {
        if let to = to as? OldChannelsSearchItem {
            if self.context !== to.context || self.theme !== to.theme || self.placeholder != to.placeholder || self.activated != to.activated {
                return false
            }
            return true
        } else {
            return false
        }
    }
    
    func titleContentNode(current: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> NavigationBarContentNode & ItemListControllerSearchNavigationContentNode {
        let updateActivated: (Bool) -> Void = self.updateActivated
        if let current = current as? NavigationBarSearchContentNode {
            current.updateThemeAndPlaceholder(theme: self.theme, placeholder: self.placeholder)
            return current
        } else {
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            return NavigationBarSearchContentNode(theme: presentationData.theme, placeholder: presentationData.strings.Settings_Search, activate: {
                updateActivated(true)
            })
        }
    }
    
    func node(current: ItemListControllerSearchNode?, titleContentNode: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> ItemListControllerSearchNode {
        let updateActivated: (Bool) -> Void = self.updateActivated
        
        if let current = current as? OldChannelsSearchItemNode, let titleContentNode = titleContentNode as? NavigationBarSearchContentNode {
            current.updatePresentationData(self.context.sharedContext.currentPresentationData.with { $0 })
            if current.isSearching != self.activated {
                if self.activated {
                    current.activateSearch(placeholderNode: titleContentNode.placeholderNode)
                } else {
                    current.deactivateSearch(placeholderNode: titleContentNode.placeholderNode)
                }
            }
            return current
        } else {
            return OldChannelsSearchItemNode(context: self.context, cancel: {
                updateActivated(false)
            }, peers: self.peers, selectedPeerIds: self.selectedPeerIds, togglePeer: self.togglePeer)
        }
    }
}

private final class OldChannelsSearchInteraction {
    let togglePeer: (PeerId) -> Void
    
    init(togglePeer: @escaping (PeerId) -> Void) {
        self.togglePeer = togglePeer
    }
}

private enum OldChannelsSearchEntry: Comparable, Identifiable {
    case peer(Int, InactiveChannel, Bool)
    
    var stableId: PeerId {
        switch self {
        case let .peer(_, peer, _):
            return peer.peer.id
        }
    }
    
    private func index() -> Int {
        switch self {
        case let .peer(index, _, _):
            return index
        }
    }
    
    static func <(lhs: OldChannelsSearchEntry, rhs: OldChannelsSearchEntry) -> Bool {
        return lhs.index() < rhs.index()
    }
    
    static func ==(lhs: OldChannelsSearchEntry, rhs: OldChannelsSearchEntry) -> Bool {
        if case let .peer(index, peer, isSelected) = lhs {
            if case .peer(index, peer, isSelected) = rhs {
                return true
            }
        }
        return false
    }
    
    func item(context: AccountContext, presentationData: ItemListPresentationData, interaction: OldChannelsSearchInteraction)  -> ListViewItem {
        switch self {
        case let .peer(_, peer, selected):
            return ContactsPeerItem(presentationData: presentationData, style: .plain, sortOrder: .firstLast, displayOrder: .firstLast, context: context, peerMode: .peer, peer: .peer(peer: EnginePeer(peer.peer), chatPeer: EnginePeer(peer.peer)), status: .custom(string: localizedOldChannelDate(peer: peer, strings: presentationData.strings), multiline: false), badge: nil, enabled: true, selection: ContactsPeerItemSelection.selectable(selected: selected), editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), options: [], actionIcon: .none, index: nil, header: nil, action: { _ in
                interaction.togglePeer(peer.peer.id)
            }, setPeerIdWithRevealedOptions: nil, deletePeer: nil, itemHighlighting: nil, contextAction: nil)
        }
    }
}

private struct OldChannelsSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
}

private func preparedOldChannelsSearchContainerTransition(presentationData: ItemListPresentationData, from fromEntries: [OldChannelsSearchEntry], to toEntries: [OldChannelsSearchEntry], context: AccountContext, interaction: OldChannelsSearchInteraction, isSearching: Bool, forceUpdate: Bool) -> OldChannelsSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, allUpdated: forceUpdate)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    
    return OldChannelsSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, isSearching: isSearching)
}

private final class OldChannelsSearchContainerNode: SearchDisplayControllerContentNode {
    private let listNode: ListView
    
    private var enqueuedTransitions: [OldChannelsSearchContainerTransition] = []
    private var hasValidLayout = false
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private var recentDisposable: Disposable?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let presentationDataPromise: Promise<PresentationData>
    
    init(context: AccountContext, peers: Signal<[InactiveChannel], NoError>, selectedPeerIds: Signal<Set<PeerId>, NoError>, togglePeer: @escaping (PeerId) -> Void) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(self.presentationData)
        
        self.listNode = ListView()
        self.listNode.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.listNode.isHidden = true
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.listNode)
        
        let interaction = OldChannelsSearchInteraction(togglePeer: { [weak self] peerId in
            togglePeer(peerId)
            
            if let strongSelf = self {
                strongSelf.listNode.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? ContactsPeerItemNode, let peer = itemNode.chatPeer, peer.id == peerId {
                        strongSelf.listNode.ensureItemNodeVisible(itemNode, curve: .Spring(duration: 0.3))
                    }
                }
            }
        })
        
        let queryAndFoundItems: Signal<(String, [OldChannelsSearchEntry])?, NoError> = combineLatest(self.searchQuery.get(), peers, selectedPeerIds)
        |> mapToSignal { query, peers, selectedPeerIds -> Signal<(String, [OldChannelsSearchEntry])?, NoError> in
            if let query = query, !query.isEmpty {
                var results: [OldChannelsSearchEntry] = []
                let normalizedQuery = query.lowercased()
                for peer in peers {
                    if peer.peer.indexName.matchesByTokens(normalizedQuery) {
                        results.append(.peer(results.count, peer, selectedPeerIds.contains(peer.peer.id)))
                    }
                }
                return .single((query, results))
            } else {
                return .single(nil)
            }
        }
        
        let previousEntriesHolder = Atomic<([OldChannelsSearchEntry], PresentationTheme, PresentationStrings)?>(value: nil)
        self.searchDisposable.set(combineLatest(queue: .mainQueue(), queryAndFoundItems, self.presentationDataPromise.get()).start(next: { [weak self] queryAndFoundItems, presentationData in
            guard let strongSelf = self else {
                return
            }
            var currentQuery: String?
            var entries: [OldChannelsSearchEntry] = []
            if let (query, items) = queryAndFoundItems {
                currentQuery = query
                for item in items {
                    entries.append(item)
                }
            }
            
            if !entries.isEmpty || currentQuery == nil {
                let previousEntriesAndPresentationData = previousEntriesHolder.swap((entries, presentationData.theme, presentationData.strings))
                let transition = preparedOldChannelsSearchContainerTransition(presentationData: ItemListPresentationData(presentationData), from: previousEntriesAndPresentationData?.0 ?? [], to: entries, context: context, interaction: interaction, isSearching: queryAndFoundItems != nil, forceUpdate: previousEntriesAndPresentationData?.1 !== presentationData.theme || previousEntriesAndPresentationData?.2 !== presentationData.strings)
                strongSelf.enqueueTransition(transition)
            }
        }))
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings(theme: presentationData.theme, strings: presentationData.strings)
                    strongSelf.presentationDataPromise.set(.single(presentationData))
                }
            }
        })
        
        self.listNode.beganInteractiveDragging = { [weak self] _ in
            self?.dismissInput?()
        }
    }
    
    deinit {
        self.searchDisposable.dispose()
        self.recentDisposable?.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.listNode.backgroundColor = theme.chatList.backgroundColor
    }
    
    override func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
    }
    
    private func enqueueTransition(_ transition: OldChannelsSearchContainerTransition) {
        self.enqueuedTransitions.append(transition)
        
        if self.hasValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let transition = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.Synchronous)
            options.insert(.PreferSynchronousDrawing)
            options.insert(.PreferSynchronousResourceLoading)
            
            let isSearching = transition.isSearching
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                self?.listNode.isHidden = !isSearching
            })
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
                
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        insets.left += layout.safeInsets.left
        insets.right += layout.safeInsets.right
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !self.hasValidLayout {
            self.hasValidLayout = true
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    override func scrollToTop() {
        let listNodeToScroll: ListView = self.listNode
        listNodeToScroll.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
}

private final class OldChannelsSearchItemNode: ItemListControllerSearchNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    private var searchDisplayController: SearchDisplayController?
    
    var cancel: () -> Void
    private let peers: Signal<[InactiveChannel], NoError>
    private let selectedPeerIds: Signal<Set<PeerId>, NoError>
    private let togglePeer: (PeerId) -> Void
    
    init(context: AccountContext, cancel: @escaping () -> Void, peers: Signal<[InactiveChannel], NoError>, selectedPeerIds: Signal<Set<PeerId>, NoError>, togglePeer: @escaping (PeerId) -> Void) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.cancel = cancel
        self.peers = peers
        self.selectedPeerIds = selectedPeerIds
        self.togglePeer = togglePeer
        
        super.init()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.searchDisplayController?.updatePresentationData(presentationData)
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, self.searchDisplayController == nil else {
            return
        }
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: OldChannelsSearchContainerNode(context: self.context, peers: self.peers, selectedPeerIds: self.selectedPeerIds, togglePeer: self.togglePeer), cancel: { [weak self] in
            self?.cancel()
        })
        
        self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
            if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
                if isSearchBar {
                    strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
                } else {
                    strongSelf.addSubnode(subnode)
                }
            }
        }, placeholder: placeholderNode)
    }
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode) {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.deactivate(placeholder: placeholderNode)
            self.searchDisplayController = nil
        }
    }
    
    var isSearching: Bool {
        return self.searchDisplayController != nil
    }
    
    override func scrollToTop() {
        self.searchDisplayController?.contentNode.scrollToTop()
    }
    
    override func queryUpdated(_ query: String) {
    }
    
    override func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let searchDisplayController = self.searchDisplayController, let result = searchDisplayController.contentNode.hitTest(self.view.convert(point, to: searchDisplayController.contentNode.view), with: event) {
            return result
        }
        
        return super.hitTest(point, with: event)
    }
}

