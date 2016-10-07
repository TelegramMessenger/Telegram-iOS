import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func joinChannel(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.loadedPeerWithId(peerId)
        |> take(1)
        |> mapToSignal { peer -> Signal<Void, NoError> in
            if let inputChannel = apiInputChannel(peer) {
                return account.network.request(Api.functions.channels.joinChannel(channel: inputChannel))
                    |> retryRequest
                    |> mapToSignal { updates -> Signal<Void, NoError> in
                        account.stateManager.addUpdates(updates)
                        return .complete()
                    }
            } else {
                return .complete()
            }
        }
}
