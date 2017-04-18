import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramLegacyComponents

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
    case storageUsage(String)
    case networkUsage(String)
    case automaticPhotoDownloadHeader(String)
    case automaticPhotoDownloadPrivateChats(String, Bool)
    case automaticPhotoDownloadGroupsAndChannels(String, Bool)
    case automaticVoiceDownloadHeader(String)
    case automaticVoiceDownloadPrivateChats(String, Bool)
    case automaticVoiceDownloadGroupsAndChannels(String, Bool)
    case automaticInstantVideoDownloadHeader(String)
    case automaticInstantVideoDownloadPrivateChats(String, Bool)
    case automaticInstantVideoDownloadGroupsAndChannels(String, Bool)
    case voiceCallsHeader(String)
    case useLessVoiceData(String, String)
    case otherHeader(String)
    case saveIncomingPhotos(String, Bool)
    case saveEditedPhotos(String, Bool)
    
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
            case let .storageUsage(text):
                if case .storageUsage(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .networkUsage(text):
                if case .networkUsage(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .automaticPhotoDownloadHeader(text):
                if case .automaticPhotoDownloadHeader(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .automaticPhotoDownloadPrivateChats(text, value):
                if case .automaticPhotoDownloadPrivateChats(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .automaticPhotoDownloadGroupsAndChannels(text, value):
                if case .automaticPhotoDownloadGroupsAndChannels(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .automaticVoiceDownloadHeader(text):
                if case .automaticVoiceDownloadHeader(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .automaticVoiceDownloadPrivateChats(text, value):
                if case .automaticVoiceDownloadPrivateChats(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .automaticVoiceDownloadGroupsAndChannels(text, value):
                if case .automaticVoiceDownloadGroupsAndChannels(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .automaticInstantVideoDownloadHeader(text):
                if case .automaticInstantVideoDownloadHeader(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .automaticInstantVideoDownloadPrivateChats(text, value):
                if case .automaticInstantVideoDownloadPrivateChats(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .automaticInstantVideoDownloadGroupsAndChannels(text, value):
                if case .automaticInstantVideoDownloadGroupsAndChannels(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .voiceCallsHeader(text):
                if case .voiceCallsHeader(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .useLessVoiceData(text, value):
                if case .useLessVoiceData(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .otherHeader(text):
                if case .otherHeader(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .saveIncomingPhotos(text, value):
                if case .saveIncomingPhotos(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .saveEditedPhotos(text, value):
                if case .saveEditedPhotos(text, value) = rhs {
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
            case let .storageUsage(text):
                return ItemListDisclosureItem(title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openStorageUsage()
                })
            case let .networkUsage(text):
                return ItemListDisclosureItem(title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openNetworkUsage()
                })
            case let .automaticPhotoDownloadHeader(text):
                return ItemListSectionHeaderItem(text: text, sectionId: self.section)
            case let .automaticPhotoDownloadPrivateChats(text, value):
                return ItemListSwitchItem(title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutomaticDownload(.photo, .privateChats, value)
                })
            case let .automaticPhotoDownloadGroupsAndChannels(text, value):
                return ItemListSwitchItem(title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutomaticDownload(.photo, .groupsAndChannels, value)
                })
            case let .automaticVoiceDownloadHeader(text):
                return ItemListSectionHeaderItem(text: text, sectionId: self.section)
            case let .automaticVoiceDownloadPrivateChats(text, value):
                return ItemListSwitchItem(title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutomaticDownload(.voice, .privateChats, value)
                })
            case let .automaticVoiceDownloadGroupsAndChannels(text, value):
                return ItemListSwitchItem(title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutomaticDownload(.voice, .groupsAndChannels, value)
                })
            case let .automaticInstantVideoDownloadHeader(text):
                return ItemListSectionHeaderItem(text: text, sectionId: self.section)
            case let .automaticInstantVideoDownloadPrivateChats(text, value):
                return ItemListSwitchItem(title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutomaticDownload(.instantVideo, .privateChats, value)
                })
            case let .automaticInstantVideoDownloadGroupsAndChannels(text, value):
                return ItemListSwitchItem(title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAutomaticDownload(.instantVideo, .groupsAndChannels, value)
                })
            case let .voiceCallsHeader(text):
                return ItemListSectionHeaderItem(text: text, sectionId: self.section)
            case let .useLessVoiceData(text, value):
                return ItemListDisclosureItem(title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openVoiceUseLessData()
                })
            case let .otherHeader(text):
                return ItemListSectionHeaderItem(text: text, sectionId: self.section)
            case let .saveIncomingPhotos(text, value):
                return ItemListSwitchItem(title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleSaveIncomingPhotos(value)
                })
            case let .saveEditedPhotos(text, value):
                return ItemListSwitchItem(title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
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

private func dataAndStorageControllerEntries(state: DataAndStorageControllerState, data: DataAndStorageData) -> [DataAndStorageEntry] {
    var entries: [DataAndStorageEntry] = []
    
    entries.append(.storageUsage("Storage Usage"))
    entries.append(.networkUsage("Network Usage"))
    
    entries.append(.automaticPhotoDownloadHeader("AUTOMATIC PHOTO DOWNLOAD"))
    entries.append(.automaticPhotoDownloadPrivateChats("Private Chats", data.automaticMediaDownloadSettings.categories.photo.privateChats))
    entries.append(.automaticPhotoDownloadGroupsAndChannels("Groups and Channels", data.automaticMediaDownloadSettings.categories.photo.groupsAndChannels))
    
    entries.append(.automaticVoiceDownloadHeader("AUTOMATIC AUDIO DOWNLOAD"))
    entries.append(.automaticVoiceDownloadPrivateChats("Private Chats", data.automaticMediaDownloadSettings.categories.voice.privateChats))
    entries.append(.automaticVoiceDownloadGroupsAndChannels("Groups and Channels", data.automaticMediaDownloadSettings.categories.voice.groupsAndChannels))
    
    entries.append(.automaticInstantVideoDownloadHeader("AUTOMATIC VIDEO MESSAGE DOWNLOAD"))
    entries.append(.automaticInstantVideoDownloadPrivateChats("Private Chats", data.automaticMediaDownloadSettings.categories.instantVideo.privateChats))
    entries.append(.automaticInstantVideoDownloadGroupsAndChannels("Groups and Channels", data.automaticMediaDownloadSettings.categories.instantVideo.groupsAndChannels))
    
    /*entries.append(.automaticGifDownloadHeader("AUTOMATIC GIF DOWNLOAD"))
    entries.append(.automaticGifDownloadPrivateChats("Private Chats", data.automaticMediaDownloadSettings.categories.gif.privateChats))
    entries.append(.automaticGifDownloadGroupsAndChannels("Groups and Channels", data.automaticMediaDownloadSettings.categories.gif.groupsAndChannels))*/
    
    entries.append(.voiceCallsHeader("VOICE CALLS"))
    entries.append(.useLessVoiceData("Use Less Data", stringForUseLessDataSetting(data.voiceCallSettings)))
    
    entries.append(.otherHeader("OTHER"))
    entries.append(.saveIncomingPhotos("Save Incoming Photos", data.automaticMediaDownloadSettings.saveIncomingPhotos))
    entries.append(.saveEditedPhotos("Save Edited Photos", data.generatedMediaStoreSettings.storeEditedPhotos))
    
    return entries
}

func dataAndStorageController(account: Account) -> ViewController {
    let initialState = DataAndStorageControllerState()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((DataAndStorageControllerState) -> DataAndStorageControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
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
    
    let signal = combineLatest(statePromise.get(), dataAndStorageDataPromise.get()) |> deliverOnMainQueue
        |> map { state, dataAndStorageData -> (ItemListControllerState, (ItemListNodeState<DataAndStorageEntry>, DataAndStorageEntry.ItemGenerationArguments)) in
            
            let controllerState = ItemListControllerState(title: .text("Data and Storage"), leftNavigationButton: nil, rightNavigationButton: nil, animateChanges: false)
            let listState = ItemListNodeState(entries: dataAndStorageControllerEntries(state: state, data: dataAndStorageData), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(signal)
    controller.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
    
    pushControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.pushViewController(c)
        }
    }
    
    return controller
}
