import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import ContextUI
import PhotoResources
import TelegramUIPreferences
import ItemListPeerItem
import MergeLists
import ItemListUI

private struct GroupsInCommonListTransaction {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private struct GroupsInCommonListEntry: Comparable, Identifiable {
    var index: Int
    var peer: Peer
    
    var stableId: PeerId {
        return self.peer.id
    }
    
    static func ==(lhs: GroupsInCommonListEntry, rhs: GroupsInCommonListEntry) -> Bool {
        return lhs.peer.isEqual(rhs.peer)
    }
    
    static func <(lhs: GroupsInCommonListEntry, rhs: GroupsInCommonListEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, presentationData: PresentationData, openPeer: @escaping (Peer) -> Void) -> ListViewItem {
        let peer = self.peer
        return ItemListPeerItem(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, context: context, peer: self.peer, presence: nil, text: .none, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: true, sectionId: 0, action: {
            openPeer(peer)
        }, setPeerIdWithRevealedOptions: { _, _ in
        }, removePeer: { _ in
        }, contextAction: { node, gesture in
            //arguments.contextAction(peer, node, gesture)
        }, hasTopStripe: false, noInsets: true)
    }
}

private func preparedTransition(from fromEntries: [GroupsInCommonListEntry], to toEntries: [GroupsInCommonListEntry], context: AccountContext, presentationData: PresentationData, openPeer: @escaping (Peer) -> Void) -> GroupsInCommonListTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, openPeer: openPeer), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, openPeer: openPeer), directionHint: nil) }
    
    return GroupsInCommonListTransaction(deletions: deletions, insertions: insertions, updates: updates)
}

final class PeerInfoGroupsInCommonPaneNode: ASDisplayNode, PeerInfoPaneNode {
    private let context: AccountContext
    private let peerId: PeerId
    private let paneInteraction: PeerInfoPaneInteraction
    
    private let listNode: ListView
    private var peers: [Peer] = []
    private var currentEntries: [GroupsInCommonListEntry] = []
    private var enqueuedTransactions: [GroupsInCommonListTransaction] = []
    
    private var currentParams: (size: CGSize, isScrollingLockedAtTop: Bool, presentationData: PresentationData)?
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }
    
    init(context: AccountContext, peerId: PeerId, interaction: PeerInfoPaneInteraction, peers: [Peer]) {
        self.context = context
        self.peerId = peerId
        self.paneInteraction = interaction
        
        self.listNode = ListView()
        
        super.init()
        
        self.listNode.preloadPages = true
        self.addSubnode(self.listNode)
        
        self.peers = peers
    }
    
    deinit {
    }
    
    func scrollToTop() -> Bool {
        if !self.listNode.scrollToOffsetFromTop(0.0) {
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Spring(duration: 0.4), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            return true
        } else {
            return false
        }
    }
    
    func update(size: CGSize, isScrollingLockedAtTop: Bool, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.currentParams == nil
        self.currentParams = (size, isScrollingLockedAtTop, presentationData)
        
        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: size))
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)

        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0), headerInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0), scrollIndicatorInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.listNode.scrollEnabled = !isScrollingLockedAtTop
        
        if isFirstLayout {
            self.updatePeers(peers: self.peers, presentationData: presentationData)
        }
    }
    
    private func updatePeers(peers: [Peer], presentationData: PresentationData) {
        var entries: [GroupsInCommonListEntry] = []
        for peer in peers {
            entries.append(GroupsInCommonListEntry(index: entries.count, peer: peer))
        }
        let transaction = preparedTransition(from: self.currentEntries, to: entries, context: self.context, presentationData: presentationData, openPeer: { [weak self] peer in
            self?.paneInteraction.openPeer(peer)
        })
        self.currentEntries = entries
        self.enqueuedTransactions.append(transaction)
        self.dequeueTransaction()
    }
    
    private func dequeueTransaction() {
        guard let (layout, _, _) = self.currentParams, let transaction = self.enqueuedTransactions.first else {
            return
        }
        
        self.enqueuedTransactions.remove(at: 0)
        
        var options = ListViewDeleteAndInsertOptions()
        options.insert(.Synchronous)
        
        self.listNode.transaction(deleteIndices: transaction.deletions, insertIndicesAndItems: transaction.insertions, updateIndicesAndItems: transaction.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.didSetReady {
                strongSelf.didSetReady = true
                strongSelf.ready.set(.single(true))
            }
        })
    }
    
    func findLoadedMessage(id: MessageId) -> Message? {
        return nil
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    func updateSelectedMessages(animated: Bool) {
    }
}
