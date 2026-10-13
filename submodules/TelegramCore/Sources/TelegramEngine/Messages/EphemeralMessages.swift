import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

private struct PreparedEphemeralMessageSend {
    let peerId: PeerId
    let localId: MessageId
    let botPeerId: PeerId
    let randomId: Int64
    let inputPeer: Api.InputPeer
    let inputUser: Api.InputUser
    let replyTo: Api.InputReplyTo?
    let message: Message
    let isWelcomeTemplate: Bool
}

func generateEphemeralLocalMessageId(peerId: PeerId, transaction: Transaction, namespace: MessageId.Namespace = Namespaces.Message.EphemeralLocal) -> MessageId {
    while true {
        var value: Int32 = 0
        arc4random_buf(&value, 4)
        if value == 0 {
            continue
        }
        let id: Int32
        if value == Int32.min {
            id = Int32.min
        } else {
            id = -abs(value)
        }
        let messageId = MessageId(peerId: peerId, namespace: namespace, id: id)
        if transaction.getMessage(messageId) == nil {
            return messageId
        }
    }
}

private func generateEphemeralOutgoingRandomId(_ current: Int64? = nil) -> Int64 {
    if let current, current != 0 {
        return current
    }
    while true {
        let value = Int64.random(in: Int64.min ... Int64.max)
        if value != 0 {
            return value
        }
    }
}

private func makeEphemeralStoreMessage(id: MessageId, accountPeerId: PeerId, botPeerId: PeerId, randomId: Int64, timestamp: Int32, text: String, entities: [MessageTextEntity], threadId: Int64?, replyAttribute: ReplyMessageAttribute?, state: EphemeralOutgoingMessageAttribute.State) -> StoreMessage {
    var flags = StoreMessageFlags()
    if state == .sending {
        flags.insert(.Sending)
    }

    var attributes: [MessageAttribute] = [
        TextEntitiesMessageAttribute(entities: entities),
        OutgoingMessageInfoAttribute(uniqueId: randomId, flags: [], acknowledged: false, correlationId: nil, bubbleUpEmojiOrStickersets: [], partialReference: nil),
        EphemeralOutgoingMessageAttribute(botPeerId: botPeerId, randomId: randomId, state: state)
    ]
    if let replyAttribute {
        attributes.append(replyAttribute)
    }

    return StoreMessage(
        id: id,
        customStableId: nil,
        globallyUniqueId: randomId,
        groupingKey: nil,
        threadId: threadId,
        timestamp: timestamp,
        flags: flags,
        tags: [],
        globalTags: [],
        localTags: [],
        forwardInfo: nil,
        authorId: accountPeerId,
        text: text,
        attributes: attributes,
        media: []
    )
}

private func preparedEphemeralReply(replyTo replySubject: EngineMessageReplySubject?, peerId: PeerId, threadId: Int64?, transaction: Transaction) -> (apiReplyTo: Api.InputReplyTo, attribute: ReplyMessageAttribute)? {
    guard let replySubject else {
        return nil
    }

    if replySubject.messageId.namespace == Namespaces.Message.EphemeralLocal {
        guard replySubject.messageId.id > 0 else {
            return nil
        }
        return (
            .inputReplyToEphemeralMessage(.init(id: replySubject.messageId.id)),
            ReplyMessageAttribute(messageId: replySubject.messageId, threadMessageId: nil, quote: nil, isQuote: false, innerSubject: nil)
        )
    }

    guard replySubject.messageId.namespace == Namespaces.Message.Cloud else {
        return nil
    }

    var topMsgId: Int32?
    if let threadId {
        topMsgId = Int32(clamping: threadId)
    }

    var replyFlags: Int32 = 0
    if topMsgId != nil {
        replyFlags |= 1 << 0
    }

    var replyToPeerId: Api.InputPeer?
    let requiresExplicitReplyPeer: Bool
    if let destinationPeer = transaction.getPeer(peerId) {
        requiresExplicitReplyPeer = outgoingReplyRequiresExplicitPeer(destinationPeer: destinationPeer, destinationThreadId: threadId, replyMessageId: replySubject.messageId, replyThreadId: transaction.getMessage(replySubject.messageId)?.threadId)
    } else {
        requiresExplicitReplyPeer = replySubject.messageId.peerId != peerId
    }
    if requiresExplicitReplyPeer {
        guard let replyPeer = transaction.getPeer(replySubject.messageId.peerId), let inputReplyPeer = apiInputPeer(replyPeer) else {
            return nil
        }
        replyToPeerId = inputReplyPeer
        replyFlags |= 1 << 1
    }

    var quoteText: String?
    var quoteEntities: [Api.MessageEntity]?
    var quoteOffset: Int32?
    if let replyQuote = replySubject.quote {
        quoteText = replyQuote.text
        replyFlags |= 1 << 2

        if !replyQuote.entities.isEmpty {
            var associatedPeers = SimpleDictionary<PeerId, Peer>()
            for entity in replyQuote.entities {
                for associatedPeerId in entity.associatedPeerIds {
                    if associatedPeers[associatedPeerId] == nil, let associatedPeer = transaction.getPeer(associatedPeerId) {
                        associatedPeers[associatedPeerId] = associatedPeer
                    }
                }
            }
            quoteEntities = apiEntitiesFromMessageTextEntities(replyQuote.entities, associatedPeers: associatedPeers)
            replyFlags |= 1 << 3
        }

        quoteOffset = replyQuote.offset.flatMap { Int32(clamping: $0) }
        if quoteOffset != nil {
            replyFlags |= 1 << 4
        }
    }

    var replyTodoItemId: Int32?
    var replyPollOption: Buffer?
    switch replySubject.innerSubject {
    case let .todoItem(todoItemId):
        replyTodoItemId = todoItemId
        replyFlags |= 1 << 6
    case let .pollOption(pollOption):
        replyPollOption = Buffer(data: pollOption)
        replyFlags |= 1 << 7
    default:
        break
    }

    let threadMessageId = topMsgId.flatMap { MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: $0) }
    return (
        .inputReplyToMessage(.init(flags: replyFlags, replyToMsgId: replySubject.messageId.id, topMsgId: topMsgId, replyToPeerId: replyToPeerId, quoteText: quoteText, quoteEntities: quoteEntities, quoteOffset: quoteOffset, monoforumPeerId: nil, todoItemId: replyTodoItemId, pollOption: replyPollOption)),
        ReplyMessageAttribute(messageId: replySubject.messageId, threadMessageId: threadMessageId, quote: replySubject.quote, isQuote: replySubject.quote != nil, innerSubject: replySubject.innerSubject)
    )
}

private func ephemeralOutgoingStoreMessageWithUpdatedState(_ message: Message, state: EphemeralOutgoingMessageAttribute.State) -> StoreMessage {
    var flags = StoreMessageFlags(message.flags)
    flags.remove(.Unsent)
    flags.remove(.Failed)
    if state == .sending {
        flags.insert(.Sending)
    } else {
        flags.remove(.Sending)
    }

    let attributes = message.attributes.map { attribute -> MessageAttribute in
        if let attribute = attribute as? EphemeralOutgoingMessageAttribute {
            return attribute.withUpdatedState(state)
        } else {
            return attribute
        }
    }

    return StoreMessage(id: message.id, customStableId: nil, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: message.author?.id, text: message.text, attributes: attributes, media: message.media)
}

private func enqueueEphemeralTextMessage(account: Account, peerId: PeerId, botPeerId: PeerId, threadId: Int64?, replyTo replySubject: EngineMessageReplySubject?, text: String, entities: [MessageTextEntity], randomId: Int64? = nil) -> Signal<MessageId?, NoError> {
    return account.postbox.transaction { transaction -> MessageId? in
        guard let peer = transaction.getPeer(peerId), let botPeer = transaction.getPeer(botPeerId), apiInputPeer(peer) != nil, apiInputUser(botPeer) != nil else {
            return nil
        }

        let reply = preparedEphemeralReply(replyTo: replySubject, peerId: peerId, threadId: threadId, transaction: transaction)
        let randomId = generateEphemeralOutgoingRandomId(randomId)
        let localId = generateEphemeralLocalMessageId(peerId: peerId, transaction: transaction)
        let timestamp = Int32(account.network.context.globalTime())
        let message = makeEphemeralStoreMessage(id: localId, accountPeerId: account.peerId, botPeerId: botPeerId, randomId: randomId, timestamp: timestamp, text: text, entities: entities, threadId: threadId, replyAttribute: reply?.attribute, state: .sending)
        let _ = transaction.addMessages([message], location: .Random)

        return localId
    }
}

private func preparedEphemeralMessageSend(account: Account, messageId: MessageId, setSending: Bool) -> Signal<PreparedEphemeralMessageSend?, NoError> {
    return account.postbox.transaction { transaction -> PreparedEphemeralMessageSend? in
        guard (messageId.namespace == Namespaces.Message.EphemeralLocal || messageId.namespace == Namespaces.Message.WelcomeMessageLocal), let currentMessage = transaction.getMessage(messageId), let outgoingAttribute = currentMessage.attributes.first(where: { $0 is EphemeralOutgoingMessageAttribute }) as? EphemeralOutgoingMessageAttribute, outgoingAttribute.randomId != 0, let peer = transaction.getPeer(messageId.peerId), let inputPeer = apiInputPeer(peer) else {
            return nil
        }
        let inputUser: Api.InputUser
        if outgoingAttribute.isWelcomeTemplate {
            inputUser = .inputUserEmpty
        } else {
            guard let botPeer = transaction.getPeer(outgoingAttribute.botPeerId), let value = apiInputUser(botPeer) else {
                return nil
            }
            inputUser = value
        }

        let replySubject: EngineMessageReplySubject?
        if let replyAttribute = currentMessage.attributes.first(where: { $0 is ReplyMessageAttribute }) as? ReplyMessageAttribute {
            replySubject = EngineMessageReplySubject(messageId: replyAttribute.messageId, quote: replyAttribute.quote, innerSubject: replyAttribute.innerSubject)
        } else {
            replySubject = nil
        }
        let reply = preparedEphemeralReply(replyTo: replySubject, peerId: messageId.peerId, threadId: currentMessage.threadId, transaction: transaction)

        if setSending {
            transaction.updateMessage(messageId, update: { currentMessage in
                return .update(ephemeralOutgoingStoreMessageWithUpdatedState(currentMessage, state: .sending))
            })
        }

        return PreparedEphemeralMessageSend(peerId: messageId.peerId, localId: messageId, botPeerId: outgoingAttribute.botPeerId, randomId: outgoingAttribute.randomId, inputPeer: inputPeer, inputUser: inputUser, replyTo: reply?.apiReplyTo, message: currentMessage, isWelcomeTemplate: outgoingAttribute.isWelcomeTemplate)
    }
}

private func failPendingEphemeralMessage(account: Account, peerId: PeerId, localId: MessageId, randomId: Int64) -> Signal<MessageId?, NoError> {
    return account.postbox.transaction { transaction -> MessageId? in
        let pendingId = transaction.messageIdForGloballyUniqueMessageId(peerId: peerId, id: randomId) ?? localId
        transaction.updateMessage(pendingId, update: { currentMessage in
            return .update(ephemeralOutgoingStoreMessageWithUpdatedState(currentMessage, state: .failed))
        })
        return pendingId
    }
}

private func outgoingEphemeralMessage(from updates: Api.Updates, prepared: PreparedEphemeralMessageSend, accountPeerId: PeerId) -> Api.EphemeralMessage? {
    for update in updates.allUpdates {
        switch update {
        case let .updateNewEphemeralMessage(updateNewEphemeralMessageData):
            let message = updateNewEphemeralMessageData.message
            if case let .ephemeralMessage(messageData) = message {
                if prepared.isWelcomeTemplate {
                    if (messageData.flags & (1 << 5)) != 0 && message.peerId == prepared.peerId {
                        return message
                    }
                } else {
                    if (messageData.flags & (1 << 0)) != 0 && message.peerId == prepared.peerId && messageData.fromId.peerId == accountPeerId && PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(messageData.receiverId)) == prepared.botPeerId {
                        return message
                    }
                }
            }
        default:
            break
        }
    }
    return nil
}

private func updatesWithoutWelcomeMessage(_ updates: Api.Updates, messageId: MessageId) -> Api.Updates? {
    let filterUpdates: ([Api.Update]) -> [Api.Update] = { updates in
        return updates.filter { update in
            if case let .updateNewEphemeralMessage(data) = update {
                return data.message.id != messageId
            } else {
                return true
            }
        }
    }

    switch updates {
    case let .updates(data):
        return .updates(Api.Updates.Cons_updates(updates: filterUpdates(data.updates), users: data.users, chats: data.chats, date: data.date, seq: data.seq))
    case let .updatesCombined(data):
        return .updatesCombined(Api.Updates.Cons_updatesCombined(updates: filterUpdates(data.updates), users: data.users, chats: data.chats, date: data.date, seqStart: data.seqStart, seq: data.seq))
    case let .updateShort(data):
        if case let .updateNewEphemeralMessage(updateData) = data.update, updateData.message.id == messageId {
            return nil
        } else {
            return updates
        }
    default:
        return updates
    }
}

func _internal_failStaleEphemeralOutgoingMessages(postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        var messageIds: [MessageId] = []
        for peerId in Set(transaction.chatListGetAllPeerIds()) {
            for namespace in [Namespaces.Message.EphemeralLocal, Namespaces.Message.WelcomeMessageLocal] {
                transaction.scanMessageAttributes(peerId: peerId, namespace: namespace, limit: Int.max, { id, attributes in
                    if attributes.contains(where: { attribute in
                        if let attribute = attribute as? EphemeralOutgoingMessageAttribute {
                            return attribute.state == .sending
                        } else {
                            return false
                        }
                    }) {
                        messageIds.append(id)
                    }
                    return true
                })
            }
        }

        for messageId in messageIds {
            transaction.updateMessage(messageId, update: { currentMessage in
                return .update(ephemeralOutgoingStoreMessageWithUpdatedState(currentMessage, state: .failed))
            })
        }
    }
}

private func completePendingEphemeralMessage(account: Account, prepared: PreparedEphemeralMessageSend, apiMessage: Api.EphemeralMessage) -> Signal<MessageId?, NoError> {
    return account.postbox.transaction { transaction -> MessageId? in
        guard let message = StoreMessage(apiEphemeralMessage: apiMessage), case let .Id(serverId) = message.id else {
            return nil
        }

        let pendingId = transaction.messageIdForGloballyUniqueMessageId(peerId: prepared.peerId, id: prepared.randomId) ?? prepared.localId
        let serverAlreadyExists = transaction.getMessage(serverId) != nil

        if serverAlreadyExists {
            if pendingId != serverId {
                transaction.deleteMessages([pendingId], forEachMedia: nil)
            }
            transaction.updateMessage(serverId, update: { _ in
                return .update(message)
            })
        } else if transaction.getMessage(pendingId) != nil {
            transaction.updateMessage(pendingId, update: { _ in
                return .update(message)
            })
        } else {
            let _ = transaction.addMessages([message], location: .Random)
        }

        if prepared.isWelcomeTemplate {
            updateCachedWelcomeMessagesFlag(transaction: transaction, peerId: prepared.peerId, hasWelcomeMessages: true)
        }

        return serverId
    }
}

func _internal_revertAnchoredEphemeralMessage(account: Account, messageId: MessageId) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> (Api.InputPeer, Api.InputUser, MessageId)? in
        guard let message = transaction.getMessage(messageId), let replacementAttribute = message.attributes.first(where: { $0 is EphemeralReplacementMessageAttribute }) as? EphemeralReplacementMessageAttribute, replacementAttribute.state == .active else {
            return nil
        }

        var attributes = message.attributes.filter { !($0 is EphemeralReplacementMessageAttribute) }
        attributes.append(EphemeralReplacementMessageAttribute(
            state: .reverted,
            replacementMessageId: replacementAttribute.replacementMessageId,
            receiverId: replacementAttribute.receiverId
        ))
        transaction.updateMessage(messageId, update: { currentMessage in
            return .update(StoreMessage(
                id: currentMessage.id,
                customStableId: nil,
                globallyUniqueId: currentMessage.globallyUniqueId,
                groupingKey: currentMessage.groupingKey,
                threadId: currentMessage.threadId,
                timestamp: currentMessage.timestamp,
                flags: StoreMessageFlags(currentMessage.flags),
                tags: currentMessage.tags,
                globalTags: currentMessage.globalTags,
                localTags: currentMessage.localTags,
                forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init),
                authorId: currentMessage.author?.id,
                text: currentMessage.text,
                attributes: attributes,
                media: currentMessage.media
            ))
        })
        transaction.deleteMessages([replacementAttribute.replacementMessageId], forEachMedia: nil)

        let receiverPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(replacementAttribute.receiverId))
        let inputUser: Api.InputUser?
        if receiverPeerId == account.peerId {
            inputUser = .inputUserSelf
        } else {
            inputUser = transaction.getPeer(receiverPeerId).flatMap(apiInputUser)
        }
        guard let inputPeer = transaction.getPeer(messageId.peerId).flatMap(apiInputPeer), let inputUser else {
            return nil
        }
        return (inputPeer, inputUser, replacementAttribute.replacementMessageId)
    }
    |> mapToSignal { request -> Signal<Never, NoError> in
        guard let (inputPeer, inputUser, replacementMessageId) = request else {
            return .complete()
        }
        return account.network.request(Api.functions.ephemeral.deleteMessage(flags: 1 << 0, peer: inputPeer, receiverId: inputUser, id: replacementMessageId.id))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> ignoreValues
    }
}

private func uploadedContentForPreparedEphemeralMessage(account: Account, prepared: PreparedEphemeralMessageSend) -> Signal<PendingMessageUploadedContentAndReuploadInfo?, NoError> {
    let contentToUpload = messageContentToUpload(accountPeerId: account.peerId, network: account.network, postbox: account.postbox, auxiliaryMethods: account.auxiliaryMethods, transformOutgoingMessageMedia: account.transformOutgoingMessageMedia, messageMediaPreuploadManager: account.messageMediaPreuploadManager, revalidationContext: account.mediaReferenceRevalidationContext, forceReupload: false, isGrouped: false, passFetchProgress: false, message: prepared.message)
    switch contentToUpload {
    case let .immediate(result, _):
        switch result {
        case let .content(content):
            return .single(content)
        case .progress:
            return .single(nil)
        }
    case let .signal(signal, _):
        return signal
        |> filter { result -> Bool in
            if case .content = result {
                return true
            } else {
                return false
            }
        }
        |> take(1)
        |> map { result -> PendingMessageUploadedContentAndReuploadInfo? in
            if case let .content(content) = result {
                return content
            } else {
                return nil
            }
        }
        |> `catch` { _ -> Signal<PendingMessageUploadedContentAndReuploadInfo?, NoError> in
            return .single(nil)
        }
    }
}

private func performPreparedEphemeralMessageSend(account: Account, prepared: PreparedEphemeralMessageSend) -> Signal<MessageId?, NoError> {
    let entitiesAttribute = prepared.message.attributes.first(where: { $0 is TextEntitiesMessageAttribute }) as? TextEntitiesMessageAttribute
    let apiEntities = entitiesAttribute.map { apiTextAttributeEntities($0, associatedPeers: prepared.message.peers) } ?? []
    var flags: Int32 = 0
    if !apiEntities.isEmpty {
        flags |= (1 << 1)
    }
    if prepared.replyTo != nil {
        flags |= (1 << 5)
    }
    if prepared.message.invertMedia {
        flags |= (1 << 6)
    }
    if prepared.isWelcomeTemplate {
        flags |= (1 << 7)
    }

    return uploadedContentForPreparedEphemeralMessage(account: account, prepared: prepared)
    |> mapToSignal { content -> Signal<MessageId?, NoError> in
        guard let content else {
            return failPendingEphemeralMessage(account: account, peerId: prepared.peerId, localId: prepared.localId, randomId: prepared.randomId)
        }

        let media: Api.InputMedia?
        let richMessage: Api.InputRichMessage?
        let messageText: String
        switch content.content {
        case let .text(text):
            media = nil
            if let richTextAttribute = prepared.message.attributes.first(where: { $0 is RichTextMessageAttribute }) as? RichTextMessageAttribute {
                richMessage = richTextAttribute.apiInputRichMessage()
                flags |= (1 << 4)
            } else {
                richMessage = nil
            }
            messageText = text
        case let .media(inputMedia, text):
            media = inputMedia
            richMessage = nil
            messageText = text
            flags |= (1 << 2)
        case let .richMessage(inputRichMessage):
            media = nil
            richMessage = inputRichMessage
            messageText = prepared.message.text
            flags |= (1 << 4)
        default:
            return failPendingEphemeralMessage(account: account, peerId: prepared.peerId, localId: prepared.localId, randomId: prepared.randomId)
        }

        flags |= (1 << 8)
        return account.network.request(Api.functions.ephemeral.sendMessage(flags: flags, peer: prepared.inputPeer, receiverId: prepared.inputUser, queryId: nil, message: messageText, entities: apiEntities.isEmpty ? nil : apiEntities, media: media, replyMarkup: nil, richMessage: richMessage, randomId: prepared.randomId, replyTo: prepared.replyTo))
        |> map { result -> Api.Updates? in
            return result
        }
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<MessageId?, NoError> in
            if let result {
                if let message = outgoingEphemeralMessage(from: result, prepared: prepared, accountPeerId: account.peerId) {
                    if prepared.isWelcomeTemplate {
                        let remainingUpdates = message.id.flatMap { updatesWithoutWelcomeMessage(result, messageId: $0) }
                        return completePendingEphemeralMessage(account: account, prepared: prepared, apiMessage: message)
                        |> afterNext { _ in
                            if let remainingUpdates {
                                account.stateManager.addUpdates(remainingUpdates)
                            }
                        }
                    } else {
                        account.stateManager.addUpdates(result)
                        return completePendingEphemeralMessage(account: account, prepared: prepared, apiMessage: message)
                    }
                } else {
                    account.stateManager.addUpdates(result)
                    return failPendingEphemeralMessage(account: account, peerId: prepared.peerId, localId: prepared.localId, randomId: prepared.randomId)
                }
            } else {
                return failPendingEphemeralMessage(account: account, peerId: prepared.peerId, localId: prepared.localId, randomId: prepared.randomId)
            }
        }
    }
}

func _internal_sendEphemeralOutgoingMessage(account: Account, messageId: MessageId) -> Signal<MessageId?, NoError> {
    return preparedEphemeralMessageSend(account: account, messageId: messageId, setSending: false)
    |> mapToSignal { prepared -> Signal<MessageId?, NoError> in
        guard let prepared else {
            return .single(nil)
        }
        return performPreparedEphemeralMessageSend(account: account, prepared: prepared)
    }
}

func _internal_retryEphemeralOutgoingMessage(account: Account, messageId: MessageId) -> Signal<MessageId?, NoError> {
    return preparedEphemeralMessageSend(account: account, messageId: messageId, setSending: true)
    |> mapToSignal { prepared -> Signal<MessageId?, NoError> in
        guard let prepared else {
            return .single(nil)
        }
        return performPreparedEphemeralMessageSend(account: account, prepared: prepared)
    }
}

private func updateCachedWelcomeMessagesFlag(transaction: Transaction, peerId: PeerId, hasWelcomeMessages: Bool) {
    transaction.updatePeerCachedData(peerIds: [peerId], update: { _, current in
        if let current = current as? CachedChannelData {
            var flags = current.flags
            if hasWelcomeMessages {
                flags.insert(.hasWelcomeMessages)
            } else {
                flags.remove(.hasWelcomeMessages)
            }
            return current.withUpdatedFlags(flags)
        } else if let current = current as? CachedGroupData {
            var flags = current.flags
            if hasWelcomeMessages {
                flags.insert(.hasWelcomeMessages)
            } else {
                flags.remove(.hasWelcomeMessages)
            }
            return current.withUpdatedFlags(flags)
        } else {
            return current
        }
    })
}

func _internal_refreshWelcomeMessages(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Api.ephemeral.WelcomeMessages?, NoError> in
        guard let inputPeer else {
            return .single(nil)
        }
        return account.network.request(Api.functions.ephemeral.getWelcomeMessages(peer: inputPeer, hash: 0))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.ephemeral.WelcomeMessages?, NoError> in
            return .single(nil)
        }
    }
    |> mapToSignal { (result: Api.ephemeral.WelcomeMessages?) -> Signal<Void, NoError> in
        guard let result else {
            return .complete()
        }
        return account.postbox.transaction { transaction -> Void in
            switch result {
            case let .welcomeMessages(data):
                var currentIds: [MessageId] = []
                transaction.scanMessageAttributes(peerId: peerId, namespace: Namespaces.Message.WelcomeMessageCloud, limit: Int.max, { id, _ in
                    currentIds.append(id)
                    return true
                })
                var currentStableIds: [MessageId: UInt32] = [:]
                for id in currentIds {
                    if let message = transaction.getMessage(id) {
                        currentStableIds[id] = message.stableId
                    }
                }
                if !currentIds.isEmpty {
                    transaction.deleteMessages(currentIds, forEachMedia: nil)
                }

                let messages = data.messages.compactMap { message -> StoreMessage? in
                    guard let message = StoreMessage(apiEphemeralMessage: message) else {
                        return nil
                    }
                    if case let .Id(id) = message.id, let stableId = currentStableIds[id] {
                        return message.withUpdatedCustomStableId(stableId)
                    } else {
                        return message
                    }
                }
                if !messages.isEmpty {
                    let _ = transaction.addMessages(messages, location: .Random)
                }
                updateCachedWelcomeMessagesFlag(transaction: transaction, peerId: peerId, hasWelcomeMessages: !messages.isEmpty)
            case .welcomeMessagesNotModified:
                break
            }
        }
    }
}

func _internal_deleteAllWelcomeMessages(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Bool, NoError> in
        guard let inputPeer else {
            return .single(false)
        }
        return account.network.request(Api.functions.ephemeral.deleteAllWelcomeMessages(peer: inputPeer))
        |> map { result -> Bool in
            if case .boolTrue = result {
                return true
            } else {
                return false
            }
        }
        |> `catch` { _ -> Signal<Bool, NoError> in
            return .single(false)
        }
    }
    |> mapToSignal { success -> Signal<Void, NoError> in
        guard success else {
            return .complete()
        }
        return account.postbox.transaction { transaction -> Void in
            var messageIds: [MessageId] = []
            for namespace in Namespaces.Message.allWelcomeMessages {
                transaction.scanMessageAttributes(peerId: peerId, namespace: namespace, limit: Int.max, { id, _ in
                    messageIds.append(id)
                    return true
                })
            }
            if !messageIds.isEmpty {
                transaction.deleteMessages(messageIds, forEachMedia: nil)
            }
            updateCachedWelcomeMessagesFlag(transaction: transaction, peerId: peerId, hasWelcomeMessages: false)
        }
    }
}
