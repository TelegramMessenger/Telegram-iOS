import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import TemporaryCachedPeerDataManager
import SearchBarNode
import ContactsPeerItem
import SearchUI
import ItemListUI

private final class ChannelMembersSearchInteraction {
    let openPeer: (Peer, RenderedChannelParticipant?) -> Void
    
    init(openPeer: @escaping (Peer, RenderedChannelParticipant?) -> Void) {
        self.openPeer = openPeer
    }
}

private enum ChannelMembersSearchEntryId: Hashable {
    case peer(PeerId)
}

private enum ChannelMembersSearchEntry: Comparable, Identifiable {
    case peer(Int, RenderedChannelParticipant, ContactsPeerItemEditing, String?, Bool)
    
    var stableId: ChannelMembersSearchEntryId {
        switch self {
            case let .peer(peer):
                return .peer(peer.1.peer.id)
        }
    }
    
    static func ==(lhs: ChannelMembersSearchEntry, rhs: ChannelMembersSearchEntry) -> Bool {
        switch lhs {
            case let .peer(lhsIndex, lhsParticipant, lhsEditing, lhsLabel, lhsEnabled):
                if case .peer(lhsIndex, lhsParticipant, lhsEditing, lhsLabel, lhsEnabled) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChannelMembersSearchEntry, rhs: ChannelMembersSearchEntry) -> Bool {
        switch lhs {
            case let .peer(lhsPeer):
                if case let .peer(rhsPeer) = rhs {
                    return lhsPeer.0 < rhsPeer.0
                } else {
                    return false
                }
        }
    }
    
    func item(context: AccountContext, presentationData: PresentationData, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, interaction: ChannelMembersSearchInteraction) -> ListViewItem {
        switch self {
            case let .peer(_, participant, editing, label, enabled):
                let status: ContactsPeerItemStatus
                if let label = label {
                    status = .custom(label)
                } else {
                    status = .none
                }
                return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: .peer, peer: .peer(peer: participant.peer, chatPeer: nil), status: status, enabled: enabled, selection: .none, editing: editing, index: nil, header: nil, action: { _ in
                    interaction.openPeer(participant.peer, participant)
                })
        }
    }
}

private struct ChannelMembersSearchTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let initial: Bool
}

private func preparedTransition(from fromEntries: [ChannelMembersSearchEntry]?, to toEntries: [ChannelMembersSearchEntry], context: AccountContext, presentationData: PresentationData, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, interaction: ChannelMembersSearchInteraction) -> ChannelMembersSearchTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries ?? [], rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, interaction: interaction), directionHint: nil) }
    
    return ChannelMembersSearchTransition(deletions: deletions, insertions: insertions, updates: updates, initial: fromEntries == nil)
}

class ChannelMembersSearchControllerNode: ASDisplayNode {
    private let context: AccountContext
    private let peerId: PeerId
    private let mode: ChannelMembersSearchControllerMode
    private let filters: [ChannelMembersSearchFilter]
    let listNode: ListView
    var navigationBar: NavigationBar?
    
    private var enqueuedTransitions: [ChannelMembersSearchTransition] = []
    
    private(set) var searchDisplayController: SearchDisplayController?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var requestActivateSearch: (() -> Void)?
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((Peer, RenderedChannelParticipant?) -> Void)?
    var pushController: ((ViewController) -> Void)?
    
    var presentationData: PresentationData

    private var disposable: Disposable?
    private var listControl: PeerChannelMemberCategoryControl?
    
    init(context: AccountContext, presentationData: PresentationData, peerId: PeerId, mode: ChannelMembersSearchControllerMode, filters: [ChannelMembersSearchFilter]) {
        self.context = context
        self.listNode = ListView()
        self.peerId = peerId
        self.mode = mode
        self.filters = filters
        self.presentationData = presentationData
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.listNode)
        
        let interaction = ChannelMembersSearchInteraction(openPeer: { [weak self] peer, participant in
            self?.requestOpenPeerFromSearch?(peer, participant)
            self?.listNode.clearHighlightAnimated(true)
        })
        
        let previousEntries = Atomic<[ChannelMembersSearchEntry]?>(value: nil)
        
        let disposableAndLoadMoreControl: (Disposable, PeerChannelMemberCategoryControl?)
        
        if peerId.namespace == Namespaces.Peer.CloudGroup {
            let disposable = (context.account.postbox.peerView(id: peerId)
            |> deliverOnMainQueue).start(next: { [weak self] peerView in
                guard let strongSelf = self else {
                    return
                }
                guard let cachedData = peerView.cachedData as? CachedGroupData, let participants = cachedData.participants else {
                    return
                }
                var creatorPeer: Peer?
                for participant in participants.participants {
                    if let peer = peerView.peers[participant.peerId] {
                        switch participant {
                            case .creator:
                                creatorPeer = peer
                            default:
                                break
                        }
                    }
                }
                guard let creator = creatorPeer else {
                    return
                }
                var entries: [ChannelMembersSearchEntry] = []
                
                var index = 0
                for participant in participants.participants {
                    guard let peer = peerView.peers[participant.peerId] else {
                        continue
                    }
                    if peer.isDeleted {
                        continue
                    }
                    var label: String?
                    var enabled = true
                    switch mode {
                        case .ban:
                            if peer.id == context.account.peerId {
                                continue
                            }
                            for filter in filters {
                                switch filter {
                                    case let .exclude(ids):
                                        if ids.contains(peer.id) {
                                            continue
                                        }
                                    case .disable:
                                        break
                                }
                            }
                        case .promote:
                            if peer.id == context.account.peerId {
                                continue
                            }
                            for filter in filters {
                                switch filter {
                                    case let .exclude(ids):
                                        if ids.contains(peer.id) {
                                            continue
                                        }
                                    case .disable:
                                        break
                                }
                            }
                            if case .creator = participant {
                                label = strongSelf.presentationData.strings.Channel_Management_LabelOwner
                                enabled = false
                            }
                    }
                    let renderedParticipant: RenderedChannelParticipant
                    switch participant {
                        case .creator:
                            renderedParticipant = RenderedChannelParticipant(participant: .creator(id: peer.id, rank: nil), peer: peer)
                        case .admin:
                            var peers: [PeerId: Peer] = [:]
                            peers[creator.id] = creator
                            peers[peer.id] = peer
                            renderedParticipant = RenderedChannelParticipant(participant: .member(id: peer.id, invitedAt: 0, adminInfo: ChannelParticipantAdminInfo(rights: TelegramChatAdminRights(flags: .groupSpecific), promotedBy: creator.id, canBeEditedByAccountPeer: creator.id == context.account.peerId), banInfo: nil, rank: nil), peer: peer, peers: peers)
                        case .member:
                            var peers: [PeerId: Peer] = [:]
                            peers[peer.id] = peer
                            renderedParticipant = RenderedChannelParticipant(participant: .member(id: peer.id, invitedAt: 0, adminInfo: nil, banInfo: nil, rank: nil), peer: peer, peers: peers)
                    }
                    
                    entries.append(.peer(index, renderedParticipant, ContactsPeerItemEditing(editable: false, editing: false, revealed: false), label, enabled))
                    index += 1
                }
                let previous = previousEntries.swap(entries)
                
                strongSelf.enqueueTransition(preparedTransition(from: previous, to: entries, context: context, presentationData: strongSelf.presentationData, nameSortOrder: strongSelf.presentationData.nameSortOrder, nameDisplayOrder: strongSelf.presentationData.nameDisplayOrder, interaction: interaction))
            })
            disposableAndLoadMoreControl = (disposable, nil)
        } else {
            disposableAndLoadMoreControl = context.peerChannelMemberCategoriesContextsManager.recent(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, updated: { [weak self] state in
                guard let strongSelf = self else {
                    return
                }
                var entries: [ChannelMembersSearchEntry] = []
                
                var index = 0
                for participant in state.list {
                    if participant.peer.isDeleted {
                        continue
                    }
                    
                    var label: String?
                    var enabled = true
                    switch mode {
                        case .ban:
                            if participant.peer.id == context.account.peerId {
                                continue
                            }
                            for filter in filters {
                                switch filter {
                                case let .exclude(ids):
                                    if ids.contains(participant.peer.id) {
                                        continue
                                    }
                                case .disable:
                                    break
                                }
                            }
                        case .promote:
                            if participant.peer.id == context.account.peerId {
                                continue
                            }
                            for filter in filters {
                                switch filter {
                                case let .exclude(ids):
                                    if ids.contains(participant.peer.id) {
                                        continue
                                    }
                                case .disable:
                                    break
                                }
                            }
                            if case .creator = participant.participant {
                                label = strongSelf.presentationData.strings.Channel_Management_LabelOwner
                                enabled = false
                            }
                    }
                    entries.append(.peer(index, participant, ContactsPeerItemEditing(editable: false, editing: false, revealed: false), label, enabled))
                    index += 1
                }
                
                let previous = previousEntries.swap(entries)
                
                strongSelf.enqueueTransition(preparedTransition(from: previous, to: entries, context: context, presentationData: strongSelf.presentationData, nameSortOrder: strongSelf.presentationData.nameSortOrder, nameDisplayOrder: strongSelf.presentationData.nameDisplayOrder, interaction: interaction))
            })
        }
        self.disposable = disposableAndLoadMoreControl.0
        self.listControl = disposableAndLoadMoreControl.1
        
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            self.listNode.visibleBottomContentOffsetChanged = { offset in
                if case let .known(value) = offset, value < 40.0 {
                    context.peerChannelMemberCategoriesContextsManager.loadMore(peerId: peerId, control: disposableAndLoadMoreControl.1)
                }
            }
        }
        
        self.listNode.beganInteractiveDragging = { [weak self] in
            self?.view.endEditing(true)
        }
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.searchDisplayController?.updatePresentationData(presentationData)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.containerLayout != nil
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        self.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)

        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar, self.searchDisplayController == nil else {
            return
        }
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: ChannelMembersSearchContainerNode(context: self.context, peerId: self.peerId, mode: .banAndPromoteActions, filters: self.filters, searchContext: nil, openPeer: { [weak self] peer, participant in
            self?.requestOpenPeerFromSearch?(peer, participant)
        }, updateActivity: { value in
            
        }, pushController: { [weak self] c in
            self?.pushController?(c)
        }), cancel: { [weak self] in
            if let requestDeactivateSearch = self?.requestDeactivateSearch {
                requestDeactivateSearch()
            }
        })
        
        self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
            if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
                if isSearchBar {
                    strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
                } else {
                    strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
                }
            }
        }, placeholder: placeholderNode)
    }
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode, animated: Bool) {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.deactivate(placeholder: placeholderNode)
            self.searchDisplayController = nil
        }
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    private func enqueueTransition(_ transition: ChannelMembersSearchTransition) {
        enqueuedTransitions.append(transition)
        
        if self.containerLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let transition = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            let options = ListViewDeleteAndInsertOptions()
            if transition.initial {
                //options.insert(.Synchronous)
                //options.insert(.LowLatency)
            } else {
                //options.insert(.AnimateTopItemPosition)
                //options.insert(.AnimateCrossfade)
            }
            
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
            })
        }
    }
    
    func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
}
