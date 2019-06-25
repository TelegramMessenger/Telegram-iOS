import Foundation
#if os(macOS)
    import PostboxMac
    import TelegramApiMac
#else
    import Postbox
    import TelegramApi
#endif

public enum PeerReference: PostboxCoding, Hashable, Equatable {
    case user(id: Int32, accessHash: Int64)
    case group(id: Int32)
    case channel(id: Int32, accessHash: Int64)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_r", orElse: 0) {
            case 0:
                self = .user(id: decoder.decodeInt32ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0))
            case 1:
                self = .group(id: decoder.decodeInt32ForKey("i", orElse: 0))
            case 2:
                self = .channel(id: decoder.decodeInt32ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0))
            default:
                assertionFailure()
                self = .user(id: 0, accessHash: 0)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .user(id, accessHash):
                encoder.encodeInt32(0, forKey: "_r")
                encoder.encodeInt32(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
            case let .group(id):
                encoder.encodeInt32(1, forKey: "_r")
                encoder.encodeInt32(id, forKey: "i")
            case let .channel(id, accessHash):
                encoder.encodeInt32(2, forKey: "_r")
                encoder.encodeInt32(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
        }
    }
    
    var id: PeerId {
        switch self {
            case let .user(id, _):
                return PeerId(namespace: Namespaces.Peer.CloudUser, id: id)
            case let .group(id):
                return PeerId(namespace: Namespaces.Peer.CloudGroup, id: id)
            case let .channel(id, _):
                return PeerId(namespace: Namespaces.Peer.CloudChannel, id: id)
        }
    }
    
    public init?(_ peer: Peer) {
        switch peer {
            case let user as TelegramUser:
                if let accessHash = user.accessHash {
                    self = .user(id: user.id.id, accessHash: accessHash.value)
                } else {
                    return nil
                }
            case let group as TelegramGroup:
                self = .group(id: group.id.id)
            case let channel as TelegramChannel:
                if let accessHash = channel.accessHash {
                    self = .channel(id: channel.id.id, accessHash: accessHash.value)
                } else {
                    return nil
                }
            default:
                return nil
        }
    }
    
    var inputPeer: Api.InputPeer {
        switch self {
            case let .user(id, accessHash):
                return .inputPeerUser(userId: id, accessHash: accessHash)
            case let .group(id):
                return .inputPeerChat(chatId: id)
            case let .channel(id, accessHash):
                return .inputPeerChannel(channelId: id, accessHash: accessHash)
        }
    }
    
    var inputUser: Api.InputUser? {
        if case let .user(id, accessHash) = self {
            return .inputUser(userId: id, accessHash: accessHash)
        } else {
            return nil
        }
    }
    
    var inputChannel: Api.InputChannel? {
        if case let .channel(id, accessHash) = self {
            return .inputChannel(channelId: id, accessHash: accessHash)
        } else {
            return nil
        }
    }
}

func forceApiInputPeer(_ peer: Peer) -> Api.InputPeer? {
    switch peer {
        case let user as TelegramUser:
            return Api.InputPeer.inputPeerUser(userId: user.id.id, accessHash: user.accessHash?.value ?? 0)
        case let group as TelegramGroup:
            return Api.InputPeer.inputPeerChat(chatId: group.id.id)
        case let channel as TelegramChannel:
            if let accessHash = channel.accessHash {
                return Api.InputPeer.inputPeerChannel(channelId: channel.id.id, accessHash: accessHash.value)
            } else {
                return nil
            }
        default:
            return nil
    }
}

func apiInputPeer(_ peer: Peer) -> Api.InputPeer? {
    switch peer {
        case let user as TelegramUser where user.accessHash != nil:
            return Api.InputPeer.inputPeerUser(userId: user.id.id, accessHash: user.accessHash!.value)
        case let group as TelegramGroup:
            return Api.InputPeer.inputPeerChat(chatId: group.id.id)
        case let channel as TelegramChannel:
            if let accessHash = channel.accessHash {
                return Api.InputPeer.inputPeerChannel(channelId: channel.id.id, accessHash: accessHash.value)
            } else {
                return nil
            }
        default:
            return nil
    }
}

func apiInputChannel(_ peer: Peer) -> Api.InputChannel? {
    if let channel = peer as? TelegramChannel, let accessHash = channel.accessHash {
        return Api.InputChannel.inputChannel(channelId: channel.id.id, accessHash: accessHash.value)
    } else {
        return nil
    }
}

func apiInputUser(_ peer: Peer) -> Api.InputUser? {
    if let user = peer as? TelegramUser, let accessHash = user.accessHash {
        return Api.InputUser.inputUser(userId: user.id.id, accessHash: accessHash.value)
    } else {
        return nil
    }
}

func apiInputSecretChat(_ peer: Peer) -> Api.InputEncryptedChat? {
    if let chat = peer as? TelegramSecretChat {
        return Api.InputEncryptedChat.inputEncryptedChat(chatId: peer.id.id, accessHash: chat.accessHash)
    } else {
        return nil
    }
}
