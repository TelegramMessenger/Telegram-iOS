import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

public enum ServerProvidedSuggestion: Equatable {
    case autoarchivePopular
    case newcomerTicks
    case validatePhoneNumber
    case validatePassword
    case setupPassword
    case upgradePremium
    case annualPremium
    case restorePremium
    case xmasPremiumGift
    case setupBirthday
    case todayBirthdays
    case gracePremium
    case starsSubscriptionLowBalance
    case setupPhoto
    case link(id: String, url: String, title: ServerSuggestionInfo.Item.Text, subtitle: ServerSuggestionInfo.Item.Text)
    
    init?(string: String) {
        switch string {
        case "AUTOARCHIVE_POPULAR":
            self = .autoarchivePopular
        case "NEWCOMER_TICKS":
            self = .newcomerTicks
        case "VALIDATE_PHONE_NUMBER":
            self = .validatePhoneNumber
        case "VALIDATE_PASSWORD":
            self = .validatePassword
        case "SETUP_PASSWORD":
            self = .setupPassword
        case "PREMIUM_UPGRADE":
            self = .upgradePremium
        case "PREMIUM_ANNUAL":
            self = .annualPremium
        case "PREMIUM_RESTORE":
            self = .restorePremium
        case "PREMIUM_CHRISTMAS":
            self = .xmasPremiumGift
        case "BIRTHDAY_SETUP":
            self = .setupBirthday
        case "BIRTHDAY_CONTACTS_TODAY":
            self = .todayBirthdays
        case "PREMIUM_GRACE":
            self = .gracePremium
        case "STARS_SUBSCRIPTION_LOW_BALANCE":
            self = .starsSubscriptionLowBalance
        case "USERPIC_SETUP":
            self = .setupPhoto
        default:
            return nil
        }
    }

    public var id: String {
        switch self {
        case .autoarchivePopular:
            return "AUTOARCHIVE_POPULAR"
        case .newcomerTicks:
            return "NEWCOMER_TICKS"
        case .validatePhoneNumber:
            return "VALIDATE_PHONE_NUMBER"
        case .validatePassword:
            return "VALIDATE_PASSWORD"
        case .setupPassword:
            return "SETUP_PASSWORD"
        case .upgradePremium:
            return "PREMIUM_UPGRADE"
        case .annualPremium:
            return "PREMIUM_ANNUAL"
        case .restorePremium:
            return "PREMIUM_RESTORE"
        case .xmasPremiumGift:
            return "PREMIUM_CHRISTMAS"
        case .setupBirthday:
            return "BIRTHDAY_SETUP"
        case .todayBirthdays:
            return "BIRTHDAY_CONTACTS_TODAY"
        case .gracePremium:
            return "PREMIUM_GRACE"
        case .starsSubscriptionLowBalance:
            return "STARS_SUBSCRIPTION_LOW_BALANCE"
        case .setupPhoto:
            return "USERPIC_SETUP"
        case let .link(id, _, _, _):
            return id
        }
    }
}

private var dismissedSuggestionsPromise = ValuePromise<[AccountRecordId: Set<String>]>([:])
private var dismissedSuggestions: [AccountRecordId: Set<String>] = [:] {
    didSet {
        dismissedSuggestionsPromise.set(dismissedSuggestions)
    }
}

func _internal_getServerProvidedSuggestions(account: Account) -> Signal<[ServerProvidedSuggestion], NoError> {
    let key: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.serverSuggestionInfo()]))
    return combineLatest(account.postbox.combinedView(keys: [key]), dismissedSuggestionsPromise.get())
    |> map { views, dismissedSuggestionsValue -> [ServerProvidedSuggestion] in
        let dismissedSuggestions = dismissedSuggestionsValue[account.id] ?? Set()
        guard let view = views.views[key] as? PreferencesView else {
            return []
        }
        guard let serverSuggestionInfo = view.values[PreferencesKeys.serverSuggestionInfo()]?.get(ServerSuggestionInfo.self) else {
            return []
        }
        
        var items: [ServerProvidedSuggestion] = []
        for item in serverSuggestionInfo.legacyItems {
            if let value = ServerProvidedSuggestion(string: item) {
                items.append(value)
            }
        }
        for item in serverSuggestionInfo.items {
            switch item.action {
            case let .link(url):
                items.append(.link(
                    id: item.id,
                    url: url,
                    title: item.title,
                    subtitle: item.text
                ))
            }
        }
        
        return items.filter({ !dismissedSuggestions.contains($0.id) })
    }
    |> distinctUntilChanged
}

func _internal_getServerDismissedSuggestions(account: Account) -> Signal<[String], NoError> {
    let key: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.serverSuggestionInfo()]))
    return combineLatest(account.postbox.combinedView(keys: [key]), dismissedSuggestionsPromise.get())
    |> map { views, dismissedSuggestionsValue -> [String] in
        let dismissedSuggestions = dismissedSuggestionsValue[account.id] ?? Set()
        guard let view = views.views[key] as? PreferencesView else {
            return []
        }
        guard let serverSuggestionInfo = view.values[PreferencesKeys.serverSuggestionInfo()]?.get(ServerSuggestionInfo.self) else {
            return []
        }
        var items: [String] = serverSuggestionInfo.dismissedIds
        items.append(contentsOf: dismissedSuggestions)
        return items
    }
    |> distinctUntilChanged
}

func _internal_dismissServerProvidedSuggestion(account: Account, suggestion: String) -> Signal<Never, NoError> {
    if let _ = dismissedSuggestions[account.id] {
        dismissedSuggestions[account.id]?.insert(suggestion)
    } else {
        dismissedSuggestions[account.id] = Set([suggestion])
    }
    return account.network.request(Api.functions.help.dismissSuggestion(peer: .inputPeerEmpty, suggestion: suggestion))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> ignoreValues
}


public enum PeerSpecificServerProvidedSuggestion: String {
    case convertToGigagroup = "CONVERT_GIGAGROUP"
}

func _internal_getPeerSpecificServerProvidedSuggestions(postbox: Postbox, peerId: PeerId) -> Signal<[PeerSpecificServerProvidedSuggestion], NoError> {
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

func _internal_dismissPeerSpecificServerProvidedSuggestion(account: Account, peerId: PeerId, suggestion: PeerSpecificServerProvidedSuggestion) -> Signal<Never, NoError> {
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
