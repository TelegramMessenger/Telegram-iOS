import Foundation
import CoreLocation
import SwiftSignalKit
import StoreKit
import Postbox
import TelegramCore
import TelegramStringFormatting
import TelegramUIPreferences
import PersistentStringHash

private let productIdentifiers = [
    "org.telegram.telegramPremium.annual",
    "org.telegram.telegramPremium.semiannual",
    "org.telegram.telegramPremium.monthly",
    "org.telegram.telegramPremium.twelveMonths",
    "org.telegram.telegramPremium.sixMonths",
    "org.telegram.telegramPremium.threeMonths"
]

private func isSubscriptionProductId(_ id: String) -> Bool {
    return id.hasSuffix(".monthly") || id.hasSuffix(".annual") || id.hasSuffix(".semiannual")
}

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
            } else if #available(iOS 11.2, *) {
                return self.skProduct.subscriptionPeriod != nil
            } else {
                return self.id.hasSuffix(".monthly") || self.id.hasSuffix(".annual") || self.id.hasSuffix(".semiannual")
            }
        }
        
        public var price: String {
            return self.numberFormatter.string(from: self.skProduct.price) ?? ""
        }
        
        public func pricePerMonth(_ monthsCount: Int) -> String {
            let price = self.skProduct.price.dividing(by: NSDecimalNumber(value: monthsCount)).prettyPrice().round(2)
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
    }
    
    public enum RestoreState {
        case succeed(Bool)
        case failed
    }
    
    private final class PaymentTransactionContext {
        var state: SKPaymentTransactionState?
        var targetPeerId: PeerId?
        let subscriber: (TransactionState) -> Void
        
        init(targetPeerId: PeerId?, subscriber: @escaping (TransactionState) -> Void) {
            self.targetPeerId = targetPeerId
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
    
    public func buyProduct(_ product: Product, targetPeerId: PeerId? = nil) -> Signal<PurchaseState, PurchaseError> {
        if !self.canMakePayments {
            return .fail(.cantMakePayments)
        }
        
        if !product.isSubscription && targetPeerId == nil {
            return .fail(.cantMakePayments)
        }
        
        let accountPeerId = "\(self.engine.account.peerId.toInt64())"
        
        Logger.shared.log("InAppPurchaseManager", "Buying: account \(accountPeerId), product \(product.skProduct.productIdentifier), price \(product.price)")
        
        let payment = SKMutablePayment(product: product.skProduct)
        payment.applicationUsername = accountPeerId
        SKPaymentQueue.default().add(payment)
        
        let productIdentifier = payment.productIdentifier
        let signal = Signal<PurchaseState, PurchaseError> { subscriber in
            let disposable = MetaDisposable()
            
            self.stateQueue.async {
                let paymentContext = PaymentTransactionContext(targetPeerId: targetPeerId, subscriber: { state in
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
                        Logger.shared.log("InAppPurchaseManager", "Account \(accountPeerId), transaction \(transaction.transactionIdentifier ?? ""), original transaction \(transaction.original?.transactionIdentifier ?? "none") purchased")
                    
                        transactionState = .purchased(transactionId: transaction.transactionIdentifier)
                        transactionsToAssign.append(transaction)
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
                                    targetPeerId: paymentContext.targetPeerId
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
                
                let purpose: Signal<AppStoreTransactionPurpose, NoError>
                if !isSubscriptionProductId(productIdentifier) {
                    let peerId: Signal<PeerId, NoError>
                    if let targetPeerId = paymentContexts[productIdentifier]?.targetPeerId {
                        peerId = .single(targetPeerId)
                    } else {
                        peerId = pendingInAppPurchaseState(engine: self.engine, productId: productIdentifier)
                        |> mapToSignal { state -> Signal<PeerId, NoError> in
                            if let state = state, let peerId = state.targetPeerId {
                                return .single(peerId)
                            } else {
                                return .complete()
                            }
                        }
                    }
                    completion = updatePendingInAppPurchaseState(engine: self.engine, productId: productIdentifier, content: nil)
                    
                    let products = self.availableProducts
                    |> filter { products in
                        return !products.isEmpty
                    }
                    |> take(1)
                    
                    purpose = combineLatest(products, peerId)
                    |> map { products, peerId -> AppStoreTransactionPurpose in
                        if let product = products.first(where: { $0.id == productIdentifier }) {
                            let (currency, amount) = product.priceCurrencyAndAmount
                            return .gift(peerId: peerId, currency: currency, amount: amount)
                        } else {
                            return .gift(peerId: peerId, currency: "", amount: 0)
                        }
                    }
                } else {
                    purpose = .single(.subscription)
                }
            
                let receiptData = getReceiptData() ?? Data()
                self.disposableSet.set(
                    (purpose
                    |> castError(AssignAppStoreTransactionError.self)
                    |> mapToSignal { purpose -> Signal<Never, AssignAppStoreTransactionError> in
                        self.engine.payments.sendAppStoreReceipt(receipt: receiptData, purpose: purpose)
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
}

private final class PendingInAppPurchaseState: Codable {
    public let productId: String
    public let targetPeerId: PeerId?
        
    public init(productId: String, targetPeerId: PeerId?) {
        self.productId = productId
        self.targetPeerId = targetPeerId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.productId = try container.decode(String.self, forKey: "productId")
        self.targetPeerId = (try container.decodeIfPresent(Int64.self, forKey: "targetPeerId")).flatMap { PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value($0)) }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.productId, forKey: "productId")
        if let targetPeerId = self.targetPeerId {
            try container.encode(targetPeerId.id._internalGetInt64Value(), forKey: "targetPeerId")
        }
    }
}

private func pendingInAppPurchaseState(engine: TelegramEngine, productId: String) -> Signal<PendingInAppPurchaseState?, NoError> {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: Int64(bitPattern: productId.persistentHashValue))
    
    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.pendingInAppPurchaseState, id: key))
    |> map { entry -> PendingInAppPurchaseState? in
        return entry?.get(PendingInAppPurchaseState.self)
    }
}

private func updatePendingInAppPurchaseState(engine: TelegramEngine, productId: String, content: PendingInAppPurchaseState?) -> Signal<Never, NoError> {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: Int64(bitPattern: productId.persistentHashValue))
    
    if let content = content {
        return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.pendingInAppPurchaseState, id: key, item: content)
    } else {
        return engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.pendingInAppPurchaseState, id: key)
    }
}
