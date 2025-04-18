import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


func _internal_updateAccountPeerName(account: Account, firstName: String, lastName: String) -> Signal<Void, NoError> {
    let accountPeerId = account.peerId
    return account.network.request(Api.functions.account.updateProfile(flags: (1 << 0) | (1 << 1), firstName: firstName, lastName: lastName, about: nil))
        |> map { result -> Api.User? in
            return result
        }
        |> `catch` { _ in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Void, NoError> in
            return account.postbox.transaction { transaction -> Void in
                if let result = result {
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(transaction: transaction, chats: [], users: [result]))
                }
            }
        }
}

public enum UpdateAboutError {
    case generic
}


func _internal_updateAbout(account: Account, about: String?) -> Signal<Void, UpdateAboutError> {
    return account.network.request(Api.functions.account.updateProfile(flags: about == nil ? 0 : (1 << 2), firstName: nil, lastName: nil, about: about))
    |> mapError { _ -> UpdateAboutError in
        return .generic
    }
    |> mapToSignal { apiUser -> Signal<Void, UpdateAboutError> in
        return account.postbox.transaction { transaction -> Void in
            transaction.updatePeerCachedData(peerIds: Set([account.peerId]), update: { _, current in
                if let current = current as? CachedUserData {
                    return current.withUpdatedAbout(about)
                } else {
                    return current
                }
            })
        }
        |> castError(UpdateAboutError.self)
    }
}

public enum UpdateNameColorAndEmojiError {
    case generic
}

func _internal_updateNameColorAndEmoji(account: Account, nameColor: PeerNameColor, backgroundEmojiId: Int64?, profileColor: PeerNameColor?, profileBackgroundEmojiId: Int64?) -> Signal<Void, UpdateNameColorAndEmojiError> {
    return account.postbox.transaction { transaction -> Signal<Peer, NoError> in
        guard let peer = transaction.getPeer(account.peerId) as? TelegramUser else {
            return .complete()
        }
        updatePeersCustom(transaction: transaction, peers: [peer.withUpdatedNameColor(nameColor).withUpdatedBackgroundEmojiId(backgroundEmojiId).withUpdatedProfileColor(profileColor).withUpdatedProfileBackgroundEmojiId(profileBackgroundEmojiId)], update: { _, updated in
            return updated
        })
        return .single(peer)
    }
    |> switchToLatest
    |> castError(UpdateNameColorAndEmojiError.self)
    |> mapToSignal { _ -> Signal<Void, UpdateNameColorAndEmojiError> in
        let flagsReplies: Int32 = (1 << 0) | (1 << 2)
        
        var flagsProfile: Int32 = (1 << 0) | (1 << 1)
        if profileColor != nil {
            flagsProfile |= (1 << 2)
        }
        
        return combineLatest(
            account.network.request(Api.functions.account.updateColor(flags: flagsReplies, color: nameColor.rawValue, backgroundEmojiId: backgroundEmojiId ?? 0)),
            account.network.request(Api.functions.account.updateColor(flags: flagsProfile, color: profileColor?.rawValue, backgroundEmojiId: profileBackgroundEmojiId ?? 0))
        )
        |> mapError { _ -> UpdateNameColorAndEmojiError in
            return .generic
        }
        |> mapToSignal { _, _ -> Signal<Void, UpdateNameColorAndEmojiError> in
            return .complete()
        }
    }
}
