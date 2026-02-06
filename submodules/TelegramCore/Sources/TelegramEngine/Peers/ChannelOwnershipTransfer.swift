import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi


public enum ChatOwnershipTransferError {
    case generic
    case twoStepAuthMissing
    case twoStepAuthTooFresh(Int32)
    case authSessionTooFresh(Int32)
    case limitExceeded
    case requestPassword
    case invalidPassword
    case adminsTooMuch
    case userPublicChannelsTooMuch
    case userLocatedGroupsTooMuch
    case tooMuchJoined
    case restricted
    case userBlocked
}

func _internal_checkOwnershipTranfserAvailability(postbox: Postbox, network: Network, accountStateManager: AccountStateManager, memberId: PeerId) -> Signal<Never, ChatOwnershipTransferError> {
    return postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(memberId)
    }
    |> castError(ChatOwnershipTransferError.self)
    |> mapToSignal { user -> Signal<Never, ChatOwnershipTransferError> in
        guard let user = user else {
            return .fail(.generic)
        }
        guard let apiUser = apiInputUser(user) else {
            return .fail(.generic)
        }
        
        return network.request(Api.functions.messages.editChatCreator(peer: .inputPeerEmpty, userId: apiUser, password: .inputCheckPasswordEmpty))
        |> mapError { error -> ChatOwnershipTransferError in
            if error.errorDescription == "PASSWORD_HASH_INVALID" {
                return .requestPassword
            } else if error.errorDescription == "PASSWORD_MISSING" {
                return .twoStepAuthMissing
            } else if error.errorDescription.hasPrefix("PASSWORD_TOO_FRESH_") {
                let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "PASSWORD_TOO_FRESH_".count)...])
                if let value = Int32(timeout) {
                    return .twoStepAuthTooFresh(value)
                }
            } else if error.errorDescription.hasPrefix("SESSION_TOO_FRESH_") {
                let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "SESSION_TOO_FRESH_".count)...])
                if let value = Int32(timeout) {
                    return .authSessionTooFresh(value)
                }
            } else if error.errorDescription == "CHANNELS_ADMIN_PUBLIC_TOO_MUCH" {
                return .userPublicChannelsTooMuch
            } else if error.errorDescription == "CHANNELS_ADMIN_LOCATED_TOO_MUCH" {
                return .userLocatedGroupsTooMuch
            } else if error.errorDescription == "ADMINS_TOO_MUCH" {
                return .adminsTooMuch
            } else if error.errorDescription == "USER_PRIVACY_RESTRICTED" {
                return .restricted
            } else if error.errorDescription == "USER_BLOCKED" {
                return .userBlocked
            } else if error.errorDescription == "CHANNELS_TOO_MUCH" {
                return .tooMuchJoined
            }
            return .generic
        }
        |> mapToSignal { updates -> Signal<Never, ChatOwnershipTransferError> in
            accountStateManager.addUpdates(updates)
            return .complete()
        }
    }
}

func _internal_updateChatOwnership(account: Account, peerId: PeerId, memberId: PeerId, password: String) -> Signal<[(ChannelParticipant?, RenderedChannelParticipant)], ChatOwnershipTransferError> {
    guard !password.isEmpty else {
        return .fail(.invalidPassword)
    }
    
    return combineLatest(_internal_fetchChannelParticipant(account: account, peerId: peerId, participantId: account.peerId), _internal_fetchChannelParticipant(account: account, peerId: peerId, participantId: memberId))
    |> mapError { _ -> ChatOwnershipTransferError in
    }
    |> mapToSignal { currentCreator, currentParticipant -> Signal<[(ChannelParticipant?, RenderedChannelParticipant)], ChatOwnershipTransferError> in
        return account.postbox.transaction { transaction -> Signal<[(ChannelParticipant?, RenderedChannelParticipant)], ChatOwnershipTransferError> in
            if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer), let accountUser = transaction.getPeer(account.peerId), let user = transaction.getPeer(memberId), let inputUser = apiInputUser(user) {
                
                let flags: TelegramChatAdminRightsFlags = TelegramChatAdminRightsFlags.peerSpecific(peer: EnginePeer(peer))
                    
                let updatedParticipant = ChannelParticipant.creator(id: user.id, adminInfo: nil, rank: currentParticipant?.rank)
                let updatedPreviousCreator = ChannelParticipant.member(id: accountUser.id, invitedAt: Int32(Date().timeIntervalSince1970), adminInfo: ChannelParticipantAdminInfo(rights: TelegramChatAdminRights(rights: flags), promotedBy: accountUser.id, canBeEditedByAccountPeer: false), banInfo: nil, rank: currentCreator?.rank, subscriptionUntilDate: nil)
                
                let checkPassword = _internal_twoStepAuthData(account.network)
                |> mapError { error -> ChatOwnershipTransferError in
                    if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                        return .limitExceeded
                    } else {
                        return .generic
                    }
                }
                |> mapToSignal { authData -> Signal<Api.InputCheckPasswordSRP, ChatOwnershipTransferError> in
                    if let currentPasswordDerivation = authData.currentPasswordDerivation, let srpSessionData = authData.srpSessionData {
                        guard let kdfResult = passwordKDF(encryptionProvider: account.network.encryptionProvider, password: password, derivation: currentPasswordDerivation, srpSessionData: srpSessionData) else {
                            return .fail(.generic)
                        }
                        return .single(.inputCheckPasswordSRP(.init(srpId: kdfResult.id, A: Buffer(data: kdfResult.A), M1: Buffer(data: kdfResult.M1))))
                    } else {
                        return .fail(.twoStepAuthMissing)
                    }
                }
                
                return checkPassword
                |> mapToSignal { password -> Signal<[(ChannelParticipant?, RenderedChannelParticipant)], ChatOwnershipTransferError> in
                    return account.network.request(Api.functions.messages.editChatCreator(peer: inputPeer, userId: inputUser, password: password), automaticFloodWait: false)
                    |> mapError { error -> ChatOwnershipTransferError in
                        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                            return .limitExceeded
                        } else if error.errorDescription == "PASSWORD_HASH_INVALID" {
                            return .invalidPassword
                        } else if error.errorDescription == "PASSWORD_MISSING" {
                            return .twoStepAuthMissing
                        } else if error.errorDescription.hasPrefix("PASSWORD_TOO_FRESH_") {
                            let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "PASSWORD_TOO_FRESH_".count)...])
                            if let value = Int32(timeout) {
                                return .twoStepAuthTooFresh(value)
                            }
                        } else if error.errorDescription.hasPrefix("SESSION_TOO_FRESH_") {
                            let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "SESSION_TOO_FRESH_".count)...])
                            if let value = Int32(timeout) {
                                return .authSessionTooFresh(value)
                            }
                        } else if error.errorDescription == "CHANNELS_ADMIN_PUBLIC_TOO_MUCH" {
                            return .userPublicChannelsTooMuch
                        } else if error.errorDescription == "CHANNELS_ADMIN_LOCATED_TOO_MUCH" {
                            return .userLocatedGroupsTooMuch
                        } else if error.errorDescription == "ADMINS_TOO_MUCH" {
                            return .adminsTooMuch
                        } else if error.errorDescription == "USER_PRIVACY_RESTRICTED" {
                            return .restricted
                        } else if error.errorDescription == "USER_BLOCKED" {
                            return .userBlocked
                        }
                        return .generic
                    }
                    |> mapToSignal { updates -> Signal<[(ChannelParticipant?, RenderedChannelParticipant)], ChatOwnershipTransferError> in
                        account.stateManager.addUpdates(updates)
                        
                        return account.postbox.transaction { transaction -> [(ChannelParticipant?, RenderedChannelParticipant)] in
                            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
                                if let cachedData = cachedData as? CachedChannelData, let adminCount = cachedData.participantsSummary.adminCount {
                                    var updatedAdminCount = adminCount
                                    var wasAdmin = false
                                    if let currentParticipant = currentParticipant {
                                        switch currentParticipant {
                                            case .creator:
                                                wasAdmin = true
                                            case let .member(_, _, adminInfo, _, _, _):
                                                if let _ = adminInfo {
                                                    wasAdmin = true
                                                }
                                        }
                                    }
                                    if !wasAdmin {
                                        updatedAdminCount = adminCount + 1
                                    }

                                    return cachedData.withUpdatedParticipantsSummary(cachedData.participantsSummary.withUpdatedAdminCount(updatedAdminCount))
                                } else {
                                    return cachedData
                                }
                            })
                            var peers: [PeerId: Peer] = [:]
                            var presences: [PeerId: PeerPresence] = [:]
                            peers[accountUser.id] = accountUser
                            if let presence = transaction.getPeerPresence(peerId: accountUser.id) {
                                presences[accountUser.id] = presence
                            }
                            peers[user.id] = user
                            if let presence = transaction.getPeerPresence(peerId: user.id) {
                                presences[user.id] = presence
                            }
                            return [(currentCreator, RenderedChannelParticipant(participant: updatedPreviousCreator, peer: accountUser, peers: peers, presences: presences)), (currentParticipant, RenderedChannelParticipant(participant: updatedParticipant, peer: user, peers: peers, presences: presences))]
                        }
                        |> mapError { _ -> ChatOwnershipTransferError in }
                    }
                }
            } else {
                return .fail(.generic)
            }
        }
        |> mapError { _ -> ChatOwnershipTransferError in }
        |> switchToLatest
    }
}
