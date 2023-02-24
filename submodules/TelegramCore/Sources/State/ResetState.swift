import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

func _internal_resetAccountState(postbox: Postbox, network: Network, accountPeerId: PeerId) -> Signal<Never, NoError> {
    return network.request(Api.functions.updates.getState())
    |> retryRequest
    |> mapToSignal { state -> Signal<Never, NoError> in
        let chatList = fetchChatList(postbox: postbox, network: network, location: .general, upperBound: .absoluteUpperBound(), hash: 0, limit: 100)
        
        return chatList
        |> mapToSignal { fetchedChats -> Signal<Never, NoError> in
            guard let fetchedChats = fetchedChats else {
                return .never()
            }
            return withResolvedAssociatedMessages(postbox: postbox, source: .network(network), peers: Dictionary(fetchedChats.peers.map({ ($0.id, $0) }), uniquingKeysWith: { lhs, _ in lhs }), storeMessages: fetchedChats.storeMessages, { transaction, additionalPeers, additionalMessages -> Void in
                for peerId in transaction.chatListGetAllPeerIds() {
                    if peerId.namespace != Namespaces.Peer.SecretChat {
                        transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
                    }
                    
                    if peerId.namespace != Namespaces.Peer.SecretChat {
                        transaction.addHole(peerId: peerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
                    }
                    
                    if peerId.namespace == Namespaces.Peer.CloudChannel {
                        if let channel = transaction.getPeer(peerId) as? TelegramChannel, channel.flags.contains(.isForum) {
                            transaction.setPeerPinnedThreads(peerId: peerId, threadIds: [])
                            for threadId in transaction.setMessageHistoryThreads(peerId: peerId) {
                                transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: threadId, info: nil)
                                transaction.addHole(peerId: peerId, threadId: threadId, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
                            }
                        }
                        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, _ in nil })
                        transaction.setPeerThreadCombinedState(peerId: peerId, state: nil)
                    }
                }
                
                transaction.removeAllChatListEntries(groupId: .root, exceptPeerNamespace: Namespaces.Peer.SecretChat)
                transaction.removeAllChatListEntries(groupId: .group(1), exceptPeerNamespace: Namespaces.Peer.SecretChat)
                
                updatePeers(transaction: transaction, peers: fetchedChats.peers + additionalPeers, update: { _, updated -> Peer in
                    return updated
                })
                
                for (threadMessageId, data) in fetchedChats.threadInfos {
                    if let entry = StoredMessageHistoryThreadInfo(data.data) {
                        transaction.setMessageHistoryThreadInfo(peerId: threadMessageId.peerId, threadId: Int64(threadMessageId.id), info: entry)
                    }
                    transaction.replaceMessageTagSummary(peerId: threadMessageId.peerId, threadId: Int64(threadMessageId.id), tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: data.unreadMentionCount, maxId: data.topMessageId)
                    transaction.replaceMessageTagSummary(peerId: threadMessageId.peerId, threadId: Int64(threadMessageId.id), tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud, count: data.unreadReactionCount, maxId: data.topMessageId)
                }
                
                updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: fetchedChats.peerPresences)
                transaction.updateCurrentPeerNotificationSettings(fetchedChats.notificationSettings)
                let _ = transaction.addMessages(fetchedChats.storeMessages, location: .UpperHistoryBlock)
                let _ = transaction.addMessages(additionalMessages, location: .Random)
                transaction.resetIncomingReadStates(fetchedChats.readStates)
                
                for (peerId, autoremoveValue) in fetchedChats.ttlPeriods {
                    transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                        if peerId.namespace == Namespaces.Peer.CloudUser {
                            let current = (current as? CachedUserData) ?? CachedUserData()
                            return current.withUpdatedAutoremoveTimeout(autoremoveValue)
                        } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                            let current = (current as? CachedChannelData) ?? CachedChannelData()
                            return current.withUpdatedAutoremoveTimeout(autoremoveValue)
                        } else if peerId.namespace == Namespaces.Peer.CloudGroup {
                            let current = (current as? CachedGroupData) ?? CachedGroupData()
                            return current.withUpdatedAutoremoveTimeout(autoremoveValue)
                        } else {
                            return current
                        }
                    })
                }
                
                for hole in transaction.allChatListHoles(groupId: .root) {
                    transaction.replaceChatListHole(groupId: .root, index: hole.index, hole: nil)
                }
                for hole in transaction.allChatListHoles(groupId: .group(1)) {
                    transaction.replaceChatListHole(groupId: .group(1), index: hole.index, hole: nil)
                }
                
                if let hole = fetchedChats.lowerNonPinnedIndex.flatMap(ChatListHole.init) {
                    transaction.addChatListHole(groupId: .root, hole: hole)
                }
                transaction.addChatListHole(groupId: .group(1), hole: ChatListHole(index: MessageIndex(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(0)), namespace: Namespaces.Message.Cloud, id: 1), timestamp: Int32.max - 1)))
                
                for peerId in fetchedChats.chatPeerIds {
                    if let peer = transaction.getPeer(peerId) {
                        transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: transaction.getPeerChatListIndex(peerId)?.1.pinningIndex, minTimestamp: minTimestampForPeerInclusion(peer)))
                    } else {
                        assertionFailure()
                    }
                }
                
                for (peerId, peerGroupId) in fetchedChats.peerGroupIds {
                    if let peer = transaction.getPeer(peerId) {
                        transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: peerGroupId, pinningIndex: nil, minTimestamp: minTimestampForPeerInclusion(peer)))
                    } else {
                        assertionFailure()
                    }
                }
                
                for (peerId, pts) in fetchedChats.channelStates {
                    if let current = transaction.getPeerChatState(peerId) as? ChannelState {
                        transaction.setPeerChatState(peerId, state: current.withUpdatedPts(pts))
                    } else {
                        transaction.setPeerChatState(peerId, state: ChannelState(pts: pts, invalidatedPts: nil, synchronizedUntilMessageId: nil))
                    }
                }
                
                if let replacePinnedItemIds = fetchedChats.pinnedItemIds {
                    transaction.setPinnedItemIds(groupId: .root, itemIds: replacePinnedItemIds.map(PinnedItemId.peer))
                }
                
                for (peerId, summary) in fetchedChats.mentionTagSummaries {
                    transaction.replaceMessageTagSummary(peerId: peerId, threadId: nil, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: summary.count, maxId: summary.range.maxId)
                }
                for (peerId, summary) in fetchedChats.reactionTagSummaries {
                    transaction.replaceMessageTagSummary(peerId: peerId, threadId: nil, tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud, count: summary.count, maxId: summary.range.maxId)
                }
                
                for (groupId, summary) in fetchedChats.folderSummaries {
                    transaction.resetPeerGroupSummary(groupId: groupId, namespace: Namespaces.Message.Cloud, summary: summary)
                }
                
                transaction.reindexUnreadCounters()
                
                if let currentState = transaction.getState() as? AuthorizedAccountState {
                    switch state {
                    case let .state(pts, qts, date, seq, _):
                        transaction.setState(currentState.changedState(AuthorizedAccountState.State(pts: pts, qts: qts, date: date, seq: seq)))
                    }
                }
            })
            |> ignoreValues
        }
    }
}
