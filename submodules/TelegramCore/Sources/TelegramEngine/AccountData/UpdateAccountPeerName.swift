import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit


public enum UpdateAccountProfileError {
    case generic
}

private final class AccountProfileRequestDependencyTag: NetworkRequestDependencyTag {
    func shouldDependOn(other: NetworkRequestDependencyTag) -> Bool {
        return other is AccountProfileRequestDependencyTag
    }
}

func _internal_updateAccountProfile(account: Account, firstName: String?, lastName: String?, about: String?) -> Signal<Void, UpdateAccountProfileError> {
    var flags: Int32 = 0
    if firstName != nil { flags |= 1 << 0 }
    if lastName != nil { flags |= 1 << 1 }
    if about != nil { flags |= 1 << 2 }
    guard flags != 0 else { return .single(()) }
    let accountPeerId = account.peerId
    let postbox = account.postbox
    return account.network.request(Api.functions.account.updateProfile(flags: flags, firstName: firstName, lastName: lastName, about: about), tag: AccountProfileRequestDependencyTag())
    |> mapError { _ -> UpdateAccountProfileError in .generic }
    |> then(.fail(.generic))
    |> take(1)
    |> mapToSignal { result -> Signal<Void, UpdateAccountProfileError> in
        guard case .user = result, result.peerId == accountPeerId else { return .fail(.generic) }
        return postbox.transaction { transaction -> Void in
            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(transaction: transaction, chats: [], users: [result]))
            if let about {
                transaction.updatePeerCachedData(peerIds: Set([accountPeerId]), update: { _, current in
                    return ((current as? CachedUserData) ?? CachedUserData()).withUpdatedAbout(about)
                })
            }
        }
        |> castError(UpdateAccountProfileError.self)
    }
}

func _internal_updateAccountPeerName(account: Account, firstName: String, lastName: String) -> Signal<Void, NoError> {
    return _internal_updateAccountProfile(account: account, firstName: firstName, lastName: lastName, about: nil)
    |> `catch` { _ -> Signal<Void, NoError> in .single(()) }
}

public enum UpdateAboutError {
    case generic
}

func _internal_updateAbout(account: Account, about: String?) -> Signal<Void, UpdateAboutError> {
    return _internal_updateAccountProfile(account: account, firstName: nil, lastName: nil, about: about)
    |> mapError { _ -> UpdateAboutError in .generic }
}

public enum UpdateNameColor {
    case preset(color: PeerNameColor, backgroundEmojiId: Int64?)
    case collectible(PeerCollectibleColor)
}

public enum UpdateNameColorAndEmojiError {
    case generic
}

private final class AccountPeerColorRequestDependencyTag: NetworkRequestDependencyTag {
    private let forProfile: Bool

    init(forProfile: Bool) {
        self.forProfile = forProfile
    }

    func shouldDependOn(other: NetworkRequestDependencyTag) -> Bool {
        guard let other = other as? AccountPeerColorRequestDependencyTag else { return false }
        return self.forProfile == other.forProfile
    }
}

private func _internal_applyAccountPeerColor(postbox: Postbox, network: Network, peerId: PeerId, forProfile: Bool, color: Api.PeerColor, update: @escaping (TelegramUser) -> TelegramUser) -> Signal<Bool, NoError> {
    var flags: Int32 = 1 << 2
    if forProfile {
        flags |= 1 << 1
    }
    return network.request(Api.functions.account.updateColor(flags: flags, color: color), tag: AccountPeerColorRequestDependencyTag(forProfile: forProfile))
    |> map { result -> Bool in
        if case .boolTrue = result { return true }
        return false
    }
    |> `catch` { _ in .single(false) }
    |> then(.single(false))
    |> take(1)
    |> mapToSignal { accepted -> Signal<Bool, NoError> in
        guard accepted else { return .single(false) }
        return postbox.transaction { transaction -> Bool in
            if let peer = transaction.getPeer(peerId) as? TelegramUser {
                updatePeersCustom(transaction: transaction, peers: [update(peer)], update: { _, updated in updated })
            }
            return true
        }
    }
}

func _internal_updateNameColorAndEmoji(account: Account, nameColor: UpdateNameColor, profileColor: PeerNameColor?, profileBackgroundEmojiId: Int64?) -> Signal<Void, UpdateNameColorAndEmojiError> {
    let peerId = account.peerId
    let postbox = account.postbox
    let network = account.network
    let inputRepliesColor: Api.PeerColor
    let nameColorValue: PeerColor
    let backgroundEmojiIdValue: Int64?
    switch nameColor {
    case let .preset(color, backgroundEmojiId):
        var flags: Int32 = 1 << 0
        if backgroundEmojiId != nil {
            flags |= 1 << 1
        }
        inputRepliesColor = .peerColor(.init(flags: flags, color: color.rawValue, backgroundEmojiId: backgroundEmojiId))
        nameColorValue = .preset(color)
        backgroundEmojiIdValue = backgroundEmojiId
    case let .collectible(color):
        inputRepliesColor = .inputPeerColorCollectible(.init(collectibleId: color.collectibleId))
        nameColorValue = .collectible(color)
        backgroundEmojiIdValue = color.backgroundEmojiId
    }
    var flagsProfile: Int32 = 0
    if profileColor != nil {
        flagsProfile |= 1 << 0
    }
    if profileBackgroundEmojiId != nil {
        flagsProfile |= 1 << 1
    }
    let inputProfileColor = Api.PeerColor.peerColor(.init(flags: flagsProfile, color: profileColor?.rawValue, backgroundEmojiId: profileBackgroundEmojiId))
    return postbox.transaction { transaction -> Bool in
        return transaction.getPeer(peerId) is TelegramUser
    }
    |> castError(UpdateNameColorAndEmojiError.self)
    |> mapToSignal { hasPeer -> Signal<Void, UpdateNameColorAndEmojiError> in
        guard hasPeer else { return .fail(.generic) }
        let replies = _internal_applyAccountPeerColor(postbox: postbox, network: network, peerId: peerId, forProfile: false, color: inputRepliesColor, update: { peer in
            return peer.withUpdatedNameColor(nameColorValue).withUpdatedBackgroundEmojiId(backgroundEmojiIdValue)
        })
        let profile = _internal_applyAccountPeerColor(postbox: postbox, network: network, peerId: peerId, forProfile: true, color: inputProfileColor, update: { peer in
            return peer.withUpdatedProfileColor(profileColor).withUpdatedProfileBackgroundEmojiId(profileBackgroundEmojiId)
        })
        return combineLatest(replies, profile)
        |> castError(UpdateNameColorAndEmojiError.self)
        |> mapToSignal { repliesAccepted, profileAccepted -> Signal<Void, UpdateNameColorAndEmojiError> in
            guard repliesAccepted && profileAccepted else { return .fail(.generic) }
            return .complete()
        }
    }
}
