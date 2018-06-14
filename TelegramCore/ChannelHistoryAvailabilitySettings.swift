#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func updateChannelHistoryAvailabilitySettingsInteractively(postbox: Postbox, network: Network, peerId: PeerId, historyAvailableForNewMembers: Bool) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
            return network.request(Api.functions.channels.togglePreHistoryHidden(channel: inputChannel, enabled: historyAvailableForNewMembers ? .boolFalse : .boolTrue))
                |> mapError {_ in}
                |> mapToSignal { _ -> Signal<Void, NoError> in
                    return postbox.transaction { transaction -> Void in
                        transaction.updatePeerCachedData(peerIds: [peerId], update: { peerId, currentData in
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
