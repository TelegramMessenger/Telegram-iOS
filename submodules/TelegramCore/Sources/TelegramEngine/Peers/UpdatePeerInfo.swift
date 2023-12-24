import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public enum UpdatePeerTitleError {
    case generic
}

func _internal_updatePeerTitle(account: Account, peerId: PeerId, title: String) -> Signal<Void, UpdatePeerTitleError> {
    let accountPeerId = account.peerId
    return account.postbox.transaction { transaction -> Signal<Void, UpdatePeerTitleError> in
        if let peer = transaction.getPeer(peerId) {
            if let peer = peer as? TelegramChannel, let inputChannel = apiInputChannel(peer) {
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

func _internal_updatePeerNameColorAndEmoji(account: Account, peerId: EnginePeer.Id, nameColor: PeerNameColor, backgroundEmojiId: Int64?, profileColor: PeerNameColor?, profileBackgroundEmojiId: Int64?) -> Signal<Void, UpdatePeerNameColorAndEmojiError> {
    return account.postbox.transaction { transaction -> Signal<Void, UpdatePeerNameColorAndEmojiError> in
        if let peer = transaction.getPeer(peerId) {
            if let peer = peer as? TelegramChannel, let inputChannel = apiInputChannel(peer) {
                var flagsReplies: Int32 = (1 << 2)
                if backgroundEmojiId != nil {
                    flagsReplies |= 1 << 0
                }
                
                var flagsProfile: Int32 = (1 << 1)
                if profileBackgroundEmojiId != nil {
                    flagsProfile |= 1 << 0
                }
                if profileColor != nil {
                    flagsProfile |= (1 << 2)
                }
                
                return combineLatest(
                    account.network.request(Api.functions.channels.updateColor(flags: flagsReplies, channel: inputChannel, color: nameColor.rawValue, backgroundEmojiId: backgroundEmojiId))
                    |> map(Optional.init)
                    |> `catch` { error -> Signal<Api.Updates?, MTRpcError> in
                        if error.errorDescription.hasPrefix("CHAT_NOT_MODIFIED") {
                            return .single(nil)
                        } else {
                            return .fail(error)
                        }
                    },
                    account.network.request(Api.functions.channels.updateColor(flags: flagsProfile, channel: inputChannel, color: profileColor?.rawValue, backgroundEmojiId: profileBackgroundEmojiId))
                    |> map(Optional.init)
                    |> `catch` { error -> Signal<Api.Updates?, MTRpcError> in
                        if error.errorDescription.hasPrefix("CHAT_NOT_MODIFIED") {
                            return .single(nil)
                        } else {
                            return .fail(error)
                        }
                    }
                )
                |> mapError { error -> UpdatePeerNameColorAndEmojiError in
                    if error.errorDescription.hasPrefix("BOOSTS_REQUIRED") {
                        return .channelBoostRequired
                    }
                    return .generic
                }
                |> mapToSignal { repliesResult, profileResult -> Signal<Void, UpdatePeerNameColorAndEmojiError> in
                    if let repliesResult = repliesResult {
                        account.stateManager.addUpdates(repliesResult)
                    }
                    if let profileResult = profileResult {
                        account.stateManager.addUpdates(profileResult)
                    }
                    
                    return account.postbox.transaction { transaction -> Void in
                        if let repliesResult = repliesResult, let apiChat = apiUpdatesGroups(repliesResult).first {
                            let parsedPeers = AccumulatedPeers(transaction: transaction, chats: [apiChat], users: [])
                            updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
                        }
                        if let profileResult = profileResult, let apiChat = apiUpdatesGroups(profileResult).first {
                            let parsedPeers = AccumulatedPeers(transaction: transaction, chats: [apiChat], users: [])
                            updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
                        }
                    }
                    |> mapError { _ -> UpdatePeerNameColorAndEmojiError in }
                }
            } else {
                return .fail(.generic)
            }
        } else {
            return .fail(.generic)
        }
    } 
    |> castError(UpdatePeerNameColorAndEmojiError.self)
    |> switchToLatest
}

func _internal_updatePeerNameColor(account: Account, peerId: EnginePeer.Id, nameColor: PeerNameColor, backgroundEmojiId: Int64?) -> Signal<Void, UpdatePeerNameColorAndEmojiError> {
    return account.postbox.transaction { transaction -> Signal<Void, UpdatePeerNameColorAndEmojiError> in
        if let peer = transaction.getPeer(peerId) {
            if let peer = peer as? TelegramChannel, let inputChannel = apiInputChannel(peer) {
                var flagsReplies: Int32 = (1 << 2)
                if backgroundEmojiId != nil {
                    flagsReplies |= 1 << 0
                }
                
                return account.network.request(Api.functions.channels.updateColor(flags: flagsReplies, channel: inputChannel, color: nameColor.rawValue, backgroundEmojiId: backgroundEmojiId))
                |> map(Optional.init)
                |> `catch` { error -> Signal<Api.Updates?, MTRpcError> in
                    if error.errorDescription.hasPrefix("CHAT_NOT_MODIFIED") {
                        return .single(nil)
                    } else {
                        return .fail(error)
                    }
                }
                |> mapError { error -> UpdatePeerNameColorAndEmojiError in
                    if error.errorDescription.hasPrefix("BOOSTS_REQUIRED") {
                        return .channelBoostRequired
                    }
                    return .generic
                }
                |> mapToSignal { repliesResult -> Signal<Void, UpdatePeerNameColorAndEmojiError> in
                    if let repliesResult = repliesResult {
                        account.stateManager.addUpdates(repliesResult)
                    }
                    
                    return account.postbox.transaction { transaction -> Void in
                        if let repliesResult = repliesResult, let apiChat = apiUpdatesGroups(repliesResult).first {
                            let parsedPeers = AccumulatedPeers(transaction: transaction, chats: [apiChat], users: [])
                            updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
                        }
                    }
                    |> mapError { _ -> UpdatePeerNameColorAndEmojiError in }
                }
            } else {
                return .fail(.generic)
            }
        } else {
            return .fail(.generic)
        }
    }
    |> castError(UpdatePeerNameColorAndEmojiError.self)
    |> switchToLatest
}

func _internal_updatePeerProfileColor(account: Account, peerId: EnginePeer.Id, profileColor: PeerNameColor?, profileBackgroundEmojiId: Int64?) -> Signal<Void, UpdatePeerNameColorAndEmojiError> {
    return account.postbox.transaction { transaction -> Signal<Void, UpdatePeerNameColorAndEmojiError> in
        if let peer = transaction.getPeer(peerId) {
            if let peer = peer as? TelegramChannel, let inputChannel = apiInputChannel(peer) {
                var flagsProfile: Int32 = (1 << 1)
                if profileBackgroundEmojiId != nil {
                    flagsProfile |= 1 << 0
                }
                if profileColor != nil {
                    flagsProfile |= (1 << 2)
                }
                
                return account.network.request(Api.functions.channels.updateColor(flags: flagsProfile, channel: inputChannel, color: profileColor?.rawValue, backgroundEmojiId: profileBackgroundEmojiId))
                |> map(Optional.init)
                |> `catch` { error -> Signal<Api.Updates?, MTRpcError> in
                    if error.errorDescription.hasPrefix("CHAT_NOT_MODIFIED") {
                        return .single(nil)
                    } else {
                        return .fail(error)
                    }
                }
                |> mapError { error -> UpdatePeerNameColorAndEmojiError in
                    if error.errorDescription.hasPrefix("BOOSTS_REQUIRED") {
                        return .channelBoostRequired
                    }
                    return .generic
                }
                |> mapToSignal { profileResult -> Signal<Void, UpdatePeerNameColorAndEmojiError> in
                    if let profileResult = profileResult {
                        account.stateManager.addUpdates(profileResult)
                    }
                    
                    return account.postbox.transaction { transaction -> Void in
                        if let profileResult = profileResult, let apiChat = apiUpdatesGroups(profileResult).first {
                            let parsedPeers = AccumulatedPeers(transaction: transaction, chats: [apiChat], users: [])
                            updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
                        }
                    }
                    |> mapError { _ -> UpdatePeerNameColorAndEmojiError in }
                }
            } else {
                return .fail(.generic)
            }
        } else {
            return .fail(.generic)
        }
    }
    |> castError(UpdatePeerNameColorAndEmojiError.self)
    |> switchToLatest
}

public enum UpdatePeerEmojiStatusError {
    case generic
}

func _internal_updatePeerEmojiStatus(account: Account, peerId: PeerId, fileId: Int64?, expirationDate: Int32?) -> Signal<Never, UpdatePeerEmojiStatusError> {
    return account.postbox.transaction { transaction -> Api.InputChannel? in
        let updatedStatus = fileId.flatMap {
            PeerEmojiStatus(fileId: $0, expirationDate: expirationDate)
        }
        if let peer = transaction.getPeer(peerId) as? TelegramChannel {
            updatePeersCustom(transaction: transaction, peers: [peer.withUpdatedEmojiStatus(updatedStatus)], update: { _, updated in updated })
        }
        
        return transaction.getPeer(peerId).flatMap(apiInputChannel)
    }
    |> castError(UpdatePeerEmojiStatusError.self)
    |> mapToSignal { inputChannel -> Signal<Never, UpdatePeerEmojiStatusError> in
        guard let inputChannel = inputChannel else {
            return .fail(.generic)
        }
        let mappedStatus: Api.EmojiStatus
        if let fileId = fileId {
            if let expirationDate = expirationDate {
                mappedStatus = .emojiStatusUntil(documentId: fileId, until: expirationDate)
            } else {
                mappedStatus = .emojiStatus(documentId: fileId)
            }
        } else {
            mappedStatus = .emojiStatusEmpty
        }
        return account.network.request(Api.functions.channels.updateEmojiStatus(channel: inputChannel, emojiStatus: mappedStatus))
        |> ignoreValues
        |> `catch` { error -> Signal<Never, UpdatePeerEmojiStatusError> in
            if error.errorDescription == "CHAT_NOT_MODIFIED" {
                return .complete()
            } else {
                return .fail(.generic)
            }
        }
    }
}
