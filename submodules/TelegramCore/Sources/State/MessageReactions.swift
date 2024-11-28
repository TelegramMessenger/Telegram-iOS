import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum UpdateMessageReaction {
    case builtin(String)
    case custom(fileId: Int64, file: TelegramMediaFile?)
    case stars
    
    public var reaction: MessageReaction.Reaction {
        switch self {
        case let .builtin(value):
            return .builtin(value)
        case let .custom(fileId, _):
            return .custom(fileId)
        case .stars:
            return .stars
        }
    }
}

public func updateMessageReactionsInteractively(account: Account, messageIds: [MessageId], reactions: [UpdateMessageReaction], isLarge: Bool, storeAsRecentlyUsed: Bool, add: Bool = false) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Void in
        guard let chatPeerId = messageIds.first?.peerId else {
            return
        }
        
        var messagesWithoutGroups: [Message] = []
        var messagesByGroupId: [Int64: [Message]] = [:]
        
        let messages = messageIds.compactMap { transaction.getMessage($0) }
        for message in messages {
            if let groupingKey = message.groupingKey {
                if messagesByGroupId[groupingKey] == nil {
                    messagesByGroupId[groupingKey] = [message]
                } else {
                    messagesByGroupId[groupingKey]?.append(message)
                }
            } else {
                messagesWithoutGroups.append(message)
            }
        }
        
        var messageIds: [MessageId] = []
        for message in messagesWithoutGroups {
            messageIds.append(message.id)
        }
        for (_, messages) in messagesByGroupId {
            if let minMessageId = messages.map(\.id).min() {
                messageIds.append(minMessageId)
            }
        }
        
        var sendAsPeerId = account.peerId
        if let cachedData = transaction.getPeerCachedData(peerId: chatPeerId) {
            if let cachedData = cachedData as? CachedChannelData {
                if let sendAsPeerIdValue = cachedData.sendAsPeerId {
                    sendAsPeerId = sendAsPeerIdValue
                }
            }
        }
        
        let isPremium = (transaction.getPeer(account.peerId) as? TelegramUser)?.isPremium ?? false
        let appConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self) ?? .defaultValue
        let maxCount: Int
        if isPremium {
            let limitsConfiguration = UserLimitsConfiguration(appConfiguration: appConfiguration, isPremium: isPremium)
            maxCount = Int(limitsConfiguration.maxReactionsPerMessage)
        } else {
            maxCount = 1
        }
        
        for messageId in messageIds {
            var mappedReactions: [PendingReactionsMessageAttribute.PendingReaction] = []
            
            var reactions: [UpdateMessageReaction] = reactions
            if add {
                if let message = transaction.getMessage(messageId), let effectiveReactions = message.effectiveReactions(isTags: message.areReactionsTags(accountPeerId: account.peerId)) {
                    for reaction in effectiveReactions {
                        if !reactions.contains(where: { $0.reaction == reaction.value }) {
                            let mappedValue: UpdateMessageReaction
                            switch reaction.value {
                            case let .builtin(value):
                                mappedValue = .builtin(value)
                            case let .custom(fileId):
                                mappedValue = .custom(fileId: fileId, file: nil)
                            case .stars:
                                mappedValue = .stars
                            }
                            reactions.append(mappedValue)
                        }
                    }
                }
            }
            
            for reaction in reactions {
                switch reaction {
                case let .custom(fileId, file):
                    mappedReactions.append(PendingReactionsMessageAttribute.PendingReaction(value: .custom(fileId), sendAsPeerId: sendAsPeerId))
                    if let file = file {
                        transaction.storeMediaIfNotPresent(media: file)
                    }
                case let .builtin(value):
                    mappedReactions.append(PendingReactionsMessageAttribute.PendingReaction(value: .builtin(value), sendAsPeerId: sendAsPeerId))
                case .stars:
                    mappedReactions.append(PendingReactionsMessageAttribute.PendingReaction(value: .stars, sendAsPeerId: sendAsPeerId))
                }
            }
            
            transaction.setPendingMessageAction(type: .updateReaction, id: messageId, action: UpdateMessageReactionsAction())
            transaction.updateMessage(messageId, update: { currentMessage in
                var storeForwardInfo: StoreMessageForwardInfo?
                if let forwardInfo = currentMessage.forwardInfo {
                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                }
                var attributes = currentMessage.attributes
            loop: for j in 0 ..< attributes.count {
                if let _ = attributes[j] as? PendingReactionsMessageAttribute {
                    attributes.remove(at: j)
                    break loop
                }
            }
                
                if storeAsRecentlyUsed {
                    let isTags = currentMessage.areReactionsTags(accountPeerId: account.peerId)
                    if !isTags {
                        let effectiveReactions = currentMessage.effectiveReactions(isTags: isTags) ?? []
                        for updatedReaction in reactions {
                            if !effectiveReactions.contains(where: { $0.value == updatedReaction.reaction && $0.isSelected }) {
                                let recentReactionItem: RecentReactionItem
                                switch updatedReaction {
                                case let .builtin(value):
                                    recentReactionItem = RecentReactionItem(.builtin(value))
                                case let .custom(fileId, file):
                                    if let file = file ?? (transaction.getMedia(MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)) as? TelegramMediaFile) {
                                        recentReactionItem = RecentReactionItem(.custom(file))
                                    } else {
                                        continue
                                    }
                                case .stars:
                                    recentReactionItem = RecentReactionItem(.stars)
                                }
                                
                                if let entry = CodableEntry(recentReactionItem) {
                                    let itemEntry = OrderedItemListEntry(id: recentReactionItem.id.rawValue, contents: entry)
                                    transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentReactions, item: itemEntry, removeTailIfCountExceeds: 50)
                                }
                            }
                        }
                    }
                }
                
                var mappedReactions = mappedReactions
                
                let updatedReactions = mergedMessageReactions(attributes: attributes + [PendingReactionsMessageAttribute(accountPeerId: account.peerId, reactions: mappedReactions, isLarge: isLarge, storeAsRecentlyUsed: storeAsRecentlyUsed, isTags: currentMessage.areReactionsTags(accountPeerId: account.peerId))], isTags: currentMessage.areReactionsTags(accountPeerId: account.peerId))?.reactions ?? []
                let updatedOutgoingReactions = updatedReactions.filter(\.isSelected)
                if updatedOutgoingReactions.count > maxCount {
                    let sortedOutgoingReactions = updatedOutgoingReactions.sorted(by: { $0.chosenOrder! < $1.chosenOrder! })
                    mappedReactions = Array(sortedOutgoingReactions.suffix(maxCount).map { reaction -> PendingReactionsMessageAttribute.PendingReaction in
                        return PendingReactionsMessageAttribute.PendingReaction(value: reaction.value, sendAsPeerId: sendAsPeerId)
                    })
                }
                
                attributes.append(PendingReactionsMessageAttribute(accountPeerId: account.peerId, reactions: mappedReactions, isLarge: isLarge, storeAsRecentlyUsed: storeAsRecentlyUsed, isTags: currentMessage.areReactionsTags(accountPeerId: account.peerId)))
                
                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
            })
        }
    }
    |> ignoreValues
}

func _internal_sendStarsReactionsInteractively(account: Account, messageId: MessageId, count: Int, isAnonymous: Bool?) -> Signal<Bool, NoError> {
    return account.postbox.transaction { transaction -> Bool in
        transaction.setPendingMessageAction(type: .sendStarsReaction, id: messageId, action: SendStarsReactionsAction(randomId: Int64.random(in: Int64.min ... Int64.max)))
        var resolvedIsAnonymousValue = false
        transaction.updateMessage(messageId, update: { currentMessage in
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
            }
            var mappedCount = Int32(count)
            var attributes = currentMessage.attributes
            var resolvedIsAnonymous = _internal_getStarsReactionDefaultToPrivate(transaction: transaction)
            for attribute in attributes {
                if let attribute = attribute as? ReactionsMessageAttribute {
                    if let myReaction = attribute.topPeers.first(where: { $0.isMy }) {
                        resolvedIsAnonymous = myReaction.isAnonymous
                    }
                }
            }
            loop: for j in 0 ..< attributes.count {
                if let current = attributes[j] as? PendingStarsReactionsMessageAttribute {
                    mappedCount += current.count
                    resolvedIsAnonymous = current.isAnonymous
                    attributes.remove(at: j)
                    break loop
                }
            }
            
            if let isAnonymous {
                resolvedIsAnonymous = isAnonymous
                _internal_setStarsReactionDefaultToPrivate(isPrivate: isAnonymous, transaction: transaction)
            }
                
            attributes.append(PendingStarsReactionsMessageAttribute(accountPeerId: account.peerId, count: mappedCount, isAnonymous: resolvedIsAnonymous))
            
            resolvedIsAnonymousValue = resolvedIsAnonymous
            
            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
        })
        
        return resolvedIsAnonymousValue
    }
}

func cancelPendingSendStarsReactionInteractively(account: Account, messageId: MessageId) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Void in
        transaction.setPendingMessageAction(type: .sendStarsReaction, id: messageId, action: nil)
        transaction.updateMessage(messageId, update: { currentMessage in
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
            }
            var attributes = currentMessage.attributes
            loop: for j in 0 ..< attributes.count {
                if let _ = attributes[j] as? PendingStarsReactionsMessageAttribute {
                    attributes.remove(at: j)
                    break loop
                }
            }
            
            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
        })
    }
    |> ignoreValues
}

func _internal_forceSendPendingSendStarsReaction(account: Account, messageId: MessageId) -> Signal<Never, NoError> {
    account.stateManager.forceSendPendingStarsReaction(messageId: messageId)
    
    return .complete()
}

func _internal_updateStarsReactionIsAnonymous(account: Account, messageId: MessageId, isAnonymous: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        _internal_setStarsReactionDefaultToPrivate(isPrivate: isAnonymous, transaction: transaction)
        
        transaction.updateMessage(messageId, update: { currentMessage in
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
            }
            var attributes = currentMessage.attributes
            for j in (0 ..< attributes.count).reversed() {
                if let attribute = attributes[j] as? ReactionsMessageAttribute {
                    var updatedTopPeers = attribute.topPeers
                    if let index = updatedTopPeers.firstIndex(where: { $0.isMy }) {
                        updatedTopPeers[index].isAnonymous = isAnonymous
                    }
                    attributes[j] = ReactionsMessageAttribute(canViewList: attribute.canViewList, isTags: attribute.isTags, reactions: attribute.reactions, recentPeers: attribute.recentPeers, topPeers: updatedTopPeers)
                }
            }
            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
        })
        
        return transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Never, NoError> in
        guard let inputPeer else {
            return .complete()
        }
        
        return account.network.request(Api.functions.messages.togglePaidReactionPrivacy(peer: inputPeer, msgId: messageId.id, private: isAnonymous ? .boolTrue : .boolFalse))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> ignoreValues
    }
}

private enum RequestUpdateMessageReactionError {
    case generic
}

private func requestUpdateMessageReaction(postbox: Postbox, network: Network, stateManager: AccountStateManager, messageId: MessageId) -> Signal<Never, RequestUpdateMessageReactionError> {
    return postbox.transaction { transaction -> (Peer, [MessageReaction.Reaction]?, Bool, Bool)? in
        guard let peer = transaction.getPeer(messageId.peerId) else {
            return nil
        }
        guard let message = transaction.getMessage(messageId) else {
            return nil
        }
        var reactions: [MessageReaction.Reaction]?
        var isLarge: Bool = false
        var storeAsRecentlyUsed: Bool = false
        for attribute in message.attributes {
            if let attribute = attribute as? PendingReactionsMessageAttribute {
                if !attribute.reactions.isEmpty {
                    reactions = attribute.reactions.map(\.value)
                }
                isLarge = attribute.isLarge
                storeAsRecentlyUsed = attribute.storeAsRecentlyUsed
                break
            }
        }
        return (peer, reactions, isLarge, storeAsRecentlyUsed)
    }
    |> castError(RequestUpdateMessageReactionError.self)
    |> mapToSignal { peerAndValue in
        guard let (peer, reactions, isLarge, storeAsRecentlyUsed) = peerAndValue else {
            return .fail(.generic)
        }
        guard let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }
        if messageId.namespace != Namespaces.Message.Cloud {
            return .fail(.generic)
        }
        
        var flags: Int32 = 0
        if reactions != nil {
            flags |= 1 << 0
            if isLarge {
                flags |= 1 << 1
            }
            if storeAsRecentlyUsed {
                flags |= 1 << 2
            }
        }
        
        let signal: Signal<Never, RequestUpdateMessageReactionError> = network.request(Api.functions.messages.sendReaction(flags: flags, peer: inputPeer, msgId: messageId.id, reaction: reactions?.map(\.apiReaction)))
        |> mapError { _ -> RequestUpdateMessageReactionError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, RequestUpdateMessageReactionError> in
            return postbox.transaction { transaction -> Void in
                transaction.setPendingMessageAction(type: .updateReaction, id: messageId, action: UpdateMessageReactionsAction())
                transaction.updateMessage(messageId, update: { currentMessage in
                    var storeForwardInfo: StoreMessageForwardInfo?
                    if let forwardInfo = currentMessage.forwardInfo {
                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                    }
                    let reactions = mergedMessageReactions(attributes: currentMessage.attributes, isTags: currentMessage.areReactionsTags(accountPeerId: stateManager.accountPeerId))
                    var attributes = currentMessage.attributes
                    for j in (0 ..< attributes.count).reversed() {
                        if attributes[j] is PendingReactionsMessageAttribute || attributes[j] is ReactionsMessageAttribute {
                            attributes.remove(at: j)
                        }
                    }
                    if let reactions = reactions {
                        attributes.append(reactions)
                    }
                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                })
                stateManager.addUpdates(result)
            }
            |> castError(RequestUpdateMessageReactionError.self)
            |> ignoreValues
        }
        #if DEBUG
        return signal |> delay(0.1, queue: .mainQueue())
        #else
        return signal
        #endif
    }
}

private func requestSendStarsReaction(postbox: Postbox, network: Network, stateManager: AccountStateManager, messageId: MessageId) -> Signal<Never, RequestUpdateMessageReactionError> {
    return postbox.transaction { transaction -> (Peer, Int32, Bool)? in
        guard let peer = transaction.getPeer(messageId.peerId) else {
            return nil
        }
        guard let message = transaction.getMessage(messageId) else {
            return nil
        }
        var count: Int32 = 0
        var isAnonymous = false
        for attribute in message.attributes {
            if let attribute = attribute as? PendingStarsReactionsMessageAttribute {
                count += attribute.count
                isAnonymous = attribute.isAnonymous
                break
            }
        }
        return (peer, count, isAnonymous)
    }
    |> castError(RequestUpdateMessageReactionError.self)
    |> mapToSignal { peerAndValue in
        guard let (peer, count, isAnonymous) = peerAndValue else {
            return .fail(.generic)
        }
        guard let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }
        if messageId.namespace != Namespaces.Message.Cloud {
            return .fail(.generic)
        }
        
        if count > 0 {
            let randomPartId = UInt64(UInt32(bitPattern: Int32.random(in: Int32.min ... Int32.max)))
            let timestampPart = UInt64(UInt32(bitPattern: Int32(Date().timeIntervalSince1970)))
            let randomId = (timestampPart << 32) | randomPartId
            
            var flags: Int32 = 0
            flags |= 1 << 0
            
            let signal: Signal<Never, RequestUpdateMessageReactionError> = network.request(Api.functions.messages.sendPaidReaction(flags: flags, peer: inputPeer, msgId: messageId.id, count: count, randomId: Int64(bitPattern: randomId), private: isAnonymous ? .boolTrue : .boolFalse))
            |> mapError { _ -> RequestUpdateMessageReactionError in
                return .generic
            }
            |> mapToSignal { result -> Signal<Never, RequestUpdateMessageReactionError> in
                stateManager.starsContext?.add(balance: StarsAmount(value: Int64(-count), nanos: 0), addTransaction: false)
                
                return postbox.transaction { transaction -> Void in
                    transaction.setPendingMessageAction(type: .sendStarsReaction, id: messageId, action: UpdateMessageReactionsAction())
                    transaction.updateMessage(messageId, update: { currentMessage in
                        var storeForwardInfo: StoreMessageForwardInfo?
                        if let forwardInfo = currentMessage.forwardInfo {
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                        }
                        let reactions = mergedMessageReactions(attributes: currentMessage.attributes, isTags: currentMessage.areReactionsTags(accountPeerId: stateManager.accountPeerId))
                        var attributes = currentMessage.attributes
                        for j in (0 ..< attributes.count).reversed() {
                            if attributes[j] is PendingStarsReactionsMessageAttribute || attributes[j] is ReactionsMessageAttribute {
                                attributes.remove(at: j)
                            }
                        }
                        if let reactions {
                            attributes.append(reactions)
                        }
                        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                    })
                    stateManager.addUpdates(result)
                }
                |> castError(RequestUpdateMessageReactionError.self)
                |> ignoreValues
            }
            return signal
        } else {
            return .complete()
        }
    }
}

private final class ManagedApplyPendingMessageReactionsActionsHelper {
    var operationDisposables: [MessageId: (PendingMessageActionData, Disposable)] = [:]
    
    func update(entries: [PendingMessageActionsEntry]) -> (disposeOperations: [Disposable], beginOperations: [(PendingMessageActionsEntry, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PendingMessageActionsEntry, MetaDisposable)] = []
        
        var hasRunningOperationForPeerId = Set<PeerId>()
        var validIds = Set<MessageId>()
        for entry in entries {
            if let current = self.operationDisposables[entry.id], !current.0.isEqual(to: entry.action) {
                self.operationDisposables.removeValue(forKey: entry.id)
                disposeOperations.append(current.1)
            }
            
            if !hasRunningOperationForPeerId.contains(entry.id.peerId) {
                hasRunningOperationForPeerId.insert(entry.id.peerId)
                validIds.insert(entry.id)
                
                let disposable = MetaDisposable()
                beginOperations.append((entry, disposable))
                self.operationDisposables[entry.id] = (entry.action, disposable)
            }
        }
        
        var removeMergedIds: [MessageId] = []
        for (id, actionAndDisposable) in self.operationDisposables {
            if !validIds.contains(id) {
                removeMergedIds.append(id)
                disposeOperations.append(actionAndDisposable.1)
            }
        }
        
        for id in removeMergedIds {
            self.operationDisposables.removeValue(forKey: id)
        }
        
        return (disposeOperations, beginOperations)
    }
    
    func reset() -> [Disposable] {
        let disposables = Array(self.operationDisposables.values.map(\.1))
        self.operationDisposables.removeAll()
        return disposables
    }
}

private func withTakenReactionsAction(postbox: Postbox, type: PendingMessageActionType, id: MessageId, _ f: @escaping (Transaction, PendingMessageActionsEntry?) -> Signal<Never, NoError>) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Signal<Never, NoError> in
        var result: PendingMessageActionsEntry?
        
        if let action = transaction.getPendingMessageAction(type: type, id: id) as? UpdateMessageReactionsAction {
            result = PendingMessageActionsEntry(id: id, action: action)
        }
        
        return f(transaction, result)
    }
    |> switchToLatest
}

private func withTakenStarsAction(postbox: Postbox, type: PendingMessageActionType, id: MessageId, _ f: @escaping (Transaction, PendingMessageActionsEntry?) -> Signal<Never, NoError>) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Signal<Never, NoError> in
        var result: PendingMessageActionsEntry?
        
        if let action = transaction.getPendingMessageAction(type: type, id: id) as? SendStarsReactionsAction {
            result = PendingMessageActionsEntry(id: id, action: action)
        }
        
        return f(transaction, result)
    }
    |> switchToLatest
}

func managedApplyPendingMessageReactionsActions(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic<ManagedApplyPendingMessageReactionsActionsHelper>(value: ManagedApplyPendingMessageReactionsActionsHelper())
        
        let actionsKey = PostboxViewKey.pendingMessageActions(type: .updateReaction)
        let disposable = postbox.combinedView(keys: [actionsKey]).start(next: { view in
            var entries: [PendingMessageActionsEntry] = []
            if let v = view.views[actionsKey] as? PendingMessageActionsView {
                entries = v.entries
            }
            
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PendingMessageActionsEntry, MetaDisposable)]) in
                return helper.update(entries: entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenReactionsAction(postbox: postbox, type: .updateReaction, id: entry.id, { transaction, entry -> Signal<Never, NoError> in
                    if let entry = entry {
                        if let _ = entry.action as? UpdateMessageReactionsAction {
                            return synchronizeMessageReactions(transaction: transaction, postbox: postbox, network: network, stateManager: stateManager, id: entry.id)
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                |> then(
                    postbox.transaction { transaction -> Void in
                    transaction.setPendingMessageAction(type: .updateReaction, id: entry.id, action: nil)
                    }
                    |> ignoreValues
                )
                
                disposable.set(signal.start())
            }
        })
        
        return ActionDisposable {
            let disposables = helper.with { helper -> [Disposable] in
                return helper.reset()
            }
            for disposable in disposables {
                disposable.dispose()
            }
            disposable.dispose()
        }
    }
}

func managedApplyPendingMessageStarsReactionsActions(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic<ManagedApplyPendingMessageReactionsActionsHelper>(value: ManagedApplyPendingMessageReactionsActionsHelper())
        
        let actionsKey = PostboxViewKey.pendingMessageActions(type: .sendStarsReaction)
        let disposable = postbox.combinedView(keys: [actionsKey]).start(next: { view in
            var entries: [PendingMessageActionsEntry] = []
            if let v = view.views[actionsKey] as? PendingMessageActionsView {
                entries = v.entries
            }
            
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PendingMessageActionsEntry, MetaDisposable)]) in
                return helper.update(entries: entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenStarsAction(postbox: postbox, type: .sendStarsReaction, id: entry.id, { transaction, entry -> Signal<Never, NoError> in
                    if let entry = entry {
                        if let _ = entry.action as? SendStarsReactionsAction {
                            let triggerSignal: Signal<Void, NoError> = stateManager.forceSendPendingStarsReaction
                            |> filter {
                                $0 == entry.id
                            }
                            |> map { _ -> Void in
                                return Void()
                            }
                            |> take(1)
                            |> timeout(5.0, queue: .mainQueue(), alternate: .single(Void()))
                            
                            return triggerSignal
                            |> mapToSignal { _ -> Signal<Never, NoError> in
                                return synchronizeMessageStarsReactions(transaction: transaction, postbox: postbox, network: network, stateManager: stateManager, id: entry.id)
                            }
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                |> then(
                    postbox.transaction { transaction -> Void in
                    transaction.setPendingMessageAction(type: .sendStarsReaction, id: entry.id, action: nil)
                    }
                    |> ignoreValues
                )
                
                disposable.set(signal.start())
            }
        })
        
        return ActionDisposable {
            let disposables = helper.with { helper -> [Disposable] in
                return helper.reset()
            }
            for disposable in disposables {
                disposable.dispose()
            }
            disposable.dispose()
        }
    }
}

private func synchronizeMessageReactions(transaction: Transaction, postbox: Postbox, network: Network, stateManager: AccountStateManager, id: MessageId) -> Signal<Never, NoError> {
    return requestUpdateMessageReaction(postbox: postbox, network: network, stateManager: stateManager, messageId: id)
    |> `catch` { _ -> Signal<Never, NoError> in
        return postbox.transaction { transaction -> Void in
            transaction.setPendingMessageAction(type: .updateReaction, id: id, action: nil)
            transaction.updateMessage(id, update: { currentMessage in
                var storeForwardInfo: StoreMessageForwardInfo?
                if let forwardInfo = currentMessage.forwardInfo {
                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                }
                var attributes = currentMessage.attributes
                loop: for j in 0 ..< attributes.count {
                    if let _ = attributes[j] as? PendingReactionsMessageAttribute {
                        attributes.remove(at: j)
                        break loop
                    }
                }
                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
            })
        }
        |> ignoreValues
    }
}

private func synchronizeMessageStarsReactions(transaction: Transaction, postbox: Postbox, network: Network, stateManager: AccountStateManager, id: MessageId) -> Signal<Never, NoError> {
    return requestSendStarsReaction(postbox: postbox, network: network, stateManager: stateManager, messageId: id)
    |> `catch` { _ -> Signal<Never, NoError> in
        return postbox.transaction { transaction -> Void in
            transaction.setPendingMessageAction(type: .sendStarsReaction, id: id, action: nil)
            transaction.updateMessage(id, update: { currentMessage in
                var storeForwardInfo: StoreMessageForwardInfo?
                if let forwardInfo = currentMessage.forwardInfo {
                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                }
                var attributes = currentMessage.attributes
                loop: for j in 0 ..< attributes.count {
                    if let _ = attributes[j] as? PendingStarsReactionsMessageAttribute {
                        attributes.remove(at: j)
                        break loop
                    }
                }
                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
            })
        }
        |> ignoreValues
    }
}

public extension EngineMessageReactionListContext.State {
    init(message: EngineMessage, readStats: MessageReadStats?, reaction: MessageReaction.Reaction?) {
        var totalCount = 0
        var hasOutgoingReaction = false
        var items: [EngineMessageReactionListContext.Item] = []
        if let reactionsAttribute = message._asMessage().reactionsAttribute {
            for messageReaction in reactionsAttribute.reactions {
                if reaction == nil || messageReaction.value == reaction {
                    if messageReaction.chosenOrder != nil {
                        hasOutgoingReaction = true
                    }
                    totalCount += Int(messageReaction.count)
                }
            }
            for recentPeer in reactionsAttribute.recentPeers {
                if let peer = message.peers[recentPeer.peerId] {
                    if reaction == nil || recentPeer.value == reaction {
                        items.append(EngineMessageReactionListContext.Item(peer: EnginePeer(peer), reaction: recentPeer.value, timestamp: recentPeer.timestamp ?? readStats?.readTimestamps[peer.id], timestampIsReaction: recentPeer.timestamp != nil))
                    }
                }
            }
        }
        if items.count != totalCount {
            items.removeAll()
        }
        self.init(
            hasOutgoingReaction: hasOutgoingReaction,
            totalCount: totalCount,
            items: items,
            canLoadMore: items.count != totalCount && totalCount != 0
        )
    }
}

public final class EngineMessageReactionListContext {
    public final class Item: Equatable {
        public let peer: EnginePeer
        public let reaction: MessageReaction.Reaction?
        public let timestamp: Int32?
        public let timestampIsReaction: Bool
        
        public init(
            peer: EnginePeer,
            reaction: MessageReaction.Reaction?,
            timestamp: Int32?,
            timestampIsReaction: Bool
        ) {
            self.peer = peer
            self.reaction = reaction
            self.timestamp = timestamp
            self.timestampIsReaction = timestampIsReaction
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.peer != rhs.peer {
                return false
            }
            if lhs.reaction != rhs.reaction {
                return false
            }
            if lhs.timestamp != rhs.timestamp {
                return false
            }
            if lhs.timestampIsReaction != rhs.timestampIsReaction {
                return false
            }
            return true
        }
    }
    
    public struct State: Equatable {
        public var hasOutgoingReaction: Bool
        public var totalCount: Int
        public var items: [Item]
        public var canLoadMore: Bool
        
        public init(
            hasOutgoingReaction: Bool,
            totalCount: Int,
            items: [Item],
            canLoadMore: Bool
        ) {
            self.hasOutgoingReaction = hasOutgoingReaction
            self.totalCount = totalCount
            self.items = items
            self.canLoadMore = canLoadMore
        }
    }
    
    private final class Impl {
        struct InternalState: Equatable {
            var hasOutgoingReaction: Bool
            var totalCount: Int
            var items: [Item]
            var canLoadMore: Bool
            var nextOffset: String?
        }
        
        let queue: Queue
        
        let account: Account
        let message: EngineMessage
        let reaction: MessageReaction.Reaction?
        
        let disposable = MetaDisposable()
        
        var state: InternalState
        let statePromise = Promise<InternalState>()
        
        var isLoadingMore: Bool = false
        
        init(queue: Queue, account: Account, message: EngineMessage, readStats: MessageReadStats?, reaction: MessageReaction.Reaction?) {
            self.queue = queue
            self.account = account
            self.message = message
            self.reaction = reaction
            
            let initialState = EngineMessageReactionListContext.State(message: message, readStats: readStats, reaction: reaction)
            self.state = InternalState(hasOutgoingReaction: initialState.hasOutgoingReaction, totalCount: initialState.totalCount, items: initialState.items, canLoadMore: initialState.canLoadMore, nextOffset: nil)
            
            if initialState.canLoadMore {
                self.loadMore()
            } else {
                self.statePromise.set(.single(self.state))
            }
        }
        
        deinit {
            assert(self.queue.isCurrent())
            
            self.disposable.dispose()
        }
        
        func loadMore() {
            if self.isLoadingMore {
                return
            }
            self.isLoadingMore = true
            
            let account = self.account
            let accountPeerId = account.peerId
            let message = self.message
            let reaction = self.reaction
            let currentOffset = self.state.nextOffset
            let limit = self.state.items.isEmpty ? 50 : 100
            let signal: Signal<InternalState, NoError> = self.account.postbox.transaction { transaction -> Api.InputPeer? in
                return transaction.getPeer(message.id.peerId).flatMap(apiInputPeer)
            }
            |> mapToSignal { inputPeer -> Signal<InternalState, NoError> in
                if message.id.namespace != Namespaces.Message.Cloud {
                    return .single(InternalState(hasOutgoingReaction: false, totalCount: 0, items: [], canLoadMore: false, nextOffset: nil))
                }
                guard let inputPeer = inputPeer else {
                    return .single(InternalState(hasOutgoingReaction: false, totalCount: 0, items: [], canLoadMore: false, nextOffset: nil))
                }
                var flags: Int32 = 0
                if reaction != nil {
                    flags |= 1 << 0
                }
                if currentOffset != nil {
                    flags |= 1 << 1
                }
                return account.network.request(Api.functions.messages.getMessageReactionsList(flags: flags, peer: inputPeer, id: message.id.id, reaction: reaction?.apiReaction, offset: currentOffset, limit: Int32(limit)))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.MessageReactionsList?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<InternalState, NoError> in
                    return account.postbox.transaction { transaction -> InternalState in
                        switch result {
                        case let .messageReactionsList(_, count, reactions, chats, users, nextOffset):
                            let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                            
                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                            
                            var items: [EngineMessageReactionListContext.Item] = []
                            for reaction in reactions {
                                switch reaction {
                                case let .messagePeerReaction(_, peer, date, reaction):
                                    if let peer = transaction.getPeer(peer.peerId), let reaction = MessageReaction.Reaction(apiReaction: reaction) {
                                        items.append(EngineMessageReactionListContext.Item(peer: EnginePeer(peer), reaction: reaction, timestamp: date, timestampIsReaction: true))
                                    }
                                }
                            }
                            
                            return InternalState(hasOutgoingReaction: false, totalCount: Int(count), items: items, canLoadMore: nextOffset != nil, nextOffset: nextOffset)
                        case .none:
                            return InternalState(hasOutgoingReaction: false, totalCount: 0, items: [], canLoadMore: false, nextOffset: nil)
                        }
                    }
                }
            }
            self.disposable.set((signal
            |> deliverOn(self.queue)).start(next: { [weak self] state in
                guard let strongSelf = self else {
                    return
                }
                
                struct ItemHash: Hashable {
                    var peerId: EnginePeer.Id
                    var value: MessageReaction.Reaction?
                }
                
                var existingItems = Set<ItemHash>()
                for item in strongSelf.state.items {
                    existingItems.insert(ItemHash(peerId: item.peer.id, value: item.reaction))
                }
                
                for item in state.items {
                    let itemHash = ItemHash(peerId: item.peer.id, value: item.reaction)
                    if existingItems.contains(itemHash) {
                        continue
                    }
                    existingItems.insert(itemHash)
                    strongSelf.state.items.append(item)
                }
                if state.canLoadMore {
                    strongSelf.state.totalCount = max(state.totalCount, strongSelf.state.items.count)
                } else {
                    strongSelf.state.totalCount = strongSelf.state.items.count
                }
                strongSelf.state.canLoadMore = state.canLoadMore
                strongSelf.state.nextOffset = state.nextOffset
                
                strongSelf.isLoadingMore = false
                strongSelf.statePromise.set(.single(strongSelf.state))
            }))
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public var state: Signal<State, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.statePromise.get().start(next: { state in
                    subscriber.putNext(State(
                        hasOutgoingReaction: state.hasOutgoingReaction,
                        totalCount: state.totalCount,
                        items: state.items,
                        canLoadMore: state.canLoadMore
                    ))
                }))
            }
            return disposable
        }
    }
    
    init(account: Account, message: EngineMessage, readStats: MessageReadStats?, reaction: MessageReaction.Reaction?) {
        let queue = Queue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, message: message, readStats: readStats, reaction: reaction)
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
}

public enum UpdatePeerAllowedReactionsError {
    case generic
    case boostRequired
}

func _internal_updatePeerReactionSettings(account: Account, peerId: PeerId, reactionSettings: PeerReactionSettings) -> Signal<Never, UpdatePeerAllowedReactionsError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> castError(UpdatePeerAllowedReactionsError.self)
    |> mapToSignal { inputPeer -> Signal<Never, UpdatePeerAllowedReactionsError> in
        guard let inputPeer = inputPeer else {
            return .fail(.generic)
        }
        
        var flags: Int32 = 0
        
        let mappedReactions: Api.ChatReactions
        switch reactionSettings.allowedReactions {
        case .all:
            mappedReactions = .chatReactionsAll(flags: 0)
        case let .limited(array):
            mappedReactions = .chatReactionsSome(reactions: array.map(\.apiReaction))
        case .empty:
            mappedReactions = .chatReactionsNone
        }
        
        var reactionLimitValue: Int32?
        if let maxReactionCount = reactionSettings.maxReactionCount {
            flags |= 1 << 0
            reactionLimitValue = maxReactionCount
        }
        
        var paidEnabled: Api.Bool?
        if let starsAllowed = reactionSettings.starsAllowed {
            flags |= 1 << 1
            paidEnabled = starsAllowed ? .boolTrue : .boolFalse
        }
        
        return account.network.request(Api.functions.messages.setChatAvailableReactions(flags: flags, peer: inputPeer, availableReactions: mappedReactions, reactionsLimit: reactionLimitValue, paidEnabled: paidEnabled))
        |> map(Optional.init)
        |> `catch` { error -> Signal<Api.Updates?, UpdatePeerAllowedReactionsError> in
            if error.errorDescription == "CHAT_NOT_MODIFIED" {
                return .single(nil)
            } else if error.errorDescription == "BOOSTS_REQUIRED" {
                return .fail(.boostRequired)
            } else {
                return .fail(.generic)
            }
        }
        |> mapToSignal { result -> Signal<Never, UpdatePeerAllowedReactionsError> in
            if let result = result {
                account.stateManager.addUpdates(result)
            }
            
            return account.postbox.transaction { transaction -> Void in
                transaction.updatePeerCachedData(peerIds: [peerId], update: { _, current in
                    if let current = current as? CachedChannelData {
                        return current.withUpdatedReactionSettings(.known(reactionSettings))
                    } else if let current = current as? CachedGroupData {
                        return current.withUpdatedReactionSettings(.known(reactionSettings))
                    } else {
                        return current
                    }
                })
            }
            |> ignoreValues
            |> castError(UpdatePeerAllowedReactionsError.self)
        }
    }
}

func _internal_updateDefaultReaction(account: Account, reaction: MessageReaction.Reaction) -> Signal<Never, NoError> {
    return account.network.request(Api.functions.messages.setDefaultReaction(reaction: reaction.apiReaction))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> ignoreValues
}

struct StarsReactionDefaultToPrivateData: Codable {
    var isPrivate: Bool
    
    init(isPrivate: Bool) {
        self.isPrivate = isPrivate
    }
    
    static func key() -> ValueBoxKey {
        let value = ValueBoxKey(length: 8)
        value.setInt64(0, value: 0)
        return value
    }
}

func _internal_getStarsReactionDefaultToPrivate(transaction: Transaction) -> Bool {
    guard let value = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.starsReactionDefaultToPrivate, key: StarsReactionDefaultToPrivateData.key()))?.get(StarsReactionDefaultToPrivateData.self) else {
        return false
    }
    return value.isPrivate
}

func _internal_setStarsReactionDefaultToPrivate(isPrivate: Bool, transaction: Transaction) {
    guard let entry = CodableEntry(StarsReactionDefaultToPrivateData(isPrivate: isPrivate)) else {
        return
    }
    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.starsReactionDefaultToPrivate, key: StarsReactionDefaultToPrivateData.key()), entry: entry)
}
