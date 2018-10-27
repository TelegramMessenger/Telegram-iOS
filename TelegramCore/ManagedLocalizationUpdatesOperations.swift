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

func managedLocalizationUpdatesOperations(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
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
                            return synchronizeLocalizationUpdates(transaction: transaction, postbox: postbox, network: network)
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

func getLocalization(_ transaction: Transaction) -> (String, Int32, [LocalizationEntry]) {
    let localizationSettings: LocalizationSettings?
    if let current = transaction.getPreferencesEntry(key: PreferencesKeys.localizationSettings) as? LocalizationSettings {
        localizationSettings = current
    } else {
        localizationSettings = nil
    }
    if let localizationSettings = localizationSettings {
        return (localizationSettings.languageCode, localizationSettings.localization.version, localizationSettings.localization.entries)
    } else {
        return ("en", 0, [])
    }
}

private func synchronizeLocalizationUpdates(transaction: Transaction, postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let currentLanguageAndVersion = postbox.transaction { transaction -> (String, Int32) in
        let (code, version, _) = getLocalization(transaction)
        return (code, version)
    }
    
    let poll = currentLanguageAndVersion
        |> mapError { _ -> SynchronizeLocalizationUpdatesError in return .done }
        |> mapToSignal { (languageCode, fromVersion) -> Signal<Void, SynchronizeLocalizationUpdatesError> in
            return network.request(Api.functions.langpack.getDifference(fromVersion: fromVersion))
                |> mapError { _ -> SynchronizeLocalizationUpdatesError in return .reset }
                |> mapToSignal { result -> Signal<Void, SynchronizeLocalizationUpdatesError> in
                    let updatedCode: String
                    let updatedVersion: Int32
                    var updatedEntries: [LocalizationEntry] = []
                    switch result {
                        case let .langPackDifference(code, _, versionValue, strings):
                            updatedCode = code
                            updatedVersion = versionValue
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
                    }
                    
                    return postbox.transaction { transaction -> Signal<Void, SynchronizeLocalizationUpdatesError> in
                        let (code, version, entries) = getLocalization(transaction)
                        
                        if code == updatedCode {
                            if fromVersion == version {
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
                                
                                transaction.setPreferencesEntry(key: PreferencesKeys.localizationSettings, value: LocalizationSettings(languageCode: updatedCode, localization: Localization(version: updatedVersion, entries: mergedEntries)))
                                
                                return .fail(.done)
                            } else {
                                return .complete()
                            }
                        } else {
                            return .fail(.reset)
                        }
                    } |> mapError { _ -> SynchronizeLocalizationUpdatesError in return .reset }
                      |> switchToLatest
                }
        }
    
    return ((poll
    |> `catch` { error -> Signal<Void, Void> in
        switch error {
            case .done:
                return .fail(Void())
            case .reset:
                return postbox.transaction { transaction -> Signal<Void, Void> in
                    let (code, _, _) = getLocalization(transaction)
                    return downoadAndApplyLocalization(postbox: postbox, network: network, languageCode: code)
                    |> mapError { _ -> Void in
                        return Void()
                    }
                }
                |> introduceError(Void.self)
                |> switchToLatest
        }
    }) |> restart) |> `catch` { _ -> Signal<Void, NoError> in
        return .complete()
    }
}

func tryApplyingLanguageDifference(transaction: Transaction, difference: Api.LangPackDifference) -> Bool {
    let (code, version, entries) = getLocalization(transaction)
    switch difference {
        case let .langPackDifference(updatedCode, fromVersion, updatedVersion, strings):
            if fromVersion == version && updatedCode == code {
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
                
                transaction.setPreferencesEntry(key: PreferencesKeys.localizationSettings, value: LocalizationSettings(languageCode: updatedCode, localization: Localization(version: updatedVersion, entries: mergedEntries)))
                
                return true
            } else {
                return false
            }
    }
}
