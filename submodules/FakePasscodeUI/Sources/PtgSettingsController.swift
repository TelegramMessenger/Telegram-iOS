import Foundation
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import AccountContext
import Postbox
import TelegramCore
import TelegramUIPreferences
import PtgSettings

private final class PtgSettingsControllerArguments {
    let switchShowPeerId: (Bool) -> Void
    let switchSuppressForeignAgentNotice: (Bool) -> Void
    let switchEnableForeignAgentNoticeSearchFiltering: (Bool) -> Void
    let switchEnableLiveText: (Bool) -> Void
    
    init(switchShowPeerId: @escaping (Bool) -> Void, switchSuppressForeignAgentNotice: @escaping (Bool) -> Void, switchEnableForeignAgentNoticeSearchFiltering: @escaping (Bool) -> Void, switchEnableLiveText: @escaping (Bool) -> Void) {
        self.switchShowPeerId = switchShowPeerId
        self.switchSuppressForeignAgentNotice = switchSuppressForeignAgentNotice
        self.switchEnableForeignAgentNoticeSearchFiltering = switchEnableForeignAgentNoticeSearchFiltering
        self.switchEnableLiveText = switchEnableLiveText
    }
}

private enum PtgSettingsSection: Int32 {
    case showPeerId
    case foreignAgentNotice
    case liveText
}

private enum PtgSettingsEntry: ItemListNodeEntry {
    case showPeerId(String, Bool)
    case showPeerIdInfo(String)
    
    case foreignAgentNoticeHeader(String)
    case suppressForeignAgentNotice(String, Bool)
    case enableForeignAgentNoticeSearchFiltering(String, Bool, Bool)
    case enableForeignAgentNoticeSearchFilteringInfo(String)

    case enableLiveText(String, Bool)
    case enableLiveTextInfo(String)

    var section: ItemListSectionId {
        switch self {
        case .showPeerId, .showPeerIdInfo:
            return PtgSettingsSection.showPeerId.rawValue
        case .foreignAgentNoticeHeader, .suppressForeignAgentNotice, .enableForeignAgentNoticeSearchFiltering, .enableForeignAgentNoticeSearchFilteringInfo:
            return PtgSettingsSection.foreignAgentNotice.rawValue
        case .enableLiveText, .enableLiveTextInfo:
            return PtgSettingsSection.liveText.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .showPeerId:
            return 0
        case .showPeerIdInfo:
            return 1
        case .foreignAgentNoticeHeader:
            return 2
        case .suppressForeignAgentNotice:
            return 3
        case .enableForeignAgentNoticeSearchFiltering:
            return 4
        case .enableForeignAgentNoticeSearchFilteringInfo:
            return 5
        case .enableLiveText:
            return 6
        case .enableLiveTextInfo:
            return 7
        }
    }
    
    static func <(lhs: PtgSettingsEntry, rhs: PtgSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PtgSettingsControllerArguments
        switch self {
        case let .showPeerId(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchShowPeerId(updatedValue)
            })
        case let .foreignAgentNoticeHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .suppressForeignAgentNotice(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchSuppressForeignAgentNotice(updatedValue)
            })
        case let .enableForeignAgentNoticeSearchFiltering(title, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchEnableForeignAgentNoticeSearchFiltering(updatedValue)
            })
        case let .enableLiveText(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchEnableLiveText(updatedValue)
            })
        case let .showPeerIdInfo(text), let .enableForeignAgentNoticeSearchFilteringInfo(text), let .enableLiveTextInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct PtgSettingsState: Equatable {
    let settings: PtgSettings

    func withUpdatedSettings(_ settings: PtgSettings) -> PtgSettingsState {
        return PtgSettingsState(settings: settings)
    }
}

private func ptgSettingsControllerEntries(presentationData: PresentationData, settings: PtgSettings) -> [PtgSettingsEntry] {
    var entries: [PtgSettingsEntry] = []
    
    entries.append(.showPeerId(presentationData.strings.PtgSettings_ShowPeerId, settings.showPeerId))
    entries.append(.showPeerIdInfo(presentationData.strings.PtgSettings_ShowPeerIdHelp))
    
    entries.append(.foreignAgentNoticeHeader(presentationData.strings.PtgSettings_ForeignAgentNoticeHeader.uppercased()))
    entries.append(.suppressForeignAgentNotice(presentationData.strings.PtgSettings_SuppressForeignAgentNotice, settings.suppressForeignAgentNotice))
    entries.append(.enableForeignAgentNoticeSearchFiltering(presentationData.strings.PtgSettings_EnableForeignAgentNoticeSearchFiltering, settings.enableForeignAgentNoticeSearchFiltering, settings.suppressForeignAgentNotice))
    entries.append(.enableForeignAgentNoticeSearchFilteringInfo(presentationData.strings.PtgSettings_EnableForeignAgentNoticeSearchFilteringHelp))

    if #available(iOS 11.0, *) {
        entries.append(.enableLiveText(presentationData.strings.PtgSettings_EnableLiveText, settings.enableLiveText))
        entries.append(.enableLiveTextInfo(presentationData.strings.PtgSettings_EnableLiveTextHelp))
    }

    return entries
}

public func ptgSettingsController(context: AccountContext) -> ViewController {
    let statePromise = Promise<PtgSettingsState>()
    statePromise.set(context.sharedContext.accountManager.transaction { transaction in
        return PtgSettingsState(settings: PtgSettings(transaction))
    })
    
    let arguments = PtgSettingsControllerArguments(switchShowPeerId: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(showPeerId: value)
        }
    }, switchSuppressForeignAgentNotice: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(suppressForeignAgentNotice: value)
        }
    }, switchEnableForeignAgentNoticeSearchFiltering: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(enableForeignAgentNoticeSearchFiltering: value)
        }
    }, switchEnableLiveText: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(enableLiveText: value)
        }
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.PtgSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ptgSettingsControllerEntries(presentationData: presentationData, settings: state.settings), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    return controller
}

private func updateSettings(_ context: AccountContext, _ statePromise: Promise<PtgSettingsState>, _ f: @escaping (PtgSettings) -> PtgSettings) {
    let _ = (statePromise.get() |> take(1)).start(next: { [weak statePromise] state in
        let updatedSettings = f(state.settings)
        statePromise?.set(.single(state.withUpdatedSettings(updatedSettings)))
        
        let _ = context.sharedContext.accountManager.transaction({ transaction -> Void in
            transaction.updateSharedData(ApplicationSpecificSharedDataKeys.ptgSettings, { _ in
                return PreferencesEntry(updatedSettings)
            })
        }).start()
    })
}
