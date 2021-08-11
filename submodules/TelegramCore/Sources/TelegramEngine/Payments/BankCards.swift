import Foundation
import Postbox
import TelegramApi
import MtProtoKit
import SwiftSignalKit

func _internal_getBankCardInfo(account: Account, cardNumber: String) -> Signal<BankCardInfo?, NoError> {
    return currentWebDocumentsHostDatacenterId(postbox: account.postbox, isTestingEnvironment: false)
    |> mapToSignal { datacenterId in
        let signal: Signal<Api.payments.BankCardData, MTRpcError>
        if account.network.datacenterId != datacenterId {
            signal = account.network.download(datacenterId: Int(datacenterId), isMedia: false, tag: nil)
            |> castError(MTRpcError.self)
            |> mapToSignal { worker in
                return worker.request(Api.functions.payments.getBankCardData(number: cardNumber))
            }
        } else {
            signal = account.network.request(Api.functions.payments.getBankCardData(number: cardNumber))
        }
        return signal
        |> map { result -> BankCardInfo? in
            return BankCardInfo(apiBankCardData: result)
        }
        |> `catch` { _ -> Signal<BankCardInfo?, NoError> in
            return .single(nil)
        }
    }
}

public struct BankCardUrl {
    public let title: String
    public let url: String
}

public struct BankCardInfo {
    public let title: String
    public let urls: [BankCardUrl]
}

extension BankCardUrl {
    init(apiBankCardOpenUrl: Api.BankCardOpenUrl) {
        switch apiBankCardOpenUrl {
            case let .bankCardOpenUrl(url, name):
                self.title = name
                self.url = url
        }
    }
}

extension BankCardInfo {
    init(apiBankCardData: Api.payments.BankCardData) {
        switch apiBankCardData {
            case let .bankCardData(title, urls):
                self.title = title
                self.urls = urls.map { BankCardUrl(apiBankCardOpenUrl: $0) }
        }
    }
}
