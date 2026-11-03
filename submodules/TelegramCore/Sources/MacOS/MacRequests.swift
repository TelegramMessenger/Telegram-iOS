import Foundation
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

public enum AppConfigurationRequestResult {
    case notModified
    case updated(data: JSON, hash: Int32)
}

/// One `help.getAppConfig` call for a caller that stores the configuration itself (Telegram-Mac
/// keeps one for unauthorized networks in the account manager). An unparsable config is `notModified`.
public func requestAppConfiguration(network: Network, hash: Int32) -> Signal<AppConfigurationRequestResult, MTRpcError> {
    return network.request(Api.functions.help.getAppConfig(hash: hash))
    |> map { result -> AppConfigurationRequestResult in
        switch result {
        case let .appConfig(data):
            if let json = JSON(apiJson: data.config) {
                return .updated(data: json, hash: data.hash)
            } else {
                return .notModified
            }
        case .appConfigNotModified:
            return .notModified
        }
    }
}

public struct TakeoutSessionContents: OptionSet {
    public var rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let contacts = TakeoutSessionContents(rawValue: 1 << 0)
    public static let messageUsers = TakeoutSessionContents(rawValue: 1 << 1)
    public static let messageChats = TakeoutSessionContents(rawValue: 1 << 2)
    public static let messageMegagroups = TakeoutSessionContents(rawValue: 1 << 3)
    public static let messageChannels = TakeoutSessionContents(rawValue: 1 << 4)
    public static let files = TakeoutSessionContents(rawValue: 1 << 5)
}

/// Starts a takeout session and returns its id. Fails with `TAKEOUT_INIT_DELAY_<seconds>` while
/// the server asks to wait.
public func initTakeoutSession(network: Network, contents: TakeoutSessionContents, fileMaxSize: Int64?) -> Signal<Int64, MTRpcError> {
    return network.request(Api.functions.account.initTakeoutSession(flags: contents.rawValue, fileMaxSize: contents.contains(.files) ? fileMaxSize : nil))
    |> map { result -> Int64 in
        switch result {
        case let .takeout(data):
            return data.id
        }
    }
}

public func finishTakeoutSession(network: Network, success: Bool) -> Signal<Never, MTRpcError> {
    return network.request(Api.functions.account.finishTakeoutSession(flags: success ? (1 << 0) : 0))
    |> ignoreValues
}
