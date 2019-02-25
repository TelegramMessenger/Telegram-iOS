import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func topPeerActiveLiveLocationMessages(viewTracker: AccountViewTracker, accountPeerId: PeerId, peerId: PeerId) -> Signal<(Peer?, [Message]), NoError> {
    return viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId), index: .upperBound, anchorIndex: .upperBound, count: 100, fixedCombinedReadStates: nil, tagMask: .liveLocation, orderStatistics: [], additionalData: [.peer(accountPeerId)])
    |> map { (view, _, _) -> (Peer?, [Message]) in
        var accountPeer: Peer?
        for entry in view.additionalData {
            if case let .peer(id, peer) = entry {
                accountPeer = peer
                break
            }
        }
        
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        var result: [Message] = []
        for entry in view.entries {
            if case let .MessageEntry(message, _, _, _, _) = entry {
                for media in message.media {
                    if let location = media as? TelegramMediaMap, let liveBroadcastingTimeout = location.liveBroadcastingTimeout {
                        if message.timestamp + liveBroadcastingTimeout > timestamp {
                            result.append(message)
                        }
                    } else {
                        assertionFailure()
                    }
                }
            }
        }
        return (accountPeer, result)
    }
}
