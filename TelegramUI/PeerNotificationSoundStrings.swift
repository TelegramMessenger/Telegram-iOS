import Foundation
import TelegramCore

private let modernSounds: [String] = [
    "Note",
    "Aurora",
    "Bamboo",
    "Chord",
    "Circles",
    "Complete",
    "Hello",
    "Input",
    "Keys",
    "Popcorn",
    "Pulse",
    "Synth"
]

private let classicSounds: [String] = [
    "Tri-tone",
    "Tremolo",
    "Alert",
    "Bell",
    "Calypso",
    "Chime",
    "Glass",
    "Telegraph"
]

private func soundName(strings: PresentationStrings, sound: PeerMessageSound) -> String {
    switch sound {
        case .none:
            return "None"
        case .default:
            return ""
        case let .bundledModern(id):
            if id >= 0 && Int(id) < modernSounds.count {
                return modernSounds[Int(id)]
            }
            return "Sound \(id)"
        case let .bundledClassic(id):
            if id >= 0 && Int(id) < classicSounds.count {
                return classicSounds[Int(id)]
            }
            return "Sound \(id)"
    }
}

func localizedPeerNotificationSoundString(strings: PresentationStrings, sound: PeerMessageSound, default: PeerMessageSound? = nil) -> String {
    switch sound {
        case .default:
            if let defaultSound = `default` {
                let name = soundName(strings: strings, sound: defaultSound)
                let actualName: String
                if name.isEmpty {
                    actualName = soundName(strings: strings, sound: .bundledModern(id: 0))
                } else {
                    actualName = name
                }
                return "Default (\(actualName))"
            } else {
                return "Default"
            }
        default:
            return soundName(strings: strings, sound: sound)
    }
}
