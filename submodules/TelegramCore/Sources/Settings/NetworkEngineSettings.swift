import Foundation
import Postbox
import SwiftSignalKit

public func updateNetworkEngineSettings(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (NetworkEngineSettings) -> NetworkEngineSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(SharedDataKeys.networkEngineSettings, { current in
            let previous = current?.get(NetworkEngineSettings.self) ?? NetworkEngineSettings.defaultSettings
            return PreferencesEntry(f(previous))
        })
    }
}

/// The build `NetworkEngineState` is kept for: the app version string with the bundle's build number,
/// so a fixed build that keeps the version string still starts clean.
func networkEngineStateBuild(appVersion: String, bundleVersion: String? = nil) -> String {
    let build = bundleVersion ?? (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "")
    return "\(appVersion) (\(build))"
}

/// The live accounts: every record except the logged-out ones (`keepingServerFlags(of:)` says whose flags count).
func networkEngineLiveAccountIds(records: [AccountRecord<TelegramAccountManagerTypes.Attribute>]) -> Set<Int64> {
    var accountIds = Set<Int64>()
    for record in records {
        let loggedOut = record.attributes.contains(where: { attribute in
            if case .loggedOut = attribute {
                return true
            } else {
                return false
            }
        })
        if !loggedOut {
            accountIds.insert(record.id.int64)
        }
    }
    return accountIds
}

/// What a network needs from the accountManager to pick its engine. It can only be read from an
/// accountManager transaction (`networkEngineInputs(transaction:)`), so no network can start without
/// the shared state, pruned against the accounts still there (`keepingServerFlags(of:)`).
struct NetworkEngineInputs {
    let settings: NetworkEngineSettings?
    let state: NetworkEngineState?

    fileprivate init(settings: NetworkEngineSettings?, state: NetworkEngineState?) {
        self.settings = settings
        self.state = state
    }
}

func networkEngineInputs(transaction: AccountManagerModifier<TelegramAccountManagerTypes>) -> NetworkEngineInputs {
    let state = transaction.getSharedData(SharedDataKeys.networkEngineState)?.get(NetworkEngineState.self)
    return NetworkEngineInputs(
        settings: transaction.getSharedData(SharedDataKeys.networkEngineSettings)?.get(NetworkEngineSettings.self),
        state: state?.keepingServerFlags(of: networkEngineLiveAccountIds(records: transaction.getRecords()))
    )
}

/// The shared state as it changes, pruned against the accounts still there as
/// `networkEngineInputs(transaction:)` prunes it.
func networkEngineStateView(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<NetworkEngineState?, NoError> {
    return combineLatest(accountManager.sharedData(keys: [SharedDataKeys.networkEngineState]), accountManager.accountRecords())
    |> map { sharedData, view -> NetworkEngineState? in
        return sharedData.entries[SharedDataKeys.networkEngineState]?.get(NetworkEngineState.self)?.keepingServerFlags(of: networkEngineLiveAccountIds(records: view.records))
    }
}

private func updateNetworkEngineState(transaction: AccountManagerModifier<TelegramAccountManagerTypes>, _ f: (NetworkEngineState) -> NetworkEngineState) -> NetworkEngineState {
    var result = NetworkEngineState()
    transaction.updateSharedData(SharedDataKeys.networkEngineState, { current in
        let previous = current?.get(NetworkEngineState.self) ?? NetworkEngineState()
        result = f(previous)
        if current != nil && result == previous {
            return current
        }
        return PreferencesEntry(result)
    })
    return result
}

/// What `help.getAppConfig` just told a production account (`managedAppConfigurationUpdates`).
func updateNetworkEngineServerFlag(accountManager: AccountManager<TelegramAccountManagerTypes>, accountId: AccountRecordId, rustDisabled: Bool, appVersion: String) -> Signal<Void, NoError> {
    let build = networkEngineStateBuild(appVersion: appVersion)
    return accountManager.transaction { transaction -> Void in
        let accountIds = networkEngineLiveAccountIds(records: transaction.getRecords())
        let _ = updateNetworkEngineState(transaction: transaction, { state in
            return state.withServerFlag(accountId: accountId.int64, rustDisabled: rustDisabled, build: build, timestamp: Int32(Date().timeIntervalSince1970), accountIds: accountIds)
        })
    }
}

/// The app's crash marker says a run died on a Rust engine thread or queue, including the bridge
/// callbacks that run there (`rustEngineOwnsThread(named:)`, `rustEngineOwnsQueue(label:)`; the engine
/// aborts on a panic). Two such crashes of a build within 24 h turn the engine off on this device for
/// 24 h. Call it, and wait for it, before the accounts start, so this launch already resolves
/// MtProtoKit. `appVersion` is `NetworkInitializationArguments.appVersion`; `crashedBundleVersion` is
/// the crashed run's `CFBundleVersion` (recorded with the marker): a crash of another build than this
/// one is ignored. Returns whether the engine is now off locally for this build.
public func recordRustEngineCrash(accountManager: AccountManager<TelegramAccountManagerTypes>, appVersion: String, crashedBundleVersion: String, timestamp: Int32) -> Signal<Bool, NoError> {
    let build = networkEngineStateBuild(appVersion: appVersion)
    let crashedBuild = networkEngineStateBuild(appVersion: appVersion, bundleVersion: crashedBundleVersion)
    return accountManager.transaction { transaction -> Bool in
        let state = updateNetworkEngineState(transaction: transaction, { state in
            if crashedBuild != build {
                return state
            }
            return state.withEngineCrash(build: build, timestamp: timestamp)
        })
        let disabled = state.locallyDisabledRust(build: build, timestamp: timestamp)
        Logger.shared.log("Network", "Rust engine crash of \(crashedBuild) at \(timestamp)\(crashedBuild == build ? "" : " ignored, this is \(build)"): engine \(disabled ? "off" : "still on") locally")
        return disabled
    }
}
