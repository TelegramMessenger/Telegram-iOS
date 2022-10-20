//
//  ViewController.swift
//  SwiftStoreOSXDemo
//
//  Created by phimage on 22/12/15.
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

import Cocoa
import StoreKit
import SwiftyStoreKit

enum RegisteredPurchase: String {

    case purchase1
    case purchase2
    case nonConsumablePurchase
    case consumablePurchase
    case autoRenewablePurchase
    case nonRenewingPurchase

}

class ViewController: NSViewController {

    let appBundleId = "com.musevisions.MacOS.SwiftyStoreKitDemo"

    let purchase1Suffix = RegisteredPurchase.purchase1
    let purchase2Suffix = RegisteredPurchase.autoRenewablePurchase

    // MARK: actions
    @IBAction func getInfo1(_ sender: Any?) {
        getInfo(purchase1Suffix)
    }
    @IBAction func purchase1(_ sender: Any?) {
        purchase(purchase1Suffix)
    }
    @IBAction func verifyPurchase1(_ sender: Any?) {
        verifyPurchase(purchase1Suffix)
    }

    @IBAction func getInfo2(_ sender: Any?) {
        getInfo(purchase2Suffix)
    }
    @IBAction func purchase2(_ sender: Any?) {
        purchase(purchase2Suffix)
    }
    @IBAction func verifyPurchase2(_ sender: Any?) {
        verifyPurchase(purchase2Suffix)
    }

    func getInfo(_ purchase: RegisteredPurchase) {

        SwiftyStoreKit.retrieveProductsInfo([appBundleId + "." + purchase.rawValue]) { result in

            self.showAlert(self.alertForProductRetrievalInfo(result))
        }
    }

    func purchase(_ purchase: RegisteredPurchase) {

        SwiftyStoreKit.purchaseProduct(appBundleId + "." + purchase.rawValue, atomically: true) { result in

            if case .success(let purchase) = result {
                // Deliver content from server, then:
                if purchase.needsFinishTransaction {
                    SwiftyStoreKit.finishTransaction(purchase.transaction)
                }
            }

            if let errorAlert = self.alertForPurchaseResult(result) {
                self.showAlert(errorAlert)
            }
        }
    }

    @IBAction func restorePurchases(_ sender: Any?) {

        SwiftyStoreKit.restorePurchases(atomically: true) { results in

            for purchase in results.restoredPurchases where purchase.needsFinishTransaction {
                // Deliver content from server, then:
                SwiftyStoreKit.finishTransaction(purchase.transaction)
            }

            self.showAlert(self.alertForRestorePurchases(results))
        }
    }

    @IBAction func verifyReceipt(_ sender: Any?) {

        verifyReceipt(completion: { result in
            self.showAlert(self.alertForVerifyReceipt(result))
        })
    }
    
    func verifyReceipt(completion: @escaping (VerifyReceiptResult) -> Void) {
        
        let appleValidator = AppleReceiptValidator(service: .production, sharedSecret: "your-shared-secret")
        SwiftyStoreKit.verifyReceipt(using: appleValidator, completion: completion)
    }

    func verifyPurchase(_ purchase: RegisteredPurchase) {

        verifyReceipt { result in

            switch result {
            case .success(let receipt):

                let productId = self.appBundleId + "." + purchase.rawValue

                switch purchase {
                case .autoRenewablePurchase:
                    let purchaseResult = SwiftyStoreKit.verifySubscription(
                        ofType: .autoRenewable,
                        productId: productId,
                        inReceipt: receipt)
                    self.showAlert(self.alertForVerifySubscription(purchaseResult))
                case .nonRenewingPurchase:
                    let purchaseResult = SwiftyStoreKit.verifySubscription(
                        ofType: .nonRenewing(validDuration: 60),
                        productId: productId,
                        inReceipt: receipt)
                    self.showAlert(self.alertForVerifySubscription(purchaseResult))
                default:
                    let purchaseResult = SwiftyStoreKit.verifyPurchase(
                        productId: productId,
                        inReceipt: receipt)
                    self.showAlert(self.alertForVerifyPurchase(purchaseResult))
                }

            case .error:
                self.showAlert(self.alertForVerifyReceipt(result))
            }
        }
    }
}

// MARK: User facing alerts
extension ViewController {

    func alertWithTitle(_ title: String, message: String) -> NSAlert {

        let alert: NSAlert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        return alert
    }
    func showAlert(_ alert: NSAlert, handler: ((NSApplication.ModalResponse) -> Void)? = nil) {

        if let window = NSApplication.shared.keyWindow {
            alert.beginSheetModal(for: window) { (response: NSApplication.ModalResponse) in
                handler?(response)
            }
        } else {
            let response = alert.runModal()
            handler?(response)
        }
    }

    func alertForProductRetrievalInfo(_ result: RetrieveResults) -> NSAlert {

        if let product = result.retrievedProducts.first {
            let priceString = product.localizedPrice!
            return alertWithTitle(product.localizedTitle, message: "\(product.localizedDescription) - \(priceString)")
        } else if let invalidProductId = result.invalidProductIDs.first {
            return alertWithTitle("Could not retrieve product info", message: "Invalid product identifier: \(invalidProductId)")
        } else {
            let errorString = result.error?.localizedDescription ?? "Unknown error. Please contact support"
            return alertWithTitle("Could not retrieve product info", message: errorString)
        }
    }

    func alertForPurchaseResult(_ result: PurchaseResult) -> NSAlert? {
        switch result {
        case .success(let purchase):
            print("Purchase Success: \(purchase.productId)")
            return alertWithTitle("Thank You", message: "Purchase completed")
        case .error(let error):
            print("Purchase Failed: \(error)")
            switch error.code {
            case .unknown: return alertWithTitle("Purchase failed", message: error.localizedDescription)
            case .clientInvalid: // client is not allowed to issue the request, etc.
                return alertWithTitle("Purchase failed", message: "Not allowed to make the payment")
            case .paymentCancelled: // user cancelled the request, etc.
                return nil
            case .paymentInvalid: // purchase identifier was invalid, etc.
                return alertWithTitle("Purchase failed", message: "The purchase identifier was invalid")
            case .paymentNotAllowed: // this device is not allowed to make the payment
                return alertWithTitle("Purchase failed", message: "The device is not allowed to make the payment")
            default:
                return alertWithTitle("Purchase failed", message: (error as NSError).localizedDescription)
            }
        }
    }

    func alertForRestorePurchases(_ results: RestoreResults) -> NSAlert {

        if results.restoreFailedPurchases.count > 0 {
            print("Restore Failed: \(results.restoreFailedPurchases)")
            return alertWithTitle("Restore failed", message: "Unknown error. Please contact support")
        } else if results.restoredPurchases.count > 0 {
            print("Restore Success: \(results.restoredPurchases)")
            return alertWithTitle("Purchases Restored", message: "All purchases have been restored")
        } else {
            print("Nothing to Restore")
            return alertWithTitle("Nothing to restore", message: "No previous purchases were found")
        }
    }

    func alertForVerifyReceipt(_ result: VerifyReceiptResult) -> NSAlert {

        switch result {
        case .success(let receipt):
            print("Verify receipt Success: \(receipt)")
            return self.alertWithTitle("Receipt verified", message: "Receipt verified remotely")
        case .error(let error):
            print("Verify receipt Failed: \(error)")
            switch error {
            case .noReceiptData:
                return alertWithTitle("Receipt verification", message: "No receipt data. Try again.")
            case .networkError(let error):
                return alertWithTitle("Receipt verification", message: "Network error while verifying receipt: \(error)")
            default:
                return alertWithTitle("Receipt verification", message: "Receipt verification failed: \(error)")
            }
        }
    }

    func alertForVerifySubscription(_ result: VerifySubscriptionResult) -> NSAlert {

        switch result {
        case .purchased(let expiryDate):
            print("Product is valid until \(expiryDate)")
            return alertWithTitle("Product is purchased", message: "Product is valid until \(expiryDate)")
        case .expired(let expiryDate):
            print("Product is expired since \(expiryDate)")
            return alertWithTitle("Product expired", message: "Product is expired since \(expiryDate)")
        case .notPurchased:
            print("This product has never been purchased")
            return alertWithTitle("Not purchased", message: "This product has never been purchased")
        }
    }

    func alertForVerifyPurchase(_ result: VerifyPurchaseResult) -> NSAlert {

        switch result {
        case .purchased:
            print("Product is purchased")
            return alertWithTitle("Product is purchased", message: "Product will not expire")
        case .notPurchased:
            print("This product has never been purchased")
            return alertWithTitle("Not purchased", message: "This product has never been purchased")
        }
    }
}
