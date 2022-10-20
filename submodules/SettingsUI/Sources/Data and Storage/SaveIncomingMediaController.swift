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

private enum PeerType {
    case contact
    case otherPrivate
    case group
    case channel
}

private final class SaveIncomingMediaControllerArguments {
    let toggle: (PeerType) -> Void
    
    init(toggle: @escaping (PeerType) -> Void) {
        self.toggle = toggle
    }
}

enum SaveIncomingMediaSection: ItemListSectionId {
    case peers
}

private enum SaveIncomingMediaEntry: ItemListNodeEntry {
    case header(PresentationTheme, String)
    case contacts(PresentationTheme, String, Bool)
    case otherPrivate(PresentationTheme, String, Bool)
    case groups(PresentationTheme, String, Bool)
    case channels(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        return SaveIncomingMediaSection.peers.rawValue
    }
    
    var stableId: Int32 {
        switch self {
            case .header:
                return 0
            case .contacts:
                return 1
            case .otherPrivate:
                return 2
            case .groups:
                return 3
            case .channels:
                return 4
        }
    }
    
    static func <(lhs: SaveIncomingMediaEntry, rhs: SaveIncomingMediaEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SaveIncomingMediaControllerArguments
        switch self {
            case let .header(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .contacts(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggle(.contact)
                })
            case let .otherPrivate(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggle(.otherPrivate)
                })
            case let .groups(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggle(.group)
                })
            case let .channels(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggle(.channel)
                })
        }
    }
}

private func saveIncomingMediaControllerEntries(presentationData: PresentationData, settings: MediaAutoDownloadSettings) -> [SaveIncomingMediaEntry] {
    var entries: [SaveIncomingMediaEntry] = []
    
    entries.append(.header(presentationData.theme, presentationData.strings.SaveIncomingPhotosSettings_From))
    entries.append(.contacts(presentationData.theme, presentationData.strings.AutoDownloadSettings_Contacts, settings.saveDownloadedPhotos.contacts))
    entries.append(.otherPrivate(presentationData.theme, presentationData.strings.AutoDownloadSettings_PrivateChats, settings.saveDownloadedPhotos.otherPrivate))
    entries.append(.groups(presentationData.theme, presentationData.strings.AutoDownloadSettings_GroupChats, settings.saveDownloadedPhotos.groups))
    entries.append(.channels(presentationData.theme, presentationData.strings.AutoDownloadSettings_Channels, settings.saveDownloadedPhotos.channels))
    
    return entries
}

func saveIncomingMediaController(context: AccountContext) -> ViewController {
    let arguments = SaveIncomingMediaControllerArguments(toggle: { type in
        let _ = updateMediaDownloadSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            switch type {
                case .contact:
                    settings.saveDownloadedPhotos.contacts = !settings.saveDownloadedPhotos.contacts
                case .otherPrivate:
                    settings.saveDownloadedPhotos.otherPrivate = !settings.saveDownloadedPhotos.otherPrivate
                case .group:
                    settings.saveDownloadedPhotos.groups = !settings.saveDownloadedPhotos.groups
                case .channel:
                    settings.saveDownloadedPhotos.channels = !settings.saveDownloadedPhotos.channels
            }
            return settings
        }).start()
    })
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings]))
    |> deliverOnMainQueue
    |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let automaticMediaDownloadSettings: MediaAutoDownloadSettings
        if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings]?.get(MediaAutoDownloadSettings.self) {
            automaticMediaDownloadSettings = value
        } else {
            automaticMediaDownloadSettings = MediaAutoDownloadSettings.defaultSettings
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.SaveIncomingPhotosSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: saveIncomingMediaControllerEntries(presentationData: presentationData, settings: automaticMediaDownloadSettings), style: .blocks, emptyStateItem: nil, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    return controller
}

