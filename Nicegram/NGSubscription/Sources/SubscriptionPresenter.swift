import UIKit
import NGStrings
import SubscriptionAnalytics
import TelegramPresentationData

protocol SubscriptionPresenterInput { }

protocol SubscriptionPresenterOutput: AnyObject {
    func display(isLoading: Bool)
    func display(title: String)
    func display(premiumFeatures: [PremiumFeatureViewModel])
    func display(subscribeInfo: String)
    func display(subscription: SubscriptionViewModel)
    func display(restoreText: String)
    func display(privacyText: String)
    func display(termsText: String)
}

final class SubscriptionPresenter: SubscriptionPresenterInput {
    
    //  MARK: - VIP
    
    weak var output: SubscriptionPresenterOutput!
    
    //  MARK: - Dependencies
    
    private let languageCode: String
    
    //  MARK: - Lifecycle
    
    init(languageCode: String) {
        self.languageCode = languageCode
    }
}

extension SubscriptionPresenter: SubscriptionInteractorOutput {
    func viewDidLoad() {
        let locale = languageCode
        
        output.display(title: l("NicePremium.Title", locale))
        output.display(subscribeInfo: l("NicePremium.Renews", locale))
        output.display(restoreText: l("IAP.Common.Restore", locale).uppercased())
        output.display(privacyText: l("Nicegram.PrivacyPolicy", locale).uppercased())
        output.display(termsText: l("Nicegram.EULA", locale).uppercased())
        
        output.display(premiumFeatures: [
            PremiumFeatureViewModel(
                image: UIImage(named: "ng.translate"),
                title: l("NicePremium.Translator", locale),
                description: l("NicePremium.Translator.Desc", locale)
            ),
            PremiumFeatureViewModel(
                image: UIImage(named: "ng.speech2text"),
                title: l("Messages.SpeechToText", locale),
                description: l("NicePremium.SpeechToText.Desc", locale)
            ),
            PremiumFeatureViewModel(
                image: UIImage(named: "ng.at"),
                title: l("NicePremium.MentionAll", locale),
                description: l("NicePremium.MentionAll.Desc", locale)
            )
        ])
    }
    
    func present(subscription: Subscription) {
        let price = subscription.price
        let subscribeButtonTitle = l("NicePremium.PricePerMonth", languageCode, with: price)
        output.display(subscription: SubscriptionViewModel(
            id: subscription.identifier,
            subscribeButtonTitle: subscribeButtonTitle
        ))
    }
    
    func display(isLoading: Bool) {
        output.display(isLoading: isLoading)
    }
}
