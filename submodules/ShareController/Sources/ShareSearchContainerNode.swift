import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
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
}

private enum ShareSearchRecentEntry: Comparable, Identifiable {
    case topPeers(PresentationTheme, PresentationStrings)
    case peer(index: Int, theme: PresentationTheme, peer: Peer, associatedPeer: Peer?, presence: EnginePeer.Presence?, PresentationStrings)
    
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
                if case let .peer(rhsIndex, rhsTheme, rhsPeer, rhsAssociatedPeer, rhsPresence, rhsStrings) = rhs, lhsPeer.isEqual(rhsPeer) && arePeersEqual(lhsAssociatedPeer, rhsAssociatedPeer) && lhsIndex == rhsIndex && lhsStrings === rhsStrings && lhsTheme === rhsTheme && lhsPresence == rhsPresence {
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
                let peer = EngineRenderedPeer(RenderedPeer(peerId: peer.id, peers: SimpleDictionary(peers), associatedMedia: [:]))
                return ShareControllerPeerGridItem(context: context, theme: theme, strings: strings, peer: peer, presence: presence, topicId: nil, threadData: nil, controllerInteraction: interfaceInteraction, sectionTitle: strings.DialogList_SearchSectionRecent, search: true)
        }
    }
}

private struct ShareSearchPeerEntry: Comparable, Identifiable {
    let index: Int32
    let peer: EngineRenderedPeer?
    let presence: EnginePeer.Presence?
    let theme: PresentationTheme
    let strings: PresentationStrings
    
    var stableId: Int64 {
        if let peer = self.peer {
            return peer.peerId.toInt64()
        } else {
            return Int64(index)
        }
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
        return ShareControllerPeerGridItem(context: context, theme: self.theme, strings: self.strings, peer: self.peer, presence: self.presence, topicId: nil, threadData: nil, controllerInteraction: interfaceInteraction, search: true)
    }
}

private struct ShareSearchGridTransaction {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let animated: Bool
    let crossFade: Bool
}

private func preparedGridEntryTransition(context: AccountContext, from fromEntries: [ShareSearchPeerEntry], to toEntries: [ShareSearchPeerEntry], interfaceInteraction: ShareControllerInteraction, crossFade: Bool) -> ShareSearchGridTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(context: context, interfaceInteraction: interfaceInteraction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, interfaceInteraction: interfaceInteraction)) }
    
    return ShareSearchGridTransaction(deletions: deletions, insertions: insertions, updates: updates, animated: false, crossFade: crossFade)
}

private func preparedRecentEntryTransition(context: AccountContext, from fromEntries: [ShareSearchRecentEntry], to toEntries: [ShareSearchRecentEntry], interfaceInteraction: ShareControllerInteraction) -> ShareSearchGridTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(context: context, interfaceInteraction: interfaceInteraction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, interfaceInteraction: interfaceInteraction)) }
    
    return ShareSearchGridTransaction(deletions: deletions, insertions: insertions, updates: updates, animated: false, crossFade: false)
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
    
    let contentGridNode: GridNode
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
        
        let foundItems = self.searchQuery.get()
        |> mapToSignal { query -> Signal<([ShareSearchPeerEntry]?, Bool), NoError> in
            if !query.isEmpty {
                let accountPeer = context.account.postbox.loadedPeerWithId(context.account.peerId) |> take(1)
                let foundLocalPeers = context.account.postbox.searchPeers(query: query.lowercased())
                let foundRemotePeers: Signal<([FoundPeer], [FoundPeer], Bool), NoError> = .single(([], [], true))
                |> then(
                    context.engine.contacts.searchRemotePeers(query: query)
                    |> delay(0.2, queue: Queue.concurrentDefaultQueue())
                    |> map { a, b -> ([FoundPeer], [FoundPeer], Bool) in
                        return (a, b, false)
                    }
                )
                
                return combineLatest(accountPeer, foundLocalPeers, foundRemotePeers)
                |> map { accountPeer, foundLocalPeers, foundRemotePeers -> ([ShareSearchPeerEntry]?, Bool) in
                    var entries: [ShareSearchPeerEntry] = []
                    var index: Int32 = 0
                    
                    var existingPeerIds = Set<PeerId>()
                    
                    let lowercasedQuery = query.lowercased()
                    if strings.DialogList_SavedMessages.lowercased().hasPrefix(lowercasedQuery) || "saved messages".hasPrefix(lowercasedQuery) {
                        if !existingPeerIds.contains(accountPeer.id) {
                            existingPeerIds.insert(accountPeer.id)
                            entries.append(ShareSearchPeerEntry(index: index, peer: EngineRenderedPeer(RenderedPeer(peer: accountPeer)), presence: nil, theme: theme, strings: strings))
                            index += 1
                        }
                    }
                    
                    for renderedPeer in foundLocalPeers {
                        if let peer = renderedPeer.peers[renderedPeer.peerId], peer.id != accountPeer.id {
                            if !existingPeerIds.contains(renderedPeer.peerId) && canSendMessagesToPeer(peer) {
                                existingPeerIds.insert(renderedPeer.peerId)
                                entries.append(ShareSearchPeerEntry(index: index, peer: EngineRenderedPeer(renderedPeer), presence: nil, theme: theme, strings: strings))
                                index += 1
                            }
                        }
                    }
                    
                    var isPlaceholder = false
                    if foundRemotePeers.2 {
                        isPlaceholder = true
                        for _ in 0 ..< 4 {
                            entries.append(ShareSearchPeerEntry(index: index, peer: nil, presence: nil, theme: theme, strings: strings))
                            index += 1
                        }
                    } else {
                        for foundPeer in foundRemotePeers.0 {
                            let peer = foundPeer.peer
                            if !existingPeerIds.contains(peer.id) && canSendMessagesToPeer(peer) {
                                existingPeerIds.insert(peer.id)
                                entries.append(ShareSearchPeerEntry(index: index, peer: EngineRenderedPeer(RenderedPeer(peer: foundPeer.peer)), presence: nil, theme: theme, strings: strings))
                                index += 1
                            }
                        }
                        
                        for foundPeer in foundRemotePeers.1 {
                            let peer = foundPeer.peer
                            if !existingPeerIds.contains(peer.id) && canSendMessagesToPeer(peer) {
                                existingPeerIds.insert(peer.id)
                                entries.append(ShareSearchPeerEntry(index: index, peer: EngineRenderedPeer(RenderedPeer(peer: peer)), presence: nil, theme: theme, strings: strings))
                                index += 1
                            }
                        }
                    }
                    
                    return (entries, isPlaceholder)
                }
            } else {
                return .single((nil, false))
            }
        }
        
        let previousSearchItemsAndIsPlaceholder = Atomic<([ShareSearchPeerEntry]?, Bool)>(value: (nil, false))
        self.searchDisposable.set((foundItems
        |> deliverOnMainQueue).start(next: { [weak self] entriesAndIsPlaceholder in
            if let strongSelf = self {
                let (entries, isPlaceholder) = entriesAndIsPlaceholder
                let previousEntries = previousSearchItemsAndIsPlaceholder.swap(entriesAndIsPlaceholder)
                strongSelf.entries = entries ?? []
                                
                let firstTime = previousEntries.0 == nil
                let crossFade = !firstTime && previousEntries.1 && !isPlaceholder
                
                let transition = preparedGridEntryTransition(context: context, from: previousEntries.0 ?? [], to: entries ?? [], interfaceInteraction: controllerInteraction, crossFade: crossFade)
                strongSelf.enqueueTransition(transition, firstTime: firstTime)
                
                if (previousEntries.0 == nil) != (entries == nil) {
                    if previousEntries.0 == nil {
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
        
        let hasRecentPeers = context.engine.peers.recentPeers()
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
    
    func updateLayout(size: CGSize, isLandscape: Bool, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
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
            if let index = self.entries.firstIndex(where: { $0.peer?.peerId == ensurePeerVisibleOnLayout }) {
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
    
    func updateSelectedPeers(animated: Bool) {
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
            
            if transition.crossFade {
                if let snapshotView = self.contentGridNode.view.snapshotView(afterScreenUpdates: false) {
                    self.contentGridNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.contentGridNode.view)
                    snapshotView.frame = self.contentGridNode.frame
                    
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                }
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
    
    func frameForPeerId(_ peerId: EnginePeer.Id) -> CGRect? {
        var node: ASDisplayNode?
        if !self.recentGridNode.isHidden {
            self.recentGridNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ShareControllerPeerGridItemNode, itemNode.peerId == peerId {
                    node = itemNode
                }
            }
        } else {
            self.contentGridNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ShareControllerPeerGridItemNode, itemNode.peerId == peerId {
                    node = itemNode
                }
            }
        }
        if let node = node {
            return node.frame.offsetBy(dx: 0.0, dy: -10.0)
        } else {
            return nil
        }
    }
    
    func animateIn(peerId: EnginePeer.Id, scrollDelta: CGFloat) -> CGRect? {
        self.searchNode.alpha = 1.0
        self.searchNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.searchNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -scrollDelta), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)

        self.cancelButtonNode.alpha = 1.0
        self.cancelButtonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.cancelButtonNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -scrollDelta), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        
        self.contentGridNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -scrollDelta), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        
        if let targetFrame = self.frameForPeerId(peerId), let (size, bottomInset) = self.validLayout {
            let clippedNode = ASDisplayNode()
            clippedNode.clipsToBounds = true
            clippedNode.cornerRadius = 16.0
            clippedNode.frame = CGRect(origin: CGPoint(x: 0.0, y: self.searchNode.frame.minY - 15.0), size: CGSize(width: size.width, height: size.height - bottomInset))
            self.contentGridNode.view.superview?.insertSubview(clippedNode.view, aboveSubview: self.contentGridNode.view)
            
            clippedNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -scrollDelta), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            
            let maskView = UIView()
            maskView.frame = clippedNode.bounds
            
            let maskImageView = UIImageView()
            maskImageView.image = generatePeersMaskImage()
            maskImageView.frame = maskView.bounds.offsetBy(dx: 0.0, dy: 36.0)
            maskView.addSubview(maskImageView)
            clippedNode.view.mask = maskView
            
            
            self.contentGridNode.alpha = 1.0
            self.contentGridNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ShareControllerPeerGridItemNode, itemNode.peerId == peerId {
                    itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, removeOnCompletion: false)
                    itemNode.layer.animateScale(from: 1.35, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak clippedNode] _ in
                        clippedNode?.view.removeFromSuperview()
                    })
                } else if let snapshotView = itemNode.view.snapshotView(afterScreenUpdates: false) {
                    snapshotView.frame = itemNode.view.convert(itemNode.bounds, to: clippedNode.view)
                    
                    clippedNode.view.addSubview(snapshotView)
                    
                    itemNode.alpha = 0.0
                    let angle = targetFrame.center.angle(to: itemNode.position)
                    let distance = targetFrame.center.distance(to: itemNode.position)
                    let newDistance = distance * 2.8
                    let newPosition = snapshotView.center.offsetBy(distance: newDistance, inDirection: angle)
                    snapshotView.layer.animatePosition(from: newPosition, to: snapshotView.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                    snapshotView.layer.animateScale(from: 1.35, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak itemNode] _ in
                        itemNode?.alpha = 1.0
                    })
                    snapshotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, removeOnCompletion: false)
                }
            }
                        
            return targetFrame
        } else {
            return nil
        }
    }
    
    func animateOut(peerId: EnginePeer.Id, scrollDelta: CGFloat) -> CGRect? {
        self.searchNode.alpha = 0.0
        self.searchNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        self.searchNode.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: -scrollDelta), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                
        self.cancelButtonNode.alpha = 0.0
        self.cancelButtonNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        self.cancelButtonNode.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: -scrollDelta), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        
        self.contentGridNode.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: -scrollDelta), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        
        if let sourceFrame = self.frameForPeerId(peerId), let (size, bottomInset) = self.validLayout {
            let clippedNode = ASDisplayNode()
            clippedNode.clipsToBounds = true
            clippedNode.cornerRadius = 16.0
            clippedNode.frame = CGRect(origin: CGPoint(x: 0.0, y: self.searchNode.frame.minY - 15.0), size: CGSize(width: size.width, height: size.height - bottomInset))
            self.contentGridNode.view.superview?.insertSubview(clippedNode.view, aboveSubview: self.contentGridNode.view)
            
            clippedNode.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: -scrollDelta), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            
            let maskView = UIView()
            maskView.frame = clippedNode.bounds
            
            let maskImageView = UIImageView()
            maskImageView.image = generatePeersMaskImage()
            maskImageView.frame = maskView.bounds.offsetBy(dx: 0.0, dy: 36.0)
            maskView.addSubview(maskImageView)
            clippedNode.view.mask = maskView
            
            self.contentGridNode.forEachItemNode { itemNode in
                if let snapshotView = itemNode.view.snapshotView(afterScreenUpdates: false) {
                    snapshotView.frame = itemNode.view.convert(itemNode.bounds, to: clippedNode.view)
                    clippedNode.view.addSubview(snapshotView)
                    
                    if let itemNode = itemNode as? ShareControllerPeerGridItemNode, itemNode.peerId == peerId {
                        
                    } else {
                        let angle = sourceFrame.center.angle(to: itemNode.position)
                        let distance = sourceFrame.center.distance(to: itemNode.position)
                        let newDistance = distance * 2.8
                        let newPosition = snapshotView.center.offsetBy(distance: newDistance, inDirection: angle)
                        snapshotView.layer.animatePosition(from: snapshotView.center, to: newPosition, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                    }
                    snapshotView.layer.animateScale(from: 1.0, to: 1.35, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                }
            }
            
            clippedNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak clippedNode] _ in
                clippedNode?.view.removeFromSuperview()
            })
            
            self.contentGridNode.alpha = 0.0
            
            return sourceFrame
        } else {
            return nil
        }
    }
}
