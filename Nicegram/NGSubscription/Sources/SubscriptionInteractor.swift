import SubscriptionAnalytics
import UIKit
import NGEnv
import NGIAP

typealias SubscriptionInteractorInput = SubscriptionViewControllerOutput

protocol SubscriptionInteractorOutput {
    func viewDidLoad()
    func present(subscription: Subscription)
    func display(isLoading: Bool)
}

final class SubscriptionInteractor {
    
    //  MARK: - VIP
    
    var output: SubscriptionInteractorOutput!
    var router: SubscriptionRouterInput!
    
    //  MARK: - Dependencies
    
    private let subscriptionService: SubscriptionService
    
    //  MARK: - Lifecycle
    
    init(subscriptionService: SubscriptionService) {
        self.subscriptionService = subscriptionService
    }
    
    //  MARK: - Private Functions

    private func purchase(productId id: String) {
        output.display(isLoading: true)
        
        subscriptionService.purchaseProduct(productID: id) { [weak self] success, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.output.display(isLoading: false)
                if let error = error {
                    print(error)
                } else {
                    self.router.dismiss()
                }
            }
        }
    }
    
    private func restore() {
        output.display(isLoading: true)
        
        subscriptionService.restorePurchase { [weak self] _, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.output.display(isLoading: false)
                if let error = error, !error.isEmpty {
                    print(error)
                } else {
                    self.router.dismiss()
                }
            }
        }
    }
}

extension SubscriptionInteractor: SubscriptionInteractorInput {
    func viewDidLoad() {
        output.viewDidLoad()
        
        if let subscription = subscriptionService.subscription(for: NicegramProducts.Premium) {
            output.present(subscription: subscription)
        }
    }
    
    func requestClose() {
        router.dismiss()
    }
    
    func requestPurchase(id: String) {
        purchase(productId: id)
    }
    
    func requestRestore() {
        restore()
    }
    
    func requestPrivacyPolicy() {
        guard let url = URL(string: NGENV.privacy_url) else { return }
        UIApplication.shared.openURL(url)
    }
    
    func requestTermsOfUse() {
        guard let url = URL(string: NGENV.terms_url) else { return }
        UIApplication.shared.openURL(url)
    }
}
