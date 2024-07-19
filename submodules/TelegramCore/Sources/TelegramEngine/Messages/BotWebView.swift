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

public enum RequestSimpleWebViewSource {
    case generic
    case inline
    case settings
}

func _internal_requestSimpleWebView(postbox: Postbox, network: Network, botId: PeerId, url: String?, source: RequestSimpleWebViewSource, themeParams: [String: Any]?) -> Signal<RequestWebViewResult, RequestWebViewError> {
    var serializedThemeParams: Api.DataJSON?
    if let themeParams = themeParams, let data = try? JSONSerialization.data(withJSONObject: themeParams, options: []), let dataString = String(data: data, encoding: .utf8) {
        serializedThemeParams = .dataJSON(data: dataString)
    }
    return postbox.transaction { transaction -> Signal<RequestWebViewResult, RequestWebViewError> in
        guard let bot = transaction.getPeer(botId), let inputUser = apiInputUser(bot) else {
            return .fail(.generic)
        }

        var flags: Int32 = 0
        if let _ = serializedThemeParams {
            flags |= (1 << 0)
        }
        switch source {
        case .inline:
            flags |= (1 << 1)
        case .settings:
            flags |= (1 << 2)
        default:
            break
        }
        if let _ = url {
            flags |= (1 << 3)
        }
        return network.request(Api.functions.messages.requestSimpleWebView(flags: flags, bot: inputUser, url: url, startParam: nil, themeParams: serializedThemeParams, platform: botWebViewPlatform))
        |> mapError { _ -> RequestWebViewError in
            return .generic
        }
        |> mapToSignal { result -> Signal<RequestWebViewResult, RequestWebViewError> in
            switch result {
            case let .webViewResultUrl(flags, queryId, url):
                var resultFlags: RequestWebViewResult.Flags = []
                if (flags & (1 << 1)) != 0 {
                    resultFlags.insert(.fullSize)
                }
                return .single(RequestWebViewResult(flags: resultFlags, queryId: queryId, url: url, keepAliveSignal: nil))
            }
        }
    }
    |> castError(RequestWebViewError.self)
    |> switchToLatest
}

func _internal_requestMainWebView(postbox: Postbox, network: Network, botId: PeerId, source: RequestSimpleWebViewSource, themeParams: [String: Any]?) -> Signal<RequestWebViewResult, RequestWebViewError> {
    var serializedThemeParams: Api.DataJSON?
    if let themeParams = themeParams, let data = try? JSONSerialization.data(withJSONObject: themeParams, options: []), let dataString = String(data: data, encoding: .utf8) {
        serializedThemeParams = .dataJSON(data: dataString)
    }
    return postbox.transaction { transaction -> Signal<RequestWebViewResult, RequestWebViewError> in
        guard let bot = transaction.getPeer(botId), let inputUser = apiInputUser(bot) else {
            return .fail(.generic)
        }
        guard let peer = transaction.getPeer(botId), let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }

        var flags: Int32 = 0
        if let _ = serializedThemeParams {
            flags |= (1 << 0)
        }
        switch source {
        case .inline:
            flags |= (1 << 1)
        case .settings:
            flags |= (1 << 2)
        default:
            break
        }
        return network.request(Api.functions.messages.requestMainWebView(flags: flags, peer: inputPeer, bot: inputUser, startParam: nil, themeParams: serializedThemeParams, platform: botWebViewPlatform))
        |> mapError { _ -> RequestWebViewError in
            return .generic
        }
        |> mapToSignal { result -> Signal<RequestWebViewResult, RequestWebViewError> in
            switch result {
            case let .webViewResultUrl(flags, queryId, url):
                var resultFlags: RequestWebViewResult.Flags = []
                if (flags & (1 << 1)) != 0 {
                    resultFlags.insert(.fullSize)
                }
                return .single(RequestWebViewResult(flags: resultFlags, queryId: queryId, url: url, keepAliveSignal: nil))
            }
        }
    }
    |> castError(RequestWebViewError.self)
    |> switchToLatest
}

public enum KeepWebViewError {
    case generic
}

public struct RequestWebViewResult {
    public struct Flags: OptionSet {
        public var rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public init() {
            self.rawValue = 0
        }
        
        public static let fullSize = Flags(rawValue: 1 << 0)
    }
    
    public let flags: Flags
    public let queryId: Int64?
    public let url: String
    public let keepAliveSignal: Signal<Never, KeepWebViewError>?
}

public enum RequestWebViewError {
    case generic
}

private func keepWebViewSignal(network: Network, stateManager: AccountStateManager, flags: Int32, peer: Api.InputPeer, bot: Api.InputUser, queryId: Int64, replyToMessageId: MessageId?, threadId: Int64?, sendAs: Api.InputPeer?) -> Signal<Never, KeepWebViewError> {
    let signal = Signal<Never, KeepWebViewError> { subscriber in
        let poll = Signal<Never, KeepWebViewError> { subscriber in
            var replyTo: Api.InputReplyTo?
            if let replyToMessageId = replyToMessageId {
                var replyFlags: Int32 = 0
                if threadId != nil {
                    replyFlags |= 1 << 0
                }
                replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: replyToMessageId.id, topMsgId: threadId.flatMap(Int32.init(clamping:)), replyToPeerId: nil, quoteText: nil, quoteEntities: nil, quoteOffset: nil)
            }
            let signal: Signal<Never, KeepWebViewError> = network.request(Api.functions.messages.prolongWebView(flags: flags, peer: peer, bot: bot, queryId: queryId, replyTo: replyTo, sendAs: sendAs))
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
        if let _ = payload {
            flags |= (1 << 3)
        }
        if fromMenu {
            flags |= (1 << 4)
        }
        
        var replyTo: Api.InputReplyTo?
        if let replyToMessageId = replyToMessageId {
            flags |= (1 << 0)
            
            var replyFlags: Int32 = 0
            if threadId != nil {
                replyFlags |= 1 << 0
            }
            replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: replyToMessageId.id, topMsgId: threadId.flatMap(Int32.init(clamping:)), replyToPeerId: nil, quoteText: nil, quoteEntities: nil, quoteOffset: nil)
        }

        return network.request(Api.functions.messages.requestWebView(flags: flags, peer: inputPeer, bot: inputBot, url: url, startParam: payload, themeParams: serializedThemeParams, platform: botWebViewPlatform, replyTo: replyTo, sendAs: nil))
        |> mapError { _ -> RequestWebViewError in
            return .generic
        }
        |> mapToSignal { result -> Signal<RequestWebViewResult, RequestWebViewError> in
            switch result {
                case let .webViewResultUrl(webViewFlags, queryId, url):
                var resultFlags: RequestWebViewResult.Flags = []
                if (webViewFlags & (1 << 1)) != 0 {
                    resultFlags.insert(.fullSize)
                }
                let keepAlive: Signal<Never, KeepWebViewError>?
                if let queryId {
                    keepAlive = keepWebViewSignal(network: network, stateManager: stateManager, flags: flags, peer: inputPeer, bot: inputBot, queryId: queryId, replyToMessageId: replyToMessageId, threadId: threadId, sendAs: nil)
                } else {
                    keepAlive = nil
                }
                
                return .single(RequestWebViewResult(flags: resultFlags, queryId: queryId, url: url, keepAliveSignal: keepAlive))
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

func _internal_requestAppWebView(postbox: Postbox, network: Network, stateManager: AccountStateManager, peerId: PeerId, appReference: BotAppReference, payload: String?, themeParams: [String: Any]?, compact: Bool, allowWrite: Bool) -> Signal<RequestWebViewResult, RequestWebViewError> {
    var serializedThemeParams: Api.DataJSON?
    if let themeParams = themeParams, let data = try? JSONSerialization.data(withJSONObject: themeParams, options: []), let dataString = String(data: data, encoding: .utf8) {
        serializedThemeParams = .dataJSON(data: dataString)
    }
    
    return postbox.transaction { transaction -> Signal<RequestWebViewResult, RequestWebViewError> in
        guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }
        
        let app: Api.InputBotApp
        switch appReference {
        case let .id(id, accessHash):
            app = .inputBotAppID(id: id, accessHash: accessHash)
        case let .shortName(peerId, shortName):
            guard let bot = transaction.getPeer(peerId), let inputBot = apiInputUser(bot) else {
                return .fail(.generic)
            }
            app = .inputBotAppShortName(botId: inputBot, shortName: shortName)
        }

        var flags: Int32 = 0
        if let _ = serializedThemeParams {
            flags |= (1 << 2)
        }
        if let _ = payload {
            flags |= (1 << 1)
        }
        if allowWrite {
            flags |= (1 << 0)
        }
        if compact {
            flags |= (1 << 7)
        }
        
        return network.request(Api.functions.messages.requestAppWebView(flags: flags, peer: inputPeer, app: app, startParam: payload, themeParams: serializedThemeParams, platform: botWebViewPlatform))
        |> mapError { _ -> RequestWebViewError in
            return .generic
        }
        |> mapToSignal { result -> Signal<RequestWebViewResult, RequestWebViewError> in
            switch result {
            case let .webViewResultUrl(flags, queryId, url):
                var resultFlags: RequestWebViewResult.Flags = []
                if (flags & (1 << 1)) != 0 {
                    resultFlags.insert(.fullSize)
                }
                return .single(RequestWebViewResult(flags: resultFlags, queryId: queryId, url: url, keepAliveSignal: nil))
            }
        }
    }
    |> castError(RequestWebViewError.self)
    |> switchToLatest
}

func _internal_canBotSendMessages(postbox: Postbox, network: Network, botId: PeerId) -> Signal<Bool, NoError> {
    return postbox.transaction { transaction -> Signal<Bool, NoError> in
        guard let bot = transaction.getPeer(botId), let inputUser = apiInputUser(bot) else {
            return .single(false)
        }

        return network.request(Api.functions.bots.canSendMessage(bot: inputUser))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> map { result -> Bool in
            if case .boolTrue = result {
                return true
            } else {
                return false
            }
        }
    }
    |> switchToLatest
}

func _internal_allowBotSendMessages(postbox: Postbox, network: Network, stateManager: AccountStateManager, botId: PeerId) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Signal<Never, NoError> in
        guard let bot = transaction.getPeer(botId), let inputUser = apiInputUser(bot) else {
            return .never()
        }

        return network.request(Api.functions.bots.allowSendMessage(bot: inputUser))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> map { updates -> Api.Updates? in
            if let updates = updates {
                stateManager.addUpdates(updates)
            }
            return updates
        }
        |> ignoreValues
    }
    |> switchToLatest
}

public enum InvokeBotCustomMethodError {
    case generic
}

func _internal_invokeBotCustomMethod(postbox: Postbox, network: Network, botId: PeerId, method: String, params: String) -> Signal<String, InvokeBotCustomMethodError> {
    let params = Api.DataJSON.dataJSON(data: params)
    return postbox.transaction { transaction -> Signal<String, InvokeBotCustomMethodError> in
        guard let bot = transaction.getPeer(botId), let inputUser = apiInputUser(bot) else {
            return .fail(.generic)
        }
        return network.request(Api.functions.bots.invokeWebViewCustomMethod(bot: inputUser, customMethod: method, params: params))
        |> mapError { _ -> InvokeBotCustomMethodError in
            return .generic
        }
        |> map { result -> String in
            if case let .dataJSON(data) = result {
                return data
            } else {
                return ""
            }
        }
    }
    |> castError(InvokeBotCustomMethodError.self)
    |> switchToLatest
}

public struct TelegramBotBiometricsState: Codable, Equatable {
    public struct OpaqueToken: Codable, Equatable {
        public let publicKey: Data
        public let data: Data
        
        public init(publicKey: Data, data: Data) {
            self.publicKey = publicKey
            self.data = data
        }
    }
    
    public var deviceId: Data
    public var accessRequested: Bool
    public var accessGranted: Bool
    public var opaqueToken: OpaqueToken?
    
    public static func create() -> TelegramBotBiometricsState {
        var deviceId = Data(count: 32)
        deviceId.withUnsafeMutableBytes { buffer -> Void in
            arc4random_buf(buffer.assumingMemoryBound(to: UInt8.self).baseAddress!, buffer.count)
        }

        return TelegramBotBiometricsState(
            deviceId: deviceId,
            accessRequested: false,
            accessGranted: false,
            opaqueToken: nil
        )
    }
    
    public init(deviceId: Data, accessRequested: Bool, accessGranted: Bool, opaqueToken: OpaqueToken?) {
        self.deviceId = deviceId
        self.accessRequested = accessRequested
        self.accessGranted = accessGranted
        self.opaqueToken = opaqueToken
    }
}

func _internal_updateBotBiometricsState(account: Account, peerId: EnginePeer.Id, update: @escaping (TelegramBotBiometricsState?) -> TelegramBotBiometricsState) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Void in
        let previousState = transaction.getPreferencesEntry(key: PreferencesKeys.botBiometricsState(peerId: peerId))?.get(TelegramBotBiometricsState.self)
        
        transaction.setPreferencesEntry(key: PreferencesKeys.botBiometricsState(peerId: peerId), value: PreferencesEntry(update(previousState)))
    }
    |> ignoreValues
}

func _internal_botsWithBiometricState(account: Account) -> Signal<Set<EnginePeer.Id>, NoError> {
    let viewKey: PostboxViewKey = PostboxViewKey.preferencesPrefix(keyPrefix: PreferencesKeys.botBiometricsStatePrefix())
    return account.postbox.combinedView(keys: [viewKey])
    |> map { views -> Set<EnginePeer.Id> in
        guard let view = views.views[viewKey] as? PreferencesPrefixView else {
            return Set()
        }
        
        var result = Set<EnginePeer.Id>()
        for (key, value) in view.values {
            guard let peerId = PreferencesKeys.extractBotBiometricsStatePeerId(key: key) else {
                continue
            }
            if value.get(TelegramBotBiometricsState.self) == nil {
                continue
            }
            result.insert(peerId)
        }
        
        return result
    }
}

func _internal_toggleChatManagingBotIsPaused(account: Account, chatId: EnginePeer.Id) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Bool in
        var isPaused = false
        transaction.updatePeerCachedData(peerIds: Set([chatId]), update: { _, current in
            guard let current = current as? CachedUserData else {
                return current
            }
            
            if var peerStatusSettings = current.peerStatusSettings {
                if let managingBot = peerStatusSettings.managingBot {
                    isPaused = !managingBot.isPaused
                    peerStatusSettings.managingBot?.isPaused = isPaused
                    if !isPaused {
                        peerStatusSettings.managingBot?.canReply = true
                    }
                }
                
                return current.withUpdatedPeerStatusSettings(peerStatusSettings)
            } else {
                return current
            }
        })
        return isPaused
    }
    |> mapToSignal { isPaused -> Signal<Never, NoError> in
        return account.postbox.transaction { transaction -> Api.InputPeer? in
            return transaction.getPeer(chatId).flatMap(apiInputPeer)
        }
        |> mapToSignal { inputPeer -> Signal<Never, NoError> in
            guard let inputPeer else {
                return .complete()
            }
            return account.network.request(Api.functions.account.toggleConnectedBotPaused(peer: inputPeer, paused: isPaused ? .boolTrue : .boolFalse))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> ignoreValues
        }
    }
}

func _internal_removeChatManagingBot(account: Account, chatId: EnginePeer.Id) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Void in
        transaction.updatePeerCachedData(peerIds: Set([chatId]), update: { _, current in
            guard let current = current as? CachedUserData else {
                return current
            }
            
            if var peerStatusSettings = current.peerStatusSettings {
                peerStatusSettings.managingBot = nil
                
                return current.withUpdatedPeerStatusSettings(peerStatusSettings)
            } else {
                return current
            }
        })
        transaction.updatePeerCachedData(peerIds: Set([account.peerId]), update: { _, current in
            guard let current = current as? CachedUserData else {
                return current
            }
            
            if let connectedBot = current.connectedBot {
                var additionalPeers = connectedBot.recipients.additionalPeers
                var excludePeers = connectedBot.recipients.excludePeers
                if connectedBot.recipients.exclude {
                    additionalPeers.insert(chatId)
                } else {
                    additionalPeers.remove(chatId)
                    excludePeers.insert(chatId)
                }
                
                return current.withUpdatedConnectedBot(TelegramAccountConnectedBot(
                    id: connectedBot.id,
                    recipients: TelegramBusinessRecipients(
                        categories: connectedBot.recipients.categories,
                        additionalPeers: additionalPeers,
                        excludePeers: excludePeers,
                        exclude: connectedBot.recipients.exclude
                    ),
                    canReply: connectedBot.canReply
                ))
            } else {
                return current
            }
        })
    }
    |> mapToSignal { _ -> Signal<Never, NoError> in
        return account.postbox.transaction { transaction -> Api.InputPeer? in
            return transaction.getPeer(chatId).flatMap(apiInputPeer)
        }
        |> mapToSignal { inputPeer -> Signal<Never, NoError> in
            guard let inputPeer else {
                return .complete()
            }
            return account.network.request(Api.functions.account.disablePeerConnectedBot(peer: inputPeer))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> ignoreValues
        }
    }
}
