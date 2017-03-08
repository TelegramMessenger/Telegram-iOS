import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func updatedAccountPrivacySettings(account: Account) -> Signal<AccountPrivacySettings, NoError> {
    let lastSeenPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyStatusTimestamp))
    let groupPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyChatInvite))
    let voiceCallPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyPhoneCall))
    let autoremoveTimeout = account.network.request(Api.functions.account.getAccountTTL())
    return combineLatest(lastSeenPrivacy, groupPrivacy, voiceCallPrivacy, autoremoveTimeout)
        |> retryRequest
        |> map { lastSeenPrivacy, groupPrivacy, voiceCallPrivacy, autoremoveTimeout -> AccountPrivacySettings in
            let accountTimeoutSeconds: Int32
            switch autoremoveTimeout {
                case let .accountDaysTTL(days):
                    accountTimeoutSeconds = days * 24 * 60 * 60
            }
            return AccountPrivacySettings(presence: .enableEveryone(disableFor: Set()), groupInvitations: .enableEveryone(disableFor: Set()), voiceCalls: .enableEveryone(disableFor: Set()), accountRemovalTimeout: accountTimeoutSeconds)
        }
}
