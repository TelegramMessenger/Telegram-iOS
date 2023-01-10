import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

#if os(macOS)
private let botWebViewPlatform = "macos"
#else
private let botWebViewPlatform = "ios"
#endif

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
        return network.request(Api.functions.messages.requestSimpleWebView(flags: flags, bot: inputUser, url: url, themeParams: serializedThemeParams, platform: botWebViewPlatform))
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

public enum KeepWebViewError {
    case generic
}

public struct RequestWebViewResult {
    public let queryId: Int64
    public let url: String
    public let keepAliveSignal: Signal<Never, KeepWebViewError>
}

public enum RequestWebViewError {
    case generic
}

private func keepWebViewSignal(network: Network, stateManager: AccountStateManager, flags: Int32, peer: Api.InputPeer, bot: Api.InputUser, queryId: Int64, replyToMessageId: MessageId?, threadId: Int64?, sendAs: Api.InputPeer?) -> Signal<Never, KeepWebViewError> {
    let signal = Signal<Never, KeepWebViewError> { subscriber in
        let poll = Signal<Never, KeepWebViewError> { subscriber in
            let signal: Signal<Never, KeepWebViewError> = network.request(Api.functions.messages.prolongWebView(flags: flags, peer: peer, bot: bot, queryId: queryId, replyToMsgId: replyToMessageId?.id, topMsgId: threadId.flatMap(Int32.init(clamping:)), sendAs: sendAs))
            |> mapError { _ -> KeepWebViewError in
                return .generic
            }
            |> ignoreValues
            
            return signal.start(error: { error in
                subscriber.putError(error)
            }, completed: {
                subscriber.putCompletion()
            })
        }
        let keepAliveSignal = (
            .complete()
            |> suspendAwareDelay(60.0, queue: Queue.concurrentDefaultQueue())
            |> then (poll)
        )
        |> restart
        
        let pollDisposable = keepAliveSignal.start(error: { error in
            subscriber.putError(error)
        })
        
        let dismissDisposable = (stateManager.dismissBotWebViews
        |> filter {
            $0.contains(queryId)
        }
        |> take(1)).start(completed: {
            subscriber.putCompletion()
        })
        
        let disposableSet = DisposableSet()
        disposableSet.add(pollDisposable)
        disposableSet.add(dismissDisposable)
        return disposableSet
    }
    return signal
}

func _internal_requestWebView(postbox: Postbox, network: Network, stateManager: AccountStateManager, peerId: PeerId, botId: PeerId, url: String?, payload: String?, themeParams: [String: Any]?, fromMenu: Bool, replyToMessageId: MessageId?, threadId: Int64?) -> Signal<RequestWebViewResult, RequestWebViewError> {
    var serializedThemeParams: Api.DataJSON?
    if let themeParams = themeParams, let data = try? JSONSerialization.data(withJSONObject: themeParams, options: []), let dataString = String(data: data, encoding: .utf8) {
        serializedThemeParams = .dataJSON(data: dataString)
    }
    
    return postbox.transaction { transaction -> Signal<RequestWebViewResult, RequestWebViewError> in
        guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer), let bot = transaction.getPeer(botId), let inputBot = apiInputUser(bot) else {
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
        if let _ = payload {
            flags |= (1 << 3)
        }
        if fromMenu {
            flags |= (1 << 4)
        }
        if threadId != nil {
            flags |= (1 << 9)
        }
//        if _ {
//            flags |= (1 << 13)
//        }
        return network.request(Api.functions.messages.requestWebView(flags: flags, peer: inputPeer, bot: inputBot, url: url, startParam: payload, themeParams: serializedThemeParams, platform: botWebViewPlatform, replyToMsgId: replyToMsgId, topMsgId: threadId.flatMap(Int32.init(clamping:)), sendAs: nil))
        |> mapError { _ -> RequestWebViewError in
            return .generic
        }
        |> mapToSignal { result -> Signal<RequestWebViewResult, RequestWebViewError> in
            switch result {
                case let .webViewResultUrl(queryId, url):
                return .single(RequestWebViewResult(queryId: queryId, url: url, keepAliveSignal: keepWebViewSignal(network: network, stateManager: stateManager, flags: flags, peer: inputPeer, bot: inputBot, queryId: queryId, replyToMessageId: replyToMessageId, threadId: threadId, sendAs: nil)))
            }
        }
    }
    |> castError(RequestWebViewError.self)
    |> switchToLatest
}

public enum SendWebViewDataError {
    case generic
}

func _internal_sendWebViewData(postbox: Postbox, network: Network, stateManager: AccountStateManager, botId: PeerId, buttonText: String, data: String) -> Signal<Never, SendWebViewDataError> {
    return postbox.transaction { transaction -> Signal<Never, SendWebViewDataError> in
        guard let bot = transaction.getPeer(botId), let inputBot = apiInputUser(bot) else {
            return .fail(.generic)
        }
        
        return network.request(Api.functions.messages.sendWebViewData(bot: inputBot, randomId: Int64.random(in: Int64.min ... Int64.max), buttonText: buttonText, data: data))
        |> mapError { _ -> SendWebViewDataError in
            return .generic
        }
        |> map { updates -> Api.Updates in
            stateManager.addUpdates(updates)
            return updates
        }
        |> ignoreValues
    }
    |> castError(SendWebViewDataError.self)
    |> switchToLatest
}
