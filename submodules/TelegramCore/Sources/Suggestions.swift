import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

public enum ServerProvidedSuggestion: String {
    case autoarchivePopular = "AUTOARCHIVE_POPULAR"
    case newcomerTicks = "NEWCOMER_TICKS"
    case validatePhoneNumber = "VALIDATE_PHONE_NUMBER"
    case validatePassword = "VALIDATE_PASSWORD"
}

private var dismissedSuggestionsPromise = ValuePromise<[AccountRecordId: Set<ServerProvidedSuggestion>]>([:])
private var dismissedSuggestions: [AccountRecordId: Set<ServerProvidedSuggestion>] = [:] {
    didSet {
        dismissedSuggestionsPromise.set(dismissedSuggestions)
    }
}

public func getServerProvidedSuggestions(account: Account) -> Signal<[ServerProvidedSuggestion], NoError> {
    let key: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.appConfiguration]))
    return combineLatest(account.postbox.combinedView(keys: [key]), dismissedSuggestionsPromise.get())
    |> map { views, dismissedSuggestionsValue -> [ServerProvidedSuggestion] in
        let dismissedSuggestions = dismissedSuggestionsValue[account.id] ?? Set()
        guard let view = views.views[key] as? PreferencesView else {
            return []
        }
        guard let appConfiguration = view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) else {
            return []
        }
        guard let data = appConfiguration.data, let list = data["pending_suggestions"] as? [String] else {
            return []
        }
        return list.compactMap { item -> ServerProvidedSuggestion? in
            return ServerProvidedSuggestion(rawValue: item)
        }.filter { !dismissedSuggestions.contains($0) }
    }
    |> distinctUntilChanged
}

public func dismissServerProvidedSuggestion(account: Account, suggestion: ServerProvidedSuggestion) -> Signal<Never, NoError> {
    if let _ = dismissedSuggestions[account.id] {
        dismissedSuggestions[account.id]?.insert(suggestion)
    } else {
        dismissedSuggestions[account.id] = Set([suggestion])
    }
    return account.network.request(Api.functions.help.dismissSuggestion(peer: .inputPeerEmpty, suggestion: suggestion.rawValue))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> ignoreValues
}


public enum PeerSpecificServerProvidedSuggestion: String {
    case convertToGigagroup = "CONVERT_GIGAGROUP"
}

public func getPeerSpecificServerProvidedSuggestions(postbox: Postbox, peerId: PeerId) -> Signal<[PeerSpecificServerProvidedSuggestion], NoError> {
    return postbox.peerView(id: peerId)
    |> map { view in
        if let cachedData = view.cachedData as? CachedChannelData {
            return cachedData.pendingSuggestions.compactMap { item -> PeerSpecificServerProvidedSuggestion? in
                return PeerSpecificServerProvidedSuggestion(rawValue: item)
            }
        }
        return []
    }
    |> distinctUntilChanged
}

public func dismissPeerSpecificServerProvidedSuggestion(account: Account, peerId: PeerId, suggestion: PeerSpecificServerProvidedSuggestion) -> Signal<Never, NoError> {
    return account.postbox.loadedPeerWithId(peerId)
    |> mapToSignal { peer -> Signal<Never, NoError> in
        guard let inputPeer = apiInputPeer(peer) else {
            return .never()
        }
        return account.network.request(Api.functions.help.dismissSuggestion(peer: inputPeer, suggestion: suggestion.rawValue))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> mapToSignal { a -> Signal<Never, NoError> in
            return account.postbox.transaction { transaction in
                transaction.updatePeerCachedData(peerIds: [peerId]) { (_, current) -> CachedPeerData? in
                    var updated = current
                    if let cachedData = current as? CachedChannelData {
                        var pendingSuggestions = cachedData.pendingSuggestions
                        pendingSuggestions.removeAll(where: { $0 == suggestion.rawValue })
                        updated = cachedData.withUpdatedPendingSuggestions(pendingSuggestions)
                    }
                    return updated
                }
            } |> ignoreValues
        }
    }
}
