import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


private final class ManagedLocalizationUpdatesOperationsHelper {
    var operationDisposables: [Int32: Disposable] = [:]
    
    func update(_ entries: [PeerMergedOperationLogEntry]) -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)] = []
        
        var hasRunningOperationForPeerId = Set<PeerId>()
        var validMergedIndices = Set<Int32>()
        for entry in entries {
            if !hasRunningOperationForPeerId.contains(entry.peerId) {
                hasRunningOperationForPeerId.insert(entry.peerId)
                validMergedIndices.insert(entry.mergedIndex)
                
                if self.operationDisposables[entry.mergedIndex] == nil {
                    let disposable = MetaDisposable()
                    beginOperations.append((entry, disposable))
                    self.operationDisposables[entry.mergedIndex] = disposable
                }
            }
        }
        
        var removeMergedIndices: [Int32] = []
        for (mergedIndex, disposable) in self.operationDisposables {
            if !validMergedIndices.contains(mergedIndex) {
                removeMergedIndices.append(mergedIndex)
                disposeOperations.append(disposable)
            }
        }
        
        for mergedIndex in removeMergedIndices {
            self.operationDisposables.removeValue(forKey: mergedIndex)
        }
        
        return (disposeOperations, beginOperations)
    }
    
    func reset() -> [Disposable] {
        let disposables = Array(self.operationDisposables.values)
        self.operationDisposables.removeAll()
        return disposables
    }
}

private func withTakenOperation(postbox: Postbox, peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: Int32, _ f: @escaping (Transaction, PeerMergedOperationLogEntry?) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var result: PeerMergedOperationLogEntry?
        transaction.operationLogUpdateEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, { entry in
            if let entry = entry, let _ = entry.mergedIndex, entry.contents is SynchronizeLocalizationUpdatesOperation  {
                result = entry.mergedEntry!
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            } else {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            }
        })
        
        return f(transaction, result)
        } |> switchToLatest
}

func managedLocalizationUpdatesOperations(accountManager: AccountManager<TelegramAccountManagerTypes>, postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return Signal { _ in
        let tag: PeerOperationLogTag = OperationLogTags.SynchronizeLocalizationUpdates
        
        let helper = Atomic<ManagedLocalizationUpdatesOperationsHelper>(value: ManagedLocalizationUpdatesOperationsHelper())
        
        let disposable = postbox.mergedOperationLogView(tag: tag, limit: 10).start(next: { view in
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) in
                return helper.update(view.entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenOperation(postbox: postbox, peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex, { transaction, entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let _ = entry.contents as? SynchronizeLocalizationUpdatesOperation {
                            return synchronizeLocalizationUpdates(accountManager: accountManager, postbox: postbox, network: network)
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                |> then(postbox.transaction { transaction -> Void in
                    let _ = transaction.operationLogRemoveEntry(peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex)
                })
                
                disposable.set(signal.start())
            }
        })
        
        return ActionDisposable {
            let disposables = helper.with { helper -> [Disposable] in
                return helper.reset()
            }
            for disposable in disposables {
                disposable.dispose()
            }
            disposable.dispose()
        }
    }
}

private enum SynchronizeLocalizationUpdatesError {
    case done
    case reset
}

func getLocalization(_ transaction: AccountManagerModifier<TelegramAccountManagerTypes>) -> (primary: (code: String, version: Int32, entries: [LocalizationEntry]), secondary: (code: String, version: Int32, entries: [LocalizationEntry])?) {
    let localizationSettings: LocalizationSettings?
    if let current = transaction.getSharedData(SharedDataKeys.localizationSettings)?.get(LocalizationSettings.self) {
        localizationSettings = current
    } else {
        localizationSettings = nil
    }
    if let localizationSettings = localizationSettings {
        return (primary: (localizationSettings.primaryComponent.languageCode, localizationSettings.primaryComponent.localization.version, localizationSettings.primaryComponent.localization.entries), secondary: localizationSettings.secondaryComponent.flatMap({ ($0.languageCode, $0.localization.version, $0.localization.entries) }))
    } else {
        return (primary: ("en", 0, []), secondary: nil)
    }
}

private func parseLangPackDifference(_ difference: Api.LangPackDifference) -> (code: String, fromVersion: Int32, version: Int32, entries: [LocalizationEntry]) {
    switch difference {
        case let .langPackDifference(code, fromVersion, version, strings):
            var entries: [LocalizationEntry] = []
            for string in strings {
                switch string {
                    case let .langPackString(key, value):
                        entries.append(.string(key: key, value: value))
                    case let .langPackStringPluralized(_, key, zeroValue, oneValue, twoValue, fewValue, manyValue, otherValue):
                        entries.append(.pluralizedString(key: key, zero: zeroValue, one: oneValue, two: twoValue, few: fewValue, many: manyValue, other: otherValue))
                    case let .langPackStringDeleted(key):
                        entries.append(.string(key: key, value: ""))
                }
            }
            return (code, fromVersion, version, entries)
    }
}

private func synchronizeLocalizationUpdates(accountManager: AccountManager<TelegramAccountManagerTypes>, postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let currentLanguageAndVersion = accountManager.transaction { transaction -> (primary: (code: String, version: Int32), secondary: (code: String, version: Int32)?) in
        let (primary, secondary) = getLocalization(transaction)
        return ((primary.code, primary.version), secondary.flatMap({ ($0.code, $0.version) }))
    }
    
    let poll = currentLanguageAndVersion
    |> castError(SynchronizeLocalizationUpdatesError.self)
    |> mapToSignal { (primary, secondary) -> Signal<Void, SynchronizeLocalizationUpdatesError> in
        var differences: [Signal<Api.LangPackDifference, MTRpcError>] = []
        differences.append(network.request(Api.functions.langpack.getDifference(langPack: "", langCode: primary.code, fromVersion: primary.version)))
        if let secondary = secondary {
            differences.append(network.request(Api.functions.langpack.getDifference(langPack: "", langCode: secondary.code, fromVersion: secondary.version)))
        }
        
        return combineLatest(differences)
        |> mapError { _ -> SynchronizeLocalizationUpdatesError in return .reset }
        |> mapToSignal { differences -> Signal<Void, SynchronizeLocalizationUpdatesError> in
            let parsedDifferences = differences.map(parseLangPackDifference)
            return accountManager.transaction { transaction -> Signal<Void, SynchronizeLocalizationUpdatesError> in
                let (primary, secondary) = getLocalization(transaction)
                
                var currentSettings = transaction.getSharedData(SharedDataKeys.localizationSettings)?.get(LocalizationSettings.self) ?? LocalizationSettings(primaryComponent: LocalizationComponent(languageCode: "en", localizedName: "English", localization: Localization(version: 0, entries: []), customPluralizationCode: nil), secondaryComponent: nil)
                
                for difference in parsedDifferences {
                    let current: (isPrimary: Bool, entries: [LocalizationEntry])
                    if difference.code == primary.code {
                        if primary.version != difference.fromVersion {
                            return .complete()
                        }
                        current = (true, primary.entries)
                    } else if let secondary = secondary, difference.code == secondary.code {
                        if secondary.version != difference.fromVersion {
                            return .complete()
                        }
                        current = (false, secondary.entries)
                    } else {
                        return .fail(.reset)
                    }
                    
                    var updatedEntryKeys = Set<String>()
                    for entry in difference.entries {
                        updatedEntryKeys.insert(entry.key)
                    }
                    
                    var mergedEntries: [LocalizationEntry] = []
                    for entry in current.entries {
                        if !updatedEntryKeys.contains(entry.key) {
                            mergedEntries.append(entry)
                        }
                    }
                    mergedEntries.append(contentsOf: difference.entries)
                    if current.isPrimary {
                        currentSettings = LocalizationSettings(primaryComponent: LocalizationComponent(languageCode: currentSettings.primaryComponent.languageCode, localizedName: currentSettings.primaryComponent.localizedName, localization: Localization(version: difference.version, entries: mergedEntries), customPluralizationCode: currentSettings.primaryComponent.customPluralizationCode), secondaryComponent: currentSettings.secondaryComponent)
                    } else if let currentSecondary = currentSettings.secondaryComponent {
                        currentSettings = LocalizationSettings(primaryComponent: currentSettings.primaryComponent, secondaryComponent: LocalizationComponent(languageCode: currentSecondary.languageCode, localizedName: currentSecondary.localizedName, localization: Localization(version: difference.version, entries: mergedEntries), customPluralizationCode: currentSecondary.customPluralizationCode))
                    }
                }
                
                transaction.updateSharedData(SharedDataKeys.localizationSettings, { _ in
                    return PreferencesEntry(currentSettings)
                })
                return .fail(.done)
            }
            |> mapError { _ -> SynchronizeLocalizationUpdatesError in
            }
            |> switchToLatest
        }
    }
    
    return ((poll
    |> `catch` { error -> Signal<Void, Void> in
        switch error {
            case .done:
                return .fail(Void())
            case .reset:
                return accountManager.transaction { transaction -> Signal<Void, Void> in
                    let (primary, _) = getLocalization(transaction)
                    return _internal_downloadAndApplyLocalization(accountManager: accountManager, postbox: postbox, network: network, languageCode: primary.code)
                    |> mapError { _ -> Void in
                        return Void()
                    }
                }
                |> castError(Void.self)
                |> switchToLatest
        }
    }) |> restart) |> `catch` { _ -> Signal<Void, NoError> in
        return .complete()
    }
}

func tryApplyingLanguageDifference(transaction: AccountManagerModifier<TelegramAccountManagerTypes>, langCode: String, difference: Api.LangPackDifference) -> Bool {
    let (primary, secondary) = getLocalization(transaction)
    switch difference {
        case let .langPackDifference(updatedCode, fromVersion, updatedVersion, strings):
            var current: (isPrimary: Bool, version: Int32, entries: [LocalizationEntry])?
            if updatedCode == primary.code {
                current = (true, primary.version, primary.entries)
            } else if let secondary = secondary, secondary.code == updatedCode {
                current = (false, secondary.version, secondary.entries)
            }
            guard let (isPrimary, version, entries) = current else {
                return false
            }
            guard fromVersion == version else {
                return false
            }
            var updatedEntries: [LocalizationEntry] = []
            
            for string in strings {
                switch string {
                    case let .langPackString(key, value):
                        updatedEntries.append(.string(key: key, value: value))
                    case let .langPackStringPluralized(_, key, zeroValue, oneValue, twoValue, fewValue, manyValue, otherValue):
                        updatedEntries.append(.pluralizedString(key: key, zero: zeroValue, one: oneValue, two: twoValue, few: fewValue, many: manyValue, other: otherValue))
                    case let .langPackStringDeleted(key):
                        updatedEntries.append(.string(key: key, value: ""))
                }
            }
            
            var updatedEntryKeys = Set<String>()
            for entry in updatedEntries {
                updatedEntryKeys.insert(entry.key)
            }
            
            var mergedEntries: [LocalizationEntry] = []
            for entry in entries {
                if !updatedEntryKeys.contains(entry.key) {
                    mergedEntries.append(entry)
                }
            }
            mergedEntries.append(contentsOf: updatedEntries)
            
            let currentSettings = transaction.getSharedData(SharedDataKeys.localizationSettings)?.get(LocalizationSettings.self) ?? LocalizationSettings(primaryComponent: LocalizationComponent(languageCode: "en", localizedName: "English", localization: Localization(version: 0, entries: []), customPluralizationCode: nil), secondaryComponent: nil)
            
            var updatedSettings: LocalizationSettings
            if isPrimary {
                updatedSettings = LocalizationSettings(primaryComponent: LocalizationComponent(languageCode: currentSettings.primaryComponent.languageCode, localizedName: currentSettings.primaryComponent.localizedName, localization: Localization(version: updatedVersion, entries: mergedEntries), customPluralizationCode: currentSettings.primaryComponent.customPluralizationCode), secondaryComponent: currentSettings.secondaryComponent)
            } else if let currentSecondary = currentSettings.secondaryComponent {
                updatedSettings = LocalizationSettings(primaryComponent: currentSettings.primaryComponent, secondaryComponent: LocalizationComponent(languageCode: currentSecondary.languageCode, localizedName: currentSecondary.localizedName, localization: Localization(version: updatedVersion, entries: mergedEntries), customPluralizationCode: currentSecondary.customPluralizationCode))
            } else {
                assertionFailure()
                return false
            }
            
            transaction.updateSharedData(SharedDataKeys.localizationSettings, { _ in
                return PreferencesEntry(updatedSettings)
            })
            
            return true
    }
}
