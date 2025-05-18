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

public enum RequestSimpleWebViewSource : Equatable {
    case generic
    case inline(startParam: String?)
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
        
        var startParam: String? = nil
        
        switch source {
        case let .inline(_startParam):
            startParam = _startParam
            flags |= (1 << 1)
        case .settings:
            flags |= (1 << 2)
        default:
            break
        }
        if let _ = url {
            flags |= (1 << 3)
        }
        return network.request(Api.functions.messages.requestSimpleWebView(flags: flags, bot: inputUser, url: url, startParam: startParam, themeParams: serializedThemeParams, platform: botWebViewPlatform))
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
                if (flags & (1 << 2)) != 0 {
                    resultFlags.insert(.fullScreen)
                }
                return .single(RequestWebViewResult(flags: resultFlags, queryId: queryId, url: url, keepAliveSignal: nil))
            }
        }
    }
    |> castError(RequestWebViewError.self)
    |> switchToLatest
}

func _internal_requestMainWebView(postbox: Postbox, network: Network, peerId: PeerId, botId: PeerId, source: RequestSimpleWebViewSource, themeParams: [String: Any]?) -> Signal<RequestWebViewResult, RequestWebViewError> {
    var serializedThemeParams: Api.DataJSON?
    if let themeParams = themeParams, let data = try? JSONSerialization.data(withJSONObject: themeParams, options: []), let dataString = String(data: data, encoding: .utf8) {
        serializedThemeParams = .dataJSON(data: dataString)
    }
    return postbox.transaction { transaction -> Signal<RequestWebViewResult, RequestWebViewError> in
        guard let bot = transaction.getPeer(botId), let inputUser = apiInputUser(bot) else {
            return .fail(.generic)
        }
        guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }

        var flags: Int32 = 0
        if let _ = serializedThemeParams {
            flags |= (1 << 0)
        }
        var startParam: String? = nil
        
        switch source {
        case let .inline(_startParam):
            startParam = _startParam
            flags |= (1 << 1)
        case .settings:
            flags |= (1 << 2)
        default:
            break
        }
        return network.request(Api.functions.messages.requestMainWebView(flags: flags, peer: inputPeer, bot: inputUser, startParam: startParam, themeParams: serializedThemeParams, platform: botWebViewPlatform))
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
                if (flags & (1 << 2)) != 0 {
                    resultFlags.insert(.fullScreen)
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
        public static let fullScreen = Flags(rawValue: 1 << 1)
    }
    
    public let flags: Flags
    public let queryId: Int64?
    public let url: String
    public let keepAliveSignal: Signal<Never, KeepWebViewError>?
}

public enum RequestWebViewError {
    case generic
}

private func keepWebViewSignal(network: Network, stateManager: AccountStateManager, flags: Int32, peer: Api.InputPeer, monoforumPeerId: Api.InputPeer?, bot: Api.InputUser, queryId: Int64, replyToMessageId: MessageId?, threadId: Int64?, sendAs: Api.InputPeer?) -> Signal<Never, KeepWebViewError> {
    let signal = Signal<Never, KeepWebViewError> { subscriber in
        let poll = Signal<Never, KeepWebViewError> { subscriber in
            var replyTo: Api.InputReplyTo?
            if let replyToMessageId {
                var replyFlags: Int32 = 0
                var topMsgId: Int32?
                if monoforumPeerId != nil {
                    replyFlags |= 1 << 5
                } else if let threadId {
                    replyFlags |= 1 << 0
                    topMsgId = Int32(clamping: threadId)
                }
                replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: replyToMessageId.id, topMsgId: topMsgId, replyToPeerId: nil, quoteText: nil, quoteEntities: nil, quoteOffset: nil, monoforumPeerId: monoforumPeerId)
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
        
        var monoforumPeerId: Api.InputPeer?
        var topMsgId: Int32?
        if let threadId {
            if let channel = peer as? TelegramChannel, channel.flags.contains(.isMonoforum) {
                monoforumPeerId = transaction.getPeer(PeerId(threadId)).flatMap(apiInputPeer)
            } else {
                topMsgId = Int32(clamping: threadId)
            }
        }
        
        if let replyToMessageId = replyToMessageId {
            flags |= (1 << 0)
            
            var replyFlags: Int32 = 0
            
            if monoforumPeerId != nil {
                replyFlags |= 1 << 5
            } else if topMsgId != nil {
                replyFlags |= 1 << 0
            }
            replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: replyToMessageId.id, topMsgId: topMsgId, replyToPeerId: nil, quoteText: nil, quoteEntities: nil, quoteOffset: nil, monoforumPeerId: monoforumPeerId)
        } else if let monoforumPeerId {
            replyTo = .inputReplyToMonoForum(monoforumPeerId: monoforumPeerId)
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
                if (webViewFlags & (1 << 2)) != 0 {
                    resultFlags.insert(.fullScreen)
                }
                let keepAlive: Signal<Never, KeepWebViewError>?
                if let queryId {
                    keepAlive = keepWebViewSignal(network: network, stateManager: stateManager, flags: flags, peer: inputPeer, monoforumPeerId: monoforumPeerId, bot: inputBot, queryId: queryId, replyToMessageId: replyToMessageId, threadId: threadId, sendAs: nil)
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

func _internal_requestAppWebView(postbox: Postbox, network: Network, stateManager: AccountStateManager, peerId: PeerId, appReference: BotAppReference, payload: String?, themeParams: [String: Any]?, compact: Bool, fullscreen: Bool, allowWrite: Bool) -> Signal<RequestWebViewResult, RequestWebViewError> {
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
        if fullscreen {
            flags |= (1 << 8)
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
                if (flags & (1 << 2)) != 0 {
                    resultFlags.insert(.fullScreen)
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

public struct TelegramSecureBotStorageState: Codable, Equatable {
    public let uuid: String
   
    public init(uuid: String) {
        self.uuid = uuid
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.uuid = try container.decode(String.self, forKey: "uuid")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.uuid, forKey: "uuid")
    }
}

func _internal_secureBotStorageUuid(account: Account) -> Signal<String, NoError> {
    return account.postbox.transaction { transaction -> String in
        if let current = transaction.getPreferencesEntry(key: PreferencesKeys.secureBotStorageState())?.get(TelegramSecureBotStorageState.self) {
            return current.uuid
        }
        
        let uuid = "\(Int64.random(in: 0 ..< .max))"
        transaction.setPreferencesEntry(key: PreferencesKeys.secureBotStorageState(), value: PreferencesEntry(TelegramSecureBotStorageState(uuid: uuid)))
        return uuid
    }
}

private let maxBotStorageSize = 5 * 1024 * 1024
public struct TelegramBotStorageState: Codable, Equatable {
    public struct KeyValue: Codable, Equatable {
        var key: String
        var value: String
    }
    
    public var data: [String: String]
   
    public init(
        data: [String: String]
    ) {
        self.data = data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        let values = try container.decode([KeyValue].self, forKey: "data")
        var data: [String: String] = [:]
        for pair in values {
            data[pair.key] = pair.value
        }
        self.data = data
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        var values: [KeyValue] = []
        for (key, value) in self.data {
            values.append(KeyValue(key: key, value: value))
        }
        try container.encode(values, forKey: "data")
    }
}

private func _internal_updateBotStorageState(account: Account, peerId: EnginePeer.Id, update: @escaping (TelegramBotStorageState?) -> TelegramBotStorageState) -> Signal<Never, BotStorageError> {
    return account.postbox.transaction { transaction -> Signal<Never, BotStorageError> in
        let previousState = transaction.getPreferencesEntry(key: PreferencesKeys.botStorageState(peerId: peerId))?.get(TelegramBotStorageState.self)
        let updatedState = update(previousState)
        
        var totalSize = 0
        for (_, value) in updatedState.data {
            totalSize += value.utf8.count
        }
        guard totalSize <= maxBotStorageSize else {
            return .fail(.quotaExceeded)
        }
        
        transaction.setPreferencesEntry(key: PreferencesKeys.botStorageState(peerId: peerId), value: PreferencesEntry(updatedState))
        return .never()
    }
    |> castError(BotStorageError.self)
    |> switchToLatest
    |> ignoreValues
}

public enum BotStorageError {
    case quotaExceeded
}

func _internal_setBotStorageValue(account: Account, peerId: EnginePeer.Id, key: String, value: String?) -> Signal<Never, BotStorageError> {
    return _internal_updateBotStorageState(account: account, peerId: peerId, update: { current in
        var data = current?.data ?? [:]
        if let value {
            data[key] = value
        } else {
            data.removeValue(forKey: key)
        }
        return TelegramBotStorageState(data: data)
    })
}

func _internal_clearBotStorage(account: Account, peerId: EnginePeer.Id) -> Signal<Never, BotStorageError> {
    return _internal_updateBotStorageState(account: account, peerId: peerId, update: { _ in
        return TelegramBotStorageState(data: [:])
    })
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
                    rights: connectedBot.rights
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

public func formatPermille(_ value: Int32) -> String {
    return formatPermille(Int(value))
}

public func formatPermille(_ value: Int) -> String {
    if value % 10 == 0 {
        return "\(value / 10)"
    } else {
        return String(format: "%.1f", Double(value) / 10.0)
    }
}

public enum StarRefBotConnectionEvent {
    case add(peerId: EnginePeer.Id, item: EngineConnectedStarRefBotsContext.Item)
    case remove(peerId: EnginePeer.Id, url: String)
}

public final class EngineConnectedStarRefBotsContext {
    public final class Item: Equatable {
        public let peer: EnginePeer
        public let url: String
        public let timestamp: Int32
        public let commissionPermille: Int32
        public let durationMonths: Int32?
        public let participants: Int64
        public let revenue: Int64
        
        public init(peer: EnginePeer, url: String, timestamp: Int32, commissionPermille: Int32, durationMonths: Int32?, participants: Int64, revenue: Int64) {
            self.peer = peer
            self.url = url
            self.timestamp = timestamp
            self.commissionPermille = commissionPermille
            self.durationMonths = durationMonths
            self.participants = participants
            self.revenue = revenue
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.peer != rhs.peer {
                return false
            }
            if lhs.url != rhs.url {
                return false
            }
            if lhs.timestamp != rhs.timestamp {
                return false
            }
            if lhs.commissionPermille != rhs.commissionPermille {
                return false
            }
            if lhs.durationMonths != rhs.durationMonths {
                return false
            }
            if lhs.participants != rhs.participants {
                return false
            }
            if lhs.revenue != rhs.revenue {
                return false
            }
            return true
        }
    }
    
    public struct State: Equatable {
        public struct Offset: Equatable {
            fileprivate var isInitial: Bool
            fileprivate var timestamp: Int32
            fileprivate var link: String
            
            fileprivate init(isInitial: Bool, timestamp: Int32, link: String) {
                self.isInitial = isInitial
                self.timestamp = timestamp
                self.link = link
            }
        }
        
        public var items: [Item]
        public var totalCount: Int
        public var nextOffset: Offset?
        public var isLoaded: Bool
        
        public init(items: [Item], totalCount: Int, nextOffset: Offset?, isLoaded: Bool) {
            self.items = items
            self.totalCount = totalCount
            self.nextOffset = nextOffset
            self.isLoaded = isLoaded
        }
    }
    
    private final class Impl {
        let queue: Queue
        let account: Account
        let peerId: EnginePeer.Id
        
        var state: State
        var pendingRemoveItems = Set<String>()
        var statePromise = Promise<State>()
        
        var loadMoreDisposable: Disposable?
        var isLoadingMore: Bool = false
        
        var eventsDisposable: Disposable?
        
        init(queue: Queue, account: Account, peerId: EnginePeer.Id) {
            self.queue = queue
            self.account = account
            self.peerId = peerId
            
            self.state = State(items: [], totalCount: 0, nextOffset: State.Offset(isInitial: true, timestamp: 0, link: ""), isLoaded: false)
            self.updateState()
            
            self.loadMore()
            
            self.eventsDisposable = (account.stateManager.starRefBotConnectionEvents()
            |> deliverOn(self.queue)).startStrict(next: { [weak self] event in
                guard let self else {
                    return
                }
                switch event {
                case let .add(peerId, item):
                    if peerId == self.peerId {
                        self.state.items.insert(item, at: 0)
                        self.updateState()
                    }
                case let .remove(peerId, url):
                    if peerId == self.peerId {
                        self.state.items.removeAll(where: { $0.url == url })
                        self.updateState()
                    }
                }
            })
        }
        
        deinit {
            assert(self.queue.isCurrent())
            self.loadMoreDisposable?.dispose()
            self.eventsDisposable?.dispose()
        }
        
        func loadMore() {
            if self.isLoadingMore {
                return
            }
            guard let offset = self.state.nextOffset else {
                return
            }
            self.isLoadingMore = true
            
            var effectiveOffset: (timestamp: Int32, link: String)?
            if !offset.isInitial {
                effectiveOffset = (timestamp: offset.timestamp, link: offset.link)
            }
            self.loadMoreDisposable?.dispose()
            self.loadMoreDisposable = (_internal_requestConnectedStarRefBots(account: self.account, id: self.peerId, offset: effectiveOffset, limit: 100)
            |> deliverOn(self.queue)).startStrict(next: { [weak self] result in
                guard let self else {
                    return
                }
                
                self.isLoadingMore = false
                
                self.state.isLoaded = true
                if let result, !result.items.isEmpty {
                    for item in result.items {
                        if !self.state.items.contains(where: { $0.url == item.url }) {
                            self.state.items.append(item)
                        }
                    }
                    if result.nextOffset != nil {
                        self.state.totalCount = result.totalCount
                    } else {
                        self.state.totalCount = self.state.items.count
                    }
                    self.state.nextOffset = result.nextOffset.flatMap { value in
                        return State.Offset(isInitial: false, timestamp: value.timestamp, link: value.link)
                    }
                } else {
                    self.state.totalCount = self.state.items.count
                    self.state.nextOffset = nil
                }
                
                self.updateState()
            })
        }
        
        private func updateState() {
            var state = self.state
            if !self.pendingRemoveItems.isEmpty {
                state.items = state.items.filter { item in
                    return !self.pendingRemoveItems.contains(item.url)
                }
            }
            self.statePromise.set(.single(state))
        }
        
        func remove(url: String) {
            self.pendingRemoveItems.insert(url)
            let _ = _internal_removeConnectedStarRefBot(account: self.account, id: self.peerId, link: url).startStandalone()
            self.updateState()
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public var state: Signal<State, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.statePromise.get().start(next: subscriber.putNext)
        }
    }
    
    init(account: Account, peerId: EnginePeer.Id) {
        let queue = Queue.mainQueue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, peerId: peerId)
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
    
    public func remove(url: String) {
        self.impl.with { impl in
            impl.remove(url: url)
        }
    }
}

public final class EngineSuggestedStarRefBotsContext {
    public final class Item: Equatable {
        public let peer: EnginePeer
        public let program: TelegramStarRefProgram
        
        public init(peer: EnginePeer, program: TelegramStarRefProgram) {
            self.peer = peer
            self.program = program
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.peer != rhs.peer {
                return false
            }
            if lhs.program != rhs.program {
                return false
            }
            return true
        }
    }
    
    public struct State: Equatable {
        public var items: [Item]
        public var totalCount: Int
        public var nextOffset: String?
        public var isLoaded: Bool
        
        public init(items: [Item], totalCount: Int, nextOffset: String?, isLoaded: Bool) {
            self.items = items
            self.totalCount = totalCount
            self.nextOffset = nextOffset
            self.isLoaded = isLoaded
        }
    }
    
    public enum SortMode {
        case date
        case profitability
        case revenue
    }
    
    private final class Impl {
        let queue: Queue
        let account: Account
        let peerId: EnginePeer.Id
        let sortMode: SortMode
        
        var state: State
        var statePromise = Promise<State>()
        
        var loadMoreDisposable: Disposable?
        var isLoadingMore: Bool = false
        
        init(queue: Queue, account: Account, peerId: EnginePeer.Id, sortMode: SortMode) {
            self.queue = queue
            self.account = account
            self.peerId = peerId
            self.sortMode = sortMode
            
            self.state = State(items: [], totalCount: 0, nextOffset: "", isLoaded: false)
            self.updateState()
            
            self.loadMore()
        }
        
        deinit {
            assert(self.queue.isCurrent())
            self.loadMoreDisposable?.dispose()
        }
        
        func loadMore() {
            if self.isLoadingMore {
                return
            }
            guard let offset = self.state.nextOffset else {
                return
            }
            self.isLoadingMore = true
            
            self.loadMoreDisposable?.dispose()
            self.loadMoreDisposable = (_internal_requestSuggestedStarRefBots(account: self.account, id: self.peerId, sortMode: self.sortMode, offset: offset, limit: 100)
            |> deliverOn(self.queue)).startStrict(next: { [weak self] result in
                guard let self else {
                    return
                }
                self.isLoadingMore = false
                
                self.state.isLoaded = true
                if let result, !result.items.isEmpty {
                    for item in result.items {
                        if !self.state.items.contains(where: { $0.peer.id == item.peer.id }) {
                            self.state.items.append(item)
                        }
                    }
                    if result.nextOffset != nil {
                        self.state.totalCount = result.totalCount
                    } else {
                        self.state.totalCount = self.state.items.count
                    }
                    self.state.nextOffset = result.nextOffset
                } else {
                    self.state.totalCount = self.state.items.count
                    self.state.nextOffset = nil
                }
                
                self.updateState()
            })
        }
        
        private func updateState() {
            self.statePromise.set(.single(self.state))
        }
    }
    
    private let queue: Queue
    public let sortMode: SortMode
    private let impl: QueueLocalObject<Impl>
    
    public var state: Signal<State, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.statePromise.get().start(next: subscriber.putNext)
        }
    }
    
    init(account: Account, peerId: EnginePeer.Id, sortMode: SortMode) {
        let queue = Queue.mainQueue()
        self.queue = queue
        self.sortMode = sortMode
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, peerId: peerId, sortMode: sortMode)
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
}

func _internal_updateStarRefProgram(account: Account, id: EnginePeer.Id, program: (commissionPermille: Int32, durationMonths: Int32?)?) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(id).flatMap(apiInputUser)
    }
    |> mapToSignal { inputPeer -> Signal<Never, NoError> in
        guard let inputPeer else {
            return .complete()
        }
        
        var flags: Int32 = 0
        if let program, program.durationMonths != nil {
            flags |= 1 << 0
        }
        
        return account.network.request(Api.functions.bots.updateStarRefProgram(
            flags: flags,
            bot: inputPeer,
            commissionPermille: program?.commissionPermille ?? 0,
            durationMonths: program?.durationMonths
        ))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.StarRefProgram?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            guard let result else {
                return .complete()
            }
            return account.postbox.transaction { transaction -> Void in
                transaction.updatePeerCachedData(peerIds: Set([id]), update: { _, current in
                    guard var current = current as? CachedUserData else {
                        return current ?? CachedUserData()
                    }
                    current = current.withUpdatedStarRefProgram(TelegramStarRefProgram(apiStarRefProgram: result))
                    return current
                })
            }
            |> ignoreValues
        }
    }
}

fileprivate func  _internal_requestConnectedStarRefBots(account: Account, id: EnginePeer.Id, offset: (timestamp: Int32, link: String)?, limit: Int) -> Signal<(items: [EngineConnectedStarRefBotsContext.Item], totalCount: Int, nextOffset: (timestamp: Int32, link: String)?)?, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(id).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<(items: [EngineConnectedStarRefBotsContext.Item], totalCount: Int, nextOffset: (timestamp: Int32, link: String)?)?, NoError> in
        guard let inputPeer else {
            return .single(nil)
        }
        var flags: Int32 = 0
        if offset != nil {
            flags |= 1 << 2
        }
        return account.network.request(Api.functions.payments.getConnectedStarRefBots(
            flags: flags,
            peer: inputPeer,
            offsetDate: offset?.timestamp,
            offsetLink: offset?.link,
            limit: Int32(limit)
        ))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.payments.ConnectedStarRefBots?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<(items: [EngineConnectedStarRefBotsContext.Item], totalCount: Int, nextOffset: (timestamp: Int32, link: String)?)?, NoError> in
            guard let result else {
                return .single(nil)
            }
            return account.postbox.transaction { transaction -> (items: [EngineConnectedStarRefBotsContext.Item], totalCount: Int, nextOffset: (timestamp: Int32, link: String)?)? in
                switch result {
                case let .connectedStarRefBots(count, connectedBots, users):
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(users: users))
                    
                    var items: [EngineConnectedStarRefBotsContext.Item] = []
                    for connectedBot in connectedBots {
                        switch connectedBot {
                        case let .connectedBotStarRef(_, url, date, botId, commissionPermille, durationMonths, participants, revenue):
                            guard let botPeer = transaction.getPeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId))) else {
                                continue
                            }
                            items.append(EngineConnectedStarRefBotsContext.Item(
                                peer: EnginePeer(botPeer),
                                url: url,
                                timestamp: date,
                                commissionPermille: commissionPermille,
                                durationMonths: durationMonths,
                                participants: participants,
                                revenue: revenue
                            ))
                        }
                    }
                    
                    var nextOffset: (timestamp: Int32, link: String)?
                    if !connectedBots.isEmpty {
                        nextOffset = items.last.flatMap { item in
                            return (item.timestamp, item.url)
                        }
                    }
                    
                    return (items: items, totalCount: Int(count), nextOffset: nextOffset)
                }
            }
        }
    }
}

fileprivate func _internal_requestSuggestedStarRefBots(account: Account, id: EnginePeer.Id, sortMode: EngineSuggestedStarRefBotsContext.SortMode, offset: String?, limit: Int) -> Signal<(items: [EngineSuggestedStarRefBotsContext.Item], totalCount: Int, nextOffset: String?)?, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(id).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<(items: [EngineSuggestedStarRefBotsContext.Item], totalCount: Int, nextOffset: String?)?, NoError> in
        guard let inputPeer else {
            return .single(nil)
        }
        var flags: Int32 = 0
        switch sortMode {
        case .revenue:
            flags |= 1 << 0
        case .date:
            flags |= 1 << 1
        case .profitability:
            break
        }
        return account.network.request(Api.functions.payments.getSuggestedStarRefBots(
            flags: flags,
            peer: inputPeer,
            offset: offset ?? "",
            limit: Int32(limit)
        ))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.payments.SuggestedStarRefBots?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<(items: [EngineSuggestedStarRefBotsContext.Item], totalCount: Int, nextOffset: String?)?, NoError> in
            guard let result else {
                return .single(nil)
            }
            return account.postbox.transaction { transaction -> (items: [EngineSuggestedStarRefBotsContext.Item], totalCount: Int, nextOffset: String?)? in
                switch result {
                case let .suggestedStarRefBots(_, count, suggestedBots, users, nextOffset):
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(users: users))
                    
                    var items: [EngineSuggestedStarRefBotsContext.Item] = []
                    for starRefProgram in suggestedBots {
                        let parsedProgram = TelegramStarRefProgram(apiStarRefProgram: starRefProgram)
                        guard let botPeer = transaction.getPeer(parsedProgram.botId) else {
                            continue
                        }
                        items.append(EngineSuggestedStarRefBotsContext.Item(
                            peer: EnginePeer(botPeer),
                            program: parsedProgram
                        ))
                    }
                    
                    return (items: items, totalCount: Int(count), nextOffset: nextOffset)
                }
            }
        }
    }
}

public enum ConnectStarRefBotError {
    case generic
}

func _internal_connectStarRefBot(account: Account, id: EnginePeer.Id, botId: EnginePeer.Id) -> Signal<EngineConnectedStarRefBotsContext.Item, ConnectStarRefBotError> {
    return account.postbox.transaction { transaction -> (Api.InputPeer?, Api.InputUser?) in
        return (
            transaction.getPeer(id).flatMap(apiInputPeer),
            transaction.getPeer(botId).flatMap(apiInputUser)
        )
    }
    |> castError(ConnectStarRefBotError.self)
    |> mapToSignal { inputPeer, inputBotUser -> Signal<EngineConnectedStarRefBotsContext.Item, ConnectStarRefBotError> in
        guard let inputPeer, let inputBotUser else {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.payments.connectStarRefBot(peer: inputPeer, bot: inputBotUser))
        |> mapError { _ -> ConnectStarRefBotError in
            return .generic
        }
        |> mapToSignal { result -> Signal<EngineConnectedStarRefBotsContext.Item, ConnectStarRefBotError> in
            return account.postbox.transaction { transaction -> EngineConnectedStarRefBotsContext.Item? in
                switch result {
                case let .connectedStarRefBots(_, connectedBots, users):
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(users: users))
                    
                    if let bot = connectedBots.first {
                        switch bot {
                        case let .connectedBotStarRef(_, url, date, botId, commissionPermille, durationMonths, participants, revenue):
                            guard let botPeer = transaction.getPeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId))) else {
                                return nil
                            }
                            return EngineConnectedStarRefBotsContext.Item(
                                peer: EnginePeer(botPeer),
                                url: url,
                                timestamp: date,
                                commissionPermille: commissionPermille,
                                durationMonths: durationMonths,
                                participants: participants,
                                revenue: revenue
                            )
                        }
                    } else {
                        return nil
                    }
                }
            }
            |> castError(ConnectStarRefBotError.self)
            |> mapToSignal { item -> Signal<EngineConnectedStarRefBotsContext.Item, ConnectStarRefBotError> in
                if let item {
                    account.stateManager.addStarRefBotConnectionEvent(event: .add(peerId: id, item: item))
                    return .single(item)
                } else {
                    return .fail(.generic)
                }
            }
        }
    }
}

fileprivate func _internal_removeConnectedStarRefBot(account: Account, id: EnginePeer.Id, link: String) -> Signal<Never, ConnectStarRefBotError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(id).flatMap(apiInputPeer)
    }
    |> castError(ConnectStarRefBotError.self)
    |> mapToSignal { inputPeer -> Signal<Never, ConnectStarRefBotError> in
        guard let inputPeer else {
            return .fail(.generic)
        }
        var flags: Int32 = 0
        flags |= 1 << 0
        return account.network.request(Api.functions.payments.editConnectedStarRefBot(flags: flags, peer: inputPeer, link: link))
        |> mapError { _ -> ConnectStarRefBotError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, ConnectStarRefBotError> in
            return account.postbox.transaction { transaction -> Void in
                switch result {
                case let .connectedStarRefBots(_, connectedBots, users):
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(users: users))
                    
                    let _ = connectedBots
                }
                
                account.stateManager.addStarRefBotConnectionEvent(event: .remove(peerId: id, url: link))
            }
            |> castError(ConnectStarRefBotError.self)
            |> ignoreValues
        }
    }
}

func _internal_getStarRefBotConnection(account: Account, id: EnginePeer.Id, targetId: EnginePeer.Id) -> Signal<EngineConnectedStarRefBotsContext.Item?, NoError> {
    return account.postbox.transaction { transaction -> (Api.InputUser?, Api.InputPeer?) in
        return (
            transaction.getPeer(id).flatMap(apiInputUser),
            transaction.getPeer(targetId).flatMap(apiInputPeer)
        )
    }
    |> mapToSignal { inputPeer, targetPeer -> Signal<EngineConnectedStarRefBotsContext.Item?, NoError> in
        guard let inputPeer, let targetPeer else {
            return .single(nil)
        }
        return account.network.request(Api.functions.payments.getConnectedStarRefBot(peer: targetPeer, bot: inputPeer))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.payments.ConnectedStarRefBots?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<EngineConnectedStarRefBotsContext.Item?, NoError> in
            guard let result else {
                return .single(nil)
            }
            return account.postbox.transaction { transaction -> EngineConnectedStarRefBotsContext.Item? in
                switch result {
                case let .connectedStarRefBots(_, connectedBots, users):
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(users: users))
                    
                    if let bot = connectedBots.first {
                        switch bot {
                        case let .connectedBotStarRef(flags, url, date, botId, commissionPermille, durationMonths, participants, revenue):
                            let isRevoked = (flags & (1 << 1)) != 0
                            if isRevoked {
                               return nil
                            }
                            
                            guard let botPeer = transaction.getPeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId))) else {
                                return nil
                            }
                            return EngineConnectedStarRefBotsContext.Item(
                                peer: EnginePeer(botPeer),
                                url: url,
                                timestamp: date,
                                commissionPermille: commissionPermille,
                                durationMonths: durationMonths,
                                participants: participants,
                                revenue: revenue
                            )
                        }
                    } else {
                        return nil
                    }
                }
            }
        }
    }
}

func _internal_getPossibleStarRefBotTargets(account: Account) -> Signal<[EnginePeer], NoError> {
    return combineLatest(
        account.network.request(Api.functions.bots.getAdminedBots())
        |> `catch` { _ -> Signal<[Api.User], NoError> in
            return .single([])
        },
        account.network.request(Api.functions.channels.getAdminedPublicChannels(flags: 0))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.Chats?, NoError> in
            return .single(nil)
        }
    )
    |> mapToSignal { apiBots, apiChannels -> Signal<[EnginePeer], NoError> in
        return account.postbox.transaction { transaction -> [EnginePeer] in
            var result: [EnginePeer] = []
            
            if let peer = transaction.getPeer(account.peerId) {
                result.append(EnginePeer(peer))
            }
            
            updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(users: apiBots))
            for bot in apiBots {
                if let peer = transaction.getPeer(bot.peerId) {
                    result.append(EnginePeer(peer))
                }
            }
            
            if let apiChannels {
                switch apiChannels {
                case let .chats(chats), let .chatsSlice(_, chats):
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(chats: chats, users: []))
                    
                    for chat in chats {
                        if let peer = transaction.getPeer(chat.peerId) {
                            result.append(EnginePeer(peer))
                        }
                    }
                }
            }
            
            return result
        }
    }
}
