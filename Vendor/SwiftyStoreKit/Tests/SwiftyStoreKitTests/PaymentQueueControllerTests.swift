//
// PaymentQueueControllerTests.swift
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

// swiftlint:disable function_body_length

import XCTest
import StoreKit
@testable import SwiftyStoreKit

class PaymentQueueControllerTests: XCTestCase {

    // MARK: init/deinit
    func testInit_registersAsObserver() {

        let spy = PaymentQueueSpy()

        let paymentQueueController = PaymentQueueController(paymentQueue: spy)

        XCTAssertTrue(spy.observer === paymentQueueController)
    }

    func testDeinit_removesObserver() {

        let spy = PaymentQueueSpy()

        _ = PaymentQueueController(paymentQueue: spy)

        XCTAssertNil(spy.observer)
    }

    // MARK: Start payment

    func testStartTransaction_QueuesOnePayment() {

        let spy = PaymentQueueSpy()

        let paymentQueueController = PaymentQueueController(paymentQueue: spy)

        let payment = makeTestPayment(productIdentifier: "com.SwiftyStoreKit.product1") { _ in }

        paymentQueueController.completeTransactions(CompleteTransactions(atomically: true) { _ in })

        paymentQueueController.startPayment(payment)

        XCTAssertEqual(spy.payments.count, 1)
    }

    // MARK: SKPaymentTransactionObserver callbacks
    func testPaymentQueue_when_oneTransactionForEachState_onePayment_oneRestorePurchases_oneCompleteTransactions_then_correctCallbacksCalled() {

        // setup
        let spy = PaymentQueueSpy()

        let paymentQueueController = PaymentQueueController(paymentQueue: spy)

        let purchasedProductIdentifier = "com.SwiftyStoreKit.product1"
        let failedProductIdentifier = "com.SwiftyStoreKit.product2"
        let restoredProductIdentifier = "com.SwiftyStoreKit.product3"
        let deferredProductIdentifier = "com.SwiftyStoreKit.product4"
        let purchasingProductIdentifier = "com.SwiftyStoreKit.product5"

        let transactions = [
            makeTestPaymentTransaction(productIdentifier: purchasedProductIdentifier, transactionState: .purchased),
            makeTestPaymentTransaction(productIdentifier: failedProductIdentifier, transactionState: .failed),
            makeTestPaymentTransaction(productIdentifier: restoredProductIdentifier, transactionState: .restored),
            makeTestPaymentTransaction(productIdentifier: deferredProductIdentifier, transactionState: .deferred),
            makeTestPaymentTransaction(productIdentifier: purchasingProductIdentifier, transactionState: .purchasing)
            ]

        var paymentCallbackCalled = false
        let testPayment = makeTestPayment(productIdentifier: purchasedProductIdentifier) { result in
            paymentCallbackCalled = true
            if case .purchased(let product) = result {
                XCTAssertEqual(product.productId, purchasedProductIdentifier)
            } else {
                XCTFail("expected purchased callback with product id")
            }
        }

        var restorePurchasesCallbackCalled = false
        let restorePurchases = RestorePurchases(atomically: true) { results in
            restorePurchasesCallbackCalled = true
            XCTAssertEqual(results.count, 1)
            let first = results.first!
            if case .restored(let restoredPayment) = first {
                XCTAssertEqual(restoredPayment.productId, restoredProductIdentifier)
            } else {
                XCTFail("expected restored callback with product")
            }
        }

        var completeTransactionsCallbackCalled = false
        let completeTransactions = CompleteTransactions(atomically: true) { purchases in
            completeTransactionsCallbackCalled = true
            XCTAssertEqual(purchases.count, 2)
            XCTAssertEqual(purchases[0].productId, failedProductIdentifier)
            XCTAssertEqual(purchases[1].productId, deferredProductIdentifier)
        }

        // run
        paymentQueueController.completeTransactions(completeTransactions)

        paymentQueueController.startPayment(testPayment)

        paymentQueueController.restorePurchases(restorePurchases)

        paymentQueueController.paymentQueue(SKPaymentQueue(), updatedTransactions: transactions)
        paymentQueueController.paymentQueueRestoreCompletedTransactionsFinished(SKPaymentQueue())

        // verify
        XCTAssertTrue(paymentCallbackCalled)
        XCTAssertTrue(restorePurchasesCallbackCalled)
        XCTAssertTrue(completeTransactionsCallbackCalled)
    }

    func testPaymentQueue_when_oneTransactionForEachState_onePayment_noRestorePurchases_oneCompleteTransactions_then_correctCallbacksCalled() {

        // setup
        let spy = PaymentQueueSpy()

        let paymentQueueController = PaymentQueueController(paymentQueue: spy)

        let purchasedProductIdentifier = "com.SwiftyStoreKit.product1"
        let failedProductIdentifier = "com.SwiftyStoreKit.product2"
        let restoredProductIdentifier = "com.SwiftyStoreKit.product3"
        let deferredProductIdentifier = "com.SwiftyStoreKit.product4"
        let purchasingProductIdentifier = "com.SwiftyStoreKit.product5"

        let transactions = [
            makeTestPaymentTransaction(productIdentifier: purchasedProductIdentifier, transactionState: .purchased),
            makeTestPaymentTransaction(productIdentifier: failedProductIdentifier, transactionState: .failed),
            makeTestPaymentTransaction(productIdentifier: restoredProductIdentifier, transactionState: .restored),
            makeTestPaymentTransaction(productIdentifier: deferredProductIdentifier, transactionState: .deferred),
            makeTestPaymentTransaction(productIdentifier: purchasingProductIdentifier, transactionState: .purchasing)
            ]

        var paymentCallbackCalled = false
        let testPayment = makeTestPayment(productIdentifier: purchasedProductIdentifier) { result in
            paymentCallbackCalled = true
            if case .purchased(let payment) = result {
                XCTAssertEqual(payment.productId, purchasedProductIdentifier)
            } else {
                XCTFail("expected purchased callback with product id")
            }
        }

        var completeTransactionsCallbackCalled = false
        let completeTransactions = CompleteTransactions(atomically: true) { payments in
            completeTransactionsCallbackCalled = true
            XCTAssertEqual(payments.count, 3)
            XCTAssertEqual(payments[0].productId, failedProductIdentifier)
            XCTAssertEqual(payments[1].productId, restoredProductIdentifier)
            XCTAssertEqual(payments[2].productId, deferredProductIdentifier)
        }

        // run
        paymentQueueController.completeTransactions(completeTransactions)

        paymentQueueController.startPayment(testPayment)

        paymentQueueController.paymentQueue(SKPaymentQueue(), updatedTransactions: transactions)
        paymentQueueController.paymentQueueRestoreCompletedTransactionsFinished(SKPaymentQueue())

        // verify
        XCTAssertTrue(paymentCallbackCalled)
        XCTAssertTrue(completeTransactionsCallbackCalled)
    }

    func testPaymentQueue_when_oneTransactionForEachState_noPayments_oneRestorePurchases_oneCompleteTransactions_then_correctCallbacksCalled() {

        // setup
        let spy = PaymentQueueSpy()

        let paymentQueueController = PaymentQueueController(paymentQueue: spy)

        let purchasedProductIdentifier = "com.SwiftyStoreKit.product1"
        let failedProductIdentifier = "com.SwiftyStoreKit.product2"
        let restoredProductIdentifier = "com.SwiftyStoreKit.product3"
        let deferredProductIdentifier = "com.SwiftyStoreKit.product4"
        let purchasingProductIdentifier = "com.SwiftyStoreKit.product5"

        let transactions = [
            makeTestPaymentTransaction(productIdentifier: purchasedProductIdentifier, transactionState: .purchased),
            makeTestPaymentTransaction(productIdentifier: failedProductIdentifier, transactionState: .failed),
            makeTestPaymentTransaction(productIdentifier: restoredProductIdentifier, transactionState: .restored),
            makeTestPaymentTransaction(productIdentifier: deferredProductIdentifier, transactionState: .deferred),
            makeTestPaymentTransaction(productIdentifier: purchasingProductIdentifier, transactionState: .purchasing)
            ]

        var restorePurchasesCallbackCalled = false
        let restorePurchases = RestorePurchases(atomically: true) { results in
            restorePurchasesCallbackCalled = true
            XCTAssertEqual(results.count, 1)
            let first = results.first!
            if case .restored(let restoredPayment) = first {
                XCTAssertEqual(restoredPayment.productId, restoredProductIdentifier)
            } else {
                XCTFail("expected restored callback with product")
            }
        }

        var completeTransactionsCallbackCalled = false
        let completeTransactions = CompleteTransactions(atomically: true) { payments in
            completeTransactionsCallbackCalled = true
            XCTAssertEqual(payments.count, 3)
            XCTAssertEqual(payments[0].productId, purchasedProductIdentifier)
            XCTAssertEqual(payments[1].productId, failedProductIdentifier)
            XCTAssertEqual(payments[2].productId, deferredProductIdentifier)
        }

        // run
        paymentQueueController.completeTransactions(completeTransactions)

        paymentQueueController.restorePurchases(restorePurchases)

        paymentQueueController.paymentQueue(SKPaymentQueue(), updatedTransactions: transactions)
        paymentQueueController.paymentQueueRestoreCompletedTransactionsFinished(SKPaymentQueue())

        // verify
        XCTAssertTrue(restorePurchasesCallbackCalled)
        XCTAssertTrue(completeTransactionsCallbackCalled)
    }
    
    // MARK: shouldAddStorePayment tests
    func testPaymentQueue_when_shouldAddStorePaymentHandlerIsNil_then_shouldAddStorePaymentReturnsFalse() {
        
        let spy = PaymentQueueSpy()
        
        let paymentQueueController = PaymentQueueController(paymentQueue: spy)
        
        paymentQueueController.shouldAddStorePaymentHandler = nil
        
        XCTAssertFalse(paymentQueueController.paymentQueue(SKPaymentQueue(), shouldAddStorePayment: SKPayment(), for: SKProduct()))
    }

    func testPaymentQueue_when_shouldAddStorePaymentHandlerReturnsTrue_then_shouldAddStorePaymentReturnsTrue() {
        
        let spy = PaymentQueueSpy()
        
        let paymentQueueController = PaymentQueueController(paymentQueue: spy)
        
        paymentQueueController.shouldAddStorePaymentHandler = { payment, product in
            return true
        }
        
        XCTAssertTrue(paymentQueueController.paymentQueue(SKPaymentQueue(), shouldAddStorePayment: SKPayment(), for: SKProduct()))
    }

    func testPaymentQueue_when_shouldAddStorePaymentHandlerReturnsFalse_then_shouldAddStorePaymentReturnsFalse() {
        
        let spy = PaymentQueueSpy()
        
        let paymentQueueController = PaymentQueueController(paymentQueue: spy)
        
        paymentQueueController.shouldAddStorePaymentHandler = { payment, product in
            return false
        }
        
        XCTAssertFalse(paymentQueueController.paymentQueue(SKPaymentQueue(), shouldAddStorePayment: SKPayment(), for: SKProduct()))
    }

    // MARK: Helpers
    func makeTestPaymentTransaction(productIdentifier: String, transactionState: SKPaymentTransactionState) -> TestPaymentTransaction {

        let testProduct = TestProduct(productIdentifier: productIdentifier)
        return TestPaymentTransaction(payment: SKPayment(product: testProduct), transactionState: transactionState)
    }

    func makeTestPayment(productIdentifier: String, quantity: Int = 1, atomically: Bool = true, callback: @escaping (TransactionResult) -> Void) -> Payment {

        let testProduct = TestProduct(productIdentifier: productIdentifier)
        return Payment(product: testProduct, paymentDiscount: nil, quantity: quantity, atomically: atomically, applicationUsername: "", simulatesAskToBuyInSandbox: false, callback: callback)
    }
}
