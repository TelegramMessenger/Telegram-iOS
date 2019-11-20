import Foundation
import Postbox
import SwiftSignalKit

import SyncCore

public func togglePeerMuted(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        if let peer = transaction.getPeer(peerId) {
            var notificationPeerId = peerId
            if let associatedPeerId = peer.associatedPeerId {
                notificationPeerId = associatedPeerId
            }
            
            let currentSettings = transaction.getPeerNotificationSettings(notificationPeerId) as? TelegramPeerNotificationSettings
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
            transaction.updatePendingPeerNotificationSettings(peerId: notificationPeerId, settings: updatedSettings)
        }
    }
}

public func updatePeerMuteSetting(account: Account, peerId: PeerId, muteInterval: Int32?) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        updatePeerMuteSetting(transaction: transaction, peerId: peerId, muteInterval: muteInterval)
    }
}

public func updatePeerMuteSetting(transaction: Transaction, peerId: PeerId, muteInterval: Int32?) {
    if let peer = transaction.getPeer(peerId) {
        var notificationPeerId = peerId
        if let associatedPeerId = peer.associatedPeerId {
            notificationPeerId = associatedPeerId
        }
        
        let currentSettings = transaction.getPeerNotificationSettings(notificationPeerId) as? TelegramPeerNotificationSettings
        let previousSettings: TelegramPeerNotificationSettings
        if let currentSettings = currentSettings {
            previousSettings = currentSettings
        } else {
            previousSettings = TelegramPeerNotificationSettings.defaultSettings
        }
        
        let muteState: PeerMuteState
        if let muteInterval = muteInterval {
            if muteInterval == 0 {
                muteState = .unmuted
            } else {
                let absoluteUntil: Int32
                if muteInterval == Int32.max {
                    absoluteUntil = Int32.max
                } else {
                    absoluteUntil = Int32(Date().timeIntervalSince1970) + muteInterval
                }
                muteState = .muted(until: absoluteUntil)
            }
        } else {
            muteState = .default
        }
        
        let updatedSettings = previousSettings.withUpdatedMuteState(muteState)
        transaction.updatePendingPeerNotificationSettings(peerId: peerId, settings: updatedSettings)
    }
}

public func updatePeerDisplayPreviewsSetting(account: Account, peerId: PeerId, displayPreviews: PeerNotificationDisplayPreviews) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        updatePeerDisplayPreviewsSetting(transaction: transaction, peerId: peerId, displayPreviews: displayPreviews)
    }
}

public func updatePeerDisplayPreviewsSetting(transaction: Transaction, peerId: PeerId, displayPreviews: PeerNotificationDisplayPreviews) {
    if let peer = transaction.getPeer(peerId) {
        var notificationPeerId = peerId
        if let associatedPeerId = peer.associatedPeerId {
            notificationPeerId = associatedPeerId
        }
        
        let currentSettings = transaction.getPeerNotificationSettings(notificationPeerId) as? TelegramPeerNotificationSettings
        let previousSettings: TelegramPeerNotificationSettings
        if let currentSettings = currentSettings {
            previousSettings = currentSettings
        } else {
            previousSettings = TelegramPeerNotificationSettings.defaultSettings
        }
        
        let updatedSettings = previousSettings.withUpdatedDisplayPreviews(displayPreviews)
        transaction.updatePendingPeerNotificationSettings(peerId: peerId, settings: updatedSettings)
    }
}

public func updatePeerNotificationSoundInteractive(account: Account, peerId: PeerId, sound: PeerMessageSound) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        updatePeerNotificationSoundInteractive(transaction: transaction, peerId: peerId, sound: sound)
    }
}

public func updatePeerNotificationSoundInteractive(transaction: Transaction, peerId: PeerId, sound: PeerMessageSound) {
    if let peer = transaction.getPeer(peerId) {
        var notificationPeerId = peerId
        if let associatedPeerId = peer.associatedPeerId {
            notificationPeerId = associatedPeerId
        }
        
        let currentSettings = transaction.getPeerNotificationSettings(notificationPeerId) as? TelegramPeerNotificationSettings
        let previousSettings: TelegramPeerNotificationSettings
        if let currentSettings = currentSettings {
            previousSettings = currentSettings
        } else {
            previousSettings = TelegramPeerNotificationSettings.defaultSettings
        }
        
        let updatedSettings = previousSettings.withUpdatedMessageSound(sound)
        transaction.updatePendingPeerNotificationSettings(peerId: peerId, settings: updatedSettings)
    }
}
