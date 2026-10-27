import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

/// Why a message widget's request to its bot (`messages.getBotWidgetQueryAnswer`) has no answer (widget-sandbox v0.2,
/// sdk-v1 §5.11): the widget's promise rejects with `TIMEOUT`, `RATE_LIMITED` or `FAILED`.
public enum BotWidgetQueryError: Error, Equatable {
    case timeout
    case rateLimited
    case failed
}

/// The tag's mapping (design §4 call 5): `WIDGET_RESPONSE_TIMEOUT` is a timeout, a flood wait a rate limit, and everything
/// else a failure, `WIDGET_QUERY_NOT_ALLOWED` included.
func botWidgetQueryError(_ error: MTRpcError) -> BotWidgetQueryError {
    if error.errorDescription == "WIDGET_RESPONSE_TIMEOUT" {
        return .timeout
    } else if error.errorDescription.hasPrefix("FLOOD_WAIT_") {
        return .rateLimited
    } else {
        return .failed
    }
}

/// Sends a widget's request (`data`, already admitted by the widget's request gate) to the bot of the message
/// `messageId`, and yields the answer's `result` (nil without one). One of the two requests the app makes for a widget
/// (design §4.A): only to Telegram's server, only the bot's data.
///
/// Exactly one outcome: a message that is not a cloud message (a local one means nothing to the server), or one whose
/// peer is unknown, fails at once, and no answer within `timeout` fails too (the server's own limit is 15 s; this keeps
/// a lost connection from leaving the widget's gate busy). Flood waits are not waited out (`automaticFloodWait: false`),
/// so a rate limit reaches the widget instead of the guard firing first.
func _internal_requestBotWidgetQueryAnswer(postbox: Postbox, network: Network, messageId: MessageId, data: Data, timeout guardTimeout: Double = 30.0) -> Signal<Data?, BotWidgetQueryError> {
    if messageId.namespace != Namespaces.Message.Cloud {
        return .fail(.failed)
    }
    return postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
    }
    |> castError(BotWidgetQueryError.self)
    |> mapToSignal { inputPeer -> Signal<Data?, BotWidgetQueryError> in
        guard let inputPeer else {
            return .fail(.failed)
        }
        return network.request(Api.functions.messages.getBotWidgetQueryAnswer(peer: inputPeer, msgId: messageId.id, data: Buffer(data: data)), automaticFloodWait: false)
        |> mapError(botWidgetQueryError)
        |> map { answer -> Data? in
            switch answer {
            case let .botWidgetQueryAnswer(botWidgetQueryAnswerData):
                return botWidgetQueryAnswerData.result.map { Data($0.utf8) }
            }
        }
    }
    |> timeout(guardTimeout, queue: Queue.concurrentDefaultQueue(), alternate: .fail(.failed))
}
