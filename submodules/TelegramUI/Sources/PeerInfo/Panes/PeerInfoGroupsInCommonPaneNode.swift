import AsyncDisplayKit
import Display
import TelegramCore
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
    
    func item(context: AccountContext, presentationData: PresentationData, openPeer: @escaping (Peer) -> Void, openPeerContextAction: @escaping (Peer, ASDisplayNode, ContextGesture?) -> Void) -> ListViewItem {
        let peer = self.peer
        return ItemListPeerItem(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, context: context, peer: EnginePeer(self.peer), presence: nil, text: .none, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: true, sectionId: 0, action: {
            openPeer(peer)
        }, setPeerIdWithRevealedOptions: { _, _ in
        }, removePeer: { _ in
        }, contextAction: { node, gesture in
            openPeerContextAction(peer, node, gesture)
        }, hasTopStripe: false, noInsets: true, noCorners: true)
    }
}

private func preparedTransition(from fromEntries: [GroupsInCommonListEntry], to toEntries: [GroupsInCommonListEntry], context: AccountContext, presentationData: PresentationData, openPeer: @escaping (Peer) -> Void, openPeerContextAction: @escaping (Peer, ASDisplayNode, ContextGesture?) -> Void) -> GroupsInCommonListTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, openPeer: openPeer, openPeerContextAction: openPeerContextAction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, openPeer: openPeer, openPeerContextAction: openPeerContextAction), directionHint: nil) }
    
    return GroupsInCommonListTransaction(deletions: deletions, insertions: insertions, updates: updates)
}

final class PeerInfoGroupsInCommonPaneNode: ASDisplayNode, PeerInfoPaneNode {
    private let context: AccountContext
    private let peerId: PeerId
    private let chatControllerInteraction: ChatControllerInteraction
    private let openPeerContextAction: (Peer, ASDisplayNode, ContextGesture?) -> Void
    private let groupsInCommonContext: GroupsInCommonContext
    
    weak var parentController: ViewController?
    
    private let listNode: ListView
    private var state: GroupsInCommonState?
    private var currentEntries: [GroupsInCommonListEntry] = []
    private var enqueuedTransactions: [GroupsInCommonListTransaction] = []
    
    private var currentParams: (size: CGSize, isScrollingLockedAtTop: Bool, presentationData: PresentationData)?
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }

    var status: Signal<PeerInfoStatusData?, NoError> {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        return self.groupsInCommonContext.state
        |> map { state in
            if let count = state.count {
                return PeerInfoStatusData(text: presentationData.strings.SharedMedia_CommonGroupCount(Int32(count)), isActivity: false, key: .groupsInCommon)
            } else {
                return nil
            }
        }
    }

    var tabBarOffsetUpdated: ((ContainedViewLayoutTransition) -> Void)?
    var tabBarOffset: CGFloat {
        return 0.0
    }
        
    private var disposable: Disposable?
    
    init(context: AccountContext, peerId: PeerId, chatControllerInteraction: ChatControllerInteraction, openPeerContextAction: @escaping (Peer, ASDisplayNode, ContextGesture?) -> Void, groupsInCommonContext: GroupsInCommonContext) {
        self.context = context
        self.peerId = peerId
        self.chatControllerInteraction = chatControllerInteraction
        self.openPeerContextAction = openPeerContextAction
        self.groupsInCommonContext = groupsInCommonContext
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.listNode = ListView()
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init()
        
        self.listNode.preloadPages = true
        self.addSubnode(self.listNode)
        
        self.disposable = (groupsInCommonContext.state
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let strongSelf = self else {
                return
            }
            strongSelf.state = state
            if let (_, _, presentationData) = strongSelf.currentParams {
                strongSelf.updatePeers(state: state, presentationData: presentationData)
            }
        })
        
        self.listNode.visibleBottomContentOffsetChanged = { [weak self] offset in
            guard let strongSelf = self, let state = strongSelf.state, case .ready(true) = state.dataState else {
                return
            }
            if case let .known(value) = offset, value < 100.0, case .ready(true) = state.dataState {
                strongSelf.groupsInCommonContext.loadMore()
            }
        }
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func ensureMessageIsVisible(id: MessageId) {    
    }
    
    func scrollToTop() -> Bool {
        if !self.listNode.scrollToOffsetFromTop(0.0) {
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            return true
        } else {
            return false
        }
    }
    
    func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.currentParams == nil
        self.currentParams = (size, isScrollingLockedAtTop, presentationData)
        
        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: size))
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        var scrollToItem: ListViewScrollToItem?
        if isScrollingLockedAtTop {
            switch self.listNode.visibleContentOffset() {
            case let .known(value) where value <= CGFloat.ulpOfOne:
                break
            default:
                scrollToItem = ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Spring(duration: duration), directionHint: .Up)
            }
        }

        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: scrollToItem, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: UIEdgeInsets(top: topInset, left: sideInset, bottom: bottomInset, right: sideInset), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.listNode.scrollEnabled = !isScrollingLockedAtTop
        
        if isFirstLayout, let state = self.state {
            self.updatePeers(state: state, presentationData: presentationData)
        }
    }
    
    private func updatePeers(state: GroupsInCommonState, presentationData: PresentationData) {
        var entries: [GroupsInCommonListEntry] = []
        for peer in state.peers {
            if let peer = peer.peer {
                entries.append(GroupsInCommonListEntry(index: entries.count, peer: peer))
            }
        }
        let transaction = preparedTransition(from: self.currentEntries, to: entries, context: self.context, presentationData: presentationData, openPeer: { [weak self] peer in
            self?.chatControllerInteraction.openPeer(EnginePeer(peer), .default, nil, false)
        }, openPeerContextAction: { [weak self] peer, node, gesture in
            self?.openPeerContextAction(peer, node, gesture)
        })
        self.currentEntries = entries
        self.enqueuedTransactions.append(transaction)
        self.dequeueTransaction()
    }
    
    private func dequeueTransaction() {
        guard let _ = self.currentParams, let transaction = self.enqueuedTransactions.first else {
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
    
    func updateHiddenMedia() {
    }
    
    func transferVelocity(_ velocity: CGFloat) {
        if velocity > 0.0 {
            self.listNode.transferVelocity(velocity)
        }
    }
    
    func cancelPreviewGestures() {
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    func addToTransitionSurface(view: UIView) {
    }
    
    func updateSelectedMessages(animated: Bool) {
    }
}
