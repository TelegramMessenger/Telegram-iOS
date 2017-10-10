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
                //config flags:# date:int expires:int test_mode:Bool this_dc:int dc_options:Vector<DcOption> chat_size_max:int megagroup_size_max:int forwarded_count_max:int online_update_period_ms:int offline_blur_timeout_ms:int offline_idle_timeout_ms:int online_cloud_timeout_ms:int notify_cloud_delay_ms:int notify_default_delay_ms:int chat_big_size:int push_chat_period_ms:int push_chat_limit:int saved_gifs_limit:int edit_time_limit:int rating_e_decay:int stickers_recent_limit:int stickers_faved_limit:int channels_read_media_period:int tmp_sessions:flags.0?int pinned_dialogs_count_max:int phonecalls_enabled:flags.1?true call_receive_timeout_ms:int call_ring_timeout_ms:int call_connect_timeout_ms:int call_packet_timeout_ms:int me_url_prefix:string suggested_lang_code:flags.2?string lang_pack_version:flags.2?int disabled_features:Vector<DisabledFeature> = Config;
                case let .config(flags, _, _, _, _, _, chatSizeMax, megagroupSizeMax, forwardedCountMax, onlineUpdatePeriodMs, offlineBlurTimeoutMs, offlineIdleTimeoutMs, onlineCloudTimeoutMs, notifyCloudDelayMs, notifyDefaultDelayMs, chatBigSize, pushChatPeriodMs, pushChatLimit, savedGifsLimit, editTimeLimit, ratingEDecay, stickersRecentLimit, stickersFavedLimit, channelsReadMediaPeriod, _, pinnedDialogsCountMax, callReceiveTimeoutMs, callRingTimeoutMs, callConnectTimeoutMs, callPacketTimeoutMs, meUrlPrefix, suggestedLangCode, _, disabledFeatures):
                    if let suggestedLangCode = suggestedLangCode {
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
