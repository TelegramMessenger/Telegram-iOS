import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import TelegramCore

public enum MediaAutoDownloadNetworkType {
    case wifi
    case cellular
}

public extension MediaAutoDownloadNetworkType {
    init(_ networkType: NetworkType) {
        switch networkType {
        case .none, .cellular:
            self = .cellular
        case .wifi:
            self = .wifi
        }
    }
}

public enum MediaAutoDownloadPreset: Int32 {
    case low
    case medium
    case high
    case custom
}

public struct MediaAutoDownloadPresets: Codable, Equatable {
    public var low: MediaAutoDownloadCategories
    public var medium: MediaAutoDownloadCategories
    public var high: MediaAutoDownloadCategories
    
    public init(low: MediaAutoDownloadCategories, medium: MediaAutoDownloadCategories, high: MediaAutoDownloadCategories) {
        self.low = low
        self.medium = medium
        self.high = high
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.low = try container.decode(MediaAutoDownloadCategories.self, forKey: "low")
        self.medium = try container.decode(MediaAutoDownloadCategories.self, forKey: "medium")
        self.high = try container.decode(MediaAutoDownloadCategories.self, forKey: "high")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.low, forKey: "low")
        try container.encode(self.medium, forKey: "medium")
        try container.encode(self.high, forKey: "high")
    }
}

public struct MediaAutoDownloadConnection: Codable, Equatable {
    public var enabled: Bool
    public var preset: MediaAutoDownloadPreset
    public var custom: MediaAutoDownloadCategories?
    
    public init(enabled: Bool, preset: MediaAutoDownloadPreset, custom: MediaAutoDownloadCategories?) {
        self.enabled = enabled
        self.preset = preset
        self.custom = custom
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.enabled = try container.decode(Int32.self, forKey: "enabled") != 0
        self.preset = MediaAutoDownloadPreset(rawValue: try container.decode(Int32.self, forKey: "preset")) ?? .medium
        self.custom = try container.decodeIfPresent(MediaAutoDownloadCategories.self, forKey: "custom")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.enabled ? 1 : 0) as Int32, forKey: "enabled")
        try container.encode(self.preset.rawValue, forKey: "preset")
        try container.encodeIfPresent(self.custom, forKey: "custom")
    }
}

public struct MediaAutoDownloadCategories: Codable, Equatable, Comparable {
    public var basePreset: MediaAutoDownloadPreset
    public var photo: MediaAutoDownloadCategory
    public var video: MediaAutoDownloadCategory
    public var file: MediaAutoDownloadCategory
    
    public init(basePreset: MediaAutoDownloadPreset, photo: MediaAutoDownloadCategory, video: MediaAutoDownloadCategory, file: MediaAutoDownloadCategory) {
        self.basePreset = basePreset
        self.photo = photo
        self.video = video
        self.file = file
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.basePreset = MediaAutoDownloadPreset(rawValue: try container.decode(Int32.self, forKey: "preset")) ?? .medium
        self.photo = try container.decode(MediaAutoDownloadCategory.self, forKey: "photo")
        self.video = try container.decode(MediaAutoDownloadCategory.self, forKey: "video")
        self.file = try container.decode(MediaAutoDownloadCategory.self, forKey: "file")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.basePreset.rawValue, forKey: "preset")
        try container.encode(self.photo, forKey: "photo")
        try container.encode(self.video, forKey: "video")
        try container.encode(self.file, forKey: "file")
    }
    
    public static func < (lhs: MediaAutoDownloadCategories, rhs: MediaAutoDownloadCategories) -> Bool {
        let lhsSizeLimit: Int64 = Int64((isAutodownloadEnabledForAnyPeerType(category: lhs.video) ? lhs.video.sizeLimit : 0)) + Int64((isAutodownloadEnabledForAnyPeerType(category: lhs.file) ? lhs.file.sizeLimit : 0))
        let rhsSizeLimit: Int64 = Int64((isAutodownloadEnabledForAnyPeerType(category: rhs.video) ? rhs.video.sizeLimit : 0)) + Int64((isAutodownloadEnabledForAnyPeerType(category: rhs.file) ? rhs.file.sizeLimit : 0))
        return lhsSizeLimit < rhsSizeLimit
    }
}

public struct MediaAutoDownloadCategory: Codable, Equatable {
    public var contacts: Bool
    public var otherPrivate: Bool
    public var groups: Bool
    public var channels: Bool
    public var sizeLimit: Int64
    public var predownload: Bool
    
    public init(contacts: Bool, otherPrivate: Bool, groups: Bool, channels: Bool, sizeLimit: Int64, predownload: Bool) {
        self.contacts = contacts
        self.otherPrivate = otherPrivate
        self.groups = groups
        self.channels = channels
        self.sizeLimit = sizeLimit
        self.predownload = predownload
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.contacts = try container.decode(Int32.self, forKey: "contacts") != 0
        self.otherPrivate = try container.decode(Int32.self, forKey: "otherPrivate") != 0
        self.groups = try container.decode(Int32.self, forKey: "groups") != 0
        self.channels = try container.decode(Int32.self, forKey: "channels") != 0
        if let sizeLimit = try container.decodeIfPresent(Int64.self, forKey: "size64") {
            self.sizeLimit = sizeLimit
        } else {
            self.sizeLimit = Int64(try container.decode(Int32.self, forKey: "size"))
        }
        self.predownload = try container.decode(Int32.self, forKey: "predownload") != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.contacts ? 1 : 0) as Int32, forKey: "contacts")
        try container.encode((self.otherPrivate ? 1 : 0) as Int32, forKey: "otherPrivate")
        try container.encode((self.groups ? 1 : 0) as Int32, forKey: "groups")
        try container.encode((self.channels ? 1 : 0) as Int32, forKey: "channels")
        try container.encode(self.sizeLimit, forKey: "size64")
        try container.encode((self.predownload ? 1 : 0) as Int32, forKey: "predownload")
    }
}

public struct MediaAutoDownloadSettings: Codable, Equatable {
    public var presets: MediaAutoDownloadPresets
    public var cellular: MediaAutoDownloadConnection
    public var wifi: MediaAutoDownloadConnection
    public var saveDownloadedPhotos: MediaAutoDownloadCategory
    
    public var autoplayGifs: Bool
    public var autoplayVideos: Bool
    public var downloadInBackground: Bool
    
    public static var defaultSettings: MediaAutoDownloadSettings {
        let mb: Int64 = 1024 * 1024
        let presets = MediaAutoDownloadPresets(low: MediaAutoDownloadCategories(basePreset: .low, photo: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false),
                                                                                video: MediaAutoDownloadCategory(contacts: false, otherPrivate: false, groups: false, channels: false, sizeLimit: 1 * mb, predownload: false),
                                                                                file: MediaAutoDownloadCategory(contacts: false, otherPrivate: false, groups: false, channels: false, sizeLimit: 1 * mb, predownload: false)),
                                               medium: MediaAutoDownloadCategories(basePreset: .medium, photo: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false),
                                                                                video: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: Int64(2.5 * CGFloat(mb)), predownload: false),
                                                                                file: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false)),
                                               high: MediaAutoDownloadCategories(basePreset: .high, photo: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false),
                                                                                video: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 10 * mb, predownload: true),
                                                                                file: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 3 * mb, predownload: false)))
        let saveDownloadedPhotos = MediaAutoDownloadCategory(contacts: false, otherPrivate: false, groups: false, channels: false, sizeLimit: 0, predownload: false)
        
        return MediaAutoDownloadSettings(presets: presets, cellular: MediaAutoDownloadConnection(enabled: true, preset: .medium, custom: nil), wifi: MediaAutoDownloadConnection(enabled: true, preset: .high, custom: nil), saveDownloadedPhotos: saveDownloadedPhotos, autoplayGifs: true, autoplayVideos: true, downloadInBackground: true)
    }
    
    public init(presets: MediaAutoDownloadPresets, cellular: MediaAutoDownloadConnection, wifi: MediaAutoDownloadConnection, saveDownloadedPhotos: MediaAutoDownloadCategory, autoplayGifs: Bool, autoplayVideos: Bool, downloadInBackground: Bool) {
        self.presets = presets
        self.cellular = cellular
        self.wifi = wifi
        self.saveDownloadedPhotos = saveDownloadedPhotos
        self.autoplayGifs = autoplayGifs
        self.autoplayVideos = autoplayGifs
        self.downloadInBackground = downloadInBackground
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        let defaultSettings = MediaAutoDownloadSettings.defaultSettings
        
        self.presets = defaultSettings.presets

        self.cellular = (try? container.decodeIfPresent(MediaAutoDownloadConnection.self, forKey: "cellular")) ?? defaultSettings.cellular
        self.wifi = (try? container.decodeIfPresent(MediaAutoDownloadConnection.self, forKey: "wifi")) ?? defaultSettings.wifi

        self.saveDownloadedPhotos = (try? container.decodeIfPresent(MediaAutoDownloadCategory.self, forKey: "saveDownloadedPhotos")) ?? defaultSettings.saveDownloadedPhotos

        self.autoplayGifs = try container.decode(Int32.self, forKey: "autoplayGifs") != 0
        self.autoplayVideos = try container.decode(Int32.self, forKey: "autoplayVideos") != 0
        self.downloadInBackground = try container.decode(Int32.self, forKey: "downloadInBackground") != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.cellular, forKey: "cellular")
        try container.encode(self.wifi, forKey: "wifi")
        try container.encode(self.saveDownloadedPhotos, forKey: "saveDownloadedPhotos")
        try container.encode((self.autoplayGifs ? 1 : 0) as Int32, forKey: "autoplayGifs")
        try container.encode((self.autoplayVideos ? 1 : 0) as Int32, forKey: "autoplayVideos")
        try container.encode((self.downloadInBackground ? 1 : 0) as Int32, forKey: "downloadInBackground")
    }
    
    public func connectionSettings(for networkType: MediaAutoDownloadNetworkType) -> MediaAutoDownloadConnection {
        switch networkType {
            case .cellular:
                return self.cellular
            case .wifi:
                return self.wifi
        }
    }
    
    public func updatedWithAutodownloadSettings(_ autodownloadSettings: AutodownloadSettings) -> MediaAutoDownloadSettings {
        var settings = self
        settings.presets = presetsWithAutodownloadSettings(autodownloadSettings)
        return settings
    }
}

private func categoriesWithAutodownloadPreset(_ autodownloadPreset: AutodownloadPresetSettings, preset: MediaAutoDownloadPreset) -> MediaAutoDownloadCategories {
    let videoEnabled = autodownloadPreset.videoSizeMax > 0
    let videoSizeMax = autodownloadPreset.videoSizeMax > 0 ? autodownloadPreset.videoSizeMax : 1 * 1024 * 1024
    let fileEnabled = autodownloadPreset.fileSizeMax > 0
    let fileSizeMax = autodownloadPreset.fileSizeMax > 0 ? autodownloadPreset.fileSizeMax : 1 * 1024 * 1024
    
    return MediaAutoDownloadCategories(basePreset: preset, photo: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: autodownloadPreset.photoSizeMax, predownload: false), video: MediaAutoDownloadCategory(contacts: videoEnabled, otherPrivate: videoEnabled, groups: videoEnabled, channels: videoEnabled, sizeLimit: videoSizeMax, predownload: autodownloadPreset.preloadLargeVideo), file: MediaAutoDownloadCategory(contacts: fileEnabled, otherPrivate: fileEnabled, groups: fileEnabled, channels: fileEnabled, sizeLimit: fileSizeMax, predownload: false))
}

private func presetsWithAutodownloadSettings(_ autodownloadSettings: AutodownloadSettings) -> MediaAutoDownloadPresets {
    return MediaAutoDownloadPresets(low: categoriesWithAutodownloadPreset(autodownloadSettings.lowPreset, preset: .low), medium: categoriesWithAutodownloadPreset(autodownloadSettings.mediumPreset, preset: .medium), high: categoriesWithAutodownloadPreset(autodownloadSettings.highPreset, preset: .high))
}

public func updateMediaDownloadSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (MediaAutoDownloadSettings) -> MediaAutoDownloadSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings, { entry in
            let currentSettings: MediaAutoDownloadSettings
            if let entry = entry?.get(MediaAutoDownloadSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = MediaAutoDownloadSettings.defaultSettings
            }
            let updated = f(currentSettings)
            return PreferencesEntry(updated)
        })
    }
}

public enum MediaAutoDownloadPeerType {
    case contact
    case otherPrivate
    case group
    case channel
}

public func effectiveAutodownloadCategories(settings: MediaAutoDownloadSettings, networkType: MediaAutoDownloadNetworkType) -> MediaAutoDownloadCategories {
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

private func categoryAndSizeForMedia(_ media: Media, categories: MediaAutoDownloadCategories) -> (MediaAutoDownloadCategory, Int32?)? {
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

public func isAutodownloadEnabledForPeerType(_ peerType: MediaAutoDownloadPeerType, category: MediaAutoDownloadCategory) -> Bool {
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

public func isAutodownloadEnabledForAnyPeerType(category: MediaAutoDownloadCategory) -> Bool {
    return category.contacts || category.otherPrivate || category.groups || category.channels
}

public func shouldDownloadMediaAutomatically(settings: MediaAutoDownloadSettings, peerType: MediaAutoDownloadPeerType, networkType: MediaAutoDownloadNetworkType, authorPeerId: PeerId? = nil, contactsPeerIds: Set<PeerId> = Set(), media: Media) -> Bool {
    if (networkType == .cellular && !settings.cellular.enabled) || (networkType == .wifi && !settings.wifi.enabled) {
        return false
    }
    if let file = media as? TelegramMediaFile, file.isSticker {
        return true
    }
    
    var peerType = peerType
    if case .group = peerType, let authorPeerId = authorPeerId, contactsPeerIds.contains(authorPeerId) {
        peerType = .contact
    }
    
    if let (category, size) = categoryAndSizeForMedia(media, categories: effectiveAutodownloadCategories(settings: settings, networkType: networkType)) {
        if let size = size {
            var sizeLimit = category.sizeLimit
            if let file = media as? TelegramMediaFile, file.isVoice {
                sizeLimit = max(2 * 1024 * 1024, sizeLimit)
            } else if !isAutodownloadEnabledForPeerType(peerType, category: category) {
                return false
            }
            return size <= sizeLimit
        } else if media.id?.namespace == Namespaces.Media.LocalFile {
            return true
        } else if category.sizeLimit == Int32.max {
            return true
        } else {
            return false
        }
    } else {
        return false
    }
}

public func shouldPredownloadMedia(settings: MediaAutoDownloadSettings, peerType: MediaAutoDownloadPeerType, networkType: MediaAutoDownloadNetworkType, media: Media) -> Bool {
    if #available(iOSApplicationExtension 10.3, *) {
        if (networkType == .cellular && !settings.cellular.enabled) || (networkType == .wifi && !settings.wifi.enabled) {
            return false
        }
        
        if let (category, _) = categoryAndSizeForMedia(media, categories: effectiveAutodownloadCategories(settings: settings, networkType: networkType)) {
            guard isAutodownloadEnabledForPeerType(peerType, category: category) else {
                return false
            }
            return category.sizeLimit > 2 * 1024 * 1024 && category.predownload
        } else {
            return false
        }
    } else {
        return false
    }
}

