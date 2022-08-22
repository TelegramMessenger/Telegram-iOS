import Foundation
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import AccountContext
import FakePasscode

private final class CloudballonSettingsControllerArguments {
    let switchShowPeerId: (Bool) -> Void
    
    init(switchShowPeerId: @escaping (Bool) -> Void) {
        self.switchShowPeerId = switchShowPeerId
    }
}

private enum CloudballonSettingsSection: Int32 {
    case settings
}

private enum CloudballonSettingsEntry: ItemListNodeEntry {
    case showPeerId(String, Bool)
    case showPeerIdInfo(String)
    
    var section: ItemListSectionId {
        switch self {
        case .showPeerId, .showPeerIdInfo:
            return CloudballonSettingsSection.settings.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .showPeerId:
            return 0
        case .showPeerIdInfo:
            return 1
        }
    }
    
    static func <(lhs: CloudballonSettingsEntry, rhs: CloudballonSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! CloudballonSettingsControllerArguments
        switch self {
        case let .showPeerId(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchShowPeerId(updatedValue)
            })
        case let .showPeerIdInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct CloudballonSettingsState: Equatable {
    let settings: CloudballonSettings

    func withUpdatedSettings(_ settings: CloudballonSettings) -> CloudballonSettingsState {
        return CloudballonSettingsState(settings: settings)
    }
}

private func cloudballonSettingsControllerEntries(presentationData: PresentationData, settings: CloudballonSettings) -> [CloudballonSettingsEntry] {
    var entries: [CloudballonSettingsEntry] = []
    
    entries.append(.showPeerId(presentationData.strings.CloudballonSettings_ShowPeerId, settings.showPeerId))
    entries.append(.showPeerIdInfo(presentationData.strings.CloudballonSettings_ShowPeerIdHelp))
    
    return entries
}

public func cloudballonSettingsController(context: AccountContext) -> ViewController {
    let statePromise = Promise<CloudballonSettingsState>()
    statePromise.set(context.sharedContext.accountManager.transaction { transaction in
        return CloudballonSettingsState(settings: CloudballonSettings(transaction))
    })
    
    let arguments = CloudballonSettingsControllerArguments(switchShowPeerId: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdatedShowPeerId(value)
        }
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.CloudballonSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: cloudballonSettingsControllerEntries(presentationData: presentationData, settings: state.settings), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    return controller
}

private func updateSettings(_ context: AccountContext, _ statePromise: Promise<CloudballonSettingsState>, _ f: @escaping (CloudballonSettings) -> CloudballonSettings) {
    let _ = (statePromise.get() |> take(1)).start(next: { [weak statePromise] data in
        let updatedSettings = f(data.settings)
        statePromise?.set(.single(data.withUpdatedSettings(updatedSettings)))
        let _ = updateCloudballonSettingsInteractively(accountManager: context.sharedContext.accountManager, { _ in
            return updatedSettings
        }).start()
    })
}
