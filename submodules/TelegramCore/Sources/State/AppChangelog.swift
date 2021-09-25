import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
import TelegramApi


func managedAppChangelog(postbox: Postbox, network: Network, stateManager: AccountStateManager, appVersion: String) -> Signal<Void, NoError> {
    return stateManager.pollStateUpdateCompletion()
    |> take(1)
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return postbox.transaction { transaction -> AppChangelogState in
            return transaction.getPreferencesEntry(key: PreferencesKeys.appChangelogState)?.get(AppChangelogState.self) ?? AppChangelogState.default
        }
        |> mapToSignal { appChangelogState -> Signal<Void, NoError> in
            let appChangelogState = appChangelogState
            if appChangelogState.checkedVersion == appVersion {
                return .complete()
            }
            let previousVersion = appChangelogState.previousVersion
            return network.request(Api.functions.help.getAppChangelog(prevAppVersion: previousVersion))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { updates -> Signal<Void, NoError> in
                if let updates = updates {
                    stateManager.addUpdates(updates)
                }
                
                return postbox.transaction { transaction in
                    updateAppChangelogState(transaction: transaction, { state in
                        var state = state
                        state.checkedVersion = appVersion
                        state.previousVersion = appVersion
                        return state
                    })
                }
            }
        }
    }
}

