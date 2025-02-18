import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit

func _internal_getPaidMessagesRevenue(account: Account, peerId: PeerId) -> Signal<StarsAmount?, NoError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(peerId).flatMap(apiInputUser)
    }
    |> mapToSignal { inputUser -> Signal<StarsAmount?, NoError> in
        guard let inputUser else {
            return .single(nil)
        }
        return account.network.request(Api.functions.account.getPaidMessagesRevenue(userId: inputUser))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.account.PaidMessagesRevenue?, NoError> in
            return .single(nil)
        }
        |> map { result -> StarsAmount? in
            guard let result else {
                return nil
            }
            switch result {
            case let .paidMessagesRevenue(amount):
                return StarsAmount(value: amount, nanos: 0)
            }
        }
    }
}

func _internal_addNoPaidMessagesException(account: Account, peerId: PeerId, refundCharged: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(peerId).flatMap(apiInputUser)
    }
    |> mapToSignal { inputUser -> Signal<Never, NoError> in
        guard let inputUser else {
            return .never()
        }
        var flags: Int32 = 0
        if refundCharged {
            flags |= (1 << 0)
        }
        return account.network.request(Api.functions.account.addNoPaidMessagesException(flags: flags, userId: inputUser))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        } |> mapToSignal { _ in
            return account.postbox.transaction { transaction -> Void in
                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData in
                    if let cachedData = cachedData as? CachedUserData {
                        var settings = cachedData.peerStatusSettings ?? .init()
                        settings.paidMessageStars = nil
                        return cachedData.withUpdatedPeerStatusSettings(settings)
                    }
                    return cachedData
                })
            }
            |> ignoreValues
        }
        |> ignoreValues
    }
}

func _internal_updateChannelPaidMessagesStars(account: Account, peerId: PeerId, stars: StarsAmount?) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Signal<Never, NoError> in
        guard let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer) else {
            return .complete()
        }
        return account.network.request(Api.functions.channels.updatePaidMessagesPrice(channel: inputChannel, sendPaidMessagesStars: stars?.value ?? 0))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            guard let result = result else {
                return .complete()
            }
            account.stateManager.addUpdates(result)
            return account.postbox.transaction { transaction -> Void in
                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData in
                    if let cachedData = cachedData as? CachedChannelData {
                        return cachedData.withUpdatedSendPaidMessageStars(stars)
                    }
                    return cachedData
                })
            }
            |> ignoreValues
        }
    }
    |> switchToLatest
}


