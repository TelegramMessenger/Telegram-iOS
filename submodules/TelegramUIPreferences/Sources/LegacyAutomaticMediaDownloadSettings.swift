import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore
import SyncCore

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
    }
}

public struct AutomaticMediaDownloadSettings: PreferencesEntry, Equatable {
    public var masterEnabled: Bool
    public var peers: AutomaticMediaDownloadPeers
    public var autoplayGifs: Bool
    public var downloadInBackground: Bool
    
    public static var defaultSettings: AutomaticMediaDownloadSettings {
        let defaultCategory = AutomaticMediaDownloadCategories(
            photo: AutomaticMediaDownloadCategory(cellular: true, wifi: true, sizeLimit: Int32.max),
            video: AutomaticMediaDownloadCategory(cellular: true, wifi: true, sizeLimit: 10 * 1024 * 1024),
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
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? AutomaticMediaDownloadSettings {
            return self == to
        } else {
            return false
        }
    }
}
