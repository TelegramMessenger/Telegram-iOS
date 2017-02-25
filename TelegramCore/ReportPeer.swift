import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

public func reportPeer(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        if let peer = modifier.getPeer(peerId) {
            if let _ = peer as? TelegramSecretChat {
                return .complete()
            } else if let inputPeer = apiInputPeer(peer) {
                return account.network.request(Api.functions.messages.reportSpam(peer: inputPeer))
                    |> map { Optional($0) }
                    |> `catch` { _ -> Signal<Api.Bool?, NoError> in
                        return .single(nil)
                    }
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        return account.postbox.modify { modifier -> Void in
                            if result != nil {
                                modifier.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                    if let current = current as? CachedUserData {
                                        return current.withUpdatedReportStatus(.didReport)
                                    } else if let current = current as? CachedGroupData {
                                        return current.withUpdatedReportStatus(.didReport)
                                    } else if let current = current as? CachedChannelData {
                                        return current.withUpdatedReportStatus(.didReport)
                                    } else {
                                        return current
                                    }
                                })
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
