#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func updateChannelHistoryAvailabilitySettingsInteractively(postbox: Postbox, network: Network, accountStateManager: AccountStateManager, peerId: PeerId, historyAvailableForNewMembers: Bool) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
            return network.request(Api.functions.channels.togglePreHistoryHidden(channel: inputChannel, enabled: historyAvailableForNewMembers ? .boolFalse : .boolTrue))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { updates -> Signal<Void, NoError> in
                if let updates = updates {
                    accountStateManager.addUpdates(updates)
                }
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
    }
    |> switchToLatest
}
