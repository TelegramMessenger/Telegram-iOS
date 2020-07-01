import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import SyncCore

public enum ServerProvidedSuggestion: String {
    case autoarchivePopular = "AUTOARCHIVE_POPULAR"
}

public func getServerProvidedSuggestions(postbox: Postbox) -> Signal<[ServerProvidedSuggestion], NoError> {
    let key: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.appConfiguration]))
    return postbox.combinedView(keys: [key])
    |> map { views -> [ServerProvidedSuggestion] in
        guard let view = views.views[key] as? PreferencesView else {
            return []
        }
        guard let appConfiguration = view.values[PreferencesKeys.appConfiguration] as? AppConfiguration else {
            return []
        }
        guard let data = appConfiguration.data, let list = data["pending_suggestions"] as? [String] else {
            return []
        }
        return list.compactMap { item -> ServerProvidedSuggestion? in
            switch item {
            case "AUTOARCHIVE_POPULAR":
                return .autoarchivePopular
            default:
                return nil
            }
        }
    }
    |> distinctUntilChanged
}

public func dismissServerProvidedSuggestion(account: Account, suggestion: ServerProvidedSuggestion) -> Signal<Never, NoError> {
    return account.network.request(Api.functions.help.dismissSuggestion(suggestion: suggestion.rawValue))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> ignoreValues
}
