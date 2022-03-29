import Foundation
import TelegramCore
import TelegramPresentationData

private let modernSoundsNamePaths: [KeyPath<PresentationStrings, String>] = [
    \.NotificationsSound_Note,
    \.NotificationsSound_Aurora,
    \.NotificationsSound_Bamboo,
    \.NotificationsSound_Chord,
    \.NotificationsSound_Circles,
    \.NotificationsSound_Complete,
    \.NotificationsSound_Hello,
    \.NotificationsSound_Input,
    \.NotificationsSound_Keys,
    \.NotificationsSound_Popcorn,
    \.NotificationsSound_Pulse,
    \.NotificationsSound_Synth
]

private let classicSoundNamePaths: [KeyPath<PresentationStrings, String>] = [
    \.NotificationsSound_Tritone,
    \.NotificationsSound_Tremolo,
    \.NotificationsSound_Alert,
    \.NotificationsSound_Bell,
    \.NotificationsSound_Calypso,
    \.NotificationsSound_Chime,
    \.NotificationsSound_Glass,
    \.NotificationsSound_Telegraph
]

private func soundName(strings: PresentationStrings, sound: PeerMessageSound, notificationSoundList: NotificationSoundList?) -> String {
    switch sound {
    case .none:
        return strings.NotificationsSound_None
    case .default:
        return ""
    case let .bundledModern(id):
        if id >= 0 && Int(id) < modernSoundsNamePaths.count {
            return strings[keyPath: modernSoundsNamePaths[Int(id)]]
        }
        return "Sound \(id)"
    case let .bundledClassic(id):
        if id >= 0 && Int(id) < classicSoundNamePaths.count {
            return strings[keyPath: classicSoundNamePaths[Int(id)]]
        }
        return "Sound \(id)"
    case let .cloud(fileId):
        guard let notificationSoundList = notificationSoundList else {
            //TODO:localize
            return "Loading..."
        }
        for sound in notificationSoundList.sounds {
            if sound.file.fileId.id == fileId {
                return sound.file.fileName ?? "Cloud Tone"
            }
        }
        return ""
    }
}

public func localizedPeerNotificationSoundString(strings: PresentationStrings, notificationSoundList: NotificationSoundList?, sound: PeerMessageSound, default: PeerMessageSound? = nil) -> String {
    switch sound {
    case .default:
        if let defaultSound = `default` {
            let name = soundName(strings: strings, sound: defaultSound, notificationSoundList: notificationSoundList)
            let actualName: String
            if name.isEmpty {
                actualName = soundName(strings: strings, sound: .bundledModern(id: 0), notificationSoundList: notificationSoundList)
            } else {
                actualName = name
            }
            return strings.UserInfo_NotificationsDefaultSound(actualName).string
        } else {
            return strings.UserInfo_NotificationsDefault
        }
    default:
        return soundName(strings: strings, sound: sound, notificationSoundList: notificationSoundList)
    }
}
