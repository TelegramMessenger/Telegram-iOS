//
//  PaymentQueueSpy.swift
//  SwiftyStoreKit
//
//  Created by Andrea Bizzotto on 17/01/2017.
//  Copyright © 2017 musevisions. All rights reserved.
//

import SwiftyStoreKit
import StoreKit

class PaymentQueueSpy: PaymentQueue {

    weak var observer: SKPaymentTransactionObserver?

    var payments: [SKPayment] = []

    var restoreCompletedTransactionCalledCount = 0

    var finishTransactionCalledCount = 0

    func add(_ observer: SKPaymentTransactionObserver) {

        self.observer = observer
    }
    func remove(_ observer: SKPaymentTransactionObserver) {

        if self.observer === observer {
            self.observer = nil
        }
    }

    func add(_ payment: SKPayment) {

        payments.append(payment)
    }

    func restoreCompletedTransactions(withApplicationUsername username: String?) {

        restoreCompletedTransactionCalledCount += 1
    }

    func finishTransaction(_ transaction: SKPaymentTransaction) {

        finishTransactionCalledCount += 1
    }
    
    func start(_ downloads: [SKDownload]) {
        
    }
    
    func pause(_ downloads: [SKDownload]) {
        
    }
    
    func resume(_ downloads: [SKDownload]) {
        
    }
    
    func cancel(_ downloads: [SKDownload]) {
        
    }
}
