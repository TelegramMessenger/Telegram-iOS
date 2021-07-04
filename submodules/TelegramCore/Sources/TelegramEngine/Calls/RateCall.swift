import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

func _internal_rateCall(account: Account, callId: CallId, starsCount: Int32, comment: String = "", userInitiated: Bool) -> Signal<Void, NoError> {
    var flags: Int32 = 0
    if userInitiated {
        flags |= (1 << 0)
    }
    return account.network.request(Api.functions.phone.setCallRating(flags: flags, peer: Api.InputPhoneCall.inputPhoneCall(id: callId.id, accessHash: callId.accessHash), rating: starsCount, comment: comment))
    |> retryRequest
    |> map { _ in }
}

func _internal_saveCallDebugLog(network: Network, callId: CallId, log: String) -> Signal<Void, NoError> {
    if log.count > 1024 * 16 {
        return .complete()
    }
    return network.request(Api.functions.phone.saveCallDebug(peer: Api.InputPhoneCall.inputPhoneCall(id: callId.id, accessHash: callId.accessHash), debug: .dataJSON(data: log)))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> map { _ in }
}
