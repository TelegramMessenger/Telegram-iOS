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
        return (network.request(Api.functions.help.getConfig()) |> retryRequest |> mapToSignal { result -> Signal<Void, NoError> in
            return postbox.modify { modifier -> Void in
                switch result {
                    case let .config(flags, _, _, _, _, dcOptions, chatSizeMax, megagroupSizeMax, forwardedCountMax, _, _, _, onlineCloudTimeoutMs, notifyCloudDelayMs, notifyDefaultDelayMs, pushChatPeriodMs, pushChatLimit, savedGifsLimit, editTimeLimit, revokeTimeLimit, revokePmTimeLimit,  ratingEDecay, stickersRecentLimit, stickersFavedLimit, channelsReadMediaPeriod, tmpSessions, pinnedDialogsCountMax, callReceiveTimeoutMs, callRingTimeoutMs, callConnectTimeoutMs, callPacketTimeoutMs, meUrlPrefix, autoupdateUrlPrefix, suggestedLangCode, langPackVersion):
                        var addressList: [Int: [MTDatacenterAddress]] = [:]
                        for option in dcOptions {
                            switch option {
                                case let .dcOption(flags, id, ipAddress, port, secret):
                                    let preferForMedia = (flags & (1 << 1)) != 0
                                    if addressList[Int(id)] == nil {
                                        addressList[Int(id)] = []
                                    }
                                    let restrictToTcp = (flags & (1 << 2)) != 0
                                    let isCdn = (flags & (1 << 3)) != 0
                                    let preferForProxy = (flags & (1 << 4)) != 0
                                    addressList[Int(id)]!.append(MTDatacenterAddress(ip: ipAddress, port: UInt16(port), preferForMedia: preferForMedia, restrictToTcp: restrictToTcp, cdn: isCdn, preferForProxy: preferForProxy, secret: secret?.makeData()))
                            }
                        }
                        network.context.performBatchUpdates {
                            for (id, list) in addressList {
                                network.context.updateAddressSetForDatacenter(withId: id, addressSet: MTDatacenterAddressSet(addressList: list), forceUpdateSchemes: false)
                            }
                        }
                        
                        let blockedMode = (flags & 8) != 0
                        updateNetworkSettingsInteractively(modifier: modifier, network: network, { settings in
                            var settings = settings
                            settings.reducedBackupDiscoveryTimeout = blockedMode
                            return settings
                        })
                        
                        modifier.updatePreferencesEntry(key: PreferencesKeys.suggestedLocalization, { entry in
                            var currentLanguageCode: String?
                            if let entry = entry as? SuggestedLocalizationEntry {
                                currentLanguageCode = entry.languageCode
                            }
                            if currentLanguageCode != suggestedLangCode {
                                if let suggestedLangCode = suggestedLangCode {
                                    return SuggestedLocalizationEntry(languageCode: suggestedLangCode, isSeen: false)
                                } else {
                                    return nil
                                }
                            }
                            return entry
                        })
                        
                        updateLimitsConfiguration(modifier: modifier, configuration: LimitsConfiguration(maxGroupMemberCount: chatSizeMax, maxSupergroupMemberCount: megagroupSizeMax, maxMessageForwardBatchSize: forwardedCountMax, maxSavedGifCount: savedGifsLimit, maxRecentStickerCount: stickersRecentLimit, maxMessageEditingInterval: editTimeLimit))
                    
                        let (_, version, _) = getLocalization(modifier)
                        if version != langPackVersion {
                            addSynchronizeLocalizationUpdatesOperation(modifier: modifier)
                        }
                }
            }
        }).start()
    }
    
    return (poll |> then(.complete() |> delay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
