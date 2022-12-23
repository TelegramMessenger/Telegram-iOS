import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

public enum BotPaymentInvoiceSource {
    case message(MessageId)
    case slug(String)
}

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
    public static let phoneAvailableToProvider = BotPaymentInvoiceFields(rawValue: 1 << 5)
    public static let emailAvailableToProvider = BotPaymentInvoiceFields(rawValue: 1 << 6)
}

public struct BotPaymentPrice : Equatable {
    public let label: String
    public let amount: Int64
    
    public init(label: String, amount: Int64) {
        self.label = label
        self.amount = amount
    }
}

public struct BotPaymentInvoice : Equatable {
    public struct Tip: Equatable {
        public var max: Int64
        public var suggested: [Int64]
    }
    
    public struct RecurrentInfo: Equatable {
        public var termsUrl: String
    }

    public let isTest: Bool
    public let requestedFields: BotPaymentInvoiceFields
    public let currency: String
    public let prices: [BotPaymentPrice]
    public let tip: Tip?
    public let recurrentInfo: RecurrentInfo?
}

public struct BotPaymentNativeProvider : Equatable {
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
}

public struct BotPaymentRequestedInfo: Equatable {
    public var name: String?
    public var phone: String?
    public var email: String?
    public var shippingAddress: BotPaymentShippingAddress?
    
    public init(name: String?, phone: String?, email: String?, shippingAddress: BotPaymentShippingAddress?) {
        self.name = name
        self.phone = phone
        self.email = email
        self.shippingAddress = shippingAddress
    }
}

public enum BotPaymentSavedCredentials: Equatable {
    case card(id: String, title: String)
    
    public static func ==(lhs: BotPaymentSavedCredentials, rhs: BotPaymentSavedCredentials) -> Bool {
        switch lhs {
            case let .card(id, title):
                if case .card(id, title) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public struct BotPaymentForm : Equatable {
    public let id: Int64
    public let canSaveCredentials: Bool
    public let passwordMissing: Bool
    public let invoice: BotPaymentInvoice
    public let paymentBotId: PeerId
    public let providerId: PeerId
    public let url: String
    public let nativeProvider: BotPaymentNativeProvider?
    public let savedInfo: BotPaymentRequestedInfo?
    public let savedCredentials: [BotPaymentSavedCredentials]
    public let additionalPaymentMethods: [BotPaymentMethod]
}

public struct BotPaymentMethod: Equatable {
    public let url: String
    public let title: String
}

extension BotPaymentMethod {
    init(apiPaymentFormMethod: Api.PaymentFormMethod) {
        switch apiPaymentFormMethod {
            case let .paymentFormMethod(url, title):
                self.init(url: url, title: title)
        }
    }
}

public enum BotPaymentFormRequestError {
    case generic
}

extension BotPaymentInvoice {
    init(apiInvoice: Api.Invoice) {
        switch apiInvoice {
        case let .invoice(flags, currency, prices, maxTipAmount, suggestedTipAmounts, recurrentTermsUrl):
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
            if (flags & (1 << 6)) != 0 {
                fields.insert(.phoneAvailableToProvider)
            }
            if (flags & (1 << 7)) != 0 {
                fields.insert(.emailAvailableToProvider)
            }
            var recurrentInfo: BotPaymentInvoice.RecurrentInfo?
            if let recurrentTermsUrl = recurrentTermsUrl {
                recurrentInfo = BotPaymentInvoice.RecurrentInfo(termsUrl: recurrentTermsUrl)
            }
            var parsedTip: BotPaymentInvoice.Tip?
            if let maxTipAmount = maxTipAmount, let suggestedTipAmounts = suggestedTipAmounts {
                parsedTip = BotPaymentInvoice.Tip(max: maxTipAmount, suggested: suggestedTipAmounts)
            }
            self.init(isTest: (flags & (1 << 0)) != 0, requestedFields: fields, currency: currency, prices: prices.map {
                switch $0 {
                case let .labeledPrice(label, amount):
                    return BotPaymentPrice(label: label, amount: amount)
                }
            }, tip: parsedTip, recurrentInfo: recurrentInfo)
        }
    }
}

extension BotPaymentRequestedInfo {
    init(apiInfo: Api.PaymentRequestedInfo) {
        switch apiInfo {
            case let .paymentRequestedInfo(_, name, phone, email, shippingAddress):
                var parsedShippingAddress: BotPaymentShippingAddress?
                if let shippingAddress = shippingAddress {
                    switch shippingAddress {
                    case let .postAddress(streetLine1, streetLine2, city, state, countryIso2, postCode):
                        parsedShippingAddress = BotPaymentShippingAddress(streetLine1: streetLine1, streetLine2: streetLine2, city: city, state: state, countryIso2: countryIso2, postCode: postCode)
                    }
                }
                self.init(name: name, phone: phone, email: email, shippingAddress: parsedShippingAddress)
        }
    }
}

func _internal_fetchBotPaymentInvoice(postbox: Postbox, network: Network, source: BotPaymentInvoiceSource) -> Signal<TelegramMediaInvoice, BotPaymentFormRequestError> {
    return postbox.transaction { transaction -> Api.InputInvoice? in
        switch source {
        case let .message(messageId):
            guard let inputPeer = transaction.getPeer(messageId.peerId).flatMap(apiInputPeer) else {
                return nil
            }
            return .inputInvoiceMessage(peer: inputPeer, msgId: messageId.id)
        case let .slug(slug):
            return .inputInvoiceSlug(slug: slug)
        }
    }
    |> castError(BotPaymentFormRequestError.self)
    |> mapToSignal { invoice -> Signal<TelegramMediaInvoice, BotPaymentFormRequestError> in
        guard let invoice = invoice else {
            return .fail(.generic)
        }
        
        let flags: Int32 = 0

        return network.request(Api.functions.payments.getPaymentForm(flags: flags, invoice: invoice, themeParams: nil))
        |> `catch` { _ -> Signal<Api.payments.PaymentForm, BotPaymentFormRequestError> in
            return .fail(.generic)
        }
        |> mapToSignal { result -> Signal<TelegramMediaInvoice, BotPaymentFormRequestError> in
            return postbox.transaction { transaction -> TelegramMediaInvoice in
                switch result {
                case let .paymentForm(_, _, _, title, description, photo, invoice, _, _, _, _, _, _, _, _):
                    let parsedInvoice = BotPaymentInvoice(apiInvoice: invoice)
                    
                    var parsedFlags = TelegramMediaInvoiceFlags()
                    if parsedInvoice.isTest {
                        parsedFlags.insert(.isTest)
                    }
                    if parsedInvoice.requestedFields.contains(.shippingAddress) {
                        parsedFlags.insert(.shippingAddressRequested)
                    }
                    
                    return TelegramMediaInvoice(title: title, description: description, photo: photo.flatMap(TelegramMediaWebFile.init), receiptMessageId: nil, currency: parsedInvoice.currency, totalAmount: 0, startParam: "", extendedMedia: nil, flags: parsedFlags, version: TelegramMediaInvoice.lastVersion)
                }
            }
            |> mapError { _ -> BotPaymentFormRequestError in }
        }
    }
}

func _internal_fetchBotPaymentForm(postbox: Postbox, network: Network, source: BotPaymentInvoiceSource, themeParams: [String: Any]?) -> Signal<BotPaymentForm, BotPaymentFormRequestError> {
    return postbox.transaction { transaction -> Api.InputInvoice? in
        switch source {
        case let .message(messageId):
            guard let inputPeer = transaction.getPeer(messageId.peerId).flatMap(apiInputPeer) else {
                return nil
            }
            return .inputInvoiceMessage(peer: inputPeer, msgId: messageId.id)
        case let .slug(slug):
            return .inputInvoiceSlug(slug: slug)
        }
    }
    |> castError(BotPaymentFormRequestError.self)
    |> mapToSignal { invoice -> Signal<BotPaymentForm, BotPaymentFormRequestError> in
        guard let invoice = invoice else {
            return .fail(.generic)
        }
        
        var flags: Int32 = 0
        var serializedThemeParams: Api.DataJSON?
        if let themeParams = themeParams, let data = try? JSONSerialization.data(withJSONObject: themeParams, options: []), let dataString = String(data: data, encoding: .utf8) {
            serializedThemeParams = Api.DataJSON.dataJSON(data: dataString)
        }
        if serializedThemeParams != nil {
            flags |= 1 << 0
        }

        return network.request(Api.functions.payments.getPaymentForm(flags: flags, invoice: invoice, themeParams: serializedThemeParams))
        |> `catch` { _ -> Signal<Api.payments.PaymentForm, BotPaymentFormRequestError> in
            return .fail(.generic)
        }
        |> mapToSignal { result -> Signal<BotPaymentForm, BotPaymentFormRequestError> in
            return postbox.transaction { transaction -> BotPaymentForm in
                switch result {
                    case let .paymentForm(flags, id, botId, title, description, photo, invoice, providerId, url, nativeProvider, nativeParams, additionalMethods, savedInfo, savedCredentials, apiUsers):
                        let _ = title
                        let _ = description
                        let _ = photo
                        
                        var peers: [Peer] = []
                        for user in apiUsers {
                            let parsed = TelegramUser(user: user)
                            peers.append(parsed)
                        }
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                            return updated
                        })

                        let parsedInvoice = BotPaymentInvoice(apiInvoice: invoice)
                        var parsedNativeProvider: BotPaymentNativeProvider?
                        if let nativeProvider = nativeProvider, let nativeParams = nativeParams {
                            switch nativeParams {
                                case let .dataJSON(data):
                                parsedNativeProvider = BotPaymentNativeProvider(name: nativeProvider, params: data)
                            }
                        }
                        let parsedSavedInfo = savedInfo.flatMap(BotPaymentRequestedInfo.init)
                        let parsedSavedCredentials = savedCredentials?.map({ savedCredentials -> BotPaymentSavedCredentials in
                            switch savedCredentials {
                                case let .paymentSavedCredentialsCard(id, title):
                                    return .card(id: id, title: title)
                            }
                        }) ?? []

                        let additionalPaymentMethods = additionalMethods?.map({ BotPaymentMethod(apiPaymentFormMethod: $0) }) ?? []
                        return BotPaymentForm(id: id, canSaveCredentials: (flags & (1 << 2)) != 0, passwordMissing: (flags & (1 << 3)) != 0, invoice: parsedInvoice, paymentBotId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId)), providerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(providerId)), url: url, nativeProvider: parsedNativeProvider, savedInfo: parsedSavedInfo, savedCredentials: parsedSavedCredentials, additionalPaymentMethods: additionalPaymentMethods)
                }
            }
            |> mapError { _ -> BotPaymentFormRequestError in }
        }
    }
}

public enum ValidateBotPaymentFormError {
    case generic
    case shippingNotAvailable
    case addressStateInvalid
    case addressPostcodeInvalid
    case addressCityInvalid
    case nameInvalid
    case emailInvalid
    case phoneInvalid
}

public struct BotPaymentShippingOption : Equatable {
    public let id: String
    public let title: String
    public let prices: [BotPaymentPrice]
}

public struct BotPaymentValidatedFormInfo : Equatable {
    public let id: String?
    public let shippingOptions: [BotPaymentShippingOption]?
}

extension BotPaymentShippingOption {
    init(apiOption: Api.ShippingOption) {
        switch apiOption {
            case let .shippingOption(id, title, prices):
                self.init(id: id, title: title, prices: prices.map {
                    switch $0 {
                        case let .labeledPrice(label, amount):
                            return BotPaymentPrice(label: label, amount: amount)
                        }
                })
        }
    }
}

func _internal_validateBotPaymentForm(account: Account, saveInfo: Bool, source: BotPaymentInvoiceSource, formInfo: BotPaymentRequestedInfo) -> Signal<BotPaymentValidatedFormInfo, ValidateBotPaymentFormError> {
    return account.postbox.transaction { transaction -> Api.InputInvoice? in
        switch source {
        case let .message(messageId):
            guard let inputPeer = transaction.getPeer(messageId.peerId).flatMap(apiInputPeer) else {
                return nil
            }
            return .inputInvoiceMessage(peer: inputPeer, msgId: messageId.id)
        case let .slug(slug):
            return .inputInvoiceSlug(slug: slug)
        }
    }
    |> castError(ValidateBotPaymentFormError.self)
    |> mapToSignal { invoice -> Signal<BotPaymentValidatedFormInfo, ValidateBotPaymentFormError> in
        guard let invoice = invoice else {
            return .fail(.generic)
        }

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
        return account.network.request(Api.functions.payments.validateRequestedInfo(flags: flags, invoice: invoice, info: .paymentRequestedInfo(flags: infoFlags, name: formInfo.name, phone: formInfo.phone, email: formInfo.email, shippingAddress: apiShippingAddress)))
        |> mapError { error -> ValidateBotPaymentFormError in
            if error.errorDescription == "SHIPPING_NOT_AVAILABLE" {
                return .shippingNotAvailable
            } else if error.errorDescription == "ADDRESS_STATE_INVALID" {
                return .addressStateInvalid
            } else if error.errorDescription == "ADDRESS_POSTCODE_INVALID" {
                return .addressPostcodeInvalid
            } else if error.errorDescription == "ADDRESS_CITY_INVALID" {
                return .addressCityInvalid
            } else if error.errorDescription == "REQ_INFO_NAME_INVALID" {
                return .nameInvalid
            } else if error.errorDescription == "REQ_INFO_EMAIL_INVALID" {
                return .emailInvalid
            } else if error.errorDescription == "REQ_INFO_PHONE_INVALID" {
                return .phoneInvalid
            } else {
                return .generic
            }
        }
        |> map { result -> BotPaymentValidatedFormInfo in
            switch result {
                case let .validatedRequestedInfo(_, id, shippingOptions):
                    return BotPaymentValidatedFormInfo(id: id, shippingOptions: shippingOptions.flatMap {
                        return $0.map(BotPaymentShippingOption.init)
                    })
            }
        }
    }
}

public enum BotPaymentCredentials {
    case generic(data: String, saveOnServer: Bool)
    case saved(id: String, tempPassword: Data)
    case applePay(data: String)
}

public enum SendBotPaymentFormError {
    case generic
    case precheckoutFailed
    case paymentFailed
    case alreadyPaid
}

public enum SendBotPaymentResult {
    case done(receiptMessageId: MessageId?)
    case externalVerificationRequired(url: String)
}

func _internal_sendBotPaymentForm(account: Account, formId: Int64, source: BotPaymentInvoiceSource, validatedInfoId: String?, shippingOptionId: String?, tipAmount: Int64?, credentials: BotPaymentCredentials) -> Signal<SendBotPaymentResult, SendBotPaymentFormError> {
    return account.postbox.transaction { transaction -> Api.InputInvoice? in
        switch source {
        case let .message(messageId):
            guard let inputPeer = transaction.getPeer(messageId.peerId).flatMap(apiInputPeer) else {
                return nil
            }
            return .inputInvoiceMessage(peer: inputPeer, msgId: messageId.id)
        case let .slug(slug):
            return .inputInvoiceSlug(slug: slug)
        }
    }
    |> castError(SendBotPaymentFormError.self)
    |> mapToSignal { invoice -> Signal<SendBotPaymentResult, SendBotPaymentFormError> in
        guard let invoice = invoice else {
            return .fail(.generic)
        }
        
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
            case let .applePay(data):
                apiCredentials = .inputPaymentCredentialsApplePay(paymentData: .dataJSON(data: data))
        }
        var flags: Int32 = 0
        if validatedInfoId != nil {
            flags |= (1 << 0)
        }
        if shippingOptionId != nil {
            flags |= (1 << 1)
        }
        if tipAmount != nil {
            flags |= (1 << 2)
        }
        
        return account.network.request(Api.functions.payments.sendPaymentForm(flags: flags, formId: formId, invoice: invoice, requestedInfoId: validatedInfoId, shippingOptionId: shippingOptionId, credentials: apiCredentials, tipAmount: tipAmount))
        |> map { result -> SendBotPaymentResult in
            switch result {
                case let .paymentResult(updates):
                    account.stateManager.addUpdates(updates)
                    var receiptMessageId: MessageId?
                    for apiMessage in updates.messages {
                        if let message = StoreMessage(apiMessage: apiMessage) {
                            for media in message.media {
                                if let action = media as? TelegramMediaAction {
                                    if case .paymentSent = action.action {
                                        switch source {
                                        case let .slug(slug):
                                            for media in message.media {
                                                if let action = media as? TelegramMediaAction, case let .paymentSent(_, _, invoiceSlug?, _, _) = action.action, invoiceSlug == slug {
                                                    if case let .Id(id) = message.id {
                                                        receiptMessageId = id
                                                    }
                                                }
                                            }
                                        case let .message(messageId):
                                            for attribute in message.attributes {
                                                if let reply = attribute as? ReplyMessageAttribute {
                                                    if reply.messageId == messageId {
                                                        if case let .Id(id) = message.id {
                                                            receiptMessageId = id
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    return .done(receiptMessageId: receiptMessageId)
                case let .paymentVerificationNeeded(url):
                    return .externalVerificationRequired(url: url)
            }
        }
        |> `catch` { error -> Signal<SendBotPaymentResult, SendBotPaymentFormError> in
            if error.errorDescription == "BOT_PRECHECKOUT_FAILED" {
                return .fail(.precheckoutFailed)
            } else if error.errorDescription == "PAYMENT_FAILED" {
                return .fail(.paymentFailed)
            } else if error.errorDescription == "INVOICE_ALREADY_PAID" {
                return .fail(.alreadyPaid)
            }
            return .fail(.generic)
        }
    }
}

public struct BotPaymentReceipt : Equatable {
    public let invoice: BotPaymentInvoice
    public let info: BotPaymentRequestedInfo?
    public let shippingOption: BotPaymentShippingOption?
    public let credentialsTitle: String
    public let invoiceMedia: TelegramMediaInvoice
    public let tipAmount: Int64?
    public let botPaymentId: PeerId
    public static func ==(lhs: BotPaymentReceipt, rhs: BotPaymentReceipt) -> Bool {
        if lhs.invoice != rhs.invoice {
            return false
        }
        if lhs.info != rhs.info {
            return false
        }
        if lhs.shippingOption != rhs.shippingOption {
            return false
        }
        if lhs.credentialsTitle != rhs.credentialsTitle {
            return false
        }
        if !lhs.invoiceMedia.isEqual(to: rhs.invoiceMedia) {
            return false
        }
        if lhs.tipAmount != rhs.tipAmount {
            return false
        }
        if lhs.botPaymentId != rhs.botPaymentId {
            return false
        }
        return true
    }
}

public enum RequestBotPaymentReceiptError {
    case generic
}

func _internal_requestBotPaymentReceipt(account: Account, messageId: MessageId) -> Signal<BotPaymentReceipt, RequestBotPaymentReceiptError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
    }
    |> castError(RequestBotPaymentReceiptError.self)
    |> mapToSignal { inputPeer -> Signal<BotPaymentReceipt, RequestBotPaymentReceiptError> in
        guard let inputPeer = inputPeer else {
            return .fail(.generic)
        }

        return account.network.request(Api.functions.payments.getPaymentReceipt(peer: inputPeer, msgId: messageId.id))
        |> mapError { _ -> RequestBotPaymentReceiptError in
            return .generic
        }
        |> mapToSignal { result -> Signal<BotPaymentReceipt, RequestBotPaymentReceiptError> in
            return account.postbox.transaction { transaction -> BotPaymentReceipt in
                switch result {
                case let .paymentReceipt(_, _, botId, _, title, description, photo, invoice, info, shipping, tipAmount, currency, totalAmount, credentialsTitle, users):
                    var peers: [Peer] = []
                    for user in users {
                        peers.append(TelegramUser(user: user))
                    }
                    updatePeers(transaction: transaction, peers: peers, update: { _, updated in return updated })

                    let parsedInvoice = BotPaymentInvoice(apiInvoice: invoice)
                    let parsedInfo = info.flatMap(BotPaymentRequestedInfo.init)
                    let shippingOption = shipping.flatMap(BotPaymentShippingOption.init)

                    let invoiceMedia = TelegramMediaInvoice(
                        title: title,
                        description: description,
                        photo: photo.flatMap(TelegramMediaWebFile.init),
                        receiptMessageId: nil,
                        currency: currency,
                        totalAmount: totalAmount,
                        startParam: "",
                        extendedMedia: nil,
                        flags: [],
                        version: TelegramMediaInvoice.lastVersion
                    )
                    
                    let botPaymentId = PeerId.init(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId))

                    return BotPaymentReceipt(invoice: parsedInvoice, info: parsedInfo, shippingOption: shippingOption, credentialsTitle: credentialsTitle, invoiceMedia: invoiceMedia, tipAmount: tipAmount, botPaymentId: botPaymentId)
                }
            }
            |> castError(RequestBotPaymentReceiptError.self)
        }
    }
}

public struct BotPaymentInfo: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let paymentInfo = BotPaymentInfo(rawValue: 1 << 0)
    public static let shippingInfo = BotPaymentInfo(rawValue: 1 << 1)
}

func _internal_clearBotPaymentInfo(network: Network, info: BotPaymentInfo) -> Signal<Void, NoError> {
    var flags: Int32 = 0
    if info.contains(.paymentInfo) {
        flags |= (1 << 0)
    }
    if info.contains(.shippingInfo) {
        flags |= (1 << 1)
    }
    return network.request(Api.functions.payments.clearSavedInfo(flags: flags))
    |> retryRequest
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return .complete()
    }
}
