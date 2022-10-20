import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi


public enum AvailableChannelDiscussionGroupError {
    case generic
}

func _internal_availableGroupsForChannelDiscussion(postbox: Postbox, network: Network) -> Signal<[Peer], AvailableChannelDiscussionGroupError> {
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
        |> castError(AvailableChannelDiscussionGroupError.self)
    }
}

public enum ChannelDiscussionGroupError {
    case generic
    case groupHistoryIsCurrentlyPrivate
    case hasNotPermissions
    case tooManyChannels
}

func _internal_updateGroupDiscussionForChannel(network: Network, postbox: Postbox, channelId: PeerId?, groupId: PeerId?) -> Signal<Bool, ChannelDiscussionGroupError> {
    return postbox.transaction { transaction -> (channel: Peer?, group: Peer?) in
        return (channel: channelId.flatMap(transaction.getPeer), group: groupId.flatMap(transaction.getPeer))
    }
    |> mapError { _ -> ChannelDiscussionGroupError in }
    |> mapToSignal { channel, group -> Signal<Bool, ChannelDiscussionGroupError> in
        let apiChannel = channel.flatMap(apiInputChannel) ?? Api.InputChannel.inputChannelEmpty
        let apiGroup = group.flatMap(apiInputChannel) ?? Api.InputChannel.inputChannelEmpty
        
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
                if let channelId = channelId {
                    var previousGroupId: CachedChannelData.LinkedDiscussionPeerId?
                    transaction.updatePeerCachedData(peerIds: Set([channelId]), update: { (_, current) -> CachedPeerData? in
                        let current: CachedChannelData = current as? CachedChannelData ?? CachedChannelData()
                        previousGroupId = current.linkedDiscussionPeerId
                        return current.withUpdatedLinkedDiscussionPeerId(.known(groupId))
                    })
                    if case let .known(maybeValue)? = previousGroupId, let value = maybeValue, value != groupId {
                        transaction.updatePeerCachedData(peerIds: Set([value]), update: { (_, current) -> CachedPeerData? in
                            let cachedData = (current as? CachedChannelData ?? CachedChannelData())
                            return cachedData.withUpdatedLinkedDiscussionPeerId(.known(nil))
                        })
                    }
                }
                if let groupId = groupId {
                    var previousChannelId: CachedChannelData.LinkedDiscussionPeerId?
                    transaction.updatePeerCachedData(peerIds: Set([groupId]), update: { (_, current) -> CachedPeerData? in
                        let current: CachedChannelData = current as? CachedChannelData ?? CachedChannelData()
                        previousChannelId = current.linkedDiscussionPeerId
                        return current.withUpdatedLinkedDiscussionPeerId(.known(channelId))
                    })
                    if case let .known(maybeValue)? = previousChannelId, let value = maybeValue, value != channelId {
                        transaction.updatePeerCachedData(peerIds: Set([value]), update: { (_, current) -> CachedPeerData? in
                            let cachedData = (current as? CachedChannelData ?? CachedChannelData())
                            return cachedData.withUpdatedLinkedDiscussionPeerId(.known(nil))
                        })
                    }
                }
            }
            |> castError(ChannelDiscussionGroupError.self)
            |> map { _ in
                return result
            }
        } else {
            return .single(result)
        }
    }
}
