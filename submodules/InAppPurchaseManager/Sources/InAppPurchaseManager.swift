import Foundation
import CoreLocation
import SwiftSignalKit
import StoreKit
import Postbox
import TelegramCore

public final class InAppPurchaseManager: NSObject {
    public final class Product {
        let skProduct: SKProduct
        
        init(skProduct: SKProduct) {
            self.skProduct = skProduct
        }
        
        public var price: String {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .currency
            numberFormatter.locale = self.skProduct.priceLocale
            return numberFormatter.string(from: self.skProduct.price) ?? ""
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
    }
    
    private final class PaymentTransactionContext {
        var state: SKPaymentTransactionState?
        let subscriber: (TransactionState) -> Void
        
        init(subscriber: @escaping (TransactionState) -> Void) {
            self.subscriber = subscriber
        }
    }
    
    private enum TransactionState {
        case purchased(transactionId: String?)
        case restored(transactionId: String?)
        case purchasing
        case failed(error: SKError?)
        case deferred
    }
    
    private let engine: TelegramEngine
    private let premiumProductId: String
    
    private var products: [Product] = []
    private var productsPromise = Promise<[Product]>()
    private var productRequest: SKProductsRequest?
    
    private let stateQueue = Queue()
    private var paymentContexts: [String: PaymentTransactionContext] = [:]
    
    private let disposableSet = DisposableDict<String>()
    
    public init(engine: TelegramEngine, premiumProductId: String) {
        self.engine = engine
        self.premiumProductId = premiumProductId
        
        super.init()
        
        SKPaymentQueue.default().add(self)
        self.requestProducts()
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    private func requestProducts() {
        guard !self.premiumProductId.isEmpty else {
            return
        }
        let productRequest = SKProductsRequest(productIdentifiers: Set([self.premiumProductId]))
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
    
    public func finishAllTransactions() {
        let paymentQueue = SKPaymentQueue.default()
        let transactions = paymentQueue.transactions
        for transaction in transactions {
            paymentQueue.finishTransaction(transaction)
        }
    }
    
    public func buyProduct(_ product: Product, account: Account) -> Signal<PurchaseState, PurchaseError> {
        let payment = SKPayment(product: product.skProduct)
        SKPaymentQueue.default().add(payment)
        
        let productIdentifier = payment.productIdentifier
        let signal = Signal<PurchaseState, PurchaseError> { subscriber in
            let disposable = MetaDisposable()
            
            self.stateQueue.async {
                let paymentContext = PaymentTransactionContext(subscriber: { state in
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
            self.productsPromise.set(.single(response.products.map { Product(skProduct: $0) }))
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
        for transaction in transactions {
            let productIdentifier = transaction.payment.productIdentifier
            self.stateQueue.async {
                let transactionState: TransactionState?
                switch transaction.transactionState {
                    case .purchased:
                        if transaction.original == nil {
                            transactionState = .purchased(transactionId: transaction.transactionIdentifier)
                            if let transactionIdentifier = transaction.transactionIdentifier {
                                self.disposableSet.set(
                                    self.engine.payments.assignAppStoreTransaction(transactionId: transactionIdentifier, receipt: getReceiptData() ?? Data(), restore: false).start(error: { _ in
                                        queue.finishTransaction(transaction)
                                    }, completed: {
                                        queue.finishTransaction(transaction)
                                    }),
                                    forKey: transaction.transactionIdentifier ?? ""
                                )
                            }
                        } else {
                            transactionState = nil
                            queue.finishTransaction(transaction)
                        }
                    case .restored:
                        transactionState = .restored(transactionId: transaction.original?.transactionIdentifier)
                        if let transactionIdentifier = transaction.original?.transactionIdentifier {
                            self.disposableSet.set(
                                self.engine.payments.assignAppStoreTransaction(transactionId: transactionIdentifier, receipt: getReceiptData() ?? Data(), restore: true).start(error: { _ in
                                    queue.finishTransaction(transaction)
                                }, completed: {
                                    queue.finishTransaction(transaction)
                                }),
                                forKey: transaction.transactionIdentifier ?? ""
                            )
                        }
                    case .failed:
                        transactionState = .failed(error: transaction.error as? SKError)
                        queue.finishTransaction(transaction)
                    case .purchasing:
                        transactionState = .purchasing
                    case .deferred:
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
        }
    }
}
