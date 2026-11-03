import Foundation
import CoreLocation
import SwiftSignalKit
import StoreKit
import TelegramCore
import TelegramStringFormatting
import TelegramUIPreferences
import PersistentStringHash

private let subscriptionProductIdentifiers = [
    "org.telegram.telegramPremium.annual",
    "org.telegram.telegramPremium.semiannual",
    "org.telegram.telegramPremium.monthly"
]

private let productIdentifiers = subscriptionProductIdentifiers + [
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
    
    "org.telegram.telegramPremium.oneWeek.auth",
    "org.telegram.telegramPremium.threeDays.auth",
    
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
        case waiting
        case pending
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
        var state: TransactionState?
        let purpose: PendingInAppPurchaseState.Purpose
        let isSubscription: Bool
        let subscribers = Bag<(TransactionState) -> Void>()
        let preparationDisposable = MetaDisposable()
        
        init(purpose: PendingInAppPurchaseState.Purpose, isSubscription: Bool) {
            self.purpose = purpose
            self.isSubscription = isSubscription
        }

        deinit {
            self.preparationDisposable.dispose()
        }

        func updateState(_ state: TransactionState) {
            self.state = state
            for subscriber in self.subscribers.copyItems() {
                subscriber(state)
            }
        }
    }
    
    private enum TransactionState {
        case purchased(transactionId: String?)
        case restored(transactionId: String?)
        case purchasing
        case failed(error: SKError?)
        case assignFailed
        case deferred

        var isTerminal: Bool {
            switch self {
            case .purchased, .restored, .failed, .assignFailed:
                return true
            case .purchasing, .deferred:
                return false
            }
        }
    }
    
    private let engine: SomeTelegramEngine
    
    private var products: [Product] = []
    private var productsPromise = Promise<[Product]>([])
    private var productRequest: SKProductsRequest?
    private var productRequestTimeoutTimer: SwiftSignalKit.Timer?
    private var productRequestRetryTimer: SwiftSignalKit.Timer?
    
    private let stateQueue = Queue()
    private var paymentContexts: [String: PaymentTransactionContext] = [:]
    
    private var finishedSuccessfulTransactions = Set<String>()
        
    private var onRestoreCompletion: ((RestoreState) -> Void)?
    
    private let disposableSet = DisposableDict<String>()
    
    public init(engine: SomeTelegramEngine) {
        self.engine = engine
                
        super.init()
        
        SKPaymentQueue.default().add(self)
        self.requestProducts()
    }
    
    deinit {
        self.productRequestTimeoutTimer?.invalidate()
        self.productRequestRetryTimer?.invalidate()
        self.productRequest?.cancel()
        SKPaymentQueue.default().remove(self)
    }
    
    var canMakePayments: Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    private func requestProducts() {
        Queue.mainQueue().async { [weak self] in
            guard let self, self.products.isEmpty, self.productRequest == nil, self.productRequestRetryTimer == nil else {
                return
            }
            Logger.shared.log("InAppPurchaseManager", "Requesting products")
            let productRequest = SKProductsRequest(productIdentifiers: Set(productIdentifiers))
            productRequest.delegate = self
            self.productRequest = productRequest

            let timeoutTimer = SwiftSignalKit.Timer(timeout: 30.0, repeat: false, completion: { [weak self, weak productRequest] in
                guard let self, let productRequest, self.productRequest === productRequest else {
                    return
                }
                Logger.shared.log("InAppPurchaseManager", "Product request timed out")
                self.productRequest = nil
                self.productRequestTimeoutTimer = nil
                productRequest.cancel()
                self.scheduleProductRequestRetry()
            }, queue: Queue.mainQueue())
            self.productRequestTimeoutTimer = timeoutTimer
            timeoutTimer.start()
            productRequest.start()
        }
    }

    private func scheduleProductRequestRetry() {
        guard self.products.isEmpty, self.productRequest == nil, self.productRequestRetryTimer == nil else {
            return
        }
        Logger.shared.log("InAppPurchaseManager", "Retrying product request in 10 seconds")
        let retryTimer = SwiftSignalKit.Timer(timeout: 10.0, repeat: false, completion: { [weak self] in
            guard let self else {
                return
            }
            self.productRequestRetryTimer = nil
            self.requestProducts()
        }, queue: Queue.mainQueue())
        self.productRequestRetryTimer = retryTimer
        retryTimer.start()
    }
    
    public var availableProducts: Signal<[Product], NoError> {
        self.requestProducts()
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
    
    public func buyProduct(_ product: Product, quantity: Int32 = 1, purpose: AppStoreTransactionPurpose, reportPending: Bool = false) -> Signal<PurchaseState, PurchaseError> {
        let accountPeerId: String
        switch self.engine {
        case let .authorized(engine):
            accountPeerId = "\(engine.account.peerId.toInt64())"
        case let .unauthorized(engine):
            accountPeerId = "\(engine.account.id.int64)"
        }
        let purpose = PendingInAppPurchaseState.Purpose(appStorePurpose: purpose)

        return Signal { subscriber in
            let disposables = DisposableSet()
            let disposed = Atomic(value: false)
            disposables.add(ActionDisposable {
                let _ = disposed.swap(true)
            })

            self.stateQueue.async {
                guard !disposed.with({ $0 }) else {
                    return
                }

                var didReportWaiting = false
                var didReportPending = false
                let reportWaitingOnce: () -> Void = {
                    if reportPending && !didReportWaiting && !didReportPending && !disposed.with({ $0 }) {
                        didReportWaiting = true
                        Logger.shared.log("InAppPurchaseManager", "Account \(accountPeerId), still waiting for purchase result")
                        subscriber.putNext(.waiting)
                    }
                }
                let reportPendingOnce: () -> Void = {
                    if reportPending && !didReportPending && !disposed.with({ $0 }) {
                        didReportPending = true
                        Logger.shared.log("InAppPurchaseManager", "Account \(accountPeerId), purchase deferred by StoreKit")
                        subscriber.putNext(.pending)
                    }
                }
                let waitingTimer: SwiftSignalKit.Timer?
                if reportPending {
                    let timer = SwiftSignalKit.Timer(timeout: 30.0, repeat: false, completion: reportWaitingOnce, queue: self.stateQueue)
                    waitingTimer = timer
                    disposables.add(ActionDisposable {
                        timer.invalidate()
                    })
                    timer.start()
                } else {
                    waitingTimer = nil
                }

                let handleState: (TransactionState) -> Void = { state in
                    if state.isTerminal {
                        waitingTimer?.invalidate()
                    }
                    switch state {
                    case let .purchased(transactionId), let .restored(transactionId):
                        if let transactionId {
                            subscriber.putNext(.purchased(transactionId: transactionId))
                            subscriber.putCompletion()
                        } else {
                            subscriber.putError(.generic)
                        }
                    case let .failed(error):
                        if let error {
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
                    case .deferred:
                        waitingTimer?.invalidate()
                        reportPendingOnce()
                    case .purchasing:
                        break
                    }
                }

                let subscribe: (PaymentTransactionContext, Bool) -> Void = { [self] context, isExisting in
                    let index = context.subscribers.add(handleState)
                    disposables.add(ActionDisposable { [weak self, weak context] in
                        self?.stateQueue.async {
                            context?.subscribers.remove(index)
                        }
                    })
                    if let state = context.state {
                        handleState(state)
                    }
                    if isExisting {
                        waitingTimer?.invalidate()
                        reportWaitingOnce()
                    }
                }

                let begin: (SKPaymentTransaction?, PendingInAppPurchaseState.Purpose?) -> Void = { [self] transaction, savedPurpose in
                    guard !disposed.with({ $0 }) else {
                        return
                    }
                    if purpose.isSubscription, let context = self.paymentContexts.values.first(where: { $0.isSubscription }) {
                        Logger.shared.log("InAppPurchaseManager", "Account \(accountPeerId), observing existing subscription")
                        subscribe(context, true)
                        return
                    }

                    let productIdentifier: String
                    let context: PaymentTransactionContext
                    if let transaction {
                        productIdentifier = transaction.payment.productIdentifier
                        switch transaction.transactionState {
                        case .purchased:
                            handleState(.purchased(transactionId: transaction.transactionIdentifier))
                            return
                        case .restored:
                            handleState(.restored(transactionId: transaction.transactionIdentifier))
                            return
                        case .failed:
                            handleState(.failed(error: transaction.error as? SKError))
                            return
                        default:
                            break
                        }
                        context = PaymentTransactionContext(purpose: savedPurpose ?? .restore, isSubscription: true)
                        context.state = transaction.transactionState == .deferred ? .deferred : .purchasing
                        self.paymentContexts[productIdentifier] = context
                        Logger.shared.log("InAppPurchaseManager", "Account \(accountPeerId), resuming subscription \(productIdentifier)")
                        subscribe(context, true)
                        return
                    } else {
                        guard self.canMakePayments else {
                            waitingTimer?.invalidate()
                            subscriber.putError(.cantMakePayments)
                            return
                        }
                        productIdentifier = product.id
                        context = PaymentTransactionContext(purpose: purpose, isSubscription: purpose.isSubscription)
                        self.paymentContexts[productIdentifier] = context
                        subscribe(context, false)
                    }

                    context.preparationDisposable.set((updatePendingInAppPurchaseState(
                        engine: self.engine,
                        productId: productIdentifier,
                        content: PendingInAppPurchaseState(productId: productIdentifier, purpose: context.purpose)
                    )
                    |> deliverOn(self.stateQueue)).start(completed: { [weak self, weak context] in
                        guard let self, let context, self.paymentContexts[productIdentifier] === context else {
                            return
                        }
                        Queue.mainQueue().async {
                            let payment = SKMutablePayment(product: product.skProduct)
                            payment.applicationUsername = accountPeerId
                            payment.quantity = Int(quantity)
                            Logger.shared.log("InAppPurchaseManager", "Buying: account \(accountPeerId), product \(productIdentifier), price \(product.price)")
                            SKPaymentQueue.default().add(payment)
                        }
                    }))
                }

                if !purpose.isSubscription || self.paymentContexts.values.contains(where: { $0.isSubscription }) {
                    begin(nil, nil)
                    return
                }

                Queue.mainQueue().async {
                    guard !disposed.with({ $0 }) else {
                        return
                    }
                    let transactions = SKPaymentQueue.default().transactions.filter { transaction in
                        guard subscriptionProductIdentifiers.contains(transaction.payment.productIdentifier),
                              transaction.payment.applicationUsername == nil || transaction.payment.applicationUsername == accountPeerId else {
                            return false
                        }
                        switch transaction.transactionState {
                        case .purchasing, .deferred, .purchased:
                            return true
                        default:
                            return false
                        }
                    }
                    let states: Signal<[(SKPaymentTransaction, PendingInAppPurchaseState?)], NoError>
                    if transactions.isEmpty {
                        states = .single([])
                    } else {
                        states = combineLatest(transactions.map { transaction in
                            return pendingInAppPurchaseState(engine: self.engine, productId: transaction.payment.productIdentifier)
                            |> take(1)
                            |> map { state in
                                return (transaction, state)
                            }
                        })
                    }
                    disposables.add((states
                    |> take(1)
                    |> deliverOn(self.stateQueue)).start(next: { states in
                        let existing = states.first(where: { transaction, state in
                            return transaction.payment.applicationUsername == accountPeerId || state?.purpose.isSubscription == true
                        })
                        begin(existing?.0, existing?.1?.purpose)
                    }))
                }
            }
            return disposables
        }
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
        Queue.mainQueue().async { [weak self] in
            guard let self, self.productRequest === request else {
                return
            }
            self.productRequest = nil
            self.productRequestTimeoutTimer?.invalidate()
            self.productRequestTimeoutTimer = nil
            let products = response.products.map { Product(skProduct: $0) }

            Logger.shared.log("InAppPurchaseManager", "Received products \(products.map({ $0.skProduct.productIdentifier }).joined(separator: ", "))")
            guard !products.isEmpty else {
                self.scheduleProductRequestRetry()
                return
            }
            self.productRequestRetryTimer?.invalidate()
            self.productRequestRetryTimer = nil
            self.products = products
            self.productsPromise.set(.single(products))
        }
    }

    public func request(_ request: SKRequest, didFailWithError error: Error) {
        Queue.mainQueue().async { [weak self] in
            guard let self, self.productRequest === request else {
                return
            }
            self.productRequest = nil
            self.productRequestTimeoutTimer?.invalidate()
            self.productRequestTimeoutTimer = nil
            Logger.shared.log("InAppPurchaseManager", "Product request failed: \(error.localizedDescription)")
            self.scheduleProductRequestRetry()
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
        self.stateQueue.async { [self] in
            let accountPeerId: String
            switch self.engine {
            case let .authorized(engine):
                accountPeerId = "\(engine.account.peerId.toInt64())"
            case let .unauthorized(engine):
                accountPeerId = "\(engine.account.id.int64)"
            }
            
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
                        context.updateState(transactionState)
                        switch transactionState {
                        case .failed:
                            self.paymentContexts.removeValue(forKey: productIdentifier)
                            let _ = updatePendingInAppPurchaseState(engine: self.engine, productId: productIdentifier, content: nil).start()
                        case .restored:
                            self.paymentContexts.removeValue(forKey: productIdentifier)
                        default:
                            break
                        }
                    } else if case .failed = transactionState, transaction.payment.applicationUsername == accountPeerId {
                        let _ = updatePendingInAppPurchaseState(engine: self.engine, productId: productIdentifier, content: nil).start()
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
                
                let receiptData = getReceiptData() ?? Data()
#if DEBUG
                self.debugSaveReceipt(receiptData: receiptData)
#endif
                
                for transaction in transactionsToAssign {
                    if let transactionIdentifier = transaction.transactionIdentifier {
                        self.finishedSuccessfulTransactions.insert(transactionIdentifier)
                    }
                }
                
                // Captured by value: this subscription is stored on self and only ends once the
                // products arrive, so reading `self.engine` here would keep the manager alive.
                let engine = self.engine
                self.disposableSet.set(
                    (purpose
                    |> castError(AssignAppStoreTransactionError.self)
                    |> mapToSignal { purpose -> Signal<Never, AssignAppStoreTransactionError> in
                        switch engine {
                        case let .authorized(engine):
                            return engine.payments.sendAppStoreReceipt(receipt: receiptData, purpose: purpose)
                        case let .unauthorized(engine):
                            return engine.payments.sendAppStoreReceipt(receipt: receiptData, purpose: purpose)
                        }
                    }).start(error: { [weak self] _ in
                        Logger.shared.log("InAppPurchaseManager", "Account \(accountPeerId), transactions [\(transactionIds)] failed to assign")
                        self?.stateQueue.async {
                            guard let self else {
                                return
                            }
                            for transaction in transactionsToAssign {
                                let productIdentifier = transaction.payment.productIdentifier
                                if let context = paymentContexts[productIdentifier] {
                                    guard self.paymentContexts[productIdentifier] === context else {
                                        continue
                                    }
                                    context.updateState(.assignFailed)
                                    self.paymentContexts.removeValue(forKey: productIdentifier)
                                } else if self.paymentContexts[productIdentifier] != nil {
                                    continue
                                }
                                let _ = updatePendingInAppPurchaseState(engine: self.engine, productId: productIdentifier, content: nil).start()
                            }
                        }
                        for transaction in transactionsToAssign {
                            queue.finishTransaction(transaction)
                        }
                    }, completed: { [weak self] in
                        Logger.shared.log("InAppPurchaseManager", "Account \(accountPeerId), transactions [\(transactionIds)] successfully assigned")
                        for transaction in transactionsToAssign {
                            queue.finishTransaction(transaction)
                        }
                        self?.stateQueue.async {
                            guard let self else {
                                return
                            }
                            for transaction in transactionsToAssign {
                                let productIdentifier = transaction.payment.productIdentifier
                                if let context = paymentContexts[productIdentifier] {
                                    guard self.paymentContexts[productIdentifier] === context else {
                                        continue
                                    }
                                    self.paymentContexts.removeValue(forKey: productIdentifier)
                                } else if self.paymentContexts[productIdentifier] != nil {
                                    continue
                                }
                                let _ = updatePendingInAppPurchaseState(engine: self.engine, productId: productIdentifier, content: nil).start()
                            }
                        }
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
                    let signal: Signal<Never, AssignAppStoreTransactionError>
                    switch self.engine {
                    case let .authorized(engine):
                        signal = engine.payments.sendAppStoreReceipt(receipt: receiptData, purpose: .restore)
                    case let .unauthorized(engine):
                        signal = engine.payments.sendAppStoreReceipt(receipt: receiptData, purpose: .restore)
                    }
                    self.disposableSet.set(
                        signal.start(error: { error in
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
        guard case let .authorized(engine) = self.engine else {
            return
        }
        let id = Int64.random(in: Int64.min ... Int64.max)
        let fileResource = LocalFileMediaResource(fileId: id, size: Int64(receiptData.count), isSecretRelated: false)
        engine.resources.storeResourceData(id: EngineMediaResource.Id(fileResource.id), data: receiptData)

        let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(receiptData.count), attributes: [.FileName(fileName: "Receipt.dat")], alternativeRepresentations: [])
        let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

        let _ = enqueueMessages(account: engine.account, peerId: engine.account.peerId, messages: [message]).start()
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
            case text
            case entities
            case restore
            case phoneNumber
            case phoneCodeHash
            case premiumDays
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
            case authCode
        }
        
        case subscription
        case upgrade
        case restore
        case gift(peerId: EnginePeer.Id)
        case giftCode(peerIds: [EnginePeer.Id], boostPeer: EnginePeer.Id?, text: String?, entities: [MessageTextEntity]?)
        case giveaway(boostPeer: EnginePeer.Id, additionalPeerIds: [EnginePeer.Id], countries: [String], onlyNewSubscribers: Bool, showWinners: Bool, prizeDescription: String?, randomId: Int64, untilDate: Int32)
        case stars(count: Int64, peerId: EnginePeer.Id?)
        case starsGift(peerId: EnginePeer.Id, count: Int64)
        case starsGiveaway(stars: Int64, boostPeer: EnginePeer.Id, additionalPeerIds: [EnginePeer.Id], countries: [String], onlyNewSubscribers: Bool, showWinners: Bool, prizeDescription: String?, randomId: Int64, untilDate: Int32, users: Int32)
        case authCode(restore: Bool, phoneNumber: String, phoneCodeHash: String, premiumDays: Int32)

        var isSubscription: Bool {
            switch self {
            case .subscription, .upgrade:
                return true
            default:
                return false
            }
        }
        
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
                    boostPeer: try container.decodeIfPresent(Int64.self, forKey: .boostPeer).flatMap({ EnginePeer.Id($0) }),
                    text: try container.decodeIfPresent(String.self, forKey: .text),
                    entities: try container.decodeIfPresent([MessageTextEntity].self, forKey: .entities)
                )
            case .giveaway:
                self = .giveaway(
                    boostPeer: EnginePeer.Id(try container.decode(Int64.self, forKey: .boostPeer)),
                    additionalPeerIds: try container.decode([Int64].self, forKey: .additionalPeerIds).map { EnginePeer.Id($0) },
                    countries: try container.decodeIfPresent([String].self, forKey: .countries) ?? [],
                    onlyNewSubscribers: try container.decode(Bool.self, forKey: .onlyNewSubscribers),
                    showWinners: try container.decodeIfPresent(Bool.self, forKey: .showWinners) ?? false,
                    prizeDescription: try container.decodeIfPresent(String.self, forKey: .prizeDescription),
                    randomId: try container.decode(Int64.self, forKey: .randomId),
                    untilDate: try container.decode(Int32.self, forKey: .untilDate)
                )
            case .stars:
                self = .stars(
                    count: try container.decode(Int64.self, forKey: .stars),
                    peerId: try container.decodeIfPresent(Int64.self, forKey: .peer).flatMap { EnginePeer.Id($0) }
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
                    additionalPeerIds: try container.decode([Int64].self, forKey: .additionalPeerIds).map { EnginePeer.Id($0) },
                    countries: try container.decodeIfPresent([String].self, forKey: .countries) ?? [],
                    onlyNewSubscribers: try container.decode(Bool.self, forKey: .onlyNewSubscribers),
                    showWinners: try container.decodeIfPresent(Bool.self, forKey: .showWinners) ?? false,
                    prizeDescription: try container.decodeIfPresent(String.self, forKey: .prizeDescription),
                    randomId: try container.decode(Int64.self, forKey: .randomId),
                    untilDate: try container.decode(Int32.self, forKey: .untilDate),
                    users: try container.decode(Int32.self, forKey: .users)
                )
            case .authCode:
                self = .authCode(
                    restore: try container.decode(Bool.self, forKey: .restore),
                    phoneNumber: try container.decode(String.self, forKey: .phoneNumber),
                    phoneCodeHash: try container.decode(String.self, forKey: .phoneCodeHash),
                    premiumDays: try container.decode(Int32.self, forKey: .premiumDays),
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
            case let .giftCode(peerIds, boostPeer, text, entities):
                try container.encode(PurposeType.giftCode.rawValue, forKey: .type)
                try container.encode(peerIds.map { $0.toInt64() }, forKey: .peers)
                try container.encodeIfPresent(boostPeer?.toInt64(), forKey: .boostPeer)
                try container.encodeIfPresent(text, forKey: .text)
                try container.encodeIfPresent(entities, forKey: .entities)
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
            case let .stars(count, peerId):
                try container.encode(PurposeType.stars.rawValue, forKey: .type)
                try container.encode(count, forKey: .stars)
                try container.encodeIfPresent(peerId?.toInt64(), forKey: .peer)
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
            case let .authCode(restore, phoneNumber, phoneCodeHash, premiumDays):
                try container.encode(PurposeType.authCode.rawValue, forKey: .type)
                try container.encode(restore, forKey: .restore)
                try container.encode(phoneNumber, forKey: .phoneNumber)
                try container.encode(phoneCodeHash, forKey: .phoneCodeHash)
                try container.encode(premiumDays, forKey: .premiumDays)
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
            case let .giftCode(peerIds, boostPeer, _, _, text, entities):
                self = .giftCode(peerIds: peerIds, boostPeer: boostPeer, text: text, entities: entities)
            case let .giveaway(boostPeer, additionalPeerIds, countries, onlyNewSubscribers, showWinners, prizeDescription, randomId, untilDate, _, _):
                self = .giveaway(boostPeer: boostPeer, additionalPeerIds: additionalPeerIds, countries: countries, onlyNewSubscribers: onlyNewSubscribers, showWinners: showWinners, prizeDescription: prizeDescription, randomId: randomId, untilDate: untilDate)
            case let .stars(count, _, _, peerId):
                self = .stars(count: count, peerId: peerId)
            case let .starsGift(peerId, count, _, _):
                self = .starsGift(peerId: peerId, count: count)
            case let .starsGiveaway(stars, boostPeer, additionalPeerIds, countries, onlyNewSubscribers, showWinners, prizeDescription, randomId, untilDate, _, _, users):
                self = .starsGiveaway(stars: stars, boostPeer: boostPeer, additionalPeerIds: additionalPeerIds, countries: countries, onlyNewSubscribers: onlyNewSubscribers, showWinners: showWinners, prizeDescription: prizeDescription, randomId: randomId, untilDate: untilDate, users: users)
            case let .authCode(restore, phoneNumber, phoneCodeHash, premiumDays, _, _):
                self = .authCode(restore: restore, phoneNumber: phoneNumber, phoneCodeHash: phoneCodeHash, premiumDays: premiumDays)
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
            case let .giftCode(peerIds, boostPeer, text, entities):
                return .giftCode(peerIds: peerIds, boostPeer: boostPeer, currency: currency, amount: amount, text: text, entities: entities)
            case let .giveaway(boostPeer, additionalPeerIds, countries, onlyNewSubscribers, showWinners, prizeDescription, randomId, untilDate):
                return .giveaway(boostPeer: boostPeer, additionalPeerIds: additionalPeerIds, countries: countries, onlyNewSubscribers: onlyNewSubscribers, showWinners: showWinners, prizeDescription: prizeDescription, randomId: randomId, untilDate: untilDate, currency: currency, amount: amount)
            case let .stars(count, peerId):
                return .stars(count: count, currency: currency, amount: amount, peerId: peerId)
            case let .starsGift(peerId, count):
                return .starsGift(peerId: peerId, count: count, currency: currency, amount: amount)
            case let .starsGiveaway(stars, boostPeer, additionalPeerIds, countries, onlyNewSubscribers, showWinners, prizeDescription, randomId, untilDate, users):
                return .starsGiveaway(stars: stars, boostPeer: boostPeer, additionalPeerIds: additionalPeerIds, countries: countries, onlyNewSubscribers: onlyNewSubscribers, showWinners: showWinners, prizeDescription: prizeDescription, randomId: randomId, untilDate: untilDate, currency: currency, amount: amount, users: users)
            case let .authCode(restore, phoneNumber, phoneCodeHash, premiumDays):
                return .authCode(restore: restore, phoneNumber: phoneNumber, phoneCodeHash: phoneCodeHash, premiumDays: premiumDays, currency: currency, amount: amount)
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

private func pendingInAppPurchaseState(engine: SomeTelegramEngine, productId: String) -> Signal<PendingInAppPurchaseState?, NoError> {
    let key = EngineDataBuffer(length: 8)
    key.setInt64(0, value: Int64(bitPattern: productId.persistentHashValue))
    
    switch engine {
    case let .authorized(engine):
        return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.pendingInAppPurchaseState, id: key))
        |> map { entry -> PendingInAppPurchaseState? in
            return entry?.get(PendingInAppPurchaseState.self)
        }
    case let .unauthorized(engine):
        return engine.itemCache.get(collectionId: ApplicationSpecificItemCacheCollectionId.pendingInAppPurchaseState, id: key)
        |> map { entry -> PendingInAppPurchaseState? in
            return entry?.get(PendingInAppPurchaseState.self)
        }
    }
}

private func updatePendingInAppPurchaseState(engine: SomeTelegramEngine, productId: String, content: PendingInAppPurchaseState?) -> Signal<Never, NoError> {
    let key = EngineDataBuffer(length: 8)
    key.setInt64(0, value: Int64(bitPattern: productId.persistentHashValue))
    
    
    switch engine {
    case let .authorized(engine):
        if let content = content {
            return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.pendingInAppPurchaseState, id: key, item: content)
        } else {
            return engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.pendingInAppPurchaseState, id: key)
        }
    case let .unauthorized(engine):
        if let content = content {
            return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.pendingInAppPurchaseState, id: key, item: content)
        } else {
            return engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.pendingInAppPurchaseState, id: key)
        }
    }
}
