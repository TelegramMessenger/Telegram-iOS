import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

public enum SavedStickerResult {
    case generic
    case limitExceeded(Int32, Int32)
}

func _internal_toggleStickerSaved(postbox: Postbox, network: Network, accountPeerId: PeerId, file: TelegramMediaFile, saved: Bool) -> Signal<SavedStickerResult, AddSavedStickerError> {
    if saved {
        return postbox.transaction { transaction -> Signal<SavedStickerResult, AddSavedStickerError> in
            let isPremium = transaction.getPeer(accountPeerId)?.isPremium ?? false
            let items = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudSavedStickers)
            
            let appConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self) ?? .defaultValue
            let limitsConfiguration = UserLimitsConfiguration(appConfiguration: appConfiguration, isPremium: false)
            let premiumLimitsConfiguration = UserLimitsConfiguration(appConfiguration: appConfiguration, isPremium: false)
            
            return addSavedSticker(postbox: postbox, network: network, file: file)
            |> map { _ -> SavedStickerResult in
                return items.count == limitsConfiguration.maxFavedStickerCount && !isPremium ? .limitExceeded(limitsConfiguration.maxFavedStickerCount, premiumLimitsConfiguration.maxFavedStickerCount) : .generic
            }
        }
        |> castError(AddSavedStickerError.self)
        |> switchToLatest
    } else {
        return removeSavedSticker(postbox: postbox, mediaId: file.fileId)
        |> map { _ -> SavedStickerResult in
            return .generic
        }
        |> castError(AddSavedStickerError.self)
    }
}
