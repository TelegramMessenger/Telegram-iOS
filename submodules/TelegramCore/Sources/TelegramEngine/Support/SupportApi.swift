import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

struct SupportInstallationTag: Codable, Equatable {
    var value: Int64
}

func supportInstallationTag(transaction: Transaction) -> UInt64 {
    if let stored = transaction.getPreferencesEntry(key: PreferencesKeys.supportInstallationTag)?.get(SupportInstallationTag.self) {
        return UInt64(bitPattern: stored.value)
    }
    var value = Int64.random(in: Int64.min ... Int64.max)
    while value & 0xffffffff == 0 {
        value = Int64.random(in: Int64.min ... Int64.max)
    }
    transaction.updatePreferencesEntry(key: PreferencesKeys.supportInstallationTag, { _ in
        return PreferencesEntry(SupportInstallationTag(value: value))
    })
    return UInt64(bitPattern: value)
}

func supportNameFallback(installationTag: UInt64) -> String {
    return "[rand^\(installationTag)]"
}

func supportName(_ result: Api.help.SupportName) -> String {
    switch result {
    case let .supportName(data):
        return data.name
    }
}

func _internal_supportName(network: Network, postbox: Postbox) -> Signal<String, NoError> {
    return network.request(Api.functions.help.getSupportName())
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.help.SupportName?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<String, NoError> in
        if let result {
            return .single(supportName(result))
        }
        return postbox.transaction { transaction -> String in
            return supportNameFallback(installationTag: supportInstallationTag(transaction: transaction))
        }
    }
}

