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

enum AutomaticDownloadConnectionType {
    case cellular
    case wifi
    
    var automaticDownloadNetworkType: MediaAutoDownloadNetworkType {
        switch self {
            case .cellular:
                return .cellular
            case .wifi:
                return .wifi
        }
    }
}

private final class AutodownloadMediaConnectionTypeControllerArguments {
    let toggleMaster: (Bool) -> Void
    let changePreset: (AutomaticDownloadDataUsage) -> Void
    let customize: (AutomaticDownloadCategory) -> Void
    
    init(toggleMaster: @escaping (Bool) -> Void, changePreset: @escaping (AutomaticDownloadDataUsage) -> Void, customize: @escaping (AutomaticDownloadCategory) -> Void) {
        self.toggleMaster = toggleMaster
        self.changePreset = changePreset
        self.customize = customize
    }
}

private enum AutodownloadMediaCategorySection: Int32 {
    case master
    case dataUsage
    case types
}

private enum AutodownloadMediaCategoryEntry: ItemListNodeEntry {
    case master(PresentationTheme, String, Bool)
    case dataUsageHeader(PresentationTheme, String)
    case dataUsageItem(PresentationTheme, PresentationStrings, AutomaticDownloadDataUsage, Int?, Bool)
    case typesHeader(PresentationTheme, String)
    case photos(PresentationTheme, String, String, Bool)
    case videos(PresentationTheme, String, String, Bool)
    case files(PresentationTheme, String, String, Bool)
    case voiceMessagesInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .master:
                return AutodownloadMediaCategorySection.master.rawValue
            case .dataUsageHeader, .dataUsageItem:
                return AutodownloadMediaCategorySection.dataUsage.rawValue
            case .typesHeader, .photos, .videos, .files, .voiceMessagesInfo:
                return AutodownloadMediaCategorySection.types.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .master:
                return 0
            case .dataUsageHeader:
                return 1
            case .dataUsageItem:
                return 2
            case .typesHeader:
                return 3
            case .photos:
                return 4
            case .videos:
                return 5
            case .files:
                return 6
            case .voiceMessagesInfo:
                return 7
        }
    }
    
    static func ==(lhs: AutodownloadMediaCategoryEntry, rhs: AutodownloadMediaCategoryEntry) -> Bool {
        switch lhs {
            case let .master(lhsTheme, lhsText, lhsValue):
                if case let .master(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .dataUsageHeader(lhsTheme, lhsText):
                if case let .dataUsageHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .dataUsageItem(lhsTheme, lhsStrings, lhsValue, lhsCustomPosition, lhsEnabled):
                if case let .dataUsageItem(rhsTheme, rhsStrings, rhsValue, rhsCustomPosition, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsStrings == rhsStrings, lhsValue == rhsValue, lhsCustomPosition == rhsCustomPosition, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .typesHeader(lhsTheme, lhsText):
                if case let .typesHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .photos(lhsTheme, lhsText, lhsValue, lhsEnabled):
                if case let .photos(rhsTheme, rhsText, rhsValue, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .videos(lhsTheme, lhsText, lhsValue, lhsEnabled):
                if case let .videos(rhsTheme, rhsText, rhsValue, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .files(lhsTheme, lhsText, lhsValue, lhsEnabled):
                if case let .files(rhsTheme, rhsText, rhsValue, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .voiceMessagesInfo(lhsTheme, lhsText):
                if case let .voiceMessagesInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: AutodownloadMediaCategoryEntry, rhs: AutodownloadMediaCategoryEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AutodownloadMediaConnectionTypeControllerArguments
        switch self {
            case let .master(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleMaster(value)
                })
            case let .dataUsageHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .dataUsageItem(theme, strings, value, customPosition, enabled):
                return AutodownloadDataUsagePickerItem(theme: theme, strings: strings, value: value, customPosition: customPosition, enabled: enabled, sectionId: self.section, updated: { preset in
                    arguments.changePreset(preset)
                })
            case let .typesHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .photos(_, text, value, enabled):
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/Photos")?.precomposed(), title: text, enabled: enabled, label: value, labelStyle: .detailText, sectionId: self.section, style: .blocks, action: {
                    arguments.customize(.photo)
                })
            case let .videos(_, text, value, enabled):
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/Videos")?.precomposed(), title: text, enabled: enabled, label: value, labelStyle: .detailText, sectionId: self.section, style: .blocks, action: {
                    arguments.customize(.video)
                })
            case let .files(_, text, value, enabled):
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/Files")?.precomposed(), title: text, enabled: enabled, label: value, labelStyle: .detailText, sectionId: self.section, style: .blocks, action: {
                    arguments.customize(.file)
                })
            case let .voiceMessagesInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct AutomaticDownloadPeers {
    let contacts: Bool
    let otherPrivate: Bool
    let groups: Bool
    let channels: Bool
    let size: Int32?
    
    init(category: MediaAutoDownloadCategory) {
        self.contacts = category.contacts
        self.otherPrivate = category.otherPrivate
        self.groups = category.groups
        self.channels = category.channels
        self.size = category.sizeLimit
    }
}

private func stringForAutomaticDownloadPeers(strings: PresentationStrings, decimalSeparator: String, peers: AutomaticDownloadPeers, category: AutomaticDownloadCategory) -> String {
    var size: String?
    if var peersSize = peers.size, category == .video || category == .file {
        if peersSize == Int32.max {
            peersSize = 1536 * 1024 * 1024
        }
        size = autodownloadDataSizeString(Int64(peersSize), decimalSeparator: decimalSeparator)
    }
    
    if peers.contacts && peers.otherPrivate && peers.groups && peers.channels {
        if let size = size {
            return strings.AutoDownloadSettings_UpToForAll(size).string
        } else {
            return strings.AutoDownloadSettings_OnForAll
        }
    } else {
        var types: [String] = []
        if peers.contacts {
            types.append(strings.AutoDownloadSettings_TypeContacts)
        }
        if peers.otherPrivate {
            types.append(strings.AutoDownloadSettings_TypePrivateChats)
        }
        if peers.groups {
            types.append(strings.AutoDownloadSettings_TypeGroupChats)
        }
        if peers.channels {
            types.append(strings.AutoDownloadSettings_TypeChannels)
        }
    
        if types.isEmpty {
            return strings.AutoDownloadSettings_OffForAll
        }
        
        var string: String = ""
        for i in 0 ..< types.count {
            if !string.isEmpty {
                if i == types.count - 1 {
                    string.append(strings.AutoDownloadSettings_LastDelimeter)
                } else {
                    string.append(strings.AutoDownloadSettings_Delimeter)
                }
            }
            string.append(types[i])
        }
        
        if let size = size {
            return strings.AutoDownloadSettings_UpToFor(size, string).string
        } else {
            return strings.AutoDownloadSettings_OnFor(string).string
        }
    }
}

private func autodownloadMediaConnectionTypeControllerEntries(presentationData: PresentationData, connectionType: AutomaticDownloadConnectionType, settings: MediaAutoDownloadSettings) -> [AutodownloadMediaCategoryEntry] {
    var entries: [AutodownloadMediaCategoryEntry] = []
    
    let connection = settings.connectionSettings(for: connectionType.automaticDownloadNetworkType)
    let categories = effectiveAutodownloadCategories(settings: settings, networkType: connectionType.automaticDownloadNetworkType)
    
    let master = connection.enabled
    let photo = AutomaticDownloadPeers(category: categories.photo)
    let video = AutomaticDownloadPeers(category: categories.video)
    let file = AutomaticDownloadPeers(category: categories.file)
    
    entries.append(.master(presentationData.theme, presentationData.strings.AutoDownloadSettings_AutoDownload, master))
    
    entries.append(.dataUsageHeader(presentationData.theme, presentationData.strings.AutoDownloadSettings_DataUsage))
    
    var customPosition: Int?
    if let custom = connection.custom {
        let sortedPresets = [settings.presets.low, settings.presets.medium, settings.presets.high, custom].sorted()
        customPosition = sortedPresets.firstIndex(of: custom) ?? 0
    }
    
    entries.append(.dataUsageItem(presentationData.theme, presentationData.strings, AutomaticDownloadDataUsage(preset: connection.preset), customPosition, master))
    
    entries.append(.typesHeader(presentationData.theme, presentationData.strings.AutoDownloadSettings_MediaTypes))
    entries.append(.photos(presentationData.theme, presentationData.strings.AutoDownloadSettings_Photos, stringForAutomaticDownloadPeers(strings: presentationData.strings, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator, peers: photo, category: .photo), master))
    entries.append(.videos(presentationData.theme, presentationData.strings.AutoDownloadSettings_Videos, stringForAutomaticDownloadPeers(strings: presentationData.strings, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator, peers: video, category: .video), master))
    entries.append(.files(presentationData.theme, presentationData.strings.AutoDownloadSettings_Files, stringForAutomaticDownloadPeers(strings: presentationData.strings, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator, peers: file, category: .file), master))
    entries.append(.voiceMessagesInfo(presentationData.theme, presentationData.strings.AutoDownloadSettings_VoiceMessagesInfo))
    
    return entries
}

func autodownloadMediaConnectionTypeController(context: AccountContext, connectionType: AutomaticDownloadConnectionType) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let arguments = AutodownloadMediaConnectionTypeControllerArguments(toggleMaster: { value in
        let _ = updateMediaDownloadSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            switch connectionType {
                case .cellular:
                    settings.cellular.enabled = value
                case .wifi:
                    settings.wifi.enabled = value
            }
            return settings
        }).start()
    }, changePreset: { value in
        let _ = updateMediaDownloadSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            let preset: MediaAutoDownloadPreset
            switch value {
                case .low:
                    preset = .low
                case .medium:
                    preset = .medium
                case .high:
                    preset = .high
                case .custom:
                    preset = .custom
            }
            switch connectionType {
                case .cellular:
                    settings.cellular.preset = preset
                case .wifi:
                    settings.wifi.preset = preset
            }
            return settings
        }).start()
    }, customize: { category in
        let controller = autodownloadMediaCategoryController(context: context, connectionType: connectionType, category: category)
        pushControllerImpl?(controller)
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.autodownloadSettings, ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings]))
        |> deliverOnMainQueue
        |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
            var automaticMediaDownloadSettings: MediaAutoDownloadSettings
            if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings]?.get(MediaAutoDownloadSettings.self) {
                automaticMediaDownloadSettings = value
            } else {
                automaticMediaDownloadSettings = MediaAutoDownloadSettings.defaultSettings
            }
            
            var autodownloadSettings: AutodownloadSettings
            if let value = sharedData.entries[SharedDataKeys.autodownloadSettings]?.get(AutodownloadSettings.self) {
                autodownloadSettings = value
                automaticMediaDownloadSettings = automaticMediaDownloadSettings.updatedWithAutodownloadSettings(autodownloadSettings)
            } else {
                autodownloadSettings = .defaultSettings
            }
            
            let title: String
            switch connectionType {
                case .cellular:
                    title = presentationData.strings.AutoDownloadSettings_CellularTitle
                case .wifi:
                    title = presentationData.strings.AutoDownloadSettings_WifiTitle
            }
            
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: autodownloadMediaConnectionTypeControllerEntries(presentationData: presentationData, connectionType: connectionType, settings: automaticMediaDownloadSettings), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
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
