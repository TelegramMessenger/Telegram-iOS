import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

func managedAutodownloadSettingsUpdates(accountManager: AccountManager, network: Network) -> Signal<Void, NoError> {
    let poll = Signal<Void, NoError> { subscriber in
        return (network.request(Api.functions.account.getAutoDownloadSettings())
        |> retryRequest
        |> mapToSignal { result -> Signal<Void, NoError> in
            return accountManager.transaction { transaction -> Void in
                return updateAutodownloadSettingsInteractively(accountManager: accountManager, { _ -> AutodownloadSettings in
                    return AutodownloadSettings(apiAutodownloadSettings: result)
                })
            }
        }).start()
    }
    return (poll |> then(.complete() |> suspendAwareDelay(24.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
