import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import TelegramUIPreferences
import ItemListPeerItem
import ItemListPeerActionItem

private final class ChatListFilterPresetControllerArguments {
    let context: AccountContext
    let updateState: ((ChatListFilterPresetControllerState) -> ChatListFilterPresetControllerState) -> Void
    let openAddPeer: () -> Void
    let deleteAdditionalPeer: (PeerId) -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    
    init(context: AccountContext, updateState: @escaping ((ChatListFilterPresetControllerState) -> ChatListFilterPresetControllerState) -> Void, openAddPeer: @escaping () -> Void, deleteAdditionalPeer: @escaping (PeerId) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void) {
        self.context = context
        self.updateState = updateState
        self.openAddPeer = openAddPeer
        self.deleteAdditionalPeer = deleteAdditionalPeer
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
    }
}

private enum ChatListFilterPresetControllerSection: Int32 {
    case name
    case categories
    case excludeCategories
    case additionalPeers
}

private func filterEntry(presentationData: ItemListPresentationData, arguments: ChatListFilterPresetControllerArguments, title: String, value: Bool, filter: ChatListIncludeCategoryFilter, section: Int32) -> ItemListCheckboxItem {
    return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: section, action: {
        arguments.updateState { current in
            var state = current
            if state.includeCategories.contains(filter) {
                state.includeCategories.remove(filter)
            } else {
                state.includeCategories.insert(filter)
            }
            return state
        }
    })
}

private enum ChatListFilterPresetEntryStableId: Hashable {
    case index(Int)
    case peer(PeerId)
    case additionalPeerInfo
}

private enum ChatListFilterPresetEntry: ItemListNodeEntry {
    case nameHeader(String)
    case name(placeholder: String, value: String)
    case filterPrivateChats(title: String, value: Bool)
    case filterSecretChats(title: String, value: Bool)
    case filterPrivateGroups(title: String, value: Bool)
    case filterBots(title: String, value: Bool)
    case filterPublicGroups(title: String, value: Bool)
    case filterChannels(title: String, value: Bool)
    case filterMuted(title: String, value: Bool)
    case filterRead(title: String, value: Bool)
    case additionalPeersHeader(String)
    case addAdditionalPeer(title: String)
    case additionalPeer(index: Int, peer: RenderedPeer, isRevealed: Bool)
    case additionalPeerInfo(String)
    
    var section: ItemListSectionId {
        switch self {
        case .nameHeader, .name:
            return ChatListFilterPresetControllerSection.name.rawValue
        case .filterPrivateChats, .filterSecretChats, .filterPrivateGroups, .filterBots, .filterPublicGroups, .filterChannels:
            return ChatListFilterPresetControllerSection.categories.rawValue
        case .filterMuted, .filterRead:
            return ChatListFilterPresetControllerSection.excludeCategories.rawValue
        case .additionalPeersHeader, .addAdditionalPeer, .additionalPeer, .additionalPeerInfo:
            return ChatListFilterPresetControllerSection.additionalPeers.rawValue
        }
    }
    
    var stableId: ChatListFilterPresetEntryStableId {
        switch self {
        case .nameHeader:
            return .index(0)
        case .name:
            return .index(1)
        case .filterPrivateChats:
            return .index(2)
        case .filterSecretChats:
            return .index(3)
        case .filterPrivateGroups:
            return .index(4)
        case .filterBots:
            return .index(5)
        case .filterPublicGroups:
            return .index(6)
        case .filterChannels:
            return .index(7)
        case .filterMuted:
            return .index(8)
        case .filterRead:
            return .index(9)
        case .additionalPeersHeader:
            return .index(10)
        case .addAdditionalPeer:
            return .index(11)
        case let .additionalPeer(additionalPeer):
            return .peer(additionalPeer.peer.peerId)
        case .additionalPeerInfo:
            return .additionalPeerInfo
        }
    }
    
    static func <(lhs: ChatListFilterPresetEntry, rhs: ChatListFilterPresetEntry) -> Bool {
        switch lhs.stableId {
        case let .index(lhsIndex):
            switch rhs.stableId {
            case let .index(rhsIndex):
                return lhsIndex < rhsIndex
            case .peer:
                return true
            case .additionalPeerInfo:
                return true
            }
        case .peer:
            switch lhs {
            case let .additionalPeer(lhsIndex, _, _):
                switch rhs.stableId {
                case .index:
                    return false
                case .additionalPeerInfo:
                    return true
                case .peer:
                    switch rhs {
                    case let .additionalPeer(rhsIndex, _, _):
                        return lhsIndex < rhsIndex
                    default:
                        preconditionFailure()
                    }
                }
            default:
                preconditionFailure()
            }
        case .additionalPeerInfo:
            switch rhs.stableId {
            case .index:
                return false
            case .peer:
                return false
            case .additionalPeerInfo:
                return false
            }
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChatListFilterPresetControllerArguments
        switch self {
        case let .nameHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .name(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: value, placeholder: placeholder, type: .regular(capitalization: true, autocorrection: false), sectionId: self.section, textUpdated: { value in
                arguments.updateState { current in
                    var state = current
                    state.name = value
                    return state
                }
            }, action: {})
        case let .filterPrivateChats(title, value):
            return filterEntry(presentationData: presentationData, arguments: arguments, title: title, value: value, filter: .privateChats, section: self.section)
        case let .filterSecretChats(title, value):
            return filterEntry(presentationData: presentationData, arguments: arguments, title: title, value: value, filter: .secretChats, section: self.section)
        case let .filterPrivateGroups(title, value):
            return filterEntry(presentationData: presentationData, arguments: arguments, title: title, value: value, filter: .privateGroups, section: self.section)
        case let .filterBots(title, value):
            return filterEntry(presentationData: presentationData, arguments: arguments, title: title, value: value, filter: .bots, section: self.section)
        case let .filterPublicGroups(title, value):
            return filterEntry(presentationData: presentationData, arguments: arguments, title: title, value: value, filter: .publicGroups, section: self.section)
        case let .filterChannels(title, value):
            return filterEntry(presentationData: presentationData, arguments: arguments, title: title, value: value, filter: .channels, section: self.section)
        case let .filterMuted(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { _ in
                arguments.updateState { current in
                    var state = current
                    if state.includeCategories.contains(.muted) {
                        state.includeCategories.remove(.muted)
                    } else {
                        state.includeCategories.insert(.muted)
                    }
                    return state
                }
            })
        case let .filterRead(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { _ in
                arguments.updateState { current in
                    var state = current
                    if state.includeCategories.contains(.read) {
                        state.includeCategories.remove(.read)
                    } else {
                        state.includeCategories.insert(.read)
                    }
                    return state
                }
            })
        case let .additionalPeersHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .addAdditionalPeer(title):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.addPersonIcon(presentationData.theme), title: title, alwaysPlain: false, sectionId: self.section, height: .peerList, editing: false, action: {
                arguments.openAddPeer()
            })
        case let .additionalPeer(title, peer, isRevealed):
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(timeFormat: .regular, dateFormat: .monthFirst, dateSeparator: ".", decimalSeparator: ".", groupingSeparator: "."), nameDisplayOrder: .firstLast, context: arguments.context, peer: peer.chatMainPeer!, height: .peerList, presence: nil, text: .none, label: .none, editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: isRevealed), revealOptions: ItemListPeerItemRevealOptions(options: [ItemListPeerItemRevealOption(type: .destructive, title: presentationData.strings.Common_Delete, action: {
                arguments.deleteAdditionalPeer(peer.peerId)
            })]), switchValue: nil, enabled: true, selectable: false, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { lhs, rhs in
                arguments.setPeerIdWithRevealedOptions(lhs, rhs)
            }, removePeer: { id in
                arguments.deleteAdditionalPeer(id)
            })
        case let .additionalPeerInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct ChatListFilterPresetControllerState: Equatable {
    var name: String
    var includeCategories: ChatListIncludeCategoryFilter
    var additionallyIncludePeers: [PeerId]
    
    var revealedPeerId: PeerId?
    
    var isComplete: Bool {
        if self.name.isEmpty {
            return false
        }
        if self.includeCategories.isEmpty && self.additionallyIncludePeers.isEmpty {
            return false
        }
        return true
    }
}

private func chatListFilterPresetControllerEntries(presentationData: PresentationData, state: ChatListFilterPresetControllerState, peers: [RenderedPeer]) -> [ChatListFilterPresetEntry] {
    var entries: [ChatListFilterPresetEntry] = []
    
    entries.append(.nameHeader("NAME"))
    entries.append(.name(placeholder: "Preset Name", value: state.name))
    
    entries.append(.filterPrivateChats(title: "Private Chats", value: state.includeCategories.contains(.privateChats)))
    entries.append(.filterSecretChats(title: "Secret Chats", value: state.includeCategories.contains(.secretChats)))
    entries.append(.filterPrivateGroups(title: "Private Groups", value: state.includeCategories.contains(.privateGroups)))
    entries.append(.filterBots(title: "Bots", value: state.includeCategories.contains(.bots)))
    entries.append(.filterPublicGroups(title: "Public Groups", value: state.includeCategories.contains(.publicGroups)))
    entries.append(.filterChannels(title: "Channels", value: state.includeCategories.contains(.channels)))
    
    entries.append(.filterMuted(title: "Exclude Muted", value: !state.includeCategories.contains(.muted)))
    entries.append(.filterRead(title: "Exclude Read", value: !state.includeCategories.contains(.read)))
    
    entries.append(.additionalPeersHeader("ALWAYS INCLUDE"))
    entries.append(.addAdditionalPeer(title: "Add"))
    
    for peer in peers {
        entries.append(.additionalPeer(index: entries.count, peer: peer, isRevealed: state.revealedPeerId == peer.peerId))
    }
    
    entries.append(.additionalPeerInfo("These chats will always be included in the list."))
    
    return entries
}

func chatListFilterPresetController(context: AccountContext, currentPreset: ChatListFilterPreset?, updated: @escaping ([ChatListFilterPreset]) -> Void) -> ViewController {
    let initialName: String
    if let currentPreset = currentPreset {
        switch currentPreset.name {
        case .unread:
            initialName = "Unread"
        case let .custom(value):
            initialName = value
        }
    } else {
        initialName = "New Preset"
    }
    let initialState = ChatListFilterPresetControllerState(name: initialName, includeCategories: currentPreset?.includeCategories ?? .all, additionallyIncludePeers: currentPreset?.additionallyIncludePeers ?? [])
    let stateValue = Atomic(value: initialState)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let updateState: ((ChatListFilterPresetControllerState) -> ChatListFilterPresetControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let actionsDisposable = DisposableSet()
    
    let addPeerDisposable = MetaDisposable()
    actionsDisposable.add(addPeerDisposable)
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var dismissImpl: (() -> Void)?
    
    let arguments = ChatListFilterPresetControllerArguments(
        context: context,
        updateState: { f in
            updateState(f)
        },
        openAddPeer: {
            let controller = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .peerSelection(searchChatList: true, searchGroups: true), options: []))
            addPeerDisposable.set((controller.result
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak controller] peerIds in
                controller?.dismiss()
                updateState { state in
                    var state = state
                    for peerId in peerIds {
                        switch peerId {
                        case let .peer(id):
                            if !state.additionallyIncludePeers.contains(id) {
                                state.additionallyIncludePeers.append(id)
                            }
                        default:
                            break
                        }
                    }
                    return state
                }
            }))
            presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        },
        deleteAdditionalPeer: { peerId in
            updateState { state in
                var state = state
                if let index = state.additionallyIncludePeers.index(of: peerId) {
                    state.additionallyIncludePeers.remove(at: index)
                }
                return state
            }
        },
        setPeerIdWithRevealedOptions: { peerId, fromPeerId in
            updateState { state in
                var state = state
                if (peerId == nil && fromPeerId == state.revealedPeerId) || (peerId != nil && fromPeerId == nil) {
                    state.revealedPeerId = peerId
                }
                return state
            }
        }
    )
    
    let statePeers = statePromise.get()
    |> map { state -> [PeerId] in
        return state.additionallyIncludePeers
    }
    |> distinctUntilChanged
    |> mapToSignal { peerIds -> Signal<[RenderedPeer], NoError> in
        return context.account.postbox.transaction { transaction -> [RenderedPeer] in
            var result: [RenderedPeer] = []
            for peerId in peerIds {
                if let peer = transaction.getPeer(peerId) {
                    result.append(RenderedPeer(peer: peer))
                }
            }
            return result
        }
    }
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get(),
        statePeers
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, statePeers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: state.isComplete, action: {
            let state = stateValue.with { $0 }
            let preset = ChatListFilterPreset(id: currentPreset?.id ?? arc4random64(), name: .custom(state.name), includeCategories: state.includeCategories, additionallyIncludePeers: state.additionallyIncludePeers)
            let _ = (updateChatListFilterSettingsInteractively(postbox: context.account.postbox, { settings in
                var settings = settings
                settings.presets = settings.presets.filter { $0 != preset && $0 != currentPreset }
                settings.presets.append(preset)
                return settings
            })
            |> deliverOnMainQueue).start(next: { settings in
                updated(settings.presets)
                dismissImpl?()
            })
        })
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.SocksProxySetup_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: chatListFilterPresetControllerEntries(presentationData: presentationData, state: state, peers: statePeers), style: .blocks, emptyStateItem: nil, animateChanges: true)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    presentControllerImpl = { [weak controller] c, d in
        controller?.present(c, in: .window(.root), with: d)
    }
    dismissImpl = { [weak controller] in
        let _ = controller?.dismiss()
    }
    
    return controller
}

