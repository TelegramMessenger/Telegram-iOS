import UIKit
import SwiftyStoreKit
import StoreKit
import NGAppCache

public final class PromotionalSubscriptionsController {
    private var isStoreTransactionStarted = false

    public func startHandlingPurchaseTransacationRequest() {
        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self else { return }

            // LoadingIndicator.shared.start()
            sSelf.isStoreTransactionStarted = true
        }
    }

    public func finishAppstoreTransactionRequestIfNeeded(purchases: [Purchase]) {
        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self, sSelf.isStoreTransactionStarted else { return }

            // LoadingIndicator.shared.stop()
            sSelf.isStoreTransactionStarted = false

            for purchase in purchases {
                switch purchase.transaction.transactionState {
                case .purchased, .restored:
                    AppCache.currentProductID = purchase.productId
                    MobySubscriptionAnalytics.validateReciept()
                    // CommonAnalyticsTracker.logEvent(.subscription_purchased, parameters: ["source": "promo_in_app", "product_id": purchase.productId])

                default: break
                }
            }
        }
    }
}

public typealias ProductsRequestCompletionHandler = (_ error: Error?) -> Void
public typealias PurchaseCompletionHandler = (_ success: Bool, _ errorDescription: String?) -> Void

public final class SubscriptionService: NSObject {
    public static let shared = SubscriptionService()

    private(set) var subscriptions = Subscription.subscriptions
    private let promotionalHandler = PromotionalSubscriptionsController()

    public func setup() {
        let ids = Set(Subscription.subscriptions.map { $0.identifier })

        SwiftyStoreKit.shouldAddStorePaymentHandler = { (_ payment: SKPayment, _ product: SKProduct) in
            DispatchQueue.main.async { [weak self] in
                guard let sSelf = self else { return }

                sSelf.promotionalHandler.startHandlingPurchaseTransacationRequest()
            }
            return true
        }

        SubscriptionService.shared.loadSubscriptionOptions(ids: ids)

        SwiftyStoreKit.completeTransactions(atomically: true) { [weak self] purchases in
            guard let sSelf = self else { return }

            DispatchQueue.main.async {
                sSelf.promotionalHandler.finishAppstoreTransactionRequestIfNeeded(purchases: purchases)
            }

            for purchase in purchases {
                switch purchase.transaction.transactionState {
                case .purchased, .restored:
                    if purchase.needsFinishTransaction {
                        SwiftyStoreKit.finishTransaction(purchase.transaction)
                    }

                case .failed, .purchasing, .deferred:
                    break

                @unknown default: break
                }
            }
        }
    }

    public func subscription(for id: String) -> Subscription? {
        return subscriptions.first(where: { $0.identifier == id })
    }

    public func loadSubscriptionOptions(ids: Set<String>, completionHandler: ProductsRequestCompletionHandler? = nil) {
        SwiftyStoreKit.retrieveProductsInfo(ids) { [weak self] result in
            if result.error == nil {
                self?.subscriptions = result.retrievedProducts.map { Subscription(product: $0) }
            }
            completionHandler?(result.error)
        }
    }

    public func purchaseProduct(productID: String, completionHandler: @escaping PurchaseCompletionHandler) {
        SwiftyStoreKit.purchaseProduct(productID, atomically: true) { [weak self] result in
            guard let sSelf = self else { return }

            switch result {
            case .success(let purchase):
                if purchase.needsFinishTransaction {
                    SwiftyStoreKit.finishTransaction(purchase.transaction)
                }

                AppCache.currentProductID = productID
                completionHandler(true,nil)

                MobySubscriptionAnalytics.validateReciept { result in }

            case .error(let error):
                let errorString = sSelf.purchaseFailDescription(for: error)
                completionHandler(false, errorString)
            default:
                return completionHandler(false, nil)
            }
        }
    }

    public func priceNumberValue(for subscriptionID: String) -> Double? {
        let subscription = subscriptions.first(where: { $0.identifier == subscriptionID }) ?? Subscription.subscriptions.first(where: { $0.identifier == subscriptionID })

        if let product = subscription?.product {
            return product.price.doubleValue
        } else if let priceNumberValue = Subscription.cachedPriceNumberValue(for: subscriptionID) {
            return priceNumberValue
        } else {
            return nil
        }
    }

    public func priceCurrencySymbol(for subscriptionID: String) -> String? {
        let subscription = subscriptions.first(where: { $0.identifier == subscriptionID }) ?? Subscription.subscriptions.first(where: { $0.identifier == subscriptionID })

        if let symbol = subscription?.product?.priceLocale.currencySymbol {
            return symbol.replacingOccurrences(of: "USD", with: "")
        } else if let symbol = Subscription.cachedCurrencySymbol(for: subscriptionID) {
            return symbol
        } else {
            return nil
        }
    }

    private func purchaseFailDescription(for error: SKError) -> String {
        var errorDescription = ""

        switch error.code {
        case .unknown:
            errorDescription = error.localizedDescription
            break

        case .clientInvalid:
            errorDescription = NSLocalizedString("not allowed to payment", comment: "")

        case .paymentCancelled:
            break

        case .paymentInvalid:
            errorDescription = NSLocalizedString("purchase identifier invalid", comment: "")

        case .paymentNotAllowed:
            errorDescription = NSLocalizedString("device not allowed payment", comment: "")

        case .storeProductNotAvailable:
            errorDescription = NSLocalizedString("product not available", comment: "")

        case .cloudServicePermissionDenied:
            errorDescription = NSLocalizedString("Access to cloud", comment: "")

        case .cloudServiceNetworkConnectionFailed:
            errorDescription = NSLocalizedString("Could not network", comment: "")

        case .cloudServiceRevoked:
            errorDescription = NSLocalizedString("User has revoked permission", comment: "")

        default:
            errorDescription = (error as NSError).localizedDescription
        }

        let errorString = errorDescription // UIApplication.isInternetAvailable ? errorDescription : NSLocalizedString("Could not network", comment: "")

        return errorString
    }

    public func price(for subscriptionId: String) -> String {
        guard let subsciption = subscriptions.first(where: { $0.identifier == subscriptionId }) else {
            return Subscription.subscriptions.first(where: { $0.identifier == subscriptionId })?.price ?? ""
        }
        return subsciption.price.replacingOccurrences(of: "USD", with: "")
    }

    public func restorePurchase(completionHandler: @escaping PurchaseCompletionHandler) {
        SwiftyStoreKit.restorePurchases(atomically: true) { [weak self] results in
            if results.restoreFailedPurchases.count > 0 {
                // let errorString = UIApplication.isInternetAvailable ? "Restore failed" : NSLocalizedString("Could not network", comment: "")
                completionHandler(false, "Restore failed")
            } else if results.restoredPurchases.count > 0 {
                self?.verifyProducts(purchases: results.restoredPurchases, completionHandler: { (succces, errorDescription) in
                    completionHandler(succces, errorDescription)
                })
            } else {
                completionHandler(false, "No valid purchase")
            }
        }
    }

    public func verifyProducts(purchases: [Purchase], completionHandler: PurchaseCompletionHandler? = nil) {
        MobySubscriptionAnalytics.validateReciept { result in
            switch result {
            case let .success(info):
                for product in info.transactions {
                    if [RenewableProductDetails.Status.active, RenewableProductDetails.Status.trial].contains(product.status),
                       purchases.contains(where: { $0.productId == product.productID }) {
                        AppCache.currentProductID = product.productID
                        completionHandler?(true,nil)
                        return
                    }
                }

                completionHandler?(false, NSLocalizedString("No valid purchase", comment: ""))
            case let .failure(error):
                completionHandler?(false, "\( NSLocalizedString("Receipt verification failed", comment: "")): \(error)")
            }
        }
    }
}
