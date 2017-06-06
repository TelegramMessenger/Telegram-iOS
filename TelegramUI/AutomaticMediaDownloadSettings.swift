import Foundation
import Postbox
import SwiftSignalKit

public struct AutomaticMediaDownloadCategoryPeers: Coding, Equatable {
    public let privateChats: Bool
    public let groupsAndChannels: Bool
    
    public init(privateChats: Bool, groupsAndChannels: Bool) {
        self.privateChats = privateChats
        self.groupsAndChannels = groupsAndChannels
    }
    
    public init(decoder: Decoder) {
        self.privateChats = decoder.decodeInt32ForKey("p", orElse: 0) != 0
        self.groupsAndChannels = decoder.decodeInt32ForKey("g", orElse: 0) != 0
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.privateChats ? 1 : 0, forKey: "p")
        encoder.encodeInt32(self.groupsAndChannels ? 1 : 0, forKey: "g")
    }
    
    public func withUpdatedPrivateChats(_ privateChats: Bool) -> AutomaticMediaDownloadCategoryPeers {
        return AutomaticMediaDownloadCategoryPeers(privateChats: privateChats, groupsAndChannels: self.groupsAndChannels)
    }
    
    public func withUpdatedGroupsAndChannels(_ groupsAndChannels: Bool) -> AutomaticMediaDownloadCategoryPeers {
        return AutomaticMediaDownloadCategoryPeers(privateChats: self.privateChats, groupsAndChannels: groupsAndChannels)
    }
    
    public static func ==(lhs: AutomaticMediaDownloadCategoryPeers, rhs: AutomaticMediaDownloadCategoryPeers) -> Bool {
        if lhs.privateChats != rhs.privateChats {
            return false
        }
        if lhs.groupsAndChannels != rhs.groupsAndChannels {
            return false
        }
        return true
    }
}

public struct AutomaticMediaDownloadCategories: Coding, Equatable {
    public let photo: AutomaticMediaDownloadCategoryPeers
    public let voice: AutomaticMediaDownloadCategoryPeers
    public let instantVideo: AutomaticMediaDownloadCategoryPeers
    public let gif: AutomaticMediaDownloadCategoryPeers
    
    public init(photo: AutomaticMediaDownloadCategoryPeers, voice: AutomaticMediaDownloadCategoryPeers, instantVideo: AutomaticMediaDownloadCategoryPeers, gif: AutomaticMediaDownloadCategoryPeers) {
        self.photo = photo
        self.voice = voice
        self.instantVideo = instantVideo
        self.gif = gif
    }
    
    public init(decoder: Decoder) {
        self.photo = decoder.decodeObjectForKey("p", decoder: { AutomaticMediaDownloadCategoryPeers(decoder: $0) }) as! AutomaticMediaDownloadCategoryPeers
        self.voice = decoder.decodeObjectForKey("v", decoder: { AutomaticMediaDownloadCategoryPeers(decoder: $0) }) as! AutomaticMediaDownloadCategoryPeers
        self.instantVideo = decoder.decodeObjectForKey("iv", decoder: { AutomaticMediaDownloadCategoryPeers(decoder: $0) }) as! AutomaticMediaDownloadCategoryPeers
        self.gif = decoder.decodeObjectForKey("g", decoder: { AutomaticMediaDownloadCategoryPeers(decoder: $0) }) as! AutomaticMediaDownloadCategoryPeers
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeObject(self.photo, forKey: "p")
        encoder.encodeObject(self.voice, forKey: "v")
        encoder.encodeObject(self.instantVideo, forKey: "iv")
        encoder.encodeObject(self.gif, forKey: "g")
    }
    
    public func withUpdatedPhoto(_ photo: AutomaticMediaDownloadCategoryPeers) -> AutomaticMediaDownloadCategories {
        return AutomaticMediaDownloadCategories(photo: photo, voice: self.voice, instantVideo: self.instantVideo, gif: self.gif)
    }
    
    public func withUpdatedVoice(_ voice: AutomaticMediaDownloadCategoryPeers) -> AutomaticMediaDownloadCategories {
        return AutomaticMediaDownloadCategories(photo: self.photo, voice: voice, instantVideo: self.instantVideo, gif: self.gif)
    }
    
    public func withUpdatedInstantVideo(_ instantVideo: AutomaticMediaDownloadCategoryPeers) -> AutomaticMediaDownloadCategories {
        return AutomaticMediaDownloadCategories(photo: self.photo, voice: self.voice, instantVideo: instantVideo, gif: self.gif)
    }
    
    public func withUpdatedGif(_ gif: AutomaticMediaDownloadCategoryPeers) -> AutomaticMediaDownloadCategories {
        return AutomaticMediaDownloadCategories(photo: self.photo, voice: self.voice, instantVideo: self.instantVideo, gif: gif)
    }
    
    public static func ==(lhs: AutomaticMediaDownloadCategories, rhs: AutomaticMediaDownloadCategories) -> Bool {
        if lhs.photo != rhs.photo {
            return false
        }
        if lhs.voice != rhs.voice {
            return false
        }
        if lhs.instantVideo != rhs.instantVideo {
            return false
        }
        if lhs.gif != rhs.gif {
            return false
        }
        return true
    }
}

public struct AutomaticMediaDownloadSettings: PreferencesEntry, Equatable {
    public let categories: AutomaticMediaDownloadCategories
    public let saveIncomingPhotos: Bool
    
    public static var defaultSettings: AutomaticMediaDownloadSettings {
        return AutomaticMediaDownloadSettings(categories: AutomaticMediaDownloadCategories(photo: AutomaticMediaDownloadCategoryPeers(privateChats: true, groupsAndChannels: true), voice: AutomaticMediaDownloadCategoryPeers(privateChats: true, groupsAndChannels: true), instantVideo: AutomaticMediaDownloadCategoryPeers(privateChats: true, groupsAndChannels: true), gif: AutomaticMediaDownloadCategoryPeers(privateChats: true, groupsAndChannels: true)), saveIncomingPhotos: false)
    }
    
    init(categories: AutomaticMediaDownloadCategories, saveIncomingPhotos: Bool) {
        self.categories = categories
        self.saveIncomingPhotos = saveIncomingPhotos
    }
    
    public init(decoder: Decoder) {
        self.categories = decoder.decodeObjectForKey("c", decoder: { AutomaticMediaDownloadCategories(decoder: $0) }) as! AutomaticMediaDownloadCategories
        self.saveIncomingPhotos = decoder.decodeInt32ForKey("siph", orElse: 0) != 0
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeObject(self.categories, forKey: "c")
        encoder.encodeInt32(self.saveIncomingPhotos ? 1 : 0, forKey: "siph")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? AutomaticMediaDownloadSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: AutomaticMediaDownloadSettings, rhs: AutomaticMediaDownloadSettings) -> Bool {
        return lhs.categories == rhs.categories && lhs.saveIncomingPhotos == rhs.saveIncomingPhotos
    }
    
    func withUpdatedCategories(_ categories: AutomaticMediaDownloadCategories) -> AutomaticMediaDownloadSettings {
        return AutomaticMediaDownloadSettings(categories: categories, saveIncomingPhotos: self.saveIncomingPhotos)
    }
    
    func withUpdatedSaveIncomingPhotos(_ saveIncomingPhotos: Bool) -> AutomaticMediaDownloadSettings {
        return AutomaticMediaDownloadSettings(categories: self.categories, saveIncomingPhotos: saveIncomingPhotos)
    }
}

func updateMediaDownloadSettingsInteractively(postbox: Postbox, _ f: @escaping (AutomaticMediaDownloadSettings) -> AutomaticMediaDownloadSettings) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        modifier.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings, { entry in
            let currentSettings: AutomaticMediaDownloadSettings
            if let entry = entry as? AutomaticMediaDownloadSettings {
                currentSettings = entry
            } else {
                currentSettings = AutomaticMediaDownloadSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}
