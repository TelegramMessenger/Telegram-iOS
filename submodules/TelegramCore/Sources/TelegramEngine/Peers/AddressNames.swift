import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public enum AddressNameFormatError {
    case startsWithUnderscore
    case endsWithUnderscore
    case startsWithDigit
    case tooShort
    case invalidCharacters
}

public enum AddressNameAvailability: Equatable {
    case available
    case invalid
    case taken
    case purchaseAvailable
}

public enum AddressNameDomain {
    case account
    case peer(PeerId)
    case bot(PeerId)
    case theme(TelegramTheme)
}

func _internal_checkAddressNameFormat(_ value: String, canEmpty: Bool = false) -> AddressNameFormatError? {
    var index = 0
    let length = value.count
    for char in value {
        if char == "_" {
            if index == 0 {
                return .startsWithUnderscore
            } else if index == length - 1 {
                return length < 4 ? .tooShort : .endsWithUnderscore
            }
        }
        if index == 0 && char >= "0" && char <= "9" {
            return .startsWithDigit
        }
        if (!((char >= "a" && char <= "z") || (char >= "A" && char <= "Z") || (char >= "0" && char <= "9") || char == "_")) {
            return .invalidCharacters
        }
        index += 1
    }
    
    if length < 4 && (!canEmpty || length != 0) {
        return .tooShort
    }
    return nil
}

func _internal_addressNameAvailability(account: Account, domain: AddressNameDomain, name: String) -> Signal<AddressNameAvailability, NoError> {
    return account.postbox.transaction { transaction -> Signal<AddressNameAvailability, NoError> in
        switch domain {
        case .account:
            return account.network.request(Api.functions.account.checkUsername(username: name))
            |> map { result -> AddressNameAvailability in
                switch result {
                    case .boolTrue:
                        return .available
                    case .boolFalse:
                        return .taken
                }
            }
            |> `catch` { error -> Signal<AddressNameAvailability, NoError> in
                if error.errorDescription == "USERNAME_PURCHASE_AVAILABLE" {
                    return .single(.purchaseAvailable)
                } else {
                    return .single(.invalid)
                }
            }
        case let .peer(peerId):
            if let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
                return account.network.request(Api.functions.channels.checkUsername(channel: inputChannel, username: name))
                |> map { result -> AddressNameAvailability in
                    switch result {
                        case .boolTrue:
                            return .available
                        case .boolFalse:
                            return .taken
                    }
                }
                |> `catch` { error -> Signal<AddressNameAvailability, NoError> in
                    if error.errorDescription == "USERNAME_PURCHASE_AVAILABLE" {
                        return .single(.purchaseAvailable)
                    } else {
                        return .single(.invalid)
                    }
                }
            } else if peerId.namespace == Namespaces.Peer.CloudGroup {
                return account.network.request(Api.functions.channels.checkUsername(channel: .inputChannelEmpty, username: name))
                |> map { result -> AddressNameAvailability in
                    switch result {
                        case .boolTrue:
                            return .available
                        case .boolFalse:
                            return .taken
                    }
                }
                |> `catch` { error -> Signal<AddressNameAvailability, NoError> in
                    if error.errorDescription == "USERNAME_PURCHASE_AVAILABLE" {
                        return .single(.purchaseAvailable)
                    } else {
                        return .single(.invalid)
                    }
                }
            } else {
                return .single(.invalid)
            }
        case .bot:
            return .single(.invalid)
        case .theme:
            return account.network.request(Api.functions.account.createTheme(flags: 0, slug: name, title: "", document: .inputDocumentEmpty, settings: nil))
            |> map { _ -> AddressNameAvailability in
                return .available
            }
            |> `catch` { error -> Signal<AddressNameAvailability, NoError> in
                if error.errorDescription == "THEME_SLUG_OCCUPIED" {
                    return .single(.taken)
                } else if error.errorDescription == "THEME_SLUG_INVALID" {
                    return .single(.invalid)
                } else {
                    return .single(.available)
                }
            }
        }
    } |> switchToLatest
}

public enum UpdateAddressNameError {
    case generic
}

func _internal_updateAddressName(account: Account, domain: AddressNameDomain, name: String?) -> Signal<Void, UpdateAddressNameError> {
    let accountPeerId = account.peerId
    return account.postbox.transaction { transaction -> Signal<Void, UpdateAddressNameError> in
        switch domain {
            case .account:
                return account.network.request(Api.functions.account.updateUsername(username: name ?? ""), automaticFloodWait: false)
                |> mapError { _ -> UpdateAddressNameError in
                    return .generic
                }
                |> mapToSignal { result -> Signal<Void, UpdateAddressNameError> in
                    return account.postbox.transaction { transaction -> Void in
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: [result]))
                    } |> mapError { _ -> UpdateAddressNameError in }
                }
            case let .peer(peerId):
                if let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
                    return account.network.request(Api.functions.channels.updateUsername(channel: inputChannel, username: name ?? ""), automaticFloodWait: false)
                        |> mapError { _ -> UpdateAddressNameError in
                            return .generic
                        }
                        |> mapToSignal { result -> Signal<Void, UpdateAddressNameError> in
                            return account.postbox.transaction { transaction -> Void in
                                if case .boolTrue = result {
                                    if let peer = transaction.getPeer(peerId) as? TelegramChannel {
                                        var updatedPeer = peer.withUpdatedAddressName(name)
                                        if name != nil, let defaultBannedRights = updatedPeer.defaultBannedRights {
                                            updatedPeer = updatedPeer.withUpdatedDefaultBannedRights(TelegramChatBannedRights(flags: defaultBannedRights.flags.union([.banPinMessages, .banChangeInfo]), untilDate: Int32.max))
                                        }
                                        updatePeersCustom(transaction: transaction, peers: [updatedPeer], update: { _, updated in
                                            updated
                                        })
                                    }
                                }
                            } |> mapError { _ -> UpdateAddressNameError in }
                    }
                } else {
                    return .fail(.generic)
                }
            case .bot:
                return .fail(.generic)
            case let .theme(theme):
                let flags: Int32 = 1 << 0
                return account.network.request(Api.functions.account.updateTheme(flags: flags, format: telegramThemeFormat, theme: .inputTheme(id: theme.id, accessHash: theme.accessHash), slug: nil, title: nil, document: nil, settings: nil))
                |> mapError { _ -> UpdateAddressNameError in
                    return .generic
                }
                |> map { _ in
                    return Void()
                }
        }
    } |> mapError { _ -> UpdateAddressNameError in } |> switchToLatest
}

public enum DeactivateAllAddressNamesError {
    case generic
}

func _internal_deactivateAllAddressNames(account: Account, peerId: EnginePeer.Id) -> Signal<Never, DeactivateAllAddressNamesError> {
    return account.postbox.transaction { transaction -> Signal<Never, DeactivateAllAddressNamesError> in
        if let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
            return account.network.request(Api.functions.channels.deactivateAllUsernames(channel: inputChannel), automaticFloodWait: false)
            |> mapError { _ -> DeactivateAllAddressNamesError in
                return .generic
            }
            |> mapToSignal { result -> Signal<Never, DeactivateAllAddressNamesError> in
                return account.postbox.transaction { transaction -> Signal<Void, DeactivateAllAddressNamesError> in
                    if case .boolTrue = result, let peer = transaction.getPeer(peerId) as? TelegramChannel {
                        var updatedNames: [TelegramPeerUsername] = []
                        for username in peer.usernames {
                            var updatedFlags = username.flags
                            updatedFlags.remove(.isActive)
                            updatedNames.append(TelegramPeerUsername(flags: updatedFlags, username: username.username))
                        }
                        let updatedUser = peer.withUpdatedAddressNames(updatedNames)
                        updatePeersCustom(transaction: transaction, peers: [updatedUser], update: { _, updated in
                            return updated
                        })
                    }
                    return .complete()
                }
                |> castError(DeactivateAllAddressNamesError.self)
                |> switchToLatest
                |> ignoreValues
            }
        } else {
            return .never()
        }
    }
    |> mapError { _ -> DeactivateAllAddressNamesError in
    }
    |> switchToLatest
}

public enum ToggleAddressNameActiveError {
    case generic
    case activeLimitReached
}

func _internal_toggleAddressNameActive(account: Account, domain: AddressNameDomain, name: String, active: Bool) -> Signal<Void, ToggleAddressNameActiveError> {
    return account.postbox.transaction { transaction -> Signal<Void, ToggleAddressNameActiveError> in
        switch domain {
        case .account:
            return account.network.request(Api.functions.account.toggleUsername(username: name, active: active ? .boolTrue : .boolFalse), automaticFloodWait: false)
            |> mapError { error -> ToggleAddressNameActiveError in
                if error.errorDescription == "USERNAMES_ACTIVE_TOO_MUCH" {
                    return .activeLimitReached
                } else {
                    return .generic
                }
            }
            |> mapToSignal { result -> Signal<Void, ToggleAddressNameActiveError> in
                return account.postbox.transaction { transaction -> Void in
                    if case .boolTrue = result, let peer = transaction.getPeer(account.peerId) as? TelegramUser {
                        var updatedNames = peer.usernames
                        if let index = updatedNames.firstIndex(where: { $0.username == name }) {
                            var updatedFlags = updatedNames[index].flags
                            var updateOrder = true
                            var updatedIndex = index
                            if active {
                                if updatedFlags.contains(.isActive) {
                                    updateOrder = false
                                }
                                updatedFlags.insert(.isActive)
                            } else {
                                if !updatedFlags.contains(.isActive) {
                                    updateOrder = false
                                }
                                updatedFlags.remove(.isActive)
                            }
                            let updatedName = TelegramPeerUsername(flags: updatedFlags, username: name)
                            updatedNames.remove(at: index)
                            if updateOrder {
                                if active {
                                    updatedIndex = 0
                                } else {
                                    updatedIndex = updatedNames.count
                                }
                                var i = 0
                                for name in updatedNames {
                                    if active && !name.flags.contains(.isActive) {
                                        updatedIndex = i
                                        break
                                    } else if !active && !name.flags.contains(.isActive) {
                                        updatedIndex = i
                                        break
                                    }
                                    i += 1
                                }
                            }
                            updatedNames.insert(updatedName, at: updatedIndex)
                        }
                        let updatedUser = peer.withUpdatedUsernames(updatedNames)
                        updatePeersCustom(transaction: transaction, peers: [updatedUser], update: { _, updated in
                            return updated
                        })
                    }
                } |> mapError { _ -> ToggleAddressNameActiveError in }
            }
        case let .peer(peerId):
            if let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
                return account.network.request(Api.functions.channels.toggleUsername(channel: inputChannel, username: name, active: active ? .boolTrue : .boolFalse), automaticFloodWait: false)
                    |> mapError { error -> ToggleAddressNameActiveError in
                        if error.errorDescription == "USERNAMES_ACTIVE_TOO_MUCH" {
                            return .activeLimitReached
                        } else {
                            return .generic
                        }
                    }
                    |> mapToSignal { result -> Signal<Void, ToggleAddressNameActiveError> in
                        return account.postbox.transaction { transaction -> Void in
                            if case .boolTrue = result, let peer = transaction.getPeer(peerId) as? TelegramChannel {
                                var updatedNames = peer.usernames
                                if let index = updatedNames.firstIndex(where: { $0.username == name }) {
                                    var updatedFlags = updatedNames[index].flags
                                    var updateOrder = true
                                    var updatedIndex = index
                                    if active {
                                        if updatedFlags.contains(.isActive) {
                                            updateOrder = false
                                        }
                                        updatedFlags.insert(.isActive)
                                    } else {
                                        if !updatedFlags.contains(.isActive) {
                                            updateOrder = false
                                        }
                                        updatedFlags.remove(.isActive)
                                    }
                                    let updatedName = TelegramPeerUsername(flags: updatedFlags, username: name)
                                    updatedNames.remove(at: index)
                                    if updateOrder {
                                        if active {
                                            updatedIndex = 0
                                        } else {
                                            updatedIndex = updatedNames.count
                                        }
                                        var i = 0
                                        for name in updatedNames {
                                            if active && !name.flags.contains(.isActive) {
                                                updatedIndex = i
                                                break
                                            } else if !active && !name.flags.contains(.isActive) {
                                                updatedIndex = i
                                                break
                                            }
                                            i += 1
                                        }
                                    }
                                    updatedNames.insert(updatedName, at: updatedIndex)
                                }
                                let updatedPeer = peer.withUpdatedAddressNames(updatedNames)
                                updatePeersCustom(transaction: transaction, peers: [updatedPeer], update: { _, updated in
                                    return updated
                                })
                            }
                        } |> mapError { _ -> ToggleAddressNameActiveError in }
                }
            } else {
                return .fail(.generic)
            }
        case let .bot(peerId):
            if let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) {
                return account.network.request(Api.functions.bots.toggleUsername(bot: inputUser, username: name, active: active ? .boolTrue : .boolFalse), automaticFloodWait: false)
                    |> mapError { error -> ToggleAddressNameActiveError in
                        if error.errorDescription == "USERNAMES_ACTIVE_TOO_MUCH" {
                            return .activeLimitReached
                        } else {
                            return .generic
                        }
                    }
                    |> mapToSignal { result -> Signal<Void, ToggleAddressNameActiveError> in
                        return account.postbox.transaction { transaction -> Void in
                            if case .boolTrue = result, let peer = transaction.getPeer(peerId) as? TelegramChannel {
                                var updatedNames = peer.usernames
                                if let index = updatedNames.firstIndex(where: { $0.username == name }) {
                                    var updatedFlags = updatedNames[index].flags
                                    var updateOrder = true
                                    var updatedIndex = index
                                    if active {
                                        if updatedFlags.contains(.isActive) {
                                            updateOrder = false
                                        }
                                        updatedFlags.insert(.isActive)
                                    } else {
                                        if !updatedFlags.contains(.isActive) {
                                            updateOrder = false
                                        }
                                        updatedFlags.remove(.isActive)
                                    }
                                    let updatedName = TelegramPeerUsername(flags: updatedFlags, username: name)
                                    updatedNames.remove(at: index)
                                    if updateOrder {
                                        if active {
                                            updatedIndex = 0
                                        } else {
                                            updatedIndex = updatedNames.count
                                        }
                                        var i = 0
                                        for name in updatedNames {
                                            if active && !name.flags.contains(.isActive) {
                                                updatedIndex = i
                                                break
                                            } else if !active && !name.flags.contains(.isActive) {
                                                updatedIndex = i
                                                break
                                            }
                                            i += 1
                                        }
                                    }
                                    updatedNames.insert(updatedName, at: updatedIndex)
                                }
                                let updatedPeer = peer.withUpdatedAddressNames(updatedNames)
                                updatePeersCustom(transaction: transaction, peers: [updatedPeer], update: { _, updated in
                                    return updated
                                })
                            }
                        } |> mapError { _ -> ToggleAddressNameActiveError in }
                }
            } else {
                return .fail(.generic)
            }
        case .theme:
            return .fail(.generic)
        }
    } |> mapError { _ -> ToggleAddressNameActiveError in } |> switchToLatest
}

public enum ReorderAddressNamesError {
    case generic
}

func _internal_reorderAddressNames(account: Account, domain: AddressNameDomain, names: [TelegramPeerUsername]) -> Signal<Void, ReorderAddressNamesError> {
    return account.postbox.transaction { transaction -> Signal<Void, ReorderAddressNamesError> in
        switch domain {
        case .account:
            return account.network.request(Api.functions.account.reorderUsernames(order: names.filter { $0.isActive }.map { $0.username }), automaticFloodWait: false)
            |> mapError { _ -> ReorderAddressNamesError in
                return .generic
            }
            |> mapToSignal { result -> Signal<Void, ReorderAddressNamesError> in
                return account.postbox.transaction { transaction -> Void in
                    if case .boolTrue = result, let peer = transaction.getPeer(account.peerId) as? TelegramUser {
                        let updatedUser = peer.withUpdatedUsernames(names)
                        updatePeersCustom(transaction: transaction, peers: [updatedUser], update: { _, updated in
                            return updated
                        })
                    }
                } |> mapError { _ -> ReorderAddressNamesError in }
            }
        case let .peer(peerId):
            if let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
                return account.network.request(Api.functions.channels.reorderUsernames(channel: inputChannel, order: names.filter { $0.isActive }.map { $0.username }), automaticFloodWait: false)
                |> mapError { _ -> ReorderAddressNamesError in
                    return .generic
                }
                |> mapToSignal { result -> Signal<Void, ReorderAddressNamesError> in
                    return account.postbox.transaction { transaction -> Void in
                        if case .boolTrue = result, let peer = transaction.getPeer(peerId) as? TelegramChannel {
                            let updatedPeer = peer.withUpdatedAddressNames(names)
                            updatePeersCustom(transaction: transaction, peers: [updatedPeer], update: { _, updated in
                                return updated
                            })
                        }
                    } |> mapError { _ -> ReorderAddressNamesError in }
                }
            } else {
                return .fail(.generic)
            }
        case let .bot(peerId):
            if let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) {
                return account.network.request(Api.functions.bots.reorderUsernames(bot: inputUser, order: names.filter { $0.isActive }.map { $0.username }), automaticFloodWait: false)
                |> mapError { _ -> ReorderAddressNamesError in
                    return .generic
                }
                |> mapToSignal { result -> Signal<Void, ReorderAddressNamesError> in
                    return account.postbox.transaction { transaction -> Void in
                        if case .boolTrue = result, let peer = transaction.getPeer(peerId) as? TelegramChannel {
                            let updatedPeer = peer.withUpdatedAddressNames(names)
                            updatePeersCustom(transaction: transaction, peers: [updatedPeer], update: { _, updated in
                                return updated
                            })
                        }
                    } |> mapError { _ -> ReorderAddressNamesError in }
                }
            } else {
                return .fail(.generic)
            }
        case .theme:
            return .fail(.generic)
        }
    } |> mapError { _ -> ReorderAddressNamesError in } |> switchToLatest
}

func _internal_checkPublicChannelCreationAvailability(account: Account, location: Bool = false) -> Signal<Bool, NoError> {
    var flags: Int32 = (1 << 1)
    if location {
        flags |= (1 << 0)
    }
    
    return account.network.request(Api.functions.channels.getAdminedPublicChannels(flags: flags))
    |> map { _ -> Bool in
        return true
    }
    |> `catch` { error -> Signal<Bool, NoError> in
        return .single(false)
    }
}

public enum AdminedPublicChannelsScope {
    case all
    case forLocation
    case forVoiceChat
    case forPersonalProfile
}

public final class TelegramAdminedPublicChannel: Equatable {
    public let peer: EnginePeer
    public let subscriberCount: Int?
    
    public init(peer: EnginePeer, subscriberCount: Int?) {
        self.peer = peer
        self.subscriberCount = subscriberCount
    }
    
    public static func ==(lhs: TelegramAdminedPublicChannel, rhs: TelegramAdminedPublicChannel) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.subscriberCount != rhs.subscriberCount {
            return false
        }
        return true
    }
}

func _internal_adminedPublicChannels(account: Account, scope: AdminedPublicChannelsScope = .all) -> Signal<[TelegramAdminedPublicChannel], NoError> {
    var flags: Int32 = 0
    switch scope {
    case .all:
        break
    case .forLocation:
        flags |= (1 << 0)
    case .forVoiceChat:
        flags |= (1 << 2)
    case .forPersonalProfile:
        flags |= (1 << 2)
    }
    
    let accountPeerId = account.peerId
    
    return account.network.request(Api.functions.channels.getAdminedPublicChannels(flags: flags))
    |> retryRequestIfNotFrozen
    |> mapToSignal { result -> Signal<[TelegramAdminedPublicChannel], NoError> in
        guard let result else {
            return .single([])
        }
        return account.postbox.transaction { transaction -> [TelegramAdminedPublicChannel] in
            let chats: [Api.Chat]
            var subscriberCounts: [PeerId: Int] = [:]
            let parsedPeers: AccumulatedPeers
            switch result {
            case let .chats(apiChats):
                chats = apiChats
                for chat in apiChats {
                    if case let .channel(_, _, _, _, _, _, _, _, _, _, _, _, participantsCount, _, _, _, _, _, _, _, _, _, _) = chat {
                        subscriberCounts[chat.peerId] = participantsCount.flatMap(Int.init)
                    }
                }
            case let .chatsSlice(_, apiChats):
                chats = apiChats
            }
            parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: [])
            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
            var peers: [TelegramAdminedPublicChannel] = []
            for chat in chats {
                if let peer = transaction.getPeer(chat.peerId) {
                    peers.append(TelegramAdminedPublicChannel(
                        peer: EnginePeer(peer),
                        subscriberCount: subscriberCounts[peer.id]
                    ))
                }
            }
            return peers
        }
    }
}

final class CachedStorySendAsPeers: Codable {
    public let peerIds: [PeerId]
    public let timestamp: Double
    
    public init(peerIds: [PeerId], timestamp: Double) {
        self.peerIds = peerIds
        self.timestamp = timestamp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.peerIds = try container.decode([Int64].self, forKey: "l").map(PeerId.init)
        self.timestamp = try container.decodeIfPresent(Double.self, forKey: "ts") ?? 0.0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.peerIds.map { $0.toInt64() }, forKey: "l")
        try container.encode(self.timestamp, forKey: "ts")
    }
}

func _internal_channelsForStories(account: Account) -> Signal<[Peer], NoError> {
    let accountPeerId = account.peerId
    return account.postbox.transaction { transaction -> [Peer]? in
        if let entry = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.storySendAsPeerIds, key: ValueBoxKey(length: 0)))?.get(CachedStorySendAsPeers.self) {
            return entry.peerIds.compactMap(transaction.getPeer)
        } else {
            return nil
        }
    }
    |> mapToSignal { cachedPeers in
        let remote: Signal<[Peer], NoError> = account.network.request(Api.functions.stories.getChatsToSend())
        |> retryRequest
        |> mapToSignal { result -> Signal<[Peer], NoError> in
            return account.postbox.transaction { transaction -> [Peer] in
                let chats: [Api.Chat]
                let parsedPeers: AccumulatedPeers
                switch result {
                case let .chats(apiChats):
                    chats = apiChats
                case let .chatsSlice(_, apiChats):
                    chats = apiChats
                }
                parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: [])
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                var peers: [Peer] = []
                for chat in chats {
                    if let peer = transaction.getPeer(chat.peerId) {
                        peers.append(peer)
                        
                        if case let .channel(_, _, _, _, _, _, _, _, _, _, _, _, participantsCount, _, _, _, _, _, _, _, _, _, _) = chat, let participantsCount = participantsCount {
                            transaction.updatePeerCachedData(peerIds: Set([peer.id]), update: { _, current in
                                var current = current as? CachedChannelData ?? CachedChannelData()
                                var participantsSummary = current.participantsSummary
                                
                                participantsSummary.memberCount = participantsCount
                                
                                current = current.withUpdatedParticipantsSummary(participantsSummary)
                                return current
                            })
                        }
                    }
                }
                
                if let entry = CodableEntry(CachedStorySendAsPeers(peerIds: peers.map(\.id), timestamp: CFAbsoluteTimeGetCurrent())) {
                    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.storySendAsPeerIds, key: ValueBoxKey(length: 0)), entry: entry)
                }
                
                return peers
            }
        }
        
        if let cachedPeers = cachedPeers {
            return .single(cachedPeers) |> then(remote)
        } else {
            return remote
        }
    }
}

func _internal_channelsForPublicReaction(account: Account, useLocalCache: Bool) -> Signal<[Peer], NoError> {
    let accountPeerId = account.peerId
    return account.postbox.transaction { transaction -> ([Peer], Double)? in
        if let entry = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.channelsForPublicReaction, key: ValueBoxKey(length: 0)))?.get(CachedStorySendAsPeers.self) {
            return (entry.peerIds.compactMap(transaction.getPeer), entry.timestamp)
        } else {
            return nil
        }
    }
    |> mapToSignal { cachedPeers in
        let remote: Signal<[Peer], NoError> = account.network.request(Api.functions.channels.getAdminedPublicChannels(flags: 0))
        |> retryRequestIfNotFrozen
        |> mapToSignal { result -> Signal<[Peer], NoError> in
            guard let result else {
                return .single([])
            }
            return account.postbox.transaction { transaction -> [Peer] in
                let chats: [Api.Chat]
                let parsedPeers: AccumulatedPeers
                switch result {
                case let .chats(apiChats):
                    chats = apiChats
                case let .chatsSlice(_, apiChats):
                    chats = apiChats
                }
                parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: [])
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                var peers: [Peer] = []
                for chat in chats {
                    if let peer = transaction.getPeer(chat.peerId) {
                        peers.append(peer)
                        
                        if case let .channel(_, _, _, _, _, _, _, _, _, _, _, _, participantsCount, _, _, _, _, _, _, _, _, _, _) = chat, let participantsCount = participantsCount {
                            transaction.updatePeerCachedData(peerIds: Set([peer.id]), update: { _, current in
                                var current = current as? CachedChannelData ?? CachedChannelData()
                                var participantsSummary = current.participantsSummary
                                
                                participantsSummary.memberCount = participantsCount
                                
                                current = current.withUpdatedParticipantsSummary(participantsSummary)
                                return current
                            })
                        }
                    }
                }
                
                if let entry = CodableEntry(CachedStorySendAsPeers(peerIds: peers.map(\.id), timestamp: CFAbsoluteTimeGetCurrent())) {
                    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.channelsForPublicReaction, key: ValueBoxKey(length: 0)), entry: entry)
                }
                
                return peers
            }
        }
        
        if useLocalCache {
            if let cachedPeers {
                return .single(cachedPeers.0)
            } else {
                return .single([])
            }
        }
        
        if let cachedPeers {
            if CFAbsoluteTimeGetCurrent() < cachedPeers.1 + 5 * 60 {
                return .single(cachedPeers.0)
            } else {
                return .single(cachedPeers.0) |> then(remote)
            }
        } else {
            return remote
        }
    }
}

public enum ChannelAddressNameAssignmentAvailability {
    case available
    case unknown
    case addressNameLimitReached
}

func _internal_channelAddressNameAssignmentAvailability(account: Account, peerId: PeerId?) -> Signal<ChannelAddressNameAssignmentAvailability, NoError> {
    return account.postbox.transaction { transaction -> Signal<ChannelAddressNameAssignmentAvailability, NoError> in
        var inputChannel: Api.InputChannel?
        if let peerId = peerId {
            if let peer = transaction.getPeer(peerId), let channel = apiInputChannel(peer) {
                inputChannel = channel
            }
        } else {
            inputChannel = .inputChannelEmpty
        }
        if let inputChannel = inputChannel {
            return account.network.request(Api.functions.channels.checkUsername(channel: inputChannel, username: "username"))
            |> map { _ -> ChannelAddressNameAssignmentAvailability in
                return .available
            }
            |> `catch` { error -> Signal<ChannelAddressNameAssignmentAvailability, NoError> in
                return .single(.addressNameLimitReached)
            }
        } else {
            return .single(.unknown)
        }
    } |> switchToLatest
}
