import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit


func _internal_currentlySuggestedLocalization(network: Network, extractKeys: [String]) -> Signal<SuggestedLocalizationInfo?, NoError> {
    return network.request(Api.functions.help.getConfig())
        |> retryRequest
        |> mapToSignal { result -> Signal<SuggestedLocalizationInfo?, NoError> in
            switch result {
                case let .config(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, suggestedLangCode, _, _, _):
                    if let suggestedLangCode = suggestedLangCode {
                        return _internal_suggestedLocalizationInfo(network: network, languageCode: suggestedLangCode, extractKeys: extractKeys) |> map(Optional.init)
                    } else {
                        return .single(nil)
                    }
            }
        }
}

func _internal_suggestedLocalizationInfo(network: Network, languageCode: String, extractKeys: [String]) -> Signal<SuggestedLocalizationInfo, NoError> {
    return combineLatest(network.request(Api.functions.langpack.getLanguages(langPack: "")), network.request(Api.functions.langpack.getStrings(langPack: "", langCode: languageCode, keys: extractKeys)))
        |> retryRequest
        |> map { languages, strings -> SuggestedLocalizationInfo in
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
            let infos: [LocalizationInfo] = languages.map(LocalizationInfo.init(apiLanguage:))
            return SuggestedLocalizationInfo(languageCode: languageCode, extractedEntries: entries, availableLocalizations: infos)
        }
}

func _internal_availableLocalizations(postbox: Postbox, network: Network, allowCached: Bool) -> Signal<[LocalizationInfo], NoError> {
    let cached: Signal<[LocalizationInfo], NoError>
    if allowCached {
        cached = postbox.transaction { transaction -> Signal<[LocalizationInfo], NoError> in
            if let entry = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedAvailableLocalizations, key: ValueBoxKey(length: 0)))?.get(CachedLocalizationInfos.self) {
                return .single(entry.list)
            }
            return .complete()
        } |> switchToLatest
    } else {
        cached = .complete()
    }
    let remote = network.request(Api.functions.langpack.getLanguages(langPack: ""))
    |> retryRequest
    |> mapToSignal { languages -> Signal<[LocalizationInfo], NoError> in
        let infos: [LocalizationInfo] = languages.map(LocalizationInfo.init(apiLanguage:))
        return postbox.transaction { transaction -> [LocalizationInfo] in
            if let entry = CodableEntry(CachedLocalizationInfos(list: infos)) {
                transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedAvailableLocalizations, key: ValueBoxKey(length: 0)), entry: entry)
            }
            return infos
        }
    }
    
    return cached |> then(remote)
}

public enum DownloadLocalizationError {
    case generic
}

func _internal_downloadLocalization(network: Network, languageCode: String) -> Signal<Localization, DownloadLocalizationError> {
    return network.request(Api.functions.langpack.getLangPack(langPack: "", langCode: languageCode))
    |> mapError { _ -> DownloadLocalizationError in
        return .generic
    }
    |> map { result -> Localization in
        let version: Int32
        var entries: [LocalizationEntry] = []
        switch result {
            case let .langPackDifference(_, _, versionValue, strings):
                version = versionValue
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
        }
        
        return Localization(version: version, entries: entries)
    }
}

public enum DownloadAndApplyLocalizationError {
    case generic
}

func _internal_downloadAndApplyLocalization(accountManager: AccountManager<TelegramAccountManagerTypes>, postbox: Postbox, network: Network, languageCode: String) -> Signal<Void, DownloadAndApplyLocalizationError> {
    return _internal_requestLocalizationPreview(network: network, identifier: languageCode)
    |> mapError { _ -> DownloadAndApplyLocalizationError in
        return .generic
    }
    |> mapToSignal { preview -> Signal<Void, DownloadAndApplyLocalizationError> in
        var primaryAndSecondaryLocalizations: [Signal<Localization, DownloadLocalizationError>] = []
        primaryAndSecondaryLocalizations.append(_internal_downloadLocalization(network: network, languageCode: preview.languageCode))
        if let secondaryCode = preview.baseLanguageCode {
            primaryAndSecondaryLocalizations.append(_internal_downloadLocalization(network: network, languageCode: secondaryCode))
        }
        return combineLatest(primaryAndSecondaryLocalizations)
        |> mapError { _ -> DownloadAndApplyLocalizationError in
            return .generic
        }
        |> mapToSignal { components -> Signal<Void, DownloadAndApplyLocalizationError> in
            guard let primaryLocalization = components.first else {
                return .fail(.generic)
            }
            var secondaryComponent: LocalizationComponent?
            if let secondaryCode = preview.baseLanguageCode, components.count > 1 {
                secondaryComponent = LocalizationComponent(languageCode: secondaryCode, localizedName: "", localization: components[1], customPluralizationCode: nil)
            }
            return accountManager.transaction { transaction -> Signal<Void, DownloadAndApplyLocalizationError> in
                transaction.updateSharedData(SharedDataKeys.localizationSettings, { _ in
                    return PreferencesEntry(LocalizationSettings(primaryComponent: LocalizationComponent(languageCode: preview.languageCode, localizedName: preview.localizedTitle, localization: primaryLocalization, customPluralizationCode: preview.customPluralizationCode), secondaryComponent: secondaryComponent))
                })
                
                return postbox.transaction { transaction -> Signal<Void, DownloadAndApplyLocalizationError> in
                    updateLocalizationListStateInteractively(transaction: transaction, { state in
                        var state = state
                        for i in 0 ..< state.availableSavedLocalizations.count {
                            if state.availableSavedLocalizations[i].languageCode == preview.languageCode {
                                state.availableSavedLocalizations.remove(at: i)
                                break
                            }
                        }
                        state.availableSavedLocalizations.insert(preview, at: 0)
                        return state
                    })
                    
                    network.context.updateApiEnvironment { current in
                        return current?.withUpdatedLangPackCode(preview.languageCode)
                    }
                    
                    return network.request(Api.functions.help.test())
                    |> `catch` { _ -> Signal<Api.Bool, NoError> in
                        return .complete()
                    }
                    |> mapToSignal { _ -> Signal<Void, NoError> in
                        return .complete()
                    }
                    |> castError(DownloadAndApplyLocalizationError.self)
                }
                |> castError(DownloadAndApplyLocalizationError.self)
                |> switchToLatest
            }
            |> castError(DownloadAndApplyLocalizationError.self)
            |> switchToLatest
        }
    }
}
