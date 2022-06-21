import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

func addMessageMediaResourceIdsToRemove(media: Media, resourceIds: inout [MediaResourceId]) {
    if let image = media as? TelegramMediaImage {
        for representation in image.representations {
            resourceIds.append(representation.resource.id)
        }
    } else if let file = media as? TelegramMediaFile {
        for representation in file.previewRepresentations {
            resourceIds.append(representation.resource.id)
        }
        resourceIds.append(file.resource.id)
    }
}

func addMessageMediaResourceIdsToRemove(message: Message, resourceIds: inout [MediaResourceId]) {
    for media in message.media {
        addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
    }
}

public func _internal_deleteMessages(transaction: Transaction, mediaBox: MediaBox, ids: [MessageId], deleteMedia: Bool = true, manualAddMessageThreadStatsDifference: ((MessageId, Int, Int) -> Void)? = nil) {
    var resourceIds: [MediaResourceId] = []
    if deleteMedia {
        for id in ids {
            if id.peerId.namespace == Namespaces.Peer.SecretChat {
                if let message = transaction.getMessage(id) {
                    addMessageMediaResourceIdsToRemove(message: message, resourceIds: &resourceIds)
                }
            }
        }
    }
    if !resourceIds.isEmpty {
        let _ = mediaBox.removeCachedResources(Set(resourceIds), force: true).start()
    }
    for id in ids {
        if id.peerId.namespace == Namespaces.Peer.CloudChannel && id.namespace == Namespaces.Message.Cloud {
            if let message = transaction.getMessage(id) {
                if let threadId = message.threadId {
                    let messageThreadId = makeThreadIdMessageId(peerId: message.id.peerId, threadId: threadId)
                    if id.peerId.namespace == Namespaces.Peer.CloudChannel {
                        if let manualAddMessageThreadStatsDifference = manualAddMessageThreadStatsDifference {
                            manualAddMessageThreadStatsDifference(messageThreadId, 0, 1)
                        } else {
                            updateMessageThreadStats(transaction: transaction, threadMessageId: messageThreadId, removedCount: 1, addedMessagePeers: [])
                        }
                    }
                }
            }
        }
    }
    transaction.deleteMessages(ids, forEachMedia: { _ in
    })
}

func _internal_deleteAllMessagesWithAuthor(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, authorId: PeerId, namespace: MessageId.Namespace) {
    var resourceIds: [MediaResourceId] = []
    transaction.removeAllMessagesWithAuthor(peerId, authorId: authorId, namespace: namespace, forEachMedia: { media in
        addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
    })
    if !resourceIds.isEmpty {
        let _ = mediaBox.removeCachedResources(Set(resourceIds)).start()
    }
}

func _internal_deleteAllMessagesWithForwardAuthor(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, forwardAuthorId: PeerId, namespace: MessageId.Namespace) {
    var resourceIds: [MediaResourceId] = []
    transaction.removeAllMessagesWithForwardAuthor(peerId, forwardAuthorId: forwardAuthorId, namespace: namespace, forEachMedia: { media in
        addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
    })
    if !resourceIds.isEmpty {
        let _ = mediaBox.removeCachedResources(Set(resourceIds), force: true).start()
    }
}

func _internal_clearHistory(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, namespaces: MessageIdNamespaces) {
    if peerId.namespace == Namespaces.Peer.SecretChat {
        var resourceIds: [MediaResourceId] = []
        transaction.withAllMessages(peerId: peerId, { message in
            addMessageMediaResourceIdsToRemove(message: message, resourceIds: &resourceIds)
            return true
        })
        if !resourceIds.isEmpty {
            let _ = mediaBox.removeCachedResources(Set(resourceIds), force: true).start()
        }
    }
    transaction.clearHistory(peerId, minTimestamp: nil, maxTimestamp: nil, namespaces: namespaces, forEachMedia: { _ in
    })
}

func _internal_clearHistoryInRange(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, minTimestamp: Int32, maxTimestamp: Int32, namespaces: MessageIdNamespaces) {
    if peerId.namespace == Namespaces.Peer.SecretChat {
        var resourceIds: [MediaResourceId] = []
        transaction.withAllMessages(peerId: peerId, { message in
            if message.timestamp >= minTimestamp && message.timestamp <= maxTimestamp {
                addMessageMediaResourceIdsToRemove(message: message, resourceIds: &resourceIds)
            }
            return true
        })
        if !resourceIds.isEmpty {
            let _ = mediaBox.removeCachedResources(Set(resourceIds), force: true).start()
        }
    }
    transaction.clearHistory(peerId, minTimestamp: minTimestamp, maxTimestamp: maxTimestamp, namespaces: namespaces, forEachMedia: { _ in
    })
}

public enum ClearCallHistoryError {
    case generic
}

func _internal_clearCallHistory(account: Account, forEveryone: Bool) -> Signal<Never, ClearCallHistoryError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        var flags: Int32 = 0
        if forEveryone {
            flags |= 1 << 0
        }
        
        let signal = account.network.request(Api.functions.messages.deletePhoneCallHistory(flags: flags))
        |> map { result -> Api.messages.AffectedFoundMessages? in
            return result
        }
        |> `catch` { _ -> Signal<Api.messages.AffectedFoundMessages?, Bool> in
            return .fail(false)
        }
        |> mapToSignal { result -> Signal<Void, Bool> in
            if let result = result {
                switch result {
                case let .affectedFoundMessages(pts, ptsCount, offset, _):
                    account.stateManager.addUpdateGroups([.updatePts(pts: pts, ptsCount: ptsCount)])
                    if offset == 0 {
                        return .fail(true)
                    } else {
                        return .complete()
                    }
                }
            } else {
                return .fail(true)
            }
        }
        return (signal
        |> restart)
        |> `catch` { success -> Signal<Void, NoError> in
            if success {
                return account.postbox.transaction { transaction -> Void in
                    transaction.removeAllMessagesWithGlobalTag(tag: GlobalMessageTags.Calls)
                }
            } else {
                return .complete()
            }
        }
    }
    |> switchToLatest
    |> ignoreValues
    |> castError(ClearCallHistoryError.self)
}

public enum SetChatMessageAutoremoveTimeoutError {
    case generic
}

func _internal_setChatMessageAutoremoveTimeoutInteractively(account: Account, peerId: PeerId, timeout: Int32?) -> Signal<Never, SetChatMessageAutoremoveTimeoutError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> castError(SetChatMessageAutoremoveTimeoutError.self)
    |> mapToSignal { inputPeer -> Signal<Never, SetChatMessageAutoremoveTimeoutError> in
        guard let inputPeer = inputPeer else {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.messages.setHistoryTTL(peer: inputPeer, period: timeout ?? 0))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> castError(SetChatMessageAutoremoveTimeoutError.self)
        |> mapToSignal { result -> Signal<Never, SetChatMessageAutoremoveTimeoutError> in
            if let result = result {
                account.stateManager.addUpdates(result)
                
                return account.postbox.transaction { transaction -> Void in
                    transaction.updatePeerCachedData(peerIds: [peerId], update: { _, current in
                        let updatedTimeout: CachedPeerAutoremoveTimeout
                        if let timeout = timeout {
                            updatedTimeout = .known(CachedPeerAutoremoveTimeout.Value(peerValue: timeout))
                        } else {
                            updatedTimeout = .known(nil)
                        }
                        
                        if let current = current as? CachedUserData {
                            return current.withUpdatedAutoremoveTimeout(updatedTimeout)
                        } else if let current = current as? CachedGroupData {
                            return current.withUpdatedAutoremoveTimeout(updatedTimeout)
                        } else if let current = current as? CachedChannelData {
                            return current.withUpdatedAutoremoveTimeout(updatedTimeout)
                        } else {
                            return current
                        }
                    })
                }
                |> castError(SetChatMessageAutoremoveTimeoutError.self)
                |> ignoreValues
            } else {
                return .fail(.generic)
            }
        }
        |> `catch` { _ -> Signal<Never, SetChatMessageAutoremoveTimeoutError> in
            return .complete()
        }
    }
}
