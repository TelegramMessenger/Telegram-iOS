//
// PaymentQueueController.swift
// SwiftyStoreKit
//
// Copyright (c) 2017 Andrea Bizzotto (bizz84@gmail.com)
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

import Foundation
import StoreKit

protocol TransactionController {
    
    /// Process the supplied transactions on a given queue.
    /// - parameter transactions: transactions to process
    /// - parameter paymentQueue: payment queue for finishing transactions
    /// - returns: array of unhandled transactions
    func processTransactions(_ transactions: [SKPaymentTransaction], on paymentQueue: PaymentQueue) -> [SKPaymentTransaction]
    
}

public enum TransactionResult {
    case purchased(purchase: PurchaseDetails)
    case restored(purchase: Purchase)
    case deferred(purchase: PurchaseDetails)
    case failed(error: SKError)
}

public protocol PaymentQueue: AnyObject {
    
    func add(_ observer: SKPaymentTransactionObserver)
    func remove(_ observer: SKPaymentTransactionObserver)
    
    func add(_ payment: SKPayment)
    
    func start(_ downloads: [SKDownload])
    func pause(_ downloads: [SKDownload])
    func resume(_ downloads: [SKDownload])
    func cancel(_ downloads: [SKDownload])
    
    func restoreCompletedTransactions(withApplicationUsername username: String?)
    
    func finishTransaction(_ transaction: SKPaymentTransaction)
}

extension SKPaymentQueue: PaymentQueue {
    
    #if os(watchOS) && swift(<5.3)
    public func resume(_ downloads: [SKDownload]) {
        resumeDownloads(downloads)
    }
    #endif
    
}

extension SKPaymentTransaction {
    
    open override var debugDescription: String {
        let transactionId = transactionIdentifier ?? "null"
        return "productId: \(payment.productIdentifier), transactionId: \(transactionId), state: \(transactionState), date: \(String(describing: transactionDate))"
    }
    
}

extension SKPaymentTransactionState: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        switch self {
        case .purchasing: return "purchasing"
        case .purchased: return "purchased"
        case .failed: return "failed"
        case .restored: return "restored"
        case .deferred: return "deferred"
        @unknown default: return "default"
        }
    }
}

struct EntitlementRevocation {
    let callback: ([String]) -> Void
    
    init(callback: @escaping ([String]) -> Void) {
        self.callback = callback
    }
}

class PaymentQueueController: NSObject, SKPaymentTransactionObserver {
    
    private let paymentsController: PaymentsController
    private let restorePurchasesController: RestorePurchasesController
    private let completeTransactionsController: CompleteTransactionsController
    unowned let paymentQueue: PaymentQueue
    private var entitlementRevocation: EntitlementRevocation?
    
    deinit {
        paymentQueue.remove(self)
    }
    
    init(paymentQueue: PaymentQueue = SKPaymentQueue.default(),
         paymentsController: PaymentsController = PaymentsController(),
         restorePurchasesController: RestorePurchasesController = RestorePurchasesController(),
         completeTransactionsController: CompleteTransactionsController = CompleteTransactionsController()) {
        
        self.paymentQueue = paymentQueue
        self.paymentsController = paymentsController
        self.restorePurchasesController = restorePurchasesController
        self.completeTransactionsController = completeTransactionsController
        super.init()
        paymentQueue.add(self)
    }
    
    private func assertCompleteTransactionsWasCalled() {
        
        let message = "SwiftyStoreKit.completeTransactions() must be called when the app launches."
        assert(completeTransactionsController.completeTransactions != nil, message)
    }
    
    func startPayment(_ payment: Payment) {
        assertCompleteTransactionsWasCalled()
        
        let skPayment = SKMutablePayment(product: payment.product)
        skPayment.applicationUsername = payment.applicationUsername
        skPayment.quantity = payment.quantity
        
        if #available(iOS 12.2, tvOS 12.2, OSX 10.14.4, watchOS 6.2, *) {
            if let discount = payment.paymentDiscount?.discount as? SKPaymentDiscount {
                skPayment.paymentDiscount = discount
            }
        }
        
        #if os(iOS) || os(tvOS) || os(watchOS)
        if #available(iOS 8.3, watchOS 6.2, *) {
            skPayment.simulatesAskToBuyInSandbox = payment.simulatesAskToBuyInSandbox
        }
        #endif
        
        paymentQueue.add(skPayment)
        
        paymentsController.append(payment)
    }
    
    func onEntitlementRevocation(_ revocation: EntitlementRevocation) {
        guard entitlementRevocation == nil else {
            print("SwiftyStoreKit.onEntitlementRevocation() should only be called once when the app launches. Ignoring this call")
            return
        }
        
        self.entitlementRevocation = revocation
    }
    
    func restorePurchases(_ restorePurchases: RestorePurchases) {
        assertCompleteTransactionsWasCalled()
        
        if restorePurchasesController.restorePurchases != nil {
            return
        }
        
        paymentQueue.restoreCompletedTransactions(withApplicationUsername: restorePurchases.applicationUsername)
        
        restorePurchasesController.restorePurchases = restorePurchases
    }
    
    func completeTransactions(_ completeTransactions: CompleteTransactions) {
        guard completeTransactionsController.completeTransactions == nil else {
            print("SwiftyStoreKit.completeTransactions() should only be called once when the app launches. Ignoring this call")
            return
        }
        
        completeTransactionsController.completeTransactions = completeTransactions
    }
    
    func finishTransaction(_ transaction: PaymentTransaction) {
        guard let skTransaction = transaction as? SKPaymentTransaction else {
            print("Object is not a SKPaymentTransaction: \(transaction)")
            return
        }
        paymentQueue.finishTransaction(skTransaction)
    }
    
    func start(_ downloads: [SKDownload]) {
        paymentQueue.start(downloads)
    }
    
    func pause(_ downloads: [SKDownload]) {
        paymentQueue.pause(downloads)
    }
    
    func resume(_ downloads: [SKDownload]) {
        paymentQueue.resume(downloads)
    }
    
    func cancel(_ downloads: [SKDownload]) {
        paymentQueue.cancel(downloads)
    }
    
    var shouldAddStorePaymentHandler: ShouldAddStorePaymentHandler?
    var updatedDownloadsHandler: UpdatedDownloadsHandler?
    
    
    // MARK: - SKPaymentTransactionObserver
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        /*
         * Some notes about how requests are processed by SKPaymentQueue:
         *
         * SKPaymentQueue is used to queue payments or restore purchases requests.
         * Payments are processed serially and in-order and require user interaction.
         * Restore purchases requests don't require user interaction and can jump ahead of the queue.
         * SKPaymentQueue rejects multiple restore purchases calls.
         * Having one payment queue observer for each request causes extra processing
         * Failed transactions only ever belong to queued payment requests.
         * restoreCompletedTransactionsFailedWithError is always called when a restore purchases request fails.
         * paymentQueueRestoreCompletedTransactionsFinished is always called following 0 or more update transactions when a restore purchases request succeeds.
         * A complete transactions handler is required to catch any transactions that are updated when the app is not running.
         * Registering a complete transactions handler when the app launches ensures that any pending transactions can be cleared.
         * If a complete transactions handler is missing, pending transactions can be mis-attributed to any new incoming payments or restore purchases.
         *
         * The order in which transaction updates are processed is:
         * 1. payments (transactionState: .purchased and .failed for matching product identifiers)
         * 2. restore purchases (transactionState: .restored, or restoreCompletedTransactionsFailedWithError, or paymentQueueRestoreCompletedTransactionsFinished)
         * 3. complete transactions (transactionState: .purchased, .failed, .restored, .deferred)
         * Any transactions where state == .purchasing are ignored.
         */
        var unhandledTransactions = transactions.filter { $0.transactionState != .purchasing }
        
        if unhandledTransactions.count > 0 {
            
            unhandledTransactions = paymentsController.processTransactions(transactions, on: paymentQueue)
            
            unhandledTransactions = restorePurchasesController.processTransactions(unhandledTransactions, on: paymentQueue)
            
            unhandledTransactions = completeTransactionsController.processTransactions(unhandledTransactions, on: paymentQueue)
            
            if unhandledTransactions.count > 0 {
                let strings = unhandledTransactions.map { $0.debugDescription }.joined(separator: "\n")
                print("unhandledTransactions:\n\(strings)")
            }
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, didRevokeEntitlementsForProductIdentifiers productIdentifiers: [String]) {
        self.entitlementRevocation?.callback(productIdentifiers)
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        restorePurchasesController.restoreCompletedTransactionsFailed(withError: error)
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        restorePurchasesController.restoreCompletedTransactionsFinished()
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload]) {
        updatedDownloadsHandler?(downloads)
    }
    
    #if !os(watchOS)
    func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        return shouldAddStorePaymentHandler?(payment, product) ?? false
    }
    #endif
}
