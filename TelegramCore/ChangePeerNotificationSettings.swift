import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func togglePeerMuted(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
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
            return changePeerNotificationSettings(account: account, peerId: notificationPeerId, settings: updatedSettings)
        } else {
            return .complete()
        }
    } |> switchToLatest
}

public func changePeerNotificationSettings(account: Account, peerId: PeerId, settings: TelegramPeerNotificationSettings) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        if let peer = modifier.getPeer(peerId) {
            var notificationPeerId = peerId
            if let associatedPeerId = peer.associatedPeerId {
                notificationPeerId = associatedPeerId
            }
            
            if let notificationPeer = modifier.getPeer(notificationPeerId), let inputPeer = apiInputPeer(notificationPeer) {
                return account.network.request(Api.functions.account.getNotifySettings(peer: .inputNotifyPeer(peer: inputPeer)))
                    |> retryRequest
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        let current = TelegramPeerNotificationSettings(apiSettings: result)
                        
                        let muteUntil: Int32
                        switch settings.muteState {
                            case let .muted(until):
                                muteUntil = until
                            case .unmuted:
                                muteUntil = 0
                        }
                        let sound: String
                        switch current.messageSound {
                            case .none:
                                sound = ""
                            case let .bundledModern(id):
                                sound = "\(id)"
                            case let .bundledClassic(id):
                                sound = "\(id + 12)"
                        }
                        let inputSettings = Api.InputPeerNotifySettings.inputPeerNotifySettings(flags: Int32(1 << 0), muteUntil: muteUntil, sound: sound)
                        return account.network.request(Api.functions.account.updateNotifySettings(peer: .inputNotifyPeer(peer: inputPeer), settings: inputSettings))
                            |> retryRequest
                            |> mapToSignal { result -> Signal<Void, NoError> in
                                return account.postbox.modify { modifier -> Void in
                                    modifier.updatePeerNotificationSettings([notificationPeerId: settings])
                                }
                        }
                }
            } else {
                return .complete()
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}
