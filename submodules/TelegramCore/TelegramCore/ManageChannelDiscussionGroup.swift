import Foundation
#if os(macOS)
import SwiftSignalKitMac
import PostboxMac
#else
import SwiftSignalKit
import Postbox
#endif
import TelegramApi

public enum AvailableChannelDiscussionGroupError {
    case generic
}

public func availableGroupsForChannelDiscussion(postbox: Postbox, network: Network) -> Signal<[Peer], AvailableChannelDiscussionGroupError> {
    return network.request(Api.functions.channels.getGroupsForDiscussion())
    |> mapError { error in
        return .generic
    }
    |> mapToSignal { result -> Signal<[Peer], AvailableChannelDiscussionGroupError> in
        let chats: [Api.Chat]
        switch result {
            case let .chats(c):
                chats = c
            case let .chatsSlice(_, c):
                chats = c
        }
        
        let peers = chats.compactMap(parseTelegramGroupOrChannel)
        return postbox.transaction { transation -> [Peer] in
            updatePeers(transaction: transation, peers: peers, update: { _, updated in updated })
            return peers
        }
        |> introduceError(AvailableChannelDiscussionGroupError.self)
    }
}

public enum ChannelDiscussionGroupError {
    case generic
    case groupHistoryIsCurrentlyPrivate
    case hasNotPermissions
}

public func updateGroupDiscussionForChannel(network: Network, postbox: Postbox, channelId: PeerId, groupId: PeerId?) -> Signal<Bool, ChannelDiscussionGroupError> {
    return postbox.transaction { transaction -> (channel: Peer?, group: Peer?) in
        return (channel: transaction.getPeer(channelId), group: groupId != nil ? transaction.getPeer(groupId!) : nil)
    }
    |> mapError { _ in ChannelDiscussionGroupError.generic }
    |> mapToSignal { peers -> Signal<Bool, ChannelDiscussionGroupError> in
        guard let channel = peers.channel else {
            return .fail(.generic)
        }
        
        let tempGroupApi = peers.group != nil ? apiInputChannel(peers.group!) : Api.InputChannel.inputChannelEmpty
        
        guard let apiChannel = apiInputChannel(channel), let apiGroup = tempGroupApi else {
            return .fail(.generic)
        }
        
        return network.request(Api.functions.channels.setDiscussionGroup(broadcast: apiChannel, group: apiGroup))
        |> map { result in
            switch result {
                case .boolTrue:
                    return true
                case .boolFalse:
                    return false
            }
        }
        |> `catch` { error -> Signal<Bool, ChannelDiscussionGroupError> in
            if error.errorDescription == "LINK_NOT_MODIFIED" {
                return .single(true)
            } else if error.errorDescription == "MEGAGROUP_PREHISTORY_HIDDEN" {
                return .fail(.groupHistoryIsCurrentlyPrivate)
            } else if error.errorDescription == "CHAT_ADMIN_REQUIRED" {
                return .fail(.hasNotPermissions)
            }
            return .fail(.generic)
        }
    }
    |> mapToSignal { result in
        if result {
            return postbox.transaction { transaction in
                var previousGroupId: PeerId?
                transaction.updatePeerCachedData(peerIds: Set([channelId]), update: { (_, current) -> CachedPeerData? in
                    let current: CachedChannelData = current as? CachedChannelData ?? CachedChannelData()
                    previousGroupId = current.linkedDiscussionPeerId
                    return current.withUpdatedLinkedDiscussionPeerId(groupId)
                })
                if let associatedId = previousGroupId ?? groupId  {
                    transaction.updatePeerCachedData(peerIds: Set([associatedId]), update: { (_, current) -> CachedPeerData? in
                        let cachedData = (current as? CachedChannelData ?? CachedChannelData())
                        return cachedData.withUpdatedLinkedDiscussionPeerId(groupId == nil ? nil : channelId)
                    })
                }
            }
            |> introduceError(ChannelDiscussionGroupError.self)
            |> map { _ in
                return result
            }
        } else {
            return .single(result)
        }
    }
}
