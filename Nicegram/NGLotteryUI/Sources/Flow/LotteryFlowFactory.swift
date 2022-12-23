import Foundation
import NGAppContext
import NGCore
import NGSubscription
import UIKit

public protocol LotteryFlowFactory {
    func makeFlow(navigationController: UINavigationController) -> any LotteryFlow
}

@available(iOS 13.0, *)
public class LotteryFlowFactoryImpl {
    
    //  MARK: - Dependencies
    
    private let appContext: AppContext
    
    //  MARK: - Lifecycle
    
    public init(appContext: AppContext) {
        self.appContext = appContext
    }
}

@available(iOS 13.0, *)
extension LotteryFlowFactoryImpl: LotteryFlowFactory {
    public func makeFlow(navigationController: UINavigationController) -> any LotteryFlow {
        return LotteryFlowImpl(
            navigationController: navigationController,
            subscriptionBuilder: SubscriptionBuilderImpl(languageCode: Locale.currentAppLocale.langCode),
            splashFactory: SplashFactoryImpl(appContext: appContext),
            createTicketFactory: CreateTicketFactoryImpl(appContext: appContext)
        )
    }
}
