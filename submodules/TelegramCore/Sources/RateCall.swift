import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

public func rateCall(account: Account, callId: CallId, starsCount: Int32, comment: String = "", userInitiated: Bool) -> Signal<Void, NoError> {
    var flags: Int32 = 0
    if userInitiated {
        flags |= (1 << 0)
    }
    return account.network.request(Api.functions.phone.setCallRating(flags: flags, peer: Api.InputPhoneCall.inputPhoneCall(id: callId.id, accessHash: callId.accessHash), rating: starsCount, comment: comment))
    |> retryRequest
    |> map { _ in }
}

public func saveCallDebugLog(network: Network, callId: CallId, log: String) -> Signal<Void, NoError> {
    return network.request(Api.functions.phone.saveCallDebug(peer: Api.InputPhoneCall.inputPhoneCall(id: callId.id, accessHash: callId.accessHash), debug: .dataJSON(data: log)))
    |> retryRequest
    |> map { _ in }
}
