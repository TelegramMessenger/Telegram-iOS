import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore

public struct AutomaticMediaDownloadCategory: PostboxCoding, Equatable {
    public var cellular: Bool
    public var wifi: Bool
    public var sizeLimit: Int32
    
    public init(cellular: Bool, wifi: Bool, sizeLimit: Int32) {
        self.cellular = cellular
        self.wifi = wifi
        self.sizeLimit = sizeLimit
    }
    
    public init(decoder: PostboxDecoder) {
        self.cellular = decoder.decodeInt32ForKey("cellular", orElse: 0) != 0
        self.wifi = decoder.decodeInt32ForKey("wifi", orElse: 0) != 0
        self.sizeLimit = decoder.decodeInt32ForKey("sizeLimit", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.cellular ? 1 : 0, forKey: "cellular")
        encoder.encodeInt32(self.wifi ? 1 : 0, forKey: "wifi")
        encoder.encodeInt32(self.sizeLimit, forKey: "sizeLimit")
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
    public var masterEnabled: Bool
    public var peers: AutomaticMediaDownloadPeers
    public var autoplayGifs: Bool
    public var downloadInBackground: Bool
    
    public static var defaultSettings: AutomaticMediaDownloadSettings {
        let defaultCategory = AutomaticMediaDownloadCategories(
            photo: AutomaticMediaDownloadCategory(cellular: true, wifi: true, sizeLimit: 1 * 1024 * 1024),
            video: AutomaticMediaDownloadCategory(cellular: false, wifi: false, sizeLimit: 1 * 1024 * 1024),
            file: AutomaticMediaDownloadCategory(cellular: false, wifi: false, sizeLimit: 1 * 1024 * 1024),
            voiceMessage: AutomaticMediaDownloadCategory(cellular: true, wifi: true, sizeLimit: 1 * 1024 * 1024),
            videoMessage: AutomaticMediaDownloadCategory(cellular: true, wifi: true, sizeLimit: 4 * 1024 * 1024),
            saveDownloadedPhotos: false
        )
        return AutomaticMediaDownloadSettings(masterEnabled: true, peers: AutomaticMediaDownloadPeers(
            contacts: defaultCategory,
            otherPrivate: defaultCategory,
            groups: defaultCategory,
            channels: defaultCategory
        ), autoplayGifs: true, downloadInBackground: true)
    }
    
    init(masterEnabled: Bool, peers: AutomaticMediaDownloadPeers, autoplayGifs: Bool, downloadInBackground: Bool) {
        self.masterEnabled = masterEnabled
        self.peers = peers
        self.autoplayGifs = autoplayGifs
        self.downloadInBackground = downloadInBackground
    }
    
    public init(decoder: PostboxDecoder) {
        self.masterEnabled = decoder.decodeInt32ForKey("masterEnabled", orElse: 1) != 0
        self.peers = (decoder.decodeObjectForKey("peers", decoder: AutomaticMediaDownloadPeers.init(decoder:)) as? AutomaticMediaDownloadPeers) ?? AutomaticMediaDownloadSettings.defaultSettings.peers
        self.autoplayGifs = decoder.decodeInt32ForKey("autoplayGifs", orElse: 1) != 0
        self.downloadInBackground = decoder.decodeInt32ForKey("downloadInBackground", orElse: 1) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.masterEnabled ? 1 : 0, forKey: "masterEnabled")
        encoder.encodeObject(self.peers, forKey: "peers")
        encoder.encodeInt32(self.autoplayGifs ? 1 : 0, forKey: "autoplayGifs")
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
                        var category = categories.videoMessage
                        category.sizeLimit = max(category.sizeLimit, 4 * 1024 * 1024)
                        return (category, file.size.flatMap(Int32.init))
                    } else {
                        if file.isAnimated {
                            var category = categories.videoMessage
                            category.sizeLimit = max(category.sizeLimit, 1 * 1024 * 1024)
                            return (category, file.size.flatMap(Int32.init))
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
    if !settings.masterEnabled {
        return false
    }
    if let file = media as? TelegramMediaFile, file.isSticker {
        return true
    }
    if let (category, size) = categoryForPeerAndMedia(settings: settings, peerType: peerType, media: media) {
        switch networkType {
            case .cellular:
                if let size = size {
                    return category.cellular && size <= category.sizeLimit
                } else if category.sizeLimit == Int32.max {
                    return category.cellular
                } else {
                    return false
                }
            case .wifi:
                if let size = size {
                    return category.wifi && size <= category.sizeLimit
                } else if category.sizeLimit == Int32.max {
                    return category.wifi
                } else {
                    return false
                }
        }
    } else {
        return false
    }
}
