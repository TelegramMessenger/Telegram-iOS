import Foundation
import Postbox
internal import TelegramApi


public extension PeerReference {
    var id: PeerId {
        switch self {
        case let .user(id, _):
            return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))
        case let .group(id):
            return PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(id))
        case let .channel(id, _):
            return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(id))
        }
    }

    init?(_ peer: EnginePeer) {
        self.init(peer._asPeer())
    }
}

extension PeerReference {    
    var inputPeer: Api.InputPeer {
        switch self {
        case let .user(id, accessHash):
            return .inputPeerUser(.init(userId: id, accessHash: accessHash))
        case let .group(id):
            return .inputPeerChat(.init(chatId: id))
        case let .channel(id, accessHash):
            return .inputPeerChannel(.init(channelId: id, accessHash: accessHash))
        }
    }
    
    var inputUser: Api.InputUser? {
        if case let .user(id, accessHash) = self {
            return .inputUser(.init(userId: id, accessHash: accessHash))
        } else {
            return nil
        }
    }
    
    var inputChannel: Api.InputChannel? {
        if case let .channel(id, accessHash) = self {
            return .inputChannel(.init(channelId: id, accessHash: accessHash))
        } else {
            return nil
        }
    }
}

func forceApiInputPeer(_ peer: Peer) -> Api.InputPeer? {
    switch peer {
    case let user as TelegramUser:
        return Api.InputPeer.inputPeerUser(.init(userId: user.id.id._internalGetInt64Value(), accessHash: user.accessHash?.value ?? 0))
    case let group as TelegramGroup:
        return Api.InputPeer.inputPeerChat(.init(chatId: group.id.id._internalGetInt64Value()))
    case let channel as TelegramChannel:
        if let accessHash = channel.accessHash {
            return Api.InputPeer.inputPeerChannel(.init(channelId: channel.id.id._internalGetInt64Value(), accessHash: accessHash.value))
        } else {
            return nil
        }
    case let community as TelegramCommunity:
        if let accessHash = community.accessHash {
            return Api.InputPeer.inputPeerChannel(.init(channelId: community.id.id._internalGetInt64Value(), accessHash: accessHash.value))
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
        return Api.InputPeer.inputPeerUser(.init(userId: user.id.id._internalGetInt64Value(), accessHash: user.accessHash!.value))
    case let group as TelegramGroup:
        return Api.InputPeer.inputPeerChat(.init(chatId: group.id.id._internalGetInt64Value()))
    case let channel as TelegramChannel:
        if let accessHash = channel.accessHash {
            return Api.InputPeer.inputPeerChannel(.init(channelId: channel.id.id._internalGetInt64Value(), accessHash: accessHash.value))
        } else {
            return nil
        }
    case let community as TelegramCommunity:
        if let accessHash = community.accessHash {
            return Api.InputPeer.inputPeerChannel(.init(channelId: community.id.id._internalGetInt64Value(), accessHash: accessHash.value))
        } else {
            return nil
        }
    default:
        return nil
    }
}

private func apiInputPeerFromSourceMessage(_ sourceMessageId: MessageId?, transaction: Transaction) -> (MessageId, Api.InputPeer)? {
    guard let sourceMessageId else {
        return nil
    }
    guard let sourcePeer = transaction.getPeer(sourceMessageId.peerId) else {
        return nil
    }
    guard let inputPeer = apiInputPeer(sourcePeer) else {
        return nil
    }
    return (sourceMessageId, inputPeer)
}

func apiInputPeer(_ peer: Peer, sourceMessageId: MessageId?, transaction: Transaction) -> Api.InputPeer? {
    switch peer {
    case let user as TelegramUser:
        if let accessHash = user.accessHash {
            switch accessHash {
            case let .personal(value):
                return Api.InputPeer.inputPeerUser(.init(userId: user.id.id._internalGetInt64Value(), accessHash: value))
            case let .genericPublic(value):
                if let (sourceMessageId, sourcePeer) = apiInputPeerFromSourceMessage(sourceMessageId, transaction: transaction) {
                    return Api.InputPeer.inputPeerUserFromMessage(.init(peer: sourcePeer, msgId: sourceMessageId.id, userId: user.id.id._internalGetInt64Value()))
                }
                return Api.InputPeer.inputPeerUser(.init(userId: user.id.id._internalGetInt64Value(), accessHash: value))
            }
        } else if let (sourceMessageId, sourcePeer) = apiInputPeerFromSourceMessage(sourceMessageId, transaction: transaction) {
            return Api.InputPeer.inputPeerUserFromMessage(.init(peer: sourcePeer, msgId: sourceMessageId.id, userId: user.id.id._internalGetInt64Value()))
        } else {
            return nil
        }
    case let group as TelegramGroup:
        return Api.InputPeer.inputPeerChat(.init(chatId: group.id.id._internalGetInt64Value()))
    case let channel as TelegramChannel:
        if let accessHash = channel.accessHash {
            switch accessHash {
            case let .personal(value):
                return Api.InputPeer.inputPeerChannel(.init(channelId: channel.id.id._internalGetInt64Value(), accessHash: value))
            case let .genericPublic(value):
                if let (sourceMessageId, sourcePeer) = apiInputPeerFromSourceMessage(sourceMessageId, transaction: transaction) {
                    return Api.InputPeer.inputPeerChannelFromMessage(.init(peer: sourcePeer, msgId: sourceMessageId.id, channelId: channel.id.id._internalGetInt64Value()))
                }
                return Api.InputPeer.inputPeerChannel(.init(channelId: channel.id.id._internalGetInt64Value(), accessHash: value))
            }
        } else if let (sourceMessageId, sourcePeer) = apiInputPeerFromSourceMessage(sourceMessageId, transaction: transaction) {
            return Api.InputPeer.inputPeerChannelFromMessage(.init(peer: sourcePeer, msgId: sourceMessageId.id, channelId: channel.id.id._internalGetInt64Value()))
        } else {
            return nil
        }
    case let community as TelegramCommunity:
        if let accessHash = community.accessHash {
            switch accessHash {
            case let .personal(value):
                return Api.InputPeer.inputPeerChannel(.init(channelId: community.id.id._internalGetInt64Value(), accessHash: value))
            case let .genericPublic(value):
                if let (sourceMessageId, sourcePeer) = apiInputPeerFromSourceMessage(sourceMessageId, transaction: transaction) {
                    return Api.InputPeer.inputPeerChannelFromMessage(.init(peer: sourcePeer, msgId: sourceMessageId.id, channelId: community.id.id._internalGetInt64Value()))
                }
                return Api.InputPeer.inputPeerChannel(.init(channelId: community.id.id._internalGetInt64Value(), accessHash: value))
            }
        } else if let (sourceMessageId, sourcePeer) = apiInputPeerFromSourceMessage(sourceMessageId, transaction: transaction) {
            return Api.InputPeer.inputPeerChannelFromMessage(.init(peer: sourcePeer, msgId: sourceMessageId.id, channelId: community.id.id._internalGetInt64Value()))
        } else {
            return nil
        }
    default:
        return nil
    }
}

func apiInputPeerOrSelf(_ peer: Peer, accountPeerId: PeerId) -> Api.InputPeer? {
    if peer.id == accountPeerId {
        return .inputPeerSelf
    }
    return apiInputPeer(peer)
}

func peerIdFromApiCommunityId(_ communityId: Int64) -> PeerId {
    return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(communityId))
}

func apiInputChannel(_ peer: Peer) -> Api.InputChannel? {
    if let channel = peer as? TelegramChannel, let accessHash = channel.accessHash {
        return Api.InputChannel.inputChannel(.init(channelId: channel.id.id._internalGetInt64Value(), accessHash: accessHash.value))
    } else if let community = peer as? TelegramCommunity, let accessHash = community.accessHash {
        return Api.InputChannel.inputChannel(.init(channelId: community.id.id._internalGetInt64Value(), accessHash: accessHash.value))
    } else {
        return nil
    }
}

func apiInputDialogPeer(_ peer: Peer) -> Api.InputDialogPeer? {
    if peer is TelegramCommunity {
        guard let inputChannel = apiInputChannel(peer) else {
            return nil
        }
        return .inputDialogPeerCommunity(.init(community: inputChannel))
    }
    guard let inputPeer = apiInputPeer(peer) else {
        return nil
    }
    return .inputDialogPeer(.init(peer: inputPeer))
}

func apiInputChannel(_ peer: Peer, sourceMessageId: MessageId?, transaction: Transaction) -> Api.InputChannel? {
    if let channel = peer as? TelegramChannel {
        if let accessHash = channel.accessHash {
            switch accessHash {
            case let .personal(value):
                return Api.InputChannel.inputChannel(.init(channelId: channel.id.id._internalGetInt64Value(), accessHash: value))
            case let .genericPublic(value):
                if let (sourceMessageId, sourcePeer) = apiInputPeerFromSourceMessage(sourceMessageId, transaction: transaction) {
                    return Api.InputChannel.inputChannelFromMessage(.init(peer: sourcePeer, msgId: sourceMessageId.id, channelId: channel.id.id._internalGetInt64Value()))
                }
                return Api.InputChannel.inputChannel(.init(channelId: channel.id.id._internalGetInt64Value(), accessHash: value))
            }
        } else if let (sourceMessageId, sourcePeer) = apiInputPeerFromSourceMessage(sourceMessageId, transaction: transaction) {
            return Api.InputChannel.inputChannelFromMessage(.init(peer: sourcePeer, msgId: sourceMessageId.id, channelId: channel.id.id._internalGetInt64Value()))
        } else {
            return nil
        }
    } else if let community = peer as? TelegramCommunity {
        if let accessHash = community.accessHash {
            switch accessHash {
            case let .personal(value):
                return Api.InputChannel.inputChannel(.init(channelId: community.id.id._internalGetInt64Value(), accessHash: value))
            case let .genericPublic(value):
                if let (sourceMessageId, sourcePeer) = apiInputPeerFromSourceMessage(sourceMessageId, transaction: transaction) {
                    return Api.InputChannel.inputChannelFromMessage(.init(peer: sourcePeer, msgId: sourceMessageId.id, channelId: community.id.id._internalGetInt64Value()))
                }
                return Api.InputChannel.inputChannel(.init(channelId: community.id.id._internalGetInt64Value(), accessHash: value))
            }
        } else if let (sourceMessageId, sourcePeer) = apiInputPeerFromSourceMessage(sourceMessageId, transaction: transaction) {
            return Api.InputChannel.inputChannelFromMessage(.init(peer: sourcePeer, msgId: sourceMessageId.id, channelId: community.id.id._internalGetInt64Value()))
        } else {
            return nil
        }
    } else {
        return nil
    }
}

func apiInputUser(_ peer: Peer) -> Api.InputUser? {
    if let user = peer as? TelegramUser, let accessHash = user.accessHash {
        return Api.InputUser.inputUser(.init(userId: user.id.id._internalGetInt64Value(), accessHash: accessHash.value))
    } else {
        return nil
    }
}

func apiInputUser(_ peer: Peer, sourceMessageId: MessageId?, transaction: Transaction) -> Api.InputUser? {
    guard let user = peer as? TelegramUser else {
        return nil
    }
    if let accessHash = user.accessHash {
        switch accessHash {
        case let .personal(value):
            return Api.InputUser.inputUser(.init(userId: user.id.id._internalGetInt64Value(), accessHash: value))
        case let .genericPublic(value):
            if let (sourceMessageId, sourcePeer) = apiInputPeerFromSourceMessage(sourceMessageId, transaction: transaction) {
                return Api.InputUser.inputUserFromMessage(.init(peer: sourcePeer, msgId: sourceMessageId.id, userId: user.id.id._internalGetInt64Value()))
            }
            return Api.InputUser.inputUser(.init(userId: user.id.id._internalGetInt64Value(), accessHash: value))
        }
    } else if let (sourceMessageId, sourcePeer) = apiInputPeerFromSourceMessage(sourceMessageId, transaction: transaction) {
        return Api.InputUser.inputUserFromMessage(.init(peer: sourcePeer, msgId: sourceMessageId.id, userId: user.id.id._internalGetInt64Value()))
    } else {
        return nil
    }
}

func apiInputSecretChat(_ peer: Peer) -> Api.InputEncryptedChat? {
    if let chat = peer as? TelegramSecretChat {
        return Api.InputEncryptedChat.inputEncryptedChat(.init(chatId: Int32(peer.id.id._internalGetInt64Value()), accessHash: chat.accessHash))
    } else {
        return nil
    }
}
