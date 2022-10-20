import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import SearchUI
import ContactsPeerItem
import ItemListUI

private enum ChannelDiscussionGroupSearchContent: Equatable {
    case peer(Peer)
    
    static func ==(lhs: ChannelDiscussionGroupSearchContent, rhs: ChannelDiscussionGroupSearchContent) -> Bool {
        switch lhs {
            case let .peer(lhsPeer):
                if case let .peer(rhsPeer) = rhs {
                    return lhsPeer.isEqual(rhsPeer)
                } else {
                    return false
                }
        }
    }
    
    var peerId: PeerId {
        switch self {
            case let .peer(peer):
                return peer.id
        }
    }
}

private final class ChannelDiscussionGroupSearchInteraction {
    let peerSelected: (Peer) -> Void
    
    init(peerSelected: @escaping (Peer) -> Void) {
        self.peerSelected = peerSelected
    }
}

private struct ChannelDiscussionGroupSearchEntryId: Hashable {
    let peerId: PeerId
}

private final class ChannelDiscussionGroupSearchEntry: Comparable, Identifiable {
    let index: Int
    let content: ChannelDiscussionGroupSearchContent
    
    init(index: Int, content: ChannelDiscussionGroupSearchContent) {
        self.index = index
        self.content = content
    }
    
    var stableId: ChannelDiscussionGroupSearchEntryId {
        return ChannelDiscussionGroupSearchEntryId(peerId: self.content.peerId)
    }
    
    static func ==(lhs: ChannelDiscussionGroupSearchEntry, rhs: ChannelDiscussionGroupSearchEntry) -> Bool {
        return lhs.index == rhs.index && lhs.content == rhs.content
    }
    
    static func <(lhs: ChannelDiscussionGroupSearchEntry, rhs: ChannelDiscussionGroupSearchEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, presentationData: PresentationData, interaction: ChannelDiscussionGroupSearchInteraction) -> ListViewItem {
        switch self.content {
            case let .peer(peer):
                return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: .firstLast, displayOrder: .firstLast, context: context, peerMode: .peer, peer: .peer(peer: EnginePeer(peer), chatPeer: EnginePeer(peer)), status: .none, enabled: true, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: nil, action: { _ in
                    interaction.peerSelected(peer)
                })
        }
    }
}

struct ChannelDiscussionGroupSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
}

private func channelDiscussionGroupSearchContainerPreparedRecentTransition(from fromEntries: [ChannelDiscussionGroupSearchEntry], to toEntries: [ChannelDiscussionGroupSearchEntry], isSearching: Bool, context: AccountContext, presentationData: PresentationData, interaction: ChannelDiscussionGroupSearchInteraction) -> ChannelDiscussionGroupSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    
    return ChannelDiscussionGroupSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, isSearching: isSearching)
}

private struct ChannelDiscussionGroupSearchContainerState: Equatable {
}

final class ChannelDiscussionGroupSearchContainerNode: SearchDisplayControllerContentNode {
    private let context: AccountContext
    private let openPeer: (Peer) -> Void
    
    private let dimNode: ASDisplayNode
    private let listNode: ListView
    
    private var enqueuedTransitions: [(ChannelDiscussionGroupSearchContainerTransition, Bool)] = []
    private var hasValidLayout = false
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let presentationDataPromise: Promise<PresentationData>
    
    public override var hasDim: Bool {
        return true
    }
    
    init(context: AccountContext, peers: [Peer], openPeer: @escaping (Peer) -> Void) {
        self.context = context
        self.openPeer = openPeer
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(self.presentationData)
        
        self.dimNode = ASDisplayNode()
        self.listNode = ListView()
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init()
        
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        self.listNode.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.listNode.isHidden = true
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.listNode)
        
        /*let statePromise = ValuePromise(ChannelDiscussionGroupSearchContainerState(), ignoreRepeated: true)
        let stateValue = Atomic(value: ChannelDiscussionGroupSearchContainerState())
        let updateState: ((ChannelDiscussionGroupSearchContainerState) -> ChannelDiscussionGroupSearchContainerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }*/
        
        let interaction = ChannelDiscussionGroupSearchInteraction(peerSelected: { peer in
            openPeer(peer)
        })
        
        var searchIndex: [ValueBoxKey: [Peer]] = [:]
        for peer in peers {
            for token in peer.indexName.indexTokens {
                if searchIndex[token] == nil {
                    searchIndex[token] = []
                }
                searchIndex[token]!.append(peer)
            }
        }
        
        let foundItems = searchQuery.get()
        |> mapToSignal { query -> Signal<[ChannelDiscussionGroupSearchEntry]?, NoError> in
            guard let query = query, !query.isEmpty else {
                return .single(nil)
            }
            
            var entries: [ChannelDiscussionGroupSearchEntry] = []
            let searchQueryTokens = stringIndexTokens(query.lowercased(), transliteration: .none)
            var filteredPeers: [Peer] = []
            var existingPeers = Set<PeerId>()
            for (key, values) in searchIndex {
                inner: for token in searchQueryTokens {
                    if token.isPrefix(to: key) {
                        for peer in values {
                            if !existingPeers.contains(peer.id) {
                                existingPeers.insert(peer.id)
                                filteredPeers.append(peer)
                            }
                        }
                        break inner
                    }
                }
            }
            for peer in filteredPeers {
                entries.append(ChannelDiscussionGroupSearchEntry(index: entries.count, content: .peer(peer)))
            }
            return .single(entries)
        }
        
        let previousSearchItems = Atomic<[ChannelDiscussionGroupSearchEntry]?>(value: nil)
        
        self.searchDisposable.set((combineLatest(foundItems, self.presentationDataPromise.get())
        |> deliverOnMainQueue).start(next: { [weak self] entries, presentationData in
            if let strongSelf = self {
                let previousEntries = previousSearchItems.swap(entries)
                let firstTime = previousEntries == nil
                let transition = channelDiscussionGroupSearchContainerPreparedRecentTransition(from: previousEntries ?? [], to: entries ?? [], isSearching: entries != nil, context: context, presentationData: presentationData, interaction: interaction)
                strongSelf.enqueueTransition(transition, firstTime: firstTime)
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
                }
            }
        })
        
        self.listNode.beganInteractiveDragging = { [weak self] _ in
            self?.dismissInput?()
        }
    }
    
    deinit {
        self.searchDisposable.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
    }
    
    private func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.listNode.backgroundColor = theme.chatList.backgroundColor
    }
    
    override func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
    }
    
    private func enqueueTransition(_ transition: ChannelDiscussionGroupSearchContainerTransition, firstTime: Bool) {
        self.enqueuedTransitions.append((transition, firstTime))
        
        if self.hasValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, _) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            options.insert(.PreferSynchronousResourceLoading)
            
            let isSearching = transition.isSearching
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                self?.listNode.isHidden = !isSearching
                self?.dimNode.isHidden = isSearching
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
        
        self.dimNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hasValidLayout {
            hasValidLayout = true
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    override func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
}
