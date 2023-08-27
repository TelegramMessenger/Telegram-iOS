import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum UpdateBotInfoError {
    case generic
}

func _internal_updateBotName(account: Account, peerId: PeerId, name: String) -> Signal<Void, UpdateBotInfoError> {
    return account.postbox.transaction { transaction -> Signal<Void, UpdateBotInfoError> in
        if let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) {
            var flags: Int32 = 1 << 2
            flags |= (1 << 3)
            return account.network.request(Api.functions.bots.setBotInfo(flags: flags, bot: inputUser, langCode: "", name: name, about: nil, description: nil))
            |> mapError { _ -> UpdateBotInfoError in
                return .generic
            }
            |> mapToSignal { result -> Signal<Void, UpdateBotInfoError> in
                return account.postbox.transaction { transaction -> Void in
                    if case .boolTrue = result {
                        var previousBotName: String?
                        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                            if let current = current as? CachedUserData, let editableBotInfo = current.editableBotInfo {
                                previousBotName = editableBotInfo.name
                                return current.withUpdatedEditableBotInfo(editableBotInfo.withUpdatedName(name))
                            } else {
                                return current
                            }
                        })
                        updatePeersCustom(transaction: transaction, peers: [peer]) { _, peer in
                            var updatedPeer = peer
                            if let user = peer as? TelegramUser, user.firstName == previousBotName {
                                updatedPeer = user.withUpdatedNames(firstName: name, lastName: nil)
                            }
                            return updatedPeer
                        }
                    }
                }
                |> mapError { _ -> UpdateBotInfoError in }
            }
        } else {
            return .fail(.generic)
        }
    }
    |> mapError { _ -> UpdateBotInfoError in }
    |> switchToLatest
}

func _internal_updateBotAbout(account: Account, peerId: PeerId, about: String) -> Signal<Void, UpdateBotInfoError> {
    return account.postbox.transaction { transaction -> Signal<Void, UpdateBotInfoError> in
        if let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) {
            var flags: Int32 = 1 << 2
            flags |= (1 << 0)
            return account.network.request(Api.functions.bots.setBotInfo(flags: flags, bot: inputUser, langCode: "", name: nil, about: about, description: nil))
            |> mapError { _ -> UpdateBotInfoError in
                return .generic
            }
            |> mapToSignal { result -> Signal<Void, UpdateBotInfoError> in
                return account.postbox.transaction { transaction -> Void in
                    if case .boolTrue = result {
                        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                            if let current = current as? CachedUserData, let editableBotInfo = current.editableBotInfo {
                                var updatedAbout = current.about
                                if (current.about ?? "") == editableBotInfo.about {
                                    updatedAbout = about
                                }
                                return current.withUpdatedEditableBotInfo(editableBotInfo.withUpdatedAbout(about)).withUpdatedAbout(updatedAbout)
                            } else {
                                return current
                            }
                        })
                    }
                }
                |> mapError { _ -> UpdateBotInfoError in }
            }
        } else {
            return .fail(.generic)
        }
    }
    |> mapError { _ -> UpdateBotInfoError in }
    |> switchToLatest
}


func _internal_updateBotDescription(account: Account, peerId: PeerId, description: String) -> Signal<Void, UpdateBotInfoError> {
    return account.postbox.transaction { transaction -> Signal<Void, UpdateBotInfoError> in
        if let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) {
            var flags: Int32 = 1 << 2
            flags |= (1 << 1)
            return account.network.request(Api.functions.bots.setBotInfo(flags: flags, bot: inputUser, langCode: "", name: nil, about: nil, description: description))
            |> mapError { _ -> UpdateBotInfoError in
                return .generic
            }
            |> mapToSignal { result -> Signal<Void, UpdateBotInfoError> in
                return account.postbox.transaction { transaction -> Void in
                    if case .boolTrue = result {
                        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                            if let current = current as? CachedUserData, let editableBotInfo = current.editableBotInfo {
                                if let botInfo = current.botInfo {
                                    var updatedBotInfo = botInfo
                                    if botInfo.description == editableBotInfo.description {
                                        updatedBotInfo = BotInfo(description: description, photo: botInfo.photo, video: botInfo.video, commands: botInfo.commands, menuButton: botInfo.menuButton)
                                    }
                                    return current.withUpdatedEditableBotInfo(editableBotInfo.withUpdatedDescription(description)).withUpdatedBotInfo(updatedBotInfo)
                                } else {
                                    return current.withUpdatedEditableBotInfo(editableBotInfo.withUpdatedDescription(description))
                                }
                            } else {
                                return current
                            }
                        })
                    }
                }
                |> mapError { _ -> UpdateBotInfoError in }
            }
        } else {
            return .fail(.generic)
        }
    }
    |> mapError { _ -> UpdateBotInfoError in }
    |> switchToLatest
}
