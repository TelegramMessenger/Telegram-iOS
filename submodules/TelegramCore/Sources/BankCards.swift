import Foundation
import Postbox
import TelegramApi
import SyncCore
import SwiftSignalKit

public struct BankCardInfo {
    public let title: String
    public let url: String?
    public let actionTitle: String?
}

public func getBankCardInfo(account: Account, cardNumber: String) -> Signal<BankCardInfo?, NoError> {
    return account.network.request(Api.functions.payments.getBankCardData(number: cardNumber))
    |> map { result -> BankCardInfo? in
        return BankCardInfo(apiBankCardData: result)
    }
    |> `catch` { _ -> Signal<BankCardInfo?, NoError> in
        return .single(nil)
    }
}

extension BankCardInfo {
    init(apiBankCardData: Api.payments.BankCardData) {
        switch apiBankCardData {
            case let .bankCardData(flags, title, url, urlName):
                self.title = title
                self.url = url
                self.actionTitle = urlName
        }
    }
}


