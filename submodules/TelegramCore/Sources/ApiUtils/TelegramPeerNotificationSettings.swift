import Foundation
import Postbox
import TelegramApi


extension TelegramPeerNotificationSettings {
    convenience init(apiSettings: Api.PeerNotifySettings) {
        switch apiSettings {
        case let .peerNotifySettings(peerNotifySettingsData):
            let (showPreviews, muteUntil, iosSound, desktopSound, storiesMuted, storiesHideSender, storiesIosSound, storiesDesktopSound) = (peerNotifySettingsData.showPreviews, peerNotifySettingsData.muteUntil, peerNotifySettingsData.iosSound, peerNotifySettingsData.otherSound, peerNotifySettingsData.storiesMuted, peerNotifySettingsData.storiesHideSender, peerNotifySettingsData.storiesIosSound, peerNotifySettingsData.storiesOtherSound)
            let sound: Api.NotificationSound?
            let storiesSound: Api.NotificationSound?
            #if os(iOS)
            sound = iosSound
            storiesSound = storiesIosSound
            #elseif os(macOS)
            sound = desktopSound
            storiesSound = storiesDesktopSound
            #endif
            
            let muteState: PeerMuteState
            if let muteUntil = muteUntil {
                if muteUntil == 0 {
                    muteState = .unmuted
                } else {
                    muteState = .muted(until: muteUntil)
                }
            } else {
                muteState = .default
            }
            let displayPreviews: PeerNotificationDisplayPreviews
            if let showPreviews = showPreviews {
                if case .boolTrue = showPreviews {
                    displayPreviews = .show
                } else {
                    displayPreviews = .hide
                }
            } else {
                displayPreviews = .default
            }
            
            let storiesMutedValue: PeerStoryNotificationSettings.Mute
            if let storiesMuted = storiesMuted {
                storiesMutedValue = storiesMuted == .boolTrue ? .muted : .unmuted
            } else {
                storiesMutedValue = .default
            }
            
            var storiesHideSenderValue: PeerStoryNotificationSettings.HideSender
            if let storiesHideSender = storiesHideSender {
                storiesHideSenderValue = storiesHideSender == .boolTrue ? .hide : .show
            } else {
                storiesHideSenderValue = .default
            }
            
            self.init(muteState: muteState, messageSound: PeerMessageSound(apiSound: sound ?? .notificationSoundDefault), displayPreviews: displayPreviews, storySettings: PeerStoryNotificationSettings(
                mute: storiesMutedValue,
                hideSender: storiesHideSenderValue,
                sound: PeerMessageSound(apiSound: storiesSound ?? .notificationSoundDefault)
            ))
        }
    }
}

extension PeerMessageSound {
    init(apiSound: Api.NotificationSound) {
        switch apiSound {
        case .notificationSoundDefault:
            self = .default
        case .notificationSoundNone:
            self = .none
        case let .notificationSoundLocal(notificationSoundLocalData):
            let (_, data) = (notificationSoundLocalData.title, notificationSoundLocalData.data)
            var rawApiSound = data
            if let index = rawApiSound.firstIndex(of: ".") {
                rawApiSound = String(rawApiSound[..<index])
            }
            let parsedSound: PeerMessageSound
            if rawApiSound == "default" {
                parsedSound = .default
            } else if rawApiSound == "" || rawApiSound == "0" {
                parsedSound = .none
            } else {
                let soundId: Int32
                if let id = Int32(rawApiSound) {
                    soundId = id
                } else {
                    soundId = 100
                }
                if soundId >= 100 && soundId <= 111 {
                    parsedSound = .bundledModern(id: soundId - 100)
                } else if soundId >= 2 && soundId <= 9 {
                    parsedSound = .bundledClassic(id: soundId - 2)
                } else {
                    parsedSound = defaultCloudPeerNotificationSound
                }
            }
            self = parsedSound
        case let .notificationSoundRingtone(notificationSoundRingtoneData):
            let id = notificationSoundRingtoneData.id
            self = .cloud(fileId: id)
        }
    }
    
    var apiSound: Api.NotificationSound {
        switch self {
        case .none:
            return .notificationSoundNone
        case .default:
            return .notificationSoundDefault
        case let .bundledModern(id):
            let string = "\(id + 100)"
            return .notificationSoundLocal(.init(title: string, data: string))
        case let .bundledClassic(id):
            let string = "\(id + 2)"
            return .notificationSoundLocal(.init(title: string, data: string))
        case let .cloud(fileId):
            return .notificationSoundRingtone(.init(id: fileId))
        }
    }
}
