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

private func createChannel(account: Account, title: String, description: String?, isSupergroup:Bool, location: (latitude: Double, longitude: Double, address: String)? = nil, isForHistoryImport: Bool = false) -> Signal<PeerId, CreateChannelError> {
    return account.postbox.transaction { transaction -> Signal<PeerId, CreateChannelError> in
        var flags: Int32 = 0
        if isSupergroup {
            flags |= (1 << 1)
        } else {
            flags |= (1 << 0)
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
        
        return account.network.request(Api.functions.channels.createChannel(flags: flags, title: title, about: description ?? "", geoPoint: geoPoint, address: address), automaticFloodWait: false)
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
            account.stateManager.addUpdates(updates)
            if let message = updates.messages.first, let peerId = apiMessagePeerId(message) {
                return account.postbox.multiplePeersView([peerId])
                |> filter { view in
                    return view.peers[peerId] != nil
                }
                |> take(1)
                |> map { _ in
                    return peerId
                }
                |> castError(CreateChannelError.self)
                |> timeout(5.0, queue: Queue.concurrentDefaultQueue(), alternate: .fail(.generic))
            } else {
                return .fail(.generic)
            }
        }
    }
    |> castError(CreateChannelError.self)
    |> switchToLatest
}

func _internal_createChannel(account: Account, title: String, description: String?) -> Signal<PeerId, CreateChannelError> {
    return createChannel(account: account, title: title, description: description, isSupergroup: false)
}

func _internal_createSupergroup(account: Account, title: String, description: String?, location: (latitude: Double, longitude: Double, address: String)? = nil, isForHistoryImport: Bool = false) -> Signal<PeerId, CreateChannelError> {
    return createChannel(account: account, title: title, description: description, isSupergroup: true, location: location, isForHistoryImport: isForHistoryImport)
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
