import Foundation
#if os(macOS)
import SwiftSignalKitMac
import PostboxMac
#else
import SwiftSignalKit
import Postbox
#endif

public struct PeerNearby {
    public let id: PeerId
    public let expires: Int32
    public let distance: Int32
}

public func peersNearby(network: Network, accountStateManager: AccountStateManager, coordinate: (latitude: Double, longitude: Double)) -> Signal<[PeerNearby], NoError> {
    let inputGeoPoint = Api.InputGeoPoint.inputGeoPoint(lat: coordinate.latitude, long: coordinate.longitude)
    
    return network.request(Api.functions.contacts.getLocated(geoPoint: inputGeoPoint))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.Updates?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { updates in
        var peersNearby: [PeerNearby] = []
        if let updates = updates {
            switch updates {
                case let .updates(updates, _, _, _, _):
                    for update in updates {
                        if case let .updatePeerLocated(peers) = update {
                            for case let .peerLocated(peer, expires, distance) in peers {
                                peersNearby.append(PeerNearby(id: peer.peerId, expires: expires, distance: distance))
                            }
                        }
                    }
                default:
                    break
            }
            
            accountStateManager.addUpdates(updates)
        }
        
        return .single(peersNearby)
        |> then(accountStateManager.updatedPeersNearby())
    }
}

public func updateChannelGeoLocation(postbox: Postbox, network: Network, channelId: PeerId, coordinate: (latitude: Double, longitude: Double)?, address: String?) -> Signal<Bool, NoError> {
    return postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(channelId)
    }
    |> mapToSignal { channel -> Signal<Bool, NoError> in
        guard let channel = channel, let apiChannel = apiInputChannel(channel) else {
            return .single(false)
        }
        
        let geoPoint: Api.InputGeoPoint
        if let (latitude, longitude) = coordinate, let _ = address {
            geoPoint = .inputGeoPoint(lat: latitude, long: longitude)
        } else {
            geoPoint = .inputGeoPointEmpty
        }
     
        return network.request(Api.functions.channels.editLocation(channel: apiChannel, geoPoint: geoPoint, address: address ?? ""))
        |> map { result -> Bool in
            switch result {
                case .boolTrue:
                    return true
                case .boolFalse:
                    return false
            }
        }
        |> `catch` { error -> Signal<Bool, NoError> in
            return .single(false)
        }
        |> mapToSignal { result in
            if result {
                return postbox.transaction { transaction in
                    transaction.updatePeerCachedData(peerIds: Set([channelId]), update: { (_, current) -> CachedPeerData? in
                        let current: CachedChannelData = current as? CachedChannelData ?? CachedChannelData()
                        let peerGeoLocation: PeerGeoLocation?
                        if let (latitude, longitude) = coordinate, let address = address {
                            peerGeoLocation = PeerGeoLocation(latitude: latitude, longitude: longitude, address: address)
                        } else {
                            peerGeoLocation = nil
                        }
                        return current.withUpdatedPeerGeoLocation(peerGeoLocation: peerGeoLocation)
                    })
                }
                |> map { _ in
                    return result
                }
            } else {
                return .single(result)
            }
        }
    }
}
