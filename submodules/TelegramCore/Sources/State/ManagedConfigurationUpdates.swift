import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


func managedConfigurationUpdates(accountManager: AccountManager<TelegramAccountManagerTypes>, postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = Signal<Void, NoError> { subscriber in
        return (network.request(Api.functions.help.getConfig())
        |> retryRequest
        |> mapToSignal { result -> Signal<Void, NoError> in
            return postbox.transaction { transaction -> Signal<Void, NoError> in
                switch result {
                case let .config(flags, _, _, _, _, dcOptions, _, chatSizeMax, megagroupSizeMax, forwardedCountMax, _, _, _, _, _, _, _, _, savedGifsLimit, editTimeLimit, revokeTimeLimit, revokePmTimeLimit, _, stickersRecentLimit, stickersFavedLimit, _, _, pinnedDialogsCountMax, pinnedInfolderCountMax, _, _, _, _, _, autoupdateUrlPrefix, gifSearchUsername, venueSearchUsername, imgSearchUsername, _, captionLengthMax, _, webfileDcId, suggestedLangCode, langPackVersion, baseLangPackVersion):
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
                        
                        updateNetworkSettingsInteractively(transaction: transaction, network: network, { settings in
                            var settings = settings
                            settings.reducedBackupDiscoveryTimeout = blockedMode
                            settings.applicationUpdateUrlPrefix = autoupdateUrlPrefix
                            return settings
                        })
                        
                        updateRemoteStorageConfiguration(transaction: transaction, configuration: RemoteStorageConfiguration(webDocumentsHostDatacenterId: webfileDcId))
                        
                        transaction.updatePreferencesEntry(key: PreferencesKeys.suggestedLocalization, { entry in
                            var currentLanguageCode: String?
                            if let entry = entry?.get(SuggestedLocalizationEntry.self) {
                                currentLanguageCode = entry.languageCode
                            }
                            if currentLanguageCode != suggestedLangCode {
                                if let suggestedLangCode = suggestedLangCode {
                                    return PreferencesEntry(SuggestedLocalizationEntry(languageCode: suggestedLangCode, isSeen: false))
                                } else {
                                    return nil
                                }
                            }
                            return entry
                        })
                        
                        updateLimitsConfiguration(transaction: transaction, configuration: LimitsConfiguration(maxPinnedChatCount: pinnedDialogsCountMax, maxArchivedPinnedChatCount: pinnedInfolderCountMax, maxGroupMemberCount: chatSizeMax, maxSupergroupMemberCount: megagroupSizeMax, maxMessageForwardBatchSize: forwardedCountMax, maxSavedGifCount: savedGifsLimit, maxRecentStickerCount: stickersRecentLimit, maxFavedStickerCount: stickersFavedLimit, maxMessageEditingInterval: editTimeLimit, maxMediaCaptionLength: captionLengthMax, canRemoveIncomingMessagesInPrivateChats: (flags & (1 << 6)) != 0, maxMessageRevokeInterval: revokeTimeLimit, maxMessageRevokeIntervalInPrivateChats: revokePmTimeLimit))
                        
                        updateSearchBotsConfiguration(transaction: transaction, configuration: SearchBotsConfiguration(imageBotUsername: imgSearchUsername, gifBotUsername: gifSearchUsername, venueBotUsername: venueSearchUsername))
                    
                        return accountManager.transaction { transaction -> Signal<Void, NoError> in
                            let (primary, secondary) = getLocalization(transaction)
                            var invalidateLocalization = false
                            if primary.version != langPackVersion {
                                invalidateLocalization = true
                            }
                            if let secondary = secondary, let baseLangPackVersion = baseLangPackVersion {
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
        }).start(completed: {
            subscriber.putCompletion()
        })
    }
    
    return (poll |> then(.complete() |> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
