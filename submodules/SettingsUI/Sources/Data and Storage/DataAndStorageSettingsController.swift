import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import LegacyComponents
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import OpenInExternalAppUI

private final class DataAndStorageControllerArguments {
    let openStorageUsage: () -> Void
    let openNetworkUsage: () -> Void
    let openProxy: () -> Void
    let openAutomaticDownloadConnectionType: (AutomaticDownloadConnectionType) -> Void
    let resetAutomaticDownload: () -> Void
    let openVoiceUseLessData: () -> Void
    let openSaveIncomingPhotos: () -> Void
    let toggleSaveEditedPhotos: (Bool) -> Void
    let toggleAutoplayGifs: (Bool) -> Void
    let toggleAutoplayVideos: (Bool) -> Void
    let toggleDownloadInBackground: (Bool) -> Void
    let openBrowserSelection: () -> Void
    let openIntents: () -> Void
    let toggleEnableSensitiveContent: (Bool) -> Void

    init(openStorageUsage: @escaping () -> Void, openNetworkUsage: @escaping () -> Void, openProxy: @escaping () -> Void,  openAutomaticDownloadConnectionType: @escaping (AutomaticDownloadConnectionType) -> Void, resetAutomaticDownload: @escaping () -> Void, openVoiceUseLessData: @escaping () -> Void, openSaveIncomingPhotos: @escaping () -> Void, toggleSaveEditedPhotos: @escaping (Bool) -> Void, toggleAutoplayGifs: @escaping (Bool) -> Void, toggleAutoplayVideos: @escaping (Bool) -> Void, toggleDownloadInBackground: @escaping (Bool) -> Void, openBrowserSelection: @escaping () -> Void, openIntents: @escaping () -> Void, toggleEnableSensitiveContent: @escaping (Bool) -> Void) {
        self.openStorageUsage = openStorageUsage
        self.openNetworkUsage = openNetworkUsage
        self.openProxy = openProxy
        self.openAutomaticDownloadConnectionType = openAutomaticDownloadConnectionType
        self.resetAutomaticDownload = resetAutomaticDownload
        self.openVoiceUseLessData = openVoiceUseLessData
        self.openSaveIncomingPhotos = openSaveIncomingPhotos
        self.toggleSaveEditedPhotos = toggleSaveEditedPhotos
        self.toggleAutoplayGifs = toggleAutoplayGifs
        self.toggleAutoplayVideos = toggleAutoplayVideos
        self.toggleDownloadInBackground = toggleDownloadInBackground
        self.openBrowserSelection = openBrowserSelection
        self.openIntents = openIntents
        self.toggleEnableSensitiveContent = toggleEnableSensitiveContent
    }
}

private enum DataAndStorageSection: Int32 {
    case usage
    case autoDownload
    case autoPlay
    case voiceCalls
    case other
    case connection
    case enableSensitiveContent
}

enum DataAndStorageEntryTag: ItemListItemTag {
    case automaticDownloadReset
    case autoplayGifs
    case autoplayVideos
    case saveEditedPhotos
    case downloadInBackground
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? DataAndStorageEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum DataAndStorageEntry: ItemListNodeEntry {
    case storageUsage(PresentationTheme, String)
    case networkUsage(PresentationTheme, String)
    case automaticDownloadHeader(PresentationTheme, String)
    case automaticDownloadCellular(PresentationTheme, String, String)
    case automaticDownloadWifi(PresentationTheme, String, String)
    case automaticDownloadReset(PresentationTheme, String, Bool)
    case autoplayHeader(PresentationTheme, String)
    case autoplayGifs(PresentationTheme, String, Bool)
    case autoplayVideos(PresentationTheme, String, Bool)
    case voiceCallsHeader(PresentationTheme, String)
    case useLessVoiceData(PresentationTheme, String, String)
    case otherHeader(PresentationTheme, String)
    case shareSheet(PresentationTheme, String)
    case saveIncomingPhotos(PresentationTheme, String)
    case saveEditedPhotos(PresentationTheme, String, Bool)
    case openLinksIn(PresentationTheme, String, String)
    case downloadInBackground(PresentationTheme, String, Bool)
    case downloadInBackgroundInfo(PresentationTheme, String)
    case connectionHeader(PresentationTheme, String)
    case connectionProxy(PresentationTheme, String, String)
    case enableSensitiveContent(String, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .storageUsage, .networkUsage:
                return DataAndStorageSection.usage.rawValue
            case .automaticDownloadHeader, .automaticDownloadCellular, .automaticDownloadWifi, .automaticDownloadReset:
                return DataAndStorageSection.autoDownload.rawValue
            case .autoplayHeader, .autoplayGifs, .autoplayVideos:
                return DataAndStorageSection.autoPlay.rawValue
            case .voiceCallsHeader, .useLessVoiceData:
                return DataAndStorageSection.voiceCalls.rawValue
            case .otherHeader, .shareSheet, .saveIncomingPhotos, .saveEditedPhotos, .openLinksIn, .downloadInBackground, .downloadInBackgroundInfo:
                return DataAndStorageSection.other.rawValue
            case .connectionHeader, .connectionProxy:
                return DataAndStorageSection.connection.rawValue
            case .enableSensitiveContent:
                return DataAndStorageSection.enableSensitiveContent.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .storageUsage:
                return 0
            case .networkUsage:
                return 1
            case .automaticDownloadHeader:
                return 2
            case .automaticDownloadCellular:
                return 3
            case .automaticDownloadWifi:
                return 4
            case .automaticDownloadReset:
                return 5
            case .autoplayHeader:
                return 6
            case .autoplayGifs:
                return 7
            case .autoplayVideos:
                return 8
            case .voiceCallsHeader:
                return 9
            case .useLessVoiceData:
                return 10
            case .otherHeader:
                return 11
            case .shareSheet:
                return 12
            case .saveIncomingPhotos:
                return 13
            case .saveEditedPhotos:
                return 14
            case .openLinksIn:
                return 15
            case .downloadInBackground:
                return 16
            case .downloadInBackgroundInfo:
                return 17
            case .connectionHeader:
                return 18
            case .connectionProxy:
                return 19
            case .enableSensitiveContent:
                return 20
        }
    }
    
    static func ==(lhs: DataAndStorageEntry, rhs: DataAndStorageEntry) -> Bool {
        switch lhs {
            case let .storageUsage(lhsTheme, lhsText):
                if case let .storageUsage(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .networkUsage(lhsTheme, lhsText):
                if case let .networkUsage(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .automaticDownloadHeader(lhsTheme, lhsText):
                if case let .automaticDownloadHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .automaticDownloadCellular(lhsTheme, lhsText, lhsValue):
                if case let .automaticDownloadCellular(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .automaticDownloadWifi(lhsTheme, lhsText, lhsEnabled):
                if case let .automaticDownloadWifi(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .automaticDownloadReset(lhsTheme, lhsText, lhsEnabled):
                if case let .automaticDownloadReset(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .autoplayHeader(lhsTheme, lhsText):
                if case let .autoplayHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .autoplayGifs(lhsTheme, lhsText, lhsValue):
                if case let .autoplayGifs(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .autoplayVideos(lhsTheme, lhsText, lhsValue):
                if case let .autoplayVideos(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .voiceCallsHeader(lhsTheme, lhsText):
                if case let .voiceCallsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .useLessVoiceData(lhsTheme, lhsText, lhsValue):
                if case let .useLessVoiceData(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .otherHeader(lhsTheme, lhsText):
                if case let .otherHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .shareSheet(lhsTheme, lhsText):
                if case let .shareSheet(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .saveIncomingPhotos(lhsTheme, lhsText):
                if case let .saveIncomingPhotos(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .saveEditedPhotos(lhsTheme, lhsText, lhsValue):
                if case let .saveEditedPhotos(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .openLinksIn(lhsTheme, lhsText, lhsValue):
                if case let .openLinksIn(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .downloadInBackground(lhsTheme, lhsText, lhsValue):
                if case let .downloadInBackground(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .downloadInBackgroundInfo(lhsTheme, lhsText):
                if case let .downloadInBackgroundInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .connectionHeader(lhsTheme, lhsText):
                if case let .connectionHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .connectionProxy(lhsTheme, lhsText, lhsValue):
                if case let .connectionProxy(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .enableSensitiveContent(text, value):
                if case .enableSensitiveContent(text, value) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: DataAndStorageEntry, rhs: DataAndStorageEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! DataAndStorageControllerArguments
        switch self {
            case let .storageUsage(theme, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openStorageUsage()
                })
            case let .networkUsage(theme, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openNetworkUsage()
                })
            case let .automaticDownloadHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .automaticDownloadCellular(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, labelStyle: .detailText, sectionId: self.section, style: .blocks, action: {
                    arguments.openAutomaticDownloadConnectionType(.cellular)
                })
            case let .automaticDownloadWifi(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, labelStyle: .detailText, sectionId: self.section, style: .blocks, action: {
                    arguments.openAutomaticDownloadConnectionType(.wifi)
                })
            case let .automaticDownloadReset(theme, text, enabled):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    if enabled {
                        arguments.resetAutomaticDownload()
                    }
                }, tag: DataAndStorageEntryTag.automaticDownloadReset)
            case let .autoplayHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .autoplayGifs(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutoplayGifs(value)
                }, tag: DataAndStorageEntryTag.autoplayGifs)
            case let .autoplayVideos(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutoplayVideos(value)
                }, tag: DataAndStorageEntryTag.autoplayVideos)
            case let .voiceCallsHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .useLessVoiceData(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openVoiceUseLessData()
                })
            case let .otherHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .shareSheet(theme, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openIntents()
                })
            case let .saveIncomingPhotos(theme, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openSaveIncomingPhotos()
                })
            case let .saveEditedPhotos(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleSaveEditedPhotos(value)
                }, tag: DataAndStorageEntryTag.saveEditedPhotos)
            case let .openLinksIn(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openBrowserSelection()
                })
            case let .downloadInBackground(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleDownloadInBackground(value)
                }, tag: DataAndStorageEntryTag.downloadInBackground)
            case let .downloadInBackgroundInfo(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .connectionHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .connectionProxy(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openProxy()
                })
            case let .enableSensitiveContent(text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleEnableSensitiveContent(value)
                }, tag: nil)
        }
    }
}

private struct DataAndStorageControllerState: Equatable {
    static func ==(lhs: DataAndStorageControllerState, rhs: DataAndStorageControllerState) -> Bool {
        return true
    }
}

private struct DataAndStorageData: Equatable {
    let automaticMediaDownloadSettings: MediaAutoDownloadSettings
    let autodownloadSettings: AutodownloadSettings
    let generatedMediaStoreSettings: GeneratedMediaStoreSettings
    let voiceCallSettings: VoiceCallSettings
    let proxySettings: ProxySettings?
    
    init(automaticMediaDownloadSettings: MediaAutoDownloadSettings, autodownloadSettings: AutodownloadSettings, generatedMediaStoreSettings: GeneratedMediaStoreSettings, voiceCallSettings: VoiceCallSettings, proxySettings: ProxySettings?) {
        self.automaticMediaDownloadSettings = automaticMediaDownloadSettings
        self.autodownloadSettings = autodownloadSettings
        self.generatedMediaStoreSettings = generatedMediaStoreSettings
        self.voiceCallSettings = voiceCallSettings
        self.proxySettings = proxySettings
    }
    
    static func ==(lhs: DataAndStorageData, rhs: DataAndStorageData) -> Bool {
        return lhs.automaticMediaDownloadSettings == rhs.automaticMediaDownloadSettings && lhs.generatedMediaStoreSettings == rhs.generatedMediaStoreSettings && lhs.voiceCallSettings == rhs.voiceCallSettings && lhs.proxySettings == rhs.proxySettings
    }
}

private func stringForUseLessDataSetting(_ dataSaving: VoiceCallDataSaving, strings: PresentationStrings) -> String {
    switch dataSaving {
        case .never:
            return strings.CallSettings_Never
        case .cellular:
            return strings.CallSettings_OnMobile
        case .always:
            return strings.CallSettings_Always
        case .default:
            return ""
    }
}

private func stringForAutoDownloadTypes(strings: PresentationStrings, decimalSeparator: String, photo: Bool, videoSize: Int32?, fileSize: Int32?) -> String {
    var types: [String] = []
    if photo {
        types.append(strings.ChatSettings_AutoDownloadSettings_TypePhoto)
    }
    if let videoSize = videoSize {
        types.append(strings.ChatSettings_AutoDownloadSettings_TypeVideo(autodownloadDataSizeString(Int64(videoSize), decimalSeparator: decimalSeparator)).0)
    }
    if let fileSize = fileSize {
        types.append(strings.ChatSettings_AutoDownloadSettings_TypeFile(autodownloadDataSizeString(Int64(fileSize), decimalSeparator: decimalSeparator)).0)
    }

    if types.isEmpty {
        return strings.ChatSettings_AutoDownloadSettings_OffForAll
    }
    
    var string: String = ""
    for i in 0 ..< types.count {
        if !string.isEmpty {
            string.append(strings.ChatSettings_AutoDownloadSettings_Delimeter)
        }
        string.append(types[i])
    }
    return string
}

private func stringForAutoDownloadSetting(strings: PresentationStrings, decimalSeparator: String, settings: MediaAutoDownloadSettings, connectionType: AutomaticDownloadConnectionType) -> String {
    let connection: MediaAutoDownloadConnection
    switch connectionType {
        case .cellular:
            connection = settings.cellular
        case .wifi:
            connection = settings.wifi
    }
    if !connection.enabled {
        return strings.ChatSettings_AutoDownloadSettings_OffForAll
    } else {
        let categories = effectiveAutodownloadCategories(settings: settings, networkType: connectionType.automaticDownloadNetworkType)
        
        let photo = isAutodownloadEnabledForAnyPeerType(category: categories.photo)
        let video = isAutodownloadEnabledForAnyPeerType(category: categories.video)
        let file = isAutodownloadEnabledForAnyPeerType(category: categories.file)
    
        return stringForAutoDownloadTypes(strings: strings, decimalSeparator: decimalSeparator, photo: photo, videoSize: video ? categories.video.sizeLimit : nil, fileSize: file ? categories.file.sizeLimit : nil)
    }
}

private func dataAndStorageControllerEntries(state: DataAndStorageControllerState, data: DataAndStorageData, presentationData: PresentationData, defaultWebBrowser: String, contentSettingsConfiguration: ContentSettingsConfiguration?) -> [DataAndStorageEntry] {
    var entries: [DataAndStorageEntry] = []
    
    entries.append(.storageUsage(presentationData.theme, presentationData.strings.ChatSettings_Cache))
    entries.append(.networkUsage(presentationData.theme, presentationData.strings.NetworkUsageSettings_Title))
    
    entries.append(.automaticDownloadHeader(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadTitle.uppercased()))
    entries.append(.automaticDownloadCellular(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadUsingCellular, stringForAutoDownloadSetting(strings: presentationData.strings, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator, settings: data.automaticMediaDownloadSettings, connectionType: .cellular)))
    entries.append(.automaticDownloadWifi(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadUsingWiFi, stringForAutoDownloadSetting(strings: presentationData.strings, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator, settings: data.automaticMediaDownloadSettings, connectionType: .wifi)))
    
    let defaultSettings = MediaAutoDownloadSettings.defaultSettings
    entries.append(.automaticDownloadReset(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadReset, data.automaticMediaDownloadSettings.cellular != defaultSettings.cellular || data.automaticMediaDownloadSettings.wifi != defaultSettings.wifi))
    
    entries.append(.autoplayHeader(presentationData.theme, presentationData.strings.ChatSettings_AutoPlayTitle))
    entries.append(.autoplayGifs(presentationData.theme, presentationData.strings.ChatSettings_AutoPlayGifs, data.automaticMediaDownloadSettings.autoplayGifs))
    entries.append(.autoplayVideos(presentationData.theme, presentationData.strings.ChatSettings_AutoPlayVideos, data.automaticMediaDownloadSettings.autoplayVideos))
    
    entries.append(.voiceCallsHeader(presentationData.theme, presentationData.strings.Settings_CallSettings.uppercased()))
    let dataSaving = effectiveDataSaving(for: data.voiceCallSettings, autodownloadSettings: data.autodownloadSettings)
    entries.append(.useLessVoiceData(presentationData.theme, presentationData.strings.CallSettings_UseLessData, stringForUseLessDataSetting(dataSaving, strings: presentationData.strings)))
    
    entries.append(.otherHeader(presentationData.theme, presentationData.strings.ChatSettings_Other))
    if #available(iOSApplicationExtension 13.2, iOS 13.2, *) {
        entries.append(.shareSheet(presentationData.theme, presentationData.strings.ChatSettings_IntentsSettings))
    }
    entries.append(.saveIncomingPhotos(presentationData.theme, presentationData.strings.Settings_SaveIncomingPhotos))
    entries.append(.saveEditedPhotos(presentationData.theme, presentationData.strings.Settings_SaveEditedPhotos, data.generatedMediaStoreSettings.storeEditedPhotos))
    entries.append(.openLinksIn(presentationData.theme, presentationData.strings.ChatSettings_OpenLinksIn, defaultWebBrowser))
    entries.append(.downloadInBackground(presentationData.theme, presentationData.strings.ChatSettings_DownloadInBackground, data.automaticMediaDownloadSettings.downloadInBackground))
    entries.append(.downloadInBackgroundInfo(presentationData.theme, presentationData.strings.ChatSettings_DownloadInBackgroundInfo))
    
    let proxyValue: String
    if let proxySettings = data.proxySettings, let activeServer = proxySettings.activeServer, proxySettings.enabled {
        switch activeServer.connection {
            case .socks5:
                proxyValue = presentationData.strings.ChatSettings_ConnectionType_UseSocks5
            case .mtp:
                proxyValue = presentationData.strings.SocksProxySetup_ProxyTelegram
        }
    } else {
        proxyValue = presentationData.strings.GroupInfo_SharedMediaNone
    }
    entries.append(.connectionHeader(presentationData.theme, presentationData.strings.ChatSettings_ConnectionType_Title.uppercased()))
    entries.append(.connectionProxy(presentationData.theme, presentationData.strings.SocksProxySetup_Title, proxyValue))
    
    #if DEBUG
    if let contentSettingsConfiguration = contentSettingsConfiguration, contentSettingsConfiguration.canAdjustSensitiveContent {
        entries.append(.enableSensitiveContent("Display Sensitive Content", contentSettingsConfiguration.sensitiveContentEnabled))
    }
    #endif
    
    return entries
}

func dataAndStorageController(context: AccountContext, focusOnItemTag: DataAndStorageEntryTag? = nil) -> ViewController {
    let initialState = DataAndStorageControllerState()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let cacheUsagePromise = Promise<CacheUsageStatsResult?>()
    cacheUsagePromise.set(cacheUsageStats(context: context))
    
    let updateSensitiveContentDisposable = MetaDisposable()
    actionsDisposable.add(updateSensitiveContentDisposable)
    
    let updatedContentSettingsConfiguration = contentSettingsConfiguration(network: context.account.network)
    |> map(Optional.init)
    let contentSettingsConfiguration = Promise<ContentSettingsConfiguration?>()
    contentSettingsConfiguration.set(.single(nil)
    |> then(updatedContentSettingsConfiguration))
    
    let dataAndStorageDataPromise = Promise<DataAndStorageData>()
    dataAndStorageDataPromise.set(context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.autodownloadSettings, ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings, ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings, ApplicationSpecificSharedDataKeys.voiceCallSettings, SharedDataKeys.proxySettings])
    |> map { sharedData -> DataAndStorageData in
        var automaticMediaDownloadSettings: MediaAutoDownloadSettings
        if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings] as? MediaAutoDownloadSettings {
            automaticMediaDownloadSettings = value
        } else {
            automaticMediaDownloadSettings = .defaultSettings
        }
        
        var autodownloadSettings: AutodownloadSettings
        if let value = sharedData.entries[SharedDataKeys.autodownloadSettings] as? AutodownloadSettings {
            autodownloadSettings = value
            automaticMediaDownloadSettings = automaticMediaDownloadSettings.updatedWithAutodownloadSettings(autodownloadSettings)
        } else {
            autodownloadSettings = .defaultSettings
        }
        
        let generatedMediaStoreSettings: GeneratedMediaStoreSettings
        if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings] as? GeneratedMediaStoreSettings {
            generatedMediaStoreSettings = value
        } else {
            generatedMediaStoreSettings = GeneratedMediaStoreSettings.defaultSettings
        }
        
        let voiceCallSettings: VoiceCallSettings
        if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.voiceCallSettings] as? VoiceCallSettings {
            voiceCallSettings = value
        } else {
            voiceCallSettings = VoiceCallSettings.defaultSettings
        }
        
        var proxySettings: ProxySettings?
        if let value = sharedData.entries[SharedDataKeys.proxySettings] as? ProxySettings {
            proxySettings = value
        }
        
        return DataAndStorageData(automaticMediaDownloadSettings: automaticMediaDownloadSettings, autodownloadSettings: autodownloadSettings, generatedMediaStoreSettings: generatedMediaStoreSettings, voiceCallSettings: voiceCallSettings, proxySettings: proxySettings)
    })
    
    let arguments = DataAndStorageControllerArguments(openStorageUsage: {
        pushControllerImpl?(storageUsageController(context: context, cacheUsagePromise: cacheUsagePromise))
    }, openNetworkUsage: {
        pushControllerImpl?(networkUsageStatsController(context: context))
    }, openProxy: {
        pushControllerImpl?(proxySettingsController(context: context))
    }, openAutomaticDownloadConnectionType: { connectionType in
        pushControllerImpl?(autodownloadMediaConnectionTypeController(context: context, connectionType: connectionType))
    }, resetAutomaticDownload: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetTextItem(title: presentationData.strings.AutoDownloadSettings_ResetHelp),
            ActionSheetButtonItem(title: presentationData.strings.AutoDownloadSettings_Reset, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                let _ = updateMediaDownloadSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                    var settings = settings
                    let defaultSettings = MediaAutoDownloadSettings.defaultSettings
                    settings.cellular = defaultSettings.cellular
                    settings.wifi = defaultSettings.wifi
                    return settings
                }).start()
            })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
                ])])
        presentControllerImpl?(actionSheet, nil)
    }, openVoiceUseLessData: {
        pushControllerImpl?(voiceCallDataSavingController(context: context))
    }, openSaveIncomingPhotos: {
        pushControllerImpl?(saveIncomingMediaController(context: context))
    }, toggleSaveEditedPhotos: { value in
        let _ = updateGeneratedMediaStoreSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return current.withUpdatedStoreEditedPhotos(value)
        }).start()
    }, toggleAutoplayGifs: { value in
        let _ = updateMediaDownloadSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.autoplayGifs = value
            return settings
        }).start()
    }, toggleAutoplayVideos: { value in
        let _ = updateMediaDownloadSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.autoplayVideos = value
            return settings
        }).start()
    }, toggleDownloadInBackground: { value in
        let _ = updateMediaDownloadSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.downloadInBackground = value
            return settings
        }).start()
    }, openBrowserSelection: {
        let controller = webBrowserSettingsController(context: context)
        pushControllerImpl?(controller)
    }, openIntents: {
        let controller = intentsSettingsController(context: context)
          pushControllerImpl?(controller)
    }, toggleEnableSensitiveContent: { value in
        let _ = (contentSettingsConfiguration.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak contentSettingsConfiguration] settings in
            if var settings = settings {
                settings.sensitiveContentEnabled = value
                contentSettingsConfiguration?.set(.single(settings))
            }
        })
        updateSensitiveContentDisposable.set(updateRemoteContentSettingsConfiguration(postbox: context.account.postbox, network: context.account.network, sensitiveContentEnabled: value).start())
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get(),
        dataAndStorageDataPromise.get(),
        context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.webBrowserSettings]),
        contentSettingsConfiguration.get()
    )
    |> map { presentationData, state, dataAndStorageData, sharedData, contentSettingsConfiguration -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let webBrowserSettings = (sharedData.entries[ApplicationSpecificSharedDataKeys.webBrowserSettings] as? WebBrowserSettings) ?? WebBrowserSettings.defaultSettings
        let options = availableOpenInOptions(context: context, item: .url(url: "https://telegram.org"))
        let defaultWebBrowser: String
        if let option = options.first(where: { $0.identifier == webBrowserSettings.defaultWebBrowser }) {
            defaultWebBrowser = option.title
        } else {
            defaultWebBrowser = presentationData.strings.WebBrowser_InAppSafari
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.ChatSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: dataAndStorageControllerEntries(state: state, data: dataAndStorageData, presentationData: presentationData, defaultWebBrowser: defaultWebBrowser, contentSettingsConfiguration: contentSettingsConfiguration), style: .blocks, ensureVisibleItemTag: focusOnItemTag, emptyStateItem: nil, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.pushViewController(c)
        }
    }
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }

    return controller
}
