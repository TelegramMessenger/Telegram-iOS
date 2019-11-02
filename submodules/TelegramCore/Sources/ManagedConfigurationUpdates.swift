import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

func managedConfigurationUpdates(accountManager: AccountManager, postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = Signal<Void, NoError> { subscriber in
        return (network.request(Api.functions.help.getConfig())
        |> retryRequest
        |> mapToSignal { result -> Signal<Void, NoError> in
            return postbox.transaction { transaction -> Signal<Void, NoError> in
                switch result {
                    case let .config(config):
                        var addressList: [Int: [MTDatacenterAddress]] = [:]
                        for option in config.dcOptions {
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
                        
                        let blockedMode = (config.flags & 8) != 0
                        updateNetworkSettingsInteractively(transaction: transaction, network: network, { settings in
                            var settings = settings
                            settings.reducedBackupDiscoveryTimeout = blockedMode
                            settings.applicationUpdateUrlPrefix = config.autoupdateUrlPrefix
                            return settings
                        })
                        
                        updateRemoteStorageConfiguration(transaction: transaction, configuration: RemoteStorageConfiguration(webDocumentsHostDatacenterId: config.webfileDcId))
                        
                        transaction.updatePreferencesEntry(key: PreferencesKeys.suggestedLocalization, { entry in
                            var currentLanguageCode: String?
                            if let entry = entry as? SuggestedLocalizationEntry {
                                currentLanguageCode = entry.languageCode
                            }
                            if currentLanguageCode != config.suggestedLangCode {
                                if let suggestedLangCode = config.suggestedLangCode {
                                    return SuggestedLocalizationEntry(languageCode: suggestedLangCode, isSeen: false)
                                } else {
                                    return nil
                                }
                            }
                            return entry
                        })
                        
                        updateLimitsConfiguration(transaction: transaction, configuration: LimitsConfiguration(maxPinnedChatCount: config.pinnedDialogsCountMax, maxArchivedPinnedChatCount: config.pinnedInfolderCountMax, maxGroupMemberCount: config.chatSizeMax, maxSupergroupMemberCount: config.megagroupSizeMax, maxMessageForwardBatchSize: config.forwardedCountMax, maxSavedGifCount: config.savedGifsLimit, maxRecentStickerCount: config.stickersRecentLimit, maxMessageEditingInterval: config.editTimeLimit, maxMediaCaptionLength: config.captionLengthMax, canRemoveIncomingMessagesInPrivateChats: (config.flags & (1 << 6)) != 0, maxMessageRevokeInterval: config.revokeTimeLimit, maxMessageRevokeIntervalInPrivateChats: config.revokePmTimeLimit))
                        
                        updateSearchBotsConfiguration(transaction: transaction, configuration: SearchBotsConfiguration(imageBotUsername: config.imgSearchUsername, gifBotUsername: config.gifSearchUsername, venueBotUsername: config.venueSearchUsername))
                    
                        return accountManager.transaction { transaction -> Signal<Void, NoError> in
                            let (primary, secondary) = getLocalization(transaction)
                            var invalidateLocalization = false
                            if primary.version != config.langPackVersion {
                                invalidateLocalization = true
                            }
                            if let secondary = secondary, let baseLangPackVersion = config.baseLangPackVersion {
                                if secondary.version != baseLangPackVersion {
                                    invalidateLocalization = true
                                }
                            }
                            if invalidateLocalization {
                                return postbox.transaction { transaction -> Void in
                                    addSynchronizeLocalizationUpdatesOperation(transaction: transaction)
                                }
                            } else {
                                return .complete()
                            }
                        }
                        |> switchToLatest
                }
            }
            |> switchToLatest
        }).start()
    }
    
    return (poll |> then(.complete() |> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
