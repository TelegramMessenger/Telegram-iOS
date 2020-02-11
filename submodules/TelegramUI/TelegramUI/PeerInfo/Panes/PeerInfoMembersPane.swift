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

private struct PeerMembersListTransaction {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let animated: Bool
}

enum PeerMembersListAction {
    case open
    case promote
    case restrict
    case remove
}

private struct PeerMembersListEntry: Comparable, Identifiable {
    var index: Int
    var member: PeerInfoMember
    
    var stableId: PeerId {
        return self.member.id
    }
    
    static func ==(lhs: PeerMembersListEntry, rhs: PeerMembersListEntry) -> Bool {
        return lhs.member == rhs.member
    }
    
    static func <(lhs: PeerMembersListEntry, rhs: PeerMembersListEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, presentationData: PresentationData, enclosingPeer: Peer, action: @escaping (PeerInfoMember, PeerMembersListAction) -> Void) -> ListViewItem {
        let member = self.member
        let label: String?
        if let rank = member.rank {
            label = rank
        } else {
            switch member.role {
            case .creator:
                label = presentationData.strings.GroupInfo_LabelOwner
            case .admin:
                label = presentationData.strings.GroupInfo_LabelAdmin
            case .member:
                label = nil
            }
        }
        
        let actions = availableActionsForMemberOfPeer(accountPeerId: context.account.peerId, peer: enclosingPeer, member: member)
        
        var options: [ItemListPeerItemRevealOption] = []
        if actions.contains(.promote) && enclosingPeer is TelegramChannel{
            options.append(ItemListPeerItemRevealOption(type: .neutral, title: presentationData.strings.GroupInfo_ActionPromote, action: {
                action(member, .promote)
            }))
        }
        if actions.contains(.restrict) {
            if enclosingPeer is TelegramChannel {
                options.append(ItemListPeerItemRevealOption(type: .warning, title: presentationData.strings.GroupInfo_ActionRestrict, action: {
                    action(member, .restrict)
                }))
            }
            options.append(ItemListPeerItemRevealOption(type: .destructive, title: presentationData.strings.Common_Delete, action: {
                action(member, .remove)
            }))
        }
        
        return ItemListPeerItem(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, context: context, peer: member.peer, presence: member.presence, text: .presence, label: label == nil ? .none : .text(label!, .standard), editing: ItemListPeerItemEditing(editable: !options.isEmpty, editing: false, revealed: false), revealOptions: ItemListPeerItemRevealOptions(options: options), switchValue: nil, enabled: true, selectable: member.id != context.account.peerId, sectionId: 0, action: {
            action(member, .open)
        }, setPeerIdWithRevealedOptions: { _, _ in
        }, removePeer: { _ in
        }, contextAction: nil/*{ node, gesture in
            openPeerContextAction(peer, node, gesture)
        }*/, hasTopStripe: false, noInsets: true)
    }
}

private func preparedTransition(from fromEntries: [PeerMembersListEntry], to toEntries: [PeerMembersListEntry], context: AccountContext, presentationData: PresentationData, enclosingPeer: Peer, action: @escaping (PeerInfoMember, PeerMembersListAction) -> Void) -> PeerMembersListTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, enclosingPeer: enclosingPeer, action: action), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, enclosingPeer: enclosingPeer, action: action), directionHint: nil) }
    
    return PeerMembersListTransaction(deletions: deletions, insertions: insertions, updates: updates, animated: toEntries.count < fromEntries.count)
}

final class PeerInfoMembersPaneNode: ASDisplayNode, PeerInfoPaneNode {
    private let context: AccountContext
    private let membersContext: PeerInfoMembersContext
    private let action: (PeerInfoMember, PeerMembersListAction) -> Void
    
    private let listNode: ListView
    private var currentEntries: [PeerMembersListEntry] = []
    private var enclosingPeer: Peer?
    private var currentState: PeerInfoMembersState?
    private var canLoadMore: Bool = false
    private var enqueuedTransactions: [PeerMembersListTransaction] = []
    
    private var currentParams: (size: CGSize, isScrollingLockedAtTop: Bool, presentationData: PresentationData)?
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }
    
    private var disposable: Disposable?
    
    init(context: AccountContext, peerId: PeerId, membersContext: PeerInfoMembersContext, action: @escaping (PeerInfoMember, PeerMembersListAction) -> Void) {
        self.context = context
        self.membersContext = membersContext
        self.action = action
        
        self.listNode = ListView()
        
        super.init()
        
        self.listNode.preloadPages = true
        self.addSubnode(self.listNode)
        
        self.disposable = (combineLatest(queue: .mainQueue(),
            membersContext.state,
            context.account.postbox.combinedView(keys: [.basicPeer(peerId)])
        )
        |> deliverOnMainQueue).start(next: { [weak self] state, combinedView in
            guard let strongSelf = self, let basicPeerView = combinedView.views[.basicPeer(peerId)] as? BasicPeerView, let enclosingPeer = basicPeerView.peer else {
                return
            }
            
            strongSelf.enclosingPeer = enclosingPeer
            strongSelf.currentState = state
            if let (_, _, presentationData) = strongSelf.currentParams {
                strongSelf.updateState(enclosingPeer: enclosingPeer, state: state, presentationData: presentationData)
            }
        })
        
        self.listNode.visibleBottomContentOffsetChanged = { [weak self] offset in
            guard let strongSelf = self, let state = strongSelf.currentState, case .ready(true) = state.dataState else {
                return
            }
            if case let .known(value) = offset, value < 100.0 {
                strongSelf.membersContext.loadMore()
            }
        }
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
    
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.currentParams == nil
        self.currentParams = (size, isScrollingLockedAtTop, presentationData)
        
        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: size))
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)

        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: UIEdgeInsets(top: 0.0, left: sideInset, bottom: bottomInset, right: sideInset), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.listNode.scrollEnabled = !isScrollingLockedAtTop
        
        if isFirstLayout, let enclosingPeer = self.enclosingPeer, let state = self.currentState {
            self.updateState(enclosingPeer: enclosingPeer, state: state, presentationData: presentationData)
        }
    }
    
    private func updateState(enclosingPeer: Peer, state: PeerInfoMembersState, presentationData: PresentationData) {
        var entries: [PeerMembersListEntry] = []
        for member in state.members {
            entries.append(PeerMembersListEntry(index: entries.count, member: member))
        }
        let transaction = preparedTransition(from: self.currentEntries, to: entries, context: self.context, presentationData: presentationData, enclosingPeer: enclosingPeer, action: { [weak self] member, action in
            self?.action(member, action)
        })
        self.enclosingPeer = enclosingPeer
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
        if transaction.animated {
            options.insert(.AnimateInsertion)
        } else {
            options.insert(.Synchronous)
        }
        
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
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    func addToTransitionSurface(view: UIView) {
    }
    
    func updateSelectedMessages(animated: Bool) {
    }
}
