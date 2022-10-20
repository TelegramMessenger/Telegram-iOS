//
// SwiftyStoreKit.swift
// SwiftyStoreKit
//
// Copyright (c) 2015 Andrea Bizzotto (bizz84@gmail.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import StoreKit

public class SwiftyStoreKit {
    
    private let productsInfoController: ProductsInfoController
    
    fileprivate let paymentQueueController: PaymentQueueController
    
    fileprivate let receiptVerificator: InAppReceiptVerificator
    
    init(productsInfoController: ProductsInfoController = ProductsInfoController(),
         paymentQueueController: PaymentQueueController = PaymentQueueController(paymentQueue: SKPaymentQueue.default()),
         receiptVerificator: InAppReceiptVerificator = InAppReceiptVerificator()) {
        
        self.productsInfoController = productsInfoController
        self.paymentQueueController = paymentQueueController
        self.receiptVerificator = receiptVerificator
    }
    
    // MARK: private methods
    fileprivate func retrieveProductsInfo(_ productIds: Set<String>, completion: @escaping (RetrieveResults) -> Void) -> InAppProductRequest {
        return productsInfoController.retrieveProductsInfo(productIds, completion: completion)
    }
    
    fileprivate func purchaseProduct(_ productId: String, quantity: Int = 1, atomically: Bool = true, applicationUsername: String = "", simulatesAskToBuyInSandbox: Bool = false, completion: @escaping ( PurchaseResult) -> Void) -> InAppProductRequest {
        
        return retrieveProductsInfo(Set([productId])) { result -> Void in
            if let product = result.retrievedProducts.first {
                self.purchase(product: product, quantity: quantity, atomically: atomically, applicationUsername: applicationUsername, simulatesAskToBuyInSandbox: simulatesAskToBuyInSandbox, completion: completion)
            } else if let error = result.error {
                completion(.error(error: SKError(_nsError: error as NSError)))
            } else if let invalidProductId = result.invalidProductIDs.first {
                let userInfo = [ NSLocalizedDescriptionKey: "Invalid product id: \(invalidProductId)" ]
                let error = NSError(domain: SKErrorDomain, code: SKError.paymentInvalid.rawValue, userInfo: userInfo)
                completion(.error(error: SKError(_nsError: error)))
            } else {
                let error = NSError(domain: SKErrorDomain, code: SKError.unknown.rawValue, userInfo: nil)
                completion(.error(error: SKError(_nsError: error)))
            }
        }
    }
    
    fileprivate func purchase(product: SKProduct, quantity: Int, atomically: Bool, applicationUsername: String = "", simulatesAskToBuyInSandbox: Bool = false, paymentDiscount: PaymentDiscount? = nil, completion: @escaping (PurchaseResult) -> Void) {
        paymentQueueController.startPayment(Payment(product: product, paymentDiscount: paymentDiscount, quantity: quantity, atomically: atomically, applicationUsername: applicationUsername, simulatesAskToBuyInSandbox: simulatesAskToBuyInSandbox) { result in
            
            completion(self.processPurchaseResult(result))
        })
    }
    
    fileprivate func restorePurchases(atomically: Bool = true, applicationUsername: String = "", completion: @escaping (RestoreResults) -> Void) {
        
        paymentQueueController.restorePurchases(RestorePurchases(atomically: atomically, applicationUsername: applicationUsername) { results in
            
            let results = self.processRestoreResults(results)
            completion(results)
        })
    }
    
    fileprivate func completeTransactions(atomically: Bool = true, completion: @escaping ([Purchase]) -> Void) {
        
        paymentQueueController.completeTransactions(CompleteTransactions(atomically: atomically, callback: completion))
    }

    fileprivate func onEntitlementRevocation(completion: @escaping ([String]) -> Void) {

        paymentQueueController.onEntitlementRevocation(EntitlementRevocation(callback: completion))
    }
    
    fileprivate func finishTransaction(_ transaction: PaymentTransaction) {
        
        paymentQueueController.finishTransaction(transaction)
    }
    
    private func processPurchaseResult(_ result: TransactionResult) -> PurchaseResult {
        switch result {
        case .purchased(let purchase):
            return .success(purchase: purchase)
        case .deferred(let purchase):
            return .deferred(purchase: purchase)
        case .failed(let error):
            return .error(error: error)
        case .restored(let purchase):
            return .error(error: storeInternalError(description: "Cannot restore product \(purchase.productId) from purchase path"))
        }
    }
    
    private func processRestoreResults(_ results: [TransactionResult]) -> RestoreResults {
        var restoredPurchases: [Purchase] = []
        var restoreFailedPurchases: [(SKError, String?)] = []
        for result in results {
            switch result {
            case .purchased(let purchase):
                let error = storeInternalError(description: "Cannot purchase product \(purchase.productId) from restore purchases path")
                restoreFailedPurchases.append((error, purchase.productId))
            case .deferred(let purchase):
                let error = storeInternalError(description: "Cannot purchase product \(purchase.productId) from restore purchases path")
                restoreFailedPurchases.append((error, purchase.productId))
            case .failed(let error):
                restoreFailedPurchases.append((error, nil))
            case .restored(let purchase):
                restoredPurchases.append(purchase)
            }
        }
        return RestoreResults(restoredPurchases: restoredPurchases, restoreFailedPurchases: restoreFailedPurchases)
    }
    
    private func storeInternalError(code: SKError.Code = SKError.unknown, description: String = "") -> SKError {
        let error = NSError(domain: SKErrorDomain, code: code.rawValue, userInfo: [ NSLocalizedDescriptionKey: description ])
        return SKError(_nsError: error)
    }
}

extension SwiftyStoreKit {
    
    // MARK: Singleton
    fileprivate static let sharedInstance = SwiftyStoreKit()
    
    // MARK: Public methods - Purchases
    
    /// Check if the current device can make payments.
    /// - returns: `false` if this device is not able or allowed to make payments
    public class var canMakePayments: Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    /// Retrieve products information
    /// - Parameter productIds: The set of product identifiers to retrieve corresponding products for
    /// - Parameter completion: handler for result
    /// - returns: A cancellable `InAppRequest` object 
    @discardableResult
    public class func retrieveProductsInfo(_ productIds: Set<String>, completion: @escaping (RetrieveResults) -> Void) -> InAppRequest {
        return sharedInstance.retrieveProductsInfo(productIds, completion: completion)
    }
    
    /// Purchase a product
    ///  - Parameter productId: productId as specified in App Store Connect
    ///  - Parameter quantity: quantity of the product to be purchased
    ///  - Parameter atomically: whether the product is purchased atomically (e.g. `finishTransaction` is called immediately)
    ///  - Parameter applicationUsername: an opaque identifier for the user’s account on your system
    ///  - Parameter completion: handler for result
    ///  - returns: A cancellable `InAppRequest` object   
    @discardableResult
    public class func purchaseProduct(_ productId: String, quantity: Int = 1, atomically: Bool = true, applicationUsername: String = "", simulatesAskToBuyInSandbox: Bool = false, completion: @escaping (PurchaseResult) -> Void) -> InAppRequest {
        
        return sharedInstance.purchaseProduct(productId, quantity: quantity, atomically: atomically, applicationUsername: applicationUsername, simulatesAskToBuyInSandbox: simulatesAskToBuyInSandbox, completion: completion)
    }
    
    /// Purchase a product
    ///  - Parameter product: product to be purchased
    ///  - Parameter quantity: quantity of the product to be purchased
    ///  - Parameter atomically: whether the product is purchased atomically (e.g. `finishTransaction` is called immediately)
    ///  - Parameter applicationUsername: an opaque identifier for the user’s account on your system
    ///  - Parameter product: optional discount to be applied. Must be of `SKProductPayment` type
    ///  - Parameter completion: handler for result
    public class func purchaseProduct(_ product: SKProduct, quantity: Int = 1, atomically: Bool = true, applicationUsername: String = "", simulatesAskToBuyInSandbox: Bool = false, paymentDiscount: PaymentDiscount? = nil, completion: @escaping ( PurchaseResult) -> Void) {
        
        sharedInstance.purchase(product: product, quantity: quantity, atomically: atomically, applicationUsername: applicationUsername, simulatesAskToBuyInSandbox: simulatesAskToBuyInSandbox, paymentDiscount: paymentDiscount, completion: completion)
    }
    
    /// Restore purchases
    ///  - Parameter atomically: whether the product is purchased atomically (e.g. `finishTransaction` is called immediately)
    ///  - Parameter applicationUsername: an opaque identifier for the user’s account on your system
    ///  - Parameter completion: handler for result
    public class func restorePurchases(atomically: Bool = true, applicationUsername: String = "", completion: @escaping (RestoreResults) -> Void) {
        
        sharedInstance.restorePurchases(atomically: atomically, applicationUsername: applicationUsername, completion: completion)
    }
    
    /// Complete transactions
    ///  - Parameter atomically: whether the product is purchased atomically (e.g. `finishTransaction` is called immediately)
    ///  - Parameter completion: handler for result
    public class func completeTransactions(atomically: Bool = true, completion: @escaping ([Purchase]) -> Void) {
        
        sharedInstance.completeTransactions(atomically: atomically, completion: completion)
    }

    /// Entitlement revocation notification
    ///   - Parameter completion: handler for result (list of product identifiers revoked)
    @available(iOS 14, tvOS 14, OSX 11, watchOS 7, macCatalyst 14, *)
    public class func onEntitlementRevocation(completion: @escaping ([String]) -> Void) {

        sharedInstance.onEntitlementRevocation(completion: completion)
    }
    
    /// Finish a transaction
    /// 
    /// Once the content has been delivered, call this method to finish a transaction that was performed non-atomically
    /// - Parameter transaction: transaction to finish
    public class func finishTransaction(_ transaction: PaymentTransaction) {
        
        sharedInstance.finishTransaction(transaction)
    }
    
    /// Register a handler for `SKPaymentQueue.shouldAddStorePayment` delegate method.
    /// - requires: iOS 11.0+
    public static var shouldAddStorePaymentHandler: ShouldAddStorePaymentHandler? {
        didSet {
            sharedInstance.paymentQueueController.shouldAddStorePaymentHandler = shouldAddStorePaymentHandler
        }
    }
    
    /// Register a handler for `paymentQueue(_:updatedDownloads:)`
    /// - seealso: `paymentQueue(_:updatedDownloads:)`
    public static var updatedDownloadsHandler: UpdatedDownloadsHandler? {
        didSet {
            sharedInstance.paymentQueueController.updatedDownloadsHandler = updatedDownloadsHandler
        }
    }
    
    public class func start(_ downloads: [SKDownload]) {
        sharedInstance.paymentQueueController.start(downloads)
    }
    public class func pause(_ downloads: [SKDownload]) {
        sharedInstance.paymentQueueController.pause(downloads)
    }
    public class func resume(_ downloads: [SKDownload]) {
        sharedInstance.paymentQueueController.resume(downloads)
    }
    public class func cancel(_ downloads: [SKDownload]) {
        sharedInstance.paymentQueueController.cancel(downloads)
    }
}

extension SwiftyStoreKit {
    
    // MARK: Public methods - Receipt verification
    
    /// Return receipt data from the application bundle. This is read from `Bundle.main.appStoreReceiptURL`.
    public static var localReceiptData: Data? {
        return sharedInstance.receiptVerificator.appStoreReceiptData
    }
    
    /// Verify application receipt
    /// - Parameter validator: receipt validator to use
    /// - Parameter forceRefresh: If `true`, refreshes the receipt even if one already exists.
    /// - Parameter completion: handler for result
    /// - returns: A cancellable `InAppRequest` object 
    @discardableResult
    public class func verifyReceipt(using validator: ReceiptValidator, forceRefresh: Bool = false, completion: @escaping (VerifyReceiptResult) -> Void) -> InAppRequest? {
        
        return sharedInstance.receiptVerificator.verifyReceipt(using: validator, forceRefresh: forceRefresh, completion: completion)
    }
    
    /// Fetch application receipt
    /// - Parameter forceRefresh: If true, refreshes the receipt even if one already exists.
    /// - Parameter completion: handler for result
    /// - returns: A cancellable `InAppRequest` object 
    @discardableResult
    public class func fetchReceipt(forceRefresh: Bool, completion: @escaping (FetchReceiptResult) -> Void) -> InAppRequest? {
        
        return sharedInstance.receiptVerificator.fetchReceipt(forceRefresh: forceRefresh, completion: completion)
    }
    
    ///  Verify the purchase of a Consumable or NonConsumable product in a receipt
    ///  - Parameter productId: the product id of the purchase to verify
    ///  - Parameter inReceipt: the receipt to use for looking up the purchase
    ///  - returns: A `VerifyPurchaseResult`, which may be either `notPurchased` or `purchased`.
    public class func verifyPurchase(productId: String, inReceipt receipt: ReceiptInfo) -> VerifyPurchaseResult {
        
        return InAppReceipt.verifyPurchase(productId: productId, inReceipt: receipt)
    }
    
    /**
     *  Verify the validity of a subscription (auto-renewable, free or non-renewing) in a receipt.
     *
     *  This method extracts all transactions matching the given productId and sorts them by date in descending order. It then compares the first transaction expiry date against the receipt date to determine its validity.
     *  - Parameter type: `.autoRenewable` or `.nonRenewing`.
     *  - Parameter productId: The product id of the subscription to verify.
     *  - Parameter receipt: The receipt to use for looking up the subscription.
     *  - Parameter validUntil: Date to check against the expiry date of the subscription. This is only used if a date is not found in the receipt.
     *  - returns: Either `.notPurchased` or `.purchased` / `.expired` with the expiry date found in the receipt.
     */
    public class func verifySubscription(ofType type: SubscriptionType, productId: String, inReceipt receipt: ReceiptInfo, validUntil date: Date = Date()) -> VerifySubscriptionResult {
        
        return InAppReceipt.verifySubscriptions(ofType: type, productIds: [productId], inReceipt: receipt, validUntil: date)
    }
    
    /**
     *  Verify the validity of a set of subscriptions in a receipt.
     *
     *  This method extracts all transactions matching the given productIds and sorts them by date in descending order. It then compares the first transaction expiry date against the receipt date, to determine its validity.
     *  - Note: You can use this method to check the validity of (mutually exclusive) subscriptions in a subscription group.
     *  - Remark: The type parameter determines how the expiration dates are calculated for all subscriptions. Make sure all productIds match the specified subscription type to avoid incorrect results.
     *  - Parameter type: `.autoRenewable` or `.nonRenewing`.
     *  - Parameter productIds: The product IDs of the subscriptions to verify.
     *  - Parameter receipt: The receipt to use for looking up the subscriptions
     *  - Parameter validUntil: Date to check against the expiry date of the subscriptions. This is only used if a date is not found in the receipt.
     *  - returns: Either `.notPurchased` or `.purchased` / `.expired` with the expiry date found in the receipt.
     */
    public class func verifySubscriptions(ofType type: SubscriptionType = .autoRenewable, productIds: Set<String>, inReceipt receipt: ReceiptInfo, validUntil date: Date = Date()) -> VerifySubscriptionResult {
        
        return InAppReceipt.verifySubscriptions(ofType: type, productIds: productIds, inReceipt: receipt, validUntil: date)
    }
    
    ///  Get the distinct product identifiers from receipt.
    ///
    /// This Method extracts all product identifiers. (Including cancelled ones).
    /// - Note: You can use this method to get all unique product identifiers from receipt.
    /// - Parameter type: `.autoRenewable` or `.nonRenewing`.
    /// - Parameter receipt: The receipt to use for looking up product identifiers.
    /// - returns: Either `Set<String>` or `nil`.
    public class func getDistinctPurchaseIds(ofType type: SubscriptionType = .autoRenewable, inReceipt receipt: ReceiptInfo) -> Set<String>? {
        
        return InAppReceipt.getDistinctPurchaseIds(ofType: type, inReceipt: receipt)
    }
}
