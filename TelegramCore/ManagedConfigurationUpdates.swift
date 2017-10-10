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

//config flags:# date:int expires:int test_mode:Bool this_dc:int dc_options:Vector<DcOption> chat_size_max:int megagroup_size_max:int forwarded_count_max:int online_update_period_ms:int offline_blur_timeout_ms:int offline_idle_timeout_ms:int online_cloud_timeout_ms:int notify_cloud_delay_ms:int notify_default_delay_ms:int chat_big_size:int push_chat_period_ms:int push_chat_limit:int saved_gifs_limit:int edit_time_limit:int rating_e_decay:int stickers_recent_limit:int stickers_faved_limit:int channels_read_media_period:int tmp_sessions:flags.0?int pinned_dialogs_count_max:int phonecalls_enabled:flags.1?true call_receive_timeout_ms:int call_ring_timeout_ms:int call_connect_timeout_ms:int call_packet_timeout_ms:int me_url_prefix:string suggested_lang_code:flags.2?string lang_pack_version:flags.2?int disabled_features:Vector<DisabledFeature> = Config;

func managedConfigurationUpdates(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = Signal<Void, NoError> { subscriber in
        return (network.request(Api.functions.help.getConfig()) |> retryRequest |> mapToSignal { result -> Signal<Void, NoError> in
            return postbox.modify { modifier -> Void in
                switch result {
                    case let .config(_, _, _, _, _, dcOptions, chatSizeMax, megagroupSizeMax, forwardedCountMax, _, _, _, onlineCloudTimeoutMs, notifyCloudDelayMs, notifyDefaultDelayMs, chatBigSize, pushChatPeriodMs, pushChatLimit, savedGifsLimit, editTimeLimit, ratingEDecay, stickersRecentLimit, stickersFavedLimit, channelsReadMediaPeriod, tmpSessions, pinnedDialogsCountMax, callReceiveTimeoutMs, callRingTimeoutMs, callConnectTimeoutMs, callPacketTimeoutMs, meUrlPrefix, suggestedLangCode, langPackVersion, disabledFeatures):
                        var addressList: [Int: [MTDatacenterAddress]] = [:]
                        for option in dcOptions {
                            switch option {
                                case let .dcOption(flags, id, ipAddress, port):
                                    let preferForMedia = (flags & (1 << 1)) != 0
                                    if addressList[Int(id)] == nil {
                                        addressList[Int(id)] = []
                                    }
                                    let restrictToTcp = (flags & (1 << 2)) != 0
                                    let isCdn = (flags & (1 << 3)) != 0
                                    let preferForProxy = (flags & (1 << 4)) != 0
                                    addressList[Int(id)]!.append(MTDatacenterAddress(ip: ipAddress, port: UInt16(port), preferForMedia: preferForMedia, restrictToTcp: restrictToTcp, cdn: isCdn, preferForProxy: preferForProxy))
                            }
                        }
                        network.context.performBatchUpdates {
                            for (id, list) in addressList {
                                network.context.updateAddressSetForDatacenter(withId: id, addressSet: MTDatacenterAddressSet(addressList: list), forceUpdateSchemes: false)
                            }
                        }
                        
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
