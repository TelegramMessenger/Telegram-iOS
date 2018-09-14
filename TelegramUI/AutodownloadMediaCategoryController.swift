import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

enum AutomaticDownloadCategory {
    case photo
    case video
    case file
    case voiceMessage
    case videoMessage
}

private enum ConnectionType {
    case cellular
    case wifi
}

private enum PeerType {
    case contact
    case otherPrivate
    case group
    case channel
}

private final class AutodownloadMediaCategoryControllerArguments {
    let toggle: (ConnectionType, PeerType) -> Void
    let adjustSize: (Int32) -> Void
    
    init(toggle: @escaping (ConnectionType, PeerType) -> Void, adjustSize: @escaping (Int32) -> Void) {
        self.toggle = toggle
        self.adjustSize = adjustSize
    }
}

private enum AutodownloadMediaCategorySection: Int32 {
    case cellular
    case wifi
    case size
}

private enum AutodownloadMediaCategoryEntry: ItemListNodeEntry {
    case cellularHeader(PresentationTheme, String)
    case cellularContacts(PresentationTheme, String, Bool)
    case cellularOtherPrivate(PresentationTheme, String, Bool)
    case cellularGroups(PresentationTheme, String, Bool)
    case cellularChannels(PresentationTheme, String, Bool)
    
    case wifiHeader(PresentationTheme, String)
    case wifiContacts(PresentationTheme, String, Bool)
    case wifiOtherPrivate(PresentationTheme, String, Bool)
    case wifiGroups(PresentationTheme, String, Bool)
    case wifiChannels(PresentationTheme, String, Bool)
    
    case sizeHeader(PresentationTheme, String)
    case sizeItem(PresentationTheme, String, Int32)
    
    var section: ItemListSectionId {
        switch self {
        case .cellularHeader, .cellularContacts, .cellularOtherPrivate, .cellularGroups, .cellularChannels:
            return AutodownloadMediaCategorySection.cellular.rawValue
        case .wifiHeader, .wifiContacts, .wifiOtherPrivate, .wifiGroups, .wifiChannels:
            return AutodownloadMediaCategorySection.wifi.rawValue
            case .sizeHeader, .sizeItem:
                return AutodownloadMediaCategorySection.size.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .cellularHeader:
                return 0
            case .cellularContacts:
                return 1
            case .cellularOtherPrivate:
                return 2
            case .cellularGroups:
                return 3
            case .cellularChannels:
                return 4
            case .wifiHeader:
                return 5
            case .wifiContacts:
                return 6
            case .wifiOtherPrivate:
                return 7
            case .wifiGroups:
                return 8
            case .wifiChannels:
                return 9
            case .sizeHeader:
                return 10
            case .sizeItem:
                return 11
        }
    }
    
    static func ==(lhs: AutodownloadMediaCategoryEntry, rhs: AutodownloadMediaCategoryEntry) -> Bool {
        switch lhs {
            case let .cellularHeader(lhsTheme, lhsText):
                if case let .cellularHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .cellularContacts(lhsTheme, lhsText, lhsValue):
                if case let .cellularContacts(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .cellularOtherPrivate(lhsTheme, lhsText, lhsValue):
                if case let .cellularOtherPrivate(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .cellularGroups(lhsTheme, lhsText, lhsValue):
                if case let .cellularGroups(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .cellularChannels(lhsTheme, lhsText, lhsValue):
                if case let .cellularChannels(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .wifiHeader(lhsTheme, lhsText):
                if case let .wifiHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .wifiContacts(lhsTheme, lhsText, lhsValue):
                if case let .wifiContacts(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .wifiOtherPrivate(lhsTheme, lhsText, lhsValue):
                if case let .wifiOtherPrivate(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .wifiGroups(lhsTheme, lhsText, lhsValue):
                if case let .wifiGroups(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .wifiChannels(lhsTheme, lhsText, lhsValue):
                if case let .wifiChannels(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .sizeHeader(lhsTheme, lhsText):
                if case let .sizeHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .sizeItem(lhsTheme, lhsText, lhsValue):
                if case let .sizeItem(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: AutodownloadMediaCategoryEntry, rhs: AutodownloadMediaCategoryEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: AutodownloadMediaCategoryControllerArguments) -> ListViewItem {
        switch self {
            case let .cellularHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .cellularContacts(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggle(.cellular, .contact)
                })
            case let .cellularOtherPrivate(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggle(.cellular, .otherPrivate)
                })
            case let .cellularGroups(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggle(.cellular, .group)
                })
            case let .cellularChannels(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggle(.cellular, .channel)
                })
            case let .wifiHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .wifiContacts(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggle(.wifi, .contact)
                })
            case let .wifiOtherPrivate(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggle(.wifi, .otherPrivate)
                })
            case let .wifiGroups(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggle(.wifi, .group)
                })
            case let .wifiChannels(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggle(.wifi, .channel)
                })
            case let .sizeHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .sizeItem(theme, text, value):
                return AutodownloadSizeLimitItem(theme: theme, text: text, value: value, sectionId: self.section, updated: { value in
                    arguments.adjustSize(value)
                })
        }
    }
}

private struct AutodownloadMediaCategoryControllerState: Equatable {
}

private struct AutomaticDownloadPeers {
    let contacts: Bool
    let otherPrivate: Bool
    let groups: Bool
    let channels: Bool
}

private func autodownloadMediaCategoryControllerEntries(presentationData: PresentationData, category: AutomaticDownloadCategory, settings: AutomaticMediaDownloadSettings) -> [AutodownloadMediaCategoryEntry] {
    var entries: [AutodownloadMediaCategoryEntry] = []
    
    let cellular: AutomaticDownloadPeers
    let wifi: AutomaticDownloadPeers
    let size: Int32
    
    switch category {
        case .photo:
            cellular = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.photo.cellular,
                otherPrivate: settings.peers.otherPrivate.photo.cellular,
                groups: settings.peers.groups.photo.cellular,
                channels: settings.peers.channels.photo.cellular
            )
            wifi = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.photo.wifi,
                otherPrivate: settings.peers.otherPrivate.photo.wifi,
                groups: settings.peers.groups.photo.wifi,
                channels: settings.peers.channels.photo.wifi
            )
            size = settings.peers.contacts.photo.sizeLimit
        case .video:
            cellular = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.video.cellular,
                otherPrivate: settings.peers.otherPrivate.video.cellular,
                groups: settings.peers.groups.video.cellular,
                channels: settings.peers.channels.video.cellular
            )
            wifi = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.video.wifi,
                otherPrivate: settings.peers.otherPrivate.video.wifi,
                groups: settings.peers.groups.video.wifi,
                channels: settings.peers.channels.video.wifi
            )
            size = settings.peers.contacts.video.sizeLimit
        case .file:
            cellular = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.file.cellular,
                otherPrivate: settings.peers.otherPrivate.file.cellular,
                groups: settings.peers.groups.file.cellular,
                channels: settings.peers.channels.file.cellular
            )
            wifi = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.file.wifi,
                otherPrivate: settings.peers.otherPrivate.file.wifi,
                groups: settings.peers.groups.file.wifi,
                channels: settings.peers.channels.file.wifi
            )
            size = settings.peers.contacts.file.sizeLimit
        case .voiceMessage:
            cellular = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.voiceMessage.cellular,
                otherPrivate: settings.peers.otherPrivate.voiceMessage.cellular,
                groups: settings.peers.groups.voiceMessage.cellular,
                channels: settings.peers.channels.voiceMessage.cellular
            )
            wifi = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.voiceMessage.wifi,
                otherPrivate: settings.peers.otherPrivate.voiceMessage.wifi,
                groups: settings.peers.groups.voiceMessage.wifi,
                channels: settings.peers.channels.voiceMessage.wifi
            )
            size = settings.peers.contacts.voiceMessage.sizeLimit
        case .videoMessage:
            cellular = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.videoMessage.cellular,
                otherPrivate: settings.peers.otherPrivate.videoMessage.cellular,
                groups: settings.peers.groups.videoMessage.cellular,
                channels: settings.peers.channels.videoMessage.cellular
            )
            wifi = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.videoMessage.wifi,
                otherPrivate: settings.peers.otherPrivate.videoMessage.wifi,
                groups: settings.peers.groups.videoMessage.wifi,
                channels: settings.peers.channels.videoMessage.wifi
            )
            size = settings.peers.contacts.videoMessage.sizeLimit
    }
    
    entries.append(.cellularHeader(presentationData.theme, presentationData.strings.AutoDownloadSettings_Cellular))
    entries.append(.cellularContacts(presentationData.theme, presentationData.strings.AutoDownloadSettings_Contacts, cellular.contacts))
    entries.append(.cellularOtherPrivate(presentationData.theme, presentationData.strings.AutoDownloadSettings_PrivateChats, cellular.otherPrivate))
    entries.append(.cellularGroups(presentationData.theme, presentationData.strings.AutoDownloadSettings_GroupChats, cellular.groups))
    entries.append(.cellularChannels(presentationData.theme, presentationData.strings.AutoDownloadSettings_Channels, cellular.channels))
    
    entries.append(.wifiHeader(presentationData.theme, presentationData.strings.AutoDownloadSettings_WiFi))
    entries.append(.wifiContacts(presentationData.theme, presentationData.strings.AutoDownloadSettings_Contacts, wifi.contacts))
    entries.append(.wifiOtherPrivate(presentationData.theme, presentationData.strings.AutoDownloadSettings_PrivateChats, wifi.otherPrivate))
    entries.append(.wifiGroups(presentationData.theme, presentationData.strings.AutoDownloadSettings_GroupChats, wifi.groups))
    entries.append(.wifiChannels(presentationData.theme, presentationData.strings.AutoDownloadSettings_Channels, wifi.channels))
    
    switch category {
        case .file, .video:
            entries.append(.sizeHeader(presentationData.theme, presentationData.strings.AutoDownloadSettings_LimitBySize))
            let text: String
            if size == Int32.max {
                text = presentationData.strings.AutoDownloadSettings_Unlimited
            } else {
                text = presentationData.strings.AutoDownloadSettings_UpTo(dataSizeString(Int(size))).0
            }
            entries.append(.sizeItem(presentationData.theme, text, size))
        default:
            break
    }
    
    return entries
}

func autodownloadMediaCategoryController(account: Account, category: AutomaticDownloadCategory) -> ViewController {
    let arguments = AutodownloadMediaCategoryControllerArguments(toggle: { connection, type in
        let _ = updateMediaDownloadSettingsInteractively(postbox: account.postbox, { settings in
            var settings = settings
            switch category {
                case .photo:
                    switch type {
                        case .contact:
                            switch connection {
                                case .cellular:
                                    settings.peers.contacts.photo.cellular = !settings.peers.contacts.photo.cellular
                                case .wifi:
                                    settings.peers.contacts.photo.wifi = !settings.peers.contacts.photo.wifi
                            }
                        case .otherPrivate:
                            switch connection {
                                case .cellular:
                                    settings.peers.otherPrivate.photo.cellular = !settings.peers.otherPrivate.photo.cellular
                                case .wifi:
                                    settings.peers.otherPrivate.photo.wifi = !settings.peers.otherPrivate.photo.wifi
                            }
                        case .group:
                            switch connection {
                                case .cellular:
                                    settings.peers.groups.photo.cellular = !settings.peers.groups.photo.cellular
                                case .wifi:
                                    settings.peers.groups.photo.wifi = !settings.peers.groups.photo.wifi
                            }
                        case .channel:
                            switch connection {
                                case .cellular:
                                    settings.peers.channels.photo.cellular = !settings.peers.channels.photo.cellular
                                case .wifi:
                                    settings.peers.channels.photo.wifi = !settings.peers.channels.photo.wifi
                            }
                    }
                case .video:
                    switch type {
                    case .contact:
                        switch connection {
                        case .cellular:
                            settings.peers.contacts.video.cellular = !settings.peers.contacts.video.cellular
                        case .wifi:
                            settings.peers.contacts.video.wifi = !settings.peers.contacts.video.wifi
                        }
                    case .otherPrivate:
                        switch connection {
                        case .cellular:
                            settings.peers.otherPrivate.video.cellular = !settings.peers.otherPrivate.video.cellular
                        case .wifi:
                            settings.peers.otherPrivate.video.wifi = !settings.peers.otherPrivate.video.wifi
                        }
                    case .group:
                        switch connection {
                        case .cellular:
                            settings.peers.groups.video.cellular = !settings.peers.groups.video.cellular
                        case .wifi:
                            settings.peers.groups.video.wifi = !settings.peers.groups.video.wifi
                        }
                    case .channel:
                        switch connection {
                        case .cellular:
                            settings.peers.channels.video.cellular = !settings.peers.channels.video.cellular
                        case .wifi:
                            settings.peers.channels.video.wifi = !settings.peers.channels.video.wifi
                        }
                    }
                case .file:
                    switch type {
                    case .contact:
                        switch connection {
                        case .cellular:
                            settings.peers.contacts.file.cellular = !settings.peers.contacts.file.cellular
                        case .wifi:
                            settings.peers.contacts.file.wifi = !settings.peers.contacts.file.wifi
                        }
                    case .otherPrivate:
                        switch connection {
                        case .cellular:
                            settings.peers.otherPrivate.file.cellular = !settings.peers.otherPrivate.file.cellular
                        case .wifi:
                            settings.peers.otherPrivate.file.wifi = !settings.peers.otherPrivate.file.wifi
                        }
                    case .group:
                        switch connection {
                        case .cellular:
                            settings.peers.groups.file.cellular = !settings.peers.groups.file.cellular
                        case .wifi:
                            settings.peers.groups.file.wifi = !settings.peers.groups.file.wifi
                        }
                    case .channel:
                        switch connection {
                        case .cellular:
                            settings.peers.channels.file.cellular = !settings.peers.channels.file.cellular
                        case .wifi:
                            settings.peers.channels.file.wifi = !settings.peers.channels.file.wifi
                        }
                    }
                case .voiceMessage:
                    switch type {
                    case .contact:
                        switch connection {
                        case .cellular:
                            settings.peers.contacts.voiceMessage.cellular = !settings.peers.contacts.voiceMessage.cellular
                        case .wifi:
                            settings.peers.contacts.voiceMessage.wifi = !settings.peers.contacts.voiceMessage.wifi
                        }
                    case .otherPrivate:
                        switch connection {
                        case .cellular:
                            settings.peers.otherPrivate.voiceMessage.cellular = !settings.peers.otherPrivate.voiceMessage.cellular
                        case .wifi:
                            settings.peers.otherPrivate.voiceMessage.wifi = !settings.peers.otherPrivate.voiceMessage.wifi
                        }
                    case .group:
                        switch connection {
                        case .cellular:
                            settings.peers.groups.voiceMessage.cellular = !settings.peers.groups.voiceMessage.cellular
                        case .wifi:
                            settings.peers.groups.voiceMessage.wifi = !settings.peers.groups.voiceMessage.wifi
                        }
                    case .channel:
                        switch connection {
                        case .cellular:
                            settings.peers.channels.voiceMessage.cellular = !settings.peers.channels.voiceMessage.cellular
                        case .wifi:
                            settings.peers.channels.voiceMessage.wifi = !settings.peers.channels.file.wifi
                        }
                    }
                case .videoMessage:
                    switch type {
                    case .contact:
                        switch connection {
                        case .cellular:
                            settings.peers.contacts.videoMessage.cellular = !settings.peers.contacts.videoMessage.cellular
                        case .wifi:
                            settings.peers.contacts.videoMessage.wifi = !settings.peers.contacts.videoMessage.wifi
                        }
                    case .otherPrivate:
                        switch connection {
                        case .cellular:
                            settings.peers.otherPrivate.videoMessage.cellular = !settings.peers.otherPrivate.videoMessage.cellular
                        case .wifi:
                            settings.peers.otherPrivate.videoMessage.wifi = !settings.peers.otherPrivate.videoMessage.wifi
                        }
                    case .group:
                        switch connection {
                        case .cellular:
                            settings.peers.groups.videoMessage.cellular = !settings.peers.groups.videoMessage.cellular
                        case .wifi:
                            settings.peers.groups.videoMessage.wifi = !settings.peers.groups.videoMessage.wifi
                        }
                    case .channel:
                        switch connection {
                        case .cellular:
                            settings.peers.channels.videoMessage.cellular = !settings.peers.channels.videoMessage.cellular
                        case .wifi:
                            settings.peers.channels.videoMessage.wifi = !settings.peers.channels.file.wifi
                        }
                    }
            }
            return settings
        }).start()
    }, adjustSize: { size in
        let _ = updateMediaDownloadSettingsInteractively(postbox: account.postbox, { settings in
            var settings = settings
            switch category {
                case .photo:
                    settings.peers.contacts.photo.sizeLimit = size
                    settings.peers.otherPrivate.photo.sizeLimit = size
                    settings.peers.groups.photo.sizeLimit = size
                    settings.peers.channels.photo.sizeLimit = size
                case .video:
                    settings.peers.contacts.video.sizeLimit = size
                    settings.peers.otherPrivate.video.sizeLimit = size
                    settings.peers.groups.video.sizeLimit = size
                    settings.peers.channels.video.sizeLimit = size
                case .file:
                    settings.peers.contacts.file.sizeLimit = size
                    settings.peers.otherPrivate.file.sizeLimit = size
                    settings.peers.groups.file.sizeLimit = size
                    settings.peers.channels.file.sizeLimit = size
                case .videoMessage:
                    settings.peers.contacts.videoMessage.sizeLimit = size
                    settings.peers.otherPrivate.videoMessage.sizeLimit = size
                    settings.peers.groups.videoMessage.sizeLimit = size
                    settings.peers.channels.videoMessage.sizeLimit = size
                case .voiceMessage:
                    settings.peers.contacts.voiceMessage.sizeLimit = size
                    settings.peers.otherPrivate.voiceMessage.sizeLimit = size
                    settings.peers.groups.voiceMessage.sizeLimit = size
                    settings.peers.channels.voiceMessage.sizeLimit = size
            }
            return settings
        }).start()
    })
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings])) |> deliverOnMainQueue
        |> map { presentationData, prefs -> (ItemListControllerState, (ItemListNodeState<AutodownloadMediaCategoryEntry>, AutodownloadMediaCategoryEntry.ItemGenerationArguments)) in
            let automaticMediaDownloadSettings: AutomaticMediaDownloadSettings
            if let value = prefs.values[ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings] as? AutomaticMediaDownloadSettings {
                automaticMediaDownloadSettings = value
            } else {
                automaticMediaDownloadSettings = AutomaticMediaDownloadSettings.defaultSettings
            }
            
            let title: String
            switch category {
                case .photo:
                    title = presentationData.strings.AutoDownloadSettings_PhotosTitle
                case .video:
                    title = presentationData.strings.AutoDownloadSettings_VideosTitle
                case .file:
                    title = presentationData.strings.AutoDownloadSettings_DocumentsTitle
                case .voiceMessage:
                    title = presentationData.strings.AutoDownloadSettings_VoiceMessagesTitle
                case .videoMessage:
                    title = presentationData.strings.AutoDownloadSettings_VideoMessagesTitle
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(entries: autodownloadMediaCategoryControllerEntries(presentationData: presentationData, category: category, settings: automaticMediaDownloadSettings), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(account: account, state: signal)
    return controller
}

