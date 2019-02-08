import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private enum AutomaticDownloadCategory {
    case photo
    case video
    case file
    case voiceMessage
    case videoMessage
}

enum AutomaticDownloadConnectionType {
    case cellular
    case wifi
}

private struct PeerType: OptionSet {
    let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let contact = PeerType(rawValue: 1 << 0)
    public static let otherPrivate = PeerType(rawValue: 1 << 1)
    public static let group = PeerType(rawValue: 1 << 2)
    public static let channel = PeerType(rawValue: 1 << 3)
}

private final class AutodownloadMediaConnectionTypeControllerArguments {
    let toggleMaster: (Bool) -> Void
    let customize: (AutomaticDownloadCategory) -> Void
    let reset: () -> Void
    
    init(toggleMaster: @escaping (Bool) -> Void, customize: @escaping (AutomaticDownloadCategory) -> Void, reset: @escaping () -> Void) {
        self.toggleMaster = toggleMaster
        self.customize = customize
        self.reset = reset
    }
}

private enum AutodownloadMediaCategorySection: Int32 {
    case master
    case types
    case reset
}

private enum AutodownloadMediaCategoryEntry: ItemListNodeEntry {
    case master(PresentationTheme, String, Bool)
    case typesHeader(PresentationTheme, String)
    case photos(PresentationTheme, String, String, Bool)
    case videos(PresentationTheme, String, String, Bool)
    case files(PresentationTheme, String, String, Bool)
    case videoMessages(PresentationTheme, String, String, Bool)
    case voiceMessages(PresentationTheme, String, String, Bool)
    case typesInfo(PresentationTheme, String)
    
    case reset(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .master:
                return AutodownloadMediaCategorySection.master.rawValue
            case .typesHeader, .photos, .videos, .files, .videoMessages, .voiceMessages, .typesInfo:
                return AutodownloadMediaCategorySection.types.rawValue
            case .reset:
                return AutodownloadMediaCategorySection.reset.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .master:
                return 0
            case .typesHeader:
                return 1
            case .photos:
                return 2
            case .videos:
                return 3
            case .files:
                return 4
            case .videoMessages:
                return 5
            case .voiceMessages:
                return 6
            case .typesInfo:
                return 7
            case .reset:
                return 8
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
        case let .videoMessages(lhsTheme, lhsText, lhsValue, lhsEnabled):
            if case let .videoMessages(rhsTheme, rhsText, rhsValue, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsEnabled == rhsEnabled {
                return true
            } else {
                return false
            }
        case let .voiceMessages(lhsTheme, lhsText, lhsValue, lhsEnabled):
            if case let .voiceMessages(rhsTheme, rhsText, rhsValue, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsEnabled == rhsEnabled {
                return true
            } else {
                return false
            }
        case let .typesInfo(lhsTheme, lhsText):
            if case let .typesInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .reset(lhsTheme, lhsTitle, lhsEnabled):
            if case let .reset(rhsTheme, rhsTitle, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsEnabled == rhsEnabled {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: AutodownloadMediaCategoryEntry, rhs: AutodownloadMediaCategoryEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: AutodownloadMediaConnectionTypeControllerArguments) -> ListViewItem {
        switch self {
            case let .master(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleMaster(value)
                })
            case let .typesHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .photos(theme, text, value, enabled):
                return ItemListDisclosureItem(theme: theme, title: text, enabled: enabled, label: value, labelStyle: .detailText, sectionId: self.section, style: .blocks, action: {
                    arguments.customize(.photo)
                })
            case let .videos(theme, text, value, enabled):
                return ItemListDisclosureItem(theme: theme, title: text, enabled: enabled, label: value, labelStyle: .detailText, sectionId: self.section, style: .blocks, action: {
                    arguments.customize(.video)
                })
            case let .files(theme, text, value, enabled):
                return ItemListDisclosureItem(theme: theme, title: text, enabled: enabled, label: value, labelStyle: .detailText, sectionId: self.section, style: .blocks, action: {
                    arguments.customize(.file)
                })
            case let .videoMessages(theme, text, value, enabled):
                return ItemListDisclosureItem(theme: theme, title: text, enabled: enabled, label: value, labelStyle: .detailText, sectionId: self.section, style: .blocks, action: {
                    arguments.customize(.videoMessage)
                })
            case let .voiceMessages(theme, text, value, enabled):
                return ItemListDisclosureItem(theme: theme, title: text, enabled: enabled, label: value, labelStyle: .detailText, sectionId: self.section, style: .blocks, action: {
                    arguments.customize(.voiceMessage)
                })
            case let .typesInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .reset(theme, text, enabled):
                return ItemListActionItem(theme: theme, title: text, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    if enabled {
                        arguments.reset()
                    }
                })
        }
    }
}

private struct AutomaticDownloadPeers {
    let contacts: Bool
    let otherPrivate: Bool
    let groups: Bool
    let channels: Bool
    let size: Int32?
}

private func stringForAutomaticDownloadPeers(strings: PresentationStrings, peers: AutomaticDownloadPeers, category: AutomaticDownloadCategory) -> String {
    var size: String?
    if var peersSize = peers.size, category == .video || category == .file {
        if peersSize == Int32.max {
            peersSize = 1536 * 1024 * 1024
        }
        size = dataSizeString(Int64(peersSize))
    }
    
    if peers.contacts && peers.otherPrivate && peers.groups && peers.channels {
        if let size = size {
            return strings.AutoDownloadSettings_UpToForAll(size).0
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
            return strings.AutoDownloadSettings_UpToFor(size, string).0
        } else {
            return strings.AutoDownloadSettings_OnFor(string).0
        }
    }
}

private func autodownloadMediaConnectionTypeControllerEntries(presentationData: PresentationData, connectionType: AutomaticDownloadConnectionType, settings: AutomaticMediaDownloadSettings) -> [AutodownloadMediaCategoryEntry] {
    var entries: [AutodownloadMediaCategoryEntry] = []
    
    let master: Bool
    let photo: AutomaticDownloadPeers
    let video: AutomaticDownloadPeers
    let file: AutomaticDownloadPeers
    let videoMessage: AutomaticDownloadPeers
    let voiceMessage: AutomaticDownloadPeers
    
    let defaultSettings = AutomaticMediaDownloadSettings.defaultSettings
    let defaultPeers = defaultSettings.peers
    let isDefault: Bool
    
    switch connectionType {
        case .cellular:
            master = settings.cellularEnabled
            photo = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.photo.cellular,
                otherPrivate: settings.peers.otherPrivate.photo.cellular,
                groups: settings.peers.groups.photo.cellular,
                channels: settings.peers.channels.photo.cellular,
                size: nil
            )
            video = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.video.cellular,
                otherPrivate: settings.peers.otherPrivate.video.cellular,
                groups: settings.peers.groups.video.cellular,
                channels: settings.peers.channels.video.cellular,
                size: settings.peers.contacts.video.cellularSizeLimit
            )
            file = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.file.cellular,
                otherPrivate: settings.peers.otherPrivate.file.cellular,
                groups: settings.peers.groups.file.cellular,
                channels: settings.peers.channels.file.cellular,
                size: settings.peers.contacts.file.cellularSizeLimit
            )
            videoMessage = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.videoMessage.cellular,
                otherPrivate: settings.peers.otherPrivate.videoMessage.cellular,
                groups: settings.peers.groups.videoMessage.cellular,
                channels: settings.peers.channels.videoMessage.cellular,
                size: nil
            )
            voiceMessage = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.voiceMessage.cellular,
                otherPrivate: settings.peers.otherPrivate.voiceMessage.cellular,
                groups: settings.peers.groups.voiceMessage.cellular,
                channels: settings.peers.channels.voiceMessage.cellular,
                size: nil
            )
        
            isDefault = master == defaultSettings.cellularEnabled && (photo.contacts == defaultPeers.contacts.photo.cellular &&
                video.contacts == defaultPeers.contacts.video.cellular &&
                video.size == defaultPeers.contacts.video.cellularSizeLimit &&
                file.contacts == defaultPeers.contacts.file.cellular &&
                file.size == defaultPeers.contacts.file.cellularSizeLimit &&
                videoMessage.contacts == defaultPeers.contacts.videoMessage.cellular &&
                voiceMessage.contacts == defaultPeers.contacts.voiceMessage.cellular &&
                photo.otherPrivate == defaultPeers.otherPrivate.photo.cellular &&
                video.otherPrivate == defaultPeers.otherPrivate.video.cellular &&
                video.size == defaultPeers.otherPrivate.video.cellularSizeLimit &&
                file.otherPrivate == defaultPeers.otherPrivate.file.cellular &&
                file.size == defaultPeers.otherPrivate.file.cellularSizeLimit &&
                videoMessage.otherPrivate == defaultPeers.otherPrivate.videoMessage.cellular &&
                voiceMessage.otherPrivate == defaultPeers.otherPrivate.voiceMessage.cellular &&
                photo.groups == defaultPeers.groups.photo.cellular &&
                video.groups == defaultPeers.groups.video.cellular &&
                video.size == defaultPeers.groups.video.cellularSizeLimit &&
                file.groups == defaultPeers.groups.file.cellular &&
                file.size == defaultPeers.groups.file.cellularSizeLimit &&
                videoMessage.groups == defaultPeers.groups.videoMessage.cellular &&
                voiceMessage.groups == defaultPeers.groups.voiceMessage.cellular &&
                photo.channels == defaultPeers.channels.photo.cellular &&
                video.channels == defaultPeers.channels.video.cellular &&
                video.size == defaultPeers.channels.video.cellularSizeLimit &&
                file.channels == defaultPeers.channels.file.cellular &&
                file.size == defaultPeers.channels.file.cellularSizeLimit &&
                videoMessage.channels == defaultPeers.channels.videoMessage.cellular &&
                voiceMessage.channels == defaultPeers.channels.voiceMessage.cellular)
        case .wifi:
            master = settings.wifiEnabled
            photo = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.photo.wifi,
                otherPrivate: settings.peers.otherPrivate.photo.wifi,
                groups: settings.peers.groups.photo.wifi,
                channels: settings.peers.channels.photo.wifi,
                size: nil
            )
            video = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.video.wifi,
                otherPrivate: settings.peers.otherPrivate.video.wifi,
                groups: settings.peers.groups.video.wifi,
                channels: settings.peers.channels.video.wifi,
                size: settings.peers.contacts.video.wifiSizeLimit
            )
            file = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.file.wifi,
                otherPrivate: settings.peers.otherPrivate.file.wifi,
                groups: settings.peers.groups.file.wifi,
                channels: settings.peers.channels.file.wifi,
                size: settings.peers.contacts.file.wifiSizeLimit
            )
            videoMessage = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.videoMessage.wifi,
                otherPrivate: settings.peers.otherPrivate.videoMessage.wifi,
                groups: settings.peers.groups.videoMessage.wifi,
                channels: settings.peers.channels.videoMessage.wifi,
                size: nil
            )
            voiceMessage = AutomaticDownloadPeers(
                contacts: settings.peers.contacts.voiceMessage.wifi,
                otherPrivate: settings.peers.otherPrivate.voiceMessage.wifi,
                groups: settings.peers.groups.voiceMessage.wifi,
                channels: settings.peers.channels.voiceMessage.wifi,
                size: nil
            )
        
            isDefault = master == defaultSettings.wifiEnabled && (photo.contacts == defaultPeers.contacts.photo.wifi &&
                video.contacts == defaultPeers.contacts.video.wifi &&
                video.size == defaultPeers.contacts.video.wifiSizeLimit &&
                file.contacts == defaultPeers.contacts.file.wifi &&
                file.size == defaultPeers.contacts.file.wifiSizeLimit &&
                videoMessage.contacts == defaultPeers.contacts.videoMessage.wifi &&
                voiceMessage.contacts == defaultPeers.contacts.voiceMessage.wifi &&
                photo.otherPrivate == defaultPeers.otherPrivate.photo.wifi &&
                video.otherPrivate == defaultPeers.otherPrivate.video.wifi &&
                video.size == defaultPeers.otherPrivate.video.wifiSizeLimit &&
                file.otherPrivate == defaultPeers.otherPrivate.file.wifi &&
                file.size == defaultPeers.otherPrivate.file.wifiSizeLimit &&
                videoMessage.otherPrivate == defaultPeers.otherPrivate.videoMessage.wifi &&
                voiceMessage.otherPrivate == defaultPeers.otherPrivate.voiceMessage.wifi &&
                photo.groups == defaultPeers.groups.photo.wifi &&
                video.groups == defaultPeers.groups.video.wifi &&
                video.size == defaultPeers.groups.video.wifiSizeLimit &&
                file.groups == defaultPeers.groups.file.wifi &&
                file.size == defaultPeers.groups.file.wifiSizeLimit &&
                videoMessage.groups == defaultPeers.groups.videoMessage.wifi &&
                voiceMessage.groups == defaultPeers.groups.voiceMessage.wifi &&
                photo.channels == defaultPeers.channels.photo.wifi &&
                video.channels == defaultPeers.channels.video.wifi &&
                video.size == defaultPeers.channels.video.wifiSizeLimit &&
                file.channels == defaultPeers.channels.file.wifi &&
                file.size == defaultPeers.channels.file.wifiSizeLimit &&
                videoMessage.channels == defaultPeers.channels.videoMessage.wifi &&
                voiceMessage.channels == defaultPeers.channels.voiceMessage.wifi)
    }
    
    entries.append(.master(presentationData.theme, presentationData.strings.AutoDownloadSettings_AutoDownload, master))
    
    entries.append(.typesHeader(presentationData.theme, presentationData.strings.AutoDownloadSettings_MediaTypes))
    entries.append(.photos(presentationData.theme, presentationData.strings.AutoDownloadSettings_Photos, stringForAutomaticDownloadPeers(strings: presentationData.strings, peers: photo, category: .photo), master))
    entries.append(.videos(presentationData.theme, presentationData.strings.AutoDownloadSettings_Videos, stringForAutomaticDownloadPeers(strings: presentationData.strings, peers: video, category: .video), master))
    entries.append(.files(presentationData.theme, presentationData.strings.AutoDownloadSettings_Files, stringForAutomaticDownloadPeers(strings: presentationData.strings, peers: file, category: .file), master))
    entries.append(.videoMessages(presentationData.theme, presentationData.strings.AutoDownloadSettings_VideoMessages, stringForAutomaticDownloadPeers(strings: presentationData.strings, peers: videoMessage, category: .videoMessage), master))
    entries.append(.voiceMessages(presentationData.theme, presentationData.strings.AutoDownloadSettings_VoiceMessages, stringForAutomaticDownloadPeers(strings: presentationData.strings, peers: voiceMessage, category: .voiceMessage), master))
    entries.append(.typesInfo(presentationData.theme, presentationData.strings.AutoDownloadSettings_MediaTypesInfo))
    
    entries.append(.reset(presentationData.theme, presentationData.strings.AutoDownloadSettings_ResetSettings, !isDefault))
    
    return entries
}

private func isAutodownloadEnabled(for category: AutomaticMediaDownloadCategory, connectionType: AutomaticDownloadConnectionType) -> Bool {
    switch connectionType {
        case .cellular:
            return category.cellular
        case .wifi:
            return category.wifi
    }
}

func autodownloadMediaConnectionTypeController(context: AccountContext, connectionType: AutomaticDownloadConnectionType) -> ViewController {
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let arguments = AutodownloadMediaConnectionTypeControllerArguments(toggleMaster: { value in
        let _ = updateMediaDownloadSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            switch connectionType {
                case .cellular:
                    settings.cellularEnabled = value
                case .wifi:
                    settings.wifiEnabled = value
            }
            return settings
        }).start()
    }, customize: { type in
        let _ = (context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings])
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedData in
            let settings: AutomaticMediaDownloadSettings
            if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings] as? AutomaticMediaDownloadSettings {
                settings = value
            } else {
                settings = AutomaticMediaDownloadSettings.defaultSettings
            }
            
            let peers = settings.peers
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = ActionSheetController(presentationTheme: presentationData.theme)
            let dismissAction: () -> Void = { [weak controller] in
                controller?.dismissAnimated()
            }
            
            var state = PeerType()
            var size: Int32?
            switch type {
                case .photo:
                    if isAutodownloadEnabled(for: peers.contacts.photo, connectionType: connectionType) {
                        state.insert(.contact)
                    }
                    if isAutodownloadEnabled(for: peers.otherPrivate.photo, connectionType: connectionType) {
                        state.insert(.otherPrivate)
                    }
                    if isAutodownloadEnabled(for: peers.groups.photo, connectionType: connectionType) {
                        state.insert(.group)
                    }
                    if isAutodownloadEnabled(for: peers.channels.photo, connectionType: connectionType) {
                        state.insert(.channel)
                    }
                case .video:
                    if isAutodownloadEnabled(for: peers.contacts.video, connectionType: connectionType) {
                        state.insert(.contact)
                    }
                    if isAutodownloadEnabled(for: peers.otherPrivate.video, connectionType: connectionType) {
                        state.insert(.otherPrivate)
                    }
                    if isAutodownloadEnabled(for: peers.groups.video, connectionType: connectionType) {
                        state.insert(.group)
                    }
                    if isAutodownloadEnabled(for: peers.channels.video, connectionType: connectionType) {
                        state.insert(.channel)
                    }
                    switch connectionType {
                        case .cellular:
                            size = peers.contacts.video.cellularSizeLimit
                        case .wifi:
                            size = peers.contacts.video.wifiSizeLimit
                    }
                case .file:
                    if isAutodownloadEnabled(for: peers.contacts.file, connectionType: connectionType) {
                        state.insert(.contact)
                    }
                    if isAutodownloadEnabled(for: peers.otherPrivate.file, connectionType: connectionType) {
                        state.insert(.otherPrivate)
                    }
                    if isAutodownloadEnabled(for: peers.groups.file, connectionType: connectionType) {
                        state.insert(.group)
                    }
                    if isAutodownloadEnabled(for: peers.channels.file, connectionType: connectionType) {
                        state.insert(.channel)
                    }
                    switch connectionType {
                        case .cellular:
                            size = peers.contacts.file.cellularSizeLimit
                        case .wifi:
                            size = peers.contacts.file.wifiSizeLimit
                    }
                case .videoMessage:
                    if isAutodownloadEnabled(for: peers.contacts.videoMessage, connectionType: connectionType) {
                        state.insert(.contact)
                    }
                    if isAutodownloadEnabled(for: peers.otherPrivate.videoMessage, connectionType: connectionType) {
                        state.insert(.otherPrivate)
                    }
                    if isAutodownloadEnabled(for: peers.groups.videoMessage, connectionType: connectionType) {
                        state.insert(.group)
                    }
                    if isAutodownloadEnabled(for: peers.channels.videoMessage, connectionType: connectionType) {
                        state.insert(.channel)
                    }
                case .voiceMessage:
                    if isAutodownloadEnabled(for: peers.contacts.voiceMessage, connectionType: connectionType) {
                        state.insert(.contact)
                    }
                    if isAutodownloadEnabled(for: peers.otherPrivate.voiceMessage, connectionType: connectionType) {
                        state.insert(.otherPrivate)
                    }
                    if isAutodownloadEnabled(for: peers.groups.voiceMessage, connectionType: connectionType) {
                        state.insert(.group)
                    }
                    if isAutodownloadEnabled(for: peers.channels.voiceMessage, connectionType: connectionType) {
                        state.insert(.channel)
                    }
            }
            
            let toggleCheck: (PeerType, Int) -> Void = { [weak controller] type, itemIndex in
                if state.contains(type) {
                    state.remove(type)
                } else {
                    state.insert(type)
                }
                controller?.updateItem(groupIndex: 0, itemIndex: itemIndex, { item in
                    if let item = item as? ActionSheetCheckboxItem {
                        return ActionSheetCheckboxItem(title: item.title, label: item.label, value: !item.value, style: .alignRight, action: item.action)
                    }
                    return item
                })
            }
            var items: [ActionSheetItem] = []
            
            items.append(ActionSheetCheckboxItem(title: presentationData.strings.AutoDownloadSettings_Contacts, label: "", value: state.contains(.contact), style: .alignRight, action: { value in
                toggleCheck(.contact, 0)
            }))
            
            items.append(ActionSheetCheckboxItem(title: presentationData.strings.AutoDownloadSettings_PrivateChats, label: "", value: state.contains(.otherPrivate), style: .alignRight, action: { value in
                toggleCheck(.otherPrivate, 1)
            }))
            
            items.append(ActionSheetCheckboxItem(title: presentationData.strings.AutoDownloadSettings_GroupChats, label: "", value: state.contains(.group), style: .alignRight, action: { value in
                toggleCheck(.group, 2)
            }))
            
            items.append(ActionSheetCheckboxItem(title: presentationData.strings.AutoDownloadSettings_Channels, label: "", value: state.contains(.channel), style: .alignRight, action: { value in
                toggleCheck(.channel, 3)
            }))
            
            if let initialSize = size {
                items.append(AutodownloadSliderItem(strings: presentationData.strings, title: presentationData.strings.AutoDownloadSettings_Limit, value: initialSize, updated: { value in
                    size = value
                }))
            }
            
            items.append(ActionSheetButtonItem(title: presentationData.strings.AutoDownloadSettings_Save, font: .bold, action: {
                dismissAction()
                
                let _ = updateMediaDownloadSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                    var settings = settings
                    switch type {
                        case .photo:
                            switch connectionType {
                                case .cellular:
                                    settings.peers.contacts.photo.cellular = state.contains(.contact)
                                    settings.peers.otherPrivate.photo.cellular = state.contains(.otherPrivate)
                                    settings.peers.groups.photo.cellular = state.contains(.group)
                                    settings.peers.channels.photo.cellular = state.contains(.channel)
                                case .wifi:
                                    settings.peers.contacts.photo.wifi = state.contains(.contact)
                                    settings.peers.otherPrivate.photo.wifi = state.contains(.otherPrivate)
                                    settings.peers.groups.photo.wifi = state.contains(.group)
                                    settings.peers.channels.photo.wifi = state.contains(.channel)
                            }
                        case .video:
                            switch connectionType {
                                case .cellular:
                                    settings.peers.contacts.video.cellular = state.contains(.contact)
                                    settings.peers.otherPrivate.video.cellular = state.contains(.otherPrivate)
                                    settings.peers.groups.video.cellular = state.contains(.group)
                                    settings.peers.channels.video.cellular = state.contains(.channel)
                                    
                                    if let size = size {
                                        settings.peers.contacts.video.cellularSizeLimit = size
                                        settings.peers.otherPrivate.video.cellularSizeLimit = size
                                        settings.peers.groups.video.cellularSizeLimit = size
                                        settings.peers.channels.video.cellularSizeLimit = size
                                    }
                                case .wifi:
                                    settings.peers.contacts.video.wifi = state.contains(.contact)
                                    settings.peers.otherPrivate.video.wifi = state.contains(.otherPrivate)
                                    settings.peers.groups.video.wifi = state.contains(.group)
                                    settings.peers.channels.video.wifi = state.contains(.channel)
                                
                                    if let size = size {
                                        settings.peers.contacts.video.wifiSizeLimit = size
                                        settings.peers.otherPrivate.video.wifiSizeLimit = size
                                        settings.peers.groups.video.wifiSizeLimit = size
                                        settings.peers.channels.video.wifiSizeLimit = size
                                    }
                            }
                        case .file:
                            switch connectionType {
                                case .cellular:
                                    settings.peers.contacts.file.cellular = state.contains(.contact)
                                    settings.peers.otherPrivate.file.cellular = state.contains(.otherPrivate)
                                    settings.peers.groups.file.cellular = state.contains(.group)
                                    settings.peers.channels.file.cellular = state.contains(.channel)
                                
                                    if let size = size {
                                        settings.peers.contacts.file.cellularSizeLimit = size
                                        settings.peers.otherPrivate.file.cellularSizeLimit = size
                                        settings.peers.groups.file.cellularSizeLimit = size
                                        settings.peers.channels.file.cellularSizeLimit = size
                                    }
                                case .wifi:
                                    settings.peers.contacts.file.wifi = state.contains(.contact)
                                    settings.peers.otherPrivate.file.wifi = state.contains(.otherPrivate)
                                    settings.peers.groups.file.wifi = state.contains(.group)
                                    settings.peers.channels.file.wifi = state.contains(.channel)
                                
                                    if let size = size {
                                        settings.peers.contacts.file.wifiSizeLimit = size
                                        settings.peers.otherPrivate.file.wifiSizeLimit = size
                                        settings.peers.groups.file.wifiSizeLimit = size
                                        settings.peers.channels.file.wifiSizeLimit = size
                                    }
                            }
                        case .videoMessage:
                            switch connectionType {
                                case .cellular:
                                    settings.peers.contacts.videoMessage.cellular = state.contains(.contact)
                                    settings.peers.otherPrivate.videoMessage.cellular = state.contains(.otherPrivate)
                                    settings.peers.groups.videoMessage.cellular = state.contains(.group)
                                    settings.peers.channels.videoMessage.cellular = state.contains(.channel)
                                case .wifi:
                                    settings.peers.contacts.videoMessage.wifi = state.contains(.contact)
                                    settings.peers.otherPrivate.videoMessage.wifi = state.contains(.otherPrivate)
                                    settings.peers.groups.videoMessage.wifi = state.contains(.group)
                                    settings.peers.channels.videoMessage.wifi = state.contains(.channel)
                            }
                        case .voiceMessage:
                            switch connectionType {
                                case .cellular:
                                    settings.peers.contacts.voiceMessage.cellular = state.contains(.contact)
                                    settings.peers.otherPrivate.voiceMessage.cellular = state.contains(.otherPrivate)
                                    settings.peers.groups.voiceMessage.cellular = state.contains(.group)
                                    settings.peers.channels.voiceMessage.cellular = state.contains(.channel)
                                case .wifi:
                                    settings.peers.contacts.voiceMessage.wifi = state.contains(.contact)
                                    settings.peers.otherPrivate.voiceMessage.wifi = state.contains(.otherPrivate)
                                    settings.peers.groups.voiceMessage.wifi = state.contains(.group)
                                    settings.peers.channels.voiceMessage.wifi = state.contains(.channel)
                            }
                    }
                    return settings
                }).start()
            }))
            
            controller.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
            presentControllerImpl?(controller)
        })
    }, reset: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetTextItem(title: presentationData.strings.AutoDownloadSettings_ResetHelp),
            ActionSheetButtonItem(title: presentationData.strings.AutoDownloadSettings_Reset, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                let _ = updateMediaDownloadSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                    var settings = settings
                    
                    let defaultSettings = AutomaticMediaDownloadSettings.defaultSettings
                    switch connectionType {
                        case .cellular:
                            settings.cellularEnabled = true
                            settings.peers.contacts.photo.cellular = defaultSettings.peers.contacts.photo.cellular
                            settings.peers.contacts.photo.cellularSizeLimit = defaultSettings.peers.contacts.photo.cellularSizeLimit
                            settings.peers.contacts.video.cellular = defaultSettings.peers.contacts.video.cellular
                            settings.peers.contacts.video.cellularSizeLimit = defaultSettings.peers.contacts.video.cellularSizeLimit
                            settings.peers.contacts.file.cellular = defaultSettings.peers.contacts.file.cellular
                            settings.peers.contacts.file.cellularSizeLimit = defaultSettings.peers.contacts.file.cellularSizeLimit
                            settings.peers.contacts.videoMessage.cellular = defaultSettings.peers.contacts.videoMessage.cellular
                            settings.peers.contacts.videoMessage.cellularSizeLimit = defaultSettings.peers.contacts.videoMessage.cellularSizeLimit
                            settings.peers.contacts.voiceMessage.cellular = defaultSettings.peers.contacts.voiceMessage.cellular
                            settings.peers.contacts.voiceMessage.cellularSizeLimit = defaultSettings.peers.contacts.voiceMessage.cellularSizeLimit
                            
                            settings.peers.otherPrivate.photo.cellular = defaultSettings.peers.otherPrivate.photo.cellular
                            settings.peers.otherPrivate.photo.cellularSizeLimit = defaultSettings.peers.otherPrivate.photo.cellularSizeLimit
                            settings.peers.otherPrivate.video.cellular = defaultSettings.peers.otherPrivate.video.cellular
                            settings.peers.otherPrivate.video.cellularSizeLimit = defaultSettings.peers.otherPrivate.video.cellularSizeLimit
                            settings.peers.otherPrivate.file.cellular = defaultSettings.peers.otherPrivate.file.cellular
                            settings.peers.otherPrivate.file.cellularSizeLimit = defaultSettings.peers.otherPrivate.file.cellularSizeLimit
                            settings.peers.otherPrivate.videoMessage.cellular = defaultSettings.peers.otherPrivate.videoMessage.cellular
                            settings.peers.otherPrivate.videoMessage.cellularSizeLimit = defaultSettings.peers.otherPrivate.videoMessage.cellularSizeLimit
                            settings.peers.otherPrivate.voiceMessage.cellular = defaultSettings.peers.otherPrivate.voiceMessage.cellular
                            settings.peers.otherPrivate.voiceMessage.cellularSizeLimit = defaultSettings.peers.otherPrivate.voiceMessage.cellularSizeLimit
                            
                            settings.peers.groups.photo.cellular = defaultSettings.peers.groups.photo.cellular
                            settings.peers.groups.photo.cellularSizeLimit = defaultSettings.peers.groups.photo.cellularSizeLimit
                            settings.peers.groups.video.cellular = defaultSettings.peers.groups.video.cellular
                            settings.peers.groups.video.cellularSizeLimit = defaultSettings.peers.groups.video.cellularSizeLimit
                            settings.peers.groups.file.cellular = defaultSettings.peers.groups.file.cellular
                            settings.peers.groups.file.cellularSizeLimit = defaultSettings.peers.groups.file.cellularSizeLimit
                            settings.peers.groups.videoMessage.cellular = defaultSettings.peers.groups.videoMessage.cellular
                            settings.peers.groups.videoMessage.cellularSizeLimit = defaultSettings.peers.groups.videoMessage.cellularSizeLimit
                            settings.peers.groups.voiceMessage.cellular = defaultSettings.peers.groups.voiceMessage.cellular
                            settings.peers.groups.voiceMessage.cellularSizeLimit = defaultSettings.peers.groups.voiceMessage.cellularSizeLimit
                            
                            settings.peers.channels.photo.cellular = defaultSettings.peers.channels.photo.cellular
                            settings.peers.channels.photo.cellularSizeLimit = defaultSettings.peers.channels.photo.cellularSizeLimit
                            settings.peers.channels.video.cellular = defaultSettings.peers.channels.video.cellular
                            settings.peers.channels.video.cellularSizeLimit = defaultSettings.peers.channels.video.cellularSizeLimit
                            settings.peers.channels.file.cellular = defaultSettings.peers.channels.file.cellular
                            settings.peers.channels.file.cellularSizeLimit = defaultSettings.peers.channels.file.cellularSizeLimit
                            settings.peers.channels.videoMessage.cellular = defaultSettings.peers.channels.videoMessage.cellular
                            settings.peers.channels.videoMessage.cellularSizeLimit = defaultSettings.peers.channels.videoMessage.cellularSizeLimit
                            settings.peers.channels.voiceMessage.cellular = defaultSettings.peers.channels.voiceMessage.cellular
                            settings.peers.channels.voiceMessage.cellularSizeLimit = defaultSettings.peers.channels.voiceMessage.cellularSizeLimit
                        case .wifi:
                            settings.wifiEnabled = true
                            settings.peers.contacts.photo.wifi = defaultSettings.peers.contacts.photo.wifi
                            settings.peers.contacts.photo.wifiSizeLimit = defaultSettings.peers.contacts.photo.wifiSizeLimit
                            settings.peers.contacts.video.wifi = defaultSettings.peers.contacts.video.wifi
                            settings.peers.contacts.video.wifiSizeLimit = defaultSettings.peers.contacts.video.wifiSizeLimit
                            settings.peers.contacts.file.wifi = defaultSettings.peers.contacts.file.wifi
                            settings.peers.contacts.file.wifiSizeLimit = defaultSettings.peers.contacts.file.wifiSizeLimit
                            settings.peers.contacts.videoMessage.wifi = defaultSettings.peers.contacts.videoMessage.wifi
                            settings.peers.contacts.videoMessage.wifiSizeLimit = defaultSettings.peers.contacts.videoMessage.wifiSizeLimit
                            settings.peers.contacts.voiceMessage.wifi = defaultSettings.peers.contacts.voiceMessage.wifi
                            settings.peers.contacts.voiceMessage.wifiSizeLimit = defaultSettings.peers.contacts.voiceMessage.wifiSizeLimit
                            
                            settings.peers.otherPrivate.photo.wifi = defaultSettings.peers.otherPrivate.photo.wifi
                            settings.peers.otherPrivate.photo.wifiSizeLimit = defaultSettings.peers.otherPrivate.photo.wifiSizeLimit
                            settings.peers.otherPrivate.video.wifi = defaultSettings.peers.otherPrivate.video.wifi
                            settings.peers.otherPrivate.video.wifiSizeLimit = defaultSettings.peers.otherPrivate.video.wifiSizeLimit
                            settings.peers.otherPrivate.file.wifi = defaultSettings.peers.otherPrivate.file.wifi
                            settings.peers.otherPrivate.file.wifiSizeLimit = defaultSettings.peers.otherPrivate.file.wifiSizeLimit
                            settings.peers.otherPrivate.videoMessage.wifi = defaultSettings.peers.otherPrivate.videoMessage.wifi
                            settings.peers.otherPrivate.videoMessage.wifiSizeLimit = defaultSettings.peers.otherPrivate.videoMessage.wifiSizeLimit
                            settings.peers.otherPrivate.voiceMessage.wifi = defaultSettings.peers.otherPrivate.voiceMessage.wifi
                            settings.peers.otherPrivate.voiceMessage.wifiSizeLimit = defaultSettings.peers.otherPrivate.voiceMessage.wifiSizeLimit
                            
                            settings.peers.groups.photo.wifi = defaultSettings.peers.groups.photo.wifi
                            settings.peers.groups.photo.wifiSizeLimit = defaultSettings.peers.groups.photo.wifiSizeLimit
                            settings.peers.groups.video.wifi = defaultSettings.peers.groups.video.wifi
                            settings.peers.groups.video.wifiSizeLimit = defaultSettings.peers.groups.video.wifiSizeLimit
                            settings.peers.groups.file.wifi = defaultSettings.peers.groups.file.wifi
                            settings.peers.groups.file.wifiSizeLimit = defaultSettings.peers.groups.file.wifiSizeLimit
                            settings.peers.groups.videoMessage.wifi = defaultSettings.peers.groups.videoMessage.wifi
                            settings.peers.groups.videoMessage.wifiSizeLimit = defaultSettings.peers.groups.videoMessage.wifiSizeLimit
                            settings.peers.groups.voiceMessage.wifi = defaultSettings.peers.groups.voiceMessage.wifi
                            settings.peers.groups.voiceMessage.wifiSizeLimit = defaultSettings.peers.groups.voiceMessage.wifiSizeLimit
                            
                            settings.peers.channels.photo.wifi = defaultSettings.peers.channels.photo.wifi
                            settings.peers.channels.photo.wifiSizeLimit = defaultSettings.peers.channels.photo.wifiSizeLimit
                            settings.peers.channels.video.wifi = defaultSettings.peers.channels.video.wifi
                            settings.peers.channels.video.wifiSizeLimit = defaultSettings.peers.channels.video.wifiSizeLimit
                            settings.peers.channels.file.wifi = defaultSettings.peers.channels.file.wifi
                            settings.peers.channels.file.wifiSizeLimit = defaultSettings.peers.channels.file.wifiSizeLimit
                            settings.peers.channels.videoMessage.wifi = defaultSettings.peers.channels.videoMessage.wifi
                            settings.peers.channels.videoMessage.wifiSizeLimit = defaultSettings.peers.channels.videoMessage.wifiSizeLimit
                            settings.peers.channels.voiceMessage.wifi = defaultSettings.peers.channels.voiceMessage.wifi
                            settings.peers.channels.voiceMessage.wifiSizeLimit = defaultSettings.peers.channels.voiceMessage.wifiSizeLimit
                    }
                    return settings
                }).start()
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet)
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings]))
        |> deliverOnMainQueue
        |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState<AutodownloadMediaCategoryEntry>, AutodownloadMediaCategoryEntry.ItemGenerationArguments)) in
            let settings: AutomaticMediaDownloadSettings
            if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings] as? AutomaticMediaDownloadSettings {
                settings = value
            } else {
                settings = AutomaticMediaDownloadSettings.defaultSettings
            }
            
            let title: String
            switch connectionType {
                case .cellular:
                    title = presentationData.strings.AutoDownloadSettings_CellularTitle
                case .wifi:
                    title = presentationData.strings.AutoDownloadSettings_WifiTitle
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(entries: autodownloadMediaConnectionTypeControllerEntries(presentationData: presentationData, connectionType: connectionType, settings: settings), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    return controller
}

