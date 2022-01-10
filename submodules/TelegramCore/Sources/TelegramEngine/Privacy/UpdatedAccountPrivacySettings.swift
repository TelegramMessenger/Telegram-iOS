import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit


func _internal_requestAccountPrivacySettings(account: Account) -> Signal<AccountPrivacySettings, NoError> {
    let lastSeenPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyStatusTimestamp))
    let groupPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyChatInvite))
    let voiceCallPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyPhoneCall))
    let voiceCallP2P = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyPhoneP2P))
    let profilePhotoPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyProfilePhoto))
    let forwardPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyForwards))
    let phoneNumberPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyPhoneNumber))
    let phoneDiscoveryPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyAddedByPhone))
    let autoremoveTimeout = account.network.request(Api.functions.account.getAccountTTL())
    let globalPrivacySettings = account.network.request(Api.functions.account.getGlobalPrivacySettings())
    return combineLatest(lastSeenPrivacy, groupPrivacy, voiceCallPrivacy, voiceCallP2P, profilePhotoPrivacy, forwardPrivacy, phoneNumberPrivacy, phoneDiscoveryPrivacy, autoremoveTimeout, globalPrivacySettings)
    |> `catch` { _ in
        return .complete()
    }
    |> mapToSignal { lastSeenPrivacy, groupPrivacy, voiceCallPrivacy, voiceCallP2P, profilePhotoPrivacy, forwardPrivacy, phoneNumberPrivacy, phoneDiscoveryPrivacy, autoremoveTimeout, globalPrivacySettings -> Signal<AccountPrivacySettings, NoError> in
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
        let phoneNumberRules: [Api.PrivacyRule]
        var apiUsers: [Api.User] = []
        var apiChats: [Api.Chat] = []
        
        switch lastSeenPrivacy {
            case let .privacyRules(rules, chats, users):
                apiUsers.append(contentsOf: users)
                apiChats.append(contentsOf: chats)
                lastSeenRules = rules
        }
        
        switch groupPrivacy {
            case let .privacyRules(rules, chats, users):
                apiUsers.append(contentsOf: users)
                apiChats.append(contentsOf: chats)
                groupRules = rules
        }
        
        switch voiceCallPrivacy {
            case let .privacyRules(rules, chats, users):
                apiUsers.append(contentsOf: users)
                apiChats.append(contentsOf: chats)
                voiceRules = rules
        }
        
        switch voiceCallP2P {
            case let .privacyRules(rules, chats, users):
                apiUsers.append(contentsOf: users)
                apiChats.append(contentsOf: chats)
                voiceP2PRules = rules
        }
        
        switch profilePhotoPrivacy {
            case let .privacyRules(rules, chats, users):
                apiUsers.append(contentsOf: users)
                apiChats.append(contentsOf: chats)
                profilePhotoRules = rules
        }
        
        switch forwardPrivacy {
            case let .privacyRules(rules, chats, users):
                apiUsers.append(contentsOf: users)
                apiChats.append(contentsOf: chats)
                forwardRules = rules
        }
        
        switch phoneNumberPrivacy {
            case let .privacyRules(rules, chats, users):
                apiUsers.append(contentsOf: users)
                apiChats.append(contentsOf: chats)
                phoneNumberRules = rules
        }
        
        var phoneDiscoveryValue = false
        switch phoneDiscoveryPrivacy {
            case let .privacyRules(rules, _, _):
                for rule in rules {
                    switch rule {
                    case .privacyValueAllowAll:
                        phoneDiscoveryValue = true
                    default:
                        break
                    }
                }
        }
        
        var peers: [SelectivePrivacyPeer] = []
        for user in apiUsers {
            peers.append(SelectivePrivacyPeer(peer: TelegramUser(user: user), participantCount: nil))
        }
        for chat in apiChats {
            if let peer = parseTelegramGroupOrChannel(chat: chat) {
                var participantCount: Int32? = nil
                switch chat {
                    case let .channel(_, _, _, _, _, _, _, _, _, _, _, participantsCountValue):
                        participantCount = participantsCountValue
                    default:
                        break
                }
                peers.append(SelectivePrivacyPeer(peer: peer, participantCount: participantCount))
            }
        }
        var peerMap: [PeerId: SelectivePrivacyPeer] = [:]
        for peer in peers {
            peerMap[peer.peer.id] = peer
        }
        
        let automaticallyArchiveAndMuteNonContacts: Bool
        switch globalPrivacySettings {
        case let .globalPrivacySettings(_, archiveAndMuteNewNoncontactPeers):
            if let archiveAndMuteNewNoncontactPeers = archiveAndMuteNewNoncontactPeers {
                automaticallyArchiveAndMuteNonContacts = archiveAndMuteNewNoncontactPeers == .boolTrue
            } else {
                automaticallyArchiveAndMuteNonContacts = false
            }
        }
        
        return account.postbox.transaction { transaction -> AccountPrivacySettings in
            updatePeers(transaction: transaction, peers: peers.map { $0.peer }, update: { _, updated in
                return updated
            })
            
            return AccountPrivacySettings(presence: SelectivePrivacySettings(apiRules: lastSeenRules, peers: peerMap), groupInvitations: SelectivePrivacySettings(apiRules: groupRules, peers: peerMap), voiceCalls: SelectivePrivacySettings(apiRules: voiceRules, peers: peerMap), voiceCallsP2P: SelectivePrivacySettings(apiRules: voiceP2PRules, peers: peerMap), profilePhoto: SelectivePrivacySettings(apiRules: profilePhotoRules, peers: peerMap), forwards: SelectivePrivacySettings(apiRules: forwardRules, peers: peerMap), phoneNumber: SelectivePrivacySettings(apiRules: phoneNumberRules, peers: peerMap), phoneDiscoveryEnabled: phoneDiscoveryValue, automaticallyArchiveAndMuteNonContacts: automaticallyArchiveAndMuteNonContacts, accountRemovalTimeout: accountTimeoutSeconds)
        }
    }
}

func _internal_updateAccountAutoArchiveChats(account: Account, value: Bool) -> Signal<Never, NoError> {
    return account.network.request(Api.functions.account.setGlobalPrivacySettings(
        settings: .globalPrivacySettings(flags: 1 << 0, archiveAndMuteNewNoncontactPeers: value ? .boolTrue : .boolFalse)
    ))
    |> retryRequest
    |> ignoreValues
}

func _internal_updateAccountRemovalTimeout(account: Account, timeout: Int32) -> Signal<Void, NoError> {
    return account.network.request(Api.functions.account.setAccountTTL(ttl: .accountDaysTTL(days: timeout / (24 * 60 * 60))))
        |> retryRequest
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
}

func _internal_updatePhoneNumberDiscovery(account: Account, value: Bool) -> Signal<Void, NoError> {
    var rules: [Api.InputPrivacyRule] = []
    if value {
        rules.append(.inputPrivacyValueAllowAll)
    } else {
        rules.append(.inputPrivacyValueAllowContacts)
    }
    return account.network.request(Api.functions.account.setPrivacy(key: .inputPrivacyKeyAddedByPhone, rules: rules))
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
    case phoneNumber
    
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
            case .phoneNumber:
                return .inputPrivacyKeyPhoneNumber
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

private func apiUserAndGroupIds(peerIds: [PeerId: SelectivePrivacyPeer]) -> (users: [PeerId], groups: [PeerId]) {
    var users: [PeerId] = []
    var groups: [PeerId] = []
    for (peerId, _) in peerIds {
        if peerId.namespace == Namespaces.Peer.CloudUser {
            users.append(peerId)
        } else if peerId.namespace == Namespaces.Peer.CloudGroup || peerId.namespace == Namespaces.Peer.CloudChannel {
            groups.append(peerId)
        }
    }
    return (users, groups)
}

func _internal_updateSelectiveAccountPrivacySettings(account: Account, type: UpdateSelectiveAccountPrivacySettingsType, settings: SelectivePrivacySettings) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        var rules: [Api.InputPrivacyRule] = []
        switch settings {
            case let .disableEveryone(enableFor):
                let enablePeers = apiUserAndGroupIds(peerIds: enableFor)
                
                if !enablePeers.users.isEmpty {
                    rules.append(Api.InputPrivacyRule.inputPrivacyValueAllowUsers(users: apiInputUsers(transaction: transaction, peerIds: enablePeers.users)))
                }
                if !enablePeers.groups.isEmpty {
                    rules.append(Api.InputPrivacyRule.inputPrivacyValueAllowChatParticipants(chats: enablePeers.groups.map({ $0.id._internalGetInt64Value() })))
                }
                
                rules.append(Api.InputPrivacyRule.inputPrivacyValueDisallowAll)
            case let .enableContacts(enableFor, disableFor):
                let enablePeers = apiUserAndGroupIds(peerIds: enableFor)
                let disablePeers = apiUserAndGroupIds(peerIds: disableFor)
                
                if !enablePeers.users.isEmpty {
                    rules.append(Api.InputPrivacyRule.inputPrivacyValueAllowUsers(users: apiInputUsers(transaction: transaction, peerIds: enablePeers.users)))
                }
                if !enablePeers.groups.isEmpty {
                    rules.append(Api.InputPrivacyRule.inputPrivacyValueAllowChatParticipants(chats: enablePeers.groups.map({ $0.id._internalGetInt64Value() })))
                }
                
                if !disablePeers.users.isEmpty {
                    rules.append(Api.InputPrivacyRule.inputPrivacyValueDisallowUsers(users: apiInputUsers(transaction: transaction, peerIds: disablePeers.users)))
                }
                if !disablePeers.groups.isEmpty {
                    rules.append(Api.InputPrivacyRule.inputPrivacyValueDisallowChatParticipants(chats: disablePeers.groups.map({ $0.id._internalGetInt64Value() })))
                }
            
                rules.append(Api.InputPrivacyRule.inputPrivacyValueAllowContacts)
            case let .enableEveryone(disableFor):
                let disablePeers = apiUserAndGroupIds(peerIds: disableFor)
                
                if !disablePeers.users.isEmpty {
                    rules.append(Api.InputPrivacyRule.inputPrivacyValueDisallowUsers(users: apiInputUsers(transaction: transaction, peerIds: disablePeers.users)))
                }
                if !disablePeers.groups.isEmpty {
                    rules.append(Api.InputPrivacyRule.inputPrivacyValueDisallowChatParticipants(chats: disablePeers.groups.map({ $0.id._internalGetInt64Value() })))
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
