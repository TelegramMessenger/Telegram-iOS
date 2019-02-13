import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore

public enum AutomaticDownloadNetworkType {
    case wifi
    case cellular
}

public enum AutomaticMediaDownloadPreset: Int32 {
    case low
    case medium
    case high
    case custom
}

public struct AutomaticMediaDownloadPresets: PostboxCoding, Equatable {
    public var low: AutomaticMediaDownloadCategories
    public var medium: AutomaticMediaDownloadCategories
    public var high: AutomaticMediaDownloadCategories
    
    public init(low: AutomaticMediaDownloadCategories, medium: AutomaticMediaDownloadCategories, high: AutomaticMediaDownloadCategories) {
        self.low = low
        self.medium = medium
        self.high = high
    }
    
    public init(decoder: PostboxDecoder) {
        self.low =  decoder.decodeObjectForKey("low", decoder: AutomaticMediaDownloadCategories.init(decoder:)) as! AutomaticMediaDownloadCategories
        self.medium =  decoder.decodeObjectForKey("medium", decoder: AutomaticMediaDownloadCategories.init(decoder:)) as! AutomaticMediaDownloadCategories
        self.high =  decoder.decodeObjectForKey("high", decoder: AutomaticMediaDownloadCategories.init(decoder:)) as! AutomaticMediaDownloadCategories
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.low, forKey: "low")
        encoder.encodeObject(self.medium, forKey: "medium")
        encoder.encodeObject(self.high, forKey: "high")
    }
}

public struct AutomaticMediaDownloadConnection: PostboxCoding, Equatable {
    public var enabled: Bool
    public var preset: AutomaticMediaDownloadPreset
    public var custom: AutomaticMediaDownloadCategories?
    
    public init(enabled: Bool, preset: AutomaticMediaDownloadPreset, custom: AutomaticMediaDownloadCategories?) {
        self.enabled = enabled
        self.preset = preset
        self.custom = custom
    }
    
    public init(decoder: PostboxDecoder) {
        self.enabled = decoder.decodeInt32ForKey("enabled", orElse: 0) != 0
        self.preset = AutomaticMediaDownloadPreset(rawValue: decoder.decodeInt32ForKey("preset", orElse: 0)) ?? .medium
        self.custom = decoder.decodeObjectForKey("custom", decoder: AutomaticMediaDownloadCategories.init(decoder:)) as? AutomaticMediaDownloadCategories
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.enabled ? 1 : 0, forKey: "enabled")
        encoder.encodeInt32(self.preset.rawValue, forKey: "preset")
        if let custom = self.custom {
            encoder.encodeObject(custom, forKey: "custom")
        } else {
            encoder.encodeNil(forKey: "custom")
        }
    }
}

public struct AutomaticMediaDownloadCategories: PostboxCoding, Equatable, Comparable {
    public var basePreset: AutomaticMediaDownloadPreset
    public var photo: AutomaticMediaDownloadCategory
    public var video: AutomaticMediaDownloadCategory
    public var file: AutomaticMediaDownloadCategory
    
    public init(basePreset: AutomaticMediaDownloadPreset, photo: AutomaticMediaDownloadCategory, video: AutomaticMediaDownloadCategory, file: AutomaticMediaDownloadCategory) {
        self.basePreset = basePreset
        self.photo = photo
        self.video = video
        self.file = file
    }
    
    public init(decoder: PostboxDecoder) {
        self.basePreset = AutomaticMediaDownloadPreset(rawValue: decoder.decodeInt32ForKey("preset", orElse: 0)) ?? .medium
        self.photo = decoder.decodeObjectForKey("photo", decoder: AutomaticMediaDownloadCategory.init(decoder:)) as! AutomaticMediaDownloadCategory
        self.video = decoder.decodeObjectForKey("video", decoder: AutomaticMediaDownloadCategory.init(decoder:)) as! AutomaticMediaDownloadCategory
        self.file = decoder.decodeObjectForKey("file", decoder: AutomaticMediaDownloadCategory.init(decoder:)) as! AutomaticMediaDownloadCategory
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.basePreset.rawValue, forKey: "preset")
        encoder.encodeObject(self.photo, forKey: "photo")
        encoder.encodeObject(self.video, forKey: "video")
        encoder.encodeObject(self.file, forKey: "file")
    }
    
    public static func < (lhs: AutomaticMediaDownloadCategories, rhs: AutomaticMediaDownloadCategories) -> Bool {
        let lhsSizeLimit = (isAutodownloadEnabledForAnyPeerType(category: lhs.video) ? lhs.video.sizeLimit : 0) + (isAutodownloadEnabledForAnyPeerType(category: lhs.file) ? lhs.file.sizeLimit : 0)
        let rhsSizeLimit = (isAutodownloadEnabledForAnyPeerType(category: rhs.video) ? rhs.video.sizeLimit : 0) + (isAutodownloadEnabledForAnyPeerType(category: rhs.file) ? rhs.file.sizeLimit : 0)
        return lhsSizeLimit < rhsSizeLimit
    }
}

public struct AutomaticMediaDownloadCategory: PostboxCoding, Equatable {
    public var contacts: Bool
    public var otherPrivate: Bool
    public var groups: Bool
    public var channels: Bool
    public var sizeLimit: Int32
    public var predownload: Bool
    
    public init(contacts: Bool, otherPrivate: Bool, groups: Bool, channels: Bool, sizeLimit: Int32, predownload: Bool) {
        self.contacts = contacts
        self.otherPrivate = otherPrivate
        self.groups = groups
        self.channels = channels
        self.sizeLimit = sizeLimit
        self.predownload = predownload
    }
    
    public init(decoder: PostboxDecoder) {
        self.contacts = decoder.decodeInt32ForKey("contacts", orElse: 0) != 0
        self.otherPrivate = decoder.decodeInt32ForKey("otherPrivate", orElse: 0) != 0
        self.groups = decoder.decodeInt32ForKey("groups", orElse: 0) != 0
        self.channels = decoder.decodeInt32ForKey("channels", orElse: 0) != 0
        self.sizeLimit = decoder.decodeInt32ForKey("size", orElse: 0)
        self.predownload = decoder.decodeInt32ForKey("predownload", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.contacts ? 1 : 0, forKey: "contacts")
        encoder.encodeInt32(self.otherPrivate ? 1 : 0, forKey: "otherPrivate")
        encoder.encodeInt32(self.groups ? 1 : 0, forKey: "groups")
        encoder.encodeInt32(self.channels ? 1 : 0, forKey: "channels")
        encoder.encodeInt32(self.sizeLimit, forKey: "size")
        encoder.encodeInt32(self.predownload ? 1 : 0, forKey: "predownload")
    }
}

public struct AutomaticMediaDownloadSettings: PreferencesEntry, Equatable {
    public var presets: AutomaticMediaDownloadPresets
    public var cellular: AutomaticMediaDownloadConnection
    public var wifi: AutomaticMediaDownloadConnection
    public var saveDownloadedPhotos: AutomaticMediaDownloadCategory
    
    public var autoplayGifs: Bool
    public var autoplayVideos: Bool
    public var downloadInBackground: Bool
    
    public static var defaultSettings: AutomaticMediaDownloadSettings {
        let mb: Int32 = 1024 * 1024
        let presets = AutomaticMediaDownloadPresets(low: AutomaticMediaDownloadCategories(basePreset: .low, photo: AutomaticMediaDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false),
                                                                                          video: AutomaticMediaDownloadCategory(contacts: false, otherPrivate: false, groups: false, channels: false, sizeLimit: 1 * mb, predownload: false),
                                                                                          file: AutomaticMediaDownloadCategory(contacts: false, otherPrivate: false, groups: false, channels: false, sizeLimit: 1 * mb, predownload: false)),
                                                    medium: AutomaticMediaDownloadCategories(basePreset: .medium, photo: AutomaticMediaDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false),
                                                                                             video: AutomaticMediaDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: Int32(2.5 * CGFloat(mb)), predownload: false),
                                                                                             file: AutomaticMediaDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false)),
                                                    high: AutomaticMediaDownloadCategories(basePreset: .high, photo: AutomaticMediaDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false),
                                                                                     video: AutomaticMediaDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 10 * mb, predownload: true),
                                                                                     file: AutomaticMediaDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 3 * mb, predownload: false)))
        let saveDownloadedPhotos = AutomaticMediaDownloadCategory(contacts: false, otherPrivate: false, groups: false, channels: false, sizeLimit: 0, predownload: false)
        
        return AutomaticMediaDownloadSettings(presets: presets, cellular: AutomaticMediaDownloadConnection(enabled: true, preset: .medium, custom: nil), wifi: AutomaticMediaDownloadConnection(enabled: true, preset: .high, custom: nil), saveDownloadedPhotos: saveDownloadedPhotos, autoplayGifs: true, autoplayVideos: true, downloadInBackground: true)
    }
    
    public init(presets: AutomaticMediaDownloadPresets, cellular: AutomaticMediaDownloadConnection, wifi: AutomaticMediaDownloadConnection, saveDownloadedPhotos: AutomaticMediaDownloadCategory, autoplayGifs: Bool, autoplayVideos: Bool, downloadInBackground: Bool) {
        self.presets = presets
        self.cellular = cellular
        self.wifi = wifi
        self.saveDownloadedPhotos = saveDownloadedPhotos
        self.autoplayGifs = autoplayGifs
        self.autoplayVideos = autoplayGifs
        self.downloadInBackground = downloadInBackground
    }
    
    public init(decoder: PostboxDecoder) {
        let defaultSettings = AutomaticMediaDownloadSettings.defaultSettings
        
        self.presets = defaultSettings.presets
        self.cellular = decoder.decodeObjectForKey("cellular", decoder: AutomaticMediaDownloadConnection.init(decoder:)) as? AutomaticMediaDownloadConnection ?? defaultSettings.cellular
        self.wifi = decoder.decodeObjectForKey("wifi", decoder: AutomaticMediaDownloadConnection.init(decoder:)) as? AutomaticMediaDownloadConnection ?? defaultSettings.wifi
        self.saveDownloadedPhotos = decoder.decodeObjectForKey("saveDownloadedPhotos", decoder: AutomaticMediaDownloadCategory.init(decoder:)) as? AutomaticMediaDownloadCategory ?? defaultSettings.saveDownloadedPhotos
        self.autoplayGifs = decoder.decodeInt32ForKey("autoplayGifs", orElse: 1) != 0
        self.autoplayVideos = decoder.decodeInt32ForKey("autoplayVideos", orElse: 1) != 0
        self.downloadInBackground = decoder.decodeInt32ForKey("downloadInBackground", orElse: 1) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.cellular, forKey: "cellular")
        encoder.encodeObject(self.wifi, forKey: "wifi")
        encoder.encodeObject(self.saveDownloadedPhotos, forKey: "saveDownloadedPhotos")
        encoder.encodeInt32(self.autoplayGifs ? 1 : 0, forKey: "autoplayGifs")
        encoder.encodeInt32(self.autoplayVideos ? 1 : 0, forKey: "autoplayVideos")
        encoder.encodeInt32(self.downloadInBackground ? 1 : 0, forKey: "downloadInBackground")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? AutomaticMediaDownloadSettings {
            return self == to
        } else {
            return false
        }
    }
    
    func connectionSettings(for networkType: AutomaticDownloadNetworkType) -> AutomaticMediaDownloadConnection {
        switch networkType {
            case .cellular:
                return self.cellular
            case .wifi:
                return self.wifi
        }
    }
    
    func updatedWithAutodownloadSettings(_ autodownloadSettings: AutodownloadSettings) -> AutomaticMediaDownloadSettings {
        var settings = self
        settings.presets = presetsWithAutodownloadSettings(autodownloadSettings)
        return self
    }
}

private func categoriesWithAutodownloadPreset(_ autodownloadPreset: AutodownloadPresetSettings, preset: AutomaticMediaDownloadPreset) -> AutomaticMediaDownloadCategories {
    let videoEnabled = autodownloadPreset.videoSizeMax > 0
    let videoSizeMax = autodownloadPreset.videoSizeMax > 0 ? autodownloadPreset.videoSizeMax : 1 * 1024 * 1024
    let fileEnabled = autodownloadPreset.fileSizeMax > 0
    let fileSizeMax = autodownloadPreset.fileSizeMax > 0 ? autodownloadPreset.fileSizeMax : 1 * 1024 * 1024
    
    return AutomaticMediaDownloadCategories(basePreset: preset, photo: AutomaticMediaDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: autodownloadPreset.photoSizeMax, predownload: false), video: AutomaticMediaDownloadCategory(contacts: videoEnabled, otherPrivate: videoEnabled, groups: videoEnabled, channels: videoEnabled, sizeLimit: videoSizeMax, predownload: autodownloadPreset.preloadLargeVideo), file: AutomaticMediaDownloadCategory(contacts: fileEnabled, otherPrivate: fileEnabled, groups: fileEnabled, channels: fileEnabled, sizeLimit: fileSizeMax, predownload: false))
}

private func presetsWithAutodownloadSettings(_ autodownloadSettings: AutodownloadSettings) -> AutomaticMediaDownloadPresets {
    return AutomaticMediaDownloadPresets(low: categoriesWithAutodownloadPreset(autodownloadSettings.lowPreset, preset: .low), medium: categoriesWithAutodownloadPreset(autodownloadSettings.mediumPreset, preset: .medium), high: categoriesWithAutodownloadPreset(autodownloadSettings.highPreset, preset: .high))
}

//public struct AutomaticMediaDownloadCategory: PostboxCoding, Equatable {
//    public var cellular: Bool
//    public var cellularSizeLimit: Int32
//    public var cellularPredownload: Bool
//    public var wifi: Bool
//    public var wifiSizeLimit: Int32
//    public var wifiPredownload: Bool
//
//    public init(cellular: Bool, cellularSizeLimit: Int32, cellularPredownload: Bool, wifi: Bool, wifiSizeLimit: Int32, wifiPredownload: Bool) {
//        self.cellular = cellular
//        self.cellularSizeLimit = cellularSizeLimit
//        self.cellularPredownload = cellularPredownload
//        self.wifi = wifi
//        self.wifiSizeLimit = wifiSizeLimit
//        self.wifiPredownload = wifiPredownload
//    }
//
//    public init(decoder: PostboxDecoder) {
//        self.cellular = decoder.decodeInt32ForKey("cellular", orElse: 0) != 0
//        self.cellularPredownload = decoder.decodeInt32ForKey("cellularPredownload", orElse: 0) != 0
//        self.wifi = decoder.decodeInt32ForKey("wifi", orElse: 0) != 0
//        self.wifiPredownload = decoder.decodeInt32ForKey("wifiPredownload", orElse: 0) != 0
//        if let cellularSizeLimit = decoder.decodeOptionalInt32ForKey("cellularSizeLimit"), let wifiSizeLimit = decoder.decodeOptionalInt32ForKey("wifiSizeLimit")  {
//            self.cellularSizeLimit = cellularSizeLimit
//            self.wifiSizeLimit = wifiSizeLimit
//        } else {
//            let sizeLimit = decoder.decodeInt32ForKey("sizeLimit", orElse: 0)
//            self.cellularSizeLimit = sizeLimit
//            self.wifiSizeLimit = sizeLimit
//        }
//    }
//
//    public func encode(_ encoder: PostboxEncoder) {
//        encoder.encodeInt32(self.cellular ? 1 : 0, forKey: "cellular")
//        encoder.encodeInt32(self.cellularSizeLimit, forKey: "cellularSizeLimit")
//        encoder.encodeInt32(self.cellularPredownload ? 1 : 0, forKey: "cellularPredownload")
//        encoder.encodeInt32(self.wifi ? 1 : 0, forKey: "wifi")
//        encoder.encodeInt32(self.wifiSizeLimit, forKey: "wifiSizeLimit")
//        encoder.encodeInt32(self.wifiPredownload ? 1 : 0, forKey: "wifiPredownload")
//    }
//}
//
//public struct AutomaticMediaDownloadCategories: Equatable, PostboxCoding {
//    public var photo: AutomaticMediaDownloadCategory
//    public var video: AutomaticMediaDownloadCategory
//    public var file: AutomaticMediaDownloadCategory
//    public var saveDownloadedPhotos: Bool
//
//    public init(photo: AutomaticMediaDownloadCategory, video: AutomaticMediaDownloadCategory, file: AutomaticMediaDownloadCategory, saveDownloadedPhotos: Bool) {
//        self.photo = photo
//        self.video = video
//        self.file = file
//        self.saveDownloadedPhotos = saveDownloadedPhotos
//    }
//
//    public init(decoder: PostboxDecoder) {
//        self.photo = decoder.decodeObjectForKey("photo", decoder: AutomaticMediaDownloadCategory.init(decoder:)) as! AutomaticMediaDownloadCategory
//        self.video = decoder.decodeObjectForKey("video", decoder: AutomaticMediaDownloadCategory.init(decoder:)) as! AutomaticMediaDownloadCategory
//        self.file = decoder.decodeObjectForKey("file", decoder: AutomaticMediaDownloadCategory.init(decoder:)) as! AutomaticMediaDownloadCategory
//        self.saveDownloadedPhotos = decoder.decodeInt32ForKey("saveDownloadedPhotos", orElse: 0) != 0
//    }
//
//    public func encode(_ encoder: PostboxEncoder) {
//        encoder.encodeObject(self.photo, forKey: "photo")
//        encoder.encodeObject(self.video, forKey: "video")
//        encoder.encodeObject(self.file, forKey: "file")
//        encoder.encodeInt32(self.saveDownloadedPhotos ? 1 : 0, forKey: "saveDownloadedPhotos")
//    }
//}
//
//public struct AutomaticMediaDownloadPeers: Equatable, PostboxCoding {
//    public var contacts: AutomaticMediaDownloadCategories
//    public var otherPrivate: AutomaticMediaDownloadCategories
//    public var groups: AutomaticMediaDownloadCategories
//    public var channels: AutomaticMediaDownloadCategories
//
//    public init(contacts: AutomaticMediaDownloadCategories, otherPrivate: AutomaticMediaDownloadCategories, groups: AutomaticMediaDownloadCategories, channels: AutomaticMediaDownloadCategories) {
//        self.contacts = contacts
//        self.otherPrivate = otherPrivate
//        self.groups = groups
//        self.channels = channels
//    }
//
//    public init(decoder: PostboxDecoder) {
//        self.contacts = decoder.decodeObjectForKey("contacts", decoder: AutomaticMediaDownloadCategories.init(decoder:)) as! AutomaticMediaDownloadCategories
//        self.otherPrivate = decoder.decodeObjectForKey("otherPrivate", decoder: AutomaticMediaDownloadCategories.init(decoder:)) as! AutomaticMediaDownloadCategories
//        self.groups = decoder.decodeObjectForKey("groups", decoder: AutomaticMediaDownloadCategories.init(decoder:)) as! AutomaticMediaDownloadCategories
//        self.channels = decoder.decodeObjectForKey("channels", decoder: AutomaticMediaDownloadCategories.init(decoder:)) as! AutomaticMediaDownloadCategories
//    }
//
//    public func encode(_ encoder: PostboxEncoder) {
//        encoder.encodeObject(self.contacts, forKey: "contacts")
//        encoder.encodeObject(self.otherPrivate, forKey: "otherPrivate")
//        encoder.encodeObject(self.groups, forKey: "groups")
//        encoder.encodeObject(self.channels, forKey: "channels")
//    }
//}
//
//public struct AutomaticMediaDownloadSettings: PreferencesEntry, Equatable {
//    public var cellularEnabled: Bool
//    public var wifiEnabled: Bool
//    public var peers: AutomaticMediaDownloadPeers
//    public var autoplayGifs: Bool
//    public var autoplayVideos: Bool
//    public var downloadInBackground: Bool
//
//    public static var defaultSettings: AutomaticMediaDownloadSettings {
//        let defaultCategory = AutomaticMediaDownloadCategories(
//            photo: AutomaticMediaDownloadCategory(cellular: true, cellularSizeLimit: Int32.max, cellularPredownload: false, wifi: true, wifiSizeLimit: Int32.max, wifiPredownload: false),
//            video: AutomaticMediaDownloadCategory(cellular: true, cellularSizeLimit: 5 * 1024 * 1024, cellularPredownload: true, wifi: true, wifiSizeLimit: 10 * 1024 * 1024, wifiPredownload: true),
//            file: AutomaticMediaDownloadCategory(cellular: false, cellularSizeLimit: 1 * 1024 * 1024, cellularPredownload: false, wifi: false, wifiSizeLimit: 3 * 1024 * 1024, wifiPredownload: false),
//            saveDownloadedPhotos: false
//        )
//        return AutomaticMediaDownloadSettings(cellularEnabled: true, wifiEnabled: true, peers: AutomaticMediaDownloadPeers(
//            contacts: defaultCategory,
//            otherPrivate: defaultCategory,
//            groups: defaultCategory,
//            channels: defaultCategory
//        ), autoplayGifs: true, autoplayVideos: true, downloadInBackground: true)
//    }
//
//    init(cellularEnabled: Bool, wifiEnabled: Bool, peers: AutomaticMediaDownloadPeers, autoplayGifs: Bool, autoplayVideos: Bool, downloadInBackground: Bool) {
//        self.cellularEnabled = cellularEnabled
//        self.wifiEnabled = wifiEnabled
//        self.peers = peers
//        self.autoplayGifs = autoplayGifs
//        self.autoplayVideos = autoplayVideos
//        self.downloadInBackground = downloadInBackground
//    }
//
//    public init(decoder: PostboxDecoder) {
//        if let cellularEnabled = decoder.decodeOptionalInt32ForKey("cellularEnabled"), let wifiEnabled = decoder.decodeOptionalInt32ForKey("wifiEnabled")  {
//            self.cellularEnabled = cellularEnabled != 0
//            self.wifiEnabled = wifiEnabled != 0
//        } else {
//            let masterEnabled = decoder.decodeInt32ForKey("masterEnabled", orElse: 1) != 0
//            self.cellularEnabled = masterEnabled
//            self.wifiEnabled = masterEnabled
//        }
//        self.peers = (decoder.decodeObjectForKey("peers", decoder: AutomaticMediaDownloadPeers.init(decoder:)) as? AutomaticMediaDownloadPeers) ?? AutomaticMediaDownloadSettings.defaultSettings.peers
//        self.autoplayGifs = decoder.decodeInt32ForKey("autoplayGifs", orElse: 1) != 0
//        self.autoplayVideos = decoder.decodeInt32ForKey("autoplayVideos", orElse: 1) != 0
//        self.downloadInBackground = decoder.decodeInt32ForKey("downloadInBackground", orElse: 1) != 0
//    }
//
//    public func encode(_ encoder: PostboxEncoder) {
//        encoder.encodeInt32(self.cellularEnabled ? 1 : 0, forKey: "cellularEnabled")
//        encoder.encodeInt32(self.wifiEnabled ? 1 : 0, forKey: "wifiEnabled")
//        encoder.encodeObject(self.peers, forKey: "peers")
//        encoder.encodeInt32(self.autoplayGifs ? 1 : 0, forKey: "autoplayGifs")
//        encoder.encodeInt32(self.autoplayVideos ? 1 : 0, forKey: "autoplayVideos")
//        encoder.encodeInt32(self.downloadInBackground ? 1 : 0, forKey: "downloadInBackground")
//    }
//
//    public func isEqual(to: PreferencesEntry) -> Bool {
//        if let to = to as? AutomaticMediaDownloadSettings {
//            return self == to
//        } else {
//            return false
//        }
//    }
//}

func updateMediaDownloadSettingsInteractively(accountManager: AccountManager, _ f: @escaping (AutomaticMediaDownloadSettings) -> AutomaticMediaDownloadSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings, { entry in
            let currentSettings: AutomaticMediaDownloadSettings
            if let entry = entry as? AutomaticMediaDownloadSettings {
                currentSettings = entry
            } else {
                currentSettings = AutomaticMediaDownloadSettings.defaultSettings
            }
            let updated = f(currentSettings)
            return updated
        })
    }
}

public enum AutomaticMediaDownloadPeerType {
    case contact
    case otherPrivate
    case group
    case channel
}

public func effectiveAutodownloadCategories(settings: AutomaticMediaDownloadSettings, networkType: AutomaticDownloadNetworkType) -> AutomaticMediaDownloadCategories {
    let connection = settings.connectionSettings(for: networkType)
    switch connection.preset {
        case .custom:
            return connection.custom ?? settings.presets.medium
        case .low:
            return settings.presets.low
        case .medium:
            return settings.presets.medium
        case .high:
            return settings.presets.high
    }
}

private func categoryAndSizeForMedia(_ media: Media, categories: AutomaticMediaDownloadCategories) -> (AutomaticMediaDownloadCategory, Int32?)? {
    if media is TelegramMediaImage || media is TelegramMediaWebFile {
        return (categories.photo, 0)
    } else if let file = media as? TelegramMediaFile {
        for attribute in file.attributes {
            switch attribute {
                case .Video:
                    return (categories.video, file.size.flatMap(Int32.init))
                case let .Audio(isVoice, _, _, _, _):
                    if isVoice {
                        return (categories.file, file.size.flatMap(Int32.init))
                    }
                case .Animated:
                    return (categories.video, file.size.flatMap(Int32.init))
                default:
                    break
            }
        }
        return (categories.file, file.size.flatMap(Int32.init))
    } else {
        return nil
    }
}

func isAutodownloadEnabledForPeerType(_ peerType: AutomaticMediaDownloadPeerType, category: AutomaticMediaDownloadCategory) -> Bool {
    switch peerType {
        case .contact:
            return category.contacts
        case .otherPrivate:
            return category.otherPrivate
        case .group:
            return category.groups
        case .channel:
            return category.channels
    }
}

func isAutodownloadEnabledForAnyPeerType(category: AutomaticMediaDownloadCategory) -> Bool {
    return category.contacts || category.otherPrivate || category.groups || category.channels
}

public func shouldDownloadMediaAutomatically(settings: AutomaticMediaDownloadSettings, peerType: AutomaticMediaDownloadPeerType, networkType: AutomaticDownloadNetworkType, media: Media) -> Bool {
    if (networkType == .cellular && !settings.cellular.enabled) || (networkType == .wifi && !settings.wifi.enabled) {
        return false
    }
    if let file = media as? TelegramMediaFile, file.isSticker {
        return true
    }
    if let (category, size) = categoryAndSizeForMedia(media, categories: effectiveAutodownloadCategories(settings: settings, networkType: networkType)) {
        guard isAutodownloadEnabledForPeerType(peerType, category: category) else {
            return false
        }
        if let size = size {
            return size <= category.sizeLimit
        } else if category.sizeLimit == Int32.max {
            return true
        } else {
            return false
        }
    } else {
        return false
    }
}

public func shouldPredownloadMedia(settings: AutomaticMediaDownloadSettings, peerType: AutomaticMediaDownloadPeerType, networkType: AutomaticDownloadNetworkType, media: Media) -> Bool {
    if (networkType == .cellular && !settings.cellular.enabled) || (networkType == .wifi && !settings.wifi.enabled) {
        return false
    }
    
    if let (category, _) = categoryAndSizeForMedia(media, categories: effectiveAutodownloadCategories(settings: settings, networkType: networkType)) {
        guard isAutodownloadEnabledForPeerType(peerType, category: category) else {
            return false
        }
        return category.sizeLimit > 3 * 1024 * 1024 && category.predownload
    } else {
        return false
    }
}

