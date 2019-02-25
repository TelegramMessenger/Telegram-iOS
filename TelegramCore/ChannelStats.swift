import Foundation
#if os(macOS)
import SwiftSignalKitMac
import PostboxMac
#else
import SwiftSignalKit
import Postbox
#endif

public enum ChannelStatsUrlError {
    case generic
}

public func channelStatsUrl(postbox: Postbox, network: Network, peerId: PeerId, params: String) -> Signal<String, ChannelStatsUrlError> {
    return postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> introduceError(ChannelStatsUrlError.self)
    |> mapToSignal { inputPeer -> Signal<String, ChannelStatsUrlError> in
        guard let inputPeer = inputPeer else {
            return .fail(.generic)
        }
        return network.request(Api.functions.messages.getStatsURL(peer: inputPeer, params: params))
        |> map { result -> String in
            switch result {
                case let .statsURL(url):
                    return url
            }
        }
        |> `catch` { _ -> Signal<String, ChannelStatsUrlError> in
            return .fail(.generic)
        }
    }
}
