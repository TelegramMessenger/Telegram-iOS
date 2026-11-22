import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Read states: inbox and outbox maxima, read-state resets, unread marks, unseen-tag summaries, read message contents
/// and the feed.
extension ReplayContext {
    func applyReadInbox(_ messageId: MessageId) {
        transaction.applyIncomingReadMaxId(messageId)
    }
    
    func applyReadOutbox(_ messageId: MessageId, _ timestamp: Int32?) {
        transaction.applyOutgoingReadMaxId(messageId)
        if messageId.peerId != accountPeerId, messageId.peerId.namespace == Namespaces.Peer.CloudUser, let timestamp = timestamp {
            recordPeerActivityTimestamp(peerId: messageId.peerId, timestamp: timestamp, into: &peerActivityTimestamps)
        }
    }
    
    func applyResetReadState(_ peerId: PeerId, _ namespace: MessageId.Namespace, _ maxIncomingReadId: MessageId.Id, _ maxOutgoingReadId: MessageId.Id, _ maxKnownId: MessageId.Id, _ count: Int32, _ markedUnread: Bool?) {
        var markedUnreadValue: Bool = false
        if let markedUnread = markedUnread {
            markedUnreadValue = markedUnread
        } else if let states = transaction.getPeerReadStates(peerId) {
            inner: for (stateNamespace, stateValue) in states {
                if stateNamespace == namespace {
                    markedUnreadValue = stateValue.markedUnread
                    break inner
                }
            }
        }

        var ignore = false
        if let currentReadState = transaction.getCombinedPeerReadState(peerId) {
            loop: for (currentNamespace, currentState) in currentReadState.states {
                if namespace == currentNamespace {
                    switch currentState {
                    case let .idBased(localMaxIncomingReadId, _, _, localCount, localMarkedUnread):
                        if localReadMarkIsAheadOfServer(localMaxIncomingReadId: localMaxIncomingReadId, serverMaxIncomingReadId: maxIncomingReadId, serverCount: count, serverMarkedUnread: markedUnreadValue) {
                            transaction.setNeedsIncomingReadStateSynchronization(peerId)

                            transaction.resetIncomingReadStates([peerId: [namespace: .idBased(maxIncomingReadId: localMaxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: localCount, markedUnread: localMarkedUnread)]])

                            Logger.shared.log("State", "not applying incoming read state for \(peerId): \(localMaxIncomingReadId) > \(maxIncomingReadId)")
                            ignore = true
                        }
                    default:
                        break
                    }
                    break loop
                }
            }
        }
        if !ignore {
            transaction.resetIncomingReadStates([peerId: [namespace: .idBased(maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: count, markedUnread: markedUnreadValue)]])
        }
    }
    
    func applyResetIncomingReadState(_ groupId: PeerGroupId, _ peerId: PeerId, _ namespace: MessageId.Namespace, _ maxIncomingReadId: MessageId.Id, _ count: Int32, _ pts: Int32) {
        var ptsMatchesState = false
        if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
            if let state = transaction.getState() as? AuthorizedAccountState {
                if state.state?.pts == pts {
                    ptsMatchesState = true
                }
            }
        } else if peerId.namespace == Namespaces.Peer.CloudChannel {
            if let state = transaction.getPeerChatState(peerId) as? ChannelState {
                if state.pts == pts {
                    ptsMatchesState = true
                }
            }
        }

        if ptsMatchesState {
            var updatedStates: [(MessageId.Namespace, PeerReadState)] = transaction.getPeerReadStates(peerId) ?? []
            var foundState = false
            for i in 0 ..< updatedStates.count {
                if updatedStates[i].0 == namespace {
                    switch updatedStates[i].1 {
                        case let .idBased(currentMaxIncomingReadId, maxOutgoingReadId, maxKnownId, _, markedUnread):
                            updatedStates[i].1 = .idBased(maxIncomingReadId: max(currentMaxIncomingReadId, maxIncomingReadId), maxOutgoingReadId: maxOutgoingReadId, maxKnownId: max(maxKnownId, maxIncomingReadId), count: count, markedUnread: markedUnread)
                            foundState = true
                        case .indexBased:
                            assertionFailure()
                            break
                    }
                    break
                }
            }
            if !foundState {
                updatedStates.append((namespace, .idBased(maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxIncomingReadId, maxKnownId: maxIncomingReadId, count: count, markedUnread: false)))
                invalidateGroupStats.insert(groupId)
            }
            let stateDict = Dictionary(updatedStates, uniquingKeysWith: { lhs, _ in lhs })
            transaction.resetIncomingReadStates([peerId: stateDict])
        } else {
            transaction.applyIncomingReadMaxId(MessageId(peerId: peerId, namespace: namespace, id: maxIncomingReadId))
            transaction.setNeedsIncomingReadStateSynchronization(peerId)
            invalidateGroupStats.insert(groupId)
        }
    }
    
    func applyUpdatePeerChatUnreadMark(_ peerId: PeerId, _ threadId: Int64?, _ namespace: MessageId.Namespace, _ value: Bool) {
        if let threadId {
            if var data = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
                data.isMarkedUnread = value
                if let entry = StoredMessageHistoryThreadInfo(data) {
                    transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: threadId, info: entry)
                }
            }
        } else {
            transaction.applyMarkUnread(peerId: peerId, namespace: namespace, value: value, interactive: false)
        }
    }
    
    func applyResetMessageTagSummary(_ peerId: PeerId, _ tag: MessageTags, _ namespace: MessageId.Namespace, _ count: Int32, _ range: MessageHistoryTagNamespaceCountValidityRange) {
        transaction.replaceMessageTagSummary(peerId: peerId, threadId: nil, tagMask: tag, namespace: namespace, customTag: nil, count: count, maxId: range.maxId)
        if count == 0 {
            transaction.removeHole(peerId: peerId, threadId: nil, namespace: namespace, space: .tag(tag), range: 1 ... (Int32.max - 1))
            if tag == .unseenPersonalMessage {
                let ids = transaction.getMessageIndicesWithTag(peerId: peerId, threadId: nil, namespace: namespace, tag: tag).map({ $0.id })
                Logger.shared.log("State", "will call markUnseenPersonalMessage for \(ids.count) messages")
                for id in ids {
                    markUnseenPersonalMessage(transaction: transaction, id: id, addSynchronizeAction: false)
                }
            }
        }
    }
    
    func applyReadMessageContents(_ peerIdAndMessageIds: (PeerId?, Int64?, [Int32]), _ date: Int32?) {
        let (peerId, _, messageIds) = peerIdAndMessageIds

        if let peerId = peerId {
            for id in messageIds {
                markMessageContentAsConsumedRemotely(transaction: transaction, messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id), consumeDate: date)
            }
        } else {
            for messageId in transaction.messageIdsForGlobalIds(messageIds) {
                markMessageContentAsConsumedRemotely(transaction: transaction, messageId: messageId, consumeDate: date)
            }
        }
    }
    
    func applyUpdateReadFeed(_ filterId: Int32, _ maxPosition: EngineFeedPosition) {
        applyFeedReadState(transaction: transaction, filterId: filterId, maxPosition: maxPosition)
    }
}
