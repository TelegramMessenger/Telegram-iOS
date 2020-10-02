import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

func updateAppConfigurationOnce(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return network.request(Api.functions.help.getAppConfig())
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.JSONValue?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Void, NoError> in
        guard let result = result else {
            return .complete()
        }
        return postbox.transaction { transaction -> Void in
            if let data = JSON(apiJson: result) {
                updateAppConfiguration(transaction: transaction, { configuration -> AppConfiguration in
                    var configuration = configuration
                    configuration.data = data
                    return configuration
                })
                var defaultEnableTempKeys = true
                if let value = data["disable_pfs"] as? Bool {
                    defaultEnableTempKeys = false
                }
                updateNetworkSettingsInteractively(transaction: transaction, network: nil, { settings in
                    var settings = settings
                    settings.defaultEnableTempKeys = defaultEnableTempKeys
                    return settings
                })
            }
        }
    }
}

func managedAppConfigurationUpdates(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = Signal<Void, NoError> { subscriber in
        return updateAppConfigurationOnce(postbox: postbox, network: network).start()
    }
    return (poll |> then(.complete() |> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
