import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum CreateGroupError {
    case generic
    case privacy
    case restricted
    case tooMuchJoined
    case tooMuchLocationBasedGroups
    case serverProvided(String)
}

public struct CreateGroupResult {
    public var peerId: EnginePeer.Id
    public var result: TelegramInvitePeersResult
    
    public init(
        peerId: EnginePeer.Id,
        result: TelegramInvitePeersResult
    ) {
        self.peerId = peerId
        self.result = result
    }
}

func _internal_createGroup(account: Account, title: String, peerIds: [PeerId], ttlPeriod: Int32?) -> Signal<CreateGroupResult?, CreateGroupError> {
    return account.postbox.transaction { transaction -> Signal<CreateGroupResult?, CreateGroupError> in
        var inputUsers: [Api.InputUser] = []
        for peerId in peerIds {
            if let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) {
                inputUsers.append(inputUser)
            } else {
                return .single(nil)
            }
        }
        
        var ttlPeriod = ttlPeriod
        if ttlPeriod == nil {
            ttlPeriod = 0
        }
        
        var flags: Int32 = 0
        if let _ = ttlPeriod {
            flags |= 1 << 0
        }
        
        return account.network.request(Api.functions.messages.createChat(flags: flags, users: inputUsers, title: title, ttlPeriod: ttlPeriod))
        |> mapError { error -> CreateGroupError in
            if error.errorDescription == "USERS_TOO_FEW" {
                return .privacy
            }
            return .generic
        }
        |> mapToSignal { result -> Signal<CreateGroupResult?, CreateGroupError> in
            let updatesValue: Api.Updates
            let missingInviteesValue: [Api.MissingInvitee]
            switch result {
            case let .invitedUsers(updates, missingInvitees):
                updatesValue = updates
                missingInviteesValue = missingInvitees
            }
            
            account.stateManager.addUpdates(updatesValue)
            if let message = updatesValue.messages.first, let peerId = apiMessagePeerId(message) {
                return account.postbox.multiplePeersView([peerId])
                |> filter { view in
                    return view.peers[peerId] != nil
                }
                |> take(1)
                |> castError(CreateGroupError.self)
                |> mapToSignal { _ -> Signal<CreateGroupResult?, CreateGroupError> in
                    return account.postbox.transaction { transaction -> CreateGroupResult in
                        return CreateGroupResult(
                            peerId: peerId,
                            result: TelegramInvitePeersResult(forbiddenPeers: missingInviteesValue.compactMap { invitee -> TelegramForbiddenInvitePeer? in
                                switch invitee {
                                case let .missingInvitee(flags, userId):
                                    guard let peer = transaction.getPeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))) else {
                                        return nil
                                    }
                                    return TelegramForbiddenInvitePeer(
                                        peer: EnginePeer(peer),
                                        canInviteWithPremium: (flags & (1 << 0)) != 0,
                                        premiumRequiredToContact: (flags & (1 << 1)) != 0
                                    )
                                }
                            })
                        )
                    }
                    |> castError(CreateGroupError.self)
                }
            } else {
                return .single(nil)
            }
        }
    }
    |> castError(CreateGroupError.self)
    |> switchToLatest
}
