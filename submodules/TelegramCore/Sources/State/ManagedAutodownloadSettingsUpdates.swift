import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


func managedAutodownloadSettingsUpdates(accountManager: AccountManager<TelegramAccountManagerTypes>, network: Network) -> Signal<Void, NoError> {
    let poll = Signal<Void, NoError> { subscriber in
        return (network.request(Api.functions.account.getAutoDownloadSettings())
        |> retryRequest
        |> mapToSignal { result -> Signal<Void, NoError> in
            return updateAutodownloadSettingsInteractively(accountManager: accountManager, { _ -> AutodownloadSettings in
                return AutodownloadSettings(apiAutodownloadSettings: result)
            })
        }).start(completed: {
            subscriber.putCompletion()
        })
    }
    return (poll |> then(.complete() |> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

public enum SavedAutodownloadPreset {
    case low
    case medium
    case high 
}

public func saveAutodownloadSettings(account: Account, preset: SavedAutodownloadPreset, settings: AutodownloadPresetSettings) -> Signal<Void, NoError> {
    var flags: Int32 = 0
    switch preset {
        case .low:
            flags |= (1 << 0)
        case .high:
            flags |= (1 << 1)
        default:
            break
    }
    return account.network.request(Api.functions.account.saveAutoDownloadSettings(flags: flags, settings: apiAutodownloadPresetSettings(settings)))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .complete()
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
    }
}
