import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

import SyncCore

private typealias SignalKitTimer = SwiftSignalKit.Timer

public enum PeerNearby {
    case selfPeer(expires: Int32)
    case peer(id: PeerId, expires: Int32, distance: Int32)
    
    var expires: Int32 {
        switch self {
            case let .selfPeer(expires), let .peer(_, expires, _):
                return expires
        }
    }
}

public enum PeerNearbyVisibilityUpdate {
    case visible(latitude: Double, longitude: Double)
    case location(latitude: Double, longitude: Double)
    case invisible
}

public func updatePeersNearbyVisibility(account: Account, update: PeerNearbyVisibilityUpdate, background: Bool) -> Signal<Void, NoError> {
    var flags: Int32 = 0
    var geoPoint: Api.InputGeoPoint
    var selfExpires: Int32?
    
    switch update {
        case let .visible(latitude, longitude):
            flags |= (1 << 0)
            geoPoint = .inputGeoPoint(lat: latitude, long: longitude)
            selfExpires = 0x7fffffff
        case let .location(latitude, longitude):
            geoPoint = .inputGeoPoint(lat: latitude, long: longitude)
        case .invisible:
            flags |= (1 << 0)
            geoPoint = .inputGeoPointEmpty
            selfExpires = 0
    }
    
    let _ = (account.postbox.transaction { transaction in
        transaction.updatePreferencesEntry(key: PreferencesKeys.peersNearby, { entry in
            var settings = entry as? PeersNearbyState ?? PeersNearbyState.default
            if case .invisible = update {
                settings.visibilityExpires = nil
            } else if let expires = selfExpires {
                settings.visibilityExpires = expires
            }
            return settings
        })
    }).start()

    if background {
        flags |= (1 << 1)
    }
        
    return account.network.request(Api.functions.contacts.getLocated(flags: flags, geoPoint: geoPoint, selfExpires: selfExpires))
    |> map(Optional.init)
    |> `catch` { error -> Signal<Api.Updates?, NoError> in
        if error.errorCode == 406 {
            return .single(nil)
        } else {
            return .single(nil)
        }
    }
    |> mapToSignal { updates -> Signal<Void, NoError> in
        if let updates = updates {
            account.stateManager.addUpdates(updates)
        }
        return .complete()
    }
}

public final class PeersNearbyContext {
    private let queue: Queue = Queue.mainQueue()
    private var subscribers = Bag<([PeerNearby]?) -> Void>()
    private let disposable = MetaDisposable()
    private var timer: SignalKitTimer?
    
    private var entries: [PeerNearby]?
   
    public init(network: Network, stateManager: AccountStateManager, coordinate: (latitude: Double, longitude: Double)) {
        let expiryExtension: Double = 10.0
        
        let poll = network.request(Api.functions.contacts.getLocated(flags: 0, geoPoint: .inputGeoPoint(lat: coordinate.latitude, long: coordinate.longitude), selfExpires: nil))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> castError(Void.self)
        |> mapToSignal { updates -> Signal<[PeerNearby], Void> in
            var peersNearby: [PeerNearby] = []
            if let updates = updates {
                switch updates {
                case let .updates(updates, _, _, _, _):
                    for update in updates {
                        if case let .updatePeerLocated(peers) = update {
                            for peer in peers {
                                switch peer {
                                    case let .peerLocated(peer, expires, distance):
                                        peersNearby.append(.peer(id: peer.peerId, expires: expires, distance: distance))
                                    case let .peerSelfLocated(expires):
                                        peersNearby.append(.selfPeer(expires: expires))
                                }
                            }
                        }
                    }
                default:
                    break
                }
                stateManager.addUpdates(updates)
            }
            return .single(peersNearby)
            |> then(
                stateManager.updatedPeersNearby()
                |> castError(Void.self)
            )
        }
                
        let error: Signal<Void, Void> = .single(Void()) |> then(Signal.fail(Void()) |> suspendAwareDelay(25.0, queue: self.queue))
        let combined = combineLatest(poll, error)
        |> map { data, _ -> [PeerNearby] in
            return data
        }
        |> restartIfError
        |> `catch` { _ -> Signal<[PeerNearby], NoError> in
            return .single([])
        }
        
        self.disposable.set((combined
        |> deliverOn(self.queue)).start(next: { [weak self] updatedEntries in
            guard let strongSelf = self else {
                return
            }
            
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            var entries = strongSelf.entries?.filter { Double($0.expires) + expiryExtension > timestamp } ?? []
            let updatedEntries = updatedEntries.filter { Double($0.expires) + expiryExtension > timestamp }
            
            var existingPeerIds: [PeerId: Int] = [:]
            var existingSelfPeer: Int?
            for i in 0 ..< entries.count {
                if case let .peer(id, _, _) = entries[i] {
                    existingPeerIds[id] = i
                } else if case .selfPeer = entries[i] {
                    existingSelfPeer = i
                }
            }
            
            var selfPeer: PeerNearby?
            for entry in updatedEntries {
                switch entry {
                    case let .selfPeer:
                        if let index = existingSelfPeer {
                            entries[index] = entry
                        } else {
                            selfPeer = entry
                        }
                    case let .peer(id, _, _):
                        if let index = existingPeerIds[id] {
                            entries[index] = entry
                        } else {
                            entries.append(entry)
                        }
                }
            }
            
            if let peer = selfPeer {
                entries.insert(peer, at: 0)
            }
            
            strongSelf.entries = entries
            for subscriber in strongSelf.subscribers.copyItems() {
                subscriber(strongSelf.entries)
            }
        }))
        
        self.timer = SignalKitTimer(timeout: 2.0, repeat: true, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            strongSelf.entries = strongSelf.entries?.filter { Double($0.expires) + expiryExtension > timestamp }
            for subscriber in strongSelf.subscribers.copyItems() {
                subscriber(strongSelf.entries)
            }
        }, queue: self.queue)
        self.timer?.start()
    }
    
    deinit {
        self.disposable.dispose()
        self.timer?.invalidate()
    }
    
    public func get() -> Signal<[PeerNearby]?, NoError> {
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
                        return current.withUpdatedPeerGeoLocation(peerGeoLocation)
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

public struct PeersNearbyState: PreferencesEntry, Equatable {
    public var visibilityExpires: Int32?
    
    public static var `default` = PeersNearbyState(visibilityExpires: nil)
    
    public init(visibilityExpires: Int32?) {
        self.visibilityExpires = visibilityExpires
    }
    
    public init(decoder: PostboxDecoder) {
        self.visibilityExpires = decoder.decodeOptionalInt32ForKey("expires")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let expires = self.visibilityExpires {
            encoder.encodeInt32(expires, forKey: "expires")
        } else {
            encoder.encodeNil(forKey: "expires")
        }
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? PeersNearbyState, self == to {
            return true
        } else {
            return false
        }
    }
}
