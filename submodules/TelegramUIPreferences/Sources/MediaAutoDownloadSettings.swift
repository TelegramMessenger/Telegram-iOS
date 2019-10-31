import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import SyncCore

public enum MediaAutoDownloadNetworkType {
    case wifi
    case cellular
}

public enum MediaAutoDownloadPreset: Int32 {
    case low
    case medium
    case high
    case custom
}

public struct MediaAutoDownloadPresets: PostboxCoding, Equatable {
    public var low: MediaAutoDownloadCategories
    public var medium: MediaAutoDownloadCategories
    public var high: MediaAutoDownloadCategories
    
    public init(low: MediaAutoDownloadCategories, medium: MediaAutoDownloadCategories, high: MediaAutoDownloadCategories) {
        self.low = low
        self.medium = medium
        self.high = high
    }
    
    public init(decoder: PostboxDecoder) {
        self.low =  decoder.decodeObjectForKey("low", decoder: MediaAutoDownloadCategories.init(decoder:)) as! MediaAutoDownloadCategories
        self.medium =  decoder.decodeObjectForKey("medium", decoder: MediaAutoDownloadCategories.init(decoder:)) as! MediaAutoDownloadCategories
        self.high =  decoder.decodeObjectForKey("high", decoder: MediaAutoDownloadCategories.init(decoder:)) as! MediaAutoDownloadCategories
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.low, forKey: "low")
        encoder.encodeObject(self.medium, forKey: "medium")
        encoder.encodeObject(self.high, forKey: "high")
    }
}

public struct MediaAutoDownloadConnection: PostboxCoding, Equatable {
    public var enabled: Bool
    public var preset: MediaAutoDownloadPreset
    public var custom: MediaAutoDownloadCategories?
    
    public init(enabled: Bool, preset: MediaAutoDownloadPreset, custom: MediaAutoDownloadCategories?) {
        self.enabled = enabled
        self.preset = preset
        self.custom = custom
    }
    
    public init(decoder: PostboxDecoder) {
        self.enabled = decoder.decodeInt32ForKey("enabled", orElse: 0) != 0
        self.preset = MediaAutoDownloadPreset(rawValue: decoder.decodeInt32ForKey("preset", orElse: 0)) ?? .medium
        self.custom = decoder.decodeObjectForKey("custom", decoder: MediaAutoDownloadCategories.init(decoder:)) as? MediaAutoDownloadCategories
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

public struct MediaAutoDownloadCategories: PostboxCoding, Equatable, Comparable {
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
    
    public init(decoder: PostboxDecoder) {
        self.basePreset = MediaAutoDownloadPreset(rawValue: decoder.decodeInt32ForKey("preset", orElse: 0)) ?? .medium
        self.photo = decoder.decodeObjectForKey("photo", decoder: MediaAutoDownloadCategory.init(decoder:)) as! MediaAutoDownloadCategory
        self.video = decoder.decodeObjectForKey("video", decoder: MediaAutoDownloadCategory.init(decoder:)) as! MediaAutoDownloadCategory
        self.file = decoder.decodeObjectForKey("file", decoder: MediaAutoDownloadCategory.init(decoder:)) as! MediaAutoDownloadCategory
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.basePreset.rawValue, forKey: "preset")
        encoder.encodeObject(self.photo, forKey: "photo")
        encoder.encodeObject(self.video, forKey: "video")
        encoder.encodeObject(self.file, forKey: "file")
    }
    
    public static func < (lhs: MediaAutoDownloadCategories, rhs: MediaAutoDownloadCategories) -> Bool {
        let lhsSizeLimit: Int64 = Int64((isAutodownloadEnabledForAnyPeerType(category: lhs.video) ? lhs.video.sizeLimit : 0)) + Int64((isAutodownloadEnabledForAnyPeerType(category: lhs.file) ? lhs.file.sizeLimit : 0))
        let rhsSizeLimit: Int64 = Int64((isAutodownloadEnabledForAnyPeerType(category: rhs.video) ? rhs.video.sizeLimit : 0)) + Int64((isAutodownloadEnabledForAnyPeerType(category: rhs.file) ? rhs.file.sizeLimit : 0))
        return lhsSizeLimit < rhsSizeLimit
    }
}

public struct MediaAutoDownloadCategory: PostboxCoding, Equatable {
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

public struct MediaAutoDownloadSettings: PreferencesEntry, Equatable {
    public var presets: MediaAutoDownloadPresets
    public var cellular: MediaAutoDownloadConnection
    public var wifi: MediaAutoDownloadConnection
    public var saveDownloadedPhotos: MediaAutoDownloadCategory
    
    public var autoplayGifs: Bool
    public var autoplayVideos: Bool
    public var downloadInBackground: Bool
    
    public static var defaultSettings: MediaAutoDownloadSettings {
        let mb: Int32 = 1024 * 1024
        let presets = MediaAutoDownloadPresets(low: MediaAutoDownloadCategories(basePreset: .low, photo: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false),
                                                                                video: MediaAutoDownloadCategory(contacts: false, otherPrivate: false, groups: false, channels: false, sizeLimit: 1 * mb, predownload: false),
                                                                                file: MediaAutoDownloadCategory(contacts: false, otherPrivate: false, groups: false, channels: false, sizeLimit: 1 * mb, predownload: false)),
                                               medium: MediaAutoDownloadCategories(basePreset: .medium, photo: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false),
                                                                                video: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: Int32(2.5 * CGFloat(mb)), predownload: false),
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
    
    public static func upgradeLegacySettings(_ settings: AutomaticMediaDownloadSettings) -> MediaAutoDownloadSettings {
        if settings == AutomaticMediaDownloadSettings.defaultSettings {
            return MediaAutoDownloadSettings.defaultSettings
        }
        
        let defaultSettings = MediaAutoDownloadSettings.defaultSettings
        let saveDownloadedPhotos = MediaAutoDownloadCategory(contacts: settings.peers.contacts.saveDownloadedPhotos, otherPrivate: settings.peers.otherPrivate.saveDownloadedPhotos, groups: settings.peers.groups.saveDownloadedPhotos, channels: settings.peers.channels.saveDownloadedPhotos, sizeLimit: 0, predownload: false)
        
        let cellular = MediaAutoDownloadConnection(enabled: settings.masterEnabled, preset: .medium, custom: nil)
        let wifi = MediaAutoDownloadConnection(enabled: settings.masterEnabled, preset: .high, custom: nil)
        
        return MediaAutoDownloadSettings(presets: defaultSettings.presets, cellular: cellular, wifi: wifi, saveDownloadedPhotos: saveDownloadedPhotos, autoplayGifs: settings.autoplayGifs, autoplayVideos: true, downloadInBackground: settings.downloadInBackground)
    }
    
    public init(decoder: PostboxDecoder) {
        let defaultSettings = MediaAutoDownloadSettings.defaultSettings
        
        self.presets = defaultSettings.presets
        self.cellular = decoder.decodeObjectForKey("cellular", decoder: MediaAutoDownloadConnection.init(decoder:)) as? MediaAutoDownloadConnection ?? defaultSettings.cellular
        self.wifi = decoder.decodeObjectForKey("wifi", decoder: MediaAutoDownloadConnection.init(decoder:)) as? MediaAutoDownloadConnection ?? defaultSettings.wifi
        self.saveDownloadedPhotos = decoder.decodeObjectForKey("saveDownloadedPhotos", decoder: MediaAutoDownloadCategory.init(decoder:)) as? MediaAutoDownloadCategory ?? defaultSettings.saveDownloadedPhotos
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
        if let to = to as? MediaAutoDownloadSettings {
            return self == to
        } else {
            return false
        }
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

public func updateMediaDownloadSettingsInteractively(accountManager: AccountManager, _ f: @escaping (MediaAutoDownloadSettings) -> MediaAutoDownloadSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings, { entry in
            let currentSettings: MediaAutoDownloadSettings
            if let entry = entry as? MediaAutoDownloadSettings {
                currentSettings = entry
            } else {
                currentSettings = MediaAutoDownloadSettings.defaultSettings
            }
            let updated = f(currentSettings)
            return updated
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

