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
    case autoplayVideo
    case autoplayGif
    case loopStickers
    case loopEmoji
    case playVideoAvatars
    case fullTranslucency
    case extendBackgroundWork
    case synchronizeInBackground
    case autodownloadInBackground
    
    var settingsKeyPath: WritableKeyPath<EnergyUsageSettings, Bool> {
        switch self {
        case .autoplayVideo:
            return \.autoplayVideo
        case .autoplayGif:
            return \.autoplayGif
        case .loopStickers:
            return \.loopStickers
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
    
    func title(strings: PresentationStrings) -> (String, String, String) {
        //TODO:localize
        switch self {
        case .autoplayVideo:
            return (
                "Settings/Menu/Reactions",
                "Autoplay Videos",
                "Autoplay and loop videos and video messages in chats."
            )
        case .autoplayGif:
            return (
                "Settings/Menu/Reactions",
                "Autoplay GIFs",
                "Autoplay and loop GIFs in chats and in the keyboard."
            )
        case .loopStickers:
            return (
                "Settings/Menu/Reactions",
                "Sticker Animations",
                "Autoplay and loop GIFs in chats and in the keyboard."
            )
        case .loopEmoji:
            return (
                "Settings/Menu/Reactions",
                "Emoli Animations",
                "Loop animated emoji in messages, reactions, statuses."
            )
        case .playVideoAvatars:
            return (
                "Settings/Menu/Reactions",
                "Autoplay Video Avatars",
                "Autoplay and loop video avatars in chats"
            )
        case .fullTranslucency:
            return (
                "Settings/Menu/Reactions",
                "Interface Effects",
                "Various effects and animations that make Telegram look amazing."
            )
        case .extendBackgroundWork:
            return (
                "Settings/Menu/Reactions",
                "Extended Background Time",
                "Extended Background Time Description"
            )
        case .synchronizeInBackground:
            return (
                "Settings/Menu/Reactions",
                "Background Sync",
                "Background Sync Description"
            )
        case .autodownloadInBackground:
            return (
                "Settings/Menu/Reactions",
                "Preload Media in Chats",
                "Preload Media in Chats Description"
            )
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
        case allFooter
        case itemsHeader
        case item(ItemType)
    }
    
    case all(Bool)
    case allFooter
    case item(index: Int, type: ItemType, value: Bool, enabled: Bool)
    case itemsHeader
    
    var section: ItemListSectionId {
        switch self {
        case .all, .allFooter:
            return EnergeSavingSettingsScreenSection.all.rawValue
        case .item, .itemsHeader:
            return EnergeSavingSettingsScreenSection.items.rawValue
        }
    }
    
    var sortIndex: Int {
        switch self {
        case .all:
            return -3
        case .allFooter:
            return -2
        case .itemsHeader:
            return -1
        case let .item(index, _, _, _):
            return index
        }
    }
    
    var stableId: StableId {
        switch self {
        case .all:
            return .all
        case .allFooter:
            return .allFooter
        case .itemsHeader:
            return .itemsHeader
        case let .item(_, type, _, _):
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
            return ItemListSwitchItem(presentationData: presentationData, title: "Power-Saving Mode", value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleAll(value)
            })
        case .allFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Reduce all resource-intensive animations and background activity."), sectionId: self.section)
        case .itemsHeader:
            //TODO:localize
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "RESOURCE-INTENSIVE PROCESSES", sectionId: self.section)
        case let .item(_, type, value, enabled):
            let (iconName, title, text) = type.title(strings: presentationData.strings)
            return ItemListSwitchItem(presentationData: presentationData, icon: UIImage(bundleImageName: iconName)?.precomposed(), title: title, text: text, value: value, enableInteractiveChanges: true, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
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
    
    let powerSavingOn = ItemType.allCases.allSatisfy({ item in !settings.energyUsageSettings[keyPath: item.settingsKeyPath] })
    entries.append(.all(powerSavingOn))
    entries.append(.allFooter)
    
    entries.append(.itemsHeader)
    for type in ItemType.allCases {
        entries.append(.item(index: entries.count, type: type, value: settings.energyUsageSettings[keyPath: type.settingsKeyPath], enabled: !powerSavingOn))
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
                    settings.energyUsageSettings[keyPath: type.settingsKeyPath] = !value
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
