import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum RequestWebViewResult {
    case webViewResult(queryId: Int64, url: String)
    case requestConfirmation
}

public enum RequestWebViewError {
    case generic
}

func _internal_requestWebView(postbox: Postbox, network: Network, peerId: PeerId, botId: PeerId, url: String?, themeParams: [String: Any]?) -> Signal<RequestWebViewResult, RequestWebViewError> {
    var serializedThemeParams: Api.DataJSON?
    if let themeParams = themeParams, let data = try? JSONSerialization.data(withJSONObject: themeParams, options: []), let dataString = String(data: data, encoding: .utf8) {
        serializedThemeParams = .dataJSON(data: dataString)
    }
    
    return postbox.transaction { transaction -> Signal<RequestWebViewResult, RequestWebViewError> in
        guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer), let bot = transaction.getPeer(botId), let inputUser = apiInputUser(bot) else {
            return .fail(.generic)
        }

        var flags: Int32 = 0
        if let _ = url {
            flags |= (1 << 0)
        }
        if let _ = serializedThemeParams {
            flags |= (1 << 1)
        }
        return network.request(Api.functions.messages.requestWebView(flags: flags, peer: inputPeer, bot: inputUser, url: url, themeParams: serializedThemeParams))
        |> mapError { _ -> RequestWebViewError in
            return .generic
        }
        |> mapToSignal { result -> Signal<RequestWebViewResult, RequestWebViewError> in
            switch result {
                case let .webViewResultConfirmationRequired(_, users):
                    return postbox.transaction { transaction -> RequestWebViewResult in
                        var peers: [Peer] = []
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                        }
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        return .requestConfirmation
                    }
                    |> castError(RequestWebViewError.self)
                case let .webViewResultUrl(queryId, url):
                    return .single(.webViewResult(queryId: queryId, url: url))
            }
        }
    }
    |> castError(RequestWebViewError.self)
    |> switchToLatest
}

public enum GetWebViewResultError {
    case generic
}

func _internal_getWebViewResult(postbox: Postbox, network: Network, peerId: PeerId, botId: PeerId, queryId: Int64) -> Signal<ChatContextResult, GetWebViewResultError> {
    return postbox.transaction { transaction -> Signal<ChatContextResult, GetWebViewResultError> in
        guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer), let bot = transaction.getPeer(botId), let inputUser = apiInputUser(bot) else {
            return .fail(.generic)
        }
        return network.request(Api.functions.messages.getWebViewResult(peer: inputPeer, bot: inputUser, queryId: queryId))
        |> mapError { _ -> GetWebViewResultError in
            return .generic
        }
        |> mapToSignal { result -> Signal<ChatContextResult, GetWebViewResultError> in
            return postbox.transaction { transaction -> ChatContextResult in
                switch result {
                    case let .webViewResult(result, users):
                        var peers: [Peer] = []
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                        }
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        return ChatContextResult(apiResult: result, queryId: queryId)
                }
            }
            |> castError(GetWebViewResultError.self)
        }
    }
    |> castError(GetWebViewResultError.self)
    |> switchToLatest
}
