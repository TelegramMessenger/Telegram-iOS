import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
import TelegramApiMac
#else
import Postbox
import SwiftSignalKit
import TelegramApi
#endif

public struct LocalizationListState: PreferencesEntry, Equatable {
    public var availableOfficialLocalizations: [LocalizationInfo]
    public var availableSavedLocalizations: [LocalizationInfo]
    
    public static var defaultSettings: LocalizationListState {
        return LocalizationListState(availableOfficialLocalizations: [], availableSavedLocalizations: [])
    }
    
    public init(availableOfficialLocalizations: [LocalizationInfo], availableSavedLocalizations: [LocalizationInfo]) {
        self.availableOfficialLocalizations = availableOfficialLocalizations
        self.availableSavedLocalizations = availableSavedLocalizations
    }
    
    public init(decoder: PostboxDecoder) {
        self.availableOfficialLocalizations = decoder.decodeObjectArrayWithDecoderForKey("availableOfficialLocalizations")
        self.availableSavedLocalizations = decoder.decodeObjectArrayWithDecoderForKey("availableSavedLocalizations")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.availableOfficialLocalizations, forKey: "availableOfficialLocalizations")
        encoder.encodeObjectArray(self.availableSavedLocalizations, forKey: "availableSavedLocalizations")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? LocalizationListState else {
            return false
        }
        
        return self == to
    }
}

public func removeSavedLocalization(transaction: Transaction, languageCode: String) {
    updateLocalizationListStateInteractively(transaction: transaction, { state in
        var state = state
        state.availableSavedLocalizations = state.availableSavedLocalizations.filter({ $0.languageCode != languageCode })
        return state
    })
}

func updateLocalizationListStateInteractively(postbox: Postbox, _ f: @escaping (LocalizationListState) -> LocalizationListState) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        updateLocalizationListStateInteractively(transaction: transaction, f)
    }
}

func updateLocalizationListStateInteractively(transaction: Transaction, _ f: @escaping (LocalizationListState) -> LocalizationListState) {
    transaction.updatePreferencesEntry(key: PreferencesKeys.localizationListState, { current in
        let previous = (current as? LocalizationListState) ?? LocalizationListState.defaultSettings
        var updated = f(previous)
        var removeOfficialIndices: [Int] = []
        var officialSet = Set<String>()
        for i in 0 ..< updated.availableOfficialLocalizations.count {
            if officialSet.contains(updated.availableOfficialLocalizations[i].languageCode) {
                removeOfficialIndices.append(i)
            } else {
                officialSet.insert(updated.availableOfficialLocalizations[i].languageCode)
            }
        }
        for i in removeOfficialIndices.reversed() {
            updated.availableOfficialLocalizations.remove(at: i)
        }
        var removeSavedIndices: [Int] = []
        var savedSet = Set<String>()
        for i in 0 ..< updated.availableSavedLocalizations.count {
            if savedSet.contains(updated.availableSavedLocalizations[i].languageCode) {
                removeSavedIndices.append(i)
            } else {
                savedSet.insert(updated.availableSavedLocalizations[i].languageCode)
            }
        }
        for i in removeSavedIndices.reversed() {
            updated.availableSavedLocalizations.remove(at: i)
        }
        return updated
    })
}

public func synchronizedLocalizationListState(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    return network.request(Api.functions.langpack.getLanguages(langPack: ""))
    |> retryRequest
    |> mapToSignal { languages -> Signal<Never, NoError> in
        let infos: [LocalizationInfo] = languages.map(LocalizationInfo.init(apiLanguage:))
        return postbox.transaction { transaction -> Void in
            updateLocalizationListStateInteractively(transaction: transaction, { current in
                var current = current
                current.availableOfficialLocalizations = infos
                return current
            })
        }
        |> ignoreValues
    }
}
