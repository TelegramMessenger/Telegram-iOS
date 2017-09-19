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
                case .unmuted:
                    updatedSettings = previousSettings.withUpdatedMuteState(.muted(until: Int32.max))
                case .muted:
                    updatedSettings = previousSettings.withUpdatedMuteState(.unmuted)
            }
            modifier.updatePendingPeerNotificationSettings(peerId: peerId, settings: updatedSettings)
        }
    }
}

public func changePeerNotificationSettings(account: Account, peerId: PeerId, settings: TelegramPeerNotificationSettings) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Void in
        modifier.updatePendingPeerNotificationSettings(peerId: peerId, settings: settings)
    }
}
