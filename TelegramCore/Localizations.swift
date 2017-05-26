import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

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

public func availableLocalizations(network: Network) -> Signal<[LocalizationInfo], NoError> {
    return network.request(Api.functions.langpack.getLanguages())
        |> retryRequest
        |> map { languages -> [LocalizationInfo] in
            var infos: [LocalizationInfo] = []
            for language in languages {
                switch language {
                case let .langPackLanguage(name, nativeName, langCode):
                    infos.append(LocalizationInfo(languageCode: langCode, title: name, localizedTitle: nativeName))
                }
            }
            return infos
        }
}

public func downloadLocalization(network: Network, languageCode: String) -> Signal<Localization, NoError> {
    return network.request(Api.functions.langpack.getLangPack(langCode: languageCode))
        |> retryRequest
        |> map { result -> Localization in
            var entries: [LocalizationEntry] = []
            switch result {
                case let .langPackDifference(_, _, _, strings):
                    for string in strings {
                        switch string {
                            case let .langPackString(key, value):
                                entries.append(.string(key: key, value: value))
                            case let .langPackStringPluralized(_, key, zeroValue, oneValue, twoValue, fewValue, manyValue, otherValue):
                                entries.append(.pluralizedString(key: key, zero: zeroValue, one: oneValue, two: twoValue, few: fewValue, many: manyValue, other: otherValue))
                        }
                    }
            }
            
            return Localization(entries: entries)
        }
}

public func downoadAndApplyLocalization(postbox: Postbox, network: Network, languageCode: String) -> Signal<Void, NoError> {
    return downloadLocalization(network: network, languageCode: languageCode)
        |> mapToSignal { language -> Signal<Void, NoError> in
            return postbox.modify { modifier -> Void in
                modifier.updatePreferencesEntry(key: PreferencesKeys.localizationSettings, { _ in
                    return LocalizationSettings(languageCode: languageCode, localization: language)
                })
                
                network.context.updateApiEnvironment { current in
                    return current?.withUpdatedLangPackCode(languageCode)
                }
            }
        }
}
