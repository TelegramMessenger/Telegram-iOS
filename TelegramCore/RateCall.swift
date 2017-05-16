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

public func rateCall(account:Account, report:ReportCallRating, starsCount:Int32, comment:String = "") -> Signal<Void, Void> {
    return account.network.request(Api.functions.phone.setCallRating(peer: Api.InputPhoneCall.inputPhoneCall(id: report.id, accessHash: report.accessHash), rating: starsCount, comment: comment)) |> retryRequest |> map {_ in}
}
