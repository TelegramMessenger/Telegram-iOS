//
//  ViewController.swift
//  SwiftyStoreKit
//
//  Created by Andrea Bizzotto on 03/09/2015.
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

import UIKit
import StoreKit
import SwiftyStoreKit

enum RegisteredPurchase: String {

    case purchase1
    case purchase2
    case nonConsumablePurchase
    case consumablePurchase
    case nonRenewingPurchase
    case autoRenewableWeekly
    case autoRenewableMonthly
    case autoRenewableYearly
}

class ViewController: UIViewController {

    let appBundleId = "com.musevisions.iOS.SwiftyStoreKit"
    
#if os(iOS)
    // UISwitch is unavailable on tvOS
    @IBOutlet var nonConsumableAtomicSwitch: UISwitch!
    @IBOutlet var consumableAtomicSwitch: UISwitch!
    @IBOutlet var nonRenewingAtomicSwitch: UISwitch!
    @IBOutlet var autoRenewableAtomicSwitch: UISwitch!
    var nonConsumableIsAtomic: Bool { return nonConsumableAtomicSwitch.isOn }
    var consumableIsAtomic: Bool { return consumableAtomicSwitch.isOn }
    var nonRenewingIsAtomic: Bool { return nonRenewingAtomicSwitch.isOn }
    var autoRenewableIsAtomic: Bool { return autoRenewableAtomicSwitch.isOn }
#else
    let nonConsumableIsAtomic = true
    let consumableIsAtomic = true
    let nonRenewingIsAtomic = true
    let autoRenewableIsAtomic = true
#endif
    // MARK: non consumable
    @IBAction func nonConsumableGetInfo() {
        getInfo(.nonConsumablePurchase)
    }
    @IBAction func nonConsumablePurchase() {
        purchase(.nonConsumablePurchase, atomically: nonConsumableIsAtomic)
    }
    @IBAction func nonConsumableVerifyPurchase() {
        verifyPurchase(.nonConsumablePurchase)
    }
    
    // MARK: consumable
    @IBAction func consumableGetInfo() {
        getInfo(.consumablePurchase)
    }
    @IBAction func consumablePurchase() {
        purchase(.consumablePurchase, atomically: consumableIsAtomic)
    }
    @IBAction func consumableVerifyPurchase() {
        verifyPurchase(.consumablePurchase)
    }

    // MARK: non renewing
    @IBAction func nonRenewingGetInfo() {
        getInfo(.nonRenewingPurchase)
    }
    @IBAction func nonRenewingPurchase() {
        purchase(.nonRenewingPurchase, atomically: nonRenewingIsAtomic)
    }
    @IBAction func nonRenewingVerifyPurchase() {
        verifyPurchase(.nonRenewingPurchase)
    }

    // MARK: auto renewable
#if os(iOS)
    @IBOutlet var autoRenewableSubscriptionSegmentedControl: UISegmentedControl!
    
    var autoRenewableSubscription: RegisteredPurchase {
        switch autoRenewableSubscriptionSegmentedControl.selectedSegmentIndex {
        case 0: return .autoRenewableWeekly
        case 1: return .autoRenewableMonthly
        case 2: return .autoRenewableYearly
        default: return .autoRenewableWeekly
        }
    }
#else
    let autoRenewableSubscription = RegisteredPurchase.autoRenewableWeekly
#endif
    @IBAction func autoRenewableGetInfo() {
        getInfo(autoRenewableSubscription)
    }
    @IBAction func autoRenewablePurchase() {
        purchase(autoRenewableSubscription, atomically: autoRenewableIsAtomic)
    }
    @IBAction func autoRenewableVerifyPurchase() {
        verifySubscriptions([.autoRenewableWeekly, .autoRenewableMonthly, .autoRenewableYearly])
    }

    func getInfo(_ purchase: RegisteredPurchase) {

        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.retrieveProductsInfo([appBundleId + "." + purchase.rawValue]) { result in
            NetworkActivityIndicatorManager.networkOperationFinished()

            self.showAlert(self.alertForProductRetrievalInfo(result))
        }
    }

    func purchase(_ purchase: RegisteredPurchase, atomically: Bool) {

        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.purchaseProduct(appBundleId + "." + purchase.rawValue, atomically: atomically) { result in
            NetworkActivityIndicatorManager.networkOperationFinished()

            if case .success(let purchase) = result {
                let downloads = purchase.transaction.downloads
                if !downloads.isEmpty {
                    SwiftyStoreKit.start(downloads)
                }
                // Deliver content from server, then:
                if purchase.needsFinishTransaction {
                    SwiftyStoreKit.finishTransaction(purchase.transaction)
                }
            }
            if let alert = self.alertForPurchaseResult(result) {
                self.showAlert(alert)
            }
        }
    }

    @IBAction func restorePurchases() {

        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.restorePurchases(atomically: true) { results in
            NetworkActivityIndicatorManager.networkOperationFinished()

            for purchase in results.restoredPurchases {
                let downloads = purchase.transaction.downloads
                if !downloads.isEmpty {
                    SwiftyStoreKit.start(downloads)
                } else if purchase.needsFinishTransaction {
                    // Deliver content from server, then:
                    SwiftyStoreKit.finishTransaction(purchase.transaction)
                }
            }
            self.showAlert(self.alertForRestorePurchases(results))
        }
    }

    @IBAction func verifyReceipt() {

        NetworkActivityIndicatorManager.networkOperationStarted()
        verifyReceipt { result in
            NetworkActivityIndicatorManager.networkOperationFinished()
            self.showAlert(self.alertForVerifyReceipt(result))
        }
    }
    
    func verifyReceipt(completion: @escaping (VerifyReceiptResult) -> Void) {
        
        let appleValidator = AppleReceiptValidator(service: .production, sharedSecret: "your-shared-secret")
        SwiftyStoreKit.verifyReceipt(using: appleValidator, completion: completion)
    }
    
    func verifyPurchase(_ purchase: RegisteredPurchase) {

        NetworkActivityIndicatorManager.networkOperationStarted()
        verifyReceipt { result in
            NetworkActivityIndicatorManager.networkOperationFinished()

            switch result {
            case .success(let receipt):

                let productId = self.appBundleId + "." + purchase.rawValue

                switch purchase {
                case .autoRenewableWeekly, .autoRenewableMonthly, .autoRenewableYearly:
                    let purchaseResult = SwiftyStoreKit.verifySubscription(
                        ofType: .autoRenewable,
                        productId: productId,
                        inReceipt: receipt)
                    self.showAlert(self.alertForVerifySubscriptions(purchaseResult, productIds: [productId]))
                case .nonRenewingPurchase:
                    let purchaseResult = SwiftyStoreKit.verifySubscription(
                        ofType: .nonRenewing(validDuration: 60),
                        productId: productId,
                        inReceipt: receipt)
                    self.showAlert(self.alertForVerifySubscriptions(purchaseResult, productIds: [productId]))
                default:
                    let purchaseResult = SwiftyStoreKit.verifyPurchase(
                        productId: productId,
                        inReceipt: receipt)
                    self.showAlert(self.alertForVerifyPurchase(purchaseResult, productId: productId))
                }

            case .error:
                self.showAlert(self.alertForVerifyReceipt(result))
            }
        }
    }
    
    func verifySubscriptions(_ purchases: Set<RegisteredPurchase>) {
        
        NetworkActivityIndicatorManager.networkOperationStarted()
        verifyReceipt { result in
            NetworkActivityIndicatorManager.networkOperationFinished()
            
            switch result {
            case .success(let receipt):
                let productIds = Set(purchases.map { self.appBundleId + "." + $0.rawValue })
                let purchaseResult = SwiftyStoreKit.verifySubscriptions(productIds: productIds, inReceipt: receipt)
                self.showAlert(self.alertForVerifySubscriptions(purchaseResult, productIds: productIds))
            case .error:
                self.showAlert(self.alertForVerifyReceipt(result))
            }
        }
    }

#if os(iOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
#endif
}

// MARK: User facing alerts
extension ViewController {

    func alertWithTitle(_ title: String, message: String) -> UIAlertController {

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        return alert
    }

    func showAlert(_ alert: UIAlertController) {
        guard self.presentedViewController != nil else {
            self.present(alert, animated: true, completion: nil)
            return
        }
    }

    func alertForProductRetrievalInfo(_ result: RetrieveResults) -> UIAlertController {

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

    // swiftlint:disable cyclomatic_complexity
    func alertForPurchaseResult(_ result: PurchaseResult) -> UIAlertController? {
        switch result {
        case .success(let purchase):
            print("Purchase Success: \(purchase.productId)")
            return nil
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
            case .storeProductNotAvailable: // Product is not available in the current storefront
                return alertWithTitle("Purchase failed", message: "The product is not available in the current storefront")
            case .cloudServicePermissionDenied: // user has not allowed access to cloud service information
                return alertWithTitle("Purchase failed", message: "Access to cloud service information is not allowed")
            case .cloudServiceNetworkConnectionFailed: // the device could not connect to the nework
                return alertWithTitle("Purchase failed", message: "Could not connect to the network")
            case .cloudServiceRevoked: // user has revoked permission to use this cloud service
                return alertWithTitle("Purchase failed", message: "Cloud service was revoked")
            default:
                return alertWithTitle("Purchase failed", message: (error as NSError).localizedDescription)
            }
        }
    }

    func alertForRestorePurchases(_ results: RestoreResults) -> UIAlertController {

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

    func alertForVerifyReceipt(_ result: VerifyReceiptResult) -> UIAlertController {

        switch result {
        case .success(let receipt):
            print("Verify receipt Success: \(receipt)")
            return alertWithTitle("Receipt verified", message: "Receipt verified remotely")
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

    func alertForVerifySubscriptions(_ result: VerifySubscriptionResult, productIds: Set<String>) -> UIAlertController {

        switch result {
        case .purchased(let expiryDate, let items):
            print("\(productIds) is valid until \(expiryDate)\n\(items)\n")
            return alertWithTitle("Product is purchased", message: "Product is valid until \(expiryDate)")
        case .expired(let expiryDate, let items):
            print("\(productIds) is expired since \(expiryDate)\n\(items)\n")
            return alertWithTitle("Product expired", message: "Product is expired since \(expiryDate)")
        case .notPurchased:
            print("\(productIds) has never been purchased")
            return alertWithTitle("Not purchased", message: "This product has never been purchased")
        }
    }

    func alertForVerifyPurchase(_ result: VerifyPurchaseResult, productId: String) -> UIAlertController {

        switch result {
        case .purchased:
            print("\(productId) is purchased")
            return alertWithTitle("Product is purchased", message: "Product will not expire")
        case .notPurchased:
            print("\(productId) has never been purchased")
            return alertWithTitle("Not purchased", message: "This product has never been purchased")
        }
    }
}
