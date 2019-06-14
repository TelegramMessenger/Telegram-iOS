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

public func peersNearby(network: Network, accountStateManager: AccountStateManager, coordinate: (latitude: Double, longitude: Double), radius: Int32) -> Signal<[PeerNearby], NoError> {
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
