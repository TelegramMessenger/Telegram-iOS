import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

/// TSupport: a note that support volunteers keep about a user, shared across all volunteers.
///
/// Fetched with `help.getUserInfo` and written with `help.editUserInfo`. Both are only
/// meaningful for support accounts, so every entry point here is gated by the caller.
///
/// This is deliberately kept out of `CachedUserData`: it is fork-local data, and storing it
/// there would change the cached-peer encoding for regular accounts as well.
public final class SupportPeerInfo: Codable, Equatable {
    public let text: String
    public let entities: [MessageTextEntity]
    /// Username of the volunteer who last edited the note, as returned by the server.
    /// This is a plain string, not a peer reference, so it cannot be resolved to a profile.
    public let author: String
    public let date: Int32

    public var isEmpty: Bool {
        return self.text.isEmpty
    }

    public init(text: String, entities: [MessageTextEntity], author: String, date: Int32) {
        self.text = text
        self.entities = entities
        self.author = author
        self.date = date
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.text = try container.decodeIfPresent(String.self, forKey: "t") ?? ""
        self.entities = try container.decodeIfPresent([MessageTextEntity].self, forKey: "e") ?? []
        self.author = try container.decodeIfPresent(String.self, forKey: "a") ?? ""
        self.date = try container.decodeIfPresent(Int32.self, forKey: "d") ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.text, forKey: "t")
        try container.encode(self.entities, forKey: "e")
        try container.encode(self.author, forKey: "a")
        try container.encode(self.date, forKey: "d")
    }

    public static func ==(lhs: SupportPeerInfo, rhs: SupportPeerInfo) -> Bool {
        return lhs.text == rhs.text && lhs.entities == rhs.entities && lhs.author == rhs.author && lhs.date == rhs.date
    }
}

private func entryId(peerId: EnginePeer.Id) -> ItemCacheEntryId {
    let cacheKey = ValueBoxKey(length: 8)
    cacheKey.setInt64(0, value: peerId.toInt64())
    return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.supportPeerInfo, key: cacheKey)
}

private func storeSupportPeerInfo(transaction: Transaction, peerId: EnginePeer.Id, result: Api.help.UserInfo) -> SupportPeerInfo? {
    let info: SupportPeerInfo
    switch result {
    case let .userInfo(data):
        info = SupportPeerInfo(text: data.message, entities: messageTextEntitiesFromApiEntities(data.entities), author: data.author, date: data.date)
    case .userInfoEmpty:
        info = SupportPeerInfo(text: "", entities: [], author: "", date: 0)
    }
    if let entry = CodableEntry(info) {
        transaction.putItemCacheEntry(id: entryId(peerId: peerId), entry: entry)
    }
    return info
}

func _internal_supportPeerInfo(postbox: Postbox, peerId: EnginePeer.Id) -> Signal<SupportPeerInfo?, NoError> {
    let key = PostboxViewKey.cachedItem(entryId(peerId: peerId))
    return postbox.combinedView(keys: [key])
    |> map { views -> SupportPeerInfo? in
        guard let info = (views.views[key] as? CachedItemView)?.value?.get(SupportPeerInfo.self), !info.isEmpty else {
            return nil
        }
        return info
    }
    |> distinctUntilChanged
}

/// Refreshes the stored note from the server. Errors are swallowed on purpose: a failed
/// fetch must not surface as "this user has no note", so the previously stored value is kept.
func _internal_fetchSupportPeerInfo(account: Account, peerId: EnginePeer.Id) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(peerId).flatMap(apiInputUser)
    }
    |> mapToSignal { inputUser -> Signal<Never, NoError> in
        guard let inputUser = inputUser else {
            return .complete()
        }
        return account.network.request(Api.functions.help.getUserInfo(userId: inputUser))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.help.UserInfo?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            guard let result = result else {
                return .complete()
            }
            return account.postbox.transaction { transaction -> Void in
                let _ = storeSupportPeerInfo(transaction: transaction, peerId: peerId, result: result)
            }
            |> ignoreValues
        }
    }
}

public enum UpdateSupportPeerInfoError {
    case generic
}

/// Writes the note and stores whatever the server echoes back, rather than the local text,
/// so any server-side normalisation of the message or entities is reflected immediately.
func _internal_updateSupportPeerInfo(account: Account, peerId: EnginePeer.Id, text: String, entities: [MessageTextEntity]) -> Signal<Never, UpdateSupportPeerInfoError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(peerId).flatMap(apiInputUser)
    }
    |> castError(UpdateSupportPeerInfoError.self)
    |> mapToSignal { inputUser -> Signal<Never, UpdateSupportPeerInfoError> in
        guard let inputUser = inputUser else {
            return .fail(.generic)
        }
        let apiEntities = apiEntitiesFromMessageTextEntities(entities, associatedPeers: SimpleDictionary())
        return account.network.request(Api.functions.help.editUserInfo(userId: inputUser, message: text, entities: apiEntities))
        |> mapError { _ -> UpdateSupportPeerInfoError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, UpdateSupportPeerInfoError> in
            return account.postbox.transaction { transaction -> Void in
                let _ = storeSupportPeerInfo(transaction: transaction, peerId: peerId, result: result)
            }
            |> castError(UpdateSupportPeerInfoError.self)
            |> ignoreValues
        }
    }
}
