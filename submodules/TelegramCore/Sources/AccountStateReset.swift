import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

private struct LocalChatListEntryRange {
    var entries: [ChatListNamespaceEntry]
    var upperBound: ChatListIndex?
    var lowerBound: ChatListIndex
    var count: Int32
    var hash: UInt32
    
    var apiHash: Int32 {
        return Int32(bitPattern: self.hash & UInt32(0x7FFFFFFF))
    }
}

private func combineHash(_ value: Int32, into hash: inout UInt32) {
    let low = UInt32(bitPattern: value)
    hash = (hash &* 20261) &+ low
}

private func combineChatListNamespaceEntryHash(index: ChatListIndex, readState: PeerReadState?, topMessageAttributes: [MessageAttribute], tagSummary: MessageHistoryTagNamespaceSummary?, interfaceState: PeerChatInterfaceState?, into hash: inout UInt32) {
    /*
     dialog.pinned ? 1 : 0,
     dialog.unread_mark ? 1 : 0,
     dialog.peer.channel_id || dialog.peer.chat_id || dialog.peer.user_id,
     dialog.top_message.id,
     top_message.edit_date || top_message.date,
     dialog.read_inbox_max_id,
     dialog.read_outbox_max_id,
     dialog.unread_count,
     dialog.unread_mentions_count,
     draft.draft.date || 0
     
     */
    
    combineHash(index.pinningIndex != nil ? 1 : 0, into: &hash)
    if let readState = readState, readState.markedUnread {
        combineHash(1, into: &hash)
    } else {
        combineHash(0, into: &hash)
    }
    combineHash(index.messageIndex.id.peerId.id, into: &hash)
    combineHash(index.messageIndex.id.id, into: &hash)
    var timestamp = index.messageIndex.timestamp
    for attribute in topMessageAttributes {
        if let attribute = attribute as? EditedMessageAttribute {
            timestamp = max(timestamp, attribute.date)
        }
    }
    combineHash(timestamp, into: &hash)
    if let readState = readState, case let .idBased(maxIncomingReadId, maxOutgoingReadId, _, count, _) = readState {
        combineHash(maxIncomingReadId, into: &hash)
        combineHash(maxOutgoingReadId, into: &hash)
        combineHash(count, into: &hash)
    } else {
        combineHash(0, into: &hash)
        combineHash(0, into: &hash)
        combineHash(0, into: &hash)
    }
    
    if let tagSummary = tagSummary {
        combineHash(tagSummary.count, into: &hash)
    } else {
        combineHash(0, into: &hash)
    }
    
    if let embeddedState = interfaceState?.chatListEmbeddedState {
        combineHash(embeddedState.timestamp, into: &hash)
    } else {
        combineHash(0, into: &hash)
    }
}

private func localChatListEntryRanges(_ entries: [ChatListNamespaceEntry], limit: Int) -> [LocalChatListEntryRange] {
    var result: [LocalChatListEntryRange] = []
    var currentRange: LocalChatListEntryRange?
    for i in 0 ..< entries.count {
        switch entries[i] {
            case let .peer(index, readState, topMessageAttributes, tagSummary, interfaceState):
                var updatedRange: LocalChatListEntryRange
                if let current = currentRange {
                    updatedRange = current
                } else {
                    updatedRange = LocalChatListEntryRange(entries: [], upperBound: result.last?.lowerBound, lowerBound: index, count: 0, hash: 0)
                }
                updatedRange.entries.append(entries[i])
                updatedRange.lowerBound = index
                updatedRange.count += 1
                
                combineChatListNamespaceEntryHash(index: index, readState: readState, topMessageAttributes: topMessageAttributes, tagSummary: tagSummary, interfaceState: interfaceState, into: &updatedRange.hash)
            
                if Int(updatedRange.count) >= limit {
                    result.append(updatedRange)
                    currentRange = nil
                } else {
                    currentRange = updatedRange
                }
            case .hole:
                if let currentRangeValue = currentRange {
                    result.append(currentRangeValue)
                    currentRange = nil
                }
        }
    }
    if let currentRangeValue = currentRange {
        result.append(currentRangeValue)
        currentRange = nil
    }
    return result
}

private struct ResolvedChatListResetRange {
    let head: Bool
    let local: LocalChatListEntryRange
    let remote: FetchedChatList
}

/*func accountStateReset(postbox: Postbox, network: Network, accountPeerId: PeerId) -> Signal<Void, NoError> {
    let pinnedChats: Signal<Api.messages.PeerDialogs, NoError> = network.request(Api.functions.messages.getPinnedDialogs(folderId: 0))
    |> retryRequest
    let state: Signal<Api.updates.State, NoError> = network.request(Api.functions.updates.getState())
    |> retryRequest
    
    return postbox.transaction { transaction -> [ChatListNamespaceEntry] in
        return transaction.getChatListNamespaceEntries(groupId: .root, namespace: Namespaces.Message.Cloud, summaryTag: MessageTags.unseenPersonalMessage)
    }
    |> mapToSignal { localChatListEntries -> Signal<Void, NoError> in
        let localRanges = localChatListEntryRanges(localChatListEntries, limit: 100)
        var signal: Signal<ResolvedChatListResetRange?, NoError> = .complete()
        for i in 0 ..< localRanges.count {
            let upperBound: MessageIndex
            let head = i == 0
            let localRange = localRanges[i]
            if let rangeUpperBound = localRange.upperBound {
                upperBound = rangeUpperBound.messageIndex.predecessor()
            } else {
                upperBound = MessageIndex(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.Empty, id: 0), namespace: Namespaces.Message.Cloud, id: 0), timestamp: 0)
            }
            
            let rangeSignal: Signal<ResolvedChatListResetRange?, NoError> = fetchChatList(postbox: postbox, network: network, location: .general, upperBound: upperBound, hash: localRange.apiHash, limit: localRange.count)
            |> map { remote -> ResolvedChatListResetRange? in
                if let remote = remote {
                    return ResolvedChatListResetRange(head: head, local: localRange, remote: remote)
                } else {
                    return nil
                }
            }
            
            signal = signal
            |> then(rangeSignal)
        }
        let collectedResolvedRanges: Signal<[ResolvedChatListResetRange], NoError> = signal
        |> map { next -> [ResolvedChatListResetRange] in
            if let next = next {
                return [next]
            } else {
                return []
            }
        }
        |> reduceLeft(value: [], f: { list, next in
            var list = list
            list.append(contentsOf: next)
            return list
        })
        
        return combineLatest(collectedResolvedRanges, state)
        |> mapToSignal { collectedRanges, state -> Signal<Void, NoError> in
            return postbox.transaction { transaction -> Void in
                for range in collectedRanges {
                    let previousPeerIds = transaction.resetChatList(keepPeerNamespaces: [Namespaces.Peer.SecretChat], upperBound: range.local.upperBound ?? ChatListIndex.absoluteUpperBound, lowerBound: range.local.lowerBound)
                    #if DEBUG
                    for peerId in previousPeerIds {
                        print("pre \(peerId) [\(transaction.getPeer(peerId)?.debugDisplayTitle ?? "nil")]")
                    }
                    print("pre hash \(range.local.hash)")
                    print("")
                    
                    var preRecalculatedHash: UInt32 = 0
                    for entry in range.local.entries {
                        switch entry {
                            case let .peer(index, readState, topMessageAttributes, tagSummary, interfaceState):
                                print("val \(index.messageIndex.id.peerId) [\(transaction.getPeer(index.messageIndex.id.peerId)?.debugDisplayTitle ?? "nil")]")
                                combineChatListNamespaceEntryHash(index: index, readState: readState, topMessageAttributes: topMessageAttributes, tagSummary: nil, interfaceState: nil, into: &preRecalculatedHash)
                            default:
                                break
                        }
                    }
                    print("pre recalculated hash \(preRecalculatedHash)")
                    print("")
                    
                    var hash: UInt32 = 0
                    range.remote.storeMessages.compactMap({ message -> MessageIndex? in
                        if case let .Id(id) = message.id {
                            if range.remote.topMessageIds[id.peerId] == id {
                                return message.index
                            }
                        }
                        return nil
                    }).sorted(by: { lhs, rhs in
                        return lhs > rhs
                    }).forEach({ index in
                        var topMessageAttributes: [MessageAttribute] = []
                        for message in range.remote.storeMessages {
                            if case let .Id(id) = message.id, id == index.id {
                                topMessageAttributes = message.attributes
                            }
                        }
                        combineChatListNamespaceEntryHash(index: ChatListIndex(pinningIndex: nil, messageIndex: index), readState: range.remote.readStates[index.id.peerId]?[Namespaces.Message.Cloud], topMessageAttributes: topMessageAttributes, tagSummary: nil, interfaceState: nil, into: &hash)
                        print("upd \(index.id.peerId) [\(transaction.getPeer(index.id.peerId)?.debugDisplayTitle ?? "nil")]")
                    })
                    print("upd hash \(hash)")
                    #endif
                    
                    updatePeers(transaction: transaction, peers: range.remote.peers, update: { _, updated -> Peer in
                        return updated
                    })
                    updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: range.remote.peerPresences)
                    
                    transaction.updateCurrentPeerNotificationSettings(range.remote.notificationSettings)
                    
                    var allPeersWithMessages = Set<PeerId>()
                    for message in range.remote.storeMessages {
                        allPeersWithMessages.insert(message.id.peerId)
                    }
                    
                    for (_, messageId) in range.remote.topMessageIds {
                        if messageId.id > 1 {
                            var skipHole = false
                            if let localTopId = transaction.getTopPeerMessageIndex(peerId: messageId.peerId, namespace: messageId.namespace)?.id {
                                if localTopId >= messageId {
                                    skipHole = true
                                }
                            }
                            if !skipHole {
                                //transaction.addHole(MessageId(peerId: messageId.peerId, namespace: messageId.namespace, id: messageId.id - 1))
                            }
                        }
                    }
                    
                    let _ = transaction.addMessages(range.remote.storeMessages, location: .UpperHistoryBlock)
                    
                    transaction.resetIncomingReadStates(range.remote.readStates)
                    
                    for (peerId, chatState) in range.remote.chatStates {
                        if let chatState = chatState as? ChannelState {
                            if let current = transaction.getPeerChatState(peerId) as? ChannelState {
                                transaction.setPeerChatState(peerId, state: current.withUpdatedPts(chatState.pts))
                            } else {
                                transaction.setPeerChatState(peerId, state: chatState)
                            }
                        } else {
                            transaction.setPeerChatState(peerId, state: chatState)
                        }
                    }
                    
                    for (peerId, summary) in range.remote.mentionTagSummaries {
                        transaction.replaceMessageTagSummary(peerId: peerId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: summary.count, maxId: summary.range.maxId)
                    }
                    
                    let namespacesWithHoles: [PeerId.Namespace: [MessageId.Namespace]] = [
                        Namespaces.Peer.CloudUser: [Namespaces.Message.Cloud],
                        Namespaces.Peer.CloudGroup: [Namespaces.Message.Cloud],
                        Namespaces.Peer.CloudChannel: [Namespaces.Message.Cloud]
                    ]
                    for peerId in previousPeerIds {
                        if !allPeersWithMessages.contains(peerId), let namespaces = namespacesWithHoles[peerId.namespace] {
                            for namespace in namespaces {
                                //transaction.addHole(MessageId(peerId: peerId, namespace: namespace, id: Int32.max - 1))
                            }
                        }
                    }
                    
                    if range.head {
                        transaction.setPinnedItemIds(groupId: nil, itemIds: range.remote.pinnedItemIds ?? [])
                    }
                }
                
                if let currentState = transaction.getState() as? AuthorizedAccountState, let embeddedState = currentState.state {
                    switch state {
                        case let .state(pts, _, _, seq, _):
                            transaction.setState(currentState.changedState(AuthorizedAccountState.State(pts: pts, qts: embeddedState.qts, date: embeddedState.date, seq: seq)))
                    }
                }
            }
        }
    }
}*/
