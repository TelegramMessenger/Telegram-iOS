import Foundation
import SwiftSignalKit
import TelegramApi

public struct OnrampMethodAvailability: Equatable {
    public let paymentMethod: String
    public let isAvailable: Bool

    public init(paymentMethod: String, isAvailable: Bool) {
        self.paymentMethod = paymentMethod
        self.isAvailable = isAvailable
    }
}

public struct OnrampProviderInfo: Equatable {
    public let id: String
    public let name: String
    public let cryptoCurrencies: [String]
    public let supportsBaseCurrencies: Bool
    public let supportsLimits: Bool
    public let supportsQuote: Bool

    public init(id: String, name: String, cryptoCurrencies: [String], supportsBaseCurrencies: Bool, supportsLimits: Bool, supportsQuote: Bool) {
        self.id = id
        self.name = name
        self.cryptoCurrencies = cryptoCurrencies
        self.supportsBaseCurrencies = supportsBaseCurrencies
        self.supportsLimits = supportsLimits
        self.supportsQuote = supportsQuote
    }
}

public struct OnrampAvailability: Equatable {
    public let isAllowed: Bool
    public let isBuyAllowed: Bool
    public let countryCode: String
    public let state: String?
    public let methods: [OnrampMethodAvailability]

    public init(isAllowed: Bool, isBuyAllowed: Bool, countryCode: String, state: String?, methods: [OnrampMethodAvailability]) {
        self.isAllowed = isAllowed
        self.isBuyAllowed = isBuyAllowed
        self.countryCode = countryCode
        self.state = state
        self.methods = methods
    }
}

public struct OnrampLimits: Equatable {
    public let baseCurrency: String
    public let baseMinAmount: String
    public let baseMaxAmount: String
    public let cryptoMinAmount: String
    public let cryptoMaxAmount: String
    public let paymentMethod: String

    public init(baseCurrency: String, baseMinAmount: String, baseMaxAmount: String, cryptoMinAmount: String, cryptoMaxAmount: String, paymentMethod: String) {
        self.baseCurrency = baseCurrency
        self.baseMinAmount = baseMinAmount
        self.baseMaxAmount = baseMaxAmount
        self.cryptoMinAmount = cryptoMinAmount
        self.cryptoMaxAmount = cryptoMaxAmount
        self.paymentMethod = paymentMethod
    }
}

public struct OnrampQuote: Equatable {
    public let baseCurrency: String
    public let baseAmount: String
    public let cryptoCurrency: String
    public let cryptoAmount: String
    public let cryptoPrice: String
    public let feeAmount: String
    public let extraFeeAmount: String
    public let networkFeeAmount: String
    public let totalAmount: String
    public let paymentMethod: String
    public let expiresDate: Int32

    public init(baseCurrency: String, baseAmount: String, cryptoCurrency: String, cryptoAmount: String, cryptoPrice: String, feeAmount: String, extraFeeAmount: String, networkFeeAmount: String, totalAmount: String, paymentMethod: String, expiresDate: Int32) {
        self.baseCurrency = baseCurrency
        self.baseAmount = baseAmount
        self.cryptoCurrency = cryptoCurrency
        self.cryptoAmount = cryptoAmount
        self.cryptoPrice = cryptoPrice
        self.feeAmount = feeAmount
        self.extraFeeAmount = extraFeeAmount
        self.networkFeeAmount = networkFeeAmount
        self.totalAmount = totalAmount
        self.paymentMethod = paymentMethod
        self.expiresDate = expiresDate
    }
}

public struct OnrampSession: Equatable {
    public let provider: String
    public let sessionId: String
    public let url: String
    public let expiresDate: Int32

    public init(provider: String, sessionId: String, url: String, expiresDate: Int32) {
        self.provider = provider
        self.sessionId = sessionId
        self.url = url
        self.expiresDate = expiresDate
    }
}

public enum OnrampQuoteAmount: Equatable {
    case base(String)
    case crypto(String)
}

public enum OnrampError: Equatable {
    case generic
}

private extension OnrampMethodAvailability {
    init(apiMethodAvailability: Api.OnrampMethodAvailability) {
        switch apiMethodAvailability {
        case let .onrampMethodAvailability(data):
            self.init(
                paymentMethod: data.paymentMethod,
                isAvailable: (data.flags & (1 << 0)) != 0
            )
        }
    }
}

private extension OnrampProviderInfo {
    init(apiProviderInfo: Api.OnrampProviderInfo) {
        switch apiProviderInfo {
        case let .onrampProviderInfo(data):
            self.init(
                id: data.id,
                name: data.name,
                cryptoCurrencies: data.cryptoCurrencies,
                supportsBaseCurrencies: (data.flags & (1 << 0)) != 0,
                supportsLimits: (data.flags & (1 << 1)) != 0,
                supportsQuote: (data.flags & (1 << 2)) != 0
            )
        }
    }
}

private extension OnrampAvailability {
    init(apiAvailability: Api.OnrampAvailability) {
        switch apiAvailability {
        case let .onrampAvailability(data):
            self.init(
                isAllowed: (data.flags & (1 << 0)) != 0,
                isBuyAllowed: (data.flags & (1 << 1)) != 0,
                countryCode: data.countryCode,
                state: data.state,
                methods: data.methods.map(OnrampMethodAvailability.init(apiMethodAvailability:))
            )
        }
    }
}

private extension OnrampLimits {
    init(apiLimits: Api.OnrampLimits) {
        switch apiLimits {
        case let .onrampLimits(data):
            self.init(
                baseCurrency: data.baseCurrency,
                baseMinAmount: data.baseMinAmount,
                baseMaxAmount: data.baseMaxAmount,
                cryptoMinAmount: data.cryptoMinAmount,
                cryptoMaxAmount: data.cryptoMaxAmount,
                paymentMethod: data.paymentMethod
            )
        }
    }
}

private extension OnrampQuote {
    init(apiQuote: Api.OnrampQuote) {
        switch apiQuote {
        case let .onrampQuote(data):
            self.init(
                baseCurrency: data.baseCurrency,
                baseAmount: data.baseAmount,
                cryptoCurrency: data.cryptoCurrency,
                cryptoAmount: data.cryptoAmount,
                cryptoPrice: data.cryptoPrice,
                feeAmount: data.feeAmount,
                extraFeeAmount: data.extraFeeAmount,
                networkFeeAmount: data.networkFeeAmount,
                totalAmount: data.totalAmount,
                paymentMethod: data.paymentMethod,
                expiresDate: data.expiresDate
            )
        }
    }
}

private extension OnrampSession {
    init(apiSession: Api.OnrampSession) {
        switch apiSession {
        case let .onrampSession(data):
            self.init(
                provider: data.provider,
                sessionId: data.sessionId,
                url: data.url,
                expiresDate: data.expiresDate
            )
        }
    }
}

func _internal_getOnrampProviders(account: Account, cryptoCurrency: String?) -> Signal<[OnrampProviderInfo], OnrampError> {
    var flags: Int32 = 0
    if cryptoCurrency != nil {
        flags |= 1 << 0
    }
    return account.network.request(Api.functions.payments.getOnrampProviders(flags: flags, cryptoCurrency: cryptoCurrency))
    |> map { providers in
        return providers.map(OnrampProviderInfo.init(apiProviderInfo:))
    }
    |> mapError { _ in
        return OnrampError.generic
    }
}

func _internal_getOnrampBaseCurrencies(account: Account, provider: String, cryptoCurrency: String) -> Signal<[String], OnrampError> {
    return account.network.request(Api.functions.payments.getOnrampBaseCurrencies(provider: provider, cryptoCurrency: cryptoCurrency))
    |> mapError { _ in
        return OnrampError.generic
    }
}

func _internal_getOnrampAvailability(account: Account, provider: String, cryptoCurrency: String, baseCurrency: String?) -> Signal<OnrampAvailability, OnrampError> {
    var flags: Int32 = 0
    if baseCurrency != nil {
        flags |= 1 << 0
    }
    return account.network.request(Api.functions.payments.getOnrampAvailability(flags: flags, provider: provider, cryptoCurrency: cryptoCurrency, baseCurrency: baseCurrency))
    |> map(OnrampAvailability.init(apiAvailability:))
    |> mapError { _ in
        return OnrampError.generic
    }
}

func _internal_getOnrampLimits(account: Account, provider: String, cryptoCurrency: String, baseCurrency: String, paymentMethod: String?) -> Signal<OnrampLimits, OnrampError> {
    var flags: Int32 = 0
    if paymentMethod != nil {
        flags |= 1 << 0
    }
    return account.network.request(Api.functions.payments.getOnrampLimits(flags: flags, provider: provider, cryptoCurrency: cryptoCurrency, baseCurrency: baseCurrency, paymentMethod: paymentMethod))
    |> map(OnrampLimits.init(apiLimits:))
    |> mapError { _ in
        return OnrampError.generic
    }
}

func _internal_getOnrampQuote(account: Account, provider: String, cryptoCurrency: String, baseCurrency: String, amount: OnrampQuoteAmount, paymentMethod: String?) -> Signal<OnrampQuote, OnrampError> {
    var flags: Int32 = 0
    let baseAmount: String?
    let cryptoAmount: String?
    switch amount {
    case let .base(value):
        flags |= 1 << 0
        baseAmount = value
        cryptoAmount = nil
    case let .crypto(value):
        flags |= 1 << 1
        baseAmount = nil
        cryptoAmount = value
    }
    if paymentMethod != nil {
        flags |= 1 << 2
    }
    return account.network.request(Api.functions.payments.getOnrampQuote(flags: flags, provider: provider, cryptoCurrency: cryptoCurrency, baseCurrency: baseCurrency, baseAmount: baseAmount, cryptoAmount: cryptoAmount, paymentMethod: paymentMethod))
    |> map(OnrampQuote.init(apiQuote:))
    |> mapError { _ in
        return OnrampError.generic
    }
}

func _internal_createOnrampSession(
    account: Account,
    provider: String,
    cryptoCurrency: String,
    address: String,
    paymentMethod: String?,
    baseCurrency: String?,
    baseAmount: String?,
    memo: String?,
    theme: String?,
    successReturnUrl: String?,
    failReturnUrl: String?
) -> Signal<OnrampSession, OnrampError> {
    var flags: Int32 = 0
    if paymentMethod != nil {
        flags |= 1 << 0
    }
    if baseCurrency != nil {
        flags |= 1 << 1
    }
    if baseAmount != nil {
        flags |= 1 << 2
    }
    if memo != nil {
        flags |= 1 << 3
    }
    if theme != nil {
        flags |= 1 << 4
    }
    if successReturnUrl != nil {
        flags |= 1 << 5
    }
    if failReturnUrl != nil {
        flags |= 1 << 6
    }
    return account.network.request(Api.functions.payments.createOnrampSession(
        flags: flags,
        provider: provider,
        cryptoCurrency: cryptoCurrency,
        address: address,
        paymentMethod: paymentMethod,
        baseCurrency: baseCurrency,
        baseAmount: baseAmount,
        memo: memo,
        theme: theme,
        successReturnUrl: successReturnUrl,
        failReturnUrl: failReturnUrl,
        cryptoAmount: nil
    ))
    |> map(OnrampSession.init(apiSession:))
    |> mapError { _ in
        return OnrampError.generic
    }
}
