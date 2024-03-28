import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext

private final class BotSettingsArguments {
    let context: AccountContext
    let updateBiometryAccess: (Bool) -> Void
    
    init(
        context: AccountContext,
        updateBiometryAccess: @escaping (Bool) -> Void
    ) {
        self.context = context
        self.updateBiometryAccess = updateBiometryAccess
    }
}

private enum BotSettingsSection: Int32 {
    case settings
}

private enum BotSettingsEntry: ItemListNodeEntry {
    case biometryAccess(value: Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .biometryAccess:
            return BotSettingsSection.settings.rawValue
        }
    }
    
    var stableId: Int {
        switch self {
        case .biometryAccess:
            return 0
        }
    }
    
    static func ==(lhs: BotSettingsEntry, rhs: BotSettingsEntry) -> Bool {
        switch lhs {
        case let .biometryAccess(value):
            if case .biometryAccess(value) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: BotSettingsEntry, rhs: BotSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! BotSettingsArguments
        switch self {
        case let .biometryAccess(value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: presentationData.strings.Settings_BotSettings_Biometry,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.updateBiometryAccess(value)
                }
            )
        }
    }
}

private struct BotSettingsState: Equatable {
    init() {
    }
}

private func botSettingsEntries(
    presentationData: PresentationData,
    peer: EnginePeer?,
    biometricsState: TelegramBotBiometricsState?
) -> [BotSettingsEntry] {
    var entries: [BotSettingsEntry] = []
    
    if let biometricsState {
        entries.append(.biometryAccess(value: biometricsState.accessGranted))
    }
    
    return entries
}

public func botSettingsScreen(context: AccountContext, peerId: EnginePeer.Id) -> ViewController {
    let initialState = BotSettingsState()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((BotSettingsState) -> BotSettingsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var pushControllerImpl: ((ViewController) -> Void)?
    let _ = pushControllerImpl
    let _ = updateState
    
    let actionsDisposable = DisposableSet()
    
    let arguments = BotSettingsArguments(
        context: context,
        updateBiometryAccess: { value in
            context.engine.peers.updateBotBiometricsState(peerId: peerId, update: { state in
                var state = state ?? TelegramBotBiometricsState.create()
                state.accessGranted = value
                return state
            })
        }
    )
        
    let data = context.engine.data.subscribe(
        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
        TelegramEngine.EngineData.Item.Peer.BotBiometricsState(id: peerId)
    )
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get(),
        data
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, data -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let (peer, biometricsState) = data
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(peer?.compactDisplayTitle ?? ""), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: botSettingsEntries(presentationData: presentationData, peer: peer, biometricsState: biometricsState), style: .blocks, animateChanges: true)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    
    return controller
}
