import Foundation
import CoreLocation
import SwiftSignalKit
import StoreKit
import TelegramCore
import Postbox
import TelegramStringFormatting
import TelegramUIPreferences
import PersistentStringHash

private let productIdentifiers = [
    "org.telegram.telegramPremium.annual",
    "org.telegram.telegramPremium.semiannual",
    "org.telegram.telegramPremium.monthly",
    "org.telegram.telegramPremium.twelveMonths",
    "org.telegram.telegramPremium.sixMonths",
    "org.telegram.telegramPremium.threeMonths",

    "org.telegram.telegramPremium.threeMonths.code_x1",
    "org.telegram.telegramPremium.sixMonths.code_x1",
    "org.telegram.telegramPremium.twelveMonths.code_x1",
    
    "org.telegram.telegramPremium.threeMonths.code_x5",
    "org.telegram.telegramPremium.sixMonths.code_x5",
    "org.telegram.telegramPremium.twelveMonths.code_x5",
    
    "org.telegram.telegramPremium.threeMonths.code_x10",
    "org.telegram.telegramPremium.sixMonths.code_x10",
    "org.telegram.telegramPremium.twelveMonths.code_x10",
    
    "org.telegram.telegramStars.topup.x15",
    "org.telegram.telegramStars.topup.x25",
    "org.telegram.telegramStars.topup.x50",
    "org.telegram.telegramStars.topup.x75",
    "org.telegram.telegramStars.topup.x100",
    "org.telegram.telegramStars.topup.x150",
    "org.telegram.telegramStars.topup.x250",
    "org.telegram.telegramStars.topup.x350",
    "org.telegram.telegramStars.topup.x500",
    "org.telegram.telegramStars.topup.x750",
    "org.telegram.telegramStars.topup.x1000",
    "org.telegram.telegramStars.topup.x1500",
    "org.telegram.telegramStars.topup.x2500",
    "org.telegram.telegramStars.topup.x5000",
    "org.telegram.telegramStars.topup.x10000",
    "org.telegram.telegramStars.topup.x25000",
    "org.telegram.telegramStars.topup.x35000"
]

private extension NSDecimalNumber {
    func round(_ decimals: Int) -> NSDecimalNumber {
        return self.rounding(accordingToBehavior:
                            NSDecimalNumberHandler(roundingMode: .down,
                                   scale: Int16(decimals),
                                   raiseOnExactness: false,
                                   raiseOnOverflow: false,
                                   raiseOnUnderflow: false,
                                   raiseOnDivideByZero: false))
    }
    
    func prettyPrice() -> NSDecimalNumber {
        return self.multiplying(by: NSDecimalNumber(value: 2))
            .rounding(accordingToBehavior:
                NSDecimalNumberHandler(
                    roundingMode: .plain,
                    scale: Int16(0),
                    raiseOnExactness: false,
                    raiseOnOverflow: false,
                    raiseOnUnderflow: false,
                    raiseOnDivideByZero: false
                )
            )
            .dividing(by: NSDecimalNumber(value: 2))
            .subtracting(NSDecimalNumber(value: 0.01))
    }
}

public final class InAppPurchaseManager: NSObject {
    public final class Product: Equatable {
        private lazy var numberFormatter: NumberFormatter = {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .currency
            numberFormatter.locale = self.skProduct.priceLocale
            return numberFormatter
        }()
        
        let skProduct: SKProduct
        
        init(skProduct: SKProduct) {
            self.skProduct = skProduct
        }
        
        public var id: String {
            return self.skProduct.productIdentifier
        }
        
        public var isSubscription: Bool {
            if #available(iOS 12.0, *) {
                return self.skProduct.subscriptionGroupIdentifier != nil
            } else {
                return self.skProduct.subscriptionPeriod != nil
            }
        }
        
        public var price: String {
            return self.numberFormatter.string(from: self.skProduct.price) ?? ""
        }
        
        public func pricePerMonth(_ monthsCount: Int) -> String {
            let price = self.skProduct.price.dividing(by: NSDecimalNumber(value: monthsCount)).round(2)
            return self.numberFormatter.string(from: price) ?? ""
        }
        
        public func defaultPrice(_ value: NSDecimalNumber, monthsCount: Int) -> String {
            let price = value.multiplying(by: NSDecimalNumber(value: monthsCount)).round(2)
            let prettierPrice = price
                .multiplying(by: NSDecimalNumber(value: 2))
                .rounding(accordingToBehavior:
                    NSDecimalNumberHandler(
                        roundingMode: .up,
                        scale: Int16(0),
                        raiseOnExactness: false,
                        raiseOnOverflow: false,
                        raiseOnUnderflow: false,
                        raiseOnDivideByZero: false
                    )
                )
                .dividing(by: NSDecimalNumber(value: 2))
                .subtracting(NSDecimalNumber(value: 0.01))
            return self.numberFormatter.string(from: prettierPrice) ?? ""
        }
        
        public func multipliedPrice(count: Int) -> String {
            let price = self.skProduct.price.multiplying(by: NSDecimalNumber(value: count)).round(2)
            let prettierPrice = price
                .multiplying(by: NSDecimalNumber(value: 2))
                .rounding(accordingToBehavior:
                    NSDecimalNumberHandler(
                        roundingMode: .up,
                        scale: Int16(0),
                        raiseOnExactness: false,
                        raiseOnOverflow: false,
                        raiseOnUnderflow: false,
                        raiseOnDivideByZero: false
                    )
                )
                .dividing(by: NSDecimalNumber(value: 2))
                .subtracting(NSDecimalNumber(value: 0.01))
            return self.numberFormatter.string(from: prettierPrice) ?? ""
        }
        
        public var priceValue: NSDecimalNumber {
            return self.skProduct.price
        }
        
        public var priceCurrencyAndAmount: (currency: String, amount: Int64) {
            if let currencyCode = self.numberFormatter.currencyCode,
                let amount = fractionalToCurrencyAmount(value: self.priceValue.doubleValue, currency: currencyCode) {
                return (currencyCode, amount)
            } else {
                return ("", 0)
            }
        }
        
        public static func ==(lhs: Product, rhs: Product) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.isSubscription != rhs.isSubscription {
                return false
            }
            if lhs.priceValue != rhs.priceValue {
                return false
            }
            return true
        }
        
    }
    
    public enum PurchaseState {
        case purchased(transactionId: String)
    }
    
    public enum PurchaseError {
        case generic
        case cancelled
        case network
        case notAllowed
        case cantMakePayments
        case assignFailed
        case tryLater
    }
    
    public enum RestoreState {
        case succeed(Bool)
        case failed
    }
    
    private final class PaymentTransactionContext {
        var state: SKPaymentTransactionState?
        let purpose: PendingInAppPurchaseState.Purpose
        let subscriber: (TransactionState) -> Void
        
        init(purpose: PendingInAppPurchaseState.Purpose, subscriber: @escaping (TransactionState) -> Void) {
            self.purpose = purpose
            self.subscriber = subscriber
        }
    }
    
    private enum TransactionState {
        case purchased(transactionId: String?)
        case restored(transactionId: String?)
        case purchasing
        case failed(error: SKError?)
        case assignFailed
        case deferred
    }
    
    private let engine: TelegramEngine
    
    private var products: [Product] = []
    private var productsPromise = Promise<[Product]>([])
    private var productRequest: SKProductsRequest?
    
    private let stateQueue = Queue()
    private var paymentContexts: [String: PaymentTransactionContext] = [:]
    
    private var finishedSuccessfulTransactions = Set<String>()
        
    private var onRestoreCompletion: ((RestoreState) -> Void)?
    
    private let disposableSet = DisposableDict<String>()
    
    public init(engine: TelegramEngine) {
        self.engine = engine
                
        super.init()
        
        SKPaymentQueue.default().add(self)
        self.requestProducts()
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    var canMakePayments: Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    private func requestProducts() {
        Logger.shared.log("InAppPurchaseManager", "Requesting products")
        let productRequest = SKProductsRequest(productIdentifiers: Set(productIdentifiers))
        productRequest.delegate = self
        productRequest.start()
        
        self.productRequest = productRequest
    }
    
    public var availableProducts: Signal<[Product], NoError> {
        if self.products.isEmpty && self.productRequest == nil {
            self.requestProducts()
        }
        return self.productsPromise.get()
    }
    
    public func restorePurchases(completion: @escaping (RestoreState) -> Void) {
        Logger.shared.log("InAppPurchaseManager", "Restoring purchases")
        self.onRestoreCompletion = completion
        
        let paymentQueue = SKPaymentQueue.default()
        paymentQueue.restoreCompletedTransactions()
    }
    
    public func finishAllTransactions() {
        Logger.shared.log("InAppPurchaseManager", "Finishing all transactions")
        
        let paymentQueue = SKPaymentQueue.default()
        let transactions = paymentQueue.transactions
        for transaction in transactions {
            paymentQueue.finishTransaction(transaction)
        }
    }
    
    public func buyProduct(_ product: Product, quantity: Int32 = 1, purpose: AppStoreTransactionPurpose) -> Signal<PurchaseState, PurchaseError> {
        if !self.canMakePayments {
            return .fail(.cantMakePayments)
        }
                
        let accountPeerId = "\(self.engine.account.peerId.toInt64())"
        
        Logger.shared.log("InAppPurchaseManager", "Buying: account \(accountPeerId), product \(product.skProduct.productIdentifier), price \(product.price)")
        
        let purpose = PendingInAppPurchaseState.Purpose(appStorePurpose: purpose)
        
        let payment = SKMutablePayment(product: product.skProduct)
        payment.applicationUsername = accountPeerId
        payment.quantity = Int(quantity)
        SKPaymentQueue.default().add(payment)
        
        let productIdentifier = payment.productIdentifier
        let signal = Signal<PurchaseState, PurchaseError> { subscriber in
            let disposable = MetaDisposable()
            
            self.stateQueue.async {
                let paymentContext = PaymentTransactionContext(purpose: purpose, subscriber: { state in
                    switch state {
                        case let .purchased(transactionId), let .restored(transactionId):
                            if let transactionId = transactionId {
                                subscriber.putNext(.purchased(transactionId: transactionId))
                                subscriber.putCompletion()
                            } else {
                                subscriber.putError(.generic)
                            }
                        case let .failed(error):
                            if let error = error {
                                let mappedError: PurchaseError
                                switch error.code {
                                    case .paymentCancelled:
                                        mappedError = .cancelled
                                    case .cloudServiceNetworkConnectionFailed, .cloudServicePermissionDenied:
                                        mappedError = .network
                                    case .paymentNotAllowed, .clientInvalid:
                                        mappedError = .notAllowed
                                    case .unknown:
                                        if let _ = error.userInfo["tryLater"] {
                                            mappedError = .tryLater
                                        } else {
                                            mappedError = .generic
                                        }
                                    default:
                                        mappedError = .generic
                                }
                                subscriber.putError(mappedError)
                            } else {
                                subscriber.putError(.generic)
                            }
                        case .assignFailed:
                            subscriber.putError(.assignFailed)
                        case .deferred, .purchasing:
                            break
                    }
                })
                self.paymentContexts[productIdentifier] = paymentContext
                
                disposable.set(ActionDisposable { [weak paymentContext] in
                    self.stateQueue.async {
                        if let current = self.paymentContexts[productIdentifier], current === paymentContext {
                            self.paymentContexts.removeValue(forKey: productIdentifier)
                        }
                    }
                })
            }
            
            return disposable
        }
        return signal
    }
    
    public struct ReceiptPurchase: Equatable {
        public let productId: String
        public let transactionId: String
        public let expirationDate: Date
    }
    
    public func getReceiptPurchases() -> [ReceiptPurchase] {
        guard let data = getReceiptData(), let receipt = parseReceipt(data) else {
            return []
        }
        return receipt.purchases.map { ReceiptPurchase(productId: $0.productId, transactionId: $0.transactionId, expirationDate: $0.expirationDate) }
    }
}

extension InAppPurchaseManager: SKProductsRequestDelegate {
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        self.productRequest = nil
        
        Queue.mainQueue().async {
            let products = response.products.map { Product(skProduct: $0) }
             
            Logger.shared.log("InAppPurchaseManager", "Received products \(products.map({ $0.skProduct.productIdentifier }).joined(separator: ", "))")
            self.productsPromise.set(.single(products))
        }
    }
}

private func getReceiptData() -> Data? {
    var receiptData: Data?
    if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {
        do {
            receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
        } catch {
            Logger.shared.log("InAppPurchaseManager", "Couldn't read receipt data with error: \(error.localizedDescription)")
        }
    }
    return receiptData
}

extension InAppPurchaseManager: SKPaymentTransactionObserver {
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        self.stateQueue.async {
            let accountPeerId = "\(self.engine.account.peerId.toInt64())"
            
            let paymentContexts = self.paymentContexts
            
            var transactionsToAssign: [SKPaymentTransaction] = []
            for transaction in transactions {
                if let applicationUsername = transaction.payment.applicationUsername, applicationUsername != accountPeerId {
                    continue
                }
                
                let productIdentifier = transaction.payment.productIdentifier
                let transactionState: TransactionState?
                switch transaction.transactionState {
                    case .purchased:
                        if transaction.payment.productIdentifier.contains(".topup."), let transactionIdentifier = transaction.transactionIdentifier, self.finishedSuccessfulTransactions.contains(transactionIdentifier) {
                            Logger.shared.log("InAppPurchaseManager", "Account \(accountPeerId), transaction \(transaction.transactionIdentifier ?? ""), original transaction \(transaction.original?.transactionIdentifier ?? "none") seems to be already reported, ask to try later")
                            transactionState = .failed(error: SKError(SKError.Code.unknown, userInfo: ["tryLater": true]))
                            queue.finishTransaction(transaction)
                        } else {
                            Logger.shared.log("InAppPurchaseManager", "Account \(accountPeerId), transaction \(transaction.transactionIdentifier ?? ""), original transaction \(transaction.original?.transactionIdentifier ?? "none") purchased")
                            transactionState = .purchased(transactionId: transaction.transactionIdentifier)
                            transactionsToAssign.append(transaction)
                        }
                    case .restored:
                        Logger.shared.log("InAppPurchaseManager", "Account \(accountPeerId), transaction \(transaction.transactionIdentifier ?? ""), original transaction \(transaction.original?.transactionIdentifier ?? "") restroring")
                        let transactionIdentifier = transaction.transactionIdentifier
                        transactionState = .restored(transactionId: transactionIdentifier)
                    case .failed:
                        Logger.shared.log("InAppPurchaseManager", "Account \(accountPeerId), transaction \(transaction.transactionIdentifier ?? "") failed \((transaction.error as? SKError)?.localizedDescription ?? "")")
                        transactionState = .failed(error: transaction.error as? SKError)
                        queue.finishTransaction(transaction)
                    case .purchasing:
                        Logger.shared.log("InAppPurchaseManager", "Account \(accountPeerId), transaction \(transaction.transactionIdentifier ?? "") purchasing")
                        transactionState = .purchasing
                        if let paymentContext = self.paymentContexts[transaction.payment.productIdentifier] {
                            let _ = updatePendingInAppPurchaseState(
                                engine: self.engine,
                                productId: transaction.payment.productIdentifier,
                                content: PendingInAppPurchaseState(
                                    productId: transaction.payment.productIdentifier,
                                    purpose: paymentContext.purpose
                                )
                            ).start()
                        }
                    case .deferred:
                        Logger.shared.log("InAppPurchaseManager", "Account \(accountPeerId), transaction \(transaction.transactionIdentifier ?? "") deferred")
                        transactionState = .deferred
                    default:
                        transactionState = nil
                }
                if let transactionState = transactionState {
                    if let context = self.paymentContexts[productIdentifier] {
                        context.subscriber(transactionState)
                    }
                }
            }
            
            if !transactionsToAssign.isEmpty {
                let transactionIds = transactionsToAssign.compactMap({ $0.transactionIdentifier }).joined(separator: ", ")
                Logger.shared.log("InAppPurchaseManager", "Account \(accountPeerId), sending receipt for transactions [\(transactionIds)]")
                
                guard let transaction = transactionsToAssign.first else {
                    return
                }
                let productIdentifier = transaction.payment.productIdentifier
                
                var completion: Signal<Never, NoError> = .never()
                
                let products = self.availableProducts
                |> filter { products in
                    return !products.isEmpty
                }
                |> take(1)
                
                let product: Signal<InAppPurchaseManager.Product?, NoError> = products
                |> map { products in
                    if let product = products.first(where: { $0.id == productIdentifier }) {
                        return product
                    } else {
                        return nil
                    }
                }
                
                let purpose: Signal<AppStoreTransactionPurpose, NoError>
                if let paymentContext = paymentContexts[productIdentifier] {
                    purpose = product
                    |> map { product in
                        return paymentContext.purpose.appStorePurpose(product: product)
                    }
                } else {
                    purpose = combineLatest(
                        product,
                        pendingInAppPurchaseState(engine: self.engine, productId: productIdentifier)
                    )
                    |> mapToSignal { product, state -> Signal<AppStoreTransactionPurpose, NoError> in
                        if let state {
                            return .single(state.purpose.appStorePurpose(product: product))
                        } else {
                            return .complete()
                        }
                    }
                }
                
                completion = updatePendingInAppPurchaseState(engine: self.engine, productId: productIdentifier, content: nil)
                
                let receiptData = getReceiptData() ?? Data()
#if DEBUG
                self.debugSaveReceipt(receiptData: receiptData)
#endif
                
                for transaction in transactionsToAssign {
                    if let transactionIdentifier = transaction.transactionIdentifier {
                        self.finishedSuccessfulTransactions.insert(transactionIdentifier)
                    }
                }
                
                self.disposableSet.set(
                    (purpose
                    |> castError(AssignAppStoreTransactionError.self)
                    |> mapToSignal { purpose -> Signal<Never, AssignAppStoreTransactionError> in
                        return self.engine.payments.sendAppStoreReceipt(receipt: receiptData, purpose: purpose)
                    }).start(error: { [weak self] _ in
                        Logger.shared.log("InAppPurchaseManager", "Account \(accountPeerId), transactions [\(transactionIds)] failed to assign")
                        for transaction in transactions {
                            self?.stateQueue.async {
                                if let strongSelf = self, let context = strongSelf.paymentContexts[transaction.payment.productIdentifier] {
                                    context.subscriber(.assignFailed)
                                }
                            }
                            queue.finishTransaction(transaction)
                        }
                    }, completed: {
                        Logger.shared.log("InAppPurchaseManager", "Account \(accountPeerId), transactions [\(transactionIds)] successfully assigned")
                        for transaction in transactions {
                            queue.finishTransaction(transaction)
                        }
                        
                        let _ = completion.start()
                    }),
                    forKey: transactionIds
                )
            }
        }
    }
    
    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        Queue.mainQueue().async {
            if let onRestoreCompletion = self.onRestoreCompletion {
                Logger.shared.log("InAppPurchaseManager", "Transactions restoration finished")
                self.onRestoreCompletion = nil
                
                if let receiptData = getReceiptData() {
                    self.disposableSet.set(
                        self.engine.payments.sendAppStoreReceipt(receipt: receiptData, purpose: .restore).start(error: { error in
                            Queue.mainQueue().async {
                                if case .serverProvided = error {
                                    onRestoreCompletion(.succeed(true))
                                } else {
                                    onRestoreCompletion(.succeed(false))
                                }
                            }
                        }, completed: {
                            Queue.mainQueue().async {
                                onRestoreCompletion(.succeed(false))
                            }
                            Logger.shared.log("InAppPurchaseManager", "Sent restored receipt")
                        }),
                        forKey: "restore"
                    )
                } else {
                    onRestoreCompletion(.succeed(false))
                }
            }
        }
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        Queue.mainQueue().async {
            if let onRestoreCompletion = self.onRestoreCompletion {
                Logger.shared.log("InAppPurchaseManager", "Transactions restoration failed with error \((error as? SKError)?.localizedDescription ?? "")")
                onRestoreCompletion(.failed)
                self.onRestoreCompletion = nil
            }
        }
    }
    
    private func debugSaveReceipt(receiptData: Data) {
        let id = Int64.random(in: Int64.min ... Int64.max)
        let fileResource = LocalFileMediaResource(fileId: id, size: Int64(receiptData.count), isSecretRelated: false)
        self.engine.account.postbox.mediaBox.storeResourceData(fileResource.id, data: receiptData)

        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(receiptData.count), attributes: [.FileName(fileName: "Receipt.dat")], alternativeRepresentations: [])
        let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

        let _ = enqueueMessages(account: self.engine.account, peerId: self.engine.account.peerId, messages: [message]).start()
    }
}

private final class PendingInAppPurchaseState: Codable {
    enum CodingKeys: String, CodingKey {
        case productId
        case purpose
        case storeProductId
    }
    
    enum Purpose: Codable {
        enum DecodingError: Error {
            case generic
        }
        
        enum CodingKeys: String, CodingKey {
            case type
            case peer
            case peers
            case boostPeer
            case additionalPeerIds
            case countries
            case onlyNewSubscribers
            case showWinners
            case prizeDescription
            case randomId
            case untilDate
            case stars
            case users
        }
        
        enum PurposeType: Int32 {
            case subscription
            case upgrade
            case restore
            case gift
            case giftCode
            case giveaway
            case stars
            case starsGift
            case starsGiveaway
        }
        
        case subscription
        case upgrade
        case restore
        case gift(peerId: EnginePeer.Id)
        case giftCode(peerIds: [EnginePeer.Id], boostPeer: EnginePeer.Id?)
        case giveaway(boostPeer: EnginePeer.Id, additionalPeerIds: [EnginePeer.Id], countries: [String], onlyNewSubscribers: Bool, showWinners: Bool, prizeDescription: String?, randomId: Int64, untilDate: Int32)
        case stars(count: Int64)
        case starsGift(peerId: EnginePeer.Id, count: Int64)
        case starsGiveaway(stars: Int64, boostPeer: EnginePeer.Id, additionalPeerIds: [EnginePeer.Id], countries: [String], onlyNewSubscribers: Bool, showWinners: Bool, prizeDescription: String?, randomId: Int64, untilDate: Int32, users: Int32)
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let type = PurposeType(rawValue: try container.decode(Int32.self, forKey: .type))
            switch type {
            case .subscription:
                self = .subscription
            case .upgrade:
                self = .upgrade
            case .restore:
                self = .restore
            case .gift:
                self = .gift(
                    peerId: EnginePeer.Id(try container.decode(Int64.self, forKey: .peer))
                )
            case .giftCode:
                self = .giftCode(
                    peerIds: try container.decode([Int64].self, forKey: .peers).map { EnginePeer.Id($0) },
                    boostPeer: try container.decodeIfPresent(Int64.self, forKey: .boostPeer).flatMap({ EnginePeer.Id($0) })
                )
            case .giveaway:
                self = .giveaway(
                    boostPeer: EnginePeer.Id(try container.decode(Int64.self, forKey: .boostPeer)),
                    additionalPeerIds: try container.decode([Int64].self, forKey: .randomId).map { EnginePeer.Id($0) },
                    countries: try container.decodeIfPresent([String].self, forKey: .countries) ?? [],
                    onlyNewSubscribers: try container.decode(Bool.self, forKey: .onlyNewSubscribers),
                    showWinners: try container.decodeIfPresent(Bool.self, forKey: .showWinners) ?? false,
                    prizeDescription: try container.decodeIfPresent(String.self, forKey: .prizeDescription),
                    randomId: try container.decode(Int64.self, forKey: .randomId),
                    untilDate: try container.decode(Int32.self, forKey: .untilDate)
                )
            case .stars:
                self = .stars(
                    count: try container.decode(Int64.self, forKey: .stars)
                )
            case .starsGift:
                self = .starsGift(
                    peerId: EnginePeer.Id(try container.decode(Int64.self, forKey: .peer)),
                    count: try container.decode(Int64.self, forKey: .stars)
                )
            case .starsGiveaway:
                self = .starsGiveaway(
                    stars: try container.decode(Int64.self, forKey: .stars),
                    boostPeer: EnginePeer.Id(try container.decode(Int64.self, forKey: .boostPeer)),
                    additionalPeerIds: try container.decode([Int64].self, forKey: .randomId).map { EnginePeer.Id($0) },
                    countries: try container.decodeIfPresent([String].self, forKey: .countries) ?? [],
                    onlyNewSubscribers: try container.decode(Bool.self, forKey: .onlyNewSubscribers),
                    showWinners: try container.decodeIfPresent(Bool.self, forKey: .showWinners) ?? false,
                    prizeDescription: try container.decodeIfPresent(String.self, forKey: .prizeDescription),
                    randomId: try container.decode(Int64.self, forKey: .randomId),
                    untilDate: try container.decode(Int32.self, forKey: .untilDate),
                    users: try container.decode(Int32.self, forKey: .users)
                )
            default:
                throw DecodingError.generic
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .subscription:
                try container.encode(PurposeType.subscription.rawValue, forKey: .type)
            case .upgrade:
                try container.encode(PurposeType.upgrade.rawValue, forKey: .type)
            case .restore:
                try container.encode(PurposeType.restore.rawValue, forKey: .type)
            case let .gift(peerId):
                try container.encode(PurposeType.gift.rawValue, forKey: .type)
                try container.encode(peerId.toInt64(), forKey: .peer)
            case let .giftCode(peerIds, boostPeer):
                try container.encode(PurposeType.giftCode.rawValue, forKey: .type)
                try container.encode(peerIds.map { $0.toInt64() }, forKey: .peers)
                try container.encodeIfPresent(boostPeer?.toInt64(), forKey: .boostPeer)
            case let .giveaway(boostPeer, additionalPeerIds, countries, onlyNewSubscribers, showWinners, prizeDescription, randomId, untilDate):
                try container.encode(PurposeType.giveaway.rawValue, forKey: .type)
                try container.encode(boostPeer.toInt64(), forKey: .boostPeer)
                try container.encode(additionalPeerIds.map { $0.toInt64() }, forKey: .additionalPeerIds)
                try container.encode(countries, forKey: .countries)
                try container.encode(onlyNewSubscribers, forKey: .onlyNewSubscribers)
                try container.encode(showWinners, forKey: .showWinners)
                try container.encodeIfPresent(prizeDescription, forKey: .prizeDescription)
                try container.encode(randomId, forKey: .randomId)
                try container.encode(untilDate, forKey: .untilDate)
            case let .stars(count):
                try container.encode(PurposeType.stars.rawValue, forKey: .type)
                try container.encode(count, forKey: .stars)
            case let .starsGift(peerId, count):
                try container.encode(PurposeType.starsGift.rawValue, forKey: .type)
                try container.encode(peerId.toInt64(), forKey: .peer)
                try container.encode(count, forKey: .stars)
            case let .starsGiveaway(stars, boostPeer, additionalPeerIds, countries, onlyNewSubscribers, showWinners, prizeDescription, randomId, untilDate, users):
                try container.encode(PurposeType.starsGiveaway.rawValue, forKey: .type)
                try container.encode(stars, forKey: .stars)
                try container.encode(boostPeer.toInt64(), forKey: .boostPeer)
                try container.encode(additionalPeerIds.map { $0.toInt64() }, forKey: .additionalPeerIds)
                try container.encode(countries, forKey: .countries)
                try container.encode(onlyNewSubscribers, forKey: .onlyNewSubscribers)
                try container.encode(showWinners, forKey: .showWinners)
                try container.encodeIfPresent(prizeDescription, forKey: .prizeDescription)
                try container.encode(randomId, forKey: .randomId)
                try container.encode(untilDate, forKey: .untilDate)
                try container.encode(users, forKey: .users)
            }
        }
        
        init(appStorePurpose: AppStoreTransactionPurpose) {
            switch appStorePurpose {
            case .subscription:
                self = .subscription
            case .upgrade:
                self = .upgrade
            case .restore:
                self = .restore
            case let .gift(peerId, _, _):
                self = .gift(peerId: peerId)
            case let .giftCode(peerIds, boostPeer, _, _):
                self = .giftCode(peerIds: peerIds, boostPeer: boostPeer)
            case let .giveaway(boostPeer, additionalPeerIds, countries, onlyNewSubscribers, showWinners, prizeDescription, randomId, untilDate, _, _):
                self = .giveaway(boostPeer: boostPeer, additionalPeerIds: additionalPeerIds, countries: countries, onlyNewSubscribers: onlyNewSubscribers, showWinners: showWinners, prizeDescription: prizeDescription, randomId: randomId, untilDate: untilDate)
            case let .stars(count, _, _):
                self = .stars(count: count)
            case let .starsGift(peerId, count, _, _):
                self = .starsGift(peerId: peerId, count: count)
            case let .starsGiveaway(stars, boostPeer, additionalPeerIds, countries, onlyNewSubscribers, showWinners, prizeDescription, randomId, untilDate, _, _, users):
                self = .starsGiveaway(stars: stars, boostPeer: boostPeer, additionalPeerIds: additionalPeerIds, countries: countries, onlyNewSubscribers: onlyNewSubscribers, showWinners: showWinners, prizeDescription: prizeDescription, randomId: randomId, untilDate: untilDate, users: users)
            }
        }
        
        func appStorePurpose(product: InAppPurchaseManager.Product?) -> AppStoreTransactionPurpose {
            let (currency, amount) = product?.priceCurrencyAndAmount ?? ("", 0)
            switch self {
            case .subscription:
                return .subscription
            case .upgrade:
                return .upgrade
            case .restore:
                return .restore
            case let .gift(peerId):
                return .gift(peerId: peerId, currency: currency, amount: amount)
            case let .giftCode(peerIds, boostPeer):
                return .giftCode(peerIds: peerIds, boostPeer: boostPeer, currency: currency, amount: amount)
            case let .giveaway(boostPeer, additionalPeerIds, countries, onlyNewSubscribers, showWinners, prizeDescription, randomId, untilDate):
                return .giveaway(boostPeer: boostPeer, additionalPeerIds: additionalPeerIds, countries: countries, onlyNewSubscribers: onlyNewSubscribers, showWinners: showWinners, prizeDescription: prizeDescription, randomId: randomId, untilDate: untilDate, currency: currency, amount: amount)
            case let .stars(count):
                return .stars(count: count, currency: currency, amount: amount)
            case let .starsGift(peerId, count):
                return .starsGift(peerId: peerId, count: count, currency: currency, amount: amount)
            case let .starsGiveaway(stars, boostPeer, additionalPeerIds, countries, onlyNewSubscribers, showWinners, prizeDescription, randomId, untilDate, users):
                return .starsGiveaway(stars: stars, boostPeer: boostPeer, additionalPeerIds: additionalPeerIds, countries: countries, onlyNewSubscribers: onlyNewSubscribers, showWinners: showWinners, prizeDescription: prizeDescription, randomId: randomId, untilDate: untilDate, currency: currency, amount: amount, users: users)
            }
        }
    }
    
    public let productId: String
    public let purpose: Purpose
        
    public init(productId: String, purpose: Purpose) {
        self.productId = productId
        self.purpose = purpose
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.productId = try container.decode(String.self, forKey: .productId)
        self.purpose = try container.decode(Purpose.self, forKey: .purpose)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.productId, forKey: .productId)
        try container.encode(self.purpose, forKey: .purpose)
    }
}

private func pendingInAppPurchaseState(engine: TelegramEngine, productId: String) -> Signal<PendingInAppPurchaseState?, NoError> {
    let key = EngineDataBuffer(length: 8)
    key.setInt64(0, value: Int64(bitPattern: productId.persistentHashValue))
    
    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.pendingInAppPurchaseState, id: key))
    |> map { entry -> PendingInAppPurchaseState? in
        return entry?.get(PendingInAppPurchaseState.self)
    }
}

private func updatePendingInAppPurchaseState(engine: TelegramEngine, productId: String, content: PendingInAppPurchaseState?) -> Signal<Never, NoError> {
    let key = EngineDataBuffer(length: 8)
    key.setInt64(0, value: Int64(bitPattern: productId.persistentHashValue))
    
    if let content = content {
        return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.pendingInAppPurchaseState, id: key, item: content)
    } else {
        return engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.pendingInAppPurchaseState, id: key)
    }
}
