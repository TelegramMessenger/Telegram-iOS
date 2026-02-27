import Postbox
import TelegramApi
import SwiftSignalKit

public enum UpdateChannelJoinToSendError {
    case generic
}

func _internal_toggleChannelJoinToSend(postbox: Postbox, network: Network, accountStateManager: AccountStateManager, peerId: PeerId, enabled: Bool) -> Signal<Never, UpdateChannelJoinToSendError> {
    return postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(peerId)
    }
    |> castError(UpdateChannelJoinToSendError.self)
    |> mapToSignal { peer in
        guard let peer = peer, let inputChannel = apiInputChannel(peer) else {
            return .fail(.generic)
        }
        return network.request(Api.functions.channels.toggleJoinToSend(channel: inputChannel, enabled: enabled ? .boolTrue : .boolFalse))
        |> `catch` { _ -> Signal<Api.Updates, UpdateChannelJoinToSendError> in
            return .fail(.generic)
        }
        |> mapToSignal { updates -> Signal<Never, UpdateChannelJoinToSendError> in
            accountStateManager.addUpdates(updates)
            return .complete()
        }
    }
}

public enum UpdateChannelJoinRequestError {
    case generic
}

func _internal_toggleChannelJoinRequest(postbox: Postbox, network: Network, accountStateManager: AccountStateManager, peerId: PeerId, enabled: Bool) -> Signal<Never, UpdateChannelJoinRequestError> {
    return postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(peerId)
    }
    |> castError(UpdateChannelJoinRequestError.self)
    |> mapToSignal { peer in
        guard let peer = peer, let inputChannel = apiInputChannel(peer) else {
            return .fail(.generic)
        }
        return network.request(Api.functions.channels.toggleJoinRequest(channel: inputChannel, enabled: enabled ? .boolTrue : .boolFalse))
        |> `catch` { _ -> Signal<Api.Updates, UpdateChannelJoinRequestError> in
            return .fail(.generic)
        }
        |> mapToSignal { updates -> Signal<Never, UpdateChannelJoinRequestError> in
            accountStateManager.addUpdates(updates)
            return .complete()
        }
    }
}
