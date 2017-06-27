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

public struct BotPaymentInvoiceFields: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let name = BotPaymentInvoiceFields(rawValue: 1 << 0)
    public static let phone = BotPaymentInvoiceFields(rawValue: 1 << 1)
    public static let email = BotPaymentInvoiceFields(rawValue: 1 << 2)
    public static let shippingAddress = BotPaymentInvoiceFields(rawValue: 1 << 3)
    public static let flexibleShipping = BotPaymentInvoiceFields(rawValue: 1 << 4)
}

public struct BotPaymentPrice {
    public let label: String
    public let amount: Int64
    
    public init(label: String, amount: Int64) {
        self.label = label
        self.amount = amount
    }
}

public struct BotPaymentInvoice {
    public let isTest: Bool
    public let requestedFields: BotPaymentInvoiceFields
    public let currency: String
    public let prices: [BotPaymentPrice]
}

public struct BotPaymentNativeProvider {
    public let name: String
    public let params: String
}

public struct BotPaymentShippingAddress: Equatable {
    public let streetLine1: String
    public let streetLine2: String
    public let city: String
    public let state: String
    public let countryIso2: String
    public let postCode: String
    
    public init(streetLine1: String, streetLine2: String, city: String, state: String, countryIso2: String, postCode: String) {
        self.streetLine1 = streetLine1
        self.streetLine2 = streetLine2
        self.city = city
        self.state = state
        self.countryIso2 = countryIso2
        self.postCode = postCode
    }
    
    public static func ==(lhs: BotPaymentShippingAddress, rhs: BotPaymentShippingAddress) -> Bool {
        if lhs.streetLine1 != rhs.streetLine1 {
            return false
        }
        if lhs.streetLine2 != rhs.streetLine2 {
            return false
        }
        if lhs.city != rhs.city {
            return false
        }
        if lhs.state != rhs.state {
            return false
        }
        if lhs.countryIso2 != rhs.countryIso2 {
            return false
        }
        if lhs.postCode != rhs.postCode {
            return false
        }
        return true
    }
}

public struct BotPaymentRequestedInfo: Equatable {
    public let name: String?
    public let phone: String?
    public let email: String?
    public let shippingAddress: BotPaymentShippingAddress?
    
    public init(name: String?, phone: String?, email: String?, shippingAddress: BotPaymentShippingAddress?) {
        self.name = name
        self.phone = phone
        self.email = email
        self.shippingAddress = shippingAddress
    }
    
    public static func ==(lhs: BotPaymentRequestedInfo, rhs: BotPaymentRequestedInfo) -> Bool {
        if lhs.name != rhs.name {
            return false
        }
        if lhs.phone != rhs.phone {
            return false
        }
        if lhs.email != rhs.email {
            return false
        }
        if lhs.shippingAddress != rhs.shippingAddress {
            return false
        }
        return true
    }
}

public enum BotPaymentSavedCredentials {
    case card(id: String, title: String)
}

public struct BotPaymentForm {
    public let canSaveCredentials: Bool
    public let passwordMissing: Bool
    public let invoice: BotPaymentInvoice
    public let providerId: Int32
    public let url: String
    public let nativeProvider: BotPaymentNativeProvider?
    public let savedInfo: BotPaymentRequestedInfo?
    public let savedCredentials: BotPaymentSavedCredentials?
}

public enum BotPaymentFormRequestError {
    case generic
}

public func fetchBotPaymentForm(postbox: Postbox, network: Network, messageId: MessageId) -> Signal<BotPaymentForm, BotPaymentFormRequestError> {
    return network.request(Api.functions.payments.getPaymentForm(msgId: messageId.id))
        |> `catch` { _ -> Signal<Api.payments.PaymentForm, BotPaymentFormRequestError> in
            return .fail(.generic)
        }
        |> map { result -> BotPaymentForm in
            switch result {
                case let .paymentForm(flags, _, invoice, providerId, url, nativeProvider, nativeParams, savedInfo, savedCredentials, _):
                    let parsedInvoice: BotPaymentInvoice
                    switch invoice {
                        case let .invoice(flags, currency, prices):
                            var fields = BotPaymentInvoiceFields()
                            if (flags & (1 << 1)) != 0 {
                                fields.insert(.name)
                            }
                            if (flags & (1 << 2)) != 0 {
                                fields.insert(.phone)
                            }
                            if (flags & (1 << 3)) != 0 {
                                fields.insert(.email)
                            }
                            if (flags & (1 << 4)) != 0 {
                                fields.insert(.shippingAddress)
                            }
                            if (flags & (1 << 5)) != 0 {
                                fields.insert(.flexibleShipping)
                            }
                            parsedInvoice = BotPaymentInvoice(isTest: (flags & (1 << 0)) != 0, requestedFields: fields, currency: currency, prices: prices.map {
                                switch $0 {
                                    case let .labeledPrice(label, amount):
                                        return BotPaymentPrice(label: label, amount: amount)
                                }
                            })
                    }
                    var parsedNativeProvider: BotPaymentNativeProvider?
                    if let nativeProvider = nativeProvider, let nativeParams = nativeParams {
                        switch nativeParams {
                            case let .dataJSON(data):
                            parsedNativeProvider = BotPaymentNativeProvider(name: nativeProvider, params: data)
                        }
                    }
                    var parsedSavedInfo: BotPaymentRequestedInfo?
                    if let savedInfo = savedInfo {
                        switch savedInfo {
                            case let .paymentRequestedInfo(_, name, phone, email, shippingAddress):
                                var parsedShippingAddress: BotPaymentShippingAddress?
                                if let shippingAddress = shippingAddress {
                                    switch shippingAddress {
                                        case let .postAddress(streetLine1, streetLine2, city, state, countryIso2, postCode):
                                            parsedShippingAddress = BotPaymentShippingAddress(streetLine1: streetLine1, streetLine2: streetLine2, city: city, state: state, countryIso2: countryIso2, postCode: postCode)
                                    }
                                }
                                parsedSavedInfo = BotPaymentRequestedInfo(name: name, phone: phone, email: email, shippingAddress: parsedShippingAddress)
                        }
                    }
                    var parsedSavedCredentials: BotPaymentSavedCredentials?
                    if let savedCredentials = savedCredentials {
                        switch savedCredentials {
                            case let .paymentSavedCredentialsCard(id, title):
                                parsedSavedCredentials = .card(id: id, title: title)
                        }
                    }
                    return BotPaymentForm(canSaveCredentials: (flags & (1 << 2)) != 0, passwordMissing: (flags & (1 << 3)) != 0, invoice: parsedInvoice, providerId: providerId, url: url, nativeProvider: parsedNativeProvider, savedInfo: parsedSavedInfo, savedCredentials: parsedSavedCredentials)
            }
        }
}

public enum ValidateBotPaymentFormError {
    case generic
}

public struct BotPaymentShippingOption {
    public let id: String
    public let title: String
    public let prices: [BotPaymentPrice]
}

public struct BotPaymentValidatedFormInfo {
    public let id: String?
    public let shippingOptions: [BotPaymentShippingOption]?
}

public func validateBotPaymentForm(network: Network, saveInfo: Bool, messageId: MessageId, formInfo: BotPaymentRequestedInfo) -> Signal<BotPaymentValidatedFormInfo, ValidateBotPaymentFormError>  {
    var flags: Int32 = 0
    if saveInfo {
        flags |= (1 << 0)
    }
    var infoFlags: Int32 = 0
    if let _ = formInfo.name {
        infoFlags |= (1 << 0)
    }
    if let _ = formInfo.phone {
        infoFlags |= (1 << 1)
    }
    if let _ = formInfo.email {
        infoFlags |= (1 << 2)
    }
    var apiShippingAddress: Api.PostAddress?
    if let address = formInfo.shippingAddress {
        infoFlags |= (1 << 3)
        apiShippingAddress = .postAddress(streetLine1: address.streetLine1, streetLine2: address.streetLine2, city: address.city, state: address.state, countryIso2: address.countryIso2, postCode: address.postCode)
    }
    return network.request(Api.functions.payments.validateRequestedInfo(flags: flags, msgId: messageId.id, info: .paymentRequestedInfo(flags: infoFlags, name: formInfo.name, phone: formInfo.phone, email: formInfo.email, shippingAddress: apiShippingAddress)))
        |> mapError { error -> ValidateBotPaymentFormError in
            return .generic
        }
        |> map { result -> BotPaymentValidatedFormInfo in
            switch result {
                case let .validatedRequestedInfo(_, id, shippingOptions):
                    return BotPaymentValidatedFormInfo(id: id, shippingOptions: shippingOptions.flatMap {
                        return $0.map {
                            switch $0 {
                                case let .shippingOption(id, title, prices):
                                    return BotPaymentShippingOption(id: id, title: title, prices: prices.map {
                                        switch $0 {
                                            case let .labeledPrice(label, amount):
                                                return BotPaymentPrice(label: label, amount: amount)
                                        }
                                    })
                            }
                        }
                    })
            }
        }
}

public enum BotPaymentCredentials {
    case generic(data: String, saveOnServer: Bool)
    case saved(id: String, tempPassword: Data)
}

public enum SendBotPaymentFormError {
    case generic
}

public enum SendBotPaymentResult {
    case done
    case externalVerificationRequired(url: String)
}

public func sendBotPaymentForm(account: Account, messageId: MessageId, validatedInfoId: String?, shippingOptionId: String?, credentials: BotPaymentCredentials) -> Signal<SendBotPaymentResult, SendBotPaymentFormError> {
    let apiCredentials: Api.InputPaymentCredentials
    switch credentials {
        case let .generic(data, saveOnServer):
            var credentialsFlags: Int32 = 0
            if saveOnServer {
                credentialsFlags |= (1 << 0)
            }
            apiCredentials = .inputPaymentCredentials(flags: credentialsFlags, data: .dataJSON(data: data))
        case let .saved(id, tempPassword):
            apiCredentials = .inputPaymentCredentialsSaved(id: id, tmpPassword: Buffer(data: tempPassword))
    }
    var flags: Int32 = 0
    if validatedInfoId != nil {
        flags |= (1 << 0)
    }
    if shippingOptionId != nil {
        flags |= (1 << 1)
    }
    return account.network.request(Api.functions.payments.sendPaymentForm(flags: flags, msgId: messageId.id, requestedInfoId: validatedInfoId, shippingOptionId: shippingOptionId, credentials: apiCredentials))
        |> map { result -> SendBotPaymentResult in
            switch result {
                case let .paymentResult(updates):
                    account.stateManager.addUpdates(updates)
                    return .done
                case let .paymentVerficationNeeded(url):
                    return .externalVerificationRequired(url: url)
            }
        }
        |> `catch` { _ -> Signal<SendBotPaymentResult, SendBotPaymentFormError> in
            return .fail(.generic)
        }
}
