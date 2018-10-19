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
    let toggleAutomaticDownloadMaster: (Bool) -> Void
    let openAutomaticDownloadCategory: (AutomaticDownloadCategory) -> Void
    let resetAutomaticDownload: () -> Void
    let openVoiceUseLessData: () -> Void
    let openSaveIncomingPhotos: () -> Void
    let toggleSaveEditedPhotos: (Bool) -> Void
    let toggleAutoplayGifs: (Bool) -> Void
    
    init(openStorageUsage: @escaping () -> Void, openNetworkUsage: @escaping () -> Void, openProxy: @escaping () -> Void, toggleAutomaticDownloadMaster: @escaping (Bool) -> Void, openAutomaticDownloadCategory: @escaping (AutomaticDownloadCategory) -> Void, resetAutomaticDownload: @escaping () -> Void, openVoiceUseLessData: @escaping () -> Void, openSaveIncomingPhotos: @escaping () -> Void, toggleSaveEditedPhotos: @escaping (Bool) -> Void, toggleAutoplayGifs: @escaping (Bool) -> Void) {
        self.openStorageUsage = openStorageUsage
        self.openNetworkUsage = openNetworkUsage
        self.openProxy = openProxy
        self.toggleAutomaticDownloadMaster = toggleAutomaticDownloadMaster
        self.openAutomaticDownloadCategory = openAutomaticDownloadCategory
        self.resetAutomaticDownload = resetAutomaticDownload
        self.openVoiceUseLessData = openVoiceUseLessData
        self.openSaveIncomingPhotos = openSaveIncomingPhotos
        self.toggleSaveEditedPhotos = toggleSaveEditedPhotos
        self.toggleAutoplayGifs = toggleAutoplayGifs
    }
}

private enum DataAndStorageSection: Int32 {
    case usage
    case automaticMediaDownload
    case voiceCalls
    case other
    case connection
}

private enum DataAndStorageEntry: ItemListNodeEntry {
    case storageUsage(PresentationTheme, String)
    case networkUsage(PresentationTheme, String)
    case automaticMediaDownloadHeader(PresentationTheme, String)
    case automaticDownloadMaster(PresentationTheme, String, Bool)
    case automaticDownloadPhoto(PresentationTheme, String, Bool)
    case automaticDownloadVideo(PresentationTheme, String, Bool)
    case automaticDownloadFile(PresentationTheme, String, Bool)
    case automaticDownloadVoiceMessage(PresentationTheme, String, Bool)
    case automaticDownloadVideoMessage(PresentationTheme, String, Bool)
    case automaticDownloadReset(PresentationTheme, String, Bool)
    case voiceCallsHeader(PresentationTheme, String)
    case useLessVoiceData(PresentationTheme, String, String)
    case otherHeader(PresentationTheme, String)
    case saveIncomingPhotos(PresentationTheme, String)
    case saveEditedPhotos(PresentationTheme, String, Bool)
    case autoplayGifs(PresentationTheme, String, Bool)
    case connectionHeader(PresentationTheme, String)
    case connectionProxy(PresentationTheme, String, String)
    
    var section: ItemListSectionId {
        switch self {
            case .storageUsage, .networkUsage:
                return DataAndStorageSection.usage.rawValue
            case .automaticMediaDownloadHeader, .automaticDownloadMaster, .automaticDownloadPhoto, .automaticDownloadVideo, .automaticDownloadFile, .automaticDownloadVideoMessage, .automaticDownloadVoiceMessage, .automaticDownloadReset:
                return DataAndStorageSection.automaticMediaDownload.rawValue
            case .voiceCallsHeader, .useLessVoiceData:
                return DataAndStorageSection.voiceCalls.rawValue
            case .otherHeader, .saveIncomingPhotos, .saveEditedPhotos, .autoplayGifs:
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
            case .automaticMediaDownloadHeader:
                return 2
            case .automaticDownloadMaster:
                return 3
            case .automaticDownloadPhoto:
                return 4
            case .automaticDownloadVideo:
                return 5
            case .automaticDownloadFile:
                return 6
            case .automaticDownloadVoiceMessage:
                return 7
            case .automaticDownloadVideoMessage:
                return 8
            case .automaticDownloadReset:
                return 9
            case .voiceCallsHeader:
                return 11
            case .useLessVoiceData:
                return 12
            case .otherHeader:
                return 13
            case .saveIncomingPhotos:
                return 14
            case .saveEditedPhotos:
                return 15
            case .autoplayGifs:
                return 16
            case .connectionHeader:
                return 17
            case .connectionProxy:
                return 18
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
            case let .automaticMediaDownloadHeader(lhsTheme, lhsText):
                if case let .automaticMediaDownloadHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .automaticDownloadMaster(lhsTheme, lhsText, lhsValue):
                if case let .automaticDownloadMaster(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .automaticDownloadPhoto(lhsTheme, lhsText, lhsEnabled):
                if case let .automaticDownloadPhoto(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .automaticDownloadVideo(lhsTheme, lhsText, lhsEnabled):
                if case let .automaticDownloadVideo(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .automaticDownloadFile(lhsTheme, lhsText, lhsEnabled):
                if case let .automaticDownloadFile(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .automaticDownloadVoiceMessage(lhsTheme, lhsText, lhsEnabled):
                if case let .automaticDownloadVoiceMessage(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .automaticDownloadVideoMessage(lhsTheme, lhsText, lhsEnabled):
                if case let .automaticDownloadVideoMessage(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
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
            case let .autoplayGifs(lhsTheme, lhsText, lhsValue):
                if case let .autoplayGifs(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
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
            case let .automaticMediaDownloadHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .automaticDownloadMaster(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutomaticDownloadMaster(value)
                })
            case let .automaticDownloadPhoto(theme, text, enabled):
                return ItemListDisclosureItem(theme: theme, title: text, kind: enabled ? .generic : .disabled,  label: "", sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    if enabled {
                        arguments.openAutomaticDownloadCategory(.photo)
                    }
                })
            case let .automaticDownloadVideo(theme, text, enabled):
                return ItemListDisclosureItem(theme: theme, title: text, kind: enabled ? .generic : .disabled, label: "", sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    if enabled {
                        arguments.openAutomaticDownloadCategory(.video)
                    }
                })
            case let .automaticDownloadFile(theme, text, enabled):
                return ItemListDisclosureItem(theme: theme, title: text, kind: enabled ? .generic : .disabled, label: "", sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    if enabled {
                        arguments.openAutomaticDownloadCategory(.file)
                    }
                })
            case let .automaticDownloadVoiceMessage(theme, text, enabled):
                return ItemListDisclosureItem(theme: theme, title: text, kind: enabled ? .generic : .disabled, label: "", sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    if enabled {
                        arguments.openAutomaticDownloadCategory(.voiceMessage)
                    }
                })
            case let .automaticDownloadVideoMessage(theme, text, enabled):
                return ItemListDisclosureItem(theme: theme, title: text, kind: enabled ? .generic : .disabled, label: "", sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    if enabled {
                        arguments.openAutomaticDownloadCategory(.videoMessage)
                    }
                })
            case let .automaticDownloadReset(theme, text, enabled):
                return ItemListActionItem(theme: theme, title: text, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    if enabled {
                        arguments.resetAutomaticDownload()
                    }
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
            case let .autoplayGifs(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutoplayGifs(value)
                })
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

private func dataAndStorageControllerEntries(state: DataAndStorageControllerState, data: DataAndStorageData, presentationData: PresentationData) -> [DataAndStorageEntry] {
    var entries: [DataAndStorageEntry] = []
    
    entries.append(.storageUsage(presentationData.theme, presentationData.strings.Cache_Title))
    entries.append(.networkUsage(presentationData.theme, presentationData.strings.NetworkUsageSettings_Title))
    
    entries.append(.automaticMediaDownloadHeader(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadTitle))
    entries.append(.automaticDownloadMaster(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadEnabled, data.automaticMediaDownloadSettings.masterEnabled))
    entries.append(.automaticDownloadPhoto(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadPhotos, data.automaticMediaDownloadSettings.masterEnabled))
    entries.append(.automaticDownloadVideo(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadVideos, data.automaticMediaDownloadSettings.masterEnabled))
    entries.append(.automaticDownloadFile(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadDocuments, data.automaticMediaDownloadSettings.masterEnabled))
    entries.append(.automaticDownloadVoiceMessage(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadVoiceMessages, data.automaticMediaDownloadSettings.masterEnabled))
    entries.append(.automaticDownloadVideoMessage(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadVideoMessages,data.automaticMediaDownloadSettings.masterEnabled))
    entries.append(.automaticDownloadReset(presentationData.theme, presentationData.strings.ChatSettings_AutoDownloadReset, data.automaticMediaDownloadSettings.peers != AutomaticMediaDownloadSettings.defaultSettings.peers || !data.automaticMediaDownloadSettings.masterEnabled))
    
    entries.append(.voiceCallsHeader(presentationData.theme, presentationData.strings.Settings_CallSettings.uppercased()))
    entries.append(.useLessVoiceData(presentationData.theme, presentationData.strings.CallSettings_UseLessData, stringForUseLessDataSetting(strings: presentationData.strings, settings: data.voiceCallSettings)))
    
    entries.append(.otherHeader(presentationData.theme, presentationData.strings.ChatSettings_Other))
    entries.append(.saveIncomingPhotos(presentationData.theme, presentationData.strings.Settings_SaveIncomingPhotos))
    entries.append(.saveEditedPhotos(presentationData.theme, presentationData.strings.Settings_SaveEditedPhotos, data.generatedMediaStoreSettings.storeEditedPhotos))
    entries.append(.autoplayGifs(presentationData.theme, presentationData.strings.ChatSettings_AutoPlayAnimations, data.automaticMediaDownloadSettings.autoplayGifs))
    
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

func dataAndStorageController(account: Account) -> ViewController {
    let initialState = DataAndStorageControllerState()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let dataAndStorageDataPromise = Promise<DataAndStorageData>()
    dataAndStorageDataPromise.set(account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings, ApplicationSpecificPreferencesKeys.generatedMediaStoreSettings, ApplicationSpecificPreferencesKeys.voiceCallSettings,
        PreferencesKeys.proxySettings])
        |> map { view -> DataAndStorageData in
            let automaticMediaDownloadSettings: AutomaticMediaDownloadSettings
            if let value = view.values[ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings] as? AutomaticMediaDownloadSettings {
                automaticMediaDownloadSettings = value
            } else {
                automaticMediaDownloadSettings = AutomaticMediaDownloadSettings.defaultSettings
            }
            
            let generatedMediaStoreSettings: GeneratedMediaStoreSettings
            if let value = view.values[ApplicationSpecificPreferencesKeys.generatedMediaStoreSettings] as? GeneratedMediaStoreSettings {
                generatedMediaStoreSettings = value
            } else {
                generatedMediaStoreSettings = GeneratedMediaStoreSettings.defaultSettings
            }
            
            let voiceCallSettings: VoiceCallSettings
            if let value = view.values[ApplicationSpecificPreferencesKeys.voiceCallSettings] as? VoiceCallSettings {
                voiceCallSettings = value
            } else {
                voiceCallSettings = VoiceCallSettings.defaultSettings
            }
            
            var proxySettings: ProxySettings?
            if let value = view.values[PreferencesKeys.proxySettings] as? ProxySettings {
                proxySettings = value
            }
            
            return DataAndStorageData(automaticMediaDownloadSettings: automaticMediaDownloadSettings, generatedMediaStoreSettings: generatedMediaStoreSettings, voiceCallSettings: voiceCallSettings, proxySettings: proxySettings)
        })
    
    let arguments = DataAndStorageControllerArguments(openStorageUsage: {
        pushControllerImpl?(storageUsageController(account: account))
    }, openNetworkUsage: {
        pushControllerImpl?(networkUsageStatsController(account: account))
    }, openProxy: {
        pushControllerImpl?(proxySettingsController(account: account))
    }, toggleAutomaticDownloadMaster: { value in
        let _ = updateMediaDownloadSettingsInteractively(postbox: account.postbox, { settings in
            var settings = settings
            settings.masterEnabled = value
            return settings
        }).start()
    }, openAutomaticDownloadCategory: { category in
        pushControllerImpl?(autodownloadMediaCategoryController(account: account, category: category))
    }, resetAutomaticDownload: {
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetTextItem(title: presentationData.strings.AutoDownloadSettings_ResetHelp),
            ActionSheetButtonItem(title: presentationData.strings.AutoDownloadSettings_Reset, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                let _ = updateMediaDownloadSettingsInteractively(postbox: account.postbox, { settings in
                    var settings = settings
                    let defaultSettings = AutomaticMediaDownloadSettings.defaultSettings
                    settings.masterEnabled = defaultSettings.masterEnabled
                    settings.peers = defaultSettings.peers
                    return settings
                }).start()
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    }, openVoiceUseLessData: {
        pushControllerImpl?(voiceCallDataSavingController(account: account))
    }, openSaveIncomingPhotos: {
        pushControllerImpl?(saveIncomingMediaController(account: account))
    }, toggleSaveEditedPhotos: { value in
        let _ = updateGeneratedMediaStoreSettingsInteractively(postbox: account.postbox, { current in
            return current.withUpdatedStoreEditedPhotos(value)
        }).start()
    }, toggleAutoplayGifs: { value in
        let _ = updateMediaDownloadSettingsInteractively(postbox: account.postbox, { settings in
            var settings = settings
            settings.autoplayGifs = value
            return settings
        }).start()
    })
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), dataAndStorageDataPromise.get()) |> deliverOnMainQueue
        |> map { presentationData, state, dataAndStorageData -> (ItemListControllerState, (ItemListNodeState<DataAndStorageEntry>, DataAndStorageEntry.ItemGenerationArguments)) in
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.ChatSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(entries: dataAndStorageControllerEntries(state: state, data: dataAndStorageData, presentationData: presentationData), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(account: account, state: signal)
    
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
