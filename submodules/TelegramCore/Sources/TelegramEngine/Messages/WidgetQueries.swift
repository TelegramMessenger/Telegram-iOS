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

/// The user's wallet as the client hands it to the server with a wallet query (`userWallet`, layer 233): the wallet's
/// address, its balance in nanotons and, for a signature, what verifies it.
public struct EngineUserWallet: Equatable {
    /// What a verifier needs for a signature: the wallet's public key and its `StateInit` (a bag of cells), which
    /// `userWallet` carries together (`flags.0`).
    public struct Signing: Equatable {
        public let publicKey: Data
        public let stateInit: Data

        public init(publicKey: Data, stateInit: Data) {
            self.publicKey = publicKey
            self.stateInit = stateInit
        }
    }

    public let address: String
    public let balance: Int64
    public let signing: Signing?

    public init(address: String, balance: Int64, signing: Signing?) {
        self.address = address
        self.balance = balance
        self.signing = signing
    }
}

/// What a widget query is (`WidgetQueryType`, widget-sandbox v0.5.0, sdk-v1 §5.13): a request (`with_wallet` when the
/// widget asked, on a tap, for the user's wallet card), the outcome of a signature (TON Connect's `signData` result as
/// JSON) or of a sent transaction (its message hash as the server returned it).
public enum BotWidgetQueryType: Equatable {
    case data(withWallet: Bool)
    case signData(wallet: EngineUserWallet, json: String)
    case sentTransaction(wallet: EngineUserWallet, msgHash: String)

    var apiQueryType: Api.WidgetQueryType {
        switch self {
        case let .data(withWallet):
            return .widgetQueryTypeData(.init(flags: withWallet ? 1 << 0 : 0))
        case let .signData(wallet, json):
            return .widgetQueryTypeSignData(.init(wallet: wallet.apiUserWallet, signData: .dataJSON(.init(data: json))))
        case let .sentTransaction(wallet, msgHash):
            return .widgetQueryTypeSentTransaction(.init(wallet: wallet.apiUserWallet, msgHash: msgHash))
        }
    }
}

extension EngineUserWallet {
    var apiUserWallet: Api.UserWallet {
        return .userWallet(.init(flags: self.signing == nil ? 0 : 1 << 0, address: self.address, balance: self.balance, publicKey: self.signing.map { Buffer(data: $0.publicKey) }, stateInit: self.signing.map { Buffer(data: $0.stateInit) }))
    }
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

/// Sends a widget's query of `queryType` (`data`: a request's, admitted by the widget's request gate, or a wallet call's
/// label) to the bot of the message `messageId`, and yields the answer's `result` (nil without one). One of the two
/// requests the app makes for a widget (design §4.A): only to Telegram's server, only the bot's data.
///
/// Exactly one outcome: a message that is not a cloud message (a local one means nothing to the server), or one whose
/// peer is unknown, fails at once, and no answer within `timeout` fails too (the server's own limit is 15 s; this keeps
/// a lost connection from leaving the widget's gate busy). Flood waits are not waited out (`automaticFloodWait: false`),
/// so a rate limit reaches the widget instead of the guard firing first.
func _internal_requestBotWidgetQueryAnswer(postbox: Postbox, network: Network, messageId: MessageId, queryType: BotWidgetQueryType, data: Data, timeout guardTimeout: Double = 30.0) -> Signal<Data?, BotWidgetQueryError> {
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
        return network.request(Api.functions.messages.getBotWidgetQueryAnswer(peer: inputPeer, msgId: messageId.id, queryType: queryType.apiQueryType, data: Buffer(data: data)), automaticFloodWait: false)
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
