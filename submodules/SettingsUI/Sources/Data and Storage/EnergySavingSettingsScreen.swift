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

enum ItemType: CaseIterable {
    case loopEmoji
    case playVideoAvatars
    case fullTranslucency
    case extendBackgroundWork
    case synchronizeInBackground
    case autodownloadInBackground
    
    var settingsKeyPath: WritableKeyPath<EnergyUsageSettings, Bool> {
        switch self {
        case .loopEmoji:
            return \.loopEmoji
        case .playVideoAvatars:
            return \.playVideoAvatars
        case .fullTranslucency:
            return \.fullTranslucency
        case .extendBackgroundWork:
            return \.extendBackgroundWork
        case .synchronizeInBackground:
            return \.synchronizeInBackground
        case .autodownloadInBackground:
            return \.autodownloadInBackground
        }
    }
    
    func title(strings: PresentationStrings) -> String {
        //TODO:localize
        switch self {
        case .loopEmoji:
            return "Loop Animated Emoji"
        case .playVideoAvatars:
            return "Play Video Avatars"
        case .fullTranslucency:
            return "Translucency Effects"
        case .extendBackgroundWork:
            return "Extended Background Time"
        case .synchronizeInBackground:
            return "Background Sync"
        case .autodownloadInBackground:
            return "Preload Media in Chats"
        }
    }
}

private final class EnergeSavingSettingsScreenArguments {
    let toggleAll: (Bool) -> Void
    let toggleItem: (ItemType) -> Void
    
    init(toggleAll: @escaping (Bool) -> Void, toggleItem: @escaping (ItemType) -> Void) {
        self.toggleAll = toggleAll
        self.toggleItem = toggleItem
    }
}

private enum EnergeSavingSettingsScreenSection: Int32 {
    case all
    case items
}

private enum EnergeSavingSettingsScreenEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case all
        case item(ItemType)
    }
    
    case all(Bool)
    case item(index: Int, type: ItemType, value: Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .all:
            return EnergeSavingSettingsScreenSection.all.rawValue
        case .item:
            return EnergeSavingSettingsScreenSection.items.rawValue
        }
    }
    
    var sortIndex: Int {
        switch self {
        case .all:
            return -1
        case let .item(index, _, _):
            return index
        }
    }
    
    var stableId: StableId {
        switch self {
        case .all:
            return .all
        case let .item(_, type, _):
            return .item(type)
        }
    }
    
    static func <(lhs: EnergeSavingSettingsScreenEntry, rhs: EnergeSavingSettingsScreenEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! EnergeSavingSettingsScreenArguments
        switch self {
        case let .all(value):
            //TODO:localize
            return ItemListSwitchItem(presentationData: presentationData, title: "Enable All", value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleAll(value)
            })
        case let .item(_, type, value):
            return ItemListSwitchItem(presentationData: presentationData, title: type.title(strings: presentationData.strings), value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleItem(type)
            })
        }
    }
}

private func energeSavingSettingsScreenEntries(
    presentationData: PresentationData,
    settings: MediaAutoDownloadSettings
) -> [EnergeSavingSettingsScreenEntry] {
    var entries: [EnergeSavingSettingsScreenEntry] = []
    
    entries.append(.all(ItemType.allCases.allSatisfy({ item in settings.energyUsageSettings[keyPath: item.settingsKeyPath] })))
    
    for type in ItemType.allCases {
        entries.append(.item(index: entries.count, type: type, value: settings.energyUsageSettings[keyPath: type.settingsKeyPath]))
    }
    
    return entries
}

func energySavingSettingsScreen(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    let _ = pushControllerImpl
    
    let arguments = EnergeSavingSettingsScreenArguments(
        toggleAll: { value in
            let _ = updateMediaDownloadSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                var settings = settings
                for type in ItemType.allCases {
                    settings.energyUsageSettings[keyPath: type.settingsKeyPath] = value
                }
                return settings
            }).start()
        },
        toggleItem: { type in
            let _ = updateMediaDownloadSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                var settings = settings
                settings.energyUsageSettings[keyPath: type.settingsKeyPath] = !settings.energyUsageSettings[keyPath: type.settingsKeyPath]
                return settings
            }).start()
        }
    )
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings]))
        |> deliverOnMainQueue
        |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
            var automaticMediaDownloadSettings: MediaAutoDownloadSettings
            if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings]?.get(MediaAutoDownloadSettings.self) {
                automaticMediaDownloadSettings = value
            } else {
                automaticMediaDownloadSettings = MediaAutoDownloadSettings.defaultSettings
            }
            
            //TODO:localize
            let controllerState = ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .text("Energy Saving"),
                leftNavigationButton: nil,
                rightNavigationButton: nil,
                backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
                animateChanges: false
            )
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: energeSavingSettingsScreenEntries(presentationData: presentationData, settings: automaticMediaDownloadSettings), style: .blocks, emptyStateItem: nil, animateChanges: true)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.pushViewController(c)
        }
    }
    return controller
}
