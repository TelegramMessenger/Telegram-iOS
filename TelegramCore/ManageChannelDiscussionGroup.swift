import Foundation
#if os(macOS)
import SwiftSignalKitMac
import PostboxMac
#else
import SwiftSignalKit
import Postbox
#endif


public enum AvailableChannelDiscussionGroupError {
    case generic
}

public func availableGroupsForChannelDiscussion(network: Network) -> Signal<[Peer], AvailableChannelDiscussionGroupError> {
    return network.request(Api.functions.channels.getGroupsForDiscussion()) |> mapError { error in
        return .generic
    } |> map { result in
        let chats:[Api.Chat]
        switch result {
        case let .chats(c):
            chats = c
        case let .chatsSlice(_, c):
            chats = c
        }
        
        let peers = chats.compactMap {
            return parseTelegramGroupOrChannel(chat: $0)
        }
        
        return peers
    }
}

public func availableChannelsForGroupDiscussion(network: Network) -> Signal<[Peer], AvailableChannelDiscussionGroupError> {
    return network.request(Api.functions.channels.getBroadcastsForDiscussion()) |> mapError { _ in
        return .generic
        } |> map { result in
            let chats:[Api.Chat]
            switch result {
            case let .chats(c):
                chats = c
            case let .chatsSlice(_, c):
                chats = c
            }
            
            let peers = chats.compactMap {
                return parseTelegramGroupOrChannel(chat: $0)
            }
            
            return peers
    }
}

public enum ChannelDiscussionGroupError {
    case generic
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
            |> mapError { error in
                return .generic
            }
            |> map { result in
                switch result {
                    case .boolTrue:
                        return true
                    case .boolFalse:
                        return false
                }
            }
    } |> mapToSignal { result in
        if result {
            return postbox.transaction { transaction in
                var previousGroupId: PeerId?
                transaction.updatePeerCachedData(peerIds: Set([channelId]), update: { (_, current) -> CachedPeerData? in
                    let current: CachedChannelData = current as? CachedChannelData ?? CachedChannelData()
                    previousGroupId = current.linkedDiscussionPeerId
                    return current.withUpdatedLinkedDiscussionPeerId(groupId)
                })
                if let previousGroupId = previousGroupId {
                    transaction.updatePeerCachedData(peerIds: Set([previousGroupId]), update: { (_, current) -> CachedPeerData? in
                        return (current as? CachedChannelData ?? CachedChannelData()).withUpdatedLinkedDiscussionPeerId(nil)
                    })
                }
                if let groupId = groupId {
                    transaction.updatePeerCachedData(peerIds: Set([groupId]), update: { (_, current) -> CachedPeerData? in
                        return (current as? CachedChannelData ?? CachedChannelData()).withUpdatedLinkedDiscussionPeerId(channelId)
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
