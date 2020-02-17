import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import Display
import TelegramPresentationData
import MergeLists
import AccountContext

private let cancelFont = Font.regular(17.0)
private let subtitleFont = Font.regular(12.0)

private enum ShareSearchRecentEntryStableId: Hashable {
    case topPeers
    case peerId(PeerId)
    
    static func ==(lhs: ShareSearchRecentEntryStableId, rhs: ShareSearchRecentEntryStableId) -> Bool {
        switch lhs {
            case .topPeers:
                if case .topPeers = rhs {
                    return true
                } else {
                    return false
                }
            case let .peerId(peerId):
                if case .peerId(peerId) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case .topPeers:
                return 0
            case let .peerId(peerId):
                return peerId.hashValue
        }
    }
}

private enum ShareSearchRecentEntry: Comparable, Identifiable {
    case topPeers(PresentationTheme, PresentationStrings)
    case peer(index: Int, theme: PresentationTheme, peer: Peer, associatedPeer: Peer?, presence: PeerPresence?, PresentationStrings)
    
    var stableId: ShareSearchRecentEntryStableId {
        switch self {
            case .topPeers:
                return .topPeers
            case let .peer(_, _, peer, _, _, _):
                return .peerId(peer.id)
        }
    }
    
    static func ==(lhs: ShareSearchRecentEntry, rhs: ShareSearchRecentEntry) -> Bool {
        switch lhs {
            case let .topPeers(lhsTheme, lhsStrings):
                if case let .topPeers(rhsTheme, rhsStrings) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .peer(lhsIndex, lhsTheme, lhsPeer, lhsAssociatedPeer, lhsPresence, lhsStrings):
                if case let .peer(rhsIndex, rhsTheme, rhsPeer, rhsAssociatedPeer, rhsPresence, rhsStrings) = rhs, lhsPeer.isEqual(rhsPeer) && arePeersEqual(lhsAssociatedPeer, rhsAssociatedPeer) && lhsIndex == rhsIndex && lhsStrings === rhsStrings && lhsTheme === rhsTheme && arePeerPresencesEqual(lhsPresence, rhsPresence) {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ShareSearchRecentEntry, rhs: ShareSearchRecentEntry) -> Bool {
        switch lhs {
            case .topPeers:
                return true
            case let .peer(lhsIndex, _, _, _, _, _):
                switch rhs {
                    case .topPeers:
                        return false
                    case let .peer(rhsIndex, _, _, _, _, _):
                        return lhsIndex <= rhsIndex
                }
        }
    }
    
    func item(context: AccountContext, interfaceInteraction: ShareControllerInteraction) -> GridItem {
        switch self {
            case let .topPeers(theme, strings):
                return ShareControllerRecentPeersGridItem(context: context, theme: theme, strings: strings, controllerInteraction: interfaceInteraction)
            case let .peer(_, theme, peer, associatedPeer, presence, strings):
                var peers: [PeerId: Peer] = [peer.id: peer]
                if let associatedPeer = associatedPeer {
                    peers[associatedPeer.id] = associatedPeer
                }
                let peer = RenderedPeer(peerId: peer.id, peers: SimpleDictionary(peers))
                return ShareControllerPeerGridItem(context: context, theme: theme, strings: strings, peer: peer, presence: presence, controllerInteraction: interfaceInteraction, sectionTitle: strings.DialogList_SearchSectionRecent, search: true)
        }
    }
}

private struct ShareSearchPeerEntry: Comparable, Identifiable {
    let index: Int32
    let peer: RenderedPeer
    let presence: PeerPresence?
    let theme: PresentationTheme
    let strings: PresentationStrings
    
    var stableId: Int64 {
        return self.peer.peerId.toInt64()
    }
    
    static func ==(lhs: ShareSearchPeerEntry, rhs: ShareSearchPeerEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        return true
    }
    
    static func <(lhs: ShareSearchPeerEntry, rhs: ShareSearchPeerEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, interfaceInteraction: ShareControllerInteraction) -> GridItem {
        return ShareControllerPeerGridItem(context: context, theme: self.theme, strings: self.strings, peer: peer, presence: self.presence, controllerInteraction: interfaceInteraction, search: true)
    }
}

private struct ShareSearchGridTransaction {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let animated: Bool
}

private func preparedGridEntryTransition(context: AccountContext, from fromEntries: [ShareSearchPeerEntry], to toEntries: [ShareSearchPeerEntry], interfaceInteraction: ShareControllerInteraction) -> ShareSearchGridTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(context: context, interfaceInteraction: interfaceInteraction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, interfaceInteraction: interfaceInteraction)) }
    
    return ShareSearchGridTransaction(deletions: deletions, insertions: insertions, updates: updates, animated: false)
}

private func preparedRecentEntryTransition(context: AccountContext, from fromEntries: [ShareSearchRecentEntry], to toEntries: [ShareSearchRecentEntry], interfaceInteraction: ShareControllerInteraction) -> ShareSearchGridTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(context: context, interfaceInteraction: interfaceInteraction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, interfaceInteraction: interfaceInteraction)) }
    
    return ShareSearchGridTransaction(deletions: deletions, insertions: insertions, updates: updates, animated: false)
}

final class ShareSearchContainerNode: ASDisplayNode, ShareContentContainerNode {
    private let sharedContext: SharedAccountContext
    private let context: AccountContext
    private let strings: PresentationStrings
    private let controllerInteraction: ShareControllerInteraction
    
    private var entries: [ShareSearchPeerEntry] = []
    private var recentEntries: [ShareSearchRecentEntry] = []
    
    private var enqueuedTransitions: [(ShareSearchGridTransaction, Bool)] = []
    private var enqueuedRecentTransitions: [(ShareSearchGridTransaction, Bool)] = []
    
    private let contentGridNode: GridNode
    private let recentGridNode: GridNode
    
    private let contentSeparatorNode: ASDisplayNode
    private let searchNode: ShareSearchBarNode
    private let cancelButtonNode: HighlightableButtonNode
    
    private var contentOffsetUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    var cancel: (() -> Void)?
    
    private var ensurePeerVisibleOnLayout: PeerId?
    private var validLayout: (CGSize, CGFloat)?
    private var overrideGridOffsetTransition: ContainedViewLayoutTransition?
    
    private let recentDisposable = MetaDisposable()
    
    private let searchQuery = ValuePromise<String>("", ignoreRepeated: true)
    private let searchDisposable = MetaDisposable()
    
    init(sharedContext: SharedAccountContext, context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, controllerInteraction: ShareControllerInteraction, recentPeers recentPeerList: [RenderedPeer]) {
        self.sharedContext = sharedContext
        self.context = context
        self.strings = strings
        self.controllerInteraction = controllerInteraction
        
        self.recentGridNode = GridNode()
        self.contentGridNode = GridNode()
        self.contentGridNode.isHidden = true
        
        self.searchNode = ShareSearchBarNode(theme: theme, placeholder: strings.Common_Search)
        
        self.cancelButtonNode = HighlightableButtonNode()
        self.cancelButtonNode.setTitle(strings.Common_Cancel, with: cancelFont, with: theme.actionSheet.controlAccentColor, for: [])
        self.cancelButtonNode.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        
        self.contentSeparatorNode = ASDisplayNode()
        self.contentSeparatorNode.isLayerBacked = true
        self.contentSeparatorNode.displaysAsynchronously = false
        self.contentSeparatorNode.backgroundColor = theme.actionSheet.opaqueItemSeparatorColor
        
        super.init()
        
        self.addSubnode(self.recentGridNode)
        self.addSubnode(self.contentGridNode)
        
        self.addSubnode(self.searchNode)
        self.addSubnode(self.cancelButtonNode)
        self.addSubnode(self.contentSeparatorNode)
        
        self.recentGridNode.presentationLayoutUpdated = { [weak self] presentationLayout, transition in
            if let strongSelf = self, !strongSelf.recentGridNode.isHidden {
                strongSelf.gridPresentationLayoutUpdated(presentationLayout, transition: transition)
            }
        }
        
        self.contentGridNode.presentationLayoutUpdated = { [weak self] presentationLayout, transition in
            if let strongSelf = self, !strongSelf.contentGridNode.isHidden {
                strongSelf.gridPresentationLayoutUpdated(presentationLayout, transition: transition)
            }
        }
        
        self.cancelButtonNode.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        
        let foundItems = searchQuery.get()
        |> mapToSignal { query -> Signal<[ShareSearchPeerEntry]?, NoError> in
            if !query.isEmpty {
                let accountPeer = context.account.postbox.loadedPeerWithId(context.account.peerId) |> take(1)
                let foundLocalPeers = context.account.postbox.searchPeers(query: query.lowercased())
                let foundRemotePeers: Signal<([FoundPeer], [FoundPeer]), NoError> = .single(([], []))
                |> then(
                    searchPeers(account: context.account, query: query)
                    |> delay(0.2, queue: Queue.concurrentDefaultQueue())
                )
                
                return combineLatest(accountPeer, foundLocalPeers, foundRemotePeers)
                |> map { accountPeer, foundLocalPeers, foundRemotePeers -> [ShareSearchPeerEntry]? in
                    var entries: [ShareSearchPeerEntry] = []
                    var index: Int32 = 0
                    
                    var existingPeerIds = Set<PeerId>()
                    
                    let lowercasedQuery = query.lowercased()
                    if strings.DialogList_SavedMessages.lowercased().hasPrefix(lowercasedQuery) || "saved messages".hasPrefix(lowercasedQuery) {
                        if !existingPeerIds.contains(accountPeer.id) {
                            existingPeerIds.insert(accountPeer.id)
                            entries.append(ShareSearchPeerEntry(index: index, peer: RenderedPeer(peer: accountPeer), presence: nil, theme: theme, strings: strings))
                            index += 1
                        }
                    }
                    
                    for renderedPeer in foundLocalPeers {
                        if let peer = renderedPeer.peers[renderedPeer.peerId], peer.id != accountPeer.id {
                            if !existingPeerIds.contains(renderedPeer.peerId) && canSendMessagesToPeer(peer) {
                                existingPeerIds.insert(renderedPeer.peerId)
                                entries.append(ShareSearchPeerEntry(index: index, peer: renderedPeer, presence: nil, theme: theme, strings: strings))
                                index += 1
                            }
                        }
                    }
                    
                    for foundPeer in foundRemotePeers.0 {
                        let peer = foundPeer.peer
                        if !existingPeerIds.contains(peer.id) && canSendMessagesToPeer(peer) {
                            existingPeerIds.insert(peer.id)
                            entries.append(ShareSearchPeerEntry(index: index, peer: RenderedPeer(peer: foundPeer.peer), presence: nil, theme: theme, strings: strings))
                            index += 1
                        }
                    }
                    
                    for foundPeer in foundRemotePeers.1 {
                        let peer = foundPeer.peer
                        if !existingPeerIds.contains(peer.id) && canSendMessagesToPeer(peer) {
                            existingPeerIds.insert(peer.id)
                            entries.append(ShareSearchPeerEntry(index: index, peer: RenderedPeer(peer: peer), presence: nil, theme: theme, strings: strings))
                            index += 1
                        }
                    }
                    
                    return entries
                }
            } else {
                return .single(nil)
            }
        }
        
        let previousSearchItems = Atomic<[ShareSearchPeerEntry]?>(value: nil)
        self.searchDisposable.set((foundItems
        |> deliverOnMainQueue).start(next: { [weak self] entries in
            if let strongSelf = self {
                let previousEntries = previousSearchItems.swap(entries)
                strongSelf.entries = entries ?? []
                
                let firstTime = previousEntries == nil
                let transition = preparedGridEntryTransition(context: context, from: previousEntries ?? [], to: entries ?? [], interfaceInteraction: controllerInteraction)
                strongSelf.enqueueTransition(transition, firstTime: firstTime)
                
                if (previousEntries == nil) != (entries == nil) {
                    if previousEntries == nil {
                        strongSelf.recentGridNode.isHidden = true
                        strongSelf.contentGridNode.isHidden = false
                        strongSelf.transitionToContentGridLayout()
                    } else {
                        strongSelf.recentGridNode.isHidden = false
                        strongSelf.contentGridNode.isHidden = true
                        strongSelf.transitionToRecentGridLayout()
                    }
                }
            }
        }))
        
        self.searchNode.textUpdated = { [weak self] text in
            self?.searchQuery.set(text)
        }
        
        let hasRecentPeers = recentPeers(account: context.account)
        |> map { value -> Bool in
            switch value {
            case let .peers(peers):
                return !peers.isEmpty
            case .disabled:
                return false
            }
        }
        |> distinctUntilChanged
        
        let recentItems: Signal<[ShareSearchRecentEntry], NoError> = hasRecentPeers
        |> map { hasRecentPeers -> [ShareSearchRecentEntry] in
            var recentItemList: [ShareSearchRecentEntry] = []
            if hasRecentPeers {
                recentItemList.append(.topPeers(theme, strings))
            }
            var index = 0
            for peer in recentPeerList {
                if let mainPeer = peer.peers[peer.peerId], canSendMessagesToPeer(mainPeer) {
                    recentItemList.append(.peer(index: index, theme: theme, peer: mainPeer, associatedPeer: mainPeer.associatedPeerId.flatMap { peer.peers[$0] }, presence: nil, strings))
                    index += 1
                }
            }
            return recentItemList
        }
        let previousRecentItems = Atomic<[ShareSearchRecentEntry]?>(value: nil)
        self.recentDisposable.set((recentItems
        |> deliverOnMainQueue).start(next: { [weak self] entries in
            if let strongSelf = self {
                let previousEntries = previousRecentItems.swap(entries)
                strongSelf.recentEntries = entries
                
                let firstTime = previousEntries == nil
                let transition = preparedRecentEntryTransition(context: context, from: previousEntries ?? [], to: entries, interfaceInteraction: controllerInteraction)
                strongSelf.enqueueRecentTransition(transition, firstTime: firstTime)
            }
        }))
    }
    
    deinit {
        self.searchDisposable.dispose()
        self.recentDisposable.dispose()
    }
    
    func setEnsurePeerVisibleOnLayout(_ peerId: PeerId?) {
        self.ensurePeerVisibleOnLayout = peerId
    }
    
    func setContentOffsetUpdated(_ f: ((CGFloat, ContainedViewLayoutTransition) -> Void)?) {
        self.contentOffsetUpdated = f
    }
    
    func activate() {
        self.searchNode.activateInput()
    }
    
    func deactivate() {
        self.searchNode.deactivateInput()
    }
    
    private func calculateMetrics(size: CGSize) -> (topInset: CGFloat, itemWidth: CGFloat) {
        let itemCount: Int
        if self.contentGridNode.isHidden {
            itemCount = self.recentEntries.count
        } else {
            itemCount = self.entries.count
        }
        
        let itemInsets = UIEdgeInsets(top: 0.0, left: 12.0, bottom: 0.0, right: 12.0)
        let minimalItemWidth: CGFloat = 70.0
        let effectiveWidth = size.width - itemInsets.left - itemInsets.right
        
        let itemsPerRow = Int(effectiveWidth / minimalItemWidth)
        
        let itemWidth = floor(effectiveWidth / CGFloat(itemsPerRow))
        var rowCount = itemCount / itemsPerRow + (itemCount % itemsPerRow != 0 ? 1 : 0)
        rowCount = max(rowCount, 4)
        
        let minimallyRevealedRowCount: CGFloat = 3.7
        let initiallyRevealedRowCount = min(minimallyRevealedRowCount, CGFloat(rowCount))
        
        let gridTopInset = max(0.0, size.height - floor(initiallyRevealedRowCount * itemWidth) - 14.0)
        return (gridTopInset, itemWidth)
    }
    
    func updateLayout(size: CGSize, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let firstLayout = self.validLayout == nil
        self.validLayout = (size, bottomInset)
        
        let gridLayoutTransition: ContainedViewLayoutTransition
        if firstLayout {
            gridLayoutTransition = .immediate
            self.overrideGridOffsetTransition = transition
        } else {
            gridLayoutTransition = transition
            self.overrideGridOffsetTransition = nil
        }
        
        let (gridTopInset, itemWidth) = self.calculateMetrics(size: size)
        
        var scrollToItem: GridNodeScrollToItem?
        if !self.contentGridNode.isHidden, let ensurePeerVisibleOnLayout = self.ensurePeerVisibleOnLayout {
            self.ensurePeerVisibleOnLayout = nil
            if let index = self.entries.firstIndex(where: { $0.peer.peerId == ensurePeerVisibleOnLayout }) {
                scrollToItem = GridNodeScrollToItem(index: index, position: .visible, transition: transition, directionHint: .up, adjustForSection: false)
            }
        }
        
        var scrollToRecentItem: GridNodeScrollToItem?
        if !self.recentGridNode.isHidden, let ensurePeerVisibleOnLayout = self.ensurePeerVisibleOnLayout {
            self.ensurePeerVisibleOnLayout = nil
            if let index = self.recentEntries.firstIndex(where: {
                switch $0 {
                    case .topPeers:
                        return false
                    case let .peer(_, _, peer, _, _, _):
                        return peer.id == ensurePeerVisibleOnLayout
                }
            }) {
                scrollToRecentItem = GridNodeScrollToItem(index: index, position: .visible, transition: transition, directionHint: .up, adjustForSection: false)
            }
        }
        
        let gridSize = CGSize(width: size.width, height: size.height - 5.0)
        
        self.recentGridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: scrollToRecentItem, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: gridSize, insets: UIEdgeInsets(top: gridTopInset, left: 6.0, bottom: bottomInset, right: 6.0), preloadSize: 80.0, type: .fixed(itemSize: CGSize(width: itemWidth, height: itemWidth + 25.0), fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)), transition: gridLayoutTransition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        gridLayoutTransition.updateFrame(node: self.recentGridNode, frame: CGRect(origin: CGPoint(x: floor((size.width - gridSize.width) / 2.0), y: 5.0), size: gridSize))
        
        self.contentGridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: scrollToItem, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: gridSize, insets: UIEdgeInsets(top: gridTopInset, left: 6.0, bottom: bottomInset, right: 6.0), preloadSize: 80.0, type: .fixed(itemSize: CGSize(width: itemWidth, height: itemWidth + 25.0), fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)), transition: gridLayoutTransition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        gridLayoutTransition.updateFrame(node: self.contentGridNode, frame: CGRect(origin: CGPoint(x: floor((size.width - gridSize.width) / 2.0), y: 5.0), size: gridSize))
        
        if firstLayout {
            self.animateIn()
            
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
            
            while !self.enqueuedRecentTransitions.isEmpty {
                self.dequeueRecentTransition()
            }
        }
    }
    
    private func transitionToRecentGridLayout(_ transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .spring)) {
        if let (size, bottomInset) = self.validLayout {
            let (gridTopInset, itemWidth) = self.calculateMetrics(size: size)
            
            let offset = self.recentGridNode.scrollView.contentOffset.y - self.contentGridNode.scrollView.contentOffset.y
            
            let gridSize = CGSize(width: size.width, height: size.height - 5.0)
            self.recentGridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: gridSize, insets: UIEdgeInsets(top: gridTopInset, left: 6.0, bottom: bottomInset, right: 6.0), preloadSize: 80.0, type: .fixed(itemSize: CGSize(width: itemWidth, height: itemWidth + 25.0), fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
            
            transition.animatePositionAdditive(node: self.recentGridNode, offset: CGPoint(x: 0.0, y: offset))
        }
    }
    
    private func transitionToContentGridLayout(_ transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .spring)) {
        if let (size, bottomInset) = self.validLayout {
            let (gridTopInset, itemWidth) = self.calculateMetrics(size: size)
            
            let offset = self.recentGridNode.scrollView.contentOffset.y - self.contentGridNode.scrollView.contentOffset.y
            
            let gridSize = CGSize(width: size.width, height: size.height - 5.0)
            self.contentGridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: gridSize, insets: UIEdgeInsets(top: gridTopInset, left: 6.0, bottom: bottomInset, right: 6.0), preloadSize: 80.0, type: .fixed(itemSize: CGSize(width: itemWidth, height: itemWidth + 25.0), fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
            
            transition.animatePositionAdditive(node: self.contentGridNode, offset: CGPoint(x: 0.0, y: -offset))
        }
    }
    
    private func gridPresentationLayoutUpdated(_ presentationLayout: GridNodeCurrentPresentationLayout, transition: ContainedViewLayoutTransition) {
        let actualTransition = self.overrideGridOffsetTransition ?? transition
        self.overrideGridOffsetTransition = nil
        
        let titleAreaHeight: CGFloat = 64.0
        
        let size = self.bounds.size
        let rawTitleOffset = -titleAreaHeight - presentationLayout.contentOffset.y
        let titleOffset = max(-titleAreaHeight, rawTitleOffset)
        
        let cancelButtonSize = self.cancelButtonNode.measure(CGSize(width: 320.0, height: 100.0))
        let cancelButtonFrame = CGRect(origin: CGPoint(x: size.width - cancelButtonSize.width - 12.0, y: titleOffset + 25.0), size: cancelButtonSize)
        transition.updateFrame(node: self.cancelButtonNode, frame: cancelButtonFrame)
        
        let searchNodeFrame = CGRect(origin: CGPoint(x: 16.0, y: titleOffset + 16.0), size: CGSize(width: cancelButtonFrame.minX - 16.0 - 10.0, height: 40.0))
        transition.updateFrame(node: self.searchNode, frame: searchNodeFrame)
        self.searchNode.updateLayout(width: searchNodeFrame.size.width, transition: transition)
        
        transition.updateFrame(node: self.contentSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: titleOffset + titleAreaHeight + 5.0), size: CGSize(width: size.width, height: UIScreenPixel)))
        
        if rawTitleOffset.isLess(than: -titleAreaHeight) {
            self.contentSeparatorNode.alpha = 1.0
        } else {
            self.contentSeparatorNode.alpha = 0.0
        }
        
        self.contentOffsetUpdated?(presentationLayout.contentOffset.y, actualTransition)
    }
    
    func animateIn() {
    }
    
    func updateSelectedPeers() {
        self.contentGridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ShareControllerPeerGridItemNode {
                itemNode.updateSelection(animated: true)
            }
        }
        self.recentGridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ShareControllerPeerGridItemNode {
                itemNode.updateSelection(animated: true)
            } else if let itemNode = itemNode as? ShareControllerRecentPeersGridItemNode {
                itemNode.updateSelection(animated: true)
            }
        }
    }
    
    @objc func cancelPressed() {
        self.cancel?()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let nodes: [ASDisplayNode] = [self.searchNode, self.cancelButtonNode]
        for node in nodes {
            let nodeFrame = node.frame
            if let result = node.hitTest(point.offsetBy(dx: -nodeFrame.minX, dy: -nodeFrame.minY), with: event) {
                return result
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    private func enqueueTransition(_ transition: ShareSearchGridTransaction, firstTime: Bool) {
        self.enqueuedTransitions.append((transition, firstTime))
        
        if self.validLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, _) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var itemTransition: ContainedViewLayoutTransition = .immediate
            if transition.animated {
                itemTransition = .animated(duration: 0.3, curve: .spring)
            }
            self.contentGridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: nil, updateLayout: nil, itemTransition: itemTransition, stationaryItems: .none, updateFirstIndexInSectionOffset: nil, synchronousLoads: true), completion: { _ in })
        }
    }
    
    private func enqueueRecentTransition(_ transition: ShareSearchGridTransaction, firstTime: Bool) {
        self.enqueuedRecentTransitions.append((transition, firstTime))
        
        if self.validLayout != nil {
            while !self.enqueuedRecentTransitions.isEmpty {
                self.dequeueRecentTransition()
            }
        }
    }
    
    private func dequeueRecentTransition() {
        if let (transition, _) = self.enqueuedRecentTransitions.first {
            self.enqueuedRecentTransitions.remove(at: 0)
            
            var itemTransition: ContainedViewLayoutTransition = .immediate
            if transition.animated {
                itemTransition = .animated(duration: 0.3, curve: .spring)
            }
            self.recentGridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: nil, updateLayout: nil, itemTransition: itemTransition, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        }
    }
}
