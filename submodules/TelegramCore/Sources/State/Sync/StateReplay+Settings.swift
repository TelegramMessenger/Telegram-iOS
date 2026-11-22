import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Account settings: notification settings, installed sticker packs and saved GIFs, language packs, themes, the app
/// config, authorizations, bot connections and the in-app browser.
extension ReplayContext {
    func applyUpdateNotificationSettings(_ subject: AccountStateNotificationSettingsSubject, _ notificationSettings: TelegramPeerNotificationSettings) {
        switch subject {
        case let .peer(peerId, threadId):
            if let threadId = threadId {
                if let initialData = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
                    var data = initialData

                    data.notificationSettings = notificationSettings

                    if data != initialData {
                        if let entry = StoredMessageHistoryThreadInfo(data) {
                            transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: threadId, info: entry)
                        }
                    }
                }
            } else {
                transaction.updateCurrentPeerNotificationSettings([peerId: notificationSettings])
            }
        }
    }
    
    func applyUpdateGlobalNotificationSettings(_ subject: AccountStateGlobalNotificationSettingsSubject, _ notificationSettings: MessageNotificationSettings) {
        switch subject {
            case .privateChats:
                transaction.updatePreferencesEntry(key: PreferencesKeys.globalNotifications, { current in
                    var updated: GlobalNotificationSettings
                    if let current = current?.get(GlobalNotificationSettings.self) {
                        updated = current
                    } else {
                        updated = GlobalNotificationSettings.defaultSettings
                    }
                    updated.remote.privateChats = notificationSettings
                    return PreferencesEntry(updated)
                })
                transaction.globalNotificationSettingsUpdated()
            case .groups:
                transaction.updatePreferencesEntry(key: PreferencesKeys.globalNotifications, { current in
                    var updated: GlobalNotificationSettings
                    if let current = current?.get(GlobalNotificationSettings.self) {
                        updated = current
                    } else {
                        updated = GlobalNotificationSettings.defaultSettings
                    }
                    updated.remote.groupChats = notificationSettings
                    return PreferencesEntry(updated)
                })
                transaction.globalNotificationSettingsUpdated()
            case .channels:
                transaction.updatePreferencesEntry(key: PreferencesKeys.globalNotifications, { current in
                    var updated: GlobalNotificationSettings
                    if let current = current?.get(GlobalNotificationSettings.self) {
                        updated = current
                    } else {
                        updated = GlobalNotificationSettings.defaultSettings
                    }
                    updated.remote.channels = notificationSettings
                    return PreferencesEntry(updated)
                })
                transaction.globalNotificationSettingsUpdated()
        }
    }
    
    func applyUpdateInstalledStickerPacks(_ operation: AccountStateUpdateStickerPacksOperation) {
        stickerPackOperations.append(operation)
    }
    
    func applyUpdateRecentGifs() {
        syncRecentGifs = true
    }
    
    func applyUpdateLangPack(_ langCode: String, _ difference: Api.LangPackDifference?) {
        if let difference = difference {
            if langPackDifferences[langCode] == nil {
                langPackDifferences[langCode] = []
            }
            langPackDifferences[langCode]!.append(difference)
        } else {
            pollLangPacks.insert(langCode)
        }
    }
    
    func applyUpdateTheme(_ theme: TelegramTheme) {
        updatedThemes[theme.id] = theme
    }
    
    func applyUpdateConfig() {
        updateConfig = true
    }
    
    func applyUpdateNewAuthorization(_ isUnconfirmed: Bool, _ hash: Int64, _ date: Int32, _ device: String, _ location: String) {
        let id = NewSessionReview.Id(id: hash)
        if isUnconfirmed {
            if let entry = CodableEntry(NewSessionReview(
                id: hash,
                device: device,
                location: location,
                timestamp: date
            )) {
                transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.NewSessionReviews, item: OrderedItemListEntry(id: id.rawValue, contents: entry), removeTailIfCountExceeds: 200)
            }
        } else {
            transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.NewSessionReviews, itemId: id.rawValue)
        }
    }
    
    func applyUpdateNewBotConnection(_ confirmed: Bool, _ botId: PeerId, _ date: Int32?, _ device: String?, _ location: String?) {
        let id = NewBotConnectionReview.Id(botId: botId)
        if confirmed {
            transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.NewBotConnectionReviews, itemId: id.rawValue)
        } else if let entry = CodableEntry(NewBotConnectionReview(
            botId: botId,
            device: device,
            location: location,
            timestamp: date
        )) {
            transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.NewBotConnectionReviews, item: OrderedItemListEntry(id: id.rawValue, contents: entry), removeTailIfCountExceeds: 200)
        }
    }
    
    func applyUpdateWebBrowserSettings(_ openExternalBrowser: Bool) {
        webBrowserSettingsUpdates.append { settings in
            settings.withUpdatedOpenExternalBrowser(openExternalBrowser)
        }
    }
    
    func applyUpdateWebBrowserException(_ openExternalBrowser: Bool?, _ delete: Bool, _ exception: AccountWebBrowserException) {
        webBrowserSettingsUpdates.append { settings in
            settings.withAppliedExceptionUpdate(openExternalBrowser: openExternalBrowser, delete: delete, exception: exception)
        }
    }
}
