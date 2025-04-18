import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

public enum ReportAdMessageResult {
    public struct Option: Equatable {
        public let text: String
        public let option: Data
    }
    
    case options(title: String, options: [Option])
    case adsHidden
    case reported
}

public enum ReportAdMessageError {
    case generic
    case premiumRequired
}

func _internal_reportAdMessage(account: Account, peerId: EnginePeer.Id, opaqueId: Data, option: Data?) -> Signal<ReportAdMessageResult, ReportAdMessageError> {
    return account.postbox.transaction { transaction -> Signal<ReportAdMessageResult, ReportAdMessageError> in
        guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.messages.reportSponsoredMessage(peer: inputPeer, randomId: Buffer(data: opaqueId), option: Buffer(data: option)))
        |> mapError { error -> ReportAdMessageError in
            if error.errorDescription == "PREMIUM_ACCOUNT_REQUIRED" {
                return .premiumRequired
            }
            return .generic
        }
        |> map { result -> ReportAdMessageResult in
            switch result {
            case let .sponsoredMessageReportResultChooseOption(title, options):
                return .options(title: title, options: options.map {
                    switch $0 {
                    case let .sponsoredMessageReportOption(text, option):
                        return ReportAdMessageResult.Option(text: text, option: option.makeData())
                    }
                })
            case .sponsoredMessageReportResultAdsHidden:
                return .adsHidden
            case .sponsoredMessageReportResultReported:
                return .reported
            }
        }
    }
    |> castError(ReportAdMessageError.self)
    |> switchToLatest
}
