import SubscriptionAnalytics
import UIKit
import NGEnv

typealias SubscriptionInteractorInput = SubscriptionViewControllerOutput

protocol SubscriptionInteractorOutput {
    func display(isLoading: Bool)
    func onSuccess()
}

final class SubscriptionInteractor {
    var output: SubscriptionInteractorOutput!
}

extension SubscriptionInteractor: SubscriptionInteractorInput {
    func restore() {
        output.display(isLoading: true)
        SubscriptionService.shared.restorePurchase { [weak self] _, error  in
            guard let self = self else { return }
            self.output.display(isLoading: false)
            if let error = error, !error.isEmpty {
                print(error)
            } else {
                self.output.onSuccess()
            }
        }
    }

    func purcahseProduct(id: String) {
        output.display(isLoading: true)
        SubscriptionService.shared.purchaseProduct(productID: id, completionHandler: { [weak self] success, error in
            guard let self = self else { return }
            self.output.display(isLoading: false)
            if let error = error {
                print(error)
            } else {
                self.output.onSuccess()
            }
        })
    }

    func openPrivacyPolicy() {
        guard let url = URL(string: NGENV.privacy_url) else { return }
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url)
        }
    }

    func openTerms() {
        guard let url = URL(string: NGENV.terms_url) else { return }
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url)
        }
    }
}
