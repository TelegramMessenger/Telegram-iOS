import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func _internal_editMessageFactCheck(account: Account, messageId: EngineMessage.Id, text: String, entities: [MessageTextEntity]) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Never, NoError> in
        guard let inputPeer  else {
            return .complete()
        }
                
        return account.network.request(Api.functions.messages.editFactCheck(
            peer: inputPeer,
            msgId: messageId.id,
            text: .textWithEntities(
                text: text,
                entities: apiEntitiesFromMessageTextEntities(entities, associatedPeers: SimpleDictionary())
            )
        ))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { updates -> Signal<Never, NoError> in
            if let updates = updates {
                account.stateManager.addUpdates(updates)
            }
            return .complete()
        }
    }
}

func _internal_deleteMessageFactCheck(account: Account, messageId: EngineMessage.Id) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Never, NoError> in
        guard let inputPeer else {
            return .complete()
        }
        return account.network.request(Api.functions.messages.deleteFactCheck(peer: inputPeer, msgId: messageId.id))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { updates -> Signal<Never, NoError> in
            if let updates = updates {
                account.stateManager.addUpdates(updates)
            }
            return .complete()
        }
    }
}

func _internal_getMessagesFactCheck(account: Account, messageIds: [EngineMessage.Id]) -> Signal<Never, NoError> {
    var signals: [Signal<Never, NoError>] = []
    for (peerId, messageIds) in messagesIdsGroupedByPeerId(messageIds) {
        signals.append(_internal_getMessagesFactCheckByPeerId(account: account, peerId: peerId, messageIds: messageIds))
    }
    return combineLatest(signals)
    |> ignoreValues
}

func _internal_getMessagesFactCheckByPeerId(account: Account, peerId: EnginePeer.Id, messageIds: [EngineMessage.Id]) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> (Api.InputPeer?, [Message]) in
        return (transaction.getPeer(peerId).flatMap(apiInputPeer), messageIds.compactMap({ transaction.getMessage($0) }))
    }
    |> mapToSignal { (inputPeer, messages) -> Signal<Never, NoError> in
        guard let inputPeer = inputPeer else {
            return .never()
        }
                
        let ids: [Int32] = messageIds.map { $0.id }
        let results: Signal<[Api.FactCheck]?, NoError>
        if ids.isEmpty {
            results = .single(nil)
        } else {
            results = account.network.request(Api.functions.messages.getFactCheck(peer: inputPeer, msgId: ids))
            |> map(Optional.init)
            |> `catch` { _ in
                return .single(nil)
            }
        }
        
        return results
        |> mapToSignal { results -> Signal<Never, NoError> in
            guard let results else {
                return .complete()
            }
            return account.postbox.transaction { transaction in
                var index = 0
                for result in results {
                    let messageId = messageIds[index]
                    switch result {
                    case let .factCheck(_, country, text, hash):
                        let content: FactCheckMessageAttribute.Content
                        if let text, let country {
                            switch text {
                            case let .textWithEntities(text, entities):
                                content = .Loaded(text: text, entities: messageTextEntitiesFromApiEntities(entities), country: country)
                            }
                        } else {
                            content = .Pending
                        }
                        let attribute = FactCheckMessageAttribute(content: content, hash: hash)
                        transaction.updateMessage(messageId, update: { currentMessage in
                            let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                            var attributes = currentMessage.attributes.filter { !($0 is FactCheckMessageAttribute) }
                            attributes.append(attribute)
                            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                        })
                    }
                    index += 1
                }
            }
            |> ignoreValues
        }
    }
}
