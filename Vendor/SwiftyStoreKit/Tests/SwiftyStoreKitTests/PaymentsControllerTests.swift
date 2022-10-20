//
// PaymentsControllerTests.swift
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

class PaymentsControllerTests: XCTestCase {

    func testInsertPayment_hasPayment() {

        let payment = makeTestPayment(productIdentifier: "com.SwiftyStoreKit.product1") { _ in }

        let paymentsController = makePaymentsController(appendPayments: [payment])

        XCTAssertTrue(paymentsController.hasPayment(payment))
    }

    func testProcessTransaction_when_onePayment_transactionStatePurchased_then_removesPayment_finishesTransaction_callsCallback() {

        let productIdentifier = "com.SwiftyStoreKit.product1"
        let testProduct = TestProduct(productIdentifier: productIdentifier)

        var callbackCalled = false
        let payment = makeTestPayment(product: testProduct) { result in

            callbackCalled = true
            if case .purchased(let payment) = result {
                XCTAssertEqual(payment.productId, productIdentifier)
                XCTAssertEqual(payment.quantity, 1)
            } else {
                XCTFail("expected purchased callback with product id")
            }
        }

        let paymentsController = makePaymentsController(appendPayments: [payment])

        let transaction = TestPaymentTransaction(payment: SKPayment(product: testProduct), transactionState: .purchased)

        let spy = PaymentQueueSpy()

        let remainingTransactions = paymentsController.processTransactions([transaction], on: spy)

        XCTAssertEqual(remainingTransactions.count, 0)

        XCTAssertFalse(paymentsController.hasPayment(payment))

        XCTAssertTrue(callbackCalled)

        XCTAssertEqual(spy.finishTransactionCalledCount, 1)
    }

    func testProcessTransaction_when_onePayment_transactionStateFailed_then_removesPayment_finishesTransaction_callsCallback() {

        let productIdentifier = "com.SwiftyStoreKit.product1"
        let testProduct = TestProduct(productIdentifier: productIdentifier)

        var callbackCalled = false
        let payment = makeTestPayment(product: testProduct) { result in

            callbackCalled = true
            if case .failed = result {

            } else {
                XCTFail("expected failed callback with error")
            }
        }

        let paymentsController = makePaymentsController(appendPayments: [payment])

        let transaction = TestPaymentTransaction(payment: SKPayment(product: testProduct), transactionState: .failed)

        let spy = PaymentQueueSpy()

        let remainingTransactions = paymentsController.processTransactions([transaction], on: spy)

        XCTAssertEqual(remainingTransactions.count, 0)

        XCTAssertFalse(paymentsController.hasPayment(payment))

        XCTAssertTrue(callbackCalled)

        XCTAssertEqual(spy.finishTransactionCalledCount, 1)
    }

    func testProcessTransaction_when_twoPaymentsSameId_firstTransactionStatePurchased_secondTransactionStateFailed_then_removesPayments_finishesTransactions_callsCallbacks() {

        let productIdentifier = "com.SwiftyStoreKit.product1"
        let testProduct1 = TestProduct(productIdentifier: productIdentifier)

        var callback1Called = false
        let payment1 = makeTestPayment(product: testProduct1) { result in

            callback1Called = true
            if case .purchased(let payment) = result {
                XCTAssertEqual(payment.productId, productIdentifier)
            } else {
                XCTFail("expected purchased callback with product id")
            }
        }

        let testProduct2 = TestProduct(productIdentifier: productIdentifier)

        var callback2Called = false
        let payment2 = makeTestPayment(product: testProduct2) { result in
            callback2Called = true
            if case .failed = result {

            } else {
                XCTFail("expected failed callback with error")
            }
        }

        let paymentsController = makePaymentsController(appendPayments: [payment1, payment2])

        let transaction1 = TestPaymentTransaction(payment: SKPayment(product: testProduct1), transactionState: .purchased)
        let transaction2 = TestPaymentTransaction(payment: SKPayment(product: testProduct2), transactionState: .failed)

        let spy = PaymentQueueSpy()

        let remainingTransactions = paymentsController.processTransactions([transaction1, transaction2], on: spy)

        XCTAssertEqual(remainingTransactions.count, 0)

        XCTAssertFalse(paymentsController.hasPayment(payment1))
        XCTAssertFalse(paymentsController.hasPayment(payment2))

        XCTAssertTrue(callback1Called)
        XCTAssertTrue(callback2Called)

        XCTAssertEqual(spy.finishTransactionCalledCount, 2)
    }

    func testProcessTransaction_when_twoPaymentsSameId_firstPayment_transactionStatePurchased_then_removesFirstPayment_finishesTransaction_callsCallback() {

        let productIdentifier = "com.SwiftyStoreKit.product1"
        let testProduct1 = TestProduct(productIdentifier: productIdentifier)

        var callback1Called = false
        let payment1 = makeTestPayment(product: testProduct1) { result in

            callback1Called = true
            if case .purchased(let payment) = result {
                XCTAssertEqual(payment.productId, productIdentifier)
            } else {
                XCTFail("expected purchased callback with product id")
            }
        }

        let testProduct2 = TestProduct(productIdentifier: productIdentifier)
        let payment2 = makeTestPayment(product: testProduct2) { _ in

            XCTFail("unexpected callback for second payment")
        }

        let paymentsController = makePaymentsController(appendPayments: [payment1, payment2])

        let transaction1 = TestPaymentTransaction(payment: SKPayment(product: testProduct1), transactionState: .purchased)

        let spy = PaymentQueueSpy()

        let remainingTransactions = paymentsController.processTransactions([transaction1], on: spy)

        XCTAssertEqual(remainingTransactions.count, 0)

        // First one removed, but second one with same identifier still there
        XCTAssertTrue(paymentsController.hasPayment(payment2))

        XCTAssertTrue(callback1Called)

        XCTAssertEqual(spy.finishTransactionCalledCount, 1)
    }
    
    func testProcessTransaction_when_onePayment_transactionStatePurchased_quantityIs2_then_removesPayment_finishesTransaction_callsCallback_correctQuantity() {
        
        let productIdentifier = "com.SwiftyStoreKit.product1"
        let quantity = 2
        let testProduct = TestProduct(productIdentifier: productIdentifier)
        
        var callbackCalled = false
        let payment = makeTestPayment(product: testProduct) { result in
            
            callbackCalled = true
            if case .purchased(let payment) = result {
                XCTAssertEqual(payment.productId, productIdentifier)
                XCTAssertEqual(payment.quantity, quantity)
            } else {
                XCTFail("expected purchased callback with product id")
            }
        }
        
        let paymentsController = makePaymentsController(appendPayments: [payment])
        
        let skPayment = SKMutablePayment(product: testProduct)
        skPayment.quantity = quantity
        let transaction = TestPaymentTransaction(payment: skPayment, transactionState: .purchased)
        
        let spy = PaymentQueueSpy()
        
        let remainingTransactions = paymentsController.processTransactions([transaction], on: spy)
        
        XCTAssertEqual(remainingTransactions.count, 0)
        
        XCTAssertFalse(paymentsController.hasPayment(payment))
        
        XCTAssertTrue(callbackCalled)
        
        XCTAssertEqual(spy.finishTransactionCalledCount, 1)
    }

    func makePaymentsController(appendPayments payments: [Payment]) -> PaymentsController {

        let paymentsController = PaymentsController()

        payments.forEach { paymentsController.append($0) }

        return paymentsController
    }

    func makeTestPayment(product: SKProduct, atomically: Bool = true, callback: @escaping (TransactionResult) -> Void) -> Payment {

        return Payment(product: product, paymentDiscount: nil, quantity: 1, atomically: atomically, applicationUsername: "", simulatesAskToBuyInSandbox: false, callback: callback)
    }

    func makeTestPayment(productIdentifier: String, atomically: Bool = true, callback: @escaping (TransactionResult) -> Void) -> Payment {

        let product = TestProduct(productIdentifier: productIdentifier)
        return makeTestPayment(product: product, atomically: atomically, callback: callback)

    }
}
