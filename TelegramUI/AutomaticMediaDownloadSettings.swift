import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore


public struct AutomaticMediaDownloadCategory: PostboxCoding, Equatable {
    public var cellular: Bool
    public var cellularSizeLimit: Int32
    public var wifi: Bool
    public var wifiSizeLimit: Int32
    
    public init(cellular: Bool, cellularSizeLimit: Int32, wifi: Bool, wifiSizeLimit: Int32) {
        self.cellular = cellular
        self.cellularSizeLimit = cellularSizeLimit
        self.wifi = wifi
        self.wifiSizeLimit = wifiSizeLimit
    }
    
    public init(decoder: PostboxDecoder) {
        self.cellular = decoder.decodeInt32ForKey("cellular", orElse: 0) != 0
        self.wifi = decoder.decodeInt32ForKey("wifi", orElse: 0) != 0
        if let cellularSizeLimit = decoder.decodeOptionalInt32ForKey("cellularSizeLimit"), let wifiSizeLimit = decoder.decodeOptionalInt32ForKey("wifiSizeLimit")  {
            self.cellularSizeLimit = cellularSizeLimit
            self.wifiSizeLimit = wifiSizeLimit
        } else {
            let sizeLimit = decoder.decodeInt32ForKey("sizeLimit", orElse: 0)
            self.cellularSizeLimit = sizeLimit
            self.wifiSizeLimit = sizeLimit
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.cellular ? 1 : 0, forKey: "cellular")
        encoder.encodeInt32(self.cellularSizeLimit, forKey: "cellularSizeLimit")
        encoder.encodeInt32(self.wifi ? 1 : 0, forKey: "wifi")
        encoder.encodeInt32(self.wifiSizeLimit, forKey: "wifiSizeLimit")
    }
}

public struct AutomaticMediaDownloadCategories: Equatable, PostboxCoding {
    public var photo: AutomaticMediaDownloadCategory
    public var video: AutomaticMediaDownloadCategory
    public var file: AutomaticMediaDownloadCategory
    public var voiceMessage: AutomaticMediaDownloadCategory
    public var videoMessage: AutomaticMediaDownloadCategory
    public var saveDownloadedPhotos: Bool
    
    public init(photo: AutomaticMediaDownloadCategory, video: AutomaticMediaDownloadCategory, file: AutomaticMediaDownloadCategory, voiceMessage: AutomaticMediaDownloadCategory, videoMessage: AutomaticMediaDownloadCategory, saveDownloadedPhotos: Bool) {
        self.photo = photo
        self.video = video
        self.file = file
        self.voiceMessage = voiceMessage
        self.videoMessage = videoMessage
        self.saveDownloadedPhotos = saveDownloadedPhotos
    }
    
    public init(decoder: PostboxDecoder) {
        self.photo = decoder.decodeObjectForKey("photo", decoder: AutomaticMediaDownloadCategory.init(decoder:)) as! AutomaticMediaDownloadCategory
        self.video = decoder.decodeObjectForKey("video", decoder: AutomaticMediaDownloadCategory.init(decoder:)) as! AutomaticMediaDownloadCategory
        self.file = decoder.decodeObjectForKey("file", decoder: AutomaticMediaDownloadCategory.init(decoder:)) as! AutomaticMediaDownloadCategory
        self.voiceMessage = decoder.decodeObjectForKey("voiceMessage", decoder: AutomaticMediaDownloadCategory.init(decoder:)) as! AutomaticMediaDownloadCategory
        self.videoMessage = decoder.decodeObjectForKey("videoMessage", decoder: AutomaticMediaDownloadCategory.init(decoder:)) as! AutomaticMediaDownloadCategory
        self.saveDownloadedPhotos = decoder.decodeInt32ForKey("saveDownloadedPhotos", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.photo, forKey: "photo")
        encoder.encodeObject(self.video, forKey: "video")
        encoder.encodeObject(self.file, forKey: "file")
        encoder.encodeObject(self.voiceMessage, forKey: "voiceMessage")
        encoder.encodeObject(self.videoMessage, forKey: "videoMessage")
        encoder.encodeInt32(self.saveDownloadedPhotos ? 1 : 0, forKey: "saveDownloadedPhotos")
    }
}

public struct AutomaticMediaDownloadPeers: Equatable, PostboxCoding {
    public var contacts: AutomaticMediaDownloadCategories
    public var otherPrivate: AutomaticMediaDownloadCategories
    public var groups: AutomaticMediaDownloadCategories
    public var channels: AutomaticMediaDownloadCategories
    
    public init(contacts: AutomaticMediaDownloadCategories, otherPrivate: AutomaticMediaDownloadCategories, groups: AutomaticMediaDownloadCategories, channels: AutomaticMediaDownloadCategories) {
        self.contacts = contacts
        self.otherPrivate = otherPrivate
        self.groups = groups
        self.channels = channels
    }
    
    public init(decoder: PostboxDecoder) {
        self.contacts = decoder.decodeObjectForKey("contacts", decoder: AutomaticMediaDownloadCategories.init(decoder:)) as! AutomaticMediaDownloadCategories
        self.otherPrivate = decoder.decodeObjectForKey("otherPrivate", decoder: AutomaticMediaDownloadCategories.init(decoder:)) as! AutomaticMediaDownloadCategories
        self.groups = decoder.decodeObjectForKey("groups", decoder: AutomaticMediaDownloadCategories.init(decoder:)) as! AutomaticMediaDownloadCategories
        self.channels = decoder.decodeObjectForKey("channels", decoder: AutomaticMediaDownloadCategories.init(decoder:)) as! AutomaticMediaDownloadCategories
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.contacts, forKey: "contacts")
        encoder.encodeObject(self.otherPrivate, forKey: "otherPrivate")
        encoder.encodeObject(self.groups, forKey: "groups")
        encoder.encodeObject(self.channels, forKey: "channels")
    }
}

public struct AutomaticMediaDownloadSettings: PreferencesEntry, Equatable {
    public var cellularEnabled: Bool
    public var wifiEnabled: Bool
    public var peers: AutomaticMediaDownloadPeers
    public var autoplayGifs: Bool
    public var autoplayVideos: Bool
    public var downloadInBackground: Bool
    
    public static var defaultSettings: AutomaticMediaDownloadSettings {
        let defaultCategory = AutomaticMediaDownloadCategories(
            photo: AutomaticMediaDownloadCategory(cellular: true, cellularSizeLimit: Int32.max, wifi: true, wifiSizeLimit: Int32.max),
            video: AutomaticMediaDownloadCategory(cellular: true, cellularSizeLimit: 10 * 1024 * 1024, wifi: true, wifiSizeLimit: 10 * 1024 * 1024),
            file: AutomaticMediaDownloadCategory(cellular: false, cellularSizeLimit: 1 * 1024 * 1024, wifi: false, wifiSizeLimit: 1 * 1024 * 1024),
            voiceMessage: AutomaticMediaDownloadCategory(cellular: true, cellularSizeLimit: 1 * 1024 * 1024, wifi: true, wifiSizeLimit: 1 * 1024 * 1024),
            videoMessage: AutomaticMediaDownloadCategory(cellular: true, cellularSizeLimit: 4 * 1024 * 1024, wifi: true, wifiSizeLimit: 4 * 1024 * 1024),
            saveDownloadedPhotos: false
        )
        return AutomaticMediaDownloadSettings(cellularEnabled: true, wifiEnabled: true, peers: AutomaticMediaDownloadPeers(
            contacts: defaultCategory,
            otherPrivate: defaultCategory,
            groups: defaultCategory,
            channels: defaultCategory
        ), autoplayGifs: true, autoplayVideos: true, downloadInBackground: true)
    }
    
    init(cellularEnabled: Bool, wifiEnabled: Bool, peers: AutomaticMediaDownloadPeers, autoplayGifs: Bool, autoplayVideos: Bool, downloadInBackground: Bool) {
        self.cellularEnabled = cellularEnabled
        self.wifiEnabled = wifiEnabled
        self.peers = peers
        self.autoplayGifs = autoplayGifs
        self.autoplayVideos = autoplayVideos
        self.downloadInBackground = downloadInBackground
    }
    
    public init(decoder: PostboxDecoder) {
        if let cellularEnabled = decoder.decodeOptionalInt32ForKey("cellularEnabled"), let wifiEnabled = decoder.decodeOptionalInt32ForKey("wifiEnabled")  {
            self.cellularEnabled = cellularEnabled != 0
            self.wifiEnabled = wifiEnabled != 0
        } else {
            let masterEnabled = decoder.decodeInt32ForKey("masterEnabled", orElse: 1) != 0
            self.cellularEnabled = masterEnabled
            self.wifiEnabled = masterEnabled
        }
        self.peers = (decoder.decodeObjectForKey("peers", decoder: AutomaticMediaDownloadPeers.init(decoder:)) as? AutomaticMediaDownloadPeers) ?? AutomaticMediaDownloadSettings.defaultSettings.peers
        self.autoplayGifs = decoder.decodeInt32ForKey("autoplayGifs", orElse: 1) != 0
        self.autoplayVideos = decoder.decodeInt32ForKey("autoplayVideos", orElse: 1) != 0
        self.downloadInBackground = decoder.decodeInt32ForKey("downloadInBackground", orElse: 1) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.cellularEnabled ? 1 : 0, forKey: "cellularEnabled")
        encoder.encodeInt32(self.wifiEnabled ? 1 : 0, forKey: "wifiEnabled")
        encoder.encodeObject(self.peers, forKey: "peers")
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
}

public func updatedAutomaticMediaDownloadSettings(accountManager: AccountManager) -> Signal<AutomaticMediaDownloadSettings, NoError> {
    return accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings])
    |> map { view -> AutomaticMediaDownloadSettings in
        let automaticMediaDownloadSettings: AutomaticMediaDownloadSettings
        if let value = view.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings] as? AutomaticMediaDownloadSettings {
            automaticMediaDownloadSettings = value
        } else {
            automaticMediaDownloadSettings = AutomaticMediaDownloadSettings.defaultSettings
        }
        return automaticMediaDownloadSettings
    }
}

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

public enum AutomaticDownloadNetworkType {
    case wifi
    case cellular
}

private func categoriesForPeerType(_ type: AutomaticMediaDownloadPeerType, settings: AutomaticMediaDownloadSettings) -> AutomaticMediaDownloadCategories {
    switch type {
        case .contact:
            return settings.peers.contacts
        case .otherPrivate:
            return settings.peers.otherPrivate
        case .group:
            return settings.peers.groups
        case .channel:
            return settings.peers.channels
    }
}

private func categoryForPeerAndMedia(settings: AutomaticMediaDownloadSettings, peerType: AutomaticMediaDownloadPeerType, media: Media) -> (AutomaticMediaDownloadCategory, Int32?)? {
    let categories = categoriesForPeerType(peerType, settings: settings)
    if media is TelegramMediaImage || media is TelegramMediaWebFile {
        return (categories.photo, nil)
    } else if let file = media as? TelegramMediaFile {
        for attribute in file.attributes {
            switch attribute {
                case let .Video(_, _, flags):
                    if flags.contains(.instantRoundVideo) {
                        //category.sizeLimit = max(category.sizeLimit, 4 * 1024 * 1024)
                        return (categories.videoMessage, file.size.flatMap(Int32.init))
                    } else {
                        if file.isAnimated {
                            //category.sizeLimit = max(category.sizeLimit, 1 * 1024 * 1024)
                            return (categories.videoMessage, file.size.flatMap(Int32.init))
                        } else {
                            return (categories.video, file.size.flatMap(Int32.init))
                        }
                    }
                case let .Audio(isVoice, _, _, _, _):
                    if isVoice {
                        return (categories.voiceMessage, file.size.flatMap(Int32.init))
                    }
                case .Animated:
                    return (categories.videoMessage, file.size.flatMap(Int32.init))
                default:
                    break
            }
        }
        return (categories.file, file.size.flatMap(Int32.init))
    } else {
        return nil
    }
}

public func shouldDownloadMediaAutomatically(settings: AutomaticMediaDownloadSettings, peerType: AutomaticMediaDownloadPeerType, networkType: AutomaticDownloadNetworkType, media: Media) -> Bool {
    if (networkType == .cellular && !settings.cellularEnabled) || (networkType == .wifi && !settings.wifiEnabled) {
        return false
    }
    if let file = media as? TelegramMediaFile, file.isSticker {
        return true
    }
    if let (category, size) = categoryForPeerAndMedia(settings: settings, peerType: peerType, media: media) {
        switch networkType {
            case .cellular:
                if let size = size {
                    return category.cellular && size <= category.cellularSizeLimit
                } else if category.cellularSizeLimit == Int32.max {
                    return category.cellular
                } else {
                    return false
                }
            case .wifi:
                if let size = size {
                    return category.wifi && size <= category.wifiSizeLimit
                } else if category.wifiSizeLimit == Int32.max {
                    return category.wifi
                } else {
                    return false
                }
        }
    } else {
        return false
    }
}
