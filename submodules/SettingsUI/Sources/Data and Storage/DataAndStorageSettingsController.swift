import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import OpenInExternalAppUI
import ItemListPeerActionItem
import StorageUsageScreen

public enum AutomaticSaveIncomingPeerType {
    case privateChats
    case groups
    case channels
}

private final class DataAndStorageControllerArguments {
    let openStorageUsage: () -> Void
    let openNetworkUsage: () -> Void
    let openProxy: () -> Void
    let openAutomaticDownloadConnectionType: (AutomaticDownloadConnectionType) -> Void
    let resetAutomaticDownload: () -> Void
    let toggleVoiceUseLessData: (Bool) -> Void
    let openSaveIncoming: (AutomaticSaveIncomingPeerType) -> Void
    let toggleSaveEditedPhotos: (Bool) -> Void
    let togglePauseMusicOnRecording: (Bool) -> Void
    let toggleRaiseToListen: (Bool) -> Void
    let toggleDownloadInBackground: (Bool) -> Void
    let openBrowserSelection: () -> Void
    let openIntents: () -> Void
    let toggleEnableSensitiveContent: (Bool) -> Void

    init(openStorageUsage: @escaping () -> Void, openNetworkUsage: @escaping () -> Void, openProxy: @escaping () -> Void,  openAutomaticDownloadConnectionType: @escaping (AutomaticDownloadConnectionType) -> Void, resetAutomaticDownload: @escaping () -> Void, toggleVoiceUseLessData: @escaping (Bool) -> Void, openSaveIncoming: @escaping (AutomaticSaveIncomingPeerType) -> Void, toggleSaveEditedPhotos: @escaping (Bool) -> Void, togglePauseMusicOnRecording: @escaping (Bool) -> Void, toggleRaiseToListen: @escaping (Bool) -> Void, toggleDownloadInBackground: @escaping (Bool) -> Void, openBrowserSelection: @escaping () -> Void, openIntents: @escaping () -> Void, toggleEnableSensitiveContent: @escaping (Bool) -> Void) {
        self.openStorageUsage = openStorageUsage
        self.openNetworkUsage = openNetworkUsage
        self.openProxy = openProxy
        self.openAutomaticDownloadConnectionType = openAutomaticDownloadConnectionType
        self.resetAutomaticDownload = resetAutomaticDownload
        self.toggleVoiceUseLessData = toggleVoiceUseLessData
        self.openSaveIncoming = openSaveIncoming
        self.toggleSaveEditedPhotos = toggleSaveEditedPhotos
        self.togglePauseMusicOnRecording = togglePauseMusicOnRecording
        self.toggleRaiseToListen = toggleRaiseToListen
        self.toggleDownloadInBackground = toggleDownloadInBackground
        self.openBrowserSelection = openBrowserSelection
        self.openIntents = openIntents
        self.toggleEnableSensitiveContent = toggleEnableSensitiveContent
    }
}

private enum DataAndStorageSection: Int32 {
    case usage
    case autoDownload
    case autoSave
    case backgroundDownload
    case voiceCalls
    case other
    case connection
    case enableSensitiveContent
}

public enum DataAndStorageEntryTag: ItemListItemTag, Equatable {
    case automaticDownloadReset
    case saveEditedPhotos
    case downloadInBackground
    case pauseMusicOnRecording
    case raiseToListen
    case autoSave(AutomaticSaveIncomingPeerType)
    
    public func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? DataAndStorageEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum DataAndStorageEntry: ItemListNodeEntry {
    case storageUsage(PresentationTheme, String, String)
    case networkUsage(PresentationTheme, String, String)
    case automaticDownloadHeader(PresentationTheme, String)
    case automaticDownloadCellular(PresentationTheme, String, String)
    case automaticDownloadWifi(PresentationTheme, String, String)
    case automaticDownloadReset(PresentationTheme, String, Bool)
    
    case autoSaveHeader(String)
    case autoSaveItem(index: Int, type: AutomaticSaveIncomingPeerType, title: String, label: String, value: String)
    case autoSaveInfo(String)
    
    case downloadInBackground(PresentationTheme, String, Bool)
    case downloadInBackgroundInfo(PresentationTheme, String)
    
    case useLessVoiceData(PresentationTheme, String, Bool)
    case useLessVoiceDataInfo(PresentationTheme, String)
    case otherHeader(PresentationTheme, String)
    case shareSheet(PresentationTheme, String)
    case saveEditedPhotos(PresentationTheme, String, Bool)
    case openLinksIn(PresentationTheme, String, String)
    case pauseMusicOnRecording(PresentationTheme, String, Bool)
    case raiseToListen(PresentationTheme, String, Bool)
    case raiseToListenInfo(PresentationTheme, String)
    
    case connectionHeader(PresentationTheme, String)
    case connectionProxy(PresentationTheme, String, String)
    case enableSensitiveContent(String, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .storageUsage, .networkUsage:
                return DataAndStorageSection.usage.rawValue
            case .automaticDownloadHeader, .automaticDownloadCellular, .automaticDownloadWifi, .automaticDownloadReset:
                return DataAndStorageSection.autoDownload.rawValue
            case .autoSaveHeader, .autoSaveItem, .autoSaveInfo:
                return DataAndStorageSection.autoSave.rawValue
            case .downloadInBackground, .downloadInBackgroundInfo:
                return DataAndStorageSection.backgroundDownload.rawValue
            case .useLessVoiceData, .useLessVoiceDataInfo:
                return DataAndStorageSection.voiceCalls.rawValue
            case .otherHeader, .shareSheet, .saveEditedPhotos, .openLinksIn, .pauseMusicOnRecording, .raiseToListen, .raiseToListenInfo:
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
            case .autoSaveHeader:
                return 6
            case let .autoSaveItem(index, _, _, _, _):
                return 7 + Int32(index)
            case .autoSaveInfo:
                return 20
            case .downloadInBackground:
                return 21
            case .downloadInBackgroundInfo:
                return 22
            case .useLessVoiceData:
                return 23
            case .useLessVoiceDataInfo:
                return 24
            case .otherHeader:
                return 29
            case .shareSheet:
                return 30
            case .saveEditedPhotos:
                return 31
            case .openLinksIn:
                return 32
            case .pauseMusicOnRecording:
                return 33
            case .raiseToListen:
                return 34
            case .raiseToListenInfo:
                return 35
            case .connectionHeader:
                return 36
            case .connectionProxy:
                return 37
            case .enableSensitiveContent:
                return 38
        }
    }
    
    static func ==(lhs: DataAndStorageEntry, rhs: DataAndStorageEntry) -> Bool {
        switch lhs {
            case let .storageUsage(lhsTheme, lhsText, lhsValue):
                if case let .storageUsage(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .networkUsage(lhsTheme, lhsText, lhsValue):
                if case let .networkUsage(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
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
            case let .autoSaveHeader(text):
                if case .autoSaveHeader(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .autoSaveItem(index, type, title, label, value):
                if case .autoSaveItem(index, type, title, label, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .autoSaveInfo(text):
                if case .autoSaveInfo(text) = rhs {
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
            case let .useLessVoiceDataInfo(lhsTheme, lhsText):
                if case let .useLessVoiceDataInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .pauseMusicOnRecording(lhsTheme, lhsText, lhsValue):
                if case let .pauseMusicOnRecording(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .raiseToListen(lhsTheme, lhsText, lhsValue):
                if case let .raiseToListen(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .raiseToListenInfo(lhsTheme, lhsText):
                if case let .raiseToListenInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .storageUsage(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/Storage")?.precomposed(), title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openStorageUsage()
                })
            case let .networkUsage(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/Network")?.precomposed(), title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openNetworkUsage()
                })
            case let .automaticDownloadHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .automaticDownloadCellular(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/Cellular")?.precomposed(), title: text, label: value, labelStyle: .detailText, sectionId: self.section, style: .blocks, action: {
                    arguments.openAutomaticDownloadConnectionType(.cellular)
                })
            case let .automaticDownloadWifi(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/WiFi")?.precomposed(), title: text, label: value, labelStyle: .detailText, sectionId: self.section, style: .blocks, action: {
                    arguments.openAutomaticDownloadConnectionType(.wifi)
                })
            case let .automaticDownloadReset(theme, text, enabled):
                var icon = PresentationResourcesItemList.resetIcon(theme)
                if !enabled {
                    icon = generateTintedImage(image: icon, color: theme.list.itemDisabledTextColor)
                }
                return ItemListPeerActionItem(presentationData: presentationData, icon: icon, title: text, sectionId: self.section, height: .generic, color: enabled ? .accent : .disabled, editing: false, action: {
                    if enabled {
                        arguments.resetAutomaticDownload()
                    }
                })
            case let .autoSaveHeader(text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .autoSaveItem(_, type, title, label, value):
                let iconName: String
                switch type {
                case .privateChats:
                    iconName = "Settings/Menu/EditProfile"
                case .groups:
                    iconName = "Settings/Menu/GroupChats"
                case .channels:
                    iconName = "Settings/Menu/Channels"
                }
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: iconName)?.precomposed(), title: title, label: value, labelStyle: .text, additionalDetailLabel: label.isEmpty ? nil : label, sectionId: self.section, style: .blocks, action: {
                    arguments.openSaveIncoming(type)
                })
            case let .autoSaveInfo(text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
            case let .useLessVoiceData(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleVoiceUseLessData(value)
                }, tag: nil)
            case let .useLessVoiceDataInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .otherHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .shareSheet(_, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openIntents()
                })
            case let .saveEditedPhotos(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleSaveEditedPhotos(value)
                }, tag: DataAndStorageEntryTag.saveEditedPhotos)
            case let .openLinksIn(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openBrowserSelection()
                })
            case let .pauseMusicOnRecording(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.togglePauseMusicOnRecording(value)
                }, tag: DataAndStorageEntryTag.pauseMusicOnRecording)
            case let .raiseToListen(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleRaiseToListen(value)
                }, tag: DataAndStorageEntryTag.raiseToListen)
            case let .raiseToListenInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
            case let .downloadInBackground(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleDownloadInBackground(value)
                }, tag: DataAndStorageEntryTag.downloadInBackground)
            case let .downloadInBackgroundInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .connectionHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .connectionProxy(_, text, value):
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
    let mediaInputSettings: MediaInputSettings
    let voiceCallSettings: VoiceCallSettings
    let proxySettings: ProxySettings?
    
    init(automaticMediaDownloadSettings: MediaAutoDownloadSettings, autodownloadSettings: AutodownloadSettings, generatedMediaStoreSettings: GeneratedMediaStoreSettings, mediaInputSettings: MediaInputSettings, voiceCallSettings: VoiceCallSettings, proxySettings: ProxySettings?) {
        self.automaticMediaDownloadSettings = automaticMediaDownloadSettings
        self.autodownloadSettings = autodownloadSettings
        self.generatedMediaStoreSettings = generatedMediaStoreSettings
        self.mediaInputSettings = mediaInputSettings
        self.voiceCallSettings = voiceCallSettings
        self.proxySettings = proxySettings
    }
    
    static func ==(lhs: DataAndStorageData, rhs: DataAndStorageData) -> Bool {
        return lhs.automaticMediaDownloadSettings == rhs.automaticMediaDownloadSettings && lhs.generatedMediaStoreSettings == rhs.generatedMediaStoreSettings && lhs.mediaInputSettings == rhs.mediaInputSettings && lhs.voiceCallSettings == rhs.voiceCallSettings && lhs.proxySettings == rhs.proxySettings
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

private func stringForAutoDownloadTypes(strings: PresentationStrings, decimalSeparator: String, photo: Bool, videoSize: Int64?, fileSize: Int64?) -> String {
    var types: [String] = []
    if photo && videoSize == nil {
        types.append(strings.ChatSettings_AutoDownloadSettings_TypePhoto)
    }
    if let videoSize = videoSize {
        if photo {
            types.append(strings.ChatSettings_AutoDownloadSettings_TypeMedia(autodownloadDataSizeString(videoSize, decimalSeparator: decimalSeparator)).string)
        } else {
            types.append(strings.ChatSettings_AutoDownloadSettings_TypeVideo(autodownloadDataSizeString(videoSize, decimalSeparator: decimalSeparator)).string)
        }
    }
    if let fileSize = fileSize {
        types.append(strings.ChatSettings_AutoDownloadSettings_TypeFile(autodownloadDataSizeString(fileSize, decimalSeparator: decimalSeparator)).string)
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

private func autosaveLabelAndValue(presentationData: PresentationData, settings: MediaAutoSaveSettings, peerType: AutomaticSaveIncomingPeerType, exceptionPeers: [EnginePeer.Id: EnginePeer?]) -> (label: String, value: String) {
    var exceptionCount = 0
    let configuration: MediaAutoSaveConfiguration
    switch peerType {
    case .privateChats:
        configuration = settings.configurations[.users] ?? .default
    case .groups:
        configuration = settings.configurations[.groups] ?? .default
    case .channels:
        configuration = settings.configurations[.channels] ?? .default
    }
    
    for exception in settings.exceptions {
        if let maybePeer = exceptionPeers[exception.id], let peer = maybePeer {
            let peerTypeValue: AutomaticSaveIncomingPeerType
            switch peer {
            case .user, .secretChat:
                peerTypeValue = .privateChats
            case .legacyGroup:
                peerTypeValue = .groups
            case let .channel(channel):
                if case .broadcast = channel.info {
                    peerTypeValue = .channels
                } else {
                    peerTypeValue = .groups
                }
            }
            
            if peerTypeValue == peerType {
                exceptionCount += 1
            }
        }
    }
    
    let value: String
    if configuration.photo || configuration.video {
        value = presentationData.strings.Settings_AutosaveMediaOn
    } else {
        value = presentationData.strings.Settings_AutosaveMediaOff
    }
    
    var label = ""
    if configuration.photo && configuration.video {
        label.append(presentationData.strings.Settings_AutosaveMediaAllMedia(dataSizeString(Int(configuration.maximumVideoSize), formatting: DataSizeStringFormatting(presentationData: presentationData))).string)
    } else {
        if configuration.photo {
            if !label.isEmpty {
                label.append(", ")
            }
            label.append(presentationData.strings.Settings_AutosaveMediaPhoto)
        } else if configuration.video {
            if !label.isEmpty {
                label.append(", ")
            }
            label.append(presentationData.strings.Settings_AutosaveMediaVideo(dataSizeString(Int(configuration.maximumVideoSize), formatting: DataSizeStringFormatting(presentationData: presentationData))).string)
        }
    }
    
    if exceptionCount != 0 {
        if !label.isEmpty {
            label.append(", ")
        }
        label.append(presentationData.strings.Notifications_CategoryExceptions(Int32(exceptionCount)))
    }
    
    return (label, value)
}

private func dataAndStorageControllerEntries(state: DataAndStorageControllerState, data: DataAndStorageData, presentationData: PresentationData, defaultWebBrowser: String, contentSettingsConfiguration: ContentSettingsConfiguration?, networkUsage: Int64, storageUsage: Int64, mediaAutoSaveSettings: MediaAutoSaveSettings, autosaveExceptionPeers: [EnginePeer.Id: EnginePeer?]) -> [DataAndStorageEntry] {
    var entries: [DataAndStorageEntry] = []
    
    entries.append(.storageUsage(presentationData.theme, presentationData.strings.ChatSettings_Cache, dataSizeString(storageUsage, formatting: DataSizeStringFormatting(presentationData: presentationData))))
    entries.append(.networkUsage(presentationData.theme, presentationData.strings.NetworkUsageSettings_Title, dataSizeString(networkUsage, formatting: DataSizeStringFormatting(presentationData: presentationData))))
    
    entries.append(.automaticDownloadHeader(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadTitle.uppercased()))
    entries.append(.automaticDownloadCellular(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadUsingCellular, stringForAutoDownloadSetting(strings: presentationData.strings, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator, settings: data.automaticMediaDownloadSettings, connectionType: .cellular)))
    entries.append(.automaticDownloadWifi(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadUsingWiFi, stringForAutoDownloadSetting(strings: presentationData.strings, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator, settings: data.automaticMediaDownloadSettings, connectionType: .wifi)))
    
    let defaultSettings = MediaAutoDownloadSettings.defaultSettings
    entries.append(.automaticDownloadReset(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadReset, data.automaticMediaDownloadSettings.cellular != defaultSettings.cellular || data.automaticMediaDownloadSettings.wifi != defaultSettings.wifi))
    
    entries.append(.autoSaveHeader(presentationData.strings.Settings_SaveToCameraRollSection))
    
    let privateLabelAndValue = autosaveLabelAndValue(presentationData: presentationData, settings: mediaAutoSaveSettings, peerType: .privateChats, exceptionPeers: autosaveExceptionPeers)
    let groupsLabelAndValue = autosaveLabelAndValue(presentationData: presentationData, settings: mediaAutoSaveSettings, peerType: .groups, exceptionPeers: autosaveExceptionPeers)
    let channelsLabelAndValue = autosaveLabelAndValue(presentationData: presentationData, settings: mediaAutoSaveSettings, peerType: .channels, exceptionPeers: autosaveExceptionPeers)
    
    entries.append(.autoSaveItem(index: 0, type: .privateChats, title: presentationData.strings.Notifications_PrivateChats, label: privateLabelAndValue.label, value: privateLabelAndValue.value))
    entries.append(.autoSaveItem(index: 1, type: .groups, title: presentationData.strings.Notifications_GroupChats, label: groupsLabelAndValue.label, value: groupsLabelAndValue.value))
    entries.append(.autoSaveItem(index: 2, type: .channels, title: presentationData.strings.Notifications_Channels, label: channelsLabelAndValue.label, value: channelsLabelAndValue.value))
    entries.append(.autoSaveInfo(presentationData.strings.Settings_SaveToCameraRollInfo))
    
    
    let dataSaving = effectiveDataSaving(for: data.voiceCallSettings, autodownloadSettings: data.autodownloadSettings)
    entries.append(.useLessVoiceData(presentationData.theme, presentationData.strings.ChatSettings_UseLessDataForCalls, dataSaving != .never))
    entries.append(.useLessVoiceDataInfo(presentationData.theme, presentationData.strings.CallSettings_UseLessDataLongDescription))
    
    entries.append(.otherHeader(presentationData.theme, presentationData.strings.ChatSettings_Other))
    if #available(iOSApplicationExtension 13.2, iOS 13.2, *) {
        entries.append(.shareSheet(presentationData.theme, presentationData.strings.ChatSettings_IntentsSettings))
    }
    entries.append(.saveEditedPhotos(presentationData.theme, presentationData.strings.Settings_SaveEditedPhotos, data.generatedMediaStoreSettings.storeEditedPhotos))
    entries.append(.openLinksIn(presentationData.theme, presentationData.strings.ChatSettings_OpenLinksIn, defaultWebBrowser))
    entries.append(.pauseMusicOnRecording(presentationData.theme, presentationData.strings.Settings_PauseMusicOnRecording, data.mediaInputSettings.pauseMusicOnRecording))
    entries.append(.raiseToListen(presentationData.theme, presentationData.strings.Settings_RaiseToListen, data.mediaInputSettings.enableRaiseToSpeak))
    entries.append(.raiseToListenInfo(presentationData.theme, presentationData.strings.Settings_RaiseToListenInfo))

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

public func dataAndStorageController(context: AccountContext, focusOnItemTag: DataAndStorageEntryTag? = nil) -> ViewController {
    let initialState = DataAndStorageControllerState()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    //let cacheUsagePromise = Promise<CacheUsageStatsResult?>()
    //cacheUsagePromise.set(cacheUsageStats(context: context))
    
    let updateSensitiveContentDisposable = MetaDisposable()
    actionsDisposable.add(updateSensitiveContentDisposable)
    
    let updatedContentSettingsConfiguration = contentSettingsConfiguration(network: context.account.network)
    |> map(Optional.init)
    let contentSettingsConfiguration = Promise<ContentSettingsConfiguration?>()
    contentSettingsConfiguration.set(.single(nil)
    |> then(updatedContentSettingsConfiguration))
    
    struct UsageData: Equatable {
        var network: Int64
        var storage: Int64
    }
    let usageSignal: Signal<UsageData, NoError> = combineLatest(
        context.account.postbox.mediaBox.storageBox.totalSize(),
        context.account.postbox.mediaBox.cacheStorageBox.totalSize(),
        accountNetworkUsageStats(account: context.account, reset: [])
    )
    |> map { disk1, disk2, networkStats -> UsageData in
        var network: Int64 = 0
        
        var keys: [KeyPath<NetworkUsageStats, Int64>] = []
        
        keys.append(\.generic.cellular.outgoing)
        keys.append(\.generic.cellular.incoming)
        keys.append(\.generic.wifi.incoming)
        keys.append(\.generic.wifi.outgoing)
        
        keys.append(\.image.cellular.outgoing)
        keys.append(\.image.cellular.incoming)
        keys.append(\.image.wifi.incoming)
        keys.append(\.image.wifi.outgoing)
        
        keys.append(\.video.cellular.outgoing)
        keys.append(\.video.cellular.incoming)
        keys.append(\.video.wifi.incoming)
        keys.append(\.video.wifi.outgoing)
        
        keys.append(\.audio.cellular.outgoing)
        keys.append(\.audio.cellular.incoming)
        keys.append(\.audio.wifi.incoming)
        keys.append(\.audio.wifi.outgoing)
        
        keys.append(\.file.cellular.outgoing)
        keys.append(\.file.cellular.incoming)
        keys.append(\.file.wifi.incoming)
        keys.append(\.file.wifi.outgoing)
        
        keys.append(\.call.cellular.outgoing)
        keys.append(\.call.cellular.incoming)
        keys.append(\.call.wifi.incoming)
        keys.append(\.call.wifi.outgoing)
        
        keys.append(\.sticker.cellular.outgoing)
        keys.append(\.sticker.cellular.incoming)
        keys.append(\.sticker.wifi.incoming)
        keys.append(\.sticker.wifi.outgoing)
        
        keys.append(\.voiceMessage.cellular.outgoing)
        keys.append(\.voiceMessage.cellular.incoming)
        keys.append(\.voiceMessage.wifi.incoming)
        keys.append(\.voiceMessage.wifi.outgoing)
        
        for key in keys {
            network += networkStats[keyPath: key]
        }
        
        return UsageData(network: network, storage: disk1 + disk2)
    }
    
    let dataAndStorageDataPromise = Promise<DataAndStorageData>()
    dataAndStorageDataPromise.set(context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.autodownloadSettings, ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings, ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings, ApplicationSpecificSharedDataKeys.voiceCallSettings, ApplicationSpecificSharedDataKeys.mediaInputSettings, SharedDataKeys.proxySettings])
    |> map { sharedData -> DataAndStorageData in
        var automaticMediaDownloadSettings: MediaAutoDownloadSettings
        if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings]?.get(MediaAutoDownloadSettings.self) {
            automaticMediaDownloadSettings = value
        } else {
            automaticMediaDownloadSettings = .defaultSettings
        }
        
        var autodownloadSettings: AutodownloadSettings
        if let value = sharedData.entries[SharedDataKeys.autodownloadSettings]?.get(AutodownloadSettings.self) {
            autodownloadSettings = value
            automaticMediaDownloadSettings = automaticMediaDownloadSettings.updatedWithAutodownloadSettings(autodownloadSettings)
        } else {
            autodownloadSettings = .defaultSettings
        }
        
        let generatedMediaStoreSettings: GeneratedMediaStoreSettings
        if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings]?.get(GeneratedMediaStoreSettings.self) {
            generatedMediaStoreSettings = value
        } else {
            generatedMediaStoreSettings = GeneratedMediaStoreSettings.defaultSettings
        }
        
        let mediaInputSettings: MediaInputSettings
        if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.mediaInputSettings]?.get(MediaInputSettings.self) {
            mediaInputSettings = value
        } else {
            mediaInputSettings = MediaInputSettings.defaultSettings
        }
        
        let voiceCallSettings: VoiceCallSettings
        if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.voiceCallSettings]?.get(VoiceCallSettings.self) {
            voiceCallSettings = value
        } else {
            voiceCallSettings = VoiceCallSettings.defaultSettings
        }
        
        var proxySettings: ProxySettings?
        if let value = sharedData.entries[SharedDataKeys.proxySettings]?.get(ProxySettings.self) {
            proxySettings = value
        }
        
        return DataAndStorageData(automaticMediaDownloadSettings: automaticMediaDownloadSettings, autodownloadSettings: autodownloadSettings, generatedMediaStoreSettings: generatedMediaStoreSettings, mediaInputSettings: mediaInputSettings, voiceCallSettings: voiceCallSettings, proxySettings: proxySettings)
    })
    
    let arguments = DataAndStorageControllerArguments(openStorageUsage: {
        pushControllerImpl?(StorageUsageScreen(context: context, makeStorageUsageExceptionsScreen: { category in
            return storageUsageExceptionsScreen(context: context, category: category)
        }))
    }, openNetworkUsage: {
        let mediaAutoDownloadSettings = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings])
        |> map { sharedData -> MediaAutoDownloadSettings in
            var automaticMediaDownloadSettings: MediaAutoDownloadSettings
            if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings]?.get(MediaAutoDownloadSettings.self) {
                automaticMediaDownloadSettings = value
            } else {
                automaticMediaDownloadSettings = .defaultSettings
            }
            return automaticMediaDownloadSettings
        }
        
        let _ = (combineLatest(
            accountNetworkUsageStats(account: context.account, reset: []),
            mediaAutoDownloadSettings
        )
        |> take(1)
        |> deliverOnMainQueue).start(next: { stats, mediaAutoDownloadSettings in
            var stats = stats
            
            if stats.resetWifiTimestamp == 0 {
                var value = stat()
                if stat(context.account.basePath, &value) == 0 {
                    stats.resetWifiTimestamp = Int32(value.st_ctimespec.tv_sec)
                }
            }
            
            pushControllerImpl?(DataUsageScreen(context: context, stats: stats, mediaAutoDownloadSettings: mediaAutoDownloadSettings, makeAutodownloadSettingsController: { isCellular in
                return autodownloadMediaConnectionTypeController(context: context, connectionType: isCellular ? .cellular : .wifi)
            }))
        })
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
    }, toggleVoiceUseLessData: { value in
        let _ = updateVoiceCallSettingsSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            var current = current
            current.dataSaving = value ? .always : .never
            return current
        }).start()
    }, openSaveIncoming: { type in
        pushControllerImpl?(saveIncomingMediaController(context: context, scope: .peerType(type)))
    }, toggleSaveEditedPhotos: { value in
        let _ = updateGeneratedMediaStoreSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return current.withUpdatedStoreEditedPhotos(value)
        }).start()
    }, togglePauseMusicOnRecording: { value in
        let _ = updateMediaInputSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return current.withUpdatedPauseMusicOnRecording(value)
        }).start()
    }, toggleRaiseToListen: { value in
        let _ = updateMediaInputSettingsInteractively(accountManager: context.sharedContext.accountManager, {
            $0.withUpdatedEnableRaiseToSpeak(value)
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
    
    let preferencesKey: PostboxViewKey = .preferences(keys: Set([ApplicationSpecificPreferencesKeys.mediaAutoSaveSettings]))
    let preferences = context.account.postbox.combinedView(keys: [preferencesKey])
    |> map { views -> MediaAutoSaveSettings in
        guard let view = views.views[preferencesKey] as? PreferencesView else {
            return .default
        }
        return view.values[ApplicationSpecificPreferencesKeys.mediaAutoSaveSettings]?.get(MediaAutoSaveSettings.self) ?? MediaAutoSaveSettings.default
    }
    
    let autosaveExceptionPeers: Signal<[EnginePeer.Id: EnginePeer?], NoError> = preferences
    |> mapToSignal { mediaAutoSaveSettings -> Signal<[EnginePeer.Id: EnginePeer?], NoError> in
        let peerIds = mediaAutoSaveSettings.exceptions.map(\.id)
        return context.engine.data.get(EngineDataMap(
            peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))
        ))
    }

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get(),
        dataAndStorageDataPromise.get(),
        context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.webBrowserSettings]),
        contentSettingsConfiguration.get(),
        preferences,
        usageSignal,
        autosaveExceptionPeers
    )
    |> map { presentationData, state, dataAndStorageData, sharedData, contentSettingsConfiguration, mediaAutoSaveSettings, usageSignal, autosaveExceptionPeers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let webBrowserSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.webBrowserSettings]?.get(WebBrowserSettings.self) ?? WebBrowserSettings.defaultSettings
        let options = availableOpenInOptions(context: context, item: .url(url: "https://telegram.org"))
        let defaultWebBrowser: String
        if let option = options.first(where: { $0.identifier == webBrowserSettings.defaultWebBrowser }) {
            defaultWebBrowser = option.title
        } else {
            defaultWebBrowser = presentationData.strings.WebBrowser_InAppSafari
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.ChatSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: dataAndStorageControllerEntries(state: state, data: dataAndStorageData, presentationData: presentationData, defaultWebBrowser: defaultWebBrowser, contentSettingsConfiguration: contentSettingsConfiguration, networkUsage: usageSignal.network, storageUsage: usageSignal.storage, mediaAutoSaveSettings: mediaAutoSaveSettings, autosaveExceptionPeers: autosaveExceptionPeers), style: .blocks, ensureVisibleItemTag: focusOnItemTag, emptyStateItem: nil, animateChanges: false)
        
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
