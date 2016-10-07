import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func changePeerNotificationSettings(account: Account, peerId: PeerId, settings: TelegramPeerNotificationSettings) -> Signal<Void, NoError> {
    return account.postbox.loadedPeerWithId(peerId)
        |> mapToSignal { peer -> Signal<Void, NoError> in
            if let inputPeer = apiInputPeer(peer) {
                let muteUntil: Int32
                switch settings.muteState {
                    case let .muted(until):
                        muteUntil = until
                    case .unmuted:
                        muteUntil = 0
                }
                let sound: String
                switch settings.messageSound {
                    case .appDefault:
                        sound = "default"
                    case let .bundled(index):
                        sound = "\(index)"
                }
                let inputSettings = Api.InputPeerNotifySettings.inputPeerNotifySettings(flags: Int32(1 << 0), muteUntil: muteUntil, sound: sound)
                return account.network.request(Api.functions.account.updateNotifySettings(peer: .inputNotifyPeer(peer: inputPeer), settings: inputSettings))
                    |> retryRequest
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        return account.postbox.modify { modifier -> Void in
                            modifier.updatePeerNotificationSettings([peerId: settings])
                        }
                    }
            } else {
                return .complete()
            }
    }
}
