import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents

private final class DataAndStorageControllerArguments {
    let openStorageUsage: () -> Void
    let openNetworkUsage: () -> Void
    let openProxy: () -> Void
    let openAutomaticDownloadConnectionType: (AutomaticDownloadConnectionType) -> Void
    let openVoiceUseLessData: () -> Void
    let openSaveIncomingPhotos: () -> Void
    let toggleSaveEditedPhotos: (Bool) -> Void
    let toggleAutoplayGifs: (Bool) -> Void
    let toggleAutoplayVideos: (Bool) -> Void
    let toggleDownloadInBackground: (Bool) -> Void
    
    init(openStorageUsage: @escaping () -> Void, openNetworkUsage: @escaping () -> Void, openProxy: @escaping () -> Void,  openAutomaticDownloadConnectionType: @escaping (AutomaticDownloadConnectionType) -> Void, openVoiceUseLessData: @escaping () -> Void, openSaveIncomingPhotos: @escaping () -> Void, toggleSaveEditedPhotos: @escaping (Bool) -> Void, toggleAutoplayGifs: @escaping (Bool) -> Void, toggleAutoplayVideos: @escaping (Bool) -> Void, toggleDownloadInBackground: @escaping (Bool) -> Void) {
        self.openStorageUsage = openStorageUsage
        self.openNetworkUsage = openNetworkUsage
        self.openProxy = openProxy
        self.openAutomaticDownloadConnectionType = openAutomaticDownloadConnectionType
        self.openVoiceUseLessData = openVoiceUseLessData
        self.openSaveIncomingPhotos = openSaveIncomingPhotos
        self.toggleSaveEditedPhotos = toggleSaveEditedPhotos
        self.toggleAutoplayGifs = toggleAutoplayGifs
        self.toggleAutoplayVideos = toggleAutoplayVideos
        self.toggleDownloadInBackground = toggleDownloadInBackground
    }
}

private enum DataAndStorageSection: Int32 {
    case usage
    case autoDownload
    case autoPlay
    case voiceCalls
    case other
    case connection
}

private enum DataAndStorageEntry: ItemListNodeEntry {
    case storageUsage(PresentationTheme, String)
    case networkUsage(PresentationTheme, String)
    case automaticDownloadHeader(PresentationTheme, String)
    case automaticDownloadCellular(PresentationTheme, String, String)
    case automaticDownloadWifi(PresentationTheme, String, String)
    case autoplayHeader(PresentationTheme, String)
    case autoplayGifs(PresentationTheme, String, Bool)
    case autoplayVideos(PresentationTheme, String, Bool)
    case voiceCallsHeader(PresentationTheme, String)
    case useLessVoiceData(PresentationTheme, String, String)
    case otherHeader(PresentationTheme, String)
    case saveIncomingPhotos(PresentationTheme, String)
    case saveEditedPhotos(PresentationTheme, String, Bool)
    case downloadInBackground(PresentationTheme, String, Bool)
    case downloadInBackgroundInfo(PresentationTheme, String)
    case connectionHeader(PresentationTheme, String)
    case connectionProxy(PresentationTheme, String, String)
    
    var section: ItemListSectionId {
        switch self {
            case .storageUsage, .networkUsage:
                return DataAndStorageSection.usage.rawValue
            case .automaticDownloadHeader, .automaticDownloadCellular, .automaticDownloadWifi:
                return DataAndStorageSection.autoDownload.rawValue
            case .autoplayHeader, .autoplayGifs, .autoplayVideos:
                return DataAndStorageSection.autoPlay.rawValue
            case .voiceCallsHeader, .useLessVoiceData:
                return DataAndStorageSection.voiceCalls.rawValue
            case .otherHeader, .saveIncomingPhotos, .saveEditedPhotos, .downloadInBackground, .downloadInBackgroundInfo:
                return DataAndStorageSection.other.rawValue
            case .connectionHeader, .connectionProxy:
                return DataAndStorageSection.connection.rawValue
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
            case .autoplayHeader:
                return 5
            case .autoplayGifs:
                return 6
            case .autoplayVideos:
                return 7
            case .voiceCallsHeader:
                return 8
            case .useLessVoiceData:
                return 9
            case .otherHeader:
                return 10
            case .saveIncomingPhotos:
                return 11
            case .saveEditedPhotos:
                return 12
            case .downloadInBackground:
                return 13
            case .downloadInBackgroundInfo:
                return 14
            case .connectionHeader:
                return 15
            case .connectionProxy:
                return 16
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
        }
    }
    
    static func <(lhs: DataAndStorageEntry, rhs: DataAndStorageEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: DataAndStorageControllerArguments) -> ListViewItem {
        switch self {
            case let .storageUsage(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openStorageUsage()
                })
            case let .networkUsage(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openNetworkUsage()
                })
            case let .automaticDownloadHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .automaticDownloadCellular(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, labelStyle: .detailText, sectionId: self.section, style: .blocks, action: {
                    arguments.openAutomaticDownloadConnectionType(.cellular)
                })
            case let .automaticDownloadWifi(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, labelStyle: .detailText, sectionId: self.section, style: .blocks, action: {
                    arguments.openAutomaticDownloadConnectionType(.wifi)
                })
            case let .autoplayHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .autoplayGifs(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutoplayGifs(value)
                })
            case let .autoplayVideos(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutoplayVideos(value)
                })
            case let .voiceCallsHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .useLessVoiceData(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openVoiceUseLessData()
                })
            case let .otherHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .saveIncomingPhotos(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openSaveIncomingPhotos()
                })
            case let .saveEditedPhotos(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleSaveEditedPhotos(value)
                })
            case let .downloadInBackground(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleDownloadInBackground(value)
                })
            case let .downloadInBackgroundInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .connectionHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .connectionProxy(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openProxy()
                })
        }
    }
}

private struct DataAndStorageControllerState: Equatable {
    static func ==(lhs: DataAndStorageControllerState, rhs: DataAndStorageControllerState) -> Bool {
        return true
    }
}

private struct DataAndStorageData: Equatable {
    let automaticMediaDownloadSettings: AutomaticMediaDownloadSettings
    let generatedMediaStoreSettings: GeneratedMediaStoreSettings
    let voiceCallSettings: VoiceCallSettings
    let proxySettings: ProxySettings?
    
    init(automaticMediaDownloadSettings: AutomaticMediaDownloadSettings, generatedMediaStoreSettings: GeneratedMediaStoreSettings, voiceCallSettings: VoiceCallSettings, proxySettings: ProxySettings?) {
        self.automaticMediaDownloadSettings = automaticMediaDownloadSettings
        self.generatedMediaStoreSettings = generatedMediaStoreSettings
        self.voiceCallSettings = voiceCallSettings
        self.proxySettings = proxySettings
    }
    
    static func ==(lhs: DataAndStorageData, rhs: DataAndStorageData) -> Bool {
        return lhs.automaticMediaDownloadSettings == rhs.automaticMediaDownloadSettings && lhs.generatedMediaStoreSettings == rhs.generatedMediaStoreSettings && lhs.voiceCallSettings == rhs.voiceCallSettings && lhs.proxySettings == rhs.proxySettings
    }
}

private func stringForUseLessDataSetting(strings: PresentationStrings, settings: VoiceCallSettings) -> String {
    switch settings.dataSaving {
        case .never:
            return strings.CallSettings_Never
        case .cellular:
            return strings.CallSettings_OnMobile
        case .always:
            return strings.CallSettings_Always
    }
}

private func stringForAutoDownloadTypes(strings: PresentationStrings, photo: Bool, video: Bool, file: Bool, videoMessage: Bool, voiceMessage: Bool) -> String {
    if photo && video && file && videoMessage && voiceMessage {
        return strings.ChatSettings_AutoDownloadSettings_OnForAll
    } else {
        var types: [String] = []
        if photo {
            types.append(strings.ChatSettings_AutoDownloadSettings_TypePhoto)
        }
        if video {
            types.append(strings.ChatSettings_AutoDownloadSettings_TypeVideo)
        }
        if file {
            types.append(strings.ChatSettings_AutoDownloadSettings_TypeFile)
        }
        if videoMessage {
            types.append(strings.ChatSettings_AutoDownloadSettings_TypeVideoMessage)
        }
        if voiceMessage {
            types.append(strings.ChatSettings_AutoDownloadSettings_TypeVoiceMessage)
        }
        
        if types.isEmpty {
            return strings.ChatSettings_AutoDownloadSettings_OffForAll
        }
        
        var string: String = ""
        for i in 0 ..< types.count {
            if !string.isEmpty {
                if i == types.count - 1 {
                    string.append(strings.ChatSettings_AutoDownloadSettings_LastDelimeter)
                } else {
                    string.append(strings.ChatSettings_AutoDownloadSettings_Delimeter)
                }
            }
            string.append(types[i])
        }
        return strings.ChatSettings_AutoDownloadSettings_OnFor(string).0
    }
}

private func stringForAutoDownloadSetting(strings: PresentationStrings, settings: AutomaticMediaDownloadSettings, connectionType: AutomaticDownloadConnectionType) -> String {
    switch connectionType {
        case .cellular:
            if !settings.cellularEnabled {
                return strings.ChatSettings_AutoDownloadSettings_OffForAll
            } else {
                let photo = settings.peers.contacts.photo.cellular || settings.peers.otherPrivate.photo.cellular || settings.peers.groups.photo.cellular || settings.peers.channels.photo.cellular
                let video = settings.peers.contacts.video.cellular || settings.peers.otherPrivate.video.cellular || settings.peers.groups.video.cellular || settings.peers.channels.video.cellular
                let file = settings.peers.contacts.file.cellular || settings.peers.otherPrivate.file.cellular || settings.peers.groups.file.cellular || settings.peers.channels.file.cellular
                let videoMessage = settings.peers.contacts.videoMessage.cellular || settings.peers.otherPrivate.videoMessage.cellular || settings.peers.groups.videoMessage.cellular || settings.peers.channels.videoMessage.cellular
                let voiceMessage = settings.peers.contacts.voiceMessage.cellular || settings.peers.otherPrivate.voiceMessage.cellular || settings.peers.groups.voiceMessage.cellular || settings.peers.channels.voiceMessage.cellular
                return stringForAutoDownloadTypes(strings: strings, photo: photo, video: video, file: file, videoMessage: videoMessage, voiceMessage: voiceMessage)
            }
        case .wifi:
            if !settings.wifiEnabled {
                return strings.ChatSettings_AutoDownloadSettings_OffForAll
            } else {
                let photo = settings.peers.contacts.photo.wifi || settings.peers.otherPrivate.photo.wifi || settings.peers.groups.photo.wifi || settings.peers.channels.photo.wifi
                let video = settings.peers.contacts.video.wifi || settings.peers.otherPrivate.video.wifi || settings.peers.groups.video.wifi || settings.peers.channels.video.wifi
                let file = settings.peers.contacts.file.wifi || settings.peers.otherPrivate.file.wifi || settings.peers.groups.file.wifi || settings.peers.channels.file.wifi
                let videoMessage = settings.peers.contacts.videoMessage.wifi || settings.peers.otherPrivate.videoMessage.wifi || settings.peers.groups.videoMessage.wifi || settings.peers.channels.videoMessage.wifi
                let voiceMessage = settings.peers.contacts.voiceMessage.wifi || settings.peers.otherPrivate.voiceMessage.wifi || settings.peers.groups.voiceMessage.wifi || settings.peers.channels.voiceMessage.wifi
                return stringForAutoDownloadTypes(strings: strings, photo: photo, video: video, file: file, videoMessage: videoMessage, voiceMessage: voiceMessage)
            }
    }
}

private func dataAndStorageControllerEntries(state: DataAndStorageControllerState, data: DataAndStorageData, presentationData: PresentationData) -> [DataAndStorageEntry] {
    var entries: [DataAndStorageEntry] = []
    
    entries.append(.storageUsage(presentationData.theme, presentationData.strings.ChatSettings_Cache))
    entries.append(.networkUsage(presentationData.theme, presentationData.strings.NetworkUsageSettings_Title))
    
    entries.append(.automaticDownloadHeader(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadTitle))
    entries.append(.automaticDownloadCellular(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadUsingCellular, stringForAutoDownloadSetting(strings: presentationData.strings, settings: data.automaticMediaDownloadSettings, connectionType: .cellular)))
    entries.append(.automaticDownloadWifi(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadUsingWiFi, stringForAutoDownloadSetting(strings: presentationData.strings, settings: data.automaticMediaDownloadSettings, connectionType: .wifi)))
    
    entries.append(.autoplayHeader(presentationData.theme, presentationData.strings.ChatSettings_AutoPlayTitle))
    entries.append(.autoplayGifs(presentationData.theme, presentationData.strings.ChatSettings_AutoPlayGifs, data.automaticMediaDownloadSettings.autoplayGifs))
    entries.append(.autoplayVideos(presentationData.theme, presentationData.strings.ChatSettings_AutoPlayVideos, data.automaticMediaDownloadSettings.autoplayVideos))
    
    entries.append(.voiceCallsHeader(presentationData.theme, presentationData.strings.Settings_CallSettings.uppercased()))
    entries.append(.useLessVoiceData(presentationData.theme, presentationData.strings.CallSettings_UseLessData, stringForUseLessDataSetting(strings: presentationData.strings, settings: data.voiceCallSettings)))
    
    entries.append(.otherHeader(presentationData.theme, presentationData.strings.ChatSettings_Other))
    entries.append(.saveIncomingPhotos(presentationData.theme, presentationData.strings.Settings_SaveIncomingPhotos))
    entries.append(.saveEditedPhotos(presentationData.theme, presentationData.strings.Settings_SaveEditedPhotos, data.generatedMediaStoreSettings.storeEditedPhotos))
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
    
    return entries
}

func dataAndStorageController(context: AccountContext) -> ViewController {
    let initialState = DataAndStorageControllerState()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let dataAndStorageDataPromise = Promise<DataAndStorageData>()
    dataAndStorageDataPromise.set(context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings, ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings, ApplicationSpecificSharedDataKeys.voiceCallSettings, SharedDataKeys.proxySettings])
    |> map { sharedData -> DataAndStorageData in
        let automaticMediaDownloadSettings: AutomaticMediaDownloadSettings
        if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings] as? AutomaticMediaDownloadSettings {
            automaticMediaDownloadSettings = value
        } else {
            automaticMediaDownloadSettings = AutomaticMediaDownloadSettings.defaultSettings
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
        
        return DataAndStorageData(automaticMediaDownloadSettings: automaticMediaDownloadSettings, generatedMediaStoreSettings: generatedMediaStoreSettings, voiceCallSettings: voiceCallSettings, proxySettings: proxySettings)
    })
    
    let arguments = DataAndStorageControllerArguments(openStorageUsage: {
        pushControllerImpl?(storageUsageController(context: context))
    }, openNetworkUsage: {
        pushControllerImpl?(networkUsageStatsController(context: context))
    }, openProxy: {
        pushControllerImpl?(proxySettingsController(context: context))
    }, openAutomaticDownloadConnectionType: { connectionType in
        pushControllerImpl?(autodownloadMediaConnectionTypeController(context: context, connectionType: connectionType))
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
    },  toggleDownloadInBackground: { value in
        let _ = updateMediaDownloadSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.downloadInBackground = value
            return settings
        }).start()
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), dataAndStorageDataPromise.get()) |> deliverOnMainQueue
        |> map { presentationData, state, dataAndStorageData -> (ItemListControllerState, (ItemListNodeState<DataAndStorageEntry>, DataAndStorageEntry.ItemGenerationArguments)) in
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.ChatSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(entries: dataAndStorageControllerEntries(state: state, data: dataAndStorageData, presentationData: presentationData), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
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
