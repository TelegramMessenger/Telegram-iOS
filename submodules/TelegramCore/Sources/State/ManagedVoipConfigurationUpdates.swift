import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func managedVoipConfigurationUpdates(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = Signal<Void, NoError> { subscriber in
        return (network.request(Api.functions.phone.getCallConfig())
        |> retryRequest
        |> mapToSignal { result -> Signal<Void, NoError> in
            return postbox.transaction { transaction -> Void in
                switch result {
                    case let .dataJSON(data):
                        updateVoipConfiguration(transaction: transaction, { configuration in
                            var configuration = configuration
                            configuration.serializedData = data
                            return configuration
                        })
                }
            }
        }).start(completed: {
            subscriber.putCompletion()
        })
    }
    return (poll |> then(.complete() |> suspendAwareDelay(12.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
