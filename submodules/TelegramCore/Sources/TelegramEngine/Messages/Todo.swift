import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit


public enum RequestUpdateTodoMessageError {
    case generic
}

func _internal_requestUpdateTodoMessageItems(account: Account, messageId: MessageId, completedIds: [Int32], incompletedIds: [Int32]) -> Signal<Never, RequestUpdateTodoMessageError> {
    return account.postbox.transaction { transaction -> Signal<Never, RequestUpdateTodoMessageError> in
        guard let peer = transaction.getPeer(messageId.peerId), let inputPeer = apiInputPeer(peer) else {
            return .complete()
        }
        transaction.updateMessage(messageId, update: { currentMessage in
            let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
            var media: [Media] = []
            if let todo = currentMessage.media.first(where: { $0 is TelegramMediaTodo }) as? TelegramMediaTodo {
                let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                var updatedCompletions = todo.completions
                for id in completedIds {
                    updatedCompletions.append(TelegramMediaTodo.Completion(id: id, date: timestamp, completedBy: account.peerId))
                }
                updatedCompletions.removeAll(where: { incompletedIds.contains($0.id) })
                media = [todo.withUpdated(completions: updatedCompletions)]
            }
            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: media))
        })
        return account.network.request(Api.functions.messages.toggleTodoCompleted(peer: inputPeer, msgId: messageId.id, completed: completedIds, incompleted: incompletedIds))
        |> mapError { _ -> RequestUpdateTodoMessageError in
            return .generic
        }
        |> map { result in
            account.stateManager.addUpdates(result)
        }
        |> ignoreValues
    }
    |> castError(RequestUpdateTodoMessageError.self)
    |> switchToLatest
    |> ignoreValues
}

public enum AppendTodoMessageError {
    case generic
}

func _internal_appendTodoMessageItems(account: Account, messageId: MessageId, items: [TelegramMediaTodo.Item]) -> Signal<Never, AppendTodoMessageError> {
    return account.postbox.transaction { transaction -> Signal<Never, AppendTodoMessageError> in
        guard let peer = transaction.getPeer(messageId.peerId), let inputPeer = apiInputPeer(peer) else {
            return .complete()
        }
        transaction.updateMessage(messageId, update: { currentMessage in
            let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
            var media: [Media] = []
            if let todo = currentMessage.media.first(where: { $0 is TelegramMediaTodo }) as? TelegramMediaTodo {
                var updatedItems = todo.items
                updatedItems.append(contentsOf: items)
                media = [todo.withUpdated(items: updatedItems)]
            }
            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: media))
        })
        return account.network.request(Api.functions.messages.appendTodoList(peer: inputPeer, msgId: messageId.id, list: items.map { $0.apiItem }))
        |> mapError { _ -> AppendTodoMessageError in
            return .generic
        }
        |> map { result in
            account.stateManager.addUpdates(result)
        }
        |> ignoreValues
    }
    |> castError(AppendTodoMessageError.self)
    |> switchToLatest
    |> ignoreValues
}
