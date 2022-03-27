import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum RequestSimpleWebViewError {
    case generic
}

func _internal_requestSimpleWebView(postbox: Postbox, network: Network, botId: PeerId, url: String, themeParams: [String: Any]?) -> Signal<String, RequestSimpleWebViewError> {
    var serializedThemeParams: Api.DataJSON?
    if let themeParams = themeParams, let data = try? JSONSerialization.data(withJSONObject: themeParams, options: []), let dataString = String(data: data, encoding: .utf8) {
        serializedThemeParams = .dataJSON(data: dataString)
    }
    
    return postbox.transaction { transaction -> Signal<String, RequestSimpleWebViewError> in
        guard let bot = transaction.getPeer(botId), let inputUser = apiInputUser(bot) else {
            return .fail(.generic)
        }

        var flags: Int32 = 0
        if let _ = serializedThemeParams {
            flags |= (1 << 0)
        }
        return network.request(Api.functions.messages.requestSimpleWebView(flags: flags, bot: inputUser, url: url, themeParams: serializedThemeParams))
        |> mapError { _ -> RequestSimpleWebViewError in
            return .generic
        }
        |> mapToSignal { result -> Signal<String, RequestSimpleWebViewError> in
            switch result {
                case let .simpleWebViewResultUrl(url):
                    return .single(url)
            }
        }
    }
    |> castError(RequestSimpleWebViewError.self)
    |> switchToLatest
}

public enum RequestWebViewResult {
    case webViewResult(queryId: Int64, url: String)
    case requestConfirmation(botIcon: TelegramMediaFile)
}

public enum RequestWebViewError {
    case generic
}

func _internal_requestWebView(postbox: Postbox, network: Network, peerId: PeerId, botId: PeerId, url: String?, themeParams: [String: Any]?, replyToMessageId: MessageId?) -> Signal<RequestWebViewResult, RequestWebViewError> {
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
            flags |= (1 << 1)
        }
        if let _ = serializedThemeParams {
            flags |= (1 << 2)
        }
        var replyToMsgId: Int32?
        if let replyToMessageId = replyToMessageId {
            flags |= (1 << 0)
            replyToMsgId = replyToMessageId.id
        }
        return network.request(Api.functions.messages.requestWebView(flags: flags, peer: inputPeer, bot: inputUser, url: url, themeParams: serializedThemeParams, replyToMsgId: replyToMsgId))
        |> mapError { _ -> RequestWebViewError in
            return .generic
        }
        |> mapToSignal { result -> Signal<RequestWebViewResult, RequestWebViewError> in
            switch result {
                case let .webViewResultConfirmationRequired(bot, users):
                    return postbox.transaction { transaction -> Signal<RequestWebViewResult, RequestWebViewError> in
                        var peers: [Peer] = []
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                        }
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        
                        if case let .attachMenuBot(_, _, _, attachMenuIcon) = bot, let icon = telegramMediaFileFromApiDocument(attachMenuIcon) {
                            return .single(.requestConfirmation(botIcon: icon))
                        } else {
                            return .complete()
                        }
                    }
                    |> castError(RequestWebViewError.self)
                    |> switchToLatest
                case let .webViewResultUrl(queryId, url):
                    return .single(.webViewResult(queryId: queryId, url: url))
            }
        }
    }
    |> castError(RequestWebViewError.self)
    |> switchToLatest
}
