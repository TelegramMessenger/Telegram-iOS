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
}

public enum AddressNameDomain {
    case account
    case peer(PeerId)
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
                return length < 5 ? .tooShort : .endsWithUnderscore
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
    
    if length < 5 && (!canEmpty || length != 0) {
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
                    return .single(.invalid)
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
                        return .single(.invalid)
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
                        return .single(.invalid)
                    }
                } else {
                    return .single(.invalid)
                }
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
    return account.postbox.transaction { transaction -> Signal<Void, UpdateAddressNameError> in
        switch domain {
            case .account:
                return account.network.request(Api.functions.account.updateUsername(username: name ?? ""), automaticFloodWait: false)
                |> mapError { _ -> UpdateAddressNameError in
                    return .generic
                }
                |> mapToSignal { result -> Signal<Void, UpdateAddressNameError> in
                    return account.postbox.transaction { transaction -> Void in
                        let user = TelegramUser(user: result)
                        updatePeers(transaction: transaction, peers: [user], update: { _, updated in
                            return updated
                        })
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
                                        updatePeers(transaction: transaction, peers: [updatedPeer], update: { _, updated in
                                            return updated
                                        })
                                    }
                                }
                            } |> mapError { _ -> UpdateAddressNameError in }
                    }
                } else {
                    return .fail(.generic)
                }
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
}

func _internal_adminedPublicChannels(account: Account, scope: AdminedPublicChannelsScope = .all) -> Signal<[Peer], NoError> {
    var flags: Int32 = 0
    switch scope {
    case .all:
        break
    case .forLocation:
        flags |= (1 << 0)
    case .forVoiceChat:
        flags |= (1 << 2)
    }
    
    return account.network.request(Api.functions.channels.getAdminedPublicChannels(flags: flags))
    |> retryRequest
    |> mapToSignal { result -> Signal<[Peer], NoError> in
        var peers: [Peer] = []
        switch result {
            case let .chats(apiChats):
                for chat in apiChats {
                    if let peer = parseTelegramGroupOrChannel(chat: chat) {
                        peers.append(peer)
                    }
                }
            case let .chatsSlice(_, apiChats):
                for chat in apiChats {
                    if let peer = parseTelegramGroupOrChannel(chat: chat) {
                        peers.append(peer)
                    }
                }
        }
        return account.postbox.transaction { transaction -> [Peer] in
            updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                return updated
            })
            return peers
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
