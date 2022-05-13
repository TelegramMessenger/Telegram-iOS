import Foundation
import CoreLocation
import SwiftSignalKit
import StoreKit
import Postbox
import TelegramCore

private final class PaymentTransactionContext {
    var state: SKPaymentTransactionState?
    let subscriber: (SKPaymentTransactionState) -> Void
    
    init(subscriber: @escaping (SKPaymentTransactionState) -> Void) {
        self.subscriber = subscriber
    }
}

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
    
    public enum PurchaseResult {
        case success
    }
    
    public enum PurchaseError {
        case generic
    }
        
    private let premiumProductId: String
    
    private var products: [Product] = []
    private var productsPromise = Promise<[Product]>()
    private var productRequest: SKProductsRequest?
    
    private let stateQueue = Queue()
    private var paymentContexts: [String: PaymentTransactionContext] = [:]
    
    public init(premiumProductId: String) {
        self.premiumProductId = premiumProductId
        
        super.init()
        
        SKPaymentQueue.default().add(self)
        self.requestProducts()
    }
    
    deinit {
        
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
    
    public func buyProduct(_ product: Product, account: Account) -> Signal<PurchaseResult, PurchaseError> {
        let payment = SKMutablePayment(product: product.skProduct)
        payment.applicationUsername = "\(account.peerId.id._internalGetInt64Value())"
        SKPaymentQueue.default().add(payment)
        
        let productIdentifier = payment.productIdentifier
        let signal = Signal<PurchaseResult, PurchaseError> { subscriber in
            let disposable = MetaDisposable()
            
            self.stateQueue.async {
                let paymentContext = PaymentTransactionContext(subscriber: { state in
                    switch state {
                        case .purchased, .restored:
                            subscriber.putNext(.success)
                            subscriber.putCompletion()
                        case .failed:
                            subscriber.putError(.generic)
                        case .deferred, .purchasing:
                            break
                        default:
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

extension InAppPurchaseManager: SKPaymentTransactionObserver {
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        if let transaction = transactions.first {
            let productIdentifier = transaction.payment.productIdentifier
            self.stateQueue.async {
                if let context = self.paymentContexts[productIdentifier] {
                    context.subscriber(transaction.transactionState)
                }
            }
        }
    }
}
