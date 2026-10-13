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
    for media in message.effectiveMedia {
        addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
    }
}

func _internal_ephemeralReplacementMessageIds(transaction: Transaction, anchorIds: [MessageId]) -> [MessageId] {
    var result = Set<MessageId>()
    for anchorId in anchorIds {
        if let message = transaction.getMessage(anchorId), let attribute = message.attributes.first(where: { $0 is EphemeralReplacementMessageAttribute }) as? EphemeralReplacementMessageAttribute {
            result.insert(attribute.replacementMessageId)
        }
    }
    return Array(result)
}

func _internal_deleteEphemeralReplacements(transaction: Transaction, anchorIds: [MessageId]) {
    let replacementMessageIds = _internal_ephemeralReplacementMessageIds(transaction: transaction, anchorIds: anchorIds)
    if !replacementMessageIds.isEmpty {
        transaction.deleteMessages(replacementMessageIds, forEachMedia: nil)
    }
}

public func _internal_deleteMessages(transaction: Transaction, mediaBox: MediaBox, ids: [MessageId], deleteMedia: Bool = true, manualAddMessageThreadStatsDifference: ((MessageThreadKey, Int, Int) -> Void)? = nil) {
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
        let _ = mediaBox.removeCachedResources(Array(Set(resourceIds)), force: true).start()
    }
    for id in ids {
        if id.peerId.namespace == Namespaces.Peer.CloudChannel && id.namespace == Namespaces.Message.Cloud {
            if let message = transaction.getMessage(id) {
                if let threadId = message.threadId {
                    let messageThreadKey = MessageThreadKey(peerId: message.id.peerId, threadId: threadId)
                    if id.peerId.namespace == Namespaces.Peer.CloudChannel {
                        if let manualAddMessageThreadStatsDifference = manualAddMessageThreadStatsDifference {
                            manualAddMessageThreadStatsDifference(messageThreadKey, 0, 1)
                        } else {
                            updateMessageThreadStats(transaction: transaction, threadKey: messageThreadKey, removedCount: 1, addedMessagePeers: [])
                        }
                    }
                }
            }
        }
    }
    let replacementMessageIds = _internal_ephemeralReplacementMessageIds(transaction: transaction, anchorIds: ids)
    transaction.deleteMessages(ids + replacementMessageIds, forEachMedia: { _ in
    })
}

func _internal_deleteAllMessagesWithAuthor(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, authorId: PeerId, namespace: MessageId.Namespace) {
    var resourceIds: [MediaResourceId] = []
    transaction.removeAllMessagesWithAuthor(peerId, authorId: authorId, namespace: namespace, forEachMedia: { media in
        addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
    })
    if !resourceIds.isEmpty {
        let _ = mediaBox.removeCachedResources(Array(Set(resourceIds))).start()
    }
}

func _internal_deleteAllMessagesWithForwardAuthor(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, forwardAuthorId: PeerId, namespace: MessageId.Namespace) {
    var resourceIds: [MediaResourceId] = []
    transaction.removeAllMessagesWithForwardAuthor(peerId, forwardAuthorId: forwardAuthorId, namespace: namespace, forEachMedia: { media in
        addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
    })
    if !resourceIds.isEmpty {
        let _ = mediaBox.removeCachedResources(Array(Set(resourceIds)), force: true).start()
    }
}

func _internal_deleteAllReactionsWithAuthor(account: Account, peerId: PeerId, authorId: PeerId, aroundMessageId: MessageId?) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> (Peer?, Peer?) in
        let peer = transaction.getPeer(peerId)
        let author = transaction.getPeer(authorId)

        if peer.flatMap(apiInputPeer) != nil && author.flatMap(apiInputPeer) != nil {
            let anchor: HistoryViewInputAnchor
            if let aroundMessageId, aroundMessageId.peerId == peerId {
                anchor = .message(aroundMessageId)
            } else {
                anchor = .upperBound
            }
            let historyView = transaction.getMessagesHistoryViewState(input: .single(peerId: peerId, threadId: nil), ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), count: 50, clipHoles: true, anchor: anchor, namespaces: .just(Set([Namespaces.Message.Cloud])))
            for entry in historyView.entries {
                transaction.updateMessage(entry.message.id, update: { currentMessage in
                    var attributes = currentMessage.attributes
                    var updated = false

                    for i in 0 ..< attributes.count {
                        guard let attribute = attributes[i] as? ReactionsMessageAttribute else {
                            continue
                        }

                        let removedRecentPeers = attribute.recentPeers.filter { $0.peerId == authorId }
                        var updatedTopPeers = attribute.topPeers
                        var removedStarsTopPeerCount: Int32 = 0
                        for j in (0 ..< updatedTopPeers.count).reversed() {
                            if updatedTopPeers[j].peerId == authorId {
                                removedStarsTopPeerCount += updatedTopPeers[j].count
                                updatedTopPeers.remove(at: j)
                            }
                        }

                        if removedRecentPeers.isEmpty && removedStarsTopPeerCount == 0 {
                            continue
                        }

                        var updatedReactions = attribute.reactions
                        for removedRecentPeer in removedRecentPeers {
                            if let index = updatedReactions.firstIndex(where: { $0.value == removedRecentPeer.value }) {
                                if removedRecentPeer.value != .stars || removedStarsTopPeerCount == 0 {
                                    updatedReactions[index].count -= 1
                                }
                                if removedRecentPeer.isMy {
                                    updatedReactions[index].chosenOrder = nil
                                }
                            }
                        }
                        if removedStarsTopPeerCount != 0, let index = updatedReactions.firstIndex(where: { $0.value == .stars }) {
                            updatedReactions[index].count -= removedStarsTopPeerCount
                        }
                        for j in (0 ..< updatedReactions.count).reversed() {
                            if updatedReactions[j].count <= 0 {
                                updatedReactions.remove(at: j)
                            }
                        }

                        let updatedRecentPeers = attribute.recentPeers.filter { $0.peerId != authorId }
                        let updatedAttribute = ReactionsMessageAttribute(canViewList: attribute.canViewList, isTags: attribute.isTags, reactions: updatedReactions, recentPeers: updatedRecentPeers, topPeers: updatedTopPeers)
                        if updatedAttribute != attribute {
                            attributes[i] = updatedAttribute
                            updated = true
                        }
                    }

                    if !updated {
                        return .skip
                    }

                    var storeForwardInfo: StoreMessageForwardInfo?
                    if let forwardInfo = currentMessage.forwardInfo {
                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                    }

                    var tags = currentMessage.tags
                    if attributes.contains(where: { ($0 as? ReactionsMessageAttribute)?.hasUnseen == true }) {
                        tags.insert(.unseenReaction)
                    } else {
                        tags.remove(.unseenReaction)
                    }

                    return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                })
            }
        }

        return (peer, author)
    }
    |> mapToSignal { peer, author in
        guard let inputPeer = peer.flatMap(apiInputPeer), let inputAuthor = author.flatMap(apiInputPeer) else {
            return .complete()
        }
        return account.network.request(Api.functions.messages.deleteParticipantReactions(peer: inputPeer, participant: inputAuthor))
        |> ignoreValues
        |> `catch` { _ -> Signal<Never, NoError> in
            return .complete()
        }
    }
}

func _internal_deleteReaction(account: Account, messageId: MessageId, authorId: PeerId) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> (Peer?, Peer?) in
        let peer = transaction.getPeer(messageId.peerId)
        let author = transaction.getPeer(authorId)

        if peer.flatMap(apiInputPeer) != nil && author.flatMap(apiInputPeer) != nil {
            transaction.updateMessage(messageId, update: { currentMessage in
                var attributes = currentMessage.attributes
                var updated = false

                for i in 0 ..< attributes.count {
                    guard let attribute = attributes[i] as? ReactionsMessageAttribute else {
                        continue
                    }

                    let removedRecentPeers = attribute.recentPeers.filter { $0.peerId == authorId }
                    var updatedTopPeers = attribute.topPeers
                    var removedStarsTopPeerCount: Int32 = 0
                    for j in (0 ..< updatedTopPeers.count).reversed() {
                        if updatedTopPeers[j].peerId == authorId {
                            removedStarsTopPeerCount += updatedTopPeers[j].count
                            updatedTopPeers.remove(at: j)
                        }
                    }

                    if removedRecentPeers.isEmpty && removedStarsTopPeerCount == 0 {
                        continue
                    }

                    var updatedReactions = attribute.reactions
                    for removedRecentPeer in removedRecentPeers {
                        if let index = updatedReactions.firstIndex(where: { $0.value == removedRecentPeer.value }) {
                            if removedRecentPeer.value != .stars || removedStarsTopPeerCount == 0 {
                                updatedReactions[index].count -= 1
                            }
                            if removedRecentPeer.isMy {
                                updatedReactions[index].chosenOrder = nil
                            }
                        }
                    }
                    if removedStarsTopPeerCount != 0, let index = updatedReactions.firstIndex(where: { $0.value == .stars }) {
                        updatedReactions[index].count -= removedStarsTopPeerCount
                    }
                    for j in (0 ..< updatedReactions.count).reversed() {
                        if updatedReactions[j].count <= 0 {
                            updatedReactions.remove(at: j)
                        }
                    }

                    let updatedRecentPeers = attribute.recentPeers.filter { $0.peerId != authorId }
                    let updatedAttribute = ReactionsMessageAttribute(canViewList: attribute.canViewList, isTags: attribute.isTags, reactions: updatedReactions, recentPeers: updatedRecentPeers, topPeers: updatedTopPeers)
                    if updatedAttribute != attribute {
                        attributes[i] = updatedAttribute
                        updated = true
                    }
                }

                if !updated {
                    return .skip
                }

                var storeForwardInfo: StoreMessageForwardInfo?
                if let forwardInfo = currentMessage.forwardInfo {
                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                }

                var tags = currentMessage.tags
                if attributes.contains(where: { ($0 as? ReactionsMessageAttribute)?.hasUnseen == true }) {
                    tags.insert(.unseenReaction)
                } else {
                    tags.remove(.unseenReaction)
                }

                return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
            })
        }

        return (peer, author)
    }
    |> mapToSignal { peer, author in
        guard let inputPeer = peer.flatMap(apiInputPeer), let inputAuthor = author.flatMap(apiInputPeer) else {
            return .complete()
        }
        return account.network.request(Api.functions.messages.deleteParticipantReaction(peer: inputPeer, msgId: messageId.id, participant: inputAuthor))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { updates -> Signal<Never, NoError> in
            if let updates {
                account.stateManager.addUpdates(updates)
            }
            return .complete()
        }
    }
}

func _internal_clearHistory(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, threadId: Int64?, namespaces: MessageIdNamespaces) {
    if peerId.namespace == Namespaces.Peer.SecretChat {
        var resourceIds: [MediaResourceId] = []
        transaction.withAllMessages(peerId: peerId, { message in
            addMessageMediaResourceIdsToRemove(message: message, resourceIds: &resourceIds)
            return true
        })
        if !resourceIds.isEmpty {
            let _ = mediaBox.removeCachedResources(Array(Set(resourceIds)), force: true).start()
        }
    }
    transaction.clearHistory(peerId, threadId: threadId, minTimestamp: nil, maxTimestamp: nil, namespaces: namespaces, forEachMedia: { _ in
    })
}

func _internal_clearHistoryInRange(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, threadId: Int64?, minTimestamp: Int32, maxTimestamp: Int32, namespaces: MessageIdNamespaces) {
    if peerId.namespace == Namespaces.Peer.SecretChat {
        var resourceIds: [MediaResourceId] = []
        transaction.withAllMessages(peerId: peerId, { message in
            if message.timestamp >= minTimestamp && message.timestamp <= maxTimestamp {
                addMessageMediaResourceIdsToRemove(message: message, resourceIds: &resourceIds)
            }
            return true
        })
        if !resourceIds.isEmpty {
            let _ = mediaBox.removeCachedResources(Array(Set(resourceIds)), force: true).start()
        }
    }
    transaction.clearHistory(peerId, threadId: threadId, minTimestamp: minTimestamp, maxTimestamp: maxTimestamp, namespaces: namespaces, forEachMedia: { _ in
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
                case let .affectedFoundMessages(affectedFoundMessagesData):
                    let (pts, ptsCount, offset) = (affectedFoundMessagesData.pts, affectedFoundMessagesData.ptsCount, affectedFoundMessagesData.offset)
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
                        
                        if peerId.namespace == Namespaces.Peer.CloudUser {
                            let current = (current as? CachedUserData) ?? CachedUserData()
                            return current.withUpdatedAutoremoveTimeout(updatedTimeout)
                        } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                            let current = (current as? CachedChannelData) ?? CachedChannelData()
                            return current.withUpdatedAutoremoveTimeout(updatedTimeout)
                        } else if peerId.namespace == Namespaces.Peer.CloudGroup {
                            let current = (current as? CachedGroupData) ?? CachedGroupData()
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
