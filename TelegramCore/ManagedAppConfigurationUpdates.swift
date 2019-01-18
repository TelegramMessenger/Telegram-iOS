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

func managedAppConfigurationUpdates(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = Signal<Void, NoError> { subscriber in
        return (network.request(Api.functions.help.getAppConfig())
        |> retryRequest
        |> mapToSignal { result -> Signal<Void, NoError> in
            return postbox.transaction { transaction -> Void in
                if let data = JSON(apiJson: result) {
                    updateAppConfiguration(transaction: transaction, { configuration -> AppConfiguration in
                        var configuration = configuration
                        configuration.data = data
                        return configuration
                    })
                }
            }
        }).start()
    }
    return (poll |> then(.complete() |> suspendAwareDelay(12.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
