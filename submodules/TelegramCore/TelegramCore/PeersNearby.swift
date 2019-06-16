import Foundation
#if os(macOS)
import SwiftSignalKitMac
import PostboxMac
#else
import SwiftSignalKit
import Postbox
#endif
import TelegramApi

public struct PeerNearby {
    public let id: PeerId
    public let expires: Int32
    public let distance: Int32
}

public final class PeersNearbyContext {
    private let queue: Queue = Queue.mainQueue()
    private var subscribers = Bag<([PeerNearby]) -> Void>()
    private let disposable = MetaDisposable()
    private var timer: SwiftSignalKit.Timer?
    
    private var entries: [PeerNearby] = []
   
    public init(network: Network, accountStateManager: AccountStateManager, coordinate: (latitude: Double, longitude: Double)) {
        self.disposable.set((network.request(Api.functions.contacts.getLocated(geoPoint: .inputGeoPoint(lat: coordinate.latitude, long: coordinate.longitude)))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { updates -> Signal<[PeerNearby], NoError> in
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
        }).start(next: { [weak self] updatedEntries in
            guard let strongSelf = self else {
                return
            }
            
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            var entries = strongSelf.entries.filter { Double($0.expires) > timestamp }
            let updatedEntries = updatedEntries.filter { Double($0.expires) > timestamp }
            
            var existingPeerIds: [PeerId: Int] = [:]
            for i in 0 ..< entries.count {
                existingPeerIds[entries[i].id] = i
            }
            
            for entry in updatedEntries {
                if let index = existingPeerIds[entry.id] {
                    entries[index] = entry
                } else {
                    entries.append(entry)
                }
            }
            
            strongSelf.entries = entries
            
            for subscriber in strongSelf.subscribers.copyItems() {
                subscriber(strongSelf.entries)
            }
        }))
        
        self.timer = SwiftSignalKit.Timer(timeout: 5.0, repeat: true, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            strongSelf.entries = strongSelf.entries.filter { Double($0.expires) > timestamp }
        }, queue: self.queue)
        self.timer?.start()
    }
    
    deinit {
        self.disposable.dispose()
        self.timer?.invalidate()
    }
    
    public func get() -> Signal<[PeerNearby], NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                subscriber.putNext(strongSelf.entries)
                
                let index = strongSelf.subscribers.add({ entries in
                    subscriber.putNext(entries)
                })
                
                return ActionDisposable {
                    queue.async {
                        if let strongSelf = self {
                            strongSelf.subscribers.remove(index)
                        }
                    }
                }
            } else {
                return EmptyDisposable
            }
        } |> runOn(queue)
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
