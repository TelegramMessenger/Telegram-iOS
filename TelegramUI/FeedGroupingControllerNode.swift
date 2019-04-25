import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import Display

import SafariServices

/*private enum FeedGroupingControllerTransitionType {
    case initial
    case initialLoad
    case generic
    case load
}

private struct FeedGroupingControllerTransition {
    let type: FeedGroupingControllerTransitionType
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private final class FeedGroupingControllerOpaqueState {
    let entries: [FeedGroupingEntry]
    let canLoadEarlier: Bool
    
    init(entries: [FeedGroupingEntry], canLoadEarlier: Bool) {
        self.entries = entries
        self.canLoadEarlier = canLoadEarlier
    }
}

private final class FeedGroupingControllerArguments {
    let account: Account
    let togglePeer: (Peer, Bool) -> Void
    let ungroupAll: () -> Void
    
    init(account: Account, togglePeer: @escaping (Peer, Bool) -> Void, ungroupAll: @escaping () -> Void) {
        self.account = account
        self.togglePeer = togglePeer
        self.ungroupAll = ungroupAll
    }
}

private enum FeedGroupingEntryId: Hashable {
    case index(Int)
    case peer(PeerId)
    
    static func ==(lhs: FeedGroupingEntryId, rhs: FeedGroupingEntryId) -> Bool {
        switch lhs {
            case let .index(value):
                if case .index(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .peer(id):
                if case .peer(id) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case let .index(value):
                return value.hashValue
            case let .peer(id):
                return id.hashValue
        }
    }
}

private enum FeedGroupingSection: ItemListSectionId {
    case peers
    case ungroup
}

private enum FeedGroupingEntry: ItemListNodeEntry {
    case groupHeader(PresentationTheme, String)
    case peer(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, Int, Peer, Bool)
    case ungroup(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .groupHeader, .peer:
                return FeedGroupingSection.peers.rawValue
            case .ungroup:
                return FeedGroupingSection.ungroup.rawValue
        }
    }
    
    var stableId: FeedGroupingEntryId {
        switch self {
            case .groupHeader:
                return .index(0)
            case let .peer(_, _, _, _, _, peer, _):
                return .peer(peer.id)
            case .ungroup:
                return .index(1)
        }
    }
    
    static func ==(lhs: FeedGroupingEntry, rhs: FeedGroupingEntry) -> Bool {
        switch lhs {
            case let .groupHeader(lhsTheme, lhsText):
                if case let .groupHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .peer(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameOrder, lhsIndex, lhsPeer, lhsValue):
                if case let .peer(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameOrder, rhsIndex, rhsPeer, rhsValue) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    if lhsNameOrder != rhsNameOrder {
                        return false
                    }
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                    if lhsValue != rhsValue {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .ungroup(lhsTheme, lhsText):
                if case let .ungroup(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: FeedGroupingEntry, rhs: FeedGroupingEntry) -> Bool {
        switch lhs {
            case .groupHeader:
                return true
            case let .peer(_, _, _, _, index, _, _):
                switch rhs {
                    case .groupHeader:
                        return false
                    case let .peer(_, _, _, _, rhsIndex, _, _):
                        return index < rhsIndex
                    default:
                        return true
                }
            case .ungroup:
                return false
        }
    }
    
    func item(_ arguments: FeedGroupingControllerArguments) -> ListViewItem {
        switch self {
            case let .groupHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .peer(theme, strings, dateTimeFormat, nameDisplayOrder, _, peer, value):
                return ItemListPeerItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, account: arguments.account, peer: peer, presence: nil, text: .none, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: ItemListPeerItemSwitch(value: value, style: .standard), enabled: true, selectable: true, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, toggleUpdated: { value in
                    arguments.togglePeer(peer, value)
                })
            case let .ungroup(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.ungroupAll()
                })
        }
    }
}

private final class FeedGroupingPeerState {
    let peer: Peer
    let included: Bool
    
    init(peer: Peer, included: Bool) {
        self.peer = peer
        self.included = included
    }
}

private final class FeedGroupingEntriesState {
    let entries: [FeedGroupingEntry]
    
    init(entries: [FeedGroupingEntry]) {
        self.entries = entries
    }
}

private final class FeedGroupingState {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let peers: [FeedGroupingPeerState]
    
    init(theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, peers: [FeedGroupingPeerState]) {
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.peers = peers
    }
    
    func withUpdatedPeers(_ peers: [FeedGroupingPeerState]) -> FeedGroupingState {
        return FeedGroupingState(theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, peers: peers)
    }
}

private func entriesStateFromState(_ state: FeedGroupingState) -> FeedGroupingEntriesState {
    var entries: [FeedGroupingEntry] = []
    if !state.peers.isEmpty {
        entries.append(.groupHeader(state.theme, "GROUP CHANNELS"))
        var index = 0
        for peer in state.peers {
            entries.append(.peer(state.theme, state.strings, state.dateTimeFormat, state.nameDisplayOrder, index, peer.peer, peer.included))
            index += 1
        }
        entries.append(.ungroup(state.theme, "Ungroup All Channels"))
    }
    return FeedGroupingEntriesState(entries: entries)
}

private func preparedItemListNodeEntryTransition(from fromEntries: [FeedGroupingEntry], to toEntries: [FeedGroupingEntry], arguments: FeedGroupingControllerArguments, type: FeedGroupingControllerTransitionType) -> FeedGroupingControllerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(arguments), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(arguments), directionHint: nil) }
    
    return FeedGroupingControllerTransition(type: type, deletions: deletions, insertions: insertions, updates: updates)
}

final class FeedGroupingControllerNode: ViewControllerTracingNode {
    private let context: AccountContext
    private let groupId: PeerGroupId
    private var presentationData: PresentationData
    private let ungroupedAll: () -> Void
    
    let readyPromise = ValuePromise<Bool>()
    private var ready: Bool = false {
        didSet {
            if self.ready && !oldValue {
                self.readyPromise.set(self.ready)
            }
        }
    }
    
    private var presentationDataDisposable: Disposable?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private let listNode: ListView
    private let blockingOverlay: ASDisplayNode
    
    private var _stateValue: FeedGroupingState
    private let statePromise = Promise<FeedGroupingState>()
    
    private var _entriesStateValue = FeedGroupingEntriesState(entries: [])
    private let entriesStatePromise = Promise<FeedGroupingEntriesState>()
    
    private var enqueuedTransitions: [FeedGroupingControllerTransition] = []
    
    private let peersDisposable = MetaDisposable()
    
    private var transitionDisposable: Disposable?
    
    init(context: AccountContext, groupId: PeerGroupId, presentationData: PresentationData, ungroupedAll: @escaping () -> Void) {
        self.context = context
        self.groupId = groupId
        self.presentationData = presentationData
        self.ungroupedAll = ungroupedAll
        
        self.listNode = ListView()
        self.listNode.isHidden = true
        
        self.blockingOverlay = ASDisplayNode()
        self.blockingOverlay.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        
        self._stateValue = FeedGroupingState(theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder, peers: [])
        self.statePromise.set(.single(self._stateValue))
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        
        self.addSubnode(self.listNode)
        self.addSubnode(self.blockingOverlay)
        
        self.listNode.displayedItemRangeChanged = { [weak self] displayedRange, opaqueTransactionState in
            if let strongSelf = self {
                /*if let state = (opaqueTransactionState as? ChatRecentActionsListOpaqueState), state.canLoadEarlier {
                    if let visible = displayedRange.visibleRange {
                        let indexRange = (state.entries.count - 1 - visible.lastIndex, state.entries.count - 1 - visible.firstIndex)
                        if indexRange.0 < 5 {
                            strongSelf.context.loadMoreEntries()
                        }
                    }
                }*/
            }
        }
        
        let previousState = Atomic<FeedGroupingEntriesState?>(value: nil)
        
        let arguments = FeedGroupingControllerArguments(account: context.account, togglePeer: { [weak self] peer, value in
            if let strongSelf = self {
                strongSelf.updateState({ current in
                    var peers = current.peers
                    var index = 0
                    for listPeer in peers {
                        if listPeer.peer.id == peer.id {
                            peers[index] = FeedGroupingPeerState(peer: listPeer.peer, included: value)
                            break
                        }
                        index += 1
                    }
                    return current.withUpdatedPeers(peers)
                })
                let _ = updatePeerGroupIdInteractively(postbox: strongSelf.context.account.postbox, peerId: peer.id, groupId: value ? strongSelf.groupId : nil).start()
            }
        }, ungroupAll: { [weak self] in
            if let strongSelf = self {
                
                let _ = (clearPeerGroupInteractively(postbox: strongSelf.context.account.postbox, groupId: strongSelf.groupId)
                |> deliverOnMainQueue).start(completed: {
                    self?.ungroupedAll()
                })
            }
        })
        
        self.transitionDisposable = (self.entriesStatePromise.get()
        |> mapToQueue { state -> Signal<FeedGroupingControllerTransition, NoError> in
            let previous = previousState.swap(state)
            let type: FeedGroupingControllerTransitionType
            if let previous = previous {
                if previous.entries.isEmpty {
                    type = .initialLoad
                } else {
                    type = .generic
                }
            } else {
                type = .initial
            }
            return .single(preparedItemListNodeEntryTransition(from: previous?.entries ?? [], to: state.entries, arguments: arguments, type: type))
        }
        |> deliverOnMainQueue).start(next: { [weak self] transition in
            return self?.enqueueTransition(transition)
        })
        
        self.updateState({ state in
            return state
        })
        
        self.peersDisposable.set((availableGroupFeedPeers(postbox: self.context.account.postbox, network: self.context.account.network, groupId: groupId)
        |> deliverOnMainQueue).start(next: { [weak self] result in
            if let strongSelf = self {
                strongSelf.updateState({ state in
                    return state.withUpdatedPeers(result.map { peer, value in
                        return FeedGroupingPeerState(peer: peer, included: value)
                    })
                })
            }
        }))
    }
    
    deinit {
        self.transitionDisposable?.dispose()
    }
    
    private func updateState(_ f: (FeedGroupingState) -> FeedGroupingState) {
        let updatedState = f(self._stateValue)
        self._stateValue = updatedState
        self._entriesStateValue = entriesStateFromState(updatedState)
        self.entriesStatePromise.set(.single(self._entriesStateValue))
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.containerLayout == nil
        
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        transition.updateBounds(node: self.listNode, bounds: CGRect(origin: CGPoint(), size: layout.size))
        transition.updatePosition(node: self.listNode, position: CGRect(origin: CGPoint(), size: layout.size).center)
        
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
            case .immediate:
                break
            case let .animated(animationDuration, animationCurve):
                duration = animationDuration
                switch animationCurve {
                    case .easeInOut, .custom:
                        break
                    case .spring:
                        curve = 7
                }
        }
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default(duration: duration)
        }
        
        let listInsets = UIEdgeInsets(top: insets.top, left: layout.safeInsets.right, bottom: insets.bottom, right: layout.safeInsets.left)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: listInsets, duration: duration, curve: listViewCurve)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, additionalScrollDistance: 0.0, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if isFirstLayout {
            self.dequeueTransitions()
        }
    }
    
    private func enqueueTransition(_ transition: FeedGroupingControllerTransition) {
        self.enqueuedTransitions.append(transition)
        if self.containerLayout != nil {
            self.dequeueTransitions()
        }
    }
    
    private func dequeueTransitions() {
        while true {
            if let transition = self.enqueuedTransitions.first {
                self.enqueuedTransitions.remove(at: 0)
                
                var options = ListViewDeleteAndInsertOptions()
                switch transition.type {
                    case .initial:
                        options.insert(.LowLatency)
                    case .generic:
                        options.insert(.AnimateInsertion)
                    case .load, .initialLoad:
                        break
                }
                
                self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                    if let strongSelf = self {
                        strongSelf.ready = true
                        if transition.type == .initialLoad {
                            strongSelf.listNode.isHidden = false
                            strongSelf.listNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        }
                        /*if displayingResults != !strongSelf.listNode.isHidden {
                            strongSelf.listNode.isHidden = !displayingResults
                            strongSelf.backgroundColor = displayingResults ? strongSelf.presentationData.theme.list.plainBackgroundColor : nil
                            
                            strongSelf.emptyNode.isHidden = displayingResults
                            if !displayingResults {
                                var text: String = ""
                                if let query = strongSelf.filter.query {
                                    text = strongSelf.presentationData.strings.Channel_AdminLog_EmptyFilterQueryText(query).0
                                } else {
                                    text = strongSelf.presentationData.strings.Channel_AdminLog_EmptyFilterText
                                }
                                strongSelf.emptyNode.setup(title: strongSelf.presentationData.strings.Channel_AdminLog_EmptyFilterTitle, text: text)
                            }
                            //strongSelf.isLoading = isEmpty && !displayingResults
                        }*/
                    }
                })
            } else {
                break
            }
        }
    }
}

*/
