import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

func _internal_updateGlobalPrivacySettings(account: Account) -> Signal<Never, NoError> {
    return account.network.request(Api.functions.account.getGlobalPrivacySettings())
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.GlobalPrivacySettings?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Never, NoError> in
        return account.postbox.transaction { transaction -> Void in
            guard let result = result else {
                return
            }
            let globalSettings: GlobalPrivacySettings
            switch result {
            case let .globalPrivacySettings(flags, nonContactPeersPaidStars, disallowedStarGifts):
                let automaticallyArchiveAndMuteNonContacts = (flags & (1 << 0)) != 0
                let keepArchivedUnmuted = (flags & (1 << 1)) != 0
                let keepArchivedFolders = (flags & (1 << 2)) != 0
                let hideReadTime = (flags & (1 << 3)) != 0
                let nonContactChatsRequirePremium = (flags & (1 << 4)) != 0
                let displayGiftButton = (flags & (1 << 7)) != 0
                
                let nonContactChatsPrivacy: GlobalPrivacySettings.NonContactChatsPrivacy
                if let nonContactPeersPaidStars, nonContactPeersPaidStars > 0 {
                    nonContactChatsPrivacy = .paidMessages(StarsAmount(value: nonContactPeersPaidStars, nanos: 0))
                } else if nonContactChatsRequirePremium {
                    nonContactChatsPrivacy = .requirePremium
                } else {
                    nonContactChatsPrivacy = .everybody
                }
                
                var disallowedGifts: TelegramDisallowedGifts = []
                if case let .disallowedGiftsSettings(giftFlags) = disallowedStarGifts {
                    if (giftFlags & (1 << 0)) != 0 {
                        disallowedGifts.insert(.unlimited)
                    }
                    if (giftFlags & (1 << 1)) != 0 {
                        disallowedGifts.insert(.limited)
                    }
                    if (giftFlags & (1 << 2)) != 0 {
                        disallowedGifts.insert(.unique)
                    }
                    if (giftFlags & (1 << 3)) != 0 {
                        disallowedGifts.insert(.premium)
                    }
                }
                
                globalSettings = GlobalPrivacySettings(
                    automaticallyArchiveAndMuteNonContacts: automaticallyArchiveAndMuteNonContacts,
                    keepArchivedUnmuted: keepArchivedUnmuted,
                    keepArchivedFolders: keepArchivedFolders,
                    hideReadTime: hideReadTime,
                    nonContactChatsPrivacy: nonContactChatsPrivacy,
                    disallowedGifts: disallowedGifts,
                    displayGiftButton: displayGiftButton
                )
            }
            updateGlobalPrivacySettings(transaction: transaction, { _ in
                return globalSettings
            })
        }
        |> ignoreValues
    }
}

func _internal_requestAccountPrivacySettings(account: Account) -> Signal<AccountPrivacySettings, NoError> {
    let lastSeenPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyStatusTimestamp))
    let groupPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyChatInvite))
    let voiceCallPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyPhoneCall))
    let voiceCallP2P = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyPhoneP2P))
    let profilePhotoPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyProfilePhoto))
    let forwardPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyForwards))
    let phoneNumberPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyPhoneNumber))
    let phoneDiscoveryPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyAddedByPhone))
    let voiceMessagesPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyVoiceMessages))
    let bioPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyAbout))
    let birthdayPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyBirthday))
    let giftsAutoSavePrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyStarGiftsAutoSave))
    let noPaidMessagesPrivacy = account.network.request(Api.functions.account.getPrivacy(key: .inputPrivacyKeyNoPaidMessages))
    
    let autoremoveTimeout = account.network.request(Api.functions.account.getAccountTTL())
    let globalPrivacySettings = account.network.request(Api.functions.account.getGlobalPrivacySettings())
    let messageAutoremoveTimeout = account.network.request(Api.functions.messages.getDefaultHistoryTTL())
    
    return combineLatest(lastSeenPrivacy, groupPrivacy, voiceCallPrivacy, voiceCallP2P, profilePhotoPrivacy, forwardPrivacy, phoneNumberPrivacy, phoneDiscoveryPrivacy, voiceMessagesPrivacy, bioPrivacy, birthdayPrivacy, giftsAutoSavePrivacy, noPaidMessagesPrivacy, autoremoveTimeout, globalPrivacySettings, messageAutoremoveTimeout)
    |> `catch` { _ in
        return .complete()
    }
    |> mapToSignal { lastSeenPrivacy, groupPrivacy, voiceCallPrivacy, voiceCallP2P, profilePhotoPrivacy, forwardPrivacy, phoneNumberPrivacy, phoneDiscoveryPrivacy, voiceMessagesPrivacy, bioPrivacy, birthdayPrivacy, giftsAutoSavePrivacy, noPaidMessagesPrivacy, autoremoveTimeout, globalPrivacySettings, messageAutoremoveTimeout -> Signal<AccountPrivacySettings, NoError> in
        let accountTimeoutSeconds: Int32
        switch autoremoveTimeout {
            case let .accountDaysTTL(days):
                accountTimeoutSeconds = days * 24 * 60 * 60
        }
        
        let messageAutoremoveSeconds: Int32?
        switch messageAutoremoveTimeout {
        case let .defaultHistoryTTL(period):
            if period != 0 {
                messageAutoremoveSeconds = period
            } else {
                messageAutoremoveSeconds = nil
            }
        }
        
        let lastSeenRules: [Api.PrivacyRule]
        let groupRules: [Api.PrivacyRule]
        let voiceRules: [Api.PrivacyRule]
        let voiceP2PRules: [Api.PrivacyRule]
        let profilePhotoRules: [Api.PrivacyRule]
        let forwardRules: [Api.PrivacyRule]
        let phoneNumberRules: [Api.PrivacyRule]
        let voiceMessagesRules: [Api.PrivacyRule]
        let bioRules: [Api.PrivacyRule]
        let birthdayRules: [Api.PrivacyRule]
        let giftsAutoSaveRules: [Api.PrivacyRule]
        let noPaidMessagesRules: [Api.PrivacyRule]
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
        
        switch voiceMessagesPrivacy {
            case let .privacyRules(rules, chats, users):
                apiUsers.append(contentsOf: users)
                apiChats.append(contentsOf: chats)
                voiceMessagesRules = rules
        }
        
        switch bioPrivacy {
            case let .privacyRules(rules, chats, users):
                apiUsers.append(contentsOf: users)
                apiChats.append(contentsOf: chats)
                bioRules = rules
        }
        
        switch birthdayPrivacy {
            case let .privacyRules(rules, chats, users):
                apiUsers.append(contentsOf: users)
                apiChats.append(contentsOf: chats)
                birthdayRules = rules
        }
        
        switch giftsAutoSavePrivacy {
            case let .privacyRules(rules, chats, users):
                apiUsers.append(contentsOf: users)
                apiChats.append(contentsOf: chats)
                giftsAutoSaveRules = rules
        }
        switch noPaidMessagesPrivacy {
            case let .privacyRules(rules, chats, users):
                apiUsers.append(contentsOf: users)
                apiChats.append(contentsOf: chats)
                noPaidMessagesRules = rules
        }
        
        var peers: [SelectivePrivacyPeer] = []
        for user in apiUsers {
            peers.append(SelectivePrivacyPeer(peer: TelegramUser(user: user), participantCount: nil))
        }
        for chat in apiChats {
            if let peer = parseTelegramGroupOrChannel(chat: chat) {
                var participantCount: Int32? = nil
                switch chat {
                    case let .channel(_, _, _, _, _, _, _, _, _, _, _, _, participantsCountValue, _, _, _, _, _, _, _, _, _, _):
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
        
        let globalSettings: GlobalPrivacySettings
        switch globalPrivacySettings {
        case let .globalPrivacySettings(flags, nonContactPeersPaidStars, disallowedStarGifts):
            let automaticallyArchiveAndMuteNonContacts = (flags & (1 << 0)) != 0
            let keepArchivedUnmuted = (flags & (1 << 1)) != 0
            let keepArchivedFolders = (flags & (1 << 2)) != 0
            let hideReadTime = (flags & (1 << 3)) != 0
            let nonContactChatsRequirePremium = (flags & (1 << 4)) != 0
            let displayGiftButton = (flags & (1 << 7)) != 0
            
            let nonContactChatsPrivacy: GlobalPrivacySettings.NonContactChatsPrivacy
            if let nonContactPeersPaidStars, nonContactPeersPaidStars > 0 {
                nonContactChatsPrivacy = .paidMessages(StarsAmount(value: nonContactPeersPaidStars, nanos: 0))
            } else if nonContactChatsRequirePremium {
                nonContactChatsPrivacy = .requirePremium
            } else {
                nonContactChatsPrivacy = .everybody
            }
            
            var disallowedGifts: TelegramDisallowedGifts = []
            if case let .disallowedGiftsSettings(giftFlags) = disallowedStarGifts {
                if (giftFlags & (1 << 0)) != 0 {
                    disallowedGifts.insert(.unlimited)
                }
                if (giftFlags & (1 << 1)) != 0 {
                    disallowedGifts.insert(.limited)
                }
                if (giftFlags & (1 << 2)) != 0 {
                    disallowedGifts.insert(.unique)
                }
                if (giftFlags & (1 << 3)) != 0 {
                    disallowedGifts.insert(.premium)
                }
            }
            
            globalSettings = GlobalPrivacySettings(
                automaticallyArchiveAndMuteNonContacts: automaticallyArchiveAndMuteNonContacts,
                keepArchivedUnmuted: keepArchivedUnmuted,
                keepArchivedFolders: keepArchivedFolders,
                hideReadTime: hideReadTime,
                nonContactChatsPrivacy: nonContactChatsPrivacy,
                disallowedGifts: disallowedGifts,
                displayGiftButton: displayGiftButton
            )
        }
        
        return account.postbox.transaction { transaction -> AccountPrivacySettings in
            updatePeersCustom(transaction: transaction, peers: peers.map { $0.peer }, update: { _, updated in
                return updated
            })
            
            updateGlobalMessageAutoremoveTimeoutSettings(transaction: transaction, { settings in
                var settings = settings
                settings.messageAutoremoveTimeout = messageAutoremoveSeconds
                return settings
            })
            
            updateGlobalPrivacySettings(transaction: transaction, { _ in
                return globalSettings
            })
            
            return AccountPrivacySettings(
                presence: SelectivePrivacySettings(apiRules: lastSeenRules, peers: peerMap),
                groupInvitations: SelectivePrivacySettings(apiRules: groupRules, peers: peerMap),
                voiceCalls: SelectivePrivacySettings(apiRules: voiceRules, peers: peerMap),
                voiceCallsP2P: SelectivePrivacySettings(apiRules: voiceP2PRules, peers: peerMap),
                profilePhoto: SelectivePrivacySettings(apiRules: profilePhotoRules, peers: peerMap),
                forwards: SelectivePrivacySettings(apiRules: forwardRules, peers: peerMap),
                phoneNumber: SelectivePrivacySettings(apiRules: phoneNumberRules, peers: peerMap),
                phoneDiscoveryEnabled: phoneDiscoveryValue,
                voiceMessages: SelectivePrivacySettings(apiRules: voiceMessagesRules, peers: peerMap),
                bio: SelectivePrivacySettings(apiRules: bioRules, peers: peerMap),
                birthday: SelectivePrivacySettings(apiRules: birthdayRules, peers: peerMap),
                giftsAutoSave: SelectivePrivacySettings(apiRules: giftsAutoSaveRules, peers: peerMap),
                noPaidMessages: SelectivePrivacySettings(apiRules: noPaidMessagesRules, peers: peerMap),
                globalSettings: globalSettings,
                accountRemovalTimeout: accountTimeoutSeconds,
                messageAutoremoveTimeout: messageAutoremoveSeconds
            )
        }
    }
}

func _internal_updateAccountAutoArchiveChats(account: Account, value: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> GlobalPrivacySettings in
        return fetchGlobalPrivacySettings(transaction: transaction)
    }
    |> mapToSignal { settings -> Signal<Never, NoError> in
        var settings = settings
        settings.automaticallyArchiveAndMuteNonContacts = value
        return _internal_updateGlobalPrivacySettings(account: account, settings: settings)
    }
}

func _internal_updateNonContactChatsPrivacy(account: Account, value: GlobalPrivacySettings.NonContactChatsPrivacy) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> GlobalPrivacySettings in
        return fetchGlobalPrivacySettings(transaction: transaction)
    }
    |> mapToSignal { settings -> Signal<Never, NoError> in
        var settings = settings
        settings.nonContactChatsPrivacy = value
        return _internal_updateGlobalPrivacySettings(account: account, settings: settings)
    }
}

func _internal_updateAccountKeepArchivedFolders(account: Account, value: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> GlobalPrivacySettings in
        return fetchGlobalPrivacySettings(transaction: transaction)
    }
    |> mapToSignal { settings -> Signal<Never, NoError> in
        var settings = settings
        settings.keepArchivedFolders = value
        return _internal_updateGlobalPrivacySettings(account: account, settings: settings)
    }
}

func _internal_updateAccountKeepArchivedUnmuted(account: Account, value: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> GlobalPrivacySettings in
        return fetchGlobalPrivacySettings(transaction: transaction)
    }
    |> mapToSignal { settings -> Signal<Never, NoError> in
        var settings = settings
        settings.keepArchivedUnmuted = value
        return _internal_updateGlobalPrivacySettings(account: account, settings: settings)
    }
}

func _internal_updateGlobalPrivacySettings(account: Account, settings: GlobalPrivacySettings) -> Signal<Never, NoError> {
    let _ = (account.postbox.transaction { transaction -> Void in
        updateGlobalPrivacySettings(transaction: transaction, { _ in
            return settings
        })
    }).start()
    
    var flags: Int32 = 0
    if settings.automaticallyArchiveAndMuteNonContacts {
        flags |= 1 << 0
    }
    if settings.keepArchivedUnmuted {
        flags |= 1 << 1
    }
    if settings.keepArchivedFolders {
        flags |= 1 << 2
    }
    if settings.hideReadTime {
        flags |= 1 << 3
    }
    if settings.displayGiftButton {
        flags |= 1 << 7
    }
    
    var noncontactPeersPaidStars: Int64?
    switch settings.nonContactChatsPrivacy {
    case .everybody:
        flags |= 1 << 5
        noncontactPeersPaidStars = 0
    case .requirePremium:
        flags |= 1 << 4
    case let .paidMessages(starsAmount):
        flags |= 1 << 5
        noncontactPeersPaidStars = starsAmount.value
    }
    
    var giftFlags: Int32 = 0
    if !settings.disallowedGifts.isEmpty {
        if settings.disallowedGifts.contains(.unlimited) {
            giftFlags |= 1 << 0
        }
        if settings.disallowedGifts.contains(.limited) {
            giftFlags |= 1 << 1
        }
        if settings.disallowedGifts.contains(.unique) {
            giftFlags |= 1 << 2
        }
        if settings.disallowedGifts.contains(.premium) {
            giftFlags |= 1 << 3
        }
    }
    flags |= 1 << 6
    let disallowedStargifts = Api.DisallowedGiftsSettings.disallowedGiftsSettings(flags: giftFlags)
    
    return account.network.request(Api.functions.account.setGlobalPrivacySettings(
        settings: .globalPrivacySettings(flags: flags, noncontactPeersPaidStars: noncontactPeersPaidStars, disallowedGifts: disallowedStargifts)
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

func _internal_updateMessageRemovalTimeout(account: Account, timeout: Int32?) -> Signal<Void, NoError> {
    let _ = account.postbox.transaction({ transaction -> Void in
        updateGlobalMessageAutoremoveTimeoutSettings(transaction: transaction, { settings in
            var settings = settings
            settings.messageAutoremoveTimeout = timeout
            return settings
        })
    }).start()
    
    return account.network.request(Api.functions.messages.setDefaultHistoryTTL(period: timeout ?? 0))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
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
    case voiceMessages
    case bio
    case birthday
    case giftsAutoSave
    case noPaidMessages
    
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
            case .voiceMessages:
                return .inputPrivacyKeyVoiceMessages
            case .bio:
                return .inputPrivacyKeyAbout
            case .birthday:
                return .inputPrivacyKeyBirthday
            case .giftsAutoSave:
                return .inputPrivacyKeyStarGiftsAutoSave
            case .noPaidMessages:
                return .inputPrivacyKeyNoPaidMessages
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
            case let .disableEveryone(enableFor, enableForCloseFriends, enableForPremium, enableForBots):
                let enablePeers = apiUserAndGroupIds(peerIds: enableFor)
                
                if !enablePeers.users.isEmpty {
                    rules.append(Api.InputPrivacyRule.inputPrivacyValueAllowUsers(users: apiInputUsers(transaction: transaction, peerIds: enablePeers.users)))
                }
                if !enablePeers.groups.isEmpty {
                    rules.append(Api.InputPrivacyRule.inputPrivacyValueAllowChatParticipants(chats: enablePeers.groups.map({ $0.id._internalGetInt64Value() })))
                }
                
                rules.append(Api.InputPrivacyRule.inputPrivacyValueDisallowAll)
                if enableForCloseFriends {
                    rules.append(.inputPrivacyValueAllowCloseFriends)
                }
                if enableForPremium {
                    rules.append(.inputPrivacyValueAllowPremium)
                }
                if enableForBots {
                    rules.append(.inputPrivacyValueAllowBots)
                }
            case let .enableContacts(enableFor, disableFor, enableForPremium, enableForBots):
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
                if enableForPremium {
                    rules.append(.inputPrivacyValueAllowPremium)
                }
                if enableForBots {
                    rules.append(.inputPrivacyValueAllowBots)
                }
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
