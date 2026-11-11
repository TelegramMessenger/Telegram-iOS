import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Message threads: thread read states, pinned forum topics, topic edits, reset forum topics and a monoforum thread's
/// paid-message exception.
extension ReplayContext {
    func applyUpdateReadThread(_ peerId: PeerId, _ threadId: Int64, _ readMaxId: Int32, _ isIncoming: Bool, _ mainChannelMessage: MessageId?) {
        let peerAndThreadId = PeerAndBoundThreadId(peerId: peerId, threadId: threadId)
        if isIncoming {
            if let currentId = updatedIncomingThreadReadStates[peerAndThreadId] {
                if currentId < readMaxId {
                    updatedIncomingThreadReadStates[peerAndThreadId] = readMaxId
                }
            } else {
                updatedIncomingThreadReadStates[peerAndThreadId] = readMaxId
            }
            if let channel = transaction.getPeer(peerAndThreadId.peerId) as? TelegramChannel, case .group = channel.info, (channel.flags.contains(.isForum) || channel.flags.contains(.isMonoforum)) {
                let threadId = peerAndThreadId.threadId
                if var data = transaction.getMessageHistoryThreadInfo(peerId: peerAndThreadId.peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
                    if readMaxId > data.maxIncomingReadId {
                        if let toIndex = transaction.getMessage(MessageId(peerId: peerAndThreadId.peerId, namespace: Namespaces.Message.Cloud, id: readMaxId))?.index {
                            if let count = transaction.getThreadMessageCount(peerId: peerAndThreadId.peerId, threadId: peerAndThreadId.threadId, namespace: Namespaces.Message.Cloud, fromIdExclusive: data.maxIncomingReadId, toIndex: toIndex) {
                                data.incomingUnreadCount = max(0, data.incomingUnreadCount - Int32(count))
                            }
                        }

                        if let topMessageIndex = transaction.getMessageHistoryThreadTopMessage(peerId: peerAndThreadId.peerId, threadId: threadId, namespaces: Set([Namespaces.Message.Cloud])) {
                            if readMaxId >= topMessageIndex.id.id {
                                let containingHole = transaction.getThreadIndexHole(peerId: peerAndThreadId.peerId, threadId: threadId, namespace: topMessageIndex.id.namespace, containing: topMessageIndex.id.id)
                                if let _ = containingHole[.everywhere] {
                                } else {
                                    data.incomingUnreadCount = 0
                                }
                            }
                        }

                        data.maxKnownMessageId = max(data.maxKnownMessageId, readMaxId)
                        data.maxIncomingReadId = max(data.maxIncomingReadId, readMaxId)

                        if let entry = StoredMessageHistoryThreadInfo(data) {
                            transaction.setMessageHistoryThreadInfo(peerId: peerAndThreadId.peerId, threadId: peerAndThreadId.threadId, info: entry)
                        }
                    }
                }
            }
            if let mainChannelMessage = mainChannelMessage {
                transaction.updateMessage(mainChannelMessage, update: { currentMessage in
                    var attributes = currentMessage.attributes
                    loop: for j in 0 ..< attributes.count {
                        if let attribute = attributes[j] as? ReplyThreadMessageAttribute {
                            if let maxReadMessageId = attribute.maxReadMessageId, maxReadMessageId > readMaxId {
                                return .skip
                            }
                            attributes[j] = ReplyThreadMessageAttribute(count: attribute.count, latestUsers: attribute.latestUsers, commentsPeerId: attribute.commentsPeerId, maxMessageId: attribute.maxMessageId, maxReadMessageId: readMaxId)
                            return .update(StoreMessage(updating: currentMessage, attributes: attributes, tags: currentMessage.tags))
                        }
                    }
                    return .skip
                })
            }
        } else {
            if let currentId = updatedOutgoingThreadReadStates[peerAndThreadId] {
                if currentId < readMaxId {
                    updatedOutgoingThreadReadStates[peerAndThreadId] = readMaxId
                }
            } else {
                updatedOutgoingThreadReadStates[peerAndThreadId] = readMaxId
            }
            if let channel = transaction.getPeer(peerAndThreadId.peerId) as? TelegramChannel, case .group = channel.info, (channel.flags.contains(.isForum) || channel.flags.contains(.isMonoforum)) {
                if var data = transaction.getMessageHistoryThreadInfo(peerId: peerAndThreadId.peerId, threadId: peerAndThreadId.threadId)?.data.get(MessageHistoryThreadData.self) {
                    if readMaxId >= data.maxOutgoingReadId {
                        data.maxOutgoingReadId = readMaxId

                        if let entry = StoredMessageHistoryThreadInfo(data) {
                            transaction.setMessageHistoryThreadInfo(peerId: peerAndThreadId.peerId, threadId: peerAndThreadId.threadId, info: entry)
                        }
                    }
                }
            } else if let user = transaction.getPeer(peerAndThreadId.peerId) as? TelegramUser, let botInfo = user.botInfo, botInfo.flags.contains(.hasForum) {
                if var data = transaction.getMessageHistoryThreadInfo(peerId: peerAndThreadId.peerId, threadId: peerAndThreadId.threadId)?.data.get(MessageHistoryThreadData.self) {
                    if readMaxId >= data.maxOutgoingReadId {
                        data.maxOutgoingReadId = readMaxId

                        if let entry = StoredMessageHistoryThreadInfo(data) {
                            transaction.setMessageHistoryThreadInfo(peerId: peerAndThreadId.peerId, threadId: peerAndThreadId.threadId, info: entry)
                        }
                    }
                }
            }
        }
    }
    
    func applyUpdatePinnedTopic(_ peerId: PeerId, _ threadId: Int64, _ isPinned: Bool) {
        var currentThreadIds = transaction.getPeerPinnedThreads(peerId: peerId)
        if isPinned {
            if !currentThreadIds.contains(threadId) {
                currentThreadIds.insert(threadId, at: 0)
            }
        } else {
            currentThreadIds.removeAll(where: { $0 == threadId })
        }
        transaction.setPeerPinnedThreads(peerId: peerId, threadIds: currentThreadIds)
    }
    
    /// A topic edit, from `updateEditForumTopic` or a `messageActionTopicEdit` service message, applied to the topic's
    /// stored info. A topic with no stored info keeps none: an info is kept only while the topic has a stored message,
    /// and its next fetch carries the edit.
    func applyEditForumTopic(_ peerId: PeerId, _ threadId: Int64, _ components: [TelegramMediaActionType.ForumTopicEditComponent]) {
        guard let initialData = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) else {
            return
        }
        var data = initialData

        for component in components {
            switch component {
            case let .title(title):
                data.info = EngineMessageHistoryThread.Info(title: title, icon: data.info.icon, iconColor: data.info.iconColor)
            case let .iconFileId(fileId):
                data.info = EngineMessageHistoryThread.Info(title: data.info.title, icon: fileId == 0 ? nil : fileId, iconColor: data.info.iconColor)
            case let .isClosed(isClosed):
                data.isClosed = isClosed
            case let .isHidden(isHidden):
                data.isHidden = isHidden
            }
        }

        if data != initialData {
            if let entry = StoredMessageHistoryThreadInfo(data) {
                transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: threadId, info: entry)
            }
        }
    }

    func applyUpdatePinnedTopicOrder(_ peerId: PeerId, _ threadIds: [Int64]) {
        transaction.setPeerPinnedThreads(peerId: peerId, threadIds: threadIds)
    }
    
    func applyResetForumTopic(_ topicId: PeerAndBoundThreadId, _ data: StoreMessageHistoryThreadData) {
        if finalState.state.resetForumTopicLists[topicId.peerId] == nil {
            if let entry = StoredMessageHistoryThreadInfo(data.data) {
                transaction.setMessageHistoryThreadInfo(peerId: topicId.peerId, threadId: topicId.threadId, info: entry)
            } else {
                assertionFailure()
            }
            transaction.replaceMessageTagSummary(peerId: topicId.peerId, threadId: topicId.threadId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, customTag: nil, count: data.unreadMentionCount, maxId: data.topMessageId)
            transaction.replaceMessageTagSummary(peerId: topicId.peerId, threadId: topicId.threadId, tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud, customTag: nil, count: data.unreadReactionCount, maxId: data.topMessageId)
            transaction.replaceMessageTagSummary(peerId: topicId.peerId, threadId: topicId.threadId, tagMask: .unseenPollVote, namespace: Namespaces.Message.Cloud, customTag: nil, count: data.unreadPollVoteCount, maxId: data.topMessageId)
        }
    }
    
    func applyUpdateMonoForumNoPaidException(_ peerId: PeerId, _ threadId: Int64, _ isFree: Bool) {
        if var data = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
            data.isMessageFeeRemoved = isFree

            if let entry = StoredMessageHistoryThreadInfo(data) {
                transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: threadId, info: entry)
            }
        }
    }
}
