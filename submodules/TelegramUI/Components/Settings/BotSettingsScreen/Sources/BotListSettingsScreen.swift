import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import ItemListPeerItem
import AccountContext

private final class BotListSettingsArguments {
    let context: AccountContext
    let openBot: (EnginePeer.Id) -> Void
    
    init(
        context: AccountContext,
        openBot: @escaping (EnginePeer.Id) -> Void
    ) {
        self.context = context
        self.openBot = openBot
    }
}

private enum BotListSettingsSection: Int32 {
    case botItems
}

private enum BotListSettingsEntry: ItemListNodeEntry {
    case botItem(peer: EnginePeer)
    
    var section: ItemListSectionId {
        switch self {
        case .botItem:
            return BotListSettingsSection.botItems.rawValue
        }
    }
    
    var stableId: EnginePeer.Id {
        switch self {
        case let .botItem(peer):
            return peer.id
        }
    }
    
    static func ==(lhs: BotListSettingsEntry, rhs: BotListSettingsEntry) -> Bool {
        switch lhs {
        case let .botItem(peer):
            if case .botItem(peer) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: BotListSettingsEntry, rhs: BotListSettingsEntry) -> Bool {
        switch lhs {
        case let .botItem(lhsPeer):
            switch rhs {
            case let .botItem(rhsPeer):
                if lhsPeer.compactDisplayTitle != rhsPeer.compactDisplayTitle {
                    return lhsPeer.compactDisplayTitle < rhsPeer.compactDisplayTitle
                }
                return lhsPeer.id < rhsPeer.id
            }
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! BotListSettingsArguments
        switch self {
        case let .botItem(peer):
            return ItemListPeerItem(
                presentationData: presentationData,
                dateTimeFormat: presentationData.dateTimeFormat,
                nameDisplayOrder: presentationData.nameDisplayOrder,
                context: arguments.context,
                peer: peer,
                presence: nil,
                text: .none,
                label: .disclosure(""),
                editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false),
                enabled: true,
                selectable: true,
                sectionId: self.section,
                action: {
                    arguments.openBot(peer.id)
                },
                setPeerIdWithRevealedOptions: { _, _ in
                },
                removePeer: { _ in
                },
                style: .blocks
            )
        }
    }
}

private struct BotListSettingsState: Equatable {
    init() {
    }
}

private func botListSettingsEntries(
    presentationData: PresentationData,
    peers: [EnginePeer]
) -> [BotListSettingsEntry] {
    var entries: [BotListSettingsEntry] = []
    
    for peer in peers {
        entries.append(.botItem(peer: peer))
    }
    entries.sort(by: { $0 < $1 })
    
    return entries
}

public func botListSettingsScreen(context: AccountContext) -> ViewController {
    let initialState = BotListSettingsState()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((BotListSettingsState) -> BotListSettingsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    let _ = updateState

    var pushControllerImpl: ((ViewController) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let arguments = BotListSettingsArguments(
        context: context,
        openBot: { peerId in
            pushControllerImpl?(botSettingsScreen(context: context, peerId: peerId))
        }
    )
    
    let botPeerList: Signal<[EnginePeer], NoError> = context.engine.peers.botsWithBiometricState()
    |> distinctUntilChanged
    |> mapToSignal { peerIds -> Signal<[EnginePeer], NoError> in
        return context.engine.data.subscribe(
            EngineDataList(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
        )
        |> map { peers -> [EnginePeer] in
            return peers.compactMap { $0 }
        }
    }
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get(),
        botPeerList
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, botPeerList -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Settings_BotListSettings), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: botListSettingsEntries(presentationData: presentationData, peers: botPeerList), style: .blocks, animateChanges: true)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c, animated: true)
    }
    
    return controller
}
