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

func initializedAppChangelogAfterLogin(transaction: Transaction, appVersion: String) {
    updateAppChangelogState(transaction: transaction, { state in
        var state = state
        state.checkedVersion = appVersion
        state.previousVersion = appVersion
        return state
    })
}

func managedAppChangelog(postbox: Postbox, network: Network, stateManager: AccountStateManager, appVersion: String) -> Signal<Void, NoError> {
    return stateManager.pollStateUpdateCompletion()
    |> take(1)
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return postbox.transaction { transaction -> AppChangelogState in
            return transaction.getPreferencesEntry(key: PreferencesKeys.appChangelogState) as? AppChangelogState ?? AppChangelogState.default
        }
        |> mapToSignal { appChangelogState -> Signal<Void, NoError> in
            var appChangelogState = appChangelogState
            #if DEBUG
            appChangelogState = AppChangelogState(checkedVersion: "5.0.17", previousVersion: "5.0.17")
            #endif
            
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

