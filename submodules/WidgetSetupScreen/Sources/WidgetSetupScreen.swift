import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import ItemListPeerItem
import ItemListPeerActionItem

private final class Arguments {
    let context: AccountContext
    
    let updateUseHints: (Bool) -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let removePeer: (PeerId) -> Void
    let addPeer: () -> Void
    let openPeer: (PeerId) -> Void
    
    init(context: AccountContext, updateUseHints: @escaping (Bool) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, removePeer: @escaping (PeerId) -> Void, addPeer: @escaping () -> Void, openPeer: @escaping (PeerId) -> Void) {
        self.context = context
        self.updateUseHints = updateUseHints
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removePeer = removePeer
        self.addPeer = addPeer
        self.openPeer = openPeer
    }
}

private enum WidgetSetupScreenEntry: ItemListNodeEntry {
    enum Section: Int32 {
        case mode
        case peers
    }
    
    enum StableId: Hashable {
        case useHints
        case peersHeaderItem
        case add
        case peer(PeerId)
    }
    
    case useHints(String, Bool)
    case peersHeaderItem(String)
    case peerItem(Int32, PresentationDateTimeFormat, PresentationPersonNameOrder, SelectivePrivacyPeer, ItemListPeerItemEditing, Bool)
    case addItem(String, Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .useHints:
            return Section.mode.rawValue
        case .peersHeaderItem, .peerItem:
            return Section.peers.rawValue
        case .addItem:
            return Section.peers.rawValue
        }
    }
    
    var stableId: StableId {
        switch self {
        case .useHints:
            return .useHints
        case .peersHeaderItem:
            return .peersHeaderItem
        case let .peerItem(_, _, _, peer, _, _):
            return .peer(peer.peer.id)
        case .addItem:
            return .add
        }
    }
    
    var sortIndex: Int32 {
        switch self {
        case .useHints:
            return 0
        case .peersHeaderItem:
            return 1
        case .addItem:
            return 2
        case let .peerItem(index, _, _, _, _, _):
            return 10 + index
        }
    }
    
    static func ==(lhs: WidgetSetupScreenEntry, rhs: WidgetSetupScreenEntry) -> Bool {
        switch lhs {
        case let .useHints(text, value):
            if case .useHints(text, value) = rhs {
                return true
            } else {
                return false
            }
        case let .peersHeaderItem(text):
            if case .peersHeaderItem(text) = rhs {
                return true
            } else {
                return false
            }
        case let .peerItem(lhsIndex, lhsDateTimeFormat, lhsNameOrder, lhsPeer, lhsEditing, lhsEnabled):
            if case let .peerItem(rhsIndex, rhsDateTimeFormat, rhsNameOrder, rhsPeer, rhsEditing, rhsEnabled) = rhs {
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsDateTimeFormat != rhsDateTimeFormat {
                    return false
                }
                if lhsNameOrder != rhsNameOrder {
                    return false
                }
                if lhsPeer != rhsPeer {
                    return false
                }
                if lhsEditing != rhsEditing {
                    return false
                }
                if lhsEnabled != rhsEnabled {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .addItem(lhsText, lhsEditing):
            if case let .addItem(rhsText, rhsEditing) = rhs, lhsText == rhsText, lhsEditing == rhsEditing {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: WidgetSetupScreenEntry, rhs: WidgetSetupScreenEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! Arguments
        switch self {
            case let .useHints(text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updateUseHints(value)
                })
            case let .peersHeaderItem(text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .peerItem(_, dateTimeFormat, nameOrder, peer, editing, enabled):
                var text: ItemListPeerItemText = .none
                if let group = peer.peer as? TelegramGroup {
                    text = .text(presentationData.strings.Conversation_StatusMembers(Int32(group.participantCount)), .secondary)
                } else if let channel = peer.peer as? TelegramChannel {
                    if let participantCount = peer.participantCount {
                        text = .text(presentationData.strings.Conversation_StatusMembers(Int32(participantCount)), .secondary)
                    } else {
                        switch channel.info {
                            case .group:
                                text = .text(presentationData.strings.Group_Status, .secondary)
                            case .broadcast:
                                text = .text(presentationData.strings.Channel_Status, .secondary)
                        }
                    }
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameOrder, context: arguments.context, peer: peer.peer, presence: nil, text: text, label: .none, editing: editing, switchValue: nil, enabled: enabled, selectable: true, sectionId: self.section, action: {
                    arguments.openPeer(peer.peer.id)
                }, setPeerIdWithRevealedOptions: { previousId, id in
                    arguments.setPeerIdWithRevealedOptions(previousId, id)
                }, removePeer: { peerId in
                    arguments.removePeer(peerId)
                })
            case let .addItem(text, editing):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.plusIconImage(presentationData.theme), title: text, sectionId: self.section, editing: editing, action: {
                    arguments.addPeer()
                })
        }
    }
}

private struct WidgetSetupScreenControllerState: Equatable {
    var editing: Bool = false
    var peerIdWithRevealedOptions: PeerId? = nil
}

private func selectivePrivacyPeersControllerEntries(presentationData: PresentationData, state: WidgetSetupScreenControllerState, useHints: Bool, peers: [SelectivePrivacyPeer]) -> [WidgetSetupScreenEntry] {
    var entries: [WidgetSetupScreenEntry] = []
    
    entries.append(.useHints("Show Recent Chats", useHints))
    
    if !useHints {
        entries.append(.peersHeaderItem(presentationData.strings.Privacy_ChatsTitle))
        entries.append(.addItem(presentationData.strings.Privacy_AddNewPeer, state.editing))
        var index: Int32 = 0
        for peer in peers {
            entries.append(.peerItem(index, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, peer, ItemListPeerItemEditing(editable: true, editing: state.editing, canBeReordered: state.editing, revealed: peer.peer.id == state.peerIdWithRevealedOptions), true))
            index += 1
        }
    }
    
    return entries
}

public func widgetSetupScreen(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(WidgetSetupScreenControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: WidgetSetupScreenControllerState())
    let updateState: ((WidgetSetupScreenControllerState) -> WidgetSetupScreenControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let actionsDisposable = DisposableSet()
    let addPeerDisposable = MetaDisposable()
    actionsDisposable.add(addPeerDisposable)
    
    let arguments = Arguments(context: context, updateUseHints: { value in
        let _ = (updateWidgetSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            settings.useHints = value
            return settings
        })
        |> deliverOnMainQueue).start()
    }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            var state = state
            if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                state.peerIdWithRevealedOptions = peerId
            }
            return state
        }
    }, removePeer: { memberId in
        let _ = (updateWidgetSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            settings.peers.removeAll(where: { $0 == memberId })
            return settings
        })
        |> deliverOnMainQueue).start()
    }, addPeer: {
        let controller = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .peerSelection(searchChatList: true, searchGroups: true, searchChannels: false), options: []))
        addPeerDisposable.set((controller.result
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak controller] result in
            var peerIds: [ContactListPeerId] = []
            if case let .result(peerIdsValue, _) = result {
                peerIds = peerIdsValue
            }
            
            let _ = (updateWidgetSettingsInteractively(postbox: context.account.postbox, { settings in
                var settings = settings
                for peerId in peerIds {
                    switch peerId {
                    case let .peer(peerId):
                        settings.peers.removeAll(where: { $0 == peerId })
                        settings.peers.insert(peerId, at: 0)
                    case .deviceContact:
                        break
                    }
                }
                return settings
            })
            |> deliverOnMainQueue).start(completed: {
                controller?.dismiss()
            })
        }))
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, openPeer: { peerId in
        let _ = (context.account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(peerId)
        }
        |> deliverOnMainQueue).start(next: { peer in
            guard let peer = peer, let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false) else {
                return
            }
            pushControllerImpl?(controller)
        })
    })
    
    var previousPeers: [SelectivePrivacyPeer]?
    var previousState: WidgetSetupScreenControllerState?
    
    struct InputData {
        var settings: WidgetSettings
        var peers: [SelectivePrivacyPeer]
    }
    
    let preferencesKey: PostboxViewKey = .preferences(keys: Set([
        ApplicationSpecificPreferencesKeys.widgetSettings
    ]))
    
    let inputData: Signal<InputData, NoError> = context.account.postbox.combinedView(keys: [
        preferencesKey
    ])
    |> mapToSignal { views -> Signal<InputData, NoError> in
        let widgetSettings: WidgetSettings
        if let view = views.views[preferencesKey] as? PreferencesView, let value = view.values[ApplicationSpecificPreferencesKeys.widgetSettings] as? WidgetSettings {
            widgetSettings = value
        } else {
            widgetSettings = .default
        }
        
        return context.account.postbox.transaction { transaction -> InputData in
            return InputData(
                settings: widgetSettings,
                peers: widgetSettings.peers.compactMap { peerId -> SelectivePrivacyPeer? in
                    guard let peer = transaction.getPeer(peerId) else {
                        return nil
                    }
                    return SelectivePrivacyPeer(peer: peer, participantCount: nil)
                }
            )
        }
    }
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), inputData)
    |> deliverOnMainQueue
    |> map { presentationData, state, inputData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var rightNavigationButton: ItemListNavigationButton?
        if !inputData.peers.isEmpty {
            if state.editing {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                    updateState { state in
                        var state = state
                        state.editing = false
                        return state
                    }
                })
            } else {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                    updateState { state in
                        var state = state
                        state.editing = true
                        return state
                    }
                })
            }
        }
        
        let previous = previousPeers
        previousPeers = inputData.peers
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Widget"), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        
        var animated = true
        if let previous = previous {
            if previous.count <= inputData.peers.count {
                if Set(previous.map { $0.peer.id }) == Set(inputData.peers.map { $0.peer.id }) && previous.map({ $0.peer.id }) != inputData.peers.map({ $0.peer.id }) {
                } else {
                    animated = false
                }
            }
        } else {
            animated = false
        }
        if let previousState = previousState {
            if previousState.editing != state.editing {
                animated = true
            }
        } else {
            animated = false
        }
        
        previousState = state
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: selectivePrivacyPeersControllerEntries(presentationData: presentationData, state: state, useHints: inputData.settings.useHints, peers: inputData.peers), style: .blocks, emptyStateItem: nil, animateChanges: animated)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    pushControllerImpl = { [weak controller] c in
        if let navigationController = controller?.navigationController as? NavigationController {
            navigationController.pushViewController(c)
        }
    }
    
    controller.setReorderEntry({ (fromIndex: Int, toIndex: Int, entries: [WidgetSetupScreenEntry]) -> Signal<Bool, NoError> in
        let fromEntry = entries[fromIndex]
        guard case let .peerItem(_, _, _, fromPeer, _, _) = fromEntry else {
            return .single(false)
        }
        var referencePeerId: PeerId?
        var beforeAll = false
        var afterAll = false
        if toIndex < entries.count {
            switch entries[toIndex] {
            case let .peerItem(_, _, _, peer, _, _):
                referencePeerId = peer.peer.id
            default:
                if entries[toIndex] < fromEntry {
                    beforeAll = true
                } else {
                    afterAll = true
                }
            }
        } else {
            afterAll = true
        }
        
        return context.account.postbox.transaction { transaction -> Bool in
            var updatedOrder = false
            
            updateWidgetSettingsInteractively(transaction: transaction, { settings in
                let initialPeers = settings.peers
                var settings = settings
                
                if let index = settings.peers.firstIndex(of: fromPeer.peer.id) {
                    settings.peers.remove(at: index)
                }
                if let referencePeerId = referencePeerId {
                    var inserted = false
                    for i in 0 ..< settings.peers.count {
                        if settings.peers[i] == referencePeerId {
                            if fromIndex < toIndex {
                                settings.peers.insert(fromPeer.peer.id, at: i + 1)
                            } else {
                                settings.peers.insert(fromPeer.peer.id, at: i)
                            }
                            inserted = true
                            break
                        }
                    }
                    if !inserted {
                        settings.peers.append(fromPeer.peer.id)
                    }
                } else if beforeAll {
                    settings.peers.insert(fromPeer.peer.id, at: 0)
                } else if afterAll {
                    settings.peers.append(fromPeer.peer.id)
                }
                
                if initialPeers != settings.peers {
                    updatedOrder = true
                }
                return settings
            })
            
            return updatedOrder
        }
    })
    
    return controller
}
