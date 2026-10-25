import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Account settings: notification settings, stickers and GIFs, language packs, themes, the app config,
/// authorizations and the in-app browser.
extension UpdateInterpreter {
    mutating func applyNotifySettings(_ updateNotifySettingsData: Api.Update.Cons_updateNotifySettings) {
        let (apiPeer, apiNotificationSettings) = (updateNotifySettingsData.peer, updateNotifySettingsData.notifySettings)
        switch apiPeer {
            case let .notifyPeer(notifyPeerData):
                let peer = notifyPeerData.peer
                let notificationSettings = TelegramPeerNotificationSettings(apiSettings: apiNotificationSettings)
                updatedState.updateNotificationSettings(.peer(peerId: peer.peerId, threadId: nil), notificationSettings: notificationSettings)
            case let .notifyForumTopic(notifyForumTopicData):
                let (peer, topMsgId) = (notifyForumTopicData.peer, notifyForumTopicData.topMsgId)
                let notificationSettings = TelegramPeerNotificationSettings(apiSettings: apiNotificationSettings)
                updatedState.updateNotificationSettings(.peer(peerId: peer.peerId, threadId: Int64(topMsgId)), notificationSettings: notificationSettings)
            case let .notifyCommunity(notifyCommunityData):
                let communityId = notifyCommunityData.communityId
                let notificationSettings = TelegramPeerNotificationSettings(apiSettings: apiNotificationSettings)
                updatedState.updateNotificationSettings(.peer(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(communityId)), threadId: nil), notificationSettings: notificationSettings)
            case .notifyUsers:
                updatedState.updateGlobalNotificationSettings(.privateChats, notificationSettings: MessageNotificationSettings(apiSettings: apiNotificationSettings))
            case .notifyChats:
                updatedState.updateGlobalNotificationSettings(.groups, notificationSettings: MessageNotificationSettings(apiSettings: apiNotificationSettings))
            case .notifyBroadcasts:
                updatedState.updateGlobalNotificationSettings(.channels, notificationSettings: MessageNotificationSettings(apiSettings: apiNotificationSettings))
        }
    }
    
    mutating func applyNewStickerSet(_ updateNewStickerSetData: Api.Update.Cons_updateNewStickerSet) {
        updatedState.addUpdateInstalledStickerPacks(.add(updateNewStickerSetData.stickerset))
    }
    
    mutating func applyStickerSetsOrder(_ updateStickerSetsOrderData: Api.Update.Cons_updateStickerSetsOrder) {
        let namespace: SynchronizeInstalledStickerPacksOperationNamespace
        if (updateStickerSetsOrderData.flags & (1 << 0)) != 0 {
            namespace = .masks
        } else if (updateStickerSetsOrderData.flags & (1 << 1)) != 0 {
            namespace = .emoji
        } else {
            namespace = .stickers
        }
        updatedState.addUpdateInstalledStickerPacks(.reorder(namespace, updateStickerSetsOrderData.order))
    }
    
    mutating func applyMoveStickerSetToTop(_ updateMoveStickerSetToTopData: Api.Update.Cons_updateMoveStickerSetToTop) {
        let namespace: SynchronizeInstalledStickerPacksOperationNamespace
        if (updateMoveStickerSetToTopData.flags & (1 << 0)) != 0 {
            namespace = .masks
        } else if (updateMoveStickerSetToTopData.flags & (1 << 1)) != 0 {
            namespace = .emoji
        } else {
            namespace = .stickers
        }
        updatedState.addUpdateInstalledStickerPacks(.reorderToTop(namespace, [updateMoveStickerSetToTopData.stickerset]))
    }
    
    mutating func applyStickerSets() {
        updatedState.addUpdateInstalledStickerPacks(.sync)
    }
    
    mutating func applySavedGifs() {
        updatedState.addUpdateRecentGifs()
    }
    
    mutating func applyLangPackTooLong(_ updateLangPackTooLongData: Api.Update.Cons_updateLangPackTooLong) {
        updatedState.updateLangPack(langCode: updateLangPackTooLongData.langCode, difference: nil)
    }
    
    mutating func applyLangPack(_ updateLangPackData: Api.Update.Cons_updateLangPack) {
        let langCode: String
        switch updateLangPackData.difference {
            case let .langPackDifference(langPackDifferenceData):
                let (langCodeValue) = (langPackDifferenceData.langCode)
                langCode = langCodeValue
        }
        updatedState.updateLangPack(langCode: langCode, difference: updateLangPackData.difference)
    }
    
    mutating func applyTheme(_ updateThemeData: Api.Update.Cons_updateTheme) {
        updatedState.updateTheme(TelegramTheme(apiTheme: updateThemeData.theme))
    }
    
    mutating func applyConfig() {
        updatedState.reloadConfig()
    }
    
    mutating func applyNewAuthorization(_ updateNewAuthorizationData: Api.Update.Cons_updateNewAuthorization) {
        let (flags, hash, date, device, location) = (updateNewAuthorizationData.flags, updateNewAuthorizationData.hash, updateNewAuthorizationData.date, updateNewAuthorizationData.device, updateNewAuthorizationData.location)
        let isUnconfirmed = (flags & (1 << 0)) != 0
        updatedState.updateNewAuthorization(isUnconfirmed: isUnconfirmed, hash: hash, date: date ?? 0, device: device ?? "", location: location ?? "")
    }
    
    mutating func applyNewBotConnection(_ updateNewBotConnectionData: Api.Update.Cons_updateNewBotConnection) {
        let (flags, botId, date, device, location) = (updateNewBotConnectionData.flags, updateNewBotConnectionData.botId, updateNewBotConnectionData.date, updateNewBotConnectionData.device, updateNewBotConnectionData.location)
        updatedState.updateNewBotConnection(
            confirmed: (flags & (1 << 0)) != 0,
            botId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId)),
            date: date,
            device: device,
            location: location
        )
    }
    
    mutating func applyWebBrowserSettings(_ updateWebBrowserSettingsData: Api.Update.Cons_updateWebBrowserSettings) {
        updatedState.updateWebBrowserSettings(openExternalBrowser: (updateWebBrowserSettingsData.flags & (1 << 0)) != 0)
    }
    
    mutating func applyWebBrowserException(_ updateWebBrowserExceptionData: Api.Update.Cons_updateWebBrowserException) {
        let openExternalBrowser: Bool?
        if let value = updateWebBrowserExceptionData.openExternalBrowser {
            switch value {
            case .boolFalse:
                openExternalBrowser = false
            case .boolTrue:
                openExternalBrowser = true
            }
        } else {
            openExternalBrowser = nil
        }
        updatedState.updateWebBrowserException(
            openExternalBrowser: openExternalBrowser,
            delete: (updateWebBrowserExceptionData.flags & (1 << 1)) != 0,
            exception: AccountWebBrowserException(apiWebDomainException: updateWebBrowserExceptionData.exception)
        )
    }
}
