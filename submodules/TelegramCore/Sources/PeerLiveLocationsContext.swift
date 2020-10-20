import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

import SyncCore

public func topPeerActiveLiveLocationMessages(viewTracker: AccountViewTracker, accountPeerId: PeerId, peerId: PeerId) -> Signal<(Peer?, [Message]), NoError> {
    return viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId), index: .upperBound, anchorIndex: .upperBound, count: 50, fixedCombinedReadStates: nil, tagMask: .liveLocation, orderStatistics: [], additionalData: [.peer(accountPeerId)])
    |> map { (view, _, _) -> (Peer?, [Message]) in
        var accountPeer: Peer?
        for entry in view.additionalData {
            if case let .peer(_, peer) = entry {
                accountPeer = peer
                break
            }
        }
        
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        var result: [Message] = []
        for entry in view.entries {
            for media in entry.message.media {
                if let location = media as? TelegramMediaMap, let liveBroadcastingTimeout = location.liveBroadcastingTimeout {
                    if entry.message.timestamp + liveBroadcastingTimeout > timestamp {
                        result.append(entry.message)
                    }
                } else {
                    assertionFailure()
                }
            }
        }
        return (accountPeer, result)
    }
}

public func requestProximityNotification(postbox: Postbox, network: Network, messageId: MessageId, distance: Int32) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Void, NoError> in
        guard let inputPeer = inputPeer else {
            return .complete()
        }
        let flags: Int32 = 1 << 0
        return network.request(Api.functions.messages.requestProximityNotification(flags: flags, peer: inputPeer, msgId: messageId.id, maxDistance: distance))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Bool?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return updateProximityNotificationStoredStateInteractively(postbox: postbox, peerId: messageId.peerId, state: ProximityNotificationStoredState(messageId: messageId, distance: distance))
        }
    }
}

public func cancelProximityNotification(postbox: Postbox, network: Network, messageId: MessageId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Void, NoError> in
        guard let inputPeer = inputPeer else {
            return .complete()
        }
        return network.request(Api.functions.messages.requestProximityNotification(flags: 0, peer: inputPeer, msgId: messageId.id, maxDistance: nil))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Bool?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return updateProximityNotificationStoredStateInteractively(postbox: postbox, peerId: messageId.peerId, state: nil)
        }
    }
}

public final class ProximityNotificationStoredState: PostboxCoding {
    public let messageId: MessageId
    public let distance: Int32
    
    public init(messageId: MessageId, distance: Int32) {
        self.messageId = messageId
        self.distance = distance
    }
    
    public init(decoder: PostboxDecoder) {
        self.messageId = MessageId(peerId: PeerId(decoder.decodeInt64ForKey("id.peerId", orElse: 0)), namespace: decoder.decodeInt32ForKey("id.namespace", orElse: 0), id: decoder.decodeInt32ForKey("id.id", orElse: 0))
        self.distance = decoder.decodeInt32ForKey("distance", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.messageId.peerId.toInt64(), forKey: "id.peerId")
        encoder.encodeInt32(self.messageId.namespace, forKey: "id.namespace")
        encoder.encodeInt32(self.messageId.id, forKey: "id.id")
        encoder.encodeInt32(self.distance, forKey: "distance")
    }
}

private let collectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 25, highWaterItemCount: 50)

public func updateProximityNotificationStoredStateInteractively(postbox: Postbox, peerId: PeerId, state: ProximityNotificationStoredState?) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        let id = ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.proximityNotificationStoredState, key: key)
        if let state = state {
            transaction.putItemCacheEntry(id: id, entry: state, collectionSpec: collectionSpec)
        } else {
            transaction.removeItemCacheEntry(id: id)
        }
    }
}
public func proximityNotificationStoredState(account: Account, peerId: PeerId) -> Signal<ProximityNotificationStoredState?, NoError> {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: peerId.toInt64())
    let id = ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.proximityNotificationStoredState, key: key)
    let viewKey = PostboxViewKey.cachedItem(id)
    return account.postbox.combinedView(keys: [viewKey])
    |> map { views -> ProximityNotificationStoredState? in
        if let value = (views.views[viewKey] as? CachedItemView)?.value as? ProximityNotificationStoredState {
            return value
        } else {
            return nil
        }
    }
}
