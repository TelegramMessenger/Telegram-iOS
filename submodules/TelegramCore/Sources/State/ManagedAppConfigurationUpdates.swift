import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

/// `confirmed` gets the stored configuration once the server confirmed it is current (a new one was
/// stored, or the stored one is not modified).
func updateAppConfigurationOnce(postbox: Postbox, network: Network, confirmed: ((AppConfiguration) -> Signal<Void, NoError>)? = nil) -> Signal<Void, NoError> {
    return fetchAppConfiguration(
        storedHash: postbox.transaction { transaction -> Int32 in
            return currentAppConfiguration(transaction: transaction).hash
        },
        request: { hash in
            return network.request(Api.functions.help.getAppConfig(hash: hash))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.help.AppConfig?, NoError> in
                return .single(nil)
            }
        },
        store: { data, hash in
            return postbox.transaction { transaction -> AppConfiguration? in
                guard let data = JSON(apiJson: data) else {
                    return nil
                }
                updateAppConfiguration(transaction: transaction, { configuration -> AppConfiguration in
                    var configuration = configuration
                    configuration.data = data
                    configuration.hash = hash
                    return configuration
                })
                
                if let audioTranscriptionCooldownUntilTimestamp = data["transcribe_audio_trial_cooldown_until"] as? Double {
                    _internal_updateAudioTranscriptionTrialState(transaction: transaction, { $0.withUpdatedCooldownUntilTime(Int32(audioTranscriptionCooldownUntilTimestamp)) })
                } else {
                    _internal_updateAudioTranscriptionTrialState(transaction: transaction, { $0.withUpdatedCooldownUntilTime(nil) })
                }
                return currentAppConfiguration(transaction: transaction)
            }
        },
        stored: postbox.transaction { transaction -> AppConfiguration in
            return currentAppConfiguration(transaction: transaction)
        },
        confirmed: confirmed
    )
}

/// `updateAppConfigurationOnce` with its storage and request passed in. `request` answers nil on an
/// error, `store` nil when the configuration cannot be parsed; neither confirms anything.
func fetchAppConfiguration(storedHash: Signal<Int32, NoError>, request: @escaping (Int32) -> Signal<Api.help.AppConfig?, NoError>, store: @escaping (Api.JSONValue, Int32) -> Signal<AppConfiguration?, NoError>, stored: Signal<AppConfiguration, NoError>, confirmed: ((AppConfiguration) -> Signal<Void, NoError>)?) -> Signal<Void, NoError> {
    return storedHash
    |> mapToSignal { hash -> Signal<Void, NoError> in
        return request(hash)
        |> mapToSignal { result -> Signal<Void, NoError> in
            let applied: Signal<AppConfiguration?, NoError>
            switch result {
            case let .appConfig(appConfigData):
                applied = store(appConfigData.config, appConfigData.hash)
            case .appConfigNotModified:
                guard confirmed != nil else {
                    return .complete()
                }
                applied = stored |> map(Optional.init)
            case .none:
                return .complete()
            }
            return applied
            |> mapToSignal { configuration -> Signal<Void, NoError> in
                guard let configuration = configuration, let confirmed = confirmed else {
                    return .complete()
                }
                return confirmed(configuration)
            }
        }
    }
}

func managedAppConfigurationUpdates(postbox: Postbox, network: Network, confirmed: ((AppConfiguration) -> Signal<Void, NoError>)? = nil) -> Signal<Void, NoError> {
    let poll = Signal<Void, NoError> { subscriber in
        return updateAppConfigurationOnce(postbox: postbox, network: network, confirmed: confirmed).start(completed: {
            subscriber.putCompletion()
        })
    }
    return (poll |> then(.complete() |> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
