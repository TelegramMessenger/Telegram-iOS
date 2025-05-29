import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum CreateChannelError {
    case generic
    case restricted
    case tooMuchJoined
    case tooMuchLocationBasedGroups
    case serverProvided(String)
}

public enum CreateChannelMode {
    case channel
    case supergroup(isForum: Bool)
}

private func createChannel(postbox: Postbox, network: Network, stateManager: AccountStateManager, title: String, description: String?, username: String?, mode: CreateChannelMode, location: (latitude: Double, longitude: Double, address: String)? = nil, isForHistoryImport: Bool = false, ttlPeriod: Int32?) -> Signal<PeerId, CreateChannelError> {
    return postbox.transaction { transaction -> Signal<PeerId, CreateChannelError> in
        var flags: Int32 = 0
        switch mode {
        case .channel:
            flags |= (1 << 0)
        case let .supergroup(isForum):
            flags |= (1 << 1)
            if isForum {
                flags |= (1 << 5)
            }
        }
        if isForHistoryImport {
            flags |= (1 << 3)
        }
        
        var geoPoint: Api.InputGeoPoint?
        var address: String?
        if let location = location {
            flags |= (1 << 2)
            geoPoint = .inputGeoPoint(flags: 0, lat: location.latitude, long: location.longitude, accuracyRadius: nil)
            address = location.address
        }
        
        transaction.clearItemCacheCollection(collectionId: Namespaces.CachedItemCollection.cachedGroupCallDisplayAsPeers)
        
        if ttlPeriod != nil {
            flags |= (1 << 4)
        }
        
        return network.request(Api.functions.channels.createChannel(flags: flags, title: title, about: description ?? "", geoPoint: geoPoint, address: address, ttlPeriod: ttlPeriod), automaticFloodWait: false)
        |> mapError { error -> CreateChannelError in
            if error.errorCode == 406 {
                return .serverProvided(error.errorDescription)
            } else if error.errorDescription == "CHANNELS_TOO_MUCH" {
                return .tooMuchJoined
            } else if error.errorDescription == "CHANNELS_ADMIN_LOCATED_TOO_MUCH" {
                return .tooMuchLocationBasedGroups
            } else if error.errorDescription == "USER_RESTRICTED" {
                return .restricted
            } else {
                return .generic
            }
        }
        |> mapToSignal { updates -> Signal<PeerId, CreateChannelError> in
            stateManager.addUpdates(updates)
            if let message = updates.messages.first, let peerId = apiMessagePeerId(message) {
                return postbox.multiplePeersView([peerId])
                |> filter { view in
                    return view.peers[peerId] != nil
                }
                |> take(1)
                |> map { _ in
                    return peerId
                }
                |> castError(CreateChannelError.self)
                |> timeout(5.0, queue: Queue.concurrentDefaultQueue(), alternate: .fail(.generic))
                |> mapToSignal { peerId -> Signal<PeerId, CreateChannelError> in
                    if title.contains("*forum") {
                        return _internal_setChannelForumMode(postbox: postbox, network: network, stateManager: stateManager, peerId: peerId, isForum: true, displayForumAsTabs: true)
                        |> castError(CreateChannelError.self)
                        |> map { _ -> PeerId in
                        }
                        |> then(.single(peerId))
                    } else {
                        return .single(peerId)
                    }
                }
            } else {
                return .fail(.generic)
            }
        }
    }
    |> castError(CreateChannelError.self)
    |> switchToLatest
}

func _internal_createChannel(account: Account, title: String, description: String?, username: String?) -> Signal<PeerId, CreateChannelError> {
    return createChannel(postbox: account.postbox, network: account.network, stateManager: account.stateManager, title: title, description: description, username: nil, mode: .channel, ttlPeriod: nil)
}

public func _internal_createSupergroup(postbox: Postbox, network: Network, stateManager: AccountStateManager, title: String, description: String?, username: String?, isForum: Bool, location: (latitude: Double, longitude: Double, address: String)? = nil, isForHistoryImport: Bool = false, ttlPeriod: Int32? = nil) -> Signal<PeerId, CreateChannelError> {
    return createChannel(postbox: postbox, network: network, stateManager: stateManager, title: title, description: description, username: username, mode: .supergroup(isForum: isForum), location: location, isForHistoryImport: isForHistoryImport, ttlPeriod: ttlPeriod)
}

public enum DeleteChannelError {
    case generic
}

func _internal_deleteChannel(account: Account, peerId: PeerId) -> Signal<Void, DeleteChannelError> {
    return account.postbox.transaction { transaction -> Api.InputChannel? in
        return transaction.getPeer(peerId).flatMap(apiInputChannel)
    }
    |> mapError { _ -> DeleteChannelError in }
    |> mapToSignal { inputChannel -> Signal<Void, DeleteChannelError> in
        if let inputChannel = inputChannel {
            return account.network.request(Api.functions.channels.deleteChannel(channel: inputChannel))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.Updates?, DeleteChannelError> in
                return .fail(.generic)
            }
            |> mapToSignal { updates -> Signal<Void, DeleteChannelError> in
                if let updates = updates {
                    account.stateManager.addUpdates(updates)
                }
                return .complete()
            }
        } else {
            return .fail(.generic)
        }
    }
}
