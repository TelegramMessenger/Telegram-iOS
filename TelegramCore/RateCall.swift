import Foundation
#if os(macOS)
    import PostboxMac
    import MtProtoKitMac
    import SwiftSignalKitMac
#else
    import Postbox
    import MtProtoKitDynamic
    import SwiftSignalKit
#endif

public func rateCall(account: Account, callId: CallId, starsCount: Int32, comment: String = "") -> Signal<Void, NoError> {
    return account.network.request(Api.functions.phone.setCallRating(peer: Api.InputPhoneCall.inputPhoneCall(id: callId.id, accessHash: callId.accessHash), rating: starsCount, comment: comment))
    |> retryRequest
    |> map { _ in }
}

public func saveCallDebugLog(account: Account, callId: CallId, log: String) -> Signal<Void, NoError> {
    return account.network.request(Api.functions.phone.saveCallDebug(peer: Api.InputPhoneCall.inputPhoneCall(id: callId.id, accessHash: callId.accessHash), debug: .dataJSON(data: log)))
    |> retryRequest
    |> map { _ in }
}
