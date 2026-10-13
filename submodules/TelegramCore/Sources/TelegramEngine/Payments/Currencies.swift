import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

public struct CurrencyRate: Codable {
    public let currency: String
    public let rate: Double

    public init(currency: String, rate: Double) {
        self.currency = currency
        self.rate = rate
    }
}

private final class CachedCurrencyRates: Codable {
    let rates: [CurrencyRate]
    let timestamp: Int32

    init(rates: [CurrencyRate], timestamp: Int32) {
        self.rates = rates
        self.timestamp = timestamp
    }
}

func _internal_currencyRates(account: Account) -> Signal<[CurrencyRate]?, NoError> {
    let cacheId = ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedCurrencyRates, key: ValueBoxKey(length: 0))
    return account.postbox.transaction { transaction -> CachedCurrencyRates? in
        return transaction.retrieveItemCacheEntry(id: cacheId)?.get(CachedCurrencyRates.self)
    }
    |> mapToSignal { cachedRates -> Signal<[CurrencyRate]?, NoError> in
        let timestamp = Int32(Date().timeIntervalSince1970)
        if let cachedRates, cachedRates.timestamp <= timestamp && cachedRates.timestamp > timestamp - 15 * 60 {
            return .single(cachedRates.rates)
        }

        return account.network.request(Api.functions.payments.getCurrencyRates())
        |> map { result -> [CurrencyRate]? in
            switch result {
            case let .currencyRates(currencyRatesData):
                return currencyRatesData.rates.map { currencyRate in
                    switch currencyRate {
                    case let .currencyRate(currencyRateData):
                        return CurrencyRate(currency: currencyRateData.currency, rate: currencyRateData.rate)
                    }
                }
            }
        }
        |> `catch` { _ -> Signal<[CurrencyRate]?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { rates -> Signal<[CurrencyRate]?, NoError> in
            guard let rates else {
                return .single(nil)
            }
            return account.postbox.transaction { transaction -> [CurrencyRate]? in
                let timestamp = Int32(Date().timeIntervalSince1970)
                if let entry = CodableEntry(CachedCurrencyRates(rates: rates, timestamp: timestamp)) {
                    transaction.putItemCacheEntry(id: cacheId, entry: entry)
                }
                return rates
            }
        }
    }
}
