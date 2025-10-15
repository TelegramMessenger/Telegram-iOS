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

public enum UpdateNameColor {
    case preset(color: PeerNameColor, backgroundEmojiId: Int64?)
    case collectible(PeerCollectibleColor)
}

public enum UpdateNameColorAndEmojiError {
    case generic
}

func _internal_updateNameColorAndEmoji(account: Account, nameColor: UpdateNameColor, profileColor: PeerNameColor?, profileBackgroundEmojiId: Int64?) -> Signal<Void, UpdateNameColorAndEmojiError> {
    return account.postbox.transaction { transaction -> Signal<Peer, NoError> in
        guard let peer = transaction.getPeer(account.peerId) as? TelegramUser else {
            return .complete()
        }
        var nameColorValue: PeerColor
        var backgroundEmojiIdValue: Int64?
        switch nameColor {
        case let .preset(color, backgroundEmojiId):
            nameColorValue = .preset(color)
            backgroundEmojiIdValue = backgroundEmojiId
        case let .collectible(collectibleColor):
            nameColorValue = .collectible(collectibleColor)
            backgroundEmojiIdValue = collectibleColor.backgroundEmojiId
        }
        
        updatePeersCustom(transaction: transaction, peers: [peer.withUpdatedNameColor(nameColorValue).withUpdatedBackgroundEmojiId(backgroundEmojiIdValue).withUpdatedProfileColor(profileColor).withUpdatedProfileBackgroundEmojiId(profileBackgroundEmojiId)], update: { _, updated in
            return updated
        })
        return .single(peer)
    }
    |> switchToLatest
    |> castError(UpdateNameColorAndEmojiError.self)
    |> mapToSignal { _ -> Signal<Void, UpdateNameColorAndEmojiError> in
        let inputRepliesColor: Api.PeerColor
        switch nameColor {
        case let .preset(color, backgroundEmojiId):
            var flags: Int32 = (1 << 0)
            if let _ = backgroundEmojiId {
                flags |= (1 << 1)
            }
            inputRepliesColor = .peerColor(flags: flags, color: color.rawValue, backgroundEmojiId: backgroundEmojiId)
        case let .collectible(collectibleColor):
            inputRepliesColor = .inputPeerColorCollectible(collectibleId: collectibleColor.collectibleId)
        }
        
        var flagsProfile: Int32 = 0
        if let _ = profileColor {
            flagsProfile |= (1 << 0)
        }
        if let _ = profileBackgroundEmojiId {
            flagsProfile |= (1 << 1)
        }
        
        return combineLatest(
            account.network.request(Api.functions.account.updateColor(flags: (1 << 2), color: inputRepliesColor)),
            account.network.request(Api.functions.account.updateColor(flags: (1 << 1) | (1 << 2), color: .peerColor(flags: flagsProfile, color: profileColor?.rawValue ?? 0, backgroundEmojiId: profileBackgroundEmojiId)))
        )
        |> mapError { _ -> UpdateNameColorAndEmojiError in
            return .generic
        }
        |> mapToSignal { _, _ -> Signal<Void, UpdateNameColorAndEmojiError> in
            return .complete()
        }
    }
}
