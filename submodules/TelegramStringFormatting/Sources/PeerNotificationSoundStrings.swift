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
        if let (id, legacyCategory) = getCloudLegacySound(id: fileId) {
            switch legacyCategory {
            case .modern:
                if id >= 0 && Int(id) < modernSoundsNamePaths.count {
                    return strings[keyPath: modernSoundsNamePaths[Int(id)]]
                }
            case .classic:
                if id >= 0 && Int(id) < classicSoundNamePaths.count {
                    return strings[keyPath: classicSoundNamePaths[Int(id)]]
                }
            }
        }
        
        guard let notificationSoundList = notificationSoundList else {
            return strings.Channel_NotificationLoading
        }
        for sound in notificationSoundList.sounds {
            if sound.file.fileId.id == fileId {
                for attribute in sound.file.attributes {
                    switch attribute {
                    case let .Audio(_, _, title, performer, _):
                        if let title = title, !title.isEmpty, let performer = performer, !performer.isEmpty {
                            return "\(title) - \(performer)"
                        } else if let title = title, !title.isEmpty {
                            return title
                        } else if let performer = performer, !performer.isEmpty {
                            return performer
                        }
                    default:
                        break
                    }
                }
                
                if let fileName = sound.file.fileName, !fileName.isEmpty {
                    if let range = fileName.range(of: ".", options: .backwards) {
                        return String(fileName[fileName.startIndex ..< range.lowerBound])
                    } else {
                        return fileName
                    }
                }
                
                return "Cloud Tone"
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
                actualName = soundName(strings: strings, sound: defaultCloudPeerNotificationSound, notificationSoundList: notificationSoundList)
            } else {
                actualName = name
            }
            return strings.UserInfo_NotificationsDefaultSound(actualName).string
        } else {
            let name = soundName(strings: strings, sound: defaultCloudPeerNotificationSound, notificationSoundList: notificationSoundList)
            return name
        }
    default:
        let name = soundName(strings: strings, sound: sound, notificationSoundList: notificationSoundList)
        if name.isEmpty {
            return localizedPeerNotificationSoundString(strings: strings, notificationSoundList: notificationSoundList, sound: .default, default: `default`)
        } else {
            return name
        }
    }
}
