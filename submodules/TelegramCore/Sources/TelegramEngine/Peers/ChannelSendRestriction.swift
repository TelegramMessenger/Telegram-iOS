import Postbox
internal import TelegramApi
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

func _internal_toggleChannelJoinRequest(postbox: Postbox, network: Network, accountStateManager: AccountStateManager, peerId: PeerId, enabled: Bool, guardBotId: PeerId?, applyToInvites: Bool, clearGuardBot: Bool) -> Signal<Never, UpdateChannelJoinRequestError> {
    let updatedGuardBotId: PeerId?
    let shouldUpdateGuardBotId: Bool
    if clearGuardBot {
        updatedGuardBotId = nil
        shouldUpdateGuardBotId = true
    } else if let guardBotId {
        updatedGuardBotId = guardBotId
        shouldUpdateGuardBotId = true
    } else {
        updatedGuardBotId = nil
        shouldUpdateGuardBotId = false
    }

    return postbox.transaction { transaction -> (Peer?, Api.InputUser?) in
        let guardBot: Api.InputUser?
        if clearGuardBot {
            guardBot = .inputUserEmpty
        } else if let guardBotId {
            guardBot = transaction.getPeer(guardBotId).flatMap(apiInputUser)
        } else {
            guardBot = nil
        }
        return (transaction.getPeer(peerId), guardBot)
    }
    |> castError(UpdateChannelJoinRequestError.self)
    |> mapToSignal { result in
        let (peer, guardBot) = result
        guard let peer = peer, let inputChannel = apiInputChannel(peer) else {
            return .fail(.generic)
        }
        if guardBotId != nil && guardBot == nil {
            return .fail(.generic)
        }
        var flags: Int32 = 0
        if guardBot != nil {
            flags |= 1 << 0
        }
        if applyToInvites {
            flags |= 1 << 1
        }
        return network.request(Api.functions.channels.toggleJoinRequest(flags: flags, channel: inputChannel, enabled: enabled ? .boolTrue : .boolFalse, guardBot: guardBot))
        |> `catch` { _ -> Signal<Api.Updates, UpdateChannelJoinRequestError> in
            return .fail(.generic)
        }
        |> mapToSignal { updates -> Signal<Never, UpdateChannelJoinRequestError> in
            accountStateManager.addUpdates(updates)

            if shouldUpdateGuardBotId {
                return postbox.transaction { transaction -> Void in
                    transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                        guard let current = current as? CachedChannelData else {
                            return current
                        }
                        return current.withUpdatedGuardBotId(updatedGuardBotId)
                    })
                }
                |> castError(UpdateChannelJoinRequestError.self)
                |> ignoreValues
            }

            return .complete()
        }
    }
}
