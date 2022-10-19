import SubscriptionAnalytics
import UIKit
import NGEnv
import NGIAP

public struct SubscriptionHandlers {
    let onSuccessPurchase: () -> Void
    let onSuccessRestore: () -> Void
    let onClose: () -> Void
    
    public init(onSuccessPurchase: @escaping () -> Void, onSuccessRestore: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.onSuccessPurchase = onSuccessRestore
        self.onSuccessRestore = onSuccessRestore
        self.onClose = onClose
    }
}

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
    
    //  MARK: - Logic
    
    private let handlers: SubscriptionHandlers
    
    //  MARK: - Lifecycle
    
    init(subscriptionService: SubscriptionService, handlers: SubscriptionHandlers) {
        self.subscriptionService = subscriptionService
        self.handlers = handlers
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
                    self.handlers.onSuccessPurchase()
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
                    self.handlers.onSuccessRestore()
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
        self.handlers.onClose()
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
