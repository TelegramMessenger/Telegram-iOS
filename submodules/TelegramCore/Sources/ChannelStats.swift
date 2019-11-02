import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public enum ChannelStatsUrlError {
    case generic
}

public func channelStatsUrl(postbox: Postbox, network: Network, peerId: PeerId, params: String, darkTheme: Bool) -> Signal<String, ChannelStatsUrlError> {
    return postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> castError(ChannelStatsUrlError.self)
    |> mapToSignal { inputPeer -> Signal<String, ChannelStatsUrlError> in
        guard let inputPeer = inputPeer else {
            return .fail(.generic)
        }
        var flags: Int32 = 0
        if darkTheme {
            flags |= (1 << 0)
        }
        return network.request(Api.functions.messages.getStatsURL(flags: flags, peer: inputPeer, params: params))
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
