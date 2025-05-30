import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit


public enum RequestUpdateTodoMessageError {
    case generic
}

func _internal_requestUpdateTodoMessageItems(account: Account, messageId: MessageId, completedIds: [Int32], incompletedIds: [Int32]) -> Signal<Never, RequestUpdateTodoMessageError> {
    return account.postbox.loadedPeerWithId(messageId.peerId)
    |> take(1)
    |> castError(RequestUpdateTodoMessageError.self)
    |> mapToSignal { peer in
        if let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.messages.toggleTodoCompleted(peer: inputPeer, msgId: messageId.id, completed: completedIds, incompleted: incompletedIds))
            |> mapError { _ -> RequestUpdateTodoMessageError in
                return .generic
            }
            |> mapToSignal { result -> Signal<TelegramMediaTodo?, RequestUpdateTodoMessageError> in
                return account.postbox.transaction { transaction -> TelegramMediaTodo? in
                    switch result {
                    case let .updates(updates, _, _, _, _):
                        let _ = updates
                    default:
                        break
                    }
                    account.stateManager.addUpdates(result)
                    return nil
                }
                |> castError(RequestUpdateTodoMessageError.self)
            }
        } else {
            return .single(nil)
        }
    }
    |> ignoreValues
}

public enum AppendTodoMessageError {
    case generic
}

func _internal_appendTodoMessageItems(account: Account, messageId: MessageId, items: [TelegramMediaTodo.Item]) -> Signal<Never, AppendTodoMessageError> {
    return account.postbox.loadedPeerWithId(messageId.peerId)
    |> take(1)
    |> castError(AppendTodoMessageError.self)
    |> mapToSignal { peer -> Signal<TelegramMediaTodo?, AppendTodoMessageError> in
        guard let inputPeer = apiInputPeer(peer) else {
            return .single(nil)
        }
        return account.network.request(Api.functions.messages.appendTodoList(peer: inputPeer, msgId: messageId.id, list: items.map { $0.apiItem }))
        |> mapError { _ -> AppendTodoMessageError in
            return .generic
        }
        |> mapToSignal { result -> Signal<TelegramMediaTodo?, AppendTodoMessageError> in
            return account.postbox.transaction { transaction -> TelegramMediaTodo? in
                switch result {
                case let .updates(updates, _, _, _, _):
                    let _ = updates
                default:
                    break
                }
                account.stateManager.addUpdates(result)
                return nil
            }
            |> castError(AppendTodoMessageError.self)
        }
    }
    |> ignoreValues
}
