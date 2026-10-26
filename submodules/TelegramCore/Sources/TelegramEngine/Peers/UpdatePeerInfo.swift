import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit


public enum UpdatePeerTitleError {
    case generic
}

func _internal_updatePeerTitle(account: Account, peerId: PeerId, title: String) -> Signal<Void, UpdatePeerTitleError> {
    let accountPeerId = account.peerId
    return account.postbox.transaction { transaction -> Signal<Void, UpdatePeerTitleError> in
        if let peer = transaction.getPeer(peerId) {
            if (peer is TelegramChannel || peer is TelegramCommunity), let inputChannel = apiInputChannel(peer) {
                return account.network.request(Api.functions.channels.editTitle(channel: inputChannel, title: title))
                    |> mapError { _ -> UpdatePeerTitleError in
                        return .generic
                    }
                    |> mapToSignal { result -> Signal<Void, UpdatePeerTitleError> in
                        account.stateManager.addUpdates(result)
                        
                        return account.postbox.transaction { transaction -> Void in
                            if let apiChat = apiUpdatesGroups(result).first {
                                let parsedPeers = AccumulatedPeers(transaction: transaction, chats: [apiChat], users: [])
                                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                            }
                        } |> mapError { _ -> UpdatePeerTitleError in }
                    }
            } else if let peer = peer as? TelegramGroup {
                return account.network.request(Api.functions.messages.editChatTitle(chatId: peer.id.id._internalGetInt64Value(), title: title))
                    |> mapError { _ -> UpdatePeerTitleError in
                        return .generic
                    }
                    |> mapToSignal { result -> Signal<Void, UpdatePeerTitleError> in
                        account.stateManager.addUpdates(result)
                        
                        return account.postbox.transaction { transaction -> Void in
                            if let apiChat = apiUpdatesGroups(result).first {
                                let parsedPeers = AccumulatedPeers(transaction: transaction, chats: [apiChat], users: [])
                                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                            }
                        } |> mapError { _ -> UpdatePeerTitleError in }
                    }
            } else {
                return .fail(.generic)
            }
        } else {
            return .fail(.generic)
        }
    } |> mapError { _ -> UpdatePeerTitleError in } |> switchToLatest
}

public enum UpdatePeerDescriptionError {
    case generic
}

func _internal_updatePeerDescription(account: Account, peerId: PeerId, description: String?) -> Signal<Void, UpdatePeerDescriptionError> {
    return account.postbox.transaction { transaction -> Signal<Void, UpdatePeerDescriptionError> in
        if let peer = transaction.getPeer(peerId) {
            if (peer is TelegramChannel || peer is TelegramGroup), let inputPeer = apiInputPeer(peer) {
                return account.network.request(Api.functions.messages.editChatAbout(peer: inputPeer, about: description ?? ""))
                |> mapError { _ -> UpdatePeerDescriptionError in
                    return .generic
                }
                |> mapToSignal { result -> Signal<Void, UpdatePeerDescriptionError> in
                    return account.postbox.transaction { transaction -> Void in
                        if case .boolTrue = result {
                            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                if let current = current as? CachedChannelData {
                                    return current.withUpdatedAbout(description)
                                } else if let current = current as? CachedGroupData {
                                    return current.withUpdatedAbout(description)
                                } else {
                                    return current
                                }
                            })
                        }
                    }
                    |> mapError { _ -> UpdatePeerDescriptionError in }
                }
            } else {
                return .fail(.generic)
            }
        } else {
            return .fail(.generic)
        }
    } |> mapError { _ -> UpdatePeerDescriptionError in } |> switchToLatest
}

public enum UpdatePeerNameColorAndEmojiError {
    case generic
    case channelBoostRequired
}

private final class PeerColorRequestDependencyTag: NetworkRequestDependencyTag {
    private let peerId: PeerId
    private let forProfile: Bool

    init(peerId: PeerId, forProfile: Bool) {
        self.peerId = peerId
        self.forProfile = forProfile
    }

    func shouldDependOn(other: NetworkRequestDependencyTag) -> Bool {
        guard let other = other as? PeerColorRequestDependencyTag else { return false }
        return self.peerId == other.peerId && self.forProfile == other.forProfile
    }
}

private func _internal_applyPeerColor(account: Account, peerId: PeerId, forProfile: Bool, color: PeerNameColor?, backgroundEmojiId: Int64?) -> Signal<Void, UpdatePeerNameColorAndEmojiError> {
    let postbox = account.postbox
    let network = account.network
    let accountPeerId = account.peerId
    return postbox.transaction { transaction -> Api.InputChannel? in
        guard let peer = transaction.getPeer(peerId) as? TelegramChannel else { return nil }
        return apiInputChannel(peer)
    }
    |> castError(UpdatePeerNameColorAndEmojiError.self)
    |> mapToSignal { [weak stateManager = account.stateManager] inputChannel -> Signal<Void, UpdatePeerNameColorAndEmojiError> in
        guard let inputChannel else { return .fail(.generic) }
        var flags: Int32 = forProfile ? (1 << 1) : 0
        if color != nil {
            flags |= 1 << 2
        }
        if backgroundEmojiId != nil {
            flags |= 1 << 0
        }
        return network.request(Api.functions.channels.updateColor(flags: flags, channel: inputChannel, color: color?.rawValue, backgroundEmojiId: backgroundEmojiId), tag: PeerColorRequestDependencyTag(peerId: peerId, forProfile: forProfile))
        |> map(Optional.init)
        |> `catch` { error -> Signal<Api.Updates?, UpdatePeerNameColorAndEmojiError> in
            if error.errorDescription == "CHAT_NOT_MODIFIED" {
                return .single(nil)
            } else if error.errorDescription.hasPrefix("BOOSTS_REQUIRED") {
                return .fail(.channelBoostRequired)
            } else {
                return .fail(.generic)
            }
        }
        |> then(.fail(.generic))
        |> take(1)
        |> mapToSignal { [weak stateManager] updates -> Signal<Void, UpdatePeerNameColorAndEmojiError> in
            guard let updates else { return .single(()) }
            return postbox.transaction { [weak stateManager] transaction -> Void in
                switch updates {
                case let .updates(data):
                    let peers = AccumulatedPeers(transaction: transaction, chats: data.chats, users: data.users)
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: peers)
                case let .updatesCombined(data):
                    let peers = AccumulatedPeers(transaction: transaction, chats: data.chats, users: data.users)
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: peers)
                default:
                    break
                }
                stateManager?.addUpdates(updates)
            }
            |> castError(UpdatePeerNameColorAndEmojiError.self)
        }
    }
}

func _internal_updatePeerNameColorAndEmoji(account: Account, peerId: EnginePeer.Id, nameColor: PeerNameColor, backgroundEmojiId: Int64?, profileColor: PeerNameColor?, profileBackgroundEmojiId: Int64?) -> Signal<Void, UpdatePeerNameColorAndEmojiError> {
    let nameResult = _internal_updatePeerNameColor(account: account, peerId: peerId, nameColor: nameColor, backgroundEmojiId: backgroundEmojiId)
    |> map { _ -> UpdatePeerNameColorAndEmojiError? in nil }
    |> `catch` { error -> Signal<UpdatePeerNameColorAndEmojiError?, NoError> in .single(error) }
    let profileResult = _internal_updatePeerProfileColor(account: account, peerId: peerId, profileColor: profileColor, profileBackgroundEmojiId: profileBackgroundEmojiId)
    |> map { _ -> UpdatePeerNameColorAndEmojiError? in nil }
    |> `catch` { error -> Signal<UpdatePeerNameColorAndEmojiError?, NoError> in .single(error) }
    return combineLatest(nameResult, profileResult)
    |> castError(UpdatePeerNameColorAndEmojiError.self)
    |> mapToSignal { nameError, profileError -> Signal<Void, UpdatePeerNameColorAndEmojiError> in
        for error in [nameError, profileError] {
            if case .channelBoostRequired? = error { return .fail(.channelBoostRequired) }
        }
        if let error = nameError ?? profileError { return .fail(error) }
        return .single(())
    }
}

func _internal_updatePeerNameColor(account: Account, peerId: EnginePeer.Id, nameColor: PeerNameColor, backgroundEmojiId: Int64?) -> Signal<Void, UpdatePeerNameColorAndEmojiError> {
    return _internal_applyPeerColor(account: account, peerId: peerId, forProfile: false, color: nameColor, backgroundEmojiId: backgroundEmojiId)
}

func _internal_updatePeerProfileColor(account: Account, peerId: EnginePeer.Id, profileColor: PeerNameColor?, profileBackgroundEmojiId: Int64?) -> Signal<Void, UpdatePeerNameColorAndEmojiError> {
    return _internal_applyPeerColor(account: account, peerId: peerId, forProfile: true, color: profileColor, backgroundEmojiId: profileBackgroundEmojiId)
}

public enum UpdatePeerEmojiStatusError {
    case generic
}

private final class PeerEmojiStatusRequestDependencyTag: NetworkRequestDependencyTag {
    let peerId: PeerId

    init(peerId: PeerId) {
        self.peerId = peerId
    }

    func shouldDependOn(other: NetworkRequestDependencyTag) -> Bool {
        guard let other = other as? PeerEmojiStatusRequestDependencyTag else { return false }
        return self.peerId == other.peerId
    }
}

private func _internal_applyPeerEmojiStatus(account: Account, peerId: PeerId, apiEmojiStatus: Api.EmojiStatus, emojiStatus: PeerEmojiStatus?, files: [TelegramMediaFile]) -> Signal<Never, UpdatePeerEmojiStatusError> {
    let postbox = account.postbox
    let network = account.network
    return postbox.transaction { transaction -> Api.InputChannel? in
        return transaction.getPeer(peerId).flatMap(apiInputChannel)
    }
    |> castError(UpdatePeerEmojiStatusError.self)
    |> mapToSignal { [weak stateManager = account.stateManager] inputChannel -> Signal<Never, UpdatePeerEmojiStatusError> in
        guard let inputChannel else {
            return .fail(.generic)
        }
        return network.request(Api.functions.channels.updateEmojiStatus(channel: inputChannel, emojiStatus: apiEmojiStatus), tag: PeerEmojiStatusRequestDependencyTag(peerId: peerId))
        |> map(Optional.init)
        |> `catch` { error -> Signal<Api.Updates?, UpdatePeerEmojiStatusError> in
            if error.errorDescription == "CHAT_NOT_MODIFIED" {
                return .single(nil)
            } else {
                return .fail(.generic)
            }
        }
        |> then(.fail(.generic))
        |> take(1)
        |> mapToSignal { [weak stateManager] updates -> Signal<Never, UpdatePeerEmojiStatusError> in
            return postbox.transaction { [weak stateManager] transaction -> Void in
                for file in files {
                    transaction.storeMediaIfNotPresent(media: file)
                }
                if let peer = transaction.getPeer(peerId) as? TelegramChannel {
                    updatePeersCustom(transaction: transaction, peers: [peer.withUpdatedEmojiStatus(emojiStatus)], update: { _, updated in updated })
                }
                if let updates {
                    stateManager?.addUpdates(updates)
                }
            }
            |> castError(UpdatePeerEmojiStatusError.self)
            |> ignoreValues
        }
    }
}

func _internal_updatePeerEmojiStatus(account: Account, peerId: PeerId, fileId: Int64?, expirationDate: Int32?) -> Signal<Never, UpdatePeerEmojiStatusError> {
    let mappedStatus: Api.EmojiStatus
    let emojiStatus: PeerEmojiStatus?
    if let fileId {
        let flags: Int32 = expirationDate == nil ? 0 : 1
        mappedStatus = .emojiStatus(.init(flags: flags, documentId: fileId, until: expirationDate))
        emojiStatus = PeerEmojiStatus(content: .emoji(fileId: fileId), expirationDate: expirationDate)
    } else {
        mappedStatus = .emojiStatusEmpty
        emojiStatus = nil
    }
    return _internal_applyPeerEmojiStatus(account: account, peerId: peerId, apiEmojiStatus: mappedStatus, emojiStatus: emojiStatus, files: [])
}

func _internal_updatePeerStarGiftStatus(account: Account, peerId: PeerId, starGift: StarGift.UniqueGift, expirationDate: Int32?) -> Signal<Never, UpdatePeerEmojiStatusError> {
    var flags: Int32 = 0
    if let _ = expirationDate {
        flags |= (1 << 0)
    }
    var file: TelegramMediaFile?
    var patternFile: TelegramMediaFile?
    var innerColor: Int32?
    var outerColor: Int32?
    var patternColor: Int32?
    var textColor: Int32?
    for attribute in starGift.attributes {
        switch attribute {
        case let .model(_, fileValue, _, _):
            file = fileValue
        case let .pattern(_, patternFileValue, _):
            patternFile = patternFileValue
        case let .backdrop(_, _, innerColorValue, outerColorValue, patternColorValue, textColorValue, _):
            innerColor = innerColorValue
            outerColor = outerColorValue
            patternColor = patternColorValue
            textColor = textColorValue
        default:
            break
        }
    }
    guard let file, let patternFile, let innerColor, let outerColor, let patternColor, let textColor else {
        return .fail(.generic)
    }
    let apiEmojiStatus = Api.EmojiStatus.inputEmojiStatusCollectible(.init(flags: flags, collectibleId: starGift.id, until: expirationDate))
    let emojiStatus = PeerEmojiStatus(content: .starGift(id: starGift.id, fileId: file.fileId.id, title: starGift.title, slug: starGift.slug, patternFileId: patternFile.fileId.id, innerColor: innerColor, outerColor: outerColor, patternColor: patternColor, textColor: textColor), expirationDate: expirationDate)
    return _internal_applyPeerEmojiStatus(account: account, peerId: peerId, apiEmojiStatus: apiEmojiStatus, emojiStatus: emojiStatus, files: [file, patternFile])
}
