import Foundation
import Postbox
import TelegramApi

import SyncCore

extension TelegramPeerNotificationSettings {
    convenience init(apiSettings: Api.PeerNotifySettings) {
        switch apiSettings {
            case .peerNotifySettingsEmpty:
                self.init(muteState: .unmuted, messageSound: .bundledModern(id: 0), displayPreviews: .default)
            case let .peerNotifySettings(_, showPreviews, _, muteUntil, sound):
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
                self.init(muteState: muteState, messageSound: PeerMessageSound(apiSound: sound), displayPreviews: displayPreviews)
        }
    }
}

extension PeerMessageSound {
    init(apiSound: String?) {
        guard let apiSound = apiSound else {
            self = .default
            return
        }
        var rawApiSound = apiSound
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
                parsedSound = .bundledModern(id: 0)
            }
        }
        self = parsedSound
    }
    
    var apiSound: String? {
        switch self {
            case .none:
                return ""
            case .default:
                return nil
            case let .bundledModern(id):
                return "\(id + 100)"
            case let .bundledClassic(id):
                return "\(id + 2)"
        }
    }
}
