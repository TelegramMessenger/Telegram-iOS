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

func localizedPeerNotificationSoundString(strings: PresentationStrings, sound: PeerMessageSound) -> String {
    switch sound {
        case .none:
            return strings.Settings_UsernameEmpty
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
