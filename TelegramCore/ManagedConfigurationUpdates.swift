import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

func managedConfigurationUpdates(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = Signal<Void, NoError> { subscriber in
        return network.request(Api.functions.help.getConfig()).start(next: { result in
            switch result {
                case let .config(_, _, _, _, _, dcOptions, chatSizeMax, megagroupSizeMax, forwardedCountMax, onlineUpdatePeriodMs, offlineBlurTimeoutMs, offlineIdleTimeoutMs, onlineCloudTimeoutMs, notifyCloudDelayMs, notifyDefaultDelayMs, chatBigSize, pushChatPeriodMs, pushChatLimit, savedGifsLimit, editTimeLimit, ratingEDecay, stickersRecentLimit, tmpSessions, pinnedDialogsCountMax, callReceiveTimeoutMs, callRingTimeoutMs, callConnectTimeoutMs, callPacketTimeoutMs, meUrlPrefix, disabledFeatures):
                    var addressList: [Int: [MTDatacenterAddress]] = [:]
                    for option in dcOptions {
                        switch option {
                            case let .dcOption(flags, id, ipAddress, port):
                                let preferForMedia = (flags & (1 << 1)) != 0
                                if addressList[Int(id)] == nil {
                                    addressList[Int(id)] = []
                                }
                                addressList[Int(id)]!.append(MTDatacenterAddress(ip: ipAddress, port: UInt16(port), preferForMedia: preferForMedia, restrictToTcp: false))
                        }
                    }
                    network.context.performBatchUpdates {
                        for (id, list) in addressList {
                            network.context.updateAddressSetForDatacenter(withId: id, addressSet: MTDatacenterAddressSet(addressList: list))
                        }
                    }
            }
        })
    }
    
    return (poll |> then(.complete() |> delay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
