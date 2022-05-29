import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

func _internal_removeSavedLocalization(transaction: Transaction, languageCode: String) {
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
        let previous = current?.get(LocalizationListState.self) ?? LocalizationListState.defaultSettings
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
        return PreferencesEntry(updated)
    })
}

func _internal_synchronizedLocalizationListState(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
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
