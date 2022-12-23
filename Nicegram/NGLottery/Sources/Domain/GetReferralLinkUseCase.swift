import Foundation
import NGEnv
import NGUtils

public protocol GetReferralLinkUseCase {
    func getReferralLink() -> URL?
}

public class GetReferralLinkUseCaseImpl {
    
    //  MARK: - Dependencies
    
    
    
    //  MARK: - Lifecycle
    
    public init() {}
    
}

extension GetReferralLinkUseCaseImpl: GetReferralLinkUseCase {
    public func getReferralLink() -> URL? {
        return makeBotUrl(domain: NGENV.lottery_referral_bot, startParam: "")
    }
}
