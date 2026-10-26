import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
internal import TelegramApi

public struct EngineAgentProvider: Equatable {
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

public struct EngineAgentProviderKey: Equatable {
    public let provider: String
    public let keyLast4: String
    public let dateConnected: Int32

    public init(provider: String, keyLast4: String, dateConnected: Int32) {
        self.provider = provider
        self.keyLast4 = keyLast4
        self.dateConnected = dateConnected
    }
}

public struct EngineAgentSettings: Equatable {
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

private func agentSettingsRequest(account: Account, _ request: (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.agent.Settings>)) -> Signal<EngineAgentSettings, EngineAgentError> {
    return account.network.request(request)
    |> mapError(agentError)
    |> map(EngineAgentSettings.init(apiSettings:))
}

public extension TelegramEngine {
    final class Agent {
        private let account: Account
        private let cachedProviders = Atomic<(hash: Int64, providers: [EngineAgentProvider])?>(value: nil)

        init(account: Account) {
            self.account = account
        }

        public func providers() -> Signal<[EngineAgentProvider], EngineAgentError> {
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
        }

        public func settings() -> Signal<EngineAgentSettings, EngineAgentError> {
            return agentSettingsRequest(account: self.account, Api.functions.agent.getSettings())
        }

        public func connect(provider: String, key: String) -> Signal<EngineAgentSettings, EngineAgentError> {
            return agentSettingsRequest(account: self.account, Api.functions.agent.connect(provider: provider, key: key))
        }

        public func disconnect(provider: String) -> Signal<EngineAgentSettings, EngineAgentError> {
            return agentSettingsRequest(account: self.account, Api.functions.agent.disconnect(provider: provider))
        }

        public func setActiveProvider(_ provider: String) -> Signal<EngineAgentSettings, EngineAgentError> {
            return agentSettingsRequest(account: self.account, Api.functions.agent.setActiveProvider(provider: provider))
        }

        public func settingsUpdates() -> Signal<EngineAgentSettings, NoError> {
            return self.account.stateManager.agentSettingsUpdates()
            |> map(EngineAgentSettings.init(apiSettings:))
        }
    }
}
