import Display
import Foundation
import UIKit
import NGData
import NGStrings
import NGSubscription
import NGUIUtils

public func onboardingController(languageCode: String, onComplete: @escaping () -> Void) -> UIViewController {
    var routeToSubscription: (() -> Void)?
    
    let controller = OnboardingViewController(
        items: onboardingPages(languageCode: languageCode),
        languageCode: languageCode,
        onComplete: {
            if isPremium() {
                onComplete()
            } else {
                routeToSubscription?()
            }
        }
    )
    
    routeToSubscription = { [weak controller] in
        let c = subscriptionController(onComplete: onComplete)
        c.modalPresentationStyle = .fullScreen
        controller?.present(c, animated: true)
    }
    
    return controller
}

private func subscriptionController(onComplete: @escaping () -> Void) -> UIViewController {
    let builder: SubscriptionBuilder = SubscriptionBuilderImpl(languageCode: Locale.currentAppLocale.langCode)
    let controller = builder.build(
        handlers: SubscriptionHandlers(
            onSuccessPurchase: onComplete,
            onSuccessRestore: onComplete,
            onClose: onComplete
        )
    )
    
    return controller
}

private func onboardingPages(languageCode: String) -> [OnboardingPageViewModel] {
    (1...5).map { index in
        OnboardingPageViewModel(
            title: l("NicegramOnboarding.\(index).Title", languageCode),
            description: l("NicegramOnboarding.\(index).Desc", languageCode),
            videoURL: Bundle.main.url(forResource: "Nicegram_Onboarding-DS_v\(index)", withExtension: "mp4")!
        )
    }
}
