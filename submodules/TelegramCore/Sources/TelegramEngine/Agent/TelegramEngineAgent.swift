import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
internal import TelegramApi

public struct EngineAgentProvider: Codable, Equatable {
    public let id: String
    public let title: String
    public let vendor: String
    public let keyUrl: String
    public let modelsSearchable: Bool
    public let iconEmojiId: Int64?

    public init(id: String, title: String, vendor: String, keyUrl: String, modelsSearchable: Bool, iconEmojiId: Int64?) {
        self.id = id
        self.title = title
        self.vendor = vendor
        self.keyUrl = keyUrl
        self.modelsSearchable = modelsSearchable
        self.iconEmojiId = iconEmojiId
    }
}

public struct EngineAgentProviderKey: Codable, Equatable {
    public let provider: String
    public let keyLast4: String
    public let dateConnected: Int32

    public init(provider: String, keyLast4: String, dateConnected: Int32) {
        self.provider = provider
        self.keyLast4 = keyLast4
        self.dateConnected = dateConnected
    }
}

public struct EngineAgentSettings: Codable, Equatable {
    public let keys: [EngineAgentProviderKey]
    public let activeProvider: String?

    public init(keys: [EngineAgentProviderKey], activeProvider: String?) {
        self.keys = keys
        self.activeProvider = activeProvider
    }
}

public enum EngineAgentError: Error, Equatable {
    case notAvailable
    case keyInvalid
    case keyMissing
    case providerUnavailable
    case generic
}

/// Whether this build talks the agent API (`TELEGRAM_AGENT_API`). Layer 233 as the server serves it has no agent.*:
/// while this is false nothing is sent, every request fails with `.notAvailable`, `updateAgentSettings` is not decoded,
/// and the app shows no agent bot's provider rows (`peerInfoScreenData`; `submodules/TelegramApi/CLAUDE.md`, "Parked
/// APIs").
#if TELEGRAM_AGENT_API
public let agentApiIsAvailable = true
#else
public let agentApiIsAvailable = false
#endif

#if TELEGRAM_AGENT_API
extension EngineAgentProvider {
    init(apiProvider: Api.agent.Provider) {
        switch apiProvider {
        case let .agentProvider(data):
            self.init(id: data.id, title: data.title, vendor: data.vendor, keyUrl: data.keyUrl, modelsSearchable: (data.flags & (1 << 0)) != 0, iconEmojiId: data.iconEmojiId)
        }
    }
}

extension EngineAgentSettings {
    init(apiSettings: Api.agent.Settings) {
        switch apiSettings {
        case let .settings(data):
            self.init(keys: data.keys.map { key in
                switch key {
                case let .providerKey(keyData):
                    return EngineAgentProviderKey(provider: keyData.provider, keyLast4: keyData.keyLast4, dateConnected: keyData.dateConnected)
                }
            }, activeProvider: data.activeProvider)
        }
    }
}

private func agentError(_ error: MTRpcError) -> EngineAgentError {
    switch error.errorDescription {
    case "AGENT_NOT_AVAILABLE":
        return .notAvailable
    case "AGENT_KEY_INVALID":
        return .keyInvalid
    case "AGENT_KEY_MISSING":
        return .keyMissing
    case "AGENT_PROVIDER_UNAVAILABLE":
        return .providerUnavailable
    default:
        return .generic
    }
}
#endif

private struct CachedAgentProviders: Codable {
    let hash: Int64
    let providers: [EngineAgentProvider]
}

private func agentSettingsCacheKey() -> ItemCacheEntryId {
    let key = ValueBoxKey(length: 1)
    key.setInt8(0, value: 0)
    return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedAgent, key: key)
}

private func agentProvidersCacheKey() -> ItemCacheEntryId {
    let key = ValueBoxKey(length: 1)
    key.setInt8(0, value: 1)
    return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedAgent, key: key)
}

private func storeAgentSettings(postbox: Postbox, settings: EngineAgentSettings) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        if let entry = CodableEntry(settings) {
            transaction.putItemCacheEntry(id: agentSettingsCacheKey(), entry: entry)
        }
    }
    |> ignoreValues
}

/// An `agent.*` request that answers with the settings.
private enum AgentSettingsRequest {
    case getSettings
    case connect(provider: String, key: String)
    case disconnect(provider: String)
    case setActiveProvider(String)
}

private func agentSettingsRequest(account: Account, _ request: AgentSettingsRequest) -> Signal<EngineAgentSettings, EngineAgentError> {
#if TELEGRAM_AGENT_API
    let function: (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.agent.Settings>)
    switch request {
    case .getSettings:
        function = Api.functions.agent.getSettings()
    case let .connect(provider, key):
        function = Api.functions.agent.connect(provider: provider, key: key)
    case let .disconnect(provider):
        function = Api.functions.agent.disconnect(provider: provider)
    case let .setActiveProvider(provider):
        function = Api.functions.agent.setActiveProvider(provider: provider)
    }
    return account.network.request(function)
    |> mapError(agentError)
    |> mapToSignal { result -> Signal<EngineAgentSettings, EngineAgentError> in
        let settings = EngineAgentSettings(apiSettings: result)
        return account.postbox.transaction { transaction -> EngineAgentSettings in
            if let entry = CodableEntry(settings) {
                transaction.putItemCacheEntry(id: agentSettingsCacheKey(), entry: entry)
            }
            return settings
        }
        |> castError(EngineAgentError.self)
    }
#else
    // The agent API is parked (layer 233 has none): nothing is sent.
    return .fail(.notAvailable)
#endif
}

private func refreshAgentProviders(account: Account) -> Signal<Never, NoError> {
#if TELEGRAM_AGENT_API
    let postbox = account.postbox
    return postbox.transaction { transaction -> CachedAgentProviders? in
        return transaction.retrieveItemCacheEntry(id: agentProvidersCacheKey())?.get(CachedAgentProviders.self)
    }
    |> mapToSignal { cached -> Signal<Never, NoError> in
        return account.network.request(Api.functions.agent.getProviders(hash: cached?.hash ?? 0))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.agent.Providers?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            guard let result else {
                return .complete()
            }
            switch result {
            case .providersNotModified:
                return .complete()
            case let .providers(data):
                let providers = data.providers.map(EngineAgentProvider.init(apiProvider:))
                return postbox.transaction { transaction -> Void in
                    if let entry = CodableEntry(CachedAgentProviders(hash: data.hash, providers: providers)) {
                        transaction.putItemCacheEntry(id: agentProvidersCacheKey(), entry: entry)
                    }
                }
                |> ignoreValues
            }
        }
    }
#else
    // The agent API is parked (layer 233 has none): nothing to refresh.
    return .complete()
#endif
}

/// The agent's provider keys as the profile of an agent bot shows them. The state is read from the cache, so it is
/// there at once on a second open; creating a context refreshes it from the server, and every change (this context's
/// own calls and `updateAgentSettings` from other sessions) is written back to the cache.
public final class AgentSettingsContext {
    public struct State: Equatable {
        /// nil until the settings were loaded at least once.
        public var settings: EngineAgentSettings?
        /// nil until the provider catalog was loaded at least once.
        public var providers: [EngineAgentProvider]?
    }

    private let account: Account
    private let disposables = DisposableSet()

    public var state: Signal<State, NoError> {
        let settingsKey = PostboxViewKey.cachedItem(agentSettingsCacheKey())
        let providersKey = PostboxViewKey.cachedItem(agentProvidersCacheKey())
        return self.account.postbox.combinedView(keys: [settingsKey, providersKey])
        |> map { views -> State in
            let settings = (views.views[settingsKey] as? CachedItemView)?.value?.get(EngineAgentSettings.self)
            let providers = (views.views[providersKey] as? CachedItemView)?.value?.get(CachedAgentProviders.self)?.providers
            return State(settings: settings, providers: providers)
        }
        |> distinctUntilChanged
    }

    init(account: Account) {
        self.account = account

        let postbox = account.postbox
        self.disposables.add((account.stateManager.agentSettingsUpdates()
        |> mapToSignal { settings -> Signal<Never, NoError> in
            return storeAgentSettings(postbox: postbox, settings: settings)
        }).startStrict())

        self.reload()
    }

    deinit {
        self.disposables.dispose()
    }

    public func reload() {
        self.disposables.add((agentSettingsRequest(account: self.account, .getSettings)
        |> ignoreValues
        |> `catch` { _ -> Signal<Never, NoError> in
            return .complete()
        }).startStrict())
        self.disposables.add(refreshAgentProviders(account: self.account).startStrict())
    }

    public func connect(provider: String, key: String) -> Signal<EngineAgentSettings, EngineAgentError> {
        return agentSettingsRequest(account: self.account, .connect(provider: provider, key: key))
    }

    public func disconnect(provider: String) -> Signal<EngineAgentSettings, EngineAgentError> {
        return agentSettingsRequest(account: self.account, .disconnect(provider: provider))
    }

    public func setActiveProvider(_ provider: String) -> Signal<EngineAgentSettings, EngineAgentError> {
        return agentSettingsRequest(account: self.account, .setActiveProvider(provider))
    }
}

public extension TelegramEngine {
    final class Agent {
        private let account: Account
        private let cachedProviders = Atomic<(hash: Int64, providers: [EngineAgentProvider])?>(value: nil)

        init(account: Account) {
            self.account = account
        }

        public func settingsContext() -> AgentSettingsContext {
            return AgentSettingsContext(account: self.account)
        }

        public func providers() -> Signal<[EngineAgentProvider], EngineAgentError> {
#if TELEGRAM_AGENT_API
            let cache = self.cachedProviders
            let hash = cache.with { $0?.hash } ?? 0
            return self.account.network.request(Api.functions.agent.getProviders(hash: hash))
            |> mapError(agentError)
            |> map { result -> [EngineAgentProvider] in
                switch result {
                case let .providers(data):
                    let providers = data.providers.map(EngineAgentProvider.init(apiProvider:))
                    let _ = cache.swap((data.hash, providers))
                    return providers
                case .providersNotModified:
                    return cache.with { $0?.providers } ?? []
                }
            }
#else
            // The agent API is parked (layer 233 has none): nothing is sent.
            return .fail(.notAvailable)
#endif
        }

        public func settings() -> Signal<EngineAgentSettings, EngineAgentError> {
            return agentSettingsRequest(account: self.account, .getSettings)
        }

        public func connect(provider: String, key: String) -> Signal<EngineAgentSettings, EngineAgentError> {
            return agentSettingsRequest(account: self.account, .connect(provider: provider, key: key))
        }

        public func disconnect(provider: String) -> Signal<EngineAgentSettings, EngineAgentError> {
            return agentSettingsRequest(account: self.account, .disconnect(provider: provider))
        }

        public func setActiveProvider(_ provider: String) -> Signal<EngineAgentSettings, EngineAgentError> {
            return agentSettingsRequest(account: self.account, .setActiveProvider(provider))
        }

        public func settingsUpdates() -> Signal<EngineAgentSettings, NoError> {
            return self.account.stateManager.agentSettingsUpdates()
        }
    }
}
