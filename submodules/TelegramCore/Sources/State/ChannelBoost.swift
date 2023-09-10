import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit

public final class ChannelBoostStatus: Equatable {
    public let level: Int
    public let boosts: Int
    public let nextLevelBoosts: Int?
    
    public init(level: Int, boosts: Int, nextLevelBoosts: Int?) {
        self.level = level
        self.boosts = boosts
        self.nextLevelBoosts = nextLevelBoosts
    }
    
    public static func ==(lhs: ChannelBoostStatus, rhs: ChannelBoostStatus) -> Bool {
        if lhs.level != rhs.level {
            return false
        }
        if lhs.boosts != rhs.boosts {
            return false
        }
        if lhs.nextLevelBoosts != rhs.nextLevelBoosts {
            return false
        }
        return true
    }
}

func _internal_getBoostStatus(account: Account, peerId: PeerId) -> Signal<ChannelBoostStatus?, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<ChannelBoostStatus?, NoError> in
        guard let inputPeer = inputPeer else {
            return .single(nil)
        }
        return account.network.request(Api.functions.stories.getBoostsStatus(peer: inputPeer))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.stories.BoostsStatus?, NoError> in
            return .single(nil)
        }
        |> map { result -> ChannelBoostStatus? in
            guard let result = result else {
                return nil
            }
            
            switch result {
            case let .boostsStatus(_, level, boosts, nextLevelBoosts):
                return ChannelBoostStatus(level: Int(level), boosts: Int(boosts), nextLevelBoosts: nextLevelBoosts.flatMap(Int.init))
            }
        }
    }
}

public enum CanApplyBoostStatus {
    case ok
    case replace(currentBoost: EnginePeer)
}

func _internal_canApplyBoost(account: Account, peerId: PeerId) -> Signal<CanApplyBoostStatus?, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<CanApplyBoostStatus?, NoError> in
        guard let inputPeer = inputPeer else {
            return .single(nil)
        }
        return account.network.request(Api.functions.stories.canApplyBoost(peer: inputPeer))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.stories.CanApplyBoostResult?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<CanApplyBoostStatus?, NoError> in
            guard let result = result else {
                return .single(nil)
            }
            
            return account.postbox.transaction { transaction -> CanApplyBoostStatus? in
                switch result {
                case .canApplyBoostOk:
                    return .ok
                case let .canApplyBoostReplace(currentBoost, chats):
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(transaction: transaction, chats: chats, users: []))
                    
                    if let peer = transaction.getPeer(currentBoost.peerId) {
                        return .replace(currentBoost: EnginePeer(peer))
                    } else {
                        return nil
                    }
                }
            }
        }
    }
}
