#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func updateChannelHistoryAvailabilitySettingsInteractively(postbox: Postbox, network: Network, peerId: PeerId, historyAvailableForNewMembers: Bool) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Signal<Void, NoError> in
        if let peer = modifier.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
            return network.request(Api.functions.channels.togglePreHistoryHidden(channel: inputChannel, enabled: historyAvailableForNewMembers ? .boolTrue : .boolFalse))
                |> retryRequest
                |> mapToSignal { _ -> Signal<Void, NoError> in
                    return postbox.modify { modifier -> Void in
                        modifier.updatePeerCachedData(peerIds: [peerId], update: { peerId, currentData in
                            if let currentData = currentData as? CachedChannelData {
                                var flags = currentData.flags
                                if historyAvailableForNewMembers {
                                    flags.insert(.preHistoryEnabled)
                                } else {
                                    flags.remove(.preHistoryEnabled)
                                }
                                return currentData.withUpdatedFlags(flags)
                            } else {
                                return currentData
                            }
                        })
                    }
                }
        } else {
            return .complete()
        }
    } |> switchToLatest
}
