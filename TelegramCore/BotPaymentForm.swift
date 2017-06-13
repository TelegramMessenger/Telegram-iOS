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

public struct BotPaymentShippingAddress {
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
}

public struct BotPaymentRequestedInfo {
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

public enum BotPaymentFormReuestError {
    case generic
}

public func fetchBotPaymentForm(postbox: Postbox, network: Network, messageId: MessageId) -> Signal<BotPaymentForm, BotPaymentFormReuestError> {
    return network.request(Api.functions.payments.getPaymentForm(msgId: messageId.id))
        |> `catch` { _ -> Signal<Api.payments.PaymentForm, BotPaymentFormReuestError> in
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
