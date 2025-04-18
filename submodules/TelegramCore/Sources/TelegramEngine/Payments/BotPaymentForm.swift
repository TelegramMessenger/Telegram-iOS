import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

public enum BotPaymentInvoiceSource {
    case message(MessageId)
    case slug(String)
    case premiumGiveaway(boostPeer: EnginePeer.Id, additionalPeerIds: [EnginePeer.Id], countries: [String], onlyNewSubscribers: Bool, showWinners: Bool, prizeDescription: String?, randomId: Int64, untilDate: Int32, currency: String, amount: Int64, option: PremiumGiftCodeOption)
    case giftCode(users: [PeerId], currency: String, amount: Int64, option: PremiumGiftCodeOption, text: String?, entities: [MessageTextEntity]?)
    case stars(option: StarsTopUpOption)
    case starsGift(peerId: EnginePeer.Id, count: Int64, currency: String, amount: Int64)
    case starsChatSubscription(hash: String)
    case starsGiveaway(stars: Int64, boostPeer: EnginePeer.Id, additionalPeerIds: [EnginePeer.Id], countries: [String], onlyNewSubscribers: Bool, showWinners: Bool, prizeDescription: String?, randomId: Int64, untilDate: Int32, currency: String, amount: Int64, users: Int32)
    case starGift(hideName: Bool, includeUpgrade: Bool, peerId: EnginePeer.Id, giftId: Int64, text: String?, entities: [MessageTextEntity]?)
    case starGiftUpgrade(keepOriginalInfo: Bool, reference: StarGiftReference)
    case starGiftTransfer(reference: StarGiftReference, toPeerId: EnginePeer.Id)
    case premiumGift(peerId: EnginePeer.Id, option: CachedPremiumGiftOption, text: String?, entities: [MessageTextEntity]?)
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
        public var isRecurrent: Bool
    }

    public let isTest: Bool
    public let requestedFields: BotPaymentInvoiceFields
    public let currency: String
    public let prices: [BotPaymentPrice]
    public let tip: Tip?
    public let termsInfo: RecurrentInfo?
    public let subscriptionPeriod: Int32?
    
    public init(isTest: Bool, requestedFields: BotPaymentInvoiceFields, currency: String, prices: [BotPaymentPrice], tip: Tip?, termsInfo: RecurrentInfo?, subscriptionPeriod: Int32?) {
        self.isTest = isTest
        self.requestedFields = requestedFields
        self.currency = currency
        self.prices = prices
        self.tip = tip
        self.termsInfo = termsInfo
        self.subscriptionPeriod = subscriptionPeriod
    }
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
    public let paymentBotId: PeerId?
    public let providerId: PeerId?
    public let url: String?
    public let nativeProvider: BotPaymentNativeProvider?
    public let savedInfo: BotPaymentRequestedInfo?
    public let savedCredentials: [BotPaymentSavedCredentials]
    public let additionalPaymentMethods: [BotPaymentMethod]
    
    public init(id: Int64, canSaveCredentials: Bool, passwordMissing: Bool, invoice: BotPaymentInvoice, paymentBotId: PeerId?, providerId: PeerId?, url: String?, nativeProvider: BotPaymentNativeProvider?, savedInfo: BotPaymentRequestedInfo?, savedCredentials: [BotPaymentSavedCredentials], additionalPaymentMethods: [BotPaymentMethod]) {
        self.id = id
        self.canSaveCredentials = canSaveCredentials
        self.passwordMissing = passwordMissing
        self.invoice = invoice
        self.paymentBotId = paymentBotId
        self.providerId = providerId
        self.url = url
        self.nativeProvider = nativeProvider
        self.savedInfo = savedInfo
        self.savedCredentials = savedCredentials
        self.additionalPaymentMethods = additionalPaymentMethods
    }
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
    case alreadyActive
    case noPaymentNeeded
}

extension BotPaymentInvoice {
    init(apiInvoice: Api.Invoice) {
        switch apiInvoice {
        case let .invoice(flags, currency, prices, maxTipAmount, suggestedTipAmounts, termsUrl, subscriptionPeriod):
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
            let isRecurrent = (flags & (1 << 9)) != 0
            var termsInfo: BotPaymentInvoice.RecurrentInfo?
            if let termsUrl = termsUrl {
                termsInfo = BotPaymentInvoice.RecurrentInfo(termsUrl: termsUrl, isRecurrent: isRecurrent)
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
            }, tip: parsedTip, termsInfo: termsInfo, subscriptionPeriod: subscriptionPeriod)
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

func _internal_parseInputInvoice(transaction: Transaction, source: BotPaymentInvoiceSource) -> Api.InputInvoice? {
    switch source {
    case let .message(messageId):
        guard let inputPeer = transaction.getPeer(messageId.peerId).flatMap(apiInputPeer) else {
            return nil
        }
        return .inputInvoiceMessage(peer: inputPeer, msgId: messageId.id)
    case let .slug(slug):
        return .inputInvoiceSlug(slug: slug)
    case let .premiumGiveaway(boostPeerId, additionalPeerIds, countries, onlyNewSubscribers, showWinners, prizeDescription, randomId, untilDate, currency, amount, option):
        guard let peer = transaction.getPeer(boostPeerId), let apiBoostPeer = apiInputPeer(peer) else {
            return nil
        }
        var flags: Int32 = 0
        if onlyNewSubscribers {
            flags |= (1 << 0)
        }
        if showWinners {
            flags |= (1 << 3)
        }
        var additionalPeers: [Api.InputPeer] = []
        if !additionalPeerIds.isEmpty {
            flags |= (1 << 1)
            for peerId in additionalPeerIds {
                if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
                    additionalPeers.append(inputPeer)
                }
            }
        }
        if !countries.isEmpty {
            flags |= (1 << 2)
        }
        if let _ = prizeDescription {
            flags |= (1 << 4)
        }
        
        let inputPurpose: Api.InputStorePaymentPurpose = .inputStorePaymentPremiumGiveaway(flags: flags, boostPeer: apiBoostPeer, additionalPeers: additionalPeers, countriesIso2: countries, prizeDescription: prizeDescription, randomId: randomId, untilDate: untilDate, currency: currency, amount: amount)

        flags = 0
        
        if let _ = option.storeProductId {
            flags |= (1 << 0)
        }
        if option.storeQuantity > 0 {
            flags |= (1 << 1)
        }
        
        let option: Api.PremiumGiftCodeOption = .premiumGiftCodeOption(flags: flags, users: option.users, months: option.months, storeProduct: option.storeProductId, storeQuantity: option.storeQuantity, currency: option.currency, amount: option.amount)
        
        return .inputInvoicePremiumGiftCode(purpose: inputPurpose, option: option)
    case let .giftCode(users, currency, amount, option, text, entities):
        var inputUsers: [Api.InputUser] = []
        if !users.isEmpty {
            for peerId in users {
                if let peer = transaction.getPeer(peerId), let inputPeer = apiInputUser(peer) {
                    inputUsers.append(inputPeer)
                }
            }
        }
        
        var inputPurposeFlags: Int32 = 0
        var message: Api.TextWithEntities?
        if let text, !text.isEmpty {
            inputPurposeFlags |= (1 << 1)
            message = .textWithEntities(text: text, entities: entities.flatMap { apiEntitiesFromMessageTextEntities($0, associatedPeers: SimpleDictionary()) } ?? [])
        }
        
        let inputPurpose: Api.InputStorePaymentPurpose = .inputStorePaymentPremiumGiftCode(flags: inputPurposeFlags, users: inputUsers, boostPeer: nil, currency: currency, amount: amount, message: message)
        
        var flags: Int32 = 0
        if let _ = option.storeProductId {
            flags |= (1 << 0)
        }
        if option.storeQuantity > 0 {
            flags |= (1 << 1)
        }
        
        let option: Api.PremiumGiftCodeOption = .premiumGiftCodeOption(flags: flags, users: option.users, months: option.months, storeProduct: option.storeProductId, storeQuantity: option.storeQuantity, currency: option.currency, amount: option.amount)

        return .inputInvoicePremiumGiftCode(purpose: inputPurpose, option: option)
    case let .stars(option):
        var flags: Int32 = 0
        if let _ = option.storeProductId {
            flags |= (1 << 0)
        }
        return .inputInvoiceStars(purpose: .inputStorePaymentStarsTopup(stars: option.count, currency: option.currency, amount: option.amount))
    case let .starsGift(peerId, count, currency, amount):
        guard let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) else {
            return nil
        }
        return .inputInvoiceStars(purpose: .inputStorePaymentStarsGift(userId: inputUser, stars: count, currency: currency, amount: amount))
    case let .starsChatSubscription(hash):
        return .inputInvoiceChatInviteSubscription(hash: hash)
    case let .starsGiveaway(stars, boostPeerId, additionalPeerIds, countries, onlyNewSubscribers, showWinners, prizeDescription, randomId, untilDate, currency, amount, users):
        guard let peer = transaction.getPeer(boostPeerId), let apiBoostPeer = apiInputPeer(peer) else {
            return nil
        }
        var flags: Int32 = 0
        if onlyNewSubscribers {
            flags |= (1 << 0)
        }
        if showWinners {
            flags |= (1 << 3)
        }
        var additionalPeers: [Api.InputPeer] = []
        if !additionalPeerIds.isEmpty {
            flags |= (1 << 1)
            for peerId in additionalPeerIds {
                if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
                    additionalPeers.append(inputPeer)
                }
            }
        }
        if !countries.isEmpty {
            flags |= (1 << 2)
        }
        if let _ = prizeDescription {
            flags |= (1 << 4)
        }
        return .inputInvoiceStars(purpose: .inputStorePaymentStarsGiveaway(flags: flags, stars: stars, boostPeer: apiBoostPeer, additionalPeers: additionalPeers, countriesIso2: countries, prizeDescription: prizeDescription, randomId: randomId, untilDate: untilDate, currency: currency, amount: amount, users: users))
    case let .starGift(hideName, includeUpgrade, peerId, giftId, text, entities):
        guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
            return nil
        }
        var flags: Int32 = 0
        if hideName {
            flags |= (1 << 0)
        }
        if includeUpgrade {
            flags |= (1 << 2)
        }
        var message: Api.TextWithEntities?
        if let text, !text.isEmpty {
            flags |= (1 << 1)
            message = .textWithEntities(text: text, entities: entities.flatMap { apiEntitiesFromMessageTextEntities($0, associatedPeers: SimpleDictionary()) } ?? [])
        }
        return .inputInvoiceStarGift(flags: flags, peer: inputPeer, giftId: giftId, message: message)
    case let .starGiftUpgrade(keepOriginalInfo, reference):
        var flags: Int32 = 0
        if keepOriginalInfo {
            flags |= (1 << 0)
        }
        return reference.apiStarGiftReference(transaction: transaction).flatMap { .inputInvoiceStarGiftUpgrade(flags: flags, stargift: $0) }
    case let .starGiftTransfer(reference, toPeerId):
        guard let peer = transaction.getPeer(toPeerId), let inputPeer = apiInputPeer(peer) else {
            return nil
        }
        return reference.apiStarGiftReference(transaction: transaction).flatMap { .inputInvoiceStarGiftTransfer(stargift: $0, toId: inputPeer) }
    case let .premiumGift(peerId, option, text, entities):
        guard let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) else {
            return nil
        }
        var flags: Int32 = 0
        var message: Api.TextWithEntities?
        if let text, !text.isEmpty {
            flags |= (1 << 1)
            message = .textWithEntities(text: text, entities: entities.flatMap { apiEntitiesFromMessageTextEntities($0, associatedPeers: SimpleDictionary()) } ?? [])
        }
        return .inputInvoicePremiumGiftStars(flags: flags, userId: inputUser, months: option.months, message: message)
    }
}

func _internal_fetchBotPaymentInvoice(postbox: Postbox, network: Network, source: BotPaymentInvoiceSource) -> Signal<TelegramMediaInvoice, BotPaymentFormRequestError> {
    return postbox.transaction { transaction -> Api.InputInvoice? in
        return _internal_parseInputInvoice(transaction: transaction, source: source)
    }
    |> castError(BotPaymentFormRequestError.self)
    |> mapToSignal { invoice -> Signal<TelegramMediaInvoice, BotPaymentFormRequestError> in
        guard let invoice = invoice else {
            return .fail(.generic)
        }
        
        let flags: Int32 = 0

        return network.request(Api.functions.payments.getPaymentForm(flags: flags, invoice: invoice, themeParams: nil))
        |> `catch` { error -> Signal<Api.payments.PaymentForm, BotPaymentFormRequestError> in
            if error.errorDescription == "SUBSCRIPTION_ALREADY_ACTIVE" {
                return .fail(.alreadyActive)
            } else {
                return .fail(.generic)
            }
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
                    
                    return TelegramMediaInvoice(title: title, description: description, photo: photo.flatMap(TelegramMediaWebFile.init), receiptMessageId: nil, currency: parsedInvoice.currency, totalAmount: 0, startParam: "", extendedMedia: nil, subscriptionPeriod: parsedInvoice.subscriptionPeriod, flags: parsedFlags, version: TelegramMediaInvoice.lastVersion)
                case let .paymentFormStars(_, _, _, title, description, photo, invoice, _):
                    let parsedInvoice = BotPaymentInvoice(apiInvoice: invoice)
                    return TelegramMediaInvoice(title: title, description: description, photo: photo.flatMap(TelegramMediaWebFile.init), receiptMessageId: nil, currency: parsedInvoice.currency, totalAmount: parsedInvoice.prices.reduce(0, { $0 + $1.amount }), startParam: "", extendedMedia: nil, subscriptionPeriod: parsedInvoice.subscriptionPeriod, flags: [], version: TelegramMediaInvoice.lastVersion)
                case let .paymentFormStarGift(_, invoice):
                    let parsedInvoice = BotPaymentInvoice(apiInvoice: invoice)
                    return TelegramMediaInvoice(title: "", description: "", photo: nil, receiptMessageId: nil, currency: parsedInvoice.currency, totalAmount: parsedInvoice.prices.reduce(0, { $0 + $1.amount }), startParam: "", extendedMedia: nil, subscriptionPeriod: parsedInvoice.subscriptionPeriod, flags: [], version: TelegramMediaInvoice.lastVersion)
                }
            }
            |> mapError { _ -> BotPaymentFormRequestError in }
        }
    }
}

func _internal_fetchBotPaymentForm(accountPeerId: PeerId, postbox: Postbox, network: Network, source: BotPaymentInvoiceSource, themeParams: [String: Any]?) -> Signal<BotPaymentForm, BotPaymentFormRequestError> {
    return postbox.transaction { transaction -> Api.InputInvoice? in
        return _internal_parseInputInvoice(transaction: transaction, source: source)
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
        |> `catch` { error -> Signal<Api.payments.PaymentForm, BotPaymentFormRequestError> in
            if error.errorDescription == "NO_PAYMENT_NEEDED" {
                return .fail(.noPaymentNeeded)
            }
            return .fail(.generic)
        }
        |> mapToSignal { result -> Signal<BotPaymentForm, BotPaymentFormRequestError> in
            return postbox.transaction { transaction -> BotPaymentForm in
                switch result {
                case let .paymentForm(flags, id, botId, title, description, photo, invoice, providerId, url, nativeProvider, nativeParams, additionalMethods, savedInfo, savedCredentials, apiUsers):
                    let _ = title
                    let _ = description
                    let _ = photo
                    
                    let parsedPeers = AccumulatedPeers(users: apiUsers)
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)

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
                case let .paymentFormStars(flags, id, botId, title, description, photo, invoice, apiUsers):
                    let _ = flags
                    let _ = title
                    let _ = description
                    let _ = photo
                
                    let parsedPeers = AccumulatedPeers(users: apiUsers)
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                
                    let parsedInvoice = BotPaymentInvoice(apiInvoice: invoice)
                    return BotPaymentForm(id: id, canSaveCredentials: false, passwordMissing: false, invoice: parsedInvoice, paymentBotId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId)), providerId: nil, url: nil, nativeProvider: nil, savedInfo: nil, savedCredentials: [], additionalPaymentMethods: [])
                    
                case let .paymentFormStarGift(id, invoice):
                    let parsedInvoice = BotPaymentInvoice(apiInvoice: invoice)
                    return BotPaymentForm(id: id, canSaveCredentials: false, passwordMissing: false, invoice: parsedInvoice, paymentBotId: nil, providerId: nil, url: nil, nativeProvider: nil, savedInfo: nil, savedCredentials: [], additionalPaymentMethods: [])
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
        return _internal_parseInputInvoice(transaction: transaction, source: source)
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
    case starGiftOutOfStock
}

public enum SendBotPaymentResult {
    case done(receiptMessageId: MessageId?, subscriptionPeerId: PeerId?, uniqueStarGift: ProfileGiftsContext.State.StarGift?)
    case externalVerificationRequired(url: String)
}

func _internal_sendBotPaymentForm(account: Account, formId: Int64, source: BotPaymentInvoiceSource, validatedInfoId: String?, shippingOptionId: String?, tipAmount: Int64?, credentials: BotPaymentCredentials) -> Signal<SendBotPaymentResult, SendBotPaymentFormError> {
    return account.postbox.transaction { transaction -> Api.InputInvoice? in
        return _internal_parseInputInvoice(transaction: transaction, source: source)
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
                
                    switch source {
                    case .starsChatSubscription:
                        let chats = updates.chats.compactMap { parseTelegramGroupOrChannel(chat: $0) }
                        if let first = chats.first {
                            return .done(receiptMessageId: nil, subscriptionPeerId: first.id, uniqueStarGift: nil)
                        }
                    default:
                        break
                    }
                                
                    for apiMessage in updates.messages {
                        if let message = StoreMessage(apiMessage: apiMessage, accountPeerId: account.peerId, peerIsForum: false) {
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
                                        case let .premiumGiveaway(_, _, _, _, _, _, randomId, _, _, _, _):
                                            if message.globallyUniqueId == randomId {
                                                if case let .Id(id) = message.id {
                                                    receiptMessageId = id
                                                }
                                            }
                                        case let .starsGiveaway(_, _, _, _, _, _, _, randomId, _, _, _, _):
                                            if message.globallyUniqueId == randomId {
                                                if case let .Id(id) = message.id {
                                                    receiptMessageId = id
                                                }
                                            }
                                        case .giftCode, .stars, .starsGift, .starsChatSubscription, .starGift, .starGiftUpgrade, .starGiftTransfer, .premiumGift:
                                            receiptMessageId = nil
                                        }
                                    }
                                }
                            }
                        }
                    }
                    return .done(receiptMessageId: receiptMessageId, subscriptionPeerId: nil, uniqueStarGift: nil)
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
    public let date: Int32
    public let info: BotPaymentRequestedInfo?
    public let shippingOption: BotPaymentShippingOption?
    public let credentialsTitle: String
    public let invoiceMedia: TelegramMediaInvoice
    public let tipAmount: Int64?
    public let botPaymentId: PeerId
    public let transactionId: String?
    
    public static func ==(lhs: BotPaymentReceipt, rhs: BotPaymentReceipt) -> Bool {
        if lhs.invoice != rhs.invoice {
            return false
        }
        if lhs.date != rhs.date {
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
        if lhs.transactionId != rhs.transactionId {
            return false
        }
        return true
    }
}

public enum RequestBotPaymentReceiptError {
    case generic
}

func _internal_requestBotPaymentReceipt(account: Account, messageId: MessageId) -> Signal<BotPaymentReceipt, RequestBotPaymentReceiptError> {
    let accountPeerId = account.peerId
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
                case let .paymentReceipt(_, date, botId, _, title, description, photo, invoice, info, shipping, tipAmount, currency, totalAmount, credentialsTitle, users):
                    let parsedPeers = AccumulatedPeers(transaction: transaction, chats: [], users: users)
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)

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
                        subscriptionPeriod: parsedInvoice.subscriptionPeriod,
                        flags: [],
                        version: TelegramMediaInvoice.lastVersion
                    )
                    
                    let botPaymentId = PeerId.init(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId))

                    return BotPaymentReceipt(invoice: parsedInvoice, date: date, info: parsedInfo, shippingOption: shippingOption, credentialsTitle: credentialsTitle, invoiceMedia: invoiceMedia, tipAmount: tipAmount, botPaymentId: botPaymentId, transactionId: nil)
                case let .paymentReceiptStars(_, date, botId, title, description, photo, invoice, currency, totalAmount, transactionId, users):
                    let parsedPeers = AccumulatedPeers(transaction: transaction, chats: [], users: users)
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                    
                    let parsedInvoice = BotPaymentInvoice(apiInvoice: invoice)
                    
                    let invoiceMedia = TelegramMediaInvoice(
                        title: title,
                        description: description,
                        photo: photo.flatMap(TelegramMediaWebFile.init),
                        receiptMessageId: nil,
                        currency: currency,
                        totalAmount: totalAmount,
                        startParam: "",
                        extendedMedia: nil,
                        subscriptionPeriod: parsedInvoice.subscriptionPeriod,
                        flags: [],
                        version: TelegramMediaInvoice.lastVersion
                    )
                    
                    let botPaymentId = PeerId.init(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId))
                    return BotPaymentReceipt(invoice: parsedInvoice, date: date, info: nil, shippingOption: nil, credentialsTitle: "", invoiceMedia: invoiceMedia, tipAmount: nil, botPaymentId: botPaymentId, transactionId: transactionId)
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
