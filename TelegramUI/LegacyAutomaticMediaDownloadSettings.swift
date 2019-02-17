import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore

public struct LegacyAutomaticMediaDownloadCategory: PostboxCoding, Equatable {
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
    }
}

public struct LegacyAutomaticMediaDownloadCategories: Equatable, PostboxCoding {
    public var photo: LegacyAutomaticMediaDownloadCategory
    public var video: LegacyAutomaticMediaDownloadCategory
    public var file: LegacyAutomaticMediaDownloadCategory
    public var voiceMessage: LegacyAutomaticMediaDownloadCategory
    public var videoMessage: LegacyAutomaticMediaDownloadCategory
    public var saveDownloadedPhotos: Bool
    
    public init(photo: LegacyAutomaticMediaDownloadCategory, video: LegacyAutomaticMediaDownloadCategory, file: LegacyAutomaticMediaDownloadCategory, voiceMessage: LegacyAutomaticMediaDownloadCategory, videoMessage: LegacyAutomaticMediaDownloadCategory, saveDownloadedPhotos: Bool) {
        self.photo = photo
        self.video = video
        self.file = file
        self.voiceMessage = voiceMessage
        self.videoMessage = videoMessage
        self.saveDownloadedPhotos = saveDownloadedPhotos
    }
    
    public init(decoder: PostboxDecoder) {
        self.photo = decoder.decodeObjectForKey("photo", decoder: LegacyAutomaticMediaDownloadCategory.init(decoder:)) as! LegacyAutomaticMediaDownloadCategory
        self.video = decoder.decodeObjectForKey("video", decoder: LegacyAutomaticMediaDownloadCategory.init(decoder:)) as! LegacyAutomaticMediaDownloadCategory
        self.file = decoder.decodeObjectForKey("file", decoder: LegacyAutomaticMediaDownloadCategory.init(decoder:)) as! LegacyAutomaticMediaDownloadCategory
        self.voiceMessage = decoder.decodeObjectForKey("voiceMessage", decoder: LegacyAutomaticMediaDownloadCategory.init(decoder:)) as! LegacyAutomaticMediaDownloadCategory
        self.videoMessage = decoder.decodeObjectForKey("videoMessage", decoder: LegacyAutomaticMediaDownloadCategory.init(decoder:)) as! LegacyAutomaticMediaDownloadCategory
        self.saveDownloadedPhotos = decoder.decodeInt32ForKey("saveDownloadedPhotos", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
}

public struct LegacyAutomaticMediaDownloadPeers: Equatable, PostboxCoding {
    public var contacts: LegacyAutomaticMediaDownloadCategories
    public var otherPrivate: LegacyAutomaticMediaDownloadCategories
    public var groups: LegacyAutomaticMediaDownloadCategories
    public var channels: LegacyAutomaticMediaDownloadCategories
    
    public init(contacts: LegacyAutomaticMediaDownloadCategories, otherPrivate: LegacyAutomaticMediaDownloadCategories, groups: LegacyAutomaticMediaDownloadCategories, channels: LegacyAutomaticMediaDownloadCategories) {
        self.contacts = contacts
        self.otherPrivate = otherPrivate
        self.groups = groups
        self.channels = channels
    }
    
    public init(decoder: PostboxDecoder) {
        self.contacts = decoder.decodeObjectForKey("contacts", decoder: LegacyAutomaticMediaDownloadCategories.init(decoder:)) as! LegacyAutomaticMediaDownloadCategories
        self.otherPrivate = decoder.decodeObjectForKey("otherPrivate", decoder: LegacyAutomaticMediaDownloadCategories.init(decoder:)) as! LegacyAutomaticMediaDownloadCategories
        self.groups = decoder.decodeObjectForKey("groups", decoder: LegacyAutomaticMediaDownloadCategories.init(decoder:)) as! LegacyAutomaticMediaDownloadCategories
        self.channels = decoder.decodeObjectForKey("channels", decoder: LegacyAutomaticMediaDownloadCategories.init(decoder:)) as! LegacyAutomaticMediaDownloadCategories
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
}

public struct LegacyAutomaticMediaDownloadSettings: PreferencesEntry, Equatable {
    public var masterEnabled: Bool
    public var peers: LegacyAutomaticMediaDownloadPeers
    public var autoplayGifs: Bool
    public var downloadInBackground: Bool
    
    public static var defaultSettings: LegacyAutomaticMediaDownloadSettings {
        let defaultCategory = LegacyAutomaticMediaDownloadCategories(
            photo: LegacyAutomaticMediaDownloadCategory(cellular: true, wifi: true, sizeLimit: Int32.max),
            video: LegacyAutomaticMediaDownloadCategory(cellular: true, wifi: true, sizeLimit: 10 * 1024 * 1024),
            file: LegacyAutomaticMediaDownloadCategory(cellular: false, wifi: false, sizeLimit: 1 * 1024 * 1024),
            voiceMessage: LegacyAutomaticMediaDownloadCategory(cellular: true, wifi: true, sizeLimit: 1 * 1024 * 1024),
            videoMessage: LegacyAutomaticMediaDownloadCategory(cellular: true, wifi: true, sizeLimit: 4 * 1024 * 1024),
            saveDownloadedPhotos: false
        )
        return LegacyAutomaticMediaDownloadSettings(masterEnabled: true, peers: LegacyAutomaticMediaDownloadPeers(
            contacts: defaultCategory,
            otherPrivate: defaultCategory,
            groups: defaultCategory,
            channels: defaultCategory
        ), autoplayGifs: true, downloadInBackground: true)
    }
    
    init(masterEnabled: Bool, peers: LegacyAutomaticMediaDownloadPeers, autoplayGifs: Bool, downloadInBackground: Bool) {
        self.masterEnabled = masterEnabled
        self.peers = peers
        self.autoplayGifs = autoplayGifs
        self.downloadInBackground = downloadInBackground
    }
    
    public init(decoder: PostboxDecoder) {
        self.masterEnabled = decoder.decodeInt32ForKey("masterEnabled", orElse: 1) != 0
        self.peers = (decoder.decodeObjectForKey("peers", decoder: LegacyAutomaticMediaDownloadPeers.init(decoder:)) as? LegacyAutomaticMediaDownloadPeers) ?? LegacyAutomaticMediaDownloadSettings.defaultSettings.peers
        self.autoplayGifs = decoder.decodeInt32ForKey("autoplayGifs", orElse: 1) != 0
        self.downloadInBackground = decoder.decodeInt32ForKey("downloadInBackground", orElse: 1) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? LegacyAutomaticMediaDownloadSettings {
            return self == to
        } else {
            return false
        }
    }
}
