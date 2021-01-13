import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

public func ensuredExistingPeerExportedInvitation(account: Account, peerId: PeerId, revokeExisted: Bool = false) -> Signal<ExportedInvitation?, NoError> {
    return account.postbox.transaction { transaction -> Signal<ExportedInvitation?, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            if let _ = peer as? TelegramChannel {
                if let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData, cachedData.exportedInvitation != nil && !revokeExisted {
                    return .complete()
                } else {
                    return account.network.request(Api.functions.messages.exportChatInvite(flags: 0, peer: inputPeer, expireDate: nil, usageLimit: nil))
                    |> retryRequest
                    |> mapToSignal { result -> Signal<ExportedInvitation?, NoError> in
                        return account.postbox.transaction { transaction -> ExportedInvitation? in
                            if let invitation = ExportedInvitation(apiExportedInvite: result) {
                                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                    if let current = current as? CachedChannelData {
                                        return current.withUpdatedExportedInvitation(invitation)
                                    } else {
                                        return CachedChannelData().withUpdatedExportedInvitation(invitation)
                                    }
                                })
                                return invitation
                            } else {
                                return nil
                            }
                        }
                    }
                }
            } else if let _ = peer as? TelegramGroup {
                if let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedGroupData, cachedData.exportedInvitation != nil && !revokeExisted {
                    return .complete()
                } else {
                    return account.network.request(Api.functions.messages.exportChatInvite(flags: 0, peer: inputPeer, expireDate: nil, usageLimit: nil))
                    |> retryRequest
                    |> mapToSignal { result -> Signal<ExportedInvitation?, NoError> in
                        return account.postbox.transaction { transaction -> ExportedInvitation? in
                            if let invitation = ExportedInvitation(apiExportedInvite: result) {
                                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                    if let current = current as? CachedGroupData {
                                        return current.withUpdatedExportedInvitation(invitation)
                                    } else {
                                        return current
                                    }
                                })
                                return invitation
                            } else {
                                return nil
                            }
                        }
                    }
                }
            } else {
                return .complete()
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

public func createPeerExportedInvitation(account: Account, peerId: PeerId, expireDate: Int32?, usageLimit: Int32?) -> Signal<ExportedInvitation?, NoError> {
    return account.postbox.transaction { transaction -> Signal<ExportedInvitation?, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var flags: Int32 = 0
            if let _ = expireDate {
                flags |= (1 << 0)
            }
            if let _ = usageLimit {
                flags |= (1 << 1)
            }
            return account.network.request(Api.functions.messages.exportChatInvite(flags: flags, peer: inputPeer, expireDate: expireDate, usageLimit: usageLimit))
            |> retryRequest
            |> map { result -> ExportedInvitation? in
                if let invitation = ExportedInvitation(apiExportedInvite: result) {
                    return invitation
                } else {
                    return nil
                }
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

public func peerExportedInvitations(account: Account, peerId: PeerId) -> Signal<[ExportedInvitation]?, NoError> {
    return account.postbox.transaction { transaction -> Signal<[ExportedInvitation]?, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.messages.getExportedChatInvites(flags: 0, peer: inputPeer, adminId: nil, offsetLink: nil, limit: 100))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.messages.ExportedChatInvites?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<[ExportedInvitation]?, NoError> in
                return account.postbox.transaction { transaction -> [ExportedInvitation]? in
                    if let result = result, case let .exportedChatInvites(_, apiInvites, users) = result {
                        var peers: [Peer] = []
                        var peersMap: [PeerId: Peer] = [:]
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                            peersMap[telegramUser.id] = telegramUser
                        }
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        
                        var invites: [ExportedInvitation] = []
                        for apiInvite in apiInvites {
                            if let invite = ExportedInvitation(apiExportedInvite: apiInvite) {
                                invites.append(invite)
                            }
                        }
                        return invites
                    } else {
                        return nil
                    }
                }
            }
        } else {
            return .single(nil)
        }
    } |> switchToLatest
}

public enum EditPeerExportedInvitationError {
    case generic
}

public func editPeerExportedInvitation(account: Account, peerId: PeerId, link: String, expireDate: Int32?, usageLimit: Int32?) -> Signal<ExportedInvitation?, EditPeerExportedInvitationError> {
    return account.postbox.transaction { transaction -> Signal<ExportedInvitation?, EditPeerExportedInvitationError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var flags: Int32 = 0
            if let _ = expireDate {
                flags |= (1 << 0)
            }
            if let _ = usageLimit {
                flags |= (1 << 1)
            }
            return account.network.request(Api.functions.messages.editExportedChatInvite(flags: flags, peer: inputPeer, link: link, expireDate: expireDate, usageLimit: usageLimit))
            |> mapError { _ in return EditPeerExportedInvitationError.generic }
            |> map { result -> ExportedInvitation? in
                if case let .exportedChatInvite(invite, recentImporters, users) = result {
                    var peers: [Peer] = []
                    for user in users {
                        let telegramUser = TelegramUser(user: user)
                        peers.append(telegramUser)
                    }
                    updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                        return updated
                    })
                    return ExportedInvitation(apiExportedInvite: invite)
                } else {
                    return nil
                }
            }
        } else {
            return .complete()
        }
    }
    |> castError(EditPeerExportedInvitationError.self)
    |> switchToLatest
}

public enum RevokePeerExportedInvitationError {
    case generic
}

public func revokePeerExportedInvitation(account: Account, peerId: PeerId, link: String) -> Signal<Never, RevokePeerExportedInvitationError> {
    return account.postbox.transaction { transaction -> Signal<Never, RevokePeerExportedInvitationError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            let flags: Int32 = (1 << 2)
            return account.network.request(Api.functions.messages.editExportedChatInvite(flags: flags, peer: inputPeer, link: link, expireDate: nil, usageLimit: nil))
            |> mapError { _ in return RevokePeerExportedInvitationError.generic }
            |> ignoreValues
        } else {
            return .complete()
        }
    }
    |> castError(RevokePeerExportedInvitationError.self)
    |> switchToLatest
}
