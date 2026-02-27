import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

public enum ResolveStarGiftOfferError {
    case generic
}

func _internal_resolveStarGiftOffer(account: Account, messageId: EngineMessage.Id, accept: Bool) -> Signal<Never, ResolveStarGiftOfferError> {
    var flags: Int32 = 0
    if !accept {
        flags |= (1 << 0)
    }
    return account.network.request(Api.functions.payments.resolveStarGiftOffer(flags: flags, offerMsgId: messageId.id))
    |> mapError { _ -> ResolveStarGiftOfferError in
        return .generic
    }
    |> mapToSignal { updates -> Signal<Never, ResolveStarGiftOfferError> in
        account.stateManager.addUpdates(updates)
        return .complete()
    }
    |> ignoreValues
}


public enum SendStarGiftOfferError {
    case generic
}

func _internal_sendStarGiftOffer(account: Account, peerId: EnginePeer.Id, slug: String, amount: CurrencyAmount, duration: Int32, allowPaidStars: Int64?) -> Signal<Never, SendStarGiftOfferError> {
    var flags: Int32 = 0
    if let _ = allowPaidStars {
        flags |= (1 << 0)
    }
    return account.postbox.transaction { transaction in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> castError(SendStarGiftOfferError.self)
    |> mapToSignal { inputPeer -> Signal<Never, SendStarGiftOfferError> in
        guard let inputPeer else {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.payments.sendStarGiftOffer(flags: flags, peer: inputPeer, slug: slug, price: amount.apiAmount, duration: duration, randomId: Int64.random(in: .min ..< .max), allowPaidStars: allowPaidStars))
        |> mapError { _ -> SendStarGiftOfferError in
            return .generic
        }
        |> mapToSignal { updates -> Signal<Never, SendStarGiftOfferError> in
            account.stateManager.addUpdates(updates)
            return .complete()
        }
    }
    |> ignoreValues
}
