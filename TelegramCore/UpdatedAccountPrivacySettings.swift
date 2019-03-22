import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func requestAccountPrivacySettings(account: Account) -> Signal<AccountPrivacySettings, NoError> {
    let lastSeenPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyStatusTimestamp))
    let groupPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyChatInvite))
    let voiceCallPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyPhoneCall))
    let voiceCallP2P = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyPhoneP2P))
    let profilePhotoPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyProfilePhoto))
    let forwardPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyForwards))
    let autoremoveTimeout = account.network.request(Api.functions.account.getAccountTTL())
    return combineLatest(lastSeenPrivacy, groupPrivacy, voiceCallPrivacy, voiceCallP2P, profilePhotoPrivacy, forwardPrivacy, autoremoveTimeout)
        |> retryRequest
        |> mapToSignal { lastSeenPrivacy, groupPrivacy, voiceCallPrivacy, voiceCallP2P, profilePhotoPrivacy, forwardPrivacy, autoremoveTimeout -> Signal<AccountPrivacySettings, NoError> in
            let accountTimeoutSeconds: Int32
            switch autoremoveTimeout {
                case let .accountDaysTTL(days):
                    accountTimeoutSeconds = days * 24 * 60 * 60
            }
            
            
            let lastSeenRules: [Api.PrivacyRule]
            let groupRules: [Api.PrivacyRule]
            let voiceRules: [Api.PrivacyRule]
            let voiceP2PRules: [Api.PrivacyRule]
            let profilePhotoRules: [Api.PrivacyRule]
            let forwardRules: [Api.PrivacyRule]
            var apiUsers: [Api.User] = []
            
            switch lastSeenPrivacy {
                case let .privacyRules(rules, users):
                    apiUsers.append(contentsOf: users)
                    lastSeenRules = rules
            }
            
            switch groupPrivacy {
                case let .privacyRules(rules, users):
                    apiUsers.append(contentsOf: users)
                    groupRules = rules
            }
            
            switch voiceCallPrivacy {
                case let .privacyRules(rules, users):
                    apiUsers.append(contentsOf: users)
                    voiceRules = rules
            }
            
            switch voiceCallP2P {
                case let .privacyRules(rules, users):
                    apiUsers.append(contentsOf: users)
                    voiceP2PRules = rules
            }
            
            switch profilePhotoPrivacy {
                case let .privacyRules(rules, users):
                    apiUsers.append(contentsOf: users)
                    profilePhotoRules = rules
            }
            
            switch forwardPrivacy {
                case let .privacyRules(rules, users):
                    apiUsers.append(contentsOf: users)
                    forwardRules = rules
            }
            
            let peers = apiUsers.map { TelegramUser(user: $0) }
            
            return account.postbox.transaction { transaction -> AccountPrivacySettings in
                updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                    return updated
                })
                
                return AccountPrivacySettings(presence: SelectivePrivacySettings(apiRules: lastSeenRules), groupInvitations: SelectivePrivacySettings(apiRules: groupRules), voiceCalls: SelectivePrivacySettings(apiRules: voiceRules), voiceCallsP2P: SelectivePrivacySettings(apiRules: voiceP2PRules), profilePhoto: SelectivePrivacySettings(apiRules: profilePhotoRules), forwards: SelectivePrivacySettings(apiRules: forwardRules), accountRemovalTimeout: accountTimeoutSeconds)
            }
        }
}

public func updateAccountRemovalTimeout(account: Account, timeout: Int32) -> Signal<Void, NoError> {
    return account.network.request(Api.functions.account.setAccountTTL(ttl: .accountDaysTTL(days: timeout / (24 * 60 * 60))))
        |> retryRequest
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
}

public enum UpdateSelectiveAccountPrivacySettingsType {
    case presence
    case groupInvitations
    case voiceCalls
    case voiceCallsP2P
    case profilePhoto
    case forwards
    
    var apiKey: Api.InputPrivacyKey {
        switch self {
            case .presence:
                return .inputPrivacyKeyStatusTimestamp
            case .groupInvitations:
                return .inputPrivacyKeyChatInvite
            case .voiceCalls:
                return .inputPrivacyKeyPhoneCall
            case .voiceCallsP2P:
                return .inputPrivacyKeyPhoneP2P
            case .profilePhoto:
                return .inputPrivacyKeyProfilePhoto
            case .forwards:
                return .inputPrivacyKeyForwards
        }
    }
}

private func apiInputUsers(transaction: Transaction, peerIds: [PeerId]) -> [Api.InputUser] {
    var result: [Api.InputUser] = []
    for peerId in peerIds {
        if let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) {
            result.append(inputUser)
        }
    }
    return result
}

public func updateSelectiveAccountPrivacySettings(account: Account, type: UpdateSelectiveAccountPrivacySettingsType, settings: SelectivePrivacySettings) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        var rules: [Api.InputPrivacyRule] = []
        switch settings {
            case let .disableEveryone(enableFor):
                if !enableFor.isEmpty {
                    rules.append(Api.InputPrivacyRule.inputPrivacyValueAllowUsers(users: apiInputUsers(transaction: transaction, peerIds: Array(enableFor))))
                }
                rules.append(Api.InputPrivacyRule.inputPrivacyValueDisallowAll)
            case let .enableContacts(enableFor, disableFor):
                if !enableFor.isEmpty {
                    rules.append(Api.InputPrivacyRule.inputPrivacyValueAllowUsers(users: apiInputUsers(transaction: transaction, peerIds: Array(enableFor))))
                }
                if !disableFor.isEmpty {
                    rules.append(Api.InputPrivacyRule.inputPrivacyValueDisallowUsers(users: apiInputUsers(transaction: transaction, peerIds: Array(disableFor))))
                }
                rules.append(Api.InputPrivacyRule.inputPrivacyValueAllowContacts)
            case let.enableEveryone(disableFor):
                if !disableFor.isEmpty {
                    rules.append(Api.InputPrivacyRule.inputPrivacyValueDisallowUsers(users: apiInputUsers(transaction: transaction, peerIds: Array(disableFor))))
                }
                rules.append(Api.InputPrivacyRule.inputPrivacyValueAllowAll)
        }
        return account.network.request(Api.functions.account.setPrivacy(key: type.apiKey, rules: rules))
        |> retryRequest
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
    }
    |> switchToLatest
}
