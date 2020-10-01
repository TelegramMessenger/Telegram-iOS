//
//  IAPHelper.swift
//  NicegramLib
//
//  Created by Sergey on 28.10.2019.
//  Copyright © 2019 Nicegram. All rights reserved.
//

import StoreKit
import NGLogging
import NGData

fileprivate let LOGTAG = extractNameFromPath(#file)

public typealias ProductIdentifier = String
public typealias ProductsRequestCompletionHandler = (_ success: Bool, _ products: [SKProduct]?) -> Void

public extension Notification.Name {
    static let IAPHelperPurchaseNotification = Notification.Name("IAPHelperPurchaseNotification")
    static let IAPHelperErrorNotification = Notification.Name("IAPHelperErrorNotification")
}

open class IAPHelper: NSObject  {
    
    private let productIdentifiers: Set<ProductIdentifier>
    private var purchasedProductIdentifiers: Set<ProductIdentifier> = []
    private var productsRequest: SKProductsRequest?
    private var productsRequestCompletionHandler: ProductsRequestCompletionHandler?
    
    public init(productIds: Set<ProductIdentifier>) {
        productIdentifiers = productIds
        for productIdentifier in productIds {
            let purchased = UserDefaults.standard.bool(forKey: productIdentifier)
            if purchased {
                purchasedProductIdentifiers.insert(productIdentifier)
                ngLog("Previously purchased: \(productIdentifier)", LOGTAG)
            } else {
                ngLog("Not purchased: \(productIdentifier)", LOGTAG)
            }
        }
        super.init()
        
        SKPaymentQueue.default().add(self)
    }
}

// MARK: - StoreKit API

extension IAPHelper {
    
    public func requestProducts(_ completionHandler: @escaping ProductsRequestCompletionHandler) {
        productsRequest?.cancel()
        productsRequestCompletionHandler = completionHandler
        
        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest!.delegate = self
        productsRequest!.start()
    }
    
    public func buyProduct(_ product: SKProduct) {
        ngLog("Buying \(product.productIdentifier)...", LOGTAG)
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    public func isProductPurchased(_ productIdentifier: ProductIdentifier) -> Bool {
        return purchasedProductIdentifiers.contains(productIdentifier)
    }
    
    public class func canMakePayments() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    public func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
}

// MARK: - SKProductsRequestDelegate

extension IAPHelper: SKProductsRequestDelegate {
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        ngLog("Loaded list of products...", LOGTAG)
        let products = response.products
        productsRequestCompletionHandler?(true, products)
        clearRequestAndHandler()
        
        for p in products {
            ngLog("Found product: \(p.productIdentifier) \(p.localizedTitle) \(p.price.floatValue)", LOGTAG)
        }
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        ngLog("Failed to load list of products.", LOGTAG)
        ngLog("Error: \(error.localizedDescription)", LOGTAG)
        productsRequestCompletionHandler?(false, nil)
        clearRequestAndHandler()
    }
    
    private func clearRequestAndHandler() {
        productsRequest = nil
        productsRequestCompletionHandler = nil
    }
}

// MARK: - SKPaymentTransactionObserver

extension IAPHelper: SKPaymentTransactionObserver {
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch (transaction.transactionState) {
            case .purchased:
                ngLog("paymentQueue purchased", LOGTAG)
                complete(transaction: transaction)
                break
            case .failed:
                ngLog("paymentQueue failed", LOGTAG)
                fail(transaction: transaction)
                break
            case .restored:
                ngLog("paymentQueue restored", LOGTAG)
                restore(transaction: transaction)
                break
            case .deferred:
                ngLog("paymentQueue deferred", LOGTAG)
                break
            case .purchasing:
                ngLog("paymentQueue purchasing", LOGTAG)
                break
            @unknown default:
                ngLog("paymentQueue unknown (fail)")
                fail(transaction: transaction)
                break
            }
        }
    }
    
    private func complete(transaction: SKPaymentTransaction) {
        ngLog("complete...", LOGTAG)
        deliverPurchaseNotificationFor(identifier: transaction.payment.productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    private func restore(transaction: SKPaymentTransaction) {
        ngLog("restore started", LOGTAG)
        guard let productIdentifier = transaction.original?.payment.productIdentifier else { return }
        
        ngLog("restore... \(productIdentifier)", LOGTAG)
        deliverPurchaseNotificationFor(identifier: productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    private func fail(transaction: SKPaymentTransaction) {
        ngLog("fail...", LOGTAG)
        if let transactionError = transaction.error as NSError?,
            let localizedDescription = transaction.error?.localizedDescription,
            transactionError.code != SKError.paymentCancelled.rawValue {
            deliverPurchaseErrorNotificationFor(error: localizedDescription)
            ngLog("Transaction Error: \(localizedDescription)", LOGTAG)
        }
        
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    private func deliverPurchaseNotificationFor(identifier: String?) {
        guard let identifier = identifier else { return }
        
        purchasedProductIdentifiers.insert(identifier)
        UserDefaults.standard.set(true, forKey: identifier)
//        if identifier == NicegramProducts.Premium {
//            patchPurchasePremium()
//        }
        NotificationCenter.default.post(name: .IAPHelperPurchaseNotification, object: identifier)
    }
    
    private func deliverPurchaseErrorNotificationFor(error: String) {
        NotificationCenter.default.post(name: .IAPHelperErrorNotification, object: error)
    }
}
