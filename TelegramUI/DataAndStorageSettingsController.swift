import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents

private enum AutomaticDownloadCategory {
    case photo
    case voice
    case instantVideo
    case gif
}

private enum AutomaticDownloadPeers {
    case privateChats
    case groupsAndChannels
}

private final class DataAndStorageControllerArguments {
    let openStorageUsage: () -> Void
    let openNetworkUsage: () -> Void
    let toggleAutomaticDownload: (AutomaticDownloadCategory, AutomaticDownloadPeers, Bool) -> Void
    let openVoiceUseLessData: () -> Void
    let toggleSaveIncomingPhotos: (Bool) -> Void
    let toggleSaveEditedPhotos: (Bool) -> Void
    
    init(openStorageUsage: @escaping () -> Void, openNetworkUsage: @escaping () -> Void, toggleAutomaticDownload: @escaping (AutomaticDownloadCategory, AutomaticDownloadPeers, Bool) -> Void, openVoiceUseLessData: @escaping () -> Void, toggleSaveIncomingPhotos: @escaping (Bool) -> Void, toggleSaveEditedPhotos: @escaping (Bool) -> Void) {
        self.openStorageUsage = openStorageUsage
        self.openNetworkUsage = openNetworkUsage
        self.toggleAutomaticDownload = toggleAutomaticDownload
        self.openVoiceUseLessData = openVoiceUseLessData
        self.toggleSaveIncomingPhotos = toggleSaveIncomingPhotos
        self.toggleSaveEditedPhotos = toggleSaveEditedPhotos
    }
}

private enum DataAndStorageSection: Int32 {
    case usage
    case automaticPhotoDownload
    case automaticVoiceDownload
    case automaticInstantVideoDownload
    case voiceCalls
    case other
}

private enum DataAndStorageEntry: ItemListNodeEntry {
    case storageUsage(PresentationTheme, String)
    case networkUsage(PresentationTheme, String)
    case automaticPhotoDownloadHeader(PresentationTheme, String)
    case automaticPhotoDownloadPrivateChats(PresentationTheme, String, Bool)
    case automaticPhotoDownloadGroupsAndChannels(PresentationTheme, String, Bool)
    case automaticVoiceDownloadHeader(PresentationTheme, String)
    case automaticVoiceDownloadPrivateChats(PresentationTheme, String, Bool)
    case automaticVoiceDownloadGroupsAndChannels(PresentationTheme, String, Bool)
    case automaticInstantVideoDownloadHeader(PresentationTheme, String)
    case automaticInstantVideoDownloadPrivateChats(PresentationTheme, String, Bool)
    case automaticInstantVideoDownloadGroupsAndChannels(PresentationTheme, String, Bool)
    case voiceCallsHeader(PresentationTheme, String)
    case useLessVoiceData(PresentationTheme, String, String)
    case otherHeader(PresentationTheme, String)
    case saveIncomingPhotos(PresentationTheme, String, Bool)
    case saveEditedPhotos(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .storageUsage, .networkUsage:
                return DataAndStorageSection.usage.rawValue
            case .automaticPhotoDownloadHeader, .automaticPhotoDownloadPrivateChats, .automaticPhotoDownloadGroupsAndChannels:
                return DataAndStorageSection.automaticPhotoDownload.rawValue
            case .automaticVoiceDownloadHeader, .automaticVoiceDownloadPrivateChats, .automaticVoiceDownloadGroupsAndChannels:
                return DataAndStorageSection.automaticVoiceDownload.rawValue
            case .automaticInstantVideoDownloadHeader, .automaticInstantVideoDownloadPrivateChats, .automaticInstantVideoDownloadGroupsAndChannels:
                return DataAndStorageSection.automaticInstantVideoDownload.rawValue
            case .voiceCallsHeader, .useLessVoiceData:
                return DataAndStorageSection.voiceCalls.rawValue
            case .otherHeader, .saveIncomingPhotos, .saveEditedPhotos:
                return DataAndStorageSection.other.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .storageUsage:
                return 0
            case .networkUsage:
                return 1
            case .automaticPhotoDownloadHeader:
                return 2
            case .automaticPhotoDownloadPrivateChats:
                return 3
            case .automaticPhotoDownloadGroupsAndChannels:
                return 4
            case .automaticVoiceDownloadHeader:
                return 5
            case .automaticVoiceDownloadPrivateChats:
                return 6
            case .automaticVoiceDownloadGroupsAndChannels:
                return 7
            case .automaticInstantVideoDownloadHeader:
                return 8
            case .automaticInstantVideoDownloadPrivateChats:
                return 9
            case .automaticInstantVideoDownloadGroupsAndChannels:
                return 10
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
            case let .automaticPhotoDownloadHeader(lhsTheme, lhsText):
                if case let .automaticPhotoDownloadHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .automaticPhotoDownloadPrivateChats(lhsTheme, lhsText, lhsValue):
                if case let .automaticPhotoDownloadPrivateChats(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .automaticPhotoDownloadGroupsAndChannels(lhsTheme, lhsText, lhsValue):
                if case let .automaticPhotoDownloadGroupsAndChannels(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .automaticVoiceDownloadHeader(lhsTheme, lhsText):
                if case let .automaticVoiceDownloadHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .automaticVoiceDownloadPrivateChats(lhsTheme, lhsText, lhsValue):
                if case let .automaticVoiceDownloadPrivateChats(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .automaticVoiceDownloadGroupsAndChannels(lhsTheme, lhsText, lhsValue):
                if case let .automaticVoiceDownloadGroupsAndChannels(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .automaticInstantVideoDownloadHeader(lhsTheme, lhsText):
                if case let .automaticInstantVideoDownloadHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .automaticInstantVideoDownloadPrivateChats(lhsTheme, lhsText, lhsValue):
                if case let .automaticInstantVideoDownloadPrivateChats(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .automaticInstantVideoDownloadGroupsAndChannels(lhsTheme, lhsText, lhsValue):
                if case let .automaticInstantVideoDownloadGroupsAndChannels(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
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
            case let .saveIncomingPhotos(lhsTheme, lhsText, lhsValue):
                if case let .saveIncomingPhotos(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
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
            case let .automaticPhotoDownloadHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .automaticPhotoDownloadPrivateChats(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutomaticDownload(.photo, .privateChats, value)
                })
            case let .automaticPhotoDownloadGroupsAndChannels(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutomaticDownload(.photo, .groupsAndChannels, value)
                })
            case let .automaticVoiceDownloadHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .automaticVoiceDownloadPrivateChats(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutomaticDownload(.voice, .privateChats, value)
                })
            case let .automaticVoiceDownloadGroupsAndChannels(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutomaticDownload(.voice, .groupsAndChannels, value)
                })
            case let .automaticInstantVideoDownloadHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .automaticInstantVideoDownloadPrivateChats(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutomaticDownload(.instantVideo, .privateChats, value)
                })
            case let .automaticInstantVideoDownloadGroupsAndChannels(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutomaticDownload(.instantVideo, .groupsAndChannels, value)
                })
            case let .voiceCallsHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .useLessVoiceData(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openVoiceUseLessData()
                })
            case let .otherHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .saveIncomingPhotos(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleSaveIncomingPhotos(value)
                })
            case let .saveEditedPhotos(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleSaveEditedPhotos(value)
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
    
    init(automaticMediaDownloadSettings: AutomaticMediaDownloadSettings, generatedMediaStoreSettings: GeneratedMediaStoreSettings, voiceCallSettings: VoiceCallSettings) {
        self.automaticMediaDownloadSettings = automaticMediaDownloadSettings
        self.generatedMediaStoreSettings = generatedMediaStoreSettings
        self.voiceCallSettings = voiceCallSettings
    }
    
    static func ==(lhs: DataAndStorageData, rhs: DataAndStorageData) -> Bool {
        return lhs.automaticMediaDownloadSettings == rhs.automaticMediaDownloadSettings && lhs.generatedMediaStoreSettings == rhs.generatedMediaStoreSettings && lhs.voiceCallSettings == rhs.voiceCallSettings
    }
}

private func stringForUseLessDataSetting(_ settings: VoiceCallSettings) -> String {
    switch settings.dataSaving {
        case .never:
            return "Never"
        case .cellular:
            return "On Mobile Network"
        case .always:
            return "Always"
    }
}

private func dataAndStorageControllerEntries(state: DataAndStorageControllerState, data: DataAndStorageData, presentationData: PresentationData) -> [DataAndStorageEntry] {
    var entries: [DataAndStorageEntry] = []
    
    entries.append(.storageUsage(presentationData.theme, "Storage Usage"))
    entries.append(.networkUsage(presentationData.theme, "Network Usage"))
    
    entries.append(.automaticPhotoDownloadHeader(presentationData.theme, "AUTOMATIC PHOTO DOWNLOAD"))
    entries.append(.automaticPhotoDownloadPrivateChats(presentationData.theme, "Private Chats", data.automaticMediaDownloadSettings.categories.photo.privateChats))
    entries.append(.automaticPhotoDownloadGroupsAndChannels(presentationData.theme, "Groups and Channels", data.automaticMediaDownloadSettings.categories.photo.groupsAndChannels))
    
    entries.append(.automaticVoiceDownloadHeader(presentationData.theme, "AUTOMATIC AUDIO DOWNLOAD"))
    entries.append(.automaticVoiceDownloadPrivateChats(presentationData.theme, "Private Chats", data.automaticMediaDownloadSettings.categories.voice.privateChats))
    entries.append(.automaticVoiceDownloadGroupsAndChannels(presentationData.theme, "Groups and Channels", data.automaticMediaDownloadSettings.categories.voice.groupsAndChannels))
    
    entries.append(.automaticInstantVideoDownloadHeader(presentationData.theme, "AUTOMATIC VIDEO MESSAGE DOWNLOAD"))
    entries.append(.automaticInstantVideoDownloadPrivateChats(presentationData.theme, "Private Chats", data.automaticMediaDownloadSettings.categories.instantVideo.privateChats))
    entries.append(.automaticInstantVideoDownloadGroupsAndChannels(presentationData.theme, "Groups and Channels", data.automaticMediaDownloadSettings.categories.instantVideo.groupsAndChannels))
    
    /*entries.append(.automaticGifDownloadHeader("AUTOMATIC GIF DOWNLOAD"))
    entries.append(.automaticGifDownloadPrivateChats("Private Chats", data.automaticMediaDownloadSettings.categories.gif.privateChats))
    entries.append(.automaticGifDownloadGroupsAndChannels("Groups and Channels", data.automaticMediaDownloadSettings.categories.gif.groupsAndChannels))*/
    
    entries.append(.voiceCallsHeader(presentationData.theme, "VOICE CALLS"))
    entries.append(.useLessVoiceData(presentationData.theme, "Use Less Data", stringForUseLessDataSetting(data.voiceCallSettings)))
    
    entries.append(.otherHeader(presentationData.theme, "OTHER"))
    entries.append(.saveIncomingPhotos(presentationData.theme, "Save Incoming Photos", data.automaticMediaDownloadSettings.saveIncomingPhotos))
    entries.append(.saveEditedPhotos(presentationData.theme, "Save Edited Photos", data.generatedMediaStoreSettings.storeEditedPhotos))
    
    return entries
}

func dataAndStorageController(account: Account) -> ViewController {
    let initialState = DataAndStorageControllerState()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let dataAndStorageDataPromise = Promise<DataAndStorageData>()
    dataAndStorageDataPromise.set(account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings, ApplicationSpecificPreferencesKeys.generatedMediaStoreSettings, ApplicationSpecificPreferencesKeys.voiceCallSettings])
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
            
            return DataAndStorageData(automaticMediaDownloadSettings: automaticMediaDownloadSettings, generatedMediaStoreSettings: generatedMediaStoreSettings, voiceCallSettings: voiceCallSettings)
        })
    
    let arguments = DataAndStorageControllerArguments(openStorageUsage: {
        pushControllerImpl?(storageUsageController(account: account))
    }, openNetworkUsage: {
        pushControllerImpl?(networkUsageStatsController(account: account))
    }, toggleAutomaticDownload: { category, peers, value in
        let _ = updateMediaDownloadSettingsInteractively(postbox: account.postbox, { current in
            switch category {
                case .photo:
                    switch peers {
                        case .privateChats:
                            return current.withUpdatedCategories(current.categories.withUpdatedPhoto(current.categories.photo.withUpdatedPrivateChats(value)))
                        case .groupsAndChannels:
                            return current.withUpdatedCategories(current.categories.withUpdatedPhoto(current.categories.photo.withUpdatedGroupsAndChannels(value)))
                    }
                case .voice:
                    switch peers {
                        case .privateChats:
                            return current.withUpdatedCategories(current.categories.withUpdatedVoice(current.categories.voice.withUpdatedPrivateChats(value)))
                        case .groupsAndChannels:
                            return current.withUpdatedCategories(current.categories.withUpdatedVoice(current.categories.voice.withUpdatedGroupsAndChannels(value)))
                    }
                case .instantVideo:
                    switch peers {
                        case .privateChats:
                            return current.withUpdatedCategories(current.categories.withUpdatedInstantVideo(current.categories.instantVideo.withUpdatedPrivateChats(value)))
                        case .groupsAndChannels:
                            return current.withUpdatedCategories(current.categories.withUpdatedInstantVideo(current.categories.instantVideo.withUpdatedGroupsAndChannels(value)))
                    }
                case .gif:
                    switch peers {
                        case .privateChats:
                            return current.withUpdatedCategories(current.categories.withUpdatedGif(current.categories.gif.withUpdatedPrivateChats(value)))
                        case .groupsAndChannels:
                            return current.withUpdatedCategories(current.categories.withUpdatedGif(current.categories.gif.withUpdatedGroupsAndChannels(value)))
                    }
            }
        }).start()
    }, openVoiceUseLessData: {
        pushControllerImpl?(voiceCallDataSavingController(account: account))
    }, toggleSaveIncomingPhotos: { value in
        let _ = updateMediaDownloadSettingsInteractively(postbox: account.postbox, { current in
            return current.withUpdatedSaveIncomingPhotos(value)
        }).start()
    }, toggleSaveEditedPhotos: { value in
        let _ = updateGeneratedMediaStoreSettingsInteractively(postbox: account.postbox, { current in
            return current.withUpdatedStoreEditedPhotos(value)
        }).start()
    })
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), dataAndStorageDataPromise.get()) |> deliverOnMainQueue
        |> map { presentationData, state, dataAndStorageData -> (ItemListControllerState, (ItemListNodeState<DataAndStorageEntry>, DataAndStorageEntry.ItemGenerationArguments)) in
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text("Data and Storage"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: "Back"), animateChanges: false)
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
    
    return controller
}
