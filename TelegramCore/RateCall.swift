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

public func rateCall(account: Account, report: ReportCallRating, starsCount: Int32, comment: String = "") -> Signal<Void, NoError> {
    return account.network.request(Api.functions.phone.setCallRating(peer: Api.InputPhoneCall.inputPhoneCall(id: report.id, accessHash: report.accessHash), rating: starsCount, comment: comment))
    |> retryRequest
    |> map { _ in }
}

public func saveCallDebugLog(account: Account, id: Int64, accessHash: Int64, log: String) -> Signal<Void, NoError> {
    return account.network.request(Api.functions.phone.saveCallDebug(peer: Api.InputPhoneCall.inputPhoneCall(id: id, accessHash: accessHash), debug: .dataJSON(data: log)))
    |> retryRequest
    |> map { _ in }
}
