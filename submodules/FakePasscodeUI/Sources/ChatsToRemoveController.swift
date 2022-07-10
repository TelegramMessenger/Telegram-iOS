import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext
import ContactsPeerItem
import FakePasscode
import SearchUI
import UIKit
import SearchBarNode
import ChatListUI

private final class ChatsToRemoveControllerArguments {
    let context: AccountContext
    
    let action: (Peer) -> Void
    let updateRevealedPeerId: (PeerId?) -> Void
    let removePeer: (Peer) -> Void
    
    init(context: AccountContext, action: @escaping (Peer) -> Void, updateRevealedPeerId: @escaping (PeerId?) -> Void, removePeer: @escaping (Peer) -> Void) {
        self.context = context
        
        self.action = action
        self.updateRevealedPeerId = updateRevealedPeerId
        self.removePeer = removePeer
    }
}

private enum ChatsToRemoveSection: Int32 {
    case configured
    case available
}

private enum ChatsToRemoveEntry: ItemListNodeEntry {
    case configuredChatsHeader(PresentationTheme, String)
    case configuredChat(Int32, PresentationTheme, PresentationPersonNameOrder, PresentationPersonNameOrder, RenderedPeer, ContactsPeerItemSelection, String, Bool, Bool)
    case availableChatsHeader(PresentationTheme, String)
    case availableChat(Int32, PresentationTheme, PresentationPersonNameOrder, PresentationPersonNameOrder, RenderedPeer, ContactsPeerItemSelection)
    
    var section: ItemListSectionId {
        switch self {
            case .configuredChatsHeader, .configuredChat:
                return ChatsToRemoveSection.configured.rawValue
            case .availableChatsHeader, .availableChat:
                return ChatsToRemoveSection.available.rawValue
        }
    }
    
    enum StableId: Hashable {
        case configuredChatsHeader
        case configuredChat(PeerId)
        case availableChatsHeader
        case availableChat(PeerId)
    }
    
    var stableId: StableId {
        switch self {
            case .configuredChatsHeader:
                return .configuredChatsHeader
            case let .configuredChat(_, _, _, _, peer, _, _, _, _):
                return .configuredChat(peer.peer!.id)
            case .availableChatsHeader:
                return .availableChatsHeader
            case let .availableChat(_, _, _, _, peer, _):
                return .availableChat(peer.peer!.id)
        }
    }
    
    static func <(lhs: ChatsToRemoveEntry, rhs: ChatsToRemoveEntry) -> Bool {
        switch lhs {
            case .configuredChatsHeader:
                return true
            case let .configuredChat(lhsIndex, _, _, _, _, _, _, _, _):
                if case .configuredChatsHeader = rhs {
                    return false
                } else if case let .configuredChat(rhsIndex, _, _, _, _, _, _, _, _) = rhs {
                    return lhsIndex < rhsIndex
                } else {
                    return true
                }
            case .availableChatsHeader:
                if case .availableChat = rhs {
                    return true
                } else {
                    return false
                }
            case let .availableChat(lhsIndex, _, _, _, _, _):
                if case let .availableChat(rhsIndex, _, _, _, _, _) = rhs {
                    return lhsIndex < rhsIndex
                } else {
                    return false
                }
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChatsToRemoveControllerArguments
        switch self {
            case let .configuredChatsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .configuredChat(_, _, nameSortOrder, nameDisplayOrder, peer, selection, description, editable, revealed):
                return ContactsPeerItem(presentationData: presentationData, style: .blocks, sectionId: self.section, sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: arguments.context, peerMode: .generalSearch, peer: .peer(peer: EnginePeer(peer.chatMainPeer!), chatPeer: EnginePeer(peer.peer!)), status: .custom(string: description, multiline: false), enabled: true, selection: selection, editing: ContactsPeerItemEditing(editable: editable, editing: false, revealed: editable && revealed), index: nil, header: nil, action: { peeritem in
                    arguments.action(peer.peer!)
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    arguments.updateRevealedPeerId(peerId)
                }, deletePeer: { peerId in
                    arguments.removePeer(peer.peer!)
                }, useBottomGroupedInset: true)
            case let .availableChatsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .availableChat(_, _, nameSortOrder, nameDisplayOrder, peer, selection):
                return ContactsPeerItem(presentationData: presentationData, style: .blocks, sectionId: self.section, sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: arguments.context, peerMode: .generalSearch, peer: .peer(peer: EnginePeer(peer.chatMainPeer!), chatPeer: EnginePeer(peer.peer!)), status: .none, enabled: true, selection: selection, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: nil, action: { peeritem in
                    arguments.action(peer.peer!)
                }, useBottomGroupedInset: true)
        }
    }
}

private struct ChatsToRemoveState: Equatable {
    let chatsToRemove: [PeerWithRemoveOptions]
    let revealedPeerId: PeerId?
    let selecting: Bool
    let selectedPeerIds: Set<PeerId>
    let searching: Bool
    
    init(chatsToRemove: [PeerWithRemoveOptions], revealedPeerId: PeerId? = nil, selecting: Bool = false, selectedPeerIds: Set<PeerId> = [], searching: Bool = false) {
        self.chatsToRemove = chatsToRemove
        self.revealedPeerId = revealedPeerId
        self.selecting = selecting
        self.selectedPeerIds = selectedPeerIds
        self.searching = searching
    }
    
    func withUpdatedChatsToRemove(_ chatsToRemove: [PeerWithRemoveOptions]) -> ChatsToRemoveState {
        return ChatsToRemoveState(chatsToRemove: chatsToRemove, revealedPeerId: self.revealedPeerId, selecting: self.selecting, selectedPeerIds: self.selectedPeerIds, searching: self.searching)
    }
    
    func withUpdatedRevealedPeerId(_ revealedPeerId: PeerId?) -> ChatsToRemoveState {
        return ChatsToRemoveState(chatsToRemove: self.chatsToRemove, revealedPeerId: revealedPeerId, selecting: self.selecting, selectedPeerIds: self.selectedPeerIds, searching: self.searching)
    }
    
    func withUpdatedSelecting(_ selecting: Bool) -> ChatsToRemoveState {
        return ChatsToRemoveState(chatsToRemove: self.chatsToRemove, revealedPeerId: !selecting ? self.revealedPeerId : nil, selecting: selecting, selectedPeerIds: selecting ? self.selectedPeerIds : [], searching: self.searching)
    }
    
    func withUpdatedSelectedPeerIds(_ selectedPeerIds: Set<PeerId>) -> ChatsToRemoveState {
        return ChatsToRemoveState(chatsToRemove: self.chatsToRemove, revealedPeerId: self.revealedPeerId, selecting: self.selecting, selectedPeerIds: selectedPeerIds, searching: self.searching)
    }
    
    func withUpdatedSearching(_ searching: Bool) -> ChatsToRemoveState {
        return ChatsToRemoveState(chatsToRemove: self.chatsToRemove, revealedPeerId: self.revealedPeerId, selecting: self.selecting, selectedPeerIds: self.selectedPeerIds, searching: searching)
    }
}

private func chatsToRemoveEntries(presentationData: PresentationData, state: ChatsToRemoveState, peerEntries: [PeerId: (index: ChatListIndex, peer: RenderedPeer)], configuredPeers: [PeerId: RenderedPeer]) -> [ChatsToRemoveEntry] {
    var entries: [ChatsToRemoveEntry] = []
    
    let configuredList = state.chatsToRemove.compactMap { chatToRemove -> (PeerWithRemoveOptions, RenderedPeer, ChatListIndex)? in
        if let pe = peerEntries[chatToRemove.peerId] {
            return (chatToRemove, pe.peer, pe.index)
        } else if let peer = configuredPeers[chatToRemove.peerId] {
            return (chatToRemove, peer, .absoluteLowerBound)
        } else {
            return nil
        }
    }.sorted {
        return $1.2 < $0.2
    }
    
    if !configuredList.isEmpty {
        entries.append(.configuredChatsHeader(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_ConfiguredChatsHeader.uppercased()))
    }
    
    let configuredPeerIds = Set(state.chatsToRemove.map { $0.peerId })
    
    for (index, value) in configuredList.enumerated() {
        let title: String
        switch value.0.removalType {
        case .delete:
            title = presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_RemovalTypeDelete
        case .hide:
            title = presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_RemovalTypeHide
        }
        
        let peer = value.1
        entries.append(.configuredChat(Int32(index), presentationData.theme, presentationData.nameSortOrder, presentationData.nameDisplayOrder, peer, state.selecting && (state.selectedPeerIds.isEmpty || configuredPeerIds.contains(state.selectedPeerIds.first!)) ? .selectable(selected: state.selectedPeerIds.contains(peer.peer!.id)) : .none, title, !state.selecting, state.revealedPeerId == peer.peer!.id))
    }
    
    let availableList = peerEntries.values.filter { value in
        return !configuredPeerIds.contains(value.peer.peerId)
    }.sorted {
        return $1.index < $0.index
    }
    
    if !availableList.isEmpty {
        entries.append(.availableChatsHeader(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_AvailableChatsHeader.uppercased()))
    }
    
    for (index, value) in availableList.enumerated() {
        entries.append(.availableChat(Int32(index), presentationData.theme, presentationData.nameSortOrder, presentationData.nameDisplayOrder, value.peer, state.selecting && (state.selectedPeerIds.isEmpty || !configuredPeerIds.contains(state.selectedPeerIds.first!)) ? .selectable(selected: state.selectedPeerIds.contains(value.peer.peer!.id)) : .none))
    }
    
    return entries
}

public func chatsToRemoveController(context: AccountContext, chatsToRemove: [PeerWithRemoveOptions], updatedSettings: @escaping ([PeerWithRemoveOptions]) -> Void) -> ViewController {
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var clearHighlightImpl: (() -> Void)?
    var setDisplayNavigationBarImpl: ((Bool) -> Void)?
    
    weak var searchContentNode: NavigationBarSearchContentNode?
    
    let initialValue = ChatsToRemoveState(chatsToRemove: chatsToRemove)
    let stateValue = Atomic(value: initialValue)
    let statePromise = ValuePromise(initialValue, ignoreRepeated: true)
    
    let updateState: ((ChatsToRemoveState) -> ChatsToRemoveState) -> Void = { f in
        let result = stateValue.modify { f($0) }
        statePromise.set(result)
    }
    
    let presentPeerSettings: ([PeerId]) -> Void = { peerIds in
        let state = stateValue.with { $0 }
        
        let peersWithRemoveOptions = state.chatsToRemove.filter({ peerIds.contains($0.peerId) })
        
        presentControllerImpl?(chatsToRemovePeerSettingsController(context: context, peerIds: peerIds, peersWithRemoveOptions: peersWithRemoveOptions, updatePeersRemoveOptions: { peerIds, removalType in
            updateState { current in
                var updatedChatsToRemove = current.chatsToRemove
                for peerId in peerIds {
                    let peerRemoveOptions = PeerWithRemoveOptions(peerId: peerId, removalType: removalType)
                    if let ind = updatedChatsToRemove.firstIndex(where: { $0.peerId == peerId }) {
                        updatedChatsToRemove[ind] = peerRemoveOptions
                    } else {
                        updatedChatsToRemove.append(peerRemoveOptions)
                    }
                }
                updatedSettings(updatedChatsToRemove)
                return current.withUpdatedChatsToRemove(updatedChatsToRemove).withUpdatedSelecting(false).withUpdatedSearching(false)
            }
        }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    
    let selectPeer: (PeerId) -> Void = { peerId in
        updateState { current in
            if !current.selectedPeerIds.isEmpty {
                let configuredPeerIds = Set(current.chatsToRemove.map { $0.peerId })
                if configuredPeerIds.contains(peerId) != configuredPeerIds.contains(current.selectedPeerIds.first!) {
                    clearHighlightImpl?()
                    return current
                }
            }
            
            var updatedSelectedPeerIds = current.selectedPeerIds
            if current.selectedPeerIds.contains(peerId) {
                updatedSelectedPeerIds.remove(peerId)
            } else {
                updatedSelectedPeerIds.insert(peerId)
            }
            return current.withUpdatedSelectedPeerIds(updatedSelectedPeerIds)
        }
    }
    
    let arguments = ChatsToRemoveControllerArguments(context: context, action: { peer in
        if stateValue.with({ $0.selecting }) {
            selectPeer(peer.id)
        } else {
            clearHighlightImpl?()
            presentPeerSettings([peer.id])
        }
    }, updateRevealedPeerId: { peerId in
        updateState { current in
            return current.withUpdatedRevealedPeerId(peerId)
        }
    }, removePeer: { peer in
        updateState { current in
            var updatedChatsToRemove = current.chatsToRemove
            updatedChatsToRemove.removeAll(where: { $0.peerId == peer.id })
            updatedSettings(updatedChatsToRemove)
            return current.withUpdatedChatsToRemove(updatedChatsToRemove)
        }
    })
    
    let configuredPeersSignal = statePromise.get()
    |> mapToSignal { state in
        return context.account.postbox.transaction { transaction -> [PeerId: RenderedPeer] in
            var peers: [PeerId: RenderedPeer] = [:]
            for peerId in state.chatsToRemove.map({ $0.peerId }) {
                if let peer = transaction.getPeer(peerId) {
                    if let associatedPeerId = peer.associatedPeerId {
                        if let associatedPeer = transaction.getPeer(associatedPeerId) {
                            peers[peerId] = RenderedPeer(peerId: peerId, peers: SimpleDictionary([peer.id: peer, associatedPeer.id: associatedPeer]))
                        }
                    } else {
                        peers[peerId] = RenderedPeer(peer: peer)
                    }
                }
            }
            return peers
        }
    }
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), ptgAllChats(account: context.account), configuredPeersSignal)
    |> deliverOnMainQueue
    |> map { presentationData, state, allChats, configuredPeers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries = chatsToRemoveEntries(presentationData: presentationData, state: state, peerEntries: allChats, configuredPeers: configuredPeers)
        
        let leftNavigationButton: ItemListNavigationButton?
        let rightNavigationButton: ItemListNavigationButton?
        if state.selecting {
            leftNavigationButton = ItemListNavigationButton(content: .none, style: .regular, enabled: false, action: {})
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                updateState { value in
                    return value.withUpdatedSelecting(false)
                }
            })
        } else {
            leftNavigationButton = nil
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Select), style: .regular, enabled: !entries.isEmpty, action: {
                updateState { value in
                    return value.withUpdatedSelecting(true)
                }
            })
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        
        let searchItem = ChatsToRemoveSearchItem(context: context, placeholder: presentationData.strings.Common_Search, activated: state.searching, updateActivated: { value in
            updateState { state in
                return state.withUpdatedSearching(value)
            }
        }, setDisplayNavigationBar: { display in
            setDisplayNavigationBarImpl?(display)
        }, searchContentNodeCreated: { node in
            searchContentNode = node
        }, openPeer: { peer in
            presentPeerSettings([peer.id])
        })
        
        searchContentNode?.setIsEnabled(!state.selecting, animated: true)
        
        let emptyStateItem = entries.isEmpty ? ItemListTextEmptyStateItem(text: presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_EmptyListInfo) : nil
        
        var toolbarItem: ItemListToolbarItem?
        
        if state.selecting && !state.selectedPeerIds.isEmpty {
            let editAction = {
                let selectedPeerIds = stateValue.with { $0.selectedPeerIds }
                let _ = (context.account.postbox.transaction { transaction in
                    var peerIndeces: [PeerId: ChatListIndex] = [:]
                    for peerId in selectedPeerIds {
                        if let (_, index) = transaction.getPeerChatListIndex(peerId) {
                            peerIndeces[peerId] = index
                        } else {
                            peerIndeces[peerId] = .absoluteLowerBound
                        }
                    }
                    return selectedPeerIds.sorted { lhs, rhs in
                        return peerIndeces[rhs]! < peerIndeces[lhs]!
                    }
                }
                |> take(1)
                |> deliverOnMainQueue).start(next: { sortedSelectedPeerIds in
                    presentPeerSettings(sortedSelectedPeerIds)
                })
            }
            
            let configuredPeerIds = Set(state.chatsToRemove.map { $0.peerId })
            if configuredPeerIds.contains(state.selectedPeerIds.first!) {
                toolbarItem = ChatsToRemoveToolbarItem(kind: 0, actions: [.init(title: presentationData.strings.Common_Delete, isEnabled: true, action: {
                    let actionSheet = ActionSheetController(presentationData: presentationData)
                    actionSheet.setItemGroups([
                        ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: presentationData.strings.Common_Delete, color: .destructive, action: { [weak actionSheet] in
                                updateState { current in
                                    var updatedChatsToRemove = current.chatsToRemove
                                    updatedChatsToRemove.removeAll(where: { current.selectedPeerIds.contains($0.peerId) })
                                    updatedSettings(updatedChatsToRemove)
                                    return current.withUpdatedChatsToRemove(updatedChatsToRemove).withUpdatedSelecting(false)
                                }
                                actionSheet?.dismissAnimated()
                            })
                        ]),
                        ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])
                    ])
                    presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }), .init(title: presentationData.strings.Common_Edit, isEnabled: true, action: editAction)])
            } else {
                toolbarItem = ChatsToRemoveToolbarItem(kind: 1, actions: [.init(title: "", isEnabled: false, action: {
                }), .init(title: presentationData.strings.Common_Edit, isEnabled: true, action: editAction)])
            }
        }
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, emptyStateItem: emptyStateItem, searchItem: searchItem, toolbarItem: toolbarItem, initialScrollToItem: ListViewScrollToItem(index: 0, position: .top(-navigationBarSearchContentHeight), animated: false, curve: .Default(duration: nil), directionHint: .Up))
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListControllerReactiveToPasscodeSwitch(context: context, state: signal, onPasscodeSwitch: { controller in
        controller.dismiss(animated: false)
    })
    
    controller.scrollToTop = { [weak controller] in
        if let controller = controller {
            if let searchContentNode = searchContentNode {
                searchContentNode.updateExpansionProgress(1.0, animated: true)
            }
            (controller.displayNode as! ItemListControllerNode).scrollToTop()
        }
    }
    
    var previousContentOffset: ListViewVisibleContentOffset?
    
    (controller.displayNode as! ItemListControllerNode).listNode.visibleContentOffsetChanged = { [weak controller] offset in
        if let controller = controller {
            if let searchContentNode = searchContentNode {
                searchContentNode.updateListVisibleContentOffset(offset)
            }
            
            var previousContentOffsetValue: CGFloat?
            if let previousContentOffset = previousContentOffset, case let .known(value) = previousContentOffset {
                previousContentOffsetValue = value
            }
            switch offset {
                case let .known(value):
                    let transition: ContainedViewLayoutTransition
                    if let previousContentOffsetValue = previousContentOffsetValue, value <= 0.0, previousContentOffsetValue > 30.0 {
                        transition = .animated(duration: 0.2, curve: .easeInOut)
                    } else {
                        transition = .immediate
                    }
                    controller.navigationBar?.updateBackgroundAlpha(stateValue.with({ $0.searching }) ? 1.0 : min(30.0, max(0.0, value - 54.0)) / 30.0, transition: transition)
                case .unknown, .none:
                    controller.navigationBar?.updateBackgroundAlpha(1.0, transition: .immediate)
            }
            
            previousContentOffset = offset
        }
    }
    
    (controller.displayNode as! ItemListControllerNode).listNode.didEndScrolling = { [weak controller] _ in
        if let controller = controller, let searchContentNode = searchContentNode {
            let _ = fixNavigationSearchableListNodeScrolling((controller.displayNode as! ItemListControllerNode).listNode, searchNode: searchContentNode)
        }
    }
    
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    
    clearHighlightImpl = { [weak controller] in
        (controller?.displayNode as? ItemListControllerNode)?.listNode.clearHighlightAnimated(true)
    }
    
    setDisplayNavigationBarImpl = { [weak controller] display in
        controller?.setDisplayNavigationBar(display, transition: .animated(duration: 0.5, curve: .spring))
    }
    
    return controller
}

func ptgAllChats(account: Account) -> Signal<[PeerId: (index: ChatListIndex, peer: RenderedPeer)], NoError> {
    return account.postbox.tailChatListView(groupId: .root, count: 1000, summaryComponents: ChatListEntrySummaryComponents())
    |> take(1)
    |> map { view, updateType in
        return view.entries
    }
    |> map { chatListEntries in
        var peerEntries: [PeerId: (index: ChatListIndex, peer: RenderedPeer)] = [:]
        for entry in chatListEntries {
            if case let .MessageEntry(index, _, _, _, _, renderedPeer, _, _, _, _) = entry {
                peerEntries[renderedPeer.peerId] = (index: index, peer: renderedPeer)
            }
        }
        return peerEntries
    }
}

final class ChatsToRemoveSearchItem: ItemListControllerSearch {
    private let context: AccountContext
    private let placeholder: String
    private let activated: Bool
    
    private let updateActivated: (Bool) -> Void
    private let setDisplayNavigationBar: (Bool) -> Void
    private let searchContentNodeCreated: (NavigationBarSearchContentNode) -> Void
    private let openPeer: (EnginePeer) -> Void
    
    init(context: AccountContext, placeholder: String, activated: Bool, updateActivated: @escaping (Bool) -> Void, setDisplayNavigationBar: @escaping (Bool) -> Void, searchContentNodeCreated: @escaping (NavigationBarSearchContentNode) -> Void, openPeer: @escaping (EnginePeer) -> Void) {
        self.context = context
        self.placeholder = placeholder
        self.activated = activated
        self.updateActivated = updateActivated
        self.setDisplayNavigationBar = setDisplayNavigationBar
        self.searchContentNodeCreated = searchContentNodeCreated
        self.openPeer = openPeer
    }
    
    func isEqual(to: ItemListControllerSearch) -> Bool {
        if let to = to as? ChatsToRemoveSearchItem {
            if self.context !== to.context || self.placeholder != to.placeholder || self.activated != to.activated {
                return false
            }
            return true
        } else {
            return false
        }
    }
    
    func titleContentNode(current: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> NavigationBarContentNode & ItemListControllerSearchNavigationContentNode {
        let updateActivated: (Bool) -> Void = self.updateActivated
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        if let current = current as? NavigationBarSearchContentNode {
            current.updateThemeAndPlaceholder(theme: presentationData.theme, placeholder: self.placeholder)
            return current
        } else {
            let searchContentNode = NavigationBarSearchContentNode(theme: presentationData.theme, placeholder: self.placeholder, activate: {
                updateActivated(true)
            })
            searchContentNode.updateExpansionProgress(0.0)
            self.searchContentNodeCreated(searchContentNode)
            return searchContentNode
        }
    }
    
    func node(current: ItemListControllerSearchNode?, titleContentNode: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> ItemListControllerSearchNode {
        let updateActivated: (Bool) -> Void = self.updateActivated
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        if let current = current as? ChatsToRemoveSearchItemNode, let titleContentNode = titleContentNode as? NavigationBarSearchContentNode {
            current.updatePresentationData(presentationData)
            if current.isSearching != self.activated {
                if self.activated {
                    current.activateSearch(placeholderNode: titleContentNode.placeholderNode)
                    self.setDisplayNavigationBar(false)
                } else {
                    self.setDisplayNavigationBar(true)
                    current.deactivateSearch(placeholderNode: titleContentNode.placeholderNode)
                }
            }
            return current
        } else {
            return ChatsToRemoveSearchItemNode(context: self.context, presentationData: presentationData, cancel: {
                updateActivated(false)
            }, openPeer: self.openPeer)
        }
    }
}

private final class ChatsToRemoveSearchItemNode: ItemListControllerSearchNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    private var searchDisplayController: SearchDisplayController?
    
    private let cancel: () -> Void
    private let openPeer: (EnginePeer) -> Void
    
    init(context: AccountContext, presentationData: PresentationData, cancel: @escaping () -> Void, openPeer: @escaping (EnginePeer) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.cancel = cancel
        self.openPeer = openPeer
        
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
        
        let contentNode = ChatListSearchContainerNode(
            context: self.context,
            filter: [.excludeRecent, .doNotSearchMessages],
            groupId: EngineChatList.Group(.root),
            displaySearchFilters: false,
            hasDownloads: false,
            openPeer: { [weak self] peer, _, _ in
                self?.openPeer(peer)
            },
            openDisabledPeer: { [weak self] peer in
                self?.openPeer(peer)
            },
            openRecentPeerOptions: { _ in
            },
            openMessage: { _, _, _ in
            },
            addContact: nil,
            peerContextAction: nil,
            present: { _, _ in
            },
            presentInGlobalOverlay: { _, _ in
            },
            navigationController: nil
        )
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: contentNode, cancel: self.cancel)
        
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

private class ChatsToRemoveToolbarItem: ItemListToolbarItem {
    private let kind: Int32
    
    init(kind: Int32, actions: [Action]) {
        self.kind = kind
        super.init(actions: actions)
    }
    
    override func isEqual(to: ItemListToolbarItem) -> Bool {
        if let other = to as? ChatsToRemoveToolbarItem {
            return self.kind == other.kind
        } else {
            return false
        }
    }
}
