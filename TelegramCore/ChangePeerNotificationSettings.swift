import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func togglePeerMuted(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Void in
        if let peer = modifier.getPeer(peerId) {
            var notificationPeerId = peerId
            if let associatedPeerId = peer.associatedPeerId {
                notificationPeerId = associatedPeerId
            }
            
            let currentSettings = modifier.getPeerNotificationSettings(notificationPeerId) as? TelegramPeerNotificationSettings
            let previousSettings: TelegramPeerNotificationSettings
            if let currentSettings = currentSettings {
                previousSettings = currentSettings
            } else {
                previousSettings = TelegramPeerNotificationSettings.defaultSettings
            }
            
            let updatedSettings: TelegramPeerNotificationSettings
            switch previousSettings.muteState {
                case .unmuted, .default:
                    updatedSettings = previousSettings.withUpdatedMuteState(.muted(until: Int32.max))
                case .muted:
                    updatedSettings = previousSettings.withUpdatedMuteState(.default)
            }
            modifier.updatePendingPeerNotificationSettings(peerId: peerId, settings: updatedSettings)
        }
    }
}

public func updatePeerMuteSetting(account: Account, peerId: PeerId, muteInterval: Int32?) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Void in
        if let peer = modifier.getPeer(peerId) {
            var notificationPeerId = peerId
            if let associatedPeerId = peer.associatedPeerId {
                notificationPeerId = associatedPeerId
            }
            
            let currentSettings = modifier.getPeerNotificationSettings(notificationPeerId) as? TelegramPeerNotificationSettings
            let previousSettings: TelegramPeerNotificationSettings
            if let currentSettings = currentSettings {
                previousSettings = currentSettings
            } else {
                previousSettings = TelegramPeerNotificationSettings.defaultSettings
            }
            
            let muteState: PeerMuteState
            if let muteInterval = muteInterval {
                let absoluteUntil: Int32
                if muteInterval == Int32.max {
                    absoluteUntil = Int32.max
                } else {
                    absoluteUntil = Int32(Date().timeIntervalSince1970) + muteInterval
                }
                muteState = .muted(until: absoluteUntil)
            } else {
                muteState = .unmuted
            }
            
            let updatedSettings = previousSettings.withUpdatedMuteState(muteState)
            modifier.updatePendingPeerNotificationSettings(peerId: peerId, settings: updatedSettings)
        }
    }
}

public func updatePeerNotificationSoundInteractive(account: Account, peerId: PeerId, sound: PeerMessageSound) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Void in
        if let peer = modifier.getPeer(peerId) {
            var notificationPeerId = peerId
            if let associatedPeerId = peer.associatedPeerId {
                notificationPeerId = associatedPeerId
            }
            
            let currentSettings = modifier.getPeerNotificationSettings(notificationPeerId) as? TelegramPeerNotificationSettings
            let previousSettings: TelegramPeerNotificationSettings
            if let currentSettings = currentSettings {
                previousSettings = currentSettings
            } else {
                previousSettings = TelegramPeerNotificationSettings.defaultSettings
            }
            
            let updatedSettings = previousSettings.withUpdatedMessageSound(sound)
            modifier.updatePendingPeerNotificationSettings(peerId: peerId, settings: updatedSettings)
        }
    }
}
