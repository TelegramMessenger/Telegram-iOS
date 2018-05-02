import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func currentlySuggestedLocalization(network: Network, extractKeys: [String]) -> Signal<SuggestedLocalizationInfo?, NoError> {
    return network.request(Api.functions.help.getConfig())
        |> retryRequest
        |> mapToSignal { result -> Signal<SuggestedLocalizationInfo?, NoError> in
            switch result {
                case let .config(config):
                    if let suggestedLangCode = config.suggestedLangCode {
                        return suggestedLocalizationInfo(network: network, languageCode: suggestedLangCode, extractKeys: extractKeys) |> map { Optional($0) }
                    } else {
                        return .single(nil)
                    }
            }
        }
}

public func suggestedLocalizationInfo(network: Network, languageCode: String, extractKeys: [String]) -> Signal<SuggestedLocalizationInfo, NoError> {
    return combineLatest(network.request(Api.functions.langpack.getLanguages()), network.request(Api.functions.langpack.getStrings(langCode: languageCode, keys: extractKeys)))
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
            var infos: [LocalizationInfo] = []
            for language in languages {
                switch language {
                    case let .langPackLanguage(name, nativeName, langCode):
                        infos.append(LocalizationInfo(languageCode: langCode, title: name, localizedTitle: nativeName))
                }
            }
            return SuggestedLocalizationInfo(languageCode: languageCode, extractedEntries: entries, availableLocalizations: infos)
        }
}

final class CachedLocalizationInfos: PostboxCoding {
    let list: [LocalizationInfo]
    
    init(list: [LocalizationInfo]) {
        self.list = list
    }
    
    init(decoder: PostboxDecoder) {
        self.list = decoder.decodeObjectArrayWithDecoderForKey("l")
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.list, forKey: "l")
    }
}

public func availableLocalizations(postbox: Postbox, network: Network, allowCached: Bool) -> Signal<[LocalizationInfo], NoError> {
    let cached: Signal<[LocalizationInfo], NoError>
    if allowCached {
        cached = postbox.modify { modifier -> Signal<[LocalizationInfo], NoError> in
            if let entry = modifier.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedAvailableLocalizations, key: ValueBoxKey(length: 0))) as? CachedLocalizationInfos {
                return .single(entry.list)
            }
            return .complete()
        } |> switchToLatest
    } else {
        cached = .complete()
    }
    let remote = network.request(Api.functions.langpack.getLanguages())
        |> retryRequest
        |> mapToSignal { languages -> Signal<[LocalizationInfo], NoError> in
            var infos: [LocalizationInfo] = []
            for language in languages {
                switch language {
                    case let .langPackLanguage(name, nativeName, langCode):
                        infos.append(LocalizationInfo(languageCode: langCode, title: name, localizedTitle: nativeName))
                }
            }
            return postbox.modify { modifier -> [LocalizationInfo] in
                modifier.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedAvailableLocalizations, key: ValueBoxKey(length: 0)), entry: CachedLocalizationInfos(list: infos), collectionSpec: ItemCacheCollectionSpec(lowWaterItemCount: 1, highWaterItemCount: 1))
                return infos
            }
        }
    
    return cached |> then(remote)
}

public func downloadLocalization(network: Network, languageCode: String) -> Signal<Localization, NoError> {
    return network.request(Api.functions.langpack.getLangPack(langCode: languageCode))
        |> retryRequest
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

public func downoadAndApplyLocalization(postbox: Postbox, network: Network, languageCode: String) -> Signal<Void, NoError> {
    return downloadLocalization(network: network, languageCode: languageCode)
        |> mapToSignal { language -> Signal<Void, NoError> in
            return postbox.modify { modifier -> Signal<Void, NoError> in
                modifier.updatePreferencesEntry(key: PreferencesKeys.localizationSettings, { _ in
                    return LocalizationSettings(languageCode: languageCode, localization: language)
                })
                
                network.context.updateApiEnvironment { current in
                    return current?.withUpdatedLangPackCode(languageCode)
                }
                
                return network.request(Api.functions.help.test())
                    |> `catch` { _ -> Signal<Api.Bool, NoError> in
                        return .complete()
                    }
                    |> mapToSignal { _ -> Signal<Void, NoError> in
                        return .complete()
                    }
            } |> switchToLatest
        }
}
