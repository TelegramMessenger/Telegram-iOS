//
// RestorePurchasesControllerTests.swift
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

import XCTest
import StoreKit
@testable import SwiftyStoreKit

class RestorePurchasesControllerTests: XCTestCase {

    func testProcessTransactions_when_oneRestoredTransaction_then_finishesTransaction_callsCallback_noRemainingTransactions() {

        let productIdentifier = "com.SwiftyStoreKit.product1"
        let testProduct = TestProduct(productIdentifier: productIdentifier)

        let transaction = TestPaymentTransaction(payment: SKPayment(product: testProduct), transactionState: .restored)

        var callbackCalled = false
        let restorePurchases = RestorePurchases(atomically: true) { results in
            callbackCalled = true
            XCTAssertEqual(results.count, 1)
            let restored = results.first!
            if case .restored(let restoredPurchase) = restored {
                XCTAssertEqual(restoredPurchase.productId, productIdentifier)
            } else {
                XCTFail("expected restored callback with product")
            }
        }

        let restorePurchasesController = makeRestorePurchasesController(restorePurchases: restorePurchases)

        let spy = PaymentQueueSpy()

        let remainingTransactions = restorePurchasesController.processTransactions([transaction], on: spy)
        restorePurchasesController.restoreCompletedTransactionsFinished()

        XCTAssertEqual(remainingTransactions.count, 0)

        XCTAssertTrue(callbackCalled)

        XCTAssertEqual(spy.finishTransactionCalledCount, 1)
    }

    func testProcessTransactions_when_twoRestoredTransactions_oneFailedTransaction_onePurchasedTransaction_then_finishesTwoTransactions_callsCallback_twoRemainingTransaction() {

        let productIdentifier1 = "com.SwiftyStoreKit.product1"
        let testProduct1 = TestProduct(productIdentifier: productIdentifier1)
        let transaction1 = TestPaymentTransaction(payment: SKPayment(product: testProduct1), transactionState: .restored)

        let productIdentifier2 = "com.SwiftyStoreKit.product2"
        let testProduct2 = TestProduct(productIdentifier: productIdentifier2)
        let transaction2 = TestPaymentTransaction(payment: SKPayment(product: testProduct2), transactionState: .restored)

        let productIdentifier3 = "com.SwiftyStoreKit.product3"
        let testProduct3 = TestProduct(productIdentifier: productIdentifier3)
        let transaction3 = TestPaymentTransaction(payment: SKPayment(product: testProduct3), transactionState: .failed)

        let productIdentifier4 = "com.SwiftyStoreKit.product4"
        let testProduct4 = TestProduct(productIdentifier: productIdentifier4)
        let transaction4 = TestPaymentTransaction(payment: SKPayment(product: testProduct4), transactionState: .purchased)

        let transactions = [transaction1, transaction2, transaction3, transaction4]

        var callbackCalled = false
        let restorePurchases = RestorePurchases(atomically: true) { results in
            callbackCalled = true
            XCTAssertEqual(results.count, 2)
            let first = results.first!
            if case .restored(let restoredPurchase) = first {
                XCTAssertEqual(restoredPurchase.productId, productIdentifier1)
            } else {
                XCTFail("expected restored callback with product")
            }
            let last = results.last!
            if case .restored(let restoredPurchase) = last {
                XCTAssertEqual(restoredPurchase.productId, productIdentifier2)
            } else {
                XCTFail("expected restored callback with product")
            }
        }

        let restorePurchasesController = makeRestorePurchasesController(restorePurchases: restorePurchases)

        let spy = PaymentQueueSpy()

        let remainingTransactions = restorePurchasesController.processTransactions(transactions, on: spy)
        restorePurchasesController.restoreCompletedTransactionsFinished()

        XCTAssertEqual(remainingTransactions.count, 2)

        XCTAssertTrue(callbackCalled)

        XCTAssertEqual(spy.finishTransactionCalledCount, 2)
    }

    func testRestoreCompletedTransactionsFailed_callsCallbackWithError() {

        var callbackCalled = false
        let restorePurchases = RestorePurchases(atomically: true) { results in
            callbackCalled = true

            XCTAssertEqual(results.count, 1)
            let first = results.first!
            if case .failed = first {

            } else {
                XCTFail("expected failed callback with error")
            }
        }

        let restorePurchasesController = makeRestorePurchasesController(restorePurchases: restorePurchases)

        let error = NSError(domain: "SwiftyStoreKit", code: 0, userInfo: nil)

        restorePurchasesController.restoreCompletedTransactionsFailed(withError: error)

        XCTAssertTrue(callbackCalled)
    }

    func testRestoreCompletedTransactionsFinished_callsCallbackWithNoTransactions() {

        var callbackCalled = false
        let restorePurchases = RestorePurchases(atomically: true) { results in
            callbackCalled = true

            XCTAssertEqual(results.count, 0)
        }
        let restorePurchasesController = makeRestorePurchasesController(restorePurchases: restorePurchases)

        restorePurchasesController.restoreCompletedTransactionsFinished()

        XCTAssertTrue(callbackCalled)
    }

    func makeRestorePurchasesController(restorePurchases: RestorePurchases?) -> RestorePurchasesController {

        let restorePurchasesController = RestorePurchasesController()

        restorePurchasesController.restorePurchases = restorePurchases

        return restorePurchasesController
    }
}
