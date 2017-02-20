import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

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
}

public func checkAddressNameFormat(_ value: String) -> AddressNameFormatError? {
    var index = 0
    let length = value.characters.count
    for char in value.characters {
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
        if (!((char >= "a" && char <= "z") || (char >= "A" && char <= "Z") || (char >= "0" && char <= "9"))) {
            return .invalidCharacters
        }
        index += 1
    }
    
    if length < 5 {
        return .tooShort
    }
    
    return nil
}

public func addressNameAvailability(account: Account, domain: AddressNameDomain, name: String) -> Signal<AddressNameAvailability, NoError> {
    return account.postbox.modify { modifier -> Signal<AddressNameAvailability, NoError> in
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
                if let peer = modifier.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
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
                } else {
                    return .single(.invalid)
                }
        }
    } |> switchToLatest
}

public enum UpdateAddressNameError {
    case generic
}

public func updateAddressName(account: Account, domain: AddressNameDomain, name: String?) -> Signal<Void, UpdateAddressNameError> {
    return account.postbox.modify { modifier -> Signal<Void, UpdateAddressNameError> in
        switch domain {
            case .account:
                return account.network.request(Api.functions.account.updateUsername(username: name ?? ""))
                |> mapError { _ -> UpdateAddressNameError in
                    return .generic
                }
                |> mapToSignal { result -> Signal<Void, UpdateAddressNameError> in
                    return account.postbox.modify { modifier -> Void in
                        let user = TelegramUser(user: result)
                        updatePeers(modifier: modifier, peers: [user], update: { _, updated in
                            return updated
                        })
                    } |> mapError { _ -> UpdateAddressNameError in return .generic }
                }
            case let .peer(peerId):
                if let peer = modifier.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
                    return account.network.request(Api.functions.channels.updateUsername(channel: inputChannel, username: name ?? ""))
                        |> mapError { _ -> UpdateAddressNameError in
                            return .generic
                        }
                        |> mapToSignal { result -> Signal<Void, UpdateAddressNameError> in
                            return account.postbox.modify { modifier -> Void in
                                if case .boolTrue = result {
                                    if let peer = modifier.getPeer(peerId) as? TelegramChannel {
                                        updatePeers(modifier: modifier, peers: [peer.withUpdatedAddressName(name)], update: { _, updated in
                                            return updated
                                        })
                                    }
                                }
                            } |> mapError { _ -> UpdateAddressNameError in return .generic }
                    }
                } else {
                    return .fail(.generic)
                }
        }
    } |> mapError { _ -> UpdateAddressNameError in return .generic } |> switchToLatest
}

public func adminedPublicChannels(account: Account) -> Signal<[Peer], NoError> {
    return account.network.request(Api.functions.channels.getAdminedPublicChannels())
        |> retryRequest
        |> map { result -> [Peer] in
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
            return peers
        }
}

public enum ChannelAddressNameAssignmentAvailability {
    case available
    case unknown
    case addressNameLimitReached
}

public func channelAddressNameAssignmentAvailability(account: Account, peerId: PeerId?) -> Signal<ChannelAddressNameAssignmentAvailability, NoError> {
    return account.postbox.modify { modifier -> Signal<ChannelAddressNameAssignmentAvailability, NoError> in
        var inputChannel: Api.InputChannel?
        if let peerId = peerId {
            if let peer = modifier.getPeer(peerId), let channel = apiInputChannel(peer) {
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
